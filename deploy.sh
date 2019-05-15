#!/usr/bin/env bash

DIR=$(dirname "$0")

cd $DIR/

if [[ $(git status -s) ]]
then
    echo "The working directory is dirty. Please commit any pending changes."
    exit 1;
fi

echo "Deleting old publication"
rm -rf public
mkdir public
git worktree prune
rm -rf .git/worktrees/public/

echo "Checking out master branch into public"
git worktree add -B master public origin/master

echo "Removing existing files"
rm -rf public/*

echo "Generating site"
hugo || exit 1;

echo "blog.whatthedude.com" > public/CNAME

msg="deploy: `git log -1 --pretty=%B content --`"

if [ $# -eq 1 ]
  then msg="$1"
fi

echo "Commit message: $msg"
cd public && git add --all && git commit -m "$msg" && git push origin master
