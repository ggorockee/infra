# Prometheus Operator CRD 버전 설정
CRD_VER=v0.72.6
BASE=https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/$CRD_VER/example/prometheus-operator-crd

# 필요한 모든 CRD 한 번에 적용
for crd in \
  alertmanagerconfigs \
  alertmanagers \
  podmonitors \
  prometheuses \
  prometheusrules \
  servicemonitors \
  thanosrulers; do
  kubectl apply --server-side -f "$BASE/monitoring.coreos.com_${crd}.yaml"
done
