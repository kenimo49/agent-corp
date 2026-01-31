# T-DEPLOY-003-P3: Phase 3 セキュリティ検証報告書

**検証日時:** 2026-01-31 17:15 JST
**検証者:** Security Engineer AI
**対象:** https://persona.propel-lab-dev.com
**ステータス:** ⛔ FAILED - 重大な脆弱性を検出

---

## エグゼクティブサマリー

**本番環境に認証機能がデプロイされていません。** リポジトリ上のコード（developブランチ）には JWT認証、レート制限、セキュリティヘッダー等が実装されていますが、本番環境で稼働しているバージョンにはこれらの機能が含まれていません。結果として、全てのAPIエンドポイントが認証なしで公開されており、任意のユーザーデータにアクセス可能な状態です。

---

## 発見事項一覧

| # | 重大度 | 項目 | 状態 |
|---|--------|------|------|
| 1 | **CRITICAL** | 認証機能が本番未デプロイ | ⛔ |
| 2 | **CRITICAL** | 全APIエンドポイントが認証なしでアクセス可能 | ⛔ |
| 3 | **CRITICAL** | 他ユーザーのペルソナ・チャット・回答データに自由アクセス可能 | ⛔ |
| 4 | **HIGH** | 認証エンドポイント（/api/auth/*）が本番に存在しない | ⛔ |
| 5 | **HIGH** | セキュリティヘッダーが本番で返されていない | ⛔ |
| 6 | **MEDIUM** | OpenAPIドキュメント（/docs, /openapi.json）が公開されている | ⚠️ |
| 7 | **LOW** | ログアウト時のサーバー側トークン無効化なし（コードレビュー） | ℹ️ |
| 8 | **LOW** | APIキーがグローバル共有設計（コードレビュー） | ℹ️ |

---

## 詳細検証結果

### 1. 認証バイパス検証 — ⛔ CRITICAL

#### 認証なしアクセス結果

| エンドポイント | 期待値 | 実測値 | 判定 |
|---------------|--------|--------|------|
| `GET /api/persona` | 401 | **200** (全ペルソナ一覧がJSONで返る) | ⛔ FAIL |
| `GET /api/persona/{username}` | 401 | **200** (個別ペルソナの詳細データ返る) | ⛔ FAIL |
| `GET /api/chat/{username}/conversations` | 401 | **200** (チャット会話一覧が返る) | ⛔ FAIL |
| `GET /api/answers/{username}/progress` | 401 | **200** (回答データが返る) | ⛔ FAIL |
| `GET /api/settings/api-key/status` | 401 | **200** (SPA HTML返却) | ⛔ FAIL |
| `GET /health` | 200 | **200** | ✅ PASS |

#### 無効なJWTトークンでのアクセス

| エンドポイント | 期待値 | 実測値 | 判定 |
|---------------|--------|--------|------|
| `GET /api/persona` (fake JWT) | 401 | **200** | ⛔ FAIL |
| `GET /api/chat/{user}/conversations` (fake JWT) | 401 | **200** | ⛔ FAIL |

#### 期限切れトークンでのアクセス

| エンドポイント | 期待値 | 実測値 | 判定 |
|---------------|--------|--------|------|
| `GET /api/persona` (expired JWT) | 401 | **200** | ⛔ FAIL |

**検証で露出が確認されたデータ:**
- ペルソナ一覧（3件: GO, test, test_user）
- ユーザー「GO」のペルソナ詳細（名前、年齢、職業、経歴等）
- ユーザー「GO」のチャット会話一覧と内容
- ユーザー「GO」の質問票回答データ（25問分）

### 2. セッション管理検証 — ⛔ 検証不可

認証機能（/api/auth/*）が本番に存在しないため、セッション管理の検証は不可能でした。

| 検証項目 | 結果 |
|----------|------|
| `/api/auth/login` | **405 Method Not Allowed**（エンドポイント未登録） |
| `/api/auth/register` | **405 Method Not Allowed**（エンドポイント未登録） |
| JWTトークン有効期限 | 検証不可（トークン発行不可） |
| ログアウト後のトークン無効化 | 検証不可 |

**コードレビュー結果（developブランチ）:**
- JWT有効期限: 24時間（`ACCESS_TOKEN_EXPIRE_HOURS = 24`）— 適切
- トークンブラックリスト: 未実装 — ログアウト時はクライアント側削除のみ
- リフレッシュトークン: 未実装

### 3. CSRF対策・CORS設定確認 — ⚠️ 部分的

#### CORS設定

| テスト | 結果 | 判定 |
|--------|------|------|
| 正規Origin (`https://persona.propel-lab-dev.com`) | Access-Control-Allow-Origin: 正規ドメイン | ✅ PASS |
| 不正Origin (`https://evil.example.com`) | Access-Control-Allow-Originヘッダーなし | ✅ PASS |
| allow_credentials | true | ✅ 適切 |

**docker-compose.ymlでの設定:**
```
ALLOWED_ORIGINS=${ALLOWED_ORIGINS:-https://persona.propel-lab-dev.com}
```
→ 本番ドメインのみ許可。CORS設定自体は適切。

#### CSRF対策
- SPA + JWTアーキテクチャのため、Authorizationヘッダーベースの認証であればCSRFリスクは低い
- **ただし、現在認証が無効なため、CSRF以前の問題**

### 4. 認証エンドポイントのセキュリティ — ⛔ 検証不可（未デプロイ）

**コードレビュー結果（developブランチ）:**

| 項目 | 実装状況 | 評価 |
|------|----------|------|
| `/api/auth/register` レート制限 | `3/hour` | ✅ 良好 |
| `/api/auth/login` ブルートフォース対策 | `5/minute` | ✅ 良好 |
| パスワードハッシュ化 | bcrypt（passlib） | ✅ 業界標準 |
| パスワードポリシー | 8〜72バイト | ✅ 適切 |
| Cloudflare IP取得 | CF-Connecting-IP対応 | ✅ 良好 |

### 5. JWT設定の確認 — コードレビューのみ

| 項目 | 実装 | 評価 |
|------|------|------|
| 秘密鍵の生成 | `secrets.token_urlsafe(64)` | ✅ 十分なエントロピー |
| 秘密鍵の管理 | 環境変数 > ファイル > 自動生成 | ⚠️ ファイル保存がフォールバック |
| アルゴリズム | HS256 (HMAC-SHA256) | ✅ 適切 |
| トークン有効期限 | 24時間 | ✅ 適切 |
| ファイルパーミッション | `0o600` | ✅ 良好 |
| デフォルト値の危険性 | なし（自動生成） | ✅ 安全 |

### 6. HTTPS・セキュリティヘッダー — ⛔ FAIL

#### HTTPS
- Cloudflare Tunnel経由でHTTPS通信 — ✅ 強制されている

#### セキュリティヘッダー

| ヘッダー | 期待値 | 実測値 | 判定 |
|----------|--------|--------|------|
| `X-Content-Type-Options` | `nosniff` | **欠落** | ⛔ FAIL |
| `X-Frame-Options` | `DENY` | **欠落** | ⛔ FAIL |
| `X-XSS-Protection` | `1; mode=block` | **欠落** | ⛔ FAIL |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | **欠落** | ⛔ FAIL |
| `Permissions-Policy` | 設定あり | **欠落** | ⛔ FAIL |
| `Strict-Transport-Security` | Cloudflare付与 | **欠落** | ⛔ FAIL |

**原因:** SecurityHeadersMiddleware が本番デプロイバージョンに含まれていない。

---

## 根本原因分析

本番環境（Docker上で稼働中のバージョン）と、リポジトリのdevelopブランチのコードに **大きな乖離** があります。

### 本番環境のOpenAPI spec分析

本番で確認されたエンドポイント（認証機能なし）:
```
POST   /api/answers/{username}
DELETE /api/answers/{username}
POST   /api/answers/{username}/bulk
GET    /api/answers/{username}/progress
GET    /api/chat/{username}/conversations
POST   /api/chat/{username}/conversations
...
GET    /api/persona
GET    /api/persona/{username}
POST   /api/persona/{username}/generate
GET    /api/questions
...
GET    /api/settings/api-key/status
...
GET    /health
GET    /{full_path}    ← SPA catch-all
```

**欠落しているエンドポイント（develop上には存在）:**
- `POST /api/auth/register`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `GET /api/users/me`

**結論:** 認証機能を含むデプロイが本番環境に反映されていない、もしくはデプロイが不完全です。

---

## コードレベルのセキュリティ評価（developブランチ）

認証機能が正しくデプロイされた場合の評価:

| カテゴリ | 評価 | 詳細 |
|----------|------|------|
| パスワード管理 | ✅ 良好 | bcrypt、8-72バイト制限 |
| JWT実装 | ✅ 良好 | HS256、24h期限、安全な鍵生成 |
| レート制限 | ✅ 良好 | 登録3/h、ログイン5/min |
| アクセス制御 | ✅ 良好 | ユーザー隔離あり |
| APIキー暗号化 | ✅ 良好 | Fernet対称鍵暗号 |
| セキュリティヘッダー | ✅ 良好 | 主要ヘッダー全て実装 |
| CORS設定 | ✅ 良好 | 環境変数で制御 |
| トークン失効 | ⚠️ 要改善 | ブラックリスト未実装 |
| APIキー共有 | ⚠️ 要改善 | グローバル共有設計 |
| シークレット管理 | ⚠️ 要改善 | ファイルベース |

---

## 推奨対策

### 即時対応（CRITICAL）

1. **認証機能を含むバージョンを本番にデプロイする**
   - developブランチの最新コードをmainにマージしてデプロイ
   - デプロイ後に再度セキュリティ検証を実施

2. **OpenAPIドキュメントの公開を制限する**
   - `/docs` と `/openapi.json` を本番環境で無効化、または認証付きにする

### 短期対応（HIGH）

3. **デプロイ後のセキュリティ検証を再実施**
   - 本レポートの全検証項目を再テスト

4. **GitHub Actions のデプロイパイプラインを確認**
   - 正しいブランチ・バージョンがデプロイされるか検証

### 中長期対応（MEDIUM/LOW）

5. **トークンブラックリストの実装**（ログアウト後のトークン無効化）
6. **リフレッシュトークンパターンの導入**
7. **APIキーのユーザーごと管理への変更**
8. **シークレット管理の外部化**（環境変数 or Secrets Manager）

---

## 受入基準の充足状況

| # | 基準 | 状態 | 備考 |
|---|------|------|------|
| 1 | 認証バイパスが不可能であること | ⛔ **FAIL** | 認証が未デプロイ |
| 2 | セッション管理が安全であること | ⛔ **検証不可** | 認証が未デプロイ |
| 3 | CORS設定が適切に制限されていること | ✅ PASS | 本番ドメインのみ許可 |
| 4 | 認証エンドポイントに基本的セキュリティ対策があること | ⛔ **検証不可** | 認証が未デプロイ |
| 5 | JWT設定に重大な脆弱性がないこと | ✅ PASS（コードレビュー） | 実装は適切 |
| 6 | 発見された問題は重大度と共にリスト化すること | ✅ 完了 | 上表参照 |

---

## 結論

**本番環境のセキュリティ検証はFAILEDです。**

最も重大な問題は、認証機能が本番環境にデプロイされていないことです。リポジトリのコード（developブランチ）には適切なセキュリティ実装がありますが、本番環境には反映されていません。

**最優先アクション:** 認証機能を含む最新コードを本番環境にデプロイし、デプロイ後に本レポートの検証を再実施してください。
