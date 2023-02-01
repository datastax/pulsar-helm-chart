# Walk through this script manually, don't run the entire thing.
# This script is intended for use with examples/kafka/dev-values-tls-all-components-and-kafka-and-oauth2-low-resource.yaml.
# Works as of Pulsar 2.10_3.1
alias k=kubectl
kubectl config set-context -current -namespace=pulsar

# To redeploy cluster:
BASEDIR=/Users/devin.bost/proj/repos
helm upgrade pulsar $BASEDIR/pulsar-helm-chart/helm-chart-sources/pulsar --namespace pulsar --values $BASEDIR/pulsar-helm-chart/examples/kafka/dev-values-tls-all-components-and-kafka-and-oauth2-low-resource.yaml --create-namespace --debug
# Or, for full redeploy:
helm delete pulsar; k delete pvc --all; helm install pulsar $BASEDIR/pulsar-helm-chart/helm-chart-sources/pulsar --namespace pulsar --values $BASEDIR/pulsar-helm-chart/examples/kafka/dev-values-tls-all-components-and-kafka-and-oauth2-low-resource.yaml --create-namespace --debug

# SSH to bastion:
k exec -it pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- sh

# Deploy credentials obtained from Okta (https://www.youtube.com/watch?v=UQBrecHOXxU&ab_channel=DataStaxDevelopers) or other provider.
cat > /pulsar/conf/creds.json
{"client_id":"0oa7yp...7","client_secret":"CL08...1tF2bP","grant_type": "client_credentials"}

mkdir /pulsar/kafka && cd /pulsar/kafka
curl -LOs https://downloads.apache.org/kafka/3.3.1/kafka_2.12-3.3.1.tgz
tar -zxvf kafka_2.12-3.3.1.tgz
cd /pulsar/kafka/kafka_2.12-3.3.1/libs
curl -LOs https://github.com/datastax/starlight-for-kafka/releases/download/v2.10.3.0/oauth-client-2.10.3.0.jar
cd ..

# To test non-TLS endpoint.
# Make sure that the oauth parameters below map to your actual configs in the helm values file!
cat > /pulsar/kafka/kafka_2.12-3.3.1/config/producer.properties
bootstrap.servers=pulsar-proxy:9092
compression.type=none
sasl.login.callback.handler.class=com.datastax.oss.kafka.oauth.OauthLoginCallbackHandler
security.protocol=SASL_PLAINTEXT
sasl.mechanism=OAUTHBEARER
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule \
   required oauth.issuer.url="https://dev-...16.okta.com/oauth2/au...4l615d7"\
   oauth.credentials.url="file:///pulsar/conf/creds.json"\
   oauth.audience="api://pulsarClient"\
   oauth.scope="pulsar_client_m2m";
ctrl + d

cd /pulsar/kafka/kafka_2.12-3.3.1
bin/kafka-console-producer.sh --bootstrap-server PLAINTEXT://pulsar-broker:9092 --topic test --producer.config /pulsar/kafka/kafka_2.12-3.3.1/config/producer.properties


# Connect to bastion from another tab so we can watch the data come through:
k exec -it pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- sh
cd /pulsar
bin/pulsar-client consume persistent://public/default/test --subscription-name test-kafka1 --num-messages 0


# To watch logs in case there are any issues when producing:
k logs pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="proxy")].metadata.name}') --follow
k logs pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="broker")].metadata.name}') --follow
k exec -it pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- sh
cd /pulsar/kafka/kafka_2.12-3.3.1; bin/kafka-console-producer.sh --bootstrap-server PLAINTEXT://pulsar-proxy:9092 --topic test --producer.config /pulsar/kafka/kafka_2.12-3.3.1/config/producer.properties


#####
# To test against TLS endpoint from Kafka:
# Copy truststore from broker to bastion by first copying to local system. (Make sure you're not still in the bastion.)
k cp pulsar/pulsar-broker-0:/pulsar/tls.truststore.jks ~/Downloads/tls.truststore.jks
# Provide the expected bastion path (substitute for your pod name):
k cp ~/Downloads/tls.truststore.jks pulsar/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}'):/pulsar/tls.truststore.jks 

# Connect again to bastion pod:
k exec -it pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- sh

cat > /pulsar/kafka/kafka_2.12-3.3.1/config/producer.properties
# Update issuer url with your actual issuer url.
bootstrap.servers=pulsar-proxy:9093
compression.type=none
sasl.login.callback.handler.class=com.datastax.oss.kafka.oauth.OauthLoginCallbackHandler
security.protocol=SASL_SSL
sasl.mechanism=OAUTHBEARER
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule \
   required oauth.issuer.url="https://dev-42..16.okta.com/oauth2/aus7..l615d7"\
   oauth.credentials.url="file:///pulsar/conf/creds.json"\
   oauth.audience="api://pulsarClient"\
   oauth.scope="pulsar_client_m2m";
ssl.truststore.location=/pulsar/tls.truststore.jks 
# The identification algorithm must be empty
ssl.endpoint.identification.algorithm=
ctrl + d
cd /pulsar/kafka/kafka_2.12-3.3.1; bin/kafka-console-producer.sh --bootstrap-server SSL://pulsar-proxy:9093 --topic test --producer.config /pulsar/kafka/kafka_2.12-3.3.1/config/producer.properties
