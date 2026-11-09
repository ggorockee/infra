package main

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

// envWithAccount 은 선택한 gcloud 계정을 CLOUDSDK_CORE_ACCOUNT 로 주입한다.
// 전역 gcloud config 를 바꾸지 않고 이 프로세스 실행에만 계정을 적용한다.
func envWithAccount(account string) []string {
	env := os.Environ()
	if strings.TrimSpace(account) != "" {
		env = append(env, "CLOUDSDK_CORE_ACCOUNT="+account)
	}
	return env
}

// lookup.go 는 "불러오기" 버튼용 읽기 전용 gcloud 조회만 담당한다.
// 고정된 read-only 명령만 실행하며, 사용자 입력을 셸에 전달하지 않는다.

type billingAccount struct {
	ID          string `json:"id"`
	DisplayName string `json:"displayName"`
	Open        bool   `json:"open"`
}

// activeAccount 는 현재 gcloud 활성 계정을 돌려준다 (없으면 빈 문자열).
func activeAccount(ctx context.Context) string {
	out, err := exec.CommandContext(ctx, "gcloud", "auth", "list",
		"--filter=status:ACTIVE", "--format=value(account)").Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

func gcloudErr(err error) string {
	if ee, ok := err.(*exec.ExitError); ok && len(ee.Stderr) > 0 {
		return strings.TrimSpace(string(ee.Stderr))
	}
	return err.Error()
}

// handleLookupAccounts: gcloud auth list (인증된 계정 목록 + 활성 계정)
func handleLookupAccounts(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	out, err := exec.CommandContext(ctx, "gcloud", "auth", "list", "--format=json").Output()
	if err != nil {
		writeJSON(w, map[string]any{"ok": false, "error": "gcloud 조회 실패: " + gcloudErr(err)})
		return
	}
	var raw []struct {
		Account string `json:"account"`
		Status  string `json:"status"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		writeJSON(w, map[string]any{"ok": false, "error": "결과 파싱 실패: " + err.Error()})
		return
	}
	active := ""
	accounts := make([]string, 0, len(raw))
	for _, a := range raw {
		accounts = append(accounts, a.Account)
		if a.Status == "ACTIVE" {
			active = a.Account
		}
	}
	writeJSON(w, map[string]any{"ok": true, "active": active, "accounts": accounts})
}

// handleLookupBilling: gcloud billing accounts list (read-only)
// ?account= 로 조회 계정을 지정할 수 있다.
func handleLookupBilling(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "gcloud", "billing", "accounts", "list", "--format=json")
	cmd.Env = envWithAccount(r.URL.Query().Get("account"))
	out, err := cmd.Output()
	if err != nil {
		writeJSON(w, map[string]any{
			"ok":    false,
			"error": "gcloud 조회 실패 (로그인/권한 확인): " + gcloudErr(err),
		})
		return
	}

	var raw []struct {
		Name        string `json:"name"`
		DisplayName string `json:"displayName"`
		Open        bool   `json:"open"`
	}
	if err := json.Unmarshal(out, &raw); err != nil {
		writeJSON(w, map[string]any{"ok": false, "error": "결과 파싱 실패: " + err.Error()})
		return
	}

	accs := make([]billingAccount, 0, len(raw))
	for _, a := range raw {
		accs = append(accs, billingAccount{
			ID:          strings.TrimPrefix(a.Name, "billingAccounts/"),
			DisplayName: a.DisplayName,
			Open:        a.Open,
		})
	}
	usedAccount := r.URL.Query().Get("account")
	if usedAccount == "" {
		usedAccount = activeAccount(ctx)
	}
	writeJSON(w, map[string]any{
		"ok":       true,
		"account":  usedAccount,
		"accounts": accs,
	})
}
