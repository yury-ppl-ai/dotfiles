HISTSIZE=10000000
SAVEHIST=10000000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS

eval "$(brew shellenv)"

fpath=($HOMEBREW_PREFIX/share/zsh/site-functions $fpath)

autoload -U compinit
compinit

export PYENV_ROOT="$HOME/.pyenv"
export PYENV_VIRTUALENVWRAPPER_PREFER_PYVENV="true"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
pyenv virtualenvwrapper_lazy

export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/libpq/lib"
export CPPFLAGS="-I/opt/homebrew/opt/libpq/include"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libpq/lib/pkgconfig"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export AWS_DEFAULT_PROFILE=default

zsh_prompt() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        venv_full=`basename $VIRTUAL_ENV`
        venv="(${venv_full%%-*}) "
    else
        venv=""
    fi

    if [[ -z "$AWS_DEFAULT_PROFILE" || "$AWS_DEFAULT_PROFILE" == "default" ]]; then
        PS1="${venv}%n@local %1~ %# "
    else
        context=`kubectl config current-context 2>&1`
        if [ $? -ne 0 ]; then
                context=""
        else
            context=":$context"
        fi

        if [[ "$AWS_DEFAULT_PROFILE" == "prod" ]]; then
            PS1="[%B$AWS_DEFAULT_PROFILE$context%b] $venv%n@local %1~ %# "
        else
            PS1="[$AWS_DEFAULT_PROFILE$context] $venv%n@local %1~ %# "
        fi
    fi
}
precmd() { zsh_prompt; }

function install_clusters() {
    if [[ -z "$AWS_DEFAULT_PROFILE" ]]; then
        echo "AWS_DEFAULT_PROFILE must be set" 1>& 2
        return
    fi
    env="$AWS_DEFAULT_PROFILE"
    for cluster in $(aws eks list-clusters | jq -r '.clusters[]')
    do
       mkdir -p "$HOME/.kube/$env"
       region="us-east-1"
       if [[ "$cluster" == "ai-eval" ]]; then
           region="us-west-2"
       fi
       KUBECONFIG="$HOME/.kube/$env/$cluster" aws eks update-kubeconfig --name "$cluster" --region "$region" --alias "$cluster"
    done
}

function switch_workspace() {
    export AWS_DEFAULT_PROFILE=default
    export KUBECONFIG=/dev/null
    if [ -n "$1" ]; then
      export AWS_DEFAULT_PROFILE="$1"
      config="$HOME/.kube/$1/$2"
      if [ -n "$2" ]; then
	  if [ -f "$config" ]; then
	      export KUBECONFIG="$config"
	  else
	      echo "$config not found" 1>&2
	  fi
      fi
    fi
}

function safe() {
    switch_workspace
}

function sandbox() {
    switch_workspace sandbox "$1"
}

function _sandbox() {
    _arguments -s '1:cluster:_path_files -W ~/.kube/sandbox -g "*(.)"'
}

compdef _sandbox sandbox

function prod() {
    switch_workspace prod "$1"
}

function _prod() {
    _arguments -s '1:cluster:_path_files -W ~/.kube/prod -g "*(.)"'
}

compdef _prod prod

function ecrlogin() {
    if [[ "$AWS_DEFAULT_PROFILE"=="sandbox" ]]; then
    	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 706218807402.dkr.ecr.us-east-1.amazonaws.com
    elif [[ "$AWS_DEFAULT_PROFILE"=="prod" ]]; then
    	aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 699753309705.dkr.ecr.us-east-1.amazonaws.com
    else
        echo "No AWS environment set." >&2
    fi
}

alias jc="curl -H 'Content-Type: application/json'"

source ~/.secrets

PATH=$PATH:$HOME/.local/bin

alias dcl="docker compose -f $HOME/workspace/agi/infra/dev/docker-compose.yml"

function since_last_deploy() {
  git log --oneline --format="%h %s" $(kubectl -n web get deployment web-server -o=jsonpath='{$.spec.template.spec.containers[0].image}' | cut -d: -f2)...$(git rev-parse origin/main) | sed -E 's/\[[A-Z]{3,4}-[0-9]+\] //'
}

alias db-prod="psql $PROD_DB_RO"
alias db-analytics="psql $ANALYTICS_DB_RW"

alias l="ls --color -F"

alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"

function gg() {
    git grep "$@" -- ':!*.json'
}

# pnpm
export PNPM_HOME="/Users/yury/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end