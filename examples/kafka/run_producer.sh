#/bin/bash
set -x
TENANT=$1
TOPIC=$2
CONFIGFILE=kafka.client.$TENANT.properties
$KAFKA_HOME/bin/kafka-topics.sh --create --bootstrap-server=localhost:9093 --command-config=$CONFIGFILE --topic=$TOPIC --partitions=4  --replication-factor=1
$KAFKA_HOME/bin/kafka-console-producer.sh --topic=$TOPIC --broker-list=localhost:9093 --producer.config=$CONFIGFILE
