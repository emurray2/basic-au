import AudioKit
import AVFoundation
import CoreAudioKit
import CAudioKitEX

open class AudioKitAUv3: AUAudioUnit {
    var mcb: AUHostMusicalContextBlock?
    var tsb: AUHostTransportStateBlock?
    var moeb: AUMIDIOutputEventBlock?

    override public var channelCapabilities: [NSNumber]? {
        return [0, 2]
    }

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
        outputBus = try AUAudioUnitBus(format: AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!)
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

fileprivate extension AUAudioUnitPreset {
    convenience init(number: Int, name: String) {
        self.init()
        self.number = number
        self.name = name
    }
}

class BasicAudioUnit: AudioKitAUv3 {
    var engine: AudioEngine!
    var osc: MIDISampler!

    public override var factoryPresets: [AUAudioUnitPreset] {
        return [
            AUAudioUnitPreset(number: 0, name: "Hello Preset")
        ]
    }

    private let factoryPresetValues:[(
        pr_gain: AUValue,
        _
    )] = [
        (1.0, 0.0) // 1.0 - gain value, 0.0 - dummy value
    ]

    private var _currentPreset: AUAudioUnitPreset?
    public override var currentPreset: AUAudioUnitPreset? {
        get { return _currentPreset }
        set {
            // If the newValue is nil, return.
            guard let preset = newValue else {
                print("bad")
                _currentPreset = nil
                return
            }

            // Factory presets need to always have a number >= 0.
            if preset.number >= 0 {
                let values = factoryPresetValues[preset.number]
                self.setPresetValues(
                    pr_gain: values.pr_gain
                )
                _currentPreset = preset
            }
        }
    }

    func setPresetValues(
        pr_gain: AUValue
    ) {
        self.parameterTree?.parameter(withAddress: 0)?.value = pr_gain // hardcode gain address for now
    }

    /// DSP Reference
    public private(set) var dsp: DSPRef?

    public override init(componentDescription: AudioComponentDescription,
                  options: AudioComponentInstantiationOptions = []) throws {
        do {
            try super.init(componentDescription: componentDescription, options: options)

            // Create pointer to C++ DSP code.
            dsp = akCreateDSP(componentDescription.componentSubType)
            assert(dsp != nil)

            try setOutputBusArrays()
        } catch let err {
            Log(err, type: .error)
            throw err
        }
        setInternalRenderingBlock()
    }

    deinit {
        deleteDSP(dsp)
    }

    override public func allocateRenderResources() throws {
        if outputBus.format.channelCount != 2 {
            throw NSError(domain: NSOSStatusErrorDomain,
                          code: Int(kAudioUnitErr_FailedInitialization),
                          userInfo: nil)
        }
        engine = AudioEngine()
        osc = MIDISampler()
        engine.output = osc
        do {
            try engine.avEngine.enableManualRenderingMode(.realtime, format: outputBus.format, maximumFrameCount: 4096)
            try engine.start()
            osc.start()
            try super.allocateRenderResources()
            initializeParameters()
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
    }

    private func handleParameter(parameterEvent event: AUParameterEvent, timestamp: UnsafePointer<AudioTimeStamp>) {
        parameterTree?.parameter(withAddress: event.parameterAddress)?.value = event.value
    }

    private func handleMIDI(midiEvent event: AUMIDIEvent) {
        let midiEvent = MIDIEvent(data: [event.data.0, event.data.1, event.data.2])
        guard let statusType = midiEvent.status?.type else { return }
        switch(statusType) {
        case .noteOn:
            try! osc.receivedMIDINoteOn(noteNumber: midiEvent.noteNumber ?? 0,
                                        velocity: midiEvent.data[1],
                                        channel: midiEvent.channel ?? 0)
        case .noteOff:
            osc.stop(noteNumber: midiEvent.noteNumber ?? 0,
                     channel: midiEvent.channel ?? 0)
        case .controllerChange:
            osc.midiCC(midiEvent.data[1],
                       value: midiEvent.data[2],
                       channel: midiEvent.channel ?? 0)
        case .pitchWheel:
            osc.setPitchbend(amount: midiEvent.pitchbendAmount ?? 0,
                             channel: midiEvent.channel ?? 0)
        default:
            break;
        }
    }

    private func handleEvents(eventsList: AURenderEvent?, timestamp: UnsafePointer<AudioTimeStamp>) {
        var nextEvent = eventsList
        while nextEvent != nil {
            if nextEvent!.head.eventType == .MIDI {
                handleMIDI(midiEvent: nextEvent!.MIDI)
            } else if nextEvent!.head.eventType == .parameter || nextEvent!.head.eventType == .parameterRamp {
                handleParameter(parameterEvent: nextEvent!.parameter, timestamp: timestamp)
            }
            nextEvent = nextEvent!.head.next?.pointee
        }
    }

    private func setInternalRenderingBlock() {
        self._internalRenderBlock = { [weak self] (actionflags,
                                                   timestamp,
                                                   frameCount,
                                                   outputBusNumber,
                                                   outputData,
                                                   renderEvent,
                                                   pullInputBlock) in
            guard let self = self else { return 1 }
            if let eventList = renderEvent?.pointee {
                self.handleEvents(eventsList: eventList, timestamp: timestamp)
            }

            // Render the audio
            _ = self.engine.avEngine.manualRenderingBlock(frameCount, outputData, nil)
            return noErr
        }
    }

    private func initializeParameters() {
        guard let paramTree = self.parameterTree else { return }
        for param in paramTree.allParameters {
            let parameterAddress = ParameterAddress(rawValue: param.address)
            switch(parameterAddress) {
            case .gain:
                self.engine.mainMixerNode?.volume = param.value
            default:
                break;
            }
        }
        paramTree.implementorValueObserver = { [weak self] param, floatValue in
            guard let self = self else { return }
            let parameterAddress = ParameterAddress(rawValue: param.address)
            switch(parameterAddress) {
            case .gain:
                self.engine.mainMixerNode?.volume = floatValue
            default:
                break;
            }
        }
        paramTree.implementorValueProvider = { [weak self] param in
            guard let self = self else { return 0.0 }
            let parameterAddress = ParameterAddress(rawValue: param.address)
            switch(parameterAddress) {
            case .gain:
                return self.engine.mainMixerNode?.volume ?? 0.0
            default:
                break;
            }
            return 0.0
        }
    }
}
