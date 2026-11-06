import Foundation

public actor BrewCatalogService {
    public static let shared = BrewCatalogService()

    private init() {}

    private var cacheFileURL: URL? {
        try? BrewCommandRunner.appSupportDirectory().appendingPathComponent("catalog_index_v2.json")
    }

    public func loadCatalog(forceRebuild: Bool = false) async throws -> [CatalogEntry] {
        if !forceRebuild, let url = cacheFileURL, FileManager.default.fileExists(atPath: url.path) {
            // Check if Homebrew internal payload was updated more recently than our index
            let indexMtime = (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? .distantPast
            let payloadMtime = latestHomebrewPayloadModificationDate() ?? .distantPast

            if indexMtime >= payloadMtime,
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(CatalogIndex.self, from: data),
               !decoded.entries.isEmpty {
                return decoded.entries
            }
        }

        let entries = try await buildCatalogFromHomebrewCache()
        if let url = cacheFileURL, !entries.isEmpty {
            let legacyURL = url.deletingLastPathComponent().appendingPathComponent("catalog_index.json")
            try? FileManager.default.removeItem(at: legacyURL)
            let index = CatalogIndex(generatedAt: Date(), entries: entries)
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
        if let payloadURL = findInternalPayloadURL(),
           let parsed = try? parseInternalPayload(at: payloadURL),
           !parsed.isEmpty {
            return parsed
        }
        return try await buildFallbackCatalogFromTxtFiles()
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
                results.append(
                    CatalogEntry(
                        name: name,
                        displayName: name,
                        type: .formula,
                        desc: desc,
                        homepage: homepage,
                        version: version,
                        appBundles: [],
                        downloadURL: downloadURL
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

                var appBundles: [String] = []
                if let rawArtifacts = info["raw_artifacts"] as? [[Any]] {
                    for artifact in rawArtifacts {
                        if artifact.count >= 2,
                           let kind = artifact[0] as? String,
                           kind == ":app",
                           let appList = artifact[1] as? [Any] {
                            for item in appList {
                                if let appName = item as? String {
                                    // Sometimes app path is "Subdir/Foo.app", take lastPathComponent for matching /Applications
                                    let bundleName = (appName as NSString).lastPathComponent
                                    if bundleName.hasSuffix(".app") {
                                        appBundles.append(bundleName)
                                    }
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
                        downloadURL: downloadURL
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
}
