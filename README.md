[![GitHub](https://avatars1.githubusercontent.com/u/9919?s=30&v=4)](https://github.com/datastax/pulsar-helm-chart) 
[![CircleCI](https://circleci.com/gh/datastax/pulsar-helm-chart.svg?style=svg)](https://circleci.com/gh/datastax/pulsar-helm-chart)
[![LICENSE](https://img.shields.io/hexpm/l/pulsar.svg)](https://github.com/datastax/pulsar-helm-chart/blob/master/LICENSE)

# Helm Chart for an Apache Pulsar Cluster

This Helm chart configures an Apache Pulsar cluster. It is designed for production use, but can also be used in local development environments with the proper settings.

It includes support for:
* [TLS](#tls)
* [Authentication](#authentication)
* [OpenID Connect Authentication](#openid-connect-authentication)
* [OpenID / OAuth2 with Starlight for Kafka](#openid-with-starlight-for-kafka)
* WebSocket Proxy
* Standalone Functions Workers
* Pulsar IO Connectors
* [Tiered Storage](#tiered-storage) including Tardigrade distributed cloud storage
* [Pulsar SQL Workers](#pulsar-sql)
* [Admin Console](#managing-pulsar-using-admin-console) for managing the cluster
* [Pulsar heartbeat](https://github.com/datastax/pulsar-heartbeat)
* [Burnell](https://github.com/datastax/burnell) for API-based token generation
* Prometheus/Grafana/Alertmanager [stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) with default Grafana dashboards and Pulsar-specific alerting rules
* cert-manager with support for self-signed certificates as well as public certificates using ACME (for example, Let's Encrypt)
* Ingress configuration for all HTTP ports (Admin Console, Prometheus, Grafana, etc.)

[Helm](https://helm.sh) must be installed and initialized to use the chart. Only Helm 3 is supported.
Please refer to Helm's [documentation](https://helm.sh/docs/) to get started.

## Upgrade considerations

## Minikube quick start

Make sure you have minikube [installed](https://minikube.sigs.k8s.io/docs/start/) and running (e.g., `minikube start --cpus 6 --memory 16G`.)

Install the Helm chart:

```
helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart
helm repo update
curl -LOs https://datastax.github.io/pulsar-helm-chart/examples/dev-values.yaml
helm install pulsar -f dev-values.yaml --wait datastax-pulsar/pulsar
```

The Helm command waits until all pods are up, which takes about 5 minutes.

In another terminal, start the minikube tunnel:

```
minikube tunnel
```

Open your browser to http://localhost to view the Admin Console:

![Admin Console](assets/admin_console.png?raw=true "Admin Console")


You can view the embedded Grafana charts using the Cluster/Monitoring menu in the Admin Console:

![Grafana in Admin Console](assets/grafana.png?raw=true "Grafana in Admin Console")

Grafana is password protected. The username is `admin`. You can get the password with this command:

```
kubectl get secret pulsar-grafana -o=jsonpath="{.data.admin-password}" | base64 --decode
```


## Quick start

With Helm installed to your local machine and with access to a Kubernetes cluster (e.g. minikube):

```
helm repo add datastax-pulsar https://datastax.github.io/pulsar-helm-chart
helm repo update
curl -LOs https://datastax.github.io/pulsar-helm-chart/examples/dev-values.yaml
helm install pulsar -f dev-values.yaml datastax-pulsar/pulsar 
```

Once all the pods are running (takes 5 to 10 minutes), you can access the admin console by forwarding to localhost: 

```kubectl port-forward $(kubectl get pods -l component=adminconsole -o jsonpath='{.items[0].metadata.name}') 8888:80```

Then open a browser to http://localhost:8888. In the admin console, you can test your Pulsar setup using the built-in clients (Test Clients in the left-hand menu).

If you also forward the Grafana port, like this:

```kubectl port-forward $(kubectl get pods -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}') 3000:3000```

You can view metrics for the Pulsar cluster via the Cluster, Monitoring menu item. You will have to log into Grafana. The username is `admin` and the password is in the downloaded file `dev-values.yaml` under the `adminPassword` setting.

To use the Pulsar admin and client tools (ex pulsar-admin, pulsar-client, pulsar-perf), log into the bastion pod:

```kubectl exec $(kubectl get pods -l component=bastion -o jsonpath="{.items[*].metadata.name}") -it -- /bin/bash```

You will find the tools in the `/pulsar/bin` directory.

Note: if you are using Cert-Manager to manage TLS certificates, see [Enabling TLS using Cert-Manager](#enabling-tls-using-cert-manager) for additional configuration information.

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
helm install pulsar datastax-pulsar/pulsar --namespace pulsar --values storage_values.yaml --create-namespace
```

## Using namespace scoped or cluster level RBAC resources

Up to Helm chart version 2.0.3, the Helm deployment uses `ClusterRole` and `ClusterRoleBinding` resources for defining access for service accounts by default. These resources get created outside the namespace defined for deployment.
Since version 2.0.4, namespace scoped `Role` and `RoleBinding` resources are used by default.

It is possible to revert to use the legacy behavior by setting `rbac.clusterRoles` to `true`.

## Installing Pulsar for development

This chart is designed for production use, but it can be used in development environments. To use this chart in a development environment (ex minikube), you need to:

* Disable anti-affinity rules that ensure components run on different nodes
* Reduce resource requirements
* Disable persistence (configuration and messages are not stored so are lost on restart). If you want persistence, you will have to configure storage settings that are compatible with your development environment as described above.

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
  pulsarAdminConsole: true
```

It will be automatically configured to connect to the Pulsar cluster.

By default, the admin console has authentication disabled. You can enable authentication with these settings:

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
      enabled: true
      user: 'admin'
      password: 'password'
```

### Accessing Admin Console on your local machine

To access the Pulsar admin console on your local machine, forward port 80:

```
kubectl port-forward -n pulsar $(kubectl get pods -n pulsar -l component=adminconsole -o jsonpath='{.items[0].metadata.name}') 8888:80
```

### Accessing Admin Console from cloud provider

To access Pulsar admin console from a cloud provider, the chart supports [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/). Your Kubernetes cluster must have a running Ingress controller (ex Nginx, Traefik, etc.).

Set these values to configure the Ingress for the admin console:

```
pulsarAdminConsole:
  ingress:
    enabled: true
    host: pulsar-ui.example.com
```

## Enabling TLS using Cert-Manager

When using Cert-Manager to create your TLS certificates, you must first install the Cert-Manager CRDs. These are
installed using the following command:

```shell
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.8.0/cert-manager.crds.yaml
```

NOTE: if you're deploying a version of the chart before 3.0.0, you'll need to use version `v1.5.5` of the CRDs.

If you don't, you will get error messages like this:

> Error: INSTALLATION FAILED: unable to build kubernetes objects from release manifest: [resource mapping not found for name: "pulsar-ca-certificate" namespace: "pulsar" from "": no matches for kind "Certificate" in version "cert-manager.io/v1"

## Prometheus stack

### Enabling the Prometheus stack

You can enable a full Prometheus stack (Prometheus, Alertmanager, Grafana) from [kube-prometheus](https://github.com/prometheus-operator/kube-prometheus). This includes default Prometheus rules and Grafana dashboards for Kubernetes. 

In an addition, this chart can deploy Grafana dashboards for Pulsar as well as Pulsar-specific rules for Prometheus. 

To deploy the Prometheus stack, use the following setting in your values file:

```
kube-prometheus-stack:
  enabled: true
```

To enable the Kubernetes default rules, use the following setting:
```
kube-prometheus-stack:
  defaultRules:
    create: true
```

## Deploying and Discovering a PodMonitor

In order to simplify metrics gathering, the helm chart has support for deploying a `PodMonitor`. This single monitor
configures scraping all the available metrics endpoints for a given Pulsar Cluster deployed by the helm chart. This
`PodMonitor` can be deployed by setting the following in your values file:

```yaml
enablePulsarPodMonitor: true
```

Note that this will deploy a `PodMonitor` in the release's namespace. If you are running a Prometheus Operator in
another Kubernetes namespace, you may need to modify the configuration to make sure that the operator can discover
`PodMonitors` in the release's namespace.

### Disabling the Prometheus stack

As some  `kube-prometheus-stack` components need CRDs to be installed and `kube-prometheus-stack.enabled: false` does not alone prevent components' CRDs installation, the `kube-prometheus-stack` components should be disabled one by one, if the service account used to deploy the cluster does not have enough permissions to install CRDs.

In order to prevent all `kube-prometheus-stack` CRDs from being installed, the following should be added to `values.yaml`:

```
kube-prometheus-stack:
  enabled: false
  prometheusOperator:
    enabled: false
  grafana:
    enabled: false
  alertmanager:
    enabled: false
  prometheus:
    enabled: false
```

### Grafana Dashboards

DataStax has several custom dashboards to help interpret Pulsar metrics. These custom dashboards are installed when the
following is set in the values file:

```
grafanaDashboards:
  enabled: true
```

Starting in Pulsar 2.8.0, the bundled Zookeeper process exports its own metrics instead of using the Pulsar metrics
implementation. This results in new metrics names. As a result, we install two Grafana dashboards for Zookeeper. The
first is a custom DataStax dashboard that works for versions before 2.8.0. The second is the official Zookeeper
community Grafana dashboard: https://grafana.com/grafana/dashboards/10465.

## Example configurations

There are several example configurations in the [examples](https://github.com/datastax/pulsar-helm-chart/blob/master/examples) directory:

* [dev-values.yaml](https://github.com/datastax/pulsar-helm-chart/blob/master/examples/dev-values.yaml). A configuration for setting up a development environment to run in a local Kubernetes environment (ex [minikube](https://minikube.sigs.k8s.io/docs/start/), [kind](https://kind.sigs.k8s.io/)). Message/state persistence, redundancy, authentication, and TLS are disabled. 

Note: With message/state persistence disabled, the cluster will not survive a restart of the ZooKeeper or BookKeeper.

* dev-values-persistence. Same as above, but persistence is enabled. This will allow for the cluster to survive the restarts of the pods, but requires persistent volume claims (PVC) to be supported by the Kubernetes environment. 
* dev-values-auth.yaml. A development environment with authentication enabled. New keys and tokens from those keys are automatically generated and stored in Kubernetes secrets. You can retrieve the superuser token from the admin console (Credentials menu) or from the secret `token-superuser`.
* dev-values-keycloak-auth.yaml. A deployment environment with authentication enabled along with a running keycloak server that can create additional tokens. Like the `dev-values-auth.yaml`, it will create a superuser token for use by pulsar components.

```helm install pulsar -f dev-values-auth.yaml datastax-pulsar/pulsar```

* dev-values-tls.yaml. Development environment with self-signed certificate created by cert-manager. You need to install the cert-manager CRDs before installing the Helm chart. The chart will install the cert-manager application.

```
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.8.0/cert-manager.crds.yaml
helm install pulsar -f dev-values-tls.yaml datastax-pulsar/pulsar
```

NOTE: if you're deploying a version of the chart before 3.0.0, you'll need to use version `v1.5.5` of the CRDs.

## Tiered Storage

Tiered storage (offload to blob storage) can be configured in the `storageOffload` section of the `values.yaml` file. Instructions for AWS S3, Google Cloud Storage and Azure are provided in the file.

In addition, you can configure any S3 compatible storage. There is explicit support for [Tardigrade](https://tardigrade.io), which is a provider of secure, decentralized storage. You can enable the Tardigrade S3 gateway in the `extra` configuration. The instructions for configuring the gateway are provided in the `tardigrade` section of the `values.yaml` file.

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


## Authentication
The chart can enable two forms of token-based authentication for a Pulsar cluster. See below for information on each:

* [OpenID Connect Authentication](#openid-connect-authentication)
* [Pulsar's Token Based Authentication](#pulsars-token-based-authentication)

The chart includes tooling to automatically create the necessary secrets, or you can do this manually.

### OpenID Connect Authentication

DataStax created the [OpenID Connect Authentication Plugin](https://github.com/datastax/pulsar-openid-connect-plugin)
to provide a more dynamic authentication option for Pulsar. This plugin integrates with your OIDC compliant Identity
Provider or the chart can deploy a Keycloak instance in the kubernetes cluster. This plugin integrates with an Identity
Provider to dynamically retrieve Public Keys from the Identity Provider for token validation. This dynamic
public key retrieval enables support for key rotation and multiple authentication/identity providers by configuring
multiple allowed token issuers. It also means that token secret keys will not be stored in Kubernetes secrets.

In order to simplify deployment for Pulsar cluster components, the plugin provides the option to use OIDC in
conjunction with Pulsar's basic token based authentication. See the [plugin project](https://github.com/datastax/pulsar-openid-connect-plugin)
for information about configuration.

#### Bring Your Own Identity Provider

To enable OpenID Connect with your already running Identity Provider, configure the `openid` section in the
values and the `authenticationProviders` in the broker, proxy, and function worker.

Here is an example of the values using Okta:

```yaml
openid:
  enabled: true
  # Comma delimited list of issuers to trust
  allowedIssuerUrls: "https://dev-1111111.okta.com/oauth2/abcd878787"
  allowedAudience: api://pulsarClient

broker:
  authenticationProviders: "com.datastax.oss.pulsar.auth.AuthenticationProviderOpenID"
proxy:
  authenticationProviders: "com.datastax.oss.pulsar.auth.AuthenticationProviderOpenID"
function:
  authenticationProviders: "com.datastax.oss.pulsar.auth.AuthenticationProviderOpenID"
```

The `AuthenticationProviderOpenID` class is included with all Luna Streaming Docker images.

#### Using Keycloak Deployed by Chart

Here is an example helm [values file](./examples/dev-values-keycloak-auth.yaml) for deploying a working cluster that
integrates with keycloak. By default, the helm chart creates a `pulsar` realm within keycloak and sets up the client
used by the Pulsar Admin Console as well as a sample client and some sample groups. The configuration for the broker
side auth plugin should be placed in the `.Values.<component>.configData` maps.

#### Configuring Keycloak for Token Generation
First deploy the cluster:

```shell
$ helm install test --values ../../examples/dev-values-keycloak-auth.yaml .
```

The name of the deployment is very important for a working cluster. The values file assumes that the cluster's name is
`test`, as shown above. Once the cluster is operational, you can start configuring keycloak. Port forward to keycloak:

```shell
$ kubectl port-forward test-keycloak-0 8080:8080
```

Then, using a browser, navigate to `localhost:8080`. At this point, you will need to retrieve the configured username
and password for the admin user in keycloak. The [values file](./examples/dev-values-keycloak-auth.yaml) configures
them here:

```yaml
keycloak:
  auth:
    adminUser: "admin"
    adminPassword: "F3LVqnxqMmkCQkvyPdJiwXodqQncK@"
```

Once in to the keycloak UI, you can view the `pulsar` realm. Note that the realm name must match the configured realm
name (`.Values.keycloak.realm`) for the OpenID Connect plugin to work properly.

The OpenID Connect plugin uses the `sub` (subject) claim from the JWT as the role used for authorization within Pulsar.
In order to get Keycloak to generate the JWT for a client with the right `sub`, you can create a special "mapper" that
is a "Hardcoded claim" mapping claim name `sub` to a claim value that is the disired role, like `superuser`. The default
config installed by this helm chart provides examples of how to add custom mapper protocols to clients.

#### Retrieving and Using a token from Keycloak with Pulsar Admin CLI
After creating your realm and client, you can retrieve a token. In order to generate a token that will have an allowed
issuer, you should exec into a pod in the k8s cluster. Exec'ing into a bastion host will give you immediate access
to a `pulsar-admin` cli tool that you can use to verify that you have access. The following is run from a bastion pod.

```shell
pulsar@pulsar-bastion-85c9b777f6-gt9ct:/pulsar$ curl -d "client_id=test-client" \
       -d "client_secret=19d9f4a2-65fb-4695-873c-d0c1d6bdadad" \
       -d "grant_type=client_credentials" \
       "http://test-keycloak/realms/pulsar/protocol/openid-connect/token"
{"access_token":"eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJDY3c3ZXcwQ0hKMThfbWpCQzYxb2xOSU1wT0d3TkEyd1ZFbHBZLUdzb2tvIn0.eyJleHAiOjE2MjY5NzUwNzIsImlhdCI6MTYyNjk3NDQ3MiwianRpIjoiYTExZmFkY2YtYTJkZi00NmNkLTk0OWEtNDdkNzdmNDYxMDMxIiwiaXNzIjoiaHR0cDovL3Rlc3Qta2V5Y2xvYWsvYXV0aC9yZWFsbXMvcHVsc2FyIiwiYXVkIjoiYWNjb3VudCIsInN1YiI6ImQwN2UxOGIxLTE4YzQtNDZhMC1hNGU0LWE3YTZjNmRiMjFkYyIsInR5cCI6IkJlYXJlciIsImF6cCI6InRlc3QtY2xpZW50IiwiYWNyIjoiMSIsInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJvZmZsaW5lX2FjY2VzcyIsImRlZmF1bHQtcm9sZXMtcHVsc2FyIiwidW1hX2F1dGhvcml6YXRpb24iXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6ImVtYWlsIHByb2ZpbGUiLCJzdWIiOiJzdXBlcnVzZXIiLCJjbGllbnRIb3N0IjoiMTcyLjE3LjAuMSIsImNsaWVudElkIjoidGVzdC1jbGllbnQiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsInByZWZlcnJlZF91c2VybmFtZSI6InNlcnZpY2UtYWNjb3VudC10ZXN0LWNsaWVudCIsImNsaWVudEFkZHJlc3MiOiIxNzIuMTcuMC4xIn0.FckQLOD64ZTKmx2uutP75QBpZAqHaqWyEE6jRUXvbSzsiXTAQyz-30zKsUSEjOMJp97NlTy3NZECVo_GdZ7oPcneFdglmFY62btWj-5s6ELcazj-AGQhyt0muGD4VP71xjpjCUpVxhyBIQlltGZLu7Rgw4trfh3LS8YjaY74vGg_BjOzZ8VI4S352lyGOULou7_dRbaeKhv43OfU7e_Y_ro_m_9UaDARypcj3uqSllhZdifA4YbHyaBCCu5eH19GCLtFm3I00PvWkOy3iTyOkkTcayqJ-Vlraf95qCZFN-sooIIU6o8L-wS-Zr7EvkoDJ-II9q49WHJJLIIvnCE2ug","expires_in":600,"refresh_expires_in":0,"token_type":"Bearer","not-before-policy":0,"scope":"email profile"}
```

Then, you can copy the `access_token` contents and use it here:

```shell
pulsar@pulsar-bastion-85c9b777f6-gt9ct:/pulsar$ bin/pulsar-admin --auth-params "token:eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJDY3c3ZXcwQ0hKMThfbWpCQzYxb2xOSU1wT0d3TkEyd1ZFbHBZLUdzb2tvIn0.eyJleHAiOjE2MjY5NzUwNzIsImlhdCI6MTYyNjk3NDQ3MiwianRpIjoiYTExZmFkY2YtYTJkZi00NmNkLTk0OWEtNDdkNzdmNDYxMDMxIiwiaXNzIjoiaHR0cDovL3Rlc3Qta2V5Y2xvYWsvYXV0aC9yZWFsbXMvcHVsc2FyIiwiYXVkIjoiYWNjb3VudCIsInN1YiI6ImQwN2UxOGIxLTE4YzQtNDZhMC1hNGU0LWE3YTZjNmRiMjFkYyIsInR5cCI6IkJlYXJlciIsImF6cCI6InRlc3QtY2xpZW50IiwiYWNyIjoiMSIsInJlYWxtX2FjY2VzcyI6eyJyb2xlcyI6WyJvZmZsaW5lX2FjY2VzcyIsImRlZmF1bHQtcm9sZXMtcHVsc2FyIiwidW1hX2F1dGhvcml6YXRpb24iXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6ImVtYWlsIHByb2ZpbGUiLCJzdWIiOiJzdXBlcnVzZXIiLCJjbGllbnRIb3N0IjoiMTcyLjE3LjAuMSIsImNsaWVudElkIjoidGVzdC1jbGllbnQiLCJlbWFpbF92ZXJpZmllZCI6ZmFsc2UsInByZWZlcnJlZF91c2VybmFtZSI6InNlcnZpY2UtYWNjb3VudC10ZXN0LWNsaWVudCIsImNsaWVudEFkZHJlc3MiOiIxNzIuMTcuMC4xIn0.FckQLOD64ZTKmx2uutP75QBpZAqHaqWyEE6jRUXvbSzsiXTAQyz-30zKsUSEjOMJp97NlTy3NZECVo_GdZ7oPcneFdglmFY62btWj-5s6ELcazj-AGQhyt0muGD4VP71xjpjCUpVxhyBIQlltGZLu7Rgw4trfh3LS8YjaY74vGg_BjOzZ8VI4S352lyGOULou7_dRbaeKhv43OfU7e_Y_ro_m_9UaDARypcj3uqSllhZdifA4YbHyaBCCu5eH19GCLtFm3I00PvWkOy3iTyOkkTcayqJ-Vlraf95qCZFN-sooIIU6o8L-wS-Zr7EvkoDJ-II9q49WHJJLIIvnCE2ug" \
      tenants list
"public"
"pulsar"
```

### Pulsar's Token Based Authentication

This token based authentication relies on a plugin provided by Apache Pulsar using the `AuthenticationProviderToken`
class that ships with Pulsar.

For information on token-based authentication from Apache Pulsar, go
[here](https://pulsar.apache.org/docs/en/security-token-admin/).

For authentication to work, the token-generation keys need to be stored in Kubernetes secrets along with some default tokens (for superuser access).

The chart includes tooling to automatically create the necessary secrets, or you can do this manually.

#### Automatic generation of secrets for token authentication

Use these settings to enable automatic generation of the secrets and enable token-based authentication:

```
enableTokenAuth: true
autoRecovery:
  enableProvisionContainer: true
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
enableTokenAuth: true
```

### TLS

#### TLS with Client Facing Components

There are many components to consider when enabling TLS for a Pulsar Cluster. To enable TLS for all client facing
endpoints, set `enableTls: true` in the values file and configure certificates. This setting will enable TLS endpoints
for the Broker pods, Function Worker pods, and Proxy pods. However, this setting will not configure the proxy or the
function worker to use TLS for connections with the broker. You can enable those by configuring
`tls.proxy.enableTlsWithBroker: true` and `tls.function.enableTlsWithBroker: true`, respectively. Because the function
worker only connects to the broker over TLS when authentication is configured, make sure to enable authentication if
you'd like the function worker to connect to the broker over TLS.

#### TLS within all components (zero-trust)

In order to support a zero-trust deployment of Pulsar please view the zero trust example values file [here](./examples/dev-values-zero-trust.yaml).
The example shows the key components necessary for configuring TLS for all connections in Pulsar cluster. Note that
you can supply a certificate per component now. Also note that the default values file has documentation for many of the
fields related to zero trust.

If you are using Cert Manager, the zero trust example is a complete example. If you are using your own certificates,
you'll need to add the correct hostnames to the certificates in order to make hostname verification work. Please see
the [self-signed-cert-per-component.yaml](helm-chart-sources/pulsar/templates/cert-manager/self-signed-cert-per-component.yaml)
template to see which hostnames are required for each component.

#### Hostname Verification

In order for hostname verification to work, you must configure the helm chart to deploy the broker cluster as a
StatefulSet. This kind of deployment gives each pod a stable network identifier, which is necessary for hostname
verification and the Pulsar Protocol.

To enable hostname verification with upstream servers, set `tls.<component>.enableHostnameVerification: true`. Note that
these settings temporarily default to false for backwards compatibility, but will be updated to default to true in the
next major version bump.

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
enableTls: true

```
### OpenID with Starlight for Kafka
To configure OpenID / OAuth2, you can use the values file that includes OpenID support with Starlight for Kafka: dev-values-tls-all-components-and-oauth2.yaml
Be sure to provide your appropriate values in the openid section of the values file:

```
openid:
  enabled: true
  # From token generated in Okta UI or other method:
  allowedIssuerUrls: $ISSUER_URI
  withS4k: true
  allowedAudience: $AUDIENCE
```
like with these example values:
```
openid:
  enabled: true
  # From token generated in Okta UI or other method:
  allowedIssuerUrls: https://dev-1111111.okta.com/oauth2/abcd878787
  allowedAudience: api://pulsarClient
  withS4k: true
```

The chart can be installed as follows:

```
BASEDIR=/path/to/repo/on/your/local/filesystem
helm install pulsar datastax-pulsar/pulsar --namespace pulsar --values $BASEDIR/pulsar-helm-chart/examples/kafka/dev-values-tls-all-components-and-kafka-and-oauth2.yaml --create-namespace --debug
```

To test the functionality (with and without TLS) for both token authentication, and for Starlight for Kafka, you can perform the following steps:
1. Set variables that will be used for subsequent commands (making sure they match the values used in the Helm values file above):
Note that these credentials can be obtained from Okta (https://www.youtube.com/watch?v=UQBrecHOXxU&ab_channel=DataStaxDevelopers) or from an equivalent auth provider.

```
ISSUER_URI="https://dev-1111111.okta.com/oauth2/abcd878787"
AUDIENCE="api://pulsarClient"
SCOPE="pulsar_client_m2m"
AUTH_PARAMS=$(cat <<EOF
{"privateKey":"/pulsar/conf/creds.json","issuerUrl":"$ISSUER_URI","scope":"$SCOPE","audience":"$AUDIENCE"}
EOF
)
CLIENT_ID="your-client-id"
CLIENT_SECRET="your-client-secret"
KAFKA_VERSION="kafka_2.12-3.3.2"
OAUTH_CLIENT="2.10.3.2"

PROXY_HOSTNAME="pulsar-proxy.pulsar.svc.cluster.local"
```
2. (Optional for TLS)
```
# Copy truststore from broker to bastion to simplify tests by first copying to local system. (Make sure you're not still in the bastion.)
kubectl cp pulsar/pulsar-broker-0:/pulsar/tls.truststore.jks ~/Downloads/tls.truststore.jks
# Provide the expected bastion path:
kubectl cp ~/Downloads/tls.truststore.jks pulsar/$(kubectl get pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}'):/pulsar/tls.truststore.jks 
```
3. SSH to bastion, passing variables for convenience:
```
kubectl exec -it pod/$(kubectl get pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- env ISSUER_URI=$ISSUER_URI AUDIENCE=$AUDIENCE SCOPE=$SCOPE AUTH_PARAMS=$AUTH_PARAMS CLIENT_ID=$CLIENT_ID CLIENT_SECRET=$CLIENT_SECRET KAFKA_VERSION=$KAFKA_VERSION OAUTH_CLIENT=$OAUTH_CLIENT PROXY_HOSTNAME=$PROXY_HOSTNAME bash
```
4. Test Pulsar client with pulsar-perf with token auth against non-TLS endpoint:
```
bin/pulsar-perf produce --num-messages 1000 -r 1000 --size 1024 --auth_plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params file:///pulsar/token-superuser-stripped.jwt --service-url pulsar://$PROXY_HOSTNAME:6650/ persistent://public/default/test
```
5. Test Pulsar client with pulsar-perf with token auth against TLS endpoint (requires the "Optional for TLS" step, above):
```
bin/pulsar-perf produce --num-messages 1000 -r 1000 --size 1024 --auth_plugin org.apache.pulsar.client.impl.auth.AuthenticationToken --auth-params file:///pulsar/token-superuser-stripped.jwt --service-url pulsar+ssl://$PROXY_HOSTNAME:6651/ persistent://public/default/test
```
6. Configure OIDC credentials (using variables set above)
```
cat << EOF > /pulsar/conf/creds.json
{"client_id":"$CLIENT_ID","client_secret":"$CLIENT_SECRET","grant_type": "client_credentials"}
EOF
```
Verify the credentials file was created as expected:
```
cat /pulsar/conf/creds.json
```
7. Test Pulsar client with pulsar-perf with token auth against non-TLS endpoint:
```
bin/pulsar-perf produce --num-messages 1000 -r 1000 --size 1024 --auth-plugin "org.apache.pulsar.client.impl.auth.oauth2.AuthenticationOAuth2" --auth-params $AUTH_PARAMS --service-url pulsar://$PROXY_HOSTNAME:6650/ persistent://public/default/test
```
8. Test Pulsar client with pulsar-perf with token auth against TLS endpoint:
```
bin/pulsar-perf produce --num-messages 1000 -r 1000 --size 1024 --auth-plugin "org.apache.pulsar.client.impl.auth.oauth2.AuthenticationOAuth2" --auth-params $AUTH_PARAMS --service-url pulsar+ssl://$PROXY_HOSTNAME:6651/ persistent://public/default/test
```
9. Test admin endpoints with token auth for non-TLS:
```
bin/pulsar-admin --auth-plugin "org.apache.pulsar.client.impl.auth.oauth2.AuthenticationOAuth2" --auth-params $AUTH_PARAMS --admin-url http://$PROXY_HOSTNAME:8080/ namespaces policies public/default
```
10. Test admin endpoints with token auth for TLS:
```
bin/pulsar-admin --auth-plugin "org.apache.pulsar.client.impl.auth.oauth2.AuthenticationOAuth2" --auth-params $AUTH_PARAMS --admin-url https://$PROXY_HOSTNAME:8443/ namespaces policies public/default
```
11. Configure Kafka client:
```
mkdir /pulsar/kafka && cd /pulsar/kafka
curl -LOs https://downloads.apache.org/kafka/3.3.2/$KAFKA_VERSION.tgz
tar -zxvf /pulsar/kafka/$KAFKA_VERSION.tgz
cd /pulsar/kafka/$KAFKA_VERSION/libs
curl -LOs "https://github.com/datastax/starlight-for-kafka/releases/download/v$OAUTH_CLIENT/oauth-client-$OAUTH_CLIENT.jar"
cd ..
```
Verify the files were downloaded as expected:
```
ls /pulsar/kafka/$KAFKA_VERSION
ls /pulsar/kafka/$KAFKA_VERSION/libs | grep -i "oauth"
```
12. Test OpenID/OAuth2 on non-TLS endpoint for Starlight for Kafka (S4K):
Setup Kafka producer properties and then run test command:
```
cat << EOF > /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
bootstrap.servers=pulsar-proxy:9092
compression.type=none
sasl.login.callback.handler.class=com.datastax.oss.kafka.oauth.OauthLoginCallbackHandler
security.protocol=SASL_PLAINTEXT
sasl.mechanism=OAUTHBEARER
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule \
   required oauth.issuer.url="$ISSUER_URI"\
   oauth.credentials.url="file:///pulsar/conf/creds.json"\
   oauth.audience="$AUDIENCE"\
   oauth.scope="$SCOPE";
EOF
```
Verify the file looks right:
```
cat /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
```
Then, you can run the producer:
```
cd /pulsar/kafka/$KAFKA_VERSION; bin/kafka-console-producer.sh --bootstrap-server PLAINTEXT://pulsar-proxy:9092 --topic test --producer.config /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
```
If you want to see the data come through, you can open another CLI tab and use the Pulsar client to subscribe to the topic when you produce the messages via Kafka:
```
kubectl exec -it pod/$(kubectl get pods -o=jsonpath='{.items[?(@.metadata.labels.component=="bastion")].metadata.name}') -- bash
cd /pulsar
bin/pulsar-client consume persistent://public/default/test --subscription-name test-kafka --num-messages 0
```
Also, if you want to observe the logs during this process, you can follow them for the proxy and broker, as follows:
```
kubectl logs pod/$(kubectl get pods -o=jsonpath='{.items[?(@.metadata.labels.component=="proxy")].metadata.name}') --follow
kubectl logs pod/$(kubectl get pods -o=jsonpath='{.items[?(@.metadata.labels.component=="broker")].metadata.name}') --follow
```
Then, produce messages from the Kafka terminal and observe them come through to the Pulsar consumer.

13. Test OpenID/OAuth2 on TLS endpoint for S4K:
We must setup the Kafka producer a little differently since it requires TLS-specific configurations:
```
cat << EOF > /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
bootstrap.servers=pulsar-proxy:9093
compression.type=none
ssl.truststore.location=/pulsar/tls.truststore.jks 
security.protocol=SASL_SSL
sasl.login.callback.handler.class=com.datastax.oss.kafka.oauth.OauthLoginCallbackHandler
sasl.mechanism=OAUTHBEARER
# The identification algorithm must be empty
ssl.endpoint.identification.algorithm=
sasl.jaas.config=org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule \
   required oauth.issuer.url="$ISSUER_URI"\
   oauth.credentials.url="file:///pulsar/conf/creds.json"\
   oauth.audience="$AUDIENCE"\
   oauth.scope="$SCOPE";
EOF
```
Then, you can run the command to start the producer:
```
cd /pulsar/kafka/$KAFKA_VERSION; bin/kafka-console-producer.sh --bootstrap-server SSL://pulsar-proxy:9093 --topic test --producer.config /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
```
14. Test S4K with token authentication on non-TLS endpoint:
```
SUPERUSER_TOKEN=$(</pulsar/token-superuser-stripped.jwt)

# To test token auth on non-TLS endpoint:
cat << EOF > /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
bootstrap.servers=pulsar-proxy:9092
compression.type=none
security.protocol=SASL_PLAINTEXT
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule \
   required username="public/default"\
   password="token:$SUPERUSER_TOKEN";
EOF

cd /pulsar/kafka/$KAFKA_VERSION; bin/kafka-console-producer.sh --bootstrap-server PLAINTEXT://pulsar-proxy:9092 --topic test --producer.config /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
```
15. Test S4K with token authentication on TLS endpoint:
```
cat << EOF > /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
bootstrap.servers=pulsar-proxy:9093
compression.type=none
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule \
required username="public/default" password="token:$SUPERUSER_TOKEN";
ssl.truststore.location=/pulsar/tls.truststore.jks
# The identification algorithm must be empty
ssl.endpoint.identification.algorithm=
EOF

cd /pulsar/kafka/$KAFKA_VERSION; bin/kafka-console-producer.sh --bootstrap-server SSL://pulsar-proxy:9093 --topic test --producer.config /pulsar/kafka/$KAFKA_VERSION/config/producer.properties
```
### Grafana dashboards for S4K
Additionally, if you want to monitor Grafana dashboards for S4K, you can download them via this command:
```
cd ~/Downloads; curl -LOs https://raw.githubusercontent.com/datastax/starlight-for-kafka/2.10_ds/grafana/dashboard.json
```
Then, after you port-forward or otherwise connect to Grafana, you can follow the UI to import the dashboard from this JSON file.