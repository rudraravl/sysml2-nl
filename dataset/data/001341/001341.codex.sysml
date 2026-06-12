package AnimatronicsSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> Real {
        doc /* Percentage value constrained to 0..100. */
    }

    attribute def AngleDeg :> Real {
        unit = "deg";
    }

    attribute def TorqueNm :> Real {
        unit = "N*m";
    }

    attribute def ForceN :> Real {
        unit = "N";
    }

    attribute def VoltageV :> Real {
        unit = "V";
    }

    attribute def CurrentA :> Real {
        unit = "A";
    }

    attribute def PowerW :> Real {
        unit = "W";
    }

    attribute def TemperatureC :> Real {
        unit = "degC";
    }

    attribute def TimeMs :> Real {
        unit = "ms";
    }

    attribute def AudioLevelDb :> Real {
        unit = "dB";
    }

    item def ElectricalPower {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
        attribute power : PowerW;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute targetJoint : String;
        attribute targetAngle : AngleDeg;
        attribute targetSpeed : Real;
        attribute priority : Integer;
    }

    item def MotionFeedback {
        attribute jointName : String;
        attribute measuredAngle : AngleDeg;
        attribute measuredTorque : TorqueNm;
        attribute temperature : TemperatureC;
        attribute faultDetected : Boolean;
    }

    item def AudioSignal {
        attribute level : AudioLevelDb;
        attribute sampleRateHz : Real;
        attribute phraseId : String;
    }

    item def LightingCommand {
        attribute red : Percent;
        attribute green : Percent;
        attribute blue : Percent;
        attribute intensity : Percent;
    }

    item def SafetyEvent {
        attribute source : String;
        attribute severity : Integer;
        attribute description : String;
        attribute emergencyStop : Boolean;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def CommandInPort {
        in item command : ControlCommand;
    }

    port def CommandOutPort {
        out item command : ControlCommand;
    }

    port def FeedbackInPort {
        in item feedback : MotionFeedback;
    }

    port def FeedbackOutPort {
        out item feedback : MotionFeedback;
    }

    port def AudioOutPort {
        out item audio : AudioSignal;
    }

    port def AudioInPort {
        in item audio : AudioSignal;
    }

    port def LightingOutPort {
        out item lighting : LightingCommand;
    }

    port def LightingInPort {
        in item lighting : LightingCommand;
    }

    port def SafetyOutPort {
        out item event : SafetyEvent;
    }

    port def SafetyInPort {
        in item event : SafetyEvent;
    }

    part def ServoActuator {
        attribute jointName : String;
        attribute maxTorque : TorqueNm;
        attribute rangeMin : AngleDeg;
        attribute rangeMax : AngleDeg;
        attribute commandedAngle : AngleDeg;
        attribute actualAngle : AngleDeg;
        attribute windingTemperature : TemperatureC;

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port feedbackOut : FeedbackOutPort;
        port safetyOut : SafetyOutPort;

        action def MoveToTarget {
            in targetAngle : AngleDeg;
            out achievedAngle : AngleDeg;
        }

        state def ServoOperatingState {
            state idle;
            state moving;
            state holding;
            state faulted;

            transition first idle;
            transition idle_to_moving first idle then moving
                accept ControlCommand;
            transition moving_to_holding first moving then holding;
            transition any_to_fault first idle then faulted
                accept SafetyEvent;
            transition moving_to_fault first moving then faulted
                accept SafetyEvent;
            transition holding_to_moving first holding then moving
                accept ControlCommand;
        }
    }

    part def EyeMechanism {
        part panServo : ServoActuator {
            attribute jointName = "EyePan";
            attribute maxTorque = 0.9;
            attribute rangeMin = -45.0;
            attribute rangeMax = 45.0;
        }

        part tiltServo : ServoActuator {
            attribute jointName = "EyeTilt";
            attribute maxTorque = 0.7;
            attribute rangeMin = -30.0;
            attribute rangeMax = 30.0;
        }

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port feedbackOut : FeedbackOutPort;
        port safetyOut : SafetyOutPort;
    }

    part def JawMechanism {
        part jawServo : ServoActuator {
            attribute jointName = "JawOpen";
            attribute maxTorque = 2.4;
            attribute rangeMin = 0.0;
            attribute rangeMax = 38.0;
        }

        attribute biteForceLimit : ForceN = 12.0;

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port feedbackOut : FeedbackOutPort;
        port safetyOut : SafetyOutPort;
    }

    part def NeckMechanism {
        part yawServo : ServoActuator {
            attribute jointName = "NeckYaw";
            attribute maxTorque = 5.0;
            attribute rangeMin = -70.0;
            attribute rangeMax = 70.0;
        }

        part pitchServo : ServoActuator {
            attribute jointName = "NeckPitch";
            attribute maxTorque = 4.2;
            attribute rangeMin = -25.0;
            attribute rangeMax = 35.0;
        }

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port feedbackOut : FeedbackOutPort;
        port safetyOut : SafetyOutPort;
    }

    part def AudioSubsystem {
        attribute maxSoundLevel : AudioLevelDb = 82.0;
        attribute nominalLatency : TimeMs = 35.0;

        port audioOut : AudioOutPort;
        port powerIn : PowerInPort;
        port safetyIn : SafetyInPort;

        action def PlayPhrase {
            in phraseId : String;
            in level : AudioLevelDb;
        }
    }

    part def LightingSubsystem {
        attribute maxIntensity : Percent = 100.0;

        port lightingIn : LightingInPort;
        port powerIn : PowerInPort;
        port safetyIn : SafetyInPort;

        action def SetExpressionLighting {
            in red : Percent;
            in green : Percent;
            in blue : Percent;
            in intensity : Percent;
        }
    }

    part def SensorSubsystem {
        attribute proximityRangeM : Real = 2.5;
        attribute touchThreshold : ForceN = 3.0;
        attribute microphoneThreshold : AudioLevelDb = 48.0;

        port safetyOut : SafetyOutPort;
        port feedbackOut : FeedbackOutPort;
        port powerIn : PowerInPort;

        action def DetectAudiencePresence {
            out audiencePresent : Boolean;
        }

        action def DetectUnsafeContact {
            out unsafeContact : Boolean;
        }
    }

    part def MotionController {
        attribute controlCycle : TimeMs = 10.0;
        attribute maxCommandAge : TimeMs = 100.0;

        port commandOut : CommandOutPort;
        port feedbackIn : FeedbackInPort;
        port safetyIn : SafetyInPort;
        port lightingOut : LightingOutPort;
        port audioOut : AudioOutPort;

        action def GeneratePerformancePose {
            in sceneName : String;
            out eyePan : AngleDeg;
            out eyeTilt : AngleDeg;
            out jawOpen : AngleDeg;
            out neckYaw : AngleDeg;
            out neckPitch : AngleDeg;
        }

        action def SynchronizeSpeechAndJaw {
            in phraseId : String;
            out jawCommand : ControlCommand;
            out audioSignal : AudioSignal;
        }

        state def ControllerMode {
            state startup;
            state idle;
            state performing;
            state interactive;
            state safeStop;
            state shutdown;

            transition first startup;
            transition startup_to_idle first startup then idle;
            transition idle_to_performing first idle then performing accept ControlCommand;
            transition performing_to_interactive first performing then interactive accept ControlCommand;
            transition interactive_to_idle first interactive then idle;
            transition any_to_safeStop first performing then safeStop accept SafetyEvent;
            transition idle_to_shutdown first idle then shutdown;
        }
    }

    part def PowerDistributionUnit {
        attribute inputVoltage : VoltageV = 24.0;
        attribute maxCurrent : CurrentA = 20.0;
        attribute logicVoltage : VoltageV = 5.0;
        attribute actuatorVoltage : VoltageV = 24.0;

        port mainPowerIn : PowerInPort;
        port actuatorPowerOut : PowerOutPort;
        port logicPowerOut : PowerOutPort;
        port audioPowerOut : PowerOutPort;
        port lightingPowerOut : PowerOutPort;
        port safetyIn : SafetyInPort;
    }

    part def SafetyController {
        attribute maxServoTemperature : TemperatureC = 70.0;
        attribute maxAllowedTorque : TorqueNm = 5.5;
        attribute emergencyStopLatency : TimeMs = 50.0;

        port feedbackIn : FeedbackInPort;
        port sensorSafetyIn : SafetyInPort;
        port safetyOut : SafetyOutPort;

        action def EvaluateSafety {
            in feedback : MotionFeedback;
            out event : SafetyEvent;
        }

        action def CommandEmergencyStop {
            out event : SafetyEvent;
        }
    }

    part def AnimatronicFigure {
        doc /* Primary function: perform lifelike character motion, synchronized speech, facial expression, lighting, and safe audience interaction for entertainment or themed experiences. */

        attribute figureName : String = "Interactive Character Animatronic";
        attribute nominalOperatingVoltage : VoltageV = 24.0;
        attribute peakPower : PowerW = 480.0;
        attribute maximumAudienceDistance : Real = 2.5;

        port externalPower : PowerInPort;
        port externalShowCommand : CommandInPort;
        port externalAudio : AudioOutPort;
        port externalSafety : SafetyOutPort;

        part powerUnit : PowerDistributionUnit;
        part controller : MotionController;
        part safetyController : SafetyController;
        part sensors : SensorSubsystem;
        part eyes : EyeMechanism;
        part jaw : JawMechanism;
        part neck : NeckMechanism;
        part audio : AudioSubsystem;
        part lighting : LightingSubsystem;

        connect externalPower to powerUnit.mainPowerIn;
        connect powerUnit.actuatorPowerOut to eyes.powerIn;
        connect powerUnit.actuatorPowerOut to jaw.powerIn;
        connect powerUnit.actuatorPowerOut to neck.powerIn;
        connect powerUnit.logicPowerOut to controller.feedbackIn;
        connect powerUnit.logicPowerOut to sensors.powerIn;
        connect powerUnit.audioPowerOut to audio.powerIn;
        connect powerUnit.lightingPowerOut to lighting.powerIn;

        connect externalShowCommand to controller.feedbackIn;
        connect controller.commandOut to eyes.commandIn;
        connect controller.commandOut to jaw.commandIn;
        connect controller.commandOut to neck.commandIn;
        connect controller.audioOut to audio.audioOut;
        connect controller.lightingOut to lighting.lightingIn;

        connect eyes.feedbackOut to safetyController.feedbackIn;
        connect jaw.feedbackOut to safetyController.feedbackIn;
        connect neck.feedbackOut to safetyController.feedbackIn;
        connect sensors.feedbackOut to safetyController.feedbackIn;
        connect sensors.safetyOut to safetyController.sensorSafetyIn;

        connect safetyController.safetyOut to controller.safetyIn;
        connect safetyController.safetyOut to powerUnit.safetyIn;
        connect safetyController.safetyOut to audio.safetyIn;
        connect safetyController.safetyOut to lighting.safetyIn;
        connect safetyController.safetyOut to externalSafety;

        connect audio.audioOut to externalAudio;

        action def PerformScene {
            in sceneName : String;
            in phraseId : String;
            out completed : Boolean;

            first start;
            then generatePose;
            then synchronizeSpeech;
            then commandMotion;
            then playAudio;
            then updateLighting;
            then monitorSafety;
            then done;

            action generatePose : MotionController::GeneratePerformancePose;
            action synchronizeSpeech : MotionController::SynchronizeSpeechAndJaw;
            action commandMotion : ServoActuator::MoveToTarget;
            action playAudio : AudioSubsystem::PlayPhrase;
            action updateLighting : LightingSubsystem::SetExpressionLighting;
            action monitorSafety : SafetyController::EvaluateSafety;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The animatronic figure shall provide a high-level entertainment function by producing coordinated lifelike movement, synchronized voice playback, expressive lighting, and safe interaction with nearby audience members. */
        subject figure : AnimatronicFigure;
        require constraint {
            figure.peakPower <= 480.0
        }
    }

    requirement def MotionCoordinationRequirement {
        doc /* The controller shall coordinate eyes, jaw, and neck motion so commanded character poses are executed within the control cycle. */
        subject controller : MotionController;
        require constraint {
            controller.controlCycle <= 10.0
        }
    }

    requirement def SpeechSynchronizationRequirement {
        doc /* Jaw motion shall be synchronized with phrase playback with nominal latency not greater than 50 ms. */
        subject audio : AudioSubsystem;
        require constraint {
            audio.nominalLatency <= 50.0
        }
    }

    requirement def AudienceSafetyRequirement {
        doc /* The system shall transition to safe stop when unsafe contact, excessive torque, or excessive actuator temperature is detected. */
        subject safety : SafetyController;
        require constraint {
            safety.emergencyStopLatency <= 50.0
        }
    }

    requirement def SoundLevelRequirement {
        doc /* The audio subsystem shall limit playback level to protect nearby audience members. */
        subject audio : AudioSubsystem;
        require constraint {
            audio.maxSoundLevel <= 82.0
        }
    }

    requirement def ActuatorThermalRequirement {
        doc /* Servo actuator winding temperature shall remain below the safety shutdown threshold during normal performance. */
        subject safety : SafetyController;
        require constraint {
            safety.maxServoTemperature <= 70.0
        }
    }

    satisfy PrimaryFunctionRequirement by AnimatronicFigure;
    satisfy MotionCoordinationRequirement by MotionController;
    satisfy SpeechSynchronizationRequirement by AudioSubsystem;
    satisfy AudienceSafetyRequirement by SafetyController;
    satisfy SoundLevelRequirement by AudioSubsystem;
    satisfy ActuatorThermalRequirement by SafetyController;

}