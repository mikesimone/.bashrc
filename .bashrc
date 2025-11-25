# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return;;
esac

########## Optional self-update from GitHub ##########
# Put this same file in a GitHub repo and point BASHRC_REMOTE_URL at its raw URL.
# Example: https://raw.githubusercontent.com/YOUR_GITHUB_USER/YOUR_REPO/main/.bashrc
BASHRC_REMOTE_URL="https://raw.githubusercontent.com/YOUR_GITHUB_USER/YOUR_REPO/main/PATH/TO/bashrc"

if command -v curl >/dev/null 2>&1 && [ -n "$BASHRC_REMOTE_URL" ]; then
    BASHRC_LOCAL="$HOME/.bashrc"
    TMPFILE="${BASHRC_LOCAL}.tmp"

    # -z only downloads if remote is newer than local (based on Last-Modified)
    if curl -fsS -z "$BASHRC_LOCAL" -o "$TMPFILE" "$BASHRC_REMOTE_URL"; then
        if [ -s "$TMPFILE" ]; then
            mv "$TMPFILE" "$BASHRC_LOCAL"
            # Re-source updated file and stop executing the old body
            # shellcheck source=/dev/null
            . "$BASHRC_LOCAL"
            return
        else
            rm -f "$TMPFILE"
        fi
    fi
fi

########## History tuning ##########
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend cmdhist histverify
HISTSIZE=50000
HISTFILESIZE=100000
HISTTIMEFORMAT='%F %T '
HISTIGNORE='ls:ll:l:cd:pwd:clear:history'

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Only set DISPLAY for SSH sessions if not already set
if [ -n "$SSH_CONNECTION" ] && [ -z "$DISPLAY" ]; then
    export DISPLAY=localhost:0.0
fi

# make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

########## Prompt ##########
if [ "$(id -u)" -eq 0 ]; then
    # root prompt
    PS1='|\[\033[1;35m\]\t\[\033[0m\]| \[\e[1;31m\]\u\[\e[1;36m\]@\h\[\e[0m\]:\[\e[1;32m\][\W]> \[\e[0m\]'
else
    # user prompt
    PS1='|\[\033[1;35m\]\t\[\033[0m\]| \[\e[1m\]\u\[\e[1;36m\]@\h\[\e[0m\]:\[\e[1;32m\][\W]> \[\e[0m\]'
fi

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# alert alias for long-running commands
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'


# Load extra aliases if present
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

set -o noclobber
export PATH=$PATH:/opt/rekall/bin

########## DNS helper ##########
dns() {
    if ! command -v dig >/dev/null 2>&1; then
        echo "dig not found" >&2
        return 1
    fi
    [ -z "$1" ] && { echo "Usage: dns <domain>"; return 1; }

    echo
    echo "DMARC Record:"
    dig txt "_dmarc.$1" +short

    echo
    echo "SPF Record:"
    dig txt "$1" +short | grep "spf1\|spf2"

    echo
    echo "MX Record(s):"
    dig mx "$1" +short
    echo
}

########## Windows Terminal tab title + color (autodetect) ##########
set_win_decor() {
    # Tab title first
    case "$TERM" in
        xterm*|rxvt*|*-256color)
            printf '\033]0;%s\007' "$USER@$HOSTNAME:${PWD/#$HOME/~}"
            ;;
    esac

    # Tab color: use WT private escape \e[2;15;N,|
    # N is a 0–15 palette index. This case block is the fun part.
    case "$HOSTNAME" in
        # Local Anton (if you ever run this inside WSL on Anton)
        Anton|anton)
            if [ "$(id -u)" -eq 0 ]; then
                # Anton (Admin) = red
                printf '\e[2;15;1,|'
            else
                # Anton (non-elevated) = teal (cyan)
                printf '\e[2;15;6,|'
            fi
            ;;
        sixofone|sixofone.*)
            # SixOfOne = pink (magenta)
            printf '\e[2;15;5,|'
            ;;
        WOPR|wopr|wopr.*)
            # WOPR = brown/yellow-ish
            printf '\e[2;15;3,|'
            ;;
        dhcphost|dhcphost.*)
            # dhcphost = blue
            printf '\e[2;15;4,|'
            ;;
        *)
            # Unknown host stub: neutral white/gray.
            # When you add a new machine, just add a new case above this.
            printf '\e[2;15;7,|'
            ;;
    esac
}

if [ -n "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="set_win_decor;$PROMPT_COMMAND"
else
    PROMPT_COMMAND="set_win_decor"
fi

# Created by `pipx` on 2025-11-21 05:15:51
export PATH="$PATH:/home/msimone/.local/bin"
