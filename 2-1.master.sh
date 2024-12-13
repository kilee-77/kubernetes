#!/bin/bash
#dnf update
dnf update -y

#timezone setup
timedatectl set-timezone Asia/Seoul

#firewall disable
systemctl disable --now firewalld
setenforce 0

#swap 0, selinux off
swapoff -a
sed -i '/ swap / s/^#//' /etc/fstab
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
free -h
getenforce

#IPtables
tee /etc/sysctl.d/kubernetes.conf<<EOF
net.brige.bridge-nf-call-ip6tables = 1
net.brige.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

#containerd kernel
modprobe overlay
modprobe br_netfilter
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sysctl --system

#utils install
dnf install dnf-utils net-tools bind-utils iproute-tc wget curl* dnf-plugins-core device-mapper-persistent-data lvm2

#Containerd install
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf update -y && dnf install -y containerd.io

#Containerd modify
mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable --now containerd

#k8s repo 1.31 ver install
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl
EOF

dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

#k8s init by yaml (master only)
kubeadm config print init-defaults > ~/kubeadm-init.yaml

sed -i 's/advertiseAddress: 1.2.3.4/advertiseAddress: 192.168.0.200/' ~/kubeadmin-init.yaml
sed -i 's/name: node/name: master/' ~/kubeadmin-init.yaml
sed -i 's/serviceSubnet: 10.96.0.0\/12/serviceSubnet: 10.10.10.0\/16/' ~/kubeadmin-init.yaml

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

#CNI setting
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml

kubeadm token create --print-join-command
