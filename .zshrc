#
# Logo
#

if hash neofetch 2> /dev/null; then
	neofetch
elif hash archey 2> /dev/null; then
	archey -c
fi

#
# p10k configuration
#

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

#
# oh-my-zsh configuration
#

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
ZSH_CUSTOM=$HOME/.oh-my-zsh-custom

# Which plugins would you like to load?
plugins=(grc kubectl pip pipenv rust terraform z zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting aws zsh-fzf-history-search tmux)

# auto-completion is provided by Arch Linux packages:
#	git docker pipenv
# auto-completion is provided by zsh-completions:
#	httpie

source $ZSH/oh-my-zsh.sh

#
# User configuration
#

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Load ~/.exports and ~/.aliases
for file in ~/.{exports,aliases}; do
	[ -r "$file" ] && source "$file"
done
unset file

# SCM breeze
[ -s "$HOME/.scm_breeze/scm_breeze.sh" ] && source "$HOME/.scm_breeze/scm_breeze.sh"

# nvm on Mac OS
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

export NVM_DIR="$HOME/.nvm"
[ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/usr/local/opt/nvm/etc/bash_completion.d/nvm" ] && . "/usr/local/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

# nvm on Arch Linux
[ -s "/usr/share/nvm/init-nvm.sh" ] && . "/usr/share/nvm/init-nvm.sh"
[ -s "/usr/share/nvm/bash_completion" ] && . "/usr/share/nvm/bash_completion"

# asdf
[ -s "/opt/homebrew/opt/asdf/asdf.sh" ] && . "/opt/homebrew/opt/asdf/asdf.sh"

# jabba
[ -s "/usr/local/opt/jabba/share/jabba/jabba.sh" ] && . "/usr/local/opt/jabba/share/jabba/jabba.sh"

# zsh-history-substring-search
# binds UP and DOWN arrow keys
bindkey "$terminfo[kcuu1]" history-substring-search-up
bindkey "$terminfo[kcud1]" history-substring-search-down

