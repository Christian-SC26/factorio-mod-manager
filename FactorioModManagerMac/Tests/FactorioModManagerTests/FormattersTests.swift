import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct FormattersTests {
    @Test(arguments: [
        (500, "500 B"),
        (1_023, "1023 B"),
        (1_024, "1.0 KB"),
        (1_536, "1.5 KB"),
        (1_048_576, "1.0 MB"),
        (26_214_400, "25.0 MB"),
        (1_073_741_824, "1.00 GB")
    ] as [(Int64, String)])
    func formatsByteSizes(size: Int64, text: String) {
        #expect(Formatters.formatBytes(size) == text, "\(size) bytes must read as \(text)")
    }

    @Test(arguments: [1_048_575, 1_073_741_000] as [Int64])
    func neverShowsThousandTwentyFourOfUnit(size: Int64) {
        #expect(!Formatters.formatBytes(size).hasPrefix("1024"), "a rounded value of 1024 belongs to the next unit")
    }

    @Test(arguments: [
        (0, "0"),
        (42, "42"),
        (999, "999"),
        (1_000, "1.0k"),
        (1_500, "1.5k"),
        (45_300, "45.3k"),
        (1_200_000, "1.2M"),
        (25_000_000, "25.0M")
    ])
    func formatsDownloadCounts(count: Int, text: String) {
        #expect(Formatters.formatDownloads(count) == text, "\(count) downloads must read as \(text)")
    }

    @Test(arguments: [999_950, 999_999])
    func neverShowsThousandKilo(count: Int) {
        #expect(!Formatters.formatDownloads(count).hasPrefix("1000"), "a rounded thousand 'k' is one million")
    }

    @Test(arguments: [
        ("maraxsis", "Maraxsis"),
        ("factorissimo-2-notnotmelon", "Factorissimo 2 Notnotmelon"),
        ("space_exploration", "Space Exploration"),
        ("se-space-exploration", "SE Space Exploration"),
        ("custom_gui_hud", "Custom GUI HUD"),
        ("hd-textures-2d", "HD Textures 2D"),
        ("--__--", "")
    ])
    func titlesModNames(name: String, title: String) {
        #expect(Formatters.formatModNameAsTitle(name) == title, "'\(name)' must read as '\(title)'")
    }

    @Test(arguments: [".", "...", "   .   ", "", " - ", "\n\t"])
    func rejectsPunctuationOnlyTitles(title: String) {
        #expect(!Formatters.isValidHumanTitle(title), "'\(title)' has nothing to read")
    }

    @Test(arguments: ["Maraxsis", "Factorissimo 2", "A.", "Космос", "李"])
    func acceptsTitlesWithLetters(title: String) {
        #expect(Formatters.isValidHumanTitle(title), "'\(title)' is readable")
    }
}
