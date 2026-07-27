# ~/.bashrc: executed by Bash for interactive non-login shells.

# Do nothing for non-interactive shells.
case $- in
    *i*) ;;
    *) return ;;
esac

# ---------------------------------------------------------------------------
# History and shell behaviour
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
# Identify a Debian/Ubuntu chroot in the prompt.
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(< /etc/debian_chroot)
fi

# ---------------------------------------------------------------------------
# PATH and development tools
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}
path_prepend "$HOME/.local/bin"
export PYENV_ROOT="$HOME/.pyenv"
path_prepend "$PYENV_ROOT/bin"
export PATH
unset -f path_prepend
if command -v pyenv >/dev/null 2>&1; then
    eval "$(pyenv init - bash)"
fi
export EDITOR="nano"
export VISUAL="$EDITOR"

# ---------------------------------------------------------------------------
# Ubuntu-style colored prompt
force_color_prompt=yes
if [ -n "${force_color_prompt:-}" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi
if [ "${color_prompt:-}" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]{\[\033[01;34m\]\w\[\033[00m\]}: '
else
   PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt
# Set the terminal title to user@host:directory.
case "$TERM" in
    xterm*|rxvt*)
        PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
        ;;
esac

# ---------------------------------------------------------------------------
# Colors, completion, and ordinary command aliases
if [ -x /usr/bin/dircolors ]; then
    if [ -r "$HOME/.dircolors" ]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
fi
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi
# Use `sleep 10; alert` to notify when a long-running command finishes.
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history | tail -n1 | sed -e '\''s/^[[:space:]]*[0-9]\+[[:space:]]*//;s/[;&|][[:space:]]*alert$//'\'')"'

# ---------------------------------------------------------------------------
# Enhanced terminal tools
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons=auto --group-directories-first'
    # alias ll='eza -lah --icons=auto --group-directories-first --git'
    # alias la='eza -a --icons=auto --group-directories-first'
    alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
fi
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi
if command -v ff-blue >/dev/null 2>&1; then
    alias fastfetch='ff-blue'
    alias ff='ff-blue'

    if [ -z "${RICE_FASTFETCH_SHOWN:-}" ] &&
            [ ! -f "$HOME/.no_fastfetch" ]; then
        export RICE_FASTFETCH_SHOWN=1
        ff-blue
    fi
fi

# ---------------------------------------------------------------------------
# Administration and Ubuntu package shortcuts
alias root='sudo -i'
alias cls='clear'
alias please='sudo'
alias turnoff='sudo poweroff'
alias reboot-now='sudo reboot'
alias reboot='sudo reboot'
alias ports='ss -tulpen'
alias myip='ip -brief addr'
# These names avoid shadowing /usr/bin/install and preserve `systemctl --user`.
alias update='sudo apt update'
alias upgrade='sudo apt full-upgrade'
alias install='sudo apt install'
alias purge='sudo apt purge'
alias autoremove='sudo apt autoremove'
# Keep the two spellings already used in the Arch configuration.
alias instally='sudo apt install -y'
alias instaly='sudo apt install -y'
alias remove='sudo apt purge'
alias auto-remove='sudo apt autoremove'

# Root-level service and journal helpers. The real systemctl and journalctl
# commands remain untouched for commands such as `systemctl --user`.
sctl() {
    sudo systemctl "$@"
}

jctl() {
    sudo journalctl "$@"
}

