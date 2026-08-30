import SwiftUI

public struct StatusBadge: View {
    public let title: String
    public var icon: String? = nil

    public init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    public init(_ title: String, color: Color, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(title)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Color.secondary.opacity(0.12))
        .foregroundColor(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

public struct VersionBadge: View {
    public let version: String

    public init(_ version: String) {
        self.version = version
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "tag")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text("v\(version)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background(Color.secondary.opacity(0.12))
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
            StatusBadge(loc("dep_required"), icon: "checkmark.circle")
        case .recommended:
            StatusBadge(loc("dep_recommended"), icon: "plus.circle")
        case .optional:
            StatusBadge(loc("dep_optional"), icon: "questionmark.circle")
        case .incompatible:
            StatusBadge(loc("dep_conflict"), icon: "exclamationmark.triangle")
        }
    }
}
