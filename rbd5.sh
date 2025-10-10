k3d cluster delete RBDcluster
k3d cluster create RBDcluster --servers 1 --agents 4 --image rancher/k3s:v1.22.2-k3s1 -p "5432-5435:5432-5435@loadbalancer" 
k3d cluster list
k3d node list

kubectl delete -f bdr.yaml

kubectl delete pvc pgsql-rbd-bdr-disk-pgsql-bdr-sts-0
kubectl delete pvc pgsql-rbd-bdr-disk-pgsql-bdr-sts-1
kubectl delete pvc pgsql-rbd-bdr-disk-pgsql-bdr-sts-1

	  


kubectl apply -f bdr.yaml
kubectl get sts --watch
kubectl cp ~/loggers pgsql-bdr-sts-0:/data
kubectl exec -it pgsql-bdr-sts-0 -- /bin/bash

kubectl exec -it pgsql-bdr-sts-0 -- /bin/bash


CREATE EXTENSION btree_gist;
CREATE EXTENSION bdr;

    SELECT bdr.bdr_group_create(
      local_node_name := 'bdr1_node',
      node_external_dsn := 'port=5432 dbname=postgres host=pgsql-bdr-sts-0.pgsql-rbd-bdr user=postgres password =rbd-bdr'
);

SELECT bdr.bdr_node_join_wait_for_ready();

SELECT bdr.bdr_group_join(
  local_node_name := 'bdr3_node',
  node_external_dsn 
     := 'port=5432 dbname=postgres host=pgsql-bdr-sts-2.pgsql-rbd-bdr user=postgres password=rbd-bdr',
  join_using_dsn 
    := 'port=5432 dbname=postgres host=pgsql-bdr-sts-0.pgsql-rbd-bdr user=postgres password=rbd-bdr ');


select node_name, case node_status when 'r' then 'ready' when 'k' then 'killed/removed' when 'i'then 'init' end as status, node_read_only from bdr.bdr_nodes;

update organizations set or_name='changed on node3' where or_id=1;
select * from organizations where or_id=1;

\i /data/loggers/loggers.sql
\i /data/loggers/organizations.dmp
\i /data/loggers/loggers.dmp
\i /data/loggers/measurements.dmp

kubectl scale sts pgsql-bdr-sts  --replicas 2 

update organizations set or_name='changed on node1' where or_id=1;
alter table organizations add column location varchar(50);

insert into organizations values(-10, 'rep3', 'CLIENT');
insert into organizations values(-10, 'rep4', 'CLIENT');

insert into organizations values(-20, 'rep5', 'CLIENT');
update organizations set or_name='new' where or_id=-20;

select * from organizations where or_id=-20;

ip link show


select * from organizations where or_id=-10;

wget www.cs.put.poznan.pl/jjezierski/RBDv2/loggers.zip
unzip loggers.zip

kubectl cp loggers pgsql-bdr-sts-0:/data
kubectl exec -it pgsql-bdr-sts-0 -- /bin/bash

kubectl cp  measurements_conflict_handler_upd_upd.sql pgsql-bdr-sts-0:/data

select * from bdr.bdr_conflict_handlers; 

kubectl scale sts pgsql-bdr-sts  --replicas 3 
alter table organizations add column location varchar(50);
\d organizations

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

