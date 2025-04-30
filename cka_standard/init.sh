#!/bin/bash

k3d cluster create CkaCluster01 --agents 2 --k3s-arg "--disable=traefik@server:*"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml


k3d cluster create mycluster --k3
kubectl config use-context k3d-CkaCluster01
kubectl apply -f k3d-CkaCluster01.yaml
kubectl label pods -n kube-system --all exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-agent-0 exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-server-0 Taint=NoSchedule
k3d cluster create CkaCluster02 --agents 1
docker exec -it k3d-CkaCluster01-agent-0 /bin/sh -c 'mkdir /data'
