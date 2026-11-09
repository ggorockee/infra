package main

import (
	"fmt"
	"strings"
)

// Config 는 GCP 프로젝트 이관에 필요한 모든 입력값을 담는다.
// 기본값은 claudedocs/migration-to-new-gcp.md 의 직전 이관(yango-501407) 기준이다.
type Config struct {
	OldProjectID      string   `json:"oldProjectID"`
	NewProjectID      string   `json:"newProjectID"`
	OldOwnerEmail     string   `json:"oldOwnerEmail"`
	NewOwnerEmail     string   `json:"newOwnerEmail"`
	BillingAccount    string   `json:"billingAccount"`
	Region            string   `json:"region"`
	TFStateBucket     string   `json:"tfStateBucket"`
	CloudSQLInstance  string   `json:"cloudSQLInstance"`
	Databases         []string `json:"databases"`
	Secrets           []string `json:"secrets"`
	Domains           []string `json:"domains"`
	DNSZones          []string `json:"dnsZones"`
	GatewayIP         string   `json:"gatewayIP"`
	GithubRepo        string   `json:"githubRepo"`
	FinalBackupBucket string   `json:"finalBackupBucket"`
}

// DefaultConfig 는 직전 이관 결과를 "구 프로젝트" 쪽 기본값으로 채워 돌려준다.
func DefaultConfig() Config {
	return Config{
		OldProjectID:     "yango-501407",
		NewProjectID:     "",
		OldOwnerEmail:    "woohalabs10@gmail.com",
		NewOwnerEmail:    "",
		BillingAccount:   "",
		Region:           "asia-northeast3",
		TFStateBucket:    "",
		CloudSQLInstance: "prod-woohalabs-cloudsql",
		Databases:        []string{"ojeomneo", "reviewmaps", "hotsao"},
		Secrets: []string{
			"prod-argocd-dex-credentials",
			"prod-ojeomneo-db-credentials",
			"prod-ojeomneo-api-credentials",
			"prod-ojeomneo-redis-credentials",
			"prod-ojeomneo-admin-credentials",
			"prod-reviewmaps-db-credentials",
			"prod-reviewmaps-api-credentials",
			"prod-reviewmaps-naver-api-credentials",
			"hotsao-app-secrets",
			"prod-hotsao-credentials",
			"cert-manager-dns01-key",
			"prod-sybot-credentials",
			"prod-yangobot-credentials",
		},
		Domains:           []string{"ggorockee.com", "hotsao.com", "review-maps.com", "woohalabs.com"},
		DNSZones:          []string{"ggorockee-com", "ggorockee-org", "hotsao-com", "review-maps-com", "woohalabs-com"},
		GatewayIP:         "",
		GithubRepo:        "",
		FinalBackupBucket: "",
	}
}

// withDerived 는 비어 있는 파생 필드를 신규 프로젝트 ID 기준으로 자동 계산한다.
func (c Config) withDerived() Config {
	n := c.NewProjectID
	if n == "" {
		n = "<NEW_PROJECT>"
	}
	if c.TFStateBucket == "" {
		c.TFStateBucket = n + "-tfstate"
	}
	if c.FinalBackupBucket == "" {
		old := c.OldProjectID
		old = strings.ReplaceAll(old, "-", "")
		c.FinalBackupBucket = n + "-final-backup-" + old
	}
	return c
}

// Command 는 UI 의 명령 카드 하나를 표현한다.
type Command struct {
	Label  string `json:"label"`
	Code   string `json:"code"`
	Danger bool   `json:"danger"` // 되돌리기 어려운 명령 (삭제/apply 등)
}

// Step 은 Phase 안의 개별 체크리스트 항목.
type Step struct {
	ID       string    `json:"id"`
	Title    string    `json:"title"`
	Note     string    `json:"note"`
	Manual   bool      `json:"manual"` // 콘솔/수동 작업 (명령 없음)
	Commands []Command `json:"commands"`
}

// Phase 는 이관 단계(0~6).
type Phase struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	Summary string `json:"summary"`
	Steps   []Step `json:"steps"`
}

// enabledAPIs 는 Phase 0 에서 활성화할 API 목록.
var enabledAPIs = []string{
	"compute.googleapis.com",
	"container.googleapis.com",
	"sqladmin.googleapis.com",
	"servicenetworking.googleapis.com",
	"secretmanager.googleapis.com",
	"iam.googleapis.com",
	"cloudresourcemanager.googleapis.com",
	"iamcredentials.googleapis.com",
	"storage.googleapis.com",
	"dns.googleapis.com",
	"logging.googleapis.com",
	"monitoring.googleapis.com",
}

// Phases 는 현재 설정값으로 치환된 전체 이관 단계를 생성한다.
func (c Config) Phases() []Phase {
	c = c.withDerived()
	old, nw := c.OldProjectID, c.NewProjectID
	if nw == "" {
		nw = "<NEW_PROJECT>"
	}
	tfSA := fmt.Sprintf("terraform@%s.iam.gserviceaccount.com", nw)

	return []Phase{
		c.phase0(old, nw, tfSA),
		c.phase1(old, nw),
		c.phase2(old, nw),
		c.phase3(old, nw),
		c.phase4(nw),
		c.phase5(nw),
		c.phase6(old, nw),
	}
}

func (c Config) phase0(old, nw, tfSA string) Phase {
	apiList := strings.Join(enabledAPIs, " \\\n  ")
	return Phase{
		ID:      "phase0",
		Title:   "Phase 0 · 새 프로젝트 사전 준비",
		Summary: "결제 연결, API 활성화, Terraform 서비스 계정, TF state 버킷을 준비합니다.",
		Steps: []Step{
			{
				ID:    "p0-create",
				Title: "새 프로젝트 생성 (이미 있으면 생략)",
				Note:  "새 계정(" + def(c.NewOwnerEmail, "<NEW_OWNER>") + ")으로 로그인된 상태에서 실행",
				Commands: []Command{
					{Label: "프로젝트 생성", Code: fmt.Sprintf("gcloud projects create %s --name=%s", nw, nw)},
				},
			},
			{
				ID:    "p0-billing",
				Title: "결제 계정 연결",
				Commands: []Command{
					{Label: "결제 연결", Code: fmt.Sprintf("gcloud billing projects link %s \\\n  --billing-account=%s", nw, def(c.BillingAccount, "<BILLING_ACCOUNT>"))},
				},
			},
			{
				ID:    "p0-apis",
				Title: "필수 API 활성화 (12개)",
				Commands: []Command{
					{Label: "API 일괄 활성화", Code: fmt.Sprintf("gcloud services enable \\\n  %s \\\n  --project=%s", apiList, nw)},
				},
			},
			{
				ID:    "p0-sa",
				Title: "Terraform 서비스 계정 생성 + Owner 권한",
				Commands: []Command{
					{Label: "SA 생성", Code: fmt.Sprintf("gcloud iam service-accounts create terraform \\\n  --display-name=\"Terraform\" --project=%s", nw)},
					{Label: "Owner 바인딩", Code: fmt.Sprintf("gcloud projects add-iam-policy-binding %s \\\n  --member=\"serviceAccount:%s\" \\\n  --role=\"roles/owner\"", nw, tfSA)},
					{Label: "SA 키 발급 (GitHub Secret용)", Code: fmt.Sprintf("gcloud iam service-accounts keys create terraform-key.json \\\n  --iam-account=%s", tfSA)},
				},
			},
			{
				ID:    "p0-bucket",
				Title: "Terraform state용 GCS 버킷 생성 + 버전관리",
				Commands: []Command{
					{Label: "버킷 생성", Code: fmt.Sprintf("gcloud storage buckets create gs://%s \\\n  --project=%s --location=%s", c.TFStateBucket, nw, c.Region)},
					{Label: "버전관리 활성화", Code: fmt.Sprintf("gcloud storage buckets update gs://%s --versioning", c.TFStateBucket)},
				},
			},
		},
	}
}

func (c Config) phase1(old, nw string) Phase {
	return Phase{
		ID:      "phase1",
		Title:   "Phase 1 · Terraform 인프라 배포",
		Summary: "코드의 프로젝트 참조를 교체하고, GitHub Secrets를 갱신한 뒤 Actions로 apply 합니다.",
		Steps: []Step{
			{
				ID:     "p1-code",
				Title:  "코드 내 프로젝트 참조 교체 (5개 파일)",
				Manual: true,
				Note: "다음 파일의 '" + old + "' → '" + nw + "' 교체:\n" +
					"• gcp/terraform/environments/prod/variables.tf (project_id default)\n" +
					"• gcp/terraform/environments/prod/backend.tf (bucket = " + c.TFStateBucket + ")\n" +
					"• charts/helm/prod/cert-manager/values.yaml (gcpProjectId)\n" +
					"• charts/helm/prod/argo-cd/values.yaml (iam.gke.io/gcp-service-account → argocd-prod@" + nw + ")\n" +
					"• charts/helm/prod/kube-prometheus-stack/values-override.yaml (gcpProjectID)",
				Commands: []Command{
					{Label: "참조 위치 전수 검색", Code: fmt.Sprintf("grep -rn \"%s\" --include='*.tf' --include='*.yaml' . | grep -v .git", old)},
				},
			},
			{
				ID:     "p1-secrets",
				Title:  "GitHub Repository Secrets 갱신",
				Manual: true,
				Note:   "GitHub → Settings → Secrets and variables → Actions",
				Commands: []Command{
					{Label: "GCP_PROJECT_ID 갱신 (gh CLI)", Code: fmt.Sprintf("gh secret set GCP_PROJECT_ID --body %q --repo %s", nw, def(c.GithubRepo, "<OWNER/REPO>"))},
					{Label: "GCP_SA_KEY 갱신 (gh CLI)", Code: fmt.Sprintf("gh secret set GCP_SA_KEY < terraform-key.json --repo %s", def(c.GithubRepo, "<OWNER/REPO>"))},
				},
			},
			{
				ID:     "p1-bootstrap",
				Title:  "⚠️ external_secrets 2단계 부트스트랩",
				Manual: true,
				Note: "최초 apply 는 GKE 와 external_secrets 를 동시에 만들 수 없음 (kubernetes_manifest 가 live cluster 필요).\n" +
					"1) main.tf 에서 external_secrets 모듈을 먼저 주석 처리하고 apply → GKE 생성\n" +
					"2) ESO CRD 를 Helm 과 별개로 먼저 적용하고 소유권 라벨 부착\n" +
					"3) external_secrets 모듈 재활성화 후 다시 apply",
			},
			{
				ID:     "p1-apply",
				Title:  "GitHub Actions apply 실행 + GKE 접근 확인",
				Manual: false,
				Commands: []Command{
					{Label: "GKE 자격증명 가져오기", Code: fmt.Sprintf("gcloud container clusters get-credentials prod-gke \\\n  --region=%s --project=%s", c.Region, nw)},
					{Label: "노드 확인", Code: "kubectl get nodes"},
				},
			},
		},
	}
}

func (c Config) phase2(old, nw string) Phase {
	steps := []Step{
		{
			ID:    "p2-list",
			Title: "기존 프로젝트 시크릿 목록 확인",
			Commands: []Command{
				{Label: "목록 조회", Code: fmt.Sprintf("gcloud secrets list --project=%s", old)},
			},
		},
	}
	// 시크릿별 복제 스크립트 (값을 구 → 신으로 복사)
	var b strings.Builder
	b.WriteString("# 구 프로젝트 → 신 프로젝트 시크릿 일괄 복제\n")
	b.WriteString(fmt.Sprintf("for S in \\\n"))
	for i, s := range c.Secrets {
		sep := " \\"
		if i == len(c.Secrets)-1 {
			sep = ""
		}
		b.WriteString(fmt.Sprintf("  %s%s\n", s, sep))
	}
	b.WriteString("; do\n")
	b.WriteString(fmt.Sprintf("  gcloud secrets create \"$S\" --project=%s 2>/dev/null\n", nw))
	b.WriteString(fmt.Sprintf("  gcloud secrets versions access latest --secret=\"$S\" --project=%s \\\n", old))
	b.WriteString(fmt.Sprintf("    | gcloud secrets versions add \"$S\" --data-file=- --project=%s\n", nw))
	b.WriteString("done")

	steps = append(steps, Step{
		ID:    "p2-copy",
		Title: fmt.Sprintf("시크릿 일괄 복제 (%d개)", len(c.Secrets)),
		Note:  "민감정보가 로컬 파이프를 통과함. 작업 후 셸 히스토리 주의.",
		Commands: []Command{
			{Label: "일괄 복제 스크립트", Code: b.String()},
		},
	})
	return Phase{
		ID:      "phase2",
		Title:   "Phase 2 · Secret Manager 이관",
		Summary: "구 프로젝트의 시크릿을 신 프로젝트로 복제합니다.",
		Steps:   steps,
	}
}

func (c Config) phase3(old, nw string) Phase {
	steps := []Step{
		{
			ID:     "p3-precreate",
			Title:  "Terraform 미관리 DB/유저 사전 생성 (예: hotsao)",
			Note:   "Terraform 이 관리하지 않는 수동 생성 DB 는 import 전에 먼저 만들어야 함.",
			Manual: false,
			Commands: []Command{
				{Label: "DB 생성", Code: fmt.Sprintf("gcloud sql databases create hotsao \\\n  --instance=%s --project=%s", c.CloudSQLInstance, nw)},
				{Label: "유저 생성", Code: fmt.Sprintf("gcloud sql users create hotsao \\\n  --instance=%s --project=%s", c.CloudSQLInstance, nw)},
			},
		},
	}
	for _, db := range c.Databases {
		bucket := c.TFStateBucket // export 임시 버킷으로 state 버킷 재사용 가능
		steps = append(steps, Step{
			ID:    "p3-db-" + db,
			Title: fmt.Sprintf("DB 이관: %s (서버사이드 export → import)", db),
			Note:  "네트워크 접근 불필요한 서버사이드 export/import 사용. import 중 서비스 다운타임 발생.",
			Commands: []Command{
				{Label: "① export (구)", Code: fmt.Sprintf("gcloud sql export sql %s \\\n  gs://%s/%s.sql --database=%s --project=%s", c.CloudSQLInstance, bucket, db, db, old)},
				{Label: "② 신 SQL SA 에 버킷 읽기 임시 부여", Code: fmt.Sprintf("SA=$(gcloud sql instances describe %s --project=%s --format='value(serviceAccountEmailAddress)')\ngcloud storage buckets add-iam-policy-binding gs://%s \\\n  --member=\"serviceAccount:$SA\" --role=roles/storage.objectViewer", c.CloudSQLInstance, nw, bucket)},
				{Label: "③ import (신)", Code: fmt.Sprintf("gcloud sql import sql %s \\\n  gs://%s/%s.sql --database=%s --project=%s", c.CloudSQLInstance, bucket, db, db, nw), Danger: true},
			},
		})
	}
	return Phase{
		ID:      "phase3",
		Title:   "Phase 3 · Cloud SQL 데이터 이관",
		Summary: "각 DB를 서버사이드 export/import로 옮깁니다. ⚠️ POSTGRES_HOST 시크릿 갱신 확인 필수.",
		Steps:   steps,
	}
}

func (c Config) phase4(nw string) Phase {
	return Phase{
		ID:      "phase4",
		Title:   "Phase 4 · 워크로드 이관 (ArgoCD)",
		Summary: "ArgoCD를 수동 설치하고 ApplicationSets로 앱을 자동 배포합니다.",
		Steps: []Step{
			{
				ID:     "p4-argocd",
				Title:  "ArgoCD 수동 설치 + Git 저장소 연결",
				Manual: true,
				Note:   "첫 설치는 사용자가 직접 진행. 이후 ApplicationSets 적용 시 12개 앱 자동 배포됨.",
			},
			{
				ID:    "p4-gateway",
				Title: "Istio Ingress Gateway 외부 IP 확인",
				Note:  "여기서 확인한 IP를 설정의 'Gateway IP' 칸에 입력하면 Phase 5 명령에 자동 반영됩니다.",
				Commands: []Command{
					{Label: "외부 IP 조회", Code: "kubectl get svc istio-ingressgateway -n istio-system \\\n  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"},
				},
			},
			{
				ID:     "p4-istio-fix",
				Title:  "⚠️ istio-ingressgateway ImagePullBackOff 대응",
				Manual: true,
				Note:   "sidecar-injector webhook 준비 전 스케줄되면 image:auto 로 뜸. 파드 삭제로 재생성하면 정상 이미지로 교체됨.",
				Commands: []Command{
					{Label: "파드 재생성", Code: "kubectl delete pod -n istio-system -l app=istio-ingressgateway"},
				},
			},
		},
	}
}

func (c Config) phase5(nw string) Phase {
	steps := []Step{}
	for _, z := range c.DNSZones {
		steps = append(steps, Step{
			ID:    "p5-zone-" + z,
			Title: "Cloud DNS 존 생성: " + z,
			Note:  "실제 권위 DNS는 Cloudflare. 이 존은 _acme-challenge SSL 발급 위임용.",
			Commands: []Command{
				{Label: "존 생성", Code: fmt.Sprintf("gcloud dns managed-zones create %s \\\n  --dns-name=%s. --project=%s \\\n  --description='migrated zone'", z, strings.ReplaceAll(z, "-", "."), nw)},
			},
		})
	}
	ip := def(c.GatewayIP, "<GATEWAY_IP>")
	steps = append(steps,
		Step{
			ID:    "p5-cert-sa",
			Title: "cert-manager DNS-01 서비스 계정 교체",
			Note:  "구 프로젝트 SA 키를 그대로 쓰면 Phase 6 삭제 후 인증서 갱신이 깨짐. 신 프로젝트 SA 로 새로 발급.",
			Commands: []Command{
				{Label: "SA 생성", Code: fmt.Sprintf("gcloud iam service-accounts create cert-manager-dns01 --project=%s", nw)},
				{Label: "dns.admin 부여", Code: fmt.Sprintf("gcloud projects add-iam-policy-binding %s \\\n  --member=\"serviceAccount:cert-manager-dns01@%s.iam.gserviceaccount.com\" \\\n  --role=roles/dns.admin", nw, nw)},
				{Label: "키 발급", Code: fmt.Sprintf("gcloud iam service-accounts keys create dns01-key.json \\\n  --iam-account=cert-manager-dns01@%s.iam.gserviceaccount.com", nw)},
			},
		},
		Step{
			ID:     "p5-cloudflare",
			Title:  "Cloudflare A레코드 전환 (실제 트래픽 전환)",
			Manual: true,
			Note:   "⚠️ 트래픽 전환의 핵심. 각 도메인 root+wildcard A레코드를 " + ip + " 로 변경. Cloud DNS 존 생성만으로는 전환되지 않음.\n대상 도메인: " + strings.Join(c.Domains, ", "),
		},
		Step{
			ID:    "p5-verify",
			Title: "도메인 통한 실제 HTTPS 검증",
			Commands: func() []Command {
				cmds := []Command{}
				for _, d := range c.Domains {
					cmds = append(cmds, Command{Label: d, Code: fmt.Sprintf("curl -sIk https://%s | head -1", d)})
				}
				return cmds
			}(),
		},
	)
	return Phase{
		ID:      "phase5",
		Title:   "Phase 5 · DNS 전환 및 검증",
		Summary: "Cloud DNS 존 생성, cert-manager SA 교체, Cloudflare A레코드 전환으로 트래픽을 넘깁니다.",
		Steps:   steps,
	}
}

func (c Config) phase6(old, nw string) Phase {
	dbExports := []Command{}
	for _, db := range c.Databases {
		dbExports = append(dbExports, Command{
			Label: "최종 백업: " + db,
			Code: fmt.Sprintf("gcloud sql export sql %s \\\n  gs://%s/%s-final.sql --database=%s --project=%s",
				c.CloudSQLInstance, c.FinalBackupBucket, db, db, old),
		})
	}
	return Phase{
		ID:      "phase6",
		Title:   "Phase 6 · 기존 프로젝트 정리",
		Summary: "최종 백업 후 구 프로젝트를 삭제합니다. 삭제는 30일 내 undelete 가능.",
		Steps: []Step{
			{
				ID:    "p6-backup-bucket",
				Title: "영구 보존용 최종 백업 버킷 생성",
				Commands: []Command{
					{Label: "버킷 생성", Code: fmt.Sprintf("gcloud storage buckets create gs://%s \\\n  --project=%s --location=%s", c.FinalBackupBucket, nw, c.Region)},
				},
			},
			{
				ID:       "p6-final-export",
				Title:    "구 Cloud SQL 최종 export (프로젝트 삭제와 무관하게 보존)",
				Commands: dbExports,
			},
			{
				ID:    "p6-delete",
				Title: "🚨 구 프로젝트 삭제 요청",
				Note:  "DELETE_REQUESTED 상태가 되며 30일 내 복구 가능. 30일 후 영구 삭제.",
				Commands: []Command{
					{Label: "삭제 요청", Code: fmt.Sprintf("gcloud projects delete %s", old), Danger: true},
					{Label: "(복구) 30일 내 되돌리기", Code: fmt.Sprintf("gcloud projects undelete %s", old)},
				},
			},
		},
	}
}

func def(v, fallback string) string {
	if strings.TrimSpace(v) == "" {
		return fallback
	}
	return v
}
