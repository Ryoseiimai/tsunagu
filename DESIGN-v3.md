# つなぐ デザイン v3（Apple HIG準拠）

この文書は見た目の正本。機能・文言・URLの正本は `SPEC-v2.md` のまま（中身は変えない、見た目だけ変える）。
Web版（index.html / manual.html / privacy.html）と iOS版（ios/）は**同じ見た目**にする。

## 0. なぜ作り直すか

本人の評価は「見た目がダサい」。原因は次の4つ。
- 絵文字アイコン（🤝💼📤🎉）
- 灰色の塗り箱
- 下線リンク
- 全部同じ太さの文字

AIが作ったのが一目で分かる状態になっている。

方針は次の2つ。
- **デザインシステムに従わせるとAIっぽさが消える**（うすたくさんの知見）。今回のシステムは **Apple Human Interface Guidelines（iOS 26）**。迷ったら iOS 標準アプリ（設定・連絡先・メッセージ・App Store・ウォレット）がどうしているかに合わせる。独自の飾りは足さない。
- 細部の手触り（押したときの縮み・シートの出方・トースト・紙吹雪）は **21st.dev** の部品の作法を借りる。Web では React/Tailwind/CDN を使わず、素の HTML/CSS/JS に移植する。借りた部品の URL は HTML コメントに残す。

## 1. 色（3色だけ: 白黒の階調＋緑1色。有彩色は画面の5%未満）

| トークン | ライト | ダーク | 用途 |
|---|---|---|---|
| `--bg` | #F2F2F7 | #000000 | 一覧画面の地（systemGroupedBackground） |
| `--surface` | #FFFFFF | #1C1C1E | セル・カード（secondarySystemGroupedBackground） |
| `--label` | #000000 | #FFFFFF | 見出し・本文 |
| `--label-2` | #6E6E73 | #98989D | 補足（白地でコントラスト4.5以上を確保した値） |
| `--label-3` | #AEAEB2 | #636366 | プレースホルダ・無効のみ（本文に使わない） |
| `--separator` | #C6C6C8 | #38383A | 0.5px の区切り線のみ |
| `--fill` | rgba(120,120,128,.12) | rgba(118,118,128,.24) | 「紹介する」ボタン地・チップ・セグメント地・アバター地 |
| `--accent` | #06C755 | #06C755 | 塗り: 「LINEで送る」「LINEで相談する」ボタンだけ |
| `--accent-text` | #00873C | #30D158 | 緑の文字・アイコン（白地で4.5以上） |

- 主ボタン（LINE以外）は **黒の塗り**（ダークでは白の塗り・黒文字）。緑はLINEの操作と「決まった」だけに使う。
- 使ってはいけないもの:
  - グラデーション
  - パステルの塗り箱
  - ドロップシャドウ
  - 絵文字
  - 下線リンク（リンクは `--accent-text` の文字だけ）
- 半透明ぼかし（backdrop-filter）は**上部のナビバーと下部の固定ボタン帯だけ**許す。iOS のマテリアルに相当する。

## 2. 文字

- Web: `font-family: -apple-system, BlinkMacSystemFont, "Hiragino Sans", "Hiragino Kaku Gothic ProN", "Noto Sans JP", system-ui, sans-serif;`
- iOS: システムフォントと Dynamic Type の標準テキストスタイルを使う。サイズの直書きはしない。

| スタイル | Web px / 行高 / 太さ | iOS |
|---|---|---|
| Large Title | 34 / 1.2 / 700 | .largeTitle（ナビの大見出し） |
| Title 1 | 28 / 1.25 / 700 | .title（求職者画面の支援者名） |
| Title 3 | 20 / 1.35 / 600 | .title3 |
| Headline | 17 / 1.4 / 600 | .headline（セルの名前） |
| Body | 17 / 1.6 / 400 | .body |
| Subheadline | 15 / 1.5 / 400 | .subheadline（得意分野など） |
| Footnote | 14 / 1.5 / 400 | .footnote（セクション見出し・注記。**これより小さい文字は使わない**） |

- 見出しだけ `font-feature-settings: "palt" 1;`。本文には付けない。
- 日本語の変な位置での折り返しを防ぐため、Web は `~/.claude/skills/shiryo/assets/budoux-wrap.html` の中身を `</body>` 直前に貼る。見出しの行末に1〜3文字だけ残る形はNG。

## 3. 形と間隔

- 8px グリッド。画面の左右余白は 16px。セル内の余白は 16px。
- 角丸:
  - セクション・カード: 20px（iOS は List の insetGrouped 既定に任せる）
  - 入力欄: 12px
  - ボタン: カプセル（完全な丸端）
- ボタンの高さ:
  - 主ボタン: 52px
  - 副ボタン: 44px
  - セル内の小ボタン: 32px。ただしタップ領域は 44px 確保する
- 押した瞬間に `transform: scale(.97)` → 離すと戻す（200ms, `cubic-bezier(.2,.8,.2,1)`）。iOS は標準ボタンの挙動に任せる。
- `prefers-reduced-motion: reduce` のときは動きを全部切る。
- **ダークモード対応は必須**（Web は `prefers-color-scheme`、iOS はシステムカラーで自動対応）。

## 4. アイコン

- iOS: SF Symbols。**名前は実在確認すること**（ios の罠: 名前ミスはコンパイルが通って何も描かれない）。
- Web: Lucide（ISCライセンス）の線アイコンを インライン SVG で埋め込む。
  - stroke 2px、24px 基準
  - 冒頭コメントに「Icons: Lucide (ISC)」と書く
  - SF Symbols を Web に持ち出すのはライセンス違反なので**やらない**

| 意味 | iOS (SF Symbols) | Web (Lucide) |
|---|---|---|
| 友達を紹介したい | person.2.fill | users |
| 仕事探しを手伝っている | briefcase.fill | briefcase |
| 使い方 | questionmark.circle | circle-help |
| メニュー | ellipsis.circle | ellipsis |
| 地域 | mappin.and.ellipse | map-pin |
| 送った | paperplane.fill | send |
| 相談してるみたい | bubble.left.and.bubble.right.fill | messages-square |
| 決まった！ | checkmark.seal.fill（緑） | badge-check（緑） |
| 別のところで決まった | arrow.uturn.right | corner-up-right |
| 見送り | minus.circle | circle-minus |
| コピー | doc.on.doc | copy |
| ほかのアプリで送る | square.and.arrow.up | share |
| LINEで送る/相談する | message.fill | message-circle |

LINE の公式ロゴは使わない（商標）。「LINEで送る」の文字と緑の塗りで伝える。

## 5. 部品（Web も iOS もこの名前で作る）

1. **ナビバー**
   - 大見出し（Large Title）
   - スクロールで上に消えると、上部に小さい中央タイトル付きの半透明バーが出る（iOS 標準の動き。Web は IntersectionObserver で再現）
   - 右上に丸いアイコンボタン（使い方「?」／メニュー「…」→「役割を変える」）
2. **セクション**
   - `--surface` の角丸 20px の箱
   - 上に Footnote で見出し（`--label-2`、左 16px）
   - 中のセル同士は左 16px 空けた 0.5px 線で区切る
3. **支援者セル**（紹介する人のホーム）
   - 左: 44px の丸アバター（`--fill` 地に名前の1文字目、`--label-2`、600）
   - 中央:
     - 名前（Headline）
     - 得意分野（Subheadline, `--label-2`）
     - 地域アイコン＋地域 ・ 「紹介 3 ・ 決まった 1」（Footnote, `--label-2`）
     - 一言（Subheadline, 2行で切る）
   - 右: **App Store の「入手」ボタンと同じ作法の小カプセル「紹介する」**（`--fill` 地・`--accent-text` 文字・600・高さ32px）。セル全体を押しても同じ動作。
4. **空の状態**（iOS は `ContentUnavailableView` を使う）
   - 中央に 48px のアイコン（`--label-3`）
   - タイトル（Title 3）と説明（Body, `--label-2`）
   - 黒の主ボタン「誘い文をコピー」＋文字ボタン「見本で試す」
5. **紹介シート**（紹介1画面。Web は下から出るシート、iOS は `.sheet`）
   - 上部:
     - つまみ（36×5px, `--label-3`）
     - 左に「キャンセル」
     - 中央に「{支援者名}さんを紹介」
   - 中身（上から）:
     1. 入力セル「送る相手」＋プレースホルダ「友達の名前（なくてもOK）」
     2. セグメント「カジュアル｜ていねい」（`--fill` 地に白い選択つまみが滑る。iOS は `Picker(.segmented)`）
     3. Footnote「相手にはこう届きます」
     4. 文面の編集欄。メッセージアプリの受信吹き出しの見た目にする（`--fill` 地、角丸 18px、左下だけ 6px）。5〜6行見える高さ
   - 下部の固定帯（半透明マテリアル＋セーフエリア）:
     - 主ボタン「LINEで送る」（緑の塗り・白文字・52px・message アイコン付き）
     - その下に副ボタン2つ横並び「コピー」「ほかのアプリ」（`--fill` 地・`--label` 文字・44px）
   - iPhone 390×844 で**スクロールせずに全部見える**こと（SPEC-v2 の要件）
   - Web はシートを下へ引っぱると閉じる（21st.dev の vaul 系 drawer の作法）
6. **紹介したあと（履歴）セル**
   - 左: 状態アイコン（28px 丸, `--fill` 地）
   - 中央:
     - 「{支援者}さん → {友達}」（Headline）
     - 送った日（Footnote, `--label-2`）
   - 右: 状態カプセル（`--fill` 地・Subheadline・下向きシェブロン付き）。押すと状態を選ぶメニュー（iOS は `Menu`、Web はアクションシート）
   - 「決まった！」にした瞬間:
     - 紙吹雪（Web は canvas 1.2秒、粒の色は緑・黒・灰の3色のみ。iOS は軽い粒子アニメ）
     - iOS は `.sensoryFeedback(.success)`
     - セルに緑の `checkmark.seal.fill` と「よかったね！」（`--accent-text`, Headline）が出て残る
   - 地味にしない、でも色は増やさない
7. **トースト**
   - 画面下（セーフエリア＋16px）に黒いカプセル（ダークでは白）＋チェックアイコン＋文言
   - 下からふわっと出て 2.4 秒で消える
   - sonner 系トーストの作法。複数出たら重ねずに差し替える
8. **役割選択**
   - 上部中央:
     - アプリアイコン（logo を 72px、角丸 16px の iOS アイコン形）
     - 「つなぐ」（Large Title）
     - 「仕事探しを、友達の紹介で。」（Body, `--label-2`）
   - 「どちらで使いますか？」（Title 3）
   - 下に選択セル2つ（各 88px 以上）:
     - 左 44px の丸（`--fill` 地に `--accent-text` アイコン）
     - タイトル（Headline 17）
     - 説明（Subheadline, `--label-2`）
     - 右シェブロン
   - 最下部に文字ボタン「使い方を見る」（`--accent-text`, 下線なし）
9. **支援する人のホーム**
   - ナビ「あなたのカード」、右上「編集」
   - 大きい支援者カード（求職者が見るのと同じ見た目）
   - 黒の主ボタン「紹介してくれる人に配る」。押すと紹介シートと同じ型の配布シートが出て、LINEで送る／コピー
   - その下に「紹介されてきた人」セクション。空なら Footnote「まだいません」
10. **カード編集**（iOS は `Form`）
    - 入力セル: 名前／得意分野／対応地域／一言（複数行）／LINEのURL（下に取り方の Footnote）
    - 右上「保存」（600）、左上「キャンセル」
11. **求職者画面**（`?s=`・アプリを持っていない人が最初に見る画面。**一番きれいに**）
    - 上部中央に小さなアプリアイコン 28px＋「つなぐ」（Footnote 600）
    - 紹介者名があれば、その下に `--fill` 地の小カプセル「{紹介者}さんからの紹介です」（人アイコン付き）
    - 大きいカード（`--surface`, 角丸 20px, 余白 24px）:
      - 72px アバター
      - 名前（Title 1）
      - 得意分野（Body, `--label-2`）
      - 地域チップ（`--fill` 地カプセル）
      - 一言（Body, 行間 1.7）
    - カードの下:
      - Footnote「決まったら、紹介してくれた人に教えてあげてね」
      - 文字ボタン「決まった！を送る」
    - 画面下に固定: 「LINEで相談する」（緑の塗り・52px・親指の位置）。LINE の URL が無ければ押せない表示＋理由の Footnote
12. **追加確認**（`?add=`）
    - 中央に「紹介リストに追加しますか？」（Title 3）
    - 支援者カードのプレビュー
    - 黒の主ボタン「追加する」と文字ボタン「追加しない」
13. **壊れたリンク**
    - 空の状態と同じ型: link アイコン、「リンクが古いようです」、説明、「ホームへ」

## 6. 21st.dev から借りる作法（Web）

| 借りる作法 | 使う場所 | 移植の要点 |
|---|---|---|
| vaul 系 drawer（下から出るシート） | 紹介シート・配布シート | 背景を暗く、下へ引っぱって閉じる、`dvh` 基準で高さ |
| スライドするセグメント | トーン切替 | 選択つまみが spring で横移動 |
| sonner 系トースト | コピー・送信後 | 下から出て自動で消える |
| 押し込みボタン | 全ボタン | scale .97 の触感 |
| confetti | 「決まった！」 | canvas、3色、reduced-motion で無効 |

具体的な 21st.dev の部品 URL は別途調査して渡す。見つからない作法は上の要点どおりに自作してよい。

## 7. 検品基準（出す前に全部満たす）

- iPhone 390×844 のライト・ダーク両方でスクショを撮る。対象は全画面:
  - 役割選択
  - 紹介ホーム（空／カードあり）
  - 紹介シート
  - 履歴（全状態・お祝い）
  - 支援ホーム・編集・配布シート
  - 求職者画面（紹介者名あり／なし）
  - 追加確認
  - 壊れたリンク
  - manual・privacy
- 絵文字がUIに1つも無い
- 14px 未満の文字が無い
- 文字のコントラストが AA 以上
- タップ領域は 44px 以上
- 横スクロールが出ない
- 有彩色が 5% 未満（緑はLINEボタンと「決まった」だけ）
- 機能は落とさない:
  - SPEC-v2 の全フロー
  - base64url の日本語往復
  - 短縮リンクAPI
  - localStorage のキーと既存データ引き継ぎ
  - `?s=` / `?add=` / 壊れたリンク
  - alert/confirm/prompt を使わない
