FROM python:3.10.6-slim

# install some tools
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    make \
    wget \
    curl \
    less \
    git \
    zsh \
    vim \
    sudo \
    sshpass \
    git-extras \
    openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean

# install docker in docker
RUN curl -fsSL https://get.docker.com | sh

# add the user
RUN useradd -md /home/clab -s /bin/zsh -u 1000 clab \
    && echo 'clab ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    # add clab user to docker group
    && usermod -aG docker clab \
    && usermod -aG sudo clab
USER clab
ENV HOME=/home/clab
ENV PATH=$PATH:/home/clab/.local/bin

WORKDIR /home/clab

# install zsh
RUN wget --quiet https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true \
    && echo 'PROMPT="%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )"' >> ${HOME}/.zshrc \
    && echo 'PROMPT+=" %{$fg[blue]%}(%{$fg[green]%}clab 🐳%{$fg[blue]%})%{$reset_color%}"' >> ${HOME}/.zshrc \
    && echo 'PROMPT+=" %{$fg[cyan]%}%c%{$reset_color%} $(git_prompt_info)"' >> ${HOME}/.zshrc \
    && echo 'plugins=(ansible common-aliases safe-paste git jsontools history git-extras)' >> ${HOME}/.zshrc \
    # redirect to &>/dev/null is required to silence `agent pid XXXX` message from ssh-agent
    && echo 'eval `ssh-agent -s` &>/dev/null' >> ${HOME}/.zshrc \
    && echo 'export TERM=xterm-256color' >>  $HOME/.zshrc \
    && echo "export LC_ALL=C.UTF-8" >> $HOME/.zshrc \
    && echo "export LANG=C.UTF-8" >> $HOME/.zshrc \
    && echo 'export PATH=$PATH:/home/clab/.local/bin' >> $HOME/.zshrc \
    && echo 'alias lab_start="sudo containerlab deploy -t ambassadors_custom_cfg.clab.yml --reconfigure"' >> $HOME/.zshrc \
    && echo 'alias lab_stop="sudo containerlab destroy -t ambassadors_custom_cfg.clab.yml --cleanup"' >> $HOME/.zshrc \
    && echo 'alias leaf1="sshpass -p admin ssh -o \"StrictHostKeyChecking no\" admin@clab-ambassadors_clab-leaf1"' >> $HOME/.zshrc \
    && echo 'alias leaf2="sshpass -p admin ssh -o \"StrictHostKeyChecking no\" admin@clab-ambassadors_clab-leaf2"' >> $HOME/.zshrc \
    && echo 'alias spine1="sshpass -p admin ssh -o \"StrictHostKeyChecking no\" admin@clab-ambassadors_clab-spine1"' >> $HOME/.zshrc \
    && echo 'alias spine2="sshpass -p admin ssh -o \"StrictHostKeyChecking no\" admin@clab-ambassadors_clab-spine2"' >> $HOME/.zshrc \
    && echo 'alias a_host="sshpass -p admin ssh -o \"StrictHostKeyChecking no\" admin@clab-ambassadors_clab-a_host"' >> $HOME/.zshrc

# install containerlab
RUN bash -c "$(curl -sL https://get.containerlab.dev)"

# install Ansible
RUN pip3 install "ansible-core>=2.11.3,<2.13.0" \
    # install community.general to support callback plugins in ansible.cfg, etc.
    && ansible-galaxy collection install community.general

# add entrypoint script
COPY ./entrypoint.sh /bin/entrypoint.sh
RUN sudo chmod +x /bin/entrypoint.sh
# use ENTRYPOINT instead of CMD to ensure that entryscript is always executed
ENTRYPOINT [ "/bin/entrypoint.sh" ]

# add gitconfig to be used if container is not called as VScode devcontainer
COPY ./gitconfig /home/clab/gitconfig-clab-base-template