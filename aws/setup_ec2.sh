#!/bin/bash
# see https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave-cli-install.html

# upgrade all packages to newest version
sudo dnf upgrade

# install nitro-cli
sudo dnf install aws-nitro-enclaves-cli aws-nitro-enclaves-cli-devel -y

# verify the installation
nitro-cli --version

# allow user to run nitro-cli+docker
sudo usermod -aG ne ec2-user
sudo usermod -aG docker ec2-user

echo 'alias la="ls -lah"' >> ~/.bashrc
echo 'BUCKET=nitro-enclaves-result-bucket' >> ~/.bashrc
echo 's3sr() { aws s3 cp "$1" s3://"$BUCKET"/; }' >> ~/.bashrc

# enable the nitro & docker service
sudo systemctl enable --now nitro-enclaves-allocator.service
sudo systemctl enable --now docker

# install useful tools
sudo dnf install @"Development Tools" git gdb make cmake perf tmux numactl rsync htop python3.11 -y

# configure python
mkdir -p $HOME/.local/bin
ln -s $(which python3.11) $HOME/.local/bin/python
python -m ensurepip --upgrade
python -m pip install --upgrade pip

# install brendan gregg's cloud perf-tools
# git clone git@github.com:brendangregg/pmc-cloud-tools.git ~/.pmc-cloud-tools
# echo 'export PATH=$HOME/.pmc-cloud-tools:$PATH' >> ~/.bash_profile

# allow perf to run without root
sudo sysctl -w kernel.perf_event_paranoid=-1

# reload the shell
source ~/.bashrc
