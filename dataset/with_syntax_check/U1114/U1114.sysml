package 'KUKA Robotic Manufacturing Cell' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def JointPosition {
        attribute j1 : Real;
        attribute j2 : Real;
        attribute j3 : Real;
        attribute j4 : Real;
        attribute j5 : Real;
        attribute j6 : Real;
    }
    
    attribute def CartesianPosition {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute rx : Real;
        attribute ry : Real;
        attribute rz : Real;
    }
    
    attribute def VelocityProfile {
        attribute linear : SpeedValue;
        attribute angular : Real;
    }
    
    attribute def GripperState {
        attribute opening : LengthValue;
        attribute force : ForceValue;
        attribute isGrasping : Boolean;
    }
    
    item def MotionProgram {
        attribute programID : String;
        attribute waypoints : CartesianPosition[*];
        attribute velocity : VelocityProfile;
    }
    
    item def WorkpieceData {
        attribute partID : String;
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute location : CartesianPosition;
    }
    
    item def SafetySignal {
        attribute emergencyStop : Boolean;
        attribute safetyZoneViolation : Boolean;
        attribute doorOpen : Boolean;
    }
    
    port def ControlBusPort {
        in item program : MotionProgram;
        out attribute status : String;
        out attribute currentPosition : CartesianPosition;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : Real;
        in attribute current : ElectricCurrentValue;
        out attribute powerConsumption : PowerValue;
    }
    
    port def SafetyInterfacePort {
        in item safetySignal : SafetySignal;
        out attribute safetyStatus : Boolean;
    }
    
    port def VisionSystemPort {
        out item workpieceData : WorkpieceData;
        in attribute captureCommand : Boolean;
    }
    
    port def GripperControlPort {
        in attribute targetOpening : LengthValue;
        in attribute targetForce : ForceValue;
        out attribute gripperState : GripperState;
    }
    
    part def RobotController {
        port controlBus : ControlBusPort;
        port safetyInterface : SafetyInterfacePort;
        
        attribute currentProgram : MotionProgram;
        attribute operationalMode : String;
        
        action def ExecuteProgram {
            in program : MotionProgram;
            out jointCommands : JointPosition[*];
        }
        
        action def MonitorSafety {
            in safety : SafetySignal;
            out halt : Boolean;
        }
        
        action def ComputeInverseKinematics {
            in targetPose : CartesianPosition;
            out jointAngles : JointPosition;
        }
    }
    
    part def ManipulatorArm {
        attribute reachRadius : LengthValue;
        attribute payloadCapacity : MassValue;
        attribute repeatability : LengthValue;
        
        part base : BaseJoint {
            attribute :>> maxTorque = 350.0;
            attribute :>> rangeMin = -185.0;
            attribute :>> rangeMax = 185.0;
        }
        
        part shoulder : ShoulderJoint {
            attribute :>> maxTorque = 350.0;
            attribute :>> rangeMin = -140.0;
            attribute :>> rangeMax = 5.0;
        }
        
        part elbow : ElbowJoint {
            attribute :>> maxTorque = 176.0;
            attribute :>> rangeMin = -120.0;
            attribute :>> rangeMax = 156.0;
        }
        
        part wrist1 : WristJoint1 {
            attribute :>> maxTorque = 176.0;
            attribute :>> rangeMin = -350.0;
            attribute :>> rangeMax = 350.0;
        }
        
        part wrist2 : WristJoint2 {
            attribute :>> maxTorque = 110.0;
            attribute :>> rangeMin = -130.0;
            attribute :>> rangeMax = 130.0;
        }
        
        part wrist3 : WristJoint3 {
            attribute :>> maxTorque = 110.0;
            attribute :>> rangeMin = -350.0;
            attribute :>> rangeMax = 350.0;
        }
        
        part def BaseJoint :> RotaryJoint;
        part def ShoulderJoint :> RotaryJoint;
        part def ElbowJoint :> RotaryJoint;
        part def WristJoint1 :> RotaryJoint;
        part def WristJoint2 :> RotaryJoint;
        part def WristJoint3 :> RotaryJoint;
        
        part def RotaryJoint {
            attribute currentAngle : Real;
            attribute targetAngle : Real;
            attribute maxTorque : TorqueValue;
            attribute rangeMin : Real;
            attribute rangeMax : Real;
            
            port motorControl {
                in attribute commandTorque : TorqueValue;
                out attribute feedbackAngle : Real;
                out attribute feedbackVelocity : Real;
            }
        }
    }
    
    part def PneumaticGripper {
        port gripperControl : GripperControlPort;
        
        attribute maxOpening : LengthValue;
        attribute maxGripForce : ForceValue;
        attribute currentState : GripperState;
        
        action def Grasp {
            in targetForce : ForceValue;
            out success : Boolean;
        }
        
        action def Release {
            out opened : Boolean;
        }
    }
    
    part def VisionSystem {
        port visionInterface : VisionSystemPort;
        
        attribute resolution : Integer[2];
        attribute fieldOfView : Real;
        
        action def CaptureImage {
            out imageData : String;
        }
        
        action def DetectWorkpiece {
            in imageData : String;
            out workpiece : WorkpieceData;
        }
    }
    
    part def SafetyController {
        port safetyIO : SafetyInterfacePort;
        
        attribute workspaceMinX : LengthValue;
        attribute workspaceMaxX : LengthValue;
        attribute workspaceMinY : LengthValue;
        attribute workspaceMaxY : LengthValue;
        attribute workspaceMinZ : LengthValue;
        attribute workspaceMaxZ : LengthValue;
        
        action def CheckWorkspaceBounds {
            in position : CartesianPosition;
            out withinBounds : Boolean;
        }
        
        action def ProcessEmergencyStop {
            in signal : SafetySignal;
            out stopCommand : Boolean;
        }
    }
    
    part def PowerDistributionUnit {
        port mainPower : PowerSupplyPort;
        
        attribute inputVoltage : Real;
        attribute maxCurrent : ElectricCurrentValue;
        attribute totalPower : PowerValue;
    }
    
    requirement def SystemFunction {
        doc /* The KUKA robotic manufacturing cell shall autonomously perform 
                precision assembly operations by identifying workpieces, 
                retrieving them from input stations, and placing them at 
                designated assembly locations with high repeatability. */
    }
    
    requirement def PositioningAccuracy {
        doc /* The robot shall achieve positioning repeatability within 0.03mm 
                under rated payload conditions. */
        attribute maxDeviation : LengthValue;
    }
    
    requirement def PayloadHandling {
        doc /* The robot shall handle payloads up to 16kg at full reach 
                without degradation in accuracy. */
        attribute maxPayload : MassValue;
    }
    
    requirement def CycleTimePerformance {
        doc /* The system shall complete a standard pick-and-place cycle 
                within 3.5 seconds. */
        attribute maxCycleTime : TimeValue;
    }
    
    requirement def SafetyCompliance {
        doc /* The system shall comply with ISO 10218-1 and ISO 10218-2 
                for industrial robot safety. */
        
        requirement emergencyStopResponse {
            doc /* Emergency stop shall halt all motion within 50ms. */
        }
        
        requirement workspaceMonitoring {
            doc /* Safety system shall monitor workspace boundaries at 100Hz. */
        }
        
        requirement collaborativeSafety {
            doc /* Force limiting shall activate when contact force exceeds 150N. */
        }
    }
    
    action def PickAndPlaceAssembly {
        in inputStation : CartesianPosition;
        in assemblyStation : CartesianPosition;
        in homePosition : CartesianPosition;
        out cycleComplete : Boolean;
        
        first start;
        then merge initialize;
        
        action initialize {
            doc /* Initialize system and verify safety conditions */
        }
        then scanWorkpiece;
        
        action scanWorkpiece : VisionSystem::DetectWorkpiece {
            in imageData = "captured";
            out workpiece;
        }
        then decide;
            if true then moveToPickup;
        
        action moveToPickup : MoveToTarget {
            in target = inputStation;
            out arrived : Boolean;
        }
        then action approachWorkpiece : MoveToTarget {
            in target = inputStation;
            out arrived : Boolean;
        }
        then action graspPart : PneumaticGripper::Grasp {
            in targetForce = 80.0 [N];
            out success;
        }
        then decide;
            if graspPart.success then liftPart;
        
        action liftPart : MoveToTarget {
            in target = inputStation;
            out arrived : Boolean;
        }
        then action moveToAssembly : MoveToTarget {
            in target = assemblyStation;
            out arrived : Boolean;
        }
        then action placePart : MoveToTarget {
            in target = assemblyStation;
            out arrived : Boolean;
        }
        then action releasePart : PneumaticGripper::Release {
            out opened;
        }
        then action retractFromAssembly : MoveToTarget {
            in target = assemblyStation;
            out arrived : Boolean;
        }
        then action returnHome : MoveToTarget {
            in target = homePosition;
            out arrived : Boolean;
        }
        then assign cycleComplete := true;
        then done;
    }
    
    action def MoveToTarget {
        in target : CartesianPosition;
        out arrived : Boolean;
        
        action planPath : RobotController::ComputeInverseKinematics {
            in targetPose = target;
            out jointAngles;
        }
        
        action executeMotion {
            in joints : JointPosition;
            out finalPosition : CartesianPosition;
        }
        
        action verifyArrival {
            in current : CartesianPosition;
            in desired : CartesianPosition;
            out withinTolerance : Boolean;
        }
        
        first planPath;
        then executeMotion;
        then verifyArrival;
        then assign arrived := verifyArrival.withinTolerance;
    }
    
    state def RobotOperationMode {
        entry; then powerOn;
        
        state powerOn {
            entry assign systemVoltage := 400.0;
        }
        accept at powerOn SystemInitialized;
        then standby;
        
        state standby {
            entry assign motorsPowered := false;
        }
        accept at standby StartProduction;
        then automatic;
        
        state automatic {
            entry assign motorsPowered := true;
            
            state executing {
                do action currentCycle : PickAndPlaceAssembly;
            }
            
            transition first executing then waitingForWorkpiece;
            
            state waitingForWorkpiece;
            accept at waitingForWorkpiece WorkpieceDetected;
            then executing;
        }
        
        accept at automatic PauseRequested;
        then paused;
        
        state paused {
            entry assign motorsPowered := false;
        }
        accept at paused ResumeRequested;
        then automatic;
        
        accept at automatic EmergencyStopActivated;
        then emergency;
        
        state emergency {
            entry assign motorsPowered := false;
            entry assign brakesEngaged := true;
        }
        
        accept at emergency SafetyReset
        if safetyConditionsClear
        then standby;
        
        attribute systemVoltage : Real;
        attribute motorsPowered : Boolean;
        attribute brakesEngaged : Boolean;
        attribute safetyConditionsClear : Boolean;
        
        event SystemInitialized;
        event StartProduction;
        event WorkpieceDetected;
        event PauseRequested;
        event ResumeRequested;
        event EmergencyStopActivated;
        event SafetyReset;
    }
    
    part def KUKAManufacturingCell {
        attribute cellID : String;
        attribute workspaceVolume : Real;
        
        part controller : RobotController {
            port :>> controlBus;
            port :>> safetyInterface;
            attribute :>> operationalMode = "Automatic";
        }
        
        part manipulator : ManipulatorArm {
            attribute :>> reachRadius = 2010.0 [mm];
            attribute :>> payloadCapacity = 16.0 [kg];
            attribute :>> repeatability = 0.03 [mm];
        }
        
        part gripper : PneumaticGripper {
            port :>> gripperControl;
            attribute :>> maxOpening = 85.0 [mm];
            attribute :>> maxGripForce = 200.0 [N];
        }
        
        part vision : VisionSystem {
            port :>> visionInterface;
            attribute :>> resolution = (1920, 1080);
            attribute :>> fieldOfView = 45.0;
        }
        
        part safety : SafetyController {
            port :>> safetyIO;
            attribute :>> workspaceMinX = -1500.0 [mm];
            attribute :>> workspaceMaxX = 1500.0 [mm];
            attribute :>> workspaceMinY = -1500.0 [mm];
            attribute :>> workspaceMaxY = 1500.0 [mm];
            attribute :>> workspaceMinZ = -200.0 [mm];
            attribute :>> workspaceMaxZ = 2200.0 [mm];
        }
        
        part power : PowerDistributionUnit {
            port :>> mainPower;
            attribute :>> inputVoltage = 400.0;
            attribute :>> maxCurrent = 32.0 [A];
            attribute :>> totalPower = 12.8 [kW];
        }
        
        connect controller.controlBus to manipulator;
        connect controller.safetyInterface to safety.safetyIO;
        connect gripper.gripperControl to controller;
        connect vision.visionInterface to controller;
        connect power.mainPower to controller;
        connect power.mainPower to manipulator;
        
        perform action assemblyOperation : PickAndPlaceAssembly;
        
        exhibit state operationMode : RobotOperationMode;
    }
    
    part kukaManufacturingCell : KUKAManufacturingCell {
        doc /* 
            KUKA KR 16 R2010 based robotic manufacturing cell for automated 
            precision assembly operations. The system integrates a 6-axis 
            industrial manipulator with vision guidance and pneumatic gripping 
            to autonomously identify, retrieve, and place workpieces with 
            high repeatability and throughput.
        */
        
        attribute :>> cellID = "KUKA_CELL_001";
        attribute :>> workspaceVolume = 4.5;
    }
}
