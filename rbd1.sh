sudo yum install -y yum-utils
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
	
sudo yum -y install docker-ce-20.10.8 docker-ce-cli-20.10.8 containerd.io

sudo systemctl start docker
sudo systemctl enable docker

sudo usermod -aG docker rbd

//przelogowanie!!!



// Minikube

sudo yum -y install https://github.com/kubernetes/minikube/releases/download/v1.23.1/minikube-1.23.1-0.x86_64.rpm

minikube start
minikube tunnel

// k3d

curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v4.4.8 bash


cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo >/dev/null
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

sudo cp kubernetes.repo /etc/yum.repos.d/

sudo yum install -y kubectl-1.22.2


k3d cluster delete RBDcluster
k3d cluster create RBDcluster --servers 1 --agents 2 --image rancher/k3s:v1.22.2-k3s1 -p "5432-5433:5432-5433@loadbalancer" 
k3d cluster list
k3d node list

 

sudo yum -y install postgresql

13.4-bullseye, 13-bullseye, bullseye

sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
sudo yum -y install postgresql14-14.0

      --api-port [HOST:]HOSTPORT              
	  Specify the Kubernetes API server port exposed on the LoadBalancer (Format: [HOST:]HOSTPORT)
	  
kubectl apply -f rbd1.yaml
kubectl apply -f rbd2.yaml
kubectl get sts -watch

psql -U postgres -h 10.43.204.211 -p 30432 postgres

psql -U postgres -h localhost -p 5432 postgres

kubectl run -it dnsutils \
  --image gcr.io/kubernetes-e2e-test-images/dnsutils:1.3

drop USER MAPPING FOR postgres SERVER rbd2;

kubectl rollout restart sts pgsql-rbd1

kubectl scale sts pgsql-rbd2 --replicas=0

SET LOCAL lock_timeout = 10000;
SET LOCAL statement_timeout = 10000;
	  
apt install curl ca-certificates gnupg
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null	  
echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
apt update
apt-get -y install postgresql-13-cron

curl https://install.citusdata.com/community/deb.sh | bash

wget www.cs.put.poznan.pl/jjezierski/RBDv2/pg_cron.dockerfile
docker build -t rbd/postgres13 - < pg_cron.dockerfile
k3d image import rbd/postgres13 --cluster RBDcluster

alter system set shared_preload_libraries = 'pg_cron';
kubectl rollout restart sts pgsql-rbd1
CREATE EXTENSION pg_cron;

docker run -it postgres:13.4-bullseye /bin/bash


https://www.bmc.com/forms/beginning-kubernetes-ebook.html
