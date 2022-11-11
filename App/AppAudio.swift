import Foundation
import CoreAudioKit
import AVFoundation
import UIKit

extension AVAudioUnit {
    static fileprivate func findComponent(type: String, subType: String, manufacturer: String) -> AVAudioUnitComponent? {
        let description = AudioComponentDescription(componentType: type.fourCharCode!,
                                                    componentSubType: subType.fourCharCode!,
                                                    componentManufacturer: manufacturer.fourCharCode!,
                                                    componentFlags: 0,
                                                    componentFlagsMask: 0)
        return AVAudioUnitComponentManager.shared().components(matching: description).first
    }

    fileprivate func loadAudioUnitViewController(completion: @escaping (UIViewController?) -> Void) {
        auAudioUnit.requestViewController { [weak self] viewController in
            DispatchQueue.main.async {
                if #available(macOS 13.0, iOS 16.0, *) {
                    if let self = self, viewController == nil {
                            let genericViewController = AUGenericViewController()
                            genericViewController.auAudioUnit = self.auAudioUnit
                            completion(genericViewController)
                            return
                    }
                }
                completion(viewController)
            }
        }
    }
}

public class AppAudio {
    private var avAudioUnit: AVAudioUnit?
    private let engine = AVAudioEngine()
    private let mixer = AVAudioMixerNode()

    // This block will be called every render cycle and will receive MIDI events
    private let midiOutBlock: AUMIDIOutputEventBlock = { sampleTime, cable, length, data in return noErr }

    // This block can be used to send MIDI UMP events to the Audio Unit
    var scheduleMIDIEventListBlock: AUMIDIEventListBlock? = nil

    public init() {
        engine.attach(mixer)
        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
        engine.prepare()
        setupMIDI()
    }

    private func setupMIDI() {
        if !MIDIManager.shared.setupPort(midiProtocol: MIDIProtocolID._2_0, receiveBlock: { [weak self] eventList, _ in
            if let scheduleMIDIEventListBlock = self?.scheduleMIDIEventListBlock {
                _ = scheduleMIDIEventListBlock(AUEventSampleTimeImmediate, 0, eventList)
            }
        }) {
            fatalError("Failed to setup Core MIDI")
        }
    }

    func initComponent(type: String, subType: String, manufacturer: String, completion: @escaping (Result<Bool, Error>, UIViewController?) -> Void) {
        // Reset the engine to remove any configured audio units.
        reset()

        guard let component = AVAudioUnit.findComponent(type: type, subType: subType, manufacturer: manufacturer) else {
            fatalError("Failed to find component with type: \(type), subtype: \(subType), manufacturer: \(manufacturer))" )
        }

        // Instantiate the audio unit.
        AVAudioUnit.instantiate(with: component.audioComponentDescription,
                                options: AudioComponentInstantiationOptions.loadOutOfProcess) { avAudioUnit, error in

            guard let audioUnit = avAudioUnit, error == nil else {
                completion(.failure(error!), nil)
                return
            }

            self.avAudioUnit = audioUnit

            self.connect(avAudioUnit: audioUnit)

            audioUnit.loadAudioUnitViewController { viewController in
                completion(.success(true), viewController)
            }
        }
    }

    private func setSessionActive(_ active: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(active)
        } catch {
            fatalError("Could not set Audio Session active \(active). error: \(error).")
        }
    }

    public func start() {
        setSessionActive(true)

        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

        do {
            try engine.start()
        } catch {
            fatalError("Could not start engine. error: \(error).")
        }
    }

    public func stop() {
        engine.stop()
        setSessionActive(false)
    }

    public func reset() {
        connect(avAudioUnit: nil)
    }

    public func connect(avAudioUnit: AVAudioUnit?) {
        guard let avAudioUnit = self.avAudioUnit else {
            return
        }

        // Break the audio unit -> mixer connection
        engine.disconnectNodeInput(engine.mainMixerNode)

        // We're done with the unit; release all references.
        engine.detach(avAudioUnit)

        // Internal function to resume playing.
        func rewiringComplete() {
            scheduleMIDIEventListBlock = auAudioUnit.scheduleMIDIEventListBlock
        }

        let hardwareFormat = engine.outputNode.outputFormat(forBus: 0)

        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: hardwareFormat)

        let auAudioUnit = avAudioUnit.auAudioUnit

        if !auAudioUnit.midiOutputNames.isEmpty {
            auAudioUnit.midiOutputEventBlock = midiOutBlock
        }

        engine.attach(avAudioUnit)

        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: hardwareFormat.sampleRate, channels: 2)
        engine.connect(avAudioUnit, to: engine.mainMixerNode, format: stereoFormat)
        rewiringComplete()
    }
}
