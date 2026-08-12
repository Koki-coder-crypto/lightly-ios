# App Store Connect 最終設定

このアプリは、GitHub ActionsからTestFlightへビルドを送信できる構成です。以下はApple Accountの保有者のみが完了できる操作です。

## 先に一度だけ済ませる設定

1. App Store ConnectのBusinessでPaid Applications Agreementに同意し、税務・口座情報を入力する。
2. App Store Connectで新規Appを作成する。
   - 名前: `Lightly：写真を軽く`
   - 主言語: 日本語
   - Bundle ID: `jp.egawa.lightly`（使用不可なら`project.yml`も変更する）
   - SKU: `lightly-ios-001`
3. サブスクリプショングループ`Lightly Pro`を作成し、次の自動更新サブスクリプションを追加する。
   - `jp.egawa.lightly.pro.monthly` — 月額300円
   - `jp.egawa.lightly.pro.yearly` — 年額2,000円
4. 各プランに日本語表示名・説明・審査用スクリーンショットを設定する。
5. `STORE_LISTING.md`の原稿とGitHub PagesのURLをApp Store Connectへ入力する。

## 提出前の実機確認

- 「きれい」「おすすめ」「最小」で写真を軽量化できる
- 圧縮後のサイズが表示され、共有シートで保存できる
- 写真がネットワークへ送信されない
- 無料枠30枚とPro購入・購入復元が動作する
- iPhoneの文字サイズを最大にしても操作できる

## 審査時に送る内容

- Support URL: `https://Koki-coder-crypto.github.io/lightly-ios/support.html`
- Privacy Policy URL: `https://Koki-coder-crypto.github.io/lightly-ios/privacy.html`
- App Review Notes: `STORE_LISTING.md`の「審査用メモ」
