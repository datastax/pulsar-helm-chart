#/bin/bash
set -x
KAFKA=~/dev/kop_test/kafka_2.13-3.0.0
CONFLUENT=~/dev/kop_test/confluent-7.0.0
TENANT=tenant5
CONFIGFILE=kafka.client.$TENANT.properties
TOPIC=$TENANT/kafka/test
#$KAFKA/bin/kafka-topics.sh --create --bootstrap-server=localhost:9093 --command-config=$CONFIGFILE --topic=$TOPIC --partitions=4  --replication-factor=1
#$KAFKA/bin/kafka-console-producer.sh --topic=$TOPIC --broker-list=localhost:9093 --producer.config=$CONFIGFILE
#$KAFKA/bin/kafka-console-consumer.sh --topic=$TOPIC --bootstrap-server=localhost:9093 --consumer.config=$CONFIGFILE


export SCHEMA_REGISTRY_OPTS="-Djavax.net.ssl.trustStore=cert.jks -Djavax.net.ssl.trustStoreType=jks -Djavax.net.ssl.trustStorePassword=pulsar"
$CONFLUENT/bin/kafka-avro-console-producer \
   --topic $TOPIC \
   --broker-list localhost:9093  \
   --producer.config $CONFIGFILE \
   --property value.schema='{"type":"record","name":"myrecord","fields":[{"name":"count","type":"int"}]}' \
   --property schema.registry.url=https://pulsar-broker.default.svc.cluster.local:8081 \
   --property basic.auth.credentials.source=USER_INFO \
   --property basic.auth.user.info=tenant5:token:eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJ0ZW5hbnQ1LWFkbWluIn0.lw-_gsGK8Q-aRMGBhJVBvQYazPgggbWd-KY1gVfeld8345vq-xQ3-g9feSZo4ORQz9iVF1molGpI4v_Co6r4PCdMzuP3zbScidVyfTNG6-tSm0m7-DjMvFJkbfjNG-sSm51mZr85uBrl2TcrRtqIccDPPRpQeqB_XIZz5k9SxUkWdqrstWuJgQ6zcw0wNGFPgoGJYFLLhvc6DY59kvCLKhVGY4aHBj1Cjky7VAsLQmn14vjzY7ZRqELdiSSbVlRPE_NctTjf3JpxjQIsN_qFbfu8lVUatCzTtDHGV4trEL_IOaZnsrPO6GnPBgtoq6eCGtnN6NxAY3pB07LTOGTrRQ
