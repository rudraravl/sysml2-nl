package ContinuumRobotPrimaryTaskModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Length_m :> ISQ::LengthValue {
        :>> unit = SI::m;
    }

    attribute def Angle_rad :> ISQ::PlaneAngleValue {
        :>> unit = SI::rad;
    }

    attribute def Time_s :> ISQ::TimeValue {
        :>> unit = SI::s;
    }

    attribute def Mass_kg :> ISQ::MassValue {
        :>> unit = SI::kg;
    }

    attribute def Force_N :> ISQ::ForceValue {
        :>> unit = SI::N;
    }

    attribute def Torque_Nm :> ISQ::TorqueValue {
        :>> unit = SI::N * SI::m;
    }

    attribute def Pressure_Pa :> ISQ::PressureValue {
        :>> unit = SI::Pa;
    }

    attribute def Voltage_V :> ISQ::ElectricPotentialValue {
        :>> unit = SI::V;
    }

    attribute def Current_A :> ISQ::ElectricCurrentValue {
        :>> unit = SI::A;
    }

    attribute def Power_W :> ISQ::PowerValue {
        :>> unit = SI::W;
    }

    attribute def Temperature_C :> ISQ::ThermodynamicTemperatureValue {
        :>> unit = SI::K;
    }

    attribute def Velocity_mps :> ISQ::SpeedValue {
        :>> unit = SI::m / SI::s;
    }

    attribute def Curvature_1pm :> ScalarValues::Real {
        attribute unitSymbol : ScalarValues::String = "1/m";
    }

    attribute def Percent :> ScalarValues::Real {
        attribute unitSymbol : ScalarValues::String = "%";
    }

    attribute def Pose3D {
        attribute x : Length_m;
        attribute y : Length_m;
        attribute z : Length_m;
        attribute roll : Angle_rad;
        attribute pitch : Angle_rad;
        attribute yaw : Angle_rad;
    }

    attribute def CurvatureVector {
        attribute kappaX : Curvature_1pm;
        attribute kappaY : Curvature_1pm;
        attribute torsion : Curvature_1pm;
    }

    attribute def Wrench6D {
        attribute forceX : Force_N;
        attribute forceY : Force_N;
        attribute forceZ : Force_N;
        attribute torqueX : Torque_Nm;
        attribute torqueY : Torque_Nm;
        attribute torqueZ : Torque_Nm;
    }

    attribute def QualityMetrics {
        attribute tipPositionError : Length_m;
        attribute graspConfidence : Percent;
        attribute pathClearance : Length_m;
        attribute shapeEstimateResidual : Length_m;
    }

    enum def SystemMode {
        enum poweredOff;
        enum initializing;
        enum standby;
        enum calibrating;
        enum planning;
        enum executingPrimaryTask;
        enum paused;
        enum completed;
        enum faulted;
        enum safeStop;
    }

    enum def ContinuumDriveMode {
        enum tendonPosition;
        enum tendonTension;
        enum curvatureClosedLoop;
        enum tipPoseClosedLoop;
        enum gravityCompensatedHold;
    }

    enum def TaskPhase {
        enum receiveMission;
        enum calibrateContinuumRobot;
        enum planCurvaturePath;
        enum insertThroughConstrainedPassage;
        enum navigateToTarget;
        enum performToolOperation;
        enum retractFromPassage;
        enum deliverResult;
        enum reportCompletion;
    }

    enum def FaultSeverity {
        enum advisory;
        enum recoverable;
        enum critical;
        enum emergency;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute availablePower : Power_W;
        attribute protectiveEarthPresent : ScalarValues::Boolean;
    }

    item def ControlPower {
        attribute voltage : Voltage_V = 24 [SI::V];
        attribute currentLimit : Current_A = 15 [SI::A];
    }

    item def MotorPower {
        attribute voltage : Voltage_V = 48 [SI::V];
        attribute currentLimit : Current_A = 40 [SI::A];
    }

    item def MotionCommand {
        attribute commandId : ScalarValues::String;
        attribute desiredTipPose : Pose3D;
        attribute desiredCurvatureSection1 : CurvatureVector;
        attribute desiredCurvatureSection2 : CurvatureVector;
        attribute desiredCurvatureSection3 : CurvatureVector;
        attribute maximumTipSpeed : Velocity_mps;
        attribute maximumContactForce : Force_N;
        attribute driveMode : ContinuumDriveMode;
    }

    item def TendonLengthCommand {
        attribute tendon1Delta : Length_m;
        attribute tendon2Delta : Length_m;
        attribute tendon3Delta : Length_m;
        attribute tendon4Delta : Length_m;
        attribute rateLimit : Velocity_mps;
    }

    item def TendonTensionCommand {
        attribute tendon1Tension : Force_N;
        attribute tendon2Tension : Force_N;
        attribute tendon3Tension : Force_N;
        attribute tendon4Tension : Force_N;
        attribute tensionSlewLimit : Force_N;
    }

    item def ShapeEstimate {
        attribute backboneBasePose : Pose3D;
        attribute section1Curvature : CurvatureVector;
        attribute section2Curvature : CurvatureVector;
        attribute section3Curvature : CurvatureVector;
        attribute tipPose : Pose3D;
        attribute residualError : Length_m;
        attribute timestamp : Time_s;
    }

    item def RobotTelemetry {
        attribute mode : SystemMode;
        attribute taskPhase : TaskPhase;
        attribute measuredTipPose : Pose3D;
        attribute measuredTipWrench : Wrench6D;
        attribute quality : QualityMetrics;
        attribute batteryOrSupplyPower : Power_W;
        attribute controllerTemperature : Temperature_C;
        attribute faultActive : ScalarValues::Boolean;
    }

    item def VisionFrame {
        attribute frameId : ScalarValues::String;
        attribute acquisitionTime : Time_s;
        attribute cameraPose : Pose3D;
        attribute targetPoseEstimate : Pose3D;
        attribute confidence : Percent;
    }

    item def TargetObject {
        attribute objectId : ScalarValues::String;
        attribute nominalPose : Pose3D;
        attribute mass : Mass_kg;
        attribute minimumGripForce : Force_N;
        attribute allowableContactForce : Force_N;
    }

    item def PrimaryTaskPlan {
        attribute taskId : ScalarValues::String;
        attribute target : TargetObject;
        attribute entryPose : Pose3D;
        attribute goalPose : Pose3D;
        attribute passageMinimumRadius : Length_m;
        attribute requiredReach : Length_m;
        attribute maximumAllowedError : Length_m;
        attribute maximumAllowedCompletionTime : Time_s;
    }

    item def TaskResult {
        attribute taskId : ScalarValues::String;
        attribute completed : ScalarValues::Boolean;
        attribute deliveredTargetPose : Pose3D;
        attribute finalQuality : QualityMetrics;
        attribute elapsedTime : Time_s;
        attribute operatorMessage : ScalarValues::String;
    }

    item def ContactInteraction {
        attribute contactDetected : ScalarValues::Boolean;
        attribute contactWrench : Wrench6D;
        attribute surfaceNormalX : ScalarValues::Real;
        attribute surfaceNormalY : ScalarValues::Real;
        attribute surfaceNormalZ : ScalarValues::Real;
    }

    item def FaultReport {
        attribute code : ScalarValues::String;
        attribute severity : FaultSeverity;
        attribute message : ScalarValues::String;
        attribute detectedTime : Time_s;
        attribute safeStopRequired : ScalarValues::Boolean;
    }

    port def ElectricalPowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def ElectricalPowerOutputPort {
        out item powerOut : ElectricalPower;
    }

    port def ControlCommandPort {
        in item command : MotionCommand;
        out item telemetry : RobotTelemetry;
        out item fault : FaultReport;
    }

    port def ControllerRobotPort {
        out item motionCommand : MotionCommand;
        out item tendonLengthCommand : TendonLengthCommand;
        out item tendonTensionCommand : TendonTensionCommand;
        in item shapeEstimate : ShapeEstimate;
        in item robotTelemetry : RobotTelemetry;
        in item contact : ContactInteraction;
        in item faultReport : FaultReport;
    }

    port def ActuatorDrivePort {
        in item lengthCommand : TendonLengthCommand;
        in item tensionCommand : TendonTensionCommand;
        out item measuredTension : TendonTensionCommand;
    }

    port def ShapeSensorPort {
        out item shapeEstimate : ShapeEstimate;
    }

    port def VisionPort {
        out item frame : VisionFrame;
    }

    port def ToolCommandPort {
        in item command : MotionCommand;
        out item contact : ContactInteraction;
        out item telemetry : RobotTelemetry;
    }

    port def MechanicalContinuumPort {
        inout item interaction : ContactInteraction;
    }

    port def TaskPlanPort {
        in item plan : PrimaryTaskPlan;
        out item result : TaskResult;
    }

    constraint def TipAccuracyConstraint {
        in commandedPose : Pose3D;
        in measuredPose : Pose3D;
        in maximumError : Length_m;
        attribute squaredError : ScalarValues::Real =
            (commandedPose.x - measuredPose.x) * (commandedPose.x - measuredPose.x) +
            (commandedPose.y - measuredPose.y) * (commandedPose.y - measuredPose.y) +
            (commandedPose.z - measuredPose.z) * (commandedPose.z - measuredPose.z);
        require constraint { squaredError <= maximumError * maximumError; }
    }

    constraint def CurvatureLimitConstraint {
        in curvature : CurvatureVector;
        in maximumCurvature : Curvature_1pm;
        require constraint {
            curvature.kappaX * curvature.kappaX + curvature.kappaY * curvature.kappaY <= maximumCurvature * maximumCurvature;
        }
    }

    constraint def ContactForceLimitConstraint {
        in wrench : Wrench6D;
        in maximumForce : Force_N;
        attribute forceMagnitudeSquared : ScalarValues::Real =
            wrench.forceX * wrench.forceX + wrench.forceY * wrench.forceY + wrench.forceZ * wrench.forceZ;
        require constraint { forceMagnitudeSquared <= maximumForce * maximumForce; }
    }

    constraint def PassageFitConstraint {
        in robotOuterDiameter : Length_m;
        in passageMinimumRadius : Length_m;
        attribute robotRadius : Length_m = robotOuterDiameter / 2.0;
        require constraint { robotRadius < passageMinimumRadius; }
    }

    action def ReceiveMissionPlan {
        in item submittedPlan : PrimaryTaskPlan;
        out item acceptedPlan : PrimaryTaskPlan;
    }

    action def CalibrateContinuumRobot {
        in item plan : PrimaryTaskPlan;
        out item initialShape : ShapeEstimate;
    }

    action def EstimateBackboneShape {
        in item rawShape : ShapeEstimate;
        out item filteredShape : ShapeEstimate;
    }

    action def PlanCurvatureTrajectory {
        in item plan : PrimaryTaskPlan;
        in item currentShape : ShapeEstimate;
        out item trajectoryCommand : MotionCommand;
    }

    action def InsertContinuumArm {
        in item trajectoryCommand : MotionCommand;
        out item insertionTelemetry : RobotTelemetry;
    }

    action def ServoTipToTarget {
        in item command : MotionCommand;
        in item shapeEstimate : ShapeEstimate;
        in item visionFrame : VisionFrame;
        out item stabilizedTelemetry : RobotTelemetry;
    }

    action def EngageEndEffector {
        in item target : TargetObject;
        in item stabilizedTelemetry : RobotTelemetry;
        out item graspContact : ContactInteraction;
    }

    action def RetractContinuumArm {
        in item graspContact : ContactInteraction;
        out item retractedTelemetry : RobotTelemetry;
    }

    action def ReleasePayload {
        in item retractedTelemetry : RobotTelemetry;
        out item releaseTelemetry : RobotTelemetry;
    }

    action def PublishTaskResult {
        in item plan : PrimaryTaskPlan;
        in item finalTelemetry : RobotTelemetry;
        out item result : TaskResult;
    }

    action def ExecuteContinuumPrimaryTask {
        in item plan : PrimaryTaskPlan;
        in item vision : VisionFrame;
        out item result : TaskResult;

        action receive : ReceiveMissionPlan {
            in item submittedPlan = plan;
        }

        then action calibrate : CalibrateContinuumRobot {
            in item plan = receive.acceptedPlan;
        }

        then action estimate : EstimateBackboneShape {
            in item rawShape = calibrate.initialShape;
        }

        then action planCurvature : PlanCurvatureTrajectory {
            in item plan = receive.acceptedPlan;
            in item currentShape = estimate.filteredShape;
        }

        then action insert : InsertContinuumArm {
            in item trajectoryCommand = planCurvature.trajectoryCommand;
        }

        then action servo : ServoTipToTarget {
            in item command = planCurvature.trajectoryCommand;
            in item shapeEstimate = estimate.filteredShape;
            in item visionFrame = vision;
        }

        then action engageTool : EngageEndEffector {
            in item target = receive.acceptedPlan.target;
            in item stabilizedTelemetry = servo.stabilizedTelemetry;
        }

        then action retract : RetractContinuumArm {
            in item graspContact = engageTool.graspContact;
        }

        then action release : ReleasePayload {
            in item retractedTelemetry = retract.retractedTelemetry;
        }

        then action report : PublishTaskResult {
            in item plan = receive.acceptedPlan;
            in item finalTelemetry = release.releaseTelemetry;
            out item result = result;
        }
    }

    state def ContinuumSystemLifecycle {
        state poweredOff;
        state initializing;
        state standby;
        state calibrating;
        state planning;
        state executingPrimaryTask {
            state inserting;
            state navigating;
            state toolOperation;
            state retracting;
            transition insertToNavigate first inserting then navigating;
            transition navigateToToolOperation first navigating then toolOperation;
            transition toolOperationToRetract first toolOperation then retracting;
        }
        state paused;
        state completed;
        state faulted;
        state safeStop;

        transition powerOn first poweredOff then initializing;
        transition initializationComplete first initializing then standby;
        transition missionAccepted first standby then calibrating;
        transition calibrationComplete first calibrating then planning;
        transition planReady first planning then executingPrimaryTask.inserting;
        transition taskComplete first executingPrimaryTask.retracting then completed;
        transition resetForNextMission first completed then standby;
        transition operatorPause first executingPrimaryTask then paused;
        transition operatorResume first paused then executingPrimaryTask;
        transition recoverableFault first executingPrimaryTask then faulted;
        transition calibrationFault first calibrating then faulted;
        transition planningFault first planning then faulted;
        transition emergencyStop first executingPrimaryTask then safeStop;
        transition safeStopFromFault first faulted then safeStop;
        transition powerDown first standby then poweredOff;
    }

    part def RegulatedPowerSupply {
        attribute inputVoltage : Voltage_V = 230 [SI::V];
        attribute controlVoltage : Voltage_V = 24 [SI::V];
        attribute motorVoltage : Voltage_V = 48 [SI::V];
        attribute maximumContinuousPower : Power_W = 1500 [SI::W];
        attribute emergencyDisconnectTime : Time_s = 0.25 [SI::s];

        port mainsInput : ElectricalPowerInputPort;
        port controlOutput : ElectricalPowerOutputPort;
        port motorOutput : ElectricalPowerOutputPort;
    }

    part def OperatorStation {
        attribute displayUpdatePeriod : Time_s = 0.05 [SI::s];
        attribute missionApprovalRequired : ScalarValues::Boolean = true;

        port taskInterface : TaskPlanPort;
        port robotCommand : ControlCommandPort;
        port powerInput : ElectricalPowerInputPort;
    }

    part def MotionController {
        attribute servoPeriod : Time_s = 0.002 [SI::s];
        attribute planningPeriod : Time_s = 0.050 [SI::s];
        attribute maximumAllowedTipError : Length_m = 0.002 [SI::m];
        attribute maximumAllowedContactForce : Force_N = 8.0 [SI::N];
        attribute commandedMode : ContinuumDriveMode = ContinuumDriveMode::tipPoseClosedLoop;

        port operatorControl : ControlCommandPort;
        port robotInterface : ControllerRobotPort;
        port visionInput : VisionPort;
        port powerInput : ElectricalPowerInputPort;

        perform action primaryTaskBehavior : ExecuteContinuumPrimaryTask;
    }

    part def TendonServoModule {
        attribute motorRatedPower : Power_W = 120 [SI::W];
        attribute encoderResolution : Length_m = 0.00001 [SI::m];
        attribute maximumTendonSpeed : Velocity_mps = 0.080 [SI::m / SI::s];
        attribute maximumTendonTension : Force_N = 45 [SI::N];
        attribute tendonPretension : Force_N = 5 [SI::N];

        port driveInput : ActuatorDrivePort;
        port powerInput : ElectricalPowerInputPort;
    }

    part def TendonActuationPack {
        attribute moduleCount : ScalarValues::Integer = 12;
        attribute totalRatedPower : Power_W = 1440 [SI::W];

        part section1Servo : TendonServoModule;
        part section2Servo : TendonServoModule;
        part section3Servo : TendonServoModule;

        port driveInput : ActuatorDrivePort;
        port motorPowerInput : ElectricalPowerInputPort;
    }

    part def ElasticBackbone {
        attribute freeLength : Length_m = 0.350 [SI::m];
        attribute outerDiameter : Length_m = 0.018 [SI::m];
        attribute centralLumenDiameter : Length_m = 0.006 [SI::m];
        attribute bendingStiffness : ScalarValues::Real = 0.42;
        attribute torsionalStiffness : ScalarValues::Real = 0.18;
        attribute materialName : ScalarValues::String = "superelastic-nitinol-and-silicone-composite";
    }

    part def SpacerDisk {
        attribute diameter : Length_m = 0.030 [SI::m];
        attribute thickness : Length_m = 0.004 [SI::m];
        attribute tendonHoleRadius : Length_m = 0.012 [SI::m];
        attribute holeCount : ScalarValues::Integer = 4;
    }

    part def Tendon {
        attribute diameter : Length_m = 0.0008 [SI::m];
        attribute allowableTension : Force_N = 45 [SI::N];
        attribute materialName : ScalarValues::String = "UHMWPE";
    }

    part def FiberBraggShapeSensor {
        attribute samplePeriod : Time_s = 0.005 [SI::s];
        attribute axialResolution : Length_m = 0.010 [SI::m];
        attribute curvatureNoise : Curvature_1pm = 0.02;
        attribute tipPoseNoise : Length_m = 0.001 [SI::m];

        port shapeOutput : ShapeSensorPort;
        port powerInput : ElectricalPowerInputPort;
    }

    part def ContinuumSection {
        attribute sectionIndex : ScalarValues::Integer;
        attribute sectionLength : Length_m = 0.350 [SI::m];
        attribute outerDiameter : Length_m = 0.032 [SI::m];
        attribute maximumCurvature : Curvature_1pm = 3.2;
        attribute nominalCurvature : CurvatureVector;
        attribute maximumAxialCompression : Force_N = 25 [SI::N];

        part backbone : ElasticBackbone;
        part disk1 : SpacerDisk;
        part disk2 : SpacerDisk;
        part disk3 : SpacerDisk;
        part disk4 : SpacerDisk;
        part disk5 : SpacerDisk;
        part tendon1 : Tendon;
        part tendon2 : Tendon;
        part tendon3 : Tendon;
        part tendon4 : Tendon;

        port proximalMechanical : MechanicalContinuumPort;
        port distalMechanical : MechanicalContinuumPort;
        port tendonDrive : ActuatorDrivePort;
        port shapeSense : ShapeSensorPort;

        assert constraint sectionCurvatureLimit : CurvatureLimitConstraint {
            in curvature = nominalCurvature;
            in maximumCurvature = maximumCurvature;
        }
    }

    part def TipForceTorqueSensor {
        attribute forceRange : Force_N = 30 [SI::N];
        attribute torqueRange : Torque_Nm = 1.5 [SI::N * SI::m];
        attribute forceResolution : Force_N = 0.05 [SI::N];

        port contactOutput : ToolCommandPort;
        port powerInput : ElectricalPowerInputPort;
    }

    part def MicroGripper {
        attribute jawOpening : Length_m = 0.020 [SI::m];
        attribute maximumGripForce : Force_N = 12 [SI::N];
        attribute minimumReliableGripForce : Force_N = 2 [SI::N];
        attribute mass : Mass_kg = 0.090 [SI::kg];

        port toolControl : ToolCommandPort;
        port powerInput : ElectricalPowerInputPort;
        port mechanicalMount : MechanicalContinuumPort;
    }

    part def ContinuumManipulator {
        attribute isPrimaryTaskExecutor : ScalarValues::Boolean = true;
        attribute totalContinuumLength : Length_m = 1.050 [SI::m];
        attribute outerDiameter : Length_m = 0.032 [SI::m];
        attribute minimumBendRadius : Length_m = 0.3125 [SI::m];
        attribute maximumReach : Length_m = 0.920 [SI::m];
        attribute payloadAtFullReach : Mass_kg = 0.150 [SI::kg];
        attribute maximumTipSpeed : Velocity_mps = 0.050 [SI::m / SI::s];
        attribute maximumSafeContactForce : Force_N = 8.0 [SI::N];

        part actuationPack : TendonActuationPack;
        part baseShapeSensor : FiberBraggShapeSensor;
        part section1 : ContinuumSection {
            :>> sectionIndex = 1;
            :>> sectionLength = 0.350 [SI::m];
            :>> maximumCurvature = 2.8;
        }
        part section2 : ContinuumSection {
            :>> sectionIndex = 2;
            :>> sectionLength = 0.350 [SI::m];
            :>> maximumCurvature = 3.0;
        }
        part section3 : ContinuumSection {
            :>> sectionIndex = 3;
            :>> sectionLength = 0.350 [SI::m];
            :>> maximumCurvature = 3.2;
        }
        part tipSensor : TipForceTorqueSensor;
        part endEffector : MicroGripper;

        port control : ControllerRobotPort;
        port powerInput : ElectricalPowerInputPort;
        port proximalBase : MechanicalContinuumPort;
        port distalTip : MechanicalContinuumPort;

        connection actuationToSection1 connect actuationPack.driveInput to section1.tendonDrive;
        connection actuationToSection2 connect actuationPack.driveInput to section2.tendonDrive;
        connection actuationToSection3 connect actuationPack.driveInput to section3.tendonDrive;
        connection section1ToSection2 connect section1.distalMechanical to section2.proximalMechanical;
        connection section2ToSection3 connect section2.distalMechanical to section3.proximalMechanical;
        connection section3ToTipSensor connect section3.distalMechanical to tipSensor.contactOutput;
        connection tipSensorToTool connect tipSensor.contactOutput to endEffector.toolControl;
        connection toolMount connect endEffector.mechanicalMount to distalTip;
        connection shapeSensorToSection1 connect baseShapeSensor.shapeOutput to section1.shapeSense;
        connection shapeSensorToSection2 connect baseShapeSensor.shapeOutput to section2.shapeSense;
        connection shapeSensorToSection3 connect baseShapeSensor.shapeOutput to section3.shapeSense;

        assert constraint passageCompatibility : PassageFitConstraint {
            in robotOuterDiameter = outerDiameter;
            in passageMinimumRadius = 0.020 [SI::m];
        }
    }

    part def StereoVisionSensor {
        attribute baseline : Length_m = 0.070 [SI::m];
        attribute framePeriod : Time_s = 0.033 [SI::s];
        attribute workingDistanceMinimum : Length_m = 0.080 [SI::m];
        attribute workingDistanceMaximum : Length_m = 1.200 [SI::m];
        attribute targetPoseAccuracy : Length_m = 0.003 [SI::m];

        port visionOutput : VisionPort;
        port powerInput : ElectricalPowerInputPort;
    }

    part def ConstrainedPassage {
        attribute length : Length_m = 0.750 [SI::m];
        attribute minimumRadius : Length_m = 0.020 [SI::m];
        attribute bendAngle : Angle_rad = 1.5708 [SI::rad];
        attribute wallAllowableNormalForce : Force_N = 10 [SI::N];
    }

    part def TaskFixture {
        attribute fixturePose : Pose3D;
        attribute targetPocketDiameter : Length_m = 0.045 [SI::m];
        attribute deliveryPocketDiameter : Length_m = 0.050 [SI::m];

        part passage : ConstrainedPassage;
    }

    part def Workcell {
        attribute guardedVolumeLength : Length_m = 2.000 [SI::m];
        attribute guardedVolumeWidth : Length_m = 1.200 [SI::m];
        attribute guardedVolumeHeight : Length_m = 1.500 [SI::m];
        attribute humanPresenceInterlockActive : ScalarValues::Boolean = true;

        part fixture : TaskFixture;
        part target : TargetObject {
            :>> objectId = "sample-capsule-17";
            :>> mass = 0.080 [SI::kg];
            :>> minimumGripForce = 3.0 [SI::N];
            :>> allowableContactForce = 8.0 [SI::N];
        }
    }

    part def SafetySupervisor {
        attribute forceTripThreshold : Force_N = 8.0 [SI::N];
        attribute curvatureTripMargin : Percent = 90.0;
        attribute watchdogTimeout : Time_s = 0.020 [SI::s];
        attribute emergencyStopLatency : Time_s = 0.100 [SI::s];

        port controllerMonitor : ControllerRobotPort;
        port powerControl : ElectricalPowerOutputPort;
    }

    part def ContinuumPrimaryTaskRoboticSystem {
        attribute systemName : ScalarValues::String = "ContinuumPrimaryTaskRobot";
        attribute primaryTaskDescription : ScalarValues::String = "Navigate through a curved constrained passage, grasp a target capsule using a continuum manipulator, retract, and deliver it to the operator-side fixture.";
        attribute mode : SystemMode = SystemMode::poweredOff;
        attribute requiredReach : Length_m = 0.800 [SI::m];
        attribute requiredTipAccuracy : Length_m = 0.002 [SI::m];
        attribute maximumTaskTime : Time_s = 180 [SI::s];

        part powerSupply : RegulatedPowerSupply;
        part operatorStation : OperatorStation;
        part controller : MotionController;
        part safetySupervisor : SafetySupervisor;
        part visionSensor : StereoVisionSensor;
        part continuumRobot : ContinuumManipulator;
        part workcell : Workcell;

        port externalTaskPort : TaskPlanPort;
        port externalPowerPort : ElectricalPowerInputPort;

        connection mainsToSupply connect externalPowerPort to powerSupply.mainsInput;
        connection supplyToController connect powerSupply.controlOutput to controller.powerInput;
        connection supplyToOperatorStation connect powerSupply.controlOutput to operatorStation.powerInput;
        connection supplyToVision connect powerSupply.controlOutput to visionSensor.powerInput;
        connection supplyToRobotControl connect powerSupply.controlOutput to continuumRobot.powerInput;
        connection supplyToRobotActuation connect powerSupply.motorOutput to continuumRobot.actuationPack.motorPowerInput;
        connection operatorToController connect operatorStation.robotCommand to controller.operatorControl;
        connection externalMissionToOperator connect externalTaskPort to operatorStation.taskInterface;
        connection controllerToContinuumRobot connect controller.robotInterface to continuumRobot.control;
        connection visionToController connect visionSensor.visionOutput to controller.visionInput;
        connection safetyMonitorToRobot connect safetySupervisor.controllerMonitor to continuumRobot.control;
        connection safetyPowerAuthority connect safetySupervisor.powerControl to powerSupply.motorOutput;
        connection robotBaseToFixture connect continuumRobot.proximalBase to workcell.fixture.passage;
        connection robotTipToTargetArea connect continuumRobot.distalTip to workcell.fixture;

        perform action executePrimaryTask : ExecuteContinuumPrimaryTask;

        exhibit state lifecycle : ContinuumSystemLifecycle;

        assert constraint reachRequirementConstraint {
            requiredReach <= continuumRobot.maximumReach;
        }

        assert constraint contactForceConstraint : ContactForceLimitConstraint {
            in wrench = continuumRobot.control.contact.contactWrench;
            in maximumForce = continuumRobot.maximumSafeContactForce;
        }
    }

    requirement def PrimaryTaskContinuumUseRequirement {
        subject system : ContinuumPrimaryTaskRoboticSystem;
        require constraint { system.continuumRobot.isPrimaryTaskExecutor == true; }
    }

    requirement def ReachRequirement {
        subject system : ContinuumPrimaryTaskRoboticSystem;
        require constraint { system.continuumRobot.maximumReach >= system.requiredReach; }
    }

    requirement def TipAccuracyRequirement {
        subject system : ContinuumPrimaryTaskRoboticSystem;
        require constraint { system.requiredTipAccuracy <= 0.002 [SI::m]; }
    }

    requirement def ConstrainedPassageCompatibilityRequirement {
        subject system : ContinuumPrimaryTaskRoboticSystem;
        require constraint { system.continuumRobot.outerDiameter / 2.0 < system.workcell.fixture.passage.minimumRadius; }
    }

    requirement def ContactForceSafetyRequirement {
        subject system : ContinuumPrimaryTaskRoboticSystem;
        require constraint { system.continuumRobot.maximumSafeContactForce <= system.workcell.fixture.passage.wallAllowableNormalForce; }
    }

    requirement def ShapeSensingRequirement {
        subject robot : ContinuumManipulator;
        require constraint { robot.baseShapeSensor.tipPoseNoise <= 0.001 [SI::m]; }
    }

    requirement def TaskCompletionTimeRequirement {
        subject system : ContinuumPrimaryTaskRoboticSystem;
        require constraint { system.maximumTaskTime <= 180 [SI::s]; }
    }

    requirement def FaultSafeStopRequirement {
        subject supervisor : SafetySupervisor;
        require constraint { supervisor.emergencyStopLatency <= 0.100 [SI::s]; }
    }

    requirement def PayloadRequirement {
        subject system : ContinuumPrimaryTaskRoboticSystem;
        require constraint { system.continuumRobot.payloadAtFullReach >= system.workcell.target.mass; }
    }

    part continuumPrimaryTaskSystem : ContinuumPrimaryTaskRoboticSystem;

    requirement primaryTaskUsesContinuumRobot : PrimaryTaskContinuumUseRequirement {
        subject system = continuumPrimaryTaskSystem;
    }

    requirement reachCapability : ReachRequirement {
        subject system = continuumPrimaryTaskSystem;
    }

    requirement tipAccuracy : TipAccuracyRequirement {
        subject system = continuumPrimaryTaskSystem;
    }

    requirement passageCompatibility : ConstrainedPassageCompatibilityRequirement {
        subject system = continuumPrimaryTaskSystem;
    }

    requirement contactForceSafety : ContactForceSafetyRequirement {
        subject system = continuumPrimaryTaskSystem;
    }

    requirement shapeSensingAccuracy : ShapeSensingRequirement {
        subject robot = continuumPrimaryTaskSystem.continuumRobot;
    }

    requirement taskCompletionTime : TaskCompletionTimeRequirement {
        subject system = continuumPrimaryTaskSystem;
    }

    requirement faultSafeStop : FaultSafeStopRequirement {
        subject supervisor = continuumPrimaryTaskSystem.safetySupervisor;
    }

    requirement payloadCapacity : PayloadRequirement {
        subject system = continuumPrimaryTaskSystem;
    }

    satisfy primaryTaskUsesContinuumRobot by continuumPrimaryTaskSystem.continuumRobot;
    satisfy reachCapability by continuumPrimaryTaskSystem.continuumRobot;
    satisfy tipAccuracy by continuumPrimaryTaskSystem.controller;
    satisfy passageCompatibility by continuumPrimaryTaskSystem.continuumRobot;
    satisfy contactForceSafety by continuumPrimaryTaskSystem.safetySupervisor;
    satisfy shapeSensingAccuracy by continuumPrimaryTaskSystem.continuumRobot.baseShapeSensor;
    satisfy taskCompletionTime by continuumPrimaryTaskSystem.executePrimaryTask;
    satisfy faultSafeStop by continuumPrimaryTaskSystem.safetySupervisor;
    satisfy payloadCapacity by continuumPrimaryTaskSystem.continuumRobot.endEffector;
}
