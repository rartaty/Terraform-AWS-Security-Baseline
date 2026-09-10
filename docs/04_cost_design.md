# Terraform AWS Security Baseline コスト設計

- 状態: 採用
- 制定日: 2026-08-25
- 更新日: 2026-09-10（構成前提の同期。料金表の再調査ではない）
- 対象リージョン: `ap-northeast-1`（東京）

## 1. 結論

本プロジェクトを全Phaseまで小規模構成で稼働させた場合、
通常時の計画値は **月額2～15 USD程度** とする。
2026-08-25時点の計画換算レートを1 USD = 159円とすると、
**月額約318～2,385円**である。

これは請求額の保証ではない。AWSは従量課金であり、ログ量、APIイベント数、
記録resource数、rule評価回数、無料トライアル、為替、税により変動する。
安全側の管理上限として、AWS Budgetは **月額10 USD** とする。
実績額が1、3、5、8、10 USDを超えた場合に通知する。
予測通知は利用履歴が十分に蓄積してから必要性を再評価する。

## 2. 見積りの前提

- 個人所有の単一AWSアカウント、単一dev環境、東京リージョンだけを対象とする。
- 本番ワークロード、EC2常時稼働、NAT Gateway、Load Balancer、専用public IPv4は使わない。
- CloudTrailは管理イベントの最初のコピーだけをS3へ配信する。
- CloudTrailのデータイベント、Insights、CloudTrail Lakeは使わない。
- 初期概算ではCloudWatch LogsとVPC Flow Logsを各1 GB/月未満と仮定した。現在CloudWatch Logs転送は見送り、VPC Flow Logsは未実装であり、採用時に再見積りする。
- KMS customer managed keyは1個とし、後続サービスで共有する。
- Security HubはEssentials相当の必要機能だけとし、Extended Planは使わない。
- GuardDuty Protection Planは必要なものだけを選び、不要なplanは無効化する。
- IAM Access Analyzerは無料のexternal access analyzerだけを使う。
- AWS Configは記録対象resource typeとmanaged ruleを少数に限定する。
- S3に保存するstateとログは小容量とする。

前提から外れる変更を行う場合は、`terraform apply`より前に再見積りする。

## 3. Phase別の月額見積り

以下の表と累計は2026-08-25の全Phase初期概算であり、現行構成の実測値ではない。
CloudWatch Logs転送はADR 0005で見送り、VPC Flow LogsはPhase 7未着手。
Phase 6の採用構成に対する見積りはADR 0008の月額0.10～1.00 USD程度を参照する。
表の0.10～5.00 USDは初期の広い概算として残す。いずれも上限保証ではなく、
Configuration Item数・Rule評価数・実料金は未確認であり、確認後に表と累計を再見積りする。

金額は、そのPhaseで作成したリソースを1か月保持した場合の**追加月額**である。
Phase作業そのものに固定料金があるわけではなく、作成後に残すAWSリソースと利用量で決まる。

| Phase | 主な課金要素 | 追加月額の計画値 | 累計月額の目安 | 判断 |
|---|---|---:|---:|---|
| 0 | ローカルTerraform、Git | 0 USD | 0 USD | AWSリソースを作らないため無料 |
| 1 | state用S3の保存・request | 0～0.01 USD未満 | 0～0.01 USD未満 | stateが小さく、S3使用量がごく少ない |
| 2 | AWS Budgets | 0 USD | 0～0.01 USD未満 | 標準の予算監視と通知を使用する |
| 3 | customer managed KMS key、S3公開防止 | 1.00～1.10 USD | 約1.00～1.11 USD | KMS keyは1 USD/月、requestは小量想定 |
| 4 | CloudTrail、ログS3、CloudWatch Logs | 0.10～1.50 USD | 約1.10～2.61 USD | 最初の管理イベントtrailは無料、保存・転送・ログ量は従量課金 |
| 5 | GuardDuty、Security Hub、Access Analyzer | 0.10～3.00 USD | 約1.20～5.61 USD | 小規模・低イベントを想定。trial終了後を基準にする |
| 6 | AWS Config、Config rule、保存S3 | 0.10～5.00 USD | 約1.30～10.61 USD | resource記録数とrule評価数が最大の変動要因 |
| 7 | VPC Flow Logs、ログ保存 | 0～0.50 USD | 約1.30～11.11 USD | VPC論理部品は原則無料。EC2・NAT・public IPv4は作らない |
| 8 | 一時的な試験操作・証跡 | 0～1.00 USD（一時的） | 定常費用の追加なし | 試験後に一時resourceを削除する |

表の単純合計は約1.30～11.11 USD/月だが、料金変更、計測単位、
想定外のイベントを吸収するため、全体の対外的な計画値は丸めて2～15 USD/月とする。
日本円は計画換算で約318～2,385円/月、消費税等は別である。

## 4. 各サービスの料金判断

### AWS Budgets

- 標準のBudget監視と通知は無料である。
- アカウント全体を対象とする月額10 USDのCost Budgetを使用する。
- 実績額1、3、5、8、10 USDの5段階でEメール通知する。
- 予測通知は初期構成では使用しない。
- クレジットと返金によって実際の利用規模が隠れないよう、予算計算から除外する。
- 税とSupport料金はAWSリソース利用額の監視対象ではないため除外する。
- Budget Actionによる自動停止・自動削除は使用しない。
- SNSとBudget Reportsは初期構成では使用しない。
- action-enabled budgetは最初の2件まで無料で、追加分には日額料金がある。
- Budget Reportsは有料なので本件では使わない。
- BudgetはAWSリソースを自動的に停止する「利用上限」ではない。

### Amazon S3

- 保存容量、PUT/GET等のrequest、データ転送などに従量課金される。
- state、CloudTrail、Configの小規模ログだけなら少額だが、完全無料とは断定しない。
- versioningにより古いobject versionも保存量に含まれるため、ログ保持期間とlifecycleを設計する。

### AWS KMS

- customer managed KMS keyは1 keyあたり1 USD/月で、時間按分される。
- requestは月20,000件の無料枠があるが、対象外APIもある。
- 複数サービスで1 keyを共有し、学習環境で不要なkeyを増やさない。
- key rotation後は追加月額が発生し得るため、rotation方針決定時に再確認する。

### AWS CloudTrailとCloudWatch Logs

- Event historyは無料である。
- trailによる管理イベントの最初のコピーはS3へ無料配信できる。
- 追加の管理イベントコピー、データイベント、Insights、CloudTrail Lakeは有料なので初期対象外とする。
- CloudWatch LogsへのCloudTrailイベント配信、保存、検索はデータ量に応じて課金される。

### Amazon GuardDuty

- 分析するCloudTrailイベント、VPC/DNSログ、workloadまたはデータ量に応じて課金される。
- 初回は原則30日間の無料トライアルがあるが、終了後は自動的に通常課金へ移る。
- 初回有効化時に利用可能なProtection Planが自動有効化される場合がある。
- 有効化前とtrial終了前に、GuardDutyコンソールの推定日額・月額を確認する。

### AWS Security Hub

- 2026-08-25時点の現行料金は、主に監視resource数に基づくEssentials Planである。
- 課金対象の主要resource typeはEC2、ECR image、Lambda、IAM user/roleである。
- 30日間の無料トライアルがあるが、GuardDuty等のaddonは別扱いである。
- 料金体系が更新されやすいため、有効化直前にAWS Security Hub Cost Estimatorで実アカウントを再見積りする。

### IAM Access Analyzer

- external access analyzerは追加料金なしであるため、本件ではこれを採用する。
- internal access analyzer、unused access analyzer、custom policy checkは有料なので対象外とする。
- unused access analyzerを誤って選ぶとIAM user/role数に応じた月額が発生する。

### AWS Config

- configuration item、Config rule評価、conformance pack評価が課金対象である。
- 継続記録ではconfiguration item数、定期記録では記録resource数と日数が費用に影響する。
- 記録対象を必要なresource typeに限定し、少数のmanaged ruleから開始する。
- Phase 6の`plan`前に「対象resource type数 × 想定resource数 × 評価頻度」で再計算する。

### Amazon VPCとVPC Flow Logs

- VPC、subnet、route table、Security Groupなどの論理部品には通常、個別の時間料金はない。
- VPC Flow Logsは出力先のログ取り込み・保存料金が発生する。
- NAT Gateway、EC2、Load Balancer、public IPv4を追加すると別料金になる。
- public IPv4は通常0.005 USD/時で、1個を1か月保持すると約3.60 USDになるため本件では作らない。

## 5. 課金開始前の停止点

次の操作は、実行前に利用者へ「何が、いつから、概算いくら課金されるか」を説明し、
明示的な了承を得てから行う。

- Phase 3: customer managed KMS keyの`apply`
- Phase 4: CloudTrailの`apply`。見送り中のCloudWatch Logs転送を後から追加する場合も事前承認・再見積りする。
- Phase 5: GuardDutyまたはSecurity Hubの有効化
- Phase 6: AWS Config recorderとConfig ruleの有効化
- Phase 7: Flow Logs、EC2、NAT Gateway、public IPv4等の作成

特に次の場合は作業を停止して再設計する。

- 推定定常月額が10 USDを超える。
- NAT Gateway、常時稼働EC2、Load Balancer、専用public IPv4がplanに現れる。
- GuardDutyの意図しないProtection Planが有効になる。
- Security HubでExtended Planまたは意図しないaddonが選択される。
- AWS Configが全resource typeまたは多数のperiodic ruleを記録・評価する。
- `plan`に意図しないdestroyまたはreplacementがある。

## 6. 運用ルール

1. Phase 2でBudgetを作ってから、Phase 3以降へ進む。
2. 毎回の`apply`前に、planのresourceと課金項目を確認する。
3. 有料サービスの有効化日、trial終了日、AWS表示の推定月額を記録する。
4. apply翌日と1週間後にBilling画面を確認し、見積りとの差を記録する。
5. 検証後は一時resourceを削除し、S3 object、log group、KMS keyなど残りやすいresourceも確認する。
6. Budget通知は請求停止機能ではないため、通知後は人が原因調査と停止判断を行う。
7. 料金ページは変更されるため、各Phase開始時に公式料金を再確認する。
8. 1 USDでは料金発生、3 USDでは1週間の想定上限、5 USDでは内訳調査、8 USDでは新規Apply停止、10 USDでは異常調査と不要resourceの停止・削除を判断する。

## 7. 公式料金情報

- [AWS Budgets Pricing](https://aws.amazon.com/aws-cost-management/aws-budgets/pricing/)
- [Amazon S3 Pricing](https://aws.amazon.com/jp/s3/pricing/)
- [AWS KMS Pricing](https://aws.amazon.com/jp/kms/pricing/)
- [AWS CloudTrail Pricing](https://aws.amazon.com/jp/cloudtrail/pricing/)
- [Amazon CloudWatch Pricing](https://aws.amazon.com/jp/cloudwatch/pricing/)
- [Amazon GuardDuty Pricing](https://aws.amazon.com/jp/guardduty/pricing/)
- [AWS Security Hub Pricing](https://aws.amazon.com/jp/security-hub/pricing/)
- [IAM Access Analyzer Pricing](https://aws.amazon.com/iam/access-analyzer/pricing/)
- [AWS Config Pricing](https://aws.amazon.com/jp/config/pricing/)
- [Amazon VPC Pricing](https://aws.amazon.com/vpc/pricing/)
