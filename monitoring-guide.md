# K8s 리소스 사용률 모니터링 가이드

## 📊 현재 모니터링 도구 확인

### Prometheus + Grafana 활용

```bash
# Grafana 접속
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80

# Default credentials
# Username: admin
# Password: prom-operator (또는 values.yaml에서 확인)
```

### 필수 모니터링 메트릭

#### 1. 노드별 리소스 사용률
```promql
# CPU 요청률
sum(kube_pod_container_resource_requests{resource="cpu"}) by (node) / 
sum(kube_node_status_allocatable{resource="cpu"}) by (node) * 100

# CPU 실제 사용률  
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (node) /
sum(kube_node_status_allocatable{resource="cpu"}) by (node) * 100

# Memory 요청률
sum(kube_pod_container_resource_requests{resource="memory"}) by (node) /
sum(kube_node_status_allocatable{resource="memory"}) by (node) * 100
```

#### 2. Pod별 리소스 사용량
```promql
# CPU 사용량 (top 10)
topk(10, rate(container_cpu_usage_seconds_total{container!=""}[5m]))

# Memory 사용량 (top 10)
topk(10, container_memory_working_set_bytes{container!=""})
```

#### 3. 네임스페이스별 리소스 합계
```promql
# CPU 요청 총합
sum(kube_pod_container_resource_requests{resource="cpu"}) by (namespace)

# Memory 요청 총합
sum(kube_pod_container_resource_requests{resource="memory"}) by (namespace)
```

## 🚨 알림 설정 (AlertManager)

### CPU 과다 요청 알림
```yaml
# charts/helm/prod/monitoring/values.yaml
prometheusRule:
  - alert: HighCPURequest
    expr: |
      sum(kube_pod_container_resource_requests{resource="cpu"}) by (node) /
      sum(kube_node_status_allocatable{resource="cpu"}) by (node) > 0.85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "노드 {{ $labels.node }}의 CPU 요청률이 85%를 초과했습니다"
```

### Pod OOMKilled 알림
```yaml
  - alert: PodOOMKilled
    expr: |
      rate(kube_pod_container_status_restarts_total[5m]) > 0
      and
      kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} == 1
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Pod {{ $labels.namespace }}/{{ $labels.pod }}가 메모리 부족으로 종료되었습니다"
```

## 📈 대시보드 Import

### Grafana 추천 대시보드 ID
1. **Kubernetes Cluster Monitoring**: 7249
2. **Kubernetes Pods**: 6417
3. **Node Exporter Full**: 1860

```bash
# Grafana UI에서 Import
# + → Import → Dashboard ID 입력 → Load
```

## 🔧 kubectl 명령어로 실시간 모니터링

```bash
# 실시간 Pod 리소스 모니터링 (5초마다 갱신)
watch -n 5 'kubectl top pods --all-namespaces --sort-by=cpu | head -20'

# 노드별 리소스 사용률
watch -n 5 'kubectl top nodes'

# 특정 네임스페이스 모니터링
watch -n 5 'kubectl top pods -n hotsao'
```

## 📝 정기 점검 체크리스트

### 주간 점검 (매주 월요일)
- [ ] 노드별 CPU/Memory 요청률 확인
- [ ] OOMKilled Pod 발생 여부 확인
- [ ] 스케줄링 실패한 Pod 확인 (`kubectl get events`)

### 월간 점검 (매월 1일)
- [ ] 리소스 사용 트렌드 분석 (Grafana 대시보드)
- [ ] 과다/과소 설정된 Pod 식별
- [ ] 노드 스케일링 필요성 검토

## 🎯 최적화 목표 지표

| 메트릭 | 목표값 | 현재값 | 상태 |
|--------|--------|--------|------|
| 노드 CPU 요청률 | 60-75% | 71-97% → 50-70% (예상) | ✅ 개선 예상 |
| 노드 Memory 요청률 | 60-75% | 45-69% | ✅ 적정 |
| Pod OOMKill 발생률 | 0% | TBD | 📊 모니터링 필요 |
| 스케줄링 실패율 | 0% | TBD | 📊 모니터링 필요 |
