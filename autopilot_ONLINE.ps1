# Capture the initial working directory
$initialDirectory = Get-Location

# Function to check if the script is running as an Administrator
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
    $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if running as Administrator, otherwise restart the script with administrative rights
if (-NOT (Test-Admin)) {
    $scriptPath = $MyInvocation.MyCommand.Definition
    $encodedPath = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($scriptPath))
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoExit", "-EncodedCommand", $encodedPath
    exit
}

# Set the location to the initial directory
Set-Location -LiteralPath $initialDirectory

# Set execution policy for this process
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

# Install the Get-WindowsAutoPilotInfo script if not already installed
Install-Script -Name Get-WindowsAutoPilotInfo -Force

# Get the serial number of the laptop22
$serialNumber = Get-WmiObject win32_bios | Select-Object -ExpandProperty SerialNumber

# Get the current timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

# Construct the filename
$filename = "$serialNumber" + "_" + "$timestamp.csv"

# Run Get-WindowsAutoPilotInfo.ps1 and output to the constructed filename
Get-WindowsAutoPilotInfo.ps1 -OutputFile $filename

# Function to check for USB drives
function Check-UsbDrives {
    Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 }
}

# Function to show a simple menu for selecting the destination
function Select-Destination {
    Write-Host "Select the destination for the CSV file:"
    Write-Host "1: C:\"
    Write-Host "2: Desktop"

    $usbDrives = Check-UsbDrives
    $driveIndex = 3
    $usbDriveChoices = @{}
    foreach ($drive in $usbDrives) {
        Write-Host ("{0}: {1}\" -f $driveIndex, $drive.DeviceID)
        $usbDriveChoices.Add($driveIndex.ToString(), $drive.DeviceID + "\")
        $driveIndex++
    }

    $choice = Read-Host "Enter your choice"
    if ($choice -eq "1") { return "C:\" }
    if ($choice -eq "2") { return [Environment]::GetFolderPath("Desktop") }
    if ($usbDriveChoices.ContainsKey($choice)) {
        return $usbDriveChoices[$choice]
    } else {
        Write-Host "Invalid choice. Please try again."
        return $null
    }
}

# Ask user to select a destination
$destination = Select-Destination

# Move the CSV file to the selected destination
if ($destination -ne $null) {
    $destinationFile = Join-Path -Path $destination -ChildPath $filename
    Move-Item -Path $filename -Destination $destinationFile
    Write-Host "File moved to $destinationFile"
} else {
    Write-Host "No valid destination selected. File remains in the current location."
}
