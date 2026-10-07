# Phase 7.5: Private HTTP Network Firewall Lab

別root・別stateで既存P7 VPCを参照する短期Lab。
設計・停止条件は[ADR 0011](../../docs/decisions/0011-test-network-firewall-with-private-http-traffic.md)を参照する。
コード実装・mockテストと、実AWSの認可・通信・ログ配送は別の確認である。

## 構成

- 同一AZのClient／Inspection／Server Subnetと各専用Route Table。
- Client→Serverと応答の両経路を、同じFirewall Endpointへ向ける。
- SGは相手Private IP `/32`へのTCP 8080だけ。SSH・SSM・Public IPv4・NAT・外向けdefault routeなし。
- 固定AL2023 AMI、EC2 2台、t3.micro・CPU credits standard・IMDSv2、暗号化gp3 8 GiB・終了時削除。
- STRICT_ORDERの試験URI署名をalert→dropへ変更。試験対象だけを遮断し、通常URIは許可するLab用policy。
- ALERT／FLOWを専用CloudWatch Logsへ配送、保持1日。配送resource policyは別管理経路で設定済みの前提。
- Clientは各HTTP要求を新規TCP接続で実施し、UTC時刻・送信元Port・HTTP結果をconsoleへ記録する。
  約35分で通信を終了。Server serviceは1時間で終了するが、どちらもEC2課金を停止しない。

## 事前確認

Role・Boundary・Budget Action、aws/ebs key、Amazon所有AMI、実SubnetとのCIDR非重複、
AZ・必要quota・現在費用・終了まで作業できる時間を確認する。
Firewall/EC2作成前に全体費用と撤去期限の承認を取る。
state keyは`labs/phase75/terraform.tfstate`、default workspaceだけを使用する。
dev stateの読取りやIAM管理はLab Roleの権限へ加えない。

AWS ProviderはEC2作成後にlaunch template IDのtagを読むため、`ec2:DescribeTags`も必要。
Network許可の東京限定Describe StatementとBoundaryの両方へ含める。Launch Templateの
作成権限を追加する理由ではない。DescribeTagsはresource-level permission非対応のため
Resourceは`*`となり、東京内のLab以外のtag metadataも参照できる例外が残る。
CLIのfilterは取得結果を絞るが、IAMの権限上限ではない。
草案の更新だけでAWSの実policyが更新済みとは扱わず、再生成・AWS validation・実本文照合を行う。

`scripts/New-Phase75LabInputs.ps1`は実識別子からbackend.hclとterraform.tfvarsを
リポジトリ外の一時フォルダーへ生成する。識別子・入力ファイル・plan JSON・証跡をGitへ追加しない。
非公開ファイルは試験終了まで維持し、消失した場合は同じ入力で再生成する。

## 初期化とLog Groupの引継ぎ

以下は設定例であり自動実行しない。非公開入力生成結果を`$phase75Inputs`へ保存した前提。
初期化前にbackend key/profileをレビューする。初期化エラーを回避するために包括的S3権限を追加しない。

```powershell
terraform -chdir=envs/phase75 init -reconfigure "-backend-config=$($phase75Inputs.BackendConfigPath)"
terraform -chdir=envs/phase75 workspace show
```

workspaceがdefaultでなければ停止する。既存stateがある場合は、その所有範囲を確認してから進む。

Firewall Policyは一時設定Roleで初期作成し、このLab stateへimportする。
Lab Roleの通常許可とBoundaryにはCreateFirewallPolicy/ListRuleGroupsを含めない。
Rule Groupだけのtarget plan/apply、一時設定Roleでのdry-runと実作成、Policyのimport、
全体planでPolicy差分なしの確認、一時Role撤去の順で進める。入力は
`scripts/New-Phase75FirewallPolicyInput.ps1`で非公開生成し、Rule Group・Policyの固定名ARN、
STRICT_ORDER・priority・default actions・タグをコードと照合する。
targetは初期引継ぎの例外であり、通常の全体planの代用にはしない。
ALERT/DROPはUpdateRuleGroupだけで行い、Policyの変更/再作成が必要なら設定経路へ戻る。

手動作成済みLog Group 2個をこのstateへimportする。まだFirewall/EC2は作成しない。
Windows PowerShellからのindex付きaddressは、内部の二重引用符もescapeする。

```powershell
terraform -chdir=envs/phase75 import "-var-file=$($phase75Inputs.TfvarsPath)" 'aws_cloudwatch_log_group.lab[\"alert\"]' /aws/vendedlogs/network-firewall/phase75-alert
terraform -chdir=envs/phase75 import "-var-file=$($phase75Inputs.TfvarsPath)" 'aws_cloudwatch_log_group.lab[\"flow\"]' /aws/vendedlogs/network-firewall/phase75-flow
terraform -chdir=envs/phase75 plan "-var-file=$($phase75Inputs.TfvarsPath)"
```

2026-10-08の実行ではtag付きCreateLogGroupがAccessDeniedとなった一方、CLIでtagなし
STANDARD作成→import→Terraformの対象Log Groupだけの更新は成功した。
この経路を使う場合も既存同名Groupを再取得し、重複作成を避ける。更新planが保持1日と
Labタグだけであることを確認し、保持期間未設定のまま放置しない。正確な拒否原因は未確定で、
成功した回避手順を理由にlogs:*等へ権限を広げない。
配送resource policyは別の短期限Roleで事前設定し、ACCOUNT/RESOURCE scopeの既存内容と
設定後の両本文を照合する。Role撤去と実配送の成功は別の確認である。

初回planはLab新規resourceとimport済みLog Groupのtag等だけが対象であることを確認する。
既存P7 VPC/Subnet/Route、IAM、Budget、NAT/EIP、追加customer KMS keyを変更しない。
planの件数だけで安全と判断しない。AMI、EBS key、IMDSv2、credits、暗号化、容量、public IP、経路と所有範囲も照合する。
paid applyは明示承認後に実行する。最初の課金resource作成開始から2時間以内に撤去し、
終了30分前に試験を打ち切る。タイムアウト・ログ遅延・認可エラーでも延長しない。

## ALERT／DROP比較

最初はrule_action=alertで作成し、Firewall READY・各同期状態・配送設定を再取得する。
Client consoleの/health・/phase75-probeの既知200応答と、署名750001のalertを照合する。
ログのdefault alertを試験署名と混同しない。Clientは継続して新しい接続を作る。

```powershell
terraform -chdir=envs/phase75 plan "-var-file=$($phase75Inputs.TfvarsPath)" -var=rule_action=drop
```

変更対象がRule Groupのrules_stringだけで、EC2・SG・Route等の置換/変更がないことを確認してから適用する。
実適用でも同じ-var指定を使い、同期完了後の新規TCP接続を比較する。
試験URIの正常応答なしと同じ署名のblocked記録、前後の通常URIの既知200応答を照合する。
Timeoutだけで合格にしない。IP・Port・UTC時刻・signature/actionを含む原本は非公開保存する。
DROP後のplanでは`-var=rule_action=drop`を維持するか、非公開tfvarsのrule_actionをdropへ更新して、意図しないALERT復帰を防ぐ。

## 撤去

証跡回収の成否にかかわらず期限を守る。Lab stateの所有範囲を再確認する。

```powershell
terraform -chdir=envs/phase75 plan -destroy "-var-file=$($phase75Inputs.TfvarsPath)" -var=rule_action=drop
```

破棄planがLabだけを対象としていることを確認し、削除の明示承認後にdestroyする。
Firewall/Endpoint、EC2/EBS/ENI、SG、Subnet、Route Table、Rule Group/Policy、専用Log Groupを
APIで再取得して残存確認する。Log Group削除前に必要な証跡を取得する。
ログ配送resource policyの残存と撤去は保護された管理経路で確認する。
Lab用IAM・Budget Actionの撤去は別の変更であり、Baseline用の権限やActionを削除しない。

EC2作成後のreadエラーでもEC2が稼働している場合がある。再applyせず、state一覧とAWSの
Labタグ・ID・状態を照合する。必要なら既存の限定TerminateInstancesで確認済みLab EC2を終了する。
DescribeTags不足でdestroyのrefreshも止まる場合、`-refresh=false`は古いstateを使う例外となる。
stateの全対象と実AWSの所有範囲・依存関係を照合し、保存したdestroy planを確認してから判断する。
state外の作成物も別途撤去する。stateを消すことやtarget planのNo changesを撤去証明にしない。
失敗/別操作後のsaved planは再利用せず、同時Terraform操作を止めて再planする。

## 静的・mock検証

```powershell
terraform -chdir=envs/phase75 init -backend=false
terraform -chdir=envs/phase75 validate
terraform -chdir=envs/phase75 test
```

tests/lab.tftest.hclは全AWS Providerをmock化する。テスト内のapply/teardownはmockだけで、
実AWSのresourceを作成・削除しない。これだけではAWSのIAM認可、Suricata署名受理、READY、
ログ配送、HTTP試験、実際の撤去成功を証明しない。
