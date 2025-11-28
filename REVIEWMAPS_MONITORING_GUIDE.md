# ReviewMaps 통합 모니터링 구현 가이드

## 📊 현재 상태

### ✅ 이미 동작하는 메트릭 (django-prometheus 기본)
- HTTP 요청/응답 통계 (`django_http_requests_*`, `django_http_responses_*`)
- Request Latency (`django_http_requests_latency_*`)
- DB 쿼리 통계 (`django_db_execute_*`, `django_db_query_duration_*`)
- DB 연결 (`django_db_new_connections_*`)
- DB 에러 (`django_db_errors_*`)
- 캐시 통계 (`django_cache_get_*`, `django_cache_get_hits_*`)
- Process 메트릭 (`process_resident_memory_bytes`, `process_cpu_seconds_total`)

---

## 🎯 추가 구현 필요한 커스텀 메트릭 (Django Server)

### 1. **비즈니스 로직 메트릭**

#### Campaign 관리
- `reviewmaps_campaign_active_total` (Gauge)
  - 라벨: `region`
  - 현재 활성 캠페인 수

- `reviewmaps_campaign_expired_total` (Counter)
  - 라벨: `region`
  - 만료된 캠페인 수

#### 데이터 enrichment
- `reviewmaps_enrichment_total` (Counter)
  - 라벨: `scope` (region/all), `status` (success/failed)
  - Enrichment 작업 횟수

- `reviewmaps_enrichment_duration_seconds` (Histogram)
  - 라벨: `scope`
  - Enrichment 소요 시간

---

### 2. **외부 API 호출 추적**

#### Naver API
- `reviewmaps_naver_api_calls_total` (Counter)
  - 라벨: `endpoint`, `status_code`
  - Naver API 호출 횟수

- `reviewmaps_naver_api_duration_seconds` (Histogram)
  - 라벨: `endpoint`
  - API 응답 시간

- `reviewmaps_naver_api_rate_limit_hits` (Counter)
  - Rate limit 도달 횟수

---

### 3. **데이터베이스 테이블별 메트릭**

#### 테이블 크기 추적
- `reviewmaps_table_rows_total` (Gauge)
  - 라벨: `table_name` (campaign/reviews)
  - 테이블 행 수

- `reviewmaps_table_size_bytes` (Gauge)
  - 라벨: `table_name`
  - 테이블 크기 (바이트)

#### Cleanup 작업
- `reviewmaps_cleanup_deleted_rows` (Counter)
  - 라벨: `table_name`
  - 정리된 행 수

---

### 4. **애플리케이션 헬스 메트릭**

#### 서비스 상태
- `reviewmaps_service_up` (Gauge)
  - 라벨: `service` (django/scraper/database)
  - 서비스 UP/DOWN 상태 (1/0)

#### 에러 추적
- `reviewmaps_exceptions_total` (Counter)
  - 라벨: `exception_type`, `view_name`
  - 발생한 예외 타입별 횟수

---

## 🔧 구현 위치 (Django Server만)

### Django Server (`reviewmaps-server`)
**파일: `metrics.py` (새로 생성)**
- 모든 커스텀 메트릭 정의
- Counter, Histogram, Gauge 선언

**파일: `middleware.py`**
- 예외 추적 미들웨어
- 서비스 상태 체크

**파일: `views.py` / `serializers.py`**
- API 호출 시 메트릭 증가
- 비즈니스 로직에 메트릭 삽입

**파일: `management/commands/collect_db_metrics.py` (새로 생성)**
- 주기적으로 테이블 통계 수집
- Gauge 메트릭 업데이트
- Celery Beat 또는 별도 스케줄러로 실행

---

## 📈 Grafana 대시보드 구성

### Row 1: 전체 시스템 상태 (한눈에 보기)
- 서비스 UP/DOWN 상태
- 총 요청 수 (RPS)
- 에러율 (5XX / Total)
- 평균 응답 시간
- 메모리 & CPU 사용률

### Row 2: Django 서버 성능
- Request Latency (P50, P95, P99)
- Top 10 느린 엔드포인트
- HTTP Status 분포
- DB 쿼리 성능

### Row 3: 비즈니스 메트릭
- 활성 캠페인 수 (지역별)
- Naver API 호출 통계
- API Rate Limit 상태
- Enrichment 작업 통계

### Row 4: 데이터베이스
- 테이블 크기 추이 (campaign, reviews)
- 연결 풀 상태
- Cleanup 작업 통계
- DB 에러 발생 빈도

### Row 5: 에러 & 알람
- 예외 타입별 발생 빈도
- 최근 에러 로그 (Table)
- DB 연결 에러
- API 장애 알림

---

## 🚨 알람 설정 (Prometheus Alert Rules)

### Critical (즉시 조치 필요)
1. **서비스 다운**
   - `reviewmaps_service_up == 0`
   - 5분 이상 지속 시 알람

2. **DB 연결 에러**
   - `django_db_new_connection_errors_total > 10`
   - 1분 내 10회 이상

3. **높은 에러율**
   - `5XX 응답 > 5%`
   - 5분 평균

### Warning (모니터링 필요)
1. **느린 응답**
   - `P95 latency > 1초`
   - 10분 평균

2. **API Rate Limit 근접**
   - `reviewmaps_naver_api_rate_limit_hits > 0`

---

## 📦 배포 후 확인사항

### 1. Django Server 재배포 후
```bash
# /metrics 엔드포인트 확인
kubectl port-forward -n reviewmaps svc/reviewmaps-server 8000:8000
curl http://localhost:8000/metrics | grep reviewmaps_

# 기대 결과: reviewmaps_ 로 시작하는 커스텀 메트릭들이 보여야 함
```

### 2. Prometheus에서 메트릭 수집 확인
- Prometheus UI → Graph
- 쿼리 테스트: `reviewmaps_campaign_active_total`
- 데이터가 보이면 성공!

### 3. Grafana 대시보드 확인
- `grafana-django-reviewmaps.json` 파일 임포트
- 모든 패널에 데이터 표시 확인
- Variables 동작 확인 ($application, $threshold)
- No Data 패널이 있다면 해당 메트릭 미구현 상태

---

## 🎯 우선순위 (Django Server 중심)

### Phase 1 (즉시 구현 - 1주)
1. ✅ Django 기본 메트릭 (이미 완료)
2. 🔥 비즈니스 메트릭 (Campaign 통계, Enrichment)
3. 🔥 예외 추적 강화
4. Naver API 호출 추적

### Phase 2 (2주차)
5. DB 테이블 통계 수집
6. 서비스 헬스 체크
7. Alert Rules 설정

### Phase 3 (나중에)
8. Scraper 메트릭 (Pushgateway 필요)
9. 고급 대시보드 최적화
10. 문서화 완료

---

## 💡 구현 팁

### Metrics 네이밍 컨벤션
- Prefix: `reviewmaps_`
- 명사형 사용
- 단위 명시: `_seconds`, `_bytes`, `_total`

### 라벨 설계
- 카디널리티 주의 (너무 많은 고유값 금지)
- 유용한 필터링 가능하도록
- Django Server 라벨 예시: `region`, `status`, `endpoint`, `exception_type`

### Performance 고려사항
- Counter는 빠름 → 자주 사용
- Histogram은 비쌈 → 중요한 것만
- Gauge는 주기적 업데이트 → 스케줄러 활용

---

## 📞 지원

구현 중 질문사항:
1. 특정 메트릭의 라벨 설계 검토
2. Histogram buckets 설정 가이드
3. Alert Rules threshold 조정

백엔드 팀이 구현 완료하면 → 인프라 팀이 Grafana 대시보드 최종 조정!

---

## 📋 요약: 백엔드 팀 구현 체크리스트

### Django Server만 구현 (Scraper는 제외)
```
□ 1. prometheus_client 라이브러리 추가
□ 2. metrics.py 파일 생성 (커스텀 메트릭 정의)
□ 3. 비즈니스 로직에 메트릭 코드 삽입
     - Campaign 통계
     - Naver API 호출 추적
     - Exception 추적
     - Enrichment 작업
□ 4. /metrics 엔드포인트에서 확인
□ 5. 새 이미지 빌드 및 태그 전달
□ 6. 인프라 팀이 배포 → Grafana 대시보드 완성!
```

**Scraper 메트릭은 나중에 Pushgateway 인프라 구축 후 추가 예정**

