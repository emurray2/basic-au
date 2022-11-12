#include "DSPBase.h"
#include "ParameterRamper.h"

enum BasicAudioUnitParameter : AUParameterAddress {
    BasicAudioUnitParameterGain
};

struct BasicAudioUnitDSP : DSPBase {
private:
    ParameterRamper gainRamp{1.0};

public:
    BasicAudioUnitDSP() : DSPBase(1, true) {
        parameters[BasicAudioUnitParameterGain] = &gainRamp;
    }

    // Uses the ParameterAddress as a key
    void setParameter(AUParameterAddress address, AUValue value, bool immediate) override {
        switch (address) {
            default:
                DSPBase::setParameter(address, value, immediate);
        }
    }

    // Uses the ParameterAddress as a key
    float getParameter(AUParameterAddress address) override {
        switch (address) {
            default:
                return DSPBase::getParameter(address);
        }
    }

    void startRamp(const AUParameterEvent &event) override {
        auto address = event.parameterAddress;
        switch (address) {
            default:
                DSPBase::startRamp(event);
        }
    }

    void process(FrameRange range) override {
        for (auto i : range) {

            float leftIn = inputSample(0, i);
            float rightIn = inputSample(1, i);

            float& leftOut = outputSample(0, i);
            float& rightOut = outputSample(1, i);

            float gain = gainRamp.getAndStep();

            leftOut = leftIn * gain;
            rightOut = rightIn * gain;
        }
    }
};

AK_REGISTER_DSP(BasicAudioUnitDSP, "abau")
AK_REGISTER_PARAMETER(BasicAudioUnitParameterGain)
