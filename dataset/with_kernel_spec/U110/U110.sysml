package RetinalProsthesisSystem {
    value type ElectricCurrent { unit A; }
    value type Duration { unit s; }
    value type Mass { unit kg; }

    item def Scene;
    item def VideoFrame;
    item def ProcessedVisualPattern;
    item def RadioFrequencySignal;
    item def StimulationPulse {
        attribute current : ElectricCurrent;
        attribute duration : Duration;
    }
    item def StimulationPattern {
        item pulses : StimulationPulse[60];
    }
    item def NeuralActivity;

    attribute def ActivationCommand;
    attribute def LowPowerCommand;
    attribute def DiagnosticCommand;
    attribute def DiagnosticComplete;

    action def CaptureLiveVideo { in item scene : Scene; out item frame : VideoFrame; }
    action def ProcessVideoToPattern { in item frame : VideoFrame; out item pattern : ProcessedVisualPattern; }
    action def EncodeStimulationPattern { in item pattern : ProcessedVisualPattern; out item stimulationPattern : StimulationPattern; }
    action def TransmitStimulationPattern { in item pattern : StimulationPattern; out item rfSignal : RadioFrequencySignal; }
    action def ReceiveRfSignal { in item rfSignal : RadioFrequencySignal; out item receivedPattern : StimulationPattern; }
    action def DecodeAndControlStimulation { in item pattern : StimulationPattern; out item pulses : StimulationPattern; }
    action def DeliverElectricalPulses { in item pulses : StimulationPattern; out item neuralActivity : NeuralActivity; }
    action def RealTimeVisualPerception { in item scene : Scene; out item perceivedNeuralActivity : NeuralActivity; }

    state def SystemOperatingMode {
        entry; then Operating;
        state Operating;
        state Standby;
        state Diagnostic;
        transition operatingToStandby
            first Operating
            accept lowPower : LowPowerCommand
            then Standby;
        transition standbyToOperating
            first Standby
            accept activate : ActivationCommand
            then Operating;
        transition operatingToDiagnostic
            first Operating
            accept diagnostics : DiagnosticCommand
            then Diagnostic;
        transition diagnosticToStandby
            first Diagnostic
            accept complete : DiagnosticComplete
            then Standby;
    }

    part def MiniatureCamera {
        port videoOut;
        port powerIn;
    }
    part def ImageProcessingUnit {
        port videoIn;
        port dataOut;
        port powerIn;
    }
    part def RfTransmitter {
        port dataIn;
        port rfOut;
        port powerIn;
    }
    part def InductivePowerCoil {
        port powerIn;
        port powerOut;
    }
    part def RechargeableBattery {
        port powerOut;
        port chargePort;
    }
    part def RfReceiver {
        port rfIn;
        port dataOut;
        port powerIn;
        port powerOut;
    }
    part def SignalDecoderStimulationController {
        port dataIn;
        port pulseOut;
        port powerIn;
        state operatingMode : SystemOperatingMode;
    }
    part def Electrode {
        port stimulationPort;
    }
    part def MicroelectrodeArray {
        port pulseIn;
        port retinaPort;
        port powerIn;
        part electrodes : Electrode[60];
    }
    part def ExternalWearableUnit {
        port wirelessDataOut;
        port wirelessPowerOut;
        part camera : MiniatureCamera;
        part imageProcessor : ImageProcessingUnit;
        part rfTransmitter : RfTransmitter;
        part inductivePowerCoil : InductivePowerCoil;
        part battery : RechargeableBattery;
        connect camera.videoOut to imageProcessor.videoIn;
        connect imageProcessor.dataOut to rfTransmitter.dataIn;
        connect battery.powerOut to camera.powerIn;
        connect battery.powerOut to imageProcessor.powerIn;
        connect battery.powerOut to rfTransmitter.powerIn;
        connect battery.powerOut to inductivePowerCoil.powerIn;
        connect rfTransmitter.rfOut to wirelessDataOut;
        connect inductivePowerCoil.powerOut to wirelessPowerOut;
    }
    part def ImplantedRetinalUnit {
        port wirelessDataIn;
        port wirelessPowerIn;
        port retinaInterface;
        part rfReceiver : RfReceiver;
        part decoderController : SignalDecoderStimulationController;
        part microelectrodeArray : MicroelectrodeArray;
        connect wirelessDataIn to rfReceiver.rfIn;
        connect wirelessPowerIn to rfReceiver.powerIn;
        connect rfReceiver.dataOut to decoderController.dataIn;
        connect rfReceiver.powerOut to decoderController.powerIn;
        connect rfReceiver.powerOut to microelectrodeArray.powerIn;
        connect decoderController.pulseOut to microelectrodeArray.pulseIn;
        connect microelectrodeArray.retinaPort to retinaInterface;
    }
    part def OpticNerve {
        port signalIn;
    }
    part def Eye {
        port retinaPort;
        part opticNerve : OpticNerve;
        connect retinaPort to opticNerve.signalIn;
    }

    part def RetinalProsthesisSystem {
        part externalUnit : ExternalWearableUnit;
        part implantedUnit : ImplantedRetinalUnit;
        part userEye : Eye;
        connect externalUnit.wirelessDataOut to implantedUnit.wirelessDataIn;
        connect externalUnit.wirelessPowerOut to implantedUnit.wirelessPowerIn;
        connect implantedUnit.retinaInterface to userEye.retinaPort;

        action realTimePerception : RealTimeVisualPerception {
            in item scene : Scene;
            out item perceivedNeuralActivity : NeuralActivity;
            action capture : CaptureLiveVideo {
                in item scene = scene;
                out item frame;
            }
            action process : ProcessVideoToPattern {
                in item frame;
                out item pattern;
            }
            action encode : EncodeStimulationPattern {
                in item pattern;
                out item stimulationPattern;
            }
            action transmit : TransmitStimulationPattern {
                in item pattern;
                out item rfSignal;
            }
            action receive : ReceiveRfSignal {
                in item rfSignal;
                out item receivedPattern;
            }
            action decode : DecodeAndControlStimulation {
                in item pattern;
                out item pulses;
            }
            action deliver : DeliverElectricalPulses {
                in item pulses;
                out item neuralActivity;
            }
            flow from capture.frame to process.frame;
            flow from process.pattern to encode.pattern;
            flow from encode.stimulationPattern to transmit.pattern;
            flow from transmit.rfSignal to receive.rfSignal;
            flow from receive.receivedPattern to decode.pattern;
            flow from decode.pulses to deliver.pulses;
            bind deliver.neuralActivity = perceivedNeuralActivity;
        }
    }

    requirement def MaximumStimulationCurrent {
        doc /* The maximum electrical current delivered by any microelectrode shall not exceed 1.0 mA to prevent retinal tissue damage. */
        attribute maximumCurrent : ElectricCurrent = 0.001;
    }
    requirement def RealtimeProcessingLatency {
        doc /* The latency from scene capture to retinal stimulation shall be less than or equal to 50 ms. */
        attribute maximumLatency : Duration = 0.05;
    }
    requirement def ExternalWearableMassLimit {
        doc /* The total mass of the external wearable unit shall not exceed 50 g. */
        attribute maximumMass : Mass = 0.05;
    }
    requirement def ImplantedUnitMassLimit {
        doc /* The total mass of the implanted unit shall not exceed 5 g. */
        attribute maximumMass : Mass = 0.005;
    }

    part prosthesis : RetinalProsthesisSystem;
}
