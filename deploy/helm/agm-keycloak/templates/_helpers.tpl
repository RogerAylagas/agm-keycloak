{{/*
Expand the name of the chart.
*/}}
{{- define "agm-keycloak.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "agm-keycloak.fullname" -}}
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
{{- define "agm-keycloak.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "agm-keycloak.labels" -}}
helm.sh/chart: {{ include "agm-keycloak.chart" . }}
{{ include "agm-keycloak.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "agm-keycloak.selectorLabels" -}}
app.kubernetes.io/name: {{ include "agm-keycloak.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Keycloak image
*/}}
{{- define "agm-keycloak.image" -}}
{{ .Values.keycloak.image.repository }}:{{ .Values.keycloak.image.tag | default .Values.global.imageTag }}
{{- end }}

{{/*
PostgreSQL image
*/}}
{{- define "agm-keycloak.postgres.image" -}}
{{ .Values.database.postgresql.image }}
{{- end }}

{{/*
Nginx image
*/}}
{{- define "agm-keycloak.nginx.image" -}}
{{ .Values.nginx.image.repository }}:{{ .Values.nginx.image.tag | default .Values.global.imageTag }}
{{- end }}

{{/*
Database host
*/}}
{{- define "agm-keycloak.db.host" -}}
{{- if eq .Values.database.provider "local" }}
agm-keycloak-postgres
{{- else }}
{{ .Values.database.host }}
{{- end }}
{{- end }}

{{/*
Service Account Name
*/}}
{{- define "agm-keycloak.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{ include "agm-keycloak.fullname" . }}
{{- else }}
{{ .Values.serviceAccount.name | default "default" }}
{{- end }}
{{- end }}
