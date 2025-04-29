# OH_MY_POSH

OH_MY_POSH_PATH="$HOME/.local/bin/oh-my-posh"
if [[ ! -f "$OH_MY_POSH_PATH" ]]; then
    curl -s https://ohmyposh.dev/install.sh | bash > /dev/null 2>&1
fi
export PATH=$PATH:$HOME/.local/bin

# To enable another theme go to https://ohmyposh.dev/docs/themes and find your new theme
# Then go to your themes folder ~/.cache/oh-my-posh/themes/ and locate the theme
# Remember the filename of your theme and then change the line below to match filename.

eval "$(oh-my-posh init zsh --config $HOME/.cache/oh-my-posh/themes/zen.toml)"

# Aliases
source $HOME/.aliases

# ZINIT - read the documentation for usage: https://zdharma-continuum.github.io/zinit/wiki/INTRODUCTION/
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# ZINIT - Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# ZINIT - Add in snippets
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward
bindkey '^[w' kill-region

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Shell integrations
eval "$(fzf --zsh)"
eval "$(zoxide init --cmd cd zsh)"

# History
HISTORY_FILE="$HOME/.config/zsh/zsh_history"
if [[ ! -f "$HISTORY_FILE" ]]; then
        mkdir -p "$(dirname "$HISTORY_FILE")"
        touch "$HISTORY_FILE"
fi
HISTSIZE=5000
HISTFILE=$HISTORY_FILE
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups
