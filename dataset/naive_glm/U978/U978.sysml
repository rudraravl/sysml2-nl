package AnimatronicsSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types with Units ----------
    attribute def Angle :> Real {
        doc /* Joint angle in degrees. */
    }
    attribute def Torque :> Real {
        doc /* Torque in newton-meters. */
    }
    attribute def Voltage :> Real {
        doc /* Control voltage in volts. */
    }
    attribute def Force :> Real {
        doc /* Force in newtons. */
    }
    attribute def TimeStamp :> Real {
        doc /* Time offset from show start in seconds. */
    }
    attribute def Frequency :> Real {
        doc /* Frequency in hertz. */
    }
    attribute def SoundPressure :> Real {
        doc /* Sound pressure level in decibels. */
    }

    // ---------- Item Types ----------
    item def JointCommand {
        attribute targetAngle : Angle;
        attribute maxTorque : Torque;
    }
    item def ActuatorFeedback {
        attribute currentAngle : Angle;
        attribute currentTorque : Torque;
    }
    item def MotionCue {
        attribute jointId : String;
        attribute time : TimeStamp;
        attribute command : JointCommand;
    }
    item def AudioFrame {
        attribute time : TimeStamp;
        attribute sampleData : String;
    }
    item def ShowProgram {
        attribute programId : String;
        attribute duration : TimeStamp;
        attribute motionCues : MotionCue[0..*] ordered;
        attribute audioFrames : AudioFrame[0..*] ordered;
    }
    item def AudioOutput {
        attribute level : SoundPressure;
    }
    item def SafetyAlert {
        attribute alertCode : String;
        attribute severity : Integer;
    }

    // ---------- Port Definitions ----------
    port def MotionCommandPort {
        out item commands : JointCommand;
        in item feedback : ActuatorFeedback;
    }
    port def ActuatorDrivePort {
        in item driveVoltage : Voltage;
        out item feedback : ActuatorFeedback;
    }
    port def AudioStreamPort {
        out item audioFrames : AudioFrame;
    }
    port def SpeakerPort {
        in item audio : AudioOutput;
    }
    port def ShowProgramPort {
        in item program : ShowProgram;
    }
    port def SafetyPort {
        out item alert : SafetyAlert;
    }

    // ---------- Servo Actuator ----------
    part def ServoActuator {
        port drivePort : ActuatorDrivePort;
        port safetyPort : SafetyPort;

        attribute currentAngle : Angle = 0;
        attribute currentTorque : Torque = 0;
        attribute maxSafeTorque : Torque = 12.0;
        attribute maxAngle : Angle = 180.0;
        attribute minAngle : Angle = -180.0;

        action def DriveActuator {
            in voltage : Voltage;
            out angle : Angle;
            out torque : Torque;
        }

        action def MonitorSafety {
            in angle : Angle;
            in torque : Torque;
            out alert : SafetyAlert;
        }

        state def ActuatorBehavior {
            entry; then Normal;
            state Normal;
            transition Normal to Fault
                when drivePort.feedback.currentTorque > maxSafeTorque
                or currentAngle > maxAngle
                or currentAngle < minAngle;
            state Fault {
                entry send SafetyAlert{alertCode = "ActuatorFault", severity = 1} to safetyPort;
            }
        }
    }

    // ---------- Motion Controller ----------
    part def MotionController {
        port commandPort : MotionCommandPort;
        port actuatorPort : ActuatorDrivePort;
        port safetyPort : SafetyPort;

        attribute jointId : String;
        attribute proportionalGain : Real = 1.0;
        attribute tolerance : Angle = 1.0;

        action def TranslateCommand {
            in command : JointCommand;
            in feedback : ActuatorFeedback;
            out voltage : Voltage;
        }

        action def VerifyPosition {
            in command : JointCommand;
            in feedback : ActuatorFeedback;
            out verified : Boolean;
        }

        state def ControllerBehavior {
            entry; then Idle;
            state Idle;
            transition Idle to Active
                when commandPort.commands.targetAngle != null;
            state Active {
                do TranslateCommand;
            }
            transition Active to Idle
                when VerifyPosition.verified == true;
            transition Active to Fault
                when actuatorPort.feedback.currentTorque > 12.0;
            state Fault {
                entry send SafetyAlert{alertCode = "ControllerFault", severity = 1} to safetyPort;
            }
        }
    }

    // ---------- Joint Assembly ----------
    part def JointAssembly {
        attribute jointName : String;
        attribute rangeMin : Angle;
        attribute rangeMax : Angle;
        part servo : ServoActuator;
        part controller : MotionController {
            attribute jointId = jointName;
        }
        connection servoActuation connect controller.actuatorPort to servo.drivePort;
    }

    // ---------- Audio Playback Unit ----------
    part def AudioPlaybackUnit {
        port audioIn : AudioStreamPort;
        port speakerOut : SpeakerPort;

        attribute sampleRate : Frequency = 44100.0;
        attribute outputLevel : SoundPressure = 80.0;

        action def DecodeAudio {
            in frame : AudioFrame;
            out output : AudioOutput;
        }

        state def AudioBehavior {
            entry; then Muted;
            state Muted;
            transition Muted to Playing
                when audioIn.audioFrames != null;
            state Playing {
                do DecodeAudio;
            }
            transition Playing to Muted
                when audioIn.audioFrames == null;
        }
    }

    // ---------- Show Sequencer ----------
    part def ShowSequencer {
        port programPort : ShowProgramPort;
        port audioOut : AudioStreamPort;
        port motionOut : MotionCommandPort[0..*];
        port safetyIn : SafetyPort[0..*];

        attribute loadedProgram : ShowProgram;
        attribute currentTime : TimeStamp = 0.0;
        attribute showActive : Boolean = false;

        action def LoadProgram {
            in program : ShowProgram;
            out ready : Boolean;
        }

        action def EmitCues {
            out motionCue : MotionCue;
            out audioFrame : AudioFrame;
        }

        action def EvaluateSafety {
            in alerts : SafetyAlert[0..*];
            out halt : Boolean;
        }

        state def SequencerBehavior {
            entry; then standby;
            state standby {
                entry;
                do LoadProgram;
            }
            transition standby to ready
                when programPort.program != null;
            state ready {
                entry;
            }
            transition ready to performing
                when showActive == true;
            state performing {
                do EmitCues;
            }
            transition performing to safeModeHalt
                when EvaluateSafety.halt == true;
            transition ready to safeModeHalt
                when EvaluateSafety.halt == true;
            transition standby to safeModeHalt
                when EvaluateSafety.halt == true;
            state safeModeHalt {
                entry;
                // Stop all motion and sound
            }
            transition safeModeHalt to standby
                when EvaluateSafety.halt == false;
        }
    }

    // ---------- Animatronic Character ----------
    part def AnimatronicCharacter {
        port motionCommandPorts : MotionCommandPort[0..*];
        port safetyPorts : SafetyPort[0..*];

        part headPan : JointAssembly {
            attribute jointName = "headPan";
            attribute rangeMin = -90.0;
            attribute rangeMax = 90.0;
        }
        part headTilt : JointAssembly {
            attribute jointName = "headTilt";
            attribute rangeMin = -45.0;
            attribute rangeMax = 45.0;
        }
        part jawOpen : JointAssembly {
            attribute jointName = "jawOpen";
            attribute rangeMin = 0.0;
            attribute rangeMax = 30.0;
        }
        part torsoRotate : JointAssembly {
            attribute jointName = "torsoRotate";
            attribute rangeMin = -60.0;
            attribute rangeMax = 60.0;
        }
        part leftShoulderPitch : JointAssembly {
            attribute jointName = "leftShoulderPitch";
            attribute rangeMin = -90.0;
            attribute rangeMax = 90.0;
        }
        part rightShoulderPitch : JointAssembly {
            attribute jointName = "rightShoulderPitch";
            attribute rangeMin = -90.0;
            attribute rangeMax = 90.0;
        }

        connection headPanCmd connect motionCommandPorts to headPan.controller.commandPort;
        connection headTiltCmd connect motionCommandPorts to headTilt.controller.commandPort;
        connection jawOpenCmd connect motionCommandPorts to jawOpen.controller.commandPort;
        connection torsoRotateCmd connect motionCommandPorts to torsoRotate.controller.commandPort;
        connection leftShoulderCmd connect motionCommandPorts to leftShoulderPitch.controller.commandPort;
        connection rightShoulderCmd connect motionCommandPorts to rightShoulderPitch.controller.commandPort;
    }

    // ---------- Top-level Audio-Animatronics System ----------
    part def AudioAnimatronicsSystem {
        part sequencer : ShowSequencer;
        part character : AnimatronicCharacter;
        part audioUnit : AudioPlaybackUnit;

        connection AudioStream connect sequencer.audioOut to audioUnit.audioIn;
        connection MotionCommands connect sequencer.motionOut to character.motionCommandPorts;
        connection SafetyFeedback connect character.safetyPorts to sequencer.safetyIn;

        // Aggregate safety from all actuators/controllers to sequencer
        connection HeadPanSafety connect character.headPan.servo.safetyPort to sequencer.safetyIn;
        connection HeadTiltSafety connect character.headTilt.servo.safetyPort to sequencer.safetyIn;
        connection JawOpenSafety connect character.jawOpen.servo.safetyPort to sequencer.safetyIn;
        connection TorsoRotateSafety connect character.torsoRotate.servo.safetyPort to sequencer.safetyIn;
        connection LeftShoulderSafety connect character.leftShoulderPitch.servo.safetyPort to sequencer.safetyIn;
        connection RightShoulderSafety connect character.rightShoulderPitch.servo.safetyPort to sequencer.safetyIn;
    }

    // ---------- Requirements ----------
    requirement def SynchronizedPerformance {
        doc /* The system shall synchronize physical movements with the audio track. */
        attribute maxSyncError : TimeStamp = 0.05;
        subject system : AudioAnimatronicsSystem;
        objective {
            /* Motion cues and audio frames emitted by the sequencer shall be within maxSyncError of each other in time. */
        }
    }

    requirement def JointRangeCompliance {
        doc /* Each joint shall operate within its defined mechanical range. */
        subject joint : JointAssembly;
        objective {
            /* joint.servo.currentAngle shall remain between joint.rangeMin and joint.rangeMax. */
        }
    }

    requirement def SafetyHalt {
        doc /* The system shall enter safeModeHalt upon detecting excessive force or out-of-position joints. */
        subject system : AudioAnimatronicsSystem;
        attribute maxResponseTime : TimeStamp = 0.1;
        objective {
            /* Upon any SafetyAlert with severity >= 1, the sequencer shall transition to safeModeHalt within maxResponseTime. */
        }
    }

    requirement def ShowProgramLoading {
        doc /* The sequencer shall load a ShowProgram containing audio and motion cues. */
        subject sequencer : ShowSequencer;
        objective {
            /* sequencer.loadedProgram shall contain at least one motionCue and one audioFrame. */
        }
    }

    requirement def ActuatorFeedback {
        doc /* Each servo actuator shall provide angle and torque feedback. */
        subject actuator : ServoActuator;
        objective {
            /* actuator.drivePort.feedback shall include currentAngle and currentTorque. */
        }
    }

    requirement def MotionControllerTranslation {
        doc /* Each motion controller shall translate joint commands into control voltages. */
        subject controller : MotionController;
        objective {
            /* controller.TranslateCommand shall produce a driveVoltage given a JointCommand and ActuatorFeedback. */
        }
    }

}
