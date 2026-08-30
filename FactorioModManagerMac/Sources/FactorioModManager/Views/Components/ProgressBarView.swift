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
                        Image(systemName: "xmark.circle.fill")
                        Text(err)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                } else if progress.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Installed")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
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
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            progress.error != nil
                                ? Color.red
                                : (progress.isCompleted ? Color.green : Color.accentColor)
                        )
                        .frame(width: max(4, geo.size.width * CGFloat(progress.fractionCompleted)), height: 6)
                        .animation(.linear(duration: 0.1), value: progress.fractionCompleted)
                }
            }
            .frame(height: 6)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
