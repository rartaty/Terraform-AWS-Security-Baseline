# Terraform AWS Security Baseline

Terraformを使用して、AWSアカウントの基本的なセキュリティ、
監査、構成管理、コスト監視基盤を構築するプロジェクトです。

## Status

設計・構築中（2026-09-11同期：Phase 0〜2・5 完了、Phase 3 はKMS権限縮小の適用待ち、Phase 4 は一部実装済み、Phase 6 は実装済み・検証記録整理中）

## Roadmap

| Phase | 内容 | 状態 |
|---|---|---|
| 0 | Terraformプロジェクト基盤 | 完了 |
| 1 | AWS認証・実行Role・S3 backend | 完了 |
| 2 | コストガードレール（AWS Budgets） | 完了 |
| 3 | 共通セキュリティ基盤（KMS・S3保護） | KMS・S3公開防止は稼働済み。aliasは不採用。通常Roleの破壊的KMS権限縮小はコード反映済み・AWS適用待ち |
| 4 | 監査ログ（CloudTrail） | 一部実装済み。CloudTrail用S3のHTTPS必須化が残作業。CloudWatch Logs転送はADR 0005で見送り |
| 5 | セキュリティ検知（GuardDuty・Security Hub・Access Analyzer） | 完了 |
| 6 | 構成・コンプライアンス管理（AWS Config） | 実装済み。主要動作確認済み、一部検証・記録と費用観測が残る |
| 7 | ネットワーク検証（VPC・Flow Logs） | 未着手 |
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
- Amazon VPC（Phase 7予定）
- VPC Flow Logs（Phase 7予定）

## Directory structure

- `bootstrap/`: Terraform backendなどの初期基盤
- `envs/dev/`: dev環境のTerraformルートモジュール
- `modules/`: 再利用可能なTerraformモジュール
- `docs/`: 要件、設計、試験、証跡
