# --- Auto-sync $PROFILE from GitHub (version 2025-11-30-F) -------------------
$profileVersion = '2025-11-30-F'

# Only run the sync once per PowerShell process
if (-not $env:PROFILE_SYNC_DONE) {
    $env:PROFILE_SYNC_DONE = '1'
    Write-Host "[PROFILE] Profile version: $profileVersion"

    $localPath = $PROFILE
    $tempPath  = Join-Path $env:TEMP 'Microsoft.PowerShell_profile.ps1.remote'

    try {
        # Cache-busted URL so GitHub raw doesn't hand you a stale file
        $cacheBuster = Get-Random
        $finalUrl    = 'https://raw.githubusercontent.com/mikesimone/.bashrc/refs/heads/main/Microsoft.PowerShell_profile.ps1?cb={0}' -f $cacheBuster

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
}
else {
    # Subsequent `. $PROFILE` in the same process: just show the version once, quietly.
    Write-Host "[PROFILE] Profile version: $profileVersion" -ForegroundColor DarkGray
}

function resync {
    Remove-Item Env:PROFILE_SYNC_DONE -ErrorAction SilentlyContinue
    . "$PROFILE"
}

# --- end auto-sync block -----------------------------------------------------
