# Using Cert-Manager for Pulsar Certificates in AWS


This document describes how to configure Cert-Manger to automatically retrieve and renew Let's Encrypt certificates for use in the Pulsar cluster. In order for Let's Encrypt to issue a certificate you must prove domain ownership using a "challenge". In this document, we are using the DNS challenge with AWS Route 53 as the DNS provider. The latest certificate will be stored in a Kubernetes secret which can be referenced by the [Datastax Pulsar Helm chart](https://datastax.github.io/pulsar-helm-chart/).

There are 3 main steps to installing Cert-Manager to use AWS Route 53:

* Install Cert-Manager using Helm
* Create an IAM user with Route 53 access and configure it for Cert-Manager
* Configure a certificate resource 

## Install Cert-Manager using Helm

Reference: https://docs.cert-manager.io

* Install the Cert-Manager CustomResourceDefinition resources
```
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.5/cert-manager.crds.yaml
```

* Create the namespace for Cert-Manager
```
kubectl create namespace cert-manager
```

* Add the Jetstack Helm repository
```
helm repo add jetstack https://charts.jetstack.io
```

* Update your local Helm chart repository cache
```
helm repo update
```

* Install the cert-manager Helm chart
```
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v1.5.5 \
  jetstack/cert-manager
```

* Verify Cert-Manager is running

```
kubectl get pods -n cert-manager
```
## Create AWS IAM user for Route 53


Ref: https://docs.cert-manager.io/en/latest/tasks/acme/configuring-dns01/route53.html

Create an IAM user with the following policy:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "route53:GetChange",
            "Resource": "arn:aws:route53:::change/*"
        },
        {
            "Effect": "Allow",
            "Action": "route53:ChangeResourceRecordSets",
            "Resource": "arn:aws:route53:::hostedzone/*"
        },
        {
            "Effect": "Allow",
            "Action": "route53:ListHostedZonesByName",
            "Resource": "*"
        }
    ]
}
```
**Note:** This is a very permission policy. It can be restricted to a hosted zone in the last clause.

Once you have created an IAM user, generate an access and secret key for that user. You must store the secret key in a Kubernetes secret. Here is the file:

```
apiVersion: v1
kind: Secret
metadata:
  name: prod-route53-credentials-secret
  namespace: cert-manager
type: Opaque
data:
  secret-access-key: <insert-IAM-secret-key-here>
```

Apply the secrets file:

```
kubectl apply -f aws_key_secret.yaml
```
Create a ClusterIssuer that includes the IAM access key and references the secret:

```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    # You must replace this email address with your own.
    # Let's Encrypt will use this to contact you about expiring
    # certificates, and issues related to your account.
    email: <insert-email-here>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      # Secret resource used to store the account's private key.
      name: letsencrypt-production-account-key
    solvers:
    - dns01:
        route53:
          region: <insert-AWS-region>
          accessKeyID: <insert-IAM-access-key>
          secretAccessKeySecretRef:
            name: prod-route53-credentials-secret
            key: secret-access-key
```

Apply the ClusterIssuer file:

```
kubectl apply -f letsencrypt-production-aws.yaml
```

## Configure a certificate resource

**Note:** The following assumes that you will run Pulsar in the `pulsar` namespace.

Create a certificate resource file like this:

```
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: <insert-name-for-certificate>
  namespace: pulsar
spec:
    # The following secret is where the certificate is stored 
    # after it is generated. This is the secret name you should
    # provide to the Pulsar Helm chart
  secretName: <insert-secret-to-store-certificate>
  issuerRef:
    # The issuer created previously
    name: letsencrypt-production
    kind: ClusterIssuer
  commonName: <insert-DNS-name-for-cluster>
  dnsNames:
  - <insert-DNS-name-for-cluster>
```

Apply the certificate file:

```
kubectl apply -f uswest2-aws-certificate.yaml
```
It may take several minutes to generate the certificate. You can check on the progress using:

```
kubectl describe certificate <certificate-name> -n pulsar
```

To troubleshoot, look at the logs from the cert-manager pod:

```
kubectl logs cert-manager-75cf57777c-k92rq -n cert-manager
```
