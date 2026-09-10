# Terraform AWS Security Baseline

Terraformを使用して、AWSアカウントの基本的なセキュリティ、
監査、構成管理、コスト監視基盤を構築するプロジェクトです。

## Status

設計・構築中（Phase 0〜3・5 完了、Phase 4 は一部実装済み、Phase 6 は技術検証済み）

## Roadmap

| Phase | 内容 | 状態 |
|---|---|---|
| 0 | Terraformプロジェクト基盤 | 完了 |
| 1 | AWS認証・実行Role・S3 backend | 完了 |
| 2 | コストガードレール（AWS Budgets） | 完了 |
| 3 | 共通セキュリティ基盤（KMS・S3保護） | 完了（KMS・アカウントレベルS3公開防止を実装・検証済み） |
| 4 | 監査ログ（CloudTrail） | 一部実装済み（CloudTrail・専用S3・KMS連携は稼働済み、HTTPS必須化・CloudWatch Logs連携は未実装） |
| 5 | セキュリティ検知（GuardDuty・Security Hub・Access Analyzer） | 完了 |
| 6 | 構成・コンプライアンス管理（AWS Config） | 実装・技術検証済み（実料金は継続観測） |
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
