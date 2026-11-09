package main

import (
	"embed"
	"encoding/json"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
	"time"
)

//go:embed web
var webFS embed.FS

const (
	configFile = ".migrator-config.json"
	stateFile  = ".migrator-state.json"
)

// store 는 설정/진행상태 파일 접근을 직렬화한다.
type store struct {
	mu sync.Mutex
}

func (s *store) loadConfig() Config {
	s.mu.Lock()
	defer s.mu.Unlock()
	b, err := os.ReadFile(configFile)
	if err != nil {
		return DefaultConfig()
	}
	var c Config
	if err := json.Unmarshal(b, &c); err != nil {
		return DefaultConfig()
	}
	return c
}

func (s *store) saveConfig(c Config) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	b, _ := json.MarshalIndent(c, "", "  ")
	return os.WriteFile(configFile, b, 0o600)
}

func (s *store) loadState() map[string]bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := map[string]bool{}
	b, err := os.ReadFile(stateFile)
	if err != nil {
		return out
	}
	_ = json.Unmarshal(b, &out)
	return out
}

func (s *store) saveState(m map[string]bool) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	b, _ := json.MarshalIndent(m, "", "  ")
	return os.WriteFile(stateFile, b, 0o600)
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(v)
}

func main() {
	addr := flag.String("addr", "127.0.0.1:8787", "listen address")
	noOpen := flag.Bool("no-open", false, "do not open browser automatically")
	flag.Parse()

	st := &store{}

	sub, err := fs.Sub(webFS, "web")
	if err != nil {
		log.Fatal(err)
	}
	mux := http.NewServeMux()
	mux.Handle("/", http.FileServer(http.FS(sub)))

	mux.HandleFunc("/api/config", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			writeJSON(w, st.loadConfig())
		case http.MethodPost:
			var c Config
			if err := json.NewDecoder(r.Body).Decode(&c); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			if err := st.saveConfig(c); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, map[string]string{"status": "saved"})
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/phases", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, st.loadConfig().Phases())
	})

	mux.HandleFunc("/api/state", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodGet:
			writeJSON(w, st.loadState())
		case http.MethodPost:
			var m map[string]bool
			if err := json.NewDecoder(r.Body).Decode(&m); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			if err := st.saveState(m); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			writeJSON(w, map[string]string{"status": "saved"})
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	mux.HandleFunc("/api/defaults", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, DefaultConfig())
	})

	// 읽기 전용 gcloud 조회 (불러오기 버튼)
	mux.HandleFunc("/api/lookup/accounts", handleLookupAccounts)
	mux.HandleFunc("/api/lookup/billing", handleLookupBilling)

	// 명령 실행 + 실시간 스트리밍 (▶ 실행 버튼)
	mux.HandleFunc("/api/run", handleRun)

	srv := &http.Server{
		Addr:              *addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	url := "http://" + *addr
	abs, _ := filepath.Abs(".")
	fmt.Printf("\n  GCP Migration Wizard\n")
	fmt.Printf("  ─────────────────────────────────────────\n")
	fmt.Printf("  URL      : %s\n", url)
	fmt.Printf("  설정파일 : %s\n", filepath.Join(abs, configFile))
	fmt.Printf("  상태파일 : %s\n", filepath.Join(abs, stateFile))
	fmt.Printf("  종료     : Ctrl+C\n\n")

	if !*noOpen {
		go openBrowser(url)
	}
	log.Fatal(srv.ListenAndServe())
}

func openBrowser(url string) {
	time.Sleep(400 * time.Millisecond)
	var cmd string
	var args []string
	switch runtime.GOOS {
	case "darwin":
		cmd = "open"
	case "windows":
		cmd, args = "rundll32", []string{"url.dll,FileProtocolHandler"}
	default:
		cmd = "xdg-open"
	}
	_ = exec.Command(cmd, append(args, url)...).Start()
}
