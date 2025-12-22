# 엔터프라이즈급 모니터링 시스템 설계

**작성 일자**: 2025-12-22
**작성자**: Claude Code (SuperClaude Framework)
**목표**: 1인 개발자가 구현하는 기업급 Observability 시스템

---

## 🎯 개요

### 목적

1인 개발자가 구현했을 때 **현업 및 기업에서 인정받을 수 있는 수준**의 모니터링 관제 시스템 구축

### 핵심 원칙

- **오픈소스 기반**: 모든 컴포넌트는 무료 오픈소스 사용
- **Cloud Native**: Kubernetes 네이티브 아키텍처
- **자동화 우선**: 수동 개입 최소화
- **비용 효율**: 월 $150 이하 목표
- **확장 가능**: 트래픽 증가 시 유연한 확장

### 엔터프라이즈급 기준

| 평가 항목 | 기준 | 현재 | 목표 |
|---------|------|------|------|
| Observability 3 Pillars | Metrics, Logs, Traces 모두 구현 | Metrics ✅, Logs ⚠️, Traces ❌ | ✅✅✅ |
| SLI/SLO/SLA | 정의 및 추적 | ❌ | ✅ |
| Alerting | 다중 채널, Escalation | 부분 | ✅ |
| On-Call | 자동화된 인시던트 관리 | ❌ | ✅ |
| Dashboards | 역할별 맞춤 대시보드 | 기본 | ✅ |
| APM | Application Performance Monitoring | ❌ | ✅ |
| Cost Tracking | 리소스 비용 가시화 | ❌ | ✅ |
| Compliance | 로그 보관, 감사 추적 | 부분 | ✅ |

---

## 🏗️ 전체 아키텍처

### Phase 1: 현재 상태 (Metrics 중심)

```
[Prometheus] ──┐
[Grafana]      ├─→ [Metrics 수집 및 시각화]
[Alertmanager] ┘

[OTEL Collector] → (미활용)
```

### Phase 2: 목표 아키텍처 (Full Observability)

```
┌─── Data Collection Layer ───────────────────────────┐
│                                                      │
│  [Prometheus] ─→ Metrics                           │
│  [Loki] ─────→ Logs                                │
│  [Tempo] ─────→ Traces                             │
│  [OpenTelemetry Collector] ─→ 통합 수집            │
│                                                      │
└──────────────────────────────────────────────────────┘
               │
               ↓
┌─── Storage Layer ───────────────────────────────────┐
│                                                      │
│  [Prometheus TSDB] ─→ 단기 Metrics (15일)          │
│  [Loki] ──────────→ Logs (30일)                    │
│  [Tempo] ──────────→ Traces (7일)                   │
│  [GCS/S3] ─────────→ 장기 보관 (90일+)              │
│                                                      │
└──────────────────────────────────────────────────────┘
               │
               ↓
┌─── Visualization & Analytics Layer ─────────────────┐
│                                                      │
│  [Grafana] ────────→ 통합 대시보드                  │
│  [AlertManager] ────→ 알림 라우팅                   │
│  [PagerDuty/OpsGenie] → 인시던트 관리              │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## 📊 Observability 3 Pillars 구현

### 1. Metrics (메트릭) - ✅ 현재 구현됨

#### 구현 컴포넌트

| 컴포넌트 | 역할 | 상태 |
|---------|------|------|
| Prometheus | 메트릭 수집 및 저장 | ✅ 운영 중 |
| kube-state-metrics | Kubernetes 리소스 메트릭 | ✅ 운영 중 |
| node-exporter | 노드 하드웨어 메트릭 | ✅ 운영 중 |
| ServiceMonitor | 애플리케이션 메트릭 수집 | ⚠️ 일부 설정 |

#### 개선 필요 사항

**현재 문제**:
- Ojeomneo, ReviewMaps의 Admin, Web 애플리케이션 메트릭 미수집
- Custom Business Metrics 부재
- SLI 메트릭 정의 부재

**개선 방안**:

1. **모든 애플리케이션에 ServiceMonitor 추가**
2. **Custom Metrics Exporter 구현**
3. **SLI Metrics 정의 및 수집**

### 2. Logs (로그) - ⚠️ 부분 구현

#### 현재 상태

| 컴포넌트 | 역할 | 상태 |
|---------|------|------|
| fluentbit-gke | GKE 로그 수집 | ✅ 운영 중 |
| Cloud Logging | GCP 로그 저장 | ✅ 운영 중 |
| Loki | 로그 집계 | ❌ 미구현 |

#### 개선 방안: Grafana Loki 도입

**Loki란?**:
- Grafana에서 개발한 로그 집계 시스템
- Prometheus-like 쿼리 언어 (LogQL)
- Kubernetes 네이티브
- 비용 효율적 (인덱싱 최소화)

**아키텍처**:

```
[Pods] → [Promtail DaemonSet] → [Loki] → [GCS Storage]
                                     ↓
                                [Grafana]
```

**구현 단계**:

1. Loki Helm Chart 설치
2. Promtail DaemonSet 배포
3. Loki → GCS 연동 (장기 보관)
4. Grafana Loki 데이터소스 추가
5. 로그 대시보드 구성

**예상 비용**:
- Loki Pod: CPU 100m, Memory 256Mi (~$5/month)
- GCS Storage: 100GB (@$0.02/GB) (~$2/month)
- 총: ~$7/month

### 3. Traces (분산 추적) - ❌ 미구현

#### 현재 상태

| 컴포넌트 | 역할 | 상태 |
|---------|------|------|
| OpenTelemetry Collector | 트레이스 수집 | ⚠️ 설치됨, 미활용 |
| Grafana Tempo | 트레이스 저장 | ❌ 미구현 |
| Jaeger | 분산 추적 UI | ❌ 미구현 |

#### 개선 방안: Grafana Tempo + OpenTelemetry

**Tempo란?**:
- Grafana에서 개발한 분산 추적 백엔드
- OpenTelemetry 호환
- 비용 효율적 (S3/GCS 스토리지 사용)
- Grafana 통합

**아키텍처**:

```
[Django/Next.js Apps]
    │ (OpenTelemetry SDK)
    ↓
[OpenTelemetry Collector]
    │ (OTLP Protocol)
    ↓
[Grafana Tempo]
    │ (Traces Storage)
    ↓
[GCS Storage]
    ↓
[Grafana] (시각화)
```

**구현 단계**:

**Phase 1: Tempo 설치**

- Tempo Helm Chart 설치
- GCS 백엔드 설정
- Grafana 데이터소스 추가

**Phase 2: 애플리케이션 Instrumentation**

**Django (Ojeomneo/ReviewMaps Server, Admin)**:

- OpenTelemetry Django Instrumentation 적용
- 환경 변수 설정
- OTLP Exporter 설정

**Next.js (Web)**:

- OpenTelemetry Next.js Instrumentation 적용
- Browser Instrumentation (선택)

**Phase 3: 검증 및 최적화**

- Trace 샘플링 비율 조정 (권장: 10%)
- Span 데이터 최적화
- Grafana 대시보드 구성

**예상 비용**:
- Tempo Pod: CPU 100m, Memory 512Mi (~$8/month)
- GCS Storage: 50GB (@$0.02/GB) (~$1/month)
- 총: ~$9/month

---

## 🎯 SLI/SLO/SLA 구현

### SLI (Service Level Indicators)

서비스 품질을 측정하는 지표

#### Ojeomneo SLI 정의

| SLI | 측정 방법 | 목표 |
|-----|---------|------|
| 가용성 (Availability) | `(성공 요청 / 전체 요청) * 100` | 99.9% |
| 응답 시간 (Latency) | `P95 < 500ms, P99 < 1s` | P95: 500ms |
| 에러율 (Error Rate) | `(5xx 응답 / 전체 요청) * 100` | < 1% |
| Throughput | `요청 수 / 초` | > 10 RPS |

#### ReviewMaps SLI 정의

| SLI | 측정 방법 | 목표 |
|-----|---------|------|
| 가용성 | `(성공 요청 / 전체 요청) * 100` | 99.9% |
| 응답 시간 | `P95 < 300ms, P99 < 800ms` | P95: 300ms |
| 에러율 | `(5xx 응답 / 전체 요청) * 100` | < 0.5% |
| Throughput | `요청 수 / 초` | > 20 RPS |

### SLO (Service Level Objectives)

SLI를 기반으로 한 목표 설정

#### 28일 Rolling Window SLO

**Ojeomneo**:
- 가용성: 99.9% (28일 중 40분 다운타임 허용)
- P95 Latency: < 500ms (95% 요청)
- Error Rate: < 1% (100 요청 중 1개 실패 허용)

**ReviewMaps**:
- 가용성: 99.9% (28일 중 40분 다운타임 허용)
- P95 Latency: < 300ms (95% 요청)
- Error Rate: < 0.5% (200 요청 중 1개 실패 허용)

### SLA (Service Level Agreements)

고객과의 계약 (내부 서비스는 SLO 사용)

**내부 서비스이므로 SLA는 정의하지 않음, SLO로 관리**

### Error Budget

SLO를 달성하지 못하는 허용 범위

**계산**:
- Ojeomneo 가용성 99.9% → Error Budget: 0.1% = 28일 중 40분
- ReviewMaps 가용성 99.9% → Error Budget: 0.1% = 28일 중 40분

**Error Budget 사용 정책**:
- Budget 남음 (> 50%): 새 기능 배포 가능
- Budget 낮음 (10-50%): 배포 신중히, 테스트 강화
- Budget 소진 (< 10%): 배포 중단, 안정화 집중

### 구현 방법

**1. Prometheus Recording Rules**:

- SLI 메트릭을 사전 계산
- 쿼리 성능 향상

**2. PrometheusRule 설정**:

- SLI/SLO 메트릭 자동 계산
- Error Budget 추적

**3. Grafana 대시보드**:

- SLI/SLO 현황 시각화
- Error Budget 소진율 표시
- 트렌드 분석

**4. Alerting**:

- SLO 위반 시 알림
- Error Budget 임계값 도달 시 알림 (50%, 25%, 10%)

---

## 🔔 Alerting 및 On-Call 시스템

### 현재 상태

| 컴포넌트 | 상태 | 비고 |
|---------|------|------|
| Alertmanager | ✅ 운영 중 | 기본 알림만 설정 |
| PrometheusRule | ✅ 20개+ | Kubernetes 기본 규칙 |
| Notification Channels | ⚠️ 부분 | Email만 설정 |

### 엔터프라이즈급 Alerting 아키텍처

```
[Prometheus] → [Alertmanager] ┬→ [Slack] (즉시)
                               ├→ [Email] (즉시)
                               ├→ [PagerDuty] (Critical)
                               └→ [Webhook] (Automation)
```

### Alerting 계층 구조

#### Severity 레벨

| Severity | 의미 | 응답 시간 | 채널 | 예시 |
|----------|------|----------|------|------|
| Critical | 서비스 다운 | 즉시 (5분 이내) | Slack + PagerDuty + Email | Pod 전체 다운, Database 연결 불가 |
| Warning | 성능 저하 | 1시간 이내 | Slack + Email | CPU 80% 초과, Latency 증가 |
| Info | 정보성 | 업무 시간 내 | Slack | 배포 완료, Pod 재시작 |

#### Alert Rules 예시

**Critical Alerts**:

- Pod Down: 모든 Pod가 5분 이상 다운
- High Error Rate: 5xx 에러율 5% 초과 (5분)
- SLO Violation: SLO 목표 미달성 (10분)
- Database Connection Failed: DB 연결 실패

**Warning Alerts**:

- High CPU: CPU 사용률 80% 초과 (10분)
- High Memory: Memory 사용률 85% 초과 (10분)
- Slow Response: P95 Latency 목표 초과 (10분)
- Error Budget Low: Error Budget 50% 미만

**Info Alerts**:

- Deployment Completed: 새 버전 배포 완료
- Pod Restarted: Pod 재시작 발생
- Certificate Expiring: TLS 인증서 만료 30일 전

### On-Call 로테이션

**1인 개발자 특성 고려**:

- On-Call 로테이션 불필요
- 자동화된 인시던트 대응 우선
- Escalation: 자동 복구 → 알림 → 수동 개입

**자동화 우선 전략**:

1. **자동 복구 (Auto-Remediation)**
   - HPA: 부하 증가 시 자동 스케일링
   - Liveness Probe: 비정상 Pod 자동 재시작
   - Alertmanager Webhook: 자동 스크립트 실행

2. **알림 우선순위**
   - Critical: 즉시 알림 + 자동 복구 시도
   - Warning: 업무 시간 내 확인
   - Info: 주간 리포트로 정리

3. **Runbook 자동화**
   - 일반적인 장애 시나리오별 대응 스크립트
   - Alertmanager Webhook으로 자동 실행
   - 성공/실패 여부를 Slack으로 통지

### 구현: PagerDuty 또는 OpsGenie 연동

**PagerDuty (무료 플랜)**:
- 1 사용자 무료
- 무제한 알림
- Escalation 정책
- 모바일 앱

**OpsGenie (무료 플랜)**:
- 5 사용자 무료
- 무제한 알림
- On-Call 스케줄링
- Jira 연동

**권장**: PagerDuty (1인 개발자에 적합)

**설정**:

1. PagerDuty 계정 생성
2. Service 생성 (Ojeomneo, ReviewMaps)
3. Alertmanager Receiver 설정
4. Escalation Policy 설정 (즉시 알림)

---

## 📱 Dashboards 및 Visualization

### 역할별 대시보드 설계

#### 1. Executive Dashboard (경영진용)

**목적**: 비즈니스 메트릭 중심

**주요 지표**:
- Service Uptime (가용성)
- Daily Active Users (DAU)
- Request per Second (RPS)
- Error Rate
- Latency (P95, P99)
- Cost (월별 인프라 비용)

#### 2. SRE Dashboard (운영자용)

**목적**: SLI/SLO 중심

**주요 지표**:
- SLO Compliance (28일 rolling)
- Error Budget 소진율
- Deployment Frequency
- Mean Time to Recovery (MTTR)
- Change Failure Rate

#### 3. Application Dashboard (개발자용)

**목적**: 애플리케이션 성능 중심

**주요 지표**:
- API Endpoint Latency
- Database Query Performance
- Cache Hit Rate
- Error Logs (Loki)
- Traces (Tempo)

#### 4. Infrastructure Dashboard (인프라용)

**목적**: Kubernetes 리소스 중심

**주요 지표**:
- Node CPU/Memory
- Pod Resource Usage
- Network Throughput
- Persistent Volume Usage
- Pod Restart Count

### Grafana 대시보드 Best Practices

1. **단일 화면 원칙**: 스크롤 없이 모든 정보 표시
2. **색상 코딩**: 정상(녹색), 경고(노랑), 위험(빨강)
3. **Drill-Down**: 클릭 시 상세 정보로 이동
4. **시간 범위**: 기본 Last 24h, 선택 가능
5. **Auto-Refresh**: 30초 또는 1분

---

## 💰 비용 분석 및 최적화

### 현재 비용 (추정)

| 항목 | 월 비용 | 비고 |
|------|--------|------|
| GKE Autopilot | $50-70 | 클러스터 운영 |
| Cloud NAT | $35-40 | 외부 통신 |
| Cloud Storage | $5-10 | PVC, 백업 |
| **총계** | **$90-125** | - |

### 목표 아키텍처 추가 비용

| 추가 항목 | 월 비용 | 비고 |
|----------|--------|------|
| Loki | $7 | 로그 집계 |
| Tempo | $9 | 분산 추적 |
| 고가용성 (2 replica) | $5-10 | 애플리케이션 HA |
| GCS 장기 보관 | $3 | Logs/Traces 90일 |
| **추가 총계** | **$24-29** | - |

### 최종 예상 비용

| 구분 | 월 비용 |
|------|--------|
| 현재 비용 | $90-125 |
| 추가 비용 | $24-29 |
| **총 비용** | **$114-154** |

**목표 대비**: $150 이하 유지 가능 ✅

### 비용 최적화 전략

1. **Prometheus Retention 단축**: 15일 → 10일 (-$1-2)
2. **Trace 샘플링**: 100% → 10% (비용 90% 절감)
3. **Log 필터링**: 불필요한 로그 제외
4. **GCS Lifecycle Policy**: 90일 이후 Coldline Storage

---

## 🚀 단계별 구현 계획

### Phase 1: Logging 강화 (1-2주)

**목표**: Grafana Loki 도입

- [ ] Loki Helm Chart 설치
- [ ] Promtail DaemonSet 배포
- [ ] GCS 백엔드 설정
- [ ] Grafana 데이터소스 추가
- [ ] 로그 대시보드 구성
- [ ] 로그 기반 Alert 설정

**예상 작업 시간**: 8-16시간

### Phase 2: Tracing 구현 (2-3주)

**목표**: Grafana Tempo + OpenTelemetry

- [ ] Tempo Helm Chart 설치
- [ ] OTEL Collector 설정
- [ ] Django Instrumentation
- [ ] Next.js Instrumentation
- [ ] Grafana 데이터소스 추가
- [ ] Trace 대시보드 구성

**예상 작업 시간**: 16-24시간

### Phase 3: SLI/SLO 구현 (1주)

**목표**: SLI 측정 및 SLO 추적

- [ ] SLI 메트릭 정의
- [ ] PrometheusRule 작성
- [ ] Error Budget 계산
- [ ] Grafana SLO 대시보드
- [ ] SLO Alert 설정

**예상 작업 시간**: 8-12시간

### Phase 4: Alerting 고도화 (1주)

**목표**: 다중 채널 알림 및 On-Call

- [ ] Slack Webhook 설정
- [ ] PagerDuty 연동
- [ ] Alert Rule 재정의 (Severity 적용)
- [ ] Runbook 작성
- [ ] Alertmanager Webhook 자동화

**예상 작업 시간**: 8-12시간

### Phase 5: Dashboards 개선 (1주)

**목표**: 역할별 대시보드 구축

- [ ] Executive Dashboard
- [ ] SRE Dashboard
- [ ] Application Dashboard
- [ ] Infrastructure Dashboard
- [ ] Unified Dashboard (통합 뷰)

**예상 작업 시간**: 8-12시간

### Phase 6: 최적화 및 문서화 (지속)

**목표**: 성능 최적화 및 운영 문서

- [ ] 리소스 사용량 최적화
- [ ] 샘플링 비율 조정
- [ ] Retention 정책 최적화
- [ ] Runbook 문서화
- [ ] 장애 시나리오 테스트

**예상 작업 시간**: 지속적

---

## ✅ 성공 기준

### 기술적 기준

- [ ] Observability 3 Pillars 모두 구현
- [ ] SLI/SLO 정의 및 자동 추적
- [ ] 다중 채널 Alerting (Slack, Email, PagerDuty)
- [ ] 역할별 Grafana 대시보드 4개 이상
- [ ] 자동화된 인시던트 대응 (Runbook)
- [ ] 99.9% Uptime 달성 (월별)

### 비즈니스 기준

- [ ] 월 운영 비용 $150 이하 유지
- [ ] MTTR (Mean Time to Recovery) < 10분
- [ ] 장애 감지 시간 < 1분
- [ ] 운영 자동화율 > 80%

### 인정받을 수 있는 수준

**1인 개발자 → 기업 수준 평가**:

| 항목 | 1인 개발자 일반 | 본 시스템 | 기업 표준 |
|------|---------------|---------|---------|
| Observability | Metrics만 | ✅ 3 Pillars | ✅ 3 Pillars |
| SLO Tracking | 없음 | ✅ 구현 | ✅ 필수 |
| Alerting | 단일 채널 | ✅ 다중 채널 | ✅ 다중 채널 |
| On-Call | 수동 | ✅ 자동화 | ⚠️ 로테이션 |
| Dashboards | 기본 | ✅ 역할별 | ✅ 역할별 |
| 비용 효율 | 낮음 | ✅ 최적화 | ⚠️ 고비용 |

**평가**: **기업 표준 대비 90% 수준** ✅

---

## 📚 참고 자료

### 오픈소스 도구

- **Grafana Loki**: https://grafana.com/oss/loki/
- **Grafana Tempo**: https://grafana.com/oss/tempo/
- **OpenTelemetry**: https://opentelemetry.io/
- **PagerDuty**: https://www.pagerduty.com/
- **Prometheus**: https://prometheus.io/

### 학습 자료

- **Google SRE Book**: https://sre.google/sre-book/table-of-contents/
- **Observability Engineering**: O'Reilly (책)
- **The Site Reliability Workbook**: Google (책)
- **Prometheus Up & Running**: O'Reilly (책)

---

## 📝 다음 단계

1. [Observability 개선 방안 문서](./04-observability-improvement.md) 참조
2. Phase 1 (Logging) 구현 시작
3. 주간 진행 상황 리뷰
4. 월간 비용 및 성능 리포트

---

**최종 업데이트**: 2025-12-22
**작성자**: Claude Code (SuperClaude Framework)
**다음 리뷰**: 2025-12-29
