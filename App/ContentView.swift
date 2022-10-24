import AudioToolbox
import SwiftUI

struct ContentView: View {
    @ObservedObject var hostModel: AudioUnitHostModel
    var margin = 10.0
    var doubleMargin: Double {
        margin * 2.0
    }
    
    var body: some View {
        VStack() {
            Text("\(hostModel.viewModel.title )")
                .textSelection(.enabled)
                .padding()
            VStack(alignment: .center) {
                if let viewController = hostModel.viewModel.viewController {
                    AUViewControllerUI(viewController: viewController)
                        .padding(margin)
                } else {
                    VStack() {
                        Text(hostModel.viewModel.message)
                            .padding()
                    }
                    .frame(minWidth: 400, minHeight: 200)
                }
            }
            .padding(doubleMargin)
            Spacer()
                .frame(height: margin)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(hostModel: AudioUnitHostModel())
    }
}
