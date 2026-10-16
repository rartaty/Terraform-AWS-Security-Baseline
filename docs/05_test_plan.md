# 試験計画・確認状況と残作業

- 同期日: 2026-10-16（Phase 8の撤去結果を反映。KMS実削除・最終費用は確認待ち。個別試験日は各行を参照）
- 対象: dev環境と短期Lab、Phase 3〜8の構成・試験状況
- 根拠: Terraformコード、設計文書、実行結果、非公開の詳細記録
- 2026-09-11にdevの通常plan（refresh有効）、Config Recorder・配送・7 Ruleのread-only APIを再実行した。その他の機能試験は各試験時の実行結果を根拠とする。bootstrapと手動管理IAM全体の実効権限監査は今回のplanに含まれない。

## 1. 状態の定義

- 実装済み: Terraformに定義があり、apply結果を確認した。
- コード確認済み: 静的な設定を確認した。実際の拒否や配信成功を意味しない。
- 結果確認済み: 試験時の実行結果を確認した。記録更新時の再実行ではない。
- Simulation確認済み: 指定したPolicy・Action・Resource・contextでの評価結果。実APIの拒否や、未入力のresource policyを含む全権限の証明ではない。
- 記録不足: 結果は確認済みだが、文書への集約が不足している。
- 未検証・未観測: 確認結果がない。記録追記だけで完了扱いにしない。

## 2. Phase 7以降の実装・試験状況

| 項目 | 現状 | 完了に必要な作業 |
|---|---|---|
| Phase 7のNetwork Baseline | 実装・主要検証済み | 静的要件と保存証跡の対応付けを完了する。第7.4節参照 |
| Phase 7のACCEPT／REJECT試験 | HTTP応答・受信側ENIのACCEPT／REJECT照合、一時resource撤去済み。手動IAMの整理結果と確認範囲は第5.1節へ記録済み | 試験の再作成は不要。IAMの未確認範囲は第4節と区別して管理する |
| Phase 7.5のAWS Network Firewall | 2026-10-08に構築、同一接続のHTTP結果とALERT／DROP署名照合、前後の通常URIの成功、非公開証跡保存、Lab主要resource 23個の撤去を確認。2026-10-09にLab IAM・Budget Action・backendの整理と保存原本による試験判定の対応付けを完了。確認方法は第5.2〜5.3節。[Lab構成・手順](../envs/phase75/README.md) | 反映後の費用確認。削除後のIAM・backend API再取得、内部ログ配送情報の全件照会、代表DROP通信のFLOWログ照合は未実施として区別する。指定名・Labタグ・IP範囲での不在確認をaccount全体の残存ゼロと扱わない。TLS・実攻撃・multi-AZ可用性・独立したStateless遮断試験は対象外 |

## 3. 採否判断が必要な事項・見送り済みの事項

| 項目 | 状態 | 次の判断 |
|---|---|---|
| KMS alias | 2026-09-11に不採用を決定 | CloudTrail・Configは固定したkey ARNを直接参照し、参照経路を単純化する |
| CloudTrailのCloudWatch Logs転送 | 検索・監視要件と追加費用を踏まえ見送り済み | 今回の完了条件から除外。再採用する場合だけ目的・料金・監視要件を再判断する。Phase 7.5のFirewallログ配送とは別の判断 |
| KMS残存riskと復旧手順 | 破壊的権限縮小を適用し、構築時の残存riskを中へ再評価 | Phase 8で回復用Key Policyを照合した。取消・再有効化の実機試験は行わず、確認限界を明記して撤去した |

## 4. 未検証・未観測の事項

| 項目 | 現在確認できること | 残作業 |
|---|---|---|
| Configuration Item数・Rule評価数・実料金 | 9月21〜22日（UTC）のアカウント全体の暫定費用を取得済み。P7単独の費用ではない | 確定費用とCI数・評価数の対応を確認し、費用設計の見積りを更新する |
| MFA未認証での実AssumeRole拒否 | Phase 6の閲覧Roleに関する条件単体Simulationとは別に、2026-09-28にTerraform実行RoleへMFA条件を追加し、新規AssumeRole成功・No changesを確認した。2026-10-15にTrust全文をAPI再取得し、MFA条件を照合した | MFAなしの実AssumeRole拒否は未試験。成功経路や過去のSimulationで代替しない |
| ConfigEvidenceReadRoleのS3変更API拒否 | 対象prefix内の仮想object ARNでGetObject=allowed、PutObject/DeleteObject=implicitDeny | identity policyのSimulation確認済み。実Put/Delete・bucket設定変更は未試験。確認限界を明記して撤去する方針とし、追加実機試験は実施しなかった |
| 現在のIAM権限全体 | 2026-10-15に実行Roleのinline 10件・managed 10件を含む指定Role・既知Policy本文をAPI再取得した（第9節）。KMS Key Policyも再取得した（第9節） | resource policy・session policy等を含む全経路・全実効権限の網羅的監査は未完了。広いCreateTags、resource／region範囲等の最小権限化は別課題 |

## 5. 確認済みの結果と確認範囲

APIの再照会と過去の試験時の結果を区別する。詳細は非公開作業記録へ集約する。

| 項目 | 確認済みの結果・範囲 |
|---|---|
| Config Recorder | Phase 6時点でRecording=True、LastStatus=SUCCESS。現行コードはNetwork 7種類追加後の17種類・CONTINUOUS。EC2 Instance／Volume／ENIは記録対象外 |
| Config配送 | 2026-09-11再照会でSnapshot・HistoryともSUCCESS、StreamはNOT_APPLICABLE。SNS未採用の構成と整合 |
| 実object暗号化 | HeadObjectのaws:kms、ExpectedKeyMatch=True |
| 7 Managed Rules | 2026-09-11の同一API照会で、プロジェクトの7 RuleすべてCOMPLIANT |
| Resource Timeline | 初期Configuration eventとCompliance eventを確認。既存設定からの意図的な変更前後比較は未検証 |
| 権限制御 | MFA付きAssumeRoleと対象prefix一覧は成功。DescribeKey、Decrypt、別RoleへのAssumeRole、対象外prefix一覧はAccessDenied（過去の確認）。S3 identity policyとMFA条件単体のSimulation結果は上記の未実施範囲と併記する |
| negative test用一時権限の撤去 | `iam:SimulateCustomPolicy`と`iam:SimulatePrincipalPolicy`を一時付与して評価後に削除。Simulation APIが再びAccessDeniedとなることを確認 |
| Terraform整合 | 2026-09-23に試験用IAM整理後、envs/devでterraform plan -input=false -no-color -detailed-exitcodeを再実行。終了コード0、No changes。applyは行っていない |
| Budget Action | 10 USDのACTUALしきい値、AUTOMATIC、APPLY_IAM_POLICYを定義し、今回のplanで差分なし。課金による発火試験は未実施 |
| KMS破壊的権限の縮小 | Key Policyから`DisableKey`と`ScheduleKeyDeletion`を除去し、`CancelKeyDeletion`と`EnableKey`の残存を確認。一時的な`PutKeyPolicy`を撤去し、最終planはNo changes |
| CloudTrail用S3のHTTPS必須化 | `DenyInsecureTransport`を適用。最終planはNo changes、CloudTrailはLogging=True、直近配送時刻あり、配送errorなし |

AccessDeniedという結果だけから、拒否原因が必ず特定のexplicit Denyだったと断定しない。
policyの静的確認とエラーで確認できたAction、実行Role、対象を対応させて記録する。

初回MFA Simulationは仮のidentity AllowとTrust Policyを同時入力してallowedとなった。
これは実STS認可の再現性を確認できていないため、合否判定に使わない。
続く試験は同じBool条件を持つ別のidentity-style Policyの単体評価であり、
実Trust Policy全体の検証に置き換えない。[AWSのSimulationと実環境の差異](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html)を参照。
一時権限は私がStatementを削除し、SimulateCustomPolicyとSimulatePrincipalPolicyの両APIでAccessDeniedを確認した。
手動管理Policyの削除確認をTerraformのNo changesだけで代替しない。

### 5.1 2026-09-28 IAM整理・MFA検証（実行結果）

以下は試験時のJSON、CLI出力、保存・削除記録に基づく。
記録更新時のAWS API再取得と、生のAPI応答ファイルの保存・hash照合は未実施である。

| 対象 | 結果と根拠 |
|---|---|
| 誤った名称のKMS管理inline policy | 内容は通常閲覧Roleの重複管理許可と一時監査Roleの管理許可だったため削除。削除後No changesと、CLI取得のinline一覧からの不在を確認 |
| Flow Logs本文読取・旧請求権限 | 一時的なGetObject Statementと旧aws-portal Statementを削除。各削除後No changes、有効なmanaged policy版／inline本文のCLI取得結果で不在を確認 |
| EC2試験・Config監査用権限 | AMI名のpolicyはEC2 Describeのみ、Config閲覧Role管理は通常Roleのみ、Config storageのKMS操作はDescribeKey／GetKeyPolicyのみであることをCLI取得結果で確認 |
| KMS Key Policy | 一時監査Role向けの復号許可なし。Terraform実行Roleへの直接許可にPutKeyPolicy／Decrypt／DisableKey／ScheduleKeyDeletionなし。通常のservice・ログ閲覧Roleへの許可とaccount recoveryは維持。これだけでIAM経由の全実効権限不在とは断定しない |
| Budget関連 | 実行Roleのtrust、inline一覧・本文、managed policy一覧、抑止policy有効版をCLI取得結果で照合。指定実行Roleへ指定Deny policyだけを付け外しする構造。実際のしきい値発火・自動attachは未試験 |
| MFAの事前検証 | 操作権限を付けない一時Roleで条件なしのAssumeRole成功。BoolのMultiFactorAuthPresent=true条件へ変更し、保存内容確認・時間を置いた再要求とも成功。認証元TYPEはlogin |
| 既存Terraform実行Roleへの適用 | 変更前のCLI取得TrustにMFA条件がなかったため条件追加を実施。追加後の新規AssumeRole成功、通常planのNo changesを確認。最終Trust全文の再取得とMFAなし拒否試験は未実施 |
| 後片付け | 一時MFA検証Roleとユーザー側の一時監査inline policyは両方削除済み。削除後の不在API照会・監査API再拒否の確認は未実施 |

一時権限の撤去と、既存Baselineの最小権限化は分ける。広いCreateTagsとタグ条件付き管理許可の
組合せ、Phase 5のresource／region範囲、Budget trustの全Budget対象などは改善候補として残す。
No changesは通常planの参照処理を確認した結果であり、将来の作成・更新・削除権限の保証ではない。

### 5.2 2026-10-09 Phase 7.5の後片付け

| 対象 | 確認結果・範囲 |
|---|---|
| Lab IAM | Lab実行Role、通常managed policy 4つ、専用Boundary、Lab用Budget抑止policy・付け外しinline policyをConsoleで削除し、不在を確認した。初期設定用・監査用・state保全用の一時Roleも削除した。削除後のIAM API再取得は未実施 |
| Budget Action | Lab専用Actionを削除し、API再取得でBaseline用ActionのみSTANDBYで残ることを確認した。Baseline用のBudget・権限は保持した |
| ログresource policy | ACCOUNT／RESOURCE両scopeをAPI再取得し、両方0件を確認した。内部のログ配送情報の全件照会とは区別する |
| Lab backend | 削除前のCLI一覧でstate 31 version、lockfile 47 version・削除マーカー47件を確認。state全31 versionと取得前後の一覧を非公開保存し、33ファイルのサイズ・SHA-256を再照合した。計125件をConsoleで完全削除し、bucket直下でversion表示ON・対象prefixの検索確定後に残存0件を確認した。削除後のAPI再取得は未実施。lockfile本文は保全していない |
| 保持対象 | 共有backend bucketとBaseline用stateを保持した。Labの撤去をBaseline全体の撤去・課金停止と扱わない |
| 通常plan | RDS_LOGIN_EVENTSを専用resourceへ分離し、そのresourceのadditional_configurationだけを無視する限定例外を適用した。moved blockによるstate移動のみでAWS resourceの追加・変更・削除0件。適用後のrefresh付き通常planは終了コード0・No changes。state一覧で旧アドレスの不在と移動先を確認し、GetDetector再取得で機能とRDS_DATA_RISKが両方DISABLEDであることを確認。IAM権限・Providerバージョンは変更していない。追加設定の監査はNo changesだけで代替しない |
| 費用 | 10月7〜8日（UTC）のアカウント全体サービス別料金を取得したが、両日Estimated=true。2026-10-09に各日のConsole出力CSVも照合し、各サービスの合計と総額が一致した。10月8日分のCSVにはFirewall・EC2の列がない。CSV単独ではフィルター・見積状態・反映完了を保証できず、Lab単独の費用帰属、確定費用、撤去後の課金停止は未確認 |

### 5.3 保存原本とPhase 7.5試験判定の対応付け

2026-10-09に保存原本9ファイルのサイズ・SHA-256をmanifestと再照合し、すべて一致した。
通信試験はALERT時とDROP時の代表各1 cycleを、時刻・5-tuple・試験URI・署名IDで照合した。
TimeoutのConsole記録時刻には待機時間が含まれるため、要求前後の時系列も区別した。

| 試験・確認項目 | 原本と判定 |
|---|---|
| ALERT | Client Consoleの試験URI HTTP 200と、ALERTログの同じ通信の署名・allowed／alertが一致。合格 |
| DROP | Client Consoleの試験URI Timeoutと、ALERTログの同じ通信の署名・blocked／dropが一致。合格。Timeout単独を遮断証明にしていない |
| 正常通信への影響 | 両cycleとも試験URIの前後の通常URIがHTTP 200。合格 |
| Firewall同期 | 保存したFirewall応答はREADY／IN_SYNC、Rule原本はdrop。試験時のALERT原本は別時点のログで照合し、最終Ruleを過去の設定証明にしない |
| FLOWログ | 保存範囲のFLOWログ配送と代表ALERT通信の同一flow_idを確認。代表DROP通信の同一flow_idは保存範囲に見つからず、未照合。HTTP結果＋署名によるDROP判定とは区別する |

ALERTログ753件中752件、FLOWログ381件中380件がJSON形式だった。
各1件の権限確認メッセージは通信イベントではないため、署名判定の対象から除外した。
詳細な対応表と解析結果はGit対象外へ保存し、公開文書に実IP・Port・flow_id・原本を含めない。

## 6. 証跡の管理と終了条件

- 公開文書には設計・確認方法・匿名化した状態を記載する。
- 個別実行結果はGit対象外のPhase別作業記録に集約し、アカウントID・実ARN・認証情報・object本文は公開しない。
- Phase 6は主要動作確認済みだが、実API拒否試験・利用量と確定費用などの残確認をすべて完了したとは扱わない。
- Phase 8の撤去結果は第9節を参照する。未実施の復旧・拒否試験は成功扱いにしない。

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
Cleanup失敗時は残存ID、error、課金継続を記録し、終了扱いにせず対応する。
上限は作業手順であり自動停止機能ではない。apply前にCleanupの権限・手順と作業時間を確保する。

### 7.3 Cleanup確認

- test flagを通常値へ戻してapplyし、EC2-A／B、root EBSおよびtest用Security Groupを削除する。
- EC2、EBS、ENI、Public IPv4およびtest用Security Groupの残存がないことをread-only APIで確認する。
- Flow Logs、専用S3、VPC、Subnet、Route Tableおよびhardening済みDefault SGは後続検証まで一時保持する。学習終了後は次節に従い削除する。
- Config Ruleが既存Default VPC等を`NON_COMPLIANT`とした場合は別findingとして記録し、Phase 7だけの判断で変更・削除しない。
- 最終`terraform plan`が`No changes`になることを確認する。
- Phase 7.5は別stateの短期Labとして実施した。試験・撤去結果と残確認は第2節で管理し、Phase 7のCleanupと区別する。

### 7.4 実績と残確認（2026-09-23）

| 対象 | 結果・根拠 |
|---|---|
| 通信試験 | 保存証跡と試験時のCLI結果でHTTP 8080成功、受信側ENIの8080 ACCEPT／8081 REJECT・log-status=OKを照合済み |
| Config監査 | P7 VPCのFlow Logs、Default SG、試験SGのSSH公開防止を対象別にCOMPLIANT確認。別VPCの不適合は対象外として分離 |
| 削除記録 | 一時監査Roleで取得したConfigのS3原本本文に、試験SG 2個のResourceDeletedを照合済み。原本・照合結果・SHA-256は非公開で保存 |
| 撤去後の再確認 | 9月23日のAPIで試験用の非terminated EC2・SG、P7 VPC内ENI、東京RegionのEBSはいずれも0件 |
| 定常構成 | 9月23日のAPIでDefault SGのIngress／Egressなし、Flow Logs ACTIVE・ALL・配送SUCCESS、KMS一時監査statement不在を確認 |
| 試験権限 | 試験用policyをDescribeのみへ縮小しアタッチ済み。その後の参照APIとplanは成功。保存後policyの再取得と他policyとの権限合成は未確認 |

この表は2026-09-23時点の結果である。その後のLab試験は第5.3節、最終照合・撤去は第9節に記載する。
planのNo changesは手動IAMの撤去証明ではない。

## 8. 学習終了時の完全削除・継続課金停止

2026-09-12の合意により、学習完了後は本件Baselineを完全削除する。ここは終了条件であり、
削除済みの記録や、今すぐdestroyする指示ではない。実施時に対象・削除plan・必要証跡を確認する。

1. dev、bootstrap、別Lab、手動作成本件専用resourceを棚卸しする。利用Region全体とglobal resourceを確認し、無関係な既存resourceを除外する。2026-10-15に、アカウント全体のS3 Block Public Accessは有効のまま保持する方針を決定した。Terraform管理から外す方法とplanは撤去前に確認する。
2. 必要な証跡は機密情報を除いてローカルへ保存する。stateは秘密情報を含み得るためGitへ入れず、安全に扱う。
3. 依存関係を確認してworkload、ログ生成・配送、課金する検知・Config等のサービスを停止／削除する。Recorderだけの停止ではRule評価や他サービスの課金停止を証明しない。
4. S3は現行objectだけでなく非現行version、delete marker、未完了multipart uploadを確認し、必要な完全削除後にbucketを削除する。30日Lifecycle待ちで継続費用を残さない。
5. Terraform backendは依存する全構成の削除とstate確認が終わるまで保持する。backend自身の削除手順・stateの扱いを事前に決め、最後にbootstrapを片付ける。
6. KMSは復号が必要な証跡処理・利用サービスの終了後に削除予約する。通常Roleから外した削除権限は必要時だけ承認された管理経路で付与し、作業後に撤去する。削除待機中は完全削除未完了として追跡し、待機期間後に不在を確認する。
7. EC2、EBS、snapshot、ENI、IP、Firewall Endpoint、S3、課金サービス等をread-only APIで照合する。Terraform管理外も確認し、stateが空という理由だけで課金ゼロとしない。
8. 課金データ反映後に削除後の利用期間を対象として新規課金がないことを確認する。削除前利用分の後日請求と継続課金を区別する。KMS削除予約取消等で料金が再発生していないことも確認する。

完了は「本件由来の継続課金なし」と「削除可能な本件resourceの完全削除」の両方を満たした時点とする。
AWS管理keyや無料のサービス保持履歴まで消去すること、無関係なresourceの削除やアカウント閉鎖は要求しない。
現在の撤去結果は第9節に示す。Terraform管理対象0とAWS上の実削除を区別する。

## 9. Phase 8の最終確認・撤去結果（2026-10-16）

構築・主要試験と撤去操作を終え、KMSの実削除と費用反映後の確認を残している。
以下は各操作時のAPI・CLI・Console結果を照合した記録であり、継続監視の結果ではない。

| 対象 | 結果・確認方法 | 確認限界 |
|---|---|---|
| Terraform | 撤去前にdev・bootstrapのfmt／validate成功。撤去後は両stateの管理対象0、devの通常planとbootstrapのdestroy planがNo changes | 通常実行Role削除前の確認。削除後は既存認証経路でplanを再実行しない |
| 検知・構成管理 | GuardDuty、Security Hub、既知のAccess Analyzer、Config、Flow Logsの対象設定を撤去し、API・CLI結果を照合 | 全サービス・全アカウントの網羅的監査を証明しない |
| CloudTrail・ネットワーク | CloudTrailと検証用ネットワークを撤去し、対象の不在を確認 | 無関係な既存resourceとDefault VPCは削除対象外 |
| ログ用S3 | 代表証跡を保全後、対象bucketの全version・削除マーカー・未完了uploadを確認し、空化・bucket撤去を確認 | 全ログ本文は保存していない。代表CloudTrail本文の取得・復号と全objectの監査は別 |
| backend | state履歴を非公開保存・SHA-256照合し、devをlocal backendへ移行。remote state／lockの全version・削除マーカーを削除し、bucket不在をAPIで確認 | local stateと履歴はGit対象外で保持。構築用コードをそのままapplyしない |
| Budgets | Budget・Actionの撤去とAPI上の不在を確認 | 予算通知・追加構築の自動抑止は終了。実しきい値発火試験は未実施 |
| 手動IAM | 既知の実行・編集・閲覧・一時Role、専用Boundary・policy、旧AssumeRole権限を整理。最終の通常実行Role・専用policy等はConsole削除・再検索で不在を確認 | 最終Console確認後のIAM API再取得は未実施。未知IAM・全実効権限の網羅的証明ではない |
| S3公開防止 | アカウント全体の4設定をtrueのままTerraform管理から除外し、最終参照で保持を確認 | 保護を弱めず意図的に保持する |
| KMS | 削除予約後のPendingDeletionと予定日時をAPIで確認。最終参照で予約日時と回復用Key Policyの保持を照合 | 実削除は未確認。削除予定は2026-11-14 18:24 JST。取消・再有効化の実機試験は未実施 |
| 費用 | 暫定データを保存し、CSVの内訳・合計を照合 | 最終費用・削除後の継続課金停止・Lab単独の費用帰属は未確定 |

### 最終照合と未実施試験

- 構築時のSecurity Hub基準READY、Access Analyzer ACTIVE、KMS rotation設定を確認した。新規脅威・外部公開の検知試験に置き換えない。
- CloudTrail・Configの代表objectの暗号化metadataと想定keyの一致を確認した。Configの記録resource数を課金CI数・評価数へ換算しない。
- 有効17 Regionの指定サービスmetadataを照合したが、対象外サービスや未知の手動resourceを含むアカウント全体の不存在保証ではない。
- MFAなしAssumeRole拒否、閲覧Roleによる実S3書込み拒否、KMS復旧の実機試験は、確認限界を明記して撤去する方針とし未実施のままとした。Simulationや成功経路で代替しない。
- Phase 7の通信・Config原本照合、Phase 7.5のALERT／DROP照合には保存済み証跡を用い、再構築による試験は行っていない。
- accountのログイン・MFA・費用参照、KMS回復経路、非公開の保全証跡は保持する。

### 完全終了までの残確認

1. KMSの削除予定日時後に対象鍵の不在を確認する。予定日時の到来だけで完了としない。
2. 費用反映後、削除後の利用期間を確認し、削除前利用分の後日計上と継続課金を区別する。
3. Phase 7の静的構成全要件と保存証跡の一覧対応は未完了のため、保存済み資料で照合できる範囲を整理し、未確認を区別する。結果と未確認範囲を文書へ反映する。自動監視・通知は設定していない。

## Activity Log

- 2026-10-16: 公開履歴のメール匿名化と変更の集約を進め、詳細作業記録を含む過去の試験文書は公開履歴から除外する方針とした。旧履歴は非公開バックアップに保持し、公開前に最終ファイルの同一性・履歴・個人情報を再検査する。

- 2026-10-16: 公開版を構成・試験結果・撤去状況・確認限界へ集約し、詳細な作業記録を非公開領域へ保全した。KMS実削除・最終費用は未完了として維持した。今回の公開準備でAWS変更・pushは行っていない。
