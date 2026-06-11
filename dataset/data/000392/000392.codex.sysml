package BushRobotPrimaryTaskSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    alias mm for SI::millimetre;
    alias cm for SI::centimetre;
    alias m for SI::metre;
    alias s for SI::second;
    alias kg for SI::kilogram;
    alias N for SI::newton;
    alias V for SI::volt;
    alias A for SI::ampere;
    alias W for SI::watt;
    alias deg for SI::degree;

    attribute def Percentage :> Real {
        range 0.0 .. 100.0;
    }

    attribute def Probability :> Real {
        range 0.0 .. 1.0;
    }

    attribute def JointAngle :> Real {
        unit = deg;
    }

    attribute def Length :> Real {
        unit = m;
    }

    attribute def Force :> Real {
        unit = N;
    }

    attribute def Voltage :> Real {
        unit = V;
    }

    attribute def Current :> Real {
        unit = A;
    }

    attribute def Power :> Real {
        unit = W;
    }

    attribute def Mass :> Real {
        unit = kg;
    }

    attribute def Duration :> Real {
        unit = s;
    }

    attribute def Position3D {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    attribute def OrientationRPY {
        attribute roll : JointAngle;
        attribute pitch : JointAngle;
        attribute yaw : JointAngle;
    }

    attribute def Pose3D {
        attribute position : Position3D;
        attribute orientation : OrientationRPY;
    }

    attribute def Velocity3D {
        attribute vx : Real { unit = m / s; }
        attribute vy : Real { unit = m / s; }
        attribute vz : Real { unit = m / s; }
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availablePower : Power;
    }

    item def MotionCommand {
        attribute targetPose : Pose3D;
        attribute maxVelocity : Real { unit = m / s; }
        attribute maxForce : Force;
        attribute priority : Integer;
    }

    item def SegmentCommand {
        attribute segmentId : Integer;
        attribute targetBendAngle : JointAngle;
        attribute targetTwistAngle : JointAngle;
        attribute extensionLength : Length;
        attribute tendonTension : Force;
    }

    item def SensorFrame {
        attribute timestamp : Duration;
        attribute basePose : Pose3D;
        attribute tipPose : Pose3D;
        attribute obstacleProbability : Probability;
        attribute targetConfidence : Probability;
    }

    item def ManipulatedObject {
        attribute objectId : String;
        attribute mass : Mass;
        attribute graspPose : Pose3D;
        attribute fragile : Boolean;
        attribute requiredGripForce : Force;
    }

    item def DiagnosticReport {
        attribute timestamp : Duration;
        attribute batteryStateOfCharge : Percentage;
        attribute controllerHealthy : Boolean;
        attribute sensorHealthy : Boolean;
        attribute actuatorHealthy : Boolean;
        attribute faultCode : String;
    }

    port def PowerOutPort {
        out item power : ElectricalPower;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def CommandOutPort {
        out item command : MotionCommand;
    }

    port def CommandInPort {
        in item command : MotionCommand;
    }

    port def SegmentCommandOutPort {
        out item segmentCommand : SegmentCommand;
    }

    port def SegmentCommandInPort {
        in item segmentCommand : SegmentCommand;
    }

    port def SensorOutPort {
        out item frame : SensorFrame;
    }

    port def SensorInPort {
        in item frame : SensorFrame;
    }

    port def ObjectInPort {
        in item object : ManipulatedObject;
    }

    port def ObjectOutPort {
        out item object : ManipulatedObject;
    }

    port def DiagnosticOutPort {
        out item report : DiagnosticReport;
    }

    port def DiagnosticInPort {
        in item report : DiagnosticReport;
    }

    part def BatteryModule {
        attribute nominalVoltage : Voltage = 48.0 [V];
        attribute capacity : Real { unit = A * s; } = 72000.0 [A * s];
        attribute stateOfCharge : Percentage = 100.0;
        attribute maximumContinuousPower : Power = 1800.0 [W];

        port powerOut : PowerOutPort;
        port diagnosticOut : DiagnosticOutPort;
    }

    part def PowerDistributionUnit {
        attribute busVoltage : Voltage = 48.0 [V];
        attribute maxBranchCurrent : Current = 20.0 [A];
        attribute emergencyCutoffEnabled : Boolean = true;

        port sourcePower : PowerInPort;
        port controllerPower : PowerOutPort;
        port actuatorPower : PowerOutPort;
        port sensorPower : PowerOutPort;
        port diagnosticOut : DiagnosticOutPort;
    }

    part def TerrainMobilityBase {
        attribute mass : Mass = 38.0 [kg];
        attribute maximumSpeed : Real { unit = m / s; } = 1.4 [m / s];
        attribute trackWidth : Length = 0.62 [m];
        attribute groundClearance : Length = 0.18 [m];
        attribute currentPose : Pose3D;

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port sensorOut : SensorOutPort;
    }

    part def PerceptionSuite {
        attribute lidarRange : Length = 25.0 [m];
        attribute stereoRange : Length = 8.0 [m];
        attribute tactileSampleRate : Real { unit = 1 / s; } = 250.0 [1 / s];
        attribute minimumTargetConfidence : Probability = 0.86;

        port powerIn : PowerInPort;
        port sensorOut : SensorOutPort;
        port diagnosticOut : DiagnosticOutPort;
    }

    part def MissionComputer {
        attribute cyclePeriod : Duration = 0.02 [s];
        attribute obstacleClearance : Length = 0.08 [m];
        attribute goalTolerance : Length = 0.015 [m];
        attribute maximumPlanningTime : Duration = 1.5 [s];

        port powerIn : PowerInPort;
        port perceptionIn : SensorInPort;
        port baseCommandOut : CommandOutPort;
        port bushRobotCommandOut : CommandOutPort;
        port diagnosticsIn : DiagnosticInPort;
        port diagnosticOut : DiagnosticOutPort;
    }

    part def TendonActuator {
        attribute actuatorId : Integer;
        attribute maxTension : Force = 120.0 [N];
        attribute maxStroke : Length = 0.08 [m];
        attribute responseTime : Duration = 0.045 [s];

        port powerIn : PowerInPort;
        port commandIn : SegmentCommandInPort;
        port diagnosticOut : DiagnosticOutPort;
    }

    part def BushRobotSegment {
        attribute segmentId : Integer;
        attribute length : Length = 0.16 [m];
        attribute diameter : Length = 0.035 [m];
        attribute maxBendAngle : JointAngle = 35.0 [deg];
        attribute maxTwistAngle : JointAngle = 60.0 [deg];
        attribute currentBendAngle : JointAngle;
        attribute currentTwistAngle : JointAngle;
        attribute stiffness : Real { unit = N / m; } = 450.0 [N / m];

        port commandIn : SegmentCommandInPort;
        port proximalMechanicalInterface;
        port distalMechanicalInterface;
        port diagnosticOut : DiagnosticOutPort;

        part bendActuatorA : TendonActuator {
            attribute actuatorId = segmentId * 10 + 1;
        }

        part bendActuatorB : TendonActuator {
            attribute actuatorId = segmentId * 10 + 2;
        }

        part twistActuator : TendonActuator {
            attribute actuatorId = segmentId * 10 + 3;
        }
    }

    part def EndEffector {
        attribute jawOpening : Length = 0.09 [m];
        attribute maximumGripForce : Force = 45.0 [N];
        attribute wristPitchLimit : JointAngle = 90.0 [deg];
        attribute wristYawLimit : JointAngle = 120.0 [deg];
        attribute toolMass : Mass = 1.8 [kg];

        port powerIn : PowerInPort;
        port commandIn : CommandInPort;
        port objectIn : ObjectInPort;
        port objectOut : ObjectOutPort;
        port sensorOut : SensorOutPort;
        port diagnosticOut : DiagnosticOutPort;
    }

    part def BushRobot {
        attribute totalReach : Length = 1.92 [m];
        attribute payloadCapacity : Mass = 2.5 [kg];
        attribute tipPositionAccuracy : Length = 0.01 [m];
        attribute maxTipForce : Force = 30.0 [N];
        attribute deployed : Boolean = false;

        port powerIn : PowerInPort;
        port motionCommandIn : CommandInPort;
        port perceptionOut : SensorOutPort;
        port objectIn : ObjectInPort;
        port objectOut : ObjectOutPort;
        port diagnosticOut : DiagnosticOutPort;

        port baseMount;
        port tipMount;

        part segment01 : BushRobotSegment { attribute segmentId = 1; }
        part segment02 : BushRobotSegment { attribute segmentId = 2; }
        part segment03 : BushRobotSegment { attribute segmentId = 3; }
        part segment04 : BushRobotSegment { attribute segmentId = 4; }
        part segment05 : BushRobotSegment { attribute segmentId = 5; }
        part segment06 : BushRobotSegment { attribute segmentId = 6; }
        part segment07 : BushRobotSegment { attribute segmentId = 7; }
        part segment08 : BushRobotSegment { attribute segmentId = 8; }
        part segment09 : BushRobotSegment { attribute segmentId = 9; }
        part segment10 : BushRobotSegment { attribute segmentId = 10; }
        part segment11 : BushRobotSegment { attribute segmentId = 11; }
        part segment12 : BushRobotSegment { attribute segmentId = 12; }

        part gripper : EndEffector;

        connect segment01.distalMechanicalInterface to segment02.proximalMechanicalInterface;
        connect segment02.distalMechanicalInterface to segment03.proximalMechanicalInterface;
        connect segment03.distalMechanicalInterface to segment04.proximalMechanicalInterface;
        connect segment04.distalMechanicalInterface to segment05.proximalMechanicalInterface;
        connect segment05.distalMechanicalInterface to segment06.proximalMechanicalInterface;
        connect segment06.distalMechanicalInterface to segment07.proximalMechanicalInterface;
        connect segment07.distalMechanicalInterface to segment08.proximalMechanicalInterface;
        connect segment08.distalMechanicalInterface to segment09.proximalMechanicalInterface;
        connect segment09.distalMechanicalInterface to segment10.proximalMechanicalInterface;
        connect segment10.distalMechanicalInterface to segment11.proximalMechanicalInterface;
        connect segment11.distalMechanicalInterface to segment12.proximalMechanicalInterface;
        connect segment12.distalMechanicalInterface to gripper.commandIn;
    }

    part def PayloadContainer {
        attribute internalVolume : Real { unit = m^3; } = 0.018 [m^3];
        attribute maxStoredMass : Mass = 4.0 [kg];
        attribute secured : Boolean = true;

        port objectIn : ObjectInPort;
        port objectOut : ObjectOutPort;
    }

    part def RoboticBushTaskSystem {
        attribute systemMass : Mass = 72.0 [kg];
        attribute operatingTemperatureMin : Real { unit = K; } = 263.15 [K];
        attribute operatingTemperatureMax : Real { unit = K; } = 318.15 [K];
        attribute primaryTaskName : String = "Navigate through dense vegetation, locate a target sample, retrieve it with the Bush robot, and return it to the payload container.";

        part battery : BatteryModule;
        part pdu : PowerDistributionUnit;
        part mobilityBase : TerrainMobilityBase;
        part perception : PerceptionSuite;
        part missionComputer : MissionComputer;
        part bushRobot : BushRobot;
        part payloadContainer : PayloadContainer;

        connect battery.powerOut to pdu.sourcePower;
        connect pdu.controllerPower to missionComputer.powerIn;
        connect pdu.actuatorPower to mobilityBase.powerIn;
        connect pdu.actuatorPower to bushRobot.powerIn;
        connect pdu.sensorPower to perception.powerIn;

        connect perception.sensorOut to missionComputer.perceptionIn;
        connect missionComputer.baseCommandOut to mobilityBase.commandIn;
        connect missionComputer.bushRobotCommandOut to bushRobot.motionCommandIn;

        connect bushRobot.objectOut to payloadContainer.objectIn;
        connect payloadContainer.objectOut to bushRobot.objectIn;

        connect battery.diagnosticOut to missionComputer.diagnosticsIn;
        connect pdu.diagnosticOut to missionComputer.diagnosticsIn;
        connect perception.diagnosticOut to missionComputer.diagnosticsIn;
        connect bushRobot.diagnosticOut to missionComputer.diagnosticsIn;
    }

    action def InitializeSystem {
        in part system : RoboticBushTaskSystem;
        out success : Boolean;

        action powerCheck;
        action sensorCalibration;
        action bushRobotHoming;
        action mobilityBaseReady;

        first start;
        then powerCheck;
        then sensorCalibration;
        then bushRobotHoming;
        then mobilityBaseReady;
        then done;

        flow powerCheck to sensorCalibration;
        flow sensorCalibration to bushRobotHoming;
        flow bushRobotHoming to mobilityBaseReady;
    }

    action def SurveyVegetatedWorkspace {
        in part system : RoboticBushTaskSystem;
        out targetPose : Pose3D;
        out routeClear : Boolean;

        action scanWithLidar;
        action classifyVegetation;
        action localizeTarget;
        action computeApproachPose;

        first scanWithLidar;
        then classifyVegetation;
        then localizeTarget;
        then computeApproachPose;
        then done;
    }

    action def NavigateToApproachPose {
        in part system : RoboticBushTaskSystem;
        in targetPose : Pose3D;
        out arrived : Boolean;

        action planBasePath;
        action commandTracks;
        action monitorSlip;
        action stopAtApproachPose;

        first planBasePath;
        then commandTracks;
        then monitorSlip;
        then stopAtApproachPose;
        then done;
    }

    action def DeployBushRobot {
        in part robot : BushRobot;
        in targetPose : Pose3D;
        out deployed : Boolean;

        action generateContinuumPath;
        action issueSegmentCommands;
        action avoidBranches;
        action verifyTipPose;

        first generateContinuumPath;
        then issueSegmentCommands;
        then avoidBranches;
        then verifyTipPose;
        then done;
    }

    action def RetrieveTargetObject {
        in part robot : BushRobot;
        in target : ManipulatedObject;
        out retrievedObject : ManipulatedObject;
        out graspStable : Boolean;

        action alignEndEffector;
        action closeGripper;
        action verifyGripForce;
        action retractAlongPath;

        first alignEndEffector;
        then closeGripper;
        then verifyGripForce;
        then retractAlongPath;
        then done;
    }

    action def StowObject {
        in part system : RoboticBushTaskSystem;
        in object : ManipulatedObject;
        out stowed : Boolean;

        action positionOverContainer;
        action releaseObject;
        action confirmContainerMassIncrease;
        action stowBushRobot;

        first positionOverContainer;
        then releaseObject;
        then confirmContainerMassIncrease;
        then stowBushRobot;
        then done;
    }

    action def ExecutePrimaryBushRobotTask {
        in part system : RoboticBushTaskSystem;
        in targetObject : ManipulatedObject;
        out missionComplete : Boolean;

        action initialize : InitializeSystem {
            in system = system;
        }

        action survey : SurveyVegetatedWorkspace {
            in system = system;
        }

        action navigate : NavigateToApproachPose {
            in system = system;
            in targetPose = survey.targetPose;
        }

        action deploy : DeployBushRobot {
            in robot = system.bushRobot;
            in targetPose = survey.targetPose;
        }

        action retrieve : RetrieveTargetObject {
            in robot = system.bushRobot;
            in target = targetObject;
        }

        action stow : StowObject {
            in system = system;
            in object = retrieve.retrievedObject;
        }

        first initialize;
        then survey;
        then navigate;
        then deploy;
        then retrieve;
        then stow;
        then done;
    }

    state def BushRobotOperationalState {
        entry action establishPower;
        exit action publishDiagnostics;

        state Off;
        state Homing;
        state Stowed;
        state Deploying;
        state Manipulating;
        state Retracting;
        state Fault;

        transition initial then Off;

        transition powerAvailable
            first Off
            accept ElectricalPower
            then Homing;

        transition homed
            first Homing
            if allSegmentsZeroed
            then Stowed;

        transition deployCommanded
            first Stowed
            accept MotionCommand
            then Deploying;

        transition tipAtTarget
            first Deploying
            if targetPoseWithinTolerance
            then Manipulating;

        transition objectSecured
            first Manipulating
            accept ManipulatedObject
            then Retracting;

        transition retracted
            first Retracting
            if robotWithinStowEnvelope
            then Stowed;

        transition faultDetectedFromHoming
            first Homing
            if actuatorHealthy == false
            then Fault;

        transition faultDetectedFromDeploying
            first Deploying
            if obstacleProbability > 0.95
            then Fault;

        transition faultDetectedFromManipulating
            first Manipulating
            if gripForceExceeded
            then Fault;

        transition resetAfterFault
            first Fault
            accept DiagnosticReport
            if controllerHealthy
            then Homing;
    }

    state def MissionState {
        state Idle;
        state Initializing;
        state Surveying;
        state Navigating;
        state DeployingBushRobot;
        state Retrieving;
        state Stowing;
        state Complete;
        state Abort;

        transition initial then Idle;

        transition startMission
            first Idle
            then Initializing;

        transition initialized
            first Initializing
            then Surveying;

        transition targetFound
            first Surveying
            if targetConfidence >= 0.86
            then Navigating;

        transition routeBlocked
            first Surveying
            if obstacleProbability >= 0.98
            then Abort;

        transition atApproachPose
            first Navigating
            then DeployingBushRobot;

        transition bushRobotDeployed
            first DeployingBushRobot
            then Retrieving;

        transition targetRetrieved
            first Retrieving
            then Stowing;

        transition objectStowed
            first Stowing
            then Complete;

        transition unrecoverableFault
            first Initializing
            then Abort;

        transition motionFault
            first Navigating
            then Abort;

        transition manipulationFault
            first Retrieving
            then Abort;
    }

    requirement def PrimaryTaskRequirement {
        doc /* The robotic system shall perform its primary field task using the Bush robot as the manipulating device for target retrieval in constrained vegetation. */
    }

    requirement def DenseVegetationReachRequirement {
        doc /* The Bush robot shall reach a target located up to 1.5 m beyond the mobility base through a vegetation gap no wider than 0.12 m without requiring the mobility base to enter the gap. */
        attribute requiredReach : Length = 1.5 [m];
        attribute maximumGapWidth : Length = 0.12 [m];
    }

    requirement def PayloadRetrievalRequirement {
        doc /* The Bush robot shall retrieve a target object with mass up to 2.0 kg and place it into the payload container without dropping it. */
        attribute maximumTargetMass : Mass = 2.0 [kg];
        attribute allowedDrops : Integer = 0;
    }

    requirement def TipAccuracyRequirement {
        doc /* The Bush robot shall position its end effector within 15 mm of the planned grasp pose before closing the gripper. */
        attribute maximumTipError : Length = 0.015 [m];
    }

    requirement def ForceLimitingRequirement {
        doc /* The Bush robot shall limit contact force against unmodeled obstacles to no more than 30 N during deployment and retraction. */
        attribute maximumContactForce : Force = 30.0 [N];
    }

    requirement def PowerEnduranceRequirement {
        doc /* The robotic system shall complete one primary retrieval mission while maintaining at least 20 percent battery state of charge. */
        attribute minimumFinalStateOfCharge : Percentage = 20.0;
    }

    requirement def SafetyFaultRequirement {
        doc /* The mission computer shall command the Bush robot to enter Fault state if actuator health is lost, obstacle probability exceeds 0.95 during deployment, or grip force exceeds the safe limit for a fragile object. */
        attribute obstacleFaultThreshold : Probability = 0.95;
    }

    requirement def DiagnosticRequirement {
        doc /* The system shall publish diagnostic reports from power, perception, mobility, and Bush robot subsystems at least once per second. */
        attribute minimumDiagnosticRate : Real { unit = 1 / s; } = 1.0 [1 / s];
    }

    satisfy PrimaryTaskRequirement by RoboticBushTaskSystem;
    satisfy DenseVegetationReachRequirement by BushRobot;
    satisfy PayloadRetrievalRequirement by BushRobot;
    satisfy PayloadRetrievalRequirement by PayloadContainer;
    satisfy TipAccuracyRequirement by BushRobot;
    satisfy ForceLimitingRequirement by BushRobot;
    satisfy PowerEnduranceRequirement by BatteryModule;
    satisfy SafetyFaultRequirement by MissionComputer;
    satisfy SafetyFaultRequirement by BushRobotOperationalState;
    satisfy DiagnosticRequirement by MissionComputer;
    satisfy DiagnosticRequirement by BatteryModule;
    satisfy DiagnosticRequirement by PerceptionSuite;
    satisfy DiagnosticRequirement by BushRobot;

    exhibit state BushRobotOperationalState by BushRobot;
    exhibit state MissionState by RoboticBushTaskSystem;

    perform action ExecutePrimaryBushRobotTask by RoboticBushTaskSystem;

    part fieldedSystem : RoboticBushTaskSystem {
        attribute systemMass = 72.0 [kg];

        part battery {
            attribute stateOfCharge = 100.0;
        }

        part bushRobot {
            attribute totalReach = 1.92 [m];
            attribute payloadCapacity = 2.5 [kg];
            attribute tipPositionAccuracy = 0.01 [m];
            attribute maxTipForce = 30.0 [N];
        }

        part payloadContainer {
            attribute maxStoredMass = 4.0 [kg];
        }
    }

    item targetSample : ManipulatedObject {
        attribute objectId = "sample-canister-01";
        attribute mass = 1.4 [kg];
        attribute fragile = true;
        attribute requiredGripForce = 18.0 [N];
    }

    action primaryMission : ExecutePrimaryBushRobotTask {
        in system = fieldedSystem;
        in targetObject = targetSample;
    }
}