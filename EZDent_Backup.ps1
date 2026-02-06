param (
    [string]$BackupRoot = "C:\Users\Admin\Documents\EZDent\Backup",
    [switch]$ZipBackup,
    [switch]$Help,
    [string]$FMPath = "C:\Program Files (x86)\VATECH\Common\FM",
    [string]$DataPath = "C:\PostgreSQL\9.2\data"
)

# ---------- Display help if requested
if ($Help.IsPresent) {
    Write-Host "EZDent Backup Script Help"
    Write-Host "========================"
    Write-Host ""
    Write-Host "Parameters:"
    Write-Host "  -BackupRoot <path>  : Optional. Specify custom backup destination."
    Write-Host "                        Default: C:\Users\Admin\Documents\EZDent\Backup"
    Write-Host "  -ZipBackup          : Optional switch. If present, backup will be compressed into a ZIP file."
    Write-Host "                        Default: Not zipped."
    Write-Host "  -Help or -h         : Display this help message."
    Write-Host "  -FMPath <path>      : Optional. Override default FM folder path."
    Write-Host "  -DataPath <path>    : Optional. Override default Data folder path."
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\EZDent_Backup.ps1"
    Write-Host "  .\EZDent_Backup.ps1 -ZipBackup"
    Write-Host "  .\EZDent_Backup.ps1 -BackupRoot D:\Backups\EZDent -ZipBackup -DataPath D:\PostgreSQL\Data"
    Write-Host ""
    exit 0
}

# ---------- Admin check
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "ERROR: This script must be run as Administrator." -ForegroundColor Red
    Pause
    exit 1
}

# ---------- Timestamp
$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# ---------- Paths
$BackupPath = Join-Path $BackupRoot $Timestamp
$ZipPath    = "$BackupPath.zip"

# ---------- EZServer Services
$EzServices = @(
    "EzServer Web",
    "EzServer Updater",
    "EzServer Messenger",
    "EzServer FastCGI",
    "EzServer Echo",
    "EzServer AuthProvider",
    "EzServer LicenseManager"
)

Write-Host "========================================="
Write-Host " EZDent Backup Started: $Timestamp"
Write-Host " Destination: $BackupRoot"
Write-Host " Create ZIP: $($ZipBackup.IsPresent)"
Write-Host "========================================="

# ---------- Track original service state
$ServiceState = @{}
foreach ($svc in $EzServices) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        $ServiceState[$svc] = $service.Status
    }
}

try {
    # ---------- Stop EZServer services
    Write-Host "Stopping EZServer services..."
    foreach ($svc in $EzServices) {
        if ($ServiceState[$svc] -eq 'Running') {
            Write-Host "Stopping $svc..."
            Stop-Service -Name $svc -Force -ErrorAction Stop
        }
    }

    Start-Sleep -Seconds 5

    # ---------- Create backup folders
    Write-Host "Creating backup folders..."
    if (Test-Path $DataPath) {
        New-Item -ItemType Directory -Path "$BackupPath\data" -Force | Out-Null
    }
    if (Test-Path $FMPath) {
        New-Item -ItemType Directory -Path "$BackupPath\FM" -Force | Out-Null
    }

    # ---------- Copy Data folder
    if (Test-Path $DataPath) {
        Write-Host "Copying Data folder..."
        Copy-Item -Path "$DataPath\*" -Destination "$BackupPath\data" -Recurse -Force -ErrorAction Stop
    }
    else {
        Write-Host "Data folder not found at $DataPath, skipping."
    }

    # ---------- Copy FM folder
    if (Test-Path $FMPath) {
        Write-Host "Copying FM files..."
        Copy-Item -Path "$FMPath\*" -Destination "$BackupPath\FM" -Recurse -Force -ErrorAction Stop
    }
    else {
        Write-Host "FM folder not found at $FMPath, skipping."
    }

    # ---------- Optional compression
    if ($ZipBackup.IsPresent) {
        Write-Host "Compressing backup..."
        Compress-Archive -Path $BackupPath -DestinationPath $ZipPath -Force -ErrorAction Stop
        Write-Host "ZIP created: $ZipPath"
    }
    else {
        Write-Host "Skipping ZIP creation as per settings."
    }
}
catch {
    Write-Host "ERROR during backup process!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
    # ---------- Always restart EZServer services
    Write-Host "Restarting EZServer services..."
    foreach ($svc in $EzServices) {
        if ($ServiceState[$svc] -eq 'Running') {
            Write-Host "Starting $svc..."
            Start-Service -Name $svc -ErrorAction SilentlyContinue
        }
    }

    Start-Sleep -Seconds 5

    # ---------- Verify service status
    Write-Host "Service status check:"
    foreach ($svc in $EzServices) {
        $status = (Get-Service -Name $svc -ErrorAction SilentlyContinue).Status
        Write-Host ("{0,-30} : {1}" -f $svc, $status)
    }

    Write-Host "========================================="
    Write-Host " Backup process finished"
    if ($ZipBackup.IsPresent) {
        Write-Host " ZIP file: $ZipPath"
    }
    Write-Host "========================================="
}

Pause
