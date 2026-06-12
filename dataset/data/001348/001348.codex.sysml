package AudioAnimatronicSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent {
        value : Real;
    }

    attribute def Decibel {
        value : Real;
    }

    attribute def Degrees {
        value : Real;
    }

    attribute def Millimeter {
        value : Real;
    }

    attribute def Millisecond {
        value : Real;
    }

    attribute def NewtonMeter {
        value : Real;
    }

    item def AudioSignal {
        attribute level : Decibel;
        attribute sampleRate : Frequency;
        attribute channelCount : Integer;
    }

    item def MotionCommand {
        attribute targetJointId : String;
        attribute targetAngle : Degrees;
        attribute velocityLimit : AngularVelocity;
        attribute torqueLimit : NewtonMeter;
        attribute executionTime : Millisecond;
    }

    item def ExpressionCommand {
        attribute mouthOpenPercent : Percent;
        attribute eyePanAngle : Degrees;
        attribute eyeTiltAngle : Degrees;
        attribute browAngle : Degrees;
        attribute blinkRequested : Boolean;
    }

    item def SafetyStatus {
        attribute emergencyStopActive : Boolean;
        attribute enclosureOpen : Boolean;
        attribute overTorqueDetected : Boolean;
        attribute performerClearanceOk : Boolean;
    }

    item def ShowCue {
        attribute cueId : String;
        attribute startTime : Time;
        attribute duration : Time;
        attribute dialogueText : String;
        attribute emotionalTone : String;
    }

    port def AudioOutPort {
        out audio : AudioSignal;
    }

    port def AudioInPort {
        in audio : AudioSignal;
    }

    port def MotionCommandPort {
        out command : MotionCommand;
    }

    port def MotionReceivePort {
        in command : MotionCommand;
    }

    port def ExpressionCommandPort {
        out expression : ExpressionCommand;
    }

    port def ExpressionReceivePort {
        in expression : ExpressionCommand;
    }

    port def SafetyStatusOutPort {
        out status : SafetyStatus;
    }

    port def SafetyStatusInPort {
        in status : SafetyStatus;
    }

    port def CueInPort {
        in cue : ShowCue;
    }

    port def CueOutPort {
        out cue : ShowCue;
    }

    part def Speaker {
        attribute ratedPower : Power;
        attribute maxSoundPressureLevel : Decibel;
        attribute frequencyLowLimit : Frequency;
        attribute frequencyHighLimit : Frequency;

        port audioInput : AudioInPort;

        action playAudio {
            in signal : AudioSignal;
        }
    }

    part def ServoActuator {
        attribute jointId : String;
        attribute minAngle : Degrees;
        attribute maxAngle : Degrees;
        attribute maxTorque : NewtonMeter;
        attribute positionAccuracy : Degrees;
        attribute currentAngle : Degrees;
        attribute enabled : Boolean;

        port motionInput : MotionReceivePort;

        action moveToAngle {
            in command : MotionCommand;
            out achievedAngle : Degrees;
        }

        action holdPosition {
            in holdAngle : Degrees;
        }
    }

    part def FacialMechanism {
        attribute lipTravel : Millimeter;
        attribute eyelidTravel : Millimeter;
        attribute eyePanRange : Degrees;
        attribute eyeTiltRange : Degrees;

        port expressionInput : ExpressionReceivePort;

        part jawServo : ServoActuator {
            attribute jointId = "jaw";
            attribute minAngle = -5.0;
            attribute maxAngle = 38.0;
            attribute maxTorque = 8.0;
            attribute positionAccuracy = 0.5;
        }

        part leftEyePanServo : ServoActuator {
            attribute jointId = "leftEyePan";
            attribute minAngle = -25.0;
            attribute maxAngle = 25.0;
            attribute maxTorque = 2.0;
            attribute positionAccuracy = 0.3;
        }

        part rightEyePanServo : ServoActuator {
            attribute jointId = "rightEyePan";
            attribute minAngle = -25.0;
            attribute maxAngle = 25.0;
            attribute maxTorque = 2.0;
            attribute positionAccuracy = 0.3;
        }

        part eyelidServo : ServoActuator {
            attribute jointId = "eyelids";
            attribute minAngle = 0.0;
            attribute maxAngle = 45.0;
            attribute maxTorque = 3.0;
            attribute positionAccuracy = 0.5;
        }

        action applyExpression {
            in expression : ExpressionCommand;
        }
    }

    part def TorsoMechanism {
        attribute yawRange : Degrees;
        attribute pitchRange : Degrees;
        attribute gestureReach : Millimeter;

        port motionInput : MotionReceivePort;

        part neckYawServo : ServoActuator {
            attribute jointId = "neckYaw";
            attribute minAngle = -45.0;
            attribute maxAngle = 45.0;
            attribute maxTorque = 18.0;
            attribute positionAccuracy = 0.4;
        }

        part neckPitchServo : ServoActuator {
            attribute jointId = "neckPitch";
            attribute minAngle = -20.0;
            attribute maxAngle = 25.0;
            attribute maxTorque = 16.0;
            attribute positionAccuracy = 0.4;
        }

        part leftArmServo : ServoActuator {
            attribute jointId = "leftArm";
            attribute minAngle = -15.0;
            attribute maxAngle = 95.0;
            attribute maxTorque = 30.0;
            attribute positionAccuracy = 0.8;
        }

        part rightArmServo : ServoActuator {
            attribute jointId = "rightArm";
            attribute minAngle = -15.0;
            attribute maxAngle = 95.0;
            attribute maxTorque = 30.0;
            attribute positionAccuracy = 0.8;
        }

        action performGesture {
            in command : MotionCommand;
        }
    }

    part def ShowController {
        attribute controllerId : String;
        attribute controlLoopPeriod : Millisecond;
        attribute cueLatencyBudget : Millisecond;
        attribute audioMotionSyncTolerance : Millisecond;

        port cueInput : CueInPort;
        port audioOutput : AudioOutPort;
        port motionOutput : MotionCommandPort;
        port expressionOutput : ExpressionCommandPort;
        port safetyInput : SafetyStatusInPort;

        action interpretCue {
            in cue : ShowCue;
            out dialogueAudio : AudioSignal;
            out faceCommand : ExpressionCommand;
            out bodyCommand : MotionCommand;
        }

        action synchronizePerformance {
            in cue : ShowCue;
            in safety : SafetyStatus;
        }

        state machine controllerStateMachine {
            state idle;
            state armed;
            state performing;
            state paused;
            state safeShutdown;

            initial then idle;

            transition idle_to_armed
                first idle
                then armed;

            transition armed_to_performing
                first armed
                then performing;

            transition performing_to_paused
                first performing
                then paused;

            transition paused_to_performing
                first paused
                then performing;

            transition performing_to_safeShutdown
                first performing
                then safeShutdown;

            transition armed_to_safeShutdown
                first armed
                then safeShutdown;
        }
    }

    part def SafetySupervisor {
        attribute minimumHumanClearance : Millimeter;
        attribute maximumAllowedTorque : NewtonMeter;
        attribute emergencyStopResponseTime : Millisecond;

        port safetyOutput : SafetyStatusOutPort;

        action monitorHazards {
            out status : SafetyStatus;
        }

        action commandShutdown {
            in status : SafetyStatus;
        }

        state machine safetyStateMachine {
            state normal;
            state warning;
            state emergencyStop;

            initial then normal;

            transition normal_to_warning
                first normal
                then warning;

            transition warning_to_normal
                first warning
                then normal;

            transition warning_to_emergencyStop
                first warning
                then emergencyStop;

            transition normal_to_emergencyStop
                first normal
                then emergencyStop;
        }
    }

    part def CueScheduler {
        attribute showDuration : Time;
        attribute cueCount : Integer;
        attribute repeatEnabled : Boolean;

        port cueOutput : CueOutPort;

        action dispatchCue {
            out cue : ShowCue;
        }
    }

    part def AudioAnimatronicCharacter {
        attribute characterName : String;
        attribute installedHeight : Length;
        attribute mass : Mass;
        attribute primaryFunction : String;

        port cueInput : CueInPort;

        part scheduler : CueScheduler {
            attribute showDuration = 180.0;
            attribute cueCount = 42;
            attribute repeatEnabled = true;
        }

        part controller : ShowController {
            attribute controllerId = "AAC-MAIN-CTRL-01";
            attribute controlLoopPeriod = 10.0;
            attribute cueLatencyBudget = 35.0;
            attribute audioMotionSyncTolerance = 25.0;
        }

        part safetySupervisor : SafetySupervisor {
            attribute minimumHumanClearance = 750.0;
            attribute maximumAllowedTorque = 32.0;
            attribute emergencyStopResponseTime = 80.0;
        }

        part facialMechanism : FacialMechanism {
            attribute lipTravel = 22.0;
            attribute eyelidTravel = 12.0;
            attribute eyePanRange = 50.0;
            attribute eyeTiltRange = 30.0;
        }

        part torsoMechanism : TorsoMechanism {
            attribute yawRange = 90.0;
            attribute pitchRange = 45.0;
            attribute gestureReach = 620.0;
        }

        part leftSpeaker : Speaker {
            attribute ratedPower = 60.0;
            attribute maxSoundPressureLevel = 96.0;
            attribute frequencyLowLimit = 80.0;
            attribute frequencyHighLimit = 18000.0;
        }

        part rightSpeaker : Speaker {
            attribute ratedPower = 60.0;
            attribute maxSoundPressureLevel = 96.0;
            attribute frequencyLowLimit = 80.0;
            attribute frequencyHighLimit = 18000.0;
        }

        connection cueFlow connect scheduler.cueOutput to controller.cueInput;
        connection externalCueFlow connect cueInput to controller.cueInput;
        connection safetyFlow connect safetySupervisor.safetyOutput to controller.safetyInput;
        connection facialCommandFlow connect controller.expressionOutput to facialMechanism.expressionInput;
        connection torsoCommandFlow connect controller.motionOutput to torsoMechanism.motionInput;
        connection leftAudioFlow connect controller.audioOutput to leftSpeaker.audioInput;
        connection rightAudioFlow connect controller.audioOutput to rightSpeaker.audioInput;

        action performAnimatedDialogue {
            in cue : ShowCue;
            out status : SafetyStatus;

            first startCue;
            then evaluateSafety;
            then generateAudioAndMotion;
            then actuateCharacter;
            then completeCue;

            action startCue {
                in cue : ShowCue;
            }

            action evaluateSafety {
                out status : SafetyStatus;
            }

            action generateAudioAndMotion {
                in cue : ShowCue;
                out audio : AudioSignal;
                out expression : ExpressionCommand;
                out motion : MotionCommand;
            }

            action actuateCharacter {
                in audio : AudioSignal;
                in expression : ExpressionCommand;
                in motion : MotionCommand;
            }

            action completeCue;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Audio-Animatronic system shall deliver a synchronized character performance by playing scripted dialogue and coordinating facial expression, eye movement, head movement, and arm gestures to create the appearance of a lifelike performer. */
    }

    requirement def AudioMotionSynchronizationRequirement {
        doc /* The system shall maintain audio-to-motion synchronization within 25 milliseconds during all scripted dialogue cues. */
    }

    requirement def SafetyStopRequirement {
        doc /* The system shall transition to safe shutdown within 80 milliseconds when emergency stop, enclosure opening, over-torque, or unsafe performer clearance is detected. */
    }

    requirement def FacialExpressionRequirement {
        doc /* The system shall animate jaw, eyelids, and eyes during speech so that mouth opening and gaze direction correspond to the active show cue emotional tone. */
    }

    requirement def GestureRequirement {
        doc /* The system shall coordinate neck and arm motion commands to produce repeatable gestures without exceeding actuator angle or torque limits. */
    }

    requirement primaryFunctionReq : PrimaryFunctionRequirement;
    requirement syncReq : AudioMotionSynchronizationRequirement;
    requirement safetyReq : SafetyStopRequirement;
    requirement expressionReq : FacialExpressionRequirement;
    requirement gestureReq : GestureRequirement;

    part animatronicHost : AudioAnimatronicCharacter {
        attribute characterName = "Harbor Storyteller";
        attribute installedHeight = 2.1;
        attribute mass = 145.0;
        attribute primaryFunction = "Present scripted spoken performances with synchronized audio, expressive facial motion, and controlled body gestures for guest entertainment.";
    }

    satisfy primaryFunctionSatisfaction by animatronicHost for primaryFunctionReq;
    satisfy syncSatisfaction by animatronicHost.controller for syncReq;
    satisfy safetySatisfaction by animatronicHost.safetySupervisor for safetyReq;
    satisfy expressionSatisfaction by animatronicHost.facialMechanism for expressionReq;
    satisfy gestureSatisfaction by animatronicHost.torsoMechanism for gestureReq;

}