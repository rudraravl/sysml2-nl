package 'Home Automation for Elderly and Disabled' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AlertLevel {
        attribute levelValue : Integer;
    }
    
    attribute def RoomIdentifier :> String;
    attribute def DeviceStatus :> Boolean;
    attribute def BrightnessLevel :> Real;
    
    item def VoiceCommand {
        attribute commandText : String;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def HealthAlert {
        attribute level : AlertLevel;
        attribute alertMessage : String;
        attribute location : RoomIdentifier;
    }
    
    item def EnvironmentCommand {
        attribute targetTemperature : ISQ::TemperatureValue;
        attribute targetBrightness : BrightnessLevel;
        attribute deviceId : String;
    }
    
    port def VoiceInterfacePort {
        in voiceInput : VoiceCommand;
        out voiceResponse : String;
    }
    
    port def HealthMonitorPort {
        out vitalData : ISQ::FrequencyValue;
        out alertSignal : HealthAlert;
    }
    
    port def EnvironmentSensorPort {
        out temperature : ISQ::TemperatureValue;
        out lightLevel : BrightnessLevel;
        out motionDetected : Boolean;
    }
    
    port def ActuatorControlPort {
        in controlCommand : EnvironmentCommand;
        out statusFeedback : DeviceStatus;
    }
    
    port def EmergencyPort {
        out emergencyAlert : HealthAlert;
        in responseConfirmation : String;
    }
    
    action def MonitorVitalSigns {
        in monitoringInterval : ISQ::TimeValue;
        out heartRate : ISQ::FrequencyValue;
        out abnormalityDetected : Boolean;
        
        first start;
        then merge continuousCheck;
        then action measureVitals {
            out currentHeartRate : ISQ::FrequencyValue;
        }
        then decide;
            if measureVitals.currentHeartRate < 50.0 or measureVitals.currentHeartRate > 120.0 then flagAbnormality;
            if measureVitals.currentHeartRate >= 50.0 and measureVitals.currentHeartRate <= 120.0 then continuousCheck;
        action flagAbnormality {
            out alert : Boolean;
        }
        then done;
    }
    
    action def DetectFall {
        in accelerationThreshold : ISQ::AccelerationValue;
        out fallDetected : Boolean;
        out fallLocation : RoomIdentifier;
        
        first start;
        then merge monitorMovement;
        then action readAccelerometer {
            out acceleration : ISQ::AccelerationValue;
        }
        then decide;
            if readAccelerometer.acceleration > accelerationThreshold then confirmFall;
            if readAccelerometer.acceleration <= accelerationThreshold then monitorMovement;
        action confirmFall {
            out confirmed : Boolean;
            out location : RoomIdentifier;
        }
        then done;
    }
    
    action def ProcessVoiceCommand {
        in command : VoiceCommand;
        out parsedAction : String;
        out targetDevice : String;
        
        first start;
        then action analyzeCommand {
            in voiceText : String;
            out intent : String;
        }
        then decide;
            if analyzeCommand.intent == "lighting" then controlLights;
            if analyzeCommand.intent == "temperature" then controlClimate;
            if analyzeCommand.intent == "emergency" then triggerEmergency;
        action controlLights {
            out lightCommand : String;
        }
        action controlClimate {
            out climateCommand : String;
        }
        action triggerEmergency {
            out emergencyCommand : String;
        }
        then done;
    }
    
    action def ManageEnvironment {
        in currentTemp : ISQ::TemperatureValue;
        in targetTemp : ISQ::TemperatureValue;
        in currentLight : BrightnessLevel;
        out heatingCommand : Boolean;
        out coolingCommand : Boolean;
        out lightingCommand : BrightnessLevel;
        
        first start;
        then action evaluateTemperature {
            in current : ISQ::TemperatureValue;
            in target : ISQ::TemperatureValue;
            out needsHeating : Boolean;
            out needsCooling : Boolean;
        }
        then action adjustClimate {
            in heating : Boolean;
            in cooling : Boolean;
            out hvacCommand : EnvironmentCommand;
        }
        then action evaluateLighting {
            in currentBrightness : BrightnessLevel;
            out targetBrightness : BrightnessLevel;
        }
        then action adjustLighting {
            in brightness : BrightnessLevel;
            out lightCommand : EnvironmentCommand;
        }
        then done;
    }
    
    action def HandleEmergency {
        in alert : HealthAlert;
        out notificationSent : Boolean;
        out emergencyServicesCalled : Boolean;
        
        first start;
        then action assessSeverity {
            in alertLevel : AlertLevel;
            out severity : Integer;
        }
        then decide;
            if assessSeverity.severity >= 9 then callEmergencyServices;
            if assessSeverity.severity >= 5 and assessSeverity.severity < 9 then notifyCaregiver;
            if assessSeverity.severity < 5 then logEvent;
        action callEmergencyServices {
            out serviceType : String;
            out locationInfo : RoomIdentifier;
        }
        then done;
        action notifyCaregiver {
            out caregiverContact : String;
            out alertMessage : String;
        }
        then done;
        action logEvent {
            out eventRecord : String;
        }
        then done;
    }
    
    part def WearableHealthMonitor {
        port healthPort : HealthMonitorPort;
        attribute sensorAccuracy : Real;
        attribute batteryLevel : Real;
        
        perform action monitorHealth : MonitorVitalSigns {
            in monitoringInterval = 1.0;
            out heartRate;
        }
    }
    
    part def FallDetectionSensor {
        port sensorPort : EnvironmentSensorPort;
        attribute sensitivity : Real;
        
        perform action detectFalls : DetectFall {
            in accelerationThreshold = 20.0;
            out fallDetected;
            out fallLocation;
        }
    }
    
    part def VoiceAssistantModule {
        port voicePort : VoiceInterfacePort;
        attribute recognitionAccuracy : Real;
        
        perform action processCommands : ProcessVoiceCommand {
            in command;
            out parsedAction;
            out targetDevice;
        }
    }
    
    part def EnvironmentController {
        port sensorInput : EnvironmentSensorPort;
        port actuatorOutput : ActuatorControlPort;
        
        part thermostat {
            attribute currentSetpoint : ISQ::TemperatureValue;
            attribute operatingMode : String;
        }
        
        part lightingSystem {
            attribute brightness : BrightnessLevel;
            attribute autoAdjust : Boolean;
        }
        
        perform action manageEnvironment : ManageEnvironment {
            in currentTemp;
            in currentLight;
            out heatingCommand;
            out coolingCommand;
            out lightingCommand;
        }
    }
    
    part def EmergencyResponseUnit {
        port emergencyPort : EmergencyPort;
        attribute responseTime : ISQ::TimeValue;
        attribute contactList : String[*];
        
        perform action handleEmergencies : HandleEmergency {
            in alert;
            out notificationSent;
            out emergencyServicesCalled;
        }
    }
    
    part def MedicationDispenser {
        attribute scheduleActive : Boolean;
        attribute dosageRemaining : Integer;
        
        action dispenseMedication {
            in scheduledTime : ISQ::TimeValue;
            out dispensed : Boolean;
            out reminderIssued : Boolean;
            
            first start;
            then action checkSchedule {
                in currentTime : ISQ::TimeValue;
                out medicationDue : Boolean;
            }
            then decide;
                if checkSchedule.medicationDue then issueReminder;
            action issueReminder {
                out voiceAlert : String;
                out visualAlert : String;
            }
            then action confirmIntake {
                out confirmed : Boolean;
            }
            then decide;
                if confirmIntake.confirmed then dispense;
            action dispense {
                out dispensedAmount : Integer;
            }
            then done;
        }
    }
    
    part def AssistiveLivingSystem;
    
    part assistiveLivingSystem : AssistiveLivingSystem {
        doc /*
            The Assistive Living System provides comprehensive home automation
            for elderly and disabled residents. Its primary function is to monitor
            health and safety, respond to emergencies, manage the living environment,
            and provide voice-controlled assistance to enable independent living
            with dignity and security.
        */
        
        part healthMonitor : WearableHealthMonitor {
            perform monitorHealth;
        }
        
        part fallDetector : FallDetectionSensor {
            perform detectFalls;
        }
        
        part voiceAssistant : VoiceAssistantModule {
            perform processCommands;
        }
        
        part environmentControl : EnvironmentController {
            perform manageEnvironment;
        }
        
        part emergencyResponse : EmergencyResponseUnit {
            perform handleEmergencies;
        }
        
        part medicationManager : MedicationDispenser;
        
        connection healthToEmergency connect 
            healthMonitor.healthPort to emergencyResponse.emergencyPort;
        
        connection fallToEmergency connect 
            fallDetector.sensorPort to emergencyResponse.emergencyPort;
        
        connection voiceToEnvironment connect 
            voiceAssistant.voicePort to environmentControl.actuatorOutput;
        
        action provideAssistiveCare {
            doc /*
                Coordinates all subsystems to provide continuous monitoring,
                environmental control, emergency response, and medication management.
            */
            
            first start;
            then fork;
            
            join healthMonitoring;
            action continuousHealthMonitoring references healthMonitor::monitorHealth;
            
            join fallMonitoring;
            action continuousFallDetection references fallDetector::detectFalls;
            
            join voiceControl;
            action processVoiceInteraction references voiceAssistant::processCommands;
            
            join environmentManagement;
            action maintainEnvironment references environmentControl::manageEnvironment;
            
            join medicationTracking;
            action manageMedication references medicationManager::dispenseMedication;
            
            join;
            then done;
        }
    }
    
    requirement def SafetyRequirement;
    requirement def AccessibilityRequirement;
    requirement def ReliabilityRequirement;
    requirement def ResponseRequirement;
    
    requirement <'REQ-001'> emergencyResponseTime : ResponseRequirement {
        doc /* The system shall detect and respond to emergency situations within 5 seconds. */
        subject assistiveLivingSystem;
        require constraint {
            assistiveLivingSystem.emergencyResponse.responseTime <= 5.0
        }
    }
    
    requirement <'REQ-002'> fallDetectionAccuracy : SafetyRequirement {
        doc /* The fall detection system shall detect falls with at least 95% accuracy. */
        subject assistiveLivingSystem.fallDetector;
        require constraint {
            assistiveLivingSystem.fallDetector.sensitivity >= 0.95
        }
    }
    
    requirement <'REQ-003'> voiceRecognitionAccuracy : AccessibilityRequirement {
        doc /* The voice assistant shall recognize commands with at least 90% accuracy for elderly users. */
        subject assistiveLivingSystem.voiceAssistant;
        require constraint {
            assistiveLivingSystem.voiceAssistant.recognitionAccuracy >= 0.90
        }
    }
    
    requirement <'REQ-004'> healthMonitoringContinuity : ReliabilityRequirement {
        doc /* The health monitoring system shall operate continuously with 99.5% uptime. */
        subject assistiveLivingSystem.healthMonitor;
    }
    
    requirement <'REQ-005'> medicationCompliance : SafetyRequirement {
        doc /* The medication dispenser shall track and ensure medication compliance with scheduled reminders. */
        subject assistiveLivingSystem.medicationManager;
        require constraint {
            assistiveLivingSystem.medicationManager.scheduleActive == true
        }
    }
    
    requirement <'REQ-006'> systemIntegration {
        doc /* All subsystems shall integrate seamlessly to provide coordinated assistive care. */
        subject assistiveLivingSystem;
        require emergencyResponseTime;
        require fallDetectionAccuracy;
        require voiceRecognitionAccuracy;
        require healthMonitoringContinuity;
        require medicationCompliance;
    }
}
