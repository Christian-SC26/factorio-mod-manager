import SwiftUI

public struct DependencyTreeNodeView: View {
    public let name: String
    public let graph: [String: [String]]
    public let depth: Int
    @State private var isExpanded: Bool = true

    public init(name: String, graph: [String: [String]], depth: Int = 0) {
        self.name = name
        self.graph = graph
        self.depth = depth
    }

    private var children: [String] {
        graph[name] ?? []
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if !children.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 5, height: 5)
                        .padding(.horizontal, 4.5)
                }

                Image(systemName: depth == 0 ? "cube.box.fill" : "puzzlepiece.extension.fill")
                    .font(.system(size: 12))
                    .foregroundColor(depth == 0 ? .accentColor : .secondary)

                Text(name)
                    .font(.system(size: 12, weight: depth == 0 ? .semibold : .regular))

                if !children.isEmpty {
                    Text("(\(children.count))")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, CGFloat(depth * 18))

            if isExpanded && !children.isEmpty {
                ForEach(children, id: \.self) { child in
                    DependencyTreeNodeView(name: child, graph: graph, depth: depth + 1)
                }
            }
        }
    }
}

public struct DependencyTreeView: View {
    public let roots: [String]
    public let graph: [String: [String]]

    public init(roots: [String], graph: [String: [String]]) {
        self.roots = roots
        self.graph = graph
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(roots, id: \.self) { root in
                DependencyTreeNodeView(name: root, graph: graph, depth: 0)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
