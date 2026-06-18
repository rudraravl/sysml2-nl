package FisheriesAcousticsModel {

  import ScalarValues::*;

  doc /*
    Primary function: The Fisheries Acoustic Survey System emits calibrated underwater sound pulses,
    receives echoes from fish and the seafloor, georeferences the measurements, estimates fish
    distribution and biomass, and produces survey products for fisheries assessment and management.
  */

  attribute def Length_m :> Real {
    doc /* Length measured in meters. */
  }

  attribute def Depth_m :> Length_m {
    doc /* Depth below water surface measured in meters. */
  }

  attribute def Range_m :> Length_m {
    doc /* Acoustic slant range measured in meters. */
  }

  attribute def Area_m2 :> Real {
    doc /* Area measured in square meters. */
  }

  attribute def Volume_m3 :> Real {
    doc /* Volume measured in cubic meters. */
  }

  attribute def Time_s :> Real {
    doc /* Time measured in seconds. */
  }

  attribute def Frequency_Hz :> Real {
    doc /* Acoustic frequency measured in hertz. */
  }

  attribute def Power_W :> Real {
    doc /* Electrical or acoustic power measured in watts. */
  }

  attribute def Voltage_V :> Real {
    doc /* Electrical potential measured in volts. */
  }

  attribute def Current_A :> Real {
    doc /* Electrical current measured in amperes. */
  }

  attribute def Temperature_degC :> Real {
    doc /* Temperature measured in degrees Celsius. */
  }

  attribute def Salinity_psu :> Real {
    doc /* Practical salinity measured in psu. */
  }

  attribute def Speed_m_per_s :> Real {
    doc /* Speed measured in meters per second. */
  }

  attribute def Angle_deg :> Real {
    doc /* Angle measured in degrees. */
  }

  attribute def Latitude_deg :> Real {
    doc /* Geodetic latitude measured in degrees. */
  }

  attribute def Longitude_deg :> Real {
    doc /* Geodetic longitude measured in degrees. */
  }

  attribute def AcousticLevel_dB :> Real {
    doc /* Acoustic level measured in decibels referenced to underwater acoustic standards. */
  }

  attribute def Sv_dB :> AcousticLevel_dB {
    doc /* Volume backscattering strength measured in dB re 1 m^-1. */
  }

  attribute def TS_dB :> AcousticLevel_dB {
    doc /* Target strength measured in dB re 1 m^2. */
  }

  attribute def Biomass_kg :> Real {
    doc /* Fish biomass measured in kilograms. */
  }

  attribute def Density_kg_per_m3 :> Real {
    doc /* Biomass density measured in kilograms per cubic meter. */
  }

  attribute def DataRate_Mbps :> Real {
    doc /* Data rate measured in megabits per second. */
  }

  enum def SurveyMode {
    enum Idle;
    enum SelfTest;
    enum Calibration;
    enum Transit;
    enum TransectSurvey;
    enum StationarySampling;
    enum DataProcessing;
    enum ReportGeneration;
    enum Fault;
  }

  enum def PingKind {
    enum Narrowband;
    enum BroadbandChirp;
    enum CalibrationTone;
  }

  enum def FishAggregationClass {
    enum NoneDetected;
    enum ScatteredIndividuals;
    enum SmallSchool;
    enum DenseSchool;
    enum BottomAssociatedLayer;
    enum PlanktonLayer;
  }

  enum def HealthState {
    enum Nominal;
    enum Degraded;
    enum Failed;
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute current : Current_A;
    attribute power : Power_W;
  }

  item def AcousticPulse {
    attribute pingId : Integer;
    attribute kind : PingKind;
    attribute centerFrequency : Frequency_Hz;
    attribute bandwidth : Frequency_Hz;
    attribute sourceLevel : AcousticLevel_dB;
    attribute pulseDuration : Time_s;
    attribute beamWidthAlongship : Angle_deg;
    attribute beamWidthAthwartship : Angle_deg;
    attribute transmitTime : Time_s;
  }

  item def AcousticEcho {
    attribute pingId : Integer;
    attribute receiveTime : Time_s;
    attribute range : Range_m;
    attribute volumeBackscatter : Sv_dB;
    attribute targetStrength : TS_dB;
    attribute signalToNoiseRatio : AcousticLevel_dB;
    attribute compensatedForMotion : Boolean;
  }

  item def NavigationFix {
    attribute time : Time_s;
    attribute latitude : Latitude_deg;
    attribute longitude : Longitude_deg;
    attribute speedOverGround : Speed_m_per_s;
    attribute courseOverGround : Angle_deg;
    attribute heading : Angle_deg;
  }

  item def AttitudeSample {
    attribute time : Time_s;
    attribute roll : Angle_deg;
    attribute pitch : Angle_deg;
    attribute heave : Length_m;
    attribute yaw : Angle_deg;
  }

  item def EnvironmentalProfile {
    attribute time : Time_s;
    attribute latitude : Latitude_deg;
    attribute longitude : Longitude_deg;
    attribute depth : Depth_m;
    attribute temperature : Temperature_degC;
    attribute salinity : Salinity_psu;
    attribute soundSpeed : Speed_m_per_s;
  }

  item def SurveyPlan {
    attribute planId : String;
    attribute surveyAreaName : String;
    attribute nominalTransectSpacing : Length_m;
    attribute nominalVesselSpeed : Speed_m_per_s;
    attribute minimumDepth : Depth_m;
    attribute maximumDepth : Depth_m;
    attribute primaryFrequency : Frequency_Hz;
    attribute secondaryFrequency : Frequency_Hz;
    attribute pingInterval : Time_s;
    attribute requireCalibration : Boolean;
  }

  item def CalibrationResult {
    attribute time : Time_s;
    attribute frequency : Frequency_Hz;
    attribute gainCorrection : AcousticLevel_dB;
    attribute beamAngleCorrection : AcousticLevel_dB;
    attribute passed : Boolean;
  }

  item def DetectedFishCell {
    attribute time : Time_s;
    attribute latitude : Latitude_deg;
    attribute longitude : Longitude_deg;
    attribute depth : Depth_m;
    attribute cellHeight : Length_m;
    attribute cellLength : Length_m;
    attribute meanSv : Sv_dB;
    attribute meanTargetStrength : TS_dB;
    attribute biomassDensity : Density_kg_per_m3;
    attribute classification : FishAggregationClass;
  }

  item def BiomassMap {
    attribute productId : String;
    attribute creationTime : Time_s;
    attribute surveyAreaName : String;
    attribute mappedArea : Area_m2;
    attribute sampledVolume : Volume_m3;
    attribute totalEstimatedBiomass : Biomass_kg;
    attribute uncertaintyPercent : Real;
  }

  item def OperatorCommand {
    attribute commandId : String;
    attribute requestedMode : SurveyMode;
    attribute time : Time_s;
  }

  item def SystemStatus {
    attribute time : Time_s;
    attribute mode : SurveyMode;
    attribute health : HealthState;
    attribute activeFrequency : Frequency_Hz;
    attribute storageRemainingPercent : Real;
    attribute lastFaultMessage : String;
  }

  port def PowerInputPort {
    in power : ElectricalPower;
  }

  port def PowerOutputPort {
    out power : ElectricalPower;
  }

  port def AcousticTransmitPort {
    out pulse : AcousticPulse;
  }

  port def AcousticReceivePort {
    in echo : AcousticEcho;
  }

  port def AcousticBidirectionalPort {
    out pulse : AcousticPulse;
    in echo : AcousticEcho;
  }

  port def NavigationOutputPort {
    out fix : NavigationFix;
  }

  port def AttitudeOutputPort {
    out attitude : AttitudeSample;
  }

  port def EnvironmentOutputPort {
    out profile : EnvironmentalProfile;
  }

  port def SurveyPlanInputPort {
    in plan : SurveyPlan;
  }

  port def CommandInputPort {
    in command : OperatorCommand;
  }

  port def StatusOutputPort {
    out status : SystemStatus;
  }

  port def EchoDataOutputPort {
    out echo : AcousticEcho;
  }

  port def EchoDataInputPort {
    in echo : AcousticEcho;
  }

  port def ProcessedCellOutputPort {
    out cell : DetectedFishCell;
  }

  port def ProcessedCellInputPort {
    in cell : DetectedFishCell;
  }

  port def BiomassProductOutputPort {
    out map : BiomassMap;
  }

  port def CalibrationOutputPort {
    out calibration : CalibrationResult;
  }

  port def CalibrationInputPort {
    in calibration : CalibrationResult;
  }

  port def DataNetworkOutputPort {
    out fix : NavigationFix;
    out attitude : AttitudeSample;
    out profile : EnvironmentalProfile;
    out status : SystemStatus;
    out map : BiomassMap;
  }

  port def DataNetworkInputPort {
    in fix : NavigationFix;
    in attitude : AttitudeSample;
    in profile : EnvironmentalProfile;
    in status : SystemStatus;
    in map : BiomassMap;
  }

  constraint def RangeFromTimeOfFlight {
    in timeOfFlight : Time_s;
    in soundSpeed : Speed_m_per_s;
    in range : Range_m;
    constraint rangeComputation {
      range == timeOfFlight * soundSpeed / 2.0;
    }
  }

  constraint def SurveyCoverageAdequacy {
    in mappedArea : Area_m2;
    in requiredArea : Area_m2;
    in coverageRatio : Real;
    constraint coverage {
      coverageRatio == mappedArea / requiredArea;
    }
  }

  constraint def BiomassUncertaintyLimit {
    in uncertaintyPercent : Real;
    in allowedPercent : Real;
    constraint limit {
      uncertaintyPercent <= allowedPercent;
    }
  }

  action def GenerateTransmitPulse {
    in plan : SurveyPlan;
    in mode : SurveyMode;
    out pulse : AcousticPulse;

    attribute selectedFrequency : Frequency_Hz;
    attribute selectedDuration : Time_s;
    attribute selectedBandwidth : Frequency_Hz;
  }

  action def AcquireEchoSamples {
    in pulse : AcousticPulse;
    in profile : EnvironmentalProfile;
    in attitude : AttitudeSample;
    out echo : AcousticEcho;

    attribute receiveWindow : Time_s;
    attribute maximumRange : Range_m;
  }

  action def ApplyMotionCompensation {
    in rawEcho : AcousticEcho;
    in attitude : AttitudeSample;
    out compensatedEcho : AcousticEcho;
  }

  action def CorrectForSoundSpeed {
    in echo : AcousticEcho;
    in profile : EnvironmentalProfile;
    out correctedEcho : AcousticEcho;
  }

  action def DetectFishBackscatter {
    in echo : AcousticEcho;
    in fix : NavigationFix;
    out fishCell : DetectedFishCell;

    attribute minimumSvThreshold : Sv_dB;
    attribute minimumSignalToNoiseRatio : AcousticLevel_dB;
  }

  action def ClassifyAggregation {
    in fishCell : DetectedFishCell;
    out classifiedCell : DetectedFishCell;

    attribute schoolSvThreshold : Sv_dB;
    attribute bottomLayerDepthTolerance : Length_m;
  }

  action def EstimateBiomass {
    in classifiedCell : DetectedFishCell;
    in plan : SurveyPlan;
    out biomassMap : BiomassMap;

    attribute targetStrengthModelIntercept : TS_dB;
    attribute meanFishMass : Biomass_kg;
  }

  action def CalibrateEchosounder {
    in profile : EnvironmentalProfile;
    out result : CalibrationResult;

    attribute calibrationSphereTargetStrength : TS_dB;
    attribute allowableGainError : AcousticLevel_dB;
  }

  action def ExecuteFisheriesAcousticSurvey {
    in plan : SurveyPlan;
    in command : OperatorCommand;
    out product : BiomassMap;
    out status : SystemStatus;

    first start;

    action calibrate : CalibrateEchosounder;
    then action transmit : GenerateTransmitPulse;
    then action receive : AcquireEchoSamples;
    then action compensate : ApplyMotionCompensation;
    then action correct : CorrectForSoundSpeed;
    then action detect : DetectFishBackscatter;
    then action classify : ClassifyAggregation;
    then action estimate : EstimateBiomass;

    then done;
  }

  state def SurveyControllerBehavior {
    entry action initializeStatus {
      out status : SystemStatus;
    }

    state idle;
    state selfTest;
    state calibration;
    state transit;
    state transectSurvey;
    state stationarySampling;
    state processing;
    state reporting;
    state fault;

    transition initialToIdle
      first idle;

    transition idleToSelfTest
      first idle
      accept OperatorCommand
      if command.requestedMode == SurveyMode::SelfTest
      then selfTest;

    transition selfTestToCalibration
      first selfTest
      if status.health == HealthState::Nominal
      then calibration;

    transition calibrationToTransit
      first calibration
      if status.health == HealthState::Nominal
      then transit;

    transition transitToTransectSurvey
      first transit
      accept OperatorCommand
      if command.requestedMode == SurveyMode::TransectSurvey
      then transectSurvey;

    transition transectToProcessing
      first transectSurvey
      accept OperatorCommand
      if command.requestedMode == SurveyMode::DataProcessing
      then processing;

    transition idleToStationarySampling
      first idle
      accept OperatorCommand
      if command.requestedMode == SurveyMode::StationarySampling
      then stationarySampling;

    transition stationaryToProcessing
      first stationarySampling
      accept OperatorCommand
      if command.requestedMode == SurveyMode::DataProcessing
      then processing;

    transition processingToReporting
      first processing
      then reporting;

    transition reportingToIdle
      first reporting
      accept OperatorCommand
      if command.requestedMode == SurveyMode::Idle
      then idle;

    transition anyToFaultFromSelfTest
      first selfTest
      if status.health == HealthState::Failed
      then fault;

    transition anyToFaultFromSurvey
      first transectSurvey
      if status.health == HealthState::Failed
      then fault;

    transition faultToIdleAfterReset
      first fault
      accept OperatorCommand
      if command.requestedMode == SurveyMode::Idle
      then idle;
  }

  part def PowerDistributionUnit {
    attribute inputVoltage : Voltage_V = 230.0;
    attribute sonarBusVoltage : Voltage_V = 48.0;
    attribute computeBusVoltage : Voltage_V = 24.0;
    attribute maximumOutputPower : Power_W = 3500.0;

    port shipPowerIn : PowerInputPort;
    port sonarPowerOut : PowerOutputPort;
    port computePowerOut : PowerOutputPort;
    port sensorPowerOut : PowerOutputPort;
  }

  part def SurveyVessel {
    attribute vesselName : String = "Acoustic Survey Vessel";
    attribute maximumSurveySpeed : Speed_m_per_s = 5.0;
    attribute nominalSurveySpeed : Speed_m_per_s = 3.0;
    attribute endurance : Time_s = 604800.0;

    port shipPowerOut : PowerOutputPort;
    port navigationOut : NavigationOutputPort;
    port attitudeOut : AttitudeOutputPort;

    part powerDistribution : PowerDistributionUnit;
  }

  part def SplitBeamTransducer {
    attribute centerFrequency : Frequency_Hz = 120000.0;
    attribute usableBandwidth : Frequency_Hz = 30000.0;
    attribute nominalBeamWidthAlongship : Angle_deg = 7.0;
    attribute nominalBeamWidthAthwartship : Angle_deg = 7.0;
    attribute maximumSourceLevel : AcousticLevel_dB = 220.0;
    attribute maximumOperatingDepth : Depth_m = 600.0;

    port powerIn : PowerInputPort;
    port acoustic : AcousticBidirectionalPort;
  }

  part def BroadbandTransceiver {
    attribute minimumFrequency : Frequency_Hz = 38000.0;
    attribute maximumFrequency : Frequency_Hz = 200000.0;
    attribute maximumTransmitPower : Power_W = 2000.0;
    attribute pingInterval : Time_s = 1.0;
    attribute receiveDynamicRange : AcousticLevel_dB = 120.0;

    port powerIn : PowerInputPort;
    port transmitOut : AcousticTransmitPort;
    port receiveIn : AcousticReceivePort;
    port echoDataOut : EchoDataOutputPort;
    port calibrationOut : CalibrationOutputPort;
  }

  part def AcousticEchosounder {
    attribute installedDepth : Depth_m = 3.5;
    attribute defaultFrequency : Frequency_Hz = 120000.0;
    attribute pingKind : PingKind = PingKind::BroadbandChirp;
    attribute health : HealthState = HealthState::Nominal;

    port powerIn : PowerInputPort;
    port acoustic : AcousticBidirectionalPort;
    port echoDataOut : EchoDataOutputPort;
    port calibrationOut : CalibrationOutputPort;

    part transceiver : BroadbandTransceiver;
    part transducer : SplitBeamTransducer;

    connect transceiver.transmitOut to transducer.acoustic;
    connect transducer.acoustic to transceiver.receiveIn;
    connect transceiver.echoDataOut to echoDataOut;
    connect transceiver.calibrationOut to calibrationOut;
    connect powerIn to transceiver.powerIn;
    connect powerIn to transducer.powerIn;
  }

  part def GNSSReceiver {
    attribute horizontalAccuracy : Length_m = 1.5;
    attribute updatePeriod : Time_s = 1.0;

    port powerIn : PowerInputPort;
    port navigationOut : NavigationOutputPort;
  }

  part def MotionReferenceUnit {
    attribute rollAccuracy : Angle_deg = 0.05;
    attribute pitchAccuracy : Angle_deg = 0.05;
    attribute heaveAccuracy : Length_m = 0.05;
    attribute updatePeriod : Time_s = 0.02;

    port powerIn : PowerInputPort;
    port attitudeOut : AttitudeOutputPort;
  }

  part def SoundSpeedProfiler {
    attribute maximumCastDepth : Depth_m = 1000.0;
    attribute temperatureAccuracy : Temperature_degC = 0.01;
    attribute salinityAccuracy : Salinity_psu = 0.02;
    attribute soundSpeedAccuracy : Speed_m_per_s = 0.2;

    port powerIn : PowerInputPort;
    port environmentOut : EnvironmentOutputPort;
  }

  part def CalibrationSphere {
    attribute sphereDiameter : Length_m = 0.0381;
    attribute nominalTargetStrengthAt120kHz : TS_dB = -42.4;
    attribute deploymentDepth : Depth_m = 15.0;
  }

  part def AcousticDataProcessor {
    attribute minimumSvThreshold : Sv_dB = -70.0;
    attribute minimumSignalToNoiseRatio : AcousticLevel_dB = 10.0;
    attribute maximumProcessingLatency : Time_s = 5.0;
    attribute internalDataRate : DataRate_Mbps = 1000.0;

    port powerIn : PowerInputPort;
    port echoIn : EchoDataInputPort;
    port navigationIn : DataNetworkInputPort;
    port attitudeIn : DataNetworkInputPort;
    port environmentIn : DataNetworkInputPort;
    port calibrationIn : CalibrationInputPort;
    port processedCellOut : ProcessedCellOutputPort;
    port statusOut : StatusOutputPort;

    perform action compensate : ApplyMotionCompensation;
    perform action correct : CorrectForSoundSpeed;
    perform action detect : DetectFishBackscatter;
    perform action classify : ClassifyAggregation;
  }

  part def BiomassEstimator {
    attribute defaultMeanFishMass : Biomass_kg = 0.18;
    attribute allowableUncertaintyPercent : Real = 25.0;
    attribute targetStrengthModelIntercept : TS_dB = -66.0;

    port powerIn : PowerInputPort;
    port processedCellIn : ProcessedCellInputPort;
    port surveyPlanIn : SurveyPlanInputPort;
    port biomassProductOut : BiomassProductOutputPort;
    port statusOut : StatusOutputPort;

    perform action estimate : EstimateBiomass;
  }

  part def OperatorConsole {
    attribute displayUpdatePeriod : Time_s = 1.0;
    attribute storageCapacityHours : Time_s = 2592000.0;

    port commandOut : CommandInputPort;
    port surveyPlanOut : SurveyPlanInputPort;
    port statusIn : StatusOutputPort;
    port biomassIn : BiomassProductOutputPort;
  }

  part def SurveyController {
    attribute currentMode : SurveyMode = SurveyMode::Idle;
    attribute health : HealthState = HealthState::Nominal;
    attribute controlCyclePeriod : Time_s = 0.1;

    port powerIn : PowerInputPort;
    port commandIn : CommandInputPort;
    port surveyPlanIn : SurveyPlanInputPort;
    port statusOut : StatusOutputPort;
    port networkOut : DataNetworkOutputPort;

    exhibit stateMachine : SurveyControllerBehavior;
    perform action surveyExecution : ExecuteFisheriesAcousticSurvey;
  }

  part def WaterColumn {
    attribute surfaceTemperature : Temperature_degC = 12.0;
    attribute surfaceSalinity : Salinity_psu = 34.5;
    attribute meanSoundSpeed : Speed_m_per_s = 1490.0;
    attribute maximumSurveyDepth : Depth_m = 500.0;
    attribute ambientNoiseLevel : AcousticLevel_dB = 65.0;

    port acousticInterface : AcousticBidirectionalPort;
    port environmentOut : EnvironmentOutputPort;
  }

  part def FishPopulation {
    attribute dominantSpecies : String = "Small pelagic schooling fish";
    attribute meanTargetStrength : TS_dB = -45.0;
    attribute meanIndividualMass : Biomass_kg = 0.18;
    attribute maximumSchoolDepth : Depth_m = 300.0;
    attribute estimatedTrueBiomass : Biomass_kg = 12500000.0;

    port acousticScattering : AcousticBidirectionalPort;
  }

  part def Seafloor {
    attribute meanDepth : Depth_m = 180.0;
    attribute roughnessIndex : Real = 0.35;
    attribute bottomBackscatterStrength : AcousticLevel_dB = -25.0;

    port acousticReflection : AcousticBidirectionalPort;
  }

  part def FisheriesAcousticSurveySystem {
    doc /*
      The system integrates a calibrated echosounder, navigation sensors, environmental sensors,
      processing software, and operator interfaces to survey fish populations acoustically and
      produce georeferenced biomass estimates.
    */

    attribute systemName : String = "Integrated Fisheries Acoustic Survey System";
    attribute designMaximumDepth : Depth_m = 600.0;
    attribute nominalPingInterval : Time_s = 1.0;
    attribute nominalSurveySpeed : Speed_m_per_s = 3.0;
    attribute primarySurveyFrequency : Frequency_Hz = 120000.0;
    attribute secondarySurveyFrequency : Frequency_Hz = 38000.0;
    attribute requiredBiomassUncertaintyPercent : Real = 25.0;
    attribute minimumDetectableSv : Sv_dB = -70.0;

    port operatorCommandIn : CommandInputPort;
    port surveyPlanIn : SurveyPlanInputPort;
    port statusOut : StatusOutputPort;
    port biomassProductOut : BiomassProductOutputPort;

    part vessel : SurveyVessel;
    part echosounder : AcousticEchosounder;
    part gnss : GNSSReceiver;
    part motionReference : MotionReferenceUnit;
    part soundSpeedProfiler : SoundSpeedProfiler;
    part controller : SurveyController;
    part dataProcessor : AcousticDataProcessor;
    part biomassEstimator : BiomassEstimator;
    part operatorConsole : OperatorConsole;
    part calibrationSphere : CalibrationSphere;

    connect vessel.powerDistribution.sonarPowerOut to echosounder.powerIn;
    connect vessel.powerDistribution.computePowerOut to controller.powerIn;
    connect vessel.powerDistribution.computePowerOut to dataProcessor.powerIn;
    connect vessel.powerDistribution.computePowerOut to biomassEstimator.powerIn;
    connect vessel.powerDistribution.sensorPowerOut to gnss.powerIn;
    connect vessel.powerDistribution.sensorPowerOut to motionReference.powerIn;
    connect vessel.powerDistribution.sensorPowerOut to soundSpeedProfiler.powerIn;

    connect operatorCommandIn to controller.commandIn;
    connect surveyPlanIn to controller.surveyPlanIn;
    connect operatorConsole.commandOut to controller.commandIn;
    connect operatorConsole.surveyPlanOut to controller.surveyPlanIn;

    connect echosounder.echoDataOut to dataProcessor.echoIn;
    connect echosounder.calibrationOut to dataProcessor.calibrationIn;
    connect gnss.navigationOut to dataProcessor.navigationIn;
    connect motionReference.attitudeOut to dataProcessor.attitudeIn;
    connect soundSpeedProfiler.environmentOut to dataProcessor.environmentIn;

    connect dataProcessor.processedCellOut to biomassEstimator.processedCellIn;
    connect controller.surveyPlanIn to biomassEstimator.surveyPlanIn;
    connect biomassEstimator.biomassProductOut to biomassProductOut;
    connect biomassEstimator.biomassProductOut to operatorConsole.biomassIn;

    connect controller.statusOut to statusOut;
    connect controller.statusOut to operatorConsole.statusIn;
    connect dataProcessor.statusOut to operatorConsole.statusIn;
    connect biomassEstimator.statusOut to operatorConsole.statusIn;
  }

  part def FisheriesAcousticOperatingEnvironment {
    part waterColumn : WaterColumn;
    part fishPopulation : FishPopulation;
    part seafloor : Seafloor;

    connect waterColumn.acousticInterface to fishPopulation.acousticScattering;
    connect waterColumn.acousticInterface to seafloor.acousticReflection;
  }

  part fisheriesAcousticMission {
    part system : FisheriesAcousticSurveySystem;
    part environment : FisheriesAcousticOperatingEnvironment;

    connect system.echosounder.acoustic to environment.waterColumn.acousticInterface;
    connect system.soundSpeedProfiler.environmentOut to environment.waterColumn.environmentOut;
  }

  requirement def PrimaryFunctionRequirement {
    doc /*
      The Fisheries Acoustic Survey System shall emit calibrated acoustic pulses into the water column,
      receive and process echoes from fish aggregations, and produce georeferenced biomass and distribution
      products for fisheries assessment.
    */

    subject system : FisheriesAcousticSurveySystem;

    require constraint {
      system.primarySurveyFrequency > 0.0
    }

    require constraint {
      system.designMaximumDepth >= 500.0
    }

    require constraint {
      system.requiredBiomassUncertaintyPercent <= 25.0
    }
  }

  requirement def AcousticDetectionRequirement {
    doc /*
      The system shall detect fish backscatter cells with volume backscattering strength at or above
      the configured survey threshold in the planned depth interval.
    */

    subject system : FisheriesAcousticSurveySystem;

    require constraint {
      system.minimumDetectableSv <= -70.0
    }

    require constraint {
      system.designMaximumDepth >= 600.0
    }
  }

  requirement def CalibrationRequirement {
    doc /*
      The system shall support echosounder calibration using a reference target before a quantitative
      biomass survey begins.
    */

    subject system : FisheriesAcousticSurveySystem;

    require constraint {
      system.echosounder.health == HealthState::Nominal
    }

    require constraint {
      system.calibrationSphere.nominalTargetStrengthAt120kHz < 0.0
    }
  }

  requirement def GeoreferencingRequirement {
    doc /*
      Each accepted acoustic fish cell shall be associated with navigation, attitude, and environmental
      context sufficient to estimate fish location and depth.
    */

    subject system : FisheriesAcousticSurveySystem;

    require constraint {
      system.gnss.horizontalAccuracy <= 2.0
    }

    require constraint {
      system.motionReference.rollAccuracy <= 0.1
    }

    require constraint {
      system.soundSpeedProfiler.soundSpeedAccuracy <= 0.5
    }
  }

  requirement def BiomassProductRequirement {
    doc /*
      The system shall generate a biomass map containing estimated total biomass, sampled volume,
      mapped area, and uncertainty for the surveyed area.
    */

    subject system : FisheriesAcousticSurveySystem;

    require constraint {
      system.biomassEstimator.allowableUncertaintyPercent <= system.requiredBiomassUncertaintyPercent
    }
  }

  requirement primaryFunction : PrimaryFunctionRequirement {
    subject system = fisheriesAcousticMission.system;
  }

  requirement acousticDetection : AcousticDetectionRequirement {
    subject system = fisheriesAcousticMission.system;
  }

  requirement calibration : CalibrationRequirement {
    subject system = fisheriesAcousticMission.system;
  }

  requirement georeferencing : GeoreferencingRequirement {
    subject system = fisheriesAcousticMission.system;
  }

  requirement biomassProduct : BiomassProductRequirement {
    subject system = fisheriesAcousticMission.system;
  }

  satisfy primaryFunction by fisheriesAcousticMission.system;
  satisfy acousticDetection by fisheriesAcousticMission.system.echosounder;
  satisfy calibration by fisheriesAcousticMission.system.calibrationSphere;
  satisfy georeferencing by fisheriesAcousticMission.system.gnss;
  satisfy georeferencing by fisheriesAcousticMission.system.motionReference;
  satisfy georeferencing by fisheriesAcousticMission.system.soundSpeedProfiler;
  satisfy biomassProduct by fisheriesAcousticMission.system.biomassEstimator;

}
