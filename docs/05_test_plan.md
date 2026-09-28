# 試験計画・確認状況と残作業

- 同期日: 2026-09-28（利用者共有のIAM整理・MFA検証・一時権限撤去結果を反映。個別試験日は各行を参照）
- 対象: dev環境、Phase 3〜7の構成・試験状況
- 根拠: Terraformコード、ADR、利用者が共有した実行結果、非公開作業記録
- 2026-09-11にdevの通常plan（refresh有効）、Config Recorder・配送・7 Ruleのread-only APIを再実行した。その他の機能試験は過去の共有結果を根拠とする。bootstrapと手動管理IAM全体の実効権限監査は今回のplanに含まれない。

## 1. 状態の定義

- 実装済み: Terraformに定義があり、apply結果が共有されている。
- コード確認済み: 静的な設定を確認した。実際の拒否や配信成功を意味しない。
- 結果共有済み: 利用者が実行結果を共有した。今回の再実行ではない。
- Simulation確認済み: 指定したPolicy・Action・Resource・contextでの評価結果。実APIの拒否や、未入力のresource policyを含む全権限の証明ではない。
- 記録不足: 結果は共有済みだが、文書への集約が不足している。
- 未検証・未観測: 確認結果がない。記録追記だけで完了扱いにしない。

## 2. Phase 7以降の実装・試験状況

| 項目 | 現状 | 完了に必要な作業 |
|---|---|---|
| Phase 7のNetwork Baseline | 実装・主要検証済み | 静的要件と保存証跡の対応付けを完了する。第7.4節参照 |
| Phase 7のACCEPT／REJECT試験 | HTTP応答・受信側ENIのACCEPT／REJECT照合、一時resource撤去済み。手動IAMの整理結果と確認範囲は第5.1節へ記録済み | 試験の再作成は不要。IAMの未確認範囲は第4節と区別して管理する |
| Phase 7.5のAWS Network Firewall | Optional・未設計 | Phase 7完了後、別ADR、1 AZ、事前費用承認、`ALERT`→`DROP`、同日destroyを条件に実施判断する |

## 3. 採否判断が必要な事項・見送り済みの事項

| 項目 | 状態 | 次の判断 |
|---|---|---|
| KMS alias | 2026-09-11に不採用を決定 | CloudTrail・Configは固定したkey ARNを直接参照する。ADR 0009を参照 |
| CloudWatch Logs転送 | ADR 0005で見送り済み | 今回の完了条件から除外。再採用する場合だけ目的・料金・監視要件を再判断する |
| KMS残存riskと復旧手順 | 破壊的権限縮小を適用し、残存riskを中へ再評価 | 稼働中keyを用いた破壊的復旧試験は行わず、Phase 8で手順確認の範囲を判断する |

## 4. 未検証・未観測の事項

| 項目 | 現在確認できること | 残作業 |
|---|---|---|
| Configuration Item数・Rule評価数・実料金 | 9月21〜22日（UTC）のアカウント全体の暫定費用を取得済み。P7単独の費用ではない | 確定費用とCI数・評価数の対応を確認し、費用設計の見積りを更新する |
| MFA未認証での実AssumeRole拒否 | Phase 6の閲覧Roleに関する条件単体Simulationとは別に、2026-09-28にTerraform実行RoleへMFA条件を追加し、新規AssumeRole成功・No changesが共有された | MFAなしの実AssumeRole拒否は未試験。成功経路や過去のSimulationで代替しない。最終Trust Policy全文のCLI再取得も未実施 |
| ConfigEvidenceReadRoleのS3変更API拒否 | 対象prefix内の仮想object ARNでGetObject=allowed、PutObject/DeleteObject=implicitDeny | identity policyのSimulation確認済み。実Put/Delete・bucket設定変更は未試験。実データを変更しない検証方法と必要範囲をPhase 8で判断する |
| 現在のIAM権限全体 | 実行Roleの20 policy本文を利用者共有JSONで確認。主要変更箇所・KMS Key Policy・Budget関連は利用者共有のCLI取得結果でも照合（第5.1節） | 全policy本文のCLI再取得・権限合成の網羅的監査は未完了。広いCreateTags、resource／region範囲等の最小権限化は別課題 |

## 5. 確認済みの結果と確認範囲

今回の再照会と過去の共有結果を区別する。詳細は非公開作業記録へ集約する。

| 項目 | 共有済みの結果・範囲 |
|---|---|
| Config Recorder | Phase 6時点でRecording=True、LastStatus=SUCCESS。現行コードはNetwork 7種類追加後の17種類・CONTINUOUS。EC2 Instance／Volume／ENIは記録対象外 |
| Config配送 | 2026-09-11再照会でSnapshot・HistoryともSUCCESS、StreamはNOT_APPLICABLE。SNS未採用の構成と整合 |
| 実object暗号化 | HeadObjectのaws:kms、ExpectedKeyMatch=True |
| 7 Managed Rules | 2026-09-11の同一API照会で、プロジェクトの7 RuleすべてCOMPLIANT |
| Resource Timeline | 初期Configuration eventとCompliance eventを確認。既存設定からの意図的な変更前後比較は未検証 |
| 権限制御 | MFA付きAssumeRoleと対象prefix一覧は成功。DescribeKey、Decrypt、別RoleへのAssumeRole、対象外prefix一覧はAccessDenied（過去の確認）。S3 identity policyとMFA条件単体のSimulation結果は上記の未実施範囲と併記する |
| negative test用一時権限の撤去 | `iam:SimulateCustomPolicy`と`iam:SimulatePrincipalPolicy`を一時付与して評価後に削除。Simulation APIが再びAccessDeniedとなることを確認 |
| Terraform整合 | 2026-09-23に試験用IAM整理の利用者報告後、envs/devでterraform plan -input=false -no-color -detailed-exitcodeを再実行。終了コード0、No changes。applyは行っていない |
| Budget Action | 10 USDのACTUALしきい値、AUTOMATIC、APPLY_IAM_POLICYを定義し、今回のplanで差分なし。課金による発火試験は未実施 |
| KMS破壊的権限の縮小 | Key Policyから`DisableKey`と`ScheduleKeyDeletion`を除去し、`CancelKeyDeletion`と`EnableKey`の残存を確認。一時的な`PutKeyPolicy`を撤去し、最終planはNo changes |
| CloudTrail用S3のHTTPS必須化 | `DenyInsecureTransport`を適用。最終planはNo changes、CloudTrailはLogging=True、直近配送時刻あり、配送errorなし |

AccessDeniedという結果だけから、拒否原因が必ず特定のexplicit Denyだったと断定しない。
policyの静的確認とエラーで確認できたAction、実行Role、対象を対応させて記録する。

初回MFA Simulationは仮のidentity AllowとTrust Policyを同時入力してallowedとなった。
これは実STS認可の再現性を確認できていないため、合否判定に使わない。
続く試験は同じBool条件を持つ別のidentity-style Policyの単体評価であり、
実Trust Policy全体の検証に置き換えない。[AWSのSimulationと実環境の差異](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html)を参照。
一時権限は利用者がStatementを削除したと報告し、SimulateCustomPolicyとSimulatePrincipalPolicyの両APIでAccessDeniedを確認した。
手動管理Policyの削除確認をTerraformのNo changesだけで代替しない。

### 5.1 2026-09-28 IAM整理・MFA検証（利用者実行結果）

以下は利用者が実行・共有したJSON、CLI出力、保存・削除完了報告に基づく。
この記録更新時にassistantがAWS APIを再実行したものではなく、生のAPI応答ファイルの
保存・hash照合まで完了したとは扱わない。

| 対象 | 結果と根拠 |
|---|---|
| 誤った名称のKMS管理inline policy | 内容は通常閲覧Roleの重複管理許可と一時監査Roleの管理許可だったため削除。削除後No changesと、CLI取得のinline一覧からの不在を共有 |
| Flow Logs本文読取・旧請求権限 | 一時的なGetObject Statementと旧aws-portal Statementを削除。各削除後No changes、有効なmanaged policy版／inline本文のCLI取得結果で不在を確認 |
| EC2試験・Config監査用権限 | AMI名のpolicyはEC2 Describeのみ、Config閲覧Role管理は通常Roleのみ、Config storageのKMS操作はDescribeKey／GetKeyPolicyのみであることをCLI取得結果で確認 |
| KMS Key Policy | 一時監査Role向けの復号許可なし。Terraform実行Roleへの直接許可にPutKeyPolicy／Decrypt／DisableKey／ScheduleKeyDeletionなし。通常のservice・ログ閲覧Roleへの許可とaccount recoveryは維持。これだけでIAM経由の全実効権限不在とは断定しない |
| Budget関連 | 実行Roleのtrust、inline一覧・本文、managed policy一覧、抑止policy有効版をCLI取得結果で照合。指定実行Roleへ指定Deny policyだけを付け外しする構造。実際のしきい値発火・自動attachは未試験 |
| MFAの事前検証 | 操作権限を付けない一時Roleで条件なしのAssumeRole成功。BoolのMultiFactorAuthPresent=true条件へ変更し、保存内容確認・時間を置いた再要求とも成功。認証元TYPEはlogin |
| 既存Terraform実行Roleへの適用 | 変更前のCLI取得TrustにMFA条件がなかったため、利用者承認で条件追加を実施。追加後の新規AssumeRole成功、通常planのNo changesを共有。最終Trust全文の再取得とMFAなし拒否試験は未実施 |
| 後片付け | 一時MFA検証Roleとユーザー側の一時監査inline policyは両方削除済みとの利用者報告。削除後の不在API照会・監査API再拒否の確認は未実施 |

一時権限の撤去と、既存Baselineの最小権限化は分ける。広いCreateTagsとタグ条件付き管理許可の
組合せ、Phase 5のresource／region範囲、Budget trustの全Budget対象などは改善候補として残す。
No changesは通常planの参照処理を確認した結果であり、将来の作成・更新・削除権限の保証ではない。

## 6. 証跡の管理と終了条件

- 公開文書には設計・確認方法・匿名化した状態を記載する。
- 個別実行結果はGit対象外のPhase別作業記録に集約し、アカウントID・実ARN・認証情報・object本文は公開しない。
- Phase 6は主要動作確認済みだが、ADR 0008の完了条件をすべて満たしたとは扱わない。
- Phase 8の統合試験・復旧・後片付けは別途計画する。この文書は全Phaseの試験仕様が完成したことを意味しない。

## 7. Phase 7の試験仕様

「通信の学習」と「継続的な設定監査」を区別する。前者はRoute・SG・実通信・Flow Logs、
後者はConfigの構成履歴とRule評価で確認する。2台試験はAZ障害切替やInternet接続の実証ではない。
Configのperiodic評価は24時間とし、変更時評価専用のDefault SG Ruleには実行頻度を指定しない。
Flow Logs RuleにはtrafficType=ALLを指定する。変更時評価とperiodic評価、記録CI数を分けて費用を計算する。
最大10分集約を設定してもNitroのENIは1分以下となるため、1分のrecordを不合格にしない。

### 7.1 静的構成確認

| 対象 | 確認内容 | 合格条件 |
|---|---|---|
| Address Plan | VPCと4 SubnetのCIDR、AZ、重複 | CIDRが重複せず、Public／Isolatedが各2 AZに存在する |
| Route Table | Main、Public、IsolatedのRouteとassociation | Main／Isolatedは`local`のみ、Publicだけが`0.0.0.0/0 -> IGW`を持ち、全Subnetが明示関連付けされる |
| Public exposure | Public IPv4自動割当、IPv6、NAT、Load Balancer | いずれも作成・有効化されていない |
| Default SG | Ingress／Egress | 両方とも空である |
| Flow Logs | Scope、Traffic Type、aggregation、destination | VPC全体、`ALL`、最大10分、専用S3で`ACTIVE`である |
| S3 | 公開防止、暗号化、Versioning、Transport、Lifecycle | Public Access Block、SSE-S3、Versioning、HTTPS必須、現行・非現行versionの30日Lifecycleを満たす |
| AWS Config | 記録対象とManaged Rules | Network resource typeが記録され、追加3 Ruleをresource別に確認し、Phase 7 VPCと既存resourceの結果を区別できる |

### 7.2 動的通信試験

EC2-AをPublic Subnet、EC2-Bを同じAZのIsolated Subnetへ配置する。両方ともPublic IPv4、
SSH keyおよびIAM Instance Profileを持たない。AのIngressは空、AのEgressはBのSecurity Groupを
destinationとして試験Portだけを許可する。BはAのSecurity Groupをsourceとして許可Portだけを
Ingress許可し、外部downloadを行わずAmazon Linux 2023のPythonで一時HTTP serviceを起動する。

| Test | 観測点 | 合格条件 |
|---|---|---|
| AからBの許可Portへ接続 | Application応答、B側ENIのFlow Log | HTTP応答を確認し、`srcaddr=A`、`dstaddr=B`、許可`dstport`、`action=ACCEPT`、`log-status=OK`を確認する |
| AからBの非許可Portへ接続 | 接続結果、B側ENIのFlow Log | 接続失敗を確認し、同じA／Bで非許可`dstport`、`action=REJECT`、`log-status=OK`を確認する |
| Source SG限定 | BのIngress Rule | SourceがCIDRやAの現在IPではなく、Aにだけ付与したSecurity Group IDである |
| S3配送 | Flow Logs専用S3 | `.log.gz` objectが到着し、対象ENIのrecordを展開して確認できる |

A側ENIでは非許可Portへの送信もEgress Ruleにより`ACCEPT`になり得るため、拒否判定は
B側ENIを基準にする。1 packetだけに依存せず、service起動待ちを含む少数回のretryを行う。
REJECTだけでSG原因と断定せず、Route、NACL、AのEgress、BのIngressおよび試験時刻を照合する。
暫定の待機上限は最終試験通信から30分、全体上限はEC2作成apply開始から2時間とする。
早い方の期限で試験を終了し、成功・失敗を問わずCleanupへ進む。起動失敗・権限不足でも同様とする。
ログ未着は失敗／未観測として時刻・ENI・試行結果を保存し、成功扱いにしない。
削除後に遅延配送されたログは記録済みENIと照合できるため、ログ待ちでEC2を無期限保持しない。
Cleanup失敗時は残存ID、error、課金継続を記録して利用者に報告し、終了扱いにせず対応する。
上限は作業手順であり自動停止機能ではない。apply前にCleanupの権限・手順と作業時間を確保する。

### 7.3 Cleanup確認

- test flagを通常値へ戻してapplyし、EC2-A／B、root EBSおよびtest用Security Groupを削除する。
- EC2、EBS、ENI、Public IPv4およびtest用Security Groupの残存がないことをread-only APIで確認する。
- Flow Logs、専用S3、VPC、Subnet、Route Tableおよびhardening済みDefault SGは後続検証まで一時保持する。学習終了後は次節に従い削除する。
- Config Ruleが既存Default VPC等を`NON_COMPLIANT`とした場合は別findingとして記録し、Phase 7だけの判断で変更・削除しない。
- 最終`terraform plan`が`No changes`になることを確認する。
- Phase 7.5を実施する場合は、このCleanupとPhase 7完了後に別試験計画を作る。

### 7.4 実績と残確認（2026-09-23）

| 対象 | 結果・根拠 |
|---|---|
| 通信試験 | 保存証跡と共有結果でHTTP 8080成功、受信側ENIの8080 ACCEPT／8081 REJECT・log-status=OKを照合済み |
| Config監査 | P7 VPCのFlow Logs、Default SG、試験SGのSSH公開防止を対象別にCOMPLIANT確認。別VPCの不適合は対象外として分離 |
| 削除記録 | 一時監査Roleで取得したConfigのS3原本本文に、試験SG 2個のResourceDeletedを照合済み。原本・照合結果・SHA-256は非公開で保存 |
| 撤去後の再確認 | 9月23日のAPIで試験用の非terminated EC2・SG、P7 VPC内ENI、東京RegionのEBSはいずれも0件 |
| 定常構成 | 9月23日のAPIでDefault SGのIngress／Egressなし、Flow Logs ACTIVE・ALL・配送SUCCESS、KMS一時監査statement不在を確認 |
| 試験権限 | 利用者が試験用policyをDescribeのみへ縮小しアタッチ済みと報告。その後の参照APIとplanは成功。保存後policyの再取得と他policyとの権限合成は未確認 |

静的構成の全要件と証跡の対応付け、手動IAMの最終確認、確定費用確認は残る。
planのNo changesは手動IAMの撤去証明ではない。保持中のBaselineは未destroyであり、
P7.5の実施判断およびPhase 8の完全削除とは区別する。

## 8. 学習終了時の完全削除・継続課金停止

2026-09-12の合意により、学習完了後は本件Baselineを完全削除する。ここは終了条件であり、
削除済みの記録や、今すぐdestroyする指示ではない。実施時に対象・削除plan・必要証跡を確認する。

1. dev、bootstrap、別Lab、手動作成本件専用resourceを棚卸しする。利用Region全体とglobal resourceを確認し、無関係な既存resourceを除外する。
2. 必要な証跡は機密情報を除いてローカルへ保存する。stateは秘密情報を含み得るためGitへ入れず、安全に扱う。
3. 依存関係を確認してworkload、ログ生成・配送、課金する検知・Config等のサービスを停止／削除する。Recorderだけの停止ではRule評価や他サービスの課金停止を証明しない。
4. S3は現行objectだけでなく非現行version、delete marker、未完了multipart uploadを確認し、必要な完全削除後にbucketを削除する。30日Lifecycle待ちで継続費用を残さない。
5. Terraform backendは依存する全構成の削除とstate確認が終わるまで保持する。backend自身の削除手順・stateの扱いを事前に決め、最後にbootstrapを片付ける。
6. KMSは復号が必要な証跡処理・利用サービスの終了後に削除予約する。通常Roleから外した削除権限は必要時だけ承認された管理経路で付与し、作業後に撤去する。削除待機中は完全削除未完了として追跡し、待機期間後に不在を確認する。
7. EC2、EBS、snapshot、ENI、IP、Firewall Endpoint、S3、課金サービス等をread-only APIで照合する。Terraform管理外も確認し、stateが空という理由だけで課金ゼロとしない。
8. 課金データ反映後に削除後の利用期間を対象として新規課金がないことを確認する。削除前利用分の後日請求と継続課金を区別する。KMS削除予約取消等で料金が再発生していないことも確認する。

完了は「本件由来の継続課金なし」と「削除可能な本件resourceの完全削除」の両方を満たした時点とする。
AWS管理keyや無料のサービス保持履歴まで消去すること、無関係なresourceの削除やアカウント閉鎖は要求しない。
削除手順の詳細化と実行はPhase 8の残作業であり、現在は未実施である。
現行のKMSコードは`prevent_destroy = true`、削除待機30日である。最終削除時は保護解除の
限定変更と削除権限を事前確認する必要があり、今のまま一括destroyできるとは限らない。
今回この保護も待機日数も変更しない。

## Activity Log

- 2026-09-28: 利用者共有のIAM整理、主要policyのCLI取得結果、MFA条件付き新規AssumeRole成功、No changes、一時Role・監査権限の削除報告を反映。MFAなし拒否試験・最終Trust全文再取得・全policy本文のCLI再取得・削除後のAPI確認は未実施として区別。今回の作業は文書更新のみ。

- 2026-09-23: P7の未実装・未実施表記を構築／通信試験／Config原本照合／一時resource撤去の実績へ同期。手動IAM縮小は利用者報告とし、実体再取得・静的証跡整理・確定費用を残確認として維持。通常planはNo changes。新規ADR・AWS変更・pushなし。

- 2026-09-17: Phase 7の設計に、resourceごとの作成理由、課金、dependency、destroy前提、削除後確認を追加。Terraformのdependency graphだけではS3全versionや遅延ENIを自動解決できないことを明記。AWS resourceの作成・削除は未実施。

- 2026-09-17: 利用者共有のVPC CIDR・利用可能AZと合意を根拠に、ADR 0010のAddress Planと1a／1c配置を確定。照合範囲は提示された東京Regionの結果に限定。AWS resource作成・通信試験は未実施。

- 2026-09-12: 構成設計のPhase 8に残っていた保持・残存費用の旧表現を同期。一時保持は削除順序上の都合に限定し、完全削除と継続課金停止を完了条件に統一した。文書のみの変更。

- 2026-09-12: 費用・保存期間の誤解を補正。Phase 7の通信学習とConfig監査を分離し、暫定待機期限と失敗時Cleanup、学習完了後の完全削除・継続課金停止確認を追加。AWS設定は変更していない。

- 2026-09-12: Phase 7の2 AZ Network Baseline、Public／Isolated Subnet、Flow Logs専用S3、Config連携、および一時EC2-A／BによるACCEPT／REJECT試験を合意済み設計として追加。Phase 7.5のAWS Network Firewallは常設せず、別ADR・1 AZ・事前費用承認・同日destroyを条件とするOptional Labへ分離した。
- 2026-09-11: 文書整合性監査でdev planのNo changes、Recorder稼働、Snapshot/History配送成功、7 RuleのCOMPLIANTを再確認。Budget Actionの説明とSimulationの証明範囲を修正し、未実施の実API試験を残作業へ戻した。
- 2026-09-11: KMS破壊的権限の縮小について、AWS適用、Key Policy確認、一時権限撤去、最終No changesを反映した。
- 2026-09-11: CloudTrail用S3のHTTPS必須化を適用し、Terraform整合とログ配送継続の確認結果を反映した。
- 2026-09-11: Phase 6のMFA条件とS3読取り専用境界をPolicy Simulatorでnegative testし、一時的なSimulation権限の撤去まで確認した。Role Trust Policy自体はSimulator非対応のため、MFA条件を同等のテストPolicyでfalse/true評価した。

- 2026-09-10: コード・ADR・共有結果を照合し、追加実装、採否判断、未検証・未観測、記録不足を分類。AWS設定・Terraformコードの変更や試験実行は行っていない。
