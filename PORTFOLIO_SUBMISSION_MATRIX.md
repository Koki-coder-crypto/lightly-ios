# 10アプリ 提出マトリクス（旧案）

この10本は提出対象ではない。提出に進めるのは、固有機能を持つ5本に再設計した [FIVE_APP_PORTFOLIO.md](FIVE_APP_PORTFOLIO.md) のみ。

各プロジェクトは独自のBundle ID、月額・年額のStoreKit商品ID、App Icon、提出メモを持つ。すべて無料ダウンロードで、3日トライアル付き自動更新サブスクリプション（月額/年額）を使う。

| アプリ | Bundle ID | 月額商品ID | 年額商品ID | 無料の最初の価値 | Proの継続価値 |
| --- | --- | --- | --- | --- | --- |
| 手渡しプリント | `jp.egawa.handyprint` | `jp.egawa.handyprint.pro.monthly` | `jp.egawa.handyprint.pro.yearly` | 月3枚のPDF作成 | 無制限・テンプレート・再出力 |
| 持ち物期限帳 | `jp.egawa.warrantyledger` | `jp.egawa.warrantyledger.pro.monthly` | `jp.egawa.warrantyledger.pro.yearly` | 20件・直近期限 | 無制限・複数通知・月次確認 |
| 会議前メモ | `jp.egawa.meetingspark` | `jp.egawa.meetingspark.pro.monthly` | `jp.egawa.meetingspark.pro.yearly` | 週5件のメモ | 無制限・予定別整理・週次レビュー |
| 出発チェック | `jp.egawa.leavecheck` | `jp.egawa.leavecheck.pro.monthly` | `jp.egawa.leavecheck.pro.yearly` | 3リスト | 無制限・曜日別・通知 |
| QR控え帳 | `jp.egawa.qrkeeper` | `jp.egawa.qrkeeper.pro.monthly` | `jp.egawa.qrkeeper.pro.yearly` | 50件の控え | 無制限・期限通知・バックアップ |
| 割り勘メモ | `jp.egawa.receiptsplit` | `jp.egawa.receiptsplit.pro.monthly` | `jp.egawa.receiptsplit.pro.yearly` | 月5回の精算 | 無制限・履歴・定番グループ |
| 荷物メモ | `jp.egawa.parcelnote` | `jp.egawa.parcelnote.pro.monthly` | `jp.egawa.parcelnote.pro.yearly` | 5件 | 無制限・受取通知・履歴 |
| Wi-Fiメモ | `jp.egawa.wifinotes` | `jp.egawa.wifinotes.pro.monthly` | `jp.egawa.wifinotes.pro.yearly` | 10件 | 無制限・検索・バックアップ |
| おうちメンテ | `jp.egawa.homecare` | `jp.egawa.homecare.pro.monthly` | `jp.egawa.homecare.pro.yearly` | 10件 | 無制限・通知・月次点検 |
| 集中ポケット | `jp.egawa.focuspocket` | `jp.egawa.focuspocket.pro.monthly` | `jp.egawa.focuspocket.pro.yearly` | 1日3セッション | 無制限・履歴・週次レポート |

## 提出前に手動で行うこと

1. Macで各ディレクトリに移動し、`xcodegen generate` を実行する。
2. XcodeでApple Developer Teamを設定し、実機で無料利用・購入・復元を確認する。
3. App Store Connectで各Bundle IDごとに自動更新サブスクリプショングループ、月額・年額、3日トライアルを登録する。
4. 購入画面に表示される商品名・トライアル・更新後の総額を日本語で確認し、プライバシーポリシーと利用規約を登録する。
5. スクリーンショット、サポートURL、プライバシーURL、App Review用の操作説明を登録してTestFlightへ提出する。

この環境にはXcode・署名証明書・App Store Connectへの認証がないため、バイナリの署名・TestFlight/App Storeへの実送信は行っていない。
