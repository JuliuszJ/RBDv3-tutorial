k3d cluster delete RBDcluster
k3d cluster create RBDcluster --servers 1 --agents 4 --image rancher/k3s:v1.22.2-k3s1 -p "5432-5435:5432-5435@loadbalancer" 
k3d cluster list
k3d node list

kubectl delete -f rbd-citus.yaml

kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-0
kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-1
kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-2
kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-3
kubectl delete pvc pgsql-rbd-citus-disk-pgsql-citus-sts-4

	  
kubectl apply -f rbd-citus.yaml
kubectl apply -f rbd2_citus.yaml

kubectl apply -f rbd-citus.yaml
kubectl get sts --watch



wget www.cs.put.poznan.pl/jjezierski/RBDv2/loggers.zip
unzip loggers.zip

kubectl cp loggers pgsql-citus-sts-0:/data
kubectl exec -it pgsql-citus-sts-0 -- /bin/bash

citusdata/citus:10.2.1

su - postgres
echo "local all all trust" > /data/pgdata/pg_hba.conf
echo "host all all 10.0.0.0/8 trust" >> /data/pgdata/pg_hba.conf
echo "host all all 127.0.0.1/32 trust" >> /data/pgdata/pg_hba.conf
echo "host all all ::1/128 trust" >> /data/pgdata/pg_hba.conf
su - postgres -c "/usr/lib/postgresql/14/bin/pg_ctl -D /data/pgdata/ reload"

/usr/lib/postgresql/14/bin/pg_ctl -D /data/pgdata/ reload

kubectl get pods -l name=pgsql-citus-sts

--koordynator
psql
SELECT citus_set_coordinator_host('pgsql-citus-sts-0.pgsql-rbd-citus', 5432);
SELECT * from citus_add_node('pgsql-citus-sts-1.pgsql-rbd-citus', 5432);
SELECT * from citus_add_node('pgsql-citus-sts-2.pgsql-rbd-citus', 5432);
select * from citus_get_active_worker_nodes();
SELECT start_metadata_sync_to_node(nodename, nodeport) FROM pg_dist_node;

drop table logger_types;
drop table measurements;
drop table loggers;
drop table organizations;

\i /data/loggers/loggers.sql
SELECT create_distributed_table('organizations', 'or_id');
SELECT create_distributed_table('loggers', 'lo_or_id', colocate_with => 'organizations');
SELECT create_distributed_table('measurements', 'me_or_id', colocate_with => 'organizations');


\i /data/loggers/organizations.dmp
\i /data/loggers/loggers.dmp
\i /data/loggers/measurements.dmp

UPDATE loggers SET lo_description='Fridge #23' where lo_id=622 and lo_or_id=138;


\i /data/loggers/logger_types.sql
SELECT create_reference_table('logger_types');
\i /data/loggers/logger_types.dmp

UPDATE logger_types SET lt_name='TypRejestratora2' WHERE lt_name='LoggerType2';

SET citus.replication_model TO 'streaming';

pgsql-citus-sts-0.pgsql-rbd-citus


psql -U postgres -h localhost -p 5432 postgres
select inet_server_addr()


kubectl scale sts pgsql-citus-sts  --replicas 4 

SELECT * from citus_add_node('pgsql-citus-sts-3.pgsql-rbd-citus', 5432);


kubectl run -it dnsutils \
  --image gcr.io/kubernetes-e2e-test-images/dnsutils:1.3

