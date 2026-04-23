<#
.SYNOPSIS
    Flux Personal Task Tracker - Local web server and data backend
.DESCRIPTION
    Hosts the Flux task tracker on localhost and persists data to a JSON file
    in a folder of your choice. Provides atomic writes, auto-backups, and
    graceful fallback if the folder is unreachable (e.g., network share down).
.NOTES
    Port: 7789 (change below if needed)

    Configure the DataFolder below to point wherever you want your tasks stored:
      - Local folder:      "$env:USERPROFILE\Documents\Flux_Data"
      - Network share:     "\\server\share\Flux_Data"
      - OneDrive/Dropbox:  "$env:USERPROFILE\OneDrive\Flux_Data"

    On first run, the script creates the folder if it doesn't exist and seeds
    a default flux-data.json with "Personal" and "Work" projects.
#>

#region ===== Configuration =====
# EDIT THIS SECTION to customize your Flux install. Only DataFolder usually needs changing.

$Script:Config = @{
    # Port Flux hosts on. Change if 7789 conflicts with something else.
    Port          = 7789

    # Where your tasks are stored. $env:USERPROFILE expands to C:\Users\<YourName>.
    # Change this to any folder path - local, network share, or cloud-synced.
    DataFolder    = "$env:USERPROFILE\Documents\Flux_Data"

    # File and subfolder names inside DataFolder - usually no need to change these.
    DataFile      = "flux-data.json"
    BackupFolder  = "backups"
    LogFile       = "flux.log"

    # How many auto-backups to keep. 10 is a good default.
    MaxBackups    = 10

    # Location of the HTML file (should sit next to this script). Leave as-is.
    HtmlFile      = Join-Path $PSScriptRoot "Flux-Tracker.html"

    # Set to $false if you use the PWA install and don't want a browser tab auto-opening.
    AutoOpenBrowser = $true
}

$Script:DataPath    = Join-Path $Script:Config.DataFolder $Script:Config.DataFile
$Script:BackupPath  = Join-Path $Script:Config.DataFolder $Script:Config.BackupFolder
$Script:LogPath     = Join-Path $Script:Config.DataFolder $Script:Config.LogFile
$Script:NetworkOk   = $true
#endregion

#region ===== Logging =====
function Write-FluxLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        'ERROR' { 'Red' }
        'WARN'  { 'Yellow' }
        'OK'    { 'Green' }
        default { 'Cyan' }
    }
    Write-Host $line -ForegroundColor $color

    if ($Script:NetworkOk) {
        try {
            Add-Content -Path $Script:LogPath -Value $line -ErrorAction Stop
        } catch {
            # Silent fail on log write - data folder may be unavailable
        }
    }
}
#endregion

#region ===== Data Folder Setup =====
function Test-DataFolder {
    try {
        if (-not (Test-Path $Script:Config.DataFolder)) {
            Write-FluxLog "Data folder not found. Attempting to create..." -Level WARN
            New-Item -Path $Script:Config.DataFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-FluxLog "Created data folder: $($Script:Config.DataFolder)" -Level OK
        }
        if (-not (Test-Path $Script:BackupPath)) {
            New-Item -Path $Script:BackupPath -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        $Script:NetworkOk = $true
        return $true
    } catch {
        Write-FluxLog "Cannot access data folder: $_" -Level ERROR
        Write-FluxLog "Falling back to local storage only. Browser localStorage will be used." -Level WARN
        $Script:NetworkOk = $false
        return $false
    }
}

function Initialize-DataFile {
    if (-not $Script:NetworkOk) { return }
    if (-not (Test-Path $Script:DataPath)) {
        $seed = @{
            projects = @(
                @{ id = "p1"; name = "Personal"; color = "#ff5c1a" }
                @{ id = "p2"; name = "Work";     color = "#2b6cb0" }
            )
            tasks    = @()
            tags     = @()
            theme    = "light"
            version  = 1
            createdAt = (Get-Date).ToString('o')
        } | ConvertTo-Json -Depth 10
        Set-Content -Path $Script:DataPath -Value $seed -Encoding UTF8
        Write-FluxLog "Created new data file at $Script:DataPath" -Level OK
    } else {
        Write-FluxLog "Using existing data file: $Script:DataPath" -Level INFO
    }
}
#endregion

#region ===== Data Read / Write =====
function Read-FluxData {
    if (-not $Script:NetworkOk) {
        return '{"error":"network_unavailable"}'
    }
    try {
        $content = Get-Content -Path $Script:DataPath -Raw -Encoding UTF8 -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($content)) {
            return '{"projects":[],"tasks":[],"tags":[]}'
        }
        return $content
    } catch {
        Write-FluxLog "Read failed: $_" -Level ERROR
        return '{"error":"read_failed"}'
    }
}

function Write-FluxData {
    param([Parameter(Mandatory)][string]$JsonContent)

    if (-not $Script:NetworkOk) {
        return @{ success = $false; reason = 'network_unavailable' }
    }

    try {
        # Validate JSON
        $null = $JsonContent | ConvertFrom-Json -ErrorAction Stop

        # Atomic write: write to .tmp then rename
        $tmpPath = "$Script:DataPath.tmp"
        Set-Content -Path $tmpPath -Value $JsonContent -Encoding UTF8 -ErrorAction Stop

        # Backup current file before overwriting
        if (Test-Path $Script:DataPath) {
            $backupName = "flux-data_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmmss')
            $backupFile = Join-Path $Script:BackupPath $backupName
            Copy-Item -Path $Script:DataPath -Destination $backupFile -ErrorAction SilentlyContinue
        }

        # Replace live file
        Move-Item -Path $tmpPath -Destination $Script:DataPath -Force -ErrorAction Stop

        # Rotate backups
        Rotate-Backups

        return @{ success = $true }
    } catch {
        Write-FluxLog "Write failed: $_" -Level ERROR
        return @{ success = $false; reason = "$_" }
    }
}

function Rotate-Backups {
    try {
        $backups = Get-ChildItem -Path $Script:BackupPath -Filter "flux-data_*.json" -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending
        if ($backups.Count -gt $Script:Config.MaxBackups) {
            $backups | Select-Object -Skip $Script:Config.MaxBackups | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    } catch {
        # Silent - backup rotation isn't critical
    }
}
#endregion

#region ===== HTTP Server =====
function Send-Response {
    param(
        $Response,
        [string]$Content,
        [string]$ContentType = 'application/json',
        [int]$StatusCode = 200
    )
    try {
        $Response.StatusCode = $StatusCode
        $Response.ContentType = $ContentType
        $Response.Headers.Add('Cache-Control', 'no-cache, no-store, must-revalidate')
        $Response.Headers.Add('Access-Control-Allow-Origin', '*')
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($Content)
        $Response.ContentLength64 = $buffer.Length
        $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    } catch {
        Write-FluxLog "Response send failed: $_" -Level ERROR
    } finally {
        try { $Response.OutputStream.Close() } catch { }
    }
}

function Start-FluxServer {
    $listener = New-Object System.Net.HttpListener
    $prefix = "http://localhost:$($Script:Config.Port)/"
    $listener.Prefixes.Add($prefix)

    try {
        $listener.Start()
        Write-FluxLog "Flux server listening on $prefix" -Level OK
    } catch {
        Write-FluxLog "Cannot start listener on port $($Script:Config.Port): $_" -Level ERROR
        Write-FluxLog "Is another instance already running? Try: Get-Process | Where-Object { `$_.Name -like '*powershell*' }" -Level WARN
        Read-Host "Press Enter to exit"
        exit 1
    }

    # Open browser
    if ($Script:Config.AutoOpenBrowser) {
        Start-Sleep -Milliseconds 400
        try {
            Start-Process $prefix
            Write-FluxLog "Opened browser at $prefix" -Level INFO
        } catch {
            Write-FluxLog "Could not auto-open browser. Navigate to $prefix manually." -Level WARN
        }
    }

    Write-Host ""
    Write-Host "  Flux is running. Close this window to stop the server." -ForegroundColor Green
    Write-Host "  Data file: $Script:DataPath" -ForegroundColor Gray
    Write-Host ""

    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request  = $context.Request
            $response = $context.Response
            $path     = $request.Url.AbsolutePath.TrimEnd('/')
            $method   = $request.HttpMethod

            try {
                switch -Regex ("$method $path") {

                    '^GET $|^GET /index\.html$' {
                        if (Test-Path $Script:Config.HtmlFile) {
                            $html = Get-Content -Path $Script:Config.HtmlFile -Raw -Encoding UTF8
                            Send-Response -Response $response -Content $html -ContentType 'text/html; charset=utf-8'
                        } else {
                            Send-Response -Response $response -Content "<h1>Flux-Tracker.html not found</h1><p>Expected at: $($Script:Config.HtmlFile)</p>" -ContentType 'text/html' -StatusCode 404
                        }
                        break
                    }

                    '^GET /api/data$' {
                        $data = Read-FluxData
                        Send-Response -Response $response -Content $data
                        break
                    }

                    '^POST /api/data$' {
                        $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
                        $body = $reader.ReadToEnd()
                        $reader.Close()
                        $result = Write-FluxData -JsonContent $body
                        Send-Response -Response $response -Content ($result | ConvertTo-Json -Compress)
                        break
                    }

                    '^GET /api/status$' {
                        $status = @{
                            network = $Script:NetworkOk
                            dataPath = $Script:DataPath
                            version = "1.0"
                        } | ConvertTo-Json -Compress
                        Send-Response -Response $response -Content $status
                        break
                    }

                    '^OPTIONS' {
                        $response.Headers.Add('Access-Control-Allow-Methods','GET, POST, OPTIONS')
                        $response.Headers.Add('Access-Control-Allow-Headers','Content-Type')
                        Send-Response -Response $response -Content '' -StatusCode 204
                        break
                    }

                    default {
                        Send-Response -Response $response -Content '{"error":"not_found"}' -StatusCode 404
                    }
                }
            } catch {
                Write-FluxLog "Request handler error: $_" -Level ERROR
                try { Send-Response -Response $response -Content '{"error":"server_error"}' -StatusCode 500 } catch {}
            }
        }
    } finally {
        if ($listener.IsListening) { $listener.Stop() }
        $listener.Close()
        Write-FluxLog "Server stopped." -Level INFO
    }
}
#endregion

#region ===== Scheduled Task Management =====
function Register-FluxStartupTask {
    $taskName = "FluxTaskTracker-AutoStart"
    $vbsPath  = Join-Path $PSScriptRoot "Flux.vbs"

    if (-not (Test-Path $vbsPath)) {
        Write-FluxLog "Flux.vbs not found at $vbsPath. Skipping scheduled task registration." -Level WARN
        return
    }

    try {
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-FluxLog "Scheduled task '$taskName' already exists." -Level INFO
            return
        }

        $action    = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`""
        $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
        $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive

        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Auto-starts Flux Task Tracker on login" -Force | Out-Null
        Write-FluxLog "Registered scheduled task '$taskName' to run at login." -Level OK
    } catch {
        Write-FluxLog "Failed to register scheduled task: $_" -Level WARN
        Write-FluxLog "You can still launch Flux manually via Flux.vbs." -Level INFO
    }
}
#endregion

#region ===== Main =====
function Main {
    Write-Host ""
    Write-Host "  ================================" -ForegroundColor DarkGray
    Write-Host "   Flux Personal Task Tracker" -ForegroundColor White
    Write-Host "   Starting up..." -ForegroundColor Gray
    Write-Host "  ================================" -ForegroundColor DarkGray
    Write-Host ""

    $folderReady = Test-DataFolder
    if ($folderReady) {
        Initialize-DataFile
        Write-FluxLog "Data folder: $($Script:Config.DataFolder)" -Level INFO
    }

    # Register startup task (first run only)
    Register-FluxStartupTask

    Start-FluxServer
}

Main
#endregion
