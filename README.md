# Terraform AWS Security Baseline

Terraformを使用して、AWSアカウントの基本的なセキュリティ、
監査、構成管理、コスト監視基盤を構築するプロジェクトです。

学習用のため、最終検証後はBaselineもdestroyします。本件由来の継続課金を残さないよう、
S3の全version、backend、課金サービス、KMSの削除待機を含む残存確認までを完了条件としています。
詳細は[試験・終了条件](docs/05_test_plan.md)を参照してください。

## Status

実装・検証を進行中（2026-09-23同期）。Phase 0〜5は完了、Phase 6は実装・主要動作確認済み。
Phase 7はNetwork Baseline・Flow Logs・Config連携の構築、通信試験、ConfigのS3原本照合、
一時試験リソースの撤去を完了しました。暫定費用は取得済みで、確定費用・静的証跡の整理・手動IAM権限の最終確認などは残っています。
Phase 7.5は2026-10-08にHTTPの内容検査とLab主要リソースの撤去を確認しました。Phase 8は未着手です。残る整理・確認は[試験・確認状況](docs/05_test_plan.md)を参照してください。

## Roadmap

| Phase | 内容 | 目的 |
|---|---|---|
| 0 | Terraformプロジェクト基盤 | 構成・バージョン管理・Git除外設定を整え、安全に変更を管理する。 |
| 1 | AWS認証・実行Role・S3 backend | AWS操作権限を実行Roleに分離し、Terraformのstateを安全に管理する。 |
| 2 | コストガードレール（AWS Budgets） | 費用の増加を通知し、予算上限到達時の追加構築を制限する。 |
| 3 | 共通セキュリティ基盤（KMS・S3保護） | 監査・構成履歴を暗号化し、S3の意図しない公開を防止する。 |
| 4 | 監査ログ（CloudTrail） | AWSの操作履歴を保存し、検知結果や設定変更の調査に使用する。 |
| 5 | セキュリティ検知（GuardDuty・Security Hub・IAM Access Analyzer） | 脅威・セキュリティ設定・外部アクセスを異なる観点から検知する。 |
| 6 | 構成・コンプライアンス管理（AWS Config） | リソースの構成履歴を保存し、設定がルールに適合しているか評価する。 |
| 7 | ネットワーク検証（VPC・Flow Logs・AWS Config） | ネットワークの許可・拒否と、設定の適合性・削除履歴を実通信とログで照合する。 |
| 7.5 | Optional IDS/IPS Lab（AWS Network Firewall） | 同じHTTPポートの通信をURIの内容で区別し、検知と遮断の違いを検証する。 |
| 8 | 統合試験・証跡・後片付け・文書化 | 要件・実装・AWS実体・証跡を対応付け、学習環境の終了まで確認する。 |

Phaseごとの目的、完了条件、依存関係は[アーキテクチャ](docs/02_architecture.md)、
料金見積りと課金前の確認事項は[コスト設計](docs/04_cost_design.md)を参照してください。

残作業の分類と確認範囲は [試験・確認状況](docs/05_test_plan.md) を参照する。
実装済み、コード確認済み、結果確認済み、未検証を区別する。

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
- Amazon VPC（Phase 7: 2 AZ・4 Subnet・明示Route／association・IGW・Default SG hardeningを実装済み）
- VPC Flow Logs（Phase 7: 専用S3への配送、実通信のACCEPT／REJECTを確認済み）
- AWS Network Firewall（Phase 7.5 Optional Lab。Baselineには常設しない）

## Directory structure

- `bootstrap/`: Terraform backendなどの初期基盤
- `envs/dev/`: dev環境のTerraformルートモジュール
- `modules/`: 再利用可能なTerraformモジュール
- `docs/`: 要件、設計、試験、証跡
