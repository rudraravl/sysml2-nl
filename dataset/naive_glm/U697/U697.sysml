package GlassBreakDetectorSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type FrequencyValue :> Real {
        unit 'Hz';
    }

    value type SoundPressureLevel :> Real {
        unit 'dB';
    }

    value type VoltageValue :> Real {
        unit 'V';
    }

    value type ConfidenceValue :> Real {
        unit '%';
        constraint { 0 <= self and self <= 100 }
    }

    value type DurationHours :> Real {
        unit 'h';
    }

    value type DurationSeconds :> Real {
        unit 's';
    }

    value type PowerValue :> Real {
        unit 'W';
    }

    // ===== Item Definitions =====

    item def RawAudio {
        attribute sampleRate : FrequencyValue := 48000 [Hz];
        attribute bandwidth : FrequencyValue := 20000 [Hz];
        attribute amplitude : SoundPressureLevel;
    }

    item def ConditionedAudio {
        attribute lowerCutoff : FrequencyValue := 2500 [Hz];
        attribute upperCutoff : FrequencyValue := 8500 [Hz];
        attribute gain : Real := 10.0;
        attribute amplitude : SoundPressureLevel;
    }

    item def GlassBreakEvent {
        attribute detected : Boolean;
        attribute confidence : ConfidenceValue;
        attribute glassType : GlassType::GlassKind;
        attribute peakFrequency : FrequencyValue;
        attribute peakAmplitude : SoundPressureLevel;
    }

    enum GlassType {
        plate;
        tempered;
        laminated;
        unknown;
    }

    item def AlarmTrigger {
        attribute active : Boolean := true;
        attribute glassType : GlassType::GlassKind;
    }

    item def PowerStatus {
        attribute source : PowerSourceKind;
        attribute voltage : VoltageValue;
        attribute batteryLevel : Real := 1.0;
    }

    enum PowerSourceKind {
        main;
        backup;
    }

    // ===== Port Definitions =====

    port def AudioOutPort {
        out audio : RawAudio;
    }

    port def AudioInPort {
        in audio : RawAudio;
    }

    port def ConditionedAudioOutPort {
        out audio : ConditionedAudio;
    }

    port def ConditionedAudioInPort {
        in audio : ConditionedAudio;
    }

    port def EventOutPort {
        out event : GlassBreakEvent;
    }

    port def EventInPort {
        in event : GlassBreakEvent;
    }

    port def TriggerOutPort {
        out trigger : AlarmTrigger;
    }

    port def TriggerInPort {
        in trigger : AlarmTrigger;
    }

    port def PowerOutPort {
        out power : PowerStatus;
    }

    port def PowerInPort {
        in power : PowerStatus;
    }

    // ===== Part Definitions =====

    part def AcousticSensor {
        port audioOut : AudioOutPort;
        attribute minDetectable : SoundPressureLevel := 30 [dB];
        attribute maxDetectable : SoundPressureLevel := 120 [dB];
        attribute frequencyRange : FrequencyValue := 20000 [Hz];

        action def CaptureSound {
            in ambient : RawAudio;
            out captured : RawAudio;
        }

        perform action capture : CaptureSound;

        attribute currentAudio : RawAudio;

        action def Sense {
            subject audioOut.audio;
            then assign currentAudio.amplitude to a random value between minDetectable and maxDetectable;
        }
    }

    part def SignalConditioner {
        port audioIn : AudioInPort;
        port audioOut : ConditionedAudioOutPort;

        attribute lowerCutoff : FrequencyValue := 2500 [Hz];
        attribute upperCutoff : FrequencyValue := 8500 [Hz];
        attribute amplification : Real := 10.0;
        attribute noiseFloor : SoundPressureLevel := 35 [dB];

        action def FilterAndAmplify {
            in raw : RawAudio;
            out conditioned : ConditionedAudio;
            // Band-pass filter between 2.5 kHz and 8.5 kHz
            // Amplify signal by amplification factor
        }

        perform action process : FilterAndAmplify;

        action def Condition {
            subject audioIn.audio;
            then assign audioOut.audio.lowerCutoff to lowerCutoff;
            then assign audioOut.audio.upperCutoff to upperCutoff;
            then assign audioOut.audio.amplitude to audioIn.audio.amplitude * amplification;
        }
    }

    part def AnalysisEngine {
        port audioIn : ConditionedAudioInPort;
        port eventOut : EventOutPort;
        port triggerOut : TriggerOutPort;

        attribute confidenceThreshold : ConfidenceValue := 80 [%];
        attribute minPeakFrequency : FrequencyValue := 2500 [Hz];
        attribute maxPeakFrequency : FrequencyValue := 8500 [Hz];
        attribute minAmplitude : SoundPressureLevel := 70 [dB];

        action def AnalyzeSignal {
            in signal : ConditionedAudio;
            out event : GlassBreakEvent;
        }

        action def ClassifyGlass {
            in signal : ConditionedAudio;
            out glassKind : GlassType::GlassKind;
        }

        action def Evaluate {
            subject audioIn.audio;
            then decide {
                if (audioIn.audio.amplitude >= minAmplitude and
                    audioIn.audio.lowerCutoff >= minPeakFrequency and
                    audioIn.audio.upperCutoff <= maxPeakFrequency) {
                    then assign eventOut.event.detected to true;
                    then assign eventOut.event.confidence to a value >= confidenceThreshold;
                    then assign triggerOut.trigger.active to true;
                    then assign triggerOut.trigger.glassType to eventOut.event.glassType;
                } else {
                    then assign eventOut.event.detected to false;
                    then assign eventOut.event.confidence to 0 [%];
                }
            }
        }

        perform action analyze : AnalyzeSignal;
        perform action classify : ClassifyGlass;
    }

    part def AlarmModule {
        port triggerIn : TriggerInPort;

        attribute sirenLevel : SoundPressureLevel := 105 [dB];
        attribute sirenDuration : DurationSeconds := 180 [s];
        attribute externalSystemActivated : Boolean := false;

        action def ActivateAlarm {
            in trigger : AlarmTrigger;
            // Activate external security system
            // Sound siren at 105 dB
        }

        action def SoundSiren {
            attribute level : SoundPressureLevel := sirenLevel;
            then assign externalSystemActivated to true;
        }

        perform action activate : ActivateAlarm;

        action def Respond {
            subject triggerIn.trigger;
            then if triggerIn.trigger.active == true {
                then invoke SoundSiren;
            }
        }
    }

    part def BackupBattery {
        attribute nominalVoltage : VoltageValue := 12 [V];
        attribute capacityHours : DurationHours := 8 [h];
        attribute chargeLevel : Real := 1.0;
        attribute maxPower : PowerValue := 5 [W];

        action def Discharge {
            in duration : DurationHours;
            then assign chargeLevel to chargeLevel - (duration / capacityHours);
        }
    }

    part def PowerManagement {
        port powerOut : PowerOutPort;

        attribute mainVoltage : VoltageValue := 12 [V];
        attribute currentSource : PowerSourceKind := PowerSourceKind::main;
        attribute switchoverDelay : DurationSeconds := 0.5 [s];

        part backupBattery : BackupBattery;

        action def MonitorPower {
            attribute mainActive : Boolean := true;
            then decide {
                if mainActive == false {
                    then assign currentSource to PowerSourceKind::backup;
                    then assign powerOut.power.source to PowerSourceKind::backup;
                    then assign powerOut.power.voltage to backupBattery.nominalVoltage;
                } else {
                    then assign currentSource to PowerSourceKind::main;
                    then assign powerOut.power.source to PowerSourceKind::main;
                    then assign powerOut.power.voltage to mainVoltage;
                }
            }
        }

        action def SwitchToBackup {
            then assign currentSource to PowerSourceKind::backup;
            then assign powerOut.power.source to PowerSourceKind::backup;
            then assign powerOut.power.voltage to backupBattery.nominalVoltage;
        }

        perform action monitor : MonitorPower;
    }

    // ===== Top-Level System =====

    part def GlassBreakDetector {

        port externalAlarmInterface : TriggerOutPort;
        port powerInput : PowerInPort;

        part acousticSensor : AcousticSensor;
        part signalConditioner : SignalConditioner;
        part analysisEngine : AnalysisEngine;
        part alarmModule : AlarmModule;
        part powerManagement : PowerManagement;

        // Connections
        connection audioLink1 connect acousticSensor.audioOut to signalConditioner.audioIn {
            :>> audio : RawAudio;
        }

        connection audioLink2 connect signalConditioner.audioOut to analysisEngine.audioIn {
            :>> audio : ConditionedAudio;
        }

        connection eventLink connect analysisEngine.eventOut to analysisEngine.triggerOut {
            // Internal event-to-trigger linkage within analysis engine
        }

        connection triggerLink connect analysisEngine.triggerOut to alarmModule.triggerIn {
            :>> trigger : AlarmTrigger;
        }

        connection powerLink1 connect powerManagement.powerOut to acousticSensor.powerIn {
            :>> power : PowerStatus;
        }

        connection powerLink2 connect powerManagement.powerOut to signalConditioner.powerIn {
            :>> power : PowerStatus;
        }

        connection powerLink3 connect powerManagement.powerOut to analysisEngine.powerIn {
            :>> power : PowerStatus;
        }

        connection powerLink4 connect powerManagement.powerOut to alarmModule.powerIn {
            :>> power : PowerStatus;
        }

        connection externalTrigger connect alarmModule.triggerOut to externalAlarmInterface {
            :>> trigger : AlarmTrigger;
        }

        // State Machine
        state def DetectorStateMachine {
            entry;
            then idle;

            state idle {
                entry;
                // Initialize all modules
                then monitoring;
            }

            state monitoring {
                // Continuous listening via acousticSensor
                // Signal conditioning active
                // Analysis engine in standby evaluation mode
            }

            state analyzing {
                // Analysis engine evaluates signal against thresholds
                // Classifies glass type if possible
                exit;
                then decide {
                    if analysisEngine.eventOut.event.detected == true and
                       analysisEngine.eventOut.event.confidence >= 80 [%] {
                        then alarming;
                    } else {
                        then monitoring;
                    }
                }
            }

            state alarming {
                // Alarm module activates siren and external system
                // Remains until manual reset
            }

            transition from idle to monitoring
                when powerManagement.powerOut.power.voltage > 0 [V];

            transition from monitoring to analyzing
                when acousticSensor.audioOut.audio.amplitude > analysisEngine.minAmplitude;

            transition from analyzing to alarming
                when analysisEngine.eventOut.event.detected == true and
                     analysisEngine.eventOut.event.confidence >= 80 [%];

            transition from analyzing to monitoring
                when analysisEngine.eventOut.event.detected == false;

            transition from alarming to monitoring
                when manualReset == true;

            attribute manualReset : Boolean := false;
        }

        perform state behavior : DetectorStateMachine;
    }

    // ===== Requirements =====

    requirement def GlassBreakDetectionRequirement {
        doc /* The system shall continuously monitor ambient sound and trigger an alarm upon detecting a glass break event with confidence >= 80%. */
        subject detector : GlassBreakDetector;
        constraint { detector.analysisEngine.confidenceThreshold >= 80 [%] }
        constraint { detector.acousticSensor.frequencyRange >= 20000 [Hz] }
    }

    requirement def SignalConditioningRequirement {
        doc /* The signal conditioner shall band-pass filter audio between 2.5 kHz and 8.5 kHz and amplify the result. */
        subject conditioner : SignalConditioner;
        constraint { conditioner.lowerCutoff == 2500 [Hz] }
        constraint { conditioner.upperCutoff == 8500 [Hz] }
        constraint { conditioner.amplification >= 1.0 }
    }

    requirement def AlarmOutputRequirement {
        doc /* The alarm module shall sound a siren at 105 dB and activate the external security system upon confirmed glass break. */
        subject alarm : AlarmModule;
        constraint { alarm.sirenLevel == 105 [dB] }
    }

    requirement def PowerBackupRequirement {
        doc /* The system shall operate on 12V main power and automatically switch to backup battery for several hours upon main power failure. */
        subject power : PowerManagement;
        constraint { power.mainVoltage == 12 [V] }
        constraint { power.backupBattery.nominalVoltage == 12 [V] }
        constraint { power.backupBattery.capacityHours >= 4 [h] }
    }

    requirement def StateBehaviorRequirement {
        doc /* The detector shall cycle through idle, monitoring, analyzing, and alarming states, returning to monitoring after manual reset. */
        subject detector : GlassBreakDetector;
        constraint { detector.behavior.idle.isDefined }
        constraint { detector.behavior.monitoring.isDefined }
        constraint { detector.behavior.analyzing.isDefined }
        constraint { detector.behavior.alarming.isDefined }
    }

    requirement def GlassClassificationRequirement {
        doc /* The analysis engine shall attempt to classify broken glass as plate, tempered, or laminated. */
        subject engine : AnalysisEngine;
        constraint { engine.classify.out.glassKind in {GlassType::plate, GlassType::tempered, GlassType::laminated, GlassType::unknown} }
    }

    // ===== Requirement Satisfaction =====

    satisfaction satisfyGlassBreak by GlassBreakDetector satisfy GlassBreakDetectionRequirement;
    satisfaction satisfyConditioning by GlassBreakDetector.signalConditioner satisfy SignalConditioningRequirement;
    satisfaction satisfyAlarm by GlassBreakDetector.alarmModule satisfy AlarmOutputRequirement;
    satisfaction satisfyPower by GlassBreakDetector.powerManagement satisfy PowerBackupRequirement;
    satisfaction satisfyState by GlassBreakDetector satisfy StateBehaviorRequirement;
    satisfaction satisfyClassification by GlassBreakDetector.analysisEngine satisfy GlassClassificationRequirement;

}
