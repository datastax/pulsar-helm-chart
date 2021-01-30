[![GitHub](https://avatars1.githubusercontent.com/u/9919?s=30&v=4)](https://github.com/datastax/pulsar-helm-chart) 
[![CircleCI](https://circleci.com/gh/datastax/pulsar-helm-chart.svg?style=svg)](https://circleci.com/gh/datastax/pulsar-helm-chart)
[![LICENSE](https://img.shields.io/hexpm/l/pulsar.svg)](https://github.com/datastax/pulsar-helm-chart/blob/master/LICENSE)

# Helm Chart for an Apache Pulsar Cluster

This Helm chart configures an Apache Pulsar cluster. It is designed for production use, but can also be used in local development environments with the proper settings.

It includes support for:
* [TLS](#tls)
* [Authentication](#authentication)
* WebSocket Proxy
* Standalone Functions Workers
* Pulsar IO Connectors
* [Tiered Storage](#tiered-storage) including Tardigarde distributed cloud storage
* [Pulsar SQL Workers](#pulsar-sql)
* [Admin Console](#managing-pulsar-using-admin-console) for managing the cluster
* [Pulsar heartbeat](https://github.com/datastax/pulsar-heartbeat)
* [Burnell](https://github.com/datastax/burnell) for API-based token generation
* Prometheus/Grafana/Alertmanager [stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) with default Grafana dashboards and Pulsar-specific alerting rules
* cert-manager with support for self-signed certificates as well as public certificates using ACME (for example, Let's Encrypt)
* Ingress configuration for all HTTP ports (Admin Console, Prometheus, Grafana, etc)

[Helm](https://helm.sh) must be installed and initialized to use the chart. Only Helm 3 is supported.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

## Minikube quick start

Make sure you have minikube [installed](https://minikube.sigs.k8s.io/docs/start/) and running (`minikube start`).

Install the Helm chart:

```
helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart
helm repo update
curl -LOs https://datastax.github.io/pulsar-helm-chart/examples/dev-values.yaml
helm install pulsar -f dev-values.yaml --wait datastax-pulsar/pulsar
```

The Helm command waits until all pods are up, which take about 5 minutes.

In another terminal, start the minikube tunnel:

```
minikube tunnel
```

Open your browser to http://localhost to view the Admin Console:

![Admin Console](assets/admin_console.png?raw=true "Admin Console")


Can view the embedded Grafana charts using the Cluster/Monitoring menu in the Admin Console:

![Grafana in Admin Console](assets/grafana.png?raw=true "Grafana in Admin Console")

Grafana is password protected. The username is `admin`. You can get the password with this command:

```
kubectl get secret pulsar-grafana -o=jsonpath="{.data.admin-password}" | base64 --decode
```


## Quick start

With Helm installed with access to a Kubernetes cluster (ex minikube):

```
helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart
helm repo update
curl -LOs https://datastax.github.io/pulsar-helm-chart/examples/dev-values.yaml
helm install pulsar -f dev-values.yaml datastax-pulsar/pulsar
```

Once all the pods are running (takes 5 to 10 minutes), you can access the admin console by forwarding to localhost: 

```kubectl port-forward $(kubectl get pods -l component=adminconsole -o jsonpath='{.items[0].metadata.name}') 8888:80```

Then open a browser to http://localhost:8888. In the admin console you can test your Pulsar setup using the built-in clients (Test Clients in the left-hand menu).

If you also forward the Grafana port, like this:

```kubectl port-forward $(kubectl get pods -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000```

You can view metrics for the Pulsar cluster the Cluster, Monitoring menu item. You will have to log into Grafana. The username is `admin` and the password is in the downloaded file `dev-values.yaml` under the `adminPassword` setting.

To use the Pulsar admin and client tools (ex pulsar-admin, pulsar-client, pulsar-perf), log into the bastion pod:

```kubectl exec $(kubectl get pods -l component=bastion -o jsonpath="{.items[*].metadata.name}") -it -- /bin/bash```

You will find the tools in the `/pulsar/bin` directory.


## Add to local Helm repository 
To add this chart to your local Helm repository:

```helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart```

To update to the latest chart:

```helm repo update```

Note: This command updates all your Helm charts.

To list the version of the chart in the local Helm repository:

```helm search repo datastax-pulsar```


## Installing Pulsar in a Cloud Provider

Before you can install the chart, you need to configure the storage class settings for your cloud provider. The handling of storage varies from cloud provider to cloud provider.

Create a new file called ```storage_values.yaml``` for the storage class settings. To use an existing storage class (including the default one) set this value:

```
default_storage:
  existingStorageClassName: default or <name of storage class>
```
For each volume of each component (Zookeeper, Bookkeeper), you can override the `default_storage` setting by specifying a different `existingStorageClassName`. This allows you to match the optimum storage type to the volume. 

If you have specific storage class requirement, for example fixed IOPS disks in AWS, you can have the chart configure the storage classes for you. Here are examples from the cloud providers:

```
# For AWS
# default_storage:
#  provisioner: kubernetes.io/aws-ebs
#  type: gp2
#  fsType: ext4
#  extraParams:
#     iopsPerGB: "10"


# For GCP
# default_storage:
#   provisioner: kubernetes.io/gce-pd
#   type: pd-ssd
#   fsType: ext4
#   extraParams:
#      replication-type: none

# For Azure
# default_storage:
#   provisioner: kubernetes.io/azure-disk
#   fsType: ext4
#   type: managed-premium
#   extraParams:
#     storageaccounttype: Premium_LRS
#     kind: Managed
#     cachingmode: ReadOnly
```
See the [values file](https://github.com/datastax/pulsar-helm-chart/blob/master/helm-chart-sources/pulsar/values.yaml) for more details on these settings.

Once you have your storage settings in the values file, install the chart like this :

```
helm install pulsar datastax/pulsar --namespace pulsar --values storage_values.yaml --create-namespace
```

## Installing Pulsar for development

This chart is designed for production use, but it can be used in development enviroments. To use this chart in a development environment (ex minikube), you need to:

* Disable anti-affinity rules that ensure components run on different nodes
* Reduce resource requirements
* Disable persistence (configuration and messages are not stored so are lost on restart). If you want persistence, you will have to configure storage settings that are compatible with your development enviroment as described above.

For an example set of values, download this [values file](https://github.com/datastax/pulsar-helm-chart/blob/master/examples/dev-values.yaml). Use that values file or one like it to start the cluster:


```
helm install pulsar -f dev-values.yaml datastax-pulsar/pulsar
```

## Accessing the Pulsar cluster in cloud

The default values will create a ClusterIP for all components. ClusterIPs are only accessible within the Kubernetes cluster. The easiest way to work with Pulsar is to log into the bastion host:

```
kubectl exec $(kubectl get pods -l component=bastion -o jsonpath="{.items[*].metadata.name}") -it -- /bin/bash
```
Once you are logged into the bastion, you can run Pulsar admin commands:

```
bin/pulsar-admin tenants list
```
For external access, you can use a load balancer. Here is an example set of values to use for load balancer on the proxy:

```
proxy:
 service:
    type: LoadBalancer
```

If you are using a load balancer on the proxy, you can find the IP address using:

```kubectl get service```

## Accessing the Pulsar cluster on localhost

To port forward the proxy admin and Pulsar ports to your local machine:

```kubectl port-forward -n pulsar $(kubectl get pods -l component=proxy -o jsonpath='{.items[0].metadata.name}') 8080:8080```

```kubectl port-forward -n pulsar $(kubectl get pods -l component=proxy -o jsonpath='{.items[0].metadata.name}') 6650:6650```

Or if you would rather go directly to the broker:

```kubectl port-forward -n pulsar $(kubectl get pods -l component=broker -o jsonpath='{.items[0].metadata.name}') 8080:8080```

```kubectl port-forward -n pulsar $(kubectl get pods -l component=broker -o jsonpath='{.items[0].metadata.name}') 6650:6650```

## Managing Pulsar using Admin Console


You can install the Pulsar admin console in your cluster by enabling with this values setting:

```
component:
  pulsarAdminConsole: yes
```

It will be automatically configured to connect to the Pulsar cluster.

By default, the admin console has authentication disabled. You can enabled authentication with these settings:

```
pulsarAdminConsole:
    authMode: k8s
```
When `k8s` authentication mode is enabled, the admin console gets the users from Kubernetes secrets that start with `dashboard-user-` in the same namespace where it is deployed. The text that follows the prefix is the username. For example, for a user `admin` you need to have a secret `dashboard-user-admin`. The secret data must have a key named `password` with the base-64 encoded password. The following command will create a secret for a user `admin` with a password of `password`:

```
kubectl create secret generic dashboard-user-admin --from-literal=password=password
```

You can create multiple users for the admin console by creating multiple secrets. To change the password for a user, delete the secret then recreate it with a new password:

```
kubectl delete secret dashboard-user-admin
kubectl create secret generic dashboard-user-admin --from-literal=password=newpassword
```

For convenience, the Helm chart is able to create an initial user for the admin console with the following settings:

```
pulsarAdminConsole:
    createUserSecret:
      enabled: yes
      user: 'admin'
      password: 'password'
```

### Accessing Admin Console on your local machine

To access the Pulsar admin console on your local machine, forward port 80:

```
kubectl port-forward -n pulsar $(kubectl get pods -n pulsar -l component=adminconsole -o jsonpath='{.items[0].metadata.name}') 8888:80
```

### Accessing Admin Console from cloud provider

To access Pulsar admin console from a cloud provider, the chart supports [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/). Your Kubernetes cluster must have a running Ingress controller (ex Nginx, Traefik, etc).

Set these values to configure the Ingress for the admin console:

```
pulsarAdminConsole:
  ingress:
    enabled: yes
    host: pulsar-ui.example.com
```

## Enabling the Prometheus stack

You can enable a full Prometheus stack (Prometheus, Altermanager, Grafana) from [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus). This includes default Prometheus rules and Grafana dashboards for Kubernetes. 

In an addition, this chart can deploy Grafana dashboards for Pulsar as well as Pulsar-specific rules for Prometheus. 

To deploy the Prometheus stack, use the following setting in your values file:

```
kube-prometheus-stack:
  enabled: yes
```

To enable the Grafana dashboards, use the following setting:

```
grafanaDashboards:
  enabled: no
```

To enable the Kubernetes default rules, use the following setting:
```
kube-prometheus-stack:
  defaultRules:
    create: yes
```


## Example configurations

There are several example configurations in the [examples](https://github.com/datastax/pulsar-helm-chart/blob/master/examples) directory:

* [dev-values.yaml](https://github.com/datastax/pulsar-helm-chart/blob/master/examples/dev-values.yaml). A configuration for setting up a development environment to run in a local Kubernetes environment (ex [minikube](https://minikube.sigs.k8s.io/docs/start/), [kind](https://kind.sigs.k8s.io/)). Message/state persistence, redundancy, authentication, and TLS are disabled. 

Note: With message/state persistence disabled, the cluster will not survive a restart of the ZooKeeper or BookKeeper.

* dev-values-persistence. Same as above, but persistence is enabled. This will allow for the cluster to survive the restarts of the pods, but requires persistent volume claims (PVC) to be supported by the Kubernetes environment. 
* dev-values-auth.yaml. A development environment with authentication enabled. New keys and tokens from those keys are automatically generated and stored in Kubernetes secrets. You can retrieve the superuser token from the admin console (Credentials menu) or from the secret `token-superuser`.

```helm install pulsar -f dev-values-auth.yaml datastax-pulsar/pulsar```

* dev-values-tls.yaml. Development environment with self-signed certficate created by cert-manager. You need to install the cert-manager CRDs before installing the Helm chart. The chart will install the cert-manager application.

```
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.1.0/cert-manager.crds.yaml
helm install pulsar -f dev-values-auth.yaml datastax-pulsar/pulsar
```


## Tiered Storage

Tiered storage (offload to blob storage) can be configured in the `storageOffload` section of the `values.yaml` file. Instructions for AWS S3 and Google Cloud Storage are provided in the file.

In addition you can configure any S3 compatible storage. There is explicit support for [Tardigrade](https://tardigrade.io), which is a provider of secure, decentralized storage. You can enable the Tardigarde S3 gateway in the `extra` configuration. The instructions for configuring the gateway are provided in the `tardigrade` section of the `values.yaml` file.

## Pulsar SQL
If you enable Pulsar SQL, the cluster provides [Presto](https://prestodb.io/) access to the data stored in BookKeeper (and tiered storage, if enabled). Presto is exposed on the service named `<release>-sql`.

The easiest way to access the Presto command line is to log into the bastion host and then connect to the Presto service port, like this:

```
bin/pulsar sql --server pulsar-sql:8090
```
Where the value for the `server` option should be the service name plus port. Once you are connected, you can enter Presto commands:

```
presto> SELECT * FROM system.runtime.nodes;
               node_id                |         http_uri         | node_version | coordinator | state  
--------------------------------------+--------------------------+--------------+-------------+--------
 64b7c5a1-9a72-4598-b494-b140169abc55 | http://10.244.5.164:8080 | 0.206        | true        | active 
 0a92962e-8b44-4bd2-8988-81cbde6bab5b | http://10.244.5.196:8080 | 0.206        | false       | active 
(2 rows)

Query 20200608_155725_00000_gpdae, FINISHED, 2 nodes
Splits: 17 total, 17 done (100.00%)
0:04 [2 rows, 144B] [0 rows/s, 37B/s]
```
To access Pulsar SQL from outside the cluster, you can enable the `ingress` option which will expose the Presto port on hostname. We have tested with the Traefik ingress, but any Kubernetes ingress should work. You can then run SQL queries using the Presto CLI and monitoring Presto using the built-in UI (point browser to the ingress hostname). Authentication is not enabled on the UI, so you can log in with any username.

It is recommended that you match the Presto CLI version to the version running as part of Pulsar SQL.

The Presto CLI supports basic authentication, so if you enabled that on the ingress (using annotations), you can have secure Presto access.

```
presto --server https://presto.example.com --user admin --password
Password: 
presto> show catalogs;
 Catalog 
---------
 pulsar  
 system  
(2 rows)

Query 20200610_131641_00027_tzc7t, FINISHED, 1 node
Splits: 19 total, 19 done (100.00%)
0:01 [0 rows, 0B] [0 rows/s, 0B/s]
```

## Dependencies

The Helm chart has the following optional dependencies:

* [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
* [cert-manager](https://cert-manager.io/)


### Authentication
The chart can enable token-based authentication for your Pulsar cluster. For information on token-based
authentication in Pulsar, go [here](https://pulsar.apache.org/docs/en/security-token-admin/).

For authentication to work, the token-generation keys need to be stored in Kubernetes secrets along with some default tokens (for superuser access). 

The chart includes tooling to automatically create the necessary secrets or you can do this manually.

#### Automatic generation of secrets for token authentication

Use these settings to enable automatic generation of the secrets and enable token-based authentication:

```
enableTokenAuth: yes
autoRecovery:
  enableProvisionContainer: yes
```

When the provision container is enabled, it will check if the required secrets exist. If they don't exist, it will generate new token keys and use those keys to generate the default set of tokens

The name of the key secrets are:

* token-private-key
* token-public-key

Using these keys, it will generate tokens for each role listed in `superUserRoles`. Based on the default settings, the following secrets will be created to store the tokens:

* token-superuser
* token-admin
* token-proxy
* token-websocket

#### Manual secret creation for token authentication

A number of values need to be stored in secrets prior to enabling token-based authentication. First, you need to generate a key-pair for signing the tokens using the Pulsar tokens command:

```bin/pulsar tokens create-key-pair --output-private-key my-private.key --output-public-key my-public.key```

**Note:** The names of the files used in this section match the default values in the chart. If you used different names, then you will have to update the corresponding values.

Then you need to store those keys as secrets.

```
kubectl create secret generic token-private-key \
 --from-file=my-private.key \
 --namespace pulsar
 ```


```
kubectl create secret generic token-public-key \
 --from-file=my-public.key \
 --namespace pulsar
 ```


Using those keys, generate tokens with subjects(roles): 

```bin/pulsar tokens create --private-key file:///pulsar/token-private-key/my-private.key --subject <subject>```

You need to generate tokens with the following subjects:

- admin
- superuser
- proxy
- websocket (only required if using the standalone WebSocket proxy)

Once you have created those tokens, add each as a secret:

```
kubectl create secret generic token-<subject> \
 --from-file=<subject>.jwt \
 --namespace pulsar
 ```

Once you have created the required secrets, you can enable token-based authentication with this setting in the values:

```
enableTokenAuth: yes
```

### TLS


### Automatically generating certificates using cert-manager

#### Manually configuring certificate secrets for TLS

To use TLS, you must first create a certificate and store it in the secret defined by ```tlsSecretName```.
You can create the certificate like this:

```kubectl create secret tls <tlsSecretName> --key <keyFile> --cert <certFile>```

The resulting secret will be of type kubernetes.io/tls. The key should not be in PKCS 8 format even though that is the format used by Pulsar.  The format will be converted by chart to PKCS 8. 

You can also specify the certificate information directly in the values:

```
# secrets:
  # key: |
  # certificate: |
  # caCertificate: |
```

This is useful if you are using a self-signed certificate.

For automated handling of publicly signed certificates, you can use a tool
such as [cert-manager](https://cert-mananager). The following [page](https://github.com/datastax/pulsar-helm-chart/blob/master/aws-customer-docs.md) describes how to set up cert-manager in AWS.

Once you have created the secrets that store the certificate info (or specified it in the values), you can enable TLS in the values:

```
enableTls: yes

```
