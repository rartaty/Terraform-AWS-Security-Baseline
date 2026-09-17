# Terraform AWS Security Baseline

Terraformを使用して、AWSアカウントの基本的なセキュリティ、
監査、構成管理、コスト監視基盤を構築するプロジェクトです。

学習用のため、最終検証後はBaselineもdestroyします。本件由来の継続課金を残さないよう、
S3の全version、backend、課金サービス、KMSの削除待機を含む残存確認までを完了条件とします。
詳細は[試験・終了条件](docs/05_test_plan.md)を参照してください。

## Status

設計・構築中（2026-09-17同期：Phase 0〜5 完了、Phase 6は実装・主要動作確認済みで実API試験範囲の判断と費用観測が残る。Phase 7は学習用VPC、Default Security Group hardening、4 Subnetを実装・実体確認済みで、Route以降を構築中）

## Roadmap

| Phase | 内容 | 状態 |
|---|---|---|
| 0 | Terraformプロジェクト基盤 | 完了 |
| 1 | AWS認証・実行Role・S3 backend | 完了 |
| 2 | コストガードレール（AWS Budgets） | 完了 |
| 3 | 共通セキュリティ基盤（KMS・S3保護） | 完了。aliasは不採用。通常RoleからKMS keyの無効化・削除予約権限を除去し、AWS適用後のNo changesを確認済み |
| 4 | 監査ログ（CloudTrail） | 完了。CloudTrail用S3のHTTPS必須化、配送継続、No changesを確認済み。CloudWatch Logs転送はADR 0005で見送り |
| 5 | セキュリティ検知（GuardDuty・Security Hub・Access Analyzer） | 完了 |
| 6 | 構成・コンプライアンス管理（AWS Config） | Recorder・配送成功、7 RuleすべてCOMPLIANT、dev planはNo changes。S3権限・MFA条件はSimulation確認済み。実API試験の未実施範囲と費用観測は試験計画参照 |
| 7 | ネットワーク検証（VPC・Flow Logs） | 学習用VPC、Default SG hardening、2 AZのPublic／Isolated Subnetは実装・AWS APIで確認済み。明示Route、専用S3、Config連携、一時EC2-A／BによるACCEPT／REJECT試験を構築予定。詳細は[ADR 0010](docs/decisions/0010-build-two-az-network-baseline-and-test-flow-logs.md) |
| 7.5 | Optional IDS/IPS Lab（AWS Network Firewall） | Phase 7完了後に別途判断。常設せず、1 AZで短期検証して同日destroyする |
| 8 | 統合試験・証跡・後片付け・文書化 | 未着手 |

Phaseごとの目的、完了条件、依存関係は `docs/02_architecture.md`、
料金見積りと課金前の確認事項は `docs/04_cost_design.md` を参照する。

残作業の分類と確認範囲は [試験・確認状況](docs/05_test_plan.md) を参照する。
実装済み、コード確認済み、利用者から結果共有済み、未検証を区別する。

## Environments

- dev

## Main components

- AWS Budgets
- AWS CloudTrail
- Amazon S3 security controls
- AWS KMS
- AWS Config
- Amazon GuardDuty
- AWS Security Hub Essentials / CSPM
- IAM Access Analyzer
- Amazon VPC（Phase 7: 学習用VPC・Default SG hardening・4 Subnet実装済み）
- VPC Flow Logs（Phase 7予定）
- AWS Network Firewall（Phase 7.5 Optional Lab。Baselineには常設しない）

## Directory structure

- `bootstrap/`: Terraform backendなどの初期基盤
- `envs/dev/`: dev環境のTerraformルートモジュール
- `modules/`: 再利用可能なTerraformモジュール
- `docs/`: 要件、設計、試験、証跡
