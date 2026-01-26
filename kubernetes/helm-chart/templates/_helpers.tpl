{{/*
Expand the name of the chart.
*/}}
{{- define "misp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "misp.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified app name for misp-modules.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "misp.modules.fullname" -}}
{{ printf "%s-%s" (include "misp.fullname" .) "modules" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "misp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
MISP NP matchLabels
*/}}
{{- define "misp.matchLabels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels for MISP
*/}}
{{- define "misp.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: {{ .Release.Name }}
helm.sh/chart: {{ include "misp.chart" . }}
{{ include "misp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for MISP
*/}}
{{- define "misp.selectorLabels" -}}
app.kubernetes.io/component: "misp"
app.kubernetes.io/part-of: {{ include "misp.name" . }}
{{- end }}

{{/*
Common labels for MISP Modules
*/}}
{{- define "misp.modules.labels" -}}
helm.sh/chart: {{ include "misp.chart" . }}
{{ include "misp.modules.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels for MISP Modules
*/}}
{{- define "misp.modules.selectorLabels" -}}
app.kubernetes.io/name: {{ include "misp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: "modules"
app.kubernetes.io/part-of: {{ include "misp.name" . }}
{{- end }}

{{/*
{{/*
 Returns the proper service account name depending if an explicit service account name is set
 in the values file. If the name is not set it will default to either Release.Name if serviceAccount.create
 is true or default otherwise.
*/}}
*/}}
{{- define "misp.serviceAccountName" -}}
{{- if .Values.misp.serviceAccount.create }}
{{- default .Release.Name .Values.misp.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.misp.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Validates that the values of isCore.enabled and isTransit.enabled
are not both set to true or both set to false at the same time.
*/}}
{{- define "validateCoreAndTransit" -}}
{{- if and .Values.misp.isCore.enabled .Values.misp.isTransit.enabled -}}
  {{- fail "Both isCore.enabled and isTransit.enabled cannot be true at the same time." -}}
{{- end -}}
{{- if and (not .Values.misp.isCore.enabled) (not .Values.misp.isTransit.enabled) -}}
  {{- fail "Both isCore.enabled and isTransit.enabled cannot be false at the same time." -}}
{{- end -}}
{{- end -}}

{{- define "validateIstioAndIngress" -}}
{{- if and (hasKey .Values.misp "istio") (hasKey .Values.misp "ingress") -}}
  {{- if and .Values.misp.istio.enabled .Values.misp.ingress.enabled -}}
    {{- print "Both istio.enabled and ingress.enabled cannot be true at the same time." -}}
  {{/*
  {{- else if and (not .Values.misp.istio.enabled) (not .Values.misp.ingress.enabled) -}}
    {{- print "Both istio.enabled and ingress.enabled cannot be false at the same time." -}}
  */}}
  {{- else -}}
    {{- print "" -}}
  {{- end -}}
{{- else -}}
  {{- print "istio and ingress configurations must be defined." -}}
{{- end -}}
{{- end -}}

{{/*
Return the secret with MISP credentials
*/}}
{{- define "misp.secretName" -}}
    {{- if .Values.misp.auth.existingSecret -}}
        {{- printf "%s" (tpl .Values.misp.auth.existingSecret $) -}}
    {{- else -}}
        {{- printf "%s-misp-secrets" (include "common.names.fullname" .) -}}
    {{- end -}}
{{- end -}}

{{/*
Return the secret with config user credentials
*/}}
{{- define "misp.configUserSecret" -}}
  {{- if .Values.misp.mispConfig.disableInitialAdmin.existingSecret -}}
    {{- printf "%s" (tpl .Values.misp.mispConfig.disableInitialAdmin.existingSecret $) -}}
  {{- else -}}
    {{- printf "%s-config-user" (include "common.names.fullname" .) -}}
  {{- end -}}
{{- end -}}

{{/*
Return true if a secret object should be created for MISP
*/}}
{{- define "misp.createSecret" -}}
{{- if and (not .Values.misp.auth.existingSecret) (not .Values.misp.auth.customPasswordFiles) }}
    {{- true -}}
{{- end -}}
{{- end -}}

{{/*
Return the configmap name for mispCronjobs
*/}}
{{- define "misp.cronjobConfigMapName" -}}
{{ printf "%s-cronjobs" .Release.Name }}
{{- end }}

