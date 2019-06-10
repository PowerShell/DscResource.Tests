# culture="en-US"
ConvertFrom-StringData @'
    CreateTempDirMessage                       = Creating a temporary working directory.
    InitializeGitMessage                       = Initialising Git.
    CloneWikiGitRepoMessage                    = Cloning the Wiki Git Repository '{0}'.
    DownloadAppVeyorArtifactDetailsMessage     = Downloading the Appveyor Artifact Details for job '{0}' from '{1}'.
    DownloadAppVeyorWikiContentArtifactMessage = Downloading the Appveyor WikiContent Artifact '{0}'.
    AddWikiContentToGitRepoMessage             = Adding the Wiki Content to the Git Repository.
    CommitAndTagRepoChangesMessage             = Committing the changes to the Repository and adding build tag '{0}'.
    PushUpdatedRepoMessage                     = Pushing the updated Repository to the Git Wiki.
    PublishWikiContentCompleteMessage          = Publish Wiki Content complete.
    UnzipWikiContentArtifactMessage            = Unzipping the WikiContent Artifact '{0}'.
    UpdateWikiCommitMessage                    = Updating Wiki from AppVeyor Job ID '{0}'.
    NoAppVeyorJobFoundError                    = No AppVeyor Job found with ID '{0}'.
    NoWikiContentArtifactError                 = No Wiki Content artifact found in AppVeyor job id '{0}'.
'@
