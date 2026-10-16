# Terraform AWS Security Baseline

Terraformを使用して、AWSアカウントの基本的なセキュリティ、
監査、構成管理、コスト監視基盤を構築するプロジェクトです。

学習用のため、最終検証後はBaselineもdestroyします。本件由来の継続課金を残さないよう、
S3の全version、backend、課金サービス、KMSの削除待機を含む残存確認までを完了条件としています。
詳細は[試験・終了条件](docs/05_test_plan.md)を参照してください。

## Status

構築・主要試験と撤去操作を終え、最終確認待ちです（2026-10-16同期）。
VPCの許可／拒否通信とFlow Logs、AWS Configの構成・削除履歴、Network FirewallのHTTP内容検査による検知／遮断を確認しました。
Phase 8では検証環境、ログ保存先、S3 backend、専用IAMを整理し、dev・bootstrapのTerraform管理対象0を確認しました。

**KMSの実削除と最終費用の確認は未完了**です。KMSは2026-11-14 18:24 JSTの削除予定で、予定日時後に実削除を確認します。
アカウント全体のS3公開防止、ログイン・MFA・費用参照の経路は保持しています。
実施していない拒否・復旧試験と確認方法の限界は[試験・確認状況](docs/05_test_plan.md)に記載しています。

コードは構築時の構成を再利用するために残しています。削除済みのbackendや実行Roleをそのまま利用することはできません。
再構築時は認証・backend・費用・削除手順を確認し、planをレビューしてからapplyしてください。

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

以下は構築・検証したサービスです。現在稼働中の一覧ではありません。

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
- `docs/`: 要件、設計概要、試験結果と確認限界（生の証跡・記事原稿・詳細な意思決定記録は非公開）
