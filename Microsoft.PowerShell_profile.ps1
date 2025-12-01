# Bootstrap PowerShell profile from private Environment repo

$EnvRepo = Join-Path $HOME "Environment"

# Ensure repo exists locally
if (-not (Test-Path (Join-Path $EnvRepo ".git"))) {
    try {
        git clone "git@github.com:mikesimone/Environment.git" $EnvRepo | Out-Null
    } catch {
        Write-Host "[PROFILE] Failed to clone Environment repo: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    try {
        git -C $EnvRepo pull --ff-only | Out-Null
    } catch {
        Write-Host "[PROFILE] Failed to update Environment repo" -ForegroundColor Yellow
    }
}

# Optional: common profile for all machines (shared functions/aliases)
$CommonProfile = Join-Path $EnvRepo "powershell\common.ps1"
if (Test-Path $CommonProfile) {
    . $CommonProfile
}

# Machine-specific profile: powershell\<computername-lower>.ps1
$machineName = $env:COMPUTERNAME.ToLowerInvariant()
$machineProfile = Join-Path $EnvRepo ("powershell\" + $machineName + ".ps1")

if (Test-Path $machineProfile) {
    . $machineProfile
} else {
    Write-Host "[PROFILE] No machine-specific profile found for $machineName at $machineProfile" -ForegroundColor DarkYellow
}

function reload-profile {
    param(
        [switch]$ForceGit      # run git pull even if ENV_PROFILE_NO_SYNC is set
    )

    # Allow reloading from scratch (skip the idempotent guard inside anton.ps1)
    Remove-Item Env:ANTON_PROFILE_LOADED -ErrorAction SilentlyContinue

    if ($ForceGit) {
        # explicitly sync with repo
        Write-Host "[PROFILE] Syncing Environment repo..." -ForegroundColor Cyan
        git -C (Join-Path $HOME "Environment") pull --ff-only 2>$null
    } else {
        # skip git update when reloading
        $env:ENV_PROFILE_NO_SYNC = '1'
    }

    Write-Host "[PROFILE] Reloading profile..." -ForegroundColor Cyan
    . $PROFILE

    # Clean up sync suppressor (if used)
    Remove-Item Env:ENV_PROFILE_NO_SYNC -ErrorAction SilentlyContinue
}
