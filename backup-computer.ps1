# Script will backup computer to current folder

$include = 'C:'

function Write-LogFile([string]$logFileName) {
    Process {
        $_
        $dt = Get-Date -UFormat "%Y-%m-%d %H:%M:%S"
        $str = $dt + " " + $_
        $str | Out-File -FilePath $logFileName -Append -Encoding ascii
    }
}

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
$logName = $backuptarget + '\' + $date + '_' + $comp + '.log'
$result = ""

# Create log file
try {
    if (!(Test-Path $logName)) {
        New-Item -Path $logName -ItemType File -ErrorAction Stop
    }
}
catch [exception] {
    $output = $output + ("Computer $comp FAILED to create log file" | Write-LogFile $logName) + "`r`n"
}

# Backup PC
$start = Get-Date
"Backup started: $start"
$output = $output + ("====================================" | Write-LogFile $logName) + "`r`n"
$output = $output + ("Backup started: $start" | Write-LogFile $logName) + "`r`n"

$wbprocinfo = New-object System.Diagnostics.ProcessStartInfo 
$wbprocinfo.CreateNoWindow = $true 
$wbprocinfo.UseShellExecute = $false 
$wbprocinfo.RedirectStandardOutput = $true 
$wbprocinfo.RedirectStandardError = $true 
$wbprocinfo.FileName = 'wbadmin.exe' 
$wbprocinfo.Arguments = @("start backup -backuptarget:$backuptarget -allCritical -include:$include -quiet") 
$wbprocess = New-Object System.Diagnostics.Process 
$wbprocess.StartInfo = $wbprocinfo
[void]$wbprocess.Start()

$operation = "Processing..."
$percent = "0"
$line = ""
while (!($wbprocess.StandardOutput.EndOfStream)) {
  $line = $wbprocess.StandardOutput.ReadLine()
  if ($line) { $operation = $line }
  $matchPercent = $line -match "\d+(?=\%)"
  if ($matchPercent) { $percent = $Matches[0] }
  Write-Progress -Activity "Backing up computer $comp" `
                 -Status "$operation" `
                 -PercentComplete $percent `
                 -CurrentOperation "$percent% complete"
  $output = $output + ($line | Write-LogFile $logName) + "`r`n"
}

$code = $wbprocess.ExitCode 
$end = Get-Date
# "Backup ended: $end `r`n"
$output = $output + ("Backup ended: $end" | Write-LogFile $logName) + "`r`n"

if ($code -eq 0 ) {
    $output = $output + ("Backup COMPLETE on $comp, user $user" | Write-LogFile $logName) + "`r`n"
    $status = "GOOD"
}
else { 
    $output = $output + ("Backup FAILED on $comp, user $user" | Write-LogFile $logName) + "`r`n"
    $status = "BAD" 
}

$output = $output + ($result | Write-LogFile $logName) + "`r`n"
$output = $output + ("====================================" | Write-LogFile $logName) + "`r`n"
