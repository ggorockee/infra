#!/usr/bin/env python3
"""AdMob API 읽기 토큰을 만들어 Kubernetes Secret에 저장한다. (최초 1회, 토큰이 만료·취소됐을 때 다시 실행)

사용: python3 scripts/admob-oauth-setup.py .secrets/<OAuth 데스크톱 클라이언트>.json
- 브라우저에서 AdMob 계정으로 로그인해 읽기 권한(admob.readonly)을 허용한다.
- 토큰은 화면과 파일에 남기지 않고 Secret monitoring/app-metrics-admob-oauth에만 저장한다.
- 설명: claudedocs/app-metrics-monitoring.md
"""

import base64
import hashlib
import json
import secrets
import subprocess
import sys
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer

SCOPE = "https://www.googleapis.com/auth/admob.readonly"
PUBLISHER = "pub-8516861197467665"
CONTEXT = "gke_yanggo-514212_asia-northeast3-a_woohalabs-prod-gke"
NAMESPACE, SECRET = "monitoring", "app-metrics-admob-oauth"


def kubectl(*args, data=None):
    return subprocess.run(
        ["kubectl", "--context", CONTEXT, "-n", NAMESPACE, *args],
        input=data, text=True, capture_output=True, check=False,
    )


def post(url, form):
    with urllib.request.urlopen(url, urllib.parse.urlencode(form).encode(), timeout=30) as response:
        return json.load(response)


def authorize(client):
    result, state, verifier = {}, secrets.token_urlsafe(24), secrets.token_urlsafe(64)

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            query = dict(urllib.parse.parse_qsl(urllib.parse.urlsplit(self.path).query))
            valid = query.get("state") == state
            if valid:
                result.update(query)
            self.send_response(200 if valid else 400)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write("완료했습니다. 터미널로 돌아가세요.".encode())

        def log_message(self, *args):
            pass

    server = HTTPServer(("127.0.0.1", 0), Handler)
    redirect = f"http://127.0.0.1:{server.server_port}"
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
        "client_id": client["client_id"], "redirect_uri": redirect, "response_type": "code", "scope": SCOPE,
        "access_type": "offline", "prompt": "consent select_account", "state": state,
        "code_challenge": challenge, "code_challenge_method": "S256",
    })
    print("브라우저에서 AdMob 계정(woohalabs)으로 로그인해 허용해 주세요. 열리지 않으면 아래 주소를 여세요.\n" + url)
    webbrowser.open(url)
    while "code" not in result and "error" not in result:
        server.handle_request()
    if "error" in result:
        sys.exit(f"허용되지 않았습니다: {result['error']}")
    return post("https://oauth2.googleapis.com/token", {
        "client_id": client["client_id"], "client_secret": client["client_secret"], "code": result["code"],
        "code_verifier": verifier, "grant_type": "authorization_code", "redirect_uri": redirect,
    })


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as file:
        client = json.load(file).get("installed")
    if not client:
        sys.exit("'데스크톱 앱' 유형의 OAuth 클라이언트 JSON이 아닙니다.")

    token = authorize(client)
    if "refresh_token" not in token or SCOPE not in token.get("scope", "").split():
        sys.exit("갱신 토큰 또는 AdMob 읽기 권한을 받지 못했습니다. 다시 실행해 주세요.")

    request = urllib.request.Request(
        "https://admob.googleapis.com/v1beta/accounts", headers={"Authorization": "Bearer " + token["access_token"]}
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        accounts = [a.get("publisherId") for a in json.load(response).get("account", [])]
    if PUBLISHER not in accounts:
        sys.exit(f"로그인한 계정에 {PUBLISHER}가 없습니다. 다른 계정으로 다시 실행해 주세요.")

    manifest = json.dumps({
        "apiVersion": "v1", "kind": "Secret", "type": "Opaque",
        "metadata": {"name": SECRET, "namespace": NAMESPACE},
        "stringData": {"oauth.json": json.dumps({
            "client_id": client["client_id"], "client_secret": client["client_secret"],
            "refresh_token": token["refresh_token"],
        })},
    })
    exists = kubectl("get", "secret", SECRET).returncode == 0
    # apply는 내용을 annotation에 한 번 더 남기므로 쓰지 않는다
    saved = kubectl("replace" if exists else "create", "-f", "-", data=manifest)
    if saved.returncode != 0:
        sys.exit("Secret 저장 실패: " + saved.stderr.strip())
    restarted = kubectl("rollout", "restart", "deploy/app-metrics-exporter")
    print("Secret을 저장했습니다." if restarted.returncode == 0 else "Secret은 저장했지만 재시작 실패: " + restarted.stderr)
    expires = token.get("refresh_token_expires_in")
    if expires:
        print(f"주의: 이 토큰은 {expires // 86400}일 뒤 만료됩니다. 동의 화면을 '프로덕션'으로 게시한 뒤 다시 실행하세요.")


if __name__ == "__main__":
    main()
