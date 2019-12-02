<#
    Define enumeration for use by wiki example generation to determine the type of
    block that a text line is within.
#>
if (-not ([System.Management.Automation.PSTypeName]'WikiExampleBlockType').Type)
{
    $typeDefinition = @'
    public enum WikiExampleBlockType
    {
        None,
        PSScriptInfo,
        Configuration,
        ExampleCommentHeader
    }
'@
    Add-Type -TypeDefinition $typeDefinition
}

$projectRootPath = Split-Path -Path $PSScriptRoot -Parent
$testHelperPath = Join-Path -Path $projectRootPath -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperPath -Force

$script:localizedData = Get-LocalizedData -ModuleName 'WikiPages' -ModuleRoot $PSScriptRoot

$appVeyorApiUrl = 'https://ci.appveyor.com/api'

<#
    .SYNOPSIS
        New-DscResourceWikiSite generates wiki pages that can be uploaded to GitHub to use as
        public documentation for a module.

    .DESCRIPTION
        The New-DscResourceWikiSite cmdlet will review all of the MOF based resources
        in a specified module directory and will output the Markdown files to the specified directory.
        These help files include details on the property types for each resource, as well as a text
        description and examples where they exist.

    .PARAMETER OutputPath
        Where should the files be saved to

    .PARAMETER ModulePath
        The path to the root of the DSC resource module (where the PSD1 file is found, not the folder for
        and individual DSC resource)

    .EXAMPLE
        New-DscResourceWikiSite -ModulePath C:\repos\SharePointdsc -OutputPath C:\repos\SharePointDsc\en-US

        This example shows how to generate help for a specific module
#>
function New-DscResourceWikiSite
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $OutputPath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $ModulePath
    )

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'MofHelper.psm1')

    $mofSearchPath = Join-Path -Path $ModulePath -ChildPath '\**\*.schema.mof'
    $mofSchemaFiles = Get-ChildItem -Path $mofSearchPath -Recurse

    # Loop through all the Schema files found in the modules folder
    foreach ($mofSchemaFile in $mofSchemaFiles)
    {
        $mofSchema = Get-MofSchemaObject -FileName $mofSchemaFile.FullName |
            Where-Object -FilterScript {
                ($_.ClassName -eq $mofSchemaFile.Name.Replace('.schema.mof', '')) `
                    -and ($null -ne $_.FriendlyName)
            }

        $descriptionPath = Join-Path -Path $mofSchemaFile.DirectoryName -ChildPath 'readme.md'

        if (Test-Path -Path $descriptionPath)
        {
            Write-Verbose -Message "Generating wiki page for $($mofSchema.FriendlyName)"

            $output = New-Object -TypeName System.Text.StringBuilder
            $null = $output.AppendLine("# $($mofSchema.FriendlyName)")
            $null = $output.AppendLine('')
            $null = $output.AppendLine('## Parameters')
            $null = $output.AppendLine('')
            $null = $output.AppendLine('| Parameter | Attribute | DataType | Description | Allowed Values |')
            $null = $output.AppendLine('| --- | --- | --- | --- | --- |')

            foreach ($property in $mofSchema.Attributes)
            {
                # If the attribute is an array, add [] to the DataType string
                $dataType = $property.DataType

                if ($property.IsArray)
                {
                    $dataType = $dataType.ToString() + '[]'
                }

                if ($property.EmbeddedInstance -eq 'MSFT_Credential')
                {
                    $dataType = 'PSCredential'
                }

                $null = $output.Append("| **$($property.Name)** " + `
                        "| $($property.State) " + `
                        "| $dataType " + `
                        "| $($property.Description) |")

                if ([string]::IsNullOrEmpty($property.ValueMap) -ne $true)
                {
                    $null = $output.Append(($property.ValueMap -Join ', '))
                }

                $null = $output.AppendLine('|')
            }

            $descriptionContent = Get-Content -Path $descriptionPath -Raw

            # Change the description H1 header to an H2
            $descriptionContent = $descriptionContent -replace '# Description', '## Description'
            $null = $output.AppendLine()
            $null = $output.AppendLine($descriptionContent)

            $exampleSearchPath = "\Examples\Resources\$($mofSchema.FriendlyName)\*.ps1"
            $examplesPath = (Join-Path -Path $ModulePath -ChildPath $exampleSearchPath)
            $exampleFiles = Get-ChildItem -Path $examplesPath -ErrorAction SilentlyContinue

            if ($null -ne $exampleFiles)
            {
                $null = $output.AppendLine('## Examples')
                $exampleCount = 1

                foreach ($exampleFile in $exampleFiles)
                {
                    Write-Verbose -Message "Adding Example file '$($exampleFile.Name)' to wiki page for $($mofSchema.FriendlyName)"

                    $exampleContent = Get-DscResourceWikiExampleContent `
                        -ExamplePath $exampleFile.FullName `
                        -ExampleNumber ($exampleCount++)

                    $null = $output.AppendLine()
                    $null = $output.AppendLine($exampleContent)
                }
            }

            $null = Out-File `
                -InputObject $output.ToString() `
                -FilePath (Join-Path -Path $OutputPath -ChildPath "$($mofSchema.FriendlyName).md") `
                -Encoding utf8 `
                -Force
        }
    }
}

<#
    .SYNOPSIS
        This function reads an example file from a resource and converts
        it to markdown for inclusion in a resource wiki file.

    .DESCRIPTION
        The function will read the example PS1 file and convert the
        help header into the description text for the example. It will
        also surround the example configuration with code marks to
        indication it is powershell code.

    .PARAMETER ExamplePath
        The path to the example file.

    .PARAMETER ModulePath
        The number of the example.

    .EXAMPLE
        Get-DscResourceWikiExampleContent -ExamplePath 'C:\repos\NetworkingDsc\Examples\Resources\DhcpClient\1-DhcpClient_EnableDHCP.ps1' -ExampleNumber 1

        Reads the content of 'C:\repos\NetworkingDsc\Examples\Resources\DhcpClient\1-DhcpClient_EnableDHCP.ps1'
        and converts it to markdown in preparation for being added to a resource wiki page.
#>

function Get-DscResourceWikiExampleContent
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ExamplePath,

        [Parameter(Mandatory = $true)]
        [System.Int32]
        $ExampleNumber
    )

    $exampleContent = Get-Content -Path $ExamplePath

    # Use a string builder to assemble the example description and code
    $exampleDescriptionStringBuilder = New-Object -TypeName System.Text.StringBuilder
    $exampleCodeStringBuilder = New-Object -TypeName System.Text.StringBuilder

    <#
        Step through each line in the source example and determine
        the content and act accordingly:
        \<#PSScriptInfo...#\> - Drop block
        \#Requires - Drop Line
        \<#...#\> - Drop .EXAMPLE, .SYNOPSIS and .DESCRIPTION but include all other lines
        Configuration ... - Include entire block until EOF
    #>
    $blockType = [WikiExampleBlockType]::None

    foreach ($exampleLine in $exampleContent)
    {
        Write-Debug -Message ('Processing Line: {0}' -f $exampleLine)

        # Determine the behavior based on the current block type
        switch ($blockType.ToString())
        {
            'PSScriptInfo'
            {
                Write-Debug -Message 'PSScriptInfo Block Processing'

                # Exclude PSScriptInfo block from any output
                if ($exampleLine -eq '#>')
                {
                    Write-Debug -Message 'PSScriptInfo Block Ended'

                    # End of the PSScriptInfo block
                    $blockType = [WikiExampleBlockType]::None
                }
            }

            'Configuration'
            {
                Write-Debug -Message 'Configuration Block Processing'

                # Include all lines in the configuration block in the code output
                $null = $exampleCodeStringBuilder.AppendLine($exampleLine)
            }

            'ExampleCommentHeader'
            {
                Write-Debug -Message 'ExampleCommentHeader Block Processing'

                # Include all lines in Example Comment Header block except for headers
                $exampleLine = $exampleLine.TrimStart()

                if ($exampleLine -notin ('.SYNOPSIS', '.DESCRIPTION', '.EXAMPLE', '#>'))
                {
                    # Not a header so add this to the output
                    $null = $exampleDescriptionStringBuilder.AppendLine($exampleLine)
                }

                if ($exampleLine -eq '#>')
                {
                    Write-Debug -Message 'ExampleCommentHeader Block Ended'

                    # End of the Example Comment Header block
                    $blockType = [WikiExampleBlockType]::None
                }
            }

            default
            {
                Write-Debug -Message 'Not Currently Processing Block'

                # Check the current line
                if ($exampleLine.TrimStart() -eq '<#PSScriptInfo')
                {
                    Write-Debug -Message 'PSScriptInfo Block Started'

                    $blockType = [WikiExampleBlockType]::PSScriptInfo
                }
                elseif ($exampleLine -match 'Configuration')
                {
                    Write-Debug -Message 'Configuration Block Started'

                    $null = $exampleCodeStringBuilder.AppendLine($exampleLine)
                    $blockType = [WikiExampleBlockType]::Configuration
                }
                elseif ($exampleLine.TrimStart() -eq '<#')
                {
                    Write-Debug -Message 'ExampleCommentHeader Block Started'

                    $blockType = [WikiExampleBlockType]::ExampleCommentHeader
                }
            }
        }
    }

    # Assemble the final output
    $null = $exampleStringBuilder = New-Object -TypeName System.Text.StringBuilder
    $null = $exampleStringBuilder.AppendLine("### Example $ExampleNumber")
    $null = $exampleStringBuilder.AppendLine()
    $null = $exampleStringBuilder.AppendLine($exampleDescriptionStringBuilder)
    $null = $exampleStringBuilder.AppendLine('```powershell')
    $null = $exampleStringBuilder.Append($exampleCodeStringBuilder)
    $null = $exampleStringBuilder.Append('```')

    return $exampleStringBuilder.ToString()
}

<#
    .SYNOPSIS
        Publishes the Wiki Content from a module and AppVeyor job artifact.

    .DESCRIPTION
        This function publishes the content pages from the Wiki Content artifact
        of a specified AppVeyor job along with any additional files stored in the
        'WikiSource' directory of the repository and an auto-generated sidebar file
        containing links to all the markdown files to the Wiki of a specified GitHub
        repository.

    .PARAMETER RepoName
        The name of the Github Repo, in the format <account>/<repo>.

    .PARAMETER JobId
        The AppVeyor job id that contains the wiki artifact to publish.

    .PARAMETER MainModulePath
        The path of the DSC Resource Module.

    .PARAMETER WikiSourceFolder
        The name of the folder in the DSC Resource Module that contains any Wiki source files.

    .PARAMETER ResourceModuleName
        The name of the Dsc Resource Module.

    .PARAMETER BuildVersion
        The build version number to tag the Wiki Github commit with.

    .PARAMETER GithubAccessToken
        The GitHub access token to allow a push to the GitHub Wiki.

    .PARAMETER GitUserEmail
        The email address to use for the Git commit.

    .PARAMETER GitUserName
        The user name to use for the Git commit.

    .EXAMPLE
        Publish-WikiContent -RepoName 'PowerShell/xActiveDirectory' -JobId 'imy2wgp1ylo9bcpb' -ResourceModuleName 'xActiveDirectory' `
                            -MainModulePath 'C:\ModulePath' -BuildVersion 'v1.0.0'

        Adds the Content pages from the AppVeyor Job artifact and module path to the Wiki for the specified GitHub repository.

    .NOTES
        Appveyor - Push to remote Git repository from a build: https://www.appveyor.com/docs/how-to/git-push/
#>
function Publish-WikiContent
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [System.String]
        $RepoName = $env:APPVEYOR_REPO_NAME,

        [Parameter()]
        [System.String]
        $JobId = $env:APPVEYOR_JOB_ID,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $MainModulePath = $env:APPVEYOR_BUILD_FOLDER,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $WikiSourceFolder = 'WikiSource',

        [Parameter()]
        [System.String]
        $ResourceModuleName = (($env:APPVEYOR_REPO_NAME -split '/')[1]),

        [Parameter()]
        [System.String]
        $BuildVersion = $env:APPVEYOR_BUILD_VERSION,

        [Parameter()]
        [System.String]
        $GithubAccessToken = $env:github_access_token,

        [Parameter()]
        [System.String]
        $GitUserEmail = $env:APPVEYOR_REPO_COMMIT_AUTHOR_EMAIL,

        [Parameter()]
        [System.String]
        $GitUserName = $env:APPVEYOR_REPO_COMMIT_AUTHOR
    )

    $ErrorActionPreference = 'Stop'

    $headers = @{
        'Content-type' = 'application/json'
    }

    Write-Verbose -Message $script:localizedData.CreateTempDirMessage
    $path = New-TempFolder

    try
    {
        Write-Verbose -Message $script:localizedData.ConfigGlobalGitMessage
        Invoke-Git -Arguments 'config', '--global', 'core.autocrlf', 'true'

        $wikiRepoName = "https://github.com/$RepoName.wiki.git"
        Write-Verbose -Message ($script:localizedData.CloneWikiGitRepoMessage -f $WikiRepoName)
        Invoke-Git -Arguments 'clone', $wikiRepoName , $path , '--quiet'

        $jobArtifactsUrl = "$appVeyorApiUrl/buildjobs/$JobId/artifacts"
        Write-Verbose -Message ($localizedData.DownloadAppVeyorArtifactDetailsMessage -f $JobId, $jobArtifactsUrl)

        try
        {
            $artifacts = Invoke-RestMethod -Method Get -Uri $jobArtifactsUrl -Headers $headers -Verbose:$false
        }
        catch
        {
            switch (($_ | ConvertFrom-Json).Message)
            {
                'Job not found.'
                {
                    throw ($script:localizedData.NoAppVeyorJobFoundError -f $JobId)
                }

                default
                {
                    throw $_
                }
            }
        }

        $wikiContentArtifact = $artifacts | Where-Object -Property fileName -like "$ResourceModuleName_*_wikicontent.zip"

        if ($null -eq $wikiContentArtifact)
        {
            throw ($LocalizedData.NoWikiContentArtifactError -f $JobId)
        }

        $artifactUrl = "$appVeyorApiUrl/buildjobs/$JobId/artifacts/$($wikiContentArtifact.fileName)"

        Write-Verbose -Message ($localizedData.DownloadAppVeyorWikiContentArtifactMessage -f $artifactUrl)
        $wikiContentArtifactPath = Join-Path -Path $Path -ChildPath $wikiContentArtifact.filename
        Invoke-RestMethod -Method Get -Uri $artifactUrl -OutFile $wikiContentArtifactPath -Headers $headers `
            -Verbose:$false

        Write-Verbose -Message ($localizedData.UnzipWikiContentArtifactMessage -f $wikiContentArtifact.filename)
        Expand-Archive -Path $wikiContentArtifactPath -DestinationPath $path -Force
        Remove-Item -Path $wikiContentArtifactPath

        Set-WikiSidebar -ResourceModuleName $ResourceModuleName -Path $path
        Set-WikiFooter -ResourceModuleName $ResourceModuleName -Path $path
        Copy-WikiFile -MainModulePath $MainModulePath -Path $path -WikiSourceFolder $WikiSourceFolder

        Push-Location
        Set-Location -Path $path

        Write-Verbose -Message $script:localizedData.ConfigLocalGitMessage
        Invoke-Git -Arguments 'config', '--local', 'user.email', $GitUserEmail
        Invoke-Git -Arguments 'config', '--local', 'user.name', $GitUserName
        Invoke-Git -Arguments 'remote', 'set-url' , 'origin' , "https://$($GitUserName):$($GithubAccessToken)@github.com/$RepoName.wiki.git"

        Write-Verbose -Message $localizedData.AddWikiContentToGitRepoMessage
        Invoke-Git -Arguments 'add', '*'

        Write-Verbose -Message ($localizedData.CommitAndTagRepoChangesMessage -f $BuildVersion)
        Invoke-Git -Arguments 'commit', '--message', ($localizedData.UpdateWikiCommitMessage -f $JobId), '--quiet'
        Invoke-Git -Arguments 'tag', '--annotate', $BuildVersion , '--message', $BuildVersion

        Write-Verbose -Message $localizedData.PushUpdatedRepoMessage
        Invoke-Git -Arguments 'push', 'origin', '--quiet'
        Invoke-Git -Arguments 'push', 'origin', $BuildVersion, '--quiet'

        Pop-Location
    }
    finally
    {
        Remove-Item -Path $path -Recurse -Force
        Write-Verbose -Message $localizedData.PublishWikiContentCompleteMessage
    }
}

<#
    .SYNOPSIS
        Invokes the git command.

    .PARAMETER Arguments
        The arguments to pass to the Git executable.

    .EXAMPLE
        Invoke-Git clone https://github.com/X-Guardian/xActiveDirectory.wiki.git --quiet

        Invokes the Git executable to clone the specified repository to the current working directory.
#>

function Invoke-Git
{
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromRemainingArguments = $true)]
        [System.String[]]
        $Arguments
    )

    Write-Debug -Message ($localizedData.InvokingGitMessage -f $Arguments)

    try
    {
        & git.exe @Arguments 2>$null
    }
    catch
    {
        if ($LASTEXITCODE -ne 0)
        {
            throw $_
        }
    }
}

<#
    .SYNOPSIS
        Creates a new temporary folder with a random name.

    .EXAMPLE
        New-TempFolder

        This command creates a new temporary folder with a random name.

    .PARAMETER MaximumRetries
        Specifies the maximum number of time to retry creating the temp folder.

    .OUTPUTS
        System.IO.DirectoryInfo
#>
function New-TempFolder
{
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param (
        [Parameter()]
        [Int]
        $MaximumRetries = 10
    )

    $tempPath = [System.IO.Path]::GetTempPath()

    $retries = 0
    do
    {
        $retries++
        if ($Retries -gt $MaximumRetries)
        {
            throw ($localizedData.NewTempFolderCreationError -f $tempPath)
        }
        $name = [System.IO.Path]::GetRandomFileName()
        $path = New-Item -Path $tempPath -Name $name -ItemType Directory -ErrorAction SilentlyContinue
    }
    while (-not $path)

    return $path
}

<#
    .SYNOPSIS
        Creates the Wiki side bar file from the list of markdown files in the path.

    .PARAMETER ResourceModuleName
        The name of the resource module.

    .PARAMETER Path
        The path of the Wiki page files.

    .EXAMPLE
        Set-WikiSidebar -ResourceModuleName $ResourceModuleName -Path $path

        Creates the Wiki side bar from the list of markdown files in the path.
#>
function Set-WikiSidebar
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceModuleName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    $wikiSideBarFileBaseName = '_Sidebar.md'
    $wikiSideBarFileFullName = Join-Path -Path $path -ChildPath $wikiSideBarFileBaseName

    Write-Verbose -Message ($localizedData.GenerateWikiSidebarMessage -f $wikiSideBarFileBaseName)
    $WikiSidebar = @(
        "# $ResourceModuleName Module"
        ' '
    )

    $wikiFiles = Get-ChildItem -Path $Path -Filter '*.md'

    foreach ($file in $wikiFiles)
    {
        $wikiSidebar += "- [$($file.BaseName)]($($file.BaseName))"
    }

    Out-File -InputObject $wikiSideBar -FilePath $wikiSideBarFileFullName -Encoding ASCII
}

<#
    .SYNOPSIS
        Creates the Wiki footer file if one does not already exist.

    .PARAMETER Path
        The path for the Wiki footer file.

    .EXAMPLE
        Set-WikiFooter -Path $path

        Creates the Wiki footer.
#>
function Set-WikiFooter
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ResourceModuleName,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path
    )

    $wikiFooterFileBaseName = '_Footer.md'
    $wikiFooterFileFullName = Join-Path -Path $path -ChildPath $wikiFooterFileBaseName

    if (-not (Test-Path -Path $wikiFooterFileFullName))
    {
        Write-Verbose -Message ($localizedData.GenerateWikiFooterMessage -f $wikiFooterFileBaseName)
        $wikiFooter = @()

        Out-File -InputObject $wikiFooter -FilePath $wikiFooterFileFullName -Encoding ASCII
    }
}

<#
    .SYNOPSIS
        Copies any Wiki files from the module into the Wiki overwriting any existing files.

    .PARAMETER MainModulePath
        The path of the module.

    .PARAMETER Path
        The destination path for the Wiki files.

    .PARAMETER WikiSourceFolder
        The name of the folder that contains the source Wiki files.

    .EXAMPLE
        Copy-WikiFile -MainModulePath $MainModulePath -Path $path -WikiSourcePath $wikiSourcePath

        Copies any Wiki files from the module into the Wiki.
#>
function Copy-WikiFile
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $MainModulePath,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Path,

        [Parameter(Mandatory = $true)]
        [System.String]
        $WikiSourceFolder
    )

    $wikiSourcePath = Join-Path -Path $MainModulePath -ChildPath $WikiSourceFolder
    Write-Verbose -Message ($localizedData.CopyWikiFilesMessage -f $wikiSourcePath)

    $wikiFiles = Get-ChildItem -Path $wikiSourcePath
    foreach ($file in $wikiFiles)

    {
        Write-Verbose -Message ($localizedData.CopyFileMessage -f $file.name)
        Copy-Item -Path $file.fullname -Destination $Path -Force
    }
}

Export-ModuleMember -Function New-DscResourceWikiSite, Publish-WikiContent
