#!/bin/bash
mkdir /etcd_backup 
mkdir /srv/app-config
mkdir /data/etcd
chmod 777 /data
chmod 777 /etcd_backup
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
kubectl label pods -n kube-system --all exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-agent-0 exam-task=cka-demo
kubectl label nodes k3d-ckacluster01-server-0 Taint=NoSchedule

#ETCD 集群
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind

# 创建 Kind 集群，指定集群名字为 ckarestore
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ckaetcd02
nodes:
- role: control-plane
  image: m.daocloud.io/docker.io/kindest/node:v1.30.10
  extraMounts:
  - hostPath: /etcd_backup
    containerPath: /var/lib/etcd-backup
EOF

kubectl config use-context kind-ckaetcd
kubectl run ckarestore --image=nginx
# 安装 etcdctl
ETCD_VER=v3.5.4
GOOGLE_URL=https://storage.googleapis.com/etcd
GITHUB_URL=https://github.com/etcd-io/etcd/releases/download
DOWNLOAD_URL=${GOOGLE_URL}

rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

curl -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

sudo cp /tmp/etcd-download-test/etcdctl /etcd_backup

# 执行 etcd 备份
docker exec  ckaetcd-control-plane /bin/sh -c "cp /var/lib/etcd-backup/etcdctl /usr/local/bin && chmod +x /usr/local/bin/etcdctl"
docker exec  ckaetcd-control-plane /bin/bash -c "ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/server.crt  --key=/etc/kubernetes/pki/etcd/server.key  snapshot save /var/lib/etcd-backup/etcd-restore.db"

kubectl delete pod ckarestore


# 创建 CkaCluster02 集群
k3d cluster create CkaCluster02 --agents 1
kubectl config use-context k3d-CkaCluster01


ctr image push --user cn-south-1@HST3W111MYCGI0CHAG2I:65192383770272e284cb6456b559bc1ed5cee935ffc14537af8aae38b8705238 swr.cn-south-1.myhuaweicloud.com//{镜像名称}:{版本名称}
sudo docker tag kindest/node:v1.27.3 swr.cn-south-1.myhuaweicloud.com/elm/node:v1.27.3
sudo docker push swr.cn-south-1.myhuaweicloud.com/elm/node:v1.27.3