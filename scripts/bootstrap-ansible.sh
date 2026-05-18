#!/bin/bash

set -e

echo "=== ACTUALIZANDO SISTEMA ==="
apt-get update -y
apt-get upgrade -y

echo "=== INSTALANDO DEPENDENCIAS BASE ==="
apt-get install -y \
  software-properties-common \
  python3 \
  python3-pip \
  python3-venv \
  git \
  curl \
  vim \
  sshpass

echo "=== INSTALANDO ANSIBLE ==="
apt-add-repository --yes --update ppa:ansible/ansible
apt-get update -y
apt-get install -y ansible

pip3 install --upgrade pip

echo "=== LIBRERÍAS PYTHON ==="
pip3 install \
  kubernetes \
  openshift \
  pyyaml

ansible-galaxy collection install kubernetes.core

echo "=== HELM ==="
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "=== KUBECTL ==="
KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
curl -sLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl

echo "=== SSH KEYS ==="
if [ ! -f /home/vagrant/.ssh/id_ed25519 ]; then
  sudo -u vagrant ssh-keygen -t ed25519 -f /home/vagrant/.ssh/id_ed25519 -N ""
fi

echo "Bootstrap completado"