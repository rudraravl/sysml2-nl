package RFTransceiverSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        attribute def FrequencyValue :> Real;
        attribute def PowerValue :> Real;

        item def BasebandSignal {
            attribute data : Integer;
            attribute dataRate : Real;
        }
        item def RFSignal {
            attribute frequency : FrequencyValue;
            attribute power : PowerValue;
        }
        item def LocalOscillatorSignal {
            attribute frequency : FrequencyValue;
        }
        item def ControlCommand {
            attribute command : String;
        }
        item def StatusSignal {
            attribute component : String;
            attribute value : Real;
        }

        port def BasebandInPort { in item signal : BasebandSignal; }
        port def BasebandOutPort { out item signal : BasebandSignal; }
        port def RFInPort { in item signal : RFSignal; }
        port def RFOutPort { out item signal : RFSignal; }
        port def RFInOutPort { in item rfIn : RFSignal; out item rfOut : RFSignal; }
        port def LOInPort { in item loSignal : LocalOscillatorSignal; }
        port def LOOutPort { out item loSignal : LocalOscillatorSignal; }
        port def ControlInPort { in item cmd : ControlCommand; }
        port def ControlOutPort { out item cmd : ControlCommand; }
        port def StatusInPort { in item status : StatusSignal; }

        action def ModulateAction {
            in item baseband : BasebandSignal;
            out item modulated : RFSignal;
        }
        action def MixAction {
            in item rfInput : RFSignal;
            in item loInput : LocalOscillatorSignal;
            out item mixed : RFSignal;
        }
        action def FilterAction {
            in item rfInput : RFSignal;
            out item filtered : RFSignal;
        }
        action def AmplifyAction {
            in item rfInput : RFSignal;
            out item amplified : RFSignal;
        }
        action def DemodulateAction {
            in item rfInput : RFSignal;
            out item baseband : BasebandSignal;
        }
        action def RadiateAction { in item rfInput : RFSignal; }
        action def CaptureAction { out item rfOutput : RFSignal; }
        action def GenerateLOAction { out item loSignal : LocalOscillatorSignal; }
        action def CalibrateAction;
        action def TransmitProcess {
            in item baseband : BasebandSignal;
            out item rfOut : RFSignal;
        }
        action def ReceiveProcess {
            in item rfIn : RFSignal;
            out item baseband : BasebandSignal;
        }

        state def TransceiverStates {
            entry; then idle;
            state idle;
            accept cmd : ControlCommand
                if cmd.command == "transmit"
                then transmit;
            accept cmd : ControlCommand
                if cmd.command == "receive"
                then receive;
            accept cmd : ControlCommand
                if cmd.command == "calibrate"
                then calibration;

            state transmit {
                do action transmitAction : TransmitProcess;
            }
            accept cmd : ControlCommand
                if cmd.command == "idle"
                then idle;
            accept fault : StatusSignal
                if fault.value > 0
                then fault;

            state receive {
                do action receiveAction : ReceiveProcess;
            }
            accept cmd : ControlCommand
                if cmd.command == "idle"
                then idle;
            accept fault : StatusSignal
                if fault.value > 0
                then fault;

            state calibration {
                do action calibrateAction : CalibrateAction;
            }
            accept cmd : ControlCommand
                if cmd.command == "idle"
                then idle;
            accept fault : StatusSignal
                if fault.value > 0
                then fault;

            state fault;
            accept cmd : ControlCommand
                if cmd.command == "reset"
                then idle;
        }

        part def Modulator {
            port basebandInput : BasebandInPort;
            port output : RFOutPort;
            port control : ControlInPort;
            perform action modulateAction : ModulateAction;
        }
        part def Demodulator {
            port rfInput : RFInPort;
            port basebandOutput : BasebandOutPort;
            port control : ControlInPort;
            perform action demodulateAction : DemodulateAction;
        }
        part def Mixer {
            port rfInput : RFInPort;
            port loInput : LOInPort;
            port output : RFOutPort;
            port control : ControlInPort;
            perform action mixAction : MixAction;
        }
        part def LocalOscillator {
            port output : LOOutPort;
            port control : ControlInPort;
            attribute frequency : FrequencyValue = 2.4;
            perform action generateLOAction : GenerateLOAction;
        }
        part def BandpassFilter {
            port input : RFInPort;
            port output : RFOutPort;
            port control : ControlInPort;
            perform action filterAction : FilterAction;
        }
        part def Amplifier {
            port input : RFInPort;
            port output : RFOutPort;
            port control : ControlInPort;
            attribute gain : Real;
            perform action amplifyAction : AmplifyAction;
        }
        part def LowNoiseAmplifier :> Amplifier {
            attribute noiseFigure : Real;
        }
        part def PowerAmplifier :> Amplifier;
        part def Antenna {
            port rfPort : RFInOutPort;
            port control : ControlInPort;
            perform action radiateAction : RadiateAction;
            perform action captureAction : CaptureAction;
        }
        part def AntennaSwitch {
            port antennaPort : RFInOutPort;
            port txPort : RFInPort;
            port rxPort : RFOutPort;
            port control : ControlInPort;
        }
        part def SystemController {
            port controlOut : ControlOutPort;
            port statusIn : StatusInPort;
            port externalControl : ControlInPort;
            exhibit state controllerStates : TransceiverStates;
        }
        part def Transceiver {
            port basebandTx : BasebandInPort;
            port basebandRx : BasebandOutPort;
            port externalControl : ControlInPort;

            part modulator : Modulator;
            part txMixer : Mixer;
            part txFilter : BandpassFilter;
            part powerAmplifier : PowerAmplifier;
            part antenna : Antenna;
            part antennaSwitch : AntennaSwitch;
            part rxFilter : BandpassFilter;
            part lna : LowNoiseAmplifier;
            part rxMixer : Mixer;
            part demodulator : Demodulator;
            part localOscillator : LocalOscillator;
            part controller : SystemController;

            connect basebandTx to modulator.basebandInput;
            connect modulator.output to txMixer.rfInput;
            connect localOscillator.output to txMixer.loInput;
            connect txMixer.output to txFilter.input;
            connect txFilter.output to powerAmplifier.input;
            connect powerAmplifier.output to antennaSwitch.txPort;
            connect antennaSwitch.antennaPort to antenna.rfPort;
            connect antenna.rfPort to antennaSwitch.antennaPort;
            connect antennaSwitch.rxPort to rxFilter.input;
            connect rxFilter.output to lna.input;
            connect lna.output to rxMixer.rfInput;
            connect localOscillator.output to rxMixer.loInput;
            connect rxMixer.output to demodulator.rfInput;
            connect demodulator.basebandOutput to basebandRx;

            connect externalControl to controller.externalControl;
            connect controller.controlOut to localOscillator.control;
            connect controller.controlOut to antennaSwitch.control;
            connect controller.controlOut to modulator.control;
            connect controller.controlOut to txMixer.control;
            connect controller.controlOut to txFilter.control;
            connect controller.controlOut to powerAmplifier.control;
            connect controller.controlOut to rxFilter.control;
            connect controller.controlOut to lna.control;
            connect controller.controlOut to rxMixer.control;
            connect controller.controlOut to demodulator.control;
            connect controller.controlOut to antenna.control;

            exhibit state transceiverStates : TransceiverStates;
        }

        requirement def FrequencyStabilityRequirement {
            attribute targetFrequency : FrequencyValue = 2.4;
            attribute maxDeviation : FrequencyValue = 0.05;
            doc { The local oscillator frequency deviation shall not exceed maxDeviation from the targetFrequency. }
        }
        requirement def TransmitPowerRequirement {
            attribute minOutputPower : PowerValue = 20.0;
            attribute maxOutputPower : PowerValue = 30.0;
            doc { The transmit output power shall be at least minOutputPower and shall not exceed maxOutputPower. }
        }
        requirement def ReceiverSensitivityRequirement {
            attribute minDetectablePower : PowerValue = -90.0;
            doc { The receiver shall be able to detect signals with power as low as minDetectablePower. }
        }
    }

    package Usages {
        import Definitions::*;

        part rfTransceiver : Transceiver;

        requirement freqStabilityReq : FrequencyStabilityRequirement {
            attribute targetFrequency = 2.4;
            attribute maxDeviation = 0.05;
        }
        requirement txPowerReq : TransmitPowerRequirement {
            attribute minOutputPower = 20.0;
            attribute maxOutputPower = 30.0;
        }
        requirement rxSensitivityReq : ReceiverSensitivityRequirement {
            attribute minDetectablePower = -90.0;
        }

        satisfy freqStabilityReq by rfTransceiver.localOscillator;
        satisfy txPowerReq by rfTransceiver.powerAmplifier;
        satisfy rxSensitivityReq by rfTransceiver.lna;
    }
}
