k3d cluster delete RBDcluster
k3d cluster create RBDcluster --servers 1 --agents 4 --image rancher/k3s:v1.22.2-k3s1 -p "5432-5435:5432-5435@loadbalancer" 
k3d cluster list
k3d node list

git clone https://github.com/mongodb/mongodb-kubernetes-operator.git
kubectl apply -f config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
kubectl get crd/mongodbcommunity.mongodbcommunity.mongodb.com

kubectl apply -k config/rbac/

kubectl get role mongodb-kubernetes-operator
kubectl get rolebinding mongodb-kubernetes-operator
kubectl get serviceaccount mongodb-kubernetes-operator
kubectl create -f config/manager/manager.yaml
kubectl get pods
