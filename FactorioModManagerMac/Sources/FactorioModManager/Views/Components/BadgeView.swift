import SwiftUI

public struct StatusBadge: View {
    public let title: String
    public let color: Color
    public var icon: String? = nil

    public init(_ title: String, color: Color = .secondary, icon: String? = nil) {
        self.title = title
        self.color = color
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
        .background(color.opacity(0.12))
        .foregroundColor(color == .secondary ? .primary : color)
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
            StatusBadge(loc("dep_required"), color: .green, icon: "checkmark.circle.fill")
        case .recommended:
            StatusBadge(loc("dep_recommended"), color: .blue, icon: "plus.circle.fill")
        case .optional:
            StatusBadge(loc("dep_optional"), color: .secondary, icon: "questionmark.circle")
        case .incompatible:
            StatusBadge(loc("dep_conflict"), color: .red, icon: "exclamationmark.triangle.fill")
        }
    }
}
