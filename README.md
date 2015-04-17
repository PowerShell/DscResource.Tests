# DscResource.Tests
Common meta tests for PowerShell DSC resources repositories.

## Goals

1. Consistency in encoding and indentations. 
Consistency is good by itself. But more importent it allows us to:
2. Avoid big diffs with cosmetic changes in Pull Requests. 
Cosmetic changes (like formatting) make reviews harder.
If you want to include formatting changes (like replacing `"` by `'`), 
please make it a **separate commit**. 
Reviewers would have an option to review meanful changes separately from formatting.

## Fixers

We are trying to provide automatic fixers, where it's appropriate. 
A fixer corresponds to a particular test.

For example, if `Files encoding` test from [Meta.Tests.ps1](Meta.Tests.ps1) test fails, 
you should be able to run `ConvertTo-UTF8` fixer from [MetaFixers.psm1](MetaFixers.psm1).
