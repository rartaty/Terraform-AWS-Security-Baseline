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
Phase 7.5は2026-10-08にHTTPの内容検査とLab主要リソースの撤去を確認しました。残る整理・確認は「実施内容・確認結果・残作業」を参照してください。

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

## 実施内容・確認結果・残作業

準備（Phase 0）として、Terraformのプロジェクト構成・バージョン管理・Git除外設定を整備しました。

### Phase 1：AWS認証・実行Role・S3 backend

- 実装：一時認証情報によるRole切り替え、S3 backendのSSE-S3暗号化・公開防止・HTTPS必須化・Versioning・S3 lockfileを設定。
- 確認：stateをS3へ移行し、backendへのアクセスとTerraformの実行を確認。
- 追加の権限制御：実行RoleのMFA条件を実APIで確認し、Permissions Boundaryと専用IAM管理Roleを整備。構成は[BoundaryとIAM管理](docs/permissions-boundary-setup.md)を参照。

### Phase 2：コストガードレール（AWS Budgets）

- 実装：月額予算・段階的な通知と、専用RoleによるBudget Actionを設定。上限到達時に高コストリソースの新規作成を拒否するPolicyを実行Roleへ自動アタッチする構成を採用。
- 確認：実績費用の超過通知を受信し、Budget Actionの対象Role・Policy・閾値・自動実行設定を確認。
- 未検証・制約：上限到達によるPolicyの自動アタッチは未試験。費用反映には遅延があり、既存リソースの課金を停止する仕組みではない。

### Phase 3：共通セキュリティ基盤（KMS・S3保護）

- 実装：CloudTrail・AWS Config用のKMS key、Key Policy、鍵の自動ローテーションと、S3のアカウント単位Public Access Blockを設定。
- 権限の縮小：通常実行RoleからKMS keyの無効化・削除予約権限を除去。aliasは採用せず、key ARNで参照。
- 確認：AWSへ適用後、Terraformの`No changes`を確認。

### Phase 4：監査ログ（CloudTrail）

- 実装：複数Regionの管理イベントを専用S3へ配送。KMS暗号化・公開防止・HTTPS必須化・Versioning・保存期間・ログファイル検証と、閲覧用Roleを設定。
- 確認：ログ配送の継続、配送エラーの有無、Terraformの`No changes`を確認。
- 対象外：CloudWatch Logsへの転送は検索・監視要件と追加費用を踏まえ見送り。Data EventsとInsightsも初期構成には含めない。

### Phase 5：セキュリティ検知（GuardDuty・Security Hub・IAM Access Analyzer）

- 実装：GuardDuty、Security Hub Essentials／CSPMとFSBP、IAM Access Analyzerの外部アクセス分析を有効化。不要な追加機能は無効化。
- 確認：GuardDutyのFindingをSecurity Hubで確認し、CloudTrailの操作履歴と変更記録を照合して調査。調査済みFindingを`Resolved`へ更新し、Terraformの`No changes`を確認。
- 確認範囲：検知基盤の構築と実際のFindingの調査を実施。すべての脅威シナリオの検知や、継続的なSOC運用までを検証したものではない。

### Phase 6：構成・コンプライアンス管理（AWS Config）

- 実装：Configuration Recorder、暗号化された専用S3への配送、Managed Rules、履歴閲覧用Roleを設定。Phase 7でネットワークの記録・評価対象を追加。
- 確認：Recorderと配送の成功、Phase 6時点の7 Ruleの`COMPLIANT`、Terraformの`No changes`を確認。S3閲覧権限とMFA条件はPolicy Simulationでも確認。
- 残作業：一部の拒否条件の実API試験、構成変更前後の履歴照合、記録・評価件数と費用の整理。未実施範囲は[試験・確認状況](docs/05_test_plan.md)を参照。

### Phase 7：ネットワーク検証（VPC・Flow Logs・AWS Config）

- 実装：2 AZ・4 Subnet、明示的なRoute Table／association、Internet Gateway、Default SGの閉鎖、専用S3へのVPC Flow Logs配送とConfig連携を構築。
- 確認：Public IPv4なしの一時EC2 2台でHTTP通信を試験し、受信側ENIの`ACCEPT`／`REJECT`と照合。対象別のConfig適合性と、試験用SG 2個の`ResourceDeleted`をS3の原本で確認。
- 撤去：一時EC2・EBS・ENI・試験用SG・一時監査Roleと追加のKMS復号許可を撤去し、Terraformの`No changes`を確認。
- 残作業：静的要件と証跡の対応付け、IAM権限の残確認、確定費用の整理。

### Phase 7.5：Optional IDS/IPS Lab（AWS Network Firewall）

- 実装：1 AZのPrivate EC2 2台、往復ともFirewallを通るRoute、Stateful Rule、CloudWatch LogsのALERT／FLOWログを構築。専用実行Role・Permissions Boundary・独立したTerraform stateでBaselineから分離。
- 確認：2026-10-08に、`ALERT`では対象URIのHTTP成功と検知ログ、`DROP`ではタイムアウトと遮断ログを照合。遮断前後も通常URIのHTTP成功が継続することを確認。
- 撤去：Labの23リソースをdestroyし、Firewall・Policy・Rule Groupの不在と、対象EC2・EBS・ENI等の残存がないことを確認。Baselineには常設しない。
- 残作業：IAM・Budget Action・backend等の整理、証跡の恒久保存、費用確認。詳細は[Labの構成・確認範囲](envs/phase75/README.md)を参照。

### Phase 8：統合試験・証跡・後片付け・文書化（未着手）

- 実施予定：統合試験、未実施の権限試験と残作業の整理、再構築・撤去手順の最終化。生の証跡は非公開で保存する。
- 撤去予定：Baselineと本件由来の手動リソースを削除。S3の全version・Delete Marker・backendと、課金サービス・KMS keyの削除待機を含めて確認する。
- 完了条件：KMSの待機期間終了後の不在確認と、費用反映の遅延を考慮した継続課金の残存確認まで完了する。

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
