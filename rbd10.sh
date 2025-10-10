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


kubectl delete -f rbd-mongodb.yaml
kubectl delete pvc data-volume-rbd-mongodb-0
kubectl delete pvc data-volume-rbd-mongodb-1
kubectl delete pvc data-volume-rbd-mongodb-2
kubectl delete pvc data-volume-rbd-mongodb-3
kubectl delete pvc data-volume-rbd-mongodb-4
kubectl delete pvc logs-volume-rbd-mongodb-0
kubectl delete pvc logs-volume-rbd-mongodb-1
kubectl delete pvc logs-volume-rbd-mongodb-2
kubectl delete pvc logs-volume-rbd-mongodb-3
kubectl delete pvc logs-volume-rbd-mongodb-4

kubectl apply -f rbd-mongodb.yaml
kubectl get sts --watch



kubectl exec -it rbd-mongodb-0 --container mongod -- /bin/bash

mongo --username rbd-admin  --password rbd-mongo
use admin;
db.createUser(
    {
      user: "rbd-user",
      pwd: "rbd-mongo",
      roles: [
         { role: "readWrite", db: "test" }
      ]
    }
);

db.grantRolesToUser('rbd-admin', [{ role: 'readWrite', db: 'admin' }])
db.getUser("rbd-admin")

mongo --username rbd-user --password rbd-mongo

db.grantRolesToUser('rbd-admin', [{ role: 'root'}])

use test
db.pracownicy.insertOne({nazwisko: "Kowalski", etat: "Stazysta", placa: 2222})

kubectl run -it mongo-sh --image mongo:4.4.10-focal -- /bin/bash

kubectl scale sts rbd-mongo --replicas=2

rs.status().members.forEach( 
    function(z){ 
            printjson(z.name);
            printjson(z.stateStr);
    } 
   );

kubectl exec -it rbd-mongodb-1 --container mongod -- /usr/bin/kill 1

kubectl attach mongo-sh -c mongo-sh -i -t

kubectl exec -it rbd-mongodb-1 --container mongod -- /usr/bin/kill 1
kubectl exec -it rbd-mongodb-2 --container mongod -- /usr/bin/kill 1


kubectl create configmap configsvr --from-file=configsvr.yaml
kubectl describe configmaps configsvr

curl https://get.helm.sh/helm-v3.7.2-linux-amd64.tar.gz | tar -xf -
sudo mv linux-amd64/helm /usr/local/bin/

helm create ~/mongo-shrd

helm lint ~/mongo-shrd --set clusterRole=mongos
helm template ~/mongo-shrd --set clusterRole=configsvr 

helm repo add rbd https://rbdput.github.io/mongo-shrd-package/

helm repo list

helm pull rbd/mongo-shrd --untar --untardir ~
 


#27017
helm install mongo-configsvr ~/mongo-shrd --set clusterRole=configsvr --set replicas=1 --set port=27019 --set replSetName=configsvr

helm ls --all
kubectl exec -it mongo-configsvr-0 -- /bin/bash
mongo 127.0.0.1:27019
 
rs.initiate(
  {
    _id: "configsvr",
    configsvr: true,
    members: [
      { _id : 0, host : "mongo-configsvr-0.mongo-configsvr:27019" }
    ]
  }
) 

helm install mongo-shard-a ~/mongo-shrd --set clusterRole=shardsvr --set replicas=1 --set port=27018 --set replSetName=shard-a
helm install mongo-shard-b ~/mongo-shrd --set clusterRole=shardsvr --set replicas=1 --set port=27018 --set replSetName=shard-b
helm install mongo-shard-c ~/mongo-shrd --set clusterRole=shardsvr --set replicas=1 --set port=27018 --set replSetName=shard-c

kubectl exec -it mongo-shard-a-0 -- /bin/bash
mongo 127.0.0.1:27018

rs.initiate(
  {
    _id : "shard-a",
    members: [
      { _id : 0, host : "mongo-shard-a-0.mongo-shard-a:27018" }
    ]
  }
)

kubectl exec -it mongo-shard-b-0 -- /bin/bash
mongo 127.0.0.1:27018

rs.initiate(
  {
    _id : "shard-b",
    members: [
      { _id : 0, host : "mongo-shard-b-0.mongo-shard-b:27018" }
    ]
  }
)

kubectl exec -it mongo-shard-c-0 -- /bin/bash
mongo 127.0.0.1:27018

rs.initiate(
  {
    _id : "shard-c",
    members: [
      { _id : 0, host : "mongo-shard-c-0.mongo-shard-c:27018" }
    ]
  }
)


helm install mongo-mongos ~/mongo-shrd --set clusterRole=mongos --set replicas=2 --set port=27017 \
--set replSetName=mongos \
--set configDB='configsvr/mongo-configsvr-0.mongo-configsvr:27019'

kubectl exec -it mongo-mongos-0 -- /bin/bash
mongo

sh.addShard( "shard-a/mongo-shard-a-0.mongo-shard-a:27018")
sh.addShard( "shard-b/mongo-shard-b-0.mongo-shard-b:27018")
sh.addShard( "shard-c/mongo-shard-c-0.mongo-shard-c:27018")


use test;

sh.enableSharding("test")

db.createCollection("logger_types")

db.createCollection("organizations")
sh.shardCollection("test.organizations", {"_id":"hashed"})

db.createCollection("loggers")
sh.shardCollection("test.loggers", {"lo_or_id":"hashed"})

db.createCollection(
    "measurements",
    {
       timeseries: {
          timeField: "me_time",
          metaField: "metadata",
          granularity: "minutes"
       }
    }
)
sh.shardCollection("test.measurements", {"metadata":"hashed"})

kubectl cp loggers-json mongo-mongos-0:/data

mongoimport --db test --collection logger_types \
--file /data/loggers-json/logger_types.json

mongoimport --db test --collection organizations \
--file /data/loggers-json/organizations.json

mongoimport --db test --collection loggers \
--file /data/loggers-json/loggers.json

mongoimport --db test --collection measurements \
--file /data/loggers-json/measurements.json

sh.status() 

db.logger_types.getShardDistribution()
db.logger_types.explain().find()
		  
db.organizations.findOne()
db.organizations.getShardDistribution()

db.organizations.find({_id:30})

db.organizations.explain().find({_id:30})

db.loggers.explain().find({lo_or_id:30})
db.loggers.explain().find()

db.loggers.aggregate([
   {
     $lookup:
       {
         from: "organizations",
         localField: "lo_or_id",
         foreignField: "_id",
         as: "loggers-with-organizations"
       }
  }
])

db.loggers.explain().aggregate([
   {
     $lookup:
       {
         from: "organizations",
         localField: "lo_or_id",
         foreignField: "_id",
         as: "loggers-with-organizations"
       }
  }
])

db.organizations.aggregate([
  {$match: {
    _id: 30
     }
  },
   {
     $lookup:
       {
         from: "loggers",
         localField: "_id",
         foreignField: "lo_or_id",
         as: "loggers-of-org"
       }
  }
])

db.organizations.explain().aggregate([
  {$match: {
    _id: 30
     }
  },
   {
     $lookup:
       {
         from: "loggers",
         localField: "_id",
         foreignField: "lo_or_id",
         as: "loggers-of-org"
       }
  }
])

.explain()

metadata:{me_lo_id:$id,me_or_id:$lo_or_id}

db.loggers.explain().aggregate([
  {$match: {
    lo_or_id: 210
     }
  },
   {
     $lookup:
       {
         from: "measurements",
         localField: "_id",
         foreignField: "metadata.me_lo_id",
         as: "measurements-of-loggers"
       }
  }
])

  {$match: {
    lo_or_id: 210
     }
  },

db.loggers.explain({executionStats:"executionStats"}).aggregate([
  {$match: {
    lo_or_id: 73
     }
  },
   {
     $lookup:
       {
         from: "logger_types",
         localField: "lo_lt_id",
         foreignField: "_id",
         as: "type-of-loggers"
       }
  }
])

db.loggers.find(
{metadata:{me_lo_id:740,me_or_id:30}}
)

db.measurements.find({me_lo_id: 740})

helm install mongo-shard-d rbd/mongo-shrd --set clusterRole=shardsvr --set replicas=1 --set port=27018 --set replSetName=shard-d

kubectl exec -it mongo-shard-d-0 -- /bin/bash
mongo 127.0.0.1:27018

rs.initiate(
  {
    _id : "shard-d",
    members: [
      { _id : 0, host : "mongo-shard-d-0.mongo-shard-d:27018" }
    ]
  }
)

kubectl exec -it mongo-mongos-0 -- /bin/bash
mongo

sh.addShard( "shard-d/mongo-shard-d-0.mongo-shard-d:27018")

db.adminCommand( { split : "test.organizations", find : { _id : 99 } } )



(1-koszt)*przychod*0.19=przychod*0.14
1-koszt=14/19
koszt=1-14/19=0,263
		  

helm uninstall mongo-mongos --wait
kubectl delete pvc mongo-persistent-storage-mongo-mongos-0
kubectl delete pvc mongo-persistent-storage-mongo-mongos-1
helm uninstall mongo-shard-a --wait
kubectl delete pvc mongo-persistent-storage-mongo-shard-a-0
helm uninstall mongo-shard-b --wait
kubectl delete pvc mongo-persistent-storage-mongo-shard-b-0
helm uninstall mongo-shard-c --wait
kubectl delete pvc mongo-persistent-storage-mongo-shard-c-0
helm uninstall mongo-configsvr --wait
kubectl delete pvc mongo-persistent-storage-mongo-configsvr-0



kubectl cp loggers pgsql-postgresql-0:/bitnami/postgresql
kubectl exec -it pgsql-postgresql-0 -- /bin/bash
PGPASSWORD=BgCz4ALh4I psql -U postgres

COPY (
select ROW_TO_JSON(t) from
(select lt_id as _id, lt_name from logger_types) t
) to '/bitnami/postgresql/loggers-json/logger_types.json'
;

COPY (
select ROW_TO_JSON(t) from
(select or_id as _id, or_name, or_type from organizations) t
) to '/bitnami/postgresql/loggers-json/organizations.json'
;

COPY (
select ROW_TO_JSON(t) from
(select lo_id as _id, lo_description, lo_or_id, lo_lt_id from loggers) t
) to '/bitnami/postgresql/loggers-json/loggers.json'
;

COPY (
select ROW_TO_JSON(t) from
(select me_id as _id, me_time, me_temperature, me_lo_id, me_or_id from measurements) t
) to '/bitnami/postgresql/loggers-json/measurements.json'
;

kubectl cp  pgsql-postgresql-0:/bitnami/postgresql/loggers-json .


docker run -t -i --rm ubuntu:focal bash
apt-get update
apt-get -y install wget gnupg

wget -qO - https://www.mongodb.org/static/pgp/server-5.0.asc | apt-key add -


echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/5.0 multiverse" |  tee /etc/apt/sources.list.d/mongodb-org-5.0.list

https://repo.mongodb.org/apt/ubuntu/dists/focal/mongodb-org/5.0/multiverse/binary-amd64/mongodb-org-database_5.0.5_amd64.deb

echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/testing multiverse" |  tee /etc/apt/sources.list.d/mongodb-org-testing.list

https://repo.mongodb.org/apt/ubuntu/dists/focal/mongodb-org/testing/multiverse/binary-amd64/mongodb-org-unstable_5.2.0~rc4_amd64.deb

apt-get update

apt-get install -y mongodb-org-unstable-database=5.2.0~rc4 mongodb-org-unstable-tools=5.2.0~rc4

docker build 5.2-rc --build-arg MONGO_PACKAGE=mongodb-org-unstable -t rbd/mongodb:5.2.0-rc4

docker tag local-image:tagname new-repo:tagname
docker push new-repo:tagname 

docker tag rbd/mongodb:5.2.0-rc4 rbdput/mongodb:5.2.0-rc4
docker push rbdput/mongodb:5.2.0-rc4 

, adres:  {$arrayElemAt:["$zespol_pracownika.adres",0]} } }
    ,{$match: { {"adres": {$regex:/^STRZELECKA.*/m}}})


db.pracownicy.aggregate([ 
	{ $lookup: {from: "zespoly", localField: "id_zesp", foreignField: "id_zesp", as: "zespol_pracownika"} }
	, { $project: {"id_prac":1, "nazwisko":1, "zespol": {$arrayElemAt:["$zespol_pracownika.nazwa",0]}, "adres": {$arrayElemAt:["$zespol_pracownika.adres",0]} } }
	,{$match: { "adres": {$regex:/^STRZELECKA.*/m}}}
	])



