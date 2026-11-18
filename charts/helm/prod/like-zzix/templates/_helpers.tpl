{{- define "like-zzix.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "like-zzix.fullname" -}}
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

{{- define "like-zzix.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "like-zzix.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "like-zzix.selectorLabels" -}}
app.kubernetes.io/name: {{ include "like-zzix.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* 관리자 콘솔(정적 SPA) — 서버 Service·ServiceMonitor 셀렉터와 겹치지 않도록 name을 따로 둔다 */}}
{{- define "like-zzix.adminName" -}}
{{- printf "%s-admin" (include "like-zzix.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "like-zzix.adminSelectorLabels" -}}
app.kubernetes.io/name: {{ include "like-zzix.name" . }}-admin
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "like-zzix.adminLabels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "like-zzix.adminSelectorLabels" . }}
app.kubernetes.io/version: {{ .Values.admin.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
