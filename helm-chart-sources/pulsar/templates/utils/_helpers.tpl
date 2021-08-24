{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "pulsar.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "pulsar.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Necessary to make proper names for keycloak services (note that it is important that
the .Chart.Name for the keycloak dependent chart does not change.)
*/}}
{{- define "pulsar.keycloak.fullname" -}}
{{- if .Values.keycloak.fullnameOverride -}}
{{- .Values.keycloak.fullnameOverride | trunc 20 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default "keycloak" .Values.keycloak.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 20 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 20 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Get the right protocol depending on whether or not tls is enabled.
*/}}
{{- define "pulsar.get.http.or.https" -}}
{{- if .Values.enableTls -}}
{{- print "https://" -}}
{{- else -}}
{{- print "http://" -}}
{{- end -}}
{{- end -}}

{{/*
Get the colon and port number for the allow listed token issuers from Keycloak
or return the empty string if the port is 80 or 443, as these won't be
part of the issuer URL returned by keycloak in the JWT iss claim.
We print the port number before checking for equality because the numbers are actually floats.
*/}}
{{- define "pulsar.keycloak.issuer.port" -}}
{{- if .Values.enableTls -}}
{{- $port := printf "%v" .Values.keycloak.service.httpsPort -}}
{{- if eq $port "443" -}}
{{- print "" -}}
{{- else -}}
{{- printf ":%v" .Values.keycloak.service.httpsPort -}}
{{- end -}}
{{- else -}}
{{- $port := printf "%v" .Values.keycloak.service.port -}}
{{- if eq $port "80" -}}
{{- print "" -}}
{{- else -}}
{{- printf ":%v" .Values.keycloak.service.port -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pulsar.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "helm-toolkit.utils.joinListWithComma" -}}
{{- $local := dict "first" true -}}
{{- range $k, $v := . -}}{{- if not $local.first -}},{{- end -}}{{- $v -}}{{- $_ := set $local "first" false -}}{{- end -}}
{{- end -}}

{{- define "pulsar.zkConnectString" -}}
{{- $global := . -}}
{{- range $i, $e := until (.Values.zookeeper.replicaCount | int) -}}{{ if ne $i 0 }},{{ end }}{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}{{ end }}
{{- $global := . -}}
{{- range $i, $e := until (.Values.zookeepernp.replicaCount | int) -}},{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeepernp.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeepernp.component }}{{ end }}
{{- end -}}

{{- define "pulsar.bkConnectString" -}}
{{- $global := . -}}
{{- range $i, $e := until (.Values.bookkeeper.replicaCount | int) -}}{{ if ne $i 0 }},{{ end }}bk://{{ template "pulsar.fullname" $global }}-{{ $global.Values.bookkeeper.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.bookkeeper.component }}:4181{{ end }}
{{- end -}}

{{- define "pulsar.zkConnectStringOne" -}}
{{- $global := . -}}
{{- range $i, $e := until 1 -}}{{ if ne $i 0 }},{{ end }}{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}{{ end }}
{{- end -}}

{{- define "pulsar.bkConnectStringOne" -}}
{{- $global := . -}}
{{- range $i, $e := until 1 -}}{{ if ne $i 0 }},{{ end }}bk://{{ template "pulsar.fullname" $global }}-{{ $global.Values.bookkeeper.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.bookkeeper.component }}:4181{{ end }}
{{- end -}}

{{- define "pulsar.zkConnectStringTls" -}}
{{- $global := . -}}
{{- $port := "2281" -}}
{{- range $i, $e := until (.Values.zookeeper.replicaCount | int) -}}{{ if ne $i 0 }},{{ end }}{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}:{{ $port }}{{ end }}
{{- $global := . -}}
{{- $port := "2281" -}}
{{- range $i, $e := until (.Values.zookeepernp.replicaCount | int) -}},{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeepernp.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeepernp.component }}:{{ $port }}{{ end }}
{{- end -}}

{{- define "pulsar.zkConnectStringTlsONe" -}}
{{- $global := . -}}
{{- $port := "2281" -}}
{{- range $i, $e := until 1 -}}{{ if ne $i 0 }},{{ end }}{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}:{{ $port }}{{ end }}
{{- end -}}

{{- define "pulsar.zkServers" -}}
{{- $global := . }}
{{- range $i, $e := until (.Values.zookeeper.replicaCount | int) -}}{{ if ne $i 0 }},{{ end }}{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}-{{ printf "%d" $i }}{{ end }}
{{- $global := . }}
{{- range $i, $e := until (.Values.zookeepernp.replicaCount | int) -}},{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeepernp.component }}-{{ printf "%d" $i }}{{ end }}
{{- end -}}

{{- define "pulsar.zkDomains" -}}
{{- $global := . -}}
{{- range $i, $e := until (.Values.zookeeper.replicaCount | int) -}}{{ if ne $i 0 }},{{ end }}{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeeper.component }}{{ end }}
{{- $global := . -}}
{{- range $i, $e := until (.Values.zookeepernp.replicaCount | int) -}},{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeepernp.component }}-{{ printf "%d" $i }}.{{ template "pulsar.fullname" $global }}-{{ $global.Values.zookeepernp.component }}{{ end }}
{{- end -}}

{{- define "pulsar.proxyAutoPort" -}}
{{- if not .Values.enableTls }}
- name: http
  port: 8080
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8080
  {{- end  }}
- name: pulsar
  port: 6650
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 6650
  {{- end  }}
- name: ws
  port: 8000
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8000
  {{- end  }}
{{- end }}
{{- if .Values.enableTls }}
- name: https
  port: 8443
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8443
  {{- end  }}
- name: pulsarssl
  port: 6651
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 6651
  {{- end  }}
- name: wss
  port: 8001
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8001
  {{- end  }}
  {{- if .Values.proxy.autoPortAssign.enablePlainTextWithTLS }}
- name: http
  port: 8080
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8080
  {{- end  }}
- name: pulsar
  port: 6650
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 6650
  {{- end  }}
- name: ws
  port: 8000
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8000
  {{- end  }}
  {{- end }}
{{- end }}
{{- if .Values.extra.pulsarBeam }}
- name: pulsarbeam
  port: 8085
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8085
  {{- end  }}
{{- end }}
{{- if .Values.extra.burnell }}
- name: burnell
  port: 8964
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8964
  {{- end  }}
{{- end }}
{{- if .Values.extra.wsAuthServer }}
- name: wsauth
  port: 8500
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 8500
  {{- end  }}
{{- end }}
{{- if .Values.extra.tokenServer }}
- name: tokenserver
  port: 3000
  protocol: TCP
  {{- if .Values.proxy.autoPortAssign.matchingNodePort }}
  nodePort: 3000
  {{- end  }}
{{- end }}
{{- end }}