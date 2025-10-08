k3d cluster delete RBDcluster
k3d cluster create RBDcluster --servers 3 --agents 2 --image rancher/k3s:v1.22.2-k3s1 -p "5432-5435:5432-5435@loadbalancer" 

kubectl delete -f rbd-citus.yaml
n
kubectl delete -f rbd-citus-coord.yaml
kubectl delete pvc postgres-db-rbd-citus-coord-1-0
kubectl delete pvc postgres-db-rbd-citus-coord-2-0
kubectl delete pvc postgres-db-rbd-citus-coord-3-0
kubectl delete pvc postgres-db-rbd-citus-coord-4-0

kubectl delete -f  rbd1.yaml
kubectl delete -f  rbd2.yaml

kubectl delete pvc pgsql-rbd1-disk-pgsql-rbd1-0
kubectl delete pvc pgsql-rbd2-disk-pgsql-rbd2-0

kubectl apply -f  rbd1.yaml
kubectl apply -f  rbd2.yaml

psql -U postgres -h localhost -p 5432 
alter system set wal_level=logical;
kubectl rollout restart sts pgsql-rbd1
psql -U postgres -h localhost -p 5433 

CREATE ROLE repl WITH REPLICATION LOGIN PASSWORD 'rbd1repl';

 
--create schema meas;
GRANT select ON ALL TABLES IN SCHEMA public TO repl;
--GRANT ALL PRIVILEGES ON DATABASE postgres TO repl;
--GRANT USAGE ON SCHEMA public TO repl;


CREATE PUBLICATION meas_publication;

--SET search_path TO meas;
\i ~/loggers/loggers.sql

GRANT select ON ALL TABLES IN SCHEMA public TO repl;

ALTER PUBLICATION meas_publication ADD TABLE organizations;
select pubname from pg_publication;
select * from pg_publication_tables;

create schema meas;
SET search_path TO meas;
drop SUBSCRIPTION meas_subscription;
CREATE SUBSCRIPTION meas_subscription CONNECTION 'host=pgsql-rbd1-lb port=5432 user=repl password=rbd1repl dbname=postgres' PUBLICATION meas_publication;
select * from pg_subscription;

\i ~/loggers/organizations.dmp

select subname as substription_name, relname as table_name, 
	case srsubstate
	when 'i' then 'initialize'
	when 'd' then 'data is being copied'
	when 's' then 'synchronized'
	when 'r' then 'ready (normal replication)'
	end
from pg_subscription_rel r join pg_subscription s on r.srsubid=s.oid
     join pg_class c on r.srrelid=c.oid

ALTER PUBLICATION meas_publication ADD TABLE loggers;
\i ~/loggers/loggers.dmp

ALTER SUBSCRIPTION meas_subscription REFRESH PUBLICATION;
select count(*) from loggers;

update organizations set or_name='Replikowana org1' where or_id=50;
select * from organizations where or_id=50;


insert into organizations values(50, 'Konflitowa', 'CLIENT');
insert into organizations values(-50, 'Nie Konflitowa', 'CLIENT');
select * from organizations where or_id=-50;

kubectl logs pgsql-rbd2-0 | tail

select s.subname, r.* 
from pg_subscription s join pg_replication_origin_status r on concat('pg_',s.oid)=r.external_id;

select roname, 
	 

