package CloudRoboticsSystem {
    attribute def BatteryLevel :> ScalarValues::Real;
    attribute def DataRateValue :> ScalarValues::Real;
    attribute def LatencyValue :> ScalarValues::Real;

    item def SensorData;
    item def Image :> SensorData;
    item def PointCloud :> SensorData;
    item def IMUData :> SensorData;

    item def Telemetry {
        attribute positionX : ISQ::LengthValue;
        attribute positionY : ISQ::LengthValue;
        attribute positionZ : ISQ::LengthValue;
        attribute batteryLevel : BatteryLevel;
    }

    item def Command;
    item def PathPlan :> Command;
    item def ManipulatorCommand :> Command;

    attribute def ConnectionLost;
    attribute def ConnectionRestored;
    attribute def SensorDataReady;
    attribute def CommandReceived;
    attribute def TaskComplete;

    port def RobotCommPort {
        out item sensorData : SensorData;
        out item telemetry : Telemetry;
        in item command : Command;
    }

    port def CloudCommPort {
        in item sensorData : SensorData;
        in item telemetry : Telemetry;
        out item command : Command;
    }

    port def NetworkPort {
        in item dataIn : SensorData;
        out item dataOut : Command;
    }

    action def captureSensorData {
        out item data : SensorData;
    }
    action def transmitDataToCloud {
        in item data : SensorData;
        in item telemetry : Telemetry;
    }
    action def executeCommand {
        in item cmd : Command;
    }
    action def runLocalSafety;
    action def processBasicData;

    action def detectObjects;
    action def generatePath;
    action def updateModels;
    action def prioritizeJobs;

    action def processRobotData {
        in item sensorData : SensorData;
        in item telemetry : Telemetry;
        out item command : Command;
        first start;
        then action analyzeData;
        then action decideAction;
        then action generateCommand;
        then done;
    }
    action def analyzeData;
    action def decideAction;
    action def generateCommand;

    part def MobileRobot {
        port commPort : RobotCommPort;

        part camera {
            out item image : Image;
        }
        part lidar {
            out item pointCloud : PointCloud;
        }
        part imu {
            out item imuData : IMUData;
        }

        part wheels;
        part manipulatorArm;

        part onboardProcessor {
            perform action processBasicData;
        }

        part powerManagement {
            attribute batteryStatus : BatteryLevel;
        }

        part wirelessTransceiver {
            port robotNetPort : NetworkPort;
        }

        state robotStates {
            entry; then sensing;
            state sensing {
                do action captureSensorData;
            }
            transition sensing_transmitting
                first sensing
                accept SensorDataReady
                then transmitting;
            state transmitting {
                do action transmitDataToCloud;
            }
            transition transmitting_executing
                first transmitting
                accept CommandReceived
                then executing;
            state executing {
                do action executeCommand;
            }
            transition executing_sensing
                first executing
                accept TaskComplete
                then sensing;

            transition sensing_localAutonomy
                first sensing
                accept ConnectionLost
                then localAutonomy;
            transition transmitting_localAutonomy
                first transmitting
                accept ConnectionLost
                then localAutonomy;
            transition executing_localAutonomy
                first executing
                accept ConnectionLost
                then localAutonomy;
            state localAutonomy {
                do action runLocalSafety;
            }
            transition localAutonomy_sensing
                first localAutonomy
                accept ConnectionRestored
                then sensing;
        }
    }

    part def CloudComputePlatform {
        port cloudCommPort : CloudCommPort;

        part aiProcessors[1..*];

        part objectDetectionModule {
            perform action detectObjects;
        }
        part planningEngine {
            perform action generatePath;
        }
        part learningModule {
            perform action updateModels;
        }

        part knowledgeDatabase;
        part taskOrchestrator {
            perform action prioritizeJobs;
        }

        perform action processRobotData;
    }

    part def NetworkInfrastructure {
        attribute bandwidth : DataRateValue;
        attribute latency : LatencyValue;
        attribute networkStandard : ScalarValues::String = "5G";
        port robotSidePort : NetworkPort;
        port cloudSidePort : NetworkPort;
    }

    part cloudRoboticsSystem {
        part robots[1..*] : MobileRobot;
        part cloud : CloudComputePlatform;
        part network : NetworkInfrastructure;

        connect robots.commPort to network.robotSidePort;
        connect network.cloudSidePort to cloud.cloudCommPort;
    }

    requirement def OffloadComputation {
        doc /* The system shall enable mobile robots to offload complex computational tasks to the cloud computing platform. */
        subject robots : MobileRobot;
        subject cloud : CloudComputePlatform;
    }

    requirement def ResilientOperation {
        doc /* The robot shall switch to local autonomy mode if the connection to the cloud is lost. */
        subject robot : MobileRobot;
    }

    requirement def NetworkPerformance {
        doc /* The network infrastructure shall provide high-bandwidth, low-latency communication between robots and the cloud. */
        subject network : NetworkInfrastructure;
    }

    requirement def SharedKnowledge {
        doc /* The cloud shall maintain a shared knowledge database accessible to all connected robots. */
        subject cloud : CloudComputePlatform;
    }
}
