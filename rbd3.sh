k3d cluster delete RBDcluster
k3d cluster create RBDcluster --servers 3 --agents 2 --image rancher/k3s:v1.22.2-k3s1 -p "5432-5435:5432-5435@loadbalancer" 

kubectl delete -f rbd-citus.yaml
kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-0
kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-1
kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-2
kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-3

kubectl apply -f rbd-citus.yaml

kubectl delete -f rbd-citus-coord.yaml
kubectl delete cm base-kubegres-config
kubectl delete pvc postgres-db-rbd-citus-coord-1-0
kubectl delete pvc postgres-db-rbd-citus-coord-2-0
kubectl delete pvc postgres-db-rbd-citus-coord-3-0


kubectl apply -f https://raw.githubusercontent.com/reactive-tech/kubegres/v1.12/kubegres.yaml
#kubectl get configmaps base-kubegres-config -o yaml | 
curl https://raw.githubusercontent.com/reactive-tech/kubegres/main/controllers/spec/template/yaml/BaseConfigMapTemplate.yaml | \
sed "s/md5/trust/g" | \
sed '/reject/d' | \
sed "/postgres.conf: |/ a \ \ \ \ shared_preload_libraries='citus'" | \
kubectl apply -f -
kubectl apply -f rbd-citus-coord.yaml

echo "postgres.conf: |" | sed "/postgres.conf: |/ a \ \ \ \ shared_preload_libraries='citus'"

kubectl exec -it rbd-citus-coord-1-0 -- /bin/bash

kubectl run -it dnsutils --image gcr.io/kubernetes-e2e-test-images/dnsutils:1.3
# Session ended, resume using 'kubectl attach dnsutils -c dnsutils -i -t' command when the pod is running
kubectl delete pod psql
kubectl run -it psql --image postgres:14.0 /bin/bash 
kubectl attach psql -c psql -i -t
kubectl cp ~/loggers psql:/

psql -h rbd-citus-coord -U postgres

#-c '/usr/bin/psql -h rbd-citus-coord -U postgres'

select * from pg_stat_replication  \x\g\x
select * from pg_stat_wal_receiver \x\g\x

SELECT inet_server_addr();

SET citus.shard_replication_factor = 2;
SET citus.replication_model TO 'streaming';



SELECT citus_set_coordinator_host('rbd-citus-coord', 5432);
SELECT * from citus_add_node('pgsql-citus-sts-0.pgsql-rbd-citus', 5432);
SELECT * from citus_add_node('pgsql-citus-sts-1.pgsql-rbd-citus', 5432);
SELECT * from citus_add_node('pgsql-citus-sts-2.pgsql-rbd-citus', 5432);

\i /loggers/loggers.sql
oraz oddzielnie:
SELECT create_distributed_table('organizations', 'or_id');
\i /loggers/organizations.dmp
oddzielnie:
SELECT create_distributed_table('loggers', 'lo_or_id', colocate_with => 'organizations');
\i /loggers/loggers.dmp

kubectl get events -o custom-columns=LastSeen:.lastTimestamp,From:.involvedObject.name,Reason:.reason --watch

select * from loggers where lo_or_id=261;

kubectl scale sts rbd-citus-coord-1  --replicas 0
kubectl scale sts rbd-citus-coord-2  --replicas 0
SELECT inet_server_addr();

select * from loggers where lo_or_id=261;

kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name --field-selector metadata.name=rbd-citus-coord-3-0

kubectl get sts -o wide


kubectl scale sts rbd-citus-coord-3  --replicas 0
kubectl scale sts rbd-citus-coord-3  --replicas 1

kubectl delete -f rbd-citus-coord.yaml
kubectl delete cm base-kubegres-config
kubectl delete pvc postgres-db-rbd-citus-coord-1-0
kubectl delete pvc postgres-db-rbd-citus-coord-2-0



