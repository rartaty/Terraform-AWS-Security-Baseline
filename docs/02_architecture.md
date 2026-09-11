# Terraform AWS Security Baseline アーキテクチャ・Phase計画

- 状態: 採用
- 制定日: 2026-08-25
- 対象: 個人所有の単一AWSアカウント、dev環境、`ap-northeast-1`

## 1. Phase構成を設ける目的

本プロジェクトを、依存関係と課金リスクに沿った小さな単位に分ける。
各Phaseでは、Terraformのコード作成だけでなく、`fmt`、`validate`、`plan`、
必要な場合の`apply`、AWS上での確認、判断理由の記録までを完了条件とする。

順序は次の考え方で決定した。

1. ローカルの作業基盤と安全な認証を最初に確立する。
2. 有料サービスより先に予算通知を作る。
3. 暗号鍵とS3保護を、ログ保存サービスより先に作る。
4. 監査ログを、検知・コンプライアンス評価より先に作る。
5. 個別機能を作った後に、ネットワークを含む統合試験を行う。

## 2. 全体像

```text
Phase 0  Terraformプロジェクト基盤
   ↓
Phase 1  AWS認証・実行Role・S3 backend
   ↓
Phase 2  コストガードレール
   ↓
Phase 3  共通セキュリティ基盤
   ↓
Phase 4  監査ログ
   ↓
Phase 5  セキュリティ検知
   ↓
Phase 6  構成・コンプライアンス管理
   ↓
Phase 7  ネットワーク検証
   ↓
Phase 8  統合試験・証跡・後片付け・文書化
```

## 3. Phase別計画

### Phase 0: Terraformプロジェクト基盤（完了）

目的:

- Terraformを安全に記述・検証・Git管理できる土台を作る。

実施内容:

- ディレクトリ構成、`.gitignore`、README、要件・設計文書の雛形を作成した。
- TerraformとAWS Providerのバージョン条件を定義した。
- dev環境のProvider、変数、data source、outputを定義した。
- `terraform init`、`fmt`、`validate`、`plan`、`apply`を確認した。

判断理由:

- AWSリソースを作る前に、認証情報やstateをGitへ誤登録しない仕組みが必要である。
- バージョン条件とlock fileにより、実行者や実行日による差を小さくする。

完了条件:

- 初期構成がGitに記録され、Terraformの基本コマンドが成功する。

### Phase 1: AWS認証・実行Role・S3 backend（完了）

目的:

- 長期アクセスキーを使わず、Terraform stateを安全にAWS上で管理する。

実施内容:

- rootユーザーとIAMユーザーにMFAを設定した。
- IAMユーザー`terraform-operator`から`TerraformExecutionRole`を引き受ける構成にした。
- `aws login`と`credential_process`を使い、一時認証情報をTerraformへ渡した。
- 非公開、SSE-S3、versioning、HTTPS必須、S3 lockfile対応のstate bucketを作成した。
- dev環境のlocal stateをS3 backendへ移行した。

判断理由:

- 長期アクセスキーは漏えい時に継続利用される危険があるため作成しない。
- stateには構成情報が含まれるため、Gitや個人PCだけに置かず、暗号化・履歴・排他制御を備えたS3で管理する。
- DynamoDB lockingは使わず、Terraformが対応するS3 lockfileを採用して構成要素を減らす。

完了条件:

- S3 backend初期化後、`terraform state list`で既存stateを確認できる。
- `terraform plan`が`No changes`になる。

### Phase 2: コストガードレール（完了）

目的:

- 有料サービスを増やす前に、想定外の請求を早期に検知できるようにする。

実施内容:

- AWS Budgetsで、アカウント全体を対象とする月額10 USDのコスト予算を作成した。
- 実績額が1、3、5、8、10 USDを超えた場合のEメール通知を設定した。
- クレジット、返金、税、Support料金を予算計算から除外した。
- 通知先はGit管理外の`terraform.tfvars`に保存し、公開可能なexampleにはダミー値だけを記載した。
- ADR 0003に基づき、実績10 USDでTerraformExecutionRoleへ高額作成抑止Policyを自動attachするBudget Actionを実装した。Action用Roleと対象Policyは手動管理である。
- 新しいOutlookとWindows 11の通知を有効化し、通常メールによるデスクトップ通知経路を確認した。
- Terraform AWS Providerが実行Roleを確実に使用するよう、ProviderにもAWS profileを明示した。

判断理由:

- Budgetは利用を自動停止する上限ではなく通知機能であるが、課金の見落としを減らせる。
- 標準の予算監視と通知は無料であり、有料サービスより先に導入する合理性がある。
- 1週間の想定上限を3 USDとし、10 USDは明確な異常として調査・停止判断を行える段階値にした。
- 利用履歴が少ない段階では予測通知の精度を期待できないため、初期構成は実績額通知だけにした。
- 料金情報の反映遅延と誤停止の危険があるため、自動停止・自動削除は設定しなかった。
- Budget Actionが抑止するのは対象Policyに列挙された新規作成操作であり、稼働中resourceの課金は継続する。しきい値到達による発火試験は未実施である。

完了条件:

- AWSコンソールでBudgetと5件の実績額通知を確認できる。
- OutlookとWindows 11のデスクトップ通知経路を通常メールで確認できる。
- Apply後の`terraform plan`が`No changes`になる。

### Phase 3: 共通セキュリティ基盤

2026-09-11時点: KMS keyとアカウントレベルS3公開防止は実装済み。
当初計画のaliasは、固定したkey ARNを直接参照する単純性を優先して不採用とした（ADR 0009）。
KMS keyはCloudTrailとConfigで共有する（ADR 0006・0008）。
通常の`TerraformExecutionRole`から`kms:DisableKey`と`kms:ScheduleKeyDeletion`を除去し、
一時的な`kms:PutKeyPolicy`の撤去とapply後の`No changes`を確認したため、Phase 3は完了とする。

目的:

- 後続Phaseのログやデータを守る共通設定を先に用意する。

予定内容:

- customer managed KMS keyを作成する。aliasはADR 0009により採用しない。
- key policy、rotation、削除待機期間を設計する。
- アカウントレベルのS3 Block Public Accessを有効化する。

判断理由:

- CloudTrailやConfigより先に鍵を作ると、後から暗号化方式を変更する手戻りを避けられる。
- アカウントレベルのS3保護は、個々のbucket設定漏れに対する防御層になる。

完了条件:

- KMS key policyを説明でき、S3のアカウントレベル公開防止を確認できる。
- `plan`に意図しない公開設定や削除がない。

### Phase 4: 監査ログ

目的:

- AWS API操作を後から追跡できる監査証跡を残す。

予定内容:

- CloudTrailとログ保存用S3 bucketを構成する。CloudWatch Logs転送はADR 0005により見送る。
- bucket暗号化、versioning、公開防止、HTTPS必須、ログ改ざん防止を設定する。
- 管理イベントを対象とし、データイベントとCloudTrail Insightsは初期対象外とする。

判断理由:

- 管理イベントを最初の対象に絞ることで、監査の基本を満たしつつ従量課金を抑える。
- S3へ保存する。CloudWatch Logsによる検索・監視は、目的と料金を再判断してから追加する。

完了条件:

- 実際の管理イベントがS3へ届く。CloudWatch Logs配送は現在の完了条件に含めない。
- 保存データが公開されず、意図したKMS keyで暗号化される。

2026-09-11時点: CloudTrail・S3配送・KMS連携に加え、CloudTrail用S3の
HTTPS必須化を適用した。apply後の`No changes`、`IsLogging=True`、
直近配送時刻の更新および配送errorなしを確認したため、Phase 4は完了とする。

### Phase 5: セキュリティ検知

目的:

- 不審な操作、外部公開、セキュリティ基準違反を検出する。

予定内容:

- Amazon GuardDutyの基礎的な脅威検出を有効化する。
- AWS Security Hubの現行プランとCSPM機能を確認して有効化する。
- IAM Access Analyzerは無料のexternal access analyzerを使用する。

判断理由:

- GuardDutyとSecurity Hubは有料かつ無料トライアル後に課金されるため、Cost Estimatorを確認してから有効化する。
- GuardDutyのProtection Planは初回に自動有効化される場合があるため、対象を明示的に確認する。
- Access Analyzerのinternal accessとunused accessは有料なので、今回の外部公開検知要件には無料のexternal accessを選ぶ。

完了条件:

- 有効にしたプラン、対象リージョン、無料トライアル終了日、推定月額を記録する。
- 各サービスのステータスと検出結果画面を確認する。

### Phase 6: 構成・コンプライアンス管理

2026-09-11時点: ADR 0008の10種類の継続記録、専用S3、共有KMS、7 Managed Rules、
ConfigEvidenceReadRoleを実装済み。dev planはNo changes、Recorder稼働、Snapshot/History配送成功、7 RuleすべてCOMPLIANTを再確認した。
S3 identity policy・MFA条件単体はSimulation確認済み。実APIによる拒否試験の未実施範囲と利用量・実料金観測は [試験計画](05_test_plan.md) で管理する。

目的:

- AWSリソースの設定変更を記録し、基本ルールへの適合性を継続評価する。

予定内容:

- AWS Config recorder、delivery channel、記録用S3 bucketを作成する。
- 記録対象のresource typeを必要最小限に限定する。
- S3公開防止など、少数のAWS managed Config rulesを設定する。

判断理由:

- AWS Configは記録項目数とrule評価回数で課金されるため、全resource type・多数ruleから始めない。
- 継続記録を基本とし、対象と評価頻度を明示して費用を予測可能にする。

完了条件:

- 設定履歴が記録され、Config ruleの評価結果を確認できる。
- 対象resource type、rule数、実測コストを記録する。

### Phase 7: ネットワーク検証

目的:

- 最小構成のVPCで、ネットワーク分離と通信記録を検証する。

予定内容:

- VPC、public/private subnet、route table、最小権限のSecurity Groupを作成する。
- VPC Flow Logsを有効化し、ログ出力を確認する。
- EC2、NAT Gateway、専用public IPv4は原則作成しない。

判断理由:

- VPCの論理部品自体は多くが無料だが、NAT Gateway、EC2、public IPv4、ログ量は継続課金になる。
- 本件の目的はアプリケーション稼働ではなく、分離・通信制御・監査の学習である。

完了条件:

- subnetとrouteの分離、Security Groupの許可内容を説明できる。
- Flow Logsの出力を確認し、検証用リソースの残置有無を決定する。

### Phase 8: 統合試験・証跡・後片付け・文書化

目的:

- 要件を満たしたことを証明し、再構築と安全な削除ができる状態にする。

予定内容:

- `fmt`、`validate`、`plan`と各サービスの機能試験を行う。
- スクリーンショット、コマンド結果、実測費用を保存する。
- destroy対象と保持対象を分け、依存順に後片付けする。
- README、設計文書、Qiita記事用の作業記録を完成させる。

判断理由:

- `apply`成功だけでは、ログ到着・検出・通知などの目的達成を証明できない。
- KMS keyやログbucketは削除に待機期間や保持判断があるため、一括destroyではなく対象を確認する。

完了条件:

- 要件定義の完了条件をすべて確認し、残存リソースと継続月額を記録する。
- 再構築手順と削除手順を第三者が実行できる。

## 4. Phase共通の作業手順

各Phaseは原則として次の順で進める。

1. 目的、選択肢、採用理由、トレードオフを決める。
2. 課金項目と削除方法を確認する。
3. Terraformを記述し、1行ずつ役割を確認する。
4. `terraform fmt`と`terraform validate`を実行する。
5. `terraform plan`を読み、作成・変更・削除を確認する。
6. 課金開始前であれば、推定金額を再確認してから`apply`する。
7. AWS上の実体と期待する機能を確認する。
8. 判断、エラー、解決策、実測費用を文書化してGitへ記録する。

## 5. 変更管理

- Phaseの追加、削除、順序変更は、理由と影響を設計判断として記録する。
- AWSのサービス名・料金体系が変わった場合は、実装時点の公式情報を再確認する。
- 完了状態はREADMEと本書の両方で更新する。
