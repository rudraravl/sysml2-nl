package MedicalDeviceModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package Definitions {
        attribute def HeartRateValue :> ScalarValues::Real;
        attribute def BloodPressureValue :> ScalarValues::Real;
        attribute def TemperatureValue :> ScalarValues::Real;
        attribute def DoseRateValue :> ScalarValues::Real;
        attribute def DurationValue :> ScalarValues::Real;
        attribute def EnergyValue :> ScalarValues::Real;

        item def PowerOnSignal;
        item def SelfTestSuccess;
        item def SelfTestFailure;
        item def ConfigureSignal;
        item def StartTherapySignal;
        item def PauseTherapySignal;
        item def ResumeTherapySignal;
        item def StopTherapySignal;
        item def EmergencyStopSignal;
        item def TherapyCompleteSignal;
        item def AlarmSignal;
        item def ResetSignal;

        port def PowerPort;
        port def DataPort;
        port def VitalSignsPort;
        port def TherapyPort;
        port def AlarmPort;

        action def PerformSelfTest;
        action def DeliverTherapy;
        action def MonitorVitals;
        action def CheckStatus;
        action def StopTherapy;
        action def TriggerAlarm;
        action def GenerateReport;
        action def EmergencyShutdown;

        part def Battery {
            attribute capacity : EnergyValue;
            port powerOut : PowerPort;
        }
        part def PowerManagementUnit {
            port powerIn : PowerPort;
            port powerOut : PowerPort;
        }
        part def PowerSubsystem {
            part battery : Battery;
            part pmu : PowerManagementUnit;
            port powerOut : PowerPort;
            connect battery.powerOut to pmu.powerIn;
            connect pmu.powerOut to powerOut;
        }
        part def TherapyDeliveryUnit {
            port powerIn : PowerPort;
            port controlIn : DataPort;
            port therapyOut : TherapyPort;
            attribute doseRate : DoseRateValue;
            attribute duration : DurationValue;
            perform action deliverTherapy : DeliverTherapy;
        }
        part def TherapySubsystem {
            part tdu : TherapyDeliveryUnit;
            port powerIn : PowerPort;
            port controlIn : DataPort;
            port therapyOut : TherapyPort;
            connect powerIn to tdu.powerIn;
            connect controlIn to tdu.controlIn;
            connect tdu.therapyOut to therapyOut;
        }
        part def SafetyMonitor {
            port powerIn : PowerPort;
            port vitalsIn : VitalSignsPort;
            port statusOut : DataPort;
            port alarmOut : AlarmPort;
            attribute isSafe : Boolean;
            attribute maxHR : HeartRateValue;
            attribute minHR : HeartRateValue;
            attribute maxBP : BloodPressureValue;
            attribute maxTemp : TemperatureValue;
            perform action monitorVitals : MonitorVitals;
            perform action checkStatus : CheckStatus;
            perform action stopTherapy : StopTherapy;
            perform action triggerAlarm : TriggerAlarm;
        }
        part def ControlProcessor {
            port powerIn : PowerPort;
            port uiIn : DataPort;
            port monitorIn : DataPort;
            port therapyOut : DataPort;
            port displayOut : DataPort;
        }
        part def UserInterface {
            port powerIn : PowerPort;
            port cmdOut : DataPort;
            port displayIn : DataPort;
            port alarmIn : AlarmPort;
        }
        part def Patient {
            port vitalsOut : VitalSignsPort;
            port therapyIn : TherapyPort;
            attribute heartRate : HeartRateValue;
            attribute bloodPressure : BloodPressureValue;
            attribute temperature : TemperatureValue;
        }
    }

    private import Definitions::*;

    part def MedicalDevice {
        part powerSubsystem : PowerSubsystem;
        part therapySubsystem : TherapySubsystem;
        part safetyMonitor : SafetyMonitor;
        part controlProcessor : ControlProcessor;
        part userInterface : UserInterface;
        ref patient : Patient;

        connect powerSubsystem.powerOut to therapySubsystem.powerIn;
        connect powerSubsystem.powerOut to safetyMonitor.powerIn;
        connect powerSubsystem.powerOut to controlProcessor.powerIn;
        connect powerSubsystem.powerOut to userInterface.powerIn;
        
        connect patient.vitalsOut to safetyMonitor.vitalsIn;
        connect safetyMonitor.statusOut to controlProcessor.monitorIn;
        connect controlProcessor.therapyOut to therapySubsystem.controlIn;
        connect therapySubsystem.therapyOut to patient.therapyIn;
        connect userInterface.cmdOut to controlProcessor.uiIn;
        connect controlProcessor.displayOut to userInterface.displayIn;
        connect safetyMonitor.alarmOut to userInterface.alarmIn;

        perform action performSelfTest : PerformSelfTest;
        perform action deliverTherapy : DeliverTherapy;
        perform action monitorVitals : MonitorVitals;
        perform action stopTherapy : StopTherapy;
        perform action triggerAlarm : TriggerAlarm;
        perform action generateReport : GenerateReport;
        perform action emergencyShutdown : EmergencyShutdown;

        exhibit state deviceStates {
            entry; then off;
            state off;
            accept PowerOnSignal
                then testing;
            state testing {
                entry action testingAction : PerformSelfTest;
                accept SelfTestSuccess
                    then ready;
                accept SelfTestFailure
                    then alarmState;
            }
            state ready;
            accept ConfigureSignal
                then ready;
            accept StartTherapySignal
                if safetyMonitor.isSafe
                then active;
            state active {
                do action deliverTherapyAction : DeliverTherapy;
                do action monitorVitalsAction : MonitorVitals;
                accept PauseTherapySignal
                    then paused;
                accept TherapyCompleteSignal
                    then finalizing;
                accept EmergencyStopSignal
                    then emergencyShutdownState;
                accept AlarmSignal
                    then alarmState;
            }
            state paused {
                accept ResumeTherapySignal
                    then active;
                accept EmergencyStopSignal
                    then emergencyShutdownState;
            }
            state finalizing {
                entry action generateReportAction : GenerateReport;
                then standby;
            }
            state standby;
            accept PowerOnSignal
                then ready;
            state alarmState {
                entry action triggerAlarmAction : TriggerAlarm;
                do action stopTherapyAction : StopTherapy;
                accept ResetSignal
                    then ready;
                accept EmergencyStopSignal
                    then emergencyShutdownState;
            }
            state emergencyShutdownState {
                entry action emergencyShutdownAction : EmergencyShutdown;
                then off;
            }
        }
    }

    requirement def OperationalDurationRequirement {
        attribute minDuration : DurationValue = 8;
        subject device : MedicalDevice;
        objective {
            device.powerSubsystem.battery.capacity >= minDuration
        }
    }

    requirement def SafeTherapyRequirement {
        subject device : MedicalDevice;
        objective {
            device.safetyMonitor.isSafe
        }
    }
}
