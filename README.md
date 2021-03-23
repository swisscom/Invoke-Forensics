# Forensic helper scripts for KAPE and RegRipper

If you use KAPE or RegRipper for forensic analysis, then Invoke-Forensics could help you by providing PowerShell commands to simplify working with these tools. They speed up your work when
* you deal with multiple evidence files in that commands are provided for
    unzipping and mounting VHDX images and run KAPE against them or let you
    getting files from them.
* you are tired of searching for the correct name to provide to these tools in
  that the commands have tab-completion support which lets you quickly find
  available [RegRipper](https://github.com/keydet89/RegRipper3.0)
  [plugins](https://github.com/keydet89/RegRipper3.0/tree/master/plugins) or
  [KAPE](https://www.kroll.com/en/services/cyber-risk/incident-response-litigation-support/kroll-artifact-parser-extractor-kape)'s
  [targets and modules
  (KapeFiles)](https://github.com/EricZimmerman/KapeFiles) ("how was that
  module name again?"), run them or let you show the content of the files for
  inspection
* you need to search for specific KAPE files based on a given filter ("Is
  there already a powershell console target available?")

***
<!-- vim-markdown-toc GFM -->

* [What exactly do these scripts provide?](#what-exactly-do-these-scripts-provide)
* [Requirements](#requirements)
* [Functions](#functions)
* [Usage](#usage)
    * [Invoke-Kape](#invoke-kape)
    * [Invoke-KapeOnMultipleImages](#invoke-kapeonmultipleimages)
    * [Invoke-KapeFileCollection](#invoke-kapefilecollection)
    * [Search-KapeFile](#search-kapefile)
    * [Invoke-KapeUnpack](#invoke-kapeunpack)
    * [Mount-VHDX](#mount-vhdx)
    * [Remove-VHDX](#remove-vhdx)
    * [Invoke-RegRipper](#invoke-regripper)
* [Tips & Tricks](#tips--tricks)
* [Changelog](#changelog)
    * [[Unreleased]](#unreleased)
    * [[0.1.0] - 2021-03-22](#010---2021-03-22)

<!-- vim-markdown-toc -->
***

## What exactly do these scripts provide?

The main advantage using the scripts is that they allow running KAPE against
or collecting files from multiple collected KAPE images in one command which
includes unzipping, mounting the VHDX and running the command (KAPE itself or
file copy) against the corresponding drive letter and unmounting the VHDX image
again. Using these function against multiple collections reduce the time
severely compared to running these commands manually.

The other purpose of the scripts is to quickly jump through the available
plugins or KAPE files using the tab-completion support and to be able to print
the content of the files to inspect those directly in the shell.

Important note: These scripts do only provide a subset of KAPE's and
RegRippers arguments. For more specific needs use the binaries directly to be
able to use all the available options, make a [pull
request](https://github.com/swisscom/Invoke-Forensics/pulls) or file an
[issue](https://github.com/swisscom/Invoke-Forensics/issues) to request the
inclusion of further arguments.

The wrapper scripts provide:
* **Tab-completion support for plugin and artifact names** which helps finding
    them without the need to navigate into subfolders.
* **Run KAPE against one or multiple evidence ZIP files or VHDX images** which
    includes unzipping evidence ZIP files, mounting VHDX images and run KAPE
    with given modules against those (`Invoke-KapeOnMultipleImages`).
* **Copy files from one or multiple evidence ZIP files or VHDX images** which
    includes unzipping evidence ZIP files, mounting VHDX images and run a
    copy command with a given (regex) pattern against those
    (`Invoke-KapeFileCollection`).
* **Run one or multiple RegRipper plugins or profiles against a given hive**.
    RegRipper only allows using one plugin or a profile per execution, but not
    multiple plugins in one command outside of profiles (`Invoke-RegRipper`).
* **Search for KAPE files based on keywords in a KAPE field (e.g. Description,
    FileMask, ...) or the whole file** and print either a short list with the
    name and the location, the file content or a file listing for further
    processing in PowerShell (`Search-KapeFile`).
* **Printing the content of plugins or artifact files** without the need for
    navigating into subfolders (Invoke-Kape*, Search-KapeFile and
    Invoke-RegRipper functions using `-Print`).
* **Mounting VHDX files and return drive letter**
* **Handling unpacking** of evidence ZIP files and VHDX ZIP
    file in target folder in one command.

## Requirements

Unzip program from e.g. Git for Windows found in the path. The Expand-Archive
PowerShell command fail when extracting the VHDX ZIP files.

For mounting VHDX images install the required PowerShell module. Native
PowerShell command `Mount-DiskImage` is used within the provided `Mount-VHDX`.
The advantage of `Mount-VHDX` over `Mount-DiskImage` is that it returns the
used drive letter.

``` PowerShell
PS> Enable-WindowsOptionalFeature -FeatureName "Hyper-V Module for Windows PowerShell"
```

## Functions

* Invoke-Kape - _Run KAPE with given targets or modules_
* Invoke-KapeOnMultipleImages - _Run KAPE against multiple VHDX containers,
    including unzipping evidence ZIP and VHDX zip and mounting VHDX files first_
* Invoke-KapeFileCollection - _Collect files based on a given pattern from VHDX containers_
* Search-KapeFile - _Search for KAPE files based on either a pattern in a field or in the whole file_
* Invoke-KapeUnpack - _Unpack KAPE evidence ZIP and included VHDX zip file_
* Mount-VHDX - _Mount VHDX container and return drive letter_
* Remove-VHDX - _Remove VHDX files from given path and all its subfolders_
* Invoke-RegRipper - _Run one or more RegRipper plugins against a hive_

## Usage

1. Navigate into KAPE or RegRipper folder
2. Load scripts into PowerShell
    ``` powershell
    # Load both RegRipper and KAPE functions
    . .\Invoke-Forensics\Invoke-Forensic.ps1
    # Load KAPE functions
    . .\Invoke-Forensics\Invoke-Kape.ps1
    # Load RegRipper functions
    . .\Invoke-Forensics\Invoke-RegRipper.ps1
    ```
3. Run commands, see below

### Invoke-Kape

_Change into KAPE's directory first._

Run a KAPE command or show the content of a target or module file. The target and module parameters have tab-completion support.

``` powershell
# List all targets which starts with an 'a' in the name and print the one which was choosen
Invoke-Kape -Target a<ctrl-space> -Print

# Jump through all targets which starts with an 'a' in the name and print the content
Invoke-Kape -Print -Target a<tab>

# Example for printing amcache target
PS> Invoke-Kape -Target Amcache -print
Description: Amcache.hve
Author: Eric Zimmerman
Version: 1.0
Id: 13ba1e33-4899-4843-adf1-c7e6b20d759a
RecreateDirectories: true
...

# Jump through all remaining modules besides AmcacheParser and print the selected
Invoke-Kape -Print -Target Amcache -Module AmcacheParser,<tab>

# Invoke KAPE using the target Amcache
Invoke-Kape -tsource C: -tdest C:\temp\ -Target Amcache

# Invoke KAPE using the module AmcacheParser
Invoke-Kape -msource C:\temp -mdest C:\temp\ -Module AmcacheParser

# Invoke KAPE using two modules
invoke-kape -msource C:\WindowsTimelineTest -mdest C:\WindowsTimelineTestTemp -Module SQLECmd,WxTCmd
```

### Invoke-KapeOnMultipleImages

_Change into KAPE's directory first._

The function provides the following:
* Unpacks all KAPE evidence zip files (unless `-SkipUnzip` or `-SkipUnzipEvidenceZip` is given)
* Unpacks all VHDX zip files found in the target output folder (`-TOutPattern`) (unless `-SkipUnzip` is given)
* Extracts the hostname from the path to use it in KAPE commands and for output folder name
* Loop over all VHDX files
  * Mounts VHDX file and provide the drive letter to the KAPE command
  * Run KAPE with the given modules (`-Module` has tab-completion support for module names)
  * Unmounts the VHDX file

Sample directory and file structure:
* C:\evidence-folder\
  * server1-evidence.zip
     * include mout and tout folders
     * tout includes the VHDX ZIP
  * server2-evidence.zip

``` powershell
PS> $zip="C:\evidence-folder\"
PS> $tout="*\tout"
PS> $dest="C:\kape-parsing-output"
PS> $serverPattern="\\(\w*)-evidence"
PS> $modules=@("JLECmd","LECmd")
PS> Invoke-KapeOnMultipleImages -KapeEvidenceFolder $zip -TOut $tout -Destination $dest -HostnamePattern $serverPattern -Module $modules -SkipUnzip
```

### Invoke-KapeFileCollection

_Change into KAPE's directory first._

The function copies files based on a pattern (`-FileNamePattern`) from the
mounted VHDX image into a destination directory. This can be used if you need
to extract a given file from an KAPE image.

The function provides the following:
* Unpacks all KAPE evidence zip files (unless `-SkipUnzip` or `-SkipUnzipEvidenceZip` is given)
* Unpacks all VHDX zip files found in the target output folder (`-TOutPattern`) (unless `-SkipUnzip` is given)
* Loop over all VHDX files
  * Mounts VHDX file and provide the drive letter to the copy command
  * Copy given files based on filename pattern into destination directory.
    The source directory is replicated in the destination directory
  * Unmounts the VHDX file

``` powershell
# Unzip evidence zip file, navigate into new subfolders, unzip VHDX ZIP files, mount VHDX images and collect files into destination directory
PS> Invoke-KapeFileCollection -KapeEvidenceFolder C:\kape-output\ -TOutPattern *\tout -Destination C:\kape-output\fs -HostnamePattern "\\(\w*)-evidence" -FileNamePattern "*console*history*"

# Skip unzipping of evidence zip file, just navigate into already unzipped envidence subfolders, mount VHDX images and collect files into destination directory
PS> Invoke-KapeFileCollection -KapeEvidenceFolder C:\kape-output\ -TOutPattern *\tout -Destination C:\kape-output\fs -HostnamePattern "\\(\w*)-evidence" -FileNamePattern "*console*history*" -SkipUnzip
```

### Search-KapeFile

Search through all module and target files, either by pattern in a specific
field or the whole file.

Basic usage, there is a generic `-Filter` parameter to search the whole file
for a keyword or more specific filters, like `-FilterDescription`,
`-FilterFileMask`, ...

If you would like to print the found files use `-Print`.

Use `-MatchAllOfThem` to match all of the given filters.

``` powershell
# Search for powershell in description field or history in the file mask field and use a short list as output.
PS> Search-KapeFile -FilterDescription powershell -FilterFileMask history -ShortList
!SANS_Triage.tkape .\Targets\Compound\!SANS_Triage.tkape
Chrome.tkape .\Targets\Browsers\Chrome.tkape
CombinedLogs.tkape .\Targets\Compound\CombinedLogs.tkape
Debian.tkape .\Targets\WSL\Debian.tkape
...

# Print the content of the found KAPE files
PS> Search-KapeFile -FilterDescription powershell -FilterPath psreadline  -MatchAllOfThem -Print

# Search for powershell in description field or history in the file mask field and return file listing object.
PS> Search-KapeFile -FilterDescription powershell -FilterFileMask history

Name                                        FullName
----                                        --------
PowerShellOperationalFullEventLogView.mkape C:\KAPE\Modules\Eve...
PowerShell5SecondPause.mkape                C:\KAPE\Modules\Mis...
DoubleCommander.tkape                       C:\KAPE\Targets\App...
Dropbox.tkape                               C:\KAPE\Targets\App...
...

# Post processing search by using native PowerShell
PS> Search-KapeFile -FilterDescription powershell -FilterFileMask history | select name
...

# Search for a KAPE file which matches all of the provided patterns.
PS> Search-KapeFile -FilterDescription powershell -FilterFileMask history -MatchAllOfThem

# Other searches to limit the scope
PS> Search-KapeFile -FilterDescription powershell -OnlyTargets
PS> Search-KapeFile -FilterPath psreadline -OnlyModules
PS> Search-KapeFile -FilterDescription mozilla -FilterPath thunderbird -OnlyTargets -MatchAllOfThem -ShortList
Thunderbird.tkape .\Targets\Apps\Thunderbird.tkape
```

### Invoke-KapeUnpack

Unzip evidence output ZIP file and then unzip the VHDX zip file inside the targets folder.

``` powershell
PS> Invoke-KapeUnpack -Path C:\kape-files\ -TOutPattern *\tout -Verbose
PS> Invoke-KapeUnpack -Path C:\kape-files\ -TOutPattern *\tout -Verbose -SkipUnzipEvidenceZip
```

### Mount-VHDX

Mount the given image and provide the used drive letter. The native mount command
doesn't provide the drive letter, therefore we use `Get-Volume` before and
after and diff the used drive letters on the system to see which was given to
our VHDX image.

``` powershell
PS> Mount-VHDX -VHDXFile C:\kape-files\server\tout\2021-03-11T152024_server_20210311T152024.vhdx
PS> Mount-VHDX -VHDXFile C:\kape-files\server\tout\2021-03-11T152024_server_20210311T152024.vhdx -verbose
```

### Remove-VHDX

Remove VHDX files recursively.

``` powershell
Remove-VHDX C:\kape-files
```

### Invoke-RegRipper

_Change into RegRipper's directory first._

Run a RegRipper plugin or profile against a hive.

``` powershell
# Print plugin content
PS> Invoke-RegRipper -Hive E:\C\Windows\System32\config\SOFTWARE -Plugin appcertdlls -Print
appcertdlls
#-----------------------------------------------------------
# appcertdlls.pl
#
# History:
#  20200427 - updated output date format
#  20120912 - created

# Print multiple plugins
PS> Invoke-RegRipper -Hive E:\C\Windows\System32\config\SOFTWARE -Plugin appcertdlls,clsid -Print

# Invoke RegRipper with given plugin
PS> Invoke-RegRipper -Hive E:\C\Windows\System32\config\SOFTWARE -Plugin app<tab>
PS> Invoke-RegRipper -Hive E:\C\Windows\System32\config\SOFTWARE -Plugin appcertdlls

# Run multiple plugins after each other
PS> Invoke-RegRipper -Hive E:\C\Windows\System32\config\SOFTWARE -Plugin appcertdlls,clsid

# list all plugins
PS> Invoke-RegRipper -Hive E:\C\Windows\System32\config\SOFTWARE -Plugin <ctrl-space>
adobe                   cached                  gpohist                 ...
allowedenum             cached_tln              gpohist_tln             ...
amcache                 calibrator              heap                    ...
amcache_tln             clsid                   heidisql                ...
...
```

## Tips & Tricks

If you work with [Vim](https://www.vim.org) and would like to use folding for RegRipper output, use the following [snippet](https://gist.github.com/Karneades/3d6643abf72a6a8731385e57d6ce9262) in your vimrc. Use `:RRFolding` to enable plugin folding

``` vimscript
" folds on <pluginname> v.XXXXXX
func! SetRegRipper()
   setlocal foldexpr=getline(v:lnum)=~\'^\\w\\+.*\\sv\\.'?'>1':'='
   setlocal foldmethod=expr
endfunc
command! RRFolding :call SetRegRipper()
```

If you would like to get crazy, put that autocmd in your vimrc to activate
folding for filenames containing "regripper".

```
au BufRead,BufNewFile * if (expand('<afile>') =~ 'regripper') | call SetRegRipper() | endif
```

## Changelog

The format is based on [Keep a Changelog](http://kgbeepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

### [Unreleased]
<!--

**Added**

**Changed**

**Fixed**

**Security**

**Deprecated**

**Removed**
-->

### [0.1.0] - 2021-03-22

**Added**

* Add initial version of the helper scripts, allow working with evidence ZIP
   files, VHDX images, running KAPE against multiple ZIP or VHDX files, search
   for targets or modules using different filters, run RegRipper commands, all
   the commands support tab-completion for RegRipper's plugins and KAPE's
   targets and modules.
