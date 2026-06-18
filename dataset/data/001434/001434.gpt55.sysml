package RoboticsGeographySpecification {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def LengthValue {
        attribute magnitude : Real;
        attribute unit : String = "m";
    }

    attribute def AreaValue {
        attribute magnitude : Real;
        attribute unit : String = "m^2";
    }

    attribute def AngleValue {
        attribute magnitude : Real;
        attribute unit : String = "deg";
    }

    attribute def TimeValue {
        attribute magnitude : Real;
        attribute unit : String = "s";
    }

    attribute def SpeedValue {
        attribute magnitude : Real;
        attribute unit : String = "m/s";
    }

    attribute def EnergyValue {
        attribute magnitude : Real;
        attribute unit : String = "Wh";
    }

    attribute def PowerValue {
        attribute magnitude : Real;
        attribute unit : String = "W";
    }

    attribute def DataRateValue {
        attribute magnitude : Real;
        attribute unit : String = "Mbit/s";
    }

    attribute def PercentValue {
        attribute magnitude : Real;
        attribute unit : String = "%";
    }

    attribute def CountValue {
        attribute magnitude : Integer;
        attribute unit : String = "count";
    }

    enum def GeographicDomainKind {
        enum aerial;
        enum terrestrial;
        enum aquatic;
        enum subterranean;
        enum indoorBuiltEnvironment;
        enum orbital;
    }

    enum def RobotMobilityKind {
        enum rotorcraft;
        enum fixedWing;
        enum wheeled;
        enum tracked;
        enum legged;
        enum surfaceVessel;
        enum underwaterVehicle;
        enum railGuided;
    }

    enum def MissionCommandKind {
        enum startSurvey;
        enum pauseSurvey;
        enum resumeSurvey;
        enum returnToBase;
        enum abortMission;
        enum publishAtlas;
    }

    enum def HazardKind {
        enum restrictedAirspace;
        enum unstableGround;
        enum waterObstacle;
        enum electromagneticInterference;
        enum humanCrowd;
        enum severeWeather;
        enum lowVisibility;
        enum depletedBattery;
        enum localizationFault;
    }

    enum def CoverageQualityKind {
        enum unknown;
        enum low;
        enum acceptable;
        enum high;
        enum verified;
    }

    item def GeoCoordinate {
        attribute latitude : AngleValue;
        attribute longitude : AngleValue;
        attribute altitudeAboveMeanSeaLevel : LengthValue;
        attribute horizontalUncertainty : LengthValue;
        attribute verticalUncertainty : LengthValue;
    }

    item def GeoBoundary {
        attribute name : String;
        attribute domain : GeographicDomainKind;
        attribute nominalArea : AreaValue;
        item corner[4..*] : GeoCoordinate;
    }

    item def GeoCell {
        attribute identifier : String;
        attribute domain : GeographicDomainKind;
        attribute cellArea : AreaValue;
        attribute requiredResolution : LengthValue;
        attribute coverageQuality : CoverageQualityKind;
        item center : GeoCoordinate;
    }

    item def RoboticsSite {
        attribute siteIdentifier : String;
        attribute siteName : String;
        attribute domain : GeographicDomainKind;
        attribute operationalRadius : LengthValue;
        attribute robotCapacity : CountValue;
        item location : GeoCoordinate;
    }

    item def TerrainFeature {
        attribute featureIdentifier : String;
        attribute featureName : String;
        attribute domain : GeographicDomainKind;
        attribute traversabilityScore : PercentValue;
        attribute slopeAngle : AngleValue;
        attribute clearanceHeight : LengthValue;
        item location : GeoCoordinate;
    }

    item def HazardArea {
        attribute hazardIdentifier : String;
        attribute hazardKind : HazardKind;
        attribute severity : PercentValue;
        attribute recommendedStandoffDistance : LengthValue;
        item boundary : GeoBoundary;
    }

    item def RobotCapabilityProfile {
        attribute robotIdentifier : String;
        attribute mobilityKind : RobotMobilityKind;
        attribute supportedDomain : GeographicDomainKind;
        attribute maximumSpeed : SpeedValue;
        attribute endurance : TimeValue;
        attribute nominalSensorRange : LengthValue;
        attribute positioningAccuracy : LengthValue;
        attribute payloadMassCapacity : LengthValue;
    }

    item def MissionObjective {
        attribute objectiveIdentifier : String;
        attribute objectiveStatement : String;
        attribute minimumCoverage : PercentValue;
        attribute targetHorizontalAccuracy : LengthValue;
        attribute maximumUpdateLatency : TimeValue;
        item regionOfInterest : GeoBoundary;
    }

    item def MissionPlan {
        attribute planIdentifier : String;
        attribute missionName : String;
        attribute plannedDuration : TimeValue;
        attribute plannedCoverage : PercentValue;
        attribute safetyStandoff : LengthValue;
        item objective : MissionObjective;
        item surveyCells[1..*] : GeoCell;
    }

    item def MissionCommand {
        attribute commandIdentifier : String;
        attribute kind : MissionCommandKind;
        attribute issuedBy : String;
        attribute issueTimeUTC : String;
        item referencedPlan : MissionPlan;
    }

    item def CommandAcknowledgement {
        attribute commandIdentifier : String;
        attribute accepted : Boolean;
        attribute reason : String;
        attribute acknowledgementTimeUTC : String;
    }

    item def RobotTelemetry {
        attribute robotIdentifier : String;
        attribute batteryStateOfCharge : PercentValue;
        attribute remainingEnergy : EnergyValue;
        attribute groundSpeed : SpeedValue;
        attribute linkQuality : PercentValue;
        attribute currentDomain : GeographicDomainKind;
        item pose : GeoCoordinate;
    }

    item def HealthReport {
        attribute robotIdentifier : String;
        attribute healthy : Boolean;
        attribute batteryStateOfCharge : PercentValue;
        attribute navigationAvailable : Boolean;
        attribute sensorPayloadAvailable : Boolean;
        attribute communicationsAvailable : Boolean;
        attribute faultDescription : String;
    }

    item def GeoObservation {
        attribute observationIdentifier : String;
        attribute sourceRobotIdentifier : String;
        attribute observationTimeUTC : String;
        attribute domain : GeographicDomainKind;
        attribute resolution : LengthValue;
        attribute confidence : PercentValue;
        item location : GeoCoordinate;
        item terrainFeature[0..*] : TerrainFeature;
        item hazard[0..*] : HazardArea;
        item roboticsSite[0..*] : RoboticsSite;
    }

    item def MapTile {
        attribute tileIdentifier : String;
        attribute domain : GeographicDomainKind;
        attribute resolution : LengthValue;
        attribute horizontalAccuracy : LengthValue;
        attribute coverageQuality : CoverageQualityKind;
        item boundary : GeoBoundary;
        item observations[0..*] : GeoObservation;
    }

    item def RoboticsGeographyAtlas {
        attribute atlasIdentifier : String;
        attribute title : String;
        attribute version : String;
        attribute generatedTimeUTC : String;
        attribute totalMappedArea : AreaValue;
        attribute achievedCoverage : PercentValue;
        attribute atlasPurpose : String;
        item region : GeoBoundary;
        item mapTiles[1..*] : MapTile;
        item knownRoboticsSites[0..*] : RoboticsSite;
        item knownHazards[0..*] : HazardArea;
    }

    port def MissionControlPort {
        in item command : MissionCommand;
        out item acknowledgement : CommandAcknowledgement;
    }

    port def FleetCommandPort {
        in item plan : MissionPlan;
        in item command : MissionCommand;
        out item acknowledgement : CommandAcknowledgement;
    }

    port def ObservationPort {
        out item observation : GeoObservation;
        out item telemetry : RobotTelemetry;
        out item health : HealthReport;
    }

    port def ObservationIngestPort {
        in item observation : GeoObservation;
        in item telemetry : RobotTelemetry;
        in item health : HealthReport;
    }

    port def AtlasPublicationPort {
        out item atlas : RoboticsGeographyAtlas;
        out item tile : MapTile;
    }

    port def AtlasConsumerPort {
        in item atlas : RoboticsGeographyAtlas;
        in item tile : MapTile;
    }

    port def DataBackhaulPort {
        in item observation : GeoObservation;
        in item telemetry : RobotTelemetry;
        out item plan : MissionPlan;
        out item command : MissionCommand;
    }

    port def PowerPort {
        in item suppliedPower : PowerValue;
        out item consumedPower : PowerValue;
    }

    part def SensorPayload {
        attribute sensorName : String;
        attribute swathWidth : LengthValue;
        attribute measurementResolution : LengthValue;
        attribute maximumRange : LengthValue;
        attribute powerDraw : PowerValue;
        port observationOut : ObservationPort;

        action def CaptureGeographicObservation {
            in item currentPose : GeoCoordinate;
            out item observation : GeoObservation;
        }
    }

    part def LocalizationModule {
        attribute horizontalAccuracy : LengthValue;
        attribute verticalAccuracy : LengthValue;
        attribute updatePeriod : TimeValue;
        port telemetryOut : ObservationPort;

        action def EstimatePose {
            out item pose : GeoCoordinate;
        }
    }

    part def RobotController {
        port fleetCommand : FleetCommandPort;
        port observationOut : ObservationPort;

        action def ExecuteSurveyCell {
            in item assignedCell : GeoCell;
            out item observation : GeoObservation;
        }

        action def ReturnToBase {
            out item finalHealth : HealthReport;
        }
    }

    state def RobotOperationalState {
        state poweredOff;
        state standby;
        state navigatingToCell;
        state surveying;
        state transmitting;
        state returning;
        state charging;
        state faulted;

        entry; then poweredOff;

        transition powerOn first poweredOff then standby;
        transition receiveAssignment first standby then navigatingToCell;
        transition arriveAtCell first navigatingToCell then surveying;
        transition completeScan first surveying then transmitting;
        transition continueMission first transmitting then navigatingToCell;
        transition returnRequested first standby then returning;
        transition returnAfterTransmit first transmitting then returning;
        transition docked first returning then charging;
        transition charged first charging then standby;
        transition faultDetected first standby then faulted;
        transition faultDuringNavigate first navigatingToCell then faulted;
        transition faultDuringSurvey first surveying then faulted;
        transition resetFault first faulted then standby;
    }

    part def MappingRobot {
        attribute robotIdentifier : String;
        attribute supportedDomain : GeographicDomainKind;
        attribute mobilityKind : RobotMobilityKind;
        attribute maximumSpeed : SpeedValue;
        attribute endurance : TimeValue;
        attribute batteryCapacity : EnergyValue;
        attribute nominalCoverageRate : AreaValue;
        port command : FleetCommandPort;
        port observation : ObservationPort;
        port power : PowerPort;
        part controller : RobotController;
        part localization : LocalizationModule;
        part primarySensor : SensorPayload;
        exhibit state operatingState : RobotOperationalState;

        perform action executeSurveyCell : RobotController::ExecuteSurveyCell;
        perform action returnToBase : RobotController::ReturnToBase;

        connection commandToController connect command to controller.fleetCommand;
        connection controllerObservation connect controller.observationOut to observation;
        connection sensorObservation connect primarySensor.observationOut to observation;
        connection localizationTelemetry connect localization.telemetryOut to observation;
    }

    part def AerialMappingRobot :> MappingRobot {
        attribute supportedDomain : GeographicDomainKind = GeographicDomainKind::aerial;
        attribute mobilityKind : RobotMobilityKind = RobotMobilityKind::rotorcraft;
        attribute regulatoryCeiling : LengthValue;
        attribute windTolerance : SpeedValue;
    }

    part def GroundMappingRobot :> MappingRobot {
        attribute supportedDomain : GeographicDomainKind = GeographicDomainKind::terrestrial;
        attribute mobilityKind : RobotMobilityKind = RobotMobilityKind::wheeled;
        attribute obstacleClimbHeight : LengthValue;
        attribute minimumPassageWidth : LengthValue;
    }

    part def IndoorMappingRobot :> MappingRobot {
        attribute supportedDomain : GeographicDomainKind = GeographicDomainKind::indoorBuiltEnvironment;
        attribute mobilityKind : RobotMobilityKind = RobotMobilityKind::tracked;
        attribute doorWidthRequired : LengthValue;
        attribute stairNegotiationCapable : Boolean;
    }

    part def AquaticMappingRobot :> MappingRobot {
        attribute supportedDomain : GeographicDomainKind = GeographicDomainKind::aquatic;
        attribute mobilityKind : RobotMobilityKind = RobotMobilityKind::surfaceVessel;
        attribute waveHeightLimit : LengthValue;
        attribute draftDepth : LengthValue;
    }

    part def RobotFleet {
        attribute fleetIdentifier : String;
        attribute availableRobotCount : CountValue;
        port command : FleetCommandPort;
        port observations : ObservationPort;

        part aerialScout[2] : AerialMappingRobot;
        part groundScout[3] : GroundMappingRobot;
        part indoorScout[2] : IndoorMappingRobot;
        part aquaticScout[1] : AquaticMappingRobot;

        connection commandToAerial0 connect command to aerialScout[0].command;
        connection commandToAerial1 connect command to aerialScout[1].command;
        connection commandToGround0 connect command to groundScout[0].command;
        connection commandToGround1 connect command to groundScout[1].command;
        connection commandToGround2 connect command to groundScout[2].command;
        connection commandToIndoor0 connect command to indoorScout[0].command;
        connection commandToIndoor1 connect command to indoorScout[1].command;
        connection commandToAquatic0 connect command to aquaticScout[0].command;

        connection aerialObs0 connect aerialScout[0].observation to observations;
        connection aerialObs1 connect aerialScout[1].observation to observations;
        connection groundObs0 connect groundScout[0].observation to observations;
        connection groundObs1 connect groundScout[1].observation to observations;
        connection groundObs2 connect groundScout[2].observation to observations;
        connection indoorObs0 connect indoorScout[0].observation to observations;
        connection indoorObs1 connect indoorScout[1].observation to observations;
        connection aquaticObs0 connect aquaticScout[0].observation to observations;
    }

    part def MissionManager {
        attribute plannerName : String;
        attribute replanningInterval : TimeValue;
        attribute defaultCellSize : LengthValue;
        attribute requiredCoverage : PercentValue;
        port operatorInterface : MissionControlPort;
        port fleetInterface : FleetCommandPort;

        action def BuildMissionPlan {
            in item objective : MissionObjective;
            out item plan : MissionPlan;
        }

        action def AllocateCellsToFleet {
            in item plan : MissionPlan;
            in item fleetCapability[1..*] : RobotCapabilityProfile;
            out item allocatedPlan : MissionPlan;
        }

        action def ReplanForHazard {
            in item currentPlan : MissionPlan;
            in item hazard : HazardArea;
            out item revisedPlan : MissionPlan;
        }
    }

    part def CommunicationsGateway {
        attribute gatewayIdentifier : String;
        attribute nominalBackhaulRate : DataRateValue;
        attribute minimumRequiredLinkQuality : PercentValue;
        port fleetBackhaul : ObservationIngestPort;
        port missionBackhaul : DataBackhaulPort;
        port power : PowerPort;
    }

    part def GeospatialDataStore {
        attribute storeIdentifier : String;
        attribute retainedObservationCount : CountValue;
        attribute retainedAtlasVersions : CountValue;
        port observationIn : ObservationIngestPort;
        port atlasOut : AtlasPublicationPort;

        action def PersistObservation {
            in item observation : GeoObservation;
        }

        action def RetrieveTilesForRegion {
            in item region : GeoBoundary;
            out item tiles[0..*] : MapTile;
        }
    }

    part def GeographyAnalyticsEngine {
        attribute engineIdentifier : String;
        attribute fusionUpdatePeriod : TimeValue;
        attribute targetHorizontalAccuracy : LengthValue;
        attribute minimumConfidence : PercentValue;
        port observationIn : ObservationIngestPort;
        port atlasOut : AtlasPublicationPort;

        action def FuseObservationsIntoTiles {
            in item observations[1..*] : GeoObservation;
            out item tiles[1..*] : MapTile;
        }

        action def ClassifyRoboticsSites {
            in item observations[1..*] : GeoObservation;
            out item sites[0..*] : RoboticsSite;
        }

        action def DetectHazards {
            in item observations[1..*] : GeoObservation;
            out item hazards[0..*] : HazardArea;
        }

        action def GenerateAtlas {
            in item region : GeoBoundary;
            in item tiles[1..*] : MapTile;
            in item sites[0..*] : RoboticsSite;
            in item hazards[0..*] : HazardArea;
            out item atlas : RoboticsGeographyAtlas;
        }
    }

    part def SafetyMonitor {
        attribute minimumBatteryForReturn : PercentValue;
        attribute minimumHumanStandoff : LengthValue;
        attribute maximumAllowedLocalizationError : LengthValue;
        port telemetryIn : ObservationIngestPort;
        port safetyCommandOut : FleetCommandPort;

        action def EvaluateMissionSafety {
            in item telemetry : RobotTelemetry;
            in item health : HealthReport;
            out item command : MissionCommand;
        }
    }

    part def OperatorConsole {
        attribute consoleIdentifier : String;
        attribute operatorRole : String;
        port missionControl : MissionControlPort;
        port atlasConsumer : AtlasConsumerPort;

        action def DisplayRoboticsGeography {
            in item atlas : RoboticsGeographyAtlas;
        }

        action def SubmitSurveyRequest {
            in item objective : MissionObjective;
            out item command : MissionCommand;
        }
    }

    part def AtlasPublicationService {
        attribute serviceIdentifier : String;
        attribute publicationInterval : TimeValue;
        attribute maximumSubscriberCount : CountValue;
        port atlasIn : AtlasConsumerPort;
        port publicAtlasOut : AtlasPublicationPort;

        action def PublishAtlasVersion {
            in item atlas : RoboticsGeographyAtlas;
            out item publishedAtlas : RoboticsGeographyAtlas;
        }
    }

    action def ProduceRoboticsGeographyAtlas {
        in item objective : MissionObjective;
        in item region : GeoBoundary;
        out item atlas : RoboticsGeographyAtlas;

        action receiveSurveyObjective;
        then action partitionRegionIntoDomainCells;
        then action allocateRobotsByGeographicDomain;
        then fork action executeAerialSurvey;
        then fork action executeTerrestrialSurvey;
        then fork action executeIndoorSurvey;
        then fork action executeAquaticSurvey;
        then join action aggregateGeoObservations;
        then action detectRoboticsSitesAndHazards;
        then action fuseMapTiles;
        then action verifyCoverageAndAccuracy;
        then action publishRoboticsGeographyAtlas;
    }

    state def SystemMissionLifecycle {
        state idle;
        state planning;
        state dispatching;
        state surveying;
        state analyzing;
        state publishing;
        state returningFleet;
        state completed;
        state degraded;
        state aborted;

        entry; then idle;

        transition startMission first idle then planning;
        transition planAccepted first planning then dispatching;
        transition fleetDispatched first dispatching then surveying;
        transition observationBatchReady first surveying then analyzing;
        transition moreCellsRequired first analyzing then surveying;
        transition atlasReady first analyzing then publishing;
        transition publishComplete first publishing then returningFleet;
        transition fleetRecovered first returningFleet then completed;
        transition resetForNextMission first completed then idle;
        transition linkOrRobotDegraded first surveying then degraded;
        transition continueWithReducedFleet first degraded then surveying;
        transition abortFromPlanning first planning then aborted;
        transition abortFromSurvey first surveying then aborted;
        transition abortFromDegraded first degraded then aborted;
        transition recoverAfterAbort first aborted then idle;
    }

    part def RoboticsGeographySystem {
        attribute systemName : String = "Robotics Geography Atlas System";
        attribute primaryFunction : String = "Produce, maintain, and publish a living geographic atlas that describes where robots can operate, where robotics assets and facilities exist, and what hazards or terrain constraints affect robotic missions across aerial, terrestrial, aquatic, and indoor domains.";
        attribute nominalMappedAreaPerMission : AreaValue;
        attribute targetHorizontalAccuracy : LengthValue;
        attribute targetCoverage : PercentValue;
        attribute maximumAtlasLatency : TimeValue;

        port operatorPort : MissionControlPort;
        port atlasPort : AtlasPublicationPort;
        port externalPower : PowerPort;

        part operatorConsole : OperatorConsole;
        part missionManager : MissionManager;
        part fleet : RobotFleet;
        part communicationsGateway : CommunicationsGateway;
        part dataStore : GeospatialDataStore;
        part analyticsEngine : GeographyAnalyticsEngine;
        part safetyMonitor : SafetyMonitor;
        part publicationService : AtlasPublicationService;

        perform action produceAtlas : ProduceRoboticsGeographyAtlas;
        exhibit state missionLifecycle : SystemMissionLifecycle;

        connection operatorCommandLink connect operatorPort to operatorConsole.missionControl;
        connection consoleToMissionManager connect operatorConsole.missionControl to missionManager.operatorInterface;
        connection missionManagerToFleet connect missionManager.fleetInterface to fleet.command;
        connection fleetObservationsToGateway connect fleet.observations to communicationsGateway.fleetBackhaul;
        connection gatewayToDataStore connect communicationsGateway.fleetBackhaul to dataStore.observationIn;
        connection gatewayToAnalytics connect communicationsGateway.fleetBackhaul to analyticsEngine.observationIn;
        connection gatewayToSafety connect communicationsGateway.fleetBackhaul to safetyMonitor.telemetryIn;
        connection safetyCommandsToFleet connect safetyMonitor.safetyCommandOut to fleet.command;
        connection analyticsToDataStore connect analyticsEngine.atlasOut to dataStore.atlasOut;
        connection dataStoreToPublication connect dataStore.atlasOut to publicationService.atlasIn;
        connection publicationToConsole connect publicationService.publicAtlasOut to operatorConsole.atlasConsumer;
        connection publicationToExternalAtlasPort connect publicationService.publicAtlasOut to atlasPort;
        connection externalPowerToGateway connect externalPower to communicationsGateway.power;
    }

    constraint def CoverageConstraint {
        in achievedCoverage : PercentValue;
        in requiredCoverage : PercentValue;
        constraint coverageSatisfied {
            achievedCoverage.magnitude >= requiredCoverage.magnitude
        }
    }

    constraint def HorizontalAccuracyConstraint {
        in achievedError : LengthValue;
        in maximumAllowedError : LengthValue;
        constraint accuracySatisfied {
            achievedError.magnitude <= maximumAllowedError.magnitude
        }
    }

    constraint def AtlasLatencyConstraint {
        in achievedLatency : TimeValue;
        in maximumAllowedLatency : TimeValue;
        constraint latencySatisfied {
            achievedLatency.magnitude <= maximumAllowedLatency.magnitude
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : RoboticsGeographySystem;
        attribute requiredFunction : String = "The system shall provide a high-level geographic understanding of robotics by mapping robot-operable domains, robotics sites, terrain constraints, and hazards into a publishable atlas.";
        require constraint {
            system.primaryFunction == "Produce, maintain, and publish a living geographic atlas that describes where robots can operate, where robotics assets and facilities exist, and what hazards or terrain constraints affect robotic missions across aerial, terrestrial, aquatic, and indoor domains."
        }
    }

    requirement def MultiDomainCoverageRequirement {
        subject atlas : RoboticsGeographyAtlas;
        attribute requiredCoverage : PercentValue;
        require constraint coverageRequirement : CoverageConstraint {
            in achievedCoverage = atlas.achievedCoverage;
            in requiredCoverage = requiredCoverage;
        }
    }

    requirement def MappingAccuracyRequirement {
        subject tile : MapTile;
        attribute maximumHorizontalError : LengthValue;
        require constraint accuracyRequirement : HorizontalAccuracyConstraint {
            in achievedError = tile.horizontalAccuracy;
            in maximumAllowedError = maximumHorizontalError;
        }
    }

    requirement def TimelyPublicationRequirement {
        subject system : RoboticsGeographySystem;
        attribute maximumPublicationLatency : TimeValue;
        require constraint {
            system.maximumAtlasLatency.magnitude <= maximumPublicationLatency.magnitude
        }
    }

    requirement def SafetyStandoffRequirement {
        subject plan : MissionPlan;
        attribute minimumStandoff : LengthValue;
        require constraint {
            plan.safetyStandoff.magnitude >= minimumStandoff.magnitude
        }
    }

    requirement def RobotHealthMonitoringRequirement {
        subject system : RoboticsGeographySystem;
        attribute minimumBatteryForReturn : PercentValue;
        require constraint {
            system.safetyMonitor.minimumBatteryForReturn.magnitude >= minimumBatteryForReturn.magnitude
        }
    }

    requirement def TraceableObservationRequirement {
        subject observation : GeoObservation;
        require constraint {
            observation.sourceRobotIdentifier != "" and observation.observationTimeUTC != ""
        }
    }

    part roboticsGeographySystem : RoboticsGeographySystem {
        attribute targetCoverage : PercentValue {
            :>> magnitude = 95.0;
            :>> unit = "%";
        }
        attribute targetHorizontalAccuracy : LengthValue {
            :>> magnitude = 1.5;
            :>> unit = "m";
        }
        attribute maximumAtlasLatency : TimeValue {
            :>> magnitude = 300.0;
            :>> unit = "s";
        }
        attribute nominalMappedAreaPerMission : AreaValue {
            :>> magnitude = 250000.0;
            :>> unit = "m^2";
        }
    }

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = roboticsGeographySystem;
    }

    requirement coverage95Percent : MultiDomainCoverageRequirement {
        attribute requiredCoverage : PercentValue {
            :>> magnitude = 95.0;
            :>> unit = "%";
        }
    }

    requirement horizontalAccuracy1_5m : MappingAccuracyRequirement {
        attribute maximumHorizontalError : LengthValue {
            :>> magnitude = 1.5;
            :>> unit = "m";
        }
    }

    requirement publishWithin5Minutes : TimelyPublicationRequirement {
        subject system = roboticsGeographySystem;
        attribute maximumPublicationLatency : TimeValue {
            :>> magnitude = 300.0;
            :>> unit = "s";
        }
    }

    requirement standoff2m : SafetyStandoffRequirement {
        attribute minimumStandoff : LengthValue {
            :>> magnitude = 2.0;
            :>> unit = "m";
        }
    }

    requirement batteryReserve20Percent : RobotHealthMonitoringRequirement {
        subject system = roboticsGeographySystem;
        attribute minimumBatteryForReturn : PercentValue {
            :>> magnitude = 20.0;
            :>> unit = "%";
        }
    }

    satisfy primaryFunction by roboticsGeographySystem;
    satisfy coverage95Percent by roboticsGeographySystem.analyticsEngine;
    satisfy horizontalAccuracy1_5m by roboticsGeographySystem.analyticsEngine;
    satisfy publishWithin5Minutes by roboticsGeographySystem.publicationService;
    satisfy standoff2m by roboticsGeographySystem.missionManager;
    satisfy batteryReserve20Percent by roboticsGeographySystem.safetyMonitor;
}
