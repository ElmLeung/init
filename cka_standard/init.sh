#!/bin/bash
mkdir /data
mkdir /srv/app-config
chmod 777 /data
k3d cluster create CkaCluster01 \
  --image rancher/k3s:v1.31.5-k3s1 \
  --servers 1   --agents 2 \
  --k3s-arg "--disable=traefik@server:*" \
  --k3s-arg '--disable=local-storage@server:*' \
  --volume '/data:/openebs-localpv@all' \
  --port '80:80@loadbalancer' \
  --port '443:443@loadbalancer'
# 清理k3d 自动安装traefik
kubectl delete helmchart traefik -n kube-system 2>/dev/null
# 部署 nginx ingressClass
kubectl apply -f nginx_deploy.yaml
# 检查 nginx ingress controller
kubectl wait -n ingress-nginx --for=condition=ready `kubectl get pods -n ingress-nginx -o name|grep controller` --timeout=180s
# 部署 csi-hostpath-driver
git clone https://github.com/kubernetes-csi/csi-driver-host-path.git
cd csi-driver-host-path
./deploy/kubernetes-1.31/deploy.sh
kubectl wait -n default --for=condition=ready pod/csi-hostpathplugin-0 --timeout=300s
cd ..
# 配置题目
kubectl config use-context k3d-CkaCluster01
kubectl apply -f kube_CkaCluster01.yaml

#ETCD 集群
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind
## docker cp ckaetcd-control-plane:/etc/kubernetes/pki/etcd/ca.crt .
## docker cp ckaetcd-control-plane:/etc/kubernetes/pki/etcd/server.crt .
## docker cp ckaetcd-control-plane:/etc/kubernetes/pki/etcd/server.key .
kind create cluster --name ckaetcd


kubectl run ckarestore --image=nginx

kubectl label pods -n kube-system --all exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-agent-0 exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-server-0 Taint=NoSchedule
k3d cluster create CkaCluster02 --agents 1
kubectl config use-context k3d-CkaCluster01


