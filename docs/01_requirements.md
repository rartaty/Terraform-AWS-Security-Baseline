# Terraform AWS Security Baseline 要件定義

## 1. 目的

Terraformを用いて、AWSアカウントに最低限必要な
セキュリティ・監査・コスト管理基盤を再現可能な形で構築する。

本プロジェクトは、AWSセキュリティ運用・クラウドガバナンス・
Infrastructure as Codeの学習を目的とする。

## 2. 対象環境

- 個人所有のAWSアカウント
- 単一アカウント
- 単一環境：dev
- 原則として低コストまたは無料枠内
- 学習・最終検証後はTerraformで作成したBaselineをdestroyし、本件由来の継続課金を残さない
- 全versionを含むS3・backend・手動作成した本件専用resourceも棚卸しし、完全削除と課金停止を確認する。無関係な既存resourceやAWS管理resourceの一括削除は対象外
- KMS等の削除待機と請求反映遅延を考慮し、destroyコマンド成功だけで完了としない
- 本番環境ではなく、セキュリティ基盤の検証環境とする

## 3. 今回の実装対象

### コスト管理
- AWS Budgets
- 予算超過通知

### 監査ログ
- AWS CloudTrail
- CloudTrailログ保存用S3バケット
- CloudWatch Logsへのログ転送は今回見送り。検索・監視の必要性と追加料金を再判断してから追加する。
- ログ暗号化
- ログ改ざん・公開防止

### セキュリティ検知
- Amazon GuardDuty
- AWS Security Hub Essentials / CSPM（採用範囲は[アーキテクチャ](02_architecture.md)を参照）
- IAM Access Analyzer

### 構成管理
- AWS Config
- Config記録用S3バケット
- 基本的なAWS Configルール

### ストレージ保護
- アカウントレベルS3 Block Public Access
- S3バケット暗号化
- バージョニング
- パブリックアクセス禁止

### IAM
- 最小権限を意識したTerraform実行ロール
- IAMユーザーの常用を避ける
- アクセスキーをコードに保存しない
- IAM Access Analyzerによる外部公開検知

### 暗号化
- AWS KMS
- CloudTrailおよびログ保存先の暗号化

### ネットワーク
- 検証用VPC
- 2 Availability Zoneに配置するパブリック／隔離（Isolated）サブネット
- VPCおよびSubnetのCIDRを明示したAddress Plan
- 各Subnetに明示的に関連付けるRoute Table
- Public Subnetだけが利用するInternet GatewayへのRoute
- Public IPv4自動割当、IPv6、NAT Gatewayを使用しない構成
- 必要最小限のSecurity Group
- Default Security GroupのIngress／Egressを空にする
- 不要なインバウンド通信を許可しない
- VPC全体を対象とするVPC Flow Logs（ACCEPT／REJECT）
- Flow Logs専用S3バケットへの暗号化保存、HTTPS必須、公開防止、30日Lifecycle
- 一時的な2台のEC2によるSecurity GroupのACCEPT／REJECT試験
- 試験後に一時EC2、EBSおよび試験用Security Groupを削除する

## 4. 今回は実装しないもの

- AWS Organizations
- Control Tower
- 複数AWSアカウント
- SCP
- 本格的なSOC／SIEM
- Amazon Macie
- Amazon Inspector
- WAF
- 高可用性を目的としたNAT Gateway構成
- 本番ワークロード
- 完全自動修復
- AWS Network Firewallの常設。IDS／IPSはPhase 7.5の短期Optional Labとして別途判断する

## 5. 非機能要件

### セキュリティ
- 認証情報をGitへ保存しない
- Terraform StateをGitへ保存しない
- S3のパブリック公開を禁止する
- 保存データを暗号化する
- 監査ログを削除・改変しにくい構成にする

### コスト
- 課金が発生するサービスを明示する
- 検証後にdestroyできるようにする
- NAT Gatewayなど高コストなリソースを原則使用しない
- AWS Budgetsで利用料金を監視する

### 運用
- terraform fmt、validate、planを実行する
- apply前にplan結果を確認する
- READMEに構築・確認・削除手順を書く
- 構築結果のスクリーンショットを保存する

## 6. 完了条件

- terraform initが成功する
- terraform validateが成功する
- terraform planの内容を説明できる
- terraform applyで対象リソースを構築できる
- AWSコンソール上で各サービスの有効化を確認できる
- CloudTrailログがS3へ保存される
- Security HubまたはConfigで検出結果を確認できる
- VPC Flow Logsで、許可PortのACCEPTと非許可PortのREJECTを識別できる
- Flow Logの`.log.gz` objectが専用S3バケットへ保存される
- Phase 7の一時試験resourceを削除し、定常構成に残っていないことを確認できる
- AWS Budgetsの設定を確認できる
- terraform destroy後に残存リソースを確認できる
- READMEと設計ドキュメントが完成している
