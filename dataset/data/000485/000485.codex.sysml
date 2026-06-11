package ParadromicsInspiredBCIModel {
    import ScalarValues::*;
    import SI::*;

    value type Microvolt specializes Real;
    value type Hertz specializes Real;
    value type SamplesPerSecond specializes Real;
    value type BitsPerSecond specializes Real;
    value type Millisecond specializes Real;
    value type Celsius specializes Real;
    value type Milliampere specializes Real;
    value type Milliwatt specializes Real;
    value type Micrometer specializes Real;
    value type Count specializes Integer;
    value type Percent specializes Real;

    enum def ImplantMode {
        enum standby;
        enum acquire;
        enum stimulate;
        enum decode;
        enum stream;
        enum fault;
        enum safeShutdown;
    }

    enum def IntentClass {
        enum noIntent;
        enum cursorMove;
        enum clickSelect;
        enum speechPhoneme;
        enum speechWord;
        enum assistiveDeviceCommand;
    }

    item def NeuralSpike {
        attribute channelId : Count;
        attribute timestamp : Millisecond;
        attribute amplitude : Microvolt;
        attribute width : Millisecond;
    }

    item def NeuralSampleFrame {
        attribute frameId : Count;
        attribute channelCount : Count;
        attribute sampleRate : SamplesPerSecond;
        attribute timestamp : Millisecond;
        attribute signalAmplitudeRms : Microvolt;
        attribute droppedSampleRatio : Percent;
    }

    item def StimulationPulse {
        attribute electrodeId : Count;
        attribute current : Milliampere;
        attribute pulseWidth : Millisecond;
        attribute frequency : Hertz;
        attribute enabled : Boolean;
    }

    item def DecodedIntent {
        attribute class : IntentClass;
        attribute confidence : Percent;
        attribute xVelocity : Real;
        attribute yVelocity : Real;
        attribute speechTokenId : Count;
        attribute timestamp : Millisecond;
    }

    item def DeviceCommand {
        attribute commandId : Count;
        attribute targetDeviceId : Count;
        attribute intent : IntentClass;
        attribute confidence : Percent;
        attribute issuedAt : Millisecond;
    }

    item def TelemetryPacket {
        attribute implantTemperature : Celsius;
        attribute supplyCurrent : Milliampere;
        attribute powerConsumption : Milliwatt;
        attribute electrodeImpedanceMean : Real;
        attribute linkBitRate : BitsPerSecond;
        attribute mode : ImplantMode;
    }

    port def NeuralAcquisitionPort {
        out item frame : NeuralSampleFrame;
        out item spike : NeuralSpike;
    }

    port def NeuralStimulationPort {
        in item pulse : StimulationPulse;
    }

    port def DigitalDataPort {
        in item inboundCommand : DeviceCommand;
        out item outboundIntent : DecodedIntent;
        out item telemetry : TelemetryPacket;
    }

    port def PowerPort {
        in attribute voltage : Real;
        in attribute currentLimit : Milliampere;
    }

    port def ClinicalConsolePort {
        in item therapyPulse : StimulationPulse;
        in item configurationCommand : DeviceCommand;
        out item clinicalTelemetry : TelemetryPacket;
        out item decodedIntent : DecodedIntent;
    }

    interface def NeuralSignalInterface {
        end corticalSide : NeuralAcquisitionPort;
        end electronicsSide : NeuralAcquisitionPort;
    }

    interface def StimulationInterface {
        end controllerSide : NeuralStimulationPort;
        end electrodeSide : NeuralStimulationPort;
    }

    interface def DataInterface {
        end implantSide : DigitalDataPort;
        end externalSide : ClinicalConsolePort;
    }

    part def CorticalMicroelectrodeArray {
        attribute electrodeCount : Count = 1600;
        attribute electrodePitch : Micrometer = 20.0;
        attribute insertionDepth : Micrometer = 1500.0;
        attribute impedanceNominal : Real = 250000.0;
        attribute maxSafeTemperatureRise : Celsius = 1.0;

        port neuralOut : NeuralAcquisitionPort;
        port stimIn : NeuralStimulationPort;
    }

    part def AnalogFrontEnd {
        attribute channelCount : Count = 1600;
        attribute inputNoiseRms : Microvolt = 3.5;
        attribute bandwidthLow : Hertz = 1.0;
        attribute bandwidthHigh : Hertz = 7500.0;
        attribute gain : Real = 200.0;

        port neuralIn : NeuralAcquisitionPort;
        port sampledOut : NeuralAcquisitionPort;
    }

    part def NeuralDigitizer {
        attribute resolutionBits : Count = 12;
        attribute aggregateSampleRate : SamplesPerSecond = 48000000.0;
        attribute maximumDroppedSampleRatio : Percent = 0.1;

        port analogSamplesIn : NeuralAcquisitionPort;
        port digitalFramesOut : NeuralAcquisitionPort;
    }

    part def SignalProcessor {
        attribute spikeDetectionThreshold : Microvolt = 45.0;
        attribute featureWindow : Millisecond = 20.0;
        attribute decoderLatencyBudget : Millisecond = 25.0;
        attribute intentConfidenceMinimum : Percent = 80.0;

        port neuralFramesIn : NeuralAcquisitionPort;
        port dataOut : DigitalDataPort;
    }

    part def ImplantTelemetryAndSafetyController {
        attribute temperatureLimit : Celsius = 39.0;
        attribute currentLimit : Milliampere = 120.0;
        attribute powerLimit : Milliwatt = 600.0;
        attribute impedanceCheckInterval : Millisecond = 1000.0;
        attribute activeMode : ImplantMode = ImplantMode::standby;

        port data : DigitalDataPort;
        port power : PowerPort;
        port stimOut : NeuralStimulationPort;
    }

    part def TranscutaneousDataLink {
        attribute uplinkCapacity : BitsPerSecond = 100000000.0;
        attribute downlinkCapacity : BitsPerSecond = 10000000.0;
        attribute nominalPacketLatency : Millisecond = 2.0;
        attribute encryptionEnabled : Boolean = true;

        port implantData : DigitalDataPort;
        port externalData : ClinicalConsolePort;
    }

    part def ExternalDecoderConsole {
        attribute calibrationSessionDuration : Millisecond = 600000.0;
        attribute decoderUpdatePeriod : Millisecond = 10.0;
        attribute supportedCommandTargets : Count = 8;

        port consolePort : ClinicalConsolePort;
    }

    part def AssistiveEndpoint {
        attribute commandAcceptanceThreshold : Percent = 85.0;
        attribute maximumCommandAge : Millisecond = 100.0;

        port controlPort : ClinicalConsolePort;
    }

    action def AcquireCorticalSignals {
        in electrodeState : TelemetryPacket;
        out sampleFrame : NeuralSampleFrame;
    }

    action def DetectNeuralSpikes {
        in sampleFrame : NeuralSampleFrame;
        out spike : NeuralSpike;
    }

    action def DecodeCommunicationIntent {
        in sampleFrame : NeuralSampleFrame;
        in spike : NeuralSpike;
        out intent : DecodedIntent;
    }

    action def IssueAssistiveCommand {
        in intent : DecodedIntent;
        out command : DeviceCommand;
    }

    action def MonitorImplantSafety {
        in telemetry : TelemetryPacket;
        out safe : Boolean;
    }

    state def ImplantLifecycle {
        state poweredOff;
        state startupSelfTest;
        state standby;
        state neuralAcquisition;
        state intentDecoding;
        state commandStreaming;
        state therapeuticStimulation;
        state faultDetected;
        state safeShutdown;

        transition initial then poweredOff;
        transition poweredOff then startupSelfTest
            accept DeviceCommand
            if inboundCommand.commandId == 1;
        transition startupSelfTest then standby
            if true;
        transition standby then neuralAcquisition
            accept DeviceCommand
            if inboundCommand.intent == IntentClass::assistiveDeviceCommand;
        transition neuralAcquisition then intentDecoding
            if true;
        transition intentDecoding then commandStreaming
            if true;
        transition commandStreaming then neuralAcquisition
            if true;
        transition standby then therapeuticStimulation
            accept StimulationPulse
            if therapyPulse.enabled == true;
        transition therapeuticStimulation then standby
            if therapyPulse.enabled == false;
        transition neuralAcquisition then faultDetected
            if false;
        transition intentDecoding then faultDetected
            if false;
        transition commandStreaming then faultDetected
            if false;
        transition therapeuticStimulation then faultDetected
            if false;
        transition faultDetected then safeShutdown
            if true;
    }

    part def ParadromicsInspiredDirectDataInterface {
        attribute primaryFunction : String =
            "Acquire high-channel-count cortical neural activity, decode intended communication or control signals, and transmit reliable commands to external assistive technology.";
        attribute maximumEndToEndLatency : Millisecond = 50.0;
        attribute neuralChannelCount : Count = 1600;
        attribute targetUplinkRate : BitsPerSecond = 100000000.0;
        attribute continuousUseHours : Real = 16.0;

        part electrodeArray : CorticalMicroelectrodeArray;
        part analogFrontEnd : AnalogFrontEnd;
        part digitizer : NeuralDigitizer;
        part processor : SignalProcessor;
        part safetyController : ImplantTelemetryAndSafetyController;
        part dataLink : TranscutaneousDataLink;
        part console : ExternalDecoderConsole;
        part assistiveEndpoint : AssistiveEndpoint;

        port corticalSignals : NeuralAcquisitionPort;
        port stimulation : NeuralStimulationPort;
        port externalInterface : ClinicalConsolePort;
        port implantPower : PowerPort;

        connect electrodeArray.neuralOut to analogFrontEnd.neuralIn;
        connect analogFrontEnd.sampledOut to digitizer.analogSamplesIn;
        connect digitizer.digitalFramesOut to processor.neuralFramesIn;
        connect processor.dataOut to safetyController.data;
        connect safetyController.data to dataLink.implantData;
        connect dataLink.externalData to console.consolePort;
        connect console.consolePort to assistiveEndpoint.controlPort;
        connect safetyController.stimOut to electrodeArray.stimIn;
        connect implantPower to safetyController.power;

        perform action AcquireCorticalSignals;
        perform action DetectNeuralSpikes;
        perform action DecodeCommunicationIntent;
        perform action IssueAssistiveCommand;
        perform action MonitorImplantSafety;

        exhibit state ImplantLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : ParadromicsInspiredDirectDataInterface;
        require constraint {
            system.neuralChannelCount >= 1000
        }
        require constraint {
            system.maximumEndToEndLatency <= 50.0
        }
        require constraint {
            system.targetUplinkRate >= 50000000.0
        }
    }

    requirement def NeuralAcquisitionRequirement {
        subject array : CorticalMicroelectrodeArray;
        subject digitizer : NeuralDigitizer;
        require constraint {
            array.electrodeCount >= 1000
        }
        require constraint {
            digitizer.resolutionBits >= 12
        }
        require constraint {
            digitizer.maximumDroppedSampleRatio <= 0.1
        }
    }

    requirement def SafetyRequirement {
        subject controller : ImplantTelemetryAndSafetyController;
        subject array : CorticalMicroelectrodeArray;
        require constraint {
            controller.temperatureLimit <= 39.0
        }
        require constraint {
            controller.powerLimit <= 600.0
        }
        require constraint {
            array.maxSafeTemperatureRise <= 1.0
        }
    }

    requirement def IntentDecodingRequirement {
        subject processor : SignalProcessor;
        require constraint {
            processor.decoderLatencyBudget <= 25.0
        }
        require constraint {
            processor.intentConfidenceMinimum >= 80.0
        }
    }

    requirement def DataLinkRequirement {
        subject link : TranscutaneousDataLink;
        require constraint {
            link.uplinkCapacity >= 100000000.0
        }
        require constraint {
            link.nominalPacketLatency <= 5.0
        }
        require constraint {
            link.encryptionEnabled == true
        }
    }

    satisfy PrimaryFunctionRequirement by ParadromicsInspiredDirectDataInterface;
    satisfy NeuralAcquisitionRequirement by ParadromicsInspiredDirectDataInterface::electrodeArray;
    satisfy NeuralAcquisitionRequirement by ParadromicsInspiredDirectDataInterface::digitizer;
    satisfy SafetyRequirement by ParadromicsInspiredDirectDataInterface::safetyController;
    satisfy IntentDecodingRequirement by ParadromicsInspiredDirectDataInterface::processor;
    satisfy DataLinkRequirement by ParadromicsInspiredDirectDataInterface::dataLink;
}