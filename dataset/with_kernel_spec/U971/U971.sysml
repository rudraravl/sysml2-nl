package AnimatronicCharacterSystem {
    private import ScalarValues::*;

    unit mm;
    unit deg;
    unit 'N*m';
    unit degC;

    attribute def DistanceValue :> Real { unit mm; }
    attribute def PositionValue :> Real { unit deg; }
    attribute def TorqueValue :> Real { unit 'N*m'; }
    attribute def TemperatureValue :> Real { unit degC; }

    attribute def ProximitySignal {
        distance : DistanceValue;
        sensorId : Integer;
    }

    attribute def ServoFeedback {
        currentPosition : PositionValue;
        currentTorque : TorqueValue;
        currentTemperature : TemperatureValue;
        jointId : String;
    }

    attribute def ServoCommand {
        targetPosition : PositionValue;
        maxTorque : TorqueValue;
        jointId : String;
    }

    attribute def AudioCommand {
        trackId : String;
        volume : Real;
    }

    attribute def AnimationCompleteSignal;
    attribute def NeutralReachedSignal;
    attribute def OverTempSignal;
    attribute def NormalTempSignal;

    port def ProximityOutputPort {
        out proximity : ProximitySignal;
    }

    port def ControllerProxInputPort {
        in leftProximity : ProximitySignal;
        in rightProximity : ProximitySignal;
    }

    port def ServoCommandOutputPort {
        out command : ServoCommand;
    }

    port def ServoCommandInputPort {
        in command : ServoCommand;
    }

    port def ServoFeedbackOutputPort {
        out feedback : ServoFeedback;
    }

    port def ServoFeedbackInputPort {
        in feedback : ServoFeedback;
    }

    port def AudioOutputPort {
        out audio : AudioCommand;
    }

    port def AudioInputPort {
        in audio : AudioCommand;
    }

    action def SelectAnimation {
        in leftDist : DistanceValue;
        in rightDist : DistanceValue;
        out animationId : String;
    }

    action def ExecuteAnimation;
    action def ReturnToNeutral;
    action def EmergencyStop;
    action def LowPowerWait;
    action def MonitorFeedback;
    action def PlayAudio {
        in cmd : AudioCommand;
    }
    action def DriveServo {
        in cmd : ServoCommand;
        out fb : ServoFeedback;
    }
    action def SenseDistance {
        out prox : ProximitySignal;
    }
    action def MonitorTemperature;
    action def TriggerCooling;

    part def ProximitySensor {
        port proxOut : ProximityOutputPort;
        perform action senseDistance : SenseDistance;
    }

    part def ServoActuator {
        port servoIn : ServoCommandInputPort;
        port servoOut : ServoFeedbackOutputPort;
        attribute maxTorque : TorqueValue = 5.0;
        attribute maxTemperature : TemperatureValue = 80.0;
        perform action driveServo : DriveServo;
    }

    part def SpeakerSystem {
        port audioIn : AudioInputPort;
        perform action playAudio : PlayAudio;
    }

    part def AnimationController {
        port proxPort : ControllerProxInputPort;
        port servoCmdPort : ServoCommandOutputPort;
        port feedbackPort : ServoFeedbackInputPort;
        port audioCmdPort : AudioOutputPort;

        attribute torqueLimit : TorqueValue = 5.0;
        attribute tempLimit : TemperatureValue = 80.0;
        attribute detectionRange : DistanceValue = 2000.0;

        state controllerStates parallel {
            state operationalCycle {
                entry; then standby;
                state standby {
                    do action lowPowerWait : LowPowerWait;
                }
                accept prox : ProximitySignal via proxPort
                    if prox.distance < detectionRange
                    do action selectAnimation : SelectAnimation {
                        in leftDist = prox.distance;
                        in rightDist = prox.distance;
                    }
                    then performing;
                state performing {
                    do action executeAnimation : ExecuteAnimation;
                    do action monitorFeedback : MonitorFeedback;
                }
                accept fb : ServoFeedback via feedbackPort
                    if fb.currentTorque > torqueLimit or fb.currentTemperature > tempLimit
                    do action emergencyStop : EmergencyStop
                    then returning;
                accept AnimationCompleteSignal
                    then returning;
                state returning {
                    do action returnToNeutral : ReturnToNeutral;
                }
                accept NeutralReachedSignal
                    then standby;
            }
            state healthMonitoring {
                entry; then normal;
                state normal {
                    do action monitorTemperature : MonitorTemperature;
                }
                accept OverTempSignal
                    then overheated;
                state overheated {
                    do action triggerCooling : TriggerCooling;
                }
                accept NormalTempSignal
                    then normal;
            }
        }
    }

    part def AnimatronicCharacter {
        part controller : AnimationController;
        part leftSensor : ProximitySensor;
        part rightSensor : ProximitySensor;
        part speaker : SpeakerSystem;
        part headServo : ServoActuator;
        part neckServo : ServoActuator;
        part leftShoulderServo : ServoActuator;
        part rightShoulderServo : ServoActuator;
        part leftElbowServo : ServoActuator;
        part rightElbowServo : ServoActuator;
        part jawServo : ServoActuator;
        part leftEyeServo : ServoActuator;
        part rightEyeServo : ServoActuator;

        flow leftProxFlow of ProximitySignal
            from leftSensor.proxOut.proximity to controller.proxPort.leftProximity;
        flow rightProxFlow of ProximitySignal
            from rightSensor.proxOut.proximity to controller.proxPort.rightProximity;

        flow headCmdFlow of ServoCommand
            from controller.servoCmdPort.command to headServo.servoIn.command;
        flow headFbFlow of ServoFeedback
            from headServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow neckCmdFlow of ServoCommand
            from controller.servoCmdPort.command to neckServo.servoIn.command;
        flow neckFbFlow of ServoFeedback
            from neckServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow leftShoulderCmdFlow of ServoCommand
            from controller.servoCmdPort.command to leftShoulderServo.servoIn.command;
        flow leftShoulderFbFlow of ServoFeedback
            from leftShoulderServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow rightShoulderCmdFlow of ServoCommand
            from controller.servoCmdPort.command to rightShoulderServo.servoIn.command;
        flow rightShoulderFbFlow of ServoFeedback
            from rightShoulderServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow leftElbowCmdFlow of ServoCommand
            from controller.servoCmdPort.command to leftElbowServo.servoIn.command;
        flow leftElbowFbFlow of ServoFeedback
            from leftElbowServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow rightElbowCmdFlow of ServoCommand
            from controller.servoCmdPort.command to rightElbowServo.servoIn.command;
        flow rightElbowFbFlow of ServoFeedback
            from rightElbowServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow jawCmdFlow of ServoCommand
            from controller.servoCmdPort.command to jawServo.servoIn.command;
        flow jawFbFlow of ServoFeedback
            from jawServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow leftEyeCmdFlow of ServoCommand
            from controller.servoCmdPort.command to leftEyeServo.servoIn.command;
        flow leftEyeFbFlow of ServoFeedback
            from leftEyeServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow rightEyeCmdFlow of ServoCommand
            from controller.servoCmdPort.command to rightEyeServo.servoIn.command;
        flow rightEyeFbFlow of ServoFeedback
            from rightEyeServo.servoOut.feedback to controller.feedbackPort.feedback;

        flow audioFlow of AudioCommand
            from controller.audioCmdPort.audio to speaker.audioIn.audio;
    }

    requirement def MaxTorqueLimit {
        doc /* The torque of any servo must not exceed 5 N*m to ensure safe operation. */
    }
    requirement def MaxTempLimit {
        doc /* The temperature of any servo must not exceed 80 degC. */
    }
    requirement def VisitorDetection {
        doc /* The system shall detect visitors within 2 meters using proximity sensors. */
    }
    requirement def LifelikeAnimation {
        doc /* The system shall execute pre-programmed animations with synchronized servo movements and audio playback. */
    }
    requirement def StandbyMode {
        doc /* The system shall enter a low-power standby mode when no visitors are detected and return to neutral position after each performance. */
    }
    requirement def LongTermOperation {
        doc /* The system must operate continuously for at least 12 hours without failure. */
    }
}
