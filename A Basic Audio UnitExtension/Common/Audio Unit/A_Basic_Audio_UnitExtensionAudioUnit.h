//
//  A_Basic_Audio_UnitExtensionAudioUnit.h
//  A Basic Audio UnitExtension
//
//  Created by Aura Audio on 9/25/22.
//

#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface A_Basic_Audio_UnitExtensionAudioUnit : AUAudioUnit
- (void)setupParameterTree:(AUParameterTree *)parameterTree;
@end
