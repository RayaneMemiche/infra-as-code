{{/*
=============================================================================
Task Manager API - Template Helpers
C4 Project - Reusable Template Functions
=============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "task-manager-api.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "task-manager-api.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "task-manager-api.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "task-manager-api.labels" -}}
helm.sh/chart: {{ include "task-manager-api.chart" . }}
{{ include "task-manager-api.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: c4-project
{{- end }}

{{/*
Selector labels
*/}}
{{- define "task-manager-api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "task-manager-api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "task-manager-api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "task-manager-api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create the name of the configmap to use
*/}}
{{- define "task-manager-api.configmapName" -}}
{{- printf "%s-config" (include "task-manager-api.fullname" .) }}
{{- end }}

{{/*
Create the name of the secret to use
*/}}
{{- define "task-manager-api.secretName" -}}
{{- if .Values.secrets.create }}
{{- printf "%s-secrets" (include "task-manager-api.fullname" .) }}
{{- else }}
{{- .Values.secrets.existingSecret }}
{{- end }}
{{- end }}
