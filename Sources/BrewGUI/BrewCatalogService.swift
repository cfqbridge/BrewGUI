import Foundation

public actor BrewCatalogService {
    public static let shared = BrewCatalogService()

    private init() {}

    private var cacheFileURL: URL? {
        try? BrewCommandRunner.appSupportDirectory().appendingPathComponent("catalog_index_v6.json")
    }

    public func loadCatalog(forceRebuild: Bool = false) async throws -> [CatalogEntry] {
        let tapSig = currentTapSignature()
        if !forceRebuild, let url = cacheFileURL, FileManager.default.fileExists(atPath: url.path) {
            // Check if Homebrew internal payload was updated more recently than our index, or if local Taps changed
            let indexMtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
            let payloadMtime = latestHomebrewPayloadModificationDate() ?? .distantPast

            if indexMtime >= payloadMtime,
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(CatalogIndex.self, from: data),
               decoded.tapSignature == tapSig,
               !decoded.entries.isEmpty {
                return decoded.entries
            }
        }

        let entries = try await buildCatalogFromHomebrewCache()
        if let url = cacheFileURL, !entries.isEmpty {
            let dir = url.deletingLastPathComponent()
            for legacy in ["catalog_index.json", "catalog_index_v2.json", "catalog_index_v3.json", "catalog_index_v4.json", "catalog_index_v5.json"] {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(legacy))
            }
            let index = CatalogIndex(generatedAt: Date(), entries: entries, tapSignature: tapSig)
            if let encoded = try? JSONEncoder().encode(index) {
                try? encoded.write(to: url, options: .atomic)
            }
        }
        return entries
    }

    private func latestHomebrewPayloadModificationDate() -> Date? {
        guard let url = findInternalPayloadURL() else { return nil }
        return try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    private func findInternalPayloadURL() -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let internalDir = home.appendingPathComponent("Library/Caches/Homebrew/api/internal", isDirectory: true)
        guard let items = try? fm.contentsOfDirectory(at: internalDir, includingPropertiesForKeys: [.contentModificationDateKey]) else {
            return nil
        }
        let payloads = items.filter { $0.lastPathComponent.hasPrefix("packages.") && $0.lastPathComponent.hasSuffix(".payload") }
        return payloads.max { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da < db
        }
    }

    private func buildCatalogFromHomebrewCache() async throws -> [CatalogEntry] {
        var baseEntries: [CatalogEntry]
        if let payloadURL = findInternalPayloadURL(),
           let parsed = try? parseInternalPayload(at: payloadURL),
           !parsed.isEmpty {
            baseEntries = parsed
        } else {
            baseEntries = try await buildFallbackCatalogFromTxtFiles()
        }

        let tapEntries = scanThirdPartyTapEntries()
        if !tapEntries.isEmpty {
            var indexMap: [String: Int] = [:]
            indexMap.reserveCapacity(baseEntries.count)
            for (idx, entry) in baseEntries.enumerated() {
                indexMap[entry.id] = idx
            }
            for tapEntry in tapEntries {
                if let existingIdx = indexMap[tapEntry.id] {
                    baseEntries[existingIdx] = tapEntry
                } else {
                    indexMap[tapEntry.id] = baseEntries.count
                    baseEntries.append(tapEntry)
                }
            }
            baseEntries.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return baseEntries
    }

    private func parseInternalPayload(at url: URL) throws -> [CatalogEntry] {
        let rawContent = try String(contentsOf: url, encoding: .utf8)
        // The payload file has 2 lines: line 1 is JWS signature header, line 2 is the full JSON object
        let lines = rawContent.split(whereSeparator: \.isNewline)
        guard let jsonLine = lines.last,
              let jsonData = String(jsonLine).data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return []
        }

        var results: [CatalogEntry] = []
        results.reserveCapacity(17000)

        if let formulaeDict = root["formulae"] as? [String: [String: Any]] {
            for (name, info) in formulaeDict {
                let desc = (info["desc"] as? String) ?? ""
                let homepage = (info["homepage"] as? String) ?? ""
                let version = (info["stable_version"] as? String) ?? ""
                let downloadURL = (info["stable_url_args"] as? [Any])?.first as? String
                let disableArgs = info["disable_args"] as? [String: Any]
                let deprecateArgs = info["deprecate_args"] as? [String: Any]
                let disableDate = disableArgs?[":date"] as? String
                let disableReason = disableArgs?[":because"] as? String
                let deprecateDate = deprecateArgs?[":date"] as? String
                let deprecateReason = deprecateArgs?[":because"] as? String
                let replacement = (disableArgs?[":replacement_formula"] as? String)
                    ?? (disableArgs?[":replacement_cask"] as? String)
                    ?? (deprecateArgs?[":replacement_formula"] as? String)
                    ?? (deprecateArgs?[":replacement_cask"] as? String)

                results.append(
                    CatalogEntry(
                        name: name,
                        displayName: name,
                        type: .formula,
                        desc: desc,
                        homepage: homepage,
                        version: version,
                        appBundles: [],
                        downloadURL: downloadURL,
                        disableDate: disableDate,
                        disableReason: disableReason,
                        deprecateDate: deprecateDate,
                        deprecateReason: deprecateReason,
                        replacementPackage: replacement
                    )
                )
            }
        }

        if let casksDict = root["casks"] as? [String: [String: Any]] {
            for (token, info) in casksDict {
                let desc = (info["desc"] as? String) ?? ""
                let homepage = (info["homepage"] as? String) ?? ""
                let version = (info["version"] as? String) ?? ""
                let names = (info["names"] as? [String]) ?? []
                let displayName = names.first ?? token
                let downloadURL = (info["url_args"] as? [Any])?.first as? String
                let disableArgs = info["disable_args"] as? [String: Any]
                let deprecateArgs = info["deprecate_args"] as? [String: Any]
                let disableDate = disableArgs?[":date"] as? String
                let disableReason = disableArgs?[":because"] as? String
                let deprecateDate = deprecateArgs?[":date"] as? String
                let deprecateReason = deprecateArgs?[":because"] as? String
                let replacement = (disableArgs?[":replacement_cask"] as? String)
                    ?? (disableArgs?[":replacement_formula"] as? String)
                    ?? (deprecateArgs?[":replacement_cask"] as? String)
                    ?? (deprecateArgs?[":replacement_formula"] as? String)

                var appBundles: [String] = []
                var zapPaths: [String] = []
                if let rawArtifacts = info["raw_artifacts"] as? [[Any]] {
                    for artifact in rawArtifacts {
                        guard artifact.count >= 2, let kind = artifact[0] as? String else { continue }
                        if kind == ":app", let appList = artifact[1] as? [Any] {
                            for item in appList {
                                if let appName = item as? String {
                                    // Sometimes app path is "Subdir/Foo.app", take lastPathComponent for matching /Applications
                                    let bundleName = (appName as NSString).lastPathComponent
                                    if bundleName.hasSuffix(".app") {
                                        appBundles.append(bundleName)
                                    }
                                }
                            }
                        } else if kind == ":zap", let zapDict = artifact[1] as? [String: Any] {
                            for key in [":trash", ":delete"] {
                                if let list = zapDict[key] as? [Any] {
                                    for item in list {
                                        if let p = item as? String, Self.isSafeUserLibraryZapPath(p) {
                                            zapPaths.append(p)
                                        }
                                    }
                                } else if let p = zapDict[key] as? String, Self.isSafeUserLibraryZapPath(p) {
                                    zapPaths.append(p)
                                }
                            }
                        }
                    }
                }

                results.append(
                    CatalogEntry(
                        name: token,
                        displayName: displayName,
                        type: .cask,
                        desc: desc,
                        homepage: homepage,
                        version: version,
                        appBundles: appBundles,
                        downloadURL: downloadURL,
                        zapTrashPaths: zapPaths.isEmpty ? nil : zapPaths,
                        disableDate: disableDate,
                        disableReason: disableReason,
                        deprecateDate: deprecateDate,
                        deprecateReason: deprecateReason,
                        replacementPackage: replacement
                    )
                )
            }
        }

        results.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return results
    }

    private func buildFallbackCatalogFromTxtFiles() async throws -> [CatalogEntry] {
        let fm = FileManager.default
        let apiDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Caches/Homebrew/api", isDirectory: true)
        var results: [CatalogEntry] = []

        let formulaeURL = apiDir.appendingPathComponent("formula_names.txt")
        if let content = try? String(contentsOf: formulaeURL, encoding: .utf8) {
            for line in content.split(whereSeparator: \.isNewline) {
                let name = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                results.append(
                    CatalogEntry(
                        name: name,
                        displayName: name,
                        type: .formula,
                        desc: "",
                        homepage: "",
                        version: "",
                        appBundles: []
                    )
                )
            }
        }

        let casksURL = apiDir.appendingPathComponent("cask_names.txt")
        if let content = try? String(contentsOf: casksURL, encoding: .utf8) {
            for line in content.split(whereSeparator: \.isNewline) {
                let token = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !token.isEmpty else { continue }
                results.append(
                    CatalogEntry(
                        name: token,
                        displayName: token,
                        type: .cask,
                        desc: "",
                        homepage: "",
                        version: "",
                        appBundles: []
                    )
                )
            }
        }

        return results
    }

    // MARK: - Third-Party Local Tap Repository Scanner

    private static let tapRoots = [
        "/opt/homebrew/Library/Taps",
        "/usr/local/Library/Taps"
    ]

    private func currentTapSignature() -> String {
        let fm = FileManager.default
        var records: [String] = []
        for root in Self.tapRoots {
            guard let users = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for user in users.sorted() where !user.hasPrefix(".") {
                let userPath = (root as NSString).appendingPathComponent(user)
                guard let repos = try? fm.contentsOfDirectory(atPath: userPath) else { continue }
                for repoDir in repos.sorted() where !repoDir.hasPrefix(".") {
                    let shortRepo = repoDir.hasPrefix("homebrew-") ? String(repoDir.dropFirst("homebrew-".count)) : repoDir
                    let tapName = "\(user)/\(shortRepo)".lowercased()
                    if tapName == "homebrew/core" || tapName == "homebrew/cask" { continue }
                    let repoPath = (userPath as NSString).appendingPathComponent(repoDir)
                    let rbFiles = Self.collectRubyFiles(inTapRepoPath: repoPath)
                    for rb in rbFiles {
                        let mtime = (try? fm.attributesOfItem(atPath: rb.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
                        records.append("\(tapName):\(rb.kind.rawValue):\((rb.path as NSString).lastPathComponent):\(Int64(mtime))")
                    }
                }
            }
        }
        return records.joined(separator: "|")
    }

    private func scanThirdPartyTapEntries() -> [CatalogEntry] {
        let fm = FileManager.default
        var results: [CatalogEntry] = []
        var seenIDs = Set<String>()

        for root in Self.tapRoots {
            guard let users = try? fm.contentsOfDirectory(atPath: root) else { continue }
            for user in users.sorted() where !user.hasPrefix(".") {
                let userPath = (root as NSString).appendingPathComponent(user)
                guard let repos = try? fm.contentsOfDirectory(atPath: userPath) else { continue }
                for repoDir in repos.sorted() where !repoDir.hasPrefix(".") {
                    let shortRepo = repoDir.hasPrefix("homebrew-") ? String(repoDir.dropFirst("homebrew-".count)) : repoDir
                    let tapName = "\(user)/\(shortRepo)"
                    let tapLower = tapName.lowercased()
                    if tapLower == "homebrew/core" || tapLower == "homebrew/cask" { continue }
                    let repoPath = (userPath as NSString).appendingPathComponent(repoDir)
                    let rbFiles = Self.collectRubyFiles(inTapRepoPath: repoPath)
                    for rb in rbFiles {
                        if let entry = Self.parseTapRubyFile(atPath: rb.path, defaultKind: rb.kind, tapName: tapName) {
                            if !seenIDs.contains(entry.id) {
                                seenIDs.insert(entry.id)
                                results.append(entry)
                            }
                        }
                    }
                }
            }
        }
        return results
    }

    private static func collectRubyFiles(inTapRepoPath repoPath: String) -> [(path: String, kind: PackageType)] {
        let fm = FileManager.default
        var list: [(path: String, kind: PackageType)] = []

        let casksDir = (repoPath as NSString).appendingPathComponent("Casks")
        if let enumerator = fm.enumerator(atPath: casksDir) {
            while let rel = enumerator.nextObject() as? String {
                if rel.hasSuffix(".rb") && !(rel as NSString).lastPathComponent.hasPrefix(".") {
                    list.append(((casksDir as NSString).appendingPathComponent(rel), .cask))
                }
            }
        }

        for formulaFolder in ["Formula", "HomebrewFormula"] {
            let fDir = (repoPath as NSString).appendingPathComponent(formulaFolder)
            if let enumerator = fm.enumerator(atPath: fDir) {
                while let rel = enumerator.nextObject() as? String {
                    if rel.hasSuffix(".rb") && !(rel as NSString).lastPathComponent.hasPrefix(".") {
                        list.append(((fDir as NSString).appendingPathComponent(rel), .formula))
                    }
                }
            }
        }

        if let rootItems = try? fm.contentsOfDirectory(atPath: repoPath) {
            for item in rootItems where item.hasSuffix(".rb") && !item.hasPrefix(".") {
                list.append(((repoPath as NSString).appendingPathComponent(item), .formula))
            }
        }

        return list
    }

    private static func parseTapRubyFile(atPath path: String, defaultKind: PackageType, tapName: String) -> CatalogEntry? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        let fileBaseName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension

        let isCaskFile = defaultKind == .cask || firstRegexCapture(#"(?m)^\s*cask\s+["']([^"']+)["']"#, in: content) != nil
        if isCaskFile {
            let token = firstRegexCapture(#"(?m)^\s*cask\s+["']([^"']+)["']"#, in: content) ?? fileBaseName
            let rawVersion = firstRegexCapture(#"(?m)^\s*version\s+["']([^"']+)["']"#, in: content)
                ?? (content.range(of: #"(?m)^\s*version\s+:latest"#, options: .regularExpression) != nil ? "latest" : "")
            let armArch = firstRegexCapture(#"arch\s+arm:\s*["']([^"']+)["']"#, in: content) ?? "arm64"
            let displayName = firstRegexCapture(#"(?m)^\s*name\s+["']([^"']+)["']"#, in: content) ?? token
            let desc = firstRegexCapture(#"(?m)^\s*desc\s+["']([^"']+)["']"#, in: content) ?? ""
            let homepage = firstRegexCapture(#"(?m)^\s*homepage\s+["']([^"']+)["']"#, in: content) ?? ""

            var downloadURL: String? = nil
            if var rawURL = firstRegexCapture(#"(?m)^\s*url\s+["']([^"']+)["']"#, in: content) {
                let verCSV = rawVersion.split(separator: ",").map(String.init)
                rawURL = rawURL
                    .replacingOccurrences(of: "#{version}", with: rawVersion)
                    .replacingOccurrences(of: "#{version.csv.first}", with: verCSV.first ?? rawVersion)
                    .replacingOccurrences(of: "#{version.csv.second}", with: verCSV.count > 1 ? verCSV[1] : "")
                    .replacingOccurrences(of: "#{arch}", with: armArch)
                if !rawURL.contains("#{") && (rawURL.hasPrefix("https://") || rawURL.hasPrefix("http://")) {
                    downloadURL = rawURL
                }
            }

            let appMatches = allRegexCaptures(#"(?m)^\s*app\s+["']([^"']+)["']"#, in: content)
            var appBundles: [String] = []
            for m in appMatches {
                let b = (m as NSString).lastPathComponent
                if b.hasSuffix(".app") && !appBundles.contains(b) {
                    appBundles.append(b)
                }
            }

            var zapPaths: [String] = []
            if let zapRange = content.range(of: #"(?s)zap\s+trash:\s*(\[[^\]]*\]|["'][^"']+["'])"#, options: .regularExpression) {
                let zapBlock = String(content[zapRange])
                let quoted = allRegexCaptures(#"["']([^"']+)["']"#, in: zapBlock)
                for p in quoted where isSafeUserLibraryZapPath(p) {
                    if !zapPaths.contains(p) {
                        zapPaths.append(p)
                    }
                }
            }

            return CatalogEntry(
                name: token,
                displayName: displayName,
                type: .cask,
                desc: desc,
                homepage: homepage,
                version: rawVersion,
                appBundles: appBundles,
                downloadURL: downloadURL,
                zapTrashPaths: zapPaths.isEmpty ? nil : zapPaths,
                tap: tapName
            )
        } else {
            let name = fileBaseName
            let desc = firstRegexCapture(#"(?m)^\s*desc\s+["']([^"']+)["']"#, in: content) ?? ""
            let homepage = firstRegexCapture(#"(?m)^\s*homepage\s+["']([^"']+)["']"#, in: content) ?? ""
            let rawURL = firstRegexCapture(#"(?m)^\s*url\s+["']([^"']+)["']"#, in: content)
            var version = firstRegexCapture(#"(?m)^\s*version\s+["']([^"']+)["']"#, in: content) ?? ""
            if version.isEmpty, let u = rawURL {
                let lastComp = (u as NSString).lastPathComponent
                if let inferred = firstRegexCapture(#"v?(\d+\.\d+(?:\.\d+)*(?:-[0-9A-Za-z._]+)?)"#, in: lastComp) {
                    version = inferred
                }
            }
            let cleanURL = (rawURL != nil && !rawURL!.contains("#{")) ? rawURL : nil
            return CatalogEntry(
                name: name,
                displayName: name,
                type: .formula,
                desc: desc,
                homepage: homepage,
                version: version,
                appBundles: [],
                downloadURL: cleanURL,
                tap: tapName
            )
        }
    }

    private static func firstRegexCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private static func allRegexCaptures(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { m in
            guard m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: text) else { return nil }
            return String(text[r])
        }
    }

    private static let sharedVendorRoots: Set<String> = [
        "~/library/application support/google",
        "~/library/application support/microsoft",
        "~/library/application support/apple",
        "~/library/application support/adobe",
        "~/library/application support/jetbrains",
        "~/library/application support/mozilla",
        "~/library/application support/clouddocs",
        "~/library/caches/google",
        "~/library/caches/microsoft",
        "~/library/caches/mozilla",
        "~/library/caches/apple",
        "~/library/logs/google",
        "~/library/logs/microsoft",
        "~/library/preferences/byhost"
    ]

    public static func isSafeUserLibraryZapPath(_ rawPath: String) -> Bool {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("~/Library/") else { return false }
        if trimmed.contains("*") || trimmed.contains("?") || trimmed.contains("$") || trimmed.contains("..") {
            return false
        }
        var normalized = trimmed
        while normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        let lower = normalized.lowercased()
        if sharedVendorRoots.contains(lower)
            || lower.contains("/clouddocs/")
            || lower.hasSuffix("/clouddocs")
            || lower.contains("/com.apple.sharedfilelist") {
            return false
        }
        let rel = String(normalized.dropFirst("~/Library/".count))
        let parts = rel.split(separator: "/")
        guard parts.count >= 2 else { return false }
        let allowedTopFolders: Set<String> = [
            "Application Support",
            "Caches",
            "Preferences",
            "Saved Application State",
            "HTTPStorages",
            "WebKit",
            "Logs",
            "Application Scripts"
        ]
        guard allowedTopFolders.contains(String(parts[0])) else { return false }
        return true
    }
}
