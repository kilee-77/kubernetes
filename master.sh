#!/bin/bash

dnf update -y

#timezone setup
timedatectl set-timezone Asia/Seoul

#firewall disable
systemctl disable --now firewalld
setenforce 0

#IP Change
#sed -i 's/address1=192\.168\.0\.61\/24/address1=192\.168\.0\.200\/24/' /etc/NetworkManager/system-connections/ens33.nmconnection
#sed -i 's/method=auto/method=manual\naddress1=10.10.10.200\/24/' /etc/NetworkManager/system-connections/ens35.nmconnection
#nmcli connection reload
#nmcli connection up ens33
#nmcli connection up ens35

#swap 0, selinux off
swapoff -a
sed -i '/ swap / s/^#//' /etc/fstab
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
free -h
getenforce

#hostname rename
#hostnamectl set-hostname "master" && exec bash

#hosts
cat <<EOF | sudo tee -a /etc/hosts
10.10.10.200 master
10.10.10.201 work1
10.10.10.202 work2
10.10.10.203 work3
EOF

#IPtables
tee /etc/sysctl.d/kubernetes.conf<<EOF
net.brige.bridge-nf-call-ip6tables = 1
net.brige.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

#containerd kernel
tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sysctl --system

#dnf install -y dnf-utils device-mapper-persistent-data lvm2
#dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf update -y && dnf install -y containerd.io

mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1

sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable --now containerd



cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.31/rpm/repodata/repomd.xml.key
EOF

dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

systemctl enable --now kubelet

kubeadm init \
--control-plane-endpoint 192.168.0.200 \
--pod-network-cidr 10.10.10.0/24

#yum install -y wget

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/tigera-operator.yaml
wget https://raw.githubusercontent.com/projectcalico/calico/v3.28.1/manifests/custom-resources.yaml

sed -i 's/192\.168\.0\.0\/16/10.10.10.0\/24/g' custom-resources.yaml
kubectl apply -f custom-resources.yaml
