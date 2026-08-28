package AudioAnimatronicsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def Angle :> ISQ::Angle;
    attribute def Torque :> ISQ::Torque;
    attribute def Voltage :> ISQ::ElectricPotential;
    attribute def Duration :> ISQ::Duration;

    item def MotionCommand {
        attribute jointID : String;
        attribute targetAngle : Angle;
        attribute executionTime : Duration;
    }

    item def SensorFeedback {
        attribute jointID : String;
        attribute currentAngle : Angle;
        attribute currentTorque : Torque;
    }

    item def ControlVoltage {
        attribute voltage : Voltage;
    }

    item def AudioData {
        attribute sampleRate : Real [SI::hertz];
        attribute duration : Duration;
    }

    item def ShowProgram {
        attribute programName : String;
        attribute audioTrack : AudioData;
        attribute motionCommands : MotionCommand[*];
    }

    item def StartCommand;
    item def ShowComplete;
    item def ResetCommand;
    item def SafetyAlert {
        attribute jointID : String;
        attribute reason : String;
    }

    port def MotionCommandPort {
        out motionCommand : MotionCommand;
    }

    port def FeedbackPort {
        out sensorFeedback : SensorFeedback;
    }

    port def ControlVoltagePort {
        out controlVoltage : ControlVoltage;
    }

    port def AudioPort {
        out audioData : AudioData;
    }

    port def ShowProgramPort {
        in showProgram : ShowProgram;
        in startCommand : StartCommand;
        in showComplete : ShowComplete;
        in resetCommand : ResetCommand;
    }

    port def SafetyPort {
        in safetyAlert : SafetyAlert;
    }

    action def moveToTarget;
    action def translateCommand;
    action def processFeedback;
    action def playAudio;
    action def loadShowProgram;
    action def runShow;
    action def haltAll;

    part def ServoActuator {
        attribute currentAngle : Angle;
        attribute currentTorque : Torque;
        port controlIn : ControlVoltagePort;
        port feedbackOut : FeedbackPort;
        perform action moveToTarget;
    }

    part def Joint {
        attribute jointName : String;
        part actuator : ServoActuator;
        port controlIn : ControlVoltagePort;
        port feedbackOut : FeedbackPort;
        connect controlIn to actuator.controlIn;
        connect actuator.feedbackOut to feedbackOut;
    }

    part def HeadPanJoint :> Joint;
    part def HeadTiltJoint :> Joint;
    part def JawJoint :> Joint;
    part def TorsoRotateJoint :> Joint;
    part def LeftShoulderPitchJoint :> Joint;
    part def RightShoulderPitchJoint :> Joint;

    part def MotionController {
        attribute jointID : String;
        attribute maxTorque : Torque = 10 [SI::newton * SI::metre];
        attribute tolerance : Angle = 0.0174533 [SI::radian];
        attribute targetAngle : Angle;
        port commandIn : MotionCommandPort;
        port controlOut : ControlVoltagePort;
        port feedbackIn : FeedbackPort;
        port safetyOut : SafetyPort;
        perform action translateCommand;
        perform action processFeedback;
        exhibit state controllerStates {
            entry; then idle;
            state idle;
            transition
                first idle
                accept cmd : MotionCommand via commandIn
                do action translateCommand
                then moving;
            state moving;
            transition
                first moving
                accept feedback : SensorFeedback via feedbackIn
                if feedback.currentAngle == targetAngle
                then idle;
            transition
                first moving
                accept feedback : SensorFeedback via feedbackIn
                if feedback.currentTorque > maxTorque
                do send new SafetyAlert(jointID, "excessive torque") via safetyOut
                then error;
            state error;
            transition
                first error
                accept ResetCommand
                then idle;
        }
    }

    part def AudioPlaybackUnit {
        port audioIn : AudioPort;
        perform action playAudio;
    }

    state def ShowSequencerStates {
        entry; then standby;
        state standby;
        transition
            first standby
            accept show : ShowProgram via programPort
            do action loadShowProgram
            then ready;
        state ready;
        transition
            first ready
            accept StartCommand via programPort
            then performing;
        state performing;
        transition
            first performing
            accept alert : SafetyAlert via safetyIn
            then safeModeHalt;
        transition
            first performing
            accept ShowComplete via programPort
            then ready;
        state safeModeHalt {
            do action haltAll;
        }
        transition
            first safeModeHalt
            accept ResetCommand via programPort
            then standby;
    }

    part def ShowSequencer {
        attribute currentShow : ShowProgram;
        port programPort : ShowProgramPort;
        port audioOut : AudioPort;
        port headPanCmd : MotionCommandPort;
        port headTiltCmd : MotionCommandPort;
        port jawCmd : MotionCommandPort;
        port torsoRotateCmd : MotionCommandPort;
        port leftShoulderPitchCmd : MotionCommandPort;
        port rightShoulderPitchCmd : MotionCommandPort;
        port safetyIn : SafetyPort;
        exhibit state sequencerStates : ShowSequencerStates;
    }

    part def AnimatronicCharacter {
        part headPan : HeadPanJoint { attribute redefines jointName = "headPan"; }
        part headTilt : HeadTiltJoint { attribute redefines jointName = "headTilt"; }
        part jaw : JawJoint { attribute redefines jointName = "jaw"; }
        part torsoRotate : TorsoRotateJoint { attribute redefines jointName = "torsoRotate"; }
        part leftShoulderPitch : LeftShoulderPitchJoint { attribute redefines jointName = "leftShoulderPitch"; }
        part rightShoulderPitch : RightShoulderPitchJoint { attribute redefines jointName = "rightShoulderPitch"; }

        part headPanCtrl : MotionController { attribute redefines jointID = "headPan"; }
        part headTiltCtrl : MotionController { attribute redefines jointID = "headTilt"; }
        part jawCtrl : MotionController { attribute redefines jointID = "jaw"; }
        part torsoRotateCtrl : MotionController { attribute redefines jointID = "torsoRotate"; }
        part leftShoulderPitchCtrl : MotionController { attribute redefines jointID = "leftShoulderPitch"; }
        part rightShoulderPitchCtrl : MotionController { attribute redefines jointID = "rightShoulderPitch"; }

        connect headPanCtrl.controlOut to headPan.controlIn;
        connect headPan.feedbackOut to headPanCtrl.feedbackIn;
        connect headTiltCtrl.controlOut to headTilt.controlIn;
        connect headTilt.feedbackOut to headTiltCtrl.feedbackIn;
        connect jawCtrl.controlOut to jaw.controlIn;
        connect jaw.feedbackOut to jawCtrl.feedbackIn;
        connect torsoRotateCtrl.controlOut to torsoRotate.controlIn;
        connect torsoRotate.feedbackOut to torsoRotateCtrl.feedbackIn;
        connect leftShoulderPitchCtrl.controlOut to leftShoulderPitch.controlIn;
        connect leftShoulderPitch.feedbackOut to leftShoulderPitchCtrl.feedbackIn;
        connect rightShoulderPitchCtrl.controlOut to rightShoulderPitch.controlIn;
        connect rightShoulderPitch.feedbackOut to rightShoulderPitchCtrl.feedbackIn;
    }

    part def AudioAnimatronicsSystemAssembly {
        part sequencer : ShowSequencer;
        part character : AnimatronicCharacter;
        part audioUnit : AudioPlaybackUnit;

        connect sequencer.audioOut to audioUnit.audioIn;
        connect sequencer.headPanCmd to character.headPanCtrl.commandIn;
        connect sequencer.headTiltCmd to character.headTiltCtrl.commandIn;
        connect sequencer.jawCmd to character.jawCtrl.commandIn;
        connect sequencer.torsoRotateCmd to character.torsoRotateCtrl.commandIn;
        connect sequencer.leftShoulderPitchCmd to character.leftShoulderPitchCtrl.commandIn;
        connect sequencer.rightShoulderPitchCmd to character.rightShoulderPitchCtrl.commandIn;

        connect character.headPanCtrl.safetyOut to sequencer.safetyIn;
        connect character.headTiltCtrl.safetyOut to sequencer.safetyIn;
        connect character.jawCtrl.safetyOut to sequencer.safetyIn;
        connect character.torsoRotateCtrl.safetyOut to sequencer.safetyIn;
        connect character.leftShoulderPitchCtrl.safetyOut to sequencer.safetyIn;
        connect character.rightShoulderPitchCtrl.safetyOut to sequencer.safetyIn;
    }

    requirement def SynchronizationRequirement {
        doc /* Audio and motion commands shall be synchronized within 50 ms tolerance. */;
        attribute maxSyncError : Duration = 0.05 [SI::second];
    }

    requirement def SafetyHaltRequirement {
        doc /* System shall enter safeModeHalt within 100 ms of detecting excessive torque or position error. */;
        attribute maxResponseTime : Duration = 0.1 [SI::second];
        attribute torqueLimit : Torque = 15 [SI::newton * SI::metre];
        attribute positionErrorLimit : Angle = 0.0872665 [SI::radian];
    }

    requirement def ShowCompletionRequirement {
        doc /* System shall return to ready state upon receiving ShowComplete signal after a performance. */;
    }

    part systemAssembly : AudioAnimatronicsSystemAssembly {
        satisfy SynchronizationRequirement by sequencer;
        satisfy SafetyHaltRequirement by sequencer;
        satisfy ShowCompletionRequirement by sequencer;
    }
}
