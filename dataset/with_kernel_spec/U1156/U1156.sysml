package IndustrialRoboticWorkCell {
    public import ScalarValues::*;

    attribute def AngleValue :> Real;
    attribute def AngularSpeedValue :> Real;
    attribute def ForceValue :> Real;
    attribute def LengthValue :> Real;
    attribute def MassValue :> Real;
    attribute def PowerValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def TimeValue :> Real;
    attribute def SpeedValue :> Real;

    item def Power;
    item def ControlData;
    item def ImageData;
    item def ProximityData {
        attribute distance : LengthValue;
        attribute detected : Boolean;
        attribute sensorId : Integer;
    }
    item def ObjectLocation {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    item def PathData;
    item def TrajectoryData;
    item def MotorCommand {
        attribute targetAngle : AngleValue;
        attribute targetSpeed : AngularSpeedValue;
        attribute torqueLimit : TorqueValue;
    }
    item def EncoderFeedback {
        attribute currentAngle : AngleValue;
        attribute currentSpeed : AngularSpeedValue;
    }
    item def GripperCommand {
        attribute targetForce : ForceValue;
        attribute openClose : Boolean;
    }
    item def ForceReading {
        attribute measuredForce : ForceValue;
    }
    item def EmergencyStopData {
        attribute reason : String;
    }

    attribute def StartAuto;
    attribute def StopAuto;
    attribute def StartManual;
    attribute def EmergencyTrigger;
    attribute def ResetSystem;
    attribute def StartTask;
    attribute def ObjectLocated;
    attribute def PathReady;
    attribute def TrajectoryReady;
    attribute def AtPickPose;
    attribute def ObjectGrasped;
    attribute def AtPlacePose;
    attribute def ObjectReleased;

    port def PowerPort {
        out power : Power;
    }
    port def DataPort {
        in dataIn : ControlData;
        out dataOut : ControlData;
    }
    port def ImagePort {
        out image : ImageData;
    }
    port def LocationPort {
        out location : ObjectLocation;
    }
    port def ProximityPort {
        out proximity : ProximityData;
    }
    port def MotorCmdPort {
        out command : MotorCommand;
    }
    port def EncoderFeedbackPort {
        out feedback : EncoderFeedback;
    }
    port def GripperCmdPort {
        out command : GripperCommand;
    }
    port def ForceReadingPort {
        out force : ForceReading;
    }
    port def PathPort {
        out path : PathData;
    }
    port def TrajectoryPort {
        out trajectory : TrajectoryData;
    }
    port def EmergencyStopPort {
        out estop : EmergencyStopData;
    }

    action def drive {
        in cmd : MotorCommand;
        out feedback : EncoderFeedback;
        first start;
        then done;
    }
    action def measurePosition {
        out feedback : EncoderFeedback;
        first start;
        then done;
    }
    action def moveJoint {
        in cmd : MotorCommand;
        out feedback : EncoderFeedback;
        first start;
        then done;
    }
    action def actuate {
        in cmd : GripperCommand;
        first start;
        then done;
    }
    action def measureForce {
        out force : ForceReading;
        first start;
        then done;
    }
    action def graspObject {
        in cmd : GripperCommand;
        out force : ForceReading;
        first start;
        then done;
    }
    action def releaseObject {
        in cmd : GripperCommand;
        first start;
        then done;
    }
    action def captureImage {
        out image : ImageData;
        first start;
        then done;
    }
    action def processImage {
        in image : ImageData;
        out location : ObjectLocation;
        first start;
        then done;
    }
    action def detectObstacle {
        out proximity : ProximityData;
        first start;
        then done;
    }
    action def senseEnvironment {
        out location : ObjectLocation;
        first start;
        then done;
    }
    action def calculatePath {
        in target : ObjectLocation;
        out path : PathData;
        first start;
        then done;
    }
    action def generateTrajectory {
        in path : PathData;
        out trajectory : TrajectoryData;
        first start;
        then done;
    }
    action def controlJoints {
        in trajectory : TrajectoryData;
        first start;
        then done;
    }
    action def controlGripper {
        in forceTarget : ForceValue;
        out cmd : GripperCommand;
        first start;
        then done;
    }
    action def monitorSafety {
        in force : ForceReading;
        out estop : EmergencyStopData;
        first start;
        then done;
    }
    action def executeTrajectory {
        in trajectory : TrajectoryData;
        first start;
        then done;
    }
    action def moveToPick {
        in trajectory : TrajectoryData;
        first start;
        then done;
    }
    action def moveToPlace {
        in trajectory : TrajectoryData;
        first start;
        then done;
    }
    action def orchestrateTask {
        in target : ObjectLocation;
        first start;
        then done;
    }
    action def supplyPower {
        first start;
        then done;
    }
    action def exchangeData {
        first start;
        then done;
    }
    action def PickAndPlaceTask {
        in targetLocation : ObjectLocation;
        in dropoffLocation : ObjectLocation;
        first start;
        then sense;
        action sense : senseEnvironment;
        then planPick;
        action planPick : calculatePath;
        then generatePick;
        action generatePick : generateTrajectory;
        then executePick;
        action executePick : moveToPick;
        then grasp;
        action grasp : graspObject;
        then planPlace;
        action planPlace : calculatePath;
        then generatePlace;
        action generatePlace : generateTrajectory;
        then executePlace;
        action executePlace : moveToPlace;
        then release;
        action release : releaseObject;
        then done;
    }

    part def Motor {
        port cmdPort : MotorCmdPort;
        port powerPort : PowerPort;
        perform action drive;
    }

    part def Encoder {
        port feedbackPort : EncoderFeedbackPort;
        perform action measurePosition;
    }

    part def Joint {
        attribute jointId : Integer;
        attribute angle : AngleValue;
        attribute angularSpeed : AngularSpeedValue;
        port cmdPort : MotorCmdPort;
        port feedbackPort : EncoderFeedbackPort;
        port powerPort : PowerPort;
        part motor : Motor;
        part encoder : Encoder;
        bind cmdPort = motor.cmdPort;
        bind feedbackPort = encoder.feedbackPort;
        bind powerPort = motor.powerPort;
        perform action moveJoint;
    }

    part def Link {
        attribute length : LengthValue;
        attribute mass : MassValue;
    }

    part def Actuator {
        port cmdPort : GripperCmdPort;
        port powerPort : PowerPort;
        perform action actuate;
    }

    part def ForceSensor {
        port forcePort : ForceReadingPort;
        perform action measureForce;
    }

    part def Gripper {
        attribute maxForce : ForceValue;
        part finger1 : Link;
        part finger2 : Link;
        part actuator : Actuator;
        part forceSensor : ForceSensor;
        port cmdPort : GripperCmdPort;
        port forcePort : ForceReadingPort;
        bind cmdPort = actuator.cmdPort;
        bind forcePort = forceSensor.forcePort;
        perform action graspObject;
        perform action releaseObject;
    }

    part def RoboticArm {
        attribute reach : LengthValue;
        attribute payload : MassValue;
        attribute repeatability : LengthValue;
        part baseLink : Link;
        part shoulderLink : Link;
        part elbowLink : Link;
        part wristLink : Link;
        part baseJoint : Joint;
        part shoulderJoint : Joint;
        part elbowJoint : Joint;
        part wristJoint : Joint;
        part gripper : Gripper;
        port jointCmdPort1 : MotorCmdPort;
        port jointCmdPort2 : MotorCmdPort;
        port jointCmdPort3 : MotorCmdPort;
        port jointCmdPort4 : MotorCmdPort;
        port jointFbPort1 : EncoderFeedbackPort;
        port jointFbPort2 : EncoderFeedbackPort;
        port jointFbPort3 : EncoderFeedbackPort;
        port jointFbPort4 : EncoderFeedbackPort;
        port gripperCmdPort : GripperCmdPort;
        port gripperForcePort : ForceReadingPort;
        port powerPort : PowerPort;
        bind baseJoint.cmdPort = jointCmdPort1;
        bind shoulderJoint.cmdPort = jointCmdPort2;
        bind elbowJoint.cmdPort = jointCmdPort3;
        bind wristJoint.cmdPort = jointCmdPort4;
        bind baseJoint.feedbackPort = jointFbPort1;
        bind shoulderJoint.feedbackPort = jointFbPort2;
        bind elbowJoint.feedbackPort = jointFbPort3;
        bind wristJoint.feedbackPort = jointFbPort4;
        bind gripper.cmdPort = gripperCmdPort;
        bind gripper.forcePort = gripperForcePort;
        perform action executeTrajectory;
        perform action moveToPick;
        perform action moveToPlace;
    }

    part def Camera {
        port imagePort : ImagePort;
        port powerPort : PowerPort;
        perform action captureImage;
    }

    part def ImageProcessor {
        port imageInPort : ImagePort;
        port locationOutPort : LocationPort;
        port powerPort : PowerPort;
        perform action processImage;
    }

    part def ProximitySensor {
        attribute sensorId : Integer;
        port proximityPort : ProximityPort;
        port powerPort : PowerPort;
        perform action detectObstacle;
    }

    part def PerceptionSystem {
        port powerPort : PowerPort;
        port imgPort : ImagePort;
        port locPort : LocationPort;
        port proxPort1 : ProximityPort;
        port proxPort2 : ProximityPort;
        port proxPort3 : ProximityPort;
        port proxPort4 : ProximityPort;
        part camera : Camera;
        part imageProcessor : ImageProcessor;
        part proxSensor1 : ProximitySensor;
        part proxSensor2 : ProximitySensor;
        part proxSensor3 : ProximitySensor;
        part proxSensor4 : ProximitySensor;
        bind camera.imagePort = imgPort;
        bind imageProcessor.imageInPort = camera.imagePort;
        bind imageProcessor.locationOutPort = locPort;
        bind proxSensor1.proximityPort = proxPort1;
        bind proxSensor2.proximityPort = proxPort2;
        bind proxSensor3.proximityPort = proxPort3;
        bind proxSensor4.proximityPort = proxPort4;
        perform action senseEnvironment;
    }

    part def MotionPlanner {
        port targetInPort : LocationPort;
        port proxInPort1 : ProximityPort;
        port proxInPort2 : ProximityPort;
        port proxInPort3 : ProximityPort;
        port proxInPort4 : ProximityPort;
        port pathOutPort : PathPort;
        perform action calculatePath;
    }

    part def TrajectoryGenerator {
        port pathInPort : PathPort;
        port trajOutPort : TrajectoryPort;
        perform action generateTrajectory;
    }

    part def JointController {
        port trajInPort : TrajectoryPort;
        port fbInPort1 : EncoderFeedbackPort;
        port fbInPort2 : EncoderFeedbackPort;
        port fbInPort3 : EncoderFeedbackPort;
        port fbInPort4 : EncoderFeedbackPort;
        port cmdOutPort1 : MotorCmdPort;
        port cmdOutPort2 : MotorCmdPort;
        port cmdOutPort3 : MotorCmdPort;
        port cmdOutPort4 : MotorCmdPort;
        port gripCmdOutPort : GripperCmdPort;
        perform action controlJoints;
        perform action controlGripper;
    }

    part def SafetyController {
        port forceInPort : ForceReadingPort;
        port proxInPort1 : ProximityPort;
        port proxInPort2 : ProximityPort;
        port proxInPort3 : ProximityPort;
        port proxInPort4 : ProximityPort;
        port fbInPort1 : EncoderFeedbackPort;
        port fbInPort2 : EncoderFeedbackPort;
        port fbInPort3 : EncoderFeedbackPort;
        port fbInPort4 : EncoderFeedbackPort;
        port estopOutPort : EmergencyStopPort;
        attribute maxForceLimit : ForceValue = 50;
        attribute maxSpeedLimit : AngularSpeedValue = 2.0;
        attribute minProximityDistance : LengthValue = 0.05;
        perform action monitorSafety;
    }

    part def ControlModule {
        port powerPort : PowerPort;
        port imgInPort : ImagePort;
        port locInPort : LocationPort;
        port proxInPort1 : ProximityPort;
        port proxInPort2 : ProximityPort;
        port proxInPort3 : ProximityPort;
        port proxInPort4 : ProximityPort;
        port jointFbInPort1 : EncoderFeedbackPort;
        port jointFbInPort2 : EncoderFeedbackPort;
        port jointFbInPort3 : EncoderFeedbackPort;
        port jointFbInPort4 : EncoderFeedbackPort;
        port jointCmdOutPort1 : MotorCmdPort;
        port jointCmdOutPort2 : MotorCmdPort;
        port jointCmdOutPort3 : MotorCmdPort;
        port jointCmdOutPort4 : MotorCmdPort;
        port gripperCmdOutPort : GripperCmdPort;
        port gripperForceInPort : ForceReadingPort;
        port estopOutPort : EmergencyStopPort;
        port dataPort : DataPort;
        part motionPlanner : MotionPlanner;
        part trajectoryGenerator : TrajectoryGenerator;
        part jointController : JointController;
        part safetyController : SafetyController;
        bind locInPort = motionPlanner.targetInPort;
        bind proxInPort1 = motionPlanner.proxInPort1;
        bind proxInPort2 = motionPlanner.proxInPort2;
        bind proxInPort3 = motionPlanner.proxInPort3;
        bind proxInPort4 = motionPlanner.proxInPort4;
        bind motionPlanner.pathOutPort = trajectoryGenerator.pathInPort;
        bind trajectoryGenerator.trajOutPort = jointController.trajInPort;
        bind jointFbInPort1 = jointController.fbInPort1;
        bind jointFbInPort2 = jointController.fbInPort2;
        bind jointFbInPort3 = jointController.fbInPort3;
        bind jointFbInPort4 = jointController.fbInPort4;
        bind jointController.cmdOutPort1 = jointCmdOutPort1;
        bind jointController.cmdOutPort2 = jointCmdOutPort2;
        bind jointController.cmdOutPort3 = jointCmdOutPort3;
        bind jointController.cmdOutPort4 = jointCmdOutPort4;
        bind jointController.gripCmdOutPort = gripperCmdOutPort;
        bind gripperForceInPort = safetyController.forceInPort;
        bind proxInPort1 = safetyController.proxInPort1;
        bind proxInPort2 = safetyController.proxInPort2;
        bind proxInPort3 = safetyController.proxInPort3;
        bind proxInPort4 = safetyController.proxInPort4;
        bind jointFbInPort1 = safetyController.fbInPort1;
        bind jointFbInPort2 = safetyController.fbInPort2;
        bind jointFbInPort3 = safetyController.fbInPort3;
        bind jointFbInPort4 = safetyController.fbInPort4;
        bind safetyController.estopOutPort = estopOutPort;
        perform action orchestrateTask;
    }

    part def PowerSupply {
        port powerOutPort1 : PowerPort;
        port powerOutPort2 : PowerPort;
        port powerOutPort3 : PowerPort;
        perform action supplyPower;
    }

    part def CommunicationInterface {
        port dataPort : DataPort;
        perform action exchangeData;
    }

    part def Workpiece {
        attribute mass : MassValue;
        attribute width : LengthValue;
        attribute height : LengthValue;
    }

    state def OperationModeStateMachine {
        entry action initial;
        state off;
        state manual;
        state automatic {
            entry action initial;
            state idle;
            state sensing;
            state planning;
            state generatingTrajectory;
            state movingToPick;
            state grasping;
            state movingToPlace;
            state releasing;
            transition initial then idle;
            transition first idle accept StartTask then sensing;
            transition first sensing accept ObjectLocated then planning;
            transition first planning accept PathReady then generatingTrajectory;
            transition first generatingTrajectory accept TrajectoryReady then movingToPick;
            transition first movingToPick accept AtPickPose then grasping;
            transition first grasping accept ObjectGrasped then movingToPlace;
            transition first movingToPlace accept AtPlacePose then releasing;
            transition first releasing accept ObjectReleased then idle;
        }
        state emergency;
        transition initial then off;
        transition first off accept StartManual then manual;
        transition first off accept StartAuto then automatic;
        transition first manual accept StopAuto then off;
        transition first automatic accept StopAuto then off;
        transition first manual accept EmergencyTrigger then emergency;
        transition first automatic accept EmergencyTrigger then emergency;
        transition first emergency accept ResetSystem then off;
    }

    requirement def HighRepeatability {
        doc /* The robotic system shall perform pick-and-place operations with sub-millimeter repeatability. */
        attribute accuracy : LengthValue;
    }
    requirement def SafetyMonitoring {
        doc /* The safety controller shall trigger an emergency stop if forces or speeds exceed predefined limits. */
        attribute maxForce : ForceValue;
        attribute maxSpeed : AngularSpeedValue;
    }
    requirement def PayloadCapacity {
        doc /* The manipulator shall carry payloads up to 5 kg. */
        attribute maxPayload : MassValue;
    }
    requirement def ForceControl {
        doc /* The gripper shall control gripping force with accuracy of plus or minus 0.5 N. */
        attribute forceAccuracy : ForceValue;
    }
    requirement def PerceptionAccuracy {
        doc /* The vision system shall identify object locations with accuracy of plus or minus 1 mm. */
        attribute locationAccuracy : LengthValue;
    }
    requirement def AutonomousPickAndPlace {
        doc /* The system shall autonomously perform pick-and-place cycles. */
    }

    part def WorkCell {
        part arm : RoboticArm;
        part perception : PerceptionSystem;
        part controller : ControlModule;
        part powerSupply : PowerSupply;
        part commInterface : CommunicationInterface;
        part workpiece : Workpiece;
        connection powerConn1 connect powerSupply.powerOutPort1 to arm.powerPort;
        connection powerConn2 connect powerSupply.powerOutPort2 to controller.powerPort;
        connection powerConn3 connect powerSupply.powerOutPort3 to perception.powerPort;
        connection imageConn connect perception.imgPort to controller.imgInPort;
        connection locationConn connect perception.locPort to controller.locInPort;
        connection proxConn1 connect perception.proxPort1 to controller.proxInPort1;
        connection proxConn2 connect perception.proxPort2 to controller.proxInPort2;
        connection proxConn3 connect perception.proxPort3 to controller.proxInPort3;
        connection proxConn4 connect perception.proxPort4 to controller.proxInPort4;
        connection jointCmdConn1 connect controller.jointCmdOutPort1 to arm.jointCmdPort1;
        connection jointCmdConn2 connect controller.jointCmdOutPort2 to arm.jointCmdPort2;
        connection jointCmdConn3 connect controller.jointCmdOutPort3 to arm.jointCmdPort3;
        connection jointCmdConn4 connect controller.jointCmdOutPort4 to arm.jointCmdPort4;
        connection jointFbConn1 connect arm.jointFbPort1 to controller.jointFbInPort1;
        connection jointFbConn2 connect arm.jointFbPort2 to controller.jointFbInPort2;
        connection jointFbConn3 connect arm.jointFbPort3 to controller.jointFbInPort3;
        connection jointFbConn4 connect arm.jointFbPort4 to controller.jointFbInPort4;
        connection gripCmdConn connect controller.gripperCmdOutPort to arm.gripperCmdPort;
        connection gripForceConn connect arm.gripperForcePort to controller.gripperForceInPort;
        connection commConn connect controller.dataPort to commInterface.dataPort;
        exhibit state operationModes : OperationModeStateMachine;
    }

    part workCell : WorkCell;

    satisfy HighRepeatability by workCell.arm;
    satisfy SafetyMonitoring by workCell.controller.safetyController;
    satisfy PayloadCapacity by workCell.arm;
    satisfy ForceControl by workCell.arm.gripper;
    satisfy PerceptionAccuracy by workCell.perception.imageProcessor;
    satisfy AutonomousPickAndPlace by workCell;
}
