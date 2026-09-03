import SwiftUI

public struct UnifiedModCardRow: View {
    public let name: String
    public let title: String
    public let owner: String?
    public let factorioVersions: String?
    public let lastUpdated: String?
    public let downloadsCount: Int
    public let summary: String?
    public let isDeprecated: Bool
    public let isInstalled: Bool
    public var suggestedBy: [String]?
    public var isSelected: Bool?
    public var onToggleSelect: (() -> Void)?
    public let onInstall: () -> Void
    public let onOpenDetails: () -> Void

    public init(
        name: String,
        title: String,
        owner: String? = nil,
        factorioVersions: String? = nil,
        lastUpdated: String? = nil,
        downloadsCount: Int = 0,
        summary: String? = nil,
        isDeprecated: Bool = false,
        isInstalled: Bool = false,
        suggestedBy: [String]? = nil,
        isSelected: Bool? = nil,
        onToggleSelect: (() -> Void)? = nil,
        onInstall: @escaping () -> Void,
        onOpenDetails: @escaping () -> Void
    ) {
        self.name = name
        self.title = title.isEmpty ? name : title
        self.owner = owner
        self.factorioVersions = factorioVersions
        self.lastUpdated = lastUpdated
        self.downloadsCount = downloadsCount
        self.summary = summary
        self.isDeprecated = isDeprecated
        self.isInstalled = isInstalled
        self.suggestedBy = suggestedBy
        self.isSelected = isSelected
        self.onToggleSelect = onToggleSelect
        self.onInstall = onInstall
        self.onOpenDetails = onOpenDetails
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Optional Selection Checkbox (for AuthorBrowseView multi-select)
            if let isSelected = isSelected, let onToggleSelect = onToggleSelect {
                Button(action: onToggleSelect) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }

            // Mod Box Icon
            Image(systemName: "cube.box")
                .font(.system(size: 22))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)

            // Mod Info Column
            VStack(alignment: .leading, spacing: 4) {
                // Title + Badges
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))

                    if isInstalled {
                        StatusBadge(loc("installed_status"), icon: "checkmark.circle")
                    }

                    if isDeprecated {
                        StatusBadge(loc("deprecated_badge"), icon: "exclamationmark.triangle")
                    }
                }

                // Metadata Chips: Owner, Version, Last Updated, Downloads, Suggested By
                HStack(spacing: 12) {
                    if let owner = owner, !owner.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "person")
                            Text(owner)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if let versions = factorioVersions, !versions.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                            Text(versions)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if let updated = lastUpdated, !updated.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(updated)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if downloadsCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text(String(format: loc("downloads_count_badge"), Formatters.formatDownloads(downloadsCount)))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    if let suggested = suggestedBy, !suggested.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "puzzlepiece")
                            Text(loc("suggested_by") + ": " + suggested.joined(separator: ", "))
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                // Summary (2 lines max)
                if let summary = summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Spacer()

            // Right Action Buttons
            VStack(spacing: 6) {
                if isInstalled {
                    Button(action: {}) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text(loc("installed_button"))
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(true)
                } else {
                    Button(action: onInstall) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                            Text(loc("install_button"))
                                .fontWeight(.semibold)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                Button(action: onOpenDetails) {
                    Text(loc("details_button"))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenDetails()
        }
    }
}
