#!/bin/bash

DOCKER_SOCKET=/var/run/docker.sock
DOCKER_GROUP=docker
USER=clab
HOME_DIR=/home/clab

GITCFGFILE=${HOME_DIR}/.gitconfig

# if container is called as devcontainer from VScode, .gitconfig must be present
if [ -f ${GITCFGFILE} ]; then
  rm -f ${HOME_DIR}/gitconfig-clab-base-template
# if no .gitconfig created by VScode, copy base template and edit
else
  mv ${HOME_DIR}/gitconfig-clab-base-template ${HOME_DIR}/.gitconfig
  # Update gitconfig with username and email
  if [ -n "${GIT_USER}" ]; then
    echo "Update gitconfig with ${GIT_USER}"
    sed -i "s/USERNAME/${GIT_USER}/g" ${HOME_DIR}/.gitconfig
  else
    echo "Update gitconfig with default username"
    sed -i "s/USERNAME/clab Base USER/g" ${HOME_DIR}/.gitconfig
  fi
  if [ -n "${GIT_EMAIL}" ]; then
    echo "Update gitconfig with ${GIT_EMAIL}"
    sed -i "s/USER_EMAIL/${GIT_EMAIL}/g" ${HOME_DIR}/.gitconfig
  else
    echo "Update gitconfig with default email"
    sed -i "s/USER_EMAIL/clab-base@arista.com/g" ${HOME_DIR}/.gitconfig
  fi
fi

if [ -S ${DOCKER_SOCKET} ]; then
    sudo chmod 666 /var/run/docker.sock &>/dev/null
fi

# execute command from docker cli if any
if [ ${@+True} ]; then
  exec "$@"
# otherwise just enter zsh
else
  exec zsh
fi