# Script will backup computer to current folder

$include = 'C:'

# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
 
# Get the security principal for the Administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
 
# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole)) {
   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
}
else {
   # We are not running "as Administrator" - so relaunch as administrator
   
   # Create a new process object that starts PowerShell
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
   
   # Specify the current script path and name as a parameter
   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
   
   # Indicate that the process should be elevated
   $newProcess.Verb = "runas";
   
   # Start the new process
   [System.Diagnostics.Process]::Start($newProcess);
   # Exit from the current, unelevated, process
   exit
}
 
# From this point running Backup in Elevated mode

# Creating backup target as UNC path if started from disk
$invocation = (Get-Variable MyInvocation).Value
$directorypath = Split-Path $invocation.MyCommand.Path
if (!($directorypath.StartsWith("\\"))) {
    $backuptarget = ("\\$env:computername\" + $directorypath.replace(":","$"))
}
else {
    $backuptarget = $directorypath
}

$date = get-date -UFormat %Y-%m-%d
$comp = gc env:computername
$user = gc env:username
$log = $backuptarget + '\' + $date + '_' + $comp + '.log'
$result = ""

# Create log file
try {
    if (!(Test-Path $log)) {
        New-Item -Path $log -ItemType File -ErrorAction Stop
    }
}
catch [exception] {
    $result = $result + "Computer $comp FAILED to create log file `r`n"
}

# Backup PC
$start = Get-Date
"Running backup."
"Started: $start"
$process = Start-Process -Wait wbadmin.exe -ArgumentList "start backup -backuptarget:$backuptarget -allCritical -include:$include -quiet" -PassThru -NoNewWindow -RedirectStandardOutput $log
$code = $process.exitcode 
$end = Get-Date
"Ended: $end"

if ($code -eq 0 ) {
    $result = $result + "Backup COMPLETE on $comp, user $user `r`n"
    $result
    $status = "GOOD"
}
else { 
    $result = $result + "Backup FAILED on $comp, user $user `r`n"
    $result
    $status = "BAD" 
}

$result = $result + "Started: $start `r`nEnded: $end `r`n"
Out-File -Append -FilePath $log -InputObject $result -Encoding ascii

# $loghtmlfile = $log + '.html'
# $File = Get-Content $log
# $FileLine = @()
# Foreach ($Line in $File) {
#     $MyObject = New-Object -TypeName PSObject
#     Add-Member -InputObject $MyObject -Type NoteProperty -Name backupstatus -Value $Line
#     $FileLine += $MyObject
# }
# $FileLine | ConvertTo-Html -Property backupstatus | Out-File $loghtmlfile
# $loghtml = gc $loghtmlfile