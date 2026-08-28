package IndustrialRoboticWorkCell {

    import ScalarValues::*;

    // =========================================================
    // UNIT DEFINITIONS
    // =========================================================
    unit kilogram;
    unit meter;
    unit newton;
    unit newton_meter;
    unit degree;
    unit degree_per_second;
    unit meter_per_second;
    unit second;
    unit watt;
    unit hertz;

    // =========================================================
    // VALUE TYPES WITH UNITS
    // =========================================================
    value type MassValue :> Real {
        :>> unit = kilogram;
    }
    value type LengthValue :> Real {
        :>> unit = meter;
    }
    value type ForceValue :> Real {
        :>> unit = newton;
    }
    value type TorqueValue :> Real {
        :>> unit = newton_meter;
    }
    value type AngleValue :> Real {
        :>> unit = degree;
    }
    value type AngularVelocityValue :> Real {
        :>> unit = degree_per_second;
    }
    value type LinearVelocityValue :> Real {
        :>> unit = meter_per_second;
    }
    value type TimeValue :> Real {
        :>> unit = second;
    }
    value type PowerValue :> Real {
        :>> unit = watt;
    }
    value type FrequencyValue :> Real {
        :>> unit = hertz;
    }

    value type Pose {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    value type JointAngleVector {
        attribute j1 : AngleValue;
        attribute j2 : AngleValue;
        attribute j3 : AngleValue;
        attribute j4 : AngleValue;
        attribute j5 : AngleValue;
        attribute j6 : AngleValue;
    }

    // =========================================================
    // ITEM DEFINITIONS
    // =========================================================
    item def Workpiece {
        attribute partId : String;
        attribute mass : MassValue;
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
        attribute material : String;
    }

    item def DetectedWorkpiece :> Workpiece {
        attribute pose : Pose;
        attribute detectionConfidence : Real;
    }

    item def RobotCommand {
        attribute targetPose : Pose;
        attribute gripAction : String;
        attribute gripForce : ForceValue;
        attribute motionSpeed : LinearVelocityValue;
    }

    // =========================================================
    // PORT DEFINITIONS
    // =========================================================
    port def MotionCommandPort {
        in command : RobotCommand;
    }

    port def FeedbackPort {
        in jointAngles : JointAngleVector;
        in endEffectorPose : Pose;
        in operationalStatus : String;
    }

    port def VisionDataPort {
        in detectedWorkpiece : DetectedWorkpiece;
    }

    port def SafetySignalPort {
        in emergencyStopTriggered : Boolean;
        in lightCurtainBroken : Boolean;
        in safeToOperate : Boolean;
    }

    port def SafetyCommandPort {
        in haltMotion : Boolean;
        in enableMotion : Boolean;
    }

    port def WorkpieceFlowPort {
        in workpiece : Workpiece;
    }

    port def ConveyorControlPort {
        in runConveyor : Boolean;
    }

    // =========================================================
    // PART DEFINITIONS - SUBCOMPONENTS
    // =========================================================
    part def ServoMotor {
        attribute jointIndex : Integer;
        attribute maxTorque : TorqueValue;
        attribute maxAngularVelocity : AngularVelocityValue;
        attribute ratedPower : PowerValue;
        attribute currentAngle : AngleValue;
        attribute currentTorque : TorqueValue;
        port motionCommandIn : MotionCommandPort;
        port feedbackOut : ~FeedbackPort;
    }

    part def Joint {
        attribute jointId : Integer;
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        attribute currentAngle : AngleValue;
        part servoMotor : ServoMotor;
    }

    part def AdaptiveGripper {
        attribute maxGripForce : ForceValue;
        attribute minGripForce : ForceValue;
        attribute strokeLength : LengthValue;
        attribute currentGripForce : ForceValue;
        attribute isOpen : Boolean;
        attribute grippingWorkpiece : Boolean;
        port gripCommandIn : MotionCommandPort;
        port workpieceIn : WorkpieceFlowPort;
        port workpieceOut : ~WorkpieceFlowPort;
    }

    part def FANUCRobotArm {
        attribute modelDesignation : String;
        attribute maxReach : LengthValue;
        attribute payloadCapacity : MassValue;
        attribute degreesOfFreedom : Integer;
        attribute mountingPose : Pose;
        attribute currentEndEffectorPose : Pose;
        attribute currentPayload : MassValue;
        attribute emergencyStopActive : Boolean;

        part joints : Joint[6];
        part gripper : AdaptiveGripper;

        port motionCommandIn : MotionCommandPort;
        port feedbackOut : ~FeedbackPort;
        port safetyCommandIn : SafetyCommandPort;

        state machine robotOperatingState {
            initial state Idle;
            state MovingToPick;
            state Gripping;
            state MovingToPlace;
            state Releasing;
            state Halted;

            transition from Idle to MovingToPick
                when motionCommandIn.command.gripAction == "close";
            transition from MovingToPick to Gripping
                when currentEndEffectorPose == motionCommandIn.command.targetPose;
            transition from Gripping to MovingToPlace
                when gripper.currentGripForce >= motionCommandIn.command.gripForce;
            transition from MovingToPlace to Releasing
                when currentEndEffectorPose == motionCommandIn.command.targetPose;
            transition from Releasing to Idle
                when gripper.isOpen;
            transition from Idle to Halted
                when safetyCommandIn.haltMotion;
            transition from MovingToPick to Halted
                when safetyCommandIn.haltMotion;
            transition from Gripping to Halted
                when safetyCommandIn.haltMotion;
            transition from MovingToPlace to Halted
                when safetyCommandIn.haltMotion;
            transition from Releasing to Halted
                when safetyCommandIn.haltMotion;
            transition from Halted to Idle
                when safetyCommandIn.enableMotion;
        }
    }

    part def RobotController {
        attribute processingFrequency : FrequencyValue;
        attribute currentProgramName : String;
        attribute safetyArmed : Boolean;
        attribute targetPickPose : Pose;
        attribute targetPlacePose : Pose;
        attribute motionPlanReady : Boolean;
        attribute cycleInProgress : Boolean;

        port motionCommandOut : ~MotionCommandPort;
        port feedbackIn : FeedbackPort;
        port visionDataIn : VisionDataPort;
        port safetyCommandOut : ~SafetyCommandPort;
        port conveyorControlOut : ~ConveyorControlPort;
        port safetyCommandIn : SafetyCommandPort;

        state machine controllerState {
            initial state Initializing;
            state Idle;
            state WaitingForPart;
            state PlanningMotion;
            state ExecutingMotion;
            state CycleComplete;

            transition from Initializing to Idle
                when safetyArmed;
            transition from Idle to WaitingForPart
                when safetyArmed;
            transition from WaitingForPart to PlanningMotion
                when visionDataIn.detectedWorkpiece.detectionConfidence > 0.9;
            transition from PlanningMotion to ExecutingMotion
                when motionPlanReady;
            transition from ExecutingMotion to CycleComplete
                when feedbackIn.operationalStatus == "complete";
            transition from CycleComplete to WaitingForPart
                when conveyorControlOut.runConveyor;
        }
    }

    part def VisionSensor {
        attribute resolutionX : Integer;
        attribute resolutionY : Integer;
        attribute frameRate : FrequencyValue;
        attribute fieldOfView : AngleValue;
        attribute detectionRange : LengthValue;
        attribute calibrationPose : Pose;
        port visionDataOut : ~VisionDataPort;
    }

    part def InputConveyor {
        attribute beltLength : LengthValue;
        attribute beltWidth : LengthValue;
        attribute beltSpeed : LinearVelocityValue;
        attribute isRunning : Boolean;
        attribute workpiecePresent : Boolean;
        port workpieceOut : ~WorkpieceFlowPort;
        port conveyorControlIn : ConveyorControlPort;

        state machine conveyorState {
            initial state Stopped;
            state Running;
            state StoppedForInspection;

            transition from Stopped to Running
                when conveyorControlIn.runConveyor;
            transition from Running to StoppedForInspection
                when workpiecePresent;
            transition from StoppedForInspection to Running
                when conveyorControlIn.runConveyor;
            transition from Running to Stopped
                when !conveyorControlIn.runConveyor;
        }
    }

    part def OutputWorkstation {
        attribute stationId : String;
        attribute targetPose : Pose;
        attribute partsProcessed : Integer;
        attribute maxCapacity : Integer;
        port workpieceIn : WorkpieceFlowPort;
    }

    part def SafetyController {
        attribute monitoringInterval : TimeValue;
        attribute safetyRelayActive : Boolean;
        attribute standardCompliance : String;
        attribute responseTime : TimeValue;
        port safetySignalIn : SafetySignalPort;
        port safetyCommandOut : ~SafetyCommandPort;

        state machine safetyMonitoringState {
            initial state Operational;
            state LightCurtainTripped;
            state EmergencyStopTripped;
            state Resetting;

            transition from Operational to LightCurtainTripped
                when safetySignalIn.lightCurtainBroken;
            transition from Operational to EmergencyStopTripped
                when safetySignalIn.emergencyStopTriggered;
            transition from LightCurtainTripped to Resetting
                when !safetySignalIn.lightCurtainBroken;
            transition from EmergencyStopTripped to Resetting
                when !safetySignalIn.emergencyStopTriggered;
            transition from Resetting to Operational
                when safetySignalIn.safeToOperate;
        }
    }

    part def LightCurtain {
        attribute curtainLength : LengthValue;
        attribute responseTime : TimeValue;
        attribute isBroken : Boolean;
        attribute mountingHeight : LengthValue;
        port safetySignalOut : ~SafetySignalPort;
    }

    part def EmergencyStopButton {
        attribute isPressed : Boolean;
        attribute label : String;
        attribute resetType : String;
        port safetySignalOut : ~SafetySignalPort;
    }

    // =========================================================
    // ACTION DEFINITIONS
    // =========================================================
    action def PickAndPlaceCycle {
        in workpiece : Workpiece;
        attribute pickPose : Pose;
        attribute placePose : Pose;
        attribute cycleStartTime : TimeValue;

        action detectPart {
            out detectedWorkpiece : DetectedWorkpiece;
        }
        action planMotionPath {
            in detectedWorkpiece : DetectedWorkpiece;
            out motionCommand : RobotCommand;
        }
        action executePick {
            in motionCommand : RobotCommand;
            out pickedWorkpiece : Workpiece;
        }
        action executePlace {
            in pickedWorkpiece : Workpiece;
            in placePose : Pose;
        }
        action releasePart {
            out releasedWorkpiece : Workpiece;
        }

        flow from detectPart.detectedWorkpiece to planMotionPath.detectedWorkpiece;
        flow from planMotionPath.motionCommand to executePick.motionCommand;
        flow from executePick.pickedWorkpiece to executePlace.pickedWorkpiece;
        flow from executePlace.pickedWorkpiece to releasePart.releasedWorkpiece;
    }

    action def DetectWorkpieceAction {
        in conveyorImage : String;
        out detectedWorkpiece : DetectedWorkpiece;
        attribute processingTime : TimeValue;
    }

    // =========================================================
    // TOP-LEVEL WORK CELL
    // =========================================================
    part def RoboticWorkCell {
        attribute workCellId : String;
        attribute productionCycleCount : Integer;
        attribute manufacturer : String;
        attribute operational : Boolean;

        part robotArm : FANUCRobotArm {
            attribute modelDesignation = "FANUC R-2000iC/210F";
            attribute maxReach : LengthValue = 1.8;
            attribute payloadCapacity : MassValue = 25;
            attribute degreesOfFreedom = 6;
        }

        part robotController : RobotController {
            attribute processingFrequency : FrequencyValue = 500;
            attribute currentProgramName = "PickAndPlace_v3";
        }

        part visionSensor : VisionSensor {
            attribute resolutionX = 2448;
            attribute resolutionY = 2048;
            attribute frameRate : FrequencyValue = 60;
            attribute fieldOfView : AngleValue = 60;
            attribute detectionRange : LengthValue = 1.0;
        }

        part inputConveyor : InputConveyor {
            attribute beltLength : LengthValue = 2.0;
            attribute beltWidth : LengthValue = 0.4;
            attribute beltSpeed : LinearVelocityValue = 0.2;
        }

        part outputWorkstation : OutputWorkstation {
            attribute stationId = "WS-001";
            attribute maxCapacity = 50;
        }

        part safetyController : SafetyController {
            attribute monitoringInterval : TimeValue = 0.01;
            attribute responseTime : TimeValue = 0.05;
            attribute standardCompliance = "ISO 10218-1";
        }

        part lightCurtain : LightCurtain {
            attribute curtainLength : LengthValue = 1.5;
            attribute responseTime : TimeValue = 0.02;
        }

        part emergencyStopButton : EmergencyStopButton {
            attribute label = "E-Stop Main";
            attribute resetType = "Manual";
        }

        // Connections - motion and feedback
        connect robotController.motionCommandOut to robotArm.motionCommandIn;
        connect robotArm.feedbackOut to robotController.feedbackIn;

        // Vision data
        connect visionSensor.visionDataOut to robotController.visionDataIn;

        // Conveyor control
        connect robotController.conveyorControlOut to inputConveyor.conveyorControlIn;

        // Workpiece flow
        connect inputConveyor.workpieceOut to robotArm.gripper.workpieceIn;
        connect robotArm.gripper.workpieceOut to outputWorkstation.workpieceIn;

        // Safety signals
        connect lightCurtain.safetySignalOut to safetyController.safetySignalIn;
        connect emergencyStopButton.safetySignalOut to safetyController.safetySignalIn;

        // Safety commands
        connect safetyController.safetyCommandOut to robotArm.safetyCommandIn;
        connect safetyController.safetyCommandOut to robotController.safetyCommandIn;

        perform action mainCycle : PickAndPlaceCycle;
    }

    // =========================================================
    // REQUIREMENTS
    // =========================================================
    requirement def ReachRequirement {
        doc "The robot arm shall have a maximum reach of at least 1.8 meters.";
        subject robotArm : FANUCRobotArm;
        attribute minReach : LengthValue = 1.8;
        objective {
            check robotArm.maxReach >= minReach;
        }
    }

    requirement def PayloadCapacityRequirement {
        doc "The robot arm shall handle workpieces weighing up to 25 kilograms.";
        subject robotArm : FANUCRobotArm;
        attribute minPayload : MassValue = 25;
        objective {
            check robotArm.payloadCapacity >= minPayload;
        }
    }

    requirement def SixAxisArticulationRequirement {
        doc "The robot arm shall be a six-axis articulated configuration.";
        subject robotArm : FANUCRobotArm;
        attribute requiredDoF : Integer = 6;
        objective {
            check robotArm.degreesOfFreedom == requiredDoF;
        }
    }

    requirement def HighTorqueServoRequirement {
        doc "Each of the six joints shall be powered by a high-torque servo motor.";
        subject robotArm : FANUCRobotArm;
        attribute jointCount : Integer = 6;
        objective {
            check robotArm.joints.size() == jointCount;
        }
    }

    requirement def AdaptiveGripperRequirement {
        doc "The adaptive gripper shall grasp and release workpieces with controlled force.";
        subject gripper : AdaptiveGripper;
        attribute minGripForce : ForceValue = 5;
        attribute maxGripForce : ForceValue = 80;
        objective {
            check gripper.minGripForce <= minGripForce;
            check gripper.maxGripForce >= maxGripForce;
        }
    }

    requirement def ControllerCoordinationRequirement {
        doc "The central robot controller shall coordinate all components and execute pre-programmed production cycles.";
        subject controller : RobotController;
        objective {
            check controller.safetyArmed == true;
        }
    }

    requirement def VisionDetectionRequirement {
        doc "The vision sensor shall identify workpieces arriving on the input conveyor, determining precise position and orientation.";
        subject vision : VisionSensor;
        attribute minDetectionRange : LengthValue = 1.0;
        objective {
            check vision.detectionRange >= minDetectionRange;
        }
    }

    requirement def AutonomousPickAndPlaceRequirement {
        doc "The work cell shall autonomously pick workpieces from the input conveyor and place them at the output workstation continuously.";
        subject workCell : RoboticWorkCell;
        objective {
            check workCell.operational == true;
        }
    }

    requirement def SafetyStopRequirement {
        doc "The safety controller shall instantly halt robot motion when safety devices are triggered.";
        subject safetyController : SafetyController;
        attribute maxResponseTime : TimeValue = 0.1;
        objective {
            check safetyController.responseTime <= maxResponseTime;
        }
    }

    requirement def IndustrialSafetyComplianceRequirement {
        doc "The work cell shall comply with industrial safety standards including light curtain and emergency stop monitoring.";
        subject workCell : RoboticWorkCell;
        attribute requiredStandard : String = "ISO 10218-1";
        objective {
            check workCell.safetyController.standardCompliance == requiredStandard;
        }
    }

    requirement def ConveyorDeliveryRequirement {
        doc "The input conveyor shall transport workpieces into the cell for processing.";
        subject conveyor : InputConveyor;
        objective {
            check conveyor.beltSpeed > 0;
        }
    }

    requirement def WorkCellSystemRequirements {
        doc "Complete set of requirements for the FANUC-based industrial robotic work cell.";

        requirement reachReq : ReachRequirement {
            :>> subject = workCell.robotArm;
        }
        requirement payloadReq : PayloadCapacityRequirement {
            :>> subject = workCell.robotArm;
        }
        requirement articulation2Req : Six2AxisArtic2ulationRequirement {
            :>> subject = workCell.robotArm;
        }
        requirement servoReq2 : High2TorqueServo2Requirement {
            :>> subject = workCell.robotArm;
        }
        requirement gripper2Req : AdaptiveGripper2Requirement {
            :>> subject = work2Cell.robot2Arm2.gripper;
        }
        requirement controllerReq2 : Controller2Coord2ination2Requirement {
            :>> subject = work2Cell2.robot2Controller;
        }
        requirement visionReq2 : Vision2Detection2Requirement2 {
            :>> subject = workCell.visionSensor;
        }
        requirement pick2PlaceReq2 :2 AutonomousPickAnd2Place2Requirement2 {
            :>> subject = workCell;
        }
        requirement safetyStop2Req : Safety2Stop2Requirement2 {
            :>> subject = workCell2.safety2Controller;
        }
        requirement safety2ComplianceReq2 : IndustrialSafety2Compliance2Requirement2 {
            :>> subject = workCell;
        }
        requirement conveyor2Req2 : ConveyorDelivery2Requirement2 {
            :>> subject2 = workCell.input2Conveyor;
        }

        part workCell : RoboticWorkCell2;
    }

    // Verification - the RoboticWorkCell satisfies WorkCellSystem2Requirements2
    satisfaction def WorkCellSatisfaction :> WorkCell2SystemRequirements2 {
        subject cell : RoboticWorkCell;
        :>> workCell = cell;
    }
}
