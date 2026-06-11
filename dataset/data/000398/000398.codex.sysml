package PersonalRobotPrimaryTaskSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import Quantities::*;

    attribute def Percent :> ScalarValues::Real {
        doc /* Percentage value normalized to 0..100. */
    }

    attribute def BatteryStateOfCharge :> Percent {
        doc /* Remaining battery charge percentage. */
    }

    attribute def Confidence :> Percent {
        doc /* Perception or decision confidence percentage. */
    }

    attribute def Distance :> ISQ::length {
        unit = SI::metre;
    }

    attribute def Speed :> ISQ::speed {
        unit = SI::metre_per_second;
    }

    attribute def Acceleration :> ISQ::acceleration {
        unit = SI::metre_per_second_squared;
    }

    attribute def Duration :> ISQ::time {
        unit = SI::second;
    }

    attribute def Mass :> ISQ::mass {
        unit = SI::kilogram;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Angle :> ISQ::planeAngle {
        unit = SI::radian;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    enum def RobotMode {
        enum idle;
        enum mapping;
        enum navigating;
        enum approaching;
        enum manipulating;
        enum delivering;
        enum charging;
        enum faulted;
    }

    enum def TaskStatus {
        enum requested;
        enum accepted;
        enum rejected;
        enum executing;
        enum paused;
        enum completed;
        enum failed;
    }

    enum def ObjectClass {
        enum cup;
        enum bottle;
        enum medicineBox;
        enum remoteControl;
        enum book;
        enum phone;
        enum tray;
    }

    enum def SurfaceClass {
        enum table;
        enum counter;
        enum shelf;
        enum floor;
        enum chargingDock;
        enum userHand;
    }

    enum def FaultKind {
        enum obstacleBlocked;
        enum objectNotFound;
        enum graspFailed;
        enum lowBattery;
        enum localizationLost;
        enum actuatorOverload;
        enum emergencyStop;
    }

    item def VoiceCommand {
        attribute phrase : String;
        attribute requestedObject : ObjectClass;
        attribute destination : String;
        attribute confidence : Confidence;
    }

    item def TaskRequest {
        attribute taskId : String;
        attribute requestedObject : ObjectClass;
        attribute pickupZone : String;
        attribute deliveryZone : String;
        attribute priority : Integer;
        attribute maxCompletionTime : Duration;
    }

    item def TaskReport {
        attribute taskId : String;
        attribute status : TaskStatus;
        attribute message : String;
        attribute elapsedTime : Duration;
        attribute remainingBattery : BatteryStateOfCharge;
    }

    item def MapUpdate {
        attribute updateId : String;
        attribute areaName : String;
        attribute occupiedCellCount : Integer;
        attribute confidence : Confidence;
    }

    item def Pose2D {
        attribute x : Distance;
        attribute y : Distance;
        attribute heading : Angle;
        attribute covarianceTrace : Real;
    }

    item def PlannedPath {
        attribute pathId : String;
        attribute length : Distance;
        attribute expectedTraversalTime : Duration;
        attribute minimumClearance : Distance;
    }

    item def MotionCommand {
        attribute linearSpeed : Speed;
        attribute angularSpeed : Angle;
        attribute allowedAcceleration : Acceleration;
    }

    item def ObjectDetection {
        attribute detectedClass : ObjectClass;
        attribute detectionConfidence : Confidence;
        attribute objectPose : Pose2D;
        attribute graspWidth : Distance;
        attribute estimatedMass : Mass;
    }

    item def GraspCommand {
        attribute targetClass : ObjectClass;
        attribute approachPose : Pose2D;
        attribute gripForce : Force;
        attribute liftHeight : Distance;
    }

    item def ManipulationStatus {
        attribute objectHeld : Boolean;
        attribute graspConfidence : Confidence;
        attribute wristLoad : Force;
    }

    item def PowerStatus {
        attribute batterySoc : BatteryStateOfCharge;
        attribute busVoltage : Voltage;
        attribute currentDraw : Current;
        attribute packTemperature : Temperature;
        attribute estimatedRuntime : Duration;
    }

    item def SafetyEvent {
        attribute fault : FaultKind;
        attribute severity : Integer;
        attribute stopRequired : Boolean;
        attribute description : String;
    }

    port def VoiceCommandPort {
        in item command : VoiceCommand;
    }

    port def TaskRequestPort {
        in item request : TaskRequest;
    }

    port def TaskReportPort {
        out item report : TaskReport;
    }

    port def MapPort {
        out item update : MapUpdate;
    }

    port def PosePort {
        out item pose : Pose2D;
    }

    port def PathPort {
        out item path : PlannedPath;
    }

    port def MotionCommandPort {
        in item command : MotionCommand;
    }

    port def ObjectDetectionPort {
        out item detection : ObjectDetection;
    }

    port def GraspCommandPort {
        in item command : GraspCommand;
    }

    port def ManipulationStatusPort {
        out item status : ManipulationStatus;
    }

    port def PowerStatusPort {
        out item status : PowerStatus;
    }

    port def SafetyEventPort {
        out item event : SafetyEvent;
    }

    port def EmergencyStopPort {
        in item event : SafetyEvent;
    }

    interface def TaskingInterface {
        end userSide : VoiceCommandPort;
        end robotSide : TaskRequestPort;
    }

    interface def ReportingInterface {
        end robotSide : TaskReportPort;
        end userSide : TaskReportPort;
    }

    interface def LocalizationInterface {
        end localizationSide : PosePort;
        end autonomySide : PosePort;
    }

    interface def PlanningInterface {
        end plannerSide : PathPort;
        end controllerSide : PathPort;
    }

    interface def PerceptionInterface {
        end sensorSide : ObjectDetectionPort;
        end autonomySide : ObjectDetectionPort;
    }

    interface def ManipulationInterface {
        end autonomySide : GraspCommandPort;
        end armSide : GraspCommandPort;
    }

    part def PersonalRobot {
        attribute mode : RobotMode = RobotMode::idle;
        attribute nominalMass : Mass = 28 [SI::kilogram];
        attribute maxPayloadMass : Mass = 2.0 [SI::kilogram];
        attribute maxSpeed : Speed = 1.0 [SI::metre_per_second];
        attribute minimumObstacleClearance : Distance = 0.30 [SI::metre];
        attribute nominalRuntime : Duration = 10800 [SI::second];

        port taskIn : TaskRequestPort;
        port voiceIn : VoiceCommandPort;
        port reportOut : TaskReportPort;
        port emergencyStopIn : EmergencyStopPort;
        port safetyOut : SafetyEventPort;

        part base : MobileBase;
        part perception : PerceptionSuite;
        part localization : LocalizationModule;
        part planner : TaskAndMotionPlanner;
        part manipulator : ManipulatorArm;
        part gripper : AdaptiveGripper;
        part power : BatterySubsystem;
        part safety : SafetySupervisor;
        part userInterface : HumanRobotInterface;
        part dockInterface : ChargingDockInterface;

        connect perception.detectionOut to planner.objectDetectionIn;
        connect localization.poseOut to planner.poseIn;
        connect planner.motionOut to base.motionIn;
        connect planner.graspOut to manipulator.graspIn;
        connect manipulator.statusOut to planner.manipulationStatusIn;
        connect power.statusOut to planner.powerStatusIn;
        connect power.statusOut to safety.powerStatusIn;
        connect perception.safetyOut to safety.perceptionSafetyIn;
        connect base.safetyOut to safety.motionSafetyIn;
        connect safety.eventOut to planner.safetyIn;
        connect safety.eventOut to safetyOut;
        connect userInterface.taskOut to taskIn;
        connect taskIn to planner.taskIn;
        connect voiceIn to userInterface.voiceIn;
        connect planner.reportOut to reportOut;
        connect emergencyStopIn to safety.emergencyStopIn;

        perform action acceptPrimaryTask;
        perform action executeFetchAndDeliverTask;
        exhibit state robotOperationalState;
    }

    part def MobileBase {
        attribute wheelDiameter : Distance = 0.165 [SI::metre];
        attribute trackWidth : Distance = 0.445 [SI::metre];
        attribute maximumSpeed : Speed = 1.0 [SI::metre_per_second];
        attribute maximumAcceleration : Acceleration = 0.7 [SI::metre_per_second_squared];
        attribute stoppingDistanceAtMaxSpeed : Distance = 0.45 [SI::metre];

        port motionIn : MotionCommandPort;
        port safetyOut : SafetyEventPort;
    }

    part def PerceptionSuite {
        attribute cameraHorizontalFov : Angle = 1.57 [SI::radian];
        attribute lidarRange : Distance = 8.0 [SI::metre];
        attribute minimumObjectDetectionConfidence : Confidence = 85.0;
        attribute objectClassificationLatency : Duration = 0.25 [SI::second];

        port detectionOut : ObjectDetectionPort;
        port safetyOut : SafetyEventPort;

        part rgbdCamera : RgbdCamera;
        part lidar : PlanarLidar;
        part microphoneArray : MicrophoneArray;
    }

    part def RgbdCamera {
        attribute depthRangeMin : Distance = 0.25 [SI::metre];
        attribute depthRangeMax : Distance = 5.0 [SI::metre];
        attribute framePeriod : Duration = 0.033 [SI::second];
    }

    part def PlanarLidar {
        attribute scanRange : Distance = 8.0 [SI::metre];
        attribute angularResolution : Angle = 0.0087 [SI::radian];
        attribute scanPeriod : Duration = 0.10 [SI::second];
    }

    part def MicrophoneArray {
        attribute microphoneCount : Integer = 4;
        attribute wakePhraseConfidenceThreshold : Confidence = 90.0;
    }

    part def LocalizationModule {
        attribute maximumPoseUncertainty : Distance = 0.10 [SI::metre];
        attribute updatePeriod : Duration = 0.05 [SI::second];

        port poseOut : PosePort;
        port mapOut : MapPort;
    }

    part def TaskAndMotionPlanner {
        attribute replanPeriod : Duration = 0.50 [SI::second];
        attribute maximumPathLength : Distance = 50.0 [SI::metre];
        attribute requiredDeliveryProximity : Distance = 0.60 [SI::metre];
        attribute lowBatteryTaskRejectThreshold : BatteryStateOfCharge = 20.0;

        port taskIn : TaskRequestPort;
        port poseIn : PosePort;
        port objectDetectionIn : ObjectDetectionPort;
        port manipulationStatusIn : ManipulationStatusPort;
        port powerStatusIn : PowerStatusPort;
        port safetyIn : EmergencyStopPort;
        port motionOut : MotionCommandPort;
        port graspOut : GraspCommandPort;
        port reportOut : TaskReportPort;

        perform action planFetchAndDeliver;
        perform action monitorTaskExecution;
    }

    part def ManipulatorArm {
        attribute degreeOfFreedom : Integer = 6;
        attribute reach : Distance = 0.75 [SI::metre];
        attribute repeatability : Distance = 0.005 [SI::metre];
        attribute maximumLiftMass : Mass = 2.0 [SI::kilogram];

        port graspIn : GraspCommandPort;
        port statusOut : ManipulationStatusPort;

        part wristForceTorqueSensor : WristForceTorqueSensor;
        part gripperMount : AdaptiveGripper;
    }

    part def WristForceTorqueSensor {
        attribute forceResolution : Force = 0.1 [SI::newton];
        attribute overloadForce : Force = 80.0 [SI::newton];
    }

    part def AdaptiveGripper {
        attribute minimumAperture : Distance = 0.0 [SI::metre];
        attribute maximumAperture : Distance = 0.095 [SI::metre];
        attribute maximumGripForce : Force = 35.0 [SI::newton];
        attribute closureTime : Duration = 0.80 [SI::second];
    }

    part def BatterySubsystem {
        attribute nominalVoltage : Voltage = 24.0 [SI::volt];
        attribute usableEnergy : Energy = 520 [SI::watt_hour];
        attribute minimumOperatingSoc : BatteryStateOfCharge = 10.0;
        attribute chargeCompleteSoc : BatteryStateOfCharge = 95.0;
        attribute maximumPackTemperature : Temperature = 323.15 [SI::kelvin];

        port statusOut : PowerStatusPort;
    }

    part def SafetySupervisor {
        attribute humanClearanceDistance : Distance = 0.45 [SI::metre];
        attribute emergencyStopLatency : Duration = 0.10 [SI::second];
        attribute maximumAllowedContactForce : Force = 45.0 [SI::newton];

        port powerStatusIn : PowerStatusPort;
        port perceptionSafetyIn : EmergencyStopPort;
        port motionSafetyIn : EmergencyStopPort;
        port emergencyStopIn : EmergencyStopPort;
        port eventOut : SafetyEventPort;

        perform action evaluateSafety;
    }

    part def HumanRobotInterface {
        attribute spokenLanguage : String = "en-US";
        attribute commandConfirmationTimeout : Duration = 10.0 [SI::second];

        port voiceIn : VoiceCommandPort;
        port taskOut : TaskRequestPort;
        port reportIn : TaskReportPort;
    }

    part def ChargingDockInterface {
        attribute dockingPoseTolerance : Distance = 0.04 [SI::metre];
        attribute chargePower : Power = 120.0 [SI::watt];
    }

    action def AcceptPrimaryTask {
        in item command : VoiceCommand;
        in item power : PowerStatus;
        out item request : TaskRequest;
        out item report : TaskReport;

        first start;
        then validateCommand;
        then checkBattery;
        then confirmTask;
        then produceTaskRequest;
        then done;

        action validateCommand {
            in item command : VoiceCommand;
            out attribute valid : Boolean;
        }

        action checkBattery {
            in item power : PowerStatus;
            out attribute sufficientEnergy : Boolean;
        }

        action confirmTask {
            in attribute valid : Boolean;
            in attribute sufficientEnergy : Boolean;
            out attribute accepted : Boolean;
        }

        action produceTaskRequest {
            in attribute accepted : Boolean;
            out item request : TaskRequest;
            out item report : TaskReport;
        }
    }

    action def PlanFetchAndDeliver {
        in item request : TaskRequest;
        in item currentPose : Pose2D;
        in item detection : ObjectDetection;
        out item path : PlannedPath;
        out item grasp : GraspCommand;
        out item report : TaskReport;

        first start;
        then buildRouteToPickup;
        then searchForObject;
        then computeApproachPose;
        then buildRouteToDelivery;
        then done;

        action buildRouteToPickup {
            in item request : TaskRequest;
            in item currentPose : Pose2D;
            out item pickupPath : PlannedPath;
        }

        action searchForObject {
            in item request : TaskRequest;
            in item detection : ObjectDetection;
            out attribute objectConfirmed : Boolean;
        }

        action computeApproachPose {
            in item detection : ObjectDetection;
            out item grasp : GraspCommand;
        }

        action buildRouteToDelivery {
            in item request : TaskRequest;
            out item deliveryPath : PlannedPath;
        }
    }

    action def ExecuteFetchAndDeliverTask {
        in item request : TaskRequest;
        out item report : TaskReport;

        first start;
        then navigateToPickup;
        then localizeObject;
        then graspObject;
        then verifyObjectHeld;
        then navigateToUser;
        then handOverObject;
        then sendCompletionReport;
        then done;

        action navigateToPickup {
            out item motion : MotionCommand;
        }

        action localizeObject {
            out item detection : ObjectDetection;
        }

        action graspObject {
            in item detection : ObjectDetection;
            out item grasp : GraspCommand;
        }

        action verifyObjectHeld {
            in item status : ManipulationStatus;
            out attribute verified : Boolean;
        }

        action navigateToUser {
            out item motion : MotionCommand;
        }

        action handOverObject {
            out item status : ManipulationStatus;
        }

        action sendCompletionReport {
            out item report : TaskReport;
        }
    }

    action def MonitorTaskExecution {
        in item pose : Pose2D;
        in item power : PowerStatus;
        in item manipulation : ManipulationStatus;
        in item safety : SafetyEvent;
        out item report : TaskReport;

        first start;
        then evaluateProgress;
        then evaluateEnergyMargin;
        then evaluateManipulationIntegrity;
        then evaluateSafetyState;
        then publishStatus;
        then done;

        action evaluateProgress {
            in item pose : Pose2D;
            out attribute onSchedule : Boolean;
        }

        action evaluateEnergyMargin {
            in item power : PowerStatus;
            out attribute energyAdequate : Boolean;
        }

        action evaluateManipulationIntegrity {
            in item manipulation : ManipulationStatus;
            out attribute objectSecure : Boolean;
        }

        action evaluateSafetyState {
            in item safety : SafetyEvent;
            out attribute continueAllowed : Boolean;
        }

        action publishStatus {
            out item report : TaskReport;
        }
    }

    action def EvaluateSafety {
        in item power : PowerStatus;
        in item obstacleEvent : SafetyEvent;
        in item emergencyStop : SafetyEvent;
        out item event : SafetyEvent;

        first start;
        then checkEmergencyStop;
        then checkBatterySafety;
        then checkObstacleClearance;
        then checkManipulatorLoad;
        then emitSafetyDecision;
        then done;

        action checkEmergencyStop {
            in item emergencyStop : SafetyEvent;
            out attribute stopRequested : Boolean;
        }

        action checkBatterySafety {
            in item power : PowerStatus;
            out attribute batterySafe : Boolean;
        }

        action checkObstacleClearance {
            in item obstacleEvent : SafetyEvent;
            out attribute clearanceSafe : Boolean;
        }

        action checkManipulatorLoad {
            out attribute loadSafe : Boolean;
        }

        action emitSafetyDecision {
            out item event : SafetyEvent;
        }
    }

    state def RobotOperationalState {
        entry action initializeSelfCheck;

        state idle;
        state acceptingTask;
        state planning;
        state navigatingToPickup;
        state searchingForObject;
        state graspingObject;
        state navigatingToDelivery;
        state deliveringObject;
        state returningToDock;
        state charging;
        state faulted;

        transition initial then idle;

        transition idle_to_accepting
            first idle
            accept TaskRequest
            then acceptingTask;

        transition accepting_to_planning
            first acceptingTask
            if acceptPrimaryTaskAccepted
            then planning;

        transition accepting_to_idle
            first acceptingTask
            if acceptPrimaryTaskRejected
            then idle;

        transition planning_to_pickup
            first planning
            if pathAvailable and batteryAdequate
            then navigatingToPickup;

        transition planning_to_fault
            first planning
            if noFeasiblePath or localizationLost
            then faulted;

        transition pickup_to_search
            first navigatingToPickup
            if arrivedAtPickupZone
            then searchingForObject;

        transition search_to_grasp
            first searchingForObject
            if objectDetected and detectionConfidenceAdequate
            then graspingObject;

        transition search_to_fault
            first searchingForObject
            if objectNotFoundTimeout
            then faulted;

        transition grasp_to_delivery
            first graspingObject
            if objectHeld
            then navigatingToDelivery;

        transition grasp_retry
            first graspingObject
            if graspFailed and retryCountBelowLimit
            then searchingForObject;

        transition grasp_to_fault
            first graspingObject
            if graspFailed and retryCountLimitReached
            then faulted;

        transition delivery_to_handover
            first navigatingToDelivery
            if arrivedAtDeliveryZone
            then deliveringObject;

        transition handover_to_idle
            first deliveringObject
            if objectReleased and completionReported
            then idle;

        transition any_to_returningDock
            first idle
            if batterySocBelowDockThreshold
            then returningToDock;

        transition returningDock_to_charging
            first returningToDock
            if docked
            then charging;

        transition charging_to_idle
            first charging
            if batterySocAboveReadyThreshold
            then idle;

        transition any_to_fault
            first idle
            accept SafetyEvent
            then faulted;

        transition fault_to_idle
            first faulted
            if faultCleared and operatorAcknowledged
            then idle;
    }

    requirement def PrimaryTaskRequirement {
        doc /* The robotic system shall perform its primary fetch-and-deliver task using a PersonalRobot as the executing robot. */
        subject robot : PersonalRobot;
        require constraint {
            robot.maxPayloadMass >= 2.0 [SI::kilogram]
        }
    }

    requirement def VoiceTaskingRequirement {
        doc /* The system shall accept a spoken user command and convert it into a structured task request when recognition confidence is at least 90 percent. */
        subject hri : HumanRobotInterface;
        require constraint {
            hri.commandConfirmationTimeout <= 10.0 [SI::second]
        }
    }

    requirement def NavigationRequirement {
        doc /* The PersonalRobot shall navigate indoor paths while maintaining at least 0.30 m clearance from static obstacles and 0.45 m clearance from detected humans. */
        subject robot : PersonalRobot;
        require constraint {
            robot.minimumObstacleClearance >= 0.30 [SI::metre]
        }
    }

    requirement def ObjectHandlingRequirement {
        doc /* The manipulator shall grasp and carry household objects up to 2.0 kg within a reach envelope of at least 0.75 m. */
        subject arm : ManipulatorArm;
        require constraint {
            arm.maximumLiftMass >= 2.0 [SI::kilogram] and arm.reach >= 0.75 [SI::metre]
        }
    }

    requirement def DeliveryAccuracyRequirement {
        doc /* The PersonalRobot shall deliver the requested object within 0.60 m of the requested destination or directly to the user's handover surface. */
        subject planner : TaskAndMotionPlanner;
        require constraint {
            planner.requiredDeliveryProximity <= 0.60 [SI::metre]
        }
    }

    requirement def BatteryRequirement {
        doc /* The PersonalRobot shall reject new primary tasks when battery state of charge is below 20 percent and shall retain at least 10 percent state of charge for safe docking. */
        subject planner : TaskAndMotionPlanner;
        require constraint {
            planner.lowBatteryTaskRejectThreshold >= 20.0
        }
    }

    requirement def SafetyStopRequirement {
        doc /* The safety supervisor shall command a stop within 0.10 s after emergency stop activation or unsafe contact detection. */
        subject safety : SafetySupervisor;
        require constraint {
            safety.emergencyStopLatency <= 0.10 [SI::second]
        }
    }

    requirement def PerceptionRequirement {
        doc /* The perception suite shall classify the requested object with at least 85 percent confidence before grasp execution. */
        subject perception : PerceptionSuite;
        require constraint {
            perception.minimumObjectDetectionConfidence >= 85.0
        }
    }

    requirement def RuntimeRequirement {
        doc /* The PersonalRobot shall support at least three hours of nominal indoor operation before charging is required. */
        subject robot : PersonalRobot;
        require constraint {
            robot.nominalRuntime >= 10800 [SI::second]
        }
    }

    part personalRobotPrimaryTaskSystem {
        attribute supportedEnvironment : String = "indoor home or assisted living apartment";
        attribute primaryTaskName : String = "fetch and deliver requested household object";
        attribute maximumNominalTaskTime : Duration = 300 [SI::second];

        part personalRobot : PersonalRobot;
        part user : User;
        part homeEnvironment : HomeEnvironment;
        part chargingDock : ChargingDock;

        connect user.voiceCommandOut to personalRobot.voiceIn;
        connect personalRobot.reportOut to user.taskReportIn;
        connect homeEnvironment.mapUpdateOut to personalRobot.localization.mapOut;
        connect chargingDock.powerStatusOut to personalRobot.power.statusOut;

        satisfy PrimaryTaskRequirement by personalRobot;
        satisfy VoiceTaskingRequirement by personalRobot.userInterface;
        satisfy NavigationRequirement by personalRobot;
        satisfy ObjectHandlingRequirement by personalRobot.manipulator;
        satisfy DeliveryAccuracyRequirement by personalRobot.planner;
        satisfy BatteryRequirement by personalRobot.planner;
        satisfy SafetyStopRequirement by personalRobot.safety;
        satisfy PerceptionRequirement by personalRobot.perception;
        satisfy RuntimeRequirement by personalRobot;
    }

    part def User {
        attribute preferredDeliveryZone : String = "living_room_seated_position";
        attribute minimumSpeechConfidence : Confidence = 90.0;

        port voiceCommandOut : VoiceCommandPort;
        port taskReportIn : TaskReportPort;
    }

    part def HomeEnvironment {
        attribute navigableFloorArea : Area = 85 [SI::squareMetre];
        attribute minimumDoorWidth : Distance = 0.78 [SI::metre];
        attribute maximumThresholdHeight : Distance = 0.015 [SI::metre];

        port mapUpdateOut : MapPort;

        part pickupTable : PickupSurface {
            attribute surfaceType : SurfaceClass = SurfaceClass::table;
            attribute height : Distance = 0.74 [SI::metre];
        }

        part deliveryArea : DeliverySurface {
            attribute surfaceType : SurfaceClass = SurfaceClass::userHand;
            attribute height : Distance = 0.95 [SI::metre];
        }
    }

    part def PickupSurface {
        attribute surfaceType : SurfaceClass;
        attribute height : Distance;
        attribute usableWidth : Distance = 0.80 [SI::metre];
        attribute usableDepth : Distance = 0.50 [SI::metre];
    }

    part def DeliverySurface {
        attribute surfaceType : SurfaceClass;
        attribute height : Distance;
        attribute handoverClearance : Distance = 0.30 [SI::metre];
    }

    part def ChargingDock {
        attribute dockVoltage : Voltage = 24.0 [SI::volt];
        attribute maximumChargeCurrent : Current = 5.0 [SI::ampere];
        attribute dockingTargetWidth : Distance = 0.42 [SI::metre];

        port powerStatusOut : PowerStatusPort;
    }

}