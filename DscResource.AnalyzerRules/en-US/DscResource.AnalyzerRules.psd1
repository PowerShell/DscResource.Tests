ConvertFrom-StringData @'
# English strings
ParameterBlockParameterAttributeMissing    = A [Parameter()] attribute must be the first attribute of each parameter and be on its own line. See https://github.com/PowerShell/DscResources/blob/master/StyleGuidelines.md#correct-format-for-parameter-block
ParameterBlockParameterAttributeLowerCase  = The [Parameter()] attribute must start with an upper case 'P'. See https://github.com/PowerShell/DscResources/blob/master/StyleGuidelines.md#correct-format-for-parameter-block
ParameterBlockParameterAttributeWrongPlace = The [Parameter()] attribute must be the first attribute of each parameter. See https://github.com/PowerShell/DscResources/blob/master/StyleGuidelines.md#correct-format-for-parameter-block
ParameterBlockParameterMandatoryAttributeWrongFormat = Mandatory parameters must use the correct format [Parameter(Mandatory = $true)] for the mandatory attribute. See https://github.com/PowerShell/DscResources/blob/master/StyleGuidelines.md#correct-format-for-parameter-block
ParameterBlockNonMandatoryParameterMandatoryAttributeWrongFormat = Non-mandatory parameters must use the correct format [Parameter()] for the parameter attribute. See https://github.com/PowerShell/DscResources/blob/master/StyleGuidelines.md#correct-format-for-parameter-block
'@
