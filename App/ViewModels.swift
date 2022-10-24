import SwiftUI
import AudioToolbox

struct AudioUnitViewModel {
    var viewController: UIViewController?
}

class AudioUnitHostModel: ObservableObject {
    /// The playback engine used to play audio.
    private let playEngine = SimplePlayEngine()

    /// The model providing information about the current Audio Unit
    @Published private(set) var viewModel = AudioUnitViewModel()

    var isPlaying: Bool {
        playEngine.isPlaying
    }

    init() {
        loadAudioUnit()
    }

    private func loadAudioUnit() {
        playEngine.initComponent(type: "aumu",
                                 subType: "abau",
                                 manufacturer: "Hwco") { [self] result, viewController in
            switch result {
            case .success(_):
                self.viewModel = AudioUnitViewModel(viewController: viewController)
                self.playEngine.startPlaying()

            case .failure(_):
                self.viewModel = AudioUnitViewModel(viewController: nil)
            }
        }
    }
}
