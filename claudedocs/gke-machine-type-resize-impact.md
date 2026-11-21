# GKE 노드 머신 유형 변경 영향도 (2026-11-17)

나중에 노드 사양을 줄여야 할 때를 대비해, 머신 유형을 2배로 올렸다가 원복(반으로 축소)하면서 걸리는 시간과 클러스터 안에서 일어나는 변화를 측정한 기록입니다. 노드 수는 그대로 두고 머신 유형만 바꿨습니다.

## 먼저 읽을 것: 핵심 위험 요약

| 구분 | 결론 |
|------|------|
| 노드 1대 | `gcloud container node-pools update --machine-type` 직접 사용 금지. 새 노드가 Ready가 되기 전에 기존 노드가 비워지면 모든 서비스가 수 분간 동시에 중단되고, 그동안 모니터링·알림도 멈출 수 있음 (CRITICAL, 예상). 10장의 blue/green 절차 사용 |
| 노드 2대 (현재) | 사용 가능하지만 무중단이 아님. 서비스별로 1~2분씩 2번 끊기고, 작업 후 Pod가 한 노드에 몰리며, 축소 때는 기동 실패(admin 약 9분 장애)가 실제로 발생함 (실측) |
| 공통 | ingressgateway PDB 때문에 최대 1시간 정체, 교체 중 모니터링 공백 1.5~4분, Terraform 미반영 시 다음 apply에서 같은 교체가 한 번 더 일어남 |
| 판단 기준 | 10.3 노드 수별 판단표, 10.4 사전 점검표 |

## 1. 대상과 변경 내용

| 항목 | 변경 전 | 변경 후 (증설) |
|------|---------|----------------|
| 노드 풀 | `woohalabs-prod-spot-large` (spot) | 동일 |
| 머신 유형 | e2-highmem-2 (2 vCPU, 16GB) | e2-highmem-4 (4 vCPU, 32GB) |
| 노드당 할당 가능 CPU | 1930m | 3920m |
| 노드당 할당 가능 메모리 | 약 13.0GiB | 약 27.7GiB |
| 노드 수 / 자동 확장 | 2대 / 2~3대 | 동일 |
| 노드 비용 | 기준 | 약 2배 |
| 업그레이드 방식 | SURGE, maxSurge 1, maxUnavailable 0 | 동일 |

다른 노드 풀 `woohalabs-prod-spot-medium`(e2-medium)은 노드가 0대라 대상에서 뺐습니다.

## 2. 작업 절차와 명령어

오늘 실제로 한 작업을 순서대로 정리했습니다. 공통 옵션은 아래 값을 씁니다.

| 약어 | 실제 값 |
|------|---------|
| `<공통>` | `--cluster woohalabs-prod-gke --zone asia-northeast3-a --project yanggo-514212` |
| `<op>` | gcloud update 실행 시 출력되는 operation ID (증설 `operation-1794913157870-...`, 원복 `operation-1794914216498-...`) |

### 2.1 사전 확인 (증설 전 1회)

| 순서 | 한 일 | 명령어 | 확인 결과 |
|------|-------|--------|-----------|
| 1 | gcloud 로그인 계정 확인 | `gcloud auth list` | `woohalabs11@gmail.com`이 이미 활성 → `gcloud auth login` 불필요 |
| 2 | 노드 풀과 머신 유형 확인 | `gcloud container node-pools list <공통>` | spot-large e2-highmem-2 (2~3대), spot-medium 0대 |
| 3 | 노드 교체 방식 확인 | `gcloud container node-pools describe woohalabs-prod-spot-large <공통> --format="yaml(upgradeSettings)"` | SURGE, maxSurge 1 |
| 4 | 실제 노드 확인 | `kubectl get nodes -L node.kubernetes.io/instance-type` | e2-highmem-2 2대 |
| 5 | drain을 막을 PDB 확인 | `kubectl get pdb -A` | `istio-ingressgateway` ALLOWED DISRUPTIONS 0 |
| 6 | ingressgateway 복제본·HPA 확인 | `kubectl -n istio-system get deploy,hpa` | 복제본 1개, HPA 없음 |
| 7 | 디스크(PVC) 쓰는 Pod 확인 | `kubectl get statefulset -A` | Prometheus, Alertmanager, ArgoCD controller, yangobot-redis |
| 8 | CPU 쿼터 확인 (교체 중 노드가 1대 더 생김) | `gcloud compute regions describe asia-northeast3 --project yanggo-514212` | CPUS 100 중 4 사용, 여유 충분 |
| 9 | 실행 중인 CronJob 확인 | `kubectl get jobs -A` + 현재 시각 확인 | 실행 중 없음, 다음 CronJob 00:05 |
| 10 | Terraform 정의 확인 | `gcp/terraform/modules/gke/main.tf`의 `machine_type` | e2-highmem-2 (작업 후 원복하므로 수정 안 함) |

### 2.2 측정 준비 (작업 시작 전에 띄워 둠)

| 기록 대상 | 명령어 | 남는 정보 |
|-----------|--------|-----------|
| 이벤트 | `kubectl get events -A -w --watch-only` | 노드 cordon·Pod 퇴거·스케줄 실패·디스크 연결 |
| Service endpoint | `kubectl get endpointslices -A -w --watch-only` | 서비스별 endpoint ready true/false 변화 시각 |
| Pod | `kubectl get pods -A -w --watch-only -o wide` | Pod 생성·삭제·Ready와 배치된 노드 |
| 노드 | `kubectl get nodes -w --watch-only -L node.kubernetes.io/instance-type` | 노드 생성·NotReady·cordon·삭제 |
| 외부 접속 | 로컬 PC에서 URL 8개에 2초마다 `curl -s -o /dev/null -m 3 -w "%{http_code} %{time_total}" <URL>` | 시각별 응답 코드와 응답 시간 |

- watch 명령은 출력에 시각이 없어서, 줄마다 KST 시각을 붙여 파일로 저장했습니다.
- 외부 검사 URL: api.review-maps.com/v1/healthz, review-maps.com, admin.review-maps.com/login/, monitoring.ggorockee.com/api/health, argocd.ggorockee.com/healthz, yangobot.ggorockee.com/healthz, woohalabs.com/app-ads.txt, yen-back.woohalabs.com/healthz
- 증설 때는 이 감시를 첫 번째 노드 교체가 끝난 뒤(20:05)에 띄워서 첫 구간을 놓쳤습니다. 원복 때는 시작 전에 띄웠습니다.

### 2.3 머신 유형 변경 실행

| 작업 | 명령어 | 시작 시각 |
|------|--------|-----------|
| 증설 | `gcloud container node-pools update woohalabs-prod-spot-large <공통> --machine-type e2-highmem-4 --async` | 19:59:17 |
| 원복(축소) | `gcloud container node-pools update woohalabs-prod-spot-large <공통> --machine-type e2-highmem-2 --async` | 20:16:54 |

- 바꾸는 값은 `--machine-type` 하나뿐입니다. 노드 수 설정(2~3대)은 그대로 둡니다.
- `--async`는 작업 완료를 기다리지 않고 operation ID만 받아 바로 끝내는 옵션입니다. 변경 결과는 같고, 작업 중에 감시와 조치를 함께 하려고 붙였습니다. 빼면 끝날 때까지 터미널이 기다립니다.

### 2.4 진행 확인 (작업 중 반복)

| 확인 내용 | 명령어 |
|-----------|--------|
| 작업 상태와 진행률 | `gcloud container operations describe <op> --zone asia-northeast3-a --project yanggo-514212` (status RUNNING/DONE, progress의 NODES_DONE, NODE_PDB_DELAY_SECONDS) |
| 노드 교체 상황 | `kubectl get nodes -L node.kubernetes.io/instance-type` (SchedulingDisabled = 비우는 중인 기존 노드) |
| 비우는 노드에 남은 Pod | `kubectl get pods -A -o wide --field-selector spec.nodeName=<기존 노드>` |
| PDB 막힘 여부 | `kubectl get pdb -A` |

### 2.5 PDB에 막혔을 때 강제 퇴거 (증설·원복 모두)

| 순서 | 한 일 | 명령어 | 시각 |
|------|-------|--------|------|
| 1 | 비우는 노드에 DaemonSet 말고 ingressgateway만 남은 것 확인 | 2.4의 "남은 Pod" 명령 | 증설 20:04~, 원복 20:22:27 |
| 2 | Pending Pod 없는지 확인 | `kubectl get pods -A` (Running/Completed 아닌 것) | |
| 3 | ingressgateway Pod 직접 삭제 (PDB 무시) | `kubectl -n istio-system delete pod <ingressgateway Pod 이름> --wait=false` | 증설 20:11:56, 원복 20:23:53 |
| 4 | 새 Pod Ready 확인 | `kubectl -n istio-system get pods -l app=istio-ingressgateway -o wide` | 증설 20:12:05, 원복 20:24:16 |

`kubectl drain`과 GKE 노드 교체는 Eviction API를 써서 PDB를 지키지만, `kubectl delete pod`는 Eviction API를 거치지 않아 PDB의 제한을 받지 않습니다. 그대로 두면 GKE가 1시간 뒤 강제로 퇴거시킵니다 (5장).

### 2.6 완료 확인

| 확인 내용 | 명령어 | 결과 |
|-----------|--------|------|
| 작업 종료와 소요 시간 | `gcloud container operations describe <op> --zone asia-northeast3-a --project yanggo-514212 --format="yaml(status,startTime,endTime,error)"` | 증설 DONE 20:12:51, 원복 DONE 20:24:40 |
| 노드 유형과 할당 가능 자원 | `kubectl get nodes -o custom-columns=NAME:.metadata.name,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory` | 증설 3920m/27.7GiB, 원복 1930m/13.0GiB |
| 노드 풀 설정 | `gcloud container node-pools describe woohalabs-prod-spot-large <공통> --format="value(config.machineType,status)"` | 바뀐 유형, RUNNING |
| 비정상 Pod | `kubectl get pods -A` (Running/Completed 아닌 것) | 없음 (원복 직후 삭제된 노드의 DaemonSet Pod는 잠시 Pending 후 사라짐) |
| ArgoCD 앱 상태 | `kubectl -n argocd get applications` | 전부 Synced/Healthy |
| 노드 사용량·예약률 | `kubectl top nodes`, `kubectl describe node <노드>`의 Allocated resources | 원복 후 `cv0o` 쏠림 확인 (7.7) |

### 2.7 원복 중 장애 조치 (reviewmaps-admin)

| 순서 | 한 일 | 명령어 | 결과 |
|------|-------|--------|------|
| 1 | 재시작 원인 확인 | `kubectl -n reviewmaps describe pod <admin Pod>` | liveness 실패로 반복 재시작 |
| 2 | 로그 확인 | `kubectl -n reviewmaps logs <admin Pod> --tail=25` | gunicorn 기동 직후 term 신호로 종료 반복 |
| 3 | 자원·probe 설정 확인 | `kubectl -n reviewmaps get pod <admin Pod> -o yaml` (resources, livenessProbe, readinessProbe) | CPU limit 100m, liveness 약 60초 |
| 4 | 실제 CPU 사용량 | `kubectl -n reviewmaps top pod` | 101m (limit에 붙음) |
| 5 | Pod 삭제 → 다른 노드에 재배치 | `kubectl -n reviewmaps delete pod <admin Pod> --wait=false` | `jtbg`에 배치, 20:29:25 Ready |

### 2.8 결과 분석

| 분석 내용 | 사용한 것 |
|-----------|-----------|
| 이벤트 전체 저장 (이벤트는 약 1시간 뒤 사라지므로 바로 저장) | `kubectl get events -A --sort-by=.lastTimestamp -o wide` |
| 이벤트 사유별 개수, 워크로드별 이동 경로 | 저장한 이벤트의 `Scheduled`(배치된 노드), `Killing`, `FailedScheduling`, `FailedAttachVolume`, `NodeShutdown` 집계 |
| Pod별 생성·배치·Ready 시각 | `kubectl get pods -A -o json`의 `metadata.creationTimestamp`, `status.conditions`(PodScheduled, Ready) |
| Service 공백 시간 | 2.2 EndpointSlice 기록에서 ready가 false가 된 시각 → true가 된 시각 |
| 외부 중단 구간 | 2.2 외부 검사 기록에서 8개 중 4개 이상 동시에 실패한 시각 |
| Prometheus 접속 | `kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 19090:9090` 후 `http://localhost:19090/api/v1/query`로 조회 |

Prometheus에서 조회한 쿼리:

| 목적 | PromQL |
|------|--------|
| blackbox 접속 실패와 수집 공백 | `probe_success[17m]` (원시 샘플 간격이 45초를 넘으면 공백) |
| Istio 응답 코드·플래그 | `sum by (destination_service_name,response_code,response_flags)(increase(istio_requests_total[14m]))` |
| admin 과거 재시작 | `max by (pod)(max_over_time(kube_pod_container_status_restarts_total{namespace="reviewmaps",container="admin"}[7d]))` |
| admin CPU 쓰로틀링 | `container_cpu_cfs_throttled_periods_total` / `container_cpu_cfs_periods_total` (admin 컨테이너, 1시간 rate) |
| 작업 중 발생한 알림 | `max by (alertname,severity)(max_over_time(ALERTS{alertstate="firing"}[38m]))` |

### 2.9 정리

| 순서 | 한 일 | 명령어 |
|------|-------|--------|
| 1 | 감시·외부 검사·port-forward 종료 | 백그라운드 `kubectl ... -w`, curl 반복, `port-forward` 프로세스 종료 |
| 2 | Terraform 정의와 실제 일치 확인 | 원복 후 실제 e2-highmem-2 = `main.tf` e2-highmem-2 → 수정 불필요 |

### 참고: 머신 유형 변경이 동작하는 방식

- 머신 유형은 노드 풀 설정이라 노드 한 대만 따로 바꿀 수 없습니다. 노드 풀 설정을 바꾸면 GKE가 새 유형의 노드를 만들고, 기존 노드를 cordon·drain한 뒤 삭제하는 방식으로 한 대씩 교체합니다. 그래서 노드 이름과 IP가 바뀌고, 노드에 있던 Pod는 모두 다시 만들어집니다.
- 노드 이름 변화: 처음 `pwk6`·`slrn` → 증설 후 `cxtu`·`o68s` → 원복 후 `cv0o`·`jtbg`
- AWS EKS 관리형 노드 그룹도 같은 원리로, 인스턴스 타입을 바꾸면 EC2 인스턴스를 새로 만들어 교체합니다.

## 3. 측정 방법

| 관찰 대상 | 방법 |
|-----------|------|
| 소요 시간 | GKE operation 시작·종료 시각, 노드 생성(`creationTimestamp`)·cordon 이벤트 |
| Pod 재기동 | 이벤트 `Scheduled`, `Killing`, `NodeShutdown`과 Pod의 생성·배치·Ready 시각 |
| Service 변화 | EndpointSlice 감시(`kubectl get endpointslices -A -w`) — 두 번째 노드부터 기록 |
| 외부 접속 | 클러스터 안 blackbox exporter(`probe_success`), Istio 응답 코드(`istio_requests_total`), 로컬 PC에서 URL 8개를 2초 간격으로 curl — 로컬 검사는 두 번째 노드부터 |
| 스케줄 실패 | 이벤트 `FailedScheduling`, `FailedAttachVolume`, `NotTriggerScaleUp` |

## 4. 증설 결과 (e2-highmem-2 → e2-highmem-4)

### 4.1 타임라인 (KST)

| 시각 | 일어난 일 |
|------|-----------|
| 19:59:17 | gcloud operation 시작 |
| 19:59:36 | 기존 노드 `pwk6` cordon·drain 시작. 새 노드가 생기기 전이라 Pod 전부가 남은 노드 `slrn` 한 대로 몰림 |
| 19:59:41~20:00:24 | PVC를 쓰는 Pod(Prometheus, yangobot-redis)는 디스크 분리를 기다렸다가 `slrn`에 다시 붙음 (`FailedAttachVolume` → `SuccessfulAttachVolume`, 11~15초) |
| 20:00:19~20:00:40 | `pwk6` 종료 중 DaemonSet Pod가 계속 거절됨 (`NodeShutdown` 25건, `FailedDaemonPod` 30건) |
| 20:00:30 | 새 노드 `cxtu`(e2-highmem-4) 생성, 20:00:36 Ready |
| 20:01:00 | 두 번째 기존 노드 `slrn` cordon·drain 시작 → Pod가 `cxtu`로 다시 이동 (두 번째 재기동) |
| 20:01:05~20:02:34 | PVC Pod 5개(Prometheus, Alertmanager, Grafana, Pushgateway, yangobot-redis)가 `cxtu`에 배치되지 못하고 대기 |
| 20:01:54 | 새 노드 `o68s`(e2-highmem-4) 생성 |
| 20:02:34 | 대기하던 PVC Pod 5개가 `o68s`에 배치됨 |
| 20:03:58 | 마지막 애플리케이션 Pod(Grafana) Ready |
| 20:04 이후 | `slrn`에 `istio-ingressgateway`만 남고 drain이 멈춤 (5장) |
| 20:11:56 | ingressgateway Pod 수동 삭제 (강제 퇴거) |
| 20:12:51 | `slrn` 삭제, operation DONE. 총 13분 34초 (PDB 대기 약 10분 20초 포함: 마지막 일반 Pod가 빠진 20:01:35 ~ 직접 삭제 20:11:56) |

첫 번째 노드는 약 3분 만에 교체됐습니다. 업무 Pod가 모두 다시 Ready가 될 때까지는 시작부터 약 4분 40초가 걸렸습니다.

### 4.2 Pod 재기동

| 구분 | 내용 |
|------|------|
| 재생성된 Pod | DaemonSet과 완료된 Job을 빼면 실행 중 Pod 대부분 (59/69, ingressgateway 제외 전부) |
| 두 번 재기동된 워크로드 | 처음에 `pwk6`에 있던 워크로드는 `pwk6 → slrn → cxtu/o68s`로 두 번 옮겨짐: reviewmaps-server, reviewmaps-web, yangobot, yangobot-redis, Prometheus, blackbox exporter, istiod, kube-dns, cert-manager, ArgoCD 일부, woohalabs-app-ads |
| 한 번 재기동된 워크로드 | 처음에 `slrn`에 있던 것: reviewmaps-admin, yen-back, ArgoCD server·repo-server·application-controller, Grafana, Alertmanager, Pushgateway, ESO, exporter류 |
| Ready까지 걸린 시간 | 일반 Deployment는 배치 후 25~100초 (이미지 pull 포함). PVC Pod는 배치 대기가 약 90초 더 걸려 생성부터 Ready까지 2~3분 |

### 4.3 Service(endpoint) 영향

복제본이 1개인 Deployment는 기존 Pod가 퇴거되는 순간부터 새 Pod가 Ready가 될 때까지 Service에 endpoint가 없습니다. 이 구간에 들어온 요청은 Istio에서 503(`UH`, 연결할 upstream 없음)이 됩니다.

| 서비스 | endpoint 없는 구간 (두 번째 이동 기준) | 실제 관측 |
|--------|----------------------------------------|-----------|
| reviewmaps-server (API) | 20:01:08 → 20:02:41, 약 93초 | 그 시간에 요청이 없어 5xx 기록 없음 |
| reviewmaps-web | 20:01:08 → 20:02:49, 약 101초 | 동일 |
| reviewmaps-admin | 20:01:07 → 20:03:19, 약 132초 | 동일 |
| yen-back | 20:01:08 → 20:02:35, 약 87초 | 동일 |
| yangobot | 20:01:04 → 20:02:06, 약 62초 | 동일 |
| woohalabs-app-ads (복제본 2개) | 두 Pod가 같은 시각에 함께 이동 → 20:01:08 → 20:02:35, 약 87초 | 동일 |
| Grafana | 20:01:05 → 20:03:58, 약 173초 | Istio 503 `UH` 약 10건, blackbox 20:03:28 1회 실패 |
| kube-dns (복제본 2개) | 두 Pod가 같은 노드에서 함께 이동 → 20:01:03 → 20:02:49 | 클러스터 DNS는 노드별 node-local-dns 캐시가 있어 영향이 작음 |

- 첫 번째 이동(19:59:36~19:59:40)에서도 위 서비스들에 같은 종류의 짧은 공백이 한 번 더 있었습니다.
- 외부 진입점인 `istio-ingressgateway`는 PDB 때문에 이 구간에 옮겨지지 않아 계속 살아 있었습니다.
- 복제본이 2개인 서비스(woohalabs-app-ads, kube-dns)도 두 Pod가 같은 노드에 있어서 함께 중단됐습니다. 복제본 수만으로는 무중단이 보장되지 않고, 다른 노드에 나눠 배치(topologySpreadConstraints 또는 podAntiAffinity)해야 합니다.

### 4.4 모니터링 공백

| 항목 | 내용 |
|------|------|
| 접속 검사 공백 | 19:59:29 ~ 20:03:36, 약 4분. blackbox exporter와 Prometheus가 함께 두 번 옮겨지면서 수집이 멈춤 |
| 의미 | 이 구간의 "접속 실패 없음"은 정상이었다는 증거가 아님. 실제 판단은 위 Pod Ready 시각으로 함 |
| Istio 지표 | 이 시간대 요청은 거의 blackbox 검사뿐(서비스당 8분에 8~18건)이라, 5xx가 없다고 해서 중단이 없었다는 뜻이 아님 |

### 4.5 스케줄·디스크 관련 관측

| 이벤트 | 원인 | 영향 |
|--------|------|------|
| `FailedAttachVolume` (Waiting for detach) | PD는 한 번에 한 노드에만 붙음. 기존 노드에서 떨어질 때까지 대기 | 11~15초 지연 |
| `FailedScheduling` (didn't match PersistentVolume's node affinity) | 갓 Ready가 된 새 노드 `cxtu`에 PVC Pod가 배치되지 못함. PV의 zone 조건(`topology.gke.io/zone`)이 새 노드에서 아직 충족되지 않은 것으로 추정 (현재 라벨은 정상) | PVC Pod 5개가 약 90초 대기 |
| `NotTriggerScaleUp` (2 max node group size reached) | 업그레이드 중에는 autoscaler가 노드를 추가하지 않음 | 대기 Pod가 있어도 노드가 늘지 않음 |
| `NodeShutdown` / `FailedDaemonPod` | 종료 중인 노드에 DaemonSet이 Pod를 계속 다시 만들다 거절됨 | 영향 없음 (기록만 많음) |

### 4.6 자원 변화

| 항목 | 변경 전 (2노드 합) | 변경 후 (2노드 합) |
|------|--------------------|--------------------|
| 할당 가능 CPU | 3.86코어 | 7.84코어 |
| 할당 가능 메모리 | 약 26GiB | 약 55GiB |
| CPU requests 예약률 | 약 46% (1.77코어 기준, #1165) | 약 23% (1.78코어) |
| 메모리 requests 예약률 | 약 20% | 약 10% (5.33GiB) |
| 노드 한 대 남았을 때 | 1.93코어로 requests 1.77을 겨우 수용 | 3.92코어로 여유 |

## 5. 두 번째 노드 — PDB 때문에 멈춤, 수동 강제 퇴거

### 5.1 PDB(PodDisruptionBudget)란

PDB는 "자발적 중단" 때 한 워크로드에서 동시에 내려가도 되는 Pod 수를 제한하는 Kubernetes 리소스입니다. 자발적 중단은 노드 drain, 노드 업그레이드, 머신 유형 변경, 클러스터 축소처럼 운영자나 플랫폼이 의도적으로 Pod를 내보내는 경우를 말합니다.

| 항목 | 내용 |
|------|------|
| 설정 방식 | `minAvailable`(최소 유지 개수) 또는 `maxUnavailable`(동시에 내려가도 되는 개수) 중 하나 |
| 적용 대상 | Eviction API를 거치는 퇴거 (`kubectl drain`, GKE 노드 업그레이드·교체, autoscaler 축소) |
| 적용 안 되는 것 | 노드 장애, spot 회수(선점), OOM 같은 비자발적 중단과, `kubectl delete pod`처럼 Eviction API를 거치지 않는 직접 삭제 |
| 상태 확인 | `kubectl get pdb -A`의 `ALLOWED DISRUPTIONS`가 0이면 지금 그 워크로드의 Pod를 하나도 퇴거시킬 수 없음 |
| AWS 대응 | EKS도 같은 Kubernetes PDB를 씀. EKS 관리형 노드 그룹 업데이트도 PDB를 존중하고, 기본은 약 15분 뒤 실패 처리(force 옵션이면 무시) |

### 5.2 이번에 걸린 PDB

| 항목 | 값 |
|------|-----|
| PDB | `istio-system/istio-ingressgateway`, `minAvailable: 1` |
| 대상 Pod 수 | 1개 (HPA 없음) |
| ALLOWED DISRUPTIONS | 0 → 이 Pod는 퇴거 불가 |
| 결과 | 20:01:04 `slrn` drain 시작 후 다른 Pod는 모두 나갔는데 ingressgateway만 남아 drain이 멈춤 |

복제본이 1개인데 "최소 1개 유지"를 걸어 두면 자발적 중단이 영원히 허용되지 않습니다. 그래서 노드 교체가 이 노드에서 멈췄습니다.

### 5.3 GKE의 동작 — 1시간 후 강제 퇴거

| 상황 | GKE 동작 |
|------|----------|
| PDB가 퇴거를 막음 | 노드 업그레이드·교체 중 PDB를 최대 1시간 존중하며 재시도 |
| 1시간 경과 | PDB를 무시하고 남은 Pod를 강제로 내보낸 뒤 노드 삭제 |
| 이번에 그대로 뒀다면 | 약 21:01 KST에 강제 퇴거. 작업 전체가 약 1시간 5분 걸리고, 그동안 기존 노드(e2-highmem-2) 1대가 더 남아 비용도 발생 |
| 강제 퇴거 시 영향 | 수동으로 지운 경우와 같음 (5.4). 복제본이 1개라 어느 쪽이든 짧은 외부 중단은 피할 수 없음 |

### 5.4 수동 강제 퇴거와 결과

1시간을 기다리지 않으려고 20:11:56에 `kubectl -n istio-system delete pod <ingressgateway Pod>`로 직접 삭제했습니다. 직접 삭제는 Eviction API를 거치지 않아 PDB의 제한을 받지 않습니다.

| 시각 (KST) | 일어난 일 |
|------------|-----------|
| 20:11:56 | 기존 Pod 삭제 → EndpointSlice에서 ready=false (트래픽 제외). 같은 초에 새 Pod 생성·`o68s`에 배치 |
| 20:12:01 | 기존 Pod endpoint 제거, 로컬 외부 검사에서 8개 URL 중 7개 동시 실패 (일부는 0.02초 만에 연결 거부) |
| 20:12:04 | 새 Pod endpoint 등록 (ready=false) |
| 20:12:05 | 새 Pod Ready → endpoint ready=true, 트래픽 복구 |
| 20:12:38 이후 | 로컬 외부 검사 전부 200 |
| 20:12:51 | 기존 노드 `slrn` 삭제, gcloud operation DONE |

| 항목 | 결과 |
|------|------|
| 외부 진입점 중단 | 약 9초 (기존 Pod 트래픽 제외 20:11:56 → 새 Pod Ready 20:12:05). 이 구간에는 모든 도메인이 응답하지 않음 |
| 측정 한계 | 로컬 검사는 평소에도 약 10%가 3초 시간 초과로 실패해서(로컬 네트워크 잡음, kubectl API 연결 시간 초과도 간헐적으로 발생), "여러 URL이 동시에 실패한 시점"만 중단으로 판단함 |
| 수동 삭제 후 operation 종료까지 | 55초 |

### 5.5 다음에 PDB 대기 없이 하려면

| 방법 | 내용 |
|------|------|
| 작업 전 복제본 늘리기 | `kubectl -n istio-system scale deploy istio-ingressgateway --replicas=2` → ALLOWED DISRUPTIONS 1이 되어 무중단으로 drain. 작업 후 1로 복구 (ArgoCD가 관리하면 self-heal로 되돌려질 수 있으니 확인) |
| 상시 2개 운영 | 차트 values에서 복제본 2개 + 노드 분산 배치. 비용은 Pod 1개분(requests)만 증가 |
| 직접 삭제 (이번 방식) | 약 9초 외부 중단 감수 |
| 그대로 기다림 | 1시간 후 GKE가 강제 퇴거, 영향은 직접 삭제와 같고 시간만 더 걸림 |

## 6. 원복(축소) 측정 준비

- [x] 원복 전 Terraform `machine_type`이 e2-highmem-2인지 확인 (바꾸지 않았으므로 그대로)
- [x] CronJob 시간대(00:05, 02:00, 05:00 KST) 피하기 — 20:16 실행
- [x] 로컬 외부 접속 검사, EndpointSlice·Pod·노드·이벤트 감시를 작업 시작 전에 먼저 띄우기
- [x] `--machine-type e2-highmem-2`로 원복 실행
- [x] 결과를 7장에 기록

## 7. 원복(축소) 결과 (e2-highmem-4 → e2-highmem-2)

### 7.1 타임라인 (KST)

| 시각 | 일어난 일 |
|------|-----------|
| 20:16:54 | gcloud operation 시작 (`--machine-type e2-highmem-2`) |
| 20:17:14~20:17:22 | 첫 노드 `cxtu` drain. 새 노드가 생기기 전이라 Pod 전부가 남은 노드 `o68s`(e2-highmem-4)로 이동 (첫 번째 재기동) |
| 20:18:10 | 새 노드 `cv0o`(e2-highmem-2) 생성, 20:18:16 Ready |
| 20:19:58 | `cxtu` 삭제 |
| 20:20:02~20:20:45 | 두 번째 노드 `o68s` drain. 이때 새 노드는 `cv0o` 하나뿐이라 ingressgateway를 뺀 모든 Pod가 `cv0o` 한 대로 이동 (두 번째 재기동) |
| 20:21:00 | 새 노드 `jtbg`(e2-highmem-2) 생성, 20:21:04 Ready. 이미 Pod가 다 옮겨진 뒤라 거의 비어 있음 |
| 20:22:27 | `o68s`에 ingressgateway만 남은 것을 확인 (PDB 정체) |
| 20:23:53 | ingressgateway Pod 직접 삭제 → `jtbg`에 새로 생성 |
| 20:24:16 | 새 ingressgateway Ready |
| 20:24:40 | `o68s` 삭제, operation DONE. 총 7분 46초 (PDB 대기 약 3분 포함: 마지막 일반 Pod가 빠진 20:20:45 ~ 직접 삭제 20:23:53) |
| 20:19~20:29 | reviewmaps-admin 기동 실패 반복 (7.4) |
| 20:27:57 | admin Pod를 직접 삭제 → `jtbg`에 배치, 20:29:25 Ready (재시작 없음) |

### 7.2 Service endpoint 공백 (EndpointSlice 실측)

EndpointSlice의 ready가 false가 된 시각부터 다시 true가 된 시각까지입니다.

| 서비스 | 1차 이동 (`cxtu`→`o68s`) | 2차 이동 (`o68s`→`cv0o`) | 합계 |
|--------|--------------------------|--------------------------|------|
| reviewmaps-server (API) | 20:17:21 → 20:18:33, 72초 | 20:20:11 → 20:21:45, 94초 | 166초 |
| reviewmaps-web | 20:17:21 → 20:18:39, 78초 | 20:20:11 → 20:21:57, 106초 | 184초 |
| reviewmaps-admin | 20:17:21 → 20:19:18, 117초 | 20:20:10 → 20:29:25, 555초 (기동 실패, 수동 조치로 복구) | 672초 |
| yen-back | 20:17:22 → 20:18:26, 64초 | 20:20:12 → 20:21:37, 85초 | 149초 |
| yangobot | 20:17:19 → 20:18:14, 55초 | 20:20:08 → 20:21:06, 58초 | 113초 |
| woohalabs-app-ads (복제본 2개) | 20:17:21 → 20:18:34, 73초 | 20:20:11 → 20:21:47, 96초 | 169초 |
| Grafana (PVC) | 이동 없음 | 20:20:09 → 20:23:26, 197초 | 197초 |
| yangobot-redis (PVC) | 이동 없음 | 20:20:08 → 20:22:13, 약 125초 | 약 125초 |
| istio-ingressgateway | 이동 없음 | 20:23:53 → 20:24:16, 23초 (전체 도메인) | 23초 |

- app-ads는 복제본이 2개지만 두 Pod가 같은 노드에 있어서 매번 함께 내려갔습니다.
- ingressgateway 중단은 증설 때(9초)보다 깁니다(23초). 새 노드 `jtbg`에서 이미지를 처음 받느라 걸린 것으로 보입니다.

### 7.3 외부에서 본 증상 — 503이 아니라 응답 지연

| 관측 | 내용 |
|------|------|
| 로컬 외부 검사 | 20:17:32~20:18:53에는 8개 중 7개, 20:20:24~20:21:57에는 8개 전부가 3초 안에 응답하지 않음 |
| Istio 응답 플래그 | `0 DC`(클라이언트가 먼저 끊음)가 서비스마다 약 11건. 빠른 503(`UH`)은 endpoint가 아예 없던 admin(90건)과 ArgoCD(14건)에서만 나옴 |
| 해석 | 서비스 Pod와 istiod가 같은 노드에서 함께 옮겨졌습니다. istiod가 다시 뜰 때까지 ingressgateway(Envoy)가 바뀐 endpoint를 받지 못하고, 이미 사라진 Pod IP로 계속 연결을 시도해서 요청이 멈춘 것으로 보입니다. 사용자 입장에서는 빠른 오류가 아니라 로딩이 멈추는 증상 |
| 영향 시간 | 1차 약 1분 40초, 2차 약 1분 50초 동안 대부분 도메인이 사실상 응답 불가 |

로컬 검사는 평소에도 약 12%가 실패하므로(4/32), 8개 중 4개 이상이 동시에 실패한 시점만 장애로 판단했습니다.

### 7.4 reviewmaps-admin 기동 실패 (축소에서만 발생)

| 항목 | 내용 |
|------|------|
| 증상 | 2차 이동 후 `cv0o`에서 liveness 실패로 5회 재시작. 외부 `admin.review-maps.com`이 20:19~20:29 동안 503 |
| 자원 설정 | CPU requests 20m / limit 100m, liveness initialDelay 30초 + 10초×3회 실패 → 약 60초 안에 응답하지 못하면 재시작 |
| 관측 | 기동 중 CPU 사용량이 limit에 붙어 있음 (101m). gunicorn 워커 2개와 Django가 60초 안에 응답하지 못함 |
| 원인 (추정) | 노드 `cv0o` 한 대에서 거의 모든 Pod가 동시에 기동하며 CPU 경합이 생김 + limit 100m 쓰로틀링 |
| 근거 | 같은 Pod를 거의 빈 노드 `jtbg`로 옮기자 재시작 없이 88초 만에 Ready. 과거 7일 admin Pod 3개는 재시작 0회 |
| 알림 | CRITICAL `WorkloadUnavailable`(20:27~20:29), `ServiceEndpointDown`(20:28~20:29), WARN `ContainerRestartsFrequent` 메일 발송 |
| 조치 | Pod 직접 삭제로 다른 노드에 재배치 (설정 변경 없음) |
| 재발 방지 후보 | admin CPU limit 상향(예: 300m) 또는 startupProbe 추가로 기동 시간 확보 |

### 7.5 스케줄·디스크 관련 관측

| 이벤트 | 증설 | 축소 |
|--------|------|------|
| `FailedScheduling` | PVC Pod 5개가 약 90초 대기 (PV zone 조건) | 없음 |
| `FailedAttachVolume` (detach 대기) | 2건, 11~15초 | 5건 (Grafana, Pushgateway, Alertmanager, yangobot-redis, Prometheus) |
| Pending (자원 부족) | 없음 | 없음. `cv0o` 한 대에 몰렸을 때 CPU requests 1294m(67%), 메모리 33% |
| OOMKilled | 없음 | 없음 |

### 7.6 모니터링 공백

| 구간 | 길이 |
|------|------|
| 20:17:06 ~ 20:18:41 | 95초 |
| 20:19:41 ~ 20:23:15 | 213초 |

blackbox exporter와 Prometheus가 옮겨지는 동안 접속 검사가 멈췄습니다. 이번에도 외부 검사와 EndpointSlice 감시가 없었다면 실제 중단을 놓쳤을 것입니다.

### 7.7 작업 후 상태와 남은 문제

| 항목 | 내용 |
|------|------|
| 노드 | `cv0o`, `jtbg` 모두 e2-highmem-2, Ready |
| Pod / ArgoCD | 모두 Running, 앱 전부 Synced/Healthy |
| 쏠림 | 업무 Pod 거의 전부가 `cv0o`에 있음 (CPU requests 67%, 실사용 26%), `jtbg`는 ingressgateway·admin만 있음 (실사용 5%). Kubernetes는 자동으로 재분배하지 않으므로, 이후 배포나 재시작 때 자연히 섞이거나 수동으로 재배치해야 함 |
| 위험 | 이 상태에서 `cv0o`가 spot 회수되면 거의 모든 서비스가 한 번에 내려감 |

## 8. 증설·축소 비교와 판단

| 항목 | 증설 (highmem-2 → 4) | 축소 (highmem-4 → 2) |
|------|----------------------|----------------------|
| 총 소요 | 13분 34초 (PDB 대기 약 10분 20초, 직접 삭제로 종료) | 7분 46초 (PDB 대기 약 3분, 직접 삭제로 종료) |
| PDB 대기 빼고 | 약 3분 15초 | 약 4분 40초 |
| 업무 Pod 재기동 | 첫 노드 Pod 2회, 나머지 1회 | 거의 전부 2회 |
| 서비스별 endpoint 공백 | 이동 1회당 약 1~2분, PVC Pod 약 3분 | 이동 1회당 약 1~2분, 합계 서비스당 약 2~3분 |
| 외부 진입점 중단 | 9초 | 23초 |
| 외부 체감 | 1차 구간 측정 못함 | 서비스 이동 때 약 1분 40초씩 2회 대부분 도메인 응답 지연 |
| 추가 장애 | Grafana 503 | reviewmaps-admin 약 9분 장애 (기동 실패) |
| 작업 후 배치 | 두 노드에 분산 | 한 노드에 쏠림 |

| 질문 | 답 |
|------|-----|
| 머신 유형 변경에 걸리는 시간 | 2노드 기준 PDB 대기를 빼면 약 3~5분. PDB를 그대로 두면 노드당 최대 1시간 추가 |
| 무중단인가 | 아님. 노드마다 Pod가 한 번씩 옮겨지고, 첫 노드의 Pod는 두 번 옮겨짐. 복제본 1개인 서비스는 이동마다 약 1~2분 중단 |
| 왜 두 번 옮겨지나 | 두 경우 모두 GKE가 새 노드가 Ready가 되기 전에 첫 노드를 비웠고, 두 번째 노드를 비울 때도 새 노드가 하나뿐이었음. 그래서 Pod가 남은 기존 노드로 갔다가 다시 옮겨지고, 마지막에는 한 노드에 몰림 |
| 축소가 더 위험한 이유 | 작은 노드 한 대에 모든 Pod가 동시에 몰려 기동하면서 CPU 경합이 생기고, limit이 낮은 Pod(admin)가 liveness에 걸려 재시작을 반복함 |
| 외부 진입점 | ingressgateway가 1개라 PDB에 막히고, 강제 퇴거 시 전체 도메인 9~23초 중단 |
| 모니터링 | 교체 중 수집이 1.5~3.5분씩 멈추므로 외부 검사와 EndpointSlice 감시를 따로 해야 함 |

다음에 머신 유형을 바꿀 때 영향을 줄이는 방법 (효과 큰 순):

| 방법 | 효과 |
|------|------|
| 노드 풀 교체 대신 새 노드 풀 생성 → cordon → drain → 기존 풀 삭제 (blue/green) | 새 노드가 모두 준비된 뒤 한 번만 옮김. 재기동 2회 → 1회, 한 노드 쏠림 방지 |
| ingressgateway 복제본 2개 + 노드 분산 | PDB 대기·진입점 중단 제거 |
| istiod 복제본 2개 | 이동 중 Envoy가 endpoint 변경을 계속 받아 응답 지연 감소 |
| 주요 서비스 복제본 2개 + topologySpreadConstraints | 서비스별 1~2분 공백 제거 |
| admin 등 limit 낮은 Pod에 startupProbe 또는 CPU limit 상향 | 동시 기동 시 재시작 반복 방지 |
| 작업 후 쏠림 확인 | `kubectl top nodes`와 Pod 배치를 확인하고 필요하면 재분배 |

## 9. 노드가 1대일 때의 진행 방식 (예상)

이번 측정은 노드 2대에서 했습니다. 이 장은 같은 노드 풀이 1대일 때 어떻게 진행될지를 이번 관찰에 근거해 정리한 것으로, 1대로 직접 시험한 결과는 아닙니다. 현재 `spot-large` 풀은 자동 확장 최소값이 2대라 평소에 1대가 되지는 않습니다.

### 9.1 GKE가 의도하는 순서 (SURGE, maxSurge 1, maxUnavailable 0)

| 단계 | 2대일 때 | 1대일 때 |
|------|----------|----------|
| 1 | 새 노드 1대 추가 (총 3대) | 새 노드 1대 추가 (총 2대) |
| 2 | 기존 노드 1대 drain → Pod는 남은 노드들로 이동 | 기존 노드 drain → Pod는 새 노드로만 이동 |
| 3 | 기존 노드 삭제 후 다음 노드 반복 | 기존 노드 삭제 후 종료 |

이 순서대로라면 1대에서도 새 노드가 먼저 준비되어 Pod가 한 번에 옮겨 갑니다.

### 9.2 이번에 실제로 관찰한 순서

증설과 원복 모두 GKE가 새 노드가 Ready가 되기 전에 첫 번째 기존 노드를 먼저 비웠습니다.

| 작업 | 첫 노드 drain 시작 | 새 노드 Ready | 차이 |
|------|--------------------|---------------|------|
| 증설 | 19:59:36 | 20:00:36 | 약 1분 |
| 원복 | 20:17:14 | 20:18:16 | 약 1분 |

2대일 때는 남은 기존 노드가 Pod를 받아 줘서 서비스가 버텼습니다. 그 대신 Pod가 두 번 옮겨졌습니다 (4.2, 7.1).

### 9.3 1대에서 같은 순서가 되면 예상되는 영향

| 시점 | 예상되는 일 |
|------|-------------|
| drain 시작 ~ 새 노드 Ready (약 1분) | 옮겨 갈 노드가 없어 모든 Pod가 Pending → 모든 서비스 중단 |
| 새 노드 Ready 직후 | 모든 Pod가 한 노드에서 동시에 기동. 이미지 받기, 디스크(PVC) 분리·연결, CPU 경합으로 Ready까지 1~3분 더 걸림 |
| 기동 경합 | 이번 원복의 reviewmaps-admin처럼 CPU limit이 낮은 Pod는 liveness에 걸려 재시작을 반복할 수 있음 (7.4) |
| PDB | ingressgateway는 1대일 때도 똑같이 drain을 막음 → 직접 삭제하거나 1시간 대기 (5장) |
| 모니터링 | Prometheus, Alertmanager, blackbox exporter도 함께 내려가 그 사이 알림이 나가지 않음 |
| 전체 | 수 분 동안 모든 서비스 중단 예상. Pod 이동은 1번이지만, 그 1번이 전체 중단이 됨 |

### 9.4 2대와 1대 비교

| 항목 | 2대 (실측) | 1대 (예상) |
|------|------------|------------|
| Pod 이동 횟수 | 첫 노드 Pod 2회, 나머지 1회 | 1회 |
| 서비스 중단 형태 | 서비스별로 이동할 때마다 1~2분씩 끊김 | 모든 서비스가 동시에 수 분 중단 |
| 외부 진입점 | PDB 정체 후 직접 삭제 시 9~23초 | drain 중 다른 Pod와 함께 끊기거나 PDB에 막힘 |
| 모니터링 | 1.5~4분 공백 | 전체 중단 동안 공백, 알림 미발송 |
| 작업 후 배치 | 한 노드에 쏠릴 수 있음 | 원래 1대라 해당 없음 |

### 9.5 1대에서 권장하는 방법: 새 노드 풀 먼저 만들기 (blue/green)

| 순서 | 할 일 | 명령어 |
|------|-------|--------|
| 1 | 새 머신 유형으로 노드 풀 생성, 노드 Ready 확인 | `gcloud container node-pools create <새 풀> <공통> --machine-type <새 유형> --num-nodes 1 --spot` (기존 풀과 디스크·라벨·oauth scope 설정을 맞춤) |
| 2 | 기존 노드 cordon (새 Pod가 기존 노드에 배치되지 않게) | `kubectl cordon <기존 노드>` |
| 3 | PDB 대비: ingressgateway 복제본 임시 2개 | `kubectl -n istio-system scale deploy istio-ingressgateway --replicas=2` |
| 4 | 기존 노드 drain → 준비된 새 노드로 한 번에 이동 | `kubectl drain <기존 노드> --ignore-daemonsets --delete-emptydir-data` |
| 5 | 서비스·ArgoCD·알림 정상 확인 | 2.6 완료 확인 명령 |
| 6 | 기존 노드 풀 삭제, ingressgateway 복제본 원복 | `gcloud container node-pools delete <기존 풀> <공통>`, `kubectl -n istio-system scale deploy istio-ingressgateway --replicas=1` |
| 7 | Terraform 반영 | `gcp/terraform/modules/gke/main.tf` 노드 풀 정의를 새 풀 기준으로 수정 (안 하면 다음 apply에서 되돌아감) |

- 새 노드가 먼저 준비되므로 "Pod가 갈 곳이 없는 1분"이 생기지 않습니다. 각 서비스는 재기동 1번(약 1~2분)만 끊깁니다.
- 노드 풀 생성·삭제는 gcloud 쓰기 작업이라 실행 전에 승인이 필요합니다.
- 1대일 때의 실제 동작을 확인하려면, 테스트용 노드 풀(1대)과 테스트 Deployment를 만들어 이 문서와 같은 방법(2.2 감시, 2.3 변경)으로 측정합니다.

## 10. 위험성 평가와 작업 판단 기준

근거 칸의 "실측"은 이번 2대 증설·원복에서 실제로 관측한 것이고, "예상"은 관측한 동작을 바탕으로 추정한 것입니다.

### 10.1 위험 목록

| 번호 | 위험 | 발생 조건 | 영향 | 등급 | 근거 |
|------|------|-----------|------|------|------|
| R1 | 전체 서비스 동시 중단 | 노드 1대에서 노드 풀을 바로 교체 | 새 노드 Ready 전 약 1분간 모든 Pod Pending, 이후 동시 기동 1~3분. 모든 도메인 수 분 중단 | CRITICAL | 예상 (9장) |
| R2 | 모니터링·알림 공백 | 모든 교체 | Prometheus, Alertmanager, blackbox exporter가 함께 옮겨져 수집이 멈춤. 2대에서 1.5~4분, 1대에서는 중단 전 구간 동안 장애 알림이 나가지 않음 | HIGH | 실측 (4.4, 7.6) |
| R3 | 동시 기동 경합으로 기동 실패 | Pod가 한 노드에 몰려 동시에 기동 (축소, 1대) | CPU limit이 낮은 Pod가 liveness에 걸려 재시작을 반복. admin 약 9분 장애 | HIGH | 실측 (7.4) |
| R4 | 축소 시 용량 부족 | 작은 유형으로 줄이고 교체 중 노드 1대에 Pod가 몰릴 때 | CPU requests 합계 1.78코어 vs e2-highmem-2 1대 1.93코어 → 여유 0.15코어(약 8%). requests가 조금만 늘어도 Pending | HIGH | 실측 (7.5) + 계산 |
| R5 | Pod 두 번 이동, 한 노드 쏠림 | 노드 2대 이상에서 노드 풀을 바로 교체 | 서비스별 1~2분 공백이 2번. 작업 후 한 노드에 쏠려 그 노드가 spot 회수되면 거의 전체 중단 | HIGH | 실측 (4.2, 7.1, 7.7) |
| R6 | Terraform 불일치 | gcloud로 바꾸고 `main.tf`를 고치지 않음 | 다음 terraform apply가 원래 유형으로 되돌리며 같은 교체가 예고 없이 한 번 더 일어남 | HIGH | 구성 확인 |
| R7 | PDB 정체 | ingressgateway 복제본 1개 + `minAvailable: 1` | 노드당 최대 1시간 정체. 강제 퇴거 시 모든 도메인 9~23초 중단 | MEDIUM | 실측 (5장) |
| R8 | 응답 지연(타임아웃) | 서비스 Pod와 istiod가 함께 이동 | 빠른 503이 아니라 요청이 멈춤. 2대에서 약 1분 40초씩 2번 | MEDIUM | 실측 (7.3) |
| R9 | 디스크(PVC) Pod 지연 | PVC를 쓰는 Pod 이동 | 디스크 분리·연결 대기, 새 노드 배치 대기로 Ready까지 2~3분 | MEDIUM | 실측 (4.5, 7.5) |
| R10 | spot 재고 부족 | spot 노드 풀에서 새 유형의 재고가 없을 때 | 새 노드 생성이 늦어지거나 실패. 기존 노드를 이미 비운 상태면 R1의 중단이 길어짐 | MEDIUM | 예상 |
| R11 | 되돌리기도 같은 비용 | 작업 중 문제가 생겨 원래 유형으로 돌릴 때 | 원복도 노드 전체 교체라 같은 중단이 한 번 더 발생 (원복 실측 7분 46초) | MEDIUM | 실측 (7장) |
| R12 | CronJob 중단 | 수집 CronJob 시간대와 겹침 (00:05, 02:00, 05:00 KST) | 실행 중 Job Pod가 퇴거되어 수집 실패·재실행 필요 | MEDIUM | 예상 |
| R13 | 쿼터 부족 | 교체 중 노드가 1대 더 필요 | surge 노드 생성 실패로 작업 정지. 현재 CPUS 100 중 4 사용으로 여유 있음 | LOW | 확인 (2.1) |
| R14 | 비용 증가 | 증설, blue/green 중 두 노드 풀 공존 | 증설 시 노드 비용 약 2배, blue/green 중에는 몇십 분간 노드 비용 추가 | LOW | 계산 |

### 10.2 위험별 대응

| 위험 | 대응 |
|------|------|
| R1 | 노드 1대에서는 10.5 blue/green 절차만 사용. 피할 수 없으면 사용자에게 점검 시간 공지 |
| R2 | 작업 전에 로컬 외부 접속 검사와 EndpointSlice 감시를 먼저 띄움 (2.2). 작업 중 장애 판단은 Grafana가 아니라 이 기록으로 함 |
| R3 | 작업 전 CPU limit이 낮은 Pod 확인 (admin 100m 등). startupProbe 추가 또는 limit 상향. 작업 후 재시작 횟수 확인, 반복하면 덜 붐비는 노드로 재배치 (2.7) |
| R4 | 축소 전에 CPU·메모리 requests 합계가 작은 노드 1대 용량 안에 여유 있게 들어가는지 계산. 부족하면 축소 보류 또는 노드 수 증가 |
| R5 | blue/green 사용. 바로 교체했다면 작업 후 `kubectl top nodes`로 쏠림 확인 후 Deployment 재시작으로 재분배 |
| R6 | gcloud 변경을 유지할 거면 같은 날 `gcp/terraform/modules/gke/main.tf`의 `machine_type`과 `TERRAFORM_RESOURCES.md`를 수정해 PR. 처음부터 Terraform PR로 바꾸는 것도 방법 |
| R7 | 작업 전 ingressgateway 복제본을 2개로 늘림 (5.5). 또는 정체 확인 후 직접 삭제 |
| R8 | istiod 복제본 2개로 운영해 이동 중에도 endpoint 변경이 전달되게 함 |
| R9 | PVC Pod는 2~3분 걸린다고 보고 일정 잡기 |
| R10 | 진행률(NODES_DONE)과 새 노드 생성 여부를 계속 확인. blue/green이면 새 노드가 뜬 걸 확인한 뒤에 기존 노드를 비우므로 영향 없음 |
| R11 | 되돌리기가 필요 없도록 사전 점검(10.4)을 충분히 함. 되돌릴 때도 같은 사전 조치 적용 |
| R12 | CronJob 시간대를 피해 작업. 시작 전 `kubectl get jobs -A`로 실행 중 Job 확인 |
| R13 | 작업 전 쿼터 확인 (2.1의 8번) |
| R14 | 작업 시간 최소화. blue/green은 확인이 끝나면 바로 기존 풀 삭제 |

### 10.3 노드 수별 판단

| 노드 수 | 노드 풀 바로 교체 (`node-pools update`) | 권장 방법 | 예상 영향 |
|---------|------------------------------------------|-----------|-----------|
| 1대 | 사용 금지 | blue/green (10.5) | blue/green이면 서비스별 재기동 1회(1~2분). 바로 교체하면 전체 수 분 중단 |
| 2대 (현재) | 가능하지만 비권장 | blue/green. 바로 교체한다면 10.4 사전 조치 필수 | 바로 교체 시 서비스별 1~2분씩 2번 끊김, 쏠림, 축소 시 기동 실패 위험 |
| 3대 이상 | 가능 | 바로 교체 또는 blue/green | 남은 노드가 많아 쏠림과 경합이 줄지만, 복제본 1개인 서비스의 재기동 공백은 동일 |

### 10.4 작업 전 점검표

- [ ] 노드 수 확인 → 1대면 바로 교체하지 않고 blue/green으로 진행
- [ ] CronJob 시간대(00:05, 02:00, 05:00 KST)를 피했고, 실행 중인 Job 없음
- [ ] `kubectl get pdb -A`에서 ALLOWED DISRUPTIONS 0인 PDB 확인 → ingressgateway 복제본 임시 2개 또는 직접 삭제 계획
- [ ] 축소라면 requests 합계가 작은 노드 1대 용량 안에 여유 있게 들어감
- [ ] CPU limit이 낮은 Pod(admin 등)의 기동 시간이 liveness 기준(약 60초) 안에 들어가는지 확인
- [ ] 리전 쿼터 여유 확인
- [ ] 외부 접속 검사와 EndpointSlice·Pod·이벤트 감시를 먼저 띄움
- [ ] Terraform 반영 계획 (유지할 거면 같은 날 `main.tf` 수정 PR)
- [ ] gcloud 쓰기 작업 승인 받음

### 10.5 blue/green 절차와 이 방식 자체의 위험

절차는 9.5와 같습니다. 이 방식에도 아래 위험이 있습니다.

| 위험 | 내용 | 대응 |
|------|------|------|
| Terraform 불일치 | gcloud로 만든 새 노드 풀은 Terraform에 없음. 그대로 두면 다음 apply가 새 풀을 지우거나 기존 풀을 다시 만들 수 있음 | 새 풀은 Terraform으로 만들거나, gcloud로 만든 뒤 `terraform import`로 반영. 기존 풀 삭제도 Terraform으로 |
| 설정 누락 | 새 풀의 디스크, oauth scope, Workload Identity(`GKE_METADATA`), 라벨, 태그가 기존 풀과 다르면 ESO·stackdriver-exporter 같은 Workload Identity 사용 Pod가 GCP 권한을 잃음 | `gcp/terraform/modules/gke/main.tf`의 기존 풀 설정을 그대로 복사. 현재 워크로드는 노드 라벨 선택자를 쓰지 않음(`kubernetes.io/os`만 사용)을 확인함 |
| 자동 확장 혼선 | 두 풀이 공존하는 동안 autoscaler가 기존 풀에 노드를 추가할 수 있음 | 기존 노드 cordon 후 바로 drain, 확인 후 바로 기존 풀 삭제 |
| 비용 | 두 풀이 공존하는 동안 노드 비용 추가 | 작업 시간 최소화 |
| PDB | drain도 PDB를 지키므로 ingressgateway에서 똑같이 멈춤 | 복제본 임시 2개 또는 직접 삭제 |

### 10.6 작업 중 중단·되돌리기 기준

| 상황 | 판단 |
|------|------|
| 새 노드가 10분 넘게 생성되지 않음 (spot 재고 등) | 기존 노드 drain 전이면 작업 중지 검토. 바로 교체 중이면 진행률을 보며 대기하고, 서비스 영향은 외부 검사 기록으로 판단 |
| Pod가 Pending으로 남음 (Insufficient cpu/memory) | 용량 부족(R4). 원래 유형으로 되돌리거나 노드 수를 늘림 |
| 특정 Pod 재시작 반복 | 기동 경합(R3). 덜 붐비는 노드로 재배치 (2.7) |
| 외부 검사에서 여러 URL이 3분 넘게 동시 실패 | 진입점·istiod 상태 확인 (`kubectl -n istio-system get pods`), 필요하면 해당 Pod 재시작 |
| 되돌리기 결정 | 원래 유형으로 같은 명령을 다시 실행. 원복도 전체 교체라 같은 영향이 한 번 더 있으므로(R11), 되돌리는 쪽이 정말 나은지 먼저 판단 |
