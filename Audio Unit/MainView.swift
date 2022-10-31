import SwiftUI

struct MainView: View {
    var parameterTree: ObservableAUParameterGroup

    var body: some View {
        ParameterSlider(param: parameterTree.global.gain)
    }
}
