# 5アプリ TestFlight 提出設定

このワークフローは `Portfolio TestFlight` を手動実行し、選択した1アプリだけを署名・アーカイブ・TestFlightへアップロードします。リリースビルドやストアへの公開は実行しません。

## Apple側で先に作成するもの

各Bundle ID（`jp.egawa.framedrop`、`jp.egawa.qrkeeper`、`jp.egawa.handyprint`、`jp.egawa.meetingspark`、`jp.egawa.focuspocket`）について、App Store Connectのアプリレコード、App ID、App Store配布用Provisioning Profileを1つずつ作成します。課金商品は各アプリで同じSubscription Group内に月額・年額を作成し、コードのProduct IDと一致させます。

## GitHub Actions Secrets

Lightlyと共通で使う既存の秘密値: `BUILD_CERTIFICATE_BASE64`、`P12_PASSWORD`、`APPLE_TEAM_ID`、`APPSTORE_KEY_ID`、`APPSTORE_ISSUER_ID`、`APPSTORE_PRIVATE_KEY`。

さらに下記をリポジトリSecretsへ追加します。`*_PROFILE_BASE64`は対応する`.mobileprovision`をBase64化した値、`*_PROFILE_NAME`はApple Developer上のプロファイル名です。

| アプリ | Profile secrets |
| --- | --- |
| FrameDrop | `FRAMEDROP_PROFILE_BASE64`, `FRAMEDROP_PROFILE_NAME` |
| QR控え帳 | `QRKEEPER_PROFILE_BASE64`, `QRKEEPER_PROFILE_NAME` |
| 手渡しプリント | `HANDYPRINT_PROFILE_BASE64`, `HANDYPRINT_PROFILE_NAME` |
| 会議前メモ | `MEETINGSPARK_PROFILE_BASE64`, `MEETINGSPARK_PROFILE_NAME` |
| 集中ポケット | `FOCUSPOCKET_PROFILE_BASE64`, `FOCUSPOCKET_PROFILE_NAME` |

## 実行順

1. StoreKit商品、価格、無料トライアル、レビュー用スクリーンショットを各アプリで入力する。
2. `Portfolio TestFlight`から対象アプリを選び、TestFlightへ1本ずつアップロードする。
3. Sandboxで購入・復元・無料枠の上限を確認する。
4. App Review提出は、各アプリのApp Store Connect画面でメタデータ・スクリーンショット・審査メモを確認してから実行する。

GitHub ActionsのアップロードはTestFlightへの外部提出操作になるため、実行直前に対象アプリと送信内容を再確認します。
