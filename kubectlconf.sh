#!/bin/bash
for host in worker-0 worker-1; do
 kubectl config set-cluster kubernetes-the-hard-way \
 --certificate-authority=ca.crt \
 --embed-certs=true \
 --server=https://server.kubernetes.local:6443 \
 --kubeconfig=${host}.kubeconfig
done