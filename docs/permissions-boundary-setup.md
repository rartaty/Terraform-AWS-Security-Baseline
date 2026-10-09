# Permissions BoundaryとIAM管理経路

通常のTerraform実行とIAM権限変更を別Roleに分け、日常の操作範囲を制限する。
Boundaryはidentity policyが付与できる権限の上限であり、単独で操作権限を与えない。

## 構造と制限

| 対象 | 用途 | 主な制限 |
|---|---|---|
| TerraformExecutionRole | Baselineの構築・参照 | 対象サービス・Regionの上限。閲覧Roleの再作成には対応Boundaryを指定 |
| CloudTrailLogReadRole | 監査ログの閲覧 | 専用prefixの読取りと、指定key・暗号化contextでの復号 |
| ConfigEvidenceReadRole | Config履歴の閲覧 | 専用prefixの読取り。現行のKMS Denyは維持 |
| BaselineIamPolicyEditorRole | 実行Roleのinline policy編集 | 指定Roleのinlineのみ。自己変更、Trust変更、Boundary変更、managed policy編集・付け外しは許可しない |
| Phase75LabExecutionRole | 短期Firewall Lab | Baselineから分離した専用Boundary。初期設定は期限付きの別Roleへ分離 |

管理Roleへ広いIAM管理権限を付けず、Boundaryの変更は初期管理・回復経路に留める。
Budget用Deny policyも日常のIAM編集対象から外す。
同じoperatorが各Roleを使う構成であり、別人物による承認や端末侵害への隔離を保証するものではない。

Boundaryは通常許可のすべてのResource／Conditionを複製していない。
上限内の対象範囲を通常policyで広げられる部分や、参照Actionのwildcardは見直し対象となる。
resource policy、Role Trust、PassRole等の別経路も含めて確認し、
Boundary導入だけを全実効権限の最小化完了とは扱わない。

## 設定と変更管理

- 公開JSONはplaceholder版とし、実ARN・account ID・監査結果・生成JSONはGitへ保存しない。
- `scripts/Export-BoundaryAudit.ps1`で指定対象の設定を読み取り、Git対象外の`learning-records/evidence/`へ保存する。書込み前にGit除外と未追跡を確認する。一時監査許可は作業後に撤去する。
- `scripts/New-BoundaryPolicyFiles.ps1`で非公開の実値版を生成する。JSON・文字数検査は実認可検証の代用ではない。
- 閲覧RoleのBoundaryはdevの非公開変数で維持する。移行後に値をnullへ戻すとBoundary削除がplanされるため、意図せず戻さない。
- 新しいActionを追加する際は通常許可とBoundaryの双方を確認し、MFA付きの新規session、plan、必要な許可／拒否を検証する。
- rootは初期設定・回復に限定し、MFAを使用する。日常の構築・編集には分離したRoleを使う。

## 確認結果と限界

2026-10-07に実行Roleと閲覧RoleのBoundary設定を確認した。
dev・bootstrapの通常planはNo changesだった。

| 確認 | 結果 | 限界 |
|---|---|---|
| Boundary比較 | 一時Roleの同じ通常Allowで、設定前はVPC参照・IAM要約取得が成功。設定後は東京のVPC参照が成功し、IAM要約取得はBoundaryのAllow不足で拒否 | 指定Actionの比較であり、全経路監査ではない |
| CloudTrail閲覧 | 許可prefixの一覧取得に成功 | GetObject・KMS復号・上限外操作の実試験は未実施 |
| Config閲覧 | Boundary設定を確認 | 一覧取得の結果は未確認 |
| IAM編集Role | 接続、対象Roleの参照、一時inlineの作成・取得・削除に成功。対象外Role参照は明示Deny | 自己変更・Trust変更・Boundary付替え・policy version変更の網羅的な実拒否試験は未実施 |
| 後片付け | 一時検証Role・一時監査許可を削除 | 削除後の全対象の不在API確認は未実施 |

planの成功は作成・変更・最終destroyの全権限を保証しない。
Phase 7.5の専用IAMと残確認は[Lab手順](../envs/phase75/README.md)、
Baselineの残確認と終了条件は[試験計画](05_test_plan.md)で管理する。

## 根拠

- [Permissions Boundaryの評価と委任](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_boundaries.html)
- [Boundaryを外す・変更する経路の保護](https://aws.amazon.com/blogs/security/when-and-where-to-use-iam-permissions-boundaries/)
- [root userの運用](https://docs.aws.amazon.com/IAM/latest/UserGuide/root-user-best-practices.html)
