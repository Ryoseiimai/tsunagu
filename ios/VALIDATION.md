# 小修正の検証 — R1856 / 2026-09-23

- `xcodegen generate` → iOS Simulator Debugビルド → uninstall → installを実施。Releaseも`CODE_SIGNING_ALLOWED=NO`で成功。両構成とも警告・エラー0件。
- 44ptの名前アバター、中央のAccentColorのlink、1ptの接続線を確認。紹介シートは「た／サ」、by付き求職者画面は「り／今」。未入力の紹介シートは左がperson.fill。
- 初回だけspring(duration: 0.4)で左右の線が18ptずつ縮み、linkがscale 0.6→1・opacity 0→1。Reduce Motionでは最初から完成状態にする分岐をコード確認。
- 紹介・配布シートは標準NavigationStackのinlineタイトルとcancellationActionを維持。principalタイトルは左右の領域を確保し、長いタイトルも中央に2行まで表示。両シートを目視確認。
- 地域アイコンの旧指定はios/Tsunagu内に残存なし。SF Symbolsの21個すべて実在確認。
- `shots-v3-ios/L04_refer_sheet.png`と`L14_consult_by.png`をライトで上書き。毎回launchしてから撮影し、保存画像を開いて「つなぐ」の対象画面と確認。
- 撮影端末はiPhone16-Tsunagu-R1856 / iOS 26.5（776C232C-DFE6-474E-97F6-A54067287B3C）。日本語キーボード操作が応答しなかったため、名前「たかし」はDEBUG限定の`-friendName`引数で再現。実操作による名前変更は今回未確認。Releaseバイナリに`-friendName`・`-uiState`・`tsunagu.debug-preview`が含まれないことを確認。
- ログは`DerivedData/R1856-debug-build.log`、`R1856-release-build.log`、`R1856-symbols.log`。配布シート確認画像は`DerivedData/R1856-distribute-check.png`。指定PNGは既存の.gitignoreに従いローカル成果物として保存。

# 検証記録 — R1843 / 2026-09-23

- XcodeGenからプロジェクトを生成。Debug（iPhone16-tsunagu / iOS 26.5）とRelease（generic/platform=iOS、CODE_SIGNING_ALLOWED=NO）とも成功、警告・エラー0件。
- バージョン1.0 / ビルド2、非免除暗号化なし。AppIconは1024×1024、アルファなし。
- SF SymbolsをSwiftソースの直接指定とSymbol定数から抽出し、macOSのNSImage(systemSymbolName:accessibilityDescription:)で21個すべて実在確認。
- CoreChecks成功。Node.js由来の日本語base64url、UTF-8往復、壊れたリンク、LINE文面中の「+」・改行、文面テンプレート、v1の全5状態、再読込、実績の二重加算防止、重複追加、キャッシュ無効化、読めない保存ファイルの保護を検証。
- シミュレータで日本語の友達名入力→文面更新→コピー→履歴作成→Menuで「決まった！」→実績更新・お祝い表示を操作確認。
- 新規カードの名前・得意分野入力→保存→支援ホームのプレビューを確認。空の対応地域は「応相談」。
- 実際のtsunagu://リンクを開き、コールド起動でsをaddより優先、紹介者名の表示、連続受信時のカード差し替え・紹介者名除去、LINE未登録時の無効化、壊れたs→ホーム復帰を確認。
- 支援者モードからaddリンクを受け、追加後に紹介ホームへ進むことを確認。
- 紹介用の短縮APIは200で短縮URLを取得。配布用addは400 missing_sを返すため、Webと同じ公開URLの長いリンクにフォールバックする。サーバー側は今回の変更範囲外。
- つなぐ線は紹介シートと求職者画面の2か所のみ。初回だけ0.4秒spring、accessibilityReduceMotion時は静止。紙吹雪とトーストの移動も同設定を尊重する。
- Release実行ファイルに-uiState / tsunagu.debug-previewの文字列が含まれないことを確認。

## 画面キャプチャ

`../shots-v3-ios/` にライト／ダーク各18枚（L01〜L18 / D01〜D18）。
役割選択、紹介ホーム空／カードあり、紹介シート、履歴5状態、お祝いの紙吹雪、支援ホーム、編集、配布、求職者byあり／なし、追加確認、壊れたリンク、支援ホーム空。
シミュレータのsimctl io screenshotによるPNG。画像加工なし。再現スクリプトはScripts/screenshots.py。

## 実行ログ

ローカルの `DerivedData/debug-build.log`、`release-build.log`、`symbols.log`、`core-checks.log`、`screenshots.log`。
DerivedData・shots-v3-ios・生成xcodeprojは既存.gitignoreで除外され、コミット対象外。
