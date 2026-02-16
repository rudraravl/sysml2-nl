package 'Audio-Animatronics System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ShowCommand {
        attribute commandType : String;
        attribute timestamp : DurationValue;
    }
    
    attribute def MotionFrame {
        attribute frameTime : DurationValue;
        attribute jointID : String;
        attribute targetAngle : PlaneAngleValue;
        attribute targetVelocity : AngularVelocityValue;
    }
    
    attribute def AudioTrack {
        attribute trackName : String;
        attribute duration : DurationValue;
        attribute sampleRate : FrequencyValue;
    }
    
    attribute def ShowProgram {
        attribute programName : String;
        attribute totalDuration : DurationValue;
        attribute audioData : AudioTrack;
        attribute motionData : MotionFrame[*] ordered;
    }
    
    attribute def JointState {
        attribute currentAngle : PlaneAngleValue;
        attribute currentVelocity : AngularVelocityValue;
        attribute currentTorque : TorqueValue;
    }
    
    attribute def ControlVoltage :> ElectricPotentialValue;
    
    item def SensorFeedback {
        attribute position : JointState;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute loadDetected : Boolean;
    }
    
    port def MotionControlPort {
        in targetPosition : MotionFrame;
        out currentState : JointState;
    }
    
    port def AudioOutputPort {
        out audioSignal : AudioTrack;
        out volume : Real;
    }
    
    port def ShowControlPort {
        in showCmd : ShowCommand;
        out status : String;
    }
    
    part def ServoActuator {
        attribute maxTorque : TorqueValue;
        attribute positionTolerance : PlaneAngleValue;
        
        port controlInput {
            in voltage : ControlVoltage;
            in targetAngle : PlaneAngleValue;
        }
        
        port feedbackOutput {
            out currentAngle : PlaneAngleValue;
            out motorTorque : TorqueValue;
        }
    }
    
    part def ArticulatedJoint {
        attribute jointName : String;
        attribute minAngle : PlaneAngleValue;
        attribute maxAngle : PlaneAngleValue;
        
        port motorPort : MotionControlPort;
        
        part actuator : ServoActuator {
            attribute :>> maxTorque = 50.0 [SI::N*SI::m];
            attribute :>> positionTolerance = 0.5 [SI::'°'];
        }
        
        connect actuator.feedbackOutput to motorPort;
    }
    
    part def MotionController {
        attribute controllerID : String;
        
        port commandInput {
            in motionCmd : MotionFrame;
        }
        
        port actuatorOutput {
            out controlSignal : ControlVoltage;
        }
        
        port sensorInput {
            in feedback : SensorFeedback;
        }
    }
    
    part def AudioPlaybackUnit {
        attribute channelCount : Integer;
        attribute maxOutputPower : PowerValue;
        
        port audioInput {
            in track : AudioTrack;
            in playbackCmd : String;
        }
        
        port speakerOutput {
            out audioSignal : AudioTrack;
            out outputLevel : Real;
        }
    }
    
    part def ShowSequencer {
        attribute activeProgram : ShowProgram;
        attribute playbackTime : DurationValue;
        attribute isRunning : Boolean;
        
        port programInput {
            in program : ShowProgram;
            in controlCmd : ShowCommand;
        }
        
        port motionOutput {
            out motionCommands : MotionFrame[*];
        }
        
        port audioOutput {
            out audioCommands : AudioTrack;
        }
        
        port statusOutput {
            out currentStatus : String;
            out elapsedTime : DurationValue;
        }
    }
    
    part def AnimatronicCharacter {
        attribute characterName : String;
        attribute totalJoints : Integer;
        
        part headPan : ArticulatedJoint {
            attribute :>> jointName = "head_pan";
            attribute :>> minAngle = -90.0 [SI::'°'];
            attribute :>> maxAngle = 90.0 [SI::'°'];
        }
        
        part headTilt : ArticulatedJoint {
            attribute :>> jointName = "head_tilt";
            attribute :>> minAngle = -45.0 [SI::'°'];
            attribute :>> maxAngle = 45.0 [SI::'°'];
        }
        
        part jawOpen : ArticulatedJoint {
            attribute :>> jointName = "jaw_open";
            attribute :>> minAngle = 0.0 [SI::'°'];
            attribute :>> maxAngle = 30.0 [SI::'°'];
        }
        
        part leftShoulderPitch : ArticulatedJoint {
            attribute :>> jointName = "left_shoulder_pitch";
            attribute :>> minAngle = -90.0 [SI::'°'];
            attribute :>> maxAngle = 180.0 [SI::'°'];
        }
        
        part rightShoulderPitch : ArticulatedJoint {
            attribute :>> jointName = "right_shoulder_pitch";
            attribute :>> minAngle = -90.0 [SI::'°'];
            attribute :>> maxAngle = 180.0 [SI::'°'];
        }
        
        part torsoRotate : ArticulatedJoint {
            attribute :>> jointName = "torso_rotate";
            attribute :>> minAngle = -45.0 [SI::'°'];
            attribute :>> maxAngle = 45.0 [SI::'°'];
        }
        
        part headPanController : MotionController {
            attribute :>> controllerID = "ctrl_head_pan";
        }
        
        part headTiltController : MotionController {
            attribute :>> controllerID = "ctrl_head_tilt";
        }
        
        part jawController : MotionController {
            attribute :>> controllerID = "ctrl_jaw";
        }
        
        part leftArmController : MotionController {
            attribute :>> controllerID = "ctrl_left_arm";
        }
        
        part rightArmController : MotionController {
            attribute :>> controllerID = "ctrl_right_arm";
        }
        
        part torsoController : MotionController {
            attribute :>> controllerID = "ctrl_torso";
        }
        
        connect headPanController.actuatorOutput to headPan.actuator.controlInput;
        connect headPan.actuator.feedbackOutput to headPanController.sensorInput;
        
        connect headTiltController.actuatorOutput to headTilt.actuator.controlInput;
        connect headTilt.actuator.feedbackOutput to headTiltController.sensorInput;
        
        connect jawController.actuatorOutput to jawOpen.actuator.controlInput;
        connect jawOpen.actuator.feedbackOutput to jawController.sensorInput;
        
        connect leftArmController.actuatorOutput to leftShoulderPitch.actuator.controlInput;
        connect leftShoulderPitch.actuator.feedbackOutput to leftArmController.sensorInput;
        
        connect rightArmController.actuatorOutput to rightShoulderPitch.actuator.controlInput;
        connect rightShoulderPitch.actuator.feedbackOutput to rightArmController.sensorInput;
        
        connect torsoController.actuatorOutput to torsoRotate.actuator.controlInput;
        connect torsoRotate.actuator.feedbackOutput to torsoController.sensorInput;
    }
    
    action def LoadShowProgram {
        in programFile : String;
        out loadedProgram : ShowProgram;
    }
    
    action def SynchronizeAudioMotion {
        in currentTime : DurationValue;
        in audioTrack : AudioTrack;
        in motionFrames : MotionFrame[*];
        out syncedMotion : MotionFrame[*];
        out syncedAudio : AudioTrack;
    }
    
    action def ExecuteJointMotion {
        in targetFrame : MotionFrame;
        in currentState : JointState;
        out controlOutput : ControlVoltage;
    }
    
    action def MonitorPerformance {
        in sensorData : SensorFeedback[*];
        out healthStatus : String;
        out safetyOK : Boolean;
    }
    
    action def PerformShow {
        in showProgram : ShowProgram;
        
        first start;
        then action loadProgram : LoadShowProgram {
            in programFile : String;
            out loadedProgram : ShowProgram;
        }
        then action initializeSystems {
            out audioReady : Boolean;
            out motorsReady : Boolean;
            out controllersReady : Boolean;
        }
        then decide;
            if initializeSystems.audioReady then checkMotors;
            else abortShow;
        
        action checkMotors;
        then decide;
            if initializeSystems.motorsReady then beginPerformance;
            else abortShow;
        
        action beginPerformance {
            first merge performanceLoop;
            then action syncSystems : SynchronizeAudioMotion {
                in currentTime : DurationValue;
                in audioTrack : AudioTrack;
                in motionFrames : MotionFrame[*];
                out syncedMotion : MotionFrame[*];
                out syncedAudio : AudioTrack;
            }
            then action executeMotions {
                for frame in syncSystems.syncedMotion {
                    action driveJoint : ExecuteJointMotion {
                        in targetFrame = frame;
                        in currentState : JointState;
                        out controlOutput : ControlVoltage;
                    }
                    then action checkSafety : MonitorPerformance {
                        in sensorData : SensorFeedback[*];
                        out healthStatus : String;
                        out safetyOK : Boolean;
                    }
                    then decide;
                        if checkSafety.safetyOK then continueMotion;
                        else emergencyStop;
                    
                    action continueMotion;
                    then performanceLoop;
                    
                    action emergencyStop {
                        out stopSignal : Boolean;
                    }
                    then abortShow;
                }
            }
            then decide;
                if loadProgram.loadedProgram.totalDuration > 0.0 [SI::s] then performanceLoop;
                else completeShow;
            
            action completeShow;
            then done;
        }
        
        action abortShow;
        then done;
    }
    
    state def AnimatronicOperationalStates {
        entry; then standby;
        
        state standby {
            entry assign systemPowered = true;
            entry assign motorsEnabled = false;
        }
        then transition loadShow
            accept ShowProgram
            do assign programLoaded = true
            then ready;
        
        state ready {
            entry assign motorsEnabled = true;
            entry assign controllersActive = true;
        }
        then transition startPerformance
            accept ShowCommand
            do assign performanceActive = true
            then performing;
        
        state performing {
            entry assign audioPlaying = true;
            entry assign motorsMoving = true;
            do action executeShow;
        }
        then transition showComplete
            when performanceActive == false
            then standby;
        
        transition safetyTriggered
            accept SensorFeedback
            from performing
            then safeModeHalt;
        
        state safeModeHalt {
            entry assign motorsEnabled = false;
            entry assign audioPlaying = false;
        }
        then transition resetSystem
            accept ShowCommand
            then standby;
    }
    
    part audioAnimatronicsSystem {
        attribute systemName : String = "Main Audio-Animatronics System";
        
        part character : AnimatronicCharacter {
            attribute :>> characterName = "Primary Character";
            attribute :>> totalJoints = 6;
        }
        
        part sequencer : ShowSequencer {
            attribute :>> playbackTime = 0.0 [SI::s];
            attribute :>> isRunning = false;
        }
        
        part audioSystem : AudioPlaybackUnit {
            attribute :>> channelCount = 2;
            attribute :>> maxOutputPower = 100.0 [SI::W];
        }
        
        port systemControl : ShowControlPort;
        
        connect sequencer.programInput to systemControl;
        connect sequencer.audioOutput to audioSystem.audioInput;
        connect sequencer.motionOutput to character.headPanController.commandInput;
        connect sequencer.motionOutput to character.headTiltController.commandInput;
        connect sequencer.motionOutput to character.jawController.commandInput;
        connect sequencer.motionOutput to character.leftArmController.commandInput;
        connect sequencer.motionOutput to character.rightArmController.commandInput;
        connect sequencer.motionOutput to character.torsoController.commandInput;
        
        perform action mainPerformance : PerformShow {
            in showProgram : ShowProgram;
        }
    }
    
    requirement def SynchronizationRequirement {
        doc /* Audio and motion shall be synchronized within acceptable tolerance. */
        
        attribute maxSyncError : DurationValue = 50.0 [SI::ms];
        
        require constraint audioMotionTiming {
            doc /* Time difference between audio events and motion commands shall not exceed maxSyncError. */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* System shall operate within safe mechanical and electrical limits. */
        
        require constraint jointLimits {
            doc /* All joint positions must remain within defined min/max angles. */
        }
        
        require constraint torqueLimits {
            doc /* Actuator torques shall not exceed rated maximum values. */
        }
        
        require constraint emergencyStop {
            doc /* System shall halt all motion within 100ms upon safety trigger. */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* System shall deliver reliable and repeatable performances. */
        
        attribute minReliability : Real = 0.995;
        
        require constraint showCompletionRate {
            doc /* At least 99.5% of initiated shows shall complete without errors. */
        }
        
        require constraint positionAccuracy {
            doc /* Joint positioning accuracy shall be within 0.5 degrees of commanded position. */
        }
        
        require constraint repeatability {
            doc /* Motion sequences shall be repeatable within 1.0 degree across performances. */
        }
    }
    
    requirement <'AA-SYS-001'> primaryFunctionRequirement {
        doc /* The Audio-Animatronics system shall perform lifelike animated entertainment performances 
             by precisely synchronizing pre-programmed audio playback with coordinated multi-axis 
             mechanical motion across multiple articulated joints, creating the illusion of autonomous 
             character behavior and speech for immersive guest experiences in themed entertainment venues. */
        
        subject audioAnimatronicsSystem;
        
        assume constraint validShowData {
            doc /* A valid show program containing synchronized audio and motion data is provided. */
        }
        
        assume constraint powerAvailable {
            doc /* Adequate electrical power is available for all actuators and control systems. */
        }
        
        require SynchronizationRequirement;
        require SafetyRequirement;
        require PerformanceRequirement;
    }
}
