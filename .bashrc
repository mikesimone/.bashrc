# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return;;
esac

########## Self-update from GitHub ##########
# This file is canonical in: mikesimone/.bashrc
# Raw URL:
BASHRC_REMOTE_URL="https://raw.githubusercontent.com/mikesimone/.bashrc/main/.bashrc"

if command -v curl >/dev/null 2>&1 && [ -n "$BASHRC_REMOTE_URL" ]; then
    BASHRC_LOCAL="$HOME/.bashrc"
    TMPFILE="${BASHRC_LOCAL}.tmp"

    # -z: only download if remote is newer than local (Last-Modified)
    if curl -fsS -z "$BASHRC_LOCAL" -o "$TMPFILE" "$BASHRC_REMOTE_URL"; then
        if [ -s "$TMPFILE" ]; then
            mv "$TMPFILE" "$BASHRC_LOCAL"
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

########## Color + ls helpers ##########
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

########## PATH tweaks ##########
export PATH=$PATH:/opt/rekall/bin
# Created by pipx
export PATH="$PATH:$HOME/.local/bin"

########## Windows Terminal tab title + color (autodetect) ##########
# We set both the tab title and a host-specific tab color.
# Palette indexes for WT tab color:
# 0=Black, 1=Red, 2=Green, 3=Yellow, 4=Blue, 5=Magenta,
# 6=Cyan, 7=White, 8=BrightBlack, 9=BrightRed, 10=BrightGreen,
# 11=BrightYellow, 12=BrightBlue, 13=BrightMagenta,
# 14=BrightCyan, 15=BrightWhite

set_win_decor() {
    # Tab title
    case "$TERM" in
        xterm*|rxvt*|*-256color)
            printf '\033]0;%s\007' "$USER@$HOSTNAME:${PWD/#$HOME/~}"
            ;;
    esac

    # Defaults if a host doesn't override:
    TAB_IDX=7   # bright/white-ish tab
    HOST_FG=36  # cyan @host text

    case "$HOSTNAME" in
        # Local Anton (if you ever run this inside WSL or similar)
        Anton|anton)
            if [ "$(id -u)" -eq 0 ]; then
                # Anton (Admin) = red tab, bright white text
                TAB_IDX=1
                HOST_FG=97
            else
                # Anton (non-admin) = cyan tab, bright white text
                TAB_IDX=6
                HOST_FG=97
            fi
            ;;
        sixofone|sixofone.*)
            # SixOfOne = magenta/pink tab, bright white text
            TAB_IDX=13
            HOST_FG=97
            ;;
        WOPR|wopr|wopr.*)
            # WOPR = yellow/brown tab, bright white text
            TAB_IDX=3
            HOST_FG=97
            ;;
        dhcphost|dhcphost.*)
            # dhcp host = blue tab, bright white text
            TAB_IDX=4
            HOST_FG=97
            ;;
        # Stubs / examples for future machines:
        FileServer1)
            TAB_IDX=2    # green
            HOST_FG=93   # bright yellow text
            ;;
        BackupNode)
            TAB_IDX=8    # dim gray
            HOST_FG=92   # bright green
            ;;
        BuildBox)
            TAB_IDX=11   # bright yellow
            HOST_FG=90   # bright black text
            ;;
        Sandbox)
            TAB_IDX=13   # bright magenta
            HOST_FG=97   # bright white
            ;;
        TestBench)
            TAB_IDX=10   # bright green
            HOST_FG=94   # bright blue
            ;;
        *)
            # Unknown hosts: neutral-ish white tab, cyan host text
            TAB_IDX=${TAB_IDX:-7}
            HOST_FG=${HOST_FG:-36}
            ;;
    esac

    # Export HOST_FG so PS1 can see it
    export HOST_FG

    # Apply tab color via Windows Terminal private escape
    printf '\e[2;15;'"${TAB_IDX}"',|'
}

if [ -n "$PROMPT_COMMAND" ]; then
    PROMPT_COMMAND="set_win_decor;$PROMPT_COMMAND"
else
    PROMPT_COMMAND="set_win_decor"
fi

########## Prompt ##########
# HOST_FG picked in set_win_decor; default if that somehow didn't run
# Default if somehow not set by set_win_decor
HOST_FG=${HOST_FG:-36}  # cyan

if [ "$(id -u)" -eq 0 ]; then
    # root prompt
    PS1='|\[\033[1;35m\]\t\[\033[0m\]| \[\e[1;31m\]\u\[\e[${HOST_FG}m\]@\h\[\e[0m\]:\[\e[1;32m\][\W]> \[\e[0m\]'
else
    # user prompt
    PS1='|\[\033[1;35m\]\t\[\033[0m\]| \[\e[1m\]\u\[\e[${HOST_FG}m\]@\h\[\e[0m\]:\[\e[1;32m\][\W]> \[\e[0m\]'
fi

