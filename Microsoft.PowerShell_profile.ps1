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
