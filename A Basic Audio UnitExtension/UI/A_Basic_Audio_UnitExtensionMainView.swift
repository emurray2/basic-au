//
//  A_Basic_Audio_UnitExtensionMainView.swift
//  A Basic Audio UnitExtension
//
//  Created by Aura Audio on 9/25/22.
//

import SwiftUI

struct A_Basic_Audio_UnitExtensionMainView: View {
    var parameterTree: ObservableAUParameterGroup
    
    var body: some View {
        ParameterSlider(param: parameterTree.global.gain)
    }
}
