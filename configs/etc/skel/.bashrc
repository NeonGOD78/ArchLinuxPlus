#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export PATH=$PATH:$HOME/.local/bin

eval "$(oh-my-posh init bash --config $HOME/.cache/oh-my-posh/themes/zen.toml)"
eval "$(fzf --bash)"

PS1='[\u@\h \W]\$ '


# Aliases
source $HOME/.aliases
