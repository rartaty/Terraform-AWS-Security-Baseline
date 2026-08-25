# Terraform AWS Security Baseline

Terraformを使用して、AWSアカウントの基本的なセキュリティ、
監査、構成管理、コスト監視基盤を構築するプロジェクトです。

## Status

設計・構築中（Phase 1 完了、次は Phase 2）

## Roadmap

| Phase | 内容 | 状態 |
|---|---|---|
| 0 | Terraformプロジェクト基盤 | 完了 |
| 1 | AWS認証・実行Role・S3 backend | 完了 |
| 2 | コストガードレール（AWS Budgets） | 次に実施 |
| 3 | 共通セキュリティ基盤（KMS・S3保護） | 未着手 |
| 4 | 監査ログ（CloudTrail） | 未着手 |
| 5 | セキュリティ検知（GuardDuty・Security Hub・Access Analyzer） | 未着手 |
| 6 | 構成・コンプライアンス管理（AWS Config） | 未着手 |
| 7 | ネットワーク検証（VPC・Flow Logs） | 未着手 |
| 8 | 統合試験・証跡・後片付け・文書化 | 未着手 |

Phaseごとの目的、完了条件、依存関係は `docs/02_architecture.md`、
料金見積りと課金前の確認事項は `docs/04_cost_design.md` を参照する。

## Environments

- dev

## Main components

- AWS Budgets
- AWS CloudTrail
- Amazon S3 security controls
- AWS KMS
- AWS Config
- Amazon GuardDuty
- AWS Security Hub CSPM
- IAM Access Analyzer
- Amazon VPC
- VPC Flow Logs

## Directory structure

- `bootstrap/`: Terraform backendなどの初期基盤
- `envs/dev/`: dev環境のTerraformルートモジュール
- `modules/`: 再利用可能なTerraformモジュール
- `docs/`: 要件、設計、試験、証跡
