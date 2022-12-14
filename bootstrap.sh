#!/bin/bash

cd "$(dirname "$0")"

git pull
git submodule init
git submodule update

function dryRun() {
  rsync --exclude ".git/" --exclude ".DS_Store" --exclude "bootstrap.sh" --exclude "README.md" --exclude .gitmodules \
    --dry-run \
    --include ".**" \
    --archive --verbose . ~
}

function run() {
  rsync --exclude ".git/" --exclude ".DS_Store" --exclude "bootstrap.sh" --exclude "README.md" --exclude .gitmodules \
    --include ".**" \
    --archive --verbose . ~
}

if [ "$1" == "--force" -o "$1" == "-f" ]; then
  run
else
  dryRun
  read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    run
  fi
fi
unset doIt

source ~/.bash_profile

echo 'Done'
