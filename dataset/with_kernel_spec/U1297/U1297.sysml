package LagotekSDR {
    attribute def FrequencyValue :> ScalarValues::Real;
    attribute def PowerValue :> ScalarValues::Real;
    attribute def DataRateValue :> ScalarValues::Real;
    attribute def GainValue :> ScalarValues::Real;
    attribute def DurationValue :> ScalarValues::Real;

    item def RFSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
    }
    item def IFSignal {
        attribute frequency : FrequencyValue;
        attribute power : PowerValue;
    }
    item def DigitalData {
        attribute dataRate : DataRateValue;
        attribute payload : ScalarValues::String;
    }
    item def ControlCommand {
        attribute targetFrequency : FrequencyValue;
        attribute gain : GainValue;
    }
    item def SignalQuality {
        attribute snr : ScalarValues::Real;
        attribute signalLock : ScalarValues::Boolean;
    }
    item def NetworkPacket {
        attribute payload : ScalarValues::String;
        attribute sequence : ScalarValues::Integer;
    }

    attribute def ActivateSignal;
    attribute def DetectionSignal;
    attribute def LockSignal;
    attribute def LossSignal;

    port def RFSignalPort {
        out rfSignal : RFSignal;
    }
    port def RFInputPort {
        in rfSignal : RFSignal;
    }
    port def IFSignalPort {
        out ifSignal : IFSignal;
    }
    port def IFInputPort {
        in ifSignal : IFSignal;
    }
    port def DigitalDataOutPort {
        out data : DigitalData;
    }
    port def DigitalDataInPort {
        in data : DigitalData;
    }
    port def ControlOutPort {
        out command : ControlCommand;
    }
    port def ControlInPort {
        in command : ControlCommand;
    }
    port def SignalQualityOutPort {
        out quality : SignalQuality;
    }
    port def SignalQualityInPort {
        in quality : SignalQuality;
    }
    port def NetworkOutPort {
        out packet : NetworkPacket;
    }

    action def CaptureSignal;
    action def AmplifyAndTune;
    action def ProcessSignal;
    action def MonitorAndAdjust;
    action def BufferAndStream;

    state def SystemStates {
        then state idle;
        accept ActivateSignal then searching;
        state searching {
        }
        accept DetectionSignal then locked;
        state locked {
        }
        accept LockSignal then processing;
        accept LossSignal then searching;
        state processing {
        }
        accept LossSignal then searching;
    }

    part def AntennaArray {
        port rfOut : RFSignalPort;
        perform action captureSignal : CaptureSignal;
    }

    part def FrontEndReceiver {
        port rfIn : RFInputPort;
        port ifOut : IFSignalPort;
        port controlIn : ControlInPort;
        attribute currentGain : GainValue;
        perform action amplifyAndTune : AmplifyAndTune;
    }

    part def DigitalSignalProcessor {
        port ifIn : IFInputPort;
        port dataOut : DigitalDataOutPort;
        port qualityOut : SignalQualityOutPort;
        port controlIn : ControlInPort;
        perform action processSignal : ProcessSignal;
    }

    part def ControlProcessor {
        port qualityIn : SignalQualityInPort;
        port controlOutFE : ControlOutPort;
        port controlOutDSP : ControlOutPort;
        exhibit state processorStates : SystemStates;
        perform action monitorAndAdjust : MonitorAndAdjust;
    }

    part def DataOutputInterface {
        port dataIn : DigitalDataInPort;
        port networkOut : NetworkOutPort;
        perform action bufferAndStream : BufferAndStream;
    }

    part def LagotekSystem {
        attribute minFrequency : FrequencyValue := 100000000.0;
        attribute maxFrequency : FrequencyValue := 6000000000.0;
        attribute operationalDuration : DurationValue := 72.0;
        port extEthPort : NetworkOutPort;
        exhibit state systemStates : SystemStates;
    }

    requirement def ContinuousOperationRequirement {
        subject sdrSystem : LagotekSystem;
        constraint { sdrSystem.operationalDuration >= 72.0 }
    }
    requirement def FrequencyRangeRequirement {
        subject sdrSystem : LagotekSystem;
        constraint { sdrSystem.minFrequency >= 100000000.0 and sdrSystem.maxFrequency <= 6000000000.0 }
    }
    requirement def AutonomousControlRequirement {
        subject sdrSystem : LagotekSystem;
    }

    part lagotekSystem : LagotekSystem {
        part antennaArray : AntennaArray;
        part frontEndReceiver : FrontEndReceiver;
        part dsp : DigitalSignalProcessor;
        part controlProcessor : ControlProcessor;
        part dataOutputInterface : DataOutputInterface;

        flow rfFlow of RFSignal
            from antennaArray.rfOut.rfSignal to frontEndReceiver.rfIn.rfSignal;
        flow ifFlow of IFSignal
            from frontEndReceiver.ifOut.ifSignal to dsp.ifIn.ifSignal;
        flow dataFlow of DigitalData
            from dsp.dataOut.data to dataOutputInterface.dataIn.data;
        flow qualityFlow of SignalQuality
            from dsp.qualityOut.quality to controlProcessor.qualityIn.quality;
        flow controlFlowFE of ControlCommand
            from controlProcessor.controlOutFE.command to frontEndReceiver.controlIn.command;
        flow controlFlowDSP of ControlCommand
            from controlProcessor.controlOutDSP.command to dsp.controlIn.command;

        bind extEthPort = dataOutputInterface.networkOut;

        satisfy continuousOp : ContinuousOperationRequirement;
        satisfy freqRange : FrequencyRangeRequirement;
        satisfy autoCtrl : AutonomousControlRequirement;
    }
}
