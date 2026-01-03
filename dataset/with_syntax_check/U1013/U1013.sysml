package CloudRoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NetworkLatency :> TimeValue {
        doc /* Round-trip communication delay between robot and cloud */
    }
    
    attribute def ComputationalLoad :> Real {
        doc /* Processing demand measured in GFLOPS */
    }
    
    attribute def BatteryCharge :> Real {
        doc /* Battery state of charge as percentage */
    }
    
    item def SensorDataPacket {
        attribute timestamp : TimeValue;
        attribute cameraImage : String;
        attribute lidarPoints : String;
        attribute imuReading : String;
        attribute dataSize : MassValue;
    }
    
    item def TaskCommand {
        attribute taskType : String;
        attribute targetLocation : String;
        attribute priority : Integer;
    }
    
    item def ProcessedIntelligence {
        attribute objectDetections : String[*];
        attribute pathPlan : String;
        attribute decisionConfidence : Real;
        attribute computeTime : TimeValue;
    }
    
    item def RobotTelemetry {
        attribute position : String;
        attribute velocity : SpeedValue;
        attribute batteryLevel : BatteryCharge;
        attribute systemHealth : String;
    }
    
    port def SensorOutputPort {
        out sensorData : SensorDataPacket;
    }
    
    port def ActuatorInputPort {
        in controlCommand : TaskCommand;
    }
    
    port def RobotNetworkPort {
        out uplinkData : SensorDataPacket;
        out telemetry : RobotTelemetry;
        in downlinkCommand : TaskCommand;
        in intelligence : ProcessedIntelligence;
    }
    
    port def CloudNetworkPort {
        in uplinkData : SensorDataPacket;
        in telemetry : RobotTelemetry;
        out downlinkCommand : TaskCommand;
        out intelligence : ProcessedIntelligence;
    }
    
    part def MobileRobot {
        attribute robotID : String;
        attribute localComputeCapacity : ComputationalLoad;
        attribute currentBattery : BatteryCharge;
        
        port sensorPort : SensorOutputPort;
        port actuatorPort : ActuatorInputPort;
        port networkPort : RobotNetworkPort;
        
        part perceptionSensors {
            part camera {
                attribute resolution : String;
                perform action captureImage;
            }
            part lidar {
                attribute scanRate : Real;
                perform action scanEnvironment;
            }
            part imu {
                attribute updateRate : Real;
                perform action measureMotion;
            }
        }
        
        part onboardProcessor {
            attribute processingPower : ComputationalLoad;
            perform action preprocessSensorData;
            perform action executeLocalControl;
        }
        
        part mobilityActuators {
            part wheels {
                attribute maxSpeed : SpeedValue;
                perform action driveMotion;
            }
            part manipulator {
                attribute degreesOfFreedom : Integer;
                perform action executeManipulation;
            }
        }
        
        part wirelessTransceiver {
            attribute bandwidth : Real;
            attribute signalStrength : Real;
            perform action transmitData;
            perform action receiveCommands;
        }
        
        part powerManagement {
            attribute batteryCapacity : EnergyValue;
            perform action monitorPower;
            perform action optimizeConsumption;
        }
    }
    
    part def CloudComputePlatform {
        attribute platformID : String;
        attribute totalComputeCapacity : ComputationalLoad;
        attribute activeRobots : Integer;
        
        port networkPort : CloudNetworkPort;
        
        part dataIngestion {
            attribute bufferSize : MassValue;
            perform action receiveSensorStreams;
            perform action validateData;
        }
        
        part aiProcessingCluster {
            part visionProcessor {
                attribute modelVersion : String;
                perform action detectObjects;
                perform action recognizeScenes;
            }
            part planningEngine {
                attribute algorithmType : String;
                perform action computeOptimalPath;
                perform action generateTaskSequence;
            }
            part learningModule {
                attribute trainingDataSize : MassValue;
                perform action updateModels;
                perform action adaptBehavior;
            }
        }
        
        part knowledgeDatabase {
            attribute storageCapacity : MassValue;
            attribute mapData : String;
            perform action storeExperience;
            perform action queryKnowledge;
        }
        
        part taskOrchestrator {
            attribute queueDepth : Integer;
            perform action prioritizeTasks;
            perform action allocateResources;
            perform action coordinateFleet;
        }
        
        part communicationGateway {
            attribute connectedDevices : Integer;
            perform action manageConnections;
            perform action routeMessages;
        }
    }
    
    part def NetworkInfrastructure {
        attribute networkType : String;
        attribute coverageArea : LengthValue;
        attribute averageLatency : NetworkLatency;
        
        part baseStation {
            attribute transmitPower : PowerValue;
            perform action relaySignals;
        }
        
        part edgeNode {
            attribute cacheCapacity : MassValue;
            perform action cacheFrequentData;
            perform action reduceLatency;
        }
    }
    
    action def CaptureSensorData {
        out rawSensorData : SensorDataPacket;
    }
    
    action def PreprocessLocally {
        in rawData : SensorDataPacket;
        in localCapacity : ComputationalLoad;
        out preprocessedData : SensorDataPacket;
    }
    
    action def TransmitToCloud {
        in data : SensorDataPacket;
        in telemetry : RobotTelemetry;
        out uploadedData : SensorDataPacket;
        out uploadedTelemetry : RobotTelemetry;
    }
    
    action def ProcessInCloud {
        in sensorData : SensorDataPacket;
        in computeCapacity : ComputationalLoad;
        out intelligence : ProcessedIntelligence;
    }
    
    action def GenerateTaskCommand {
        in intelligence : ProcessedIntelligence;
        in robotState : RobotTelemetry;
        out command : TaskCommand;
    }
    
    action def TransmitToRobot {
        in command : TaskCommand;
        in intelligence : ProcessedIntelligence;
        out deliveredCommand : TaskCommand;
        out deliveredIntelligence : ProcessedIntelligence;
    }
    
    action def ExecuteTask {
        in command : TaskCommand;
        in intelligence : ProcessedIntelligence;
        out executionStatus : String;
    }
    
    action def CloudRoboticsOperationalCycle {
        first start;
        then merge continuousOperation;
        
        action captureSensors : CaptureSensorData {
            out rawSensorData : SensorDataPacket;
        }
        
        then action preprocessData : PreprocessLocally {
            in rawData = captureSensors.rawSensorData;
            in localCapacity;
            out preprocessedData : SensorDataPacket;
        }
        
        then action uploadData : TransmitToCloud {
            in data = preprocessData.preprocessedData;
            in telemetry;
            out uploadedData : SensorDataPacket;
            out uploadedTelemetry : RobotTelemetry;
        }
        
        then action cloudProcessing : ProcessInCloud {
            in sensorData = uploadData.uploadedData;
            in computeCapacity;
            out intelligence : ProcessedIntelligence;
        }
        
        then action generateCommand : GenerateTaskCommand {
            in intelligence = cloudProcessing.intelligence;
            in robotState = uploadData.uploadedTelemetry;
            out command : TaskCommand;
        }
        
        then action downloadCommand : TransmitToRobot {
            in command = generateCommand.command;
            in intelligence = cloudProcessing.intelligence;
            out deliveredCommand : TaskCommand;
            out deliveredIntelligence : ProcessedIntelligence;
        }
        
        then action executeTask : ExecuteTask {
            in command = downloadCommand.deliveredCommand;
            in intelligence = downloadCommand.deliveredIntelligence;
            out executionStatus : String;
        }
        
        then decide;
            if executeTask.executionStatus == "continue" then continuousOperation;
            if executeTask.executionStatus == "complete" then done;
    }
    
    attribute def TaskAssignmentSignal;
    attribute def SensorReadySignal;
    attribute def UploadCompleteSignal;
    attribute def IntelligenceReceivedSignal;
    attribute def TaskCompletedSignal;
    attribute def CloudConnectionLostSignal;
    attribute def CloudConnectionRestoredSignal;
    
    state def RobotOperationalStates {
        entry action initializeRobot;
        exit action shutdownRobot;
        
        state Idle {
            entry action enterLowPowerMode;
        }
        
        state Sensing {
            entry action activateAllSensors;
            do action continuousSensorCapture;
        }
        
        state Transmitting {
            entry action establishCloudConnection;
            do action streamSensorData;
        }
        
        state AwaitingIntelligence {
            entry action listenForCloudResponse;
        }
        
        state Executing {
            entry action parseIncomingCommand;
            do action performTaskActions;
        }
        
        state LocalAutonomy {
            entry action switchToLocalControl;
            do action executeBasicBehaviors;
        }
        
        transition idleToSensing
            first Idle
            accept taskAssignment : TaskAssignmentSignal
            then Sensing;
        
        transition sensingToTransmitting
            first Sensing
            accept sensorDataReady : SensorReadySignal
            then Transmitting;
        
        transition transmittingToAwaiting
            first Transmitting
            accept uploadComplete : UploadCompleteSignal
            then AwaitingIntelligence;
        
        transition awaitingToExecuting
            first AwaitingIntelligence
            accept intelligenceReceived : IntelligenceReceivedSignal
            then Executing;
        
        transition executingToIdle
            first Executing
            accept taskCompleted : TaskCompletedSignal
            then Idle;
        
        transition awaitingToLocalAutonomy
            first AwaitingIntelligence
            accept cloudConnectionLost : CloudConnectionLostSignal
            then LocalAutonomy;
        
        transition localAutonomyToAwaiting
            first LocalAutonomy
            accept cloudConnectionRestored : CloudConnectionRestoredSignal
            then AwaitingIntelligence;
    }
    
    attribute def DataStreamInitiatedSignal;
    attribute def DataPacketCompleteSignal;
    attribute def InferenceCompleteSignal;
    attribute def CommandsReadySignal;
    attribute def TransmissionCompleteSignal;
    
    state def CloudOperationalStates {
        entry action initializeCloudServices;
        
        state Ready {
            entry action prepareResources;
        }
        
        state ReceivingData {
            entry action openDataChannels;
            do action ingestSensorStreams;
        }
        
        state Processing {
            entry action allocateComputeResources;
            do action runAIInference;
        }
        
        state GeneratingCommands {
            entry action synthesizeDecisions;
            do action createTaskCommands;
        }
        
        state TransmittingResults {
            entry action packageResults;
            do action sendToRobots;
        }
        
        transition readyToReceiving
            first Ready
            accept dataStreamInitiated : DataStreamInitiatedSignal
            then ReceivingData;
        
        transition receivingToProcessing
            first ReceivingData
            accept dataPacketComplete : DataPacketCompleteSignal
            then Processing;
        
        transition processingToGenerating
            first Processing
            accept inferenceComplete : InferenceCompleteSignal
            then GeneratingCommands;
        
        transition generatingToTransmitting
            first GeneratingCommands
            accept commandsReady : CommandsReadySignal
            then TransmittingResults;
        
        transition transmittingToReady
            first TransmittingResults
            accept transmissionComplete : TransmissionCompleteSignal
            then Ready;
    }
    
    requirement def CloudRoboticsRequirements {
        doc /* System-level requirements for cloud robotics operation */
        
        requirement <'CR-REQ-001'> primaryFunctionRequirement {
            doc /* The system shall enable mobile robots to offload computationally intensive perception, planning, and learning tasks to cloud infrastructure while maintaining real-time responsiveness for mission-critical operations. */
        }
        
        requirement <'CR-REQ-002'> latencyRequirement {
            doc /* End-to-end latency from sensor capture to command execution shall not exceed 200 milliseconds for time-critical tasks. */
            subject robot : MobileRobot;
            require constraint {
                robot.networkPort.intelligence.computeTime < 0.2[s]
            }
        }
        
        requirement <'CR-REQ-003'> bandwidthRequirement {
            doc /* Network bandwidth shall support continuous streaming of sensor data at minimum 50 Mbps uplink and 10 Mbps downlink. */
            subject network : NetworkInfrastructure;
        }
        
        requirement <'CR-REQ-004'> computeOffloadRequirement {
            doc /* The system shall offload at least 80% of AI processing tasks to cloud when network connectivity is available. */
        }
        
        requirement <'CR-REQ-005'> autonomyRequirement {
            doc /* Robots shall maintain basic autonomous operation for minimum 60 seconds during cloud connectivity loss. */
            subject robot : MobileRobot;
        }
        
        requirement <'CR-REQ-006'> scalabilityRequirement {
            doc /* Cloud platform shall support simultaneous operation of at least 100 robots with degradation less than 10% in processing time. */
            subject cloud : CloudComputePlatform;
        }
        
        requirement <'CR-REQ-007'> energyEfficiencyRequirement {
            doc /* Offloading computation to cloud shall reduce robot onboard energy consumption by minimum 40% compared to local processing. */
            subject robot : MobileRobot;
        }
        
        requirement <'CR-REQ-008'> dataSecurityRequirement {
            doc /* All data transmitted between robots and cloud shall be encrypted using AES-256 standard. */
            subject network : NetworkInfrastructure;
        }
    }
    
    part def CloudRoboticsSystemDef {
        doc /* 
            Cloud Robotics System integrating mobile robots with cloud computing infrastructure.
            
            Primary Function: Enable resource-constrained mobile robots to perform complex tasks 
            requiring intensive computation (computer vision, path planning, machine learning) by 
            offloading processing to powerful cloud servers. The system maintains a continuous 
            bidirectional data flow where robots stream sensor data to the cloud for analysis, 
            and receive back high-level intelligence and task commands. This architecture allows 
            robots to benefit from virtually unlimited computational resources, shared knowledge 
            bases, and continuous learning while preserving local autonomy for safety-critical 
            real-time control.
        */
        
        attribute systemID : String;
        
        part robot : MobileRobot {
            :>> robotID = "ROBOT-ALPHA-01";
            :>> localComputeCapacity = 50.0;
            :>> currentBattery = 0.85;
        }
        
        part cloud : CloudComputePlatform {
            :>> platformID = "CLOUD-MAIN-DC1";
            :>> totalComputeCapacity = 10000.0;
            :>> activeRobots = 1;
        }
        
        part network : NetworkInfrastructure {
            :>> networkType = "5G-NR";
            :>> averageLatency = 0.05[s];
        }
        
        connection robotToNetwork connect 
            robot.networkPort to network.baseStation;
        
        connection networkToCloud connect 
            network.edgeNode to cloud.networkPort;
        
        perform action mainOperation : CloudRoboticsOperationalCycle;
        
        state robotState : RobotOperationalStates;
        state cloudState : CloudOperationalStates;
    }
    
    part cloudRoboticsSystem : CloudRoboticsSystemDef;
    
    satisfy CloudRoboticsRequirements::primaryFunctionRequirement by cloudRoboticsSystem;
    satisfy CloudRoboticsRequirements::latencyRequirement by cloudRoboticsSystem.robot;
    satisfy CloudRoboticsRequirements::bandwidthRequirement by cloudRoboticsSystem.network;
    satisfy CloudRoboticsRequirements::computeOffloadRequirement by cloudRoboticsSystem;
    satisfy CloudRoboticsRequirements::autonomyRequirement by cloudRoboticsSystem.robot;
    satisfy CloudRoboticsRequirements::scalabilityRequirement by cloudRoboticsSystem.cloud;
    satisfy CloudRoboticsRequirements::energyEfficiencyRequirement by cloudRoboticsSystem.robot;
    satisfy CloudRoboticsRequirements::dataSecurityRequirement by cloudRoboticsSystem.network;
}
