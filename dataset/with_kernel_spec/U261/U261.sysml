package CardiologyInstrumentSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        value type HeartRateValue :> Real { unit "bpm"; }
        value type BloodPressureValue :> Real { unit "mmHg"; }
        value type OxygenSaturationValue :> Real { unit "%"; }
        value type DefibEnergyValue :> Real { unit "J"; }

        item def ECGWaveform {
            attribute leadCount : Integer = 12;
            attribute samplingRate : Real = 500;
        }
        item def VitalSignsData {
            attribute heartRate : HeartRateValue;
            attribute systolicBP : BloodPressureValue;
            attribute diastolicBP : BloodPressureValue;
            attribute oxygenSaturation : OxygenSaturationValue;
        }
        item def DiagnosticResult {
            attribute arrhythmiaDetected : Boolean;
            attribute stElevationDetected : Boolean;
            attribute abnormalBP : Boolean;
            attribute lowOxygen : Boolean;
            attribute shockAdvised : Boolean;
        }

        attribute def StandardAlarm;
        attribute def CriticalAlarm;
        attribute def ChargeCmd;
        attribute def ClinicianAuth;
        attribute def AlarmAcknowledge;
        attribute def DefibReady;

        port def ECGOutPort { out ecg : ECGWaveform; }
        port def VitalsOutPort { out vitals : VitalSignsData; }
        port def DataInPort {
            in ecg : ECGWaveform;
            in vitals : VitalSignsData;
        }
        port def DisplayInPort {
            in ecg : ECGWaveform;
            in vitals : VitalSignsData;
        }
        port def AlarmOutPort { out standardAlarm : StandardAlarm; out criticalAlarm : CriticalAlarm; }
        port def AlarmInPort { in standardAlarm : StandardAlarm; in criticalAlarm : CriticalAlarm; }
        port def DefibCmdOutPort { out chargeCmd : ChargeCmd; }
        port def DefibCmdInPort { in chargeCmd : ChargeCmd; in auth : ClinicianAuth; }
        port def DefibStatusOutPort { out ready : DefibReady; }

        action def CaptureECG { out ecg : ECGWaveform; }
        action def MeasureVitals { out vitals : VitalSignsData; }
        action def DisplayData {
            in ecg : ECGWaveform;
            in vitals : VitalSignsData;
        }
        action def AnalyzeData {
            in ecg : ECGWaveform;
            in vitals : VitalSignsData;
            out result : DiagnosticResult;
        }
        action def SoundAlarm;
        action def ChargeDefib { out ready : DefibReady; }
        action def DeliverShock;

        state def SystemStates;
        state def AlarmStates;
        state def DefibStates;

        part def Patient;
        part def Clinician;

        part def ECGMonitor {
            port ecgOut : ECGOutPort;
            perform action captureECG : CaptureECG;
        }
        part def VitalSignsMonitor {
            port vitalsOut : VitalsOutPort;
            perform action measureVitals : MeasureVitals;
        }
        part def DisplayConsole {
            port displayIn : DisplayInPort;
            perform action displayData : DisplayData;
        }
        part def DiagnosticProcessor {
            port dataIn : DataInPort;
            port alarmOut : AlarmOutPort;
            port defibCmdOut : DefibCmdOutPort;
            perform action analyzeData : AnalyzeData;
            exhibit state systemStates : SystemStates;
        }
        part def AlarmModule {
            port alarmIn : AlarmInPort;
            perform action soundAlarm : SoundAlarm;
            exhibit state alarmStates : AlarmStates;
        }
        part def Defibrillator {
            port cmdIn : DefibCmdInPort;
            port statusOut : DefibStatusOutPort;
            attribute energyLevel : DefibEnergyValue;
            perform action chargeDefib : ChargeDefib;
            perform action deliverShock : DeliverShock;
            exhibit state defibStates : DefibStates;
        }

        part def CardiologySystem {
            part patient : Patient;
            part ecgMonitor : ECGMonitor;
            part vitalsMonitor : VitalSignsMonitor;
            part displayConsole : DisplayConsole;
            part diagnosticProcessor : DiagnosticProcessor;
            part alarmModule : AlarmModule;
            part defibrillator : Defibrillator;
            part clinician : Clinician;

            connect ecgMonitor.ecgOut to diagnosticProcessor.dataIn;
            connect ecgMonitor.ecgOut to displayConsole.displayIn;
            connect vitalsMonitor.vitalsOut to diagnosticProcessor.dataIn;
            connect vitalsMonitor.vitalsOut to displayConsole.displayIn;
            connect diagnosticProcessor.alarmOut to alarmModule.alarmIn;
            connect diagnosticProcessor.defibCmdOut to defibrillator.cmdIn;
        }

        requirement def CardiologySystemRequirements {
            doc /* Integrated cardiology instrument system for continuous monitoring, automated diagnosis, and therapeutic intervention. */
            requirement ContinuousECGMonitoring {
                doc /* The ECG Monitor shall continuously capture 12-lead ECG waveforms in real-time. */
            }
            requirement VitalSignsMeasurement {
                doc /* The Vital Signs Monitor shall measure heart rate, blood pressure, and oxygen saturation at regular intervals. */
            }
            requirement RealTimeDisplay {
                doc /* The Display Console shall display live ECG waveforms and numerical vital signs for medical staff. */
            }
            requirement AutomatedDiagnosis {
                doc /* The Diagnostic Processor shall detect arrhythmias, ST-segment elevation, abnormal blood pressure, and low oxygen levels. */
            }
            requirement AlarmActivation {
                doc /* The Alarm Module shall issue standard alerts for minor abnormalities and critical alarms for life-threatening conditions. */
            }
            requirement DefibrillatorIntegration {
                doc /* The Defibrillator shall charge upon command from the Diagnostic Processor and deliver a controlled shock upon clinician authorization. */
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part cardiologySystem : CardiologySystem;

        action 'capture ecg' : CaptureECG;
        action 'measure vitals' : MeasureVitals;
        action 'display data' : DisplayData;
        action 'analyze data' : AnalyzeData;
        action 'sound alarm' : SoundAlarm;
        action 'charge defib' : ChargeDefib;
        action 'deliver shock' : DeliverShock;

        state systemStates : SystemStates parallel {
            state monitoring {
                entry; then active;
                state active {
                    do 'capture ecg';
                    do 'measure vitals';
                    do 'display data';
                    do 'analyze data';
                }
            }

            state alarmControl {
                entry; then normal;
                state normal;
                accept StandardAlarm
                    do send new StandardAlarm() to cardiologySystem.alarmModule
                    then standardAlert;
                accept CriticalAlarm
                    do send new CriticalAlarm() to cardiologySystem.alarmModule
                    then criticalAlert;
                state standardAlert;
                accept CriticalAlarm
                    do send new CriticalAlarm() to cardiologySystem.alarmModule
                    then criticalAlert;
                accept AlarmAcknowledge
                    then normal;
                state criticalAlert;
                accept StandardAlarm
                    do send new StandardAlarm() to cardiologySystem.alarmModule
                    then standardAlert;
                accept AlarmAcknowledge
                    then normal;
            }

            state defibControl {
                entry; then idle;
                state idle;
                accept ChargeCmd
                    do send new ChargeCmd() to cardiologySystem.defibrillator
                    then commanding;
                state commanding;
                accept DefibReady
                    then ready;
                state ready;
                accept ClinicianAuth
                    do send new ClinicianAuth() to cardiologySystem.defibrillator
                    then delivering;
                state delivering;
                then idle;
            }
        }

        state alarmStates : AlarmStates {
            entry; then silent;
            state silent;
            accept StandardAlarm
                do 'sound alarm'
                then standardAlert;
            accept CriticalAlarm
                do 'sound alarm'
                then criticalAlert;
            state standardAlert;
            accept CriticalAlarm
                do 'sound alarm'
                then criticalAlert;
            accept AlarmAcknowledge
                then silent;
            state criticalAlert;
            accept StandardAlarm
                do 'sound alarm'
                then standardAlert;
            accept AlarmAcknowledge
                then silent;
        }

        state defibStates : DefibStates {
            entry; then idle;
            state idle;
            accept ChargeCmd
                do 'charge defib'
                then charging;
            state charging;
            accept when 'charge defib'.ready
                then charged;
            state charged;
            accept ClinicianAuth
                do 'deliver shock'
                then delivering;
            state delivering;
            then idle;
        }

        satisfy CardiologySystemRequirements by cardiologySystem;
    }
}
