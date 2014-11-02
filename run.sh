#!/bin/bash
initGit() {
    cd /
    mkdir -p -m 660 $GIT_DIR
    mkdir -p -m 774 $PROJECT_DIR

    chown -R $USER:root $GIT_DIR $PROJECT_DIR

    git init --bare --shared=0660
    git config --add receive.denyNonFastForwards false
    git config --add receive.denyCurrentBranch ignore
}

FORMAT='%Y-%m-%dT%H:%M:%SZ'

log() {
    echo -e "\e[93m[+] $(date -u +$FORMAT): \e[32m$1\e[0m"
}

wideenv() {
    echo "$1=$2" >> /etc/environment
}

export HOME=/home/$USER

MEM_LOG=/dev/shm/$USER
wideenv MEM_LOG "$MEM_LOG"
touch $MEM_LOG
chmod 0777 $MEM_LOG

useradd -s /bin/bash -m -d $HOME -g root $USER
mkdir -p -m 700 $HOME/.ssh

# Set Project
if [[ -z $PROJECT ]]; then
    export $PROJECT="project"
fi
wideenv PROJECT "$PROJECT"

# Check and authorize SSH key
if [[ -n $PUBLIC_KEY ]]; then
    if [[ -e "$PUBLIC_KEY" ]]; then
        log "Reading public key mount"
        cat $PUBLIC_KEY >> $HOME/.ssh/authorized_keys
    else
        log "Appending raw public key"
        echo $PUBLIC_KEY >> $HOME/.ssh/authorized_keys
    fi
else
    log "Missing public key"
    exit 1
fi

unset PUBLIC_KEY

chmod 600 $HOME/.ssh/authorized_keys
sed -ri "s@#?AuthorizedKeysFile\s+.*@AuthorizedKeysFile $HOME/.ssh/authorized_keys@" /etc/ssh/sshd_config
chown -R $USER:root $HOME/.ssh

log "Created user '$USER'"

# Disable root login
if [[ ! $PERMITROOTLOGIN ]]; then
    log "Disable root login"
    sed -ri 's/#?PermitRootLogin\s+.*/PermitRootLogin no/' /etc/ssh/sshd_config
else
    log "Enable root login"
    sed -ri 's/#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config
fi

# PROVISION SCRIPT/PATH
if [[ -e "/provision" ]]; then
    if [[ ! -d "/provision" ]]; then
        PROVISION=/provision
        log "Using $PROVISION"
        chmod +x /provision
    else
        log "Skipping /provision because its a folder"
    fi
fi

wideenv PROVISION "$PROVISION"
wideenv PROVISION_PATH "$PROVISION_PATH"

# Set default $GIT_DIR if is null or '.'
if [ -z $GIT_DIR ] || [ "$GIT_DIR" == "." ]; then
    export GIT_DIR=/$PROJECT.git
fi

# Set default $PROJECT_DIR if is null
if [[ -z $PROJECT_DIR ]]; then
    export PROJECT_DIR=/$PROJECT
fi

log "Set git dir '$GIT_DIR'"
log "Set project dir '$PROJECT_DIR'"

wideenv GIT_DIR "$GIT_DIR"
wideenv PROJECT_DIR "$PROJECT_DIR"

initGit

# Create git post-receive hook
log "Create git post-receive hook"
if [[ $(cd $GIT_DIR && git rev-parse --is-inside-work-tree) ]]
then
    if [[ $(cd $GIT_DIR && git rev-parse --is-bare-repository) ]]
    then
        touch $GIT_DIR/hooks/post-receive
        chmod +x $GIT_DIR/hooks/post-receive

(
cat <<POSTRECEIVE
#!/bin/bash

while read oldrev newrev refname
do
    branch=\$(git rev-parse --symbolic --abbrev-ref \$refname)
    path=\$PROJECT_DIR

    echo -e "\e[93m[^] $(date -u +$FORMAT): \e[32mStart update sources on '\$path' from '\$branch' branch\e[0m" >> \$MEM_LOG
        export GIT_WORK_TREE=\$path

    if [[ -e \$path ]]; then

        if [[ -d \$path ]]; then
            git checkout -f \$branch
            echo -e "\e[93m[^] $(date -u +$FORMAT): \e[32m [^] Updated sources on '\$path'\e[0m" >> \$MEM_LOG
            git log -1 --pretty=format:"%h - %an, %ar: %s" | xargs -I {} echo -e "-------------\n\e[35m\$branch\e[0m \e[32m{}\e[0m\n-------------" >> \$MEM_LOG

            if [ \${PROVISION} ]
            then
                \$PROVISION \$branch \$refname
            fi

            if [[ -n "\$PROVISION_PATH" ]]; then
                if [ -f "\$PROVISION_PATH" ]; then
                    echo -e "\e[93m[^] $(date -u +$FORMAT): \e[32mRUN '\$PROVISION_PATH \$branch \$refname'\e[0m" >> \$MEM_LOG
                    chmod +x \$PROVISION_PATH
                    \$PROVISION_PATH \$branch \$refname
                else
                    echo -e "\e[93m[^] $(date -u +$FORMAT): \e[32mSkipping \$PROVISION_PATH because its not a file\e[0m" >> \$MEM_LOG
                fi
            fi
        else
            echo -e "\e[93m[^] $(date -u +$FORMAT): \e[32mIgnoring push to \$branch because the path '\$path' isnt a folder\e[0m" >> \$MEM_LOG
        fi
    else
        echo -e "\e[93m[^] $(date -u +$FORMAT): \e[32m [X] Ignoring push to \$branch because the path '\$path' does not exist\e[0m" >> \$MEM_LOG
    fi
done
POSTRECEIVE
) > $GIT_DIR/hooks/post-receive

        log " [^] created git bare repo"
    else
        log " [X] invalid git bare repo"
        exit 3
    fi
fi

# Scripts
if [[ -e "/setup" ]]; then
    chmod +x /setup
    log "Executing setup script"
    /setup
    chmod -x /setup
fi


log "Deploy using this git remote url: ssh://$USER@host:port$GIT_DIR"

tail -f $MEM_LOG & $(which sshd) -D -E $MEM_LOG
