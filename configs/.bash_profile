# Bash login shells should retain Ubuntu's ~/.profile behaviour.
# Ubuntu's default ~/.profile already sources ~/.bashrc when Bash is in use.
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
elif [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
