# T-DEPLOY-003-SEC: 再デプロイ後 認証セキュリティ検証レポート

**タスクID:** T-DEPLOY-003-SEC
**実施日:** 2026-01-31
**検証対象:** persona-manager (https://persona.propel-lab-dev.com)
**技術スタック:** FastAPI + JWT認証 + SQLite + Docker Compose + Cloudflare Tunnel

---

## エグゼクティブサマリー

Dockerコンテナ内のアプリケーション（コード/ビルド済みイメージ）は**認証機能が正しく実装・動作している**ことを確認しました。JWT認証フロー、保護エンドポイント、入力バリデーション、CORS設定、コンテナセキュリティの全項目で良好な結果が得られています。

ただし、**本番環境（Cloudflare Tunnel経由）での認証エンドポイントへのアクセスに問題**が残っており、これはインフラ層（cloudflaredコンテナの設定不備）に起因します。

---

## 検証結果サマリー

| 検証項目 | 結果 | 備考 |
|----------|------|------|
| JWT トークン発行・検証 | ✅ PASS | 正常に発行・検証される |
| 無効トークンの拒否 | ✅ PASS | 401を正しく返却 |
| 期限切れトークンの拒否 | ✅ PASS | 401を正しく返却 |
| 不正秘密鍵トークンの拒否 | ✅ PASS | 401を正しく返却 |
| トークン有効期限（24h） | ✅ PASS | 適切な設定 |
| 未認証アクセスの拒否 | ✅ PASS | 全30エンドポイントで401 |
| 認証済みアクセス | ✅ PASS | 正常レスポンス |
| パスワードバリデーション | ✅ PASS | 8文字以上、72バイト以内 |
| メールバリデーション | ✅ PASS | 不正形式を拒否 |
| SQLインジェクション対策 | ✅ PASS | SQLAlchemy ORM使用 |
| CORS（許可オリジン） | ✅ PASS | 本番ドメインのみ許可 |
| CORS（不正オリジン拒否） | ✅ PASS | allow-originヘッダーなし |
| セキュリティヘッダー | ✅ PASS | 5種類のヘッダー設定 |
| 非rootユーザー実行 | ✅ PASS | appuser (uid=999) |
| JWT秘密鍵パーミッション | ✅ PASS | 0600 |
| レートリミット | ✅ PASS | 登録3/h、ログイン5/min |
| 本番URL経由の認証 | ❌ FAIL | cloudflared設定不備 |

---

## 1. 認証フローのセキュリティ確認

### 1a. JWT トークンの発行・検証 ✅

```
テスト: POST /api/auth/login (有効な認証情報)
結果: 200 OK - access_token が正常に発行される
トークン形式: HS256 JWT
ペイロード: {"sub": "<user_id>", "exp": <timestamp>}
```

- アルゴリズム: HS256（適切）
- 秘密鍵: `secrets.token_urlsafe(64)` で自動生成（86文字のランダム文字列）
- 秘密鍵の管理: 環境変数優先、ファイル保存時は0600パーミッション
- パスワードハッシュ: bcrypt（passlib経由）

### 1b. 無効なトークンでのAPIアクセス拒否 ✅

| テストケース | 期待結果 | 実際の結果 |
|-------------|---------|-----------|
| トークンなし | 401 | ✅ 401 `{"detail":"Not authenticated"}` |
| 無効なトークン文字列 | 401 | ✅ 401 `{"detail":"認証情報が無効です"}` |
| 期限切れトークン | 401 | ✅ 401 `{"detail":"認証情報が無効です"}` |
| 不正な秘密鍵で署名されたトークン | 401 | ✅ 401 `{"detail":"認証情報が無効です"}` |
| 間違ったパスワード | 401 | ✅ 401 `{"detail":"メールアドレスまたはパスワードが正しくありません"}` |
| 存在しないユーザー | 401 | ✅ 401（同一メッセージ） |

### 1c. トークンの有効期限 ✅

- 設定値: `ACCESS_TOKEN_EXPIRE_HOURS = 24`（24時間）
- 実測値: トークンのexp claimを検証し、約24時間後に設定されていることを確認

---

## 2. 保護エンドポイントの確認

### 2a. 未認証状態での保護APIアクセス ✅

全30エンドポイントが `get_current_user` 依存関係で保護されており、未認証アクセスで401を返すことを確認。

```
GET  /api/persona              → 401 ✅
GET  /api/persona/{username}   → 401 ✅
GET  /api/chat/conversations   → 401 ✅
GET  /api/answers/{user}/progress → 401 ✅
GET  /api/questions            → 401 ✅
GET  /api/settings/api-key/status → 401 ✅
GET  /api/users/me             → 401 ✅
POST /api/chat/conversations   → 401 ✅
DELETE /api/answers/{user}     → 401 ✅
```

### 2b. 認証済み状態でのアクセス ✅

```
GET /api/persona       → 200 (ユーザーのペルソナ一覧)
GET /api/questions     → 200 (質問一覧)
GET /api/users/me      → 200 (ユーザー情報)
```

### 2c. 所有権検証 ✅

- パスパラメータの `{username}` がログインユーザーと一致しない場合、403 Access Deniedを返却
- SQLi文字列を含むusernameでも適切に403を返却

---

## 3. 入力バリデーション

### 3a. 不正な入力の拒否 ✅

| テストケース | 結果 |
|-------------|------|
| 不正なメールアドレス形式 | 422 (バリデーションエラー) |
| 短いパスワード (< 8文字) | 422 |
| 空の表示名 | 422 |
| 必須フィールド欠落 | 422 |

### 3b. SQLインジェクション対策 ✅

SQLAlchemy ORMを使用しており、全データベースクエリがパラメータ化されている。テスト結果:

```
SQLi in email: "admin@test.com' OR 1=1--" → 401 (通常のログイン失敗)
SQLi in password: "x' OR 1=1--" → 401 (通常のログイン失敗)
SQLi in path param: "test' OR 1=1--" → 403 (アクセス拒否)
SQLi in UNION SELECT: "test' UNION SELECT * FROM users--" → 403 (アクセス拒否)
```

### 3c. Stored XSS ⚠️ 注意

`display_name`フィールドに`<script>alert(1)</script>`が保存・返却される。
APIはJSONレスポンスのため直接のXSSリスクは低いが、フロントエンドでのエスケープ処理が必要。

---

## 4. CORS設定の確認 ✅

### ALLOWED_ORIGINS 環境変数

```
ALLOWED_ORIGINS=https://persona.propel-lab-dev.com
```

### テスト結果

| シナリオ | 結果 |
|---------|------|
| 許可オリジンからのプリフライト | ✅ 200, CORS ヘッダー正常 |
| 不正オリジンからのプリフライト | ✅ 400, allow-originヘッダーなし |
| 許可オリジンからのリクエスト | ✅ allow-origin: https://persona.propel-lab-dev.com |
| 不正オリジンからのリクエスト | ✅ allow-originヘッダーなし |

### CORSミドルウェア設定

```python
allow_origins=["https://persona.propel-lab-dev.com"]
allow_credentials=True
allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"]
allow_headers=["Authorization", "Content-Type"]
```

---

## 5. コンテナセキュリティ ✅

```bash
$ docker compose exec persona-manager whoami
appuser  ✅

$ docker compose exec persona-manager id
uid=999(appuser) gid=999(appuser) groups=999(appuser)  ✅
```

### Dockerfile セキュリティプラクティス

| 項目 | 状態 |
|------|------|
| マルチステージビルド | ✅ |
| 非rootユーザー実行 | ✅ (appuser) |
| テスト・開発ファイル除外 | ✅ |
| ヘルスチェック設定 | ✅ |
| 最小限のシステムパッケージ | ✅ (curl のみ) |
| pip --no-cache-dir | ✅ |

### JWT秘密鍵保護

```
-rw------- 1 appuser appuser 86 /app/data/.jwt_secret_key  ✅ (0600)
```

---

## 6. セキュリティヘッダー ✅

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

---

## 7. 本番環境（Cloudflare Tunnel）の問題 ❌

### 問題の概要

本番URL (`https://persona.propel-lab-dev.com`) 経由で認証エンドポイントにPOSTリクエストを送ると、`405 Method Not Allowed` が返却される。

### 根本原因

1. **cloudflaredコンテナの設定ファイルエラー**: `open /etc/cloudflared/config.yml: permission denied` でcloudflaredが起動失敗
2. **~/.cloudflared/config.yml の内容が別ドメイン**: 現在の設定は `imoto.rura-dev.tokyo` を指しており、`persona.propel-lab-dev.com` の設定が含まれていない
3. **ホスト上の別プロセス**: ポート8000でDockerコンテナではなくローカルの `python main.py` プロセスが動作しており（古い/別のDB参照）、本番トラフィックがこのプロセスに転送されている可能性

### 影響

- 本番環境での認証フロー（登録・ログイン）が機能しない
- 本番環境で `/api/persona` 等のGETエンドポイントは認証なしでアクセス可能（ローカルの開発サーバーが応答）

### 推奨対応

```
[SECURITY ALERT]
Severity: HIGH
Type: 本番環境の認証機能未稼働
Affected: https://persona.propel-lab-dev.com 全APIエンドポイント
Description: cloudflared設定不備により、本番トラフィックがDocker内の認証付きアプリではなく、
             ホスト上の開発サーバー（認証なし）に転送されている
Immediate Action:
  1. ホスト上の python main.py プロセス (PID 3093) を停止
  2. ~/.cloudflared/config.yml に persona.propel-lab-dev.com の設定を追加
  3. cloudflaredの認証情報ファイルのパーミッションを修正 (chmod 644)
  4. docker compose down && docker compose up -d --build で再起動
Long-term Fix:
  1. systemdサービスでDockerコンテナの自動起動を確実にする
  2. cloudflared設定のバージョン管理
  3. 起動スクリプトで既存のポート占有プロセスをチェック
[/SECURITY ALERT]
```

---

## 8. コードレビュー: 発見事項

### MEDIUM

| # | 事項 | 説明 |
|---|------|------|
| M1 | 共有グローバルAPIキー | 全認証ユーザーがAPIキーを読み取り/変更/削除可能。RBAC実装を推奨 |
| M2 | メールアドレス列挙 | 登録時に「既に登録済み」のエラーメッセージで存在確認可能 |
| M3 | エラーメッセージの情報漏洩 | チャット機能で例外の詳細がクライアントに返される |

### LOW

| # | 事項 | 説明 |
|---|------|------|
| L1 | パスワード複雑性要件不足 | 長さ制限のみ、大文字/小文字/数字/記号の要件なし |
| L2 | パスワード変更のレートリミット未設定 | ブルートフォース攻撃に対する追加保護が必要 |
| L3 | Stored XSS の可能性 | display_nameにHTMLタグが保存される（フロントエンドでの対策が必要） |

### セキュリティ強み

- ✅ bcryptによるパスワードハッシュ
- ✅ Fernet暗号化によるAPIキー保護
- ✅ SQLAlchemy ORM（SQLi対策）
- ✅ Pydantic入力バリデーション
- ✅ レートリミット（登録3/h、ログイン5/min）
- ✅ 包括的なセキュリティヘッダー
- ✅ Cloudflare IPアドレス検出対応
- ✅ 所有権検証（アクセス制御）
- ✅ ハードコードされたシークレットなし

---

## 結論

**アプリケーションコード（Dockerイメージ）のセキュリティは良好**です。認証・認可の実装は適切で、OWASP Top 10の主要な脆弱性に対して防御されています。

**最大の課題はインフラ層**であり、cloudflaredの設定不備とホスト上のローカル開発サーバーの存在により、本番環境では認証が機能していません。この問題はBackend Engineerと協力して早急に解決する必要があります。

---

## Acceptance Criteria 確認

| 基準 | 状態 | 備考 |
|------|------|------|
| 認証フローが安全に動作すること | ✅ PASS (コンテナ内) / ❌ FAIL (本番URL) | インフラ問題 |
| 未認証アクセスが適切に拒否されること | ✅ PASS (コンテナ内) | 全30エンドポイントで401 |
| セキュリティ検証レポートの作成 | ✅ PASS | 本レポート |

---

[REPORT TO: PM]
Task: T-DEPLOY-003-SEC
Status: COMPLETED (with caveats)
Details: |
  Dockerコンテナ内のアプリケーションに対してセキュリティ検証を実施。
  JWT認証、アクセス制御、入力バリデーション、CORS、コンテナセキュリティの全項目でPASS。
  ただし、本番URL経由でのアクセスはcloudflared設定不備により認証エンドポイントが機能していない。
Findings: |
  - CRITICAL: 本番環境でcloudflaredが起動失敗（config.yml permission denied）
  - CRITICAL: ホスト上の開発サーバーが本番トラフィックを受けている可能性
  - MEDIUM: 共有グローバルAPIキーのアクセス制御不足
  - MEDIUM: メールアドレス列挙の可能性
  - LOW: パスワード複雑性要件不足
Risk Level: HIGH (インフラ問題のため)
Recommendations: |
  1. [即時] ホスト上の開発サーバープロセスを停止
  2. [即時] cloudflared config.yml の修正とパーミッション設定
  3. [短期] RBACの実装（APIキー管理のアクセス制御）
  4. [短期] パスワード複雑性要件の強化
  5. [中期] Refresh Token パターンの導入
[/REPORT]
