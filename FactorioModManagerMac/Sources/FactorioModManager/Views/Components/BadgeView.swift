import SwiftUI

public struct StatusBadge: View {
    public let title: String
    public let color: Color
    public var icon: String? = nil

    public init(_ title: String, color: Color, icon: String? = nil) {
        self.title = title
        self.color = color
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(color.opacity(0.25), lineWidth: 0.8)
        )
    }
}

public struct VersionBadge: View {
    public let version: String
    public var isV2: Bool = false

    public init(_ version: String) {
        self.version = version
        self.isV2 = version.contains("2.0") || version.contains("2.1") || version.hasPrefix("2.")
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "tag.fill")
                .font(.system(size: 9))
            Text("v\(version)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(isV2 ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.12))
        .foregroundColor(isV2 ? Color.orange : Color.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

public struct DependencyBadge: View {
    public let type: DependencyType

    public init(type: DependencyType) {
        self.type = type
    }

    public var body: some View {
        switch type {
        case .required:
            StatusBadge(loc("dep_required"), color: .green, icon: "checkmark.circle.fill")
        case .recommended:
            StatusBadge(loc("dep_recommended"), color: .cyan, icon: "plus.circle.fill")
        case .optional:
            StatusBadge(loc("dep_optional"), color: .yellow, icon: "questionmark.circle.fill")
        case .incompatible:
            StatusBadge(loc("dep_conflict"), color: .red, icon: "exclamationmark.triangle.fill")
        }
    }
}
