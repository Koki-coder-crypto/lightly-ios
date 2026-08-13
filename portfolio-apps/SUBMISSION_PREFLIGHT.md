# 6アプリ 提出前チェック

対象: 持ち物期限帳、Wi-Fiメモ、おうちメンテ、出発チェック、荷物メモ、割り勘メモ。

各アプリは端末内に記録を保存・削除できます。無料枠に達すると新規追加を止め、Pro画面へ案内します。外部アカウントは不要です。割り勘メモは合計と人数から1人あたりの金額を計算し、持ち物期限帳は期限までの日数を表示します。

## Macでの最終確認

各アプリのフォルダで次を実行し、Xcodeで生成されたプロジェクトを開きます。

```sh
xcodegen generate
xcodebuild -scheme "<アプリ名>" -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

実機またはシミュレータで、(1) 空タイトルが保存できないこと、(2) 追加・削除・再起動後の保存、(3) 無料枠到達時の案内、(4) 購入復元ボタン、を確認します。

## App Store Connectで必要な設定

- 各 `APP_STORE_SUBMISSION.md` のBundle IDでアプリを作成する。
- 月額・年額の自動更新サブスクリプションを、各ファイル記載のProduct IDで作成する。
- プライバシーポリシーに `https://koki-coder-crypto.github.io/lightly-ios/privacy.html` を設定する。
- スクリーンショット、価格、トライアル条件、レビュー用メモを入力してTestFlightに提出する。製品がReady to Submitになるまでは、購入画面に価格は表示されない。

このリポジトリには署名用のApple Developer Team、証明書、App Store Connectの権限情報を保存しません。したがって、上記のMacでの署名ビルドとTestFlightアップロードが提出直前の残作業です。
