#!/bin/bash

mkdir -p  ~/repos
cd ~/repos
source /etc/os-release
if [ $VERSION -lt 8 ]
then
	PIP="pip"
	sudo dnf install -y vim vim-data git tmux fontconfig wget unzip tree sysstat collectl
else
	PIP="pip2"
	sudo dnf install -y vim git tmux fontconfig wget unzip tree sysstat
fi

# vim_config and tmux config
#for x in vim_config tmux_config; do
for x in vim_config; do
    git clone https://github.com/matthewoliver/$x
    cd $x
    ./setup.sh
    cd -
done
echo "let g:TerminusMouse=0" >> ~/.vimrc_overrides

echo 'export EDITOR=vim' >> ~/.bashrc
export EDITOR=vim

# git-vimdiff
cd ~/repos
git clone https://github.com/frutiger/git-vimdiff
cd ~/bin
ln -sf ~/repos/git-vimdiff/git-vimdiff.py git-vimdiff

# other useful tools
sudo $pip install pudb nose-pudb

cd
git clone https://github.com/matthewoliver/junk
cp junk/swift/swiftclient.env ~/

mkdir -p ~/tools
cd ~/tools
git clone https://github.com/markseger/getput
git clone https://github.com/swiftstack/ssbench
