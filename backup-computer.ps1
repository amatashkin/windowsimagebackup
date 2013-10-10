# Script will backup computer to current folder

$include = ''

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
    # $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    clear-host
}
else {
    # We are not running "as Administrator" - so relaunch as administrator

    # Create a new process object that starts PowerShell
    $newProcess = new-object System.Diagnostics.ProcessStartInfo
    $newProcess.FileName = 'powershell.exe'

    # Specify the current script path and name as a parameter
    $newProcess.Arguments = $myInvocation.MyCommand.Definition

    # Indicate that the process should be elevated
    $newProcess.Verb = "runas"

    # Start the new process
    [System.Diagnostics.Process]::Start($newProcess)
    # Exit from the current, unelevated, process
    exit
}
 
# From this point running Backup in Elevated mode
# Set variables
$date = get-date -UFormat %Y-%m-%d
$comp = gc env:computername
$user = gc env:username

# Set include parameter if assigned 
if ($include) {$include = "-include:$include"}

# Get current directory
$invocation = (Get-Variable MyInvocation).Value
$directorypath = Split-Path $invocation.MyCommand.Path
$logName = Join-Path $directorypath ($date + '_' + $comp + '.log')

# Create log file
try {
    if (!(Test-Path $logName)) {
        New-Item -Path $logName -ItemType File -ErrorAction Stop | Out-Null
        $output = $output + ("Created log file $logName" | Write-LogFile $logName) + "`r`n"
    }
}
catch [exception] {
    $output = $output + ("Computer $comp FAILED to create log file" | Write-LogFile $logName) + "`r`n"
}

# Check directory and set BackupTarget.
# UNC if running from network, Drive letter if from localdisk.
$directory = Split-Path $directorypath -Leaf
if (($directory) -ne "WindowsImageBackup") {
    "Backup FAILED. Script must be started from WindowsImageBackup folder." | Write-LogFile $logName
    exit 10
}
if (!($directorypath.StartsWith("\\"))) {
    $backuptarget = Split-Path $directorypath -Qualifier
}
else {
    $backuptarget = Split-Path $directorypath -Parent
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
$wbprocinfo.Arguments = @("start backup -backuptarget:$backuptarget -allCritical $include -quiet") 
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
  Write-Progress -Activity "Backing up computer $comp to $directorypath" `
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

$output = $output + ("====================================" | Write-LogFile $logName) + "`r`n"
