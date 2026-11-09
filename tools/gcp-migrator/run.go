package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os/exec"
	"strings"
	"time"
)

// run.go 는 "▶ 실행" 버튼용. 생성된 명령을 로컬 셸로 실행하고
// stdout/stderr 를 실시간으로 브라우저에 스트리밍한다.
//
// 이 도구는 127.0.0.1 에만 바인딩되며, 실행 주체는 로컬 사용자 본인이고
// gcloud/kubectl 인증도 로컬 환경 그대로 사용한다.

// flushWriter 는 쓰는 즉시 HTTP 응답을 flush 해 실시간 스트리밍을 만든다.
type flushWriter struct {
	w http.ResponseWriter
	f http.Flusher
}

func (fw flushWriter) Write(p []byte) (int, error) {
	n, err := fw.w.Write(p)
	if fw.f != nil {
		fw.f.Flush()
	}
	return n, err
}

func handleRun(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	var body struct {
		Code string `json:"code"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	code := strings.TrimSpace(body.Code)
	if code == "" {
		http.Error(w, "빈 명령", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	w.Header().Set("Cache-Control", "no-cache")
	flusher, _ := w.(http.Flusher)
	fw := flushWriter{w: w, f: flusher}

	fmt.Fprintf(fw, "$ %s\n\n", singleLine(code))

	// 장시간 작업(터라폼/큰 export)도 고려해 넉넉한 타임아웃.
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Minute)
	defer cancel()

	// 로그인 셸(-l)로 실행해 사용자 PATH(gcloud SDK 등)와 프로파일을 그대로 사용.
	// 파이프/for 루프/$(...) 등 셸 기능을 쓰는 생성 명령을 그대로 실행하기 위함.
	cmd := exec.CommandContext(ctx, "bash", "-lc", code)
	cmd.Stdout = fw
	cmd.Stderr = fw

	start := time.Now()
	err := cmd.Run()
	elapsed := time.Since(start).Round(time.Millisecond)

	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			fmt.Fprintf(fw, "\n[중단] 30분 타임아웃 초과\n")
		} else {
			fmt.Fprintf(fw, "\n[종료코드] 실패: %v  (소요 %s)\n", err, elapsed)
		}
		return
	}
	fmt.Fprintf(fw, "\n[종료코드] 0 · 성공  (소요 %s)\n", elapsed)
}

// singleLine 은 에코 표시용으로 줄바꿈 연속(\)을 한 줄로 축약한다.
func singleLine(code string) string {
	s := strings.ReplaceAll(code, "\\\n", " ")
	s = strings.ReplaceAll(s, "\n", " ; ")
	for strings.Contains(s, "  ") {
		s = strings.ReplaceAll(s, "  ", " ")
	}
	return strings.TrimSpace(s)
}
