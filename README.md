# Terraform AWS Security Baseline

Terraformを使用して、AWSアカウントの基本的なセキュリティ、
監査、構成管理、コスト監視基盤を構築するプロジェクトです。

## Status

設計・構築中

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
