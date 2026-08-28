package AutonomousAssemblySystem {
    import ISQ::*;
    import ISQSpace::*;
    import ISQMass::*;
    import ISQForce::*;
    import ISQDuration::*;
    import SI::*;
    import ScalarFunctions::*;

    // ===== Value Types =====
    value type LengthValue :> Length {
        unit mm;
    }
    value type CoordinateValue :> Length {
        unit mm;
    }
    value type AccuracyValue :> Length {
        unit mm;
    }
    value type MassValue :> Mass {
        unit kg;
    }
    value type ForceValue :> Force {
        unit N;
    }
    value type DurationValue :> Duration {
        unit s;
    }
    value type FrequencyValue :> Frequency {
        unit Hz;
    }
    value type PressureValue :> Pressure {
        unit Pa;
    }
    value type AngleValue :> Angle {
        unit deg;
    }
    value type VelocityValue :> Velocity {
        unit mm / s;
    }
    value type TorqueValue :> Torque {
        unit N m;
    }
    value type ConfidenceValue :> Real;

    // ===== Enumerations =====
    enum def SystemState {
        idle;
        scanning;
        acquiring;
        assembling;
        inspecting;
        fault;
    }
    enum def GripperState {
        open;
        closed;
        holding;
        releasing;
        fault;
    }
    enum def FeederState {
        stopped;
        feeding;
        empty;
        fault;
    }
    enum def VisionState {
        idle;
        scanning;
        inspecting;
        fault;
    }
    enum def ArmState {
        idle;
        moving;
        positioning;
        fault;
    }
    enum def PathPlanStatus {
        success;
        failure;
        inProgress;
    }
    enum def FaultType {
        none;
        collisionRisk;
        forceExceeded;
        componentMissing;
        visionFailure;
        actuatorFault;
        communicationError;
    }

    // ===== Item Definitions =====
    item def Component {
        attribute identifier : String;
        attribute weight : MassValue;
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute material : String;
    }
    item def AssembledProduct {
        attribute identifier : String;
        attribute componentCount : Integer;
        attribute assembledComponents : Component[*];
    }
    item def ComponentPosition {
        attribute x : CoordinateValue;
        attribute y : CoordinateValue;
        attribute z : CoordinateValue;
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }
    item def PathPlan {
        attribute waypoints : ComponentPosition[*];
        attribute estimatedDuration : DurationValue;
        attribute status : PathPlanStatus;
    }
    item def QualityReport {
        attribute componentId : String;
        attribute positionValid : Boolean;
        attribute orientationValid : Boolean;
        attribute forceValid : Boolean;
        attribute overallPass : Boolean;
        attribute timestamp : String;
        attribute deviation : AccuracyValue;
    }
    item def VisionResult {
        attribute componentId : String;
        attribute position : ComponentPosition;
        attribute orientation : AngleValue;
        attribute confidence : ConfidenceValue;
        attribute componentDetected : Boolean;
    }

    // ===== Port Definitions =====
    port def VisionDataPort {
        out visionResult : VisionResult;
        out qualityReport : QualityReport;
    }
    port def ArmCommandPort {
        in targetPosition : ComponentPosition;
        in velocity : VelocityValue;
        in acceleration : Real;
        in command : String;
    }
    port def ArmFeedbackPort {
        out currentPosition : ComponentPosition;
        out currentLoad : MassValue;
        out moving : Boolean;
    }
    port def GripperCommandPort {
        in command : String;
        in targetForce : ForceValue;
    }
    port def GripperFeedbackPort {
        out currentForce : ForceValue;
        out componentHeld : Boolean;
        out gripperState : GripperState;
    }
    port def ComponentFlowPort {
        out component : Component;
    }
    port def FeederStatusPort {
        out bufferCount : Integer;
        out beltRunning : Boolean;
    }
    port def SystemStatusPort {
        out currentState : SystemState;
        out activeFault : FaultType;
        out cyclesCompleted : Integer;
    }

    // ===== Action Definitions =====
    action def PlanPath {
        in start : ComponentPosition;
        in goal : ComponentPosition;
        in obstacles : ComponentPosition[*];
        out path : PathPlan;
    }
    action def ExecuteMotion {
        in path : PathPlan;
        out finalPosition : ComponentPosition;
        out motionComplete : Boolean;
    }
    action def InspectQuality {
        in image : String;
        in targetPosition : ComponentPosition;
        out report : QualityReport;
    }
    action def IdentifyComponent {
        in image : String;
        out result : VisionResult;
    }
    action def GraspComponent {
        in force : ForceValue;
        out componentHeld : Boolean;
        out appliedForce : ForceValue;
    }
    action def ReleaseComponent {
        out componentReleased : Boolean;
    }

    // ===== Requirements =====
    requirement def ManipulatorReachRequirement {
        doc "The robotic manipulator arm must provide a reach of at least 1.5 meters.";
        attribute minReach : LengthValue = 1500 [mm];
        constraint { minReach >= 1500 [mm]; }
    }
    requirement def ManipulatorPayloadRequirement {
        doc "The robotic arm must handle components weighing up to 15 kg.";
        attribute maxPayload : MassValue = 15 [kg];
        constraint { maxPayload >= 15 [kg]; }
    }
    requirement def PlacementAccuracyRequirement {
        doc "The system must place components with an accuracy of 0.05 mm or better.";
        attribute maxPlacementError : AccuracyValue = 0.05 [mm];
        constraint { maxPlacementError <= 0.05 [mm]; }
    }
    requirement def FeederBufferRequirement {
        doc "The component feeder must hold a buffer of up to 50 parts.";
        attribute bufferCapacity : Integer = 50;
        constraint { bufferCapacity >= 50; }
    }
    requirement def GripperForceControlRequirement {
        doc "The pneumatic gripper must grasp components with controlled force.";
        attribute maxGripForce : ForceValue = 60 [N];
        attribute minGripForce : ForceValue = 5 [N];
        constraint { maxGripForce <= 60 [N]; }
        constraint { minGripForce >= 5 [N]; }
    }
    requirement def VisionInspectionRequirement {
        doc "The vision system must scan and inspect components during and after assembly.";
        attribute inspectionRate : FrequencyValue = 10 [Hz];
        constraint { inspectionRate >= 10 [Hz]; }
    }
    requirement def SafeOperationRequirement {
        doc "The system must safely handle errors and safety violations.";
        attribute emergencyStopTime : DurationValue = 0.5 [s];
        attribute faultResponseTime : DurationValue = 0.2 [s];
        constraint { emergencyStopTime <= 0.5 [s]; }
        constraint { faultResponseTime <= 0.2 [s]; }
    }
    requirement def AutonomousOperationRequirement {
        doc "The system must operate without direct human intervention.";
        attribute humanInterventionRequired : Boolean = false;
        constraint { humanInterventionRequired == false; }
    }
    requirement def SixJointManipulatorRequirement {
        doc "The manipulator must have six joints for the required reach and dexterity.";
        attribute jointCount : Integer = 6;
        constraint { jointCount == 6; }
    }

    // ===== Part Definitions =====

    part def RoboticManipulatorArm {
        requirement reachReq : ManipulatorReachRequirement;
        requirement payloadReq : ManipulatorPayloadRequirement;
        requirement accuracyReq : PlacementAccuracyRequirement;
        requirement jointsReq : SixJointManipulatorRequirement;

        attribute maxReach : LengthValue = 1500 [mm];
        attribute maxPayload : MassValue = 15 [kg];
        attribute placementAccuracy : AccuracyValue = 0.05 [mm];
        attribute jointCount : Integer = 6;
        attribute currentLoad : MassValue;
        attribute currentEndEffectorPos : ComponentPosition;
        attribute isMoving : Boolean = false;
        attribute currentCommand : String;
        attribute targetPos : ComponentPosition;
        attribute positionReached : Boolean = false;
        attribute overLoaded : Boolean = false;

        port in armCommand : ArmCommandPort;
        port out armFeedback : ArmFeedbackPort;
        port in componentInput : ComponentFlowPort;

        part joint1 {
            attribute angle : AngleValue;
            attribute maxTorque : TorqueValue = 250 [N m];
            attribute currentTorque : TorqueValue;
        }
        part joint2 {
            attribute angle : AngleValue;
            attribute maxTorque : TorqueValue = 250 [N m];
            attribute currentTorque : TorqueValue;
        }
        part joint3 {
            attribute angle : AngleValue;
            attribute maxTorque : TorqueValue = 150 [N m];
            attribute currentTorque : TorqueValue;
        }
        part joint4 {
            attribute angle : AngleValue;
            attribute maxTorque : TorqueValue = 100 [N m];
            attribute currentTorque : TorqueValue;
        }
        part joint5 {
            attribute angle : AngleValue;
            attribute maxTorque : TorqueValue = 50 [N m];
            attribute currentTorque : TorqueValue;
        }
        part joint6 {
            attribute angle : AngleValue;
            attribute maxTorque : TorqueValue = 25 [N m];
            attribute currentTorque : TorqueValue;
        }

        part endEffector {
            attribute position : ComponentPosition;
            attribute mountedTool : String = "pneumaticGripper";
        }

        action computeJointAngles {
            in targetPosition : ComponentPosition;
            out j1 : AngleValue;
            out j2 : AngleValue;
            out j3 : AngleValue;
            out j4 : AngleValue;
            out j5 : AngleValue;
            out j6 : AngleValue;
        }
        action executeJointMotion;
        action holdPosition;
        action freezeJoints;
        action startMotion;
        action stopMotion;

        state armStateMachine {
            state idle {
                entry action holdPosition();
            }
            state moving {
                entry action startMotion();
                do action executeJointMotion();
                exit action stopMotion();
            }
            state positioning {
                entry action computeJointAngles();
                do action executeJointMotion();
                exit action holdPosition();
            }
            state fault {
                entry action freezeJoints();
            }

            transition from idle to moving when currentCommand == "move";
            transition from moving to positioning when positionReached == true;
            transition from positioning to idle when currentCommand == "hold";
            transition from idle to positioning when currentCommand == "position";
            transition from moving to fault when overLoaded == true;
            transition from positioning to fault when overLoaded == true;
            transition from idle to fault when overLoaded == true;
        }
    }

    part def PneumaticGripper {
        requirement gripForceReq : GripperForceControlRequirement;

        attribute maxGripForce : ForceValue = 60 [N];
        attribute minGripForce : ForceValue = 5 [N];
        attribute currentForce : ForceValue;
        attribute supplyPressure : PressureValue = 600000 [Pa];
        attribute gripperOpenWidth : LengthValue = 80 [mm];
        attribute heldComponentRef : Component[0..1];
        attribute isHolding : Boolean = false;
        attribute currentCommand : String;
        attribute targetForceAttr : ForceValue;
        attribute forceExceeded : Boolean = false;

        port in gripperCommand : GripperCommandPort;
        port out gripperFeedback : GripperFeedbackPort;

        part gripperJaw1 {
            attribute position : LengthValue;
            attribute surface : String = "rubber";
        }
        part gripperJaw2 {
            attribute position : LengthValue;
            attribute surface : String = "rubber";
        }
        part pressureRegulator {
            attribute setPressure : PressureValue;
            attribute maxPressure : PressureValue = 700000 [Pa];
        }
        part forceSensor {
            attribute reading : ForceValue;
        }
        part proximitySensor {
            attribute detected : Boolean;
        }

        action openJaws;
        action closeJaws {
            in targetForce : ForceValue;
        }
        action applyGripForce {
            in targetForce : ForceValue;
        }
        action releaseJaws;
        action monitorGripForce;

        state gripperStateMachine {
            state open {
                entry action openJaws();
            }
            state holding {
                entry action applyGripForce();
                do action monitorGripForce();
            }
            state releasing {
                entry action releaseJaws();
            }
            state fault {
                entry action releaseJaws();
            }

            transition from open to holding when currentCommand == "grip";
            transition from holding to releasing when currentCommand == "release";
            transition from releasing to open when isHolding == false;
            transition from holding to fault when forceExceeded == true;
            transition from open to fault when forceExceeded == true;
        }
    }

    part def AssemblyController {
        requirement safetyReq : SafeOperationRequirement;
        requirement autonomyReq : AutonomousOperationRequirement;

        attribute cycleTime : DurationValue;
        attribute currentCycle : Integer = 0;
        attribute lastCommand : String;
        attribute activeFault : FaultType = none;
        attribute visionConfidence : ConfidenceValue = 0.0;
        attribute componentReady : Boolean = false;
        attribute componentAcquired : Boolean = false;
        attribute componentSecured : Boolean = false;
        attribute qualityPassed : Boolean = false;
        attribute faultActive : Boolean = false;
        attribute faultCleared : Boolean = false;
        attribute bufferCount : Integer = 0;
        attribute startReceived : Boolean = false;

        port in visionData : VisionDataPort;
        port in armFeedback : ArmFeedbackPort;
        port in gripperFeedback : GripperFeedbackPort;
        port in feederStatus : FeederStatusPort;
        port in startCommand : String;
        port out armCommand : ArmCommandPort;
        port out gripperCommand : GripperCommandPort;
        port out systemStatus : SystemStatusPort;
        port out feederControl : String;
        port out visionControl : String;

        part trajectoryPlanner {
            attribute planningTime : DurationValue = 0.1 [s];
            attribute currentPlan : PathPlan;
            action planPath : PlanPath;
            action validatePath {
                in path : PathPlan;
                out valid : Boolean;
            }
        }

        part safetyMonitor {
            attribute maxVelocity : VelocityValue = 2000 [mm / s];
            attribute maxAcceleration : Real = 10;
            attribute detectedFault : FaultType = none;
            action checkCollision {
                in path : PathPlan;
                out safe : Boolean;
            }
            action triggerEmergencyStop;
            action logFaultEvent {
                in faultType : FaultType;
                in timestamp : String;
            }
        }

        part taskScheduler {
            attribute currentTask : String;
            attribute taskQueue : String[*];
            action scheduleNextTask;
            action clearTaskQueue;
        }

        action waitForComponents;
        action requestScan;
        action processScanResults;
        action planPickup;
        action executePickup;
        action planAssembly;
        action executeAssembly;
        action requestInspection;
        action evaluateQuality;
        action handleFault;
        action logFault;
        action resetSystem;

        state controllerStateMachine {
            state idle {
                entry action waitForComponents();
            }
            state scanning {
                entry action requestScan();
                do action processScanResults();
            }
            state acquiring {
                entry action planPickup();
                do action executePickup();
            }
            state assembling {
                entry action planAssembly();
                do action executeAssembly();
            }
            state inspecting {
                entry action requestInspection();
                do action evaluateQuality();
            }
            state fault {
                entry action handleFault();
                do action logFault();
                exit action resetSystem();
            }

            transition from idle to scanning when startReceived == true;
            transition from idle to scanning when bufferCount > 0;
            transition from scanning to acquiring when visionConfidence > 0.8;
            transition from scanning to fault when faultActive == true;
            transition from acquiring to assembling when componentAcquired == true;
            transition from acquiring to fault when faultActive == true;
            transition from assembling to inspecting when componentSecured == true;
            transition from assembling to fault when faultActive == true;
            transition from inspecting to idle when qualityPassed == true;
            transition from inspecting to fault when qualityPassed == false;
            transition from fault to idle when faultCleared == true;
        }
    }

    part def ComponentFeeder {
        requirement bufferReq : FeederBufferRequirement;

        attribute bufferCapacity : Integer = 50;
        attribute currentBufferCount : Integer = 0;
        attribute beltSpeed : VelocityValue = 50 [mm / s];
        attribute beltLength : LengthValue = 2000 [mm];
        attribute feederCommand : String;
        attribute beltRunning : Boolean = false;

        port in feederControl : String;
        port out componentOutput : ComponentFlowPort;
        port out feederStatus : FeederStatusPort;

        part conveyorBelt {
            attribute length : LengthValue = 2000 [mm];
            attribute width : LengthValue = 200 [mm];
            attribute speed : VelocityValue = 50 [mm / s];
            attribute beltMaterial : String = "polyurethane";
        }

        part sensorArray {
            part presenceSensor1 {
                attribute detected : Boolean;
                attribute position : LengthValue = 100 [mm];
            }
            part presenceSensor2 {
                attribute detected : Boolean;
                attribute position : LengthValue = 1900 [mm];
            }
            part proximitySensor {
                attribute detected : Boolean;
                attribute range : LengthValue = 50 [mm];
            }
        }

        part buffer {
            attribute capacity : Integer = 50;
            attribute currentCount : Integer;
            action addComponent {
                in component : Component;
            }
            action removeComponent {
                out component : Component;
            }
        }

        action advanceBelt;
        action stopBelt;
        action requestRefill;
        action loadComponent;
        action ejectComponent;

        state feederStateMachine {
            state stopped {
                entry action stopBelt();
            }
            state feeding {
                entry action advanceBelt();
                do action loadComponent();
            }
            state empty {
                entry action requestRefill();
            }
            state fault {
                entry action stopBelt();
            }

            transition from stopped to feeding when feederControl == "start";
            transition from feeding to empty when currentBufferCount == 0;
            transition from empty to feeding when currentBufferCount > 0;
            transition from feeding to stopped when feederControl == "stop";
            transition from feeding to fault when feederControl == "fault";
            transition from fault to stopped when feederControl == "reset";
        }
    }

    part def VisionSystem {
        requirement visionReq : VisionInspectionRequirement;

        attribute inspectionRate : FrequencyValue = 10 [Hz];
        attribute resolution : Real = 12;
        attribute fieldOfView : AngleValue = 60 [deg];
        attribute calibrationDate : String;
        attribute inspectionCommand : String;
        attribute detectionConfidence : ConfidenceValue = 0.0;
        attribute lastQualityReport : QualityReport;
        attribute scanComplete : Boolean = false;
        attribute inspectionComplete : Boolean = false;
        attribute inspectionPassed : Boolean = false;

        port out visionData : VisionDataPort;
        port in inspectionCmd : String;

        part camera1 {
            attribute focalLength : LengthValue = 25 [mm];
            attribute exposure : DurationValue = 0.005 [s];
            attribute resolutionX : Integer = 2048;
            attribute resolutionY : Integer = 2048;
            action captureImage {
                out image : String;
            }
        }

        part camera2 {
            attribute focalLength : LengthValue = 50 [mm];
            attribute exposure : DurationValue = 0.003 [s];
            attribute resolutionX : Integer = 4096;
            attribute resolutionY : Integer = 4096;
            action captureImage {
                out image : String;
            }
        }

        part lightingSystem {
            attribute brightness : Real = 0.8;
            attribute lightType : String = "LED";
            part ringLight {
                attribute diameter : LengthValue = 100 [mm];
            }
            part backLight {
                attribute size : LengthValue = 200 [mm];
            }
        }

        part imageProcessor {
            attribute processingTime : DurationValue = 0.05 [s];
            attribute modelVersion : String = "v2.1";
            action identifyComponent : IdentifyComponent;
            action inspectQuality : InspectQuality;
            action calibratePosition {
                in rawPosition : ComponentPosition;
                out calibratedPosition : ComponentPosition;
            }
        }

        action captureImages;
        action processImages;
        action identifyComponentAction;
        action inspectQualityAction;
        action logVisionError;
        action resetVision;

        state visionStateMachine {
            state idle;
            state scanning {
                entry action captureImages();
                do action identifyComponentAction();
            }
            state inspecting {
                entry action captureImages();
                do action inspectQualityAction();
            }
            state fault {
                entry action logVisionError();
            }

            transition from idle to scanning when inspectionCmd == "scan";
            transition from scanning to idle when scanComplete == true;
            transition from idle to inspecting when inspectionCmd == "inspect";
            transition from inspecting to idle when inspectionComplete == true;
            transition from scanning to fault when detectionConfidence < 0.3;
            transition from inspecting to fault when inspectionPassed == false;
            transition from fault to idle when inspectionCmd == "reset";
        }
    }

    // ===== Top-Level Assembly System =====
    part def AutonomousAssemblySystem {
        attribute systemId : String;
        attribute location : String;
        attribute activeState : SystemState = idle;
        attribute cyclesCompleted : Integer = 0;
        attribute activeFaultAttr : FaultType = none;
        attribute componentDetected : Boolean = false;
        attribute componentHeld : Boolean = false;
        attribute componentPlaced : Boolean = false;
        attribute qualityVerified : Boolean = false;
        attribute faultActive : Boolean = false;
        attribute faultCleared : Boolean = false;

        port in startCommand : String;
        port out systemStatus : SystemStatusPort;

        requirement systemReach : ManipulatorReachRequirement;
        requirement systemPayload : ManipulatorPayloadRequirement;
        requirement systemAccuracy : PlacementAccuracyRequirement;
        requirement systemFeeder : FeederBufferRequirement;
        requirement systemGripper : GripperForceControlRequirement;
        requirement systemVision : VisionInspectionRequirement;
        requirement systemSafety : SafeOperationRequirement;
        requirement systemAutonomy : AutonomousOperationRequirement;
        requirement systemJoints : SixJointManipulatorRequirement;

        part roboticArm : RoboticManipulatorArm {
            attribute maxReach : LengthValue = 1500 [mm];
            attribute maxPayload : MassValue = 15 [kg];
            attribute placementAccuracy : AccuracyValue = 0.05 [mm];
            attribute jointCount : Integer = 6;
        }

        part gripper : PneumaticGripper {
            attribute maxGripForce : ForceValue = 60 [N];
            attribute minGripForce : ForceValue = 5 [N];
            attribute supplyPressure : PressureValue = 600000 [Pa];
        }

        part controller : AssemblyController {
            attribute emergencyStopTime : DurationValue = 0.5 [s];
            attribute faultResponseTime : DurationValue = 0.2 [s];
        }

        part feeder : ComponentFeeder {
            attribute bufferCapacity : Integer = 50;
            attribute beltLength : LengthValue = 2000 [mm];
        }

        part vision : VisionSystem {
            attribute inspectionRate : FrequencyValue = 10 [Hz];
            attribute resolution : Real = 12;
            attribute fieldOfView : AngleValue = 60 [deg];
        }

        connection c1 from controller.armCommand to roboticArm.armCommand;
        connection c2 from roboticArm.armFeedback to controller.armFeedback;
        connection c3 from controller.gripperCommand to gripper.gripperCommand;
        connection c4 from gripper.gripperFeedback to controller.gripperFeedback;
        connection c5 from vision.visionData to controller.visionData;
        connection c6 from feeder.feederStatus to controller.feederStatus;
        connection c7 from feeder.componentOutput to roboticArm.componentInput;
        connection c8 from controller.feederControl to feeder.feederControl;
        connection c9 from controller.visionControl to vision.inspectionCmd;
        connection c10 from controller.systemStatus to systemStatus;
        connection c11 from startCommand to controller.startCommand;

        action calibrateArm;
        action calibrateVision;
        action verifyGripper;
        action homePosition;
        action parkArm;
        action closeGripper;
        action stopFeeder;
        action saveLogs;
        action freezeArm;
        action releaseGripper;
        action logFaultEvent;

        action initializeSystem {
            action calibrateArm;
            action calibrateVision;
            action verifyGripper;
            action homePosition;
        }

        action shutdownSystem {
            action parkArm;
            action closeGripper;
            action stopFeeder;
            action saveLogs;
        }

        action emergencyStop {
            action freezeArm;
            action releaseGripper;
            action stopFeeder;
            action logFaultEvent;
        }

        state systemStateMachine {
            state idle;
            state scanning;
            state acquiring;
            state assembling;
            state inspecting;
            state fault;

            transition from idle to scanning when startCommand == "start";
            transition from scanning to acquiring when componentDetected == true;
            transition from acquiring to assembling when componentHeld == true;
            transition from assembling to inspecting when componentPlaced == true;
            transition from inspecting to idle when qualityVerified == true;
            transition from inspecting to fault when qualityVerified == false;
            transition from scanning to fault when faultActive == true;
            transition from acquiring to fault when faultActive == true;
            transition from assembling to fault when faultActive == true;
            transition from fault to idle when faultCleared == true;
        }
    }
}
