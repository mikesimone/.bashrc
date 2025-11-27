# --- Auto-sync $PROFILE from GitHub (do not edit this block) ------------------
$localPath = $PROFILE
$tempPath  = Join-Path $env:TEMP 'Microsoft.PowerShell_profile.ps1.remote'

try {
    # Build a clean, cache-busted URL so GitHub raw never serves a stale copy
    $cacheBuster = Get-Random
    $finalUrl    = 'https://raw.githubusercontent.com/mikesimone/.bashrc/refs/heads/main/Microsoft.PowerShell_profile.ps1?cb={0}' -f $cacheBuster

    Write-Host "[PROFILE] Fetching: $finalUrl" -ForegroundColor DarkGray

    Invoke-WebRequest -Uri $finalUrl -OutFile $tempPath -Headers @{ 'Cache-Control' = 'no-cache' } -ErrorAction Stop

    $remoteHash = (Get-FileHash $tempPath -Algorithm SHA256).Hash
    $localHash  = (Get-FileHash $localPath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash

    if ($remoteHash -ne $localHash) {
        Write-Host "[PROFILE] Remote change detected, updating and reloading..." -ForegroundColor Yellow
        Copy-Item $tempPath $localPath -Force
        . $localPath   # reload the new profile immediately
        Remove-Item $tempPath -ErrorAction SilentlyContinue
        return
    }
}
catch {
    Write-Host "[PROFILE] Auto-update failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
}
finally {
    Remove-Item $tempPath -ErrorAction SilentlyContinue
}
# --- end auto-sync -----------------------------------------------------------



############################################
# Minimal AI Profile — Comfy-first (restored)
############################################

# =====================================================================
# Core console / output configuration
# =====================================================================

# Force UTF-8 so ANSI/prompt glyphs behave
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# Make sure ANSI rendering + classic progress bar
if ($PSStyle) {
    $PSStyle.OutputRendering = 'Ansi'
    if ($PSStyle.PSObject.Properties.Name -contains 'ProgressView') {
        $PSStyle.ProgressView = 'Classic'
    }
}

# Always show Write-Information and progress
$InformationPreference = 'Continue'
$ProgressPreference    = 'Continue'


# =====================================================================
# Toast notifications (Windows notification center)
# =====================================================================

function toast {
    <#
        .SYNOPSIS
        Show a Windows toast notification (or fallback to console).

        .PARAMETER Message
        Body text of the toast.

        .PARAMETER Title
        Title line of the toast (defaults to "PowerShell").
    #>
    param(
        [string]$Message = "Done!",
        [string]$Title   = "PowerShell"
    )

    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime -ErrorAction SilentlyContinue | Out-Null
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null

        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(
            [Windows.UI.Notifications.ToastTemplateType]::ToastText02
        )

        $textNodes = $template.GetElementsByTagName("text")
        $null = $textNodes[0].AppendChild($template.CreateTextNode($Title))
        $null = $textNodes[1].AppendChild($template.CreateTextNode($Message))

        $toast    = [Windows.UI.Notifications.ToastNotification]::new($template)
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
        $notifier.Show($toast)
    }
    catch {
        # If toasts aren't available (or error), degrade gracefully
        Write-Host ("{0}: {1}" -f $Title, $Message)

    }
}


# =====================================================================
# ComfyUI + AI helper functions
# =====================================================================

function comfy {
    <#
        .SYNOPSIS
        Launch ComfyUI in the comfy-312 venv with Sage attention and WAN defaults.

        .PARAMETER Activate
        Just activate the venv and return (no ComfyUI launched).

        .PARAMETER DebugCuda
        Set CUDA_LAUNCH_BLOCKING=1 for debugging GPU issues.

        .PARAMETER Extra
        Any extra arguments to pass to ComfyUI.
    #>
    param(
        [switch]$Activate,
        [switch]$DebugCuda,
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Extra
    )

    $venv  = "D:\AI\venv\comfy-312"
    $py    = Join-Path $venv "Scripts\python.exe"
    $comfy = "D:\AI\ComfyUI\main.py"

    $env:PYTHONIOENCODING = "utf-8"

    if (-not (Test-Path $py)) {
        Write-Host "❌ venv not found: $venv" -ForegroundColor Red
        return
    }

    # Stable environment for big VRAM ComfyUI
    $env:PYTORCH_CUDA_ALLOC_CONF             = "expandable_segments:True,max_split_size_mb:128,garbage_collection_threshold:0.70"
    $env:COMFYUI_USER_DIR                    = "D:\AI\ComfyUI"
    $env:CUDA_MODULE_LOADING                 = "LAZY"
    $env:PYTORCH_CUDA_FUSER_DISABLE_FALLBACK = "1"
    $env:TORCHINDUCTOR_DISABLE               = "1"
    $env:XFORMERS_FORCE_DISABLE_FLASH        = "1"

    # Einops determinism preferences
    $env:EINOPS_IGNORED_BACKENDS  = "tensorflow"
    $env:EINOPS_BACKENDS_PRIORITY = "torch,numpy"

    if ($DebugCuda) {
        $env:CUDA_LAUNCH_BLOCKING = "1"
    } else {
        Remove-Item Env:CUDA_LAUNCH_BLOCKING -ErrorAction SilentlyContinue
    }

    # Clean up potential stray alloc config
    Remove-Item Env:PYTORCH_ALLOC_CONF -ErrorAction SilentlyContinue

    if ($Activate) {
        & "$venv\Scripts\Activate.ps1"
        Write-Host " Activated ComfyUI venv: $venv" -ForegroundColor Magenta
        return
    }

    # Comfy tab: orange-ish for visual context
    if (Get-Command Set-WTTabColor -ErrorAction SilentlyContinue) {
        Set-WTTabColor 3
    }

    Push-Location "D:\AI\ComfyUI"
    Write-Host "`n ComfyUI (SageAttention, Py 3.12)..." -ForegroundColor Yellow

    # Base Comfy arguments (WAN2.2 style) + any extras
    $argv = @(
        '--use-sage-attention',
        '--listen',
        '--port', '8188'
    ) + $Extra

    $logDir = "D:\AI\ComfyUI\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }

    $log = Join-Path $logDir ("comfy_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

    # Run ComfyUI, log all output, and watch for per-prompt success/failure lines
    & $py $comfy @argv *>&1 |
        Tee-Object -FilePath $log |
        ForEach-Object {
            # Per-prompt success line
            if ($_ -match '^Prompt executed in .* seconds') {
                toast "ComfyUI prompt finished on $env:COMPUTERNAME" "ComfyUI"
            }
            # Per-prompt failure / interruption markers
            elseif ($_ -match '^(Processing interrupted|!!! Exception during processing !!!)') {
                toast "ComfyUI prompt failed on $env:COMPUTERNAME" "ComfyUI Error"
            }

            # Always echo the line so the terminal still shows everything
            $_
        }

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        # Whole Comfy process crashed / exited abnormally
        toast "ComfyUI crashed (exit $exitCode) — see $log" "ComfyUI Error"
        Write-Host "`n ComfyUI exited with code $exitCode.`n Log saved to $log" -ForegroundColor Red
    }
    else {
        # Whole Comfy process exited cleanly
        toast "ComfyUI server exited normally on $env:COMPUTERNAME" "ComfyUI"
    }

    Pop-Location
}


function comfy-log {
    <#
        .SYNOPSIS
        Open the most recent ComfyUI log file in Notepad.
    #>
    $logDir = "D:\AI\ComfyUI\logs"

    if (-not (Test-Path $logDir)) {
        Write-Host "No log dir at $logDir" -ForegroundColor Yellow
        return
    }

    $latest = Get-ChildItem $logDir -Filter "comfy_*.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) {
        Write-Host "No comfy logs found." -ForegroundColor Yellow
        return
    }

    Write-Host "Opening $($latest.FullName)" -ForegroundColor Cyan
    & notepad.exe $latest.FullName
}


function hf {
    <#
        .SYNOPSIS
        Pull an LLM or model snapshot from HuggingFace into ComfyUI's models/LLM.

        .PARAMETER repo
        HuggingFace repo id (e.g. "mistralai/Mistral-7B-v0.3").

        .PARAMETER name
        Local folder name under models/LLM (defaults to last part of repo id).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$repo,
        [string]$name
    )

    $venvPy = "D:\AI\venv\comfy-312\Scripts\python.exe"

    if (-not (Test-Path $venvPy)) {
        Write-Host "❌ Venv not found: D:\AI\venv\comfy-312" -ForegroundColor Red
        return
    }

    if (-not $name) {
        $name = ($repo -split "/")[-1]
    }

    $dest = "D:\AI\ComfyUI\models\LLM\$name"
    if (!(Test-Path $dest)) {
        New-Item -ItemType Directory -Force -Path $dest | Out-Null
    }

    & $venvPy -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='$repo', local_dir=r'$dest')"
    Write-Host "✅ Pulled $repo → $dest" -ForegroundColor Green
}


function check-ai {
    <#
        .SYNOPSIS
        Report Python, Torch, CUDA, and xformers versions for the active venv.
    #>
    if (-not $env:VIRTUAL_ENV) {
        Write-Host "No active venv." -ForegroundColor Yellow
        return
    }

    & "$env:VIRTUAL_ENV\Scripts\python.exe" -c "import torch, sys; print(f'PyTorch: {torch.__version__}, CUDA: {torch.version.cuda}, Device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"CPU\"}'); print(f'Python: {sys.version}')"

    try {
        & "$env:VIRTUAL_ENV\Scripts\python.exe" -c "import xformers; import sys; v=getattr(xformers,'__version__', 'installed'); print(f'xformers: {v}')"
    } catch {
        Write-Host 'xformers not found'
    }
}


# =====================================================================
# Training helpers (sd-scripts / LoRA)
# =====================================================================

function train-venv {
    <#
        .SYNOPSIS
        Activate the sd-train2 venv for training sd-scripts / LoRA.
    #>
    & "D:\AI\venv\sd-train2\Scripts\Activate.ps1"
}


function train-lora {
    <#
        .SYNOPSIS
        Simple LoRA training launcher using TOML configs under E:\SD-Models\lora.
    #>
    $loraDir = "E:\SD-Models\lora"
    $tomls   = Get-ChildItem -Recurse -Filter *.toml -Path $loraDir -ErrorAction SilentlyContinue |
               Sort-Object FullName

    if (-not $tomls) {
        Write-Host "❌ No TOML files in $loraDir"
        return
    }

    Write-Host "`nAvailable TOMLs:`n"
    for ($i = 0; $i -lt $tomls.Count; $i++) {
        Write-Host "[$i] $($tomls[$i].FullName)"
    }

    $choice = Read-Host "`nSelect index"
    if ($choice -notmatch '^\d+$' -or [int]$choice -ge $tomls.Count) {
        Write-Host "❌ Invalid selection"
        return
    }

    $cfg = $tomls[[int]$choice].FullName

    # ensure flashattention off in xformers when training
    Get-ChildItem -Recurse -Filter "_C_flashattention.pyd" "D:\AI\venv\sd-train2\Lib\site-packages\xformers" -ErrorAction SilentlyContinue |
        Remove-Item -Force

    $env:XFORMERS_FORCE_DISABLE_FLASH = "1"

    & "D:\AI\venv\sd-train2\Scripts\accelerate.exe" launch D:\AI\sd-scripts-new\train_network.py --config_file "$cfg"
}


# =====================================================================
# Misc utility: m3u8 → mp4 converter (for streaming captures)
# =====================================================================

function convertm3u {
    <#
        .SYNOPSIS
        Convert a local .m3u8 playlist to .mp4 using ffmpeg with headers/cookies.

        NOTE: Relies on Get-SessionCookieForDomain to exist in your environment.
    #>
    $m3u = Get-ChildItem -Filter *.m3u8 | Select-Object -ExpandProperty Name
    if (-not $m3u) {
        Write-Host "No .m3u8 here." -ForegroundColor Yellow
        return
    }

    $i = 1
    $m3u | ForEach-Object {
        Write-Host "$i. $_"
        $i++
    }

    $sel = Read-Host "Pick #"
    if ($sel -notmatch '^\d+$' -or [int]$sel -lt 1 -or [int]$sel -gt $m3u.Count) {
        Write-Host "Bad choice"
        return
    }

    $in  = $m3u[[int]$sel - 1]
    $out = Read-Host "Output name (.mp4)"

    if (-not $out.EndsWith(".mp4")) {
        $out += ".mp4"
    }

    $first = Select-String -Path $in -Pattern '^https?://' | Select-Object -First 1
    if (-not $first) {
        Write-Host "No URL in m3u8"
        return
    }

    $uri  = [Uri]$first.Line
    $host = $uri.Host

    try {
        $cookie = Get-SessionCookieForDomain $host
    } catch {
        $cookie = $null
    }

    $headers = "User-Agent: Mozilla/5.0`r`nReferer: https://$host"
    if ($cookie) {
        $headers += "`r`nCookie: $cookie"
    }

    ffmpeg -headers "$headers" -protocol_whitelist "file,http,https,tcp,tls,crypto" -i "$in" -c copy "$out"
}


# =====================================================================
# Windows Terminal tab helpers: color + title
# =====================================================================

function Set-WTTabColor {
    <#
        .SYNOPSIS
        Set Windows Terminal tab background color by palette index (0–15).

        1 = red, 2 = green, 3 = yellow/orange, 4 = blue, 5 = magenta, 6 = cyan.
    #>
    param(
        [int]$Index
    )

    if ($Index -lt 0 -or $Index -gt 15) {
        return
    }

    $esc = [char]27
    # "2;15;Index,|" is the WT alias escape for tab background from palette
    Write-Host "$esc[2;15;${Index},|" -NoNewline
}


function Set-WTTabTitle {
    <#
        .SYNOPSIS
        Set Windows Terminal tab title using OSC escape.
    #>
    param(
        [string]$Title
    )

    $esc = [char]27
    $bel = [char]7
    Write-Host "$esc]0;$Title$bel" -NoNewline
}


# =====================================================================
# Admin detection + tab color/title per machine
# =====================================================================

# Figure out whether this shell is elevated
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal       = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $global:IsAdmin  = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
} catch {
    $global:IsAdmin = $false
}

# Tab title / color defaults
$machine       = $env:COMPUTERNAME
$tabTitle      = $machine
$tabColorIndex = 6  # default teal/cyan

if ($machine -eq 'ANTON') {
    # Special-case ANTON styling
    if ($IsAdmin) {
        $tabTitle      = 'ANTON-ADMIN'
        $tabColorIndex = 1   # red
    } else {
        $tabTitle      = 'ANTON'
        $tabColorIndex = 6   # teal
    }
} else {
    # For SSH sessions, show remote host instead
    if ($env:SSH_CONNECTION) {
        $machine  = ($env:SSH_CONNECTION -split ' ')[2]
        $tabTitle = $machine
    }

    if ($IsAdmin) {
        # Any non-ANTON box: mark admin shells loudly
        $tabTitle      = "$tabTitle-ADMIN"
        $tabColorIndex = 1   # red
    }
}

if (Get-Command Set-WTTabColor -ErrorAction SilentlyContinue) {
    Set-WTTabColor $tabColorIndex
}
if (Get-Command Set-WTTabTitle -ErrorAction SilentlyContinue) {
    Set-WTTabTitle $tabTitle
}


# =====================================================================
# Environment variables for AI / venv sanity
# =====================================================================

$env:TORCH_USE_REENTRANT_CHECKPOINT  = "False"
$env:VIRTUAL_ENV_DISABLE_PROMPT      = 1
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = 1
$env:TORCH_ELASTIC_NO_REDIRECTS      = 1
$env:XFORMERS_FORCE_DISABLE_FLASH    = "1"


# =====================================================================
# UI / extras (prompt theme, choco)
# =====================================================================

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\purple-man.json" | Invoke-Expression

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module "$ChocolateyProfile"
}

# Also expose admin state as an env var for other tools / themes
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal       = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $env:IS_ADMIN    = ($principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) ? "1" : "0"
} catch {
    $env:IS_ADMIN = "0"
}


# =====================================================================
# PSReadLine tuning
# =====================================================================

if (Get-Module -ListAvailable -Name PSReadLine) {
    if (-not (Get-Module PSReadLine)) {
        Import-Module PSReadLine
    }

    # History-based prediction (like fish shell)
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView

    # Quiet the bell and make history search nicer
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd

    # Up/Down = prefix search instead of scrolling whole history
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Ctrl+Space to accept a single token of prediction
    Set-PSReadLineKeyHandler -Key "Ctrl+Spacebar" -Function AcceptSuggestion
}


# =====================================================================
# File colorization in dir listings
# =====================================================================

$PSStyle.FileInfo.Directory                 = "`e[38;2;0;209;209m"
$PSStyle.FileInfo.SymbolicLink              = "`e[38;2;255;35;255m"
$PSStyle.FileInfo.Executable                = "`e[38;2;57;255;20m"
$PSStyle.FileInfo.Extension[".zip"]         = "`e[38;2;233;40;135m"
$PSStyle.FileInfo.Extension[".tgz"]         = "`e[38;2;233;40;135m"
$PSStyle.FileInfo.Extension[".gz"]          = "`e[38;2;233;40;135m"
$PSStyle.FileInfo.Extension[".tar"]         = "`e[38;2;233;40;135m"
$PSStyle.FileInfo.Extension[".nupkg"]       = "`e[38;2;233;40;135m"
$PSStyle.FileInfo.Extension[".cab"]         = "`e[38;2;233;40;135m"
$PSStyle.FileInfo.Extension[".7z"]          = "`e[38;2;233;40;135m"
$PSStyle.FileInfo.Extension[".ps1"]         = "`e[38;2;255;222;87m"
$PSStyle.FileInfo.Extension[".psd1"]        = "`e[38;2;255;222;87m"
$PSStyle.FileInfo.Extension[".psm1"]        = "`e[38;2;255;222;87m"
$PSStyle.FileInfo.Extension[".ps1xml"]      = "`e[38;2;255;222;87m"


# =====================================================================
# Aliases
# =====================================================================

# Use gsudo for sudo; your sudo function has been retired with honors
Set-Alias sudo gsudo -Force
