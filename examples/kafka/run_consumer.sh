#/bin/bash
set -x
TENANT=$1
CONFIGFILE=kafka.client.$TENANT.properties
TOPIC=$2
$KAFKA_HOME/bin/kafka-topics.sh --create --bootstrap-server=localhost:9093 --command-config=$CONFIGFILE --topic=$TOPIC --partitions=4  --replication-factor=1
$KAFKA_HOME/bin/kafka-console-consumer.sh --topic=$TOPIC --bootstrap-server=localhost:9093 --consumer.config=$CONFIGFILE
