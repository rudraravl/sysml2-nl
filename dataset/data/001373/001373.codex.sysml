package BostonDynamicsSpotInspiredInspectionSystem {

  doc /* System based on a Boston Dynamics quadruped robot platform. Its primary function is autonomous mobile inspection: traverse human-scale industrial spaces, collect visual, thermal, acoustic, and gas data, detect anomalies, and report actionable inspection results. */

  enum def MissionMode {
    enum idle;
    enum teleoperated;
    enum autonomousInspection;
    enum returnToDock;
    enum emergencyStop;
  }

  enum def TerrainClass {
    enum flatFloor;
    enum stairs;
    enum gratedWalkway;
    enum gravel;
    enum wetSurface;
    enum obstacleField;
  }

  enum def HazardLevel {
    enum nominal;
    enum caution;
    enum warning;
    enum critical;
  }

  enum def RobotHealth {
    enum healthy;
    enum degraded;
    enum faulted;
    enum unsafe;
  }

  attribute def Mass_kg {
    attribute value : Real;
    attribute unit : String = "kg";
  }

  attribute def Length_m {
    attribute value : Real;
    attribute unit : String = "m";
  }

  attribute def Speed_mps {
    attribute value : Real;
    attribute unit : String = "m/s";
  }

  attribute def Power_W {
    attribute value : Real;
    attribute unit : String = "W";
  }

  attribute def Energy_Wh {
    attribute value : Real;
    attribute unit : String = "Wh";
  }

  attribute def Voltage_V {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def Temperature_C {
    attribute value : Real;
    attribute unit : String = "degC";
  }

  attribute def SoundPressure_dBA {
    attribute value : Real;
    attribute unit : String = "dBA";
  }

  attribute def GasConcentration_ppm {
    attribute value : Real;
    attribute unit : String = "ppm";
  }

  attribute def DataRate_Mbps {
    attribute value : Real;
    attribute unit : String = "Mb/s";
  }

  item def ElectricPower {
    attribute voltage : Voltage_V;
    attribute power : Power_W;
  }

  item def MotionCommand {
    attribute desiredForwardSpeed : Speed_mps;
    attribute desiredLateralSpeed : Speed_mps;
    attribute desiredYawRate_radps : Real;
    attribute requestedGait : String;
  }

  item def JointTorqueCommand {
    attribute hipTorque_Nm : Real;
    attribute kneeTorque_Nm : Real;
    attribute abductionTorque_Nm : Real;
  }

  item def PoseEstimate {
    attribute x_m : Real;
    attribute y_m : Real;
    attribute z_m : Real;
    attribute roll_rad : Real;
    attribute pitch_rad : Real;
    attribute yaw_rad : Real;
    attribute confidence : Real;
  }

  item def TerrainAssessment {
    attribute terrain : TerrainClass;
    attribute traversabilityScore : Real;
    attribute slipRisk : HazardLevel;
  }

  item def InspectionPlan {
    attribute siteId : String;
    attribute routeId : String;
    attribute targetWaypointCount : Integer;
    attribute requiredStandOffDistance : Length_m;
    attribute mode : MissionMode;
  }

  item def VisualImage {
    attribute resolutionWidth_px : Integer;
    attribute resolutionHeight_px : Integer;
    attribute timestamp_s : Real;
  }

  item def ThermalImage {
    attribute resolutionWidth_px : Integer;
    attribute resolutionHeight_px : Integer;
    attribute timestamp_s : Real;
    attribute minimumTemperature : Temperature_C;
    attribute maximumTemperature : Temperature_C;
  }

  item def AcousticSample {
    attribute duration_s : Real;
    attribute soundLevel : SoundPressure_dBA;
    attribute dominantFrequency_Hz : Real;
  }

  item def GasSample {
    attribute methane : GasConcentration_ppm;
    attribute carbonMonoxide : GasConcentration_ppm;
    attribute hydrogenSulfide : GasConcentration_ppm;
    attribute oxygenPercent : Real;
  }

  item def InspectionFinding {
    attribute assetId : String;
    attribute hazard : HazardLevel;
    attribute description : String;
    attribute confidence : Real;
    attribute pose : PoseEstimate;
  }

  item def InspectionReport {
    attribute missionId : String;
    attribute completedWaypointCount : Integer;
    attribute anomalyCount : Integer;
    attribute overallHazard : HazardLevel;
  }

  item def EmergencyStopSignal {
    attribute source : String;
    attribute asserted : Boolean;
  }

  port def PowerInputPort {
    in item power : ElectricPower;
  }

  port def PowerOutputPort {
    out item power : ElectricPower;
  }

  port def CommandInputPort {
    in item command : MotionCommand;
  }

  port def TorqueOutputPort {
    out item torqueCommand : JointTorqueCommand;
  }

  port def PoseOutputPort {
    out item pose : PoseEstimate;
  }

  port def TerrainOutputPort {
    out item terrainAssessment : TerrainAssessment;
  }

  port def PlanInputPort {
    in item plan : InspectionPlan;
  }

  port def FindingOutputPort {
    out item finding : InspectionFinding;
  }

  port def ReportOutputPort {
    out item report : InspectionReport;
  }

  port def EmergencyStopInputPort {
    in item stop : EmergencyStopSignal;
  }

  port def DataNetworkPort {
    in item inboundPlan : InspectionPlan;
    out item outboundReport : InspectionReport;
    attribute dataRate : DataRate_Mbps;
  }

  part def RechargeableBattery {
    attribute storedEnergy : Energy_Wh;
    attribute nominalVoltage : Voltage_V;
    attribute maximumPowerOutput : Power_W;
    port powerOut : PowerOutputPort;
  }

  part def PowerDistributionUnit {
    port batteryPowerIn : PowerInputPort;
    port computePowerOut : PowerOutputPort;
    port actuatorPowerOut : PowerOutputPort;
    port payloadPowerOut : PowerOutputPort;
  }

  part def LegActuator {
    attribute peakTorque_Nm : Real;
    attribute continuousPower : Power_W;
    port powerIn : PowerInputPort;
    port commandIn : CommandInputPort;
  }

  part def QuadrupedLeg {
    attribute legName : String;
    part hip : LegActuator;
    part knee : LegActuator;
    part abduction : LegActuator;
    port motionCommandIn : CommandInputPort;
  }

  part def LocomotionController {
    port powerIn : PowerInputPort;
    port motionCommandIn : CommandInputPort;
    port frontLeftTorqueOut : TorqueOutputPort;
    port frontRightTorqueOut : TorqueOutputPort;
    port rearLeftTorqueOut : TorqueOutputPort;
    port rearRightTorqueOut : TorqueOutputPort;
    port terrainIn : TerrainOutputPort;
  }

  part def PerceptionSuite {
    port powerIn : PowerInputPort;
    port poseOut : PoseOutputPort;
    port terrainOut : TerrainOutputPort;
    item visualFrame : VisualImage;
    item thermalFrame : ThermalImage;
    item acousticSample : AcousticSample;
    item gasSample : GasSample;
  }

  part def MissionComputer {
    attribute processorLoadPercent : Real;
    attribute health : RobotHealth;
    port powerIn : PowerInputPort;
    port planIn : PlanInputPort;
    port commandOut : CommandInputPort;
    port poseIn : PoseOutputPort;
    port terrainIn : TerrainOutputPort;
    port findingOut : FindingOutputPort;
    port reportOut : ReportOutputPort;
    port emergencyStopIn : EmergencyStopInputPort;
  }

  part def CommunicationsModule {
    port network : DataNetworkPort;
    port planOut : PlanInputPort;
    port reportIn : ReportOutputPort;
  }

  part def DockingStation {
    attribute availableChargePower : Power_W;
    port chargePowerOut : PowerOutputPort;
    port network : DataNetworkPort;
  }

  part def SpotInspiredInspectionRobot {
    attribute robotMass : Mass_kg = (value = 32.5; unit = "kg");
    attribute maximumSpeed : Speed_mps = (value = 1.6; unit = "m/s");
    attribute nominalRuntime : Energy_Wh = (value = 605.0; unit = "Wh");
    attribute currentMode : MissionMode;
    attribute health : RobotHealth;

    part battery : RechargeableBattery;
    part pdu : PowerDistributionUnit;
    part frontLeftLeg : QuadrupedLeg;
    part frontRightLeg : QuadrupedLeg;
    part rearLeftLeg : QuadrupedLeg;
    part rearRightLeg : QuadrupedLeg;
    part locomotion : LocomotionController;
    part perception : PerceptionSuite;
    part missionComputer : MissionComputer;
    part comms : CommunicationsModule;

    port externalPlanIn : PlanInputPort;
    port externalReportOut : ReportOutputPort;
    port emergencyStopIn : EmergencyStopInputPort;

    connect battery.powerOut to pdu.batteryPowerIn;
    connect pdu.computePowerOut to missionComputer.powerIn;
    connect pdu.computePowerOut to locomotion.powerIn;
    connect pdu.payloadPowerOut to perception.powerIn;

    connect missionComputer.commandOut to locomotion.motionCommandIn;
    connect perception.poseOut to missionComputer.poseIn;
    connect perception.terrainOut to missionComputer.terrainIn;
    connect perception.terrainOut to locomotion.terrainIn;

    connect locomotion.frontLeftTorqueOut to frontLeftLeg.motionCommandIn;
    connect locomotion.frontRightTorqueOut to frontRightLeg.motionCommandIn;
    connect locomotion.rearLeftTorqueOut to rearLeftLeg.motionCommandIn;
    connect locomotion.rearRightTorqueOut to rearRightLeg.motionCommandIn;

    connect externalPlanIn to missionComputer.planIn;
    connect missionComputer.reportOut to externalReportOut;
    connect emergencyStopIn to missionComputer.emergencyStopIn;
  }

  action def ExecuteInspectionMission {
    in item plan : InspectionPlan;
    out item report : InspectionReport;

    action receivePlan;
    action initializeRobot;
    action localizeInSite;
    action traverseRoute;
    action collectSensorData;
    action detectAnomalies;
    action generateInspectionReport;
    action returnToDock;

    first receivePlan then initializeRobot;
    then localizeInSite;
    then traverseRoute;
    then collectSensorData;
    then detectAnomalies;
    then generateInspectionReport;
    then returnToDock;
  }

  action def TraverseWaypoint {
    in item command : MotionCommand;
    in item terrain : TerrainAssessment;
    out item pose : PoseEstimate;

    action estimateFootPlacement;
    action stabilizeBody;
    action commandLegTorques;
    action updatePose;

    first estimateFootPlacement then stabilizeBody;
    then commandLegTorques;
    then updatePose;
  }

  action def AnalyzeInspectionData {
    in item visual : VisualImage;
    in item thermal : ThermalImage;
    in item acoustic : AcousticSample;
    in item gas : GasSample;
    out item finding : InspectionFinding;

    action detectVisualDefects;
    action detectThermalHotspots;
    action detectAcousticLeaks;
    action detectGasHazards;
    action fuseFindings;

    first detectVisualDefects then detectThermalHotspots;
    then detectAcousticLeaks;
    then detectGasHazards;
    then fuseFindings;
  }

  state def RobotMissionStateMachine {
    state poweredOff;
    state booting;
    state awaitingMission;
    state autonomousInspection;
    state obstacleNegotiation;
    state anomalyConfirmation;
    state returningToDock;
    state charging;
    state emergencyStopped;
    state faulted;

    transition initial then poweredOff;
    transition poweredOff to booting accept PowerOn;
    transition booting to awaitingMission when selfTestPassed;
    transition booting to faulted when selfTestFailed;
    transition awaitingMission to autonomousInspection accept MissionReceived;
    transition autonomousInspection to obstacleNegotiation when obstacleDetected;
    transition obstacleNegotiation to autonomousInspection when routeRecovered;
    transition autonomousInspection to anomalyConfirmation when anomalyDetected;
    transition anomalyConfirmation to autonomousInspection when anomalyRecorded;
    transition autonomousInspection to returningToDock when missionComplete;
    transition autonomousInspection to returningToDock when lowBattery;
    transition returningToDock to charging when docked;
    transition charging to awaitingMission when batteryCharged;
    transition awaitingMission to emergencyStopped accept EmergencyStopSignal;
    transition autonomousInspection to emergencyStopped accept EmergencyStopSignal;
    transition obstacleNegotiation to emergencyStopped accept EmergencyStopSignal;
    transition anomalyConfirmation to emergencyStopped accept EmergencyStopSignal;
    transition emergencyStopped to awaitingMission when operatorReset;
    transition faulted to awaitingMission when maintenanceCleared;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall autonomously inspect industrial facilities by traversing assigned routes, collecting multimodal sensor data, detecting anomalies, and reporting findings to operators. */
    attribute minimumCompletedWaypointRatio : Real = 0.95;
    attribute maximumReportLatency_s : Real = 30.0;
  }

  requirement def MobilityRequirement {
    doc /* The robot shall traverse flat floors, stairs, grated walkways, and obstacle fields while maintaining stable locomotion. */
    attribute minimumObstacleHeight_m : Real = 0.15;
    attribute minimumStairRise_m : Real = 0.18;
    attribute maximumNominalSpeed_mps : Real = 1.6;
  }

  requirement def InspectionPayloadRequirement {
    doc /* The inspection payload shall collect visual, thermal, acoustic, and gas measurements at each target waypoint. */
    attribute minimumVisualWidth_px : Integer = 1920;
    attribute minimumVisualHeight_px : Integer = 1080;
    attribute thermalAccuracy_C : Real = 2.0;
    attribute gasDetectionThreshold_ppm : Real = 50.0;
  }

  requirement def SafetyRequirement {
    doc /* The robot shall enter an emergency stopped state when an emergency stop signal is asserted or a critical hazard is detected. */
    attribute stopReactionTime_s : Real = 0.5;
  }

  requirement def RuntimeRequirement {
    doc /* The robot shall complete a standard inspection route before reaching reserve battery energy. */
    attribute minimumRuntime_min : Real = 90.0;
    attribute reserveEnergyPercent : Real = 15.0;
  }

  part inspectionSystem {
    part robot : SpotInspiredInspectionRobot;
    part dock : DockingStation;

    connect dock.chargePowerOut to robot.battery.powerOut;
    connect dock.network to robot.comms.network;
  }

  satisfy PrimaryFunctionRequirement by SpotInspiredInspectionRobot;
  satisfy MobilityRequirement by QuadrupedLeg;
  satisfy MobilityRequirement by LocomotionController;
  satisfy InspectionPayloadRequirement by PerceptionSuite;
  satisfy SafetyRequirement by MissionComputer;
  satisfy RuntimeRequirement by RechargeableBattery;

}