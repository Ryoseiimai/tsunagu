# つなぐアプリ 引き継ぎ書

これは個人アプリ「つなぐ」の引き継ぎ書です。このセッションを知らない別のAIセッション、または内容を忘れた本人が読むことを想定しています。現状（2026-09-23時点）は開発・検証が完了し、Web版・iOS版ともに動作確認済みです。

## 背景

- きっかけ: 本人（今井涼晴）の友人・佐藤将大さんとのLINEで「仕事探してる人を、仕事探してくれる人に繋いでくれるアプリ作ろうかなw」という発言から着手（2026-09-22夜）
- 目的: 転職エージェントと正面衝突しない「友達経由の紹介」に絞ったマッチング。個人開発（会社案件ではない）
- 途中で本人から「iOSアプリにしたい」「ロゴも」「人に使ってもらうときは紹介する人が使いやすいように」という追加要望があり、v1（3タブ均等構成）からv2（紹介する人を主役にした役割別UI）へ作り替えた

## 登場人物の設計（v2の核）

3つの役割を想定しています。

1. 紹介する人（主役）
2. 支援する人
3. 仕事を探している人（アプリ不要・リンクを開くだけ）

詳細仕様は `SPEC-v2.md` が正本です。

## 現物と置き場所

すべて `/Users/ryoseiworld/dev/2026-09-22-shokai-app/` 配下です。

- `index.html` — Web版本体。単一HTML、外部ライブラリ・CDN不使用、localStorage保存
- `manual.html` — マニュアル。3人の役割別セクション、インラインSVGの相関図
- `SPEC-v2.md` — 仕様書（正本）
- `ios/` — iOS版。SwiftUI、XcodeGen運用、`project.yml`が正本、bundleId `com.ryoseiworld.tsunagu`
- `logo/tsunagu_icon_v1.png` — ロゴ。gpt-image-2生成、緑地に白い吹き出し2つが鎖状に繋がる意匠
- `shortlink/` — 短縮リンク基盤。Cloudflare Worker + KV、個人アカウント`wrp`で運用
- `shots/` — 検証スクショ多数。`v2/`が最新の役割別通し検証、`prod/`が本番反映後の確認

## 公開・配備状況（2026-09-23時点で全て動作確認済み）

- 公開URL: `https://ryoseiimai.github.io/tsunagu/`（個人GitHub `Ryoseiimai/tsunagu`、GitHub Pages）
- 短縮リンク: `https://tsunagu.densalon.com/s/<4文字コード>` → 302で公開URLへリダイレクト。無料（新規ドメイン購入はしていない。既存の個人ドメイン`densalon.com`のサブドメインをCloudflare Worker custom domainで割り当てただけ）
  - API: `POST https://tsunagu.densalon.com/api/shorten` に `{"s":"...","ref":"...","by":"..."}` または `{"add":"..."}` を投げると `{"code":"k3m9","url":"https://tsunagu.densalon.com/s/k3m9"}` が返る
  - KVネームスペース `TSUNAGU_LINKS`（id: 9d70908e09264fd99905c0d9efbdf380）
- iOS版: 本人のiPhone「RYOSEIWORLD🌏」(UDID 504BE9CF-302A-5B02-B84B-EE2A08C720D0)に実機インストール済み・起動確認済み。ホーム画面にアイコンあり。署名は個人Apple Developerチーム（RYOSEI IMAI, team X72629Z4T6）、有効期限2027年8月27日
  - 技術メモ: `xcrun devicectl device install app`はUSBケーブル不要でWi-Fi経由でも通ることを確認済み（過去の「CoreDeviceError 1001で不可」という記録は今回のXcode 26.6環境では再現しなかった）。詳細は memory `reference_ios_native_dev_traps` に追記済み

## URLパラメータ設計

- `?s=<base64url>&ref=<id>&by=<base64url任意>` — 支援者を紹介された人向け（求職者）。`s`は`{name,skill,area,comment,lineUrl}`をJSON→UTF8→base64url化したもの
- `?add=<base64url>` — 支援者カードを紹介リストに追加する配布リンク
- デコード失敗時は画面を落とさず「リンクが古いようです」で通常画面にフォールバックする作りになっている

## 未解決・申し送り事項

1. 配布リンク（`?add=`）が短縮リンクを経由していない。紹介リンク（`?s=`）は短縮APIに繋がっているが、配布リンク側は未接続。急ぎではないが、次に触るなら揃えるとよい
2. `favicon.ico`が404（機能影響なし、見た目のみ）
3. iOS版に、紹介する人がWeb版で行う「役割選択→紹介1画面→LINEで送る」というv2のフローがまだ反映されていない可能性がある。v2化はWeb版が先行しており、iOS版は`ios-deploy`/`devicectl`でのビルド確認はv1相当の3タブ構成までしか検証していない。iOS版もv2の役割別UIに合わせるかは要判断
4. データはlocalStorage/端末内JSONのみ。サーバー間同期・会員登録・本物のプッシュ通知は無い（意図的簡略化。コード冒頭コメントに明記済み）
5. アプリ名「つなぐ」・ロゴは本人が仮承認した状態。正式に「これで決定」とは明言されていないので、迷ったら確認する

## 次にやるとしたら

- 実際に佐藤将大さんへ送る文面の下書き（本人が最終送信ボタンを押す形）
- iOS版のv2対応
- 配布リンクの短縮対応

## 更新 2026-09-23 05:30（見た目の作り直し＋iOS配布）

- 本人評価「見た目がダサい」→ **DESIGN-v3.md（Apple HIG準拠）が見た目の正本**。絵文字・灰色塗り箱・下線リンクを廃止、白黒＋緑1色、21st.devの作法（drawer/segmented/toast/押し込み/confetti）を素のHTMLに移植、記憶に残る要素は「つなぐ線」1つだけ
- Web版 v3 公開済み（index/manual/privacy.html/install.html）。privacy.html は TestFlight の審査情報に登録済み
- iOS版を v2＋HIG で作り直し済み（SwiftUI標準部品・つなぐ線・Debug限定の状態注入 DebugSeed.swift）。version 1.0 build 2
- App Store Connect: 名前「つなぐ - 友達で仕事紹介」（「つなぐ」は使用済み）、Apple ID 6814945848、SKU tsunagu-ios-001
- TestFlight: 外部グループ「友達」、公開リンク https://testflight.apple.com/join/4VXvAgzX （上限100人）。build 2 を 05:23 に外部テスト審査へ提出（承認されるまでリンクは使えない）
- 配布の道具: `ios/release/`（asc.py＝TestFlight操作、upload.sh＝アーカイブ→アップロード）。電話番号・Issuer ID を含むため git 追跡外。次のビルドは project.yml の CURRENT_PROJECT_VERSION を上げて `bash ios/release/upload.sh <iosディレクトリ>` → `python3 asc.py wait-build N && python3 asc.py add N`（同じバージョンの2本目以降は審査が省かれることが多い）
- 残り: TestFlight 承認の確認 → 佐藤将大さんへの案内（下書きは本人が送る）／TestFlight ビルドは90日で期限切れ／App Store 公開は別途判断
