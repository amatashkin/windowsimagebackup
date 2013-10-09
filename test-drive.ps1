$invocation = (Get-Variable MyInvocation).Value
$directorypath = Split-Path $invocation.MyCommand.Path
"Path:"
$directorypath
# $backuptarget = ("\\localhost\" + $directorypath.replace(":","$"))
# $backuptarget

if ($directorypath.StartsWith("\\")) { "Network!!! by name" } 
else {
    $backuptarget = ("\\$env:computername\" + $directorypath.replace(":","$"))
    "Creating backup target link:"
    $backuptarget
    Test-Path $backuptarget
    # $location = New-Object System.IO.DriveInfo($directorypath)
    # switch ($location.DriveType)
    #     {
    #         "Fixed" { "Fixed!!!"}
    #         "Network" { "Network!!!"}
    #         default {"Can't detect drive type"}
    #     }
}

pause