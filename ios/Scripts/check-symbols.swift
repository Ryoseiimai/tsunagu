import AppKit
import Foundation

// Run from ios/: swift Scripts/check-symbols.swift
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "Tsunagu")
let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
var symbols = Set<String>()
for case let url as URL in files where url.pathExtension == "swift" {
    let source = try String(contentsOf: url, encoding: .utf8)
    let patterns = [#"(?:systemName|systemImage):\s*"([^"]+)""#]
        + (url.lastPathComponent == "Theme.swift" ? [#"static let \w+ = "([^"]+)""#] : [])
    for pattern in patterns {
        let regex = try NSRegularExpression(pattern: pattern)
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            symbols.insert(String(source[Range(match.range(at: 1), in: source)!]))
        }
    }
}
precondition(!symbols.isEmpty, "No SF Symbols were extracted; check the source directory")
var missing = [String]()
for symbol in symbols.sorted() {
    let exists = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil
    print("\(exists ? "OK" : "MISSING") \(symbol)")
    if !exists { missing.append(symbol) }
}
print("Checked \(symbols.count) symbols; missing: \(missing.count)")
exit(missing.isEmpty ? 0 : 1)
