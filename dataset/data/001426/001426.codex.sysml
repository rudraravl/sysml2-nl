package FarmWiseSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Area :> Real {
    unit = SI::squareMetre;
  }

  attribute def MassFlowRate :> Real {
    unit = SI::kilogramPerSecond;
  }

  attribute def VolumeFlowRate :> Real {
    unit = SI::cubicMetrePerSecond;
  }

  attribute def Speed :> Real {
    unit = SI::metrePerSecond;
  }

  attribute def Energy :> Real {
    unit = SI::joule;
  }

  attribute def Power :> Real {
    unit = SI::watt;
  }

  attribute def Percent :> Real {
    range = 0.0 .. 100.0;
  }

  attribute def Confidence :> Real {
    range = 0.0 .. 1.0;
  }

  attribute def PlantSpacing :> Real {
    unit = SI::metre;
  }

  enum def CropType {
    enum wheat;
    enum corn;
    enum lettuce;
    enum tomato;
    enum strawberry;
    enum soybean;
  }

  enum def WeedTreatmentMode {
    enum mechanicalCut;
    enum precisionSpray;
    enum avoidCrop;
    enum noAction;
  }

  item def FieldMap {
    attribute fieldArea : Area;
    attribute rowSpacing : PlantSpacing;
    attribute crop : CropType;
    attribute boundaryLatitudeDegrees : Real[*];
    attribute boundaryLongitudeDegrees : Real[*];
  }

  item def NavigationCommand {
    attribute targetLatitudeDegrees : Real;
    attribute targetLongitudeDegrees : Real;
    attribute targetSpeed : Speed;
    attribute rowIndex : Integer;
  }

  item def CropObservation {
    attribute latitudeDegrees : Real;
    attribute longitudeDegrees : Real;
    attribute cropProbability : Confidence;
    attribute weedProbability : Confidence;
    attribute plantHealthScore : Percent;
  }

  item def TreatmentCommand {
    attribute latitudeDegrees : Real;
    attribute longitudeDegrees : Real;
    attribute mode : WeedTreatmentMode;
    attribute doseRate : VolumeFlowRate;
    attribute bladeDepth : LengthValue;
  }

  item def FarmReport {
    attribute treatedArea : Area;
    attribute weedCount : Integer;
    attribute cropCount : Integer;
    attribute averageCropHealth : Percent;
    attribute energyConsumed : Energy;
  }

  port def DataPort {
    out item data : CropObservation;
  }

  port def CommandPort {
    in item command : NavigationCommand;
  }

  port def TreatmentPort {
    in item treatment : TreatmentCommand;
  }

  port def ReportPort {
    out item report : FarmReport;
  }

  port def PowerPort {
    out attribute suppliedPower : Power;
  }

  port def MobilityPort {
    in item routeCommand : NavigationCommand;
    out attribute actualSpeed : Speed;
  }

  part def FarmWiseAutonomousCultivator {
    doc /* Primary high-level function: autonomously navigate crop rows, detect crops and weeds, and perform precise weed control while preserving crop health and generating operational farm intelligence. */

    attribute nominalOperatingSpeed : Speed = 1.2;
    attribute maximumOperatingSpeed : Speed = 2.0;
    attribute minimumCropDetectionConfidence : Confidence = 0.92;
    attribute minimumWeedDetectionConfidence : Confidence = 0.88;
    attribute batteryCapacity : Energy = 288000000.0;
    attribute maximumContinuousPower : Power = 8500.0;
    attribute dailyCoverageTarget : Area = 40000.0;

    port commandIn : CommandPort;
    port reportOut : ReportPort;
    port powerOut : PowerPort;

    part autonomyController : AutonomyController;
    part perceptionSystem : PerceptionSystem;
    part navigationSystem : NavigationSystem;
    part treatmentSystem : WeedTreatmentSystem;
    part energySystem : EnergySystem;
    part safetySystem : SafetySystem;
    part farmDataSystem : FarmDataSystem;

    connect commandIn.command to autonomyController.navigationRequest;
    connect autonomyController.navigationCommand to navigationSystem.routeCommand;
    connect navigationSystem.poseEstimate to autonomyController.poseInput;
    connect perceptionSystem.observationOut to autonomyController.cropObservation;
    connect autonomyController.treatmentCommand to treatmentSystem.treatment;
    connect energySystem.availablePower to powerOut.suppliedPower;
    connect energySystem.availablePower to navigationSystem.drivePower;
    connect energySystem.availablePower to treatmentSystem.toolPower;
    connect safetySystem.safeStopCommand to autonomyController.safetyOverride;
    connect autonomyController.reportSummary to farmDataSystem.reportInput;
    connect farmDataSystem.reportOut to reportOut.report;

    action def ExecuteFarmWiseMission {
      in item fieldMap : FieldMap;
      out item missionReport : FarmReport;

      first startMission;
      then loadFieldPlan;
      then surveyCropRows;
      then identifyPlants;
      then treatDetectedWeeds;
      then compileOperationalReport;

      action startMission;
      action loadFieldPlan;
      action surveyCropRows;
      action identifyPlants;
      action treatDetectedWeeds;
      action compileOperationalReport;
    }

    state def OperationalStates {
      state idle;
      state planning;
      state navigating;
      state detectingPlants;
      state treatingWeeds;
      state reporting;
      state safeStopped;
      state charging;

      initial then idle;

      transition idle_to_planning
        first idle
        accept NavigationCommand
        then planning;

      transition planning_to_navigating
        first planning
        if autonomyController.routeValid == true
        then navigating;

      transition navigating_to_detecting
        first navigating
        if navigationSystem.rowTrackingError <= 0.05
        then detectingPlants;

      transition detecting_to_treating
        first detectingPlants
        if perceptionSystem.latestWeedConfidence >= minimumWeedDetectionConfidence
        then treatingWeeds;

      transition treating_to_navigating
        first treatingWeeds
        if treatmentSystem.currentTreatmentComplete == true
        then navigating;

      transition navigating_to_reporting
        first navigating
        if autonomyController.fieldComplete == true
        then reporting;

      transition reporting_to_idle
        first reporting
        then idle;

      transition any_to_safeStopped
        first idle, planning, navigating, detectingPlants, treatingWeeds, reporting
        if safetySystem.emergencyStopActive == true
        then safeStopped;

      transition safeStopped_to_idle
        first safeStopped
        if safetySystem.emergencyStopActive == false
        then idle;

      transition idle_to_charging
        first idle
        if energySystem.stateOfCharge < 20.0
        then charging;

      transition charging_to_idle
        first charging
        if energySystem.stateOfCharge >= 95.0
        then idle;
    }
  }

  part def AutonomyController {
    attribute routeValid : Boolean;
    attribute fieldComplete : Boolean;
    attribute activeRowIndex : Integer;
    attribute coverageCompleted : Percent;

    in item navigationRequest : NavigationCommand;
    in item poseInput : NavigationCommand;
    in item cropObservation : CropObservation;
    in item safetyOverride : NavigationCommand;
    out item navigationCommand : NavigationCommand;
    out item treatmentCommand : TreatmentCommand;
    out item reportSummary : FarmReport;

    action def PlanAndCoordinateMission {
      in item fieldPlan : FieldMap;
      in item observation : CropObservation;
      out item route : NavigationCommand;
      out item treatment : TreatmentCommand;

      action selectNextCropRow;
      action maintainRowCenterline;
      action classifyPlantTarget;
      action authorizeTreatment;
    }
  }

  part def PerceptionSystem {
    attribute cameraFrameRateHz : Real = 30.0;
    attribute lidarScanRateHz : Real = 20.0;
    attribute latestCropConfidence : Confidence;
    attribute latestWeedConfidence : Confidence;
    attribute minimumIlluminationLux : Real = 200.0;

    port observationOut : DataPort;

    part stereoCamera : StereoCamera;
    part lidar : FieldLidar;
    part plantClassifier : PlantClassifier;

    connect stereoCamera.imageObservation to plantClassifier.visualInput;
    connect lidar.rangeObservation to plantClassifier.depthInput;
    connect plantClassifier.classifiedObservation to observationOut.data;

    action def DetectCropAndWeed {
      in item fieldImage : CropObservation;
      out item classifiedPlant : CropObservation;

      action normalizeImage;
      action segmentPlantCanopy;
      action classifyCropVersusWeed;
      action estimatePlantHealth;
    }
  }

  part def StereoCamera {
    attribute horizontalFieldOfViewDegrees : Real = 90.0;
    attribute verticalFieldOfViewDegrees : Real = 60.0;
    attribute resolutionMegapixels : Real = 12.0;
    out item imageObservation : CropObservation;
  }

  part def FieldLidar {
    attribute rangeMetres : LengthValue = 25.0;
    attribute angularResolutionDegrees : Real = 0.2;
    out item rangeObservation : CropObservation;
  }

  part def PlantClassifier {
    attribute cropModelAccuracy : Percent = 96.0;
    attribute weedModelAccuracy : Percent = 94.0;
    in item visualInput : CropObservation;
    in item depthInput : CropObservation;
    out item classifiedObservation : CropObservation;
  }

  part def NavigationSystem {
    attribute rowTrackingError : LengthValue;
    attribute maximumSlopeDegrees : Real = 12.0;
    attribute commandedSpeed : Speed;
    attribute actualSpeed : Speed;

    in item routeCommand : NavigationCommand;
    in attribute drivePower : Power;
    out item poseEstimate : NavigationCommand;

    part gnssReceiver : GnssReceiver;
    part wheelDrive : ElectricDrive;
    part rowFollower : RowFollower;

    connect routeCommand to rowFollower.desiredRoute;
    connect rowFollower.driveCommand to wheelDrive.mobilityCommand;
    connect gnssReceiver.positionEstimate to poseEstimate;
  }

  part def GnssReceiver {
    attribute horizontalAccuracy : LengthValue = 0.02;
    attribute updateRateHz : Real = 10.0;
    out item positionEstimate : NavigationCommand;
  }

  part def RowFollower {
    attribute lateralError : LengthValue;
    in item desiredRoute : NavigationCommand;
    out item driveCommand : NavigationCommand;
  }

  part def ElectricDrive {
    attribute tractionPower : Power;
    attribute wheelTorqueNewtonMetre : Real;
    in item mobilityCommand : NavigationCommand;
  }

  part def WeedTreatmentSystem {
    attribute currentTreatmentComplete : Boolean;
    attribute treatmentLatencySeconds : Real = 0.12;
    attribute maximumSprayRate : VolumeFlowRate = 0.00004;
    attribute bladeMaximumDepth : LengthValue = 0.04;

    in item treatment : TreatmentCommand;
    in attribute toolPower : Power;

    part microSprayer : PrecisionSprayer;
    part mechanicalBlade : MechanicalWeeder;
    part actuatorController : TreatmentActuatorController;

    connect treatment to actuatorController.requestedTreatment;
    connect actuatorController.sprayCommand to microSprayer.sprayRequest;
    connect actuatorController.bladeCommand to mechanicalBlade.cutRequest;
  }

  part def PrecisionSprayer {
    attribute tankVolume : VolumeValue = 0.08;
    attribute nozzleCount : Integer = 12;
    attribute dropletDiameterMetres : LengthValue = 0.0002;
    in item sprayRequest : TreatmentCommand;
  }

  part def MechanicalWeeder {
    attribute bladeWidth : LengthValue = 0.08;
    attribute actuationTimeSeconds : Real = 0.08;
    in item cutRequest : TreatmentCommand;
  }

  part def TreatmentActuatorController {
    in item requestedTreatment : TreatmentCommand;
    out item sprayCommand : TreatmentCommand;
    out item bladeCommand : TreatmentCommand;
  }

  part def EnergySystem {
    attribute stateOfCharge : Percent;
    attribute availableEnergy : Energy;
    attribute availablePower : Power;
    attribute chargeRate : Power = 3200.0;

    part batteryPack : BatteryPack;
    part powerDistributionUnit : PowerDistributionUnit;

    connect batteryPack.outputPower to powerDistributionUnit.inputPower;
    connect powerDistributionUnit.regulatedPower to availablePower;
  }

  part def BatteryPack {
    attribute capacity : Energy = 288000000.0;
    attribute stateOfCharge : Percent;
    out attribute outputPower : Power;
  }

  part def PowerDistributionUnit {
    in attribute inputPower : Power;
    out attribute regulatedPower : Power;
  }

  part def SafetySystem {
    attribute emergencyStopActive : Boolean;
    attribute obstacleDistance : LengthValue;
    attribute minimumObstacleClearance : LengthValue = 1.5;

    out item safeStopCommand : NavigationCommand;

    part obstacleMonitor : ObstacleMonitor;
    part emergencyStop : EmergencyStopController;

    connect obstacleMonitor.stopRequest to emergencyStop.stopInput;
    connect emergencyStop.stopCommand to safeStopCommand;
  }

  part def ObstacleMonitor {
    attribute nearestObstacleDistance : LengthValue;
    out item stopRequest : NavigationCommand;
  }

  part def EmergencyStopController {
    in item stopInput : NavigationCommand;
    out item stopCommand : NavigationCommand;
  }

  part def FarmDataSystem {
    attribute retainedMissionCount : Integer;
    attribute uploadedReportCount : Integer;

    in item reportInput : FarmReport;
    out item reportOut : FarmReport;

    action def GenerateFarmIntelligenceReport {
      in item observations : CropObservation[*];
      out item report : FarmReport;

      action aggregateWeedLocations;
      action computeTreatedArea;
      action calculateCropHealthAverage;
      action estimateEnergyUse;
      action publishMissionReport;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The FarmWise system shall autonomously perform precision crop-row navigation, plant detection, weed treatment, and operational reporting to reduce manual weeding effort while protecting crop plants. */

    subject farmWise : FarmWiseAutonomousCultivator;

    require constraint {
      farmWise.minimumCropDetectionConfidence >= 0.92 and
      farmWise.minimumWeedDetectionConfidence >= 0.88 and
      farmWise.dailyCoverageTarget >= 40000.0
    }
  }

  requirement def CropProtectionRequirement {
    doc /* The system shall avoid treating detected crop plants when crop classification confidence meets or exceeds the minimum crop detection confidence. */

    subject perception : PerceptionSystem;

    require constraint {
      perception.latestCropConfidence >= 0.92 implies perception.latestWeedConfidence < 0.88
    }
  }

  requirement def WeedTreatmentRequirement {
    doc /* The system shall command a weed treatment when weed confidence is sufficient and the target is within the treatment workspace. */

    subject treatment : WeedTreatmentSystem;

    require constraint {
      treatment.treatmentLatencySeconds <= 0.15 and
      treatment.maximumSprayRate <= 0.00004
    }
  }

  requirement def NavigationRequirement {
    doc /* The system shall maintain crop-row tracking accuracy during autonomous field traversal. */

    subject navigation : NavigationSystem;

    require constraint {
      navigation.rowTrackingError <= 0.05 and
      navigation.maximumSlopeDegrees >= 12.0
    }
  }

  requirement def EnergyRequirement {
    doc /* The system shall provide enough stored energy for a normal field mission and enter charging when reserve energy is low. */

    subject energy : EnergySystem;

    require constraint {
      energy.stateOfCharge >= 20.0 implies energy.availablePower >= 5000.0
    }
  }

  requirement def SafetyRequirement {
    doc /* The system shall issue a safe stop when an obstacle is detected within the minimum clearance distance or when emergency stop is active. */

    subject safety : SafetySystem;

    require constraint {
      safety.obstacleDistance < safety.minimumObstacleClearance implies safety.emergencyStopActive == true
    }
  }

  part farmWiseSystem : FarmWiseAutonomousCultivator;

  satisfy PrimaryFunctionRequirement by farmWiseSystem;
  satisfy NavigationRequirement by farmWiseSystem.navigationSystem;
  satisfy WeedTreatmentRequirement by farmWiseSystem.treatmentSystem;
  satisfy CropProtectionRequirement by farmWiseSystem.perceptionSystem;
  satisfy EnergyRequirement by farmWiseSystem.energySystem;
  satisfy SafetyRequirement by farmWiseSystem.safetySystem;
}