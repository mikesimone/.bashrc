# ~/.bashrc – bootstrap into private Environment repo

# If not running interactively, bail out early
case $- in
    *i*) ;;
    *) return ;;
esac

ENV_DIR="$HOME/Environment"

# Clone or update the Environment repo
if command -v git >/dev/null 2>&1; then
    if [ ! -d "$ENV_DIR/.git" ]; then
        git clone git@github.com:mikesimone/Environment.git "$ENV_DIR" >/dev/null 2>&1 || \
            echo "[.bashrc] Failed to clone Environment repo; using local settings."
    else
        git -C "$ENV_DIR" pull --ff-only >/dev/null 2>&1 || \
            echo "[.bashrc] Failed to update Environment repo; using existing copy."
    fi
else
    echo "[.bashrc] git not found; cannot sync Environment repo."
fi

# If the private .bashrc exists, source it and stop
if [ -f "$ENV_DIR/.bashrc" ]; then
    # shellcheck source=/dev/null
    . "$ENV_DIR/.bashrc"
    return
fi

echo "[.bashrc] No Environment .bashrc found at $ENV_DIR/.bashrc; fallback only."
