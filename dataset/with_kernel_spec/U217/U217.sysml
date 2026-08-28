package EsophagealDopplerMonitoringSystem {

    attribute def FrequencyValue :> Real;
    attribute def VelocityValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def TimeValue :> Real;
    attribute def LengthValue :> Real;
    attribute def MassValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;

    attribute def PowerOn;
    attribute def PowerOff;
    attribute def StartMonitoring;
    attribute def StopMonitoring;
    attribute def PoorSignal;
    attribute def SystemFault;
    attribute def ClearAlarm;
    attribute def EchoReceived;
    attribute def SignalProcessed;
    attribute def CalculationDone;
    attribute def DisplayUpdated;

    item def UltrasoundPulse {
        attribute frequency : FrequencyValue;
        attribute amplitude : Real;
    }
    item def EchoSignal {
        attribute frequencyShift : FrequencyValue;
        attribute amplitude : Real;
        attribute timestamp : TimeValue;
    }
    item def VelocityWaveform {
        attribute velocity : VelocityValue;
        attribute timestamp : TimeValue;
        attribute qualityIndex : Real;
    }
    item def PatientData {
        attribute age : TimeValue;
        attribute height : LengthValue;
        attribute weight : MassValue;
        attribute estimatedAortaDiameter : LengthValue;
    }
    item def HemodynamicParameters {
        attribute strokeVolume : VolumeValue;
        attribute cardiacOutput : FlowRateValue;
        attribute heartRate : FrequencyValue;
        attribute bloodFlowTime : TimeValue;
    }
    item def AlarmSignal {
        attribute alarmType : String;
        attribute severity : Integer;
    }
    item def ControlCommand {
        attribute commandType : String;
    }
    item def StatusMsg {
        attribute statusType : String;
        attribute info : String;
    }
    item def PowerSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    port def UltrasoundTxPort {
        out pulse : UltrasoundPulse;
        in echo : EchoSignal;
    }
    port def UltrasoundRxPort {
        in pulse : UltrasoundPulse;
        out echo : EchoSignal;
    }
    port def EchoOutPort {
        out echo : EchoSignal;
    }
    port def EchoInPort {
        in echo : EchoSignal;
    }
    port def WaveformOutPort {
        out waveform : VelocityWaveform;
    }
    port def WaveformInPort {
        in waveform : VelocityWaveform;
    }
    port def ParamsOutPort {
        out params : HemodynamicParameters;
    }
    port def PatientDataInPort {
        in data : PatientData;
    }
    port def DisplayInPort {
        in waveform : VelocityWaveform;
        in params : HemodynamicParameters;
        in alarm : AlarmSignal;
    }
    port def ControlOutPort {
        out command : ControlCommand;
        out alarm : AlarmSignal;
    }
    port def ControlInPort {
        in command : ControlCommand;
        in alarm : AlarmSignal;
    }
    port def PowerOutPort {
        out power : PowerSignal;
    }
    port def PowerInPort {
        in power : PowerSignal;
    }

    action def GeneratePulse {
        out pulse : UltrasoundPulse;
    }
    action def CaptureEcho {
        in pulse : UltrasoundPulse;
        out echo : EchoSignal;
    }
    action def CleanSignal {
        in echo : EchoSignal;
        out cleanEcho : EchoSignal;
    }
    action def AnalyzeDopplerShift {
        in echo : EchoSignal;
        out waveform : VelocityWaveform;
    }
    action def AssessSignalQuality {
        in echo : EchoSignal;
        out qualityIndex : Real;
    }
    action def EstimateAortaDiameter {
        in patientData : PatientData;
        out diameter : LengthValue;
    }
    action def CalculateHemodynamics {
        in waveform : VelocityWaveform;
        in patientData : PatientData;
        out params : HemodynamicParameters;
    }
    action def UpdateDisplayAction {
        in waveform : VelocityWaveform;
        in params : HemodynamicParameters;
        in alarm : AlarmSignal;
    }
    action def ProcessUserInput {
        in command : ControlCommand;
        out status : StatusMsg;
    }
    action def MonitorSystemHealth {
        in qualityIndex : Real;
        out faultDetected : Boolean;
    }
    action def TriggerAlarmAction {
        in faultDetected : Boolean;
        out alarm : AlarmSignal;
    }
    action def SupplyPower {
        out power : PowerSignal;
    }
    action def MonitorCycle {
        in patientData : PatientData;
        out waveform : VelocityWaveform;
        out params : HemodynamicParameters;
    }

    state def SystemOperationalStates {
        entry; then off;
        state off;
        accept PowerOn then standby;
        state standby;
        accept StartMonitoring then monitoring;
        state monitoring {
            entry; then acquire;
            state acquire;
            accept EchoReceived then process;
            state process;
            accept SignalProcessed then calculate;
            state calculate;
            accept CalculationDone then update;
            state update;
            accept DisplayUpdated then acquire;
            accept PoorSignal then alarm;
            accept SystemFault then alarm;
            accept StopMonitoring then standby;
        }
        state alarm;
        accept ClearAlarm then standby;
        accept PowerOff then off;
    }

    part def Patient {
        port aortaPort : UltrasoundRxPort;
    }
    part def UltrasoundTransducer {
        port ultrasoundPort : UltrasoundTxPort;
        port echoOut : EchoOutPort;
        port powerIn : PowerInPort;
        attribute pulseFrequency : FrequencyValue;
        perform action generatePulse : GeneratePulse;
        perform action captureEcho : CaptureEcho;
    }
    part def EsophagealProbe {
        part transducer : UltrasoundTransducer;
        port echoOut : EchoOutPort;
        port powerIn : PowerInPort;
    }
    part def SignalProcessingUnit {
        port echoIn : EchoInPort;
        port waveformOut : WaveformOutPort;
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        perform action cleanSignal : CleanSignal;
        perform action analyzeDopplerShift : AnalyzeDopplerShift;
        perform action assessSignalQuality : AssessSignalQuality;
    }
    part def HemodynamicCalculator {
        port waveformIn : WaveformInPort;
        port patientDataIn : PatientDataInPort;
        port paramsOut : ParamsOutPort;
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        attribute patientData : PatientData;
        perform action estimateAortaDiameter : EstimateAortaDiameter;
        perform action calculateHemodynamics : CalculateHemodynamics;
    }
    part def DisplayUnit {
        port displayIn : DisplayInPort;
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        perform action updateDisplay : UpdateDisplayAction;
    }
    part def ControlModule {
        port controlOut : ControlOutPort;
        port powerIn : PowerInPort;
        attribute patientData : PatientData;
        perform action processUserInput : ProcessUserInput;
        perform action monitorSystemHealth : MonitorSystemHealth;
        perform action triggerAlarm : TriggerAlarmAction;
        exhibit state systemStates : SystemOperationalStates;
    }
    part def PowerSupply {
        port powerOut : PowerOutPort;
        perform action supplyPower : SupplyPower;
    }
    part def EsophagealDopplerSystem {
        part patient : Patient;
        part probe : EsophagealProbe;
        part signalProcessor : SignalProcessingUnit;
        part hemodynamicCalc : HemodynamicCalculator;
        part display : DisplayUnit;
        part controller : ControlModule;
        part powerSupply : PowerSupply;
        port patientDataInput : PatientDataInPort;
    }

    requirement def ContinuousMonitoringRequirement {
        doc
            "The system shall provide continuous real-time monitoring of hemodynamic parameters "
            "including stroke volume, cardiac output, heart rate, and blood flow time.";
    }
    requirement def DopplerShiftAnalysisRequirement {
        doc
            "The signal processing unit shall analyze Doppler frequency shifts from ultrasound "
            "echoes to calculate blood velocity and generate a real-time velocity waveform.";
    }
    requirement def SignalQualityAssessmentRequirement {
        doc
            "The system shall continuously assess signal quality and trigger an alarm when "
            "quality falls below acceptable thresholds.";
    }
    requirement def HemodynamicCalculationRequirement {
        doc
            "The hemodynamic calculator shall compute stroke volume and cardiac output using "
            "the velocity waveform and patient-specific data including age, height, and weight "
            "to estimate aortic diameter.";
    }
    requirement def DisplayRequirement {
        doc
            "The display unit shall show a real-time graph of the blood velocity waveform "
            "alongside calculated hemodynamic parameters.";
    }
    requirement def AlarmRequirement {
        doc
            "The control module shall raise an alarm upon detection of poor signal quality "
            "or system fault conditions.";
    }

    part edSystem : EsophagealDopplerSystem {
        part patient : Patient;
        part probe : EsophagealProbe {
            part transducer : UltrasoundTransducer;
        }
        part signalProcessor : SignalProcessingUnit;
        part hemodynamicCalc : HemodynamicCalculator;
        part display : DisplayUnit;
        part controller : ControlModule;
        part powerSupply : PowerSupply;

        connect probe.transducer.ultrasoundPort to patient.aortaPort;

        connect probe.transducer.echoOut to probe.echoOut;
        flow probe.echoOut.echo to signalProcessor.echoIn.echo;

        flow signalProcessor.waveformOut.waveform to hemodynamicCalc.waveformIn.waveform;
        flow signalProcessor.waveformOut.waveform to display.displayIn.waveform;

        flow hemodynamicCalc.paramsOut.params to display.displayIn.params;

        connect patientDataInput to hemodynamicCalc.patientDataIn;

        flow controller.controlOut.command to signalProcessor.controlIn.command;
        flow controller.controlOut.alarm to signalProcessor.controlIn.alarm;
        flow controller.controlOut.command to hemodynamicCalc.controlIn.command;
        flow controller.controlOut.alarm to hemodynamicCalc.controlIn.alarm;
        flow controller.controlOut.command to display.controlIn.command;
        flow controller.controlOut.alarm to display.controlIn.alarm;
        flow controller.controlOut.alarm to display.displayIn.alarm;

        connect probe.powerIn to probe.transducer.powerIn;
        flow powerSupply.powerOut.power to probe.powerIn.power;
        flow powerSupply.powerOut.power to signalProcessor.powerIn.power;
        flow powerSupply.powerOut.power to hemodynamicCalc.powerIn.power;
        flow powerSupply.powerOut.power to display.powerIn.power;
        flow powerSupply.powerOut.power to controller.powerIn.power;

        perform action monitorCycle : MonitorCycle {
            in patientData : PatientData = controller.patientData;
            out waveform : VelocityWaveform;
            out params : HemodynamicParameters;
            loop {
                action generatePulse : GeneratePulse {
                    out pulse : UltrasoundPulse;
                }
                flow generatePulse.pulse to captureEcho.pulse;
                action captureEcho : CaptureEcho {
                    in pulse : UltrasoundPulse;
                    out echo : EchoSignal;
                }
                flow captureEcho.echo to cleanSignal.echo;
                action cleanSignal : CleanSignal {
                    in echo : EchoSignal;
                    out cleanEcho : EchoSignal;
                }
                flow cleanSignal.cleanEcho to analyzeDopplerShift.echo;
                flow cleanSignal.cleanEcho to assessSignalQuality.echo;
                action analyzeDopplerShift : AnalyzeDopplerShift {
                    in echo : EchoSignal;
                    out waveform : VelocityWaveform;
                }
                action assessSignalQuality : AssessSignalQuality {
                    in echo : EchoSignal;
                    out qualityIndex : Real;
                }
                flow analyzeDopplerShift.waveform to calculateHemodynamics.waveform;
                action calculateHemodynamics : CalculateHemodynamics {
                    in waveform : VelocityWaveform;
                    in patientData : PatientData = monitorCycle::patientData;
                    out params : HemodynamicParameters;
                }
                flow calculateHemodynamics.params to updateDisplay.params;
                flow analyzeDopplerShift.waveform to updateDisplay.waveform;
                action updateDisplay : UpdateDisplayAction {
                    in waveform : VelocityWaveform;
                    in params : HemodynamicParameters;
                    in alarm : AlarmSignal;
                }
            }
        }
    }

    requirement continuousMonitoring : ContinuousMonitoringRequirement;
    requirement dopplerAnalysis : DopplerShiftAnalysisRequirement;
    requirement signalQuality : SignalQualityAssessmentRequirement;
    requirement hemodynamicCalcReq : HemodynamicCalculationRequirement;
    requirement displayReq : DisplayRequirement;
    requirement alarmReq : AlarmRequirement;
}
