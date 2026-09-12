# 試験計画・確認状況と残作業

- 同期日: 2026-09-12
- 対象: dev環境、Phase 3〜6の現行構成とPhase 7の合意済み試験設計
- 根拠: Terraformコード、ADR、利用者が共有した実行結果、非公開作業記録
- 2026-09-11にdevの通常plan（refresh有効）、Config Recorder・配送・7 Ruleのread-only APIを再実行した。その他の機能試験は過去の共有結果を根拠とする。bootstrapと手動管理IAM全体の実効権限監査は今回のplanに含まれない。

## 1. 状態の定義

- 実装済み: Terraformに定義があり、apply結果が共有されている。
- コード確認済み: 静的な設定を確認した。実際の拒否や配信成功を意味しない。
- 結果共有済み: 利用者が実行結果を共有した。今回の再実行ではない。
- Simulation確認済み: 指定したPolicy・Action・Resource・contextでの評価結果。実APIの拒否や、未入力のresource policyを含む全権限の証明ではない。
- 記録不足: 結果は共有済みだが、文書への集約が不足している。
- 未検証・未観測: 確認結果がない。記録追記だけで完了扱いにしない。

## 2. 追加実装が必要な事項

| 項目 | 現状 | 完了に必要な作業 |
|---|---|---|
| Phase 7のNetwork Baseline | 設計合意済み・未実装 | 2 AZのPublic／Isolated Subnet、明示Route、Default SG hardening、VPC Flow Logs、専用S3およびConfig連携を構築・検証する |
| Phase 7のACCEPT／REJECT試験 | 設計合意済み・未実施 | Public IPv4なしの一時EC2-A／Bを作成し、許可Portと非許可PortのFlow LogをEC2-B側ENIで確認後、全一時resourceを削除する |
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
| Configuration Item数・Rule評価数・実料金 | 少数resourceの概算のみ | 計測期間・集計範囲を決めて観測し、ADR 0008と費用設計の見積りを更新する |
| MFA未認証での実AssumeRole拒否 | 実Trust PolicyのMFA条件を確認し、手作業で同条件を記述したテストPolicyはfalse=implicitDeny、true=allowed | 条件単体の試験として記録。実Role全体のnegative testは未実施であり、完了条件への代替として認めるかはPhase 8で判断する |
| ConfigEvidenceReadRoleのS3変更API拒否 | 対象prefix内の仮想object ARNでGetObject=allowed、PutObject/DeleteObject=implicitDeny | identity policyのSimulation確認済み。実Put/Delete・bucket設定変更は未試験。実データを変更しない検証方法と必要範囲をPhase 8で判断する |
| 現在のIAM権限全体 | コード管理部分と一部手動変更の報告のみ | リスク再評価時に、手動管理policy・trust・権限合成を含め確認する。今回の文書照合で全AWS権限を監査済みとはしない |

## 5. 確認済みの結果と確認範囲

今回の再照会と過去の共有結果を区別する。詳細は非公開作業記録へ集約する。

| 項目 | 共有済みの結果・範囲 |
|---|---|
| Config Recorder | Recording=True、LastStatus=SUCCESS。コード上は10種類・CONTINUOUS |
| Config配送 | 2026-09-11再照会でSnapshot・HistoryともSUCCESS、StreamはNOT_APPLICABLE。SNS未採用の構成と整合 |
| 実object暗号化 | HeadObjectのaws:kms、ExpectedKeyMatch=True |
| 7 Managed Rules | 2026-09-11の同一API照会で、プロジェクトの7 RuleすべてCOMPLIANT |
| Resource Timeline | 初期Configuration eventとCompliance eventを確認。既存設定からの意図的な変更前後比較は未検証 |
| 権限制御 | MFA付きAssumeRoleと対象prefix一覧は成功。DescribeKey、Decrypt、別RoleへのAssumeRole、対象外prefix一覧はAccessDenied（過去の確認）。S3 identity policyとMFA条件単体のSimulation結果は上記の未実施範囲と併記する |
| negative test用一時権限の撤去 | `iam:SimulateCustomPolicy`と`iam:SimulatePrincipalPolicy`を一時付与して評価後に削除。Simulation APIが再びAccessDeniedとなることを確認 |
| Terraform整合 | 2026-09-11にenvs/devでterraform plan -input=false -no-color -detailed-exitcodeを再実行。終了コード0、No changes。applyは行っていない |
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

## 6. 証跡の管理と終了条件

- 公開文書には設計・確認方法・匿名化した状態を記載する。
- 個別実行結果はGit対象外のPhase別作業記録に集約し、アカウントID・実ARN・認証情報・object本文は公開しない。
- Phase 6は主要動作確認済みだが、ADR 0008の完了条件をすべて満たしたとは扱わない。
- Phase 8の統合試験・復旧・後片付けは別途計画する。この文書は全Phaseの試験仕様が完成したことを意味しない。

## 7. Phase 7の試験仕様

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
Flow Logsはreal-time packet captureではないため、S3到着を確認する前にtest resourceを削除しない。

### 7.3 Cleanup確認

- test flagを通常値へ戻してapplyし、EC2-A／B、root EBSおよびtest用Security Groupを削除する。
- EC2、EBS、ENI、Public IPv4およびtest用Security Groupの残存がないことをread-only APIで確認する。
- Flow Logs、専用S3、VPC、Subnet、Route Tableおよびhardening済みDefault SGはBaselineとして保持する。
- Config Ruleが既存Default VPC等を`NON_COMPLIANT`とした場合は別findingとして記録し、Phase 7だけの判断で変更・削除しない。
- 最終`terraform plan`が`No changes`になることを確認する。
- Phase 7.5を実施する場合は、このCleanupとPhase 7完了後に別試験計画を作る。

## Activity Log

- 2026-09-12: Phase 7の2 AZ Network Baseline、Public／Isolated Subnet、Flow Logs専用S3、Config連携、および一時EC2-A／BによるACCEPT／REJECT試験を合意済み設計として追加。Phase 7.5のAWS Network Firewallは常設せず、別ADR・1 AZ・事前費用承認・同日destroyを条件とするOptional Labへ分離した。
- 2026-09-11: 文書整合性監査でdev planのNo changes、Recorder稼働、Snapshot/History配送成功、7 RuleのCOMPLIANTを再確認。Budget Actionの説明とSimulationの証明範囲を修正し、未実施の実API試験を残作業へ戻した。
- 2026-09-11: KMS破壊的権限の縮小について、AWS適用、Key Policy確認、一時権限撤去、最終No changesを反映した。
- 2026-09-11: CloudTrail用S3のHTTPS必須化を適用し、Terraform整合とログ配送継続の確認結果を反映した。
- 2026-09-11: Phase 6のMFA条件とS3読取り専用境界をPolicy Simulatorでnegative testし、一時的なSimulation権限の撤去まで確認した。Role Trust Policy自体はSimulator非対応のため、MFA条件を同等のテストPolicyでfalse/true評価した。

- 2026-09-10: コード・ADR・共有結果を照合し、追加実装、採否判断、未検証・未観測、記録不足を分類。AWS設定・Terraformコードの変更や試験実行は行っていない。
