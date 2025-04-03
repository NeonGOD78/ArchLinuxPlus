# OH_MY_POSH
# To enable another theme go to https://ohmyposh.dev/docs/themes and find your new theme
# Then go to your themes folder ~/.cache/oh-my-posh/themes/ and locate the theme
# Remember the filename of your theme and then change the line below to match filename.
eval "$(oh-my-posh init zsh --config $HOME/.cache/oh-my-posh/themes/zen.toml)"

# Aliases
source $HOME/.aliases

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

#RELOGIN_NOTICE
if grep -q "#RELOGIN_NOTICE" "$HOME/.zshrc"; then
    echo "⚠️  You need to relog to activate the newly installed addons! ⚠️"
    sed -i '/#RELOGIN_NOTICE/d' "$HOME/.zshrc"
fi
