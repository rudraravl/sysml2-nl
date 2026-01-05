package HugMachineSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ComfortLevel :> Real;
    attribute def IntensitySetting :> Real;
    
    enum def SessionMode {
        gentle;
        moderate;
        firm;
    }
    
    enum def SystemCommand {
        initialize;
        start;
        pause;
        resume;
        stop;
        emergencyRelease;
    }
    
    item def UserProfile {
        attribute preferredIntensity : IntensitySetting;
        attribute maxPressure : PressureValue;
        attribute sessionDuration : DurationValue;
    }
    
    part def PressureSensor {
        attribute sensorId : String;
        out currentPressure : PressureValue;
        out contactDetected : Boolean;
    }
    
    part def ActuatorAssembly {
        attribute actuatorId : String;
        attribute maxExtension : LengthValue;
        in commandedForce : ForceValue;
        in commandedPosition : LengthValue;
        out actualForce : ForceValue;
        out actualPosition : LengthValue;
    }
    
    part def ControlProcessor {
        in targetForce : ForceValue;
        in sensorFeedback : PressureValue;
        in userCommand : SystemCommand;
        out actuatorCommand : ForceValue;
        out systemStatus : String;
    }
    
    part def UserInterface {
        attribute displayActive : Boolean;
        in intensityInput : IntensitySetting;
        in modeSelection : SessionMode;
        out commandOutput : SystemCommand;
        out sessionParameters : UserProfile;
    }
    
    part def SafetyController {
        attribute maxAllowedPressure : PressureValue;
        attribute maxAllowedForce : ForceValue;
        in monitoredPressure : PressureValue;
        in monitoredForce : ForceValue;
        out safetyOverride : Boolean;
        out emergencyStop : Boolean;
    }
    
    action def InitializeSystem {
        in systemConfig : UserProfile;
        out calibrationComplete : Boolean;
        out systemReady : Boolean;
    }
    
    action def DetectUserPresence {
        in sensorReadings : PressureValue[*];
        out userDetected : Boolean;
        out userPosition : LengthValue;
    }
    
    action def CalculateTargetForce {
        in desiredIntensity : IntensitySetting;
        in currentMode : SessionMode;
        in userProfile : UserProfile;
        out targetForce : ForceValue;
    }
    
    action def ApplyHugPressure {
        in targetForce : ForceValue;
        in currentPressure : PressureValue;
        out adjustedForce : ForceValue;
    }
    
    action def MonitorUserComfort {
        in pressureFeedback : PressureValue;
        in forceFeedback : ForceValue;
        in sessionTime : DurationValue;
        out comfortLevel : ComfortLevel;
    }
    
    action def ReleaseUser {
        in releaseRate : Real;
        out releaseComplete : Boolean;
    }
    
    action def ExecuteHugSession {
        first start;
        then action init : InitializeSystem;
        then action detectUser : DetectUserPresence;
        then decide;
            if detectUser.userDetected then prepareHug;
            if !detectUser.userDetected then waitForUser;
        
        action waitForUser;
        then detectUser;
        
        action prepareHug;
        then action calculateForce : CalculateTargetForce;
        then merge hugLoop;
        
        action applyPressure : ApplyHugPressure {
            in targetForce = calculateForce.targetForce;
        }
        then action monitorComfort : MonitorUserComfort;
        then decide;
            if monitorComfort.comfortLevel >= 0.7 then continueHug;
            if monitorComfort.comfortLevel < 0.7 then adjustParameters;
        
        action adjustParameters;
        then calculateForce;
        
        action continueHug;
        then decide;
            if monitorComfort.sessionTime < 60 [s] then hugLoop;
            if monitorComfort.sessionTime >= 60 [s] then completeSession;
        
        action completeSession;
        then action release : ReleaseUser;
        then done;
    }
    
    part def HugMachine {
        doc /* 
            A therapeutic comfort delivery system that provides controlled,
            adjustable physical embrace to users seeking stress relief and
            emotional support through calibrated pressure application.
        */
        
        attribute systemInitialized : Boolean;
        attribute armsRetracted : Boolean;
        attribute armsExtending : Boolean;
        attribute contactEstablished : Boolean;
        attribute hugActive : Boolean;
        attribute maintainingPressure : Boolean;
        attribute emergencyStopActive : Boolean;
        
        attribute maxOperatingForce : ForceValue = 60 [N];
        attribute maxOperatingPressure : PressureValue = 10 [kPa];
        attribute defaultSessionDuration : DurationValue = 45 [s];
        attribute minSessionDuration : DurationValue = 15 [s];
        attribute maxSessionDuration : DurationValue = 120 [s];
        
        part userInterface : UserInterface {
            attribute :>> displayActive = true;
        }
        
        part controlProcessor : ControlProcessor;
        
        part leftActuator : ActuatorAssembly {
            attribute :>> actuatorId = "LEFT_ARM";
            attribute :>> maxExtension = 0.5 [m];
        }
        
        part rightActuator : ActuatorAssembly {
            attribute :>> actuatorId = "RIGHT_ARM";
            attribute :>> maxExtension = 0.5 [m];
        }
        
        part leftSensor : PressureSensor {
            attribute :>> sensorId = "LEFT_SENSOR";
        }
        
        part rightSensor : PressureSensor {
            attribute :>> sensorId = "RIGHT_SENSOR";
        }
        
        part backSensor : PressureSensor {
            attribute :>> sensorId = "BACK_SENSOR";
        }
        
        part safetyController : SafetyController {
            attribute :>> maxAllowedPressure = maxOperatingPressure;
            attribute :>> maxAllowedForce = maxOperatingForce;
        }
        
        perform action therapeuticSession : ExecuteHugSession;
        
        state operationalState {
            entry; then powerOff;
            
            state powerOff;
            transition powerOff_to_standby
                first powerOff
                then standby;
            
            state standby {
                entry assign systemInitialized = false;
            }
            transition standby_to_ready
                first standby
                then ready;
            
            state ready {
                entry assign armsRetracted = true;
            }
            transition ready_to_detecting
                first ready
                then detecting;
            
            state detecting;
            transition detecting_to_positioning
                first detecting
                then positioning;
            transition detecting_to_ready
                first detecting
                then ready;
            
            state positioning {
                entry assign armsExtending = true;
            }
            transition positioning_to_engaging
                first positioning
                then engaging;
            
            state engaging {
                entry assign contactEstablished = true;
            }
            transition engaging_to_activeHug
                first engaging
                then activeHug;
            
            state activeHug {
                entry assign hugActive = true;
            }
            transition activeHug_to_holding
                first activeHug
                then holding;
            transition activeHug_to_emergency
                first activeHug
                then emergency;
            
            state holding {
                entry assign maintainingPressure = true;
            }
            transition holding_to_releasing
                first holding
                then releasing;
            transition holding_to_paused
                first holding
                then paused;
            transition holding_to_emergency
                first holding
                then emergency;
            
            state paused {
                entry assign hugActive = false;
            }
            transition paused_to_holding
                first paused
                then holding;
            transition paused_to_releasing
                first paused
                then releasing;
            
            state releasing {
                entry assign armsRetracting = true;
                entry assign hugActive = false;
            }
            transition releasing_to_ready
                first releasing
                then ready;
            
            state emergency {
                entry assign emergencyStopActive = true;
                entry assign armsRetracting = true;
            }
            transition emergency_to_standby
                first emergency
                then standby;
        }
        
        connection uiToProcessor connect 
            userInterface.commandOutput to controlProcessor.userCommand;
        
        connection leftSensorToProcessor connect 
            leftSensor.currentPressure to controlProcessor.sensorFeedback;
        
        connection processorToLeftActuator connect 
            controlProcessor.actuatorCommand to leftActuator.commandedForce;
        
        connection processorToRightActuator connect 
            controlProcessor.actuatorCommand to rightActuator.commandedForce;
        
        connection leftSensorToSafety connect 
            leftSensor.currentPressure to safetyController.monitoredPressure;
        
        connection rightSensorToSafety connect 
            rightSensor.currentPressure to safetyController.monitoredPressure;
        
        connection leftActuatorToSafety connect 
            leftActuator.actualForce to safetyController.monitoredForce;
        
        connection rightActuatorToSafety connect 
            rightActuator.actualForce to safetyController.monitoredForce;
    }
    
    requirement <'REQ-HUG-PRIMARY'> primaryTherapeuticFunction {
        doc /* 
            The Hug Machine shall provide therapeutic comfort and stress relief
            by delivering controlled, adjustable physical embrace to users through
            calibrated pressure application with real-time safety monitoring.
        */
        subject machine : HugMachine;
        
        require <'REQ-HUG-FORCE'> forceLimit {
            doc /* The system shall limit applied force to safe therapeutic levels. */
            assert constraint {
                machine.maxOperatingForce <= 60 [N]
            }
        }
        
        require <'REQ-HUG-PRESSURE'> pressureLimit {
            doc /* The system shall limit applied pressure to prevent user discomfort. */
            assert constraint {
                machine.maxOperatingPressure <= 10 [kPa]
            }
        }
        
        require <'REQ-HUG-DURATION'> sessionDurationRange {
            doc /* The system shall support configurable session durations within safe limits. */
            assert constraint {
                machine.minSessionDuration >= 15 [s] and 
                machine.maxSessionDuration <= 120 [s] and
                machine.defaultSessionDuration >= machine.minSessionDuration and
                machine.defaultSessionDuration <= machine.maxSessionDuration
            }
        }
        
        require <'REQ-HUG-SAFETY'> emergencySafetyResponse {
            doc /* The system shall immediately cease operation when safety limits are exceeded. */
            assert constraint {
                machine.safetyController.emergencyStop implies machine.emergencyStopActive
            }
        }
        
        require <'REQ-HUG-CONTROL'> userControlCapability {
            doc /* The system shall provide user control for session initiation, pause, resume, and termination. */
            subject ui :>> machine.userInterface;
        }
    }
    
    part hugMachinePrototype : HugMachine {
        attribute :>> maxOperatingForce = 55 [N];
        attribute :>> maxOperatingPressure = 8.5 [kPa];
        attribute :>> defaultSessionDuration = 45 [s];
    }
    
    satisfy primaryTherapeuticFunction by hugMachinePrototype;
}
