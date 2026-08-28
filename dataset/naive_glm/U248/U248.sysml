package HugMachine {
    public import ISQ::*;
    
    // ---- Value Types ----
    value def Force :> Real { unit 'N' }
    value def Pressure :> Real { unit 'Pa' }
    value def Duration :> Real { unit 's' }
    value def Intensity :> Real { unit 'pct' }
    value def Position :> Real { unit 'm' }
    value def Velocity :> Real {> Position / Duration }
    
    enum def SessionMode { gentle; moderate; firm; }
    enum def SessionCommand { start; pause; resume; stop; }
    enum def SafetyStatus { nominal; warning; emergencyStop; }
    
    // ---- Item Types ----
    item def UserPreference {
        attribute mode : SessionMode;
        attribute intensity : Intensity;
        attribute duration : Duration;
    }
    item def UserProfile {
        attribute userId : String;
        attribute preference : UserPreference;
    }
    item def SensorReading {
        attribute pressure : Pressure;
        attribute timestamp : Duration;
    }
    item def ActuatorCommand {
        attribute targetForce : Force;
        attribute targetVelocity : Velocity;
    }
    item def SafetyAlert {
        attribute status : SafetyStatus;
        attribute measuredForce : Force;
        attribute measuredPressure : Pressure;
    }
    
    // ---- Port Definitions ----
    port def PressureSensorPort { out reading : SensorReading; }
    port def ActuatorCmdPort { out command : ActuatorCommand; in forceFeedback : Force; }
    port def UIPort {
        in command : SessionCommand;
        in preference : UserPreference;
        in profile : UserProfile;
        out statusDisplay : String;
    }
    port def SafetyCmdPort { out alert : SafetyAlert; }
    port def ControlBusPort {
        in sensorData : SensorReading;
        in userCmd : SessionCommand;
        in userPref : UserPreference;
        out actuatorCmd : ActuatorCommand;
        out uiStatus : String;
    }
    
    // ---- Requirements ----
    requirement def ProvideTherapeuticHug {
        subject hugMachine : HugMachineSystem;
        objective {
            The hugMachine shall provide controlled and adjustable physical embraces 
            for stress relief and emotional support.
        }
    }
    requirement def CalibratedForceApplication {
        subject arms : RoboticArm::*;
        objective {
            Each arm shall apply a calibrated force not exceeding the user-selected 
            intensity and the maximum safety limit.
        }
    }
    requirement def PresenceDetection {
        subject sensors : PressureSensor::*;
        objective {
            The system shall detect user presence using left, right, and back 
            pressure sensors before initiating a hug.
        }
    }
    requirement def EmergencyStop {
        subject safetyController : SafetyController;
        objective {
            If force or pressure readings exceed pre-set maximum safety limits, 
            the safetyController shall trigger an immediate emergency stop causing 
            the arms to release and retract.
        }
    }
    requirement def SessionControl {
        subject ui : UserInterface;
        objective {
            The user shall be able to pause, resume, or stop the session at any 
            time through the ui.
        }
    }
    requirement def UserProfileSupport {
        subject ui : UserInterface;
        objective {
            The ui shall support saving and loading user profiles containing 
            preferred session settings.
        }
    }
    
    // ---- Parts ----
    part def PressureSensor {
        attribute location : String;
        attribute maxSafePressure : Pressure = 8000[Pa];
        port sensorOut : PressureSensorPort;
        
        attribute currentPressure : Pressure;
        
        action def sensePressure {
            in userContact : Boolean;
            out reading : SensorReading;
        }
        
        action sense : sensePressure {
            if userContact then {
                currentPressure := currentPressure + 100[Pa];
            }
            sensorOut.reading.pressure := currentPressure;
            sensorOut.reading.timestamp := now();
        }
    }
    
    part def ActuatorAssembly {
        attribute maxForce : Force = 120[N];
        attribute maxVelocity : Velocity = 0.5[m/s];
        port cmdIn : ActuatorCmdPort;
        
        attribute appliedForce : Force;
        attribute armPosition : Position;
        
        action def applyForce {
            in command : ActuatorCommand;
            out feedbackForce : Force;
        }
        
        action execute : applyForce {
            if command.targetForce > maxForce then {
                appliedForce := maxForce;
            } else {
                appliedForce := command.targetForce;
            }
            cmdIn.forceFeedback := appliedForce;
        }
    }
    
    part def RoboticArm {
        attribute side : String;
        attribute contactSurface : String;
        port actuatorPort : ActuatorCmdPort;
        
        part actuator : ActuatorAssembly {
            port cmdIn : ActuatorCmdPort = actuatorPort;
        }
        
        action def extend {
            in targetPosition : Position;
        }
        action def retract {
            in targetVelocity : Velocity;
        }
        action def applyPressure {
            in targetForce : Force;
        }
        action def release {
            in releaseVelocity : Velocity;
        }
    }
    
    part def UserInterface {
        attribute currentPreference : UserPreference;
        attribute savedProfiles : UserProfile[0..*];
        port uiPort : UIPort;
        
        action def capturePreferences {
            out preference : UserPreference;
        }
        action def saveProfile {
            in profile : UserProfile;
        }
        action def loadProfile {
            in userId : String;
            out profile : UserProfile;
        }
        action def displayStatus {
            in status : String;
        }
        
        action run {
            capturePreferences();
            uiPort.statusDisplay := "Ready";
        }
    }
    
    part def SafetyController {
        attribute maxSafeForce : Force = 100[N];
        attribute maxSafePressure : Pressure = 6000[Pa];
        attribute status : SafetyStatus = SafetyStatus::nominal;
        port safetyOut : SafetyCmdPort;
        
        action def monitor {
            in force : Force;
            in pressure : Pressure;
            out alert : SafetyAlert;
        }
        
        action supervise : monitor {
            if force > maxSafeForce or pressure > maxSafePressure then {
                status := SafetyStatus::emergencyStop;
                safetyOut.alert.status := status;
                safetyOut.alert.measuredForce := force;
                safetyOut.alert.measuredPressure := pressure;
            } else if force > 0.8 * maxSafeForce or pressure > 0.8 * maxSafePressure then {
                status := SafetyStatus::warning;
            } else {
                status := SafetyStatus::nominal;
            }
        }
        
        state def SafetyStateMachine {
            entry; then Nominal;
            state Nominal;
            state Warning;
            state EmergencyStop;
            transition Nominal -> Warning 
                when supervise.status == SafetyStatus::warning;
            transition Warning -> Nominal 
                when supervise.status == SafetyStatus::nominal;
            transition Nominal -> EmergencyStop 
                when supervise.status == SafetyStatus::emergencyStop;
            transition Warning -> EmergencyStop 
                when supervise.status == SafetyStatus::emergencyStop;
        }
    }
    
    part def ControlProcessor {
        attribute activePreference : UserPreference;
        attribute sessionActive : Boolean = false;
        attribute sessionPaused : Boolean = false;
        attribute sessionElapsed : Duration = 0[s];
        attribute targetForce : Force;
        port controlBus : ControlBusPort;
        
        action def calculateForce {
            in preference : UserPreference;
            in sensorData : SensorReading;
            out command : ActuatorCommand;
        }
        
        action def manageSession {
            in command : SessionCommand;
            in preference : UserPreference;
        }
        
        action compute : calculateForce {
            attribute baseForce : Force;
            if preference.mode == SessionMode::gentle then {
                baseForce := 20[N];
            } else if preference.mode == SessionMode::moderate then {
                baseForce := 45[N];
            } else {
                baseForce := 70[N];
            }
            targetForce := baseForce * (preference.intensity / 100[pct]);
            controlBus.actuatorCmd.targetForce := targetForce;
            controlBus.actuatorCmd.targetVelocity := 0.2[m/s];
        }
        
        state def ControlStateMachine {
            entry; then Idle;
            state Idle;
            state DetectingUser;
            state ClosingArms;
            state Hugging;
            state Paused;
            state Releasing;
            state EmergencyRetract;
            
            transition Idle -> DetectingUser 
                when controlBus.userCmd == SessionCommand::start;
            transition DetectingUser -> ClosingArms 
                when controlBus.sensorData.pressure > 500[Pa];
            transition ClosingArms -> Hugging 
                when controlBus.sensorData.pressure > 2000[Pa];
            transition Hugging -> Paused 
                when controlBus.userCmd == SessionCommand::pause;
            transition Paused -> Hugging 
                when controlBus.userCmd == SessionCommand::resume;
            transition Hugging -> Releasing 
                when sessionElapsed >= activePreference.duration;
            transition Paused -> Releasing 
                when controlBus.userCmd == SessionCommand::stop;
            transition Hugging -> Releasing 
                when controlBus.userCmd == SessionCommand::stop;
            transition Releasing -> Idle 
                when controlBus.sensorData.pressure < 100[Pa];
            transition any -> EmergencyRetract 
                when controlBus.sensorData.pressure > 6000[Pa];
            transition EmergencyRetract -> Idle 
                when controlBus.sensorData.pressure < 100[Pa];
        }
        
        action operate {
            manageSession(controlBus.userCmd, controlBus.userPref);
            compute(controlBus.userPref, controlBus.sensorData);
            sessionElapsed := sessionElapsed + 0.1[s];
        }
    }
    
    part def HugMachineSystem {
        requirement hugReq : ProvideTherapeuticHug;
        requirement forceReq : CalibratedForceApplication;
        requirement presenceReq : PresenceDetection;
        requirement safetyReq : EmergencyStop;
        requirement sessionReq : SessionControl;
        requirement profileReq : UserProfileSupport;
        
        part controlProcessor : ControlProcessor {
            port controlBus : ControlBusPort;
        }
        part safetyController : SafetyController {
            port safetyOut : SafetyCmdPort;
        }
        part ui : UserInterface {
            port uiPort : UIPort;
        }
        part leftArm : RoboticArm {
            attribute side = "left";
            attribute contactSurface = "left";
        }
        part rightArm : RoboticArm {
            attribute side = "right";
            attribute contactSurface = "right";
        }
        part leftSensor : PressureSensor {
            attribute location = "left";
        }
        part rightSensor : PressureSensor {
            attribute location = "right";
        }
        part backSensor : PressureSensor {
            attribute location = "back";
        }
        
        connection def SensorToControl {
            end sensorOut : PressureSensorPort;
            end controlIn : ControlBusPort;
        }
        connection def ControlToActuator {
            end controlOut : ControlBusPort;
            end actuatorIn : ActuatorCmdPort;
        }
        connection def UIToControl {
            end uiOut : UIPort;
            end controlIn : ControlBusPort;
        }
        connection def SafetyToControl {
            end safetyOut : SafetyCmdPort;
            end controlIn : ControlBusPort;
        }
        connection def ActuatorFeedbackToSafety {
            end actuatorFeedback : ActuatorCmdPort;
            end safetyIn : SafetyCmdPort;
        }
        
        connection leftSensorConn : SensorToControl 
            connect leftSensor.sensorOut to controlProcessor.controlBus;
        connection rightSensorConn : SensorToControl 
            connect rightSensor.sensorOut to controlProcessor.controlBus;
        connection backSensorConn : SensorToControl 
            connect backSensor.sensorOut to controlProcessor.controlBus;
        
        connection leftArmConn : ControlToActuator 
            connect controlProcessor.controlBus to leftArm.actuatorPort;
        connection rightArmConn : ControlToActuator 
            connect controlProcessor.controlBus to rightArm.actuatorPort;
        
        connection uiConn : UIToControl 
            connect ui.uiPort to controlProcessor.controlBus;
        
        connection safetyConn : SafetyToControl 
            connect safetyController.safetyOut to controlProcessor.controlBus;
        
        connection leftArmSafety : ActuatorFeedbackToSafety 
            connect leftArm.actuatorPort to safetyController.safetyOut;
        connection rightArmSafety : ActuatorFeedbackToSafety 
            connect rightArm.actuatorPort to safetyController.safetyOut;
        
        action def fullSessionOperation {
            attribute preference : UserPreference;
            attribute command : SessionCommand;
            
            parallel {
                ui.run();
                controlProcessor.operate();
                safetyController.supervise(
                    leftArm.actuator.cmdIn.forceFeedback,
                    leftSensor.sensorOut.reading.pressure
                );
            }
        }
        
        action main : fullSessionOperation;
    }
}
