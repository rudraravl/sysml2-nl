package NasalEPAPSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        unit cmH2O;
        unit L_per_min;

        value def PressureValue :> Real {
            :>> unit = cmH2O;
        }
        value def FlowRateValue :> Real {
            :>> unit = L_per_min;
        }
        value def ValvePosition :> Real;

        enum def BreathingPhase {
            inhalation;
            exhalation;
        }

        attribute def OpenValveCommand;
        attribute def PartialCloseCommand;
        attribute def HighPressureAlarmSignal;
        attribute def LowPressureAlarmSignal;
        attribute def EmergencyShutdownSignal;
        attribute def StartSignal;
        attribute def StopSignal;
        attribute def SelfTestCompleteSignal;

        action def SenseAirflow {
            out airflow : FlowRateValue;
            out pressure : PressureValue;
        }
        action def DetectBreathingPhase {
            in airflow : FlowRateValue;
            out phase : BreathingPhase;
        }
        action def MeasurePressure {
            out pressure : PressureValue;
        }
        action def RegulatePressure {
            in targetPressure : PressureValue;
            in currentPressure : PressureValue;
            out valvePosition : ValvePosition;
        }
        action def ActuateValve {
            in position : ValvePosition;
        }
        action def CheckPressureLimits {
            in pressure : PressureValue;
            in highLimit : PressureValue;
            in lowLimit : PressureValue;
            out isSafe : Boolean;
        }
        action def TriggerAlarm;
        action def EmergencyShutdown;
        action def PerformSelfTest;

        port def AirwayPort {
            inout airflow : FlowRateValue;
            inout pressure : PressureValue;
        }
        port def PhaseDataPort {
            out phase : BreathingPhase;
            out pressure : PressureValue;
        }
        port def ValveCmdPort {
            out position : ValvePosition;
        }
        port def AlarmPort {
            out highAlarm : HighPressureAlarmSignal;
            out lowAlarm : LowPressureAlarmSignal;
            out shutdown : EmergencyShutdownSignal;
        }

        part def Patient {
            port airway : AirwayPort;
        }

        part def NasalInterface {
            port patientEnd : AirwayPort;
            port deviceEnd : AirwayPort;
        }

        part def RespiratoryMonitor {
            port airwayIn : AirwayPort;
            port dataOut : PhaseDataPort;
            perform action 'sense airflow' : SenseAirflow;
            perform action 'detect phase' : DetectBreathingPhase;
            perform action 'measure pressure' : MeasurePressure;
        }

        part def PressureRegulator {
            port dataIn : ~PhaseDataPort;
            port valveCmdOut : ValveCmdPort;
            attribute targetPressure : PressureValue;
            perform action 'regulate pressure' : RegulatePressure;
        }

        part def ExpiratoryValve {
            port valveCmdIn : ~ValveCmdPort;
            port airway : AirwayPort;
            attribute position : ValvePosition;
            perform action 'actuate valve' : ActuateValve;
        }

        part def SafetyMonitor {
            port pressureIn : ~PhaseDataPort;
            port alarmOut : AlarmPort;
            attribute maxPressure : PressureValue;
            attribute minPressure : PressureValue;
            perform action 'check pressure limits' : CheckPressureLimits;
            perform action 'trigger alarm' : TriggerAlarm;
            perform action 'emergency shutdown' : EmergencyShutdown;
        }

        part def NasalEPAPDevice {
            part monitor : RespiratoryMonitor;
            part regulator : PressureRegulator;
            part valve : ExpiratoryValve;
            part safety : SafetyMonitor;
            part nasalInterface : NasalInterface;
            port patientConnection : AirwayPort;
            port alarmOutput : ~AlarmPort;
            attribute targetPressure : PressureValue;
            attribute maxPressure : PressureValue;
            attribute minPressure : PressureValue;
            exhibit state 'system states' : SystemStates;
        }

        state def SystemStates;

        requirement def MaintainExpiratoryPressure {
            doc /* The system shall maintain a positive airway pressure during exhalation to prevent airway collapse. */
            attribute prescribedPressure : PressureValue;
        }
        requirement def MinimizeInspiratoryResistance {
            doc /* The system shall provide minimal resistance during inhalation to allow comfortable breathing. */
        }
        requirement def MonitorSafetyLimits {
            doc /* The system shall continuously monitor airway pressure and trigger alarms or emergency shutdown if limits are exceeded. */
            attribute maxPressureLimit : PressureValue;
            attribute minPressureLimit : PressureValue;
        }
        requirement def ResponsiveValveControl {
            doc /* The valve shall adjust dynamically based on detected breathing phase and real-time pressure feedback. */
        }
        requirement def SelfTestOnStartup {
            doc /* The system shall perform a self-test upon startup. */
        }
    }

    package Usages {
        private import Definitions::*;

        action 'perform self test' : PerformSelfTest;
        action 'sense airflow' : SenseAirflow;
        action 'detect phase' : DetectBreathingPhase;
        action 'measure pressure' : MeasurePressure;
        action 'regulate pressure' : RegulatePressure;
        action 'actuate valve' : ActuateValve;
        action 'check pressure limits' : CheckPressureLimits;
        action 'trigger alarm' : TriggerAlarm;
        action 'emergency shutdown' : EmergencyShutdown;

        part epapDevice : NasalEPAPDevice {
            attribute targetPressure : PressureValue = 10.0;
            attribute maxPressure : PressureValue = 20.0;
            attribute minPressure : PressureValue = 4.0;
        }

        part patient : Patient;

        state 'system states' : SystemStates {
            attribute currentPhase : BreathingPhase;
            attribute currentPressure : PressureValue;

            entry; then off;
            state off;
            accept StartSignal then selfTest;
            state selfTest {
                entry 'perform self test';
            }
            accept SelfTestCompleteSignal then running;
            state running {
                parallel {
                    state breathingCycle {
                        entry; then inhaling;
                        state inhaling {
                            entry send new OpenValveCommand() to epapDevice.valve;
                            do 'sense airflow';
                        }
                        accept when currentPhase == BreathingPhase::exhalation
                            then exhaling;
                        state exhaling {
                            entry send new PartialCloseCommand() to epapDevice.valve;
                            do 'regulate pressure';
                            do 'sense airflow';
                        }
                        accept when currentPhase == BreathingPhase::inhalation
                            then inhaling;
                    }
                    state safetyMonitoring {
                        entry; then normal;
                        state normal {
                            do 'check pressure limits';
                        }
                        accept when currentPressure > epapDevice.maxPressure
                            do 'trigger alarm'
                            then alarmState;
                        accept when currentPressure < epapDevice.minPressure
                            do 'trigger alarm'
                            then alarmState;
                        state alarmState {
                            do 'trigger alarm';
                        }
                        accept when currentPressure > epapDevice.maxPressure * 1.5
                            do 'emergency shutdown'
                            then shutdownState;
                        accept when currentPressure < epapDevice.minPressure * 0.5
                            do 'emergency shutdown'
                            then shutdownState;
                        accept when currentPressure <= epapDevice.maxPressure
                            and currentPressure >= epapDevice.minPressure
                            then normal;
                        state shutdownState {
                            do 'emergency shutdown';
                        }
                    }
                }
            }
            accept StopSignal then off;
        }

        connect patient.airway to epapDevice.patientConnection;
        connect epapDevice.patientConnection to epapDevice.nasalInterface.patientEnd;
        connect epapDevice.nasalInterface.deviceEnd to epapDevice.valve.airway;
        connect epapDevice.nasalInterface.deviceEnd to epapDevice.monitor.airwayIn;
        connect epapDevice.monitor.dataOut to epapDevice.regulator.dataIn;
        connect epapDevice.monitor.dataOut to epapDevice.safety.pressureIn;
        connect epapDevice.regulator.valveCmdOut to epapDevice.valve.valveCmdIn;
        connect epapDevice.safety.alarmOut to epapDevice.alarmOutput;

        satisfy MaintainExpiratoryPressure by epapDevice;
        satisfy MinimizeInspiratoryResistance by epapDevice.valve;
        satisfy MonitorSafetyLimits by epapDevice.safety;
        satisfy ResponsiveValveControl by epapDevice.regulator;
        satisfy SelfTestOnStartup by epapDevice;
    }
}
