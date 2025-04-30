#!/bin/bash

k3d cluster create CkaCluster01 --agents 2 \
  --k3s-arg "--disable=traefik@server:0" \
  -p "80:80@loadbalancer" \ 
  -p "443:443@loadbalancer

# 删除 Traefik 的 Deployment 和 Service
kubectl delete -n kube-system deploy traefik
kubectl delete -n kube-system svc traefik

# 确保删除 CRD (防止自动重建)
kubectl delete crd ingressroutes.traefik.io ingressroutetcps.traefik.io ingressrouteudps.traefik.io

kubectl apply -f nginx_deploy.yaml


kubectl config use-context k3d-CkaCluster01
kubectl apply -f k3d-CkaCluster01.yaml
kubectl label pods -n kube-system --all exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-agent-0 exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-server-0 Taint=NoSchedule
k3d cluster create CkaCluster02 --agents 1
docker exec -it k3d-CkaCluster01-agent-0 /bin/sh -c 'mkdir /data'
