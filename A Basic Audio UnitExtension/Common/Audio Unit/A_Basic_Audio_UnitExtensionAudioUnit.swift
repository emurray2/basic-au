//
//  A_Basic_Audio_UnitExtensionAudioUnit.swift
//  A Basic Audio UnitExtension
//
//  Created by Aura Audio on 9/25/22.
//

import AudioKit
import AVFoundation
import CoreAudioKit

open class AudioKitAUv3: AUAudioUnit {

    var mcb: AUHostMusicalContextBlock?
    var tsb: AUHostTransportStateBlock?
    var moeb: AUMIDIOutputEventBlock?

    // Parameter tree stuff (for automation + control)
    open var _parameterTree: AUParameterTree!
    override open var parameterTree: AUParameterTree? {
        get { return self._parameterTree }
        set { _parameterTree = newValue }
    }

    // Internal Render block stuff
    open var _internalRenderBlock: AUInternalRenderBlock!
    override open var internalRenderBlock: AUInternalRenderBlock {
        return self._internalRenderBlock
    }

    // Default OutputBusArray stuff you will need
    var outputBus: AUAudioUnitBus!
    open var _outputBusArray: AUAudioUnitBusArray!
    override open var outputBusses: AUAudioUnitBusArray {
        return self._outputBusArray
    }
    open func setOutputBusArrays() throws {
        outputBus = try AUAudioUnitBus(format: Settings.audioFormat)
        self._outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus])
    }

    override open func supportedViewConfigurations(_ availableViewConfigurations: [AUAudioUnitViewConfiguration]) -> IndexSet {
        var index = 0
        var returnValue = IndexSet()

        for configuration in availableViewConfigurations {
            print("width", configuration.width)
            print("height", configuration.height)
            print("has controller", configuration.hostHasController)
            print("")
            returnValue.insert(index)
            index += 1
        }
        return returnValue // Support everything
    }

    override open func allocateRenderResources() throws {
        do {
            try super.allocateRenderResources()
        } catch {
            return
        }

        self.mcb = self.musicalContextBlock
        self.tsb = self.transportStateBlock
        self.moeb = self.midiOutputEventBlock

    }

    override open func deallocateRenderResources() {
        super.deallocateRenderResources()
        self.mcb = nil
        self.tsb = nil
        self.moeb = nil
    }

}

class A_Basic_Audio_UnitExtensionAudioUnit: AudioKitAUv3 {
    var engine: AudioEngine!
    var audioPlayer: AudioPlayer!
    public override init(componentDescription: AudioComponentDescription,
                  options: AudioComponentInstantiationOptions = []) throws {
        Settings.disableAVAudioSessionCategoryManagement = true
        engine = AudioEngine()
        audioPlayer = AudioPlayer(url: Bundle.main.url(forResource: "FunStuff", withExtension: "wav")!, buffered: true)
        audioPlayer.isLooping = true
        engine.output = Reverb(audioPlayer)
        do {
            try engine.avEngine.enableManualRenderingMode(.offline,
                                                          format: Settings.audioFormat,
                                                          maximumFrameCount: 4096)
            try engine.start()
            audioPlayer.play()
            try super.init(componentDescription: componentDescription, options: options)
            try setOutputBusArrays()
        } catch let err {
            Log(err, type: .error)
            throw err
        }
        setInternalRenderingBlock()
        log(componentDescription)
    }
    override public func allocateRenderResources() throws {
        do {
            try engine.avEngine.enableManualRenderingMode(.offline, format: outputBus.format, maximumFrameCount: 4096)
            Settings.disableAVAudioSessionCategoryManagement = true
            let sessionSize = Settings.session.sampleRate * Settings.session.ioBufferDuration
            if let length = Settings.BufferLength.init(rawValue: Int(sessionSize.rounded())) {
                Settings.bufferLength = length
            }
            Settings.sampleRate = outputBus.format.sampleRate
            try engine.start()
            audioPlayer.play()
            try super.allocateRenderResources()
        } catch {
            return
        }
        self.mcb = self.musicalContextBlock
        self.tsb = self.transportStateBlock
        self.moeb = self.midiOutputEventBlock
    }
    override public func deallocateRenderResources() {
        engine.stop()
        super.deallocateRenderResources()
        self.mcb = nil
        self.tsb = nil
        self.moeb = nil
    }
    private func handleParameter(parameterEvent event: AUParameterEvent, timestamp: UnsafePointer<AudioTimeStamp>) {
                // accurate to buffer size, when AKNodes support control signals w/ buffer offsets, use this code to get offset
        //        let diff = Float64(parameterPointer.eventSampleTime) - timestamp.pointee.mSampleTime
        //        let offset = MIDITimeStamp(UInt32(max(0, diff)))
            parameterTree?.parameter(withAddress: event.parameterAddress)?.value = event.value
        self.audioPlayer.mixerNode.volume = event.value
    }
    public func setupParameterTree(parameterTree: AUParameterTree) {
        _parameterTree = parameterTree
    }
    private func handleEvents(eventsList: AURenderEvent?, timestamp: UnsafePointer<AudioTimeStamp>) {
        var nextEvent = eventsList
        while nextEvent != nil {
            if nextEvent!.head.eventType == .MIDI {
                //handleMIDI(midiEvent: nextEvent!.MIDI, timestamp: timestamp)
            } else if (nextEvent!.head.eventType == .parameter ||  nextEvent!.head.eventType == .parameterRamp) {
                handleParameter(parameterEvent: nextEvent!.parameter, timestamp: timestamp)
                //print("Event:",nextEvent)
            }
            nextEvent = nextEvent!.head.next?.pointee
        }
    }
    private func setInternalRenderingBlock() {
        self._internalRenderBlock = { [weak self] (actionflags, timestamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock) in
            guard let self = self else { return 1 }
            self.audioPlayer.volume = self.parameterTree!.allParameters.first!.value
            if let eventList = renderEvent?.pointee {
                self.handleEvents(eventsList: eventList, timestamp: timestamp)
            }
            
            // Render the audio
            _ = self.engine.avEngine.manualRenderingBlock(frameCount, outputData, nil)
            return noErr
        }
    }
    private func log(_ acd: AudioComponentDescription) {

        let info = ProcessInfo.processInfo
        print("\nProcess Name: \(info.processName) PID: \(info.processIdentifier)\n")

        let message = """
        ExampleApp_Demo (
                  type: \(acd.componentType.stringValue)
               subtype: \(acd.componentSubType.stringValue)
          manufacturer: \(acd.componentManufacturer.stringValue)
                 flags: \(String(format: "%#010x", acd.componentFlags))
        )
        """
        print(message)
    }
}

extension FourCharCode {
    var stringValue: String {
        let value = CFSwapInt32BigToHost(self)
        let bytes = [0, 8, 16, 24].map { UInt8(value >> $0 & 0x000000FF) }
        guard let result = String(bytes: bytes, encoding: .macOSRoman) else {
            return "fail"
        }
        return result
    }
}
