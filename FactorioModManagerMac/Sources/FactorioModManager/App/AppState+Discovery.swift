import Foundation
import SwiftUI

extension AppState {
    public func loadPortalCatalog(version: String = "2.1") async {
        isSearching = true
        lastSearchQuery = ""
        do {
            let results = try await ModPortalClient.shared.fetchCatalog(version: version, pageSize: 100)
            self.searchResults = results
        } catch {
            self.searchResults = []
            showNotification(title: loc("search_portal_title"), message: error.localizedDescription, isError: true)
        }
        isSearching = false
    }

    public func searchPortal(query: String, version: String = "2.1") async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            await loadPortalCatalog(version: version)
            return
        }

        isSearching = true
        lastSearchQuery = trimmed
        do {
            let results = try await ModPortalClient.shared.searchPortalMods(query: trimmed, version: version)
            self.searchResults = results
        } catch {
            self.searchResults = []
            showNotification(title: loc("search_portal_title"), message: error.localizedDescription, isError: true)
        }
        isSearching = false
    }

    public func searchPortalMods(query: String, onlyV2: Bool = false) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        lastSearchQuery = trimmed
        do {
            let results = try await ModPortalClient.shared.searchPortalMods(query: trimmed, onlyV2: onlyV2)
            self.searchResults = results
        } catch {
            self.searchResults = []
            showNotification(title: loc("search_portal_title"), message: error.localizedDescription, isError: true)
        }
        isSearching = false
    }

    public func searchPortal(query: String, scope: Int = 1) async {
        if scope == 2 {
            let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let filtered = installedMods.filter {
                $0.name.lowercased().contains(clean) || $0.displayTitle.lowercased().contains(clean)
            }.map {
                SearchModItem(
                    name: $0.name,
                    title: $0.displayTitle,
                    owner: $0.author,
                    summary: $0.summary,
                    factorioVersions: $0.factorioVersion,
                    downloadsCount: 0,
                    isDeprecated: false
                )
            }
            self.searchResults = filtered
            self.lastSearchQuery = query
        } else {
            await searchPortalMods(query: query, onlyV2: scope == 1)
        }
    }

    public func scanOptionalMods() {
        Task {
            await scanOptionalCompanionMods()
        }
    }

    public func fetchAuthorMods(author: String) async {
        await fetchAuthorMods(authorOrUrl: author)
    }

    public func fetchAuthorMods(authorOrUrl: String) async {
        let trimmed = authorOrUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isFetchingAuthor = true
        do {
            let (name, mods) = try await ModPortalClient.shared.fetchAuthorMods(authorOrUrl: trimmed)
            self.currentAuthorName = name
            self.authorResults = mods
        } catch {
            self.authorResults = []
            showNotification(title: loc("author_title"), message: error.localizedDescription, isError: true)
        }
        isFetchingAuthor = false
    }

    public func scanOptionalCompanionMods() async {
        isScanningOptional = true
        let installed = installedMods.filter { $0.enabled }
        var suggestionsMap: [String: [String]] = [:]
        let installedNames = Set(installedMods.map(\.name))

        for mod in installed {
            let deps = mod.getDependencies()
            for dep in deps where (dep.depType == .recommended || dep.depType == .optional) && !dep.isVirtual && !FactorioConstants.isOfficialMod(dep.name) {
                if !installedNames.contains(dep.name) {
                    if suggestionsMap[dep.name] == nil {
                        suggestionsMap[dep.name] = []
                    }
                    if !suggestionsMap[dep.name]!.contains(mod.name) {
                        suggestionsMap[dep.name]!.append(mod.name)
                    }
                }
            }
        }

        var list: [OptionalModItem] = []
        for (name, parents) in suggestionsMap {
            list.append(OptionalModItem(name: name, suggestedBy: parents))
        }
        list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        self.optionalMods = list
        self.isScanningOptional = false
    }
}
