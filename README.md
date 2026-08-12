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

## サブスクリプション

Lightlyは無料ダウンロードです。無料プランでは毎月30枚まで圧縮でき、Proは自動更新サブスクリプション（月額・年額）のみで提供します。買い切り商品は提供しません。

- `jp.egawa.lightly.pro.monthly`
- `jp.egawa.lightly.pro.yearly`

初回トライアルを提供する場合は、期間と終了後の更新価格を購入前に明示します。購入の復元、利用規約、プライバシーポリシーへの導線をアプリ内に設けています。

## 公開前に必ず設定する箇所

- `jp.egawa.lightly`: 固有のBundle Identifier
- App Store ConnectのサポートURLとプライバシーポリシーURL
- App Store掲載画像・アイコン
- App Store Connect上の月額・年額商品、トライアル、審査用説明

Apple側での最終設定は [APP_STORE_SETUP.md](APP_STORE_SETUP.md) を参照してください。

価格とトライアルの設定は [LIGHTLY_SUBSCRIPTION_PLAN.md](LIGHTLY_SUBSCRIPTION_PLAN.md) を参照してください。
