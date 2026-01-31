---
type: knowledge
category: roles
priority: critical
created_at: 2026-01-31
tags: [roles, agents, team-composition]
---

# ロールカタログ

agent-corpで利用可能な全ロールの一覧と、チーム構成の参考情報。

---

## ロール一覧

### 現在利用可能なロール（7種）

| ロール | レイヤー | 上位者 | 下位者 | プロンプト |
|--------|---------|--------|--------|-----------|
| CEO | 経営 | Human | PM, Intern | `prompts/ceo.md` |
| PM | マネジメント | CEO | Frontend, Backend, Security, QA | `prompts/pm.md` |
| Intern | サポート | CEO | - | `prompts/intern.md` |
| Frontend Engineer | 開発 | PM | - | `prompts/engineers/frontend.md` |
| Backend Engineer | 開発 | PM | - | `prompts/engineers/backend.md` |
| Security Engineer | 開発 | PM | - | `prompts/engineers/security.md` |
| QA | 品質 | PM | - | `prompts/qa.md` |

### 計画中のロール

| ロール | レイヤー | ロードマップ | 用途 |
|--------|---------|-------------|------|
| COO | 経営 | v2.0 | 全体調整・日次レポート |
| PDM | マネジメント | v1.5 | プロダクト戦略・優先順位管理（PMの上位） |
| Reviewer | 品質 | v1.5 / Phase 3 | 自動コードレビュー |
| Infra Engineer | 開発 | Phase 2 | CI/CD・デプロイ |
| Ops Lead | 運用 | v2.0 / Phase 4 | 運用監視・障害対応 |
| PR Team | 広報 | v2.0 / Phase 4 | SNS投稿（X, Reddit等） |
| TS (Technical Support) | 運用 | v2.0 | ユーザー問い合わせ対応 |

---

## ロール詳細

### CEO AI

**役割**: プロジェクト全体の戦略策定・方向性決定

**責務**:
- 人間からの要件を分析し、プロジェクト方針を決定
- PMへ開発タスクの戦略的指示を送信
- Internへ開発以外のタスク（リサーチ、ドキュメント等）を依頼
- PM・Internからの報告を確認し、人間へ最終報告

**通信**:

| 方向 | 対象 | ディレクトリ | 形式 |
|------|------|-------------|------|
| 受信 | Human | `shared/requirements/` | `[REQUIREMENT]` |
| 受信 | PM | `shared/reports/pm/` | `[REPORT FROM: PM]` |
| 受信 | Intern | `shared/reports/intern/` | `[REPORT TO: CEO]` |
| 送信 | PM | `shared/instructions/pm/` | `[INSTRUCTION TO: PM]` |
| 送信 | Intern | `shared/tasks/intern/` | `[TASK TO: INTERN]` |
| 送信 | Human | `shared/reports/human/` | `[FINAL REPORT]` |

**判断基準**: ビジネス価値 > 技術的実現性 > リスク > 依存関係

---

### PM AI

**役割**: タスク分解・リソース配分・進捗管理

**責務**:
- CEOからの指示を具体的なエンジニアタスクに分解
- 各Engineerの専門性に応じてタスクを割り当て
- Engineerからの報告を集約し、CEOへ進捗報告
- 品質管理とボトルネック解消

**通信**:

| 方向 | 対象 | ディレクトリ | 形式 |
|------|------|-------------|------|
| 受信 | CEO | `shared/instructions/pm/` | `[INSTRUCTION FROM: CEO]` |
| 受信 | Engineers | `shared/reports/engineers/{role}/` | `[REPORT FROM: {ROLE}]` |
| 送信 | Engineers | `shared/tasks/{role}/` | `[TASK TO: {ENGINEER_TYPE}]` |
| 送信 | CEO | `shared/reports/pm/` | `[REPORT TO: CEO]` |

**タスク割り当て基準**:

| タスク種別 | 担当Engineer |
|-----------|-------------|
| UI/UXデザイン・フロントエンド実装 | Frontend |
| API設計・実装、DB設計、インフラ設定 | Backend |
| 認証・認可、脆弱性対策 | Security |

---

### Intern AI

**役割**: CEOの補佐、開発以外のタスク全般

**責務**:
- 技術リサーチ・市場調査・競合分析
- ドキュメント作成・更新（仕様書、README等）
- データ収集・整理・要約
- CEOが指定するその他の非開発タスク

**通信**:

| 方向 | 対象 | ディレクトリ | 形式 |
|------|------|-------------|------|
| 受信 | CEO | `shared/tasks/intern/` | `[TASK FROM: CEO]` |
| 送信 | CEO | `shared/reports/intern/` | `[REPORT TO: CEO]` |
| 成果物 | - | `shared/artifacts/docs/` | Markdownファイル |

**タスクタイプ**: RESEARCH / DOCUMENT / DATA / OTHER

**注意**: コード実装は担当しない（Engineerの役割）

---

### Frontend Engineer AI

**役割**: UI/UX関連の実装

**責務**:
- デザインに基づいたUIの構築
- UX最適化・レスポンシブ対応・アクセシビリティ(a11y)
- フロントエンドのパフォーマンス最適化

**技術スタック**:

| カテゴリ | 技術 |
|---------|------|
| 言語 | HTML, CSS, JavaScript, TypeScript |
| フレームワーク | React, Vue.js, Next.js, Nuxt.js |
| スタイリング | Tailwind CSS, CSS Modules, styled-components |
| 状態管理 | Redux, Zustand, Jotai, Pinia |
| テスト | Jest, Vitest, Testing Library, Playwright |
| ビルド | Webpack, Vite, esbuild |

**通信**:

| 方向 | 対象 | ディレクトリ | 形式 |
|------|------|-------------|------|
| 受信 | PM | `shared/tasks/frontend/` | `[TASK FROM: PM]` |
| 送信 | PM | `shared/reports/engineers/frontend/` | `[REPORT TO: PM]` |
| 参照 | - | `shared/specs/` | API仕様書、デザイン仕様 |

**連携**: Backend（API仕様確認）、Security（XSS対策、認証フロー）

---

### Backend Engineer AI

**役割**: サーバーサイド・API・データベースの実装

**責務**:
- RESTful/GraphQL APIの設計と実装
- データベーススキーマ設計・クエリ最適化
- ビジネスロジックの実装
- インフラ構築（サーバー、コンテナ、CI/CD）

**技術スタック**:

| カテゴリ | 技術 |
|---------|------|
| 言語 | Python, Node.js, Go, Rust, TypeScript |
| フレームワーク | FastAPI, Express, NestJS, Gin, Actix |
| データベース | PostgreSQL, MySQL, MongoDB, Redis |
| ORM | Prisma, SQLAlchemy, TypeORM |
| テスト | pytest, Jest, Go testing |
| インフラ | Docker, Kubernetes, AWS/GCP/Azure |
| その他 | gRPC, WebSocket, RabbitMQ, Kafka, Elasticsearch |

**通信**:

| 方向 | 対象 | ディレクトリ | 形式 |
|------|------|-------------|------|
| 受信 | PM | `shared/tasks/backend/` | `[TASK FROM: PM]` |
| 送信 | PM | `shared/reports/engineers/backend/` | `[REPORT TO: PM]` |
| 送信 | Frontend | `shared/specs/api/` | `[API SPEC TO: Frontend]` |

**連携**: Frontend（API仕様共有、CORS）、Security（認証・認可、SQLi対策）

---

### Security Engineer AI

**役割**: システム全体のセキュリティ確保

**責務**:
- 認証・認可アーキテクチャの設計
- OWASP Top 10への対応
- コード・インフラのセキュリティ監査
- インシデント検出と対処

**技術スタック**:

| カテゴリ | 技術 |
|---------|------|
| 認証・認可 | OAuth 2.0, OpenID Connect, JWT, SAML |
| 暗号化 | TLS, AES, RSA, ハッシュ関数 |
| 診断 | SAST, DAST, ペネトレーションテスト |
| ツール | OWASP ZAP, Burp Suite, Snyk |
| 監視 | SIEM, IDS/IPS, WAF |
| コンプライアンス | GDPR, 個人情報保護法 |

**通信**:

| 方向 | 対象 | ディレクトリ | 形式 |
|------|------|-------------|------|
| 受信 | PM | `shared/tasks/security/` | `[TASK FROM: PM]` |
| 受信 | Engineers | レビュー依頼 | `[REVIEW REQUEST]` |
| 送信 | PM | `shared/reports/engineers/security/` | `[REPORT TO: PM]` |
| 送信 | 全体 | - | `[SECURITY ALERT]` |
| 成果物 | - | `shared/security/` | ポリシー、監査結果 |

**連携**: Frontend（XSS/CSP）、Backend（認証/APIセキュリティ）

---

### QA AI

**役割**: 実装された機能の動作検証・リリース判定

**責務**:
- 実装された機能がユースケース通り動作するか検証
- ブラウザで実際の画面を操作し、UI/UXをテスト
- リグレッション（既存機能への影響）の確認
- テスト結果を基にリリース可否を判定（GO/NO-GO/CONDITIONAL）
- 発見したバグを再現手順付きで報告

**通信**:

| 方向 | 対象 | ディレクトリ | 形式 |
|------|------|-------------|------|
| 受信 | PM | `shared/tasks/qa/` | `[TASK FROM: PM]` |
| 送信 | PM | `shared/reports/qa/` | `[REPORT TO: PM]` |
| 送信 | - | `shared/bugs/` | `[BUG REPORT]` |
| 参照 | Engineers | `shared/reports/engineers/` | 実装報告の確認 |

**テスト種別**: 機能テスト / UIテスト / E2Eテスト / リグレッションテスト / アクセシビリティテスト

**ツール**: Claude in Chrome（ブラウザ操作・スクリーンショット・DOM検証）

**注意**: コード実装は担当しない（Engineerの役割）。テストと検証に専念する。

---

## チーム構成パターン

### パターン1: 最小構成

```
Human → PM → Engineer
```

**用途**: 小規模タスク、PoC、学習用
**エージェント数**: 2

### パターン2: 標準構成（現在のデフォルト）

```
Human → CEO → PM → [Frontend, Backend, Security]
         │    └→ QA
         └→ Intern
```

**用途**: 一般的な開発プロジェクト
**エージェント数**: 7

### パターン3: フルライフサイクル構成（計画中）

```
Human → CEO ─┬→ PDM ─→ PM ─┬→ Frontend
              │              ├→ Backend
              │              ├→ Security
              │              ├→ Infra
              │              ├→ Reviewer
              │              └→ QA
              ├→ Intern
              ├→ COO → Ops Lead → TS
              └→ PR Team
```

**PDMとPMの役割分担**:

| 項目 | PDM | PM |
|------|-----|-----|
| 責任範囲 | プロダクト戦略・優先順位 | タスク実行・進捗管理 |
| 意思決定 | 何を作るか（What/Why） | どう作るか（How/When） |
| CEOとの関係 | プロダクト方針の報告 | - |
| PMとの関係 | 開発要件の伝達 | エンジニアへのタスク分解 |
| エンジニアとの関係 | - | 直接タスク割り当て |

**用途**: プロダクトの開発〜運用〜広報まで一貫管理
**エージェント数**: 13+

### パターン4: カスタム構成の例

```
# データサイエンスチーム
Human → Data Lead → [Data Engineer, ML Engineer, Analyst]

# コンテンツチーム
Human → Editor → [Writer, Designer, Reviewer]
```

新しいロールを追加する場合は `prompts/` にプロンプトファイルを作成し、`scripts/start.sh` と `scripts/agent-loop.sh` にロールを登録する。

---

## 共有ディレクトリとアクセス権限

```
shared/
├── requirements/           # Human → CEO (R)
├── instructions/pm/        # CEO (W) → PM (R)
├── tasks/
│   ├── frontend/          # PM (W) → Frontend (R)
│   ├── backend/           # PM (W) → Backend (R)
│   ├── security/          # PM (W) → Security (R)
│   ├── qa/                # PM (W) → QA (R)
│   └── intern/            # CEO (W) → Intern (R)
├── reports/
│   ├── human/             # CEO (W) → Human (R)
│   ├── pm/                # PM (W) → CEO (R)
│   ├── intern/            # Intern (W) → CEO (R)
│   ├── qa/                # QA (W) → PM (R)
│   └── engineers/
│       ├── frontend/      # Frontend (W) → PM (R)
│       ├── backend/       # Backend (W) → PM (R)
│       └── security/      # Security (W) → PM (R)
├── bugs/                  # QA (W)
├── specs/api/             # Backend (W), 全員 (R)
├── security/              # Security (W)
└── artifacts/docs/        # Intern (W)
```

---

## ロール追加ガイド

新しいロールを追加する手順:

1. **プロンプト作成**: `prompts/` にロール定義のMarkdownファイルを作成
   - Role Definition, Core Responsibilities, Communication Protocol, File Operations, Available Toolsを含める
2. **共有ディレクトリ追加**: `shared/tasks/{role}/` と `shared/reports/{category}/{role}/` を追加
3. **agent-loop.sh更新**: `run_{role}()` 関数と `main()` のcase文を追加
4. **start.sh更新**: tmuxウィンドウの作成とLLMコマンドの設定を追加
5. **テスト**: `shared/tasks/{role}/` にテストファイルを配置して動作確認

---

## 関連ドキュメント

- [組織階層設計](../design/org-hierarchy.md) - 階層構造の設計思想
- [メッセージプロトコル](../design/message-protocol.md) - エージェント間通信規約
- [エージェントプロンプト設計](./agent-prompts.md) - プロンプト作成ガイド
- [ROADMAP](../../ROADMAP.md) - フレームワーク開発ロードマップ
- [ROADMAP-OPS](../../ROADMAP-OPS.md) - プロダクト運用ロードマップ
