# 試験計画・確認状況と残作業

- 同期日: 2026-09-10
- 対象: dev環境、Phase 3〜6を中心とした現行構成
- 根拠: Terraformコード、ADR、利用者が共有した実行結果、非公開作業記録
- 今回の文書同期ではAWS実環境へ再照会していない。現在の稼働を再検証した記録ではない。

## 1. 状態の定義

- 実装済み: Terraformに定義があり、apply結果が共有されている。
- コード確認済み: 静的な設定を確認した。実際の拒否や配信成功を意味しない。
- 結果共有済み: 利用者が実行結果を共有した。今回の再実行ではない。
- 記録不足: 結果は共有済みだが、文書への集約が不足している。
- 未検証・未観測: 確認結果がない。記録追記だけで完了扱いにしない。

## 2. 追加実装が必要な事項

| 項目 | 現状 | 完了に必要な作業 |
|---|---|---|
| CloudTrail用S3のHTTPS必須化 | bucket policyにSecureTransportによる拒否がない | 設計済み要件に沿うpolicy追加、plan確認、apply、配信が継続することとpolicyの検証。今回は実装しない |
| Phase 7のVPC・Flow Logs | 未着手 | 別Phaseとして設計・構築・検証する |

## 3. 採否判断が必要な事項・見送り済みの事項

| 項目 | 状態 | 次の判断 |
|---|---|---|
| KMS alias | 当初計画にあるがコードにない | 追加するか今回対象外とするかを利用者が判断する。不要と決めたことにはしない |
| CloudWatch Logs転送 | ADR 0005で見送り済み | 今回の完了条件から除外。再採用する場合だけ目的・料金・監視要件を再判断する |
| KMS残存riskと復旧手順 | 共有keyが稼働中。従来の未構築扱いは不適切 | 現行管理権限、CloudTrail・Config双方への影響、復旧手順を評価する。対策追加の要否はその後に判断する |

## 4. 未検証・未観測の事項

| 項目 | 現在確認できること | 残作業 |
|---|---|---|
| ConfigEvidenceReadRoleのS3変更拒否 | コードに書込み・削除・設定変更のAllowがない | ADR 0008の実拒否確認結果は未確認。対象と安全な方法を合意して検証する。実データの削除・上書きを試験として勝手に実行しない |
| MFAなしのAssumeRole拒否 | MFA必須条件をコード確認。MFA付き成功は結果共有済み | negative testは未確認。MFA付き成功と区別して記録する |
| Configuration Item数・Rule評価数・実料金 | 少数resourceの概算のみ | 計測期間・集計範囲を決めて観測し、ADR 0008と費用設計の見積りを更新する |
| 現在のIAM権限全体 | コード管理部分と一部手動変更の報告のみ | リスク再評価時に、手動管理policy・trust・権限合成を含め確認する。今回の文書照合で全AWS権限を監査済みとはしない |

## 5. 確認済みで記録整理が必要な事項

以下は追加実装を要する問題ではない。共有済み結果を非公開作業記録へ集約する。

| 項目 | 共有済みの結果・範囲 |
|---|---|
| Config Recorder | Recording=True、LastStatus=SUCCESS。コード上は10種類・CONTINUOUS |
| Config配送 | delivery channelの存在と配信SUCCESS。どの配送情報かは元出力で確認可能な範囲だけ記す |
| 実object暗号化 | HeadObjectのaws:kms、ExpectedKeyMatch=True |
| 7 Managed Rules | 最初の6件COMPLIANT、account BPAは定期評価版への変更後COMPLIANT。7件同時の再取得を今回行ったとはしない |
| Resource Timeline | 初期Configuration eventとCompliance eventを確認。既存設定からの意図的な変更前後比較は未検証 |
| 権限制御 | MFA付きAssumeRoleと対象prefix一覧は成功。DescribeKey、Decrypt、別RoleへのAssumeRole、対象外prefix一覧はAccessDenied |
| Terraform整合 | 利用者からapply成功とNo changesの結果共有済み。現在の再planは今回未実施 |

AccessDeniedという結果だけから、拒否原因が必ず特定のexplicit Denyだったと断定しない。
policyの静的確認とエラーで確認できたAction、実行Role、対象を対応させて記録する。

## 6. 証跡の管理と終了条件

- 公開文書には設計・確認方法・匿名化した状態を記載する。
- 個別実行結果はGit対象外のPhase別作業記録に集約し、アカウントID・実ARN・認証情報・object本文は公開しない。
- Phase 6は主要動作確認済みだが、ADR 0008の完了条件をすべて満たしたとは扱わない。
- Phase 8の統合試験・復旧・後片付けは別途計画する。この文書は全Phaseの試験仕様が完成したことを意味しない。

## Activity Log

- 2026-09-10: コード・ADR・共有結果を照合し、追加実装、採否判断、未検証・未観測、記録不足を分類。AWS設定・Terraformコードの変更や試験実行は行っていない。
