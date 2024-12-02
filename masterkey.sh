#!/bin/bash

#token key 
echo token key:
sudo kubeadm token list
echo
echo sha256 key:
#sha256 key
sudo openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
