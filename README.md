# DscResource.Tests
Common meta tests for PowerShell DSC resources repositories.

## Goals

1. Consistency in encoding and indentations. 
Consistency is good by itself. But more important it allows us to:
2. Avoid big diffs with cosmetic changes in Pull Requests. 
Cosmetic changes (like formatting) make reviews harder.
If you want to include formatting changes (like replacing `"` by `'`), 
please make it a **separate commit**. 
This will give reviewers an option to review meaningful changes separately from formatting changes.

## Git and Unicode

By default git treats [unicode files as binary files](http://stackoverflow.com/questions/6855712/why-does-git-treat-this-text-file-as-a-binary-file).
You may not notice it if your client (like VS or GitHub for Windows) takes care of such convertion. 
History with Unicode files is hardly usable from command line `git`.

```
> git diff
 diff --git a/xActiveDirectory.psd1 b/xActiveDirectory.psd1
 index 0fc1914..55fdb85 100644
Binary files a/xActiveDirectory.psd1 and b/xActiveDirectory.psd1 differ
```

With forced `--text` option it would look like this:

```
> git diff --text
 diff --git a/xActiveDirectory.psd1 b/xActiveDirectory.psd1
 index 0fc1914..55fdb85 100644
 --- a/xActiveDirectory.psd1
 +++ b/xActiveDirectory.psd1
@@ -30,4 +30,4 @@
   C m d l e t s T o E x p o r t   =   ' * ' 
  
   } 
  
   
  
 - 
 \ No newline at end of file
 + #   h e l l o 
 \ No newline at end of file
```

Command line `git` version is a core component and should be used as a common denamenator.

## Fixers

We are trying to provide automatic fixers where it's appropriate. 
A fixer corresponds to a particular test.

For example, if `Files encoding` test from [Meta.Tests.ps1](Meta.Tests.ps1) test fails, 
you should be able to run `ConvertTo-UTF8` fixer from [MetaFixers.psm1](MetaFixers.psm1).
