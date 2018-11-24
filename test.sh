#!/bin/bash
echo "Rozpoczynam proces testowania Cassandry dla:"
echo "Liczba testów: $1"
echo "Plik wynikowy: $2"

numOfTests=$1
output_file=$2

if [ ! -f /$output_file ] 
then
   output_file="result.csv"
   touch $output_file
fi

echo "workload;nodes;consistency_level;throughput" > $output_file

nodes=("1" "2" "4" "8")
hosts_all=("127.0.0.1" "127.0.0.2" "127.0.0.3" "127.0.0.4" "127.0.0.5" "127.0.0.6" "127.0.0.7" "127.0.0.8")
workload=("workloads/workloada" "workloads/workloadb" "workloads/workloadc" "workloads/workloadf" "workloads/workloadd" "workloads/workloade")
workloadByLetter=("A" "B" "C" "F" "D" "E")
consistency=("ONE" "TWO" "THREE" "ALL" "QUORUM" "ANY")

for nodeIX in ${!nodes[*]}
do
    sudo service cassandra stop
    sudo ccm create testCluster -v 2.0.9
    sudo ccm populate -n ${nodes[$nodeIX]}
    sudo ccm start
    sleep 5
    cqlsh -e "create keyspace ycsb with replication = {'class': 'SimpleStrategy', 'replication_factor':1};"
    echo "Step6"

    # Prepare hosts string
    hosts_string=""
    for (( ix=0; ix<${nodes[$nodeIX]}; ix++ ))
    do
        if [ $ix = 0 ] 
        then
            hosts_string+="${hosts_all[$ix]}"
        else
            hosts_string+=",${hosts_all[$ix]}"
        fi
    done

    # for every consistency level
    for consIX in ${!consistency[*]}
    do
        # load data
        cqlsh -e "use ycsb; drop table usertable;create table usertable (y_id varchar primary key, field0 varchar, field1 varchar, field2 varchar, field3 varchar, field4 varchar, field5 varchar, field6 varchar, field7 varchar, field8 varchar, field9 varchar);"
        ./bin/ycsb load cassandra-cql  -p hosts=$hosts_string -p cassandra.readconistencylevel=${consistency[$consIX]} -p cassandra.writeconsistencylevel=${consistency[$consIX]} -P workloads/workloada
        # for every workload
        for workIX in ${!workload[*]}
        do
            if [ ${workload[$workIX]} = "workloads/workloade" ]
            then
                cqlsh -e "use ycsb; drop table usertable;create table usertable (y_id varchar primary key, field0 varchar, field1 varchar, field2 varchar, field3 varchar, field4 varchar, field5 varchar, field6 varchar, field7 varchar, field8 varchar, field9 varchar);"
                ./bin/ycsb load cassandra-cql  -p hosts=$hosts_string -p cassandra.readconistencylevel=${consistency[$consIX]} -p cassandra.writeconsistencylevel=${consistency[$consIX]} -P workloads/workloada
            fi
            # for passed by user number of tests
            for (( testIX=1; testIX<=$numOfTests; testIX++ ))
            do
                if ( [ ${nodes[$nodeIX]} = "1" ] && ( [ ${consistency[$consIX]} = "TWO" ] || [ ${consistency[$consIX]} = "THREE" ] ) ) || ( [ ${nodes[$nodeIX]} = "2" ] && [ ${consistency[$consIX]} = "THREE" ] )
                then
                    resultThroughput=0
                else
                    resultThroughput=`./bin/ycsb run cassandra-cql  -p hosts=$hosts_string -p cassandra.readconistencylevel=${consistency[$consIX]} -p cassandra.writeconsistencylevel=${consistency[$consIX]} -P ${workload[$workIX]} | grep Throughput | cut -d ',' -f3 |  cut -c2- | cut -d '.' -f1`
                fi
                echo "${workloadByLetter[$workIX]};${nodes[$nodeIX]};${consistency[$consIX]};$resultThroughput" >> $output_file
            done
        done
    done

    sudo ccm stop
    sudo ccm remove testCluster
done