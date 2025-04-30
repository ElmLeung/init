#!/bin/bash
k3d cluster delete --all
k3d cluster create CkaCluster01 \
  --image rancher/k3s:v1.31.5-k3s1 \
  --servers 1   --agents 2 \
  --k3s-arg "--disable=traefik@server:*" \
  --port '80:80@loadbalancer' \
  --port '443:443@loadbalancer'
# 清理k3d 自动安装traefik
kubectl delete helmchart traefik -n kube-system 2>/dev/null
# 部署 nginx ingressClass
kubectl apply -f nginx_deploy.yaml
# 检查 nginx ingress controller
kubectl wait -n ingress-nginx --for=condition=ready `kubectl get pods -n ingress-nginx -o name|grep controller` --timeout=180s
# 部署题目
kubectl config use-context k3d-CkaCluster01
kubectl apply -f kube-CkaCluster01.yaml

kubectl label pods -n kube-system --all exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-agent-0 exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-server-0 Taint=NoSchedule
k3d cluster create CkaCluster02 --agents 1
#docker exec -it k3d-CkaCluster01-agent-0 /bin/sh -c 'mkdir /data'
