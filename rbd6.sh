k3d cluster delete RBDcluster
k3d cluster create RBDcluster --servers 1 --agents 4 --image rancher/k3s:v1.22.2-k3s1 -p "5432-5435:5432-5435@loadbalancer" 
k3d cluster list
k3d node list

k3d image import

kubectl delete -f ora1.yaml
kubectl delete -f ora2-stand.yaml

kubectl delete pvc ora-rbd1-disk-ora-rbd1-0
kubectl delete pvc ora-rbd2-disk-ora-rbd2-0

	  
kubectl apply -f ora-headless-service.yaml

kubectl apply -f ora1.yaml
kubectl apply -f ora2-stand.yaml
kubectl get sts --watch


kubectl exec -it ora-rbd1-0 -- /bin/bash
export ORACLE_HOME=/opt/oracle/product/18c/dbhomeXE/
export ORACLE_SID=XE
export PATH=$ORACLE_HOME/bin:${PATH}
export TNS_ADMIN=/opt/oracle/oradata/dbconfig/XE

sqlplus pdbadmin/rbd1@XEPDB1
sqlplus pdbadmin/rbd2@RBD2

sed -i "s/XEPDB1 =/RBD1/g" ~/tnsnames.ora

    # To create a standby database referred by PRIMARY_DB_CONN_STR
    STANDBY_DB=false \
    # Env var below should be in <HOST>:<PORT>/<SERVICE_NAME> format
    PRIMARY_DB_CONN_STR="" \

	
# Clone DB/ Standby DB creation path
if [[ "${STANDBY_DB}" == "true" ]]; then
  # Reverting umask to original value for clone/standby DB cases
  umask 022

  # Validation: Check if PRIMARY_DB_CONN_STR is provided or not
  if [[ -z "${PRIMARY_DB_CONN_STR}" ]] || [[ $PRIMARY_DB_CONN_STR != *:*/* ]]; then
    echo "ERROR: Please provide PRIMARY_DB_CONN_STR in <HOST>:<PORT>/<SERVICE_NAME> format to connect with primary database. Exiting..."
    exit 1
  fi

  # Primary database parameters extration
  PRIMARY_DB_NAME=$(echo "${PRIMARY_DB_CONN_STR}" | cut -d '/' -f 2)

	# Creating standby database
	dbca -silent -createDuplicateDB -gdbName "$PRIMARY_DB_NAME" -primaryDBConnectionString "$PRIMARY_DB_CONN_STR" ${DBCA_CRED_OPTIONS} -sid "$ORACLE_SID" -createAsStandby -dbUniquename "$ORACLE_SID" ORACLE_HOSTNAME="$ORACLE_HOSTNAME" ||
	  cat /opt/oracle/cfgtoollogs/dbca/"$ORACLE_SID"/"$ORACLE_SID".log ||
	  cat /opt/oracle/cfgtoollogs/dbca/"$ORACLE_SID".log

  # Remove temporary response file
  if [ -f "$ORACLE_BASE"/dbca.rsp ]; then
    rm "$ORACLE_BASE"/dbca.rsp
  fi

  exit 0
fi	

cat <<EOT >> /opt/oracle/oradata/dbconfig/XE/listener.ora
SID_LIST_LISTENER=(SID_LIST=
 (SID_DESC=(SID_NAME=XE)))
EOT

lsnrctl stop
lsnrctl start

startup mount
alter database archivelog;
alter database open;
ALTER DATABASE FORCE LOGGING;
ALTER SYSTEM SWITCH LOGFILE;

ALTER DATABASE ADD STANDBY LOGFILE GROUP 4 ('/opt/oracle/oradata/XE/redo04.log') SIZE 200M;

su oracle -c "dbca -silent -createDuplicateDB -gdbName $PRIMARY_DB_NAME -primaryDBConnectionString $PRIMARY_DB_CONN_STR -sid $ORACLE_SID -createAsStandby -dbUniquename $ORACLE_SID"

su oracle
PRIMARY_DB_NAME=$(echo "${PRIMARY_DB_CONN_STR}" | cut -d '/' -f 2)
dbca -silent -createDuplicateDB -gdbName "$PRIMARY_DB_NAME" -primaryDBConnectionString "$PRIMARY_DB_CONN_STR" -sid "$ORACLE_SID" -createAsStandby -dbUniquename "$ORACLE_SID" ORACLE_HOSTNAME="$ORACLE_HOSTNAME" 

sqlplus sys/rbd1@localhost:1521/XE as sysdba

rman TARGET sys/rbd1@ora-rbd1-lb:1521/XE AUXILIARY sys/rbd1@localhost:1521/XE
run
{
   backup as copy reuse
   passwordfile auxiliary format  '/opt/oracle/product/18c/dbhomeXE/dbs/orapwXE'   ;
}
