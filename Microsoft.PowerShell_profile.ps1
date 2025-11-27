# --- Auto-sync $PROFILE from GitHub (do not edit this block) ---
$localPath = $PROFILE
$tempPath  = Join-Path $env:TEMP 'Microsoft.PowerShell_profile.ps1.remote'

try {
    # Build a clean, cache-busted URL
    $cacheBuster = Get-Random
    $finalUrl    = 'https://raw.githubusercontent.com/mikesimone/.bashrc/refs/heads/main/Microsoft.PowerShell_profile.ps1?cb={0}' -f $cacheBuster

    Write-Host "[PROFILE] Fetching: $finalUrl" -ForegroundColor DarkGray

    Invoke-WebRequest -Uri $finalUrl -OutFile $tempPath -Headers @{ 'Cache-Control' = 'no-cache' } -ErrorAction Stop

    $remoteHash = (Get-FileHash $tempPath -Algorithm SHA256).Hash
    $localHash  = (Get-FileHash $localPath -Algorithm SHA256 -ErrorAction SilentlyContinue).Hash

    if ($remoteHash -ne $localHash) {
        Write-Host "[PROFILE] Remote change detected, updating and reloading..." -ForegroundColor Yellow
        Copy-Item $tempPath $localPath -Force
        . $localPath
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
# --- end auto-sync ---

############################################
# Minimal AI Profile — Comfy-first (restored)
############################################

# --- Console/Rendering fixes (color + progress + UTF-8) ---
# NOTE: Do NOT enable StrictMode here; it breaks prompt/theme quirks.

# --- Console/Rendering fixes (color + progress + UTF-8) ---
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ($PSStyle) {
    $PSStyle.OutputRendering = 'Ansi'
    if ($PSStyle.PSObject.Properties.Name -contains 'ProgressView') {
        $PSStyle.ProgressView = 'Classic'
    }
}

$InformationPreference = 'Continue'
$ProgressPreference    = 'Continue'

# --- Functions ---

function comfy {
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

    # Your environment (stable on big VRAM)
    $env:PYTORCH_CUDA_ALLOC_CONF           = "expandable_segments:True,max_split_size_mb:128,garbage_collection_threshold:0.70"
    $env:COMFYUI_USER_DIR                  = "D:\AI\ComfyUI"
    $env:CUDA_MODULE_LOADING               = "LAZY"
    $env:PYTORCH_CUDA_FUSER_DISABLE_FALLBACK = "1"
    $env:TORCHINDUCTOR_DISABLE             = "1"
    $env:XFORMERS_FORCE_DISABLE_FLASH      = "1"

    # Sage determinism
    $env:EINOPS_IGNORED_BACKENDS   = "tensorflow"
    $env:EINOPS_BACKENDS_PRIORITY  = "torch,numpy"

    if ($DebugCuda) {
        $env:CUDA_LAUNCH_BLOCKING = "1"
    } else {
        Remove-Item Env:CUDA_LAUNCH_BLOCKING -ErrorAction SilentlyContinue
    }

    Remove-Item Env:PYTORCH_ALLOC_CONF -ErrorAction SilentlyContinue

    if ($Activate) {
        & "$venv\Scripts\Activate.ps1"
        Write-Host " Activated ComfyUI venv: $venv" -ForegroundColor Magenta
        return
    }

    # Comfy tab: orange (index 3 = yellow/brown, shows as orange-ish)
    if (Get-Command Set-WTTabColor -ErrorAction SilentlyContinue) {
        Set-WTTabColor 3
    }

    Push-Location "D:\AI\ComfyUI"
    Write-Host "`n ComfyUI (SageAttention, Py 3.12)..." -ForegroundColor Yellow

    # Match your old args; you can tack on extras at the end
    $argv = @(
        '--use-sage-attention',
        '--listen',
        '--port','8188'
    ) + $Extra

    $logDir = "D:\AI\ComfyUI\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }

    $log = Join-Path $logDir ("comfy_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

    # Keep console alive AND capture everything, with ANSI preserved
    & $py $comfy @argv *>&1 | Tee-Object -FilePath $log

    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host "`n ComfyUI exited with code $exitCode.`n Log saved to $log" -ForegroundColor Red
    }

    Pop-Location
    # Clear Comfy mode for future tabs
}

function comfy-log {
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

# Training (kept lean; you still use sd-scripts outside Comfy)

function train-venv {
    & "D:\AI\venv\sd-train2\Scripts\Activate.ps1"
}

function train-lora {
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

function convertm3u {
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

function Set-WTTabColor {
    param(
        [int]$Index
    )
    # 0–7 = normal, 8–15 = bright variants
    # 1 = red, 2 = green, 3 = yellow/brown, 4 = blue, 5 = magenta/pink, 6 = cyan/teal

    if ($Index -lt 0 -or $Index -gt 15) {
        return
    }

    $esc = [char]27
    # 2 = tab background alias, 15 = foreground (ignored by WT), Index = palette entry
    Write-Host "$esc[2;15;${Index},|" -NoNewline
}

function Set-WTTabTitle {
    param(
        [string]$Title
    )

    $esc = [char]27
    $bel = [char]7
    Write-Host "$esc]0;$Title$bel" -NoNewline
}

# --- Admin flag for prompt/theming ---
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal       = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $global:IsAdmin  = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
} catch {
    $global:IsAdmin = $false
}

# --- Context-based tab title + colors (all machines, not just ANTON) ---

$machine       = $env:COMPUTERNAME
$tabTitle      = $machine
$tabColorIndex = 6  # default teal/cyan

if ($machine -eq 'ANTON') {
    if ($IsAdmin) {
        $tabTitle      = 'ANTON-ADMIN'
        $tabColorIndex = 1   # red
    } else {
        $tabTitle      = 'ANTON'
        $tabColorIndex = 6   # teal
    }
} else {
    if ($env:SSH_CONNECTION) {
        # Show remote host name when in SSH
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

# --- Environment (keep tidy; prevent venv from mangling prompt text) ---
$env:TORCH_USE_REENTRANT_CHECKPOINT = "False"
$env:VIRTUAL_ENV_DISABLE_PROMPT     = 1
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = 1
$env:TORCH_ELASTIC_NO_REDIRECTS     = 1
$env:XFORMERS_FORCE_DISABLE_FLASH   = "1"

# --- UI / Extras ---

oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\purple-man.json" | Invoke-Expression

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module "$ChocolateyProfile"
}

# --- Admin flag for prompt theming (env var) ---
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal       = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $env:IS_ADMIN    = ($principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) ? "1" : "0"
} catch {
    $env:IS_ADMIN = "0"
}

# --- PSReadLine QoL ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    if (-not (Get-Module PSReadLine)) {
        Import-Module PSReadLine
    }

    # History-based prediction (like fish shell, but not awful)
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView

    # Make editing feel nicer
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd

    # Up/Down = search history by prefix instead of dumb full history scroll
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Ctrl+Space to accept a single token of prediction
    Set-PSReadLineKeyHandler -Key "Ctrl+Spacebar" -Function AcceptSuggestion
}

# --- Colors (PowerShell 7+; proper ESC with backtick-e) ---
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

# --- Prefer gsudo for sudo ---
Set-Alias sudo gsudo -Force
