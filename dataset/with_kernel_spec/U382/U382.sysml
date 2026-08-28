package SensorMedicsHFOV {
    private import ScalarValues::*;
    private import ScalarFunctions::*;

    attribute def Percentage :> Real;
    attribute def PressureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def TimeValue :> Real;

    item def Gas;
    item def MedicalAir :> Gas;
    item def Oxygen :> Gas;
    item def GasMixture :> Gas;
    item def Measurement {
        attribute value : Real;
    }
    item def AlarmEvent {
        attribute alarmText : String;
        attribute severity : Integer;
    }

    item def ControlCommand;
    item def OxygenConcentrationCommand :> ControlCommand {
        attribute concentration : Percentage;
    }
    item def MeanPressureCommand :> ControlCommand {
        attribute pressure : PressureValue;
    }
    item def OscillationFrequencyCommand :> ControlCommand {
        attribute frequency : FrequencyValue;
    }
    item def PressureAmplitudeCommand :> ControlCommand {
        attribute amplitude : PressureValue;
    }

    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def SelfTestPassSignal;
    attribute def SelfTestFailSignal;
    attribute def StartVentilationSignal;
    attribute def StopVentilationSignal;
    attribute def CriticalAlarmSignal;
    attribute def AlarmResetSignal;

    port def GasInPort { in item gas : Gas; }
    port def GasOutPort { out item gas : Gas; }
    port def ControlInPort { in item command : ControlCommand; }
    port def ControlOutPort { out item command : ControlCommand; }
    port def MonitorInPort { in item measurement : Measurement; }
    port def MonitorOutPort { out item measurement : Measurement; }
    port def AlarmInPort { in item alarm : AlarmEvent; }
    port def AlarmOutPort { out item alarm : AlarmEvent; }

    part def OperatorInterface {
        port controlOut : ControlOutPort;
    }

    part def GasBlender {
        port airIn : GasInPort;
        port o2In : GasInPort;
        port mixtureOut : GasOutPort;
        port controlIn : ControlInPort;
    }

    part def ContinuousFlowGenerator {
        port mixtureIn : GasInPort;
        port flowOut : GasOutPort;
        port controlIn : ControlInPort;
    }

    part def PistonOscillator {
        port flowIn : GasInPort;
        port flowOut : GasOutPort;
        port freqControlIn : ControlInPort;
        port ampControlIn : ControlInPort;
    }

    part def PatientCircuit {
        port ventIn : GasInPort;
        port patientOut : GasOutPort;
        port pressureSense : MonitorOutPort;
        port volumeSense : MonitorOutPort;
    }

    part def Patient {
        port airwayIn : GasInPort;
    }

    part def PressureMonitor {
        port circuitIn : MonitorInPort;
        port monitorOut : MonitorOutPort;
    }

    part def VolumeMonitor {
        port circuitIn : MonitorInPort;
        port monitorOut : MonitorOutPort;
    }

    part def ControlSystem {
        port operatorIn : ControlInPort;
        port blenderCmd : ControlOutPort;
        port flowCmd : ControlOutPort;
        port oscFreqCmd : ControlOutPort;
        port oscAmpCmd : ControlOutPort;
        port pressureData : MonitorInPort;
        port volumeData : MonitorInPort;
        port alarmCmd : AlarmOutPort;
    }

    part def AlarmSystem {
        port alarmIn : AlarmInPort;
        port audibleOut : AlarmOutPort;
        port visualOut : AlarmOutPort;
    }

    state def VentilatorStates;

    part def HFOV {
        port externalAirSupply : GasInPort;
        port externalO2Supply : GasInPort;
        port externalAlarmAudible : AlarmOutPort;
        port externalAlarmVisual : AlarmOutPort;

        part gasBlender : GasBlender;
        part flowGenerator : ContinuousFlowGenerator;
        part pistonOscillator : PistonOscillator;
        part patientCircuit : PatientCircuit;
        part patient : Patient;
        part pressureMonitor : PressureMonitor;
        part volumeMonitor : VolumeMonitor;
        part controlSystem : ControlSystem;
        part alarmSystem : AlarmSystem;
        part operatorInterface : OperatorInterface;

        flow airFlow of MedicalAir from externalAirSupply.gas to gasBlender.airIn.gas;
        flow o2Flow of Oxygen from externalO2Supply.gas to gasBlender.o2In.gas;
        flow mixtureFlow of GasMixture from gasBlender.mixtureOut.gas to flowGenerator.mixtureIn.gas;
        flow continuousFlow of GasMixture from flowGenerator.flowOut.gas to pistonOscillator.flowIn.gas;
        flow oscillatoryFlow of GasMixture from pistonOscillator.flowOut.gas to patientCircuit.ventIn.gas;
        flow deliveredFlow of GasMixture from patientCircuit.patientOut.gas to patient.airwayIn.gas;

        flow operatorCmdFlow of ControlCommand from operatorInterface.controlOut.command to controlSystem.operatorIn.command;
        flow blenderCmdFlow of OxygenConcentrationCommand from controlSystem.blenderCmd.command to gasBlender.controlIn.command;
        flow flowCmdFlow of MeanPressureCommand from controlSystem.flowCmd.command to flowGenerator.controlIn.command;
        flow oscFreqCmdFlow of OscillationFrequencyCommand from controlSystem.oscFreqCmd.command to pistonOscillator.freqControlIn.command;
        flow oscAmpCmdFlow of PressureAmplitudeCommand from controlSystem.oscAmpCmd.command to pistonOscillator.ampControlIn.command;

        flow pressureSenseFlow of Measurement from patientCircuit.pressureSense.measurement to pressureMonitor.circuitIn.measurement;
        flow volumeSenseFlow of Measurement from patientCircuit.volumeSense.measurement to volumeMonitor.circuitIn.measurement;
        flow pressureReportFlow of Measurement from pressureMonitor.monitorOut.measurement to controlSystem.pressureData.measurement;
        flow volumeReportFlow of Measurement from volumeMonitor.monitorOut.measurement to controlSystem.volumeData.measurement;
        flow alarmTriggerFlow of AlarmEvent from controlSystem.alarmCmd.alarm to alarmSystem.alarmIn.alarm;

        flow audibleAlarmFlow of AlarmEvent from alarmSystem.audibleOut.alarm to externalAlarmAudible.alarm;
        flow visualAlarmFlow of AlarmEvent from alarmSystem.visualOut.alarm to externalAlarmVisual.alarm;

        exhibit state ventilatorStates : VentilatorStates {
            entry; then powerOff;
            state powerOff;
            accept PowerOnSignal then selfTest;
            state selfTest;
            accept SelfTestPassSignal then standby;
            accept SelfTestFailSignal then criticalAlarm;
            state standby;
            accept StartVentilationSignal then activeVentilating;
            accept PowerOffSignal then powerOff;
            state activeVentilating;
            accept StopVentilationSignal then standby;
            accept CriticalAlarmSignal then criticalAlarm;
            accept PowerOffSignal then powerOff;
            state criticalAlarm;
            accept AlarmResetSignal then standby;
            accept PowerOffSignal then powerOff;
        }
    }

    requirement def OxygenMixingReq {
        doc /* The gas blender shall mix air and oxygen to the prescribed concentration within 2 percent. */
        attribute prescribedConcentration : Percentage;
        attribute actualConcentration : Percentage;
        require constraint { (actualConcentration - prescribedConcentration <= 2) && (prescribedConcentration - actualConcentration <= 2) }
    }

    requirement def MeanPressureReq {
        doc /* The continuous flow generator shall maintain the prescribed mean airway pressure within 1 cmH2O. */
        attribute prescribedPressure : PressureValue;
        attribute actualPressure : PressureValue;
        require constraint { (actualPressure - prescribedPressure <= 1) && (prescribedPressure - actualPressure <= 1) }
    }

    requirement def OscillationFrequencyReq {
        doc /* The piston oscillator shall oscillate at the prescribed frequency between 3 and 15 Hz. */
        attribute prescribedFrequency : FrequencyValue;
        attribute actualFrequency : FrequencyValue;
        require constraint { actualFrequency >= 3 && actualFrequency <= 15 && (actualFrequency - prescribedFrequency <= 1) && (prescribedFrequency - actualFrequency <= 1) }
    }

    requirement def PressureAmplitudeReq {
        doc /* The piston oscillator shall generate the prescribed pressure amplitude within 2 cmH2O. */
        attribute prescribedAmplitude : PressureValue;
        attribute actualAmplitude : PressureValue;
        require constraint { (actualAmplitude - prescribedAmplitude <= 2) && (prescribedAmplitude - actualAmplitude <= 2) }
    }

    requirement def AlarmResponseReq {
        doc /* The alarm system shall trigger if monitored values exceed safe limits within 100 ms. */
        attribute pressureLimit : PressureValue;
        attribute actualPressure : PressureValue;
        attribute volumeLimit : VolumeValue;
        attribute actualVolume : VolumeValue;
        attribute responseTime : TimeValue;
        require constraint { responseTime <= 0.1 && actualPressure <= pressureLimit && actualVolume <= volumeLimit }
    }
}
