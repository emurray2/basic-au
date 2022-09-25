//
//  A_Basic_Audio_UnitExtensionParameterAddresses.h
//  A Basic Audio UnitExtension
//
//  Created by Aura Audio on 9/25/22.
//

#pragma once

#include <AudioToolbox/AUParameters.h>

#ifdef __cplusplus
namespace A_Basic_Audio_UnitExtensionParameterAddress {
#endif

typedef NS_ENUM(AUParameterAddress, A_Basic_Audio_UnitExtensionParameterAddress) {
    gain = 0
};

#ifdef __cplusplus
}
#endif
