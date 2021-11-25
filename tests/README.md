# CI tests

### Running locally

```
export SKIP_YQ_INSTALL=1
./tests/e2e-kind.sh
```

### Debugging the test run

Get a shell inside the ct container
```
docker exec -it ct bash
```

`kubectl` can be used.

examples:
```
# list all resources in all namespaces
kubectl get all -A

# watch for k8s events
kubectl get events -wA

# find out the namespace used
kubectl get namespaces -o=name |grep pulsar

# get logs for a crashed container
kubectl logs -n pulsar-d2t71e2zm3 -p pod/pulsar-function-0
```
