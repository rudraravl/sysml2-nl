package CloudRoboticsSystem {

    import ScalarValues::*;

    // ═══════════════════════════════════════════════════════════
    // UNITS
    // ═══════════════════════════════════════════════════════════

    unit m;
    unit m_per_s;
    unit rad_per_s;
    unit deg;
    unit percent;
    unit Mbps;
    unit ms;
    unit dBm;
    unit s;
    unit degC;
    unit kg;

    // ═══════════════════════════════════════════════════════════
    // VALUE TYPES
    // ═══════════════════════════════════════════════════════════

    value type Distance :> Real {
        unit m;
    }

    value type Velocity :> Real {
        unit m_per_s;
    }

    value type AngularVelocity :> Real {
        unit rad_per_s;
    }

    value type Angle :> Real {
        unit deg;
    }

    value type BatteryLevel :> Real {
        min = 0;
        max = 100;
        unit percent;
    }

    value type DataRate :> Real {
        unit Mbps;
    }

    value type Latency :> Real {
        unit ms;
    }

    value type SignalStrength :> Real {
        unit dBm;
    }

    value type Timestamp :> Real {
        unit s;
    }

    value type Temperature :> Real {
        unit degC;
    }

    value type Mass :> Real {
        unit kg;
    }

    value type Confidence :> Real {
        min = 0.0;
        max = 1.0;
    }

    // ═══════════════════════════════════════════════════════════
    // ENUMERATIONS
    // ═══════════════════════════════════════════════════════════

    enum def CommandKind {
        moveTo;
        stop;
        turn;
        pickObject;
        placeObject;
        returnToBase;
        emergencyStop;
    }

    enum def TaskType {
        navigate;
        pick;
        place;
        patrol;
        scan;
        returnHome;
    }

    enum def ConnectionState {
        connected;
        degraded;
        disconnected;
    }

    // ═══════════════════════════════════════════════════════════
    // ITEM DEFINITIONS
    // ═══════════════════════════════════════════════════════════

    item def Pose {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute heading : Angle;
    }

    item def BoundingBox {
        attribute minX : Distance;
        attribute minY : Distance;
        attribute minZ : Distance;
        attribute maxX : Distance;
        attribute maxY : Distance;
        attribute maxZ : Distance;
    }

    item def ImageData {
        attribute width : Integer;
        attribute height : Integer;
        attribute channels : Integer;
        attribute frameId : Integer;
        attribute timestamp : Timestamp;
    }

    item def LidarPoint {
        attribute distance : Distance;
        attribute angle : Angle;
        attribute intensity : Real;
    }

    item def LidarScan {
        attribute points : LidarPoint[0..*];
        attribute scanId : Integer;
        attribute timestamp : Timestamp;
    }

    item def IMUReading {
        attribute linearAccelX : Real;
        attribute linearAccelY : Real;
        attribute linearAccelZ : Real;
        attribute angularVelX : AngularVelocity;
        attribute angularVelY : AngularVelocity;
        attribute angularVelZ : AngularVelocity;
        attribute timestamp : Timestamp;
    }

    item def SensorPacket {
        item image : ImageData;
        item lidar : LidarScan;
        item imu : IMUReading;
        attribute robotId : String;
        attribute timestamp : Timestamp;
    }

    item def TelemetryData {
        attribute robotId : String;
        attribute pose : Pose;
        attribute batteryLevel : BatteryLevel;
        attribute temperature : Temperature;
        attribute timestamp : Timestamp;
    }

    item def ObjectDetection {
        attribute objectClass : String;
        attribute boundingBox : BoundingBox;
        attribute confidence : Confidence;
        attribute timestamp : Timestamp;
    }

    item def PathWaypoint {
        attribute x : Distance;
        attribute y : Distance;
        attribute orientation : Angle;
    }

    item def PathPlan {
        attribute waypoints : PathWaypoint[0..*];
        attribute estimatedDuration : Real;
        attribute pathId : Integer;
        attribute timestamp : Timestamp;
    }

    item def NavigationCommand {
        attribute commandType : CommandKind;
        attribute targetPose : Pose;
        attribute pathPlan : PathPlan;
        attribute priority : Integer;
        attribute timestamp : Timestamp;
    }

    item def TaskAssignment {
        attribute taskId : String;
        attribute taskType : TaskType;
        attribute targetPose : Pose;
        attribute priority : Integer;
        attribute deadline : Timestamp;
    }

    item def MapUpdate {
        attribute mapId : String;
        attribute region : BoundingBox;
        attribute updateData : String;
        attribute timestamp : Timestamp;
    }

    item def ExperienceEntry {
        attribute robotId : String;
        attribute scenario : String;
        attribute outcome : String;
        attribute timestamp : Timestamp;
    }

    // ═══════════════════════════════════════════════════════════
    // PORT DEFINITIONS
    // ═══════════════════════════════════════════════════════════

    port def SensorDataOut {
        out sensorData : SensorPacket;
    }

    port def SensorDataIn {
        in sensorData : SensorPacket;
    }

    port def TelemetryDataOut {
        out telemetry : TelemetryData;
    }

    port def TelemetryDataIn {
        in telemetry : TelemetryData;
    }

    port def NavigationCommandOut {
        out command : NavigationCommand;
    }

    port def NavigationCommandIn {
        in command : NavigationCommand;
    }

    port def NetworkLink {
        in sensorData : SensorPacket;
        in telemetry : TelemetryData;
        out command : NavigationCommand;
        out mapUpdate : MapUpdate;
    }

    port def CloudService {
        in sensorData : SensorPacket;
        in telemetry : TelemetryData;
        out command : NavigationCommand;
        out mapUpdate : MapUpdate;
    }

    // ═══════════════════════════════════════════════════════════
    // MOBILE ROBOT SUB-PART DEFINITIONS
    // ═══════════════════════════════════════════════════════════

    part def Camera {
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute frameRate : Integer = 30;
        attribute isCalibrated : Boolean = true;
        port sensorOut : SensorDataOut;
        action captureImage {
            out image : ImageData;
        }
    }

    part def LiDAR {
        attribute maxRange : Distance = 100;
        attribute angularResolution : Angle = 0.5;
        attribute scanRate : Integer = 10;
        port sensorOut : SensorDataOut;
        action performScan {
            out scan : LidarScan;
        }
    }

    part def IMU {
        attribute updateRate : Integer = 100;
        attribute noiseDensity : Real = 0.01;
        port sensorOut : SensorDataOut;
        action readSensor {
            out reading : IMUReading;
        }
    }

    part def WheelAssembly {
        attribute wheelCount : Integer = 2;
        attribute maxSpeed : Velocity = 2.0;
        attribute maxTurnRate : AngularVelocity = 1.5;
        port commandIn : NavigationCommandIn;
        action drive {
            in linearVelocity : Velocity;
            in angularVelocity : AngularVelocity;
        }
        action brake {}
        action emergencyStop {}
    }

    part def ManipulatorArm {
        attribute jointCount : Integer = 6;
        attribute payloadCapacity : Mass = 5.0;
        attribute reach : Distance = 0.8;
        port commandIn : NavigationCommandIn;
        action grasp {
            in targetPose : Pose;
        }
        action release {
            in targetPose : Pose;
        }
        action moveToJointPositions {
            in positions : Real[0..*];
        }
        action home {}
    }

    part def OnboardProcessor {
        attribute clockSpeed : Integer = 1000;
        attribute memorySize : Integer = 4096;
        attribute isAutonomyModeActive : Boolean = false;
        port sensorIn : SensorDataIn;
        port telemetryIn : TelemetryDataIn;
        port uplinkOut : SensorDataOut;
        port commandIn : NavigationCommandIn;
        port actuatorCommandOut : NavigationCommandOut;
        action preprocessSensorData {
            in rawSensorData : SensorPacket;
            out processedData : SensorPacket;
        }
        action packageTelemetry {
            in sensorData : SensorPacket;
            in telemetry : TelemetryData;
            out combinedPacket : SensorPacket;
        }
        action localAutonomyControl {
            in sensorData : SensorPacket;
            out safetyCommand : NavigationCommand;
        }
        action executeBasicSafetyBehavior {
            out command : NavigationCommand;
        }
        action parseCloudCommand {
            in command : NavigationCommand;
            out actuatorCommand : NavigationCommand;
        }
        action checkConnectionStatus {
            out status : ConnectionState;
        }
    }

    part def PowerManagement {
        attribute currentBatteryLevel : BatteryLevel = 100;
        attribute batteryCapacity : Real = 5000;
        attribute lowPowerThreshold : BatteryLevel = 20;
        attribute criticalPowerThreshold : BatteryLevel = 10;
        port telemetryOut : TelemetryDataOut;
        action monitorBattery {
            out batteryLevel : BatteryLevel;
        }
        action triggerLowPowerAlert {}
        action managePowerStates {
            in batteryLevel : BatteryLevel;
        }
        action estimateRemainingTime {
            in batteryLevel : BatteryLevel;
            out remainingMinutes : Real;
        }
    }

    part def WirelessTransceiver {
        attribute supportedProtocols : String = "5G, WiFi";
        attribute maxDataRate : DataRate = 1000;
        attribute currentLatency : Latency = 10;
        attribute isConnected : Boolean = true;
        attribute signalStrength : SignalStrength = -50;
        port dataIn : SensorDataIn;
        port commandOut : NavigationCommandOut;
        port networkInterface : NetworkLink;
        action transmitData {
            in sensorData : SensorPacket;
            in telemetry : TelemetryData;
        }
        action receiveCommand {
            out command : NavigationCommand;
        }
        action checkConnection {
            out status : Boolean;
            out latency : Latency;
        }
        action establishConnection {}
        action reconnect {
            out status : Boolean;
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MOBILE ROBOT DEFINITION WITH STATE MACHINE
    // ═══════════════════════════════════════════════════════════

    part def MobileRobot {
        attribute robotId : String;
        attribute currentPose : Pose;
        attribute connectionState : ConnectionState = connected;

        part camera : Camera;
        part lidar : LiDAR;
        part imu : IMU;
        part wheels : WheelAssembly;
        part arm : ManipulatorArm;
        part processor : OnboardProcessor;
        part power : PowerManagement;
        part transceiver : WirelessTransceiver;

        port cloudLink : NetworkLink;
        port telemetryPort : TelemetryDataOut;

        connection cameraToProcessor {
            camera.sensorOut -> processor.sensorIn;
        }
        connection lidarToProcessor {
            lidar.sensorOut -> processor.sensorIn;
        }
        connection imuToProcessor {
            imu.sensorOut -> processor.sensorIn;
        }
        connection powerToProcessor {
            power.telemetryOut -> processor.telemetryIn;
        }
        connection powerToTelemetry {
            power.telemetryOut -> telemetryPort;
        }
        connection processorToTransceiver {
            processor.uplinkOut -> transceiver.dataIn;
        }
        connection transceiverToProcessor {
            transceiver.commandOut -> processor.commandIn;
        }
        connection processorToWheels {
            processor.actuatorCommandOut -> wheels.commandIn;
        }
        connection processorToArm {
            processor.actuatorCommandOut -> arm.commandIn;
        }
        connection transceiverToCloudLink {
            transceiver.networkInterface <-> cloudLink;
        }

        state machine RobotStates {
            state idle {
                entry {
                    processor.isAutonomyModeActive = false;
                }
            }

            state sensing {
                entry {
                    camera.captureImage;
                    lidar.performScan;
                    imu.readSensor;
                }
                do {
                    processor.preprocessSensorData;
                    power.monitorBattery;
                }
                exit {
                    processor.packageTelemetry;
                }
            }

            state transmitting {
                entry {
                    transceiver.transmitData;
                }
                do {
                    transceiver.checkConnection;
                }
                exit {
                    transceiver.receiveCommand;
                }
            }

            state executing {
                entry {
                    processor.parseCloudCommand;
                }
                do {
                    wheels.drive;
                    arm.grasp;
                }
                exit {
                    power.monitorBattery;
                }
            }

            state localAutonomy {
                entry {
                    processor.isAutonomyModeActive = true;
                    processor.localAutonomyControl;
                }
                do {
                    processor.executeBasicSafetyBehavior;
                    wheels.emergencyStop;
                    power.monitorBattery;
                    transceiver.reconnect;
                }
                exit {
                    processor.isAutonomyModeActive = false;
                }
            }

            transition from idle to sensing
                when startMission;

            transition from sensing to transmitting
                when sensorDataReady;

            transition from transmitting to executing
                when cloudCommandReceived;

            transition from executing to sensing
                when executionComplete;

            transition from transmitting to localAutonomy
                when connectionLost;

            transition from executing to localAutonomy
                when connectionLost;

            transition from sensing to localAutonomy
                when connectionLost;

            transition from localAutonomy to sensing
                when connectionRestored;

            transition from executing to idle
                when missionComplete;

            transition from localAutonomy to idle
                when safetyAchieved;
        }
    }

    // ═══════════════════════════════════════════════════════════
    // CLOUD COMPUTE PLATFORM SUB-PART DEFINITIONS
    // ═══════════════════════════════════════════════════════════

    part def AIProcessorCluster {
        attribute processorCount : Integer = 64;
        attribute gpuCount : Integer = 16;
        attribute totalMemory : Integer = 1048576;
        attribute utilization : Real = 0.0;
        action allocateResources {
            in taskCount : Integer;
            out allocationStatus : Boolean;
        }
        action scaleCompute {
            in demand : Real;
            out allocatedCompute : Real;
        }
    }

    part def ObjectDetector {
        attribute modelVersion : String = "v2.5";
        attribute supportedClasses : String = "person, vehicle, obstacle, package, door, furniture";
        attribute detectionThreshold : Confidence = 0.85;
        action detectObjects {
            in image : ImageData;
            out detections : ObjectDetection[0..*];
        }
        action batchDetect {
            in images : ImageData[0..*];
            out allDetections : ObjectDetection[0..*];
        }
        action classifyObject {
            in detection : ObjectDetection;
            out refinedClass : String;
        }
    }

    part def PathPlanner {
        attribute algorithm : String = "A_star";
        attribute mapResolution : Distance = 0.1;
        attribute maxPlanningTime : Latency = 50;
        action planPath {
            in startPose : Pose;
            in goalPose : Pose;
            in detectedObjects : ObjectDetection[0..*];
            out pathPlan : PathPlan;
        }
        action optimizePath {
            in pathPlan : PathPlan;
            out optimizedPath : PathPlan;
        }
        action replanAroundObstacle {
            in currentPose : Pose;
            in obstacle : ObjectDetection;
            out newPath : PathPlan;
        }
    }

    part def LearningModule {
        attribute modelType : String = "deep_reinforcement_learning";
        attribute trainingIterations : Integer = 0;
        attribute learningRate : Real = 0.001;
        action updateModels {
            in experienceData : ExperienceEntry[0..*];
            out modelUpdateStatus : Boolean;
        }
        action fineTuneObjectDetector {
            in labeledData : ImageData[0..*];
        }
        action collectExperience {
            in telemetry : TelemetryData;
            in sensorData : SensorPacket;
            out experience : ExperienceEntry;
        }
    }

    part def KnowledgeDatabase {
        attribute totalMaps : Integer = 0;
        attribute totalExperiences : Integer = 0;
        attribute storageCapacity : Integer = 1000000;
        action storeMap {
            in mapUpdate : MapUpdate;
        }
        action retrieveMap {
            in region : BoundingBox;
            out mapData : String;
        }
        action storeExperience {
            in experience : ExperienceEntry;
        }
        action shareMapAcrossFleet {
            in mapUpdate : MapUpdate;
            out fleetUpdate : MapUpdate;
        }
        action queryHistoricalData {
            in region : BoundingBox;
            out historicalDetections : ObjectDetection[0..*];
        }
    }

    part def TaskOrchestrator {
        attribute activeRobots : Integer = 0;
        attribute taskQueueSize : Integer = 0;
        attribute maxConcurrentTasks : Integer = 200;
        action assignTask {
            in robotId : String;
            in task : TaskAssignment;
            out assignment : TaskAssignment;
        }
        action prioritizeTasks {
            in tasks : TaskAssignment[0..*];
            out prioritized : TaskAssignment[0..*];
        }
        action monitorFleet {
            in telemetry : TelemetryData[0..*];
        }
        action rebalanceLoad {
            in fleetTelemetry : TelemetryData[0..*];
            out reassignedTasks : TaskAssignment[0..*];
        }
        action cancelTask {
            in taskId : String;
        }
    }

    // ═══════════════════════════════════════════════════════════
    // CLOUD COMPUTE PLATFORM DEFINITION
    // ═══════════════════════════════════════════════════════════

    part def CloudComputePlatform {
        attribute platformId : String;
        attribute maxConnectedRobots : Integer = 100;
        attribute currentlyConnectedRobots : Integer = 0;
        attribute uptime : Timestamp = 0;

        part aiCluster : AIProcessorCluster;
        part objectDetector : ObjectDetector;
        part pathPlanner : PathPlanner;
        part learningModule : LearningModule;
        part knowledgeDB : KnowledgeDatabase;
        part orchestrator : TaskOrchestrator;

        port servicePort : CloudService;

        connection sensorDataToDetector {
            servicePort.sensorData -> objectDetector;
        }
        connection detectorToPlanner {
            objectDetector -> pathPlanner;
        }
        connection knowledgeToPlanner {
            knowledgeDB -> pathPlanner;
        }
        connection plannerToServicePort {
            pathPlanner -> servicePort;
        }
        connection telemetryToOrchestrator {
            servicePort.telemetry -> orchestrator;
        }
        connection orchestratorToPlanner {
            orchestrator -> pathPlanner;
        }
        connection orchestratorToServicePort {
            orchestrator -> servicePort;
        }
        connection learningToKnowledge {
            learningModule -> knowledgeDB;
        }
        connection clusterToDetector {
            aiCluster -> objectDetector;
        }
        connection clusterToPlanner {
            aiCluster -> pathPlanner;
        }
        connection clusterToLearning {
            aiCluster -> learningModule;
        }

        action processSensorData {
            in sensorData : SensorPacket;
            out command : NavigationCommand;
        }

        action handleTelemetry {
            in telemetry : TelemetryData;
        }

        action updateLearningModels {
            in experiences : ExperienceEntry[0..*];
        }

        action shareFleetKnowledge {
            in mapUpdate : MapUpdate;
            out fleetUpdate : MapUpdate;
        }

        action manageFleet {
            in allTelemetry : TelemetryData[0..*];
            out assignments : TaskAssignment[0..*];
        }
    }

    // ═══════════════════════════════════════════════════════════
    // NETWORK INFRASTRUCTURE SUB-PART DEFINITIONS
    // ═══════════════════════════════════════════════════════════

    part def BaseStation {
        attribute stationId : String;
        attribute coverageRadius : Distance = 500;
        attribute maxConnections : Integer = 1000;
        attribute supportedStandard : String = "5G";
        attribute currentConnections : Integer = 0;
        port robotInterface : NetworkLink;
        port backbone : NetworkLink;
        action acceptConnection {
            in robotId : String;
            out connectionStatus : Boolean;
        }
        action relayData {
            in data : SensorPacket;
            out forwarded : SensorPacket;
        }
        action broadcastMap {
            in mapUpdate : MapUpdate;
        }
    }

    part def NetworkRouter {
        attribute routingTableEntries : Integer = 0;
        attribute maxThroughput : DataRate = 10000;
        attribute currentThroughput : DataRate = 0;
        port accessSide : NetworkLink;
        port coreSide : CloudService;
        action routeDataToCloud {
            in sensorData : SensorPacket;
            in telemetry : TelemetryData;
            out routedSensorData : SensorPacket;
            out routedTelemetry : TelemetryData;
        }
        action routeCommandToRobot {
            in command : NavigationCommand;
            in robotId : String;
            out routedCommand : NavigationCommand;
        }
        action updateRoutingTable {
            in robotId : String;
            in baseStationId : String;
        }
        action measureLatency {
            out latency : Latency;
        }
    }

    // ═══════════════════════════════════════════════════════════
    // NETWORK INFRASTRUCTURE DEFINITION
    // ═══════════════════════════════════════════════════════════

    part def NetworkInfrastructure {
        attribute networkType : String = "5G";
        attribute bandwidth : DataRate = 10000;
        attribute targetLatency : Latency = 5;
        attribute maxConnections : Integer = 1000;
        attribute isActive : Boolean = true;

        part baseStations : BaseStation[1..*];
        part coreRouter : NetworkRouter;

        port robotAccess : NetworkLink;
        port cloudAccess : CloudService;

        connection baseStationToRobotAccess {
            baseStations.robotInterface <-> robotAccess;
        }
        connection baseStationToRouter {
            baseStations.backbone -> coreRouter.accessSide;
        }
        connection routerToCloudAccess {
            coreRouter.coreSide <-> cloudAccess;
        }

        action routeDataToCloud {
            in sensorData : SensorPacket;
            in telemetry : TelemetryData;
            out routedSensorData : SensorPacket;
            out routedTelemetry : TelemetryData;
        }

        action routeCommandToRobot {
            in command : NavigationCommand;
            in robotId : String;
            out routedCommand : NavigationCommand;
        }

        action checkConnectionHealth {
            out status : Boolean;
            out latency : Latency;
        }

        action handleFailover {
            in failedComponentId : String;
            out recoveryStatus : Boolean;
        }

        action scaleCapacity {
            in expectedConnections : Integer;
            out allocatedBandwidth : DataRate;
        }
    }

    // ═══════════════════════════════════════════════════════════
    // CLOUD ROBOTICS SYSTEM DEFINITION
    // ═══════════════════════════════════════════════════════════

    part def CloudRoboticsSystem {
        attribute systemId : String;
        attribute fleetSize : Integer = 0;
        attribute systemStatus : String = "operational";

        part robots : MobileRobot[1..*];
        part cloud : CloudComputePlatform;
        part network : NetworkInfrastructure;

        connection robotToNetwork {
            robots.cloudLink <-> network.robotAccess;
        }

        connection networkToCloud {
            network.cloudAccess <-> cloud.servicePort;
        }

        action deployFleet {
            in robotCount : Integer;
        }

        action monitorSystemHealth {
            out systemStatus : Boolean;
        }

        action handleSystemFailover {
            in failedComponentId : String;
        }

        action registerRobot {
            in robotId : String;
            out registrationStatus : Boolean;
        }

        action deregisterRobot {
            in robotId : String;
        }

        action performFullCycle {
            in sensorData : SensorPacket;
            in telemetry : TelemetryData;
            out command : NavigationCommand;
        }
    }

    // ═══════════════════════════════════════════════════════════
    // REQUIREMENTS
    // ═══════════════════════════════════════════════════════════

    requirement def CloudRoboticsReq {
        doc "The cloud robotics system shall pair mobile robots with a centralized cloud computing platform.";
    }

    requirement def ComplexTaskSupportReq {
        doc "The system shall enable robots to perform highly complex tasks including advanced navigation and object manipulation.";
    }

    requirement def CloudOffloadReq {
        doc "The system shall offload heavy computational work to the cloud platform.";
    }

    requirement def ThreePartArchitectureReq {
        doc "The system shall consist of three main parts: Mobile Robot, Cloud Compute Platform, and Network Infrastructure.";
    }

    requirement def SensorSuiteReq {
        doc "The mobile robot shall be equipped with a camera, LiDAR, and IMU for environment perception.";
    }

    requirement def ActuationCapabilityReq {
        doc "The mobile robot shall have wheels for movement and a manipulator arm for physical interaction.";
    }

    requirement def OnboardProcessingReq {
        doc "The mobile robot shall include a small onboard processor for essential functions and basic data handling.";
    }

    requirement def CloudDependenceReq {
        doc "The mobile robot shall rely on the cloud for complex computational tasks.";
    }

    requirement def PowerManagementReq {
        doc "The mobile robot shall include a power management system to monitor battery level.";
    }

    requirement def WirelessCommunicationReq {
        doc "The mobile robot shall include a wireless transceiver for cloud communication.";
    }

    requirement def CloudBrainReq {
        doc "The cloud compute platform shall act as a shared brain for one or more robots.";
    }

    requirement def DataReceptionReq {
        doc "The cloud shall receive streams of sensor data and telemetry from connected robots.";
    }

    requirement def AIProcessingReq {
        doc "The cloud shall contain a cluster of AI processors for analyzing robot data.";
    }

    requirement def ObjectDetectionReq {
        doc "The cloud shall include a module for detecting objects in camera images.";
    }

    requirement def PathPlanningReq {
        doc "The cloud shall include a planning engine for generating optimal travel paths.";
    }

    requirement def LearningModuleReq {
        doc "The cloud shall include a learning module for continuously updating AI models.";
    }

    requirement def KnowledgeDBReq {
        doc "The cloud shall maintain a large knowledge database for fleet-wide map and experience sharing.";
    }

    requirement def TaskOrchestrationReq {
        doc "The cloud shall include a task orchestrator to manage and prioritize jobs for all connected robots.";
    }

    requirement def NetworkConnectivityReq {
        doc "The network infrastructure shall provide a high-bandwidth, low-latency link between robots and cloud.";
    }

    requirement def BidirectionalFlowReq {
        doc "The network shall facilitate constant two-way flow of information between robots and cloud.";
    }

    requirement def OperationFlowReq {
        doc "The robot shall continuously capture environmental data, send it to the cloud, receive commands, and execute them.";
    }

    requirement def ResilienceReq {
        doc "The robot shall be resilient and capable of operating in various states.";
    }

    requirement def LocalAutonomyReq {
        doc "Upon loss of cloud connection, the robot shall switch to local autonomy mode with pre-programmed safety behaviors.";
    }

    requirement def ConnectionRecoveryReq {
        doc "The robot shall exit local autonomy mode and resume cloud-dependent operation upon connection restoration.";
    }

    requirement def LatencyReq {
        doc "The network round-trip latency shall not exceed 20 ms under normal operating conditions.";
        attribute maxLatency : Latency = 20;
    }

    requirement def DataRateReq {
        doc "The network shall support a minimum uplink data rate of 500 Mbps per robot.";
        attribute minDataRate : DataRate = 500;
    }

    requirement def BatteryLifeReq {
        doc "The mobile robot shall maintain a battery level above 10 percent during normal operation.";
        attribute minBatteryLevel : BatteryLevel = 10;
    }

    requirement def FleetSharingReq {
        doc "The knowledge database shall enable all connected robots to share maps and experiences across the fleet.";
    }

    requirement def SafetyReq {
        doc "During local autonomy mode, the robot shall execute only pre-programmed safety behaviors.";
    }

    // ═══════════════════════════════════════════════════════════
    // SATISFACTION RELATIONSHIPS
    // ═══════════════════════════════════════════════════════════

    satisfy CloudRoboticsReq by CloudRoboticsSystem;
    satisfy ComplexTaskSupportReq by CloudRoboticsSystem;
    satisfy CloudOffloadReq by CloudComputePlatform;
    satisfy ThreePartArchitectureReq by CloudRoboticsSystem;
    satisfy SensorSuiteReq by MobileRobot;
    satisfy ActuationCapabilityReq by MobileRobot;
    satisfy OnboardProcessingReq by OnboardProcessor;
    satisfy CloudDependenceReq by MobileRobot;
    satisfy PowerManagementReq by PowerManagement;
    satisfy WirelessCommunicationReq by WirelessTransceiver;
    satisfy CloudBrainReq by CloudComputePlatform;
    satisfy DataReceptionReq by CloudComputePlatform;
    satisfy AIProcessingReq by AIProcessorCluster;
    satisfy ObjectDetectionReq by ObjectDetector;
    satisfy PathPlanningReq by PathPlanner;
    satisfy LearningModuleReq by LearningModule;
    satisfy KnowledgeDBReq by KnowledgeDatabase;
    satisfy TaskOrchestrationReq by TaskOrchestrator;
    satisfy NetworkConnectivityReq by NetworkInfrastructure;
    satisfy BidirectionalFlowReq by NetworkInfrastructure;
    satisfy OperationFlowReq by MobileRobot;
    satisfy ResilienceReq by MobileRobot;
    satisfy LocalAutonomyReq by MobileRobot;
    satisfy ConnectionRecoveryReq by MobileRobot;
    satisfy LatencyReq by NetworkInfrastructure;
    satisfy DataRateReq by NetworkInfrastructure;
    satisfy BatteryLifeReq by PowerManagement;
    satisfy FleetSharingReq by KnowledgeDatabase;
    satisfy SafetyReq by OnboardProcessor;
}
