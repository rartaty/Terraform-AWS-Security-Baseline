# 試験計画・確認状況と残作業

- 同期日: 2026-09-11
- 対象: dev環境、Phase 3〜6を中心とした現行構成
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
| Phase 7のVPC・Flow Logs | 未着手 | 別Phaseとして設計・構築・検証する |

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

## Activity Log

- 2026-09-11: 文書整合性監査でdev planのNo changes、Recorder稼働、Snapshot/History配送成功、7 RuleのCOMPLIANTを再確認。Budget Actionの説明とSimulationの証明範囲を修正し、未実施の実API試験を残作業へ戻した。
- 2026-09-11: KMS破壊的権限の縮小について、AWS適用、Key Policy確認、一時権限撤去、最終No changesを反映した。
- 2026-09-11: CloudTrail用S3のHTTPS必須化を適用し、Terraform整合とログ配送継続の確認結果を反映した。
- 2026-09-11: Phase 6のMFA条件とS3読取り専用境界をPolicy Simulatorでnegative testし、一時的なSimulation権限の撤去まで確認した。Role Trust Policy自体はSimulator非対応のため、MFA条件を同等のテストPolicyでfalse/true評価した。

- 2026-09-10: コード・ADR・共有結果を照合し、追加実装、採否判断、未検証・未観測、記録不足を分類。AWS設定・Terraformコードの変更や試験実行は行っていない。
