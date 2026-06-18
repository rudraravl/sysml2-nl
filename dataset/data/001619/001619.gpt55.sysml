package VehicularAutomationSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def TimeValue :> ISQ::time;
    attribute def LengthValue :> ISQ::length;
    attribute def SpeedValue :> ISQ::speed;
    attribute def AccelerationValue :> ISQ::acceleration;
    attribute def AngleValue :> ISQ::planeAngle;
    attribute def AngularRateValue;
    attribute def VoltageValue :> ISQ::electricPotential;
    attribute def CurrentValue :> ISQ::electricCurrent;
    attribute def TorqueValue :> ISQ::torque;
    attribute def ForceValue :> ISQ::force;
    attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
    attribute def DataRateValue;
    attribute def ProbabilityValue :> Real;
    attribute def PercentValue :> Real;

    enum def AutomationMode {
        enum off;
        enum standby;
        enum manualDriving;
        enum automatedDriving;
        enum degradedAutomatedDriving;
        enum minimalRiskManeuver;
        enum faulted;
    }

    enum def DrivingIntent {
        enum noRequest;
        enum engageAutomation;
        enum disengageAutomation;
        enum changeDestination;
        enum emergencyStop;
    }

    enum def RoadObjectKind {
        enum passengerVehicle;
        enum truck;
        enum motorcycle;
        enum bicycle;
        enum pedestrian;
        enum animal;
        enum staticObstacle;
        enum trafficCone;
        enum unknown;
    }

    enum def LaneBoundaryKind {
        enum solidWhite;
        enum dashedWhite;
        enum solidYellow;
        enum dashedYellow;
        enum curb;
        enum roadEdge;
        enum unknown;
    }

    enum def FaultSeverity {
        enum informational;
        enum degraded;
        enum severe;
        enum critical;
    }

    enum def PowerState {
        enum unpowered;
        enum lowVoltageReady;
        enum highVoltageReady;
        enum emergencyIsolated;
    }

    item def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    item def Velocity3D {
        attribute vx : SpeedValue;
        attribute vy : SpeedValue;
        attribute vz : SpeedValue;
    }

    item def Orientation3D {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def EgoPose {
        attribute timestamp : TimeValue;
        attribute position : Position3D;
        attribute orientation : Orientation3D;
        attribute longitudinalSpeed : SpeedValue;
        attribute lateralSpeed : SpeedValue;
        attribute yawRate : AngularRateValue;
        attribute positionUncertainty : LengthValue;
        attribute headingUncertainty : AngleValue;
    }

    item def CameraFrame {
        attribute timestamp : TimeValue;
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute frameRate : Real;
        attribute fieldOfView : AngleValue;
        attribute exposureTime : TimeValue;
    }

    item def RadarScan {
        attribute timestamp : TimeValue;
        attribute range : LengthValue;
        attribute rangeRate : SpeedValue;
        attribute azimuth : AngleValue;
        attribute elevation : AngleValue;
        attribute detectionCount : Integer;
    }

    item def LidarPointCloud {
        attribute timestamp : TimeValue;
        attribute pointCount : Integer;
        attribute horizontalFieldOfView : AngleValue;
        attribute verticalFieldOfView : AngleValue;
        attribute maximumRange : LengthValue;
    }

    item def GnssMeasurement {
        attribute timestamp : TimeValue;
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
        attribute horizontalAccuracy : LengthValue;
        attribute speedOverGround : SpeedValue;
        attribute heading : AngleValue;
    }

    item def ImuMeasurement {
        attribute timestamp : TimeValue;
        attribute longitudinalAcceleration : AccelerationValue;
        attribute lateralAcceleration : AccelerationValue;
        attribute verticalAcceleration : AccelerationValue;
        attribute rollRate : AngularRateValue;
        attribute pitchRate : AngularRateValue;
        attribute yawRate : AngularRateValue;
    }

    item def DetectedObject {
        attribute objectId : Integer;
        attribute kind : RoadObjectKind;
        attribute pose : Position3D;
        attribute velocity : Velocity3D;
        attribute width : LengthValue;
        attribute length : LengthValue;
        attribute height : LengthValue;
        attribute classificationConfidence : ProbabilityValue;
        attribute predictedTimeToCollision : TimeValue;
    }

    item def ObjectList {
        attribute timestamp : TimeValue;
        attribute objectCount : Integer;
        item objects : DetectedObject[0..200];
    }

    item def LaneBoundary {
        attribute boundaryId : Integer;
        attribute kind : LaneBoundaryKind;
        attribute confidence : ProbabilityValue;
        attribute lateralOffset : LengthValue;
        attribute curvature : Real;
    }

    item def LaneModel {
        attribute timestamp : TimeValue;
        attribute laneCount : Integer;
        item boundaries : LaneBoundary[0..12];
        attribute egoLaneWidth : LengthValue;
        attribute egoLaneCurvature : Real;
    }

    item def MapSegment {
        attribute segmentId : Integer;
        attribute speedLimit : SpeedValue;
        attribute laneCount : Integer;
        attribute roadGrade : AngleValue;
        attribute curvature : Real;
        attribute validHorizon : LengthValue;
    }

    item def Destination {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute preferredArrivalTime : TimeValue;
    }

    item def MissionPlan {
        attribute routeId : Integer;
        attribute routeLength : LengthValue;
        attribute estimatedTravelTime : TimeValue;
        attribute maximumAllowedSpeed : SpeedValue;
        item destination : Destination;
    }

    item def TrajectoryPoint {
        attribute relativeTime : TimeValue;
        attribute position : Position3D;
        attribute heading : AngleValue;
        attribute targetSpeed : SpeedValue;
        attribute targetAcceleration : AccelerationValue;
        attribute curvature : Real;
    }

    item def Trajectory {
        attribute timestamp : TimeValue;
        attribute horizonTime : TimeValue;
        attribute horizonDistance : LengthValue;
        attribute pointCount : Integer;
        item points : TrajectoryPoint[2..120];
    }

    item def MotionCommand {
        attribute timestamp : TimeValue;
        attribute targetSteeringAngle : AngleValue;
        attribute targetAcceleration : AccelerationValue;
        attribute targetSpeed : SpeedValue;
        attribute requestedBrakeForce : ForceValue;
        attribute requestedPropulsionTorque : TorqueValue;
    }

    item def VehicleActuationCommand {
        attribute timestamp : TimeValue;
        attribute steeringMotorTorque : TorqueValue;
        attribute brakePressureRequest : Real;
        attribute propulsionTorqueRequest : TorqueValue;
        attribute parkBrakeRequest : Boolean;
    }

    item def ActuatorFeedback {
        attribute timestamp : TimeValue;
        attribute actualSteeringAngle : AngleValue;
        attribute actualBrakePressure : Real;
        attribute actualPropulsionTorque : TorqueValue;
        attribute wheelSpeedFrontLeft : SpeedValue;
        attribute wheelSpeedFrontRight : SpeedValue;
        attribute wheelSpeedRearLeft : SpeedValue;
        attribute wheelSpeedRearRight : SpeedValue;
    }

    item def DriverIntent {
        attribute intent : DrivingIntent;
        attribute requestedMode : AutomationMode;
        item destination : Destination;
    }

    item def AutomationStatus {
        attribute mode : AutomationMode;
        attribute automationAvailable : Boolean;
        attribute operationalDesignDomainSatisfied : Boolean;
        attribute currentSpeed : SpeedValue;
        attribute distanceToDestination : LengthValue;
        attribute minimumTimeToCollision : TimeValue;
        attribute activeFaultSeverity : FaultSeverity;
    }

    item def SafetyEvent {
        attribute timestamp : TimeValue;
        attribute severity : FaultSeverity;
        attribute descriptionCode : Integer;
        attribute requiresMinimalRiskManeuver : Boolean;
    }

    item def PowerReport {
        attribute state : PowerState;
        attribute lowVoltageBus : VoltageValue;
        attribute highVoltageBus : VoltageValue;
        attribute currentDraw : CurrentValue;
        attribute electronicsTemperature : TemperatureValue;
    }

    port def CameraFrameOutPort {
        out item frame : CameraFrame;
    }

    port def CameraFrameInPort {
        in item frame : CameraFrame;
    }

    port def RadarScanOutPort {
        out item scan : RadarScan;
    }

    port def RadarScanInPort {
        in item scan : RadarScan;
    }

    port def LidarCloudOutPort {
        out item cloud : LidarPointCloud;
    }

    port def LidarCloudInPort {
        in item cloud : LidarPointCloud;
    }

    port def GnssOutPort {
        out item measurement : GnssMeasurement;
    }

    port def GnssInPort {
        in item measurement : GnssMeasurement;
    }

    port def ImuOutPort {
        out item measurement : ImuMeasurement;
    }

    port def ImuInPort {
        in item measurement : ImuMeasurement;
    }

    port def ObjectListOutPort {
        out item objects : ObjectList;
    }

    port def ObjectListInPort {
        in item objects : ObjectList;
    }

    port def LaneModelOutPort {
        out item lanes : LaneModel;
    }

    port def LaneModelInPort {
        in item lanes : LaneModel;
    }

    port def EgoPoseOutPort {
        out item pose : EgoPose;
    }

    port def EgoPoseInPort {
        in item pose : EgoPose;
    }

    port def MapSegmentOutPort {
        out item map : MapSegment;
    }

    port def MapSegmentInPort {
        in item map : MapSegment;
    }

    port def DriverIntentOutPort {
        out item intent : DriverIntent;
    }

    port def DriverIntentInPort {
        in item intent : DriverIntent;
    }

    port def MissionPlanOutPort {
        out item plan : MissionPlan;
    }

    port def MissionPlanInPort {
        in item plan : MissionPlan;
    }

    port def TrajectoryOutPort {
        out item trajectory : Trajectory;
    }

    port def TrajectoryInPort {
        in item trajectory : Trajectory;
    }

    port def MotionCommandOutPort {
        out item command : MotionCommand;
    }

    port def MotionCommandInPort {
        in item command : MotionCommand;
    }

    port def VehicleActuationCommandOutPort {
        out item command : VehicleActuationCommand;
    }

    port def VehicleActuationCommandInPort {
        in item command : VehicleActuationCommand;
    }

    port def ActuatorFeedbackOutPort {
        out item feedback : ActuatorFeedback;
    }

    port def ActuatorFeedbackInPort {
        in item feedback : ActuatorFeedback;
    }

    port def AutomationStatusOutPort {
        out item status : AutomationStatus;
    }

    port def AutomationStatusInPort {
        in item status : AutomationStatus;
    }

    port def SafetyEventOutPort {
        out item event : SafetyEvent;
    }

    port def SafetyEventInPort {
        in item event : SafetyEvent;
    }

    port def PowerReportOutPort {
        out item report : PowerReport;
    }

    port def PowerReportInPort {
        in item report : PowerReport;
    }

    constraint def MaintainSafeTimeGap {
        in actualTimeGap : TimeValue;
        in minimumTimeGap : TimeValue;
        constraint { actualTimeGap >= minimumTimeGap }
    }

    constraint def StayWithinSpeedLimit {
        in commandedSpeed : SpeedValue;
        in legalSpeedLimit : SpeedValue;
        constraint { commandedSpeed <= legalSpeedLimit }
    }

    constraint def KeepWithinLane {
        in lateralOffset : LengthValue;
        in allowedOffset : LengthValue;
        constraint { lateralOffset <= allowedOffset and lateralOffset >= -allowedOffset }
    }

    constraint def MaintainActuationLatency {
        in commandAge : TimeValue;
        in maximumCommandAge : TimeValue;
        constraint { commandAge <= maximumCommandAge }
    }

    action def SenseEnvironment {
        in item cameraFrame : CameraFrame;
        in item radarScan : RadarScan;
        in item lidarCloud : LidarPointCloud;
        out item detectedObjects : ObjectList;
        out item laneModel : LaneModel;
    }

    action def LocalizeVehicle {
        in item gnss : GnssMeasurement;
        in item imu : ImuMeasurement;
        in item map : MapSegment;
        out item egoPose : EgoPose;
    }

    action def PlanMission {
        in item driverIntent : DriverIntent;
        in item egoPose : EgoPose;
        in item map : MapSegment;
        out item missionPlan : MissionPlan;
    }

    action def PlanTrajectory {
        in item egoPose : EgoPose;
        in item missionPlan : MissionPlan;
        in item objects : ObjectList;
        in item lanes : LaneModel;
        in item map : MapSegment;
        out item trajectory : Trajectory;
        assert constraint safeGap : MaintainSafeTimeGap {
            in minimumTimeGap = 2.0 [s];
        }
        assert constraint speedCompliance : StayWithinSpeedLimit;
        assert constraint laneKeeping : KeepWithinLane {
            in allowedOffset = 0.35 [m];
        }
    }

    action def ControlMotion {
        in item egoPose : EgoPose;
        in item trajectory : Trajectory;
        in item feedback : ActuatorFeedback;
        out item motionCommand : MotionCommand;
    }

    action def TranslateToVehicleActuation {
        in item motionCommand : MotionCommand;
        out item vehicleCommand : VehicleActuationCommand;
        assert constraint latency : MaintainActuationLatency {
            in maximumCommandAge = 0.050 [s];
        }
    }

    action def SuperviseSafety {
        in item egoPose : EgoPose;
        in item objects : ObjectList;
        in item lanes : LaneModel;
        in item feedback : ActuatorFeedback;
        in item power : PowerReport;
        out item status : AutomationStatus;
        out item safetyEvent : SafetyEvent;
    }

    action def ExecuteMinimalRiskManeuver {
        in item egoPose : EgoPose;
        in item objects : ObjectList;
        out item vehicleCommand : VehicleActuationCommand;
        out item status : AutomationStatus;
    }

    action def AutomatedDrivingCycle {
        in item driverIntent : DriverIntent;
        in item cameraFrame : CameraFrame;
        in item radarScan : RadarScan;
        in item lidarCloud : LidarPointCloud;
        in item gnss : GnssMeasurement;
        in item imu : ImuMeasurement;
        in item map : MapSegment;
        in item feedback : ActuatorFeedback;
        in item power : PowerReport;
        out item vehicleCommand : VehicleActuationCommand;
        out item status : AutomationStatus;
        out item safetyEvent : SafetyEvent;

        action sense : SenseEnvironment {
            in item cameraFrame = AutomatedDrivingCycle::cameraFrame;
            in item radarScan = AutomatedDrivingCycle::radarScan;
            in item lidarCloud = AutomatedDrivingCycle::lidarCloud;
        }

        then action localize : LocalizeVehicle {
            in item gnss = AutomatedDrivingCycle::gnss;
            in item imu = AutomatedDrivingCycle::imu;
            in item map = AutomatedDrivingCycle::map;
        }

        then action mission : PlanMission {
            in item driverIntent = AutomatedDrivingCycle::driverIntent;
            in item egoPose = localize.egoPose;
            in item map = AutomatedDrivingCycle::map;
        }

        then action trajectory : PlanTrajectory {
            in item egoPose = localize.egoPose;
            in item missionPlan = mission.missionPlan;
            in item objects = sense.detectedObjects;
            in item lanes = sense.laneModel;
            in item map = AutomatedDrivingCycle::map;
        }

        then action control : ControlMotion {
            in item egoPose = localize.egoPose;
            in item trajectory = trajectory.trajectory;
            in item feedback = AutomatedDrivingCycle::feedback;
        }

        then action actuation : TranslateToVehicleActuation {
            in item motionCommand = control.motionCommand;
        }

        then action supervise : SuperviseSafety {
            in item egoPose = localize.egoPose;
            in item objects = sense.detectedObjects;
            in item lanes = sense.laneModel;
            in item feedback = AutomatedDrivingCycle::feedback;
            in item power = AutomatedDrivingCycle::power;
        }
    }

    event def PowerOn;
    event def PowerOff;
    event def AutomationRequested;
    event def AutomationAvailable;
    event def AutomationCancelled;
    event def AutomationFaultDetected;
    event def HazardDetected;
    event def MinimalRiskReached;
    event def FaultCleared;

    state def AutomationOperationalStates {
        state off;
        state standby;
        state manualDriving;
        state automatedDriving;
        state degradedAutomatedDriving;
        state minimalRiskManeuver;
        state faulted;

        transition initialToOff first off;

        transition powerOnToStandby
            from off
            to standby
            accept PowerOn;

        transition standbyToManual
            from standby
            to manualDriving
            accept AutomationAvailable;

        transition manualToAutomated
            from manualDriving
            to automatedDriving
            accept AutomationRequested;

        transition automatedToManual
            from automatedDriving
            to manualDriving
            accept AutomationCancelled;

        transition automatedToDegraded
            from automatedDriving
            to degradedAutomatedDriving
            accept AutomationFaultDetected;

        transition degradedToMinimalRisk
            from degradedAutomatedDriving
            to minimalRiskManeuver
            accept HazardDetected;

        transition automatedToMinimalRisk
            from automatedDriving
            to minimalRiskManeuver
            accept HazardDetected;

        transition minimalRiskToStandby
            from minimalRiskManeuver
            to standby
            accept MinimalRiskReached;

        transition degradedToFaulted
            from degradedAutomatedDriving
            to faulted
            accept AutomationFaultDetected;

        transition faultedToStandby
            from faulted
            to standby
            accept FaultCleared;

        transition standbyToOff
            from standby
            to off
            accept PowerOff;
    }

    part def CameraSensor {
        attribute horizontalFieldOfView : AngleValue = 120 [deg];
        attribute verticalFieldOfView : AngleValue = 60 [deg];
        attribute frameRate : Real = 30.0;
        attribute nominalDataRate : DataRateValue;
        port videoOut : CameraFrameOutPort;
    }

    part def RadarSensor {
        attribute maximumRange : LengthValue = 180 [m];
        attribute rangeResolution : LengthValue = 0.25 [m];
        attribute updatePeriod : TimeValue = 0.050 [s];
        port radarOut : RadarScanOutPort;
    }

    part def LidarSensor {
        attribute maximumRange : LengthValue = 120 [m];
        attribute horizontalFieldOfView : AngleValue = 360 [deg];
        attribute verticalFieldOfView : AngleValue = 40 [deg];
        attribute updatePeriod : TimeValue = 0.100 [s];
        port cloudOut : LidarCloudOutPort;
    }

    part def GnssReceiver {
        attribute nominalHorizontalAccuracy : LengthValue = 1.0 [m];
        attribute updatePeriod : TimeValue = 0.100 [s];
        port gnssOut : GnssOutPort;
    }

    part def InertialMeasurementUnit {
        attribute updatePeriod : TimeValue = 0.010 [s];
        attribute yawRateBiasStability : AngularRateValue;
        port imuOut : ImuOutPort;
    }

    part def SensingSuite {
        part frontCamera : CameraSensor;
        part rearCamera : CameraSensor;
        part frontRadar : RadarSensor;
        part cornerRadarLeft : RadarSensor;
        part cornerRadarRight : RadarSensor;
        part roofLidar : LidarSensor;
        part gnssReceiver : GnssReceiver;
        part imu : InertialMeasurementUnit;

        port frontCameraFrameOut : CameraFrameOutPort;
        port rearCameraFrameOut : CameraFrameOutPort;
        port frontRadarScanOut : RadarScanOutPort;
        port leftRadarScanOut : RadarScanOutPort;
        port rightRadarScanOut : RadarScanOutPort;
        port lidarCloudOut : LidarCloudOutPort;
        port gnssOut : GnssOutPort;
        port imuOut : ImuOutPort;

        connection exportFrontCamera connect frontCamera.videoOut to frontCameraFrameOut;
        connection exportRearCamera connect rearCamera.videoOut to rearCameraFrameOut;
        connection exportFrontRadar connect frontRadar.radarOut to frontRadarScanOut;
        connection exportLeftRadar connect cornerRadarLeft.radarOut to leftRadarScanOut;
        connection exportRightRadar connect cornerRadarRight.radarOut to rightRadarScanOut;
        connection exportLidar connect roofLidar.cloudOut to lidarCloudOut;
        connection exportGnss connect gnssReceiver.gnssOut to gnssOut;
        connection exportImu connect imu.imuOut to imuOut;
    }

    part def PerceptionComputer {
        attribute processingPeriod : TimeValue = 0.050 [s];
        attribute minimumObjectConfidence : ProbabilityValue = 0.80;
        port cameraFrameIn : CameraFrameInPort;
        port rearCameraFrameIn : CameraFrameInPort;
        port radarScanIn : RadarScanInPort;
        port leftRadarScanIn : RadarScanInPort;
        port rightRadarScanIn : RadarScanInPort;
        port lidarCloudIn : LidarCloudInPort;
        port objectsOut : ObjectListOutPort;
        port lanesOut : LaneModelOutPort;
        perform action perceptionAction : SenseEnvironment;
    }

    part def LocalizationComputer {
        attribute updatePeriod : TimeValue = 0.020 [s];
        attribute maximumPoseUncertainty : LengthValue = 0.50 [m];
        port gnssIn : GnssInPort;
        port imuIn : ImuInPort;
        port mapIn : MapSegmentInPort;
        port egoPoseOut : EgoPoseOutPort;
        perform action localizationAction : LocalizeVehicle;
    }

    part def MapAndRoutingService {
        attribute mapRefreshPeriod : TimeValue = 1.0 [s];
        attribute routeReplanPeriod : TimeValue = 5.0 [s];
        port driverIntentIn : DriverIntentInPort;
        port egoPoseIn : EgoPoseInPort;
        port mapOut : MapSegmentOutPort;
        port missionPlanOut : MissionPlanOutPort;
        perform action missionPlanningAction : PlanMission;
    }

    part def TrajectoryPlanner {
        attribute planningPeriod : TimeValue = 0.100 [s];
        attribute nominalHorizonTime : TimeValue = 6.0 [s];
        attribute nominalHorizonDistance : LengthValue = 120 [m];
        attribute comfortAccelerationLimit : AccelerationValue = 2.0 [m/s^2];
        attribute comfortDecelerationLimit : AccelerationValue = -3.0 [m/s^2];
        port egoPoseIn : EgoPoseInPort;
        port objectsIn : ObjectListInPort;
        port lanesIn : LaneModelInPort;
        port mapIn : MapSegmentInPort;
        port missionPlanIn : MissionPlanInPort;
        port trajectoryOut : TrajectoryOutPort;
        perform action trajectoryPlanningAction : PlanTrajectory;
    }

    part def MotionController {
        attribute controlPeriod : TimeValue = 0.010 [s];
        attribute maximumSteeringAngle : AngleValue = 35 [deg];
        attribute maximumAcceleration : AccelerationValue = 3.0 [m/s^2];
        attribute maximumServiceBrakeDeceleration : AccelerationValue = -7.0 [m/s^2];
        port egoPoseIn : EgoPoseInPort;
        port trajectoryIn : TrajectoryInPort;
        port feedbackIn : ActuatorFeedbackInPort;
        port motionCommandOut : MotionCommandOutPort;
        perform action controlAction : ControlMotion;
    }

    part def ActuatorInterface {
        attribute commandTranslationPeriod : TimeValue = 0.010 [s];
        attribute maximumCommandAge : TimeValue = 0.050 [s];
        port motionCommandIn : MotionCommandInPort;
        port actuationCommandOut : VehicleActuationCommandOutPort;
        port feedbackIn : ActuatorFeedbackInPort;
        port feedbackOut : ActuatorFeedbackOutPort;
        perform action actuationTranslationAction : TranslateToVehicleActuation;
    }

    part def SteeringActuator {
        attribute peakTorque : TorqueValue = 8.0 [N*m];
        attribute maximumAngle : AngleValue = 35 [deg];
        port commandIn : VehicleActuationCommandInPort;
        port feedbackOut : ActuatorFeedbackOutPort;
    }

    part def BrakeActuator {
        attribute maximumBrakeForce : ForceValue = 18000 [N];
        attribute pressureRiseTime : TimeValue = 0.150 [s];
        port commandIn : VehicleActuationCommandInPort;
        port feedbackOut : ActuatorFeedbackOutPort;
    }

    part def PropulsionActuator {
        attribute maximumTorque : TorqueValue = 320 [N*m];
        attribute torqueResponseTime : TimeValue = 0.100 [s];
        port commandIn : VehicleActuationCommandInPort;
        port feedbackOut : ActuatorFeedbackOutPort;
    }

    part def VehiclePlatform {
        attribute curbMass : ISQ::mass = 1850 [kg];
        attribute wheelBase : LengthValue = 2.85 [m];
        attribute trackWidth : LengthValue = 1.62 [m];
        attribute maximumSpeed : SpeedValue = 38.9 [m/s];
        part steering : SteeringActuator;
        part brake : BrakeActuator;
        part propulsion : PropulsionActuator;
        port actuationCommandIn : VehicleActuationCommandInPort;
        port actuatorFeedbackOut : ActuatorFeedbackOutPort;

        connection steeringCommand connect actuationCommandIn to steering.commandIn;
        connection brakeCommand connect actuationCommandIn to brake.commandIn;
        connection propulsionCommand connect actuationCommandIn to propulsion.commandIn;
        connection steeringFeedback connect steering.feedbackOut to actuatorFeedbackOut;
        connection brakeFeedback connect brake.feedbackOut to actuatorFeedbackOut;
        connection propulsionFeedback connect propulsion.feedbackOut to actuatorFeedbackOut;
    }

    part def HumanMachineInterface {
        attribute displayUpdatePeriod : TimeValue = 0.100 [s];
        attribute warningAudibilityLevel : Real = 75.0;
        port driverIntentOut : DriverIntentOutPort;
        port automationStatusIn : AutomationStatusInPort;
        port safetyEventIn : SafetyEventInPort;
    }

    part def SafetySupervisor {
        attribute supervisionPeriod : TimeValue = 0.020 [s];
        attribute minimumAllowedTimeToCollision : TimeValue = 2.0 [s];
        attribute maximumAllowedPoseUncertainty : LengthValue = 1.0 [m];
        port egoPoseIn : EgoPoseInPort;
        port objectsIn : ObjectListInPort;
        port lanesIn : LaneModelInPort;
        port feedbackIn : ActuatorFeedbackInPort;
        port powerReportIn : PowerReportInPort;
        port statusOut : AutomationStatusOutPort;
        port safetyEventOut : SafetyEventOutPort;
        port minimalRiskCommandOut : VehicleActuationCommandOutPort;
        perform action supervisionAction : SuperviseSafety;
        perform action minimalRiskAction : ExecuteMinimalRiskManeuver;
    }

    part def PowerDistributionUnit {
        attribute lowVoltageNominal : VoltageValue = 12 [V];
        attribute highVoltageNominal : VoltageValue = 400 [V];
        attribute maximumContinuousCurrent : CurrentValue = 250 [A];
        port powerReportOut : PowerReportOutPort;
    }

    part def DataLogger {
        attribute storageCapacity : Real = 8.0;
        attribute loggingPeriod : TimeValue = 0.050 [s];
        port statusIn : AutomationStatusInPort;
        port safetyEventIn : SafetyEventInPort;
        port egoPoseIn : EgoPoseInPort;
        port objectsIn : ObjectListInPort;
        port trajectoryIn : TrajectoryInPort;
        port commandIn : VehicleActuationCommandInPort;
    }

    requirement def PrimaryAutomatedDrivingFunction {
        doc /* The vehicular automation system shall perform the high-level primary function of transporting occupants from a requested origin to a requested destination by perceiving the driving environment, localizing the vehicle, planning a safe route and trajectory, and commanding steering, propulsion, and braking while operating inside the defined operational design domain. */
        subject automatedVehicle : AutomatedVehicleSystem;
        require constraint {
            automatedVehicle.nominalAutomationMode == AutomationMode::automatedDriving
        }
    }

    requirement def SafeOperationRequirement {
        doc /* The automated vehicle shall maintain a safe time gap, obey speed limits supplied by the map, remain within the selected lane corridor, and transition to a minimal risk maneuver when continued automated driving is unsafe. */
        subject automatedVehicle : AutomatedVehicleSystem;
        require constraint safeGap : MaintainSafeTimeGap {
            in minimumTimeGap = 2.0 [s];
        }
    }

    requirement def AvailabilityRequirement {
        doc /* The automated vehicle shall provide automated driving availability when required sensors, localization, power, computation, and actuators are healthy and the route is inside the operational design domain. */
        subject automatedVehicle : AutomatedVehicleSystem;
    }

    requirement def ControlLatencyRequirement {
        doc /* The time from trajectory command generation to vehicle actuation command availability shall not exceed 50 milliseconds during automated driving. */
        subject automatedVehicle : AutomatedVehicleSystem;
        require constraint latency : MaintainActuationLatency {
            in maximumCommandAge = 0.050 [s];
        }
    }

    requirement def DriverInteractionRequirement {
        doc /* The system shall accept driver destination and automation engagement requests, report automation status, and provide timely warnings for degraded operation or minimal risk maneuver initiation. */
        subject automatedVehicle : AutomatedVehicleSystem;
    }

    part def AutomatedVehicleSystem {
        doc /* A vehicular automation system whose primary high-level function is to drive a road vehicle along a requested route with supervised automated steering, propulsion, and braking based on fused sensor perception, localization, trajectory planning, motion control, and safety supervision. */

        attribute nominalAutomationMode : AutomationMode = AutomationMode::automatedDriving;
        attribute operationalDesignDomainMaximumSpeed : SpeedValue = 33.3 [m/s];
        attribute operationalDesignDomainMinimumLaneWidth : LengthValue = 2.7 [m];
        attribute nominalFollowingTimeGap : TimeValue = 2.0 [s];
        attribute nominalControlPeriod : TimeValue = 0.010 [s];

        part sensingSuite : SensingSuite;
        part perception : PerceptionComputer;
        part localization : LocalizationComputer;
        part mapAndRouting : MapAndRoutingService;
        part trajectoryPlanner : TrajectoryPlanner;
        part motionController : MotionController;
        part actuatorInterface : ActuatorInterface;
        part vehiclePlatform : VehiclePlatform;
        part hmi : HumanMachineInterface;
        part safetySupervisor : SafetySupervisor;
        part powerDistribution : PowerDistributionUnit;
        part dataLogger : DataLogger;

        exhibit state automationStates : AutomationOperationalStates;
        perform action automatedDrivingCycle : AutomatedDrivingCycle;

        port externalDriverIntentIn : DriverIntentInPort;
        port externalAutomationStatusOut : AutomationStatusOutPort;
        port externalSafetyEventOut : SafetyEventOutPort;

        connection driverIntentToRouting connect hmi.driverIntentOut to mapAndRouting.driverIntentIn;
        connection driverIntentExternal connect externalDriverIntentIn to mapAndRouting.driverIntentIn;

        connection frontCameraToPerception connect sensingSuite.frontCameraFrameOut to perception.cameraFrameIn;
        connection rearCameraToPerception connect sensingSuite.rearCameraFrameOut to perception.rearCameraFrameIn;
        connection frontRadarToPerception connect sensingSuite.frontRadarScanOut to perception.radarScanIn;
        connection leftRadarToPerception connect sensingSuite.leftRadarScanOut to perception.leftRadarScanIn;
        connection rightRadarToPerception connect sensingSuite.rightRadarScanOut to perception.rightRadarScanIn;
        connection lidarToPerception connect sensingSuite.lidarCloudOut to perception.lidarCloudIn;

        connection gnssToLocalization connect sensingSuite.gnssOut to localization.gnssIn;
        connection imuToLocalization connect sensingSuite.imuOut to localization.imuIn;
        connection mapToLocalization connect mapAndRouting.mapOut to localization.mapIn;

        connection egoPoseToRouting connect localization.egoPoseOut to mapAndRouting.egoPoseIn;
        connection egoPoseToPlanner connect localization.egoPoseOut to trajectoryPlanner.egoPoseIn;
        connection egoPoseToController connect localization.egoPoseOut to motionController.egoPoseIn;
        connection egoPoseToSafety connect localization.egoPoseOut to safetySupervisor.egoPoseIn;
        connection egoPoseToLogger connect localization.egoPoseOut to dataLogger.egoPoseIn;

        connection objectsToPlanner connect perception.objectsOut to trajectoryPlanner.objectsIn;
        connection lanesToPlanner connect perception.lanesOut to trajectoryPlanner.lanesIn;
        connection objectsToSafety connect perception.objectsOut to safetySupervisor.objectsIn;
        connection lanesToSafety connect perception.lanesOut to safetySupervisor.lanesIn;
        connection objectsToLogger connect perception.objectsOut to dataLogger.objectsIn;

        connection mapToPlanner connect mapAndRouting.mapOut to trajectoryPlanner.mapIn;
        connection missionToPlanner connect mapAndRouting.missionPlanOut to trajectoryPlanner.missionPlanIn;

        connection trajectoryToController connect trajectoryPlanner.trajectoryOut to motionController.trajectoryIn;
        connection trajectoryToLogger connect trajectoryPlanner.trajectoryOut to dataLogger.trajectoryIn;

        connection motionToActuatorInterface connect motionController.motionCommandOut to actuatorInterface.motionCommandIn;
        connection actuationToPlatform connect actuatorInterface.actuationCommandOut to vehiclePlatform.actuationCommandIn;
        connection actuationToLogger connect actuatorInterface.actuationCommandOut to dataLogger.commandIn;

        connection platformFeedbackToActuatorInterface connect vehiclePlatform.actuatorFeedbackOut to actuatorInterface.feedbackIn;
        connection actuatorFeedbackToController connect actuatorInterface.feedbackOut to motionController.feedbackIn;
        connection actuatorFeedbackToSafety connect actuatorInterface.feedbackOut to safetySupervisor.feedbackIn;

        connection powerToSafety connect powerDistribution.powerReportOut to safetySupervisor.powerReportIn;

        connection statusToHmi connect safetySupervisor.statusOut to hmi.automationStatusIn;
        connection statusToLogger connect safetySupervisor.statusOut to dataLogger.statusIn;
        connection statusExternal connect safetySupervisor.statusOut to externalAutomationStatusOut;

        connection safetyEventToHmi connect safetySupervisor.safetyEventOut to hmi.safetyEventIn;
        connection safetyEventToLogger connect safetySupervisor.safetyEventOut to dataLogger.safetyEventIn;
        connection safetyEventExternal connect safetySupervisor.safetyEventOut to externalSafetyEventOut;

        connection minimalRiskCommandToPlatform connect safetySupervisor.minimalRiskCommandOut to vehiclePlatform.actuationCommandIn;

        satisfy PrimaryAutomatedDrivingFunction by AutomatedVehicleSystem;
        satisfy SafeOperationRequirement by AutomatedVehicleSystem;
        satisfy AvailabilityRequirement by AutomatedVehicleSystem;
        satisfy ControlLatencyRequirement by AutomatedVehicleSystem;
        satisfy DriverInteractionRequirement by AutomatedVehicleSystem;
    }

    part automatedRoadVehicle : AutomatedVehicleSystem {
        attribute operationalDesignDomainMaximumSpeed = 33.3 [m/s];
        attribute operationalDesignDomainMinimumLaneWidth = 2.7 [m];
        attribute nominalFollowingTimeGap = 2.0 [s];
        attribute nominalControlPeriod = 0.010 [s];
    }
}
