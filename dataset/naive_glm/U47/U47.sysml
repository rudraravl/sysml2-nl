package CochlearImplantSystem {
    import ScalarValues::*;

    value type SoundPressure :> Real {
        attribute unit : String = "Pa";
    }

    value type ElectricPotential :> Real {
        attribute unit : String = "V";
    }

    value type ElectricCurrent :> Real {
        attribute unit : String = "uA";
    }

    value type Frequency :> Real {
        attribute unit : String = "Hz";
    }

    value type Power :> Real {
        attribute unit : String = "mW";
    }

    value type TimeDuration :> Real {
        attribute unit : String = "ms";
    }

    value type SoundPressureLevel :> Real {
        attribute unit : String = "dB SPL";
    }

    item def AcousticSignal {
        attribute soundPressure : SoundPressure;
        attribute frequency : Frequency;
        attribute duration : TimeDuration;
        attribute intensity : SoundPressureLevel;
    }

    item def EncodedStimulusPattern {
        attribute electrodeId : Integer;
        attribute pulseAmplitude : ElectricCurrent;
        attribute pulseWidth : TimeDuration;
        attribute stimulationRate : Frequency;
        attribute channelFrequency : Frequency;
    }

    item def ElectricalPulse {
        attribute amplitude : ElectricCurrent;
        attribute pulseWidth : TimeDuration;
        attribute electrodeId : Integer;
        attribute phase : Integer;
    }

    item def WirelessTransmission {
        attribute encodedData : EncodedStimulusPattern[1..*];
        attribute carrierFrequency : Frequency;
        attribute transmittedPower : Power;
        attribute dataRate : Frequency;
    }

    port def AcousticPort {
        out acousticSignal : AcousticSignal;
    }

    port def AudioSignalPort {
        out audioSignal : AcousticSignal;
    }

    port def EncodedPatternPort {
        out pattern : EncodedStimulusPattern[1..*];
    }

    port def WirelessPort {
        out transmission : WirelessTransmission;
    }

    port def StimulationPort {
        out pulse : ElectricalPulse;
    }

    action def CaptureSound {
        in ambientSound : AcousticSignal;
        out audioSignal : AcousticSignal;
    }

    action def FilterAndAnalyze {
        in audioSignal : AcousticSignal;
        out filteredSignal : AcousticSignal;
    }

    action def EncodePattern {
        in filteredSignal : AcousticSignal;
        out encodedPattern : EncodedStimulusPattern[1..*];
    }

    action def ProcessSound {
        in audioSignal : AcousticSignal;
        out encodedPattern : EncodedStimulusPattern[1..*];

        perform filterAndAnalyze : FilterAndAnalyze;
        perform encodePattern : EncodePattern;

        flow from filterAndAnalyze.filteredSignal to encodePattern.filteredSignal;
    }

    action def TransmitPattern {
        in encodedPattern : EncodedStimulusPattern[1..*];
        out transmission : WirelessTransmission;
    }

    action def ReceivePattern {
        in transmission : WirelessTransmission;
        out encodedPattern : EncodedStimulusPattern[1..*];
    }

    action def GeneratePulse {
        in encodedPattern : EncodedStimulusPattern[1..*];
        out electricalPulse : ElectricalPulse;
    }

    action def StimulateNerve {
        in electricalPulse : ElectricalPulse;
    }

    part def Microphone {
        port acousticIn : AcousticPort;
        port audioOut : AudioSignalPort;

        attribute sensitivity : SoundPressure;
        attribute frequencyResponseMin : Frequency;
        attribute frequencyResponseMax : Frequency;
        attribute powerConsumption : Power;

        perform capture : CaptureSound;
    }

    part def SpeechProcessor {
        port audioIn : ~AudioSignalPort;
        port patternOut : EncodedPatternPort;

        attribute processingLatency : TimeDuration;
        attribute channelCount : Integer;
        attribute frequencyRangeMin : Frequency;
        attribute frequencyRangeMax : Frequency;
        attribute maxStimulationRate : Frequency;
        attribute compressionRatio : Real;

        perform process : ProcessSound;
    }

    part def ExternalTransmitter {
        port patternIn : ~EncodedPatternPort;
        port wirelessOut : WirelessPort;

        attribute carrierFrequency : Frequency;
        attribute transmissionPower : Power;
        attribute coilDiameter : Real;
        attribute dataRate : Frequency;

        perform transmit : TransmitPattern;
    }

    part def Battery {
        attribute capacity : Power;
        attribute voltage : ElectricPotential;
        attribute batteryLife : TimeDuration;
        attribute chargeLevel : Real;
    }

    part def InternalReceiver {
        port wirelessIn : ~WirelessPort;
        port patternOut : EncodedPatternPort;

        attribute receiverSensitivity : Power;
        attribute coilDiameter : Real;

        perform receive : ReceivePattern;
    }

    part def CurrentStimulator {
        port patternIn : ~EncodedPatternPort;
        port pulseOut : StimulationPort;

        attribute maxCurrent : ElectricCurrent;
        attribute minPulseWidth : TimeDuration;
        attribute maxPulseWidth : TimeDuration;
        attribute pulseRate : Frequency;
        attribute complianceVoltage : ElectricPotential;

        perform generate : GeneratePulse;
    }

    part def ElectrodeArray {
        port pulseIn : ~StimulationPort;

        attribute electrodeCount : Integer;
        attribute contactMaterial : String;
        attribute insertionDepth : Real;
        attribute arrayLength : Real;
        attribute contactSpacing : Real;

        perform stimulate : StimulateNerve;
    }

    part def ExternalUnit {
        port acousticInput : AcousticPort;
        port wirelessOutput : WirelessPort;

        part microphone : Microphone;
        part speechProcessor : SpeechProcessor;
        part externalTransmitter : ExternalTransmitter;
        part battery : Battery;

        connection externalAcousticInput connect acousticInput to microphone.acousticIn;
        connection acousticToProcessor connect microphone.audioOut to speechProcessor.audioIn;
        connection processorToTransmitter connect speechProcessor.patternOut to externalTransmitter.patternIn;
        connection externalWirelessOutput connect externalTransmitter.wirelessOut to wirelessOutput;
    }

    part def InternalUnit {
        port wirelessInput : ~WirelessPort;

        part internalReceiver : InternalReceiver;
        part currentStimulator : CurrentStimulator;
        part electrodeArray : ElectrodeArray;

        connection wirelessToReceiver connect wirelessInput to internalReceiver.wirelessIn;
        connection receiverToStimulator connect internalReceiver.patternOut to currentStimulator.patternIn;
        connection stimulatorToElectrode connect currentStimulator.pulseOut to electrodeArray.pulseIn;
    }

    enum def OperationalState {
        ACTIVE;
        STANDBY;
        FAULT;
    }

    state def SystemStateMachine {
        attribute currentState : OperationalState;
        attribute noSoundDetected : Boolean;
        attribute soundDetected : Boolean;
        attribute systemError : Boolean;
        attribute reset : Boolean;
        attribute standbyTimer : TimeDuration;

        entry; then active;

        state active {
            entry { currentState = OperationalState::ACTIVE; }
            do {
                // Continuously cycle through capture, process, and stimulate
            }
        }

        state standby {
            entry { currentState = OperationalState::STANDBY; }
        }

        state fault {
            entry { currentState = OperationalState::FAULT; }
        }

        transition activeToStandby from active to standby when (noSoundDetected);
        transition standbyToActive from standby to active when (soundDetected);
        transition activeToFault from active to fault when (systemError);
        transition standbyToFault from standby to fault when (systemError);
        transition faultToActive from fault to active when (reset);
    }

    part def CochlearImplant {
        port acousticInput : AcousticPort;

        part externalUnit : ExternalUnit;
        part internalUnit : InternalUnit;

        connection systemAcousticInput connect acousticInput to externalUnit.acousticInput;
        connection wirelessLink connect externalUnit.wirelessOutput to internalUnit.wirelessInput;

        perform systemBehavior : SystemStateMachine;
    }

    part cochlearImplant : CochlearImplant;

    requirement def SoundCaptureRequirement {
        doc "The microphone shall capture ambient sounds with pressure levels from 25 dB SPL to 120 dB SPL.";
        attribute minSoundPressureLevel : SoundPressureLevel = 25.0;
        attribute maxSoundPressureLevel : SoundPressureLevel = 120.0;
    }

    requirement def ProcessingLatencyRequirement {
        doc "The speech processor shall convert audio signals to encoded stimulus patterns within 10 ms.";
        attribute maxLatency : TimeDuration = 10.0;
    }

    requirement def WirelessTransmissionRequirement {
        doc "The external transmitter shall transmit encoded patterns through the skin at carrier frequency 49 MHz.";
        attribute requiredCarrierFrequency : Frequency = 49000000.0;
        attribute minTransmittedPower : Power = 5.0;
    }

    requirement def StimulationRequirement {
        doc "The current stimulator shall generate electrical pulses with amplitudes up to 1800 uA.";
        attribute maxStimulationCurrent : ElectricCurrent = 1800.0;
        attribute minPulseWidth : TimeDuration = 25.0;
        attribute maxPulseWidth : TimeDuration = 400.0;
    }

    requirement def ElectrodeCountRequirement {
        doc "The electrode array shall contain at least 12 electrode contacts.";
        attribute minElectrodeCount : Integer = 12;
    }

    requirement def StandbyModeRequirement {
        doc "The system shall enter standby mode when no sound is detected for more than 5 seconds.";
        attribute standbyTimeout : TimeDuration = 5000.0;
    }

    requirement def RealTimePerceptionRequirement {
        doc "The system shall continuously cycle through capturing, processing, and stimulating to provide real-time perception of sound.";
        attribute maxEndToEndLatency : TimeDuration = 50.0;
    }

    requirement def HearingRestorationRequirement {
        doc "The cochlear implant system shall restore a sense of hearing to individuals with severe to profound hearing loss by directly stimulating the auditory nerve.";
        attribute targetFrequencyRangeMin : Frequency = 250.0;
        attribute targetFrequencyRangeMax : Frequency = 8000.0;
    }

    requirement soundCaptureReq : SoundCaptureRequirement;
    requirement processingLatencyReq : ProcessingLatencyRequirement;
    requirement wirelessTransmissionReq : WirelessTransmissionRequirement;
    requirement stimulationReq : StimulationRequirement;
    requirement electrodeCountReq : ElectrodeCountRequirement;
    requirement standbyModeReq : StandbyModeRequirement;
    requirement realTimePerceptionReq : RealTimePerceptionRequirement;
    requirement hearingRestorationReq : HearingRestorationRequirement;

    satisfy soundCaptureReq by cochlearImplant.externalUnit.microphone;
    satisfy processingLatencyReq by cochlearImplant.externalUnit.speechProcessor;
    satisfy wirelessTransmissionReq by cochlearImplant.externalUnit.externalTransmitter;
    satisfy stimulationReq by cochlearImplant.internalUnit.currentStimulator;
    satisfy electrodeCountReq by cochlearImplant.internalUnit.electrodeArray;
    satisfy standbyModeReq by cochlearImplant;
    satisfy realTimePerceptionReq by cochlearImplant;
    satisfy hearingRestorationReq by cochlearImplant;
}
