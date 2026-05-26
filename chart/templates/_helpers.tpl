{{/*
Expand the name of the vinaros
*/}}
{{- define "vinaros.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "vinaros.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "vinaros.labels" -}}
helm.sh/chart: {{ include "vinaros.chart" . }}
{{ include "vinaros.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "vinaros.selectorLabels" -}}
app.kubernetes.io/name: {{ include "vinaros.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
