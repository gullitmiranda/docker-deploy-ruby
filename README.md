Docker Ruby Deploy [![Docker repo](http://img.shields.io/badge/docker-repo-blue.svg)](https://registry.hub.docker.com/u/gullitmiranda/deploy/)
================

Dockerized Git deploy through SSH service, built on top of [gullitmiranda/ruby](https://registry.hub.docker.com/u/gullitmiranda/ruby/) image. It uses git 'post-receive' hook and provides nice colored logs for each pushed commit.

This Dockerized image doesn't allow plain text logins, can only connect to it through the use of a public RSA key.

NOTE: This repository is based on [pocesar/docker-git-deploy](https://github.com/pocesar/docker-git-deploy)

## Image Tags

- `deploy:ruby` based on [gullitmiranda/ruby](https://registry.hub.docker.com/u/gullitmiranda/ruby/)
  + Ruby 2.1.2p95 (2014-05-08 revision 45877) [x86_64-linux]
  + Bundler 1.7.3

All images contains:
  - OpenSSH
  - Git and Git bare

## Setup

```bash
$ docker run -d \
  -p 1234:22 \
  --name deploy-ruby \
  -e PROJECT="project" \
  -e PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)" \
  -e PROVISION_PATH="./config/after_deploy.rb" \
  deploy:ruby

b5b5b70c523c6313d95860fd1c52af249a910a6933bee1a5e265866acc7ee17f
```

## Deploy

```bash
git remote add deploy ssh://git@localhost:1234/project.git # project.git is default $GIT_DIR
git push deploy master
```

## Get logs (with colors!)

```
$ docker logs deploy-ruby
[+] 2014-11-02T01:11:24Z: Appending raw public key
[+] 2014-11-02T01:11:24Z: Created user 'git'
[+] 2014-11-02T01:11:24Z: Enable root login
[+] 2014-11-02T01:11:24Z: Set git dir '/project.git'
[+] 2014-11-02T01:11:24Z: Set project dir '/project'
Initialized empty shared Git repository in /project.git/
[+] 2014-11-02T01:11:24Z: Create git post-receive hook
[+] 2014-11-02T01:11:24Z:  [^] created git bare repo
[+] 2014-11-02T01:11:24Z: Deploy using this git remote url: ssh://git@host:port/project.git
Server listening on 0.0.0.0 port 22.
Server listening on :: port 22.
Accepted publickey for git from 172.17.42.1 port 53207 ssh2: RSA e1:86:6c:66:d0:b1:0d:1d:ba:f9:ca:cf:70:53:b2:bc
[^] 2014-11-02T01:11:24Z: Start update sources on '/project' from 'develop' branch
[^] 2014-11-02T01:11:24Z:  [^] Updated sources on '/project"
-------------
develop be0d5d8 - Gullit Miranda, 2 weeks ago: [azk] update Azkfile.js to suport `mounts`
-------------
[^] 2014-11-02T01:11:24Z: Skipping ./config/after_deploy.rb because its not a file
Received disconnect from 172.17.42.1: 11: disconnected by user
```

## Settings

```
# Required
  PUBLIC_KEY = '" # Your mounted public key path inside the container

# Optional
  USER              # The user used in the git push, default is 'git'
  PERMITROOTLOGIN   # Allow login as root

  ### PATHs
  PROJECT           # Project name, also used to set the default GIT_DIR and PROJECT_DIR, default 'project'
  GIT_DIR           # The folder that holds the git bare repo, default '/$PROJECT.git'
  PROJECT_DIR       # The folder that receives the git checkout, default `/$PROJECT`

  ### Scripts
  PROVISION_PATH    # Path of the script to run after deploy
```

## Mods

You can inject your bash scripts into the `post-receive` hook by mounting your script to `-v /var/some/script.sh:/userscript`. It can be anything, like set folder / file permissions, execute `npm install`, `bower install` etc. and any type of language (if you install the needed binaries of course).

You can also use `echo "hello world" >> $MEM_LOG` to output stuff to the docker log from any of your scripts. Be aware that the user script will be called everytime there's a push.

The same goes for the setup script, in `-v /var/some/script.sh:/setup`, it will be called once the container is ran. Useful to install extra software you may need (like `ruby`, `node`, `jekyll`). Please note that those tools are ran inside the container, and you may only output or use the `$PROJECT_DIR` environment variables to execute your commands. Eg.:

```bash
#!/bin/bash

# this is /setup

apt-get -y -qq install nodejs
wget http://example.com/something.js > "$PROJECT_DIR/something.js"
echo "something.js downloaded" >> $MEM_LOG # goes to docker logs
```

```bash
#!/usr/bin/env nodejs

// this is /userscript

var
    path = require('path'), fs = require('fs');

# process.argv[1] === branch
# process.argv[2] === gitref

if (process.argv[1] === 'master') {
    fs.chmodSync(path.join(process.env.PROJECT_DIR, 'cache'), '0774');
}
```
