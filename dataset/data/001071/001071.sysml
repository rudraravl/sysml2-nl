package GlassBreakDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    comment SystemOverview
    /* This model describes a glass break detector system designed to monitor
     * ambient acoustic signals, identify the characteristic sound signature
     * of breaking glass, and trigger security alarm responses. The system
     * continuously analyzes sound patterns in the frequency range typical
     * of glass breakage events and activates alerts when a break is detected.
     */
    
    attribute def SoundPressureLevelValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def SensitivityValue :> Real;
    
    enum def SystemState {
        idle;
        monitoring;
        analyzing;
        alarming;
        reset;
    }
    
    enum def GlassTypeEnum {
        plate;
        tempered;
        laminated;
        wired;
    }
    
    item def AcousticSignal {
        attribute frequency : FrequencyValue;
        attribute amplitude : SoundPressureLevelValue;
        attribute duration : DurationValue;
        attribute timestamp : TimeInstantValue;
    }
    
    item def GlassBreakEvent {
        attribute detectionTime : TimeInstantValue;
        attribute confidenceLevel : Real;
        attribute glassType : GlassTypeEnum;
        attribute signalStrength : SoundPressureLevelValue;
    }
    
    port def AcousticPort {
        in item acousticInput : AcousticSignal;
    }
    
    port def AlarmPort {
        out item alarmTrigger : GlassBreakEvent;
    }
    
    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    part def AcousticSensor {
        attribute sensitivity : SensitivityValue;
        attribute minFrequency : FrequencyValue;
        attribute maxFrequency : FrequencyValue;
        attribute noiseFloor : SoundPressureLevelValue;
        
        port acousticIn : AcousticPort;
        port powerIn : PowerPort;
        
        action captureSound {
            out capturedSignal : AcousticSignal;
        }
    }
    
    part def SignalConditioner {
        attribute samplingRate : FrequencyValue;
        attribute lowCutoffFreq : FrequencyValue;
        attribute highCutoffFreq : FrequencyValue;
        attribute gain : Real;
        
        port signalIn : AcousticPort;
        port powerIn : PowerPort;
        
        action filterSignal {
            in rawSignal : AcousticSignal;
            out filteredSignal : AcousticSignal;
        }
        
        action amplifySignal {
            in inputSignal : AcousticSignal;
            out amplifiedSignal : AcousticSignal;
        }
    }
    
    part def AnalysisEngine {
        attribute detectionThreshold : SoundPressureLevelValue;
        attribute glassBreakFreqMin : FrequencyValue;
        attribute glassBreakFreqMax : FrequencyValue;
        attribute minimumConfidence : Real;
        
        port powerIn : PowerPort;
        
        action analyzeFrequency {
            in signal : AcousticSignal;
            out isGlassBreak : Boolean;
            out confidence : Real;
        }
        
        action classifyGlassType {
            in signal : AcousticSignal;
            out glassType : GlassTypeEnum;
        }
        
        action validateEvent {
            in signal : AcousticSignal;
            in confidence : Real;
            out isValid : Boolean;
        }
    }
    
    part def AlarmModule {
        attribute alarmActive : Boolean;
        attribute resetDelay : DurationValue;
        attribute sirenLevel : SoundPressureLevelValue;
        
        port alarmOut : AlarmPort;
        port powerIn : PowerPort;
        
        action activateAlarm {
            in breakEvent : GlassBreakEvent;
            out alarmStatus : Boolean;
        }
        
        action deactivateAlarm {
            in resetCommand : Boolean;
        }
        
        action soundSiren {
            in level : SoundPressureLevelValue;
            in duration : DurationValue;
        }
    }
    
    part def PowerManagement {
        attribute primaryVoltage : ElectricPotentialValue;
        attribute backupCapacity : EnergyValue;
        attribute batteryCharge : Real;
        attribute powerStatus : Boolean;
        
        port powerOut : PowerPort;
        
        action monitorPowerStatus {
            out mainPowerAvailable : Boolean;
            out batteryLevel : Real;
        }
        
        action switchToBackup {
            in mainPowerLost : Boolean;
        }
    }
    
    part def GlassBreakDetector {
        attribute systemId : String;
        attribute currentState : SystemState;
        attribute coverageArea : AreaValue;
        attribute operatingVoltage : ElectricPotentialValue;
        attribute maxDetectionRange : LengthValue;
        
        part sensor : AcousticSensor {
            attribute :>> sensitivity = 0.88;
            attribute :>> minFrequency = 100.0;
            attribute :>> maxFrequency = 16000.0;
            attribute :>> noiseFloor = 30.0;
        }
        
        part conditioner : SignalConditioner {
            attribute :>> samplingRate = 48000.0;
            attribute :>> lowCutoffFreq = 2500.0;
            attribute :>> highCutoffFreq = 8500.0;
            attribute :>> gain = 20.0;
        }
        
        part analyzer : AnalysisEngine {
            attribute :>> detectionThreshold = 75.0;
            attribute :>> glassBreakFreqMin = 3000.0;
            attribute :>> glassBreakFreqMax = 7500.0;
            attribute :>> minimumConfidence = 0.80;
        }
        
        part alarmUnit : AlarmModule {
            attribute :>> alarmActive = false;
            attribute :>> resetDelay = 45.0;
            attribute :>> sirenLevel = 105.0;
        }
        
        part powerMgmt : PowerManagement {
            attribute :>> primaryVoltage = 12.0 [V];
            attribute :>> backupCapacity = 10800.0;
            attribute :>> batteryCharge = 100.0;
            attribute :>> powerStatus = true;
        }
        
        connection sensorToConditioner connect 
            sensor.acousticIn to conditioner.signalIn;
        
        connection powerToSensor connect 
            powerMgmt.powerOut to sensor.powerIn;
        
        connection powerToConditioner connect 
            powerMgmt.powerOut to conditioner.powerIn;
        
        connection powerToAnalyzer connect 
            powerMgmt.powerOut to analyzer.powerIn;
        
        connection powerToAlarm connect 
            powerMgmt.powerOut to alarmUnit.powerIn;
    }
    
    action def MonitorEnvironment {
        in sensitivity : SensitivityValue;
        out acousticData : AcousticSignal;
    }
    
    action def ConditionSignal {
        in rawData : AcousticSignal;
        out conditionedData : AcousticSignal;
    }
    
    action def AnalyzeSignal {
        in conditionedSignal : AcousticSignal;
        out breakDetected : Boolean;
        out eventDetails : GlassBreakEvent;
    }
    
    action def TriggerAlarm {
        in event : GlassBreakEvent;
        out alarmActivated : Boolean;
    }
    
    action def ResetSystem {
        in resetCommand : Boolean;
    }
    
    action detectAndAlarm {
        first start;
        then merge continuousMonitor;
        
        then action monitor : MonitorEnvironment {
            out acousticData : AcousticSignal;
        }
        
        then action condition : ConditionSignal {
            in rawData = monitor.acousticData;
            out conditionedData : AcousticSignal;
        }
        
        then action analyze : AnalyzeSignal {
            in conditionedSignal = condition.conditionedData;
            out breakDetected : Boolean;
            out eventDetails : GlassBreakEvent;
        }
        
        then decide;
            if analyze.breakDetected then triggerAlarm;
            if !analyze.breakDetected then continuousMonitor;
        
        action triggerAlarm : TriggerAlarm {
            in event = analyze.eventDetails;
            out alarmActivated : Boolean;
        }
        then awaitReset;
        
        action awaitReset : ResetSystem {
            in resetCommand : Boolean;
        }
        then continuousMonitor;
        
        then done;
    }
    
    state def DetectorStateMachine {
        entry; then idleState;
        
        state idleState;
        then monitoringState;
        
        state monitoringState;
        accept soundDetected;
        then analyzingState;
        
        state analyzingState;
        if breakDetected then alarmingState;
        else monitoringState;
        
        state alarmingState;
        accept resetSignal;
        then resetState;
        
        state resetState;
        then monitoringState;
    }
    
    requirement <'GBD-REQ-001'> primaryDetectionRequirement {
        doc /* The glass break detector shall continuously monitor ambient acoustic
             * signals and detect the characteristic sound signature of breaking glass
             * within its specified coverage area.
             */
        subject detector : GlassBreakDetector;
        
        require constraint {
            detector.maxDetectionRange >= 8.0 [m]
        }
    }
    
    requirement <'GBD-REQ-002'> frequencyAnalysisRequirement {
        doc /* The system shall analyze acoustic signals in the frequency range
             * of 3 kHz to 7.5 kHz, which is characteristic of glass breakage events.
             */
        subject analysisEngine :> GlassBreakDetector::analyzer;
        
        assert constraint {
            analysisEngine.glassBreakFreqMin >= 3000.0 and
            analysisEngine.glassBreakFreqMax <= 7500.0
        }
    }
    
    requirement <'GBD-REQ-003'> alarmActivationRequirement {
        doc /* Upon detection of a glass break event with confidence level above
             * 80%, the system shall activate the alarm within 500 milliseconds.
             */
        subject alarmSystem :> GlassBreakDetector::alarmUnit;
    }
    
    requirement <'GBD-REQ-004'> powerBackupRequirement {
        doc /* The detector shall maintain continuous operation for at least 3 hours
             * on backup battery power in the event of primary power failure.
             */
        subject powerSystem :> GlassBreakDetector::powerMgmt;
        
        assert constraint {
            powerSystem.backupCapacity >= 10800.0
        }
    }
    
    requirement <'GBD-REQ-005'> falseAlarmReductionRequirement {
        doc /* The detector shall minimize false alarms by requiring acoustic
             * signatures to match both frequency and amplitude characteristics
             * of actual glass breakage events with minimum 80% confidence.
             */
        subject detector : GlassBreakDetector;
        
        assert constraint {
            detector.analyzer.minimumConfidence >= 0.80
        }
    }
    
    requirement <'GBD-REQ-006'> sensitivityRequirement {
        doc /* The acoustic sensor shall maintain a sensitivity level of at least
             * 0.85 to ensure reliable detection of glass break events.
             */
        subject sensorUnit :> GlassBreakDetector::sensor;
        
        assert constraint {
            sensorUnit.sensitivity >= 0.85
        }
    }
    
    part glassBreakDetectorInstance : GlassBreakDetector {
        attribute :>> systemId = "GBD-2025-ALPHA-001";
        attribute :>> currentState = SystemState::idle;
        attribute :>> coverageArea = 64.0 [m^2];
        attribute :>> operatingVoltage = 12.0 [V];
        attribute :>> maxDetectionRange = 9.0 [m];
    }
    
    satisfy primaryDetectionRequirement by glassBreakDetectorInstance;
    satisfy frequencyAnalysisRequirement by glassBreakDetectorInstance.analyzer;
    satisfy alarmActivationRequirement by glassBreakDetectorInstance.alarmUnit;
    satisfy powerBackupRequirement by glassBreakDetectorInstance.powerMgmt;
    satisfy falseAlarmReductionRequirement by glassBreakDetectorInstance;
    satisfy sensitivityRequirement by glassBreakDetectorInstance.sensor;
}
