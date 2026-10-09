# Terraform AWS Security Baseline コスト設計

- 状態: 採用
- 制定日: 2026-08-25
- 更新日: 2026-09-28（Phase 7の実装状態を同期。料金単価・月額モデルの再見積りは未実施）
- 対象リージョン: `ap-northeast-1`（東京）

## 1. 結論

本プロジェクトを全Phaseまで小規模構成で稼働させた場合、
低利用時の暫定計画値は **月額約3～6 USD** とする（下記モデルは2.30～5.90 USD）。
これは一時EC2削除後、Baselineを後続学習のため一時保持する期間の月額であり実測値ではない。
全学習終了後は完全削除し、本件由来の継続課金を残さない。削除前の利用料金まで消えるわけではない。

これは請求額の保証ではない。AWSは従量課金であり、ログ量、APIイベント数、
記録resource数、rule評価回数、無料トライアル、為替、税により変動する。
通知と追加作成抑止のしきい値として、AWS Budgetは **月額10 USD** とする。
課金全体のhard capではなく、請求データ・Actionの反映遅延もある。
実績額が1、3、5、8、10 USDを超えた場合に通知する。
予測通知は利用履歴が十分に蓄積してから必要性を再評価する。

## 2. 見積りの前提

- 個人所有の単一AWSアカウント、単一dev環境、東京リージョンだけを対象とする。
- 本番ワークロード、EC2常時稼働、NAT Gateway、Load Balancer、専用public IPv4は使わない。Phase 7のEC2はFlow Logs試験中だけ2台を一時作成し、同日中に削除する。
- CloudTrailは管理イベントの最初のコピーだけをS3へ配信する。
- CloudTrailのデータイベント、Insights、CloudTrail Lakeは使わない。
- 初期概算ではCloudWatch LogsとVPC Flow Logsを各1 GB/月未満と仮定した。現在CloudWatch Logs転送は見送り、VPC Flow Logsは専用S3への配送を実装・確認済み。実際の配送量を使った月額モデルの更新は残る。
- KMS customer managed keyは1個とし、CloudTrailとAWS Configで共有する。Phase 7のFlow Logs専用S3はSSE-S3とし、KMS利用主体を追加しない。
- Security HubはEssentials相当の必要機能だけとし、Extended Planは使わない。
- GuardDuty Protection Planは必要なものだけを選び、不要なplanは無効化する。
- IAM Access Analyzerは無料のexternal access analyzerだけを使う。
- AWS Configは記録対象resource typeとmanaged ruleを少数に限定する。
- S3に保存するstateとログは小容量とする。

前提から外れる変更を行う場合は、`terraform apply`より前に再見積りする。

## 3. 現行構成を前提とする条件付き見積り

旧Phase別累計はCloudWatch Logsと一時費用が混在していたため置き換える。
Phase 6の初期概算も実測上限ではない。以下は無料trial・税・為替を除き、実利用量の代わりに
仮定を置いた計画モデルである。東京Regionの全SKUを確定した見積りではなく、apply前に再確認する。

| 費目・Phase | 前提 | 月額USD |
|---|---|---:|
| KMS（3） | key 1本、追加rotation課金前 | 1.00 |
| Security Hub IAM分（5） | 課金対象user／role 10～30個、3.75 / 125 × 個数 | 0.30～0.90 |
| Config記録（6・7合算） | CONTINUOUSのCI 100～500件 × 0.003 | 0.30～1.50 |
| Config評価（6・7合算） | 月500～1,500評価 × 0.001 | 0.50～1.50 |
| 脅威分析（5） | 低利用時の仮置き予算。実ログ量未取得 | 0.10～0.50 |
| 保存・配送・request（1・3・4・6・7合算） | S3、Flow Logs配送、KMS request等の仮置き予算 | 0.10～0.50 |
| 合計 | 上記仮定の算術合計。上限保証ではない | 2.30～5.90 |

Phase 4は管理イベントの最初のコピーのTrail配信が0 USD、CloudWatch Logs転送は見送りで
本件の当該利用料を0 USDとする。残るCloudTrail用S3保存・requestとKMS利用料は上の合算枠に含む。
旧0.10～1.50 USDのPhase 4追加額を重ねて計上しない。Essentialsに含まれるCSPM等も重複加算しない。
Phase 0はAWS課金なし、Phase 2は本件の無料枠内のBudget利用を前提とする。

### 一時試験費用（定常月額に含めない）

- Phase 7: EC2 2台 × 時間 × 東京時間単価 ＋ EBS容量 × GB月単価 × 時間按分 ＋ ログ・Config・Security Hub等の増分。
- instance type、AMI、EBS容量と時間を確定して積算する。試験1回1 USD以内は暫定目標であり自動停止額ではない。
- Phase 7.5: Firewall Endpoint、処理data、ログ、一時resourceを別見積り・別承認とする。現時点で今回の合計へ算入しない。
- Phase 8: 最終試験・証跡取得・削除に伴うrequest等を計上する。destroy後の既発生料金の後日反映を継続課金と混同しない。

### 実測への置換（暫定費用取得済み・モデル更新は未実施）

2026-09-23に短期間のアカウント全体の暫定費用を取得済み。ただしPhase 7単独の費用でも
確定請求でもなく、下記の利用量内訳に基づく月額モデルへの置換は未実施である。

課金対象IAM数、月次CI数・評価数、GuardDuty使用量、S3容量・version・request、保持日数を取得する。
短期間を月換算する場合は初回記録と平常変更を分離する。既存Default VPC等もConfigの対象になり得る。
実測後に上の仮定を置換し、総費用は保持期間分＋一時試験＋削除時利用分で再計算する。

## 4. 各サービスの料金判断

### AWS Budgets

- 標準のBudget監視と通知は無料である。
- アカウント全体を対象とする月額10 USDのCost Budgetを使用する。
- 実績額1、3、5、8、10 USDの5段階でEメール通知する。
- 予測通知は初期構成では使用しない。
- クレジットと返金によって実際の利用規模が隠れないよう、予算計算から除外する。
- 税とSupport料金はAWSリソース利用額の監視対象ではないため除外する。
- Budget Actionによる自動停止・自動削除は使用しない。
- Budget Actionは実装済み。実績10 USDでTerraformExecutionRoleへ高額作成抑止Policyを自動attachする。既存resourceの稼働・課金は止まらず、拒否対象外の操作や別identityには適用されない。Phase 7.5の専用Roleには別Actionを追加した。
- SNSとBudget Reportsは初期構成では使用しない。
- action-enabled budgetは最初の2件まで無料で、追加分には日額料金がある。
- Budget Reportsは有料なので本件では使わない。
- BudgetはAWSリソースを自動的に停止する「利用上限」ではない。

### Amazon S3

- 保存容量、PUT/GET等のrequest、データ転送などに従量課金される。
- state、CloudTrail、Configの小規模ログだけなら少額だが、完全無料とは断定しない。
- versioningにより古いobject versionも保存量に含まれるため、ログ保持期間とlifecycleを設計する。
- CloudTrail・Config・Flow Logsは現行30日＋非現行30日。未更新objectは概ね60日後に完全削除対象となり、非現行期間も保存料金がかかる。UTC日付の丸め・非同期処理があり厳密な60日保証ではない。
- 完全削除対象になった後のLifecycle処理遅延分は原則追加保存課金されない。学習終了時はLifecycle待ちにせず全versionを明示削除する。今回Lifecycleコードは変更しない。

### AWS KMS

- customer managed KMS keyは1 keyあたり1 USD/月で、時間按分される。
- requestは月20,000件の無料枠があるが、対象外APIもある。
- 複数サービスで1 keyを共有し、学習環境で不要なkeyを増やさない。
- key rotation後は追加月額が発生し得るため、rotation方針決定時に再確認する。

### AWS CloudTrailとCloudWatch Logs

- Event historyは無料である。
- trailによる管理イベントの最初のコピーはS3へ無料配信できる。
- 追加の管理イベントコピー、データイベント、Insights、CloudTrail Lakeは有料なので初期対象外とする。
- CloudWatch LogsへのCloudTrailイベント配信は見送り。本件の現行見積りでは当該取り込み・保存・検索料金を計上しない。将来採用時だけ再見積りする。

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
- 現行のcustomer-managed Recorderは17 resource typeのCONTINUOUS記録、Terraformで明示管理するManaged Rulesは10個（2026-09-28実体確認）。Security Hubが管理するRuleは別に存在し、10個をアカウント全体のRule数や評価費用の全対象とは扱わない。記録料金は実際のConfiguration Item数、評価料金はRuleごとの対象resource数・評価回数で見積もる。両者を単一の掛け算で算定しない。
- CloudTrail・Config用S3は現行versionの期限切れが30日、非現行化後の削除が30日。保存から30日で物理削除される設定ではなく、非現行versionも保存料金に含まれる。

### Amazon VPCとVPC Flow Logs

- VPC、subnet、route table、Security Groupなどの論理部品には通常、個別の時間料金はない。
- VPC Flow Logsは出力先のログ取り込み・保存料金が発生する。
- Phase 7ではVPC全体の`ALL` trafficを最大10分で集約し、専用S3へ標準Text・Gzip形式で保存する。少量を前提とするが、上限料金ではない。
- Nitro EC2のENIは指定にかかわらず実際の集約が1分以下になる。機能上の問題ではないが、10分設定によるログ削減を料金前提にしない。
- 専用S3はSSE-S3、Versioning、現行・非現行versionとも30日Lifecycleとする。Flow Log objectは通常上書きしないが、Versioningを他のlog bucketと共通の保護層として採用する。
- Phase 7で、Phase 6の10 resource type・7 Ruleへnetwork用7 resource type・3 Ruleを追加済み。既存resourceも対象になり得るため、増額を一律に少額とは断定しない。記録CIと評価件数を別々に積算する。
- ACCEPT／REJECT試験ではEC2 2台と暗号化EBSを短時間だけ使用する。作成前に東京単価・時間を確認し、成功時または試験計画の待機期限・失敗時にCleanupする。
- NAT Gateway、Load Balancer、public IPv4を追加すると別料金になるため、Phase 7では作成しない。
- public IPv4は通常0.005 USD/時で、1個を1か月保持すると約3.60 USDになるため本件では作らない。

### AWS Network Firewall（Phase 7.5 Optional Lab）

- Availability ZoneごとのFirewall Endpoint時間料金、処理data量、Firewall Logの配送・保存、test resourceが課金対象になる。
- Phase 7の2 AZ Baselineへ常設せず、1 AZの単純なinspection pathとして短時間だけ構築する。2 AZへ配置するとEndpoint時間料金も2系統分になる。
- `ALERT`確認後に`DROP`を試し、試験当日にdestroyする。作成前に東京Regionの現行単価と予定稼働時間から上限見積りを作り、対象・費用・期限を確認し、実行を手動承認する。
- Firewall Endpoint、専用Route、Log出力先およびtest resourceの削除をCLIで確認するまで、Labを終了扱いにしない。
- 2026-10-07にAWS公開料金データの東京Regionで、標準Endpoint 0.395 USD/時間、処理0.065 USD/GBを確認した。1 AZ・Endpoint 1個・2時間ならEndpoint部分は0.79 USD。EC2・EBS・ログ・Config等の増分と税は別で、合計見積りと費用承認は未完了。出典は[東京の公開料金データ](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AWSNetworkFirewall/current/ap-northeast-1/index.json)（publicationDate: 2026-09-11）。
- Lab専用Roleは既存Budget Actionの対象に自動追加されない。Lab用作成抑止の設定と撤去権限を確認してから課金開始する。

## 5. 課金開始前の停止点

次の操作は、実行前に「何が、いつから、概算いくら課金されるか」を確認し、
対象・費用・期限を手動承認してから行う。

- Phase 3: customer managed KMS keyの`apply`
- Phase 4: CloudTrailの`apply`。見送り中のCloudWatch Logs転送を後から追加する場合も事前承認・再見積りする。
- Phase 5: GuardDutyまたはSecurity Hubの有効化
- Phase 6: AWS Config recorderとConfig ruleの有効化
- Phase 7: Flow Logs専用S3、Flow Logsおよび一時EC2／EBSの作成
- Phase 7.5: AWS Network Firewall、Firewall Endpoint、Firewall Logおよびtest resourceの作成

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

全学習終了時は[試験計画8](05_test_plan.md)に従い、devだけでなくbootstrap・手動作成本件専用resource・全S3 versionを確認する。
KMS削除予約後の待機と請求反映も追跡し、本件の継続課金停止および完全削除を別々に確認する。

- [S3 Lifecycleと課金](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [Flow Logsの集約間隔](https://docs.aws.amazon.com/vpc/latest/userguide/flow-log-records.html)
- [KMS keyの削除](https://docs.aws.amazon.com/kms/latest/developerguide/deleting-keys.html)

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
