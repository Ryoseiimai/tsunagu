# つなぐ iOS

SwiftUI / iOS 17以降。仕様はルートの SPEC-v2.md、見た目は DESIGN-v3.md。
Web側は変更せず、文面・base64url・短縮API・LINE共有URLを揃える。

## ビルド

この `ios/` ディレクトリで実行する。`.xcodeproj` は生成物で、編集・コミットしない。

```sh
/opt/homebrew/bin/xcodegen generate
xcrun simctl list devices available
xcodebuild -scheme Tsunagu -destination 'platform=iOS Simulator,name=iPhone16-tsunagu' -derivedDataPath DerivedData build
xcodebuild -scheme Tsunagu -configuration Release -destination 'generic/platform=iOS' -derivedDataPath DerivedData build CODE_SIGNING_ALLOWED=NO
```

シミュレータ名はローカルに存在するiPhoneを指定する。複数が起動している場合は `booted` ではなく対象UDIDを指定する。

## 検証

```sh
mkdir -p DerivedData
swift Scripts/check-symbols.swift
swiftc -parse-as-library Tsunagu/Models.swift Tsunagu/Links.swift Tsunagu/AppStore.swift Tsunagu/ShareText.swift Tests/CoreChecks.swift -o DerivedData/core-checks
DerivedData/core-checks
```

CoreChecksは一時ファイルと専用UserDefaultsだけを使い、日本語・Web由来のリンク、旧データ全状態、再読込、二重加算防止、重複カード、破損ファイルの保護を検証する。

## シミュレータ撮影

対象をbootし `open -a Simulator` で開く。同じbundle IDの旧アプリを `xcrun simctl uninstall <UDID> com.ryoseiworld.tsunagu` で除去してから、下記の現行Debugアプリをインストールする。

```sh
xcrun simctl install <UDID> DerivedData/Build/Products/Debug-iphonesimulator/Tsunagu.app
python3 Scripts/screenshots.py <UDID>
```

ライトとダークの各18状態を `../shots-v3-ios/L01_role.png` 〜 `D18_support_empty.png` に保存する。
`-uiState <状態名>` はDebug限定。通常のDocuments/tsunagu.jsonと役割保存に触れず、撮影専用の一時データを毎回初期化する。
状態名は `DebugSeed.swift` と撮影スクリプトを参照。起動引数を外せば通常データに戻る。
Releaseでは状態注入コード・専用保存領域はコンパイルされない。

## 引き継ぎ上の注意

- v1のDocuments/tsunagu.jsonをそのまま読み、旧ステータスを変換して実績を復元する。読めない保存ファイルは上書きしない。
- 紹介リンクは `tsunagu://open?s=<base64url>&ref=<id>&by=<base64url>`、配布リンクは `tsunagu://open?add=<base64url>` で受けられる。`s` を優先し、連続受信でも画面を更新する。
- 短縮APIが失敗したら公開URLの長いリンクを使う。配布用 `add` は現行APIが `400 missing_s` を返すため、このフォールバックで送れる。
- サーバー保存・認証・端末間同期・実際の通知は未実装。入口と制約はModels.swift冒頭に記載。
- 手元のDESIGN-v3.mdには§5-14がないため、つなぐ線は依頼の指定（紹介シート・求職者画面、初回0.4秒spring、Reduce Motionで静止）を適用。
