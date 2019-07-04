ConvertFrom-StringData @'
# English strings
CannotPublish                     = Cannot publish to PowerShell Gallery.
FoundApiKey                       = Found API key to use for publishing to the PowerShell Gallery.
MissingApiKey                     = Missing API key in $env:gallery_api.
EvaluatingExamples                = Evaluating examples that end with 'Config' if they need publishing.
NotOnMasterBranch                 = Not running against the branch 'master'. Will run Publish-Script with parameter WhatIf.
MissingExampleValidationOptIn     = Examples will not publish unless repository has opt-in for example validation. To opt-in, create a '.MetaTestOptIn.json' at the root of the repo in the following format: ["{0}"]
SkipPublish                       = Skipping publishing example '{0}'.
TestScriptFileInfoError           = Error testing example '{0}'. {1}.
ScriptParseError                  = The example could not be read, for example if there is a required module missing when the script should be parsed, or general script parsing errors. General errors should have been caught with the common example validation test. Error: {0}
MissingMetadata                   = The example has not opt-in by adding script metadata to the example. Error: {0}
MissingRequiredMetadataProperties = The example is missing needed metadata properties. This can also happen if code is checked out with just LF instead of CRLF (make sure core.autocrlf is set to true). Error: {0}
InvalidGuid                       = The example has an invalid GUID. The format must be [XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX] where X is a hex digit (0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F). Error: {0}
ConfigurationNameMismatch         = The configuration name and the file name are not the same, or the name does not contain only letters, numbers, and underscores. The name must also start with a letter, and it must end with a letter or a number.
AddingExampleToBePublished        = Adding the example '{0}' to the list to be published.
DuplicateGuid                     = Skipping examples that was found having the same GUID. Duplicate examples: '{0}'.
ExampleIsAlreadyPublished         = The example '{0}' is already published (same version).
PublishExample                    = The example '{0}' with version '{1}' is being published as '{2}'.
'@
