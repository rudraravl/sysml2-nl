package BedwettingAlarmSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MoistureLevel :> Real {
        doc /* Normalized moisture level from 0.0 (dry) to 1.0 (fully wet) */
    }
    
    attribute def SoundIntensity :> Real {
        doc /* Alarm sound intensity in decibels */
    }
    
    attribute def VibrationStrength :> Real {
        doc /* Vibration motor strength from 0.0 to 1.0 */
    }
    
    attribute def MoistureThreshold;
    attribute def AlarmActivationSignal;
    attribute def ResetCommand;
    
    item def MoistureReading {
        attribute level : MoistureLevel;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def AlarmConfiguration {
        attribute soundEnabled : Boolean;
        attribute vibrationEnabled : Boolean;
        attribute soundLevel : SoundIntensity;
        attribute vibrationLevel : VibrationStrength;
    }
    
    port def MoistureOutputPort {
        out moistureData : MoistureReading;
    }
    
    port def AlarmControlPort {
        in activationSignal : AlarmActivationSignal;
        in config : AlarmConfiguration;
    }
    
    port def UserControlPort {
        out resetSignal : ResetCommand;
        out configUpdate : AlarmConfiguration;
    }
    
    part def MoistureSensorPad {
        doc /* Conductive sensor pad placed under bedsheet to detect moisture */
        port moistureOut : MoistureOutputPort;
        attribute detectionThreshold : MoistureLevel := 0.1;
        attribute currentReading : MoistureLevel := 0.0;
        attribute sensorActive : Boolean := true;
    }
    
    part def ControlUnit {
        doc /* Central processing unit that monitors sensor and triggers alarms */
        port moistureIn : MoistureOutputPort;
        port alarmControl : AlarmControlPort;
        port userControl : UserControlPort;
        attribute alarmThreshold : MoistureLevel := 0.15;
        attribute alarmActive : Boolean := false;
        attribute systemEnabled : Boolean := true;
    }
    
    part def AudioAlarm {
        doc /* Speaker unit that produces audible alert */
        port controlIn : AlarmControlPort;
        attribute maxSoundLevel : SoundIntensity;
        attribute currentSoundLevel : SoundIntensity := 0.0;
        attribute isPlaying : Boolean := false;
    }
    
    part def VibrationMotor {
        doc /* Vibration motor for tactile alert */
        port controlIn : AlarmControlPort;
        attribute maxVibration : VibrationStrength := 1.0;
        attribute currentVibration : VibrationStrength := 0.0;
        attribute isVibrating : Boolean := false;
    }
    
    part def BatteryPack {
        doc /* Power supply for the alarm system */
        attribute capacity : ISQ::EnergyValue;
        attribute currentCharge : ISQ::EnergyValue;
        attribute voltage : ISQ::ElectricPotentialValue := 9.0[V];
    }
    
    part def UserInterface {
        doc /* Control panel with buttons and status indicators */
        port userOut : UserControlPort;
        attribute powerButton : Boolean := false;
        attribute resetButton : Boolean := false;
        attribute sensitivityLevel : MoistureLevel := 0.15;
    }
    
    action def SenseMoisture {
        in sensorPad : MoistureSensorPad;
        out reading : MoistureReading;
        doc /* Continuously sample moisture level from sensor pad */
    }
    
    action def EvaluateThreshold {
        in moistureReading : MoistureReading;
        in threshold : MoistureLevel;
        out thresholdExceeded : Boolean;
        doc /* Compare moisture reading against configured threshold */
    }
    
    action def ActivateAlarms {
        in config : AlarmConfiguration;
        out soundActivated : Boolean;
        out vibrationActivated : Boolean;
        doc /* Trigger audio and vibration alarms based on configuration */
    }
    
    action def WaitForReset {
        out resetReceived : Boolean;
        doc /* Wait for user to acknowledge alarm and press reset */
    }
    
    action def DeactivateAlarms {
        out alarmsOff : Boolean;
        doc /* Turn off all alarm outputs */
    }
    
    action def BedwettingMonitoringCycle {
        doc /* Main operational cycle for bedwetting detection and alerting */
        
        first start;
        then merge continuousMonitoring;
        
        then action senseMoisture : SenseMoisture {
            out currentReading : MoistureReading;
        }
        
        then action evaluateThreshold : EvaluateThreshold {
            in moistureReading = senseMoisture.currentReading;
            in threshold : MoistureLevel;
            out thresholdExceeded : Boolean;
        }
        
        then decide;
            if evaluateThreshold.thresholdExceeded then triggerAlarm;
            if not evaluateThreshold.thresholdExceeded then continuousMonitoring;
        
        action triggerAlarm {
            action activateAlarms : ActivateAlarms {
                in config : AlarmConfiguration;
                out soundActivated : Boolean;
                out vibrationActivated : Boolean;
            }
            
            then action waitForReset : WaitForReset {
                out resetReceived : Boolean;
            }
            
            then action deactivateAlarms : DeactivateAlarms {
                out alarmsOff : Boolean;
            }
        }
        
        then continuousMonitoring;
        then done;
    }
    
    event def PowerOnEvent;
    event def MoistureDetectedEvent;
    event def UserResetEvent;
    event def PowerOffEvent;
    
    state def AlarmSystemLifecycle {
        doc /* State machine governing system operational modes */
        
        entry; then standby;
        
        state standby {
            doc /* System powered but not actively monitoring */
        }
        
        transition standby_to_monitoring
            first standby
            accept PowerOnEvent
            then monitoring;
        
        state monitoring {
            doc /* Active monitoring for moisture detection */
            do action continuousSensing;
        }
        
        transition monitoring_to_alarming
            first monitoring
            accept MoistureDetectedEvent
            then alarming;
        
        state alarming {
            doc /* Alarms activated, awaiting user reset */
            do action soundAlert;
            do action vibrateAlert;
        }
        
        transition alarming_to_monitoring
            first alarming
            accept UserResetEvent
            then monitoring;
        
        transition monitoring_to_standby
            first monitoring
            accept PowerOffEvent
            then standby;
        
        transition alarming_to_standby
            first alarming
            accept PowerOffEvent
            then standby;
    }
    
    part def BedwettingAlarmSystem {
        doc /* 
            Complete bedwetting alarm system designed to detect nocturnal enuresis
            and alert the user through audible and tactile stimuli. The system helps
            train bladder control by waking the user immediately upon moisture detection,
            creating a conditioned response to bladder fullness during sleep.
        */
        
        part sensorPad : MoistureSensorPad {
            attribute :>> detectionThreshold = 0.1;
        }
        
        part controller : ControlUnit {
            attribute :>> alarmThreshold = 0.15;
        }
        
        part audioAlarm : AudioAlarm {
            attribute :>> maxSoundLevel = 85.0;
        }
        
        part vibrationMotor : VibrationMotor {
            attribute :>> maxVibration = 1.0;
        }
        
        part battery : BatteryPack {
            attribute :>> voltage = 9.0[V];
        }
        
        part userInterface : UserInterface {
            attribute :>> sensitivityLevel = 0.15;
        }
        
        connection sensorToController connect 
            sensorPad.moistureOut to controller.moistureIn;
        
        connection controllerToAudio connect 
            controller.alarmControl to audioAlarm.controlIn;
        
        connection controllerToVibration connect 
            controller.alarmControl to vibrationMotor.controlIn;
        
        connection userToController connect 
            userInterface.userOut to controller.userControl;
        
        perform action monitoringCycle : BedwettingMonitoringCycle;
        
        exhibit state systemBehavior : AlarmSystemLifecycle;
    }
    
    part bedwettingAlarm : BedwettingAlarmSystem;
    
    requirement <'REQ-001'> rapidMoistureDetection {
        doc /* 
            The system shall detect the presence of moisture within 2 seconds
            of initial contact with the sensor pad to ensure timely alerting.
        */
        subject bedwettingAlarm : BedwettingAlarmSystem;
    }
    
    requirement <'REQ-002'> immediateAlarmActivation {
        doc /* 
            Upon detecting moisture above threshold, the system shall activate
            both audible and vibration alarms within 1 second to wake the user.
        */
        subject bedwettingAlarm : BedwettingAlarmSystem;
    }
    
    requirement <'REQ-003'> persistentAlarmOperation {
        doc /* 
            Alarms shall continue operating until manually reset by the user
            to ensure the bedwetting event is acknowledged and addressed.
        */
        subject bedwettingAlarm : BedwettingAlarmSystem;
    }
    
    requirement <'REQ-004'> adjustableSensitivity {
        doc /* 
            The system shall provide user-adjustable moisture sensitivity
            settings to accommodate different user needs and minimize false alarms.
        */
        subject bedwettingAlarm : BedwettingAlarmSystem;
    }
    
    requirement <'REQ-005'> reliablePowerSupply {
        doc /* 
            The system shall operate on battery power with sufficient capacity
            for at least 30 consecutive nights of monitoring without replacement.
        */
        subject bedwettingAlarm : BedwettingAlarmSystem;
    }
    
    requirement <'REQ-006'> multimodalAlerting {
        doc /* 
            The system shall provide both audible (minimum 75 dB) and tactile
            (vibration) alerts to ensure effective user awakening.
        */
        subject bedwettingAlarm : BedwettingAlarmSystem;
    }
    
    requirement primarySystemRequirement {
        doc /* 
            The bedwetting alarm system shall reliably detect bedwetting events
            and immediately alert the user through multiple sensory channels,
            supporting behavioral conditioning for improved bladder control.
        */
        
        require rapidMoistureDetection;
        require immediateAlarmActivation;
        require persistentAlarmOperation;
        require adjustableSensitivity;
        require reliablePowerSupply;
        require multimodalAlerting;
    }
}
