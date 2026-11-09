"use strict";

const api = {
  async get(path) { const r = await fetch(path); return r.json(); },
  async post(path, body) {
    const r = await fetch(path, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    return r.json();
  },
};

const state = {
  config: {},
  phases: [],
  progress: {}, // stepID -> bool
  view: "config", // "config" | phaseID
  runAccount: "", // gcloud 실행 계정 (빈 값 = gcloud 활성 계정)
  accounts: [],
};

// 설정 폼 필드 정의 (라벨/힌트/타입)
const FIELDS = [
  { key: "oldProjectID", label: "구 프로젝트 ID", hint: "현재 운영 중인 프로젝트" },
  { key: "newProjectID", label: "신 프로젝트 ID *", hint: "이관 대상 (필수)" },
  { key: "oldOwnerEmail", label: "구 소유 계정" },
  { key: "newOwnerEmail", label: "신 소유 계정" },
  { key: "billingAccount", label: "결제 계정 ID", hint: "예: 019BE5-B9EFB8-C3E4D3", fetch: "billing" },
  { key: "region", label: "리전" },
  { key: "tfStateBucket", label: "TF State 버킷", hint: "비우면 {신}-tfstate 자동" },
  { key: "cloudSQLInstance", label: "Cloud SQL 인스턴스" },
  { key: "gatewayIP", label: "Istio Gateway IP", hint: "Phase 4 에서 확인 후 입력" },
  { key: "githubRepo", label: "GitHub 저장소", hint: "예: woohaen88/infra" },
  { key: "finalBackupBucket", label: "최종 백업 버킷", hint: "비우면 자동 생성" },
];
const LIST_FIELDS = [
  { key: "databases", label: "이관 DB 목록 (쉼표 구분)" },
  { key: "domains", label: "도메인 목록 (쉼표 구분)" },
  { key: "dnsZones", label: "Cloud DNS 존 목록 (쉼표 구분)" },
  { key: "secrets", label: "Secret Manager 시크릿 목록 (쉼표 구분)" },
];

function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

function toast(msg) {
  const t = document.getElementById("toast");
  t.textContent = msg;
  t.classList.add("show");
  clearTimeout(t._timer);
  t._timer = setTimeout(() => t.classList.remove("show"), 1800);
}

// ── progress 계산 ──
function allStepIDs() {
  const ids = [];
  for (const p of state.phases) for (const s of p.steps) ids.push(s.id);
  return ids;
}
function phaseProgress(p) {
  const total = p.steps.length;
  const done = p.steps.filter((s) => state.progress[s.id]).length;
  return { done, total };
}
function overallProgress() {
  const ids = allStepIDs();
  const done = ids.filter((id) => state.progress[id]).length;
  return { done, total: ids.length };
}

// ── 렌더: 사이드바 ──
function renderSidebar() {
  document.getElementById("route-old").textContent = state.config.oldProjectID || "—";
  document.getElementById("route-new").textContent = state.config.newProjectID || "신규?";

  const ov = overallProgress();
  const pct = ov.total ? Math.round((ov.done / ov.total) * 100) : 0;
  document.getElementById("overall-pct").textContent = pct + "%";
  document.getElementById("overall-bar").style.width = pct + "%";

  const nav = document.getElementById("nav");
  let html = navItem("config", "⚙", "설정", state.view === "config", "", true);
  for (const p of state.phases) {
    const pr = phaseProgress(p);
    const done = pr.total > 0 && pr.done === pr.total;
    const num = p.id.replace("phase", "");
    html += navItem(p.id, done ? "✓" : num, p.title.split("·")[1]?.trim() || p.title,
      state.view === p.id, `${pr.done}/${pr.total}`, false, done);
  }
  nav.innerHTML = html;
  nav.querySelectorAll(".nav-item").forEach((el) =>
    el.addEventListener("click", () => { state.view = el.dataset.id; render(); }));
}

function navItem(id, dot, title, active, prog, isConfig, done) {
  return `<div class="nav-item ${active ? "active" : ""}" data-id="${id}">
    <div class="nav-dot ${done ? "done" : ""}">${esc(dot)}</div>
    <div class="nav-label">
      <div class="nav-title">${esc(title)}</div>
      ${isConfig ? "" : `<div class="nav-prog">${prog} 완료</div>`}
    </div>
  </div>`;
}

// ── 렌더: 설정 뷰 ──
function renderConfig() {
  const c = state.config;
  let fields = FIELDS.map((f) => `
    <div class="field">
      <label>${esc(f.label)}</label>
      <div class="field-row">
        <input id="f-${f.key}" value="${esc(c[f.key] || "")}" placeholder="${esc(f.hint || "")}" />
        ${f.fetch ? `<button class="fetch-btn" data-fetch="${f.fetch}">불러오기</button>` : ""}
      </div>
      ${f.hint ? `<span class="hint">${esc(f.hint)}</span>` : ""}
    </div>`).join("");

  let lists = LIST_FIELDS.map((f) => `
    <div class="field full">
      <label>${esc(f.label)}</label>
      <textarea id="f-${f.key}">${esc((c[f.key] || []).join(", "))}</textarea>
    </div>`).join("");

  document.getElementById("view").innerHTML = `
    <div class="page-head">
      <h1>이관 설정</h1>
      <p>신규 프로젝트 정보를 입력하면 Phase 0~6 의 모든 명령이 자동으로 채워집니다.
      입력값은 로컬 파일(.migrator-config.json)에만 저장됩니다.</p>
    </div>
    <div class="form-grid">${fields}${lists}</div>
    <div class="form-actions">
      <button class="btn" id="save-cfg">저장하고 명령 생성 →</button>
      <button class="btn btn-sec" id="load-def">기본값 불러오기</button>
    </div>`;

  document.getElementById("save-cfg").addEventListener("click", saveConfig);
  document.getElementById("load-def").addEventListener("click", async () => {
    state.config = await api.get("/api/defaults");
    renderConfig();
    toast("기본값을 불러왔습니다");
  });
  document.querySelectorAll(".fetch-btn").forEach((el) =>
    el.addEventListener("click", () => {
      if (el.dataset.fetch === "billing") lookupBilling(el);
    }));
}

// gcloud 인증을 활용해 결제 계정을 조회하고 입력란을 채운다 (읽기 전용)
async function lookupBilling(btn) {
  const orig = btn.textContent;
  btn.textContent = "조회 중…";
  btn.disabled = true;
  try {
    const q = state.runAccount ? "?account=" + encodeURIComponent(state.runAccount) : "";
    const r = await api.get("/api/lookup/billing" + q);
    if (!r.ok) { toast("⚠️ " + (r.error || "조회 실패")); return; }
    const accs = r.accounts || [];
    if (accs.length === 0) { toast("조회된 결제 계정이 없습니다"); return; }

    let chosen = accs[0];
    if (accs.length > 1) {
      const lines = accs.map((a, i) =>
        `${i + 1}. ${a.id}  (${a.displayName}${a.open ? "" : " · 닫힘"})`).join("\n");
      const pick = prompt(
        `현재 gcloud 계정: ${r.account || "?"}\n결제 계정을 선택하세요:\n\n${lines}\n\n번호 입력:`, "1");
      if (pick === null) return;
      const idx = parseInt(pick, 10) - 1;
      if (isNaN(idx) || idx < 0 || idx >= accs.length) { toast("잘못된 선택"); return; }
      chosen = accs[idx];
    }
    document.getElementById("f-billingAccount").value = chosen.id;
    toast(`결제 계정 입력됨: ${chosen.id} (gcloud: ${r.account || "?"})`);
  } catch (e) {
    toast("조회 중 오류: " + e.message);
  } finally {
    btn.textContent = orig;
    btn.disabled = false;
  }
}

function collectConfig() {
  const c = { ...state.config };
  for (const f of FIELDS) c[f.key] = document.getElementById("f-" + f.key).value.trim();
  for (const f of LIST_FIELDS) {
    c[f.key] = document.getElementById("f-" + f.key).value
      .split(",").map((s) => s.trim()).filter(Boolean);
  }
  return c;
}

async function saveConfig() {
  const c = collectConfig();
  if (!c.newProjectID) { toast("⚠️ 신 프로젝트 ID는 필수입니다"); return; }
  await api.post("/api/config", c);
  state.config = c;
  state.phases = await api.get("/api/phases");
  state.view = "phase0";
  render();
  toast("저장 완료 · 명령이 생성되었습니다");
}

// ── 렌더: Phase 뷰 ──
function renderPhase(p) {
  const steps = p.steps.map(renderStep).join("");
  document.getElementById("view").innerHTML = `
    <div class="page-head">
      <h1>${esc(p.title)}</h1>
      <p>${esc(p.summary)}</p>
    </div>
    ${steps}`;

  document.querySelectorAll(".check").forEach((el) =>
    el.addEventListener("click", () => toggleStep(el.dataset.step)));
  document.querySelectorAll(".copy-btn").forEach((el) =>
    el.addEventListener("click", () => copyCode(el)));
  document.querySelectorAll(".run-btn").forEach((el) =>
    el.addEventListener("click", () => runCommand(el)));
}

// 명령을 로컬 셸로 실행하고 결과를 실시간 스트리밍으로 출력한다.
async function runCommand(btn) {
  const code = btn.dataset.code;
  const danger = btn.dataset.danger === "1";
  if (danger && !confirm("🚨 되돌리기 어려운 명령입니다.\n정말 실행할까요?\n\n" + code)) return;

  const out = document.getElementById("out-" + btn.dataset.out);
  out.hidden = false;
  out.textContent = "";
  out.classList.add("running");
  const orig = btn.textContent;
  btn.disabled = true;
  btn.textContent = "⏳ 실행 중";

  try {
    const resp = await fetch("/api/run", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code, account: state.runAccount }),
    });
    if (!resp.ok || !resp.body) {
      out.textContent += "\n[오류] 서버 응답 실패 (" + resp.status + ")";
      return;
    }
    const reader = resp.body.getReader();
    const dec = new TextDecoder();
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      out.textContent += dec.decode(value, { stream: true });
      out.scrollTop = out.scrollHeight;
    }
  } catch (e) {
    out.textContent += "\n[오류] " + e.message;
  } finally {
    out.classList.remove("running");
    btn.disabled = false;
    btn.textContent = orig;
  }
}

function renderStep(s) {
  const on = !!state.progress[s.id];
  const cmds = (s.commands || []).map((cmd, ci) => {
    const cid = `${s.id}-c${ci}`;
    return `
    <div class="cmd ${cmd.danger ? "danger" : ""}">
      <div class="cmd-head">
        <span class="cmd-label">${esc(cmd.label)}</span>
        <div class="cmd-actions">
          <button class="copy-btn" data-code="${esc(cmd.code)}">복사</button>
          <button class="run-btn" data-code="${esc(cmd.code)}" data-danger="${cmd.danger ? 1 : 0}" data-out="${cid}">▶ 실행</button>
        </div>
      </div>
      <pre>${esc(cmd.code)}</pre>
      <div class="cmd-out" id="out-${cid}" hidden></div>
    </div>`;
  }).join("");

  return `<div class="step ${on ? "done" : ""}">
    <div class="step-head">
      <div class="check ${on ? "on" : ""}" data-step="${s.id}"></div>
      <div class="step-body">
        <div class="step-title">${esc(s.title)}${s.manual ? '<span class="badge-manual">수동</span>' : ""}</div>
        ${s.note ? `<div class="step-note">${esc(s.note)}</div>` : ""}
        ${cmds ? `<div class="cmds">${cmds}</div>` : ""}
      </div>
    </div>
  </div>`;
}

async function toggleStep(id) {
  state.progress[id] = !state.progress[id];
  await api.post("/api/state", state.progress);
  render();
}

function copyCode(el) {
  const code = el.dataset.code;
  navigator.clipboard.writeText(code).then(() => {
    el.textContent = "복사됨";
    el.classList.add("copied");
    toast("클립보드에 복사했습니다");
    setTimeout(() => { el.textContent = "복사"; el.classList.remove("copied"); }, 1500);
  });
}

// ── 메인 렌더 ──
function render() {
  renderSidebar();
  if (state.view === "config") { renderConfig(); return; }
  const p = state.phases.find((x) => x.id === state.view);
  if (p) renderPhase(p); else renderConfig();
}

async function loadAccounts() {
  const sel = document.getElementById("acct-sel");
  const hint = document.getElementById("acct-hint");
  const r = await api.get("/api/lookup/accounts");
  if (!r.ok) {
    sel.innerHTML = `<option value="">(gcloud 조회 실패)</option>`;
    hint.textContent = r.error || "gcloud 인증을 확인하세요";
    return;
  }
  state.accounts = r.accounts || [];
  const saved = localStorage.getItem("runAccount");
  state.runAccount = (saved && state.accounts.includes(saved)) ? saved : (r.active || "");
  sel.innerHTML = state.accounts
    .map((a) => `<option value="${esc(a)}" ${a === state.runAccount ? "selected" : ""}>${esc(a)}${a === r.active ? " (활성)" : ""}</option>`)
    .join("");
  hint.textContent = `${state.accounts.length}개 계정 인증됨 · 선택 계정으로 실행`;
  sel.addEventListener("change", () => {
    state.runAccount = sel.value;
    localStorage.setItem("runAccount", sel.value);
    toast("실행 계정: " + sel.value);
  });
}

async function init() {
  state.config = await api.get("/api/config");
  state.phases = await api.get("/api/phases");
  state.progress = await api.get("/api/state");
  await loadAccounts();
  state.view = state.config.newProjectID ? "phase0" : "config";
  render();

  document.getElementById("reset-btn").addEventListener("click", async () => {
    if (!confirm("모든 진행상태를 초기화할까요? (설정값은 유지)")) return;
    state.progress = {};
    await api.post("/api/state", {});
    render();
    toast("진행상태를 초기화했습니다");
  });
}

init();
