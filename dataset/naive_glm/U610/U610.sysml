package BedwettingAlarmSystem {
    import ScalarValues::*;
    import SI::*;
    
    // ===== Value Types =====
    
    value def MoistureLevel :> Real {
        in ref unit : UnitValue[1] default unit::percent;
        attribute threshold : Real;
    }
    
    value def SensitivityLevel :> Real {
        in ref unit : UnitValue[1] default unit::percent;
    }
    
    value def Voltage :> Real {
        in ref unit : UnitValue[1] default unit::volt;
    }
    
    value def Current :> Real {
        in ref unit : UnitValue[1] default unit::ampere;
    }
    
    value def Frequency :> Real {
        in ref unit : UnitValue[1] default unit::hertz;
    }
    
    value def BatteryCapacity :> Real {
        in ref unit : UnitValue[1] default unit::ampereHour;
    }
    
    value def SoundPressureLevel :> Real {
        in ref unit : UnitValue[1] default unit::decibel;
    }
    
    // ===== Item Types =====
    
    item def Moisture {
        attribute level : MoistureLevel;
    }
    
    item def ElectricalSignal {
        attribute voltage : Voltage;
        attribute active : Boolean;
    }
    
    item def AudioSignal {
        attribute frequency : Frequency;
        attribute volume : SoundPressureLevel;
    }
    
    item def VibrationSignal {
        attribute frequency : Frequency;
        attribute intensity : Real;
    }
    
    item def PowerFlow {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    // ===== Enumerations =====
    
    enum def SystemState {
        enum OFF;
        enum MONITORING;
        enum ALARMING;
    }
    
    enum def ButtonEvent {
        enum POWER_ON;
        enum POWER_OFF;
        enum RESET;
        enum SENSITIVITY_UP;
        enum SENSITIVITY_DOWN;
    }
    
    // ===== Interfaces =====
    
    interface def MoistureDetectionInterface {
        in item moistureSignal : ElectricalSignal;
    }
    
    interface def AudioInterface {
        out item audio : AudioSignal;
    }
    
    interface def VibrationInterface {
        out item vibration : VibrationSignal;
    }
    
    interface def PowerInterface {
        out item power : PowerFlow;
    }
    
    interface def ControlInterface {
        in item buttonEvent : ButtonEvent;
        out item sensitivitySetting : SensitivityLevel;
    }
    
    // ===== Parts =====
    
    part def MoistureSensorPad {
        attribute placement : String default "under bedsheet";
        attribute conductiveArea : Real;
        attribute currentSensitivity : SensitivityLevel default 50.0;
        
        in item moisture : Moisture;
        out item detectionSignal : ElectricalSignal;
        
        port moistureInput {
            in item moistureIn : Moisture;
        }
        
        port detectionOutput {
            out item signal : ElectricalSignal;
        }
        
        action detectMoisture {
            in item sensedMoisture : Moisture;
            out item signal : ElectricalSignal;
            
            // Compare moisture level against sensitivity threshold
            if sensedMoisture.level > currentSensitivity {
                assign signal.voltage := 3.3;
                assign signal.active := true;
            } else {
                assign signal.voltage := 0.0;
                assign signal.active := false;
            }
        }
        
        action updateSensitivity {
            in newLevel : SensitivityLevel;
            then assign currentSensitivity := newLevel;
        }
    }
    
    part def Speaker {
        attribute maxVolume : SoundPressureLevel default 85.0;
        attribute isPowered : Boolean default false;
        
        in item audioSignal : AudioSignal;
        
        port audioInput {
            in item signal : AudioSignal;
        }
        
        action produceSound {
            in item signal : AudioSignal;
            if signal.volume > 0.0 {
                assign isPowered := true;
            } else {
                assign isPowered := false;
            }
        }
    }
    
    part def VibrationMotor {
        attribute maxFrequency : Frequency default 200.0;
        attribute isPowered : Boolean default false;
        
        in item vibrationSignal : VibrationSignal;
        
        port vibrationInput {
            in item signal : VibrationSignal;
        }
        
        action produceVibration {
            in item signal : VibrationSignal;
            if signal.intensity > 0.0 {
                assign isPowered := true;
            } else {
                assign isPowered := false;
            }
        }
    }
    
    part def UserInterface {
        attribute powerButtonPresent : Boolean default true;
        attribute resetButtonPresent : Boolean default true;
        attribute sensitivityAdjustPresent : Boolean default true;
        
        out item buttonEvent : ButtonEvent;
        out item sensitivityLevel : SensitivityLevel;
        
        port controlOutput {
            out item event : ButtonEvent;
            out item sensitivity : SensitivityLevel;
        }
        
        action handleButtonPress {
            out item event : ButtonEvent;
            out item sensitivity : SensitivityLevel;
        }
    }
    
    part def BatteryPack {
        attribute capacity : BatteryCapacity default 2000.0;
        attribute currentCharge : BatteryCapacity default 2000.0;
        attribute nominalVoltage : Voltage default 3.7;
        attribute estimatedNights : Integer default 14;
        
        out item power : PowerFlow;
        
        port powerOutput {
            out item powerFlow : PowerFlow;
        }
        
        action discharge {
            out item powerFlow : PowerFlow;
            assign powerFlow.voltage := nominalVoltage;
            assign powerFlow.current := 0.5;
        }
        
        action checkChargeLevel {
            if currentCharge < (capacity * 0.1) {
                // Low battery warning
            }
        }
    }
    
    part def ControlUnit {
        attribute currentState : SystemState default SystemState::OFF;
        attribute sensitivityThreshold : SensitivityLevel default 50.0;
        attribute alarmActive : Boolean default false;
        
        in item sensorSignal : ElectricalSignal;
        in item buttonEvent : ButtonEvent;
        in item power : PowerFlow;
        
        out item audioOutput : AudioSignal;
        out item vibrationOutput : VibrationSignal;
        out item sensitivityUpdate : SensitivityLevel;
        
        port sensorInput {
            in item signal : ElectricalSignal;
        }
        
        port uiInput {
            in item event : ButtonEvent;
        }
        
        port powerInput {
            in item powerFlow : PowerFlow;
        }
        
        port speakerOutput {
            out item audio : AudioSignal;
        }
        
        port motorOutput {
            out item vibration : VibrationSignal;
        }
        
        port sensorConfigOutput {
            out item sensitivity : SensitivityLevel;
        }
        
        // State Machine
        state def ControlUnitStateMachine {
            entry action;
            
            state OFF {
                entry action {
                    assign alarmActive := false;
                    assign audioOutput.volume := 0.0;
                    assign vibrationOutput.intensity := 0.0;
                }
                
                transition OFF_to_MONITORING
                    on sensorInput.buttonEvent::POWER_ON
                    to MONITORING;
            }
            
            state MONITORING {
                entry action {
                    assign alarmActive := false;
                    assign audioOutput.volume := 0.0;
                    assign vibrationOutput.intensity := 0.0;
                }
                
                do action monitorMoisture {
                    // Continuously check sensor signal
                    if sensorInput.signal.active == true {
                        // Transition to alarming
                    }
                }
                
                transition MONITORING_to_ALARMING
                    on sensorInput.signal.active == true
                    to ALARMING;
                
                transition MONITORING_to_OFF
                    on uiInput.event::POWER_OFF
                    to OFF;
            }
            
            state ALARMING {
                entry action {
                    assign alarmActive := true;
                    assign audioOutput.frequency := 3000.0;
                    assign audioOutput.volume := 85.0;
                    assign vibrationOutput.frequency := 200.0;
                    assign vibrationOutput.intensity := 1.0;
                }
                
                do action persistAlarm {
                    // Alarms continue to sound and vibrate persistently
                    assign audioOutput.volume := 85.0;
                    assign vibrationOutput.intensity := 1.0;
                }
                
                transition ALARMING_to_MONITORING
                    on uiInput.event::RESET
                    to MONITORING;
                
                transition ALARMING_to_OFF
                    on uiInput.event::POWER_OFF
                    to OFF;
            }
        }
        
        action processButtonEvent {
            in item event : ButtonEvent;
            out item sensitivity : SensitivityLevel;
            
            if event == ButtonEvent::SENSITIVITY_UP {
                assign sensitivityThreshold := sensitivityThreshold + 5.0;
            } elif event == ButtonEvent::SENSITIVITY_DOWN {
                assign sensitivityThreshold := sensitivityThreshold - 5.0;
            }
            assign sensitivity := sensitivityThreshold;
        }
        
        action activateAlarms {
            assign audioOutput.frequency := 3000.0;
            assign audioOutput.volume := 85.0;
            assign vibrationOutput.frequency := 200.0;
            assign vibrationOutput.intensity := 1.0;
            assign alarmActive := true;
        }
        
        action deactivateAlarms {
            assign audioOutput.volume := 0.0;
            assign vibrationOutput.intensity := 0.0;
            assign alarmActive := false;
        }
    }
    
    // ===== Top-level System =====
    
    part def BedwettingAlarm {
        attribute systemWeight : Real;
        attribute isPortable : Boolean default true;
        attribute isSelfContained : Boolean default true;
        
        part moistureSensorPad : MoistureSensorPad {
            attribute placement : String default "under bedsheet";
        }
        
        part controlUnit : ControlUnit;
        
        part speaker : Speaker;
        
        part vibrationMotor : VibrationMotor;
        
        part userInterface : UserInterface;
        
        part batteryPack : BatteryPack;
        
        // Connections
        connection moistureSensorToControl
            connect moistureSensorPad.detectionOutput
            to controlUnit.sensorInput;
        
        connection controlToSpeaker
            connect controlUnit.speakerOutput
            to speaker.audioInput;
        
        connection controlToMotor
            connect controlUnit.motorOutput
            to vibrationMotor.vibrationInput;
        
        connection uiToControl
            connect userInterface.controlOutput
            to controlUnit.uiInput;
        
        connection batteryToControl
            connect batteryPack.powerOutput
            to controlUnit.powerInput;
        
        connection controlToSensorConfig
            connect controlUnit.sensorConfigOutput
            to moistureSensorPad.detectionOutput;
        
        // System-level behavior
        state def SystemStateMachine {
            state SystemOff;
            state SystemMonitoring;
            state SystemAlarming;
            
            transition offToMonitoring
                on userInterface.controlOutput.event::POWER_ON
                from SystemOff to SystemMonitoring;
            
            transition monitoringToAlarming
                on moistureSensorPad.detectionOutput.signal.active == true
                from SystemMonitoring to SystemAlarming;
            
            transition alarmingToMonitoring
                on userInterface.controlOutput.event::RESET
                from SystemAlarming to SystemMonitoring;
            
            transition anyToOff
                on userInterface.controlOutput.event::POWER_OFF
                from SystemMonitoring to SystemOff;
            
            transition alarmingToOff
                on userInterface.controlOutput.event::POWER_OFF
                from SystemAlarming to SystemOff;
        }
    }
    
    // ===== Requirements =====
    
    requirement def MoistureDetectionRequirement {
        attribute id : String = "REQ-001";
        attribute text : String = "The system shall detect moisture on the sensor pad within 2 seconds of wetness beginning.";
        attribute maxDetectionTime : Real = 2.0;
    }
    
    requirement def AlarmActivationRequirement {
        attribute id : String = "REQ-002";
        attribute text : String = "Upon moisture detection, the system shall activate both audible and tactile alarms within 1 second.";
        attribute maxActivationTime : Real = 1.0;
    }
    
    requirement def PersistentAlarmRequirement {
        attribute id : String = "REQ-003";
        attribute text : String = "The alarms shall continue to sound and vibrate persistently until manually turned off via the reset button.";
    }
    
    requirement def SensitivityAdjustmentRequirement {
        attribute id : String = "REQ-004";
        attribute text : String = "The system shall allow the user to adjust moisture sensitivity level to prevent false alarms from sweat.";
        attribute minSensitivity : Real = 10.0;
        attribute maxSensitivity : Real = 90.0;
    }
    
    requirement def BatteryLifeRequirement {
        attribute id : String = "REQ-005";
        attribute text : String = "The battery pack shall support extended use over many nights, minimum 7 nights on a single charge.";
        attribute minNights : Integer = 7;
    }
    
    requirement def PortabilityRequirement {
        attribute id : String = "REQ-006";
        attribute text : String = "The system shall be portable and self-contained.";
    }
    
    requirement def StateTransitionRequirement {
        attribute id : String = "REQ-007";
        attribute text : String = "The system shall have distinct states: OFF, MONITORING, and ALARMING, with appropriate transitions triggered by power, moisture detection, and reset.";
    }
    
    requirement def AudibleAlarmRequirement {
        attribute id : String = "REQ-008";
        attribute text : String = "The audible alarm shall produce sound at minimum 80 dB to wake deep sleepers.";
        attribute minVolume : SoundPressureLevel = 80.0;
    }
    
    requirement def TactileAlarmRequirement {
        attribute id : String = "REQ-009";
        attribute text : String = "The vibration motor shall produce tactile alert at minimum 150 Hz frequency.";
        attribute minFrequency : Frequency = 150.0;
    }
    
    // ===== Requirement Satisfaction =====
    
    requirement MoistureDetectionSatisfaction : MoistureDetectionRequirement {
        subject moistureSensorPad.detectMoisture;
    }
    
    requirement AlarmActivationSatisfaction : AlarmActivationRequirement {
        subject controlUnit.activateAlarms;
    }
    
    requirement PersistentAlarmSatisfaction : PersistentAlarmRequirement {
        subject controlUnit.ControlUnitStateMachine.ALARMING.persistAlarm;
    }
    
    requirement SensitivityAdjustmentSatisfaction : SensitivityAdjustmentRequirement {
        subject controlUnit.processButtonEvent;
    }
    
    requirement BatteryLifeSatisfaction : BatteryLifeRequirement {
        subject batteryPack;
    }
    
    requirement PortabilitySatisfaction : PortabilityRequirement {
        subject BedwettingAlarm;
    }
    
    requirement StateTransitionSatisfaction : StateTransitionRequirement {
        subject controlUnit.ControlUnitStateMachine;
    }
    
    requirement AudibleAlarmSatisfaction : AudibleAlarmRequirement {
        subject speaker;
    }
    
    requirement TactileAlarmSatisfaction : TactileAlarmRequirement {
        subject vibrationMotor;
    }
}
