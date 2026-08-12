# Photo Cleaner: Review & Remove — 提出メモ

## App Store Connect

- 表示名（日本語）: `Photo Cleaner: Review & Remove`
- 表示名（英語）: `Photo Cleaner: Review & Remove`
- サブタイトル（日本語）: `スクショ・動画を確認して安全に整理`
- サブタイトル（英語）: `Review photos before removing them`
- Bundle ID: `jp.egawa.roomroll`
- SKU: `roomroll-ios-001`
- カテゴリ: ユーティリティ
- 年齢制限: 4+
- サブスクグループ: `Photo Cleaner Pro`
- 商品ID: `jp.egawa.roomroll.pro.monthly` / `jp.egawa.roomroll.pro.yearly`
- サポート: `https://koki-coder-crypto.github.io/lightly-ios/support.html`
- プライバシー: `https://koki-coder-crypto.github.io/lightly-ios/privacy.html`

## 掲載原稿（日本語）

Photo Cleanerは、スクリーンショット、長い動画、最近追加した大きい写真を端末内で見直すためのストレージ整理アプリです。候補を確認して選んだものだけを写真アプリの「最近削除した項目」へ移動します。自動削除、アカウント登録、写真のアップロードはありません。iOSが管理するシステム領域や他アプリのデータを消去する機能はありません。

- スクリーンショットをまとめて確認
- 最近の大きい写真と長いビデオを優先表示
- 削除前に一件ずつ選択・確認
- 解析は端末内で完結

キーワード: `写真整理,ストレージ,容量,スクリーンショット,動画,削除,アルバム,写真`

## Review Notes

サインインは不要です。初回画面で写真ライブラリのアクセス理由を表示し、ユーザーが許可した範囲だけを端末内で解析します。Photo Cleanerは写真を外部サーバーに送信しません。削除はユーザーが項目を選択し、確認ダイアログで承認した場合だけ実行され、写真アプリの「最近削除した項目」に移動します。レビューでは写真ライブラリへの読み書き許可後、「スクリーンショット」または「最近の大きい写真」を開いて項目を選択してください。

## 英語（米国）掲載原稿

**Description**

Photo Cleaner: Review & Remove is a private, on-device way to review the photos that tend to accumulate: screenshots, long videos, and recently added large photos. Open a category, inspect each item, and select only what you no longer need. Before anything is removed, you confirm it; iOS moves it to Recently Deleted in Photos.

There is no account, cloud upload, automatic deletion, or access to other apps' data. Photo Cleaner cannot clear iOS system storage. The free plan includes 30 reviewed removals per calendar month. Optional Photo Cleaner Pro unlocks unlimited reviews.

**Keywords**: `photo,cleanup,storage,screenshot,video,organize,declutter`

## 提出前の実機チェック

- 初回表示で「端末内で処理」「自動削除なし」が読めること
- 写真アクセスの「すべて」「選択した写真」で候補を表示できること
- 1件と複数件の削除が、確認後にPhotosの「最近削除した項目」へ移ること
- 無料枠30件、月替わりのリセット、Pro購入、復元、解約後の無料枠をSandboxで確認すること
- 英語（米国）で、ホーム、候補一覧、削除確認、Pro画面を6.7インチiPhoneで撮影すること
