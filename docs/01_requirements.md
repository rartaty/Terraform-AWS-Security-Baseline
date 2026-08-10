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
- Terraformで作成したリソースは検証後にdestroy可能とする
- 本番環境ではなく、セキュリティ基盤の検証環境とする

## 3. 今回の実装対象

### コスト管理
- AWS Budgets
- 予算超過通知

### 監査ログ
- AWS CloudTrail
- CloudTrailログ保存用S3バケット
- CloudWatch Logsへのログ転送
- ログ暗号化
- ログ改ざん・公開防止

### セキュリティ検知
- Amazon GuardDuty
- AWS Security Hub CSPM
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
- パブリック／プライベートサブネット
- 必要最小限のSecurity Group
- 不要なインバウンド通信を許可しない

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
- AWS Budgetsの設定を確認できる
- terraform destroy後に残存リソースを確認できる
- READMEと設計ドキュメントが完成している