import Foundation
import Testing
@testable import FactorioModManagerMac

@Suite(.tags(.fast), .timeLimit(.minutes(1)))
struct DiscoveryNavCoordinatorTests {
    @MainActor
    @Test
    func clampsFocusToLastItem() {
        let coordinator = DiscoveryNavCoordinator(targetTab: .search)
        coordinator.focusedIndex = 7
        coordinator.clampIndex(count: 3)
        #expect(coordinator.focusedIndex == 2, "focus cannot point past the end of a shrunk list")
    }

    @MainActor
    @Test
    func resetsFocusForEmptyList() {
        let coordinator = DiscoveryNavCoordinator(targetTab: .authors)
        coordinator.focusedIndex = 4
        coordinator.clampIndex(count: 0)
        #expect(coordinator.focusedIndex == 0, "an empty list has its focus at the top")
    }

    @MainActor
    @Test
    func deselectsModOnSecondToggle() {
        let coordinator = DiscoveryNavCoordinator(targetTab: .search)
        coordinator.toggleSelect(name: "Squeak Through")
        coordinator.toggleSelect(name: "Squeak Through")
        #expect(coordinator.selectedModNames.isEmpty, "toggling twice leaves nothing selected")
    }

    @MainActor
    @Test
    func clearsSelectionWhenEverythingIsSelected() {
        let coordinator = DiscoveryNavCoordinator(targetTab: .search)
        coordinator.selectedModNames = ["flib", "Krastorio2"]
        coordinator.toggleSelectAll(items: ["Krastorio2", "flib"])
        #expect(coordinator.selectedModNames.isEmpty, "Cmd+A on a fully selected list deselects it")
    }

    @MainActor
    @Test
    func selectsVisibleItemsWhenSelectionHoldsOthers() {
        let coordinator = DiscoveryNavCoordinator(targetTab: .search)
        coordinator.selectedModNames = ["hidden-a", "hidden-b"]
        coordinator.toggleSelectAll(items: ["flib", "Krastorio2"])
        #expect(coordinator.selectedModNames == ["flib", "Krastorio2"], "items from an old search must not count as selected")
    }
}
