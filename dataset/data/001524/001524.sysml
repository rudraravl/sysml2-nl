package RoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def PositionVector {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    attribute def OrientationAngles {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }

    attribute def Pose {
        attribute position : PositionVector;
        attribute orientation : OrientationAngles;
    }

    attribute def JointAngle :> Real;
    attribute def JointVelocity :> AngularVelocityValue;
    attribute def JointTorque :> TorqueValue;

    enum def RobotMode {
        manual;
        automatic;
        teaching;
        emergency;
    }

    enum def TaskStatus {
        pending;
        executing;
        completed;
        failed;
    }

    item def Workpiece {
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute currentPose : Pose;
    }

    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    port def DataPort {
        attribute bandwidth : Real;
    }

    port def SensorPort {
        out sensorData : Real;
    }

    port def ActuatorPort {
        in commandSignal : Real;
        out feedbackSignal : Real;
    }

    part def Joint {
        attribute jointID : Integer;
        attribute currentAngle : JointAngle;
        attribute currentVelocity : JointVelocity;
        attribute minAngle : JointAngle;
        attribute maxAngle : JointAngle;
        attribute maxTorque : JointTorque;
        
        part motor {
            attribute ratedTorque : JointTorque;
            attribute ratedSpeed : JointVelocity;
            port power : PowerPort;
            port control : ActuatorPort;
        }
        
        part encoder {
            attribute resolution : Integer;
            port sensorOut : SensorPort;
        }
    }

    part def Link {
        attribute linkID : Integer;
        attribute length : LengthValue;
        attribute mass : MassValue;
        attribute centerOfMass : PositionVector;
    }

    part def EndEffector {
        attribute maxGrippingForce : ForceValue;
        attribute fingerSpan : LengthValue;
        attribute currentGripForce : ForceValue;
        
        part leftFinger {
            part actuator {
                attribute maxForce : ForceValue;
                port control : ActuatorPort;
            }
        }
        
        part rightFinger {
            part actuator {
                attribute maxForce : ForceValue;
                port control : ActuatorPort;
            }
        }
        
        part forceSensor {
            attribute maxForce : ForceValue;
            attribute sensitivity : Real;
            port sensorOut : SensorPort;
        }
    }

    part def ManipulatorArm {
        attribute degreesOfFreedom : Integer;
        attribute workspaceRadius : LengthValue;
        attribute totalMass : MassValue;
        
        part baseJoint : Joint {
            attribute :>> jointID = 1;
            attribute :>> minAngle = -3.14;
            attribute :>> maxAngle = 3.14;
            attribute :>> maxTorque = 200.0 [N*m];
        }
        
        part link1 : Link {
            attribute :>> linkID = 1;
            attribute :>> length = 0.4 [m];
            attribute :>> mass = 5.0 [kg];
        }
        
        part shoulderJoint : Joint {
            attribute :>> jointID = 2;
            attribute :>> minAngle = -1.57;
            attribute :>> maxAngle = 1.57;
            attribute :>> maxTorque = 150.0 [N*m];
        }
        
        part link2 : Link {
            attribute :>> linkID = 2;
            attribute :>> length = 0.35 [m];
            attribute :>> mass = 4.0 [kg];
        }
        
        part elbowJoint : Joint {
            attribute :>> jointID = 3;
            attribute :>> minAngle = -2.0;
            attribute :>> maxAngle = 2.0;
            attribute :>> maxTorque = 100.0 [N*m];
        }
        
        part link3 : Link {
            attribute :>> linkID = 3;
            attribute :>> length = 0.3 [m];
            attribute :>> mass = 3.0 [kg];
        }
        
        part wristJoint : Joint {
            attribute :>> jointID = 4;
            attribute :>> minAngle = -3.14;
            attribute :>> maxAngle = 3.14;
            attribute :>> maxTorque = 50.0 [N*m];
        }
        
        part endEffector : EndEffector {
            attribute :>> maxGrippingForce = 300.0 [N];
            attribute :>> fingerSpan = 0.15 [m];
        }
        
        port armPower : PowerPort;
        port armData : DataPort;
    }

    part def VisionSystem {
        attribute fieldOfView : Real;
        attribute resolution : Integer[2];
        attribute frameRate : FrequencyValue;
        
        part camera {
            attribute :>> resolution = (1920, 1080);
            attribute :>> frameRate = 30.0 [Hz];
            port power : PowerPort;
            port data : DataPort;
        }
        
        part imageProcessor {
            attribute processingPower : PowerValue;
            port data : DataPort;
        }
        
        port visionPower : PowerPort;
        port visionData : DataPort;
    }

    part def ProximitySensor {
        attribute detectionRange : LengthValue;
        attribute accuracy : LengthValue;
        port sensorOut : SensorPort;
        port power : PowerPort;
    }

    part def PerceptionModule {
        part visionSystem : VisionSystem {
            attribute :>> fieldOfView = 1.22;
        }
        
        part proximitySensor1 : ProximitySensor {
            attribute :>> detectionRange = 5.0 [m];
            attribute :>> accuracy = 0.01 [m];
        }
        
        part proximitySensor2 : ProximitySensor {
            attribute :>> detectionRange = 5.0 [m];
            attribute :>> accuracy = 0.01 [m];
        }
        
        part proximitySensor3 : ProximitySensor {
            attribute :>> detectionRange = 5.0 [m];
            attribute :>> accuracy = 0.01 [m];
        }
        
        part proximitySensor4 : ProximitySensor {
            attribute :>> detectionRange = 5.0 [m];
            attribute :>> accuracy = 0.01 [m];
        }
        
        port perceptionPower : PowerPort;
        port perceptionData : DataPort;
    }

    part def MotionPlanner {
        attribute planningCycleTime : TimeValue;
        attribute maxIterations : Integer;
        port plannerData : DataPort;
    }

    part def TrajectoryGenerator {
        attribute interpolationRate : FrequencyValue;
        port trajectoryData : DataPort;
    }

    part def JointController {
        attribute controlFrequency : FrequencyValue;
        attribute pidGains : Real[3];
        port controlData : DataPort;
    }

    part def SafetyController {
        attribute emergencyStopTime : TimeValue;
        attribute maxForceThreshold : ForceValue;
        attribute maxVelocityThreshold : Real;
        port safetyData : DataPort;
    }

    part def ControlModule {
        part motionPlanner : MotionPlanner {
            attribute :>> planningCycleTime = 0.1 [s];
            attribute :>> maxIterations = 1000;
        }
        
        part trajectoryGenerator : TrajectoryGenerator {
            attribute :>> interpolationRate = 100.0 [Hz];
        }
        
        part jointController : JointController {
            attribute :>> controlFrequency = 1000.0 [Hz];
        }
        
        part safetyController : SafetyController {
            attribute :>> emergencyStopTime = 0.05 [s];
            attribute :>> maxForceThreshold = 500.0 [N];
        }
        
        port controlPower : PowerPort;
        port controlData : DataPort;
    }

    part def PowerSupply {
        attribute nominalVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        attribute capacity : ElectricChargeValue;
        attribute stateOfCharge : Real;
        
        port mainPowerOut : PowerPort;
    }

    part def CommunicationInterface {
        attribute protocol : String;
        attribute dataRate : Real;
        port externalComm : DataPort;
        port internalComm : DataPort;
    }

    part def IndustrialRobot {
        attribute robotID : String;
        attribute operatingMode : RobotMode;
        attribute totalSystemMass : MassValue;
        attribute maxPayload : MassValue;
        attribute repeatability : LengthValue;
        
        part manipulator : ManipulatorArm {
            attribute :>> degreesOfFreedom = 4;
            attribute :>> workspaceRadius = 1.05 [m];
            attribute :>> totalMass = 12.0 [kg];
        }
        
        part perception : PerceptionModule;
        
        part control : ControlModule;
        
        part power : PowerSupply {
            attribute :>> nominalVoltage = 48.0 [V];
            attribute :>> maxCurrent = 100.0 [A];
            attribute :>> capacity = 80.0 [A*h];
            attribute :>> stateOfCharge = 1.0;
        }
        
        part communication : CommunicationInterface {
            attribute :>> protocol = "EtherCAT";
            attribute :>> dataRate = 100.0;
        }
        
        connection powerToManipulator connect power.mainPowerOut to manipulator.armPower;
        connection powerToPerception connect power.mainPowerOut to perception.perceptionPower;
        connection powerToControl connect power.mainPowerOut to control.controlPower;
        
        connection perceptionToControl connect perception.perceptionData to control.controlData;
        connection controlToManipulator connect control.controlData to manipulator.armData;
        connection manipulatorToControl connect manipulator.armData to control.controlData;
        
        connection externalComm connect communication.externalComm to control.controlData;
    }

    action def SenseEnvironment {
        in visionSystem : VisionSystem;
        in proximitySensors : ProximitySensor[*];
        out detectedObjects : Workpiece[*];
        out obstacleMap : Real[*];
    }

    action def PlanMotion {
        in currentPose : Pose;
        in targetPose : Pose;
        in obstacles : Real[*];
        out trajectory : Real[*];
        out planSuccess : Boolean;
    }

    action def ExecuteTrajectory {
        in trajectory : Real[*];
        in manipulator : ManipulatorArm;
        out executionComplete : Boolean;
    }

    action def GraspObject {
        in targetObject : Workpiece;
        in endEffector : EndEffector;
        out graspSuccess : Boolean;
    }

    action def ReleaseObject {
        in endEffector : EndEffector;
        out releaseSuccess : Boolean;
    }

    action def MonitorSafety {
        in forces : ForceValue[*];
        in velocities : Real[*];
        in safetyThresholds : Real[*];
        out safetyStatus : Boolean;
    }

    action def PickAndPlaceTask {
        in pickPose : Pose;
        in placePose : Pose;
        in workpiece : Workpiece;
        out taskStatus : TaskStatus;
        
        first start;
        then action sense : SenseEnvironment;
        then action planToPick : PlanMotion {
            in targetPose = pickPose;
        }
        then decide;
            if planToPick.planSuccess then executeToPick;
            if not planToPick.planSuccess then replan;
        
        action executeToPick : ExecuteTrajectory;
        then action grasp : GraspObject {
            in targetObject = workpiece;
        }
        then decide;
            if grasp.graspSuccess then planToPlace;
            if not grasp.graspSuccess then retryGrasp;
        
        action planToPlace : PlanMotion {
            in targetPose = placePose;
        }
        then action executeToPlace : ExecuteTrajectory;
        then action release : ReleaseObject;
        then decide;
            if release.releaseSuccess then taskComplete;
            if not release.releaseSuccess then retryRelease;
        
        action replan {
            out taskStatus = TaskStatus::failed;
        }
        then done;
        
        action retryGrasp {
            out taskStatus = TaskStatus::failed;
        }
        then done;
        
        action retryRelease {
            out taskStatus = TaskStatus::failed;
        }
        then done;
        
        action taskComplete {
            out taskStatus = TaskStatus::completed;
        }
        then done;
    }

    state def RobotOperationStateMachine {
        entry; then idle;
        
        state idle;
        
        transition idleToInitializing
            first idle
            accept initializeCommand
            then initializing;
        
        state initializing;
        
        transition initializingToReady
            first initializing
            accept calibrationComplete
            then ready;
        
        state ready;
        
        transition readyToExecuting
            first ready
            accept taskCommand
            then executing;
        
        state executing;
        
        transition executingToReady
            first executing
            accept taskCompleted
            then ready;
        
        transition executingToError
            first executing
            accept taskFailed
            then error;
        
        transition anyToEmergency
            first idle, initializing, ready, executing
            accept emergencyStop
            then emergency;
        
        state emergency;
        
        transition emergencyToError
            first emergency
            accept acknowledgeEmergency
            then error;
        
        state error;
        
        transition errorToIdle
            first error
            accept resetCommand
            then idle;
    }

    requirement def FunctionalRequirement {
        doc /* Base functional requirement for robotic systems */
        subject robot : IndustrialRobot;
    }

    requirement def PerformanceRequirement {
        doc /* Base performance requirement for robotic systems */
        subject robot : IndustrialRobot;
    }

    requirement def SafetyRequirement {
        doc /* Base safety requirement for robotic systems */
        subject robot : IndustrialRobot;
    }

    requirement <'REQ-FUNC-001'> primaryFunction : FunctionalRequirement {
        doc /* The robotic system shall autonomously manipulate workpieces in a 
             * structured industrial environment by perceiving objects through vision 
             * and proximity sensing, planning collision-free trajectories using motion 
             * planning algorithms, executing precise multi-axis movements through 
             * coordinated joint control, and performing pick-and-place operations with 
             * force-controlled grasping to achieve repeatable positioning within 0.1mm 
             * accuracy while continuously monitoring safety constraints.
             */
        subject robot : IndustrialRobot;
    }

    requirement <'REQ-PERF-001'> workspaceRequirement : PerformanceRequirement {
        doc /* The manipulator shall have a minimum workspace radius of 1.0 meters */
        subject manipulator :>> IndustrialRobot::manipulator;
        assert constraint {
            manipulator.workspaceRadius >= 1.0 [m]
        }
    }

    requirement <'REQ-PERF-002'> payloadRequirement : PerformanceRequirement {
        doc /* The robot shall handle payloads up to 15 kilograms */
        subject robot : IndustrialRobot;
        assert constraint {
            robot.maxPayload >= 15.0 [kg]
        }
    }

    requirement <'REQ-PERF-003'> repeatabilityRequirement : PerformanceRequirement {
        doc /* The robot shall achieve positional repeatability within 0.1 millimeters */
        subject robot : IndustrialRobot;
        assert constraint {
            robot.repeatability <= 0.0001 [m]
        }
    }

    requirement <'REQ-PERF-004'> cycleTimeRequirement : PerformanceRequirement {
        doc /* The robot shall complete a standard pick-and-place cycle in less than 4 seconds */
        subject robot : IndustrialRobot;
    }

    requirement <'REQ-SAFE-001'> emergencyStopRequirement : SafetyRequirement {
        doc /* The safety controller shall trigger emergency stop within 50 milliseconds 
             * upon detection of excessive force or velocity */
        subject safetyController :>> IndustrialRobot::control.safetyController;
        assert constraint {
            safetyController.emergencyStopTime <= 0.05 [s]
        }
    }

    requirement <'REQ-SAFE-002'> forceMonitoringRequirement : SafetyRequirement {
        doc /* The system shall continuously monitor contact forces and limit them 
             * to a maximum of 500 Newtons */
        subject safetyController :>> IndustrialRobot::control.safetyController;
        assert constraint {
            safetyController.maxForceThreshold <= 500.0 [N]
        }
    }

    requirement <'REQ-SAFE-003'> collisionDetectionRequirement : SafetyRequirement {
        doc /* The perception module shall detect obstacles within 5 meters with 
             * accuracy better than 10 millimeters */
        subject perception :>> IndustrialRobot::perception;
    }

    constraint def MassConstraint {
        in manipulatorMass : MassValue;
        in payloadMass : MassValue;
        in totalMass : MassValue;
        totalMass >= manipulatorMass + payloadMass
    }

    part roboticWorkCell {
        part robot : IndustrialRobot {
            attribute :>> robotID = "ROBOT-CELL-001";
            attribute :>> operatingMode = RobotMode::manual;
            attribute :>> totalSystemMass = 50.0 [kg];
            attribute :>> maxPayload = 15.0 [kg];
            attribute :>> repeatability = 0.0001 [m];
        }
        
        item workpiece1 : Workpiece {
            attribute :>> mass = 8.0 [kg];
            attribute :>> dimensions = (0.2, 0.15, 0.1) [m];
        }
        
        item workpiece2 : Workpiece {
            attribute :>> mass = 6.5 [kg];
            attribute :>> dimensions = (0.18, 0.12, 0.08) [m];
        }
        
        assert constraint massCheck : MassConstraint {
            in manipulatorMass = robot.manipulator.totalMass;
            in payloadMass = robot.maxPayload;
            in totalMass = robot.totalSystemMass;
        }
        
        satisfy primaryFunction by robot;
        satisfy workspaceRequirement by robot.manipulator;
        satisfy payloadRequirement by robot;
        satisfy repeatabilityRequirement by robot;
        satisfy emergencyStopRequirement by robot.control.safetyController;
        satisfy forceMonitoringRequirement by robot.control.safetyController;
    }

    action operateRoboticSystem {
        doc /* Primary operational action: The robotic system continuously perceives 
             * its environment using vision and proximity sensors, receives task commands 
             * specifying pick and place locations, plans collision-free trajectories 
             * through its workspace, executes coordinated multi-joint movements with 
             * precise position control, performs force-controlled grasping and releasing 
             * of workpieces, and maintains continuous safety monitoring to autonomously 
             * handle industrial manipulation tasks with high repeatability and reliability.
             */
        
        first start;
        then merge continuousOperation;
        
        then action perceive : SenseEnvironment;
        
        then action receiveTaskCommand {
            out pickLocation : Pose;
            out placeLocation : Pose;
            out targetWorkpiece : Workpiece;
        }
        
        then action checkSafety : MonitorSafety;
        
        then decide;
            if checkSafety.safetyStatus then executeTask;
            if not checkSafety.safetyStatus then emergencyStop;
        
        action executeTask : PickAndPlaceTask {
            in pickPose = receiveTaskCommand.pickLocation;
            in placePose = receiveTaskCommand.placeLocation;
            in workpiece = receiveTaskCommand.targetWorkpiece;
        }
        
        then decide;
            if executeTask.taskStatus == TaskStatus::completed then continuousOperation;
            if executeTask.taskStatus == TaskStatus::failed then handleFailure;
        
        action emergencyStop {
            out stopped : Boolean;
        }
        then done;
        
        action handleFailure {
            out recovered : Boolean;
        }
        then continuousOperation;
    }
}
