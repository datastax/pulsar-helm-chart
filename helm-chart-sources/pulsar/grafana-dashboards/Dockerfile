FROM grafana/grafana-oss:latest

COPY *.json /var/lib/grafana/dashboards/

COPY provider.yaml /etc/grafana/provisioning/dashboards/pulsar.yaml
COPY pulsar-datasource.yaml /etc/grafana/provisioning/datasources/pulsar.yaml
