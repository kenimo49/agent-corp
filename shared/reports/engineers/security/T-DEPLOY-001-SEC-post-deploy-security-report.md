# T-DEPLOY-001-SEC: 本番デプロイ後セキュリティ確認レポート

**実施日時:** 2026-01-31 16:50 JST
**対象URL:** https://persona.propel-lab-dev.com
**実施者:** Security Engineer AI
**タスクID:** T-DEPLOY-001-SEC

---

## エグゼクティブサマリー

| カテゴリ | 結果 | 重要度 |
|----------|------|--------|
| HTTPS/TLS | ✅ PASS | - |
| HTTP→HTTPS リダイレクト | ❌ FAIL | HIGH |
| セキュリティヘッダー | ❌ FAIL | HIGH |
| HSTS | ❌ FAIL | HIGH |
| 認証機能(auth/users) | ❌ FAIL | **CRITICAL** |
| CORS設定 | ❌ FAIL | **CRITICAL** |
| 既知Issue | ⚠️ 未解決 | MEDIUM |

**総合判定: ❌ FAIL** — CRITICALおよびHIGH Issue が複数未解決

---

## Phase 1: HTTPS/通信セキュリティ確認

### 1.1 HTTPS接続 ✅ PASS

```
SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384 / X25519 / id-ecPublicKey
Server certificate:
  subject: CN=propel-lab-dev.com
  start date: Jan 29 08:50:05 2026 GMT
  expire date: Apr 29 09:45:37 2026 GMT
  issuer: C=US; O=Google Trust Services; CN=WE1
  SSL certificate verify ok.
```

- TLS 1.3 で接続確立
- 証明書はワイルドカード(`*.propel-lab-dev.com`)で有効
- Google Trust Services (Let's Encrypt相当) による発行
- HTTP/2 対応

### 1.2 HTTP→HTTPS リダイレクト ❌ FAIL (HIGH)

```
$ curl -sv http://persona.propel-lab-dev.com/api/health
< HTTP/1.1 200 OK
```

- **HTTPリクエストがリダイレクトされずにそのまま200を返す**
- Cloudflare側で「Always Use HTTPS」が有効化されていない
- 中間者攻撃（MitM）のリスクあり

**推奨対策:** Cloudflareダッシュボードで SSL/TLS → Edge Certificates → Always Use HTTPS を有効化

### 1.3 セキュリティヘッダー ❌ FAIL (HIGH)

**アプリケーション実装:** SecurityHeadersMiddleware で以下を設定済み
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block
- Referrer-Policy: strict-origin-when-cross-origin
- Permissions-Policy: camera=(), microphone=(), geolocation=()

**本番環境レスポンス（実測値）:**

```
HTTP/2 200
content-type: application/json
server: cloudflare
cf-cache-status: DYNAMIC
```

- **セキュリティヘッダーが全て欠落** — Cloudflare CDN層で除去されている
- アプリケーションレベルでは正しく実装されているが、CDN通過後に消失

**推奨対策:** Cloudflare Transform Rules で以下のレスポンスヘッダーを追加:
1. `X-Content-Type-Options: nosniff`
2. `X-Frame-Options: DENY`
3. `X-XSS-Protection: 1; mode=block`
4. `Referrer-Policy: strict-origin-when-cross-origin`
5. `Permissions-Policy: camera=(), microphone=(), geolocation=()`

### 1.4 HSTS (Strict-Transport-Security) ❌ FAIL (HIGH)

- HSTSヘッダー未設定
- アプリケーションコードにコメント: `# HSTSはCloudflare Tunnelが付与するため、ここでは設定しない`
- しかし実際にはCloudflare側でも付与されていない

**推奨対策:** Cloudflare SSL/TLS → Edge Certificates → HSTS を有効化、または Transform Rulesで `Strict-Transport-Security: max-age=31536000; includeSubDomains` を追加

---

## Phase 2: 認証セキュリティ確認

### 2.1 認証機能の存在確認 ❌ FAIL (**CRITICAL**)

OpenAPIスキーマ (`/openapi.json`) を取得し、登録されているエンドポイントを確認した結果:

**登録されているルーター:**
- `/api/questions` ✅
- `/api/answers` ✅
- `/api/persona` ✅
- `/api/settings` ✅
- `/api/chat` ✅
- `/health` ✅

**登録されていないルーター:**
- `/api/auth/*` ❌ **未登録**
- `/api/users/*` ❌ **未登録**

**検証結果:**

```
$ curl -X POST https://persona.propel-lab-dev.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@test.com","password":"test"}'

HTTP/2 405
{"detail":"Method Not Allowed"}
allow: GET
```

- POST `/api/auth/login` → 405 (SPAフォールバックの `/{full_path:path}` GETルートにマッチ)
- POST `/api/auth/register` → 405 (同上)

**結論:** 認証機能（auth, users ルーター）が本番環境にデプロイされていない。
開発環境のコードにはルーター登録が存在するが、本番のDockerイメージが古いか、デプロイが未完了。

**即時対応:** 認証機能を含む最新コードを本番環境に再デプロイする必要がある

### 2.2 JWT検証 ⏸️ テスト不能

認証機能が未デプロイのため、以下のテストは実施不能:
- 期限切れトークンの拒否
- 改ざんトークンの拒否
- 適切な401レスポンス

### 2.3 CORS設定 ❌ FAIL (**CRITICAL**)

**テスト1: 悪意あるオリジンでのプリフライトリクエスト**

```
$ curl -H "Origin: https://evil.example.com" -X OPTIONS \
  -H "Access-Control-Request-Method: GET" \
  https://persona.propel-lab-dev.com/api/health

access-control-allow-credentials: true
access-control-allow-methods: DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT
access-control-allow-origin: https://evil.example.com
```

- **悪意あるオリジンが許可されている** — CSRF攻撃のリスク
- `allow_credentials: true` と組み合わさり、認証付きリクエストも悪意あるサイトから送信可能

**テスト2: GETリクエストでのCORS**

```
$ curl -H "Origin: https://evil.example.com" \
  https://persona.propel-lab-dev.com/api/questions

access-control-allow-credentials: true
access-control-allow-origin: *
```

- `access-control-allow-origin: *` が返される（ワイルドカード）
- Cloudflare CDN が CORS ヘッダーを上書きしている

**根本原因分析:**

1. **プリフライトリクエスト（OPTIONS）:** アプリケーションのCORSMiddlewareが応答 → `evil.example.com` を許可
   - これはFastAPIのCORSMiddlewareがオリジンリストに含まれないオリジンでも `allow_credentials=True` の場合にリクエストオリジンをエコーバックする仕様
   - ❌ アプリケーション側のCORS設定に問題がある可能性（`ALLOWED_ORIGINS`環境変数が正しく設定されていない）
2. **通常リクエスト（GET）:** Cloudflare CDN が `access-control-allow-origin: *` を付与
   - ❌ Cloudflare側でCORSヘッダーが上書きされている

**推奨対策:**
1. Docker環境で `ALLOWED_ORIGINS=https://persona.propel-lab-dev.com` が正しく設定されているか確認
2. Cloudflare側のCORS設定（Page Rules, Transform Rules）を確認・修正
3. Cloudflare側でアプリケーションのCORSヘッダーを上書きしないよう設定

---

## Phase 3: 既知Issue確認

### 3.1 T-INT-003/T-SEC-FINAL で報告されたIssue

| Issue | 重要度 | T-DEPLOY-003時点 | 現在の状態 |
|-------|--------|-----------------|-----------|
| JWT_SECRET_KEY_PATH パス問題 | MEDIUM | ⚠️ 未解決 | ⚠️ **未確認**（auth未デプロイのため確認不能） |
| Cloudflare CORS `*` 上書き | CRITICAL | ❌ 未解決 | ❌ **未解決** — `access-control-allow-origin: *` が依然として返される |
| セキュリティヘッダー欠落 | HIGH | ❌ 未解決 | ❌ **未解決** — ヘッダーが返されていない |
| HSTS未設定 | HIGH | ❌ 未解決 | ❌ **未解決** |
| HTTP→HTTPSリダイレクト | HIGH | - | ❌ **新規発見** — リダイレクトされない |

### 3.2 新規発見Issue

| Issue | 重要度 | 説明 |
|-------|--------|------|
| 認証機能未デプロイ | **CRITICAL** | auth/users ルーターが本番環境に登録されていない。OpenAPI定義にも含まれない |
| 全エンドポイント未認証 | **CRITICAL** | 認証機能が未デプロイのため、全APIエンドポイントが認証なしでアクセス可能 |

---

## リスク評価サマリー

### CRITICAL (即時対応必要)

1. **認証機能未デプロイ** — 全APIが認証なしでアクセス可能。ペルソナデータ、チャット履歴、設定の閲覧・変更が第三者から可能
2. **CORS `access-control-allow-origin: *`** — 悪意あるサイトからのクロスオリジンリクエストが許可される

### HIGH (速やかに対応)

3. **HTTP→HTTPSリダイレクトなし** — 暗号化されていない通信が可能
4. **セキュリティヘッダー欠落** — XSS, クリックジャッキング等のブラウザレベル防御が機能しない
5. **HSTS未設定** — HTTPダウングレード攻撃のリスク

### MEDIUM (計画的に対応)

6. **JWT_SECRET_KEY_PATH パス問題** — コンテナ内パスの不一致（認証デプロイ後に再確認必要）

---

## 推奨アクション

### 即時対応（Backendエンジニア向け）

1. **認証機能を含む最新コードを本番に再デプロイ**
   - `main.py` で `auth.router` と `users.router` が正しく登録されていることを確認
   - Docker イメージを最新のdevelop/mainから再ビルド
   - デプロイ後、`/openapi.json` に `/api/auth/*` が含まれることを確認

### 即時対応（インフラ/Cloudflare設定）

2. **Cloudflare SSL設定**
   - Always Use HTTPS: 有効化
   - HSTS: 有効化 (max-age=31536000)

3. **Cloudflare Transform Rules**
   - セキュリティヘッダーの追加
   - CORS上書きの無効化（アプリケーション側のCORSヘッダーを保持）

### 再検証

4. 上記対応完了後、本レポートのテスト項目を再実施すること

---

## テスト環境情報

```
Test Client: curl/8.5.0 (WSL2 Ubuntu)
TLS: TLSv1.3 / TLS_AES_256_GCM_SHA384
Target: persona.propel-lab-dev.com (Cloudflare CDN → Cloudflare Tunnel → Docker)
Certificate: *.propel-lab-dev.com (Google Trust Services / WE1)
```
