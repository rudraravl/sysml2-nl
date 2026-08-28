package CardiologyInstrumentSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def HeartRate :> Real { unit 'bpm'; }
    value def Pressure :> Real { unit 'mmHg'; }
    value def Saturation :> Real { unit '%'; }
    value def Voltage :> Real { unit 'V'; }
    value def Energy :> Real { unit 'J'; }
    value def Time :> Real { unit 's'; }
    value def Frequency :> Real { unit 'Hz'; }

    // ---- Enumerations ----
    enum def SeverityKind { normal; alert; critical; }
    enum def DefibStateKind { idle; charging; ready; delivering; fault; }
    enum def AlarmLevel { silent; standard; critical; }

    // ---- Item definitions ----
    item def ECGWaveform {
        attribute leadCount : Integer = 12;
        attribute samplingRate : Frequency = 500;
        attribute samples : Real[12][*] ordered;
        attribute timestamp : Time;
    }

    item def VitalSigns {
        attribute heartRate : HeartRate;
        attribute systolicBP : Pressure;
        attribute diastolicBP : Pressure;
        attribute oxygenSaturation : Saturation;
        attribute timestamp : Time;
    }

    item def DiagnosticResult {
        attribute arrhythmiaDetected : Boolean;
        attribute STElevationDetected : Boolean;
        attribute abnormalBP : Boolean;
        attribute lowOxygen : Boolean;
        attribute severity : SeverityKind;
        attribute timestamp : Time;
    }

    item def AlarmCommand {
        attribute level : AlarmLevel;
        attribute message : String;
    }

    item def DefibCommand {
        attribute chargeRequested : Boolean;
        attribute targetEnergy : Energy;
    }

    item def DefibStatus {
        attribute state : DefibStateKind;
        attribute energyStored : Energy;
        attribute ready : Boolean;
    }

    item def ShockDelivery {
        attribute deliveredEnergy : Energy;
        attribute duration : Time;
        attribute timestamp : Time;
    }

    // ---- Port definitions ----
    port def ECGOutPort { out waveform : ECGWaveform; }
    port def ECGInPort { in waveform : ECGWaveform; }
    port def VitalOutPort { out vitals : VitalSigns; }
    port def VitalInPort { in vitals : VitalSigns; }
    port def DiagnosticOutPort { out result : DiagnosticResult; }
    port def DiagnosticInPort { in result : DiagnosticResult; }
    port def AlarmCmdOutPort { out command : AlarmCommand; }
    port def AlarmCmdInPort { in command : AlarmCommand; }
    port def DefibCmdOutPort { out command : DefibCommand; }
    port def DefibCmdInPort { in command : DefibCommand; }
    port def DefibStatusOutPort { out status : DefibStatus; }
    port def DefibStatusInPort { in status : DefibStatus; }
    port def ShockOutPort { out shock : ShockDelivery; }
    port def ShockInPort { in shock : ShockDelivery; }

    // ---- ECG Monitor ----
    part def ECGMonitor {
        port ecgOut : ECGOutPort;
        attribute leadCount : Integer = 12;
        attribute samplingRate : Frequency = 500;
        attribute captureInterval : Time = 0.002;

        action def CaptureECG {
            in leadSignals : Real[12];
            out waveform : ECGWaveform;
        }

        state def ECGMonitorBehavior {
            initial start Active;
            state Active {
                entry action { 
                    /* Acquire 12-lead signals and emit waveform */
                    send ecgOut.waveform; 
                }
                do action { /* Continuous sampling loop */ }
            }
        }
        exhibit ECGMonitorBehavior;
    }

    // ---- Vital Signs Monitor ----
    part def VitalSignsMonitor {
        port vitalOut : VitalOutPort;
        attribute measurementInterval : Time = 1.0;

        action def MeasureVitals {
            out vitals : VitalSigns;
        }

        state def VitalMonitorBehavior {
            initial start Measuring;
            state Measuring {
                entry action { send vitalOut.vitals; }
                do action { /* Periodic measurement of HR, BP, SpO2 */ }
            }
        }
        exhibit VitalMonitorBehavior;
    }

    // ---- Display Console ----
    part def DisplayConsole {
        port ecgIn : ECGInPort;
        port vitalIn : VitalInPort;
        attribute resolution : String = "high";

        state def DisplayBehavior {
            initial start Showing;
            state Showing {
                do action { /* Render live ECG waveform and numerical vitals */ }
            }
        }
        exhibit DisplayBehavior;
    }

    // ---- Diagnostic Processor ----
    part def DiagnosticProcessor {
        port ecgIn : ECGInPort;
        port vitalIn : VitalInPort;
        port alarmCmd : AlarmCmdOutPort;
        port defibCmd : DefibCmdOutPort;
        port defibStatusIn : DefibStatusInPort;
        port diagnosticOut : DiagnosticOutPort;

        attribute arrhythmiaThreshold : HeartRate = 150;
        attribute lowSpO2Threshold : Saturation = 90;
        attribute highBPThreshold : Pressure = 180;
        attribute lowBPThreshold : Pressure = 90;
        attribute STElevationThreshold : Voltage = 0.1;

        action def AnalyzeData {
            in waveform : ECGWaveform;
            in vitals : VitalSigns;
            out result : DiagnosticResult;
            out alarm : AlarmCommand;
            out defib : DefibCommand;
        }

        state def ProcessorBehavior {
            initial start Idle;
            state Idle;
            state Analyzing;
            state TriggeringAlarm;
            state TriggeringDefib;
            state AwaitingDefibReady;

            transition Idle to Analyzing when ecgIn.waveform? or vitalIn.vitals?;
            transition Analyzing to TriggeringAlarm;
            transition TriggeringAlarm to TriggeringDefib 
                when [result.severity == SeverityKind::critical];
            transition TriggeringAlarm to Idle 
                when [result.severity != SeverityKind::critical];
            transition TriggeringDefib to AwaitingDefibReady;
            transition AwaitingDefibReady to Idle 
                when defibStatusIn.status? and defibStatusIn.status.ready;
        }
        exhibit ProcessorBehavior;
    }

    // ---- Alarm Module ----
    part def AlarmModule {
        port alarmIn : AlarmCmdInPort;
        attribute currentLevel : AlarmLevel = AlarmLevel::silent;

        state def AlarmBehavior {
            initial start Silent;
            state Silent;
            state StandardAlert {
                do action { /* Activate audible and visual standard alert */ }
            }
            state CriticalAlarm {
                do action { /* Activate urgent audible and visual critical alarm */ }
            }
            transition Silent to StandardAlert 
                when alarmIn.command? and alarmIn.command.level == AlarmLevel::standard;
            transition Silent to CriticalAlarm 
                when alarmIn.command? and alarmIn.command.level == AlarmLevel::critical;
            transition StandardAlert to Silent 
                when alarmIn.command? and alarmIn.command.level == AlarmLevel::silent;
            transition CriticalAlarm to Silent 
                when alarmIn.command? and alarmIn.command.level == AlarmLevel::silent;
            transition StandardAlert to CriticalAlarm 
                when alarmIn.command? and alarmIn.command.level == AlarmLevel::critical;
        }
        exhibit AlarmBehavior;
    }

    // ---- Defibrillator ----
    part def Defibrillator {
        port defibCmdIn : DefibCmdInPort;
        port statusOut : DefibStatusOutPort;
        port shockOut : ShockOutPort;

        attribute maxEnergy : Energy = 360.0;
        attribute storedEnergy : Energy;
        attribute chargeRate : Energy = 50.0; // J/s
        attribute authorized : Boolean = false;

        action def ChargeCapacitor {
            in target : Energy;
            out stored : Energy;
        }

        action def DeliverShock {
            in energy : Energy;
            out shock : ShockDelivery;
        }

        state def DefibBehavior {
            initial start Idle;
            state Idle {
                entry action { storedEnergy = 0.0; }
            }
            state Charging {
                do action { /* Charge capacitor toward target energy */ }
                entry action { send statusOut.status; }
            }
            state Ready {
                entry action { send statusOut.status; }
                do action { /* Await clinician authorization */ }
            }
            state Delivering {
                entry action { send shockOut.shock; }
                do action { /* Deliver controlled electrical shock */ }
            }
            state Fault;

            transition Idle to Charging 
                when defibCmdIn.command? and defibCmdIn.command.chargeRequested;
            transition Charging to Ready 
                when [storedEnergy >= defibCmdIn.command.targetEnergy];
            transition Ready to Delivering 
                when [authorized == true];
            transition Delivering to Idle;
            transition any to Fault when [faultCondition == true];
            transition Fault to Idle when [resetRequested == true];
        }
        exhibit DefibBehavior;
    }

    // ---- Top-level integrated system ----
    part def CardiologySystem {
        part ecgMonitor : ECGMonitor;
        part vitalMonitor : VitalSignsMonitor;
        part display : DisplayConsole;
        part processor : DiagnosticProcessor;
        part alarm : AlarmModule;
        part defib : Defibrillator;

        connection ecgMonitor.ecgOut to display.ecgIn;
        connection ecgMonitor.ecgOut to processor.ecgIn;
        connection vitalMonitor.vitalOut to display.vitalIn;
        connection vitalMonitor.vitalOut to processor.vitalIn;
        connection processor.alarmCmd to alarm.alarmIn;
        connection processor.defibCmd to defib.defibCmdIn;
        connection defib.statusOut to processor.defibStatusIn;
        connection defib.shockOut to patientShockSink.shockIn;

        part patientShockSink {
            port shockIn : ShockInPort;
        }
    }

    // ---- Requirements ----
    req def ContinuousCardiacMonitoring {
        doc { 
            The system shall continuously capture the patient's cardiac electrical 
            activity using a 12-lead ECG setup and produce a detailed waveform. 
        }
        attribute requiredLeads : Integer = 12;
    }

    req def VitalSignsMeasurement {
        doc { 
            The system shall measure heart rate, blood pressure, and oxygen 
            saturation at regular intervals. 
        }
        attribute measurementInterval : Time = 1.0;
    }

    req def RealTimeDisplay {
        doc { 
            The system shall provide a high-resolution display console showing 
            live ECG waveforms and numerical vital signs to medical staff. 
        }
    }

    req def AutomatedDiagnosis {
        doc { 
            The diagnostic processor shall automatically detect cardiac arrhythmias, 
            ST-segment elevation, abnormal blood pressure, and low oxygen levels 
            from incoming ECG and vital signs data. 
        }
    }

    req def TieredAlarmSystem {
        doc { 
            The alarm module shall issue a standard alert for minor abnormalities 
            and a critical alarm for life-threatening conditions to summon 
            immediate medical help. 
        }
    }

    req def IntegratedDefibrillation {
        doc { 
            The defibrillator shall charge upon command from the diagnostic 
            processor, signal readiness, and deliver a controlled electrical 
            shock to the patient upon authorization from a clinician. 
        }
        attribute maxEnergy : Energy = 360.0;
    }

    req def SystemIntegration {
        doc { 
            The ECG monitor, vital signs monitor, display console, diagnostic 
            processor, alarm module, and defibrillator shall be integrated into 
            a single patient-side instrument system for monitoring, diagnosis, 
            and therapeutic intervention. 
        }
        subject part : CardiologySystem;
        satisfy ContinuousCardiacMonitoring, VitalSignsMeasurement, 
            RealTimeDisplay, AutomatedDiagnosis, TieredAlarmSystem, 
            IntegratedDefibrillation;
    }
}
