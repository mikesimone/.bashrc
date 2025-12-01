# --- Auto-sync $PROFILE from GitHub (version 2025-11-30-D) -------------------
$profileVersion = '2025-11-30-D'
Write-Host "[PROFILE] Profile version: $profileVersion"

$localPath     = $PROFILE
$tempPath      = Join-Path $env:TEMP 'Microsoft.PowerShell_profile.ps1.remote'
$remoteBaseUrl = 'https://raw.githubusercontent.com/mikesimone/.bashrc/refs/heads/main/Microsoft.PowerShell_profile.ps1'

# Only try to sync once per PowerShell process
if (-not $env:PROFILE_SYNCED) {
    try {
        # Cache-buster so GitHub raw never serves a stale file
        $cacheBuster = Get-Random
        $finalUrl    = "$remoteBaseUrl?cb=$cacheBuster"

        Write-Host "[PROFILE] Fetching: $finalUrl" -ForegroundColor DarkGray

        Invoke-WebRequest -Uri $finalUrl -OutFile $tempPath -Headers @{
            'Cache-Control' = 'no-cache'
        } -ErrorAction Stop

        if (Test-Path $tempPath) {
            $remoteHash = (Get-FileHash $tempPath -Algorithm SHA256).Hash
            $localHash  = if (Test-Path $localPath) {
                              (Get-FileHash $localPath -Algorithm SHA256).Hash
                          } else { '' }

            if ($remoteHash -ne $localHash) {
                Write-Host "[PROFILE] Remote change detected; updating local profile file. Restart PowerShell to load it." -ForegroundColor Yellow
                Copy-Item $tempPath $localPath -Force
            }
            else {
                Write-Host "[PROFILE] No remote changes; keeping existing profile." -ForegroundColor DarkGray
            }
        }
    }
    catch {
        Write-Host "[PROFILE] Auto-sync failed: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
    finally {
        Remove-Item $tempPath -ErrorAction SilentlyContinue
    }

    # Guard so we only attempt sync once per process
    $env:PROFILE_SYNCED = '1'
}
# --- end auto-sync block -----------------------------------------------------


############################################
# Minimal AI Profile — Comfy-first (portable)
############################################


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

# --- WT helpers: tab color + title ------------------------------------------

function Set-WTTabColor {
    param(
        [int]$Index
    )
    # 0–7 = normal, 8–15 = bright variants
    # 1 = red, 2 = green, 3 = yellow/brown, 4 = blue, 5 = magenta/pink, 6 = cyan/teal
    if ($Index -lt 0 -or $Index -gt 15) { return }
    $esc = [char]27
    # 2 = tab background alias, 15 = foreground (ignored by WT), Index = palette entry
    Write-Host "$esc[2;15;${Index},|" -NoNewline
}

function Set-WTTabTitle {
    param([string]$Title)
    if (-not $Title) { return }
    $esc = [char]27
    $bel = [char]7
    Write-Host "$esc]0;$Title$bel" -NoNewline
}

# --- Admin flag for prompt/theming ------------------------------------------

try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $global:IsAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
} catch {
    $global:IsAdmin = $false
}

# Small env flag for other tools if needed
try {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    $env:IS_ADMIN = ($principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) ? "1" : "0"
} catch {
    $env:IS_ADMIN = "0"
}

# --- Context-aware tab title builder ----------------------------------------

function Update-WTTabContext {
    param(
        [string]$Extra  # e.g. "ComfyUI"
    )

    # Base host label
    $hostLabel = $env:COMPUTERNAME
    if ($env:COMPUTERNAME -eq 'ANTON') {
        $hostLabel = if ($IsAdmin) { 'ANTON-ADMIN' } else { 'ANTON' }
    }

    # Venv label (if any)
    $venvLabel = $null
    if ($env:VIRTUAL_ENV) {
        $venvName = Split-Path -Leaf $env:VIRTUAL_ENV
        if ($venvName) {
            $venvLabel = "venv:$venvName"
        }
    }

    $parts = @($hostLabel)
    if ($venvLabel) { $parts += $venvLabel }
    if ($Extra)     { $parts += $Extra  }

    $title = ($parts -join ' | ')
    Set-WTTabTitle $title

    # Also ensure base tab color for host/admin if not overridden later
    if ($env:COMPUTERNAME -eq 'ANTON') {
        if ($IsAdmin) {
            Set-WTTabColor 1   # red
        } else {
            Set-WTTabColor 6   # teal/cyan
        }
    }
}

function Install-VenvDeactivationHook {
    # Grab the current deactivate function (the one created by Activate.ps1)
    $cmd = Get-Command deactivate -CommandType Function -ErrorAction SilentlyContinue
    if (-not $cmd) { return }

    # Keep the original scriptblock around
    $script:OrigDeactivate = $cmd.ScriptBlock

    # Wrap deactivate so it calls the original, then refreshes the tab title
    function global:deactivate {
        & $script:OrigDeactivate
        Update-WTTabContext  # recompute title: ANTON / ANTON-ADMIN and venv tag
    }
}


# Initialize title for this tab on startup
Update-WTTabContext

# --- Functions --------------------------------------------------------------

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
    $env:PYTHONIOENCODING="utf-8"

    if (-not (Test-Path $py)) {
        Write-Host "❌ venv not found: $venv" -ForegroundColor Red
        return
    }

    # Your environment (stable on big VRAM)
    $env:PYTORCH_CUDA_ALLOC_CONF       = "expandable_segments:True,max_split_size_mb:128,garbage_collection_threshold:0.70"
    $env:COMFYUI_USER_DIR              = "D:\AI\ComfyUI"
    $env:CUDA_MODULE_LOADING           = "LAZY"
    $env:PYTORCH_CUDA_FUSER_DISABLE_FALLBACK = "1"
    $env:TORCHINDUCTOR_DISABLE         = "1"
    $env:XFORMERS_FORCE_DISABLE_FLASH  = "1"   # Sage determinism
    $env:EINOPS_IGNORED_BACKENDS       = "tensorflow"
    $env:EINOPS_BACKENDS_PRIORITY      = "torch,numpy"

    if ($DebugCuda) {
        $env:CUDA_LAUNCH_BLOCKING = "1"
    } else {
        Remove-Item Env:CUDA_LAUNCH_BLOCKING -ErrorAction SilentlyContinue
    }
    Remove-Item Env:PYTORCH_ALLOC_CONF -ErrorAction SilentlyContinue

    if ($Activate) {
        & "$venv\Scripts\Activate.ps1"
        Write-Host "🐍 Activated ComfyUI venv: $venv" -ForegroundColor Magenta

        # Hook deactivate so it also refreshes the tab
        Install-VenvDeactivationHook

        # Reflect active venv in tab title, but don't force ComfyUI label
        Update-WTTabContext
        return
    }


    # Running the server: orange tab + label
    Set-WTTabColor 3                    # orange-ish (brown/yellow)
    Update-WTTabContext -Extra 'ComfyUI'

    Push-Location "D:\AI\ComfyUI"
    Write-Host "`n🚀 ComfyUI (SageAttention, Py 3.12)..." -ForegroundColor Yellow

    # Match your old args; you can tack on extras at the end
    $argv = @('--use-sage-attention','--listen','--port','8188') + $Extra

    $logDir = "D:\AI\ComfyUI\logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $log = Join-Path $logDir ("comfy_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

    # Keep console alive AND capture everything, with ANSI preserved
    & $py $comfy @argv *>&1 | Tee-Object -FilePath $log

    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        Write-Host "`n💥 ComfyUI exited with code $exitCode. Log saved to $log" -ForegroundColor Red
    }

    Pop-Location
}

function comfy-log {
    $logDir = "D:\AI\ComfyUI\logs"
    if (-not (Test-Path $logDir)) { Write-Host "No log dir at $logDir" -ForegroundColor Yellow; return }
    $latest = Get-ChildItem $logDir -Filter "comfy_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) { Write-Host "No comfy logs found." -ForegroundColor Yellow; return }
    Write-Host "Opening $($latest.FullName)" -ForegroundColor Cyan
    & notepad.exe $latest.FullName
}

function hf {
    param(
        [Parameter(Mandatory=$true)][string]$repo,
        [string]$name
    )
    $venvPy = "D:\AI\venv\comfy-312\Scripts\python.exe"
    if (-not (Test-Path $venvPy)) { Write-Host "❌ Venv not found: D:\AI\venv\comfy-312" -ForegroundColor Red; return }
    if (-not $name) { $name = ($repo -split "/")[-1] }
    $dest = "D:\AI\ComfyUI\models\LLM\$name"
    if (!(Test-Path $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }
    & $venvPy -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='$repo', local_dir=r'$dest')"
    Write-Host "✅ Pulled $repo → $dest" -ForegroundColor Green
}

function check-ai {
    if (-not $env:VIRTUAL_ENV) { Write-Host "No active venv." -ForegroundColor Yellow; return }
    & "$env:VIRTUAL_ENV\Scripts\python.exe" -c "import torch, sys; print(f'PyTorch: {torch.__version__}, CUDA: {torch.version.cuda}, Device: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"CPU\"}'); print(f'Python: {sys.version}')"
    try {
        & "$env:VIRTUAL_ENV\Scripts\python.exe" -c "import xformers; import sys; v=getattr(xformers,'__version__', 'installed'); print(f'xformers: {v}')"
    } catch {
        Write-Host 'xformers not found'
    }
}

function train-venv {
    & "D:\AI\venv\sd-train2\Scripts\Activate.ps1"
    Write-Host "🐍 Activated training venv: D:\AI\venv\sd-train2" -ForegroundColor Magenta

    Install-VenvDeactivationHook
    Update-WTTabContext
}


function train-lora {
    $loraDir = "E:\SD-Models\lora"
    $tomls = Get-ChildItem -Recurse -Filter *.toml -Path $loraDir -ErrorAction SilentlyContinue | Sort-Object FullName
    if (-not $tomls) { Write-Host "❌ No TOML files in $loraDir"; return }
    Write-Host "`nAvailable TOMLs:`n"
    for ($i=0; $i -lt $tomls.Count; $i++){ Write-Host "[$i] $($tomls[$i].FullName)" }
    $choice = Read-Host "`nSelect index"
    if ($choice -notmatch '^\d+$' -or [int]$choice -ge $tomls.Count){ Write-Host "❌ Invalid selection"; return }
    $cfg = $tomls[[int]$choice].FullName

    # ensure flashattention off in xformers when training
    Get-ChildItem -Recurse -Filter "_C_flashattention.pyd" "D:\AI\venv\sd-train2\Lib\site-packages\xformers" -ErrorAction SilentlyContinue | Remove-Item -Force
    $env:XFORMERS_FORCE_DISABLE_FLASH = "1"

    & "D:\AI\venv\sd-train2\Scripts\accelerate.exe" launch D:\AI\sd-scripts-new\train_network.py --config_file "$cfg"
}

function sudo {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)
    & "C:\Windows\System32\sudo.exe" pwsh -Command ($Args -join " ")
}

function Use-Venv {
    param(
        [Parameter(Mandatory)][string]$Path
    )
    $activate = Join-Path $Path "Scripts\Activate.ps1"
    if (-not (Test-Path $activate)) {
        Write-Host "❌ No Activate.ps1 at $activate" -ForegroundColor Red
        return
    }
    & $activate
    Write-Host "🐍 Activated venv: $Path" -ForegroundColor Magenta

    Install-VenvDeactivationHook
    Update-WTTabContext
}
Set-Alias venv Use-Venv -Force

function convertm3u {
    $m3u = Get-ChildItem -Filter *.m3u8 | Select-Object -ExpandProperty Name
    if (-not $m3u){ Write-Host "No .m3u8 here." -ForegroundColor Yellow; return }
    $i=1; $m3u | ForEach-Object { Write-Host "$i. $_"; $i++ }
    $sel = Read-Host "Pick #"
    if ($sel -notmatch '^\d+$' -or [int]$sel -lt 1 -or [int]$sel -gt $m3u.Count){ Write-Host "Bad choice"; return }
    $in  = $m3u[[int]$sel-1]
    $out = Read-Host "Output name (.mp4)"
    if (-not $out.EndsWith(".mp4")){ $out += ".mp4" }
    $first = Select-String -Path $in -Pattern '^https?://' | Select-Object -First 1
    if (-not $first){ Write-Host "No URL in m3u8"; return }
    $uri = [Uri]$first.Line; $host = $uri.Host
    try { $cookie = Get-SessionCookieForDomain $host } catch { $cookie = $null }
    $headers = "User-Agent: Mozilla/5.0`r`nReferer: https://$host"
    if ($cookie){ $headers += "`r`nCookie: $cookie" }
    ffmpeg -headers "$headers" -protocol_whitelist "file,http,https,tcp,tls,crypto" -i "$in" -c copy "$out"
}

# --- Environment (keep tidy; prevent venv from mangling prompt text) ---
$env:TORCH_USE_REENTRANT_CHECKPOINT = "False"
$env:VIRTUAL_ENV_DISABLE_PROMPT      = 1
$env:HF_HUB_DISABLE_SYMLINKS_WARNING = 1
$env:TORCH_ELASTIC_NO_REDIRECTS      = 1
$env:XFORMERS_FORCE_DISABLE_FLASH    = "1"

# --- UI / Extras ---
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\purple-man.json" | Invoke-Expression
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) { Import-Module "$ChocolateyProfile" }

# --- PSReadLine QoL ---
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine

    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -BellStyle None
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd

    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key "Ctrl+Spacebar" -Function AcceptSuggestion
}

# Make sure sudo means gsudo in your shell
Set-Alias sudo gsudo -Force
