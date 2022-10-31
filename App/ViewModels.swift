import SwiftUI

struct AudioUnitViewModel { var viewController: UIViewController? }

class AudioUnitHostModel: ObservableObject {
    private let appAudio = AppAudio()

    @Published private(set) var viewModel = AudioUnitViewModel()

    init() { loadAudioUnit() }

    private func loadAudioUnit() {
        appAudio.initComponent(type: "aumu",
                                 subType: "abau",
                                 manufacturer: "Hwco") { [self] result, viewController in
            switch result {
            case .success(_):
                self.viewModel = AudioUnitViewModel(viewController: viewController)
                self.appAudio.start()

            case .failure(_):
                self.viewModel = AudioUnitViewModel(viewController: nil)
            }
        }
    }
}
