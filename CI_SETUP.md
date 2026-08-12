# Macなし・追加費用なしの提出設定

公開GitHubリポジトリではGitHub Actionsの標準macOSランナーを無料で使えます。ワークフローは、通常は署名なしビルドだけを実行し、手動実行時だけTestFlightへ提出します。

## あなたが一度だけ行うこと

1. GitHubに**公開**リポジトリを作成し、このフォルダをpushします。コードを非公開にしたい場合、無料枠ではmacOSランナーに利用時間の制限があるためこの方法は使えません。
2. Apple DeveloperのCertificates, Identifiers & Profilesで、Bundle ID `jp.egawa.lightly`（使用可能なら）を登録し、App Store配布用のProvisioning Profileを作成します。重複していたら、固有のIDに変更して`project.yml`も同じIDにします。
3. App Store Connectで同じBundle IDのアプリレコードを作成します。これはアップロード前の必須条件です。
4. App Store ConnectのUsers and Access → Integrationsで、App Manager権限のAPI Keyを発行します。`.p8`は一度だけダウンロードできるため安全に保存してください。APIの利用申請が未承認なら、先にAccount Holderが申請します。
5. GitHubのRepository Settings → Secrets and variables → Actionsに次を登録します。秘密鍵や証明書をリポジトリへcommitしないでください。

| Secret | 値 |
|---|---|
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `PROFILE_NAME` | Provisioning Profileの表示名 |
| `BUILD_CERTIFICATE_BASE64` | Distribution certificateの`.p12`をBase64化した値 |
| `P12_PASSWORD` | `.p12`作成時のパスワード |
| `BUILD_PROVISION_PROFILE_BASE64` | `.mobileprovision`をBase64化した値 |
| `APPSTORE_KEY_ID` | App Store Connect API Key ID |
| `APPSTORE_ISSUER_ID` | Issuer ID |
| `APPSTORE_PRIVATE_KEY` | `.p8`の内容全体 |

配布証明書用のCSR・秘密鍵・`.p12`はWindowsでもOpenSSLで作れます。秘密鍵を失うと証明書を使えないため、暗号化して保管してください。

## 提出

GitHub Actionsの`iOS`を開き、`Run workflow`で「TestFlightへ送信する」をオンにして実行します。TestFlightで実機確認後、App Store Connectの審査提出だけはアカウント保有者が最終承認します。
