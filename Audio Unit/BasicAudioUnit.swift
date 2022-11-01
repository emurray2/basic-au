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

        for _ in availableViewConfigurations {
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

class BasicAudioUnit: AudioKitAUv3 {
    var engine: AudioEngine!
    var osc: PlaygroundOscillator!

    public override init(componentDescription: AudioComponentDescription,
                  options: AudioComponentInstantiationOptions = []) throws {
        do {
            try super.init(componentDescription: componentDescription, options: options)
            try setOutputBusArrays()
        } catch let err {
            Log(err, type: .error)
            throw err
        }
        setInternalRenderingBlock()
    }

    override public func allocateRenderResources() throws {
        engine = AudioEngine()
        osc = PlaygroundOscillator()
        engine.output = osc
        do {
            try engine.avEngine.enableManualRenderingMode(.offline, format: outputBus.format, maximumFrameCount: 4096)
            Settings.disableAVAudioSessionCategoryManagement = true
            let sessionSize = Settings.session.sampleRate * Settings.session.ioBufferDuration
            if let length = Settings.BufferLength.init(rawValue: Int(sessionSize.rounded())) {
                Settings.bufferLength = length
            }
            Settings.sampleRate = outputBus.format.sampleRate
            try engine.start()
            osc.start()
            try super.allocateRenderResources()
            setInitialValues()
        } catch {
            return
        }
    }

    override public func deallocateRenderResources() {
        engine.stop()
        super.deallocateRenderResources()
    }

    public func setupParameterTree(parameterTree: AUParameterTree) {
        _parameterTree = parameterTree
        createParamSetters()
    }

    private func handleEvents(eventsList: AURenderEvent?, timestamp: UnsafePointer<AudioTimeStamp>) {
        var nextEvent = eventsList
        while nextEvent != nil {
            if nextEvent!.head.eventType == .MIDI {
                //handleMIDI(midiEvent: nextEvent!.MIDI, timestamp: timestamp)
            }
            nextEvent = nextEvent!.head.next?.pointee
        }
    }

    private func setInternalRenderingBlock() {
        self._internalRenderBlock = { [weak self] (actionflags, timestamp, frameCount, outputBusNumber, outputData, renderEvent, pullInputBlock) in
            guard let self = self else { return 1 }
            if let eventList = renderEvent?.pointee {
                self.handleEvents(eventsList: eventList, timestamp: timestamp)
            }

            // Render the audio
            _ = self.engine.avEngine.manualRenderingBlock(frameCount, outputData, nil)
            return noErr
        }
    }
    
    private func createParamSetters() {
        guard let paramTree = self.parameterTree else { return }
        paramTree.implementorValueObserver = { param, floatValue in
            let parameterAddress = ParameterAddress(rawValue: param.address)
            switch(parameterAddress) {
            case .gain:
                guard let mainMixer = self.engine.mainMixerNode else { return }
                mainMixer.volume = floatValue
            default:
                break;
            }
        }
    }
    
    private func setInitialValues() {
        guard let mainMixer = self.engine.mainMixerNode else { return }
        mainMixer.volume = 0.25
    }
}
