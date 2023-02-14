# This file needs to be merged into the readme file.

# Walk through this script manually, don't run the entire thing.
# This script is intended for use with examples/dev-values-tls-all-components-and-kafka-and-oauth2-low-resource.yaml.
# Works as of Pulsar 2.10_3.1

alias k=kubectl
kubectl config set-context -current -namespace=pulsar

# Set the appropriate values in the openid section of the Helm chart values file:
openid:
  enabled: true
  # From token generated in Okta UI or other method:
  issuerUrl: https://dev-42506116.okta.com/oauth2/aus7ypk6sjvgF4l615d7
  scope: pulsar_client_m2m
  client_id: "0oa7ypwvxnvo9xnDd5d7"
  client_secret: "CL08ZNhF91fsCUm7rtYqHs-XUak5H7gLY01tF2bP"
  withS4k: true

# To redeploy cluster:
BASEDIR=/Users/YOUR_USER/proj/repos
helm upgrade pulsar $BASEDIR/pulsar-helm-chart/helm-chart-sources/pulsar --namespace pulsar --values $BASEDIR/pulsar-helm-chart/examples/kafka/dev-values-tls-all-components-and-kafka-and-oauth2-low-resource.yaml --create-namespace --debug
# Or, for full redeploy:
helm delete pulsar; k delete pvc --all; helm install pulsar $BASEDIR/pulsar-helm-chart/helm-chart-sources/pulsar --namespace pulsar --values $BASEDIR/pulsar-helm-chart/examples/kafka/dev-values-tls-all-components-and-kafka-and-oauth2-low-resource.yaml --create-namespace --debug

# To test against TLS endpoint from Kafka:
# Copy truststore from broker to bastion by first copying to local system. (Make sure you're not still in the bastion.)
k cp pulsar/pulsar-broker-0:/pulsar/tls.truststore.jks ~/Downloads/tls.truststore.jks
# Provide the expected bastion path:
k cp ~/Downloads/tls.truststore.jks pulsar/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}'):/pulsar/tls.truststore.jks 

# SSH to bastion:
k exec -it pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- bash


### Use Pulsar client with non-TLS endpoint in Pulsar with token auth:
bin/pulsar-perf produce -r 1000 --size 1024 --auth_plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params file:///pulsar/token-superuser-stripped.jwt --service-url pulsar://pulsar-proxy.pulsar.svc.cluster.local:6650/ persistent://public/default/test
### Use Pulsar client with TLS endpoint in Pulsar with token auth:
bin/pulsar-perf produce -r 1000 --size 1024 --auth_plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params file:///pulsar/token-superuser-stripped.jwt --service-url pulsar+ssl://pulsar-proxy.pulsar.svc.cluster.local:6651/ persistent://public/default/test

## OIDC Setup:
cat > /pulsar/conf/creds.json
{"client_id":"0oa7ypwvxnvo9xnDd5d7","client_secret":"CL08ZNhF91fsCUm7rtYqHs-XUak5H7gLY01tF2bP","grant_type": "client_credentials"}

### Use Pulsar client with non-TLS endpoint in Pulsar with OIDC:
bin/pulsar-perf produce -r 1000 --size 1024 --auth-plugin "org.apache.pulsar.client.impl.auth.oauth2.AuthenticationOAuth2" --auth-params '{"privateKey":"/pulsar/conf/creds.json","issuerUrl":"https://dev-42506116.okta.com/oauth2/aus3thh6rqs3FU45X697","scope":"pulsar_client_m2m","audience":"api://pulsarClient"}' --service-url pulsar://pulsar-proxy.pulsar.svc.cluster.local:6650/ persistent://public/default/test
### Use Pulsar client with TLS endpoint in Pulsar with OIDC:
bin/pulsar-perf produce -r 1000 --size 1024 --auth-plugin "org.apache.pulsar.client.impl.auth.oauth2.AuthenticationOAuth2" --auth-params '{"privateKey":"/pulsar/conf/creds.json","issuerUrl":"https://dev-42506116.okta.com/oauth2/aus3thh6rqs3FU45X697","scope":"pulsar_client_m2m","audience":"api://pulsarClient"}' --service-url pulsar+ssl://pulsar-proxy.pulsar.svc.cluster.local:6651/ persistent://public/default/test


# Deploy credentials obtained from Okta (https://www.youtube.com/watch?v=UQBrecHOXxU&ab_channel=DataStaxDevelopers) or other provider.
# Note: The Kafka endpoints occasionally change as they lifecycle versions of Kafka releases. If you have an error when unpacking
#     the tarball, you might be curling a 404, so be sure to check that the URL hasn't changed.
mkdir /pulsar/kafka && cd /pulsar/kafka
curl -LOs https://downloads.apache.org/kafka/3.3.2/kafka_2.12-3.3.2.tgz
tar -zxvf /pulsar/kafka/kafka_2.12-3.3.2.tgz
cd /pulsar/kafka/kafka_2.12-3.3.2/libs
curl -LOs https://github.com/datastax/starlight-for-kafka/releases/download/v2.10.3.0/oauth-client-2.10.3.0.jar
cd ..

########
# To test OpenID/OAuth2 on non-TLS endpoint:
# Make sure that the oauth parameters below map to your actual configs in the helm values file!
cat > /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties
bootstrap.servers=pulsar-proxy:9092
compression.type=none
sasl.login.callback.handler.class=com.datastax.oss.kafka.oauth.OauthLoginCallbackHandler
security.protocol=SASL_PLAINTEXT
sasl.mechanism=OAUTHBEARER
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule \
   required oauth.issuer.url="https://dev-42506116.okta.com/oauth2/aus7ypk6sjvgF4l615d7"\
   oauth.credentials.url="file:///pulsar/conf/creds.json"\
   oauth.audience="api://pulsarClient"\
   oauth.scope="pulsar_client_m2m";
ctrl + c

cd /pulsar/kafka/kafka_2.12-3.3.2; bin/kafka-console-producer.sh --bootstrap-server PLAINTEXT://pulsar-proxy:9092 --topic test --producer.config /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties


# Connect to bastion from another tab so we can watch the data come through:
k exec -it pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- bash
cd /pulsar
bin/pulsar-client consume persistent://public/default/test --subscription-name test-kafka2 --num-messages 0


# To watch logs in case there are any issues when producing:
k logs pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="proxy")].metadata.name}') --follow
k logs pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="broker")].metadata.name}') --follow
k exec -it pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- bash
cd /pulsar/kafka/kafka_2.12-3.3.2; bin/kafka-console-producer.sh --bootstrap-server PLAINTEXT://pulsar-proxy:9092 --topic test --producer.config /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties

# Connect again to bastion pod:
k exec -it pod/$(kg pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- bash


##### 
## To test OpenID/OAuth2 on TLS endpoint:
cat > /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties
bootstrap.servers=pulsar-proxy:9093
compression.type=none
ssl.truststore.location=/pulsar/tls.truststore.jks 
security.protocol=SASL_SSL
sasl.login.callback.handler.class=com.datastax.oss.kafka.oauth.OauthLoginCallbackHandler
sasl.mechanism=OAUTHBEARER
# The identification algorithm must be empty
ssl.endpoint.identification.algorithm=
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule \
   required oauth.issuer.url="https://dev-42506116.okta.com/oauth2/aus7ypk6sjvgF4l615d7"\
   oauth.credentials.url="file:///pulsar/conf/creds.json"\
   oauth.audience="api://pulsarClient"\
   oauth.scope="pulsar_client_m2m";

ctrl + c
cd /pulsar/kafka/kafka_2.12-3.3.2; bin/kafka-console-producer.sh --bootstrap-server SSL://pulsar-proxy:9093 --topic test --producer.config /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties

# Import Grafana dashboard via UI for S4K on local machine:

cd ~/Downloads; curl -LOs https://raw.githubusercontent.com/datastax/starlight-for-kafka/2.10_ds/grafana/dashboard.json

###### 
# To test token auth on non-TLS endpoint:
cat > /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties
bootstrap.servers=pulsar-proxy:9092
compression.type=none
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule \
   required username="public/default"\
   password="token:eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzdXBlcnVzZXIifQ.xVMf-lCZgR8eagjXVQiSKO4Sib1O-jz06uE8SGteH3QW4TnozMRaI_13yIancrjzb7Q_4-9tvXXCO7p_9HOVNmRF2gyAVcL1qhfs3DgmTWgGk1-Iuj9J8yITvVnemH-6E9bER7e62yRw39zHjhuWe7_5DY6ZcdX1MOCYMK7qn3Xmx1LdSaujOUxbIvx3QLZAsqnnWSG9VXV_mpKHgnj5UHZNIqKgqSqHyE5t5Bo9Qft4BS5ArVtAOB6_sTECEKIUfA4X0L2b6jHszMk2TmsujBIEHPlo66SFyDQl0MlOhvSjiOi43OZ8PcNAGYn2EYT_3aQqqQLLHHzDl7-owoBr0g";
ctrl + c
# When publishing this doc, we should automate getting the superuser token via the line below:
$(cat /pulsar/token-superuser-stripped.jwt)
cd /pulsar/kafka/kafka_2.12-3.3.2; bin/kafka-console-producer.sh --bootstrap-server PLAINTEXT://pulsar-proxy:9092 --topic test --producer.config /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties

######
# To test token auth with TLS endpoint:
cat > /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties
bootstrap.servers=pulsar-proxy:9093
compression.type=none
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule \
required username="public/default" password="token:eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJzdXBlcnVzZXIifQ.xVMf-lCZgR8eagjXVQiSKO4Sib1O-jz06uE8SGteH3QW4TnozMRaI_13yIancrjzb7Q_4-9tvXXCO7p_9HOVNmRF2gyAVcL1qhfs3DgmTWgGk1-Iuj9J8yITvVnemH-6E9bER7e62yRw39zHjhuWe7_5DY6ZcdX1MOCYMK7qn3Xmx1LdSaujOUxbIvx3QLZAsqnnWSG9VXV_mpKHgnj5UHZNIqKgqSqHyE5t5Bo9Qft4BS5ArVtAOB6_sTECEKIUfA4X0L2b6jHszMk2TmsujBIEHPlo66SFyDQl0MlOhvSjiOi43OZ8PcNAGYn2EYT_3aQqqQLLHHzDl7-owoBr0g";
ssl.truststore.location=/pulsar/tls.truststore.jks
# The identification algorithm must be empty
ssl.endpoint.identification.algorithm=

ctrl + c

cd /pulsar/kafka/kafka_2.12-3.3.2; bin/kafka-console-producer.sh --bootstrap-server SSL://pulsar-proxy:9093 --topic test --producer.config /pulsar/kafka/kafka_2.12-3.3.2/config/producer.properties

