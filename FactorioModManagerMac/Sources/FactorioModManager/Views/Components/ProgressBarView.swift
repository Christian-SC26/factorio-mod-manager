import SwiftUI

public struct DownloadProgressBar: View {
    public let progress: DownloadProgress

    public init(progress: DownloadProgress) {
        self.progress = progress
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(progress.modName)
                    .font(.system(size: 13, weight: .semibold))
                Text("v\(progress.version)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                if let err = progress.error {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle")
                        Text(err)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                } else if progress.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                        Text("Installed")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
                } else {
                    let speed = formatBytes(Int64(progress.speedBytesPerSec))
                    let cur = formatBytes(progress.bytesDownloaded)
                    let tot = progress.totalBytes > 0 ? formatBytes(progress.totalBytes) : "?"
                    Text("\(cur) / \(tot) (\(speed)/s)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 5)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.primary.opacity(progress.isCompleted ? 0.9 : 0.7))
                        .frame(width: max(4, geo.size.width * CGFloat(progress.fractionCompleted)), height: 5)
                        .animation(.linear(duration: 0.1), value: progress.fractionCompleted)
                }
            }
            .frame(height: 5)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
