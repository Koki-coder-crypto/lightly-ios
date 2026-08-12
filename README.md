# Lightly

写真を端末内だけで一括軽量化する、iOS 17以降向けの日本語ユーティリティアプリです。

## 方針

- 写真・個人情報をサーバーに送信しない
- 登録不要、広告なしの軽快な体験
- Apple標準の操作モデルを踏襲し、既存アプリのUI・素材は流用しない

## Macでの起動

1. Xcode 16以降をインストールします。
2. `brew install xcodegen` を実行します。
3. このフォルダで `xcodegen generate` を実行し、`Lightly.xcodeproj` をXcodeで開きます。
4. Signing & Capabilities で、固有のBundle IdentifierとApple Developer Teamを選びます。

## 公開前に必ず置き換える箇所

- `jp.egawa.lightly`: 固有のBundle Identifier
- App Store ConnectのサポートURLとプライバシーポリシーURL
- App Store掲載画像・アイコン
- 課金を導入する場合のStoreKit Product IDと審査用説明

Apple側での最終設定は [APP_STORE_SETUP.md](APP_STORE_SETUP.md) を参照してください。

## 収益モデル案

無料: 月30枚まで。Pro: 月額300円 / 年額2,000円で無制限・一括処理を提供します。`jp.egawa.lightly.pro.monthly` と `jp.egawa.lightly.pro.yearly` の自動更新サブスクリプションを、App Store Connectで作成してから公開してください。
