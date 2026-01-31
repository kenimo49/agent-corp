[TASK TO: SECURITY]
Task ID: T-DEPLOY-003-P3
Priority: HIGH
Description: |
  Phase 2（フロントエンド検証）完了後、本番環境の認証・セキュリティ検証を実施する。

  ## 背景
  認証機能が新たに追加されたため、セキュリティ面での検証が必要。
  元々認証なしの環境だったため緊急度は最高ではないが、可能な限り早く完了させる。

  ## 対象
  - 本番URL: https://persona.propel-lab-dev.com
  - 技術スタック: FastAPI + JWT認証 + React SPA

  ## 検証項目

  ### 1. 認証バイパス検証
  - APIエンドポイントに認証トークンなしでアクセスし、401が返ることを確認
    - `GET /api/personas` → 401
    - `GET /api/personas/{id}` → 401
    - `POST /api/chat` → 401
    - その他保護されるべきエンドポイント
  - 無効なJWTトークンでのアクセスが拒否されること
  - 期限切れトークンでのアクセスが拒否されること
  - `/health` エンドポイントは認証不要で200を返すこと（ヘルスチェック用）

  ### 2. セッション管理検証
  - JWTトークンの有効期限が適切に設定されていること
  - ログアウト後にトークンが無効化されること（またはクライアント側で削除されること）
  - トークンの保存場所を確認（localStorage / httpOnly cookie 等）
  - リフレッシュトークンの仕組みがある場合、その安全性を確認

  ### 3. CSRF対策確認
  - SPAアーキテクチャにおけるCSRF対策の有無を確認
  - CORSの設定を確認（`ALLOWED_ORIGINS` が適切に制限されているか）
    - docker-compose.ymlでは `ALLOWED_ORIGINS=${ALLOWED_ORIGINS:-https://persona.propel-lab-dev.com}` が設定されている

  ### 4. 認証エンドポイントのセキュリティ
  - `/api/auth/register`: レート制限があるか（無限登録の防止）
  - `/api/auth/login`: ブルートフォース対策があるか
  - パスワードのハッシュ化方式を確認（bcrypt等の安全なアルゴリズムか）
  - パスワードポリシー（最小文字数等）の有無

  ### 5. JWT設定の確認
  - `JWT_SECRET_KEY` が十分に強固な値で設定されているか（デフォルト値の危険性）
  - JWTアルゴリズム（HS256等）の安全性
  - トークンの署名検証が正しく行われているか

  ### 6. HTTPSとセキュリティヘッダー
  - Cloudflare Tunnel経由でHTTPS通信が強制されていること
  - セキュリティ関連レスポンスヘッダーの確認
    - X-Content-Type-Options
    - X-Frame-Options
    - Strict-Transport-Security（HSTS）

Acceptance Criteria:
  1. 認証バイパスが不可能であること（保護対象APIが全て401を返す）
  2. セッション管理が安全であること
  3. CORS設定が適切に制限されていること
  4. 認証エンドポイントに基本的なセキュリティ対策があること
  5. JWT設定に重大な脆弱性がないこと
  6. 発見された問題は重大度（Critical/High/Medium/Low）と共にリスト化すること

Dependencies: T-DEPLOY-003-P2（Frontend Engineerの検証完了後に着手）
Deadline Hint: Phase 2完了後、速やかに実施

## 報告先
完了後、以下に報告を作成してください：
`shared/reports/engineers/security/T-DEPLOY-003-P3-report.md`

[/TASK]
