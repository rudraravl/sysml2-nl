package daVinciSystem {
    import ScalarValues::*;
    
    // ===== Value Types =====
    
    value type ForceValue :> Real {
        attribute unit : String = "N";
    }
    
    value type TorqueValue :> Real {
        attribute unit : String = "N*m";
    }
    
    value type LinearVelocity :> Real {
        attribute unit : String = "m/s";
    }
    
    value type AngularVelocity :> Real {
        attribute unit : String = "rad/s";
    }
    
    value type LinearPosition :> Real {
        attribute unit : String = "m";
    }
    
    value type AngularPosition :> Real {
        attribute unit : String = "rad";
    }
    
    value type DistanceValue :> Real {
        attribute unit : String = "m";
    }
    
    value type ScaleFactor :> Real {
        attribute unit : String = "dimensionless";
    }
    
    value type FrequencyValue :> Real {
        attribute unit : String = "Hz";
    }
    
    value type TimeDelay :> Real {
        attribute unit : String = "s";
    }
    
    value type MagnificationFactor :> Real {
        attribute unit : String = "dimensionless";
    }
    
    value type ResolutionPixels :> Integer {
        attribute unit : String = "px";
    }
    
    // ===== Item Definitions =====
    
    item def HandMotion {
        attribute handId : String;
        attribute position : LinearPosition;
        attribute orientation : AngularPosition;
        attribute velocity : LinearVelocity;
        attribute timestamp : TimeDelay;
    }
    
    item def ScaledMotion {
        attribute position : LinearPosition;
        attribute orientation : AngularPosition;
        attribute velocity : LinearVelocity;
        attribute scale : ScaleFactor;
    }
    
    item def ControlCommand {
        attribute armId : String;
        attribute targetPosition : LinearPosition;
        attribute targetOrientation : AngularPosition;
        attribute targetVelocity : LinearVelocity;
        attribute isEmergency : Boolean = false;
    }
    
    item def InstrumentCommand {
        attribute instrumentId : String;
        attribute wristBend : AngularPosition;
        attribute wristRotation : AngularPosition;
        attribute graspAngle : AngularPosition;
    }
    
    item def CameraCommand {
        attribute panAngle : AngularPosition;
        attribute tiltAngle : AngularPosition;
        attribute zoomLevel : MagnificationFactor;
    }
    
    item def VideoFrame {
        attribute frameId : Integer;
        attribute leftEyeData : String;
        attribute rightEyeData : String;
        attribute timestamp : TimeDelay;
    }
    
    item def StereoVideoStream {
        attribute frameRate : FrequencyValue;
        attribute resolution : String;
        attribute leftChannel : String;
        attribute rightChannel : String;
        attribute latency : TimeDelay;
    }
    
    item def ArmTelemetry {
        attribute armId : String;
        attribute currentPosition : LinearPosition;
        attribute currentVelocity : LinearVelocity;
        attribute appliedForce : ForceValue;
        attribute appliedTorque : TorqueValue;
        attribute timestamp : TimeDelay;
    }
    
    item def SafetyAlert {
        attribute alertId : String;
        attribute alertType : String;
        attribute severity : Integer;
        attribute message : String;
        attribute timestamp : TimeDelay;
    }
    
    item def EmergencyStopSignal {
        attribute signalId : String;
        attribute reason : String;
        attribute timestamp : TimeDelay;
    }
    
    // ===== Port Definitions =====
    
    port def HandMotionPort {
        out item handMotion : HandMotion;
    }
    
    port def ControlCommandPort {
        out item command : ControlCommand;
        in item telemetry : ArmTelemetry;
    }
    
    port def InstrumentCommandPort {
        out item instrumentCommand : InstrumentCommand;
        in item telemetry : ArmTelemetry;
    }
    
    port def CameraCommandPort {
        out item cameraCommand : CameraCommand;
        in item telemetry : ArmTelemetry;
    }
    
    port def RawVideoPort {
        out item rawFrame : VideoFrame;
    }
    
    port def ProcessedVideoPort {
        out item stereoStream : StereoVideoStream;
    }
    
    port def TelemetryPort {
        out item telemetry : ArmTelemetry;
    }
    
    port def SafetyPort {
        out item alert : SafetyAlert;
        out item stopSignal : EmergencyStopSignal;
        in item telemetry : ArmTelemetry;
    }
    
    // ===== Interface Definitions =====
    
    interface def SurgeonToControlInterface {
        end port surgeonSide : HandMotionPort;
        end port controlSide : HandMotionPort;
    }
    
    interface def ControlToArmInterface {
        end port controlSide : ControlCommandPort;
        end port armSide : InstrumentCommandPort;
    }
    
    interface def CameraToVisionInterface {
        end port cameraSide : RawVideoPort;
        end port visionSide : RawVideoPort;
    }
    
    interface def VisionToConsoleInterface {
        end port visionSide : ProcessedVideoPort;
        end port consoleSide : ProcessedVideoPort;
    }
    
    interface def SafetyMonitoringInterface {
        end port armSide : TelemetryPort;
        end port safetySide : SafetyPort;
    }
    
    // ===== Requirement Definitions =====
    
    requirement def VisualizationRequirement {
        doc /* The system shall provide a high-definition 3D stereoscopic view of the surgical site with sufficient magnification and minimal latency. */
        attribute minMagnification : MagnificationFactor = 10.0;
        attribute maxLatency : TimeDelay = 0.040;
        attribute isStereoscopic : Boolean = true;
        attribute minResolution : String = "1920x1080";
    }
    
    requirement def MotionScalingRequirement {
        doc /* The system shall scale surgeon hand movements down to micromovements of instrument tips with configurable scaling factors. */
        attribute minScale : ScaleFactor = 0.1;
        attribute maxScale : ScaleFactor = 1.0;
        attribute defaultScale : ScaleFactor = 0.3;
    }
    
    requirement def TremorFilteringRequirement {
        doc /* The system shall actively filter natural hand tremors to ensure steady instrument motion. */
        attribute filterCutoffFrequency : FrequencyValue = 6.0;
        attribute minAttenuation : Real = 0.8;
    }
    
    requirement def SafetyMonitoringRequirement {
        doc /* The system shall continuously monitor arm position, force, and velocity against predefined safety limits and initiate emergency stop when exceeded. */
        attribute maxForceLimit : ForceValue = 10.0;
        attribute maxVelocityLimit : LinearVelocity = 0.5;
        attribute maxPositionDeviation : DistanceValue = 0.05;
        attribute emergencyStopResponseTime : TimeDelay = 0.010;
    }
    
    requirement def DexterityRequirement {
        doc /* Robotic instruments shall have wrists that can bend and rotate beyond human hand capability for dexterity in confined spaces. */
        attribute minWristBend : AngularPosition = 3.14;
        attribute minWristRotation : AngularPosition = 6.28;
    }
    
    requirement def ArmCountRequirement {
        doc /* The patient-side cart shall have three or more robotic arms for instruments and one dedicated arm for the camera. */
        attribute minInstrumentArms : Integer = 3;
        attribute cameraArms : Integer = 1;
    }
    
    // ===== Leaf Part Definitions =====
    
    part def StereoscopicViewer {
        attribute viewerId : String;
        attribute resolution : String = "1920x1080";
        attribute magnification : MagnificationFactor = 10.0;
        attribute is3DCapable : Boolean = true;
        attribute isHeadTrackingEnabled : Boolean = true;
        port videoIn : ProcessedVideoPort;
    }
    
    part def MasterHandController {
        attribute controllerId : String;
        attribute currentPosition : LinearPosition;
        attribute currentOrientation : AngularPosition;
        attribute currentVelocity : LinearVelocity;
        attribute isCalibrated : Boolean = true;
        port handMotionOut : HandMotionPort;
        
        action def captureHandMotion {
            in physicalPosition : LinearPosition;
            in physicalOrientation : AngularPosition;
            out motion : HandMotion;
        }
    }
    
    part def FootPedal {
        attribute pedalId : String;
        attribute pedalFunction : String;
        attribute isPressed : Boolean = false;
        attribute pressTimestamp : TimeDelay;
        
        action def detectPress {
            out isPressed : Boolean;
        }
    }
    
    part def SurgicalInstrument {
        attribute instrumentId : String;
        attribute instrumentType : String;
        attribute wristBendAngle : AngularPosition = 0.0;
        attribute wristRotationAngle : AngularPosition = 0.0;
        attribute graspAngle : AngularPosition = 0.0;
        attribute maxWristBend : AngularPosition = 3.14;
        attribute maxWristRotation : AngularPosition = 6.28;
        attribute maxGraspAngle : AngularPosition = 1.57;
        attribute isSterile : Boolean = true;
        port commandIn : InstrumentCommandPort;
        
        action def actuate {
            in command : InstrumentCommand;
            out wristBend : AngularPosition;
            out wristRotation : AngularPosition;
            out grasp : AngularPosition;
        }
    }
    
    part def EndoscopicCamera {
        attribute cameraId : String;
        attribute isStereoscopic : Boolean = true;
        attribute resolution : String = "1920x1080";
        attribute frameRate : FrequencyValue = 60.0;
        attribute currentPan : AngularPosition = 0.0;
        attribute currentTilt : AngularPosition = 0.0;
        attribute currentZoom : MagnificationFactor = 1.0;
        port rawVideoOut : RawVideoPort;
        port commandIn : CameraCommandPort;
        
        action def captureStereoFrame {
            out leftFrame : VideoFrame;
            out rightFrame : VideoFrame;
        }
    }
    
    part def RoboticArm {
        attribute armId : String;
        attribute armType : String;
        attribute currentPosition : LinearPosition;
        attribute currentVelocity : LinearVelocity;
        attribute appliedForce : ForceValue;
        attribute appliedTorque : TorqueValue;
        attribute isFrozen : Boolean = false;
        attribute maxReach : DistanceValue = 0.8;
        attribute maxForce : ForceValue = 10.0;
        port commandIn : InstrumentCommandPort;
        port telemetryOut : TelemetryPort;
        
        action def move {
            in command : InstrumentCommand;
            out telemetry : ArmTelemetry;
        }
        
        action def freeze {
            in reason : String;
            out frozenStatus : Boolean;
        }
    }
    
    part def MotionControlProcessor {
        attribute processorId : String;
        attribute scaleFactor : ScaleFactor = 0.3;
        attribute tremorFilterCutoff : FrequencyValue = 6.0;
        attribute isOperational : Boolean = true;
        attribute processingLatency : TimeDelay = 0.005;
        port handMotionIn : HandMotionPort;
        port commandOut : ControlCommandPort;
        port safetyIn : SafetyPort;
        
        action def processMotion {
            in rawMotion : HandMotion;
            out command : ControlCommand;
            
            action filterTremor {
                in motion : HandMotion;
                in cutoffFreq : FrequencyValue;
                out filteredMotion : HandMotion;
            }
            
            action scaleMotion {
                in motion : HandMotion;
                in scale : ScaleFactor;
                out scaled : ScaledMotion;
            }
            
            action generateCommand {
                in scaled : ScaledMotion;
                out cmd : ControlCommand;
            }
            
            flow rawMotion to filterTremor.motion;
            flow filterTremor.filteredMotion to scaleMotion.motion;
            flow scaleMotion.scaled to generateCommand.scaled;
            flow generateCommand.cmd to command;
        }
    }
    
    part def VisionProcessingUnit {
        attribute unitId : String;
        attribute processingDelay : TimeDelay = 0.020;
        attribute enhancementEnabled : Boolean = true;
        attribute noiseReductionLevel : Real = 0.7;
        attribute edgeEnhancementLevel : Real = 0.5;
        port rawVideoIn : RawVideoPort;
        port processedVideoOut : ProcessedVideoPort;
        
        action def processVideo {
            in rawFrame : VideoFrame;
            out stereoStream : StereoVideoStream;
            
            action enhanceFrame {
                in frame : VideoFrame;
                out enhanced : VideoFrame;
            }
            
            action generateStereoStream {
                in leftFrame : VideoFrame;
                in rightFrame : VideoFrame;
                out stream : StereoVideoStream;
            }
            
            flow rawFrame to enhanceFrame.frame;
            flow enhanceFrame.enhanced to generateStereoStream.leftFrame;
            flow enhanceFrame.enhanced to generateStereoStream.rightFrame;
            flow generateStereoStream.stream to stereoStream;
        }
    }
    
    part def SafetyMonitoringSystem {
        attribute systemId : String;
        attribute maxForceLimit : ForceValue = 10.0;
        attribute maxVelocityLimit : LinearVelocity = 0.5;
        attribute maxPositionDeviation : DistanceValue = 0.05;
        attribute emergencyStopActive : Boolean = false;
        attribute monitoringFrequency : FrequencyValue = 1000.0;
        port telemetryIn : TelemetryPort;
        port alertOut : SafetyPort;
        
        state def SafetyMonitorStateMachine {
            entry; then Monitoring;
            
            state Monitoring {
                entry;
                action checkLimits {
                    in telemetry : ArmTelemetry;
                    out violation : Boolean;
                    out alert : SafetyAlert;
                }
            }
            
            state EmergencyStop {
                entry;
                action freezeAllArms;
                action alertSurgicalTeam;
            }
            
            state Recovery {
                entry;
                action verifySafeConditions;
                action resetSystem;
            }
            
            transition Monitoring -> EmergencyStop {
                when (telemetryIn.telemetry.appliedForce > maxForceLimit);
            }
            
            transition Monitoring -> EmergencyStop {
                when (telemetryIn.telemetry.currentVelocity > maxVelocityLimit);
            }
            
            transition EmergencyStop -> Recovery {
                when (emergencyStopActive == false);
            }
            
            transition Recovery -> Monitoring {
                when (true);
            }
        }
        
        action def checkTelemetry {
            in telemetry : ArmTelemetry;
            out isSafe : Boolean;
            out alert : SafetyAlert;
        }
        
        action def initiateEmergencyStop {
            out stopSignal : EmergencyStopSignal;
        }
    }
    
    // ===== Composite Part Definitions =====
    
    part def SurgeonConsole {
        attribute consoleId : String;
        attribute isPowered : Boolean = false;
        attribute surgeonId : String;
        port handMotionOut : HandMotionPort;
        port videoIn : ProcessedVideoPort;
        
        part viewer : StereoscopicViewer {
            port videoIn : ProcessedVideoPort;
        }
        
        part leftController : MasterHandController {
            attribute controllerId : String = "LeftMaster";
            port handMotionOut : HandMotionPort;
        }
        
        part rightController : MasterHandController {
            attribute controllerId : String = "RightMaster";
            port handMotionOut : HandMotionPort;
        }
        
        part clutchPedal : FootPedal {
            attribute pedalId : String = "ClutchPedal";
            attribute pedalFunction : String = "CameraControl";
        }
        
        part cameraPedal : FootPedal {
            attribute pedalId : String = "CameraPedal";
            attribute pedalFunction : String = "CameraNavigation";
        }
        
        part energyPedal : FootPedal {
            attribute pedalId : String = "EnergyPedal";
            attribute pedalFunction : String = "EnergyDeviceControl";
        }
        
        part focusPedal : FootPedal {
            attribute pedalId : String = "FocusPedal";
            attribute pedalFunction : String = "CameraFocus";
        }
        
        connection leftControllerMotion {
            source leftController.handMotionOut;
            target handMotionOut;
        }
        
        connection rightControllerMotion {
            source rightController.handMotionOut;
            target handMotionOut;
        }
        
        connection videoToViewer {
            source videoIn;
            target viewer.videoIn;
        }
    }
    
    part def PatientSideCart {
        attribute cartId : String;
        attribute isDocked : Boolean = false;
        attribute patientPosition : LinearPosition;
        port commandIn : ControlCommandPort;
        port telemetryOut : TelemetryPort;
        port rawVideoOut : RawVideoPort;
        port safetyIn : SafetyPort;
        
        part instrumentArm1 : RoboticArm {
            attribute armId : String = "InstrumentArm1";
            attribute armType : String = "instrument";
            port commandIn : InstrumentCommandPort;
            port telemetryOut : TelemetryPort;
            
            part instrument1 : SurgicalInstrument {
                attribute instrumentId : String = "Instr1";
                attribute instrumentType : String = "grasper";
                port commandIn : InstrumentCommandPort;
            }
        }
        
        part instrumentArm2 : RoboticArm {
            attribute armId : String = "InstrumentArm2";
            attribute armType : String = "instrument";
            port commandIn : InstrumentCommandPort;
            port telemetryOut : TelemetryPort;
            
            part instrument2 : SurgicalInstrument {
                attribute instrumentId : String = "Instr2";
                attribute instrumentType : String = "scissors";
                port commandIn : InstrumentCommandPort;
            }
        }
        
        part instrumentArm3 : RoboticArm {
            attribute armId : String = "InstrumentArm3";
            attribute armType : String = "instrument";
            port commandIn : InstrumentCommandPort;
            port telemetryOut : TelemetryPort;
            
            part instrument3 : SurgicalInstrument {
                attribute instrumentId : String = "Instr3";
                attribute instrumentType : String = "needle_holder";
                port commandIn : InstrumentCommandPort;
            }
        }
        
        part cameraArm : RoboticArm {
            attribute armId : String = "CameraArm";
            attribute armType : String = "camera";
            port commandIn : InstrumentCommandPort;
            port telemetryOut : TelemetryPort;
            
            part endoscopicCamera : EndoscopicCamera {
                attribute cameraId : String = "StereoCam1";
                port rawVideoOut : RawVideoPort;
                port commandIn : CameraCommandPort;
            }
        }
        
        connection commandToArm1 {
            source commandIn;
            target instrumentArm1.commandIn;
        }
        
        connection commandToArm2 {
            source commandIn;
            target instrumentArm2.commandIn;
        }
        
        connection commandToArm3 {
            source commandIn;
            target instrumentArm3.commandIn;
        }
        
        connection commandToCameraArm {
            source commandIn;
            target cameraArm.commandIn;
        }
        
        connection telemetryFromArm1 {
            source instrumentArm1.telemetryOut;
            target telemetryOut;
        }
        
        connection telemetryFromArm2 {
            source instrumentArm2.telemetryOut;
            target telemetryOut;
        }
        
        connection telemetryFromArm3 {
            source instrumentArm3.telemetryOut;
            target telemetryOut;
        }
        
        connection telemetryFromCameraArm {
            source cameraArm.telemetryOut;
            target telemetryOut;
        }
        
        connection cameraVideoRouting {
            source cameraArm.endoscopicCamera.rawVideoOut;
            target rawVideoOut;
        }
    }
    
    part def VisionTower {
        attribute towerId : String;
        attribute isPowered : Boolean = false;
        port handMotionIn : HandMotionPort;
        port commandOut : ControlCommandPort;
        port rawVideoIn : RawVideoPort;
        port processedVideoOut : ProcessedVideoPort;
        port telemetryIn : TelemetryPort;
        port safetyOut : SafetyPort;
        
        part motionControl : MotionControlProcessor {
            attribute processorId : String = "MCP-001";
            port handMotionIn : HandMotionPort;
            port commandOut : ControlCommandPort;
            port safetyIn : SafetyPort;
        }
        
        part visionProcessing : VisionProcessingUnit {
            attribute unitId : String = "VPU-001";
            port rawVideoIn : RawVideoPort;
            port processedVideoOut : ProcessedVideoPort;
        }
        
        part safetyMonitor : SafetyMonitoringSystem {
            attribute systemId : String = "SMS-001";
            port telemetryIn : TelemetryPort;
            port alertOut : SafetyPort;
        }
        
        connection handMotionToProcessor {
            source handMotionIn;
            target motionControl.handMotionIn;
        }
        
        connection commandFromProcessor {
            source motionControl.commandOut;
            target commandOut;
        }
        
        connection rawVideoToProcessor {
            source rawVideoIn;
            target visionProcessing.rawVideoIn;
        }
        
        connection processedVideoFromUnit {
            source visionProcessing.processedVideoOut;
            target processedVideoOut;
        }
        
        connection telemetryToSafety {
            source telemetryIn;
            target safetyMonitor.telemetryIn;
        }
        
        connection safetyFromMonitor {
            source safetyMonitor.alertOut;
            target safetyOut;
        }
        
        connection safetyToMotionControl {
            source safetyMonitor.alertOut;
            target motionControl.safetyIn;
        }
    }
    
    // ===== Top-Level System Definition =====
    
    part def DaVinciSystem {
        attribute systemId : String = "daVinci-Xi";
        attribute systemVersion : String = "4.0";
        attribute isOperational : Boolean = false;
        attribute procedureId : String;
        
        part surgeonConsole : SurgeonConsole {
            attribute consoleId : String = "SC-001";
            port handMotionOut : HandMotionPort;
            port videoIn : ProcessedVideoPort;
        }
        
        part patientSideCart : PatientSideCart {
            attribute cartId : String = "PSC-001";
            port commandIn : ControlCommandPort;
            port telemetryOut : TelemetryPort;
            port rawVideoOut : RawVideoPort;
            port safetyIn : SafetyPort;
        }
        
        part visionTower : VisionTower {
            attribute towerId : String = "VT-001";
            port handMotionIn : HandMotionPort;
            port commandOut : ControlCommandPort;
            port rawVideoIn : RawVideoPort;
            port processedVideoOut : ProcessedVideoPort;
            port telemetryIn : TelemetryPort;
            port safetyOut : SafetyPort;
        }
        
        // Surgeon Console -> Vision Tower (hand motion)
        connection surgeonToVisionTower {
            source surgeonConsole.handMotionOut;
            target visionTower.handMotionIn;
        }
        
        // Vision Tower -> Patient Side Cart (control commands)
        connection visionTowerToPatientCart {
            source visionTower.commandOut;
            target patientSideCart.commandIn;
        }
        
        // Patient Side Cart -> Vision Tower (telemetry)
        connection patientCartToVisionTower {
            source patientSideCart.telemetryOut;
            target visionTower.telemetryIn;
        }
        
        // Patient Side Cart -> Vision Tower (raw video)
        connection patientCartVideoToVisionTower {
            source patientSideCart.rawVideoOut;
            target visionTower.rawVideoIn;
        }
        
        // Vision Tower -> Surgeon Console (processed video)
        connection visionTowerToConsole {
            source visionTower.processedVideoOut;
            target surgeonConsole.videoIn;
        }
        
        // Vision Tower -> Patient Side Cart (safety signals)
        connection safetyToPatientCart {
            source visionTower.safetyOut;
            target patientSideCart.safetyIn;
        }
        
        // System-level state machine
        state def SystemOperationStateMachine {
            entry; then Standby;
            
            state Standby {
                entry;
                action initializeSystem {
                    out initialized : Boolean;
                }
            }
            
            state Ready {
                entry;
                action performSelfTest {
                    out selfTestPassed : Boolean;
                }
            }
            
            state Operating {
                entry;
                action monitorProcedure {
                    in telemetry : ArmTelemetry;
                    out procedureStatus : String;
                }
            }
            
            state EmergencyStopped {
                entry;
                action freezeAllMotion;
                action alertSurgicalTeam {
                    out alert : SafetyAlert;
                }
            }
            
            state Shutdown {
                entry;
                action performSafeShutdown {
                    out shutdownComplete : Boolean;
                }
            }
            
            transition Standby -> Ready {
                when (selfTestPassed == true);
            }
            
            transition Ready -> Operating {
                when (surgeonEngaged == true);
            }
            
            transition Operating -> EmergencyStopped {
                when (safetyViolation == true);
            }
            
            transition EmergencyStopped -> Ready {
                when (safetyCleared == true);
            }
            
            transition Operating -> Shutdown {
                when (procedureComplete == true);
            }
        }
        
        // Requirement usages and satisfaction
        requirement visReq : VisualizationRequirement {
            attribute minMagnification = 10.0;
            attribute maxLatency = 0.040;
        }
        
        requirement motionScaleReq : MotionScalingRequirement {
            attribute defaultScale = 0.3;
        }
        
        requirement tremorReq : TremorFilteringRequirement {
            attribute filterCutoffFrequency = 6.0;
        }
        
        requirement safetyReq : SafetyMonitoringRequirement {
            attribute maxForceLimit = 10.0;
            attribute maxVelocityLimit = 0.5;
        }
        
        requirement dexterityReq : DexterityRequirement {
            attribute minWristBend = 3.14;
            attribute minWristRotation = 6.28;
        }
        
        requirement armCountReq : ArmCountRequirement {
            attribute minInstrumentArms = 3;
            attribute cameraArms = 1;
        }
        
        satisfy visReq by surgeonConsole.viewer;
        satisfy motionScaleReq by visionTower.motionControl;
        satisfy tremorReq by visionTower.motionControl;
        satisfy safetyReq by visionTower.safetyMonitor;
        satisfy dexterityReq by patientSideCart.instrumentArm1.instrument1;
        satisfy dexterityReq by patientSideCart.instrumentArm2.instrument2;
        satisfy dexterityReq by patientSideCart.instrumentArm3.instrument3;
        satisfy armCountReq by patientSideCart;
    }
}
