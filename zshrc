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


zsh_prompt() {
    if [[ -z "$AWS_DEFAULT_PROFILE" ]]; then
        PS1="%n@%m %1~ %# "
    else
        context=`kubectl config current-context 2>&1`
        if [ $? -ne 0 ]; then
                context=""
        else
            context=":$context"
        fi

        if [[ "$AWS_DEFAULT_PROFILE" == "prod" ]]; then
            PS1="[%B$AWS_DEFAULT_PROFILE$context%b] %n@%m %1~ %# "
        else
            PS1="[$AWS_DEFAULT_PROFILE$context] %n@%m %1~ %# "
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
    export AWS_DEFAULT_PROFILE=
    export KUBECONFIG=/dev/null
    export AWS_DEFAULT_PROFILE="$1"
    config="$HOME/.kube/$1/$2"
    if [ -n "$2" ]; then
        if [ -f "$config" ]; then
            export KUBECONFIG="$config"
        else
            echo "$config not found" 1>&2
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
