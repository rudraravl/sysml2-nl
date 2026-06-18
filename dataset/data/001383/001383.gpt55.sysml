package CloudRoboticsModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Percentage {
        attribute value : Real;
        attribute unit : String = "%";
    }

    attribute def LatencyValue {
        attribute value : Real;
        attribute unit : String = "ms";
    }

    attribute def BandwidthValue {
        attribute value : Real;
        attribute unit : String = "Mbps";
    }

    attribute def DistanceValue {
        attribute value : Real;
        attribute unit : String = "m";
    }

    attribute def VelocityValue {
        attribute value : Real;
        attribute unit : String = "m/s";
    }

    attribute def AccelerationValue {
        attribute value : Real;
        attribute unit : String = "m/s^2";
    }

    attribute def MassValue {
        attribute value : Real;
        attribute unit : String = "kg";
    }

    attribute def EnergyValue {
        attribute value : Real;
        attribute unit : String = "Wh";
    }

    attribute def PowerValue {
        attribute value : Real;
        attribute unit : String = "W";
    }

    attribute def TemperatureValue {
        attribute value : Real;
        attribute unit : String = "degC";
    }

    attribute def TimeValue {
        attribute value : Real;
        attribute unit : String = "s";
    }

    attribute def CoordinateValue {
        attribute x : DistanceValue;
        attribute y : DistanceValue;
        attribute z : DistanceValue;
    }

    enum def MissionPriority {
        enum low;
        enum normal;
        enum high;
        enum emergency;
    }

    enum def RobotMode {
        enum poweredOff;
        enum booting;
        enum standby;
        enum cloudConnected;
        enum executingMission;
        enum degradedAutonomy;
        enum returningToDock;
        enum charging;
        enum faulted;
    }

    enum def NetworkQuality {
        enum unavailable;
        enum poor;
        enum acceptable;
        enum good;
        enum excellent;
    }

    enum def MissionStatusKind {
        enum planned;
        enum dispatched;
        enum executing;
        enum paused;
        enum completed;
        enum aborted;
        enum failed;
    }

    item def RobotCommand {
        attribute commandId : String;
        attribute targetRobotId : String;
        attribute commandName : String;
        attribute priority : MissionPriority;
        attribute issuedTime : TimeValue;
    }

    item def MotionCommand :> RobotCommand {
        attribute targetPose : CoordinateValue;
        attribute maximumVelocity : VelocityValue;
        attribute maximumAcceleration : AccelerationValue;
        attribute obstacleClearance : DistanceValue;
    }

    item def ManipulationCommand :> RobotCommand {
        attribute targetObjectId : String;
        attribute graspForce : PowerValue;
        attribute targetLocation : CoordinateValue;
    }

    item def MissionOrder {
        attribute orderId : String;
        attribute requestingApplication : String;
        attribute requestedGoal : String;
        attribute priority : MissionPriority;
        attribute requiredCompletionTime : TimeValue;
    }

    item def MissionPlan {
        attribute planId : String;
        attribute assignedRobotId : String;
        attribute status : MissionStatusKind;
        attribute expectedDuration : TimeValue;
        attribute expectedEnergyUse : EnergyValue;
        attribute routeLength : DistanceValue;
    }

    item def MissionReport {
        attribute reportId : String;
        attribute completed : Boolean;
        attribute finalStatus : MissionStatusKind;
        attribute actualDuration : TimeValue;
        attribute consumedEnergy : EnergyValue;
        attribute summary : String;
    }

    item def SensorFrame {
        attribute frameId : String;
        attribute sourceRobotId : String;
        attribute captureTime : TimeValue;
        attribute pose : CoordinateValue;
        attribute payloadSize : BandwidthValue;
    }

    item def LidarPointCloud :> SensorFrame {
        attribute pointCount : Integer;
        attribute horizontalRange : DistanceValue;
        attribute verticalRange : DistanceValue;
    }

    item def CameraImage :> SensorFrame {
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute compressionRatio : Percentage;
    }

    item def RobotStatus {
        attribute robotId : String;
        attribute mode : RobotMode;
        attribute batteryStateOfCharge : Percentage;
        attribute currentPose : CoordinateValue;
        attribute healthSummary : String;
        attribute activeMissionId : String;
    }

    item def CloudAnalyticsResult {
        attribute resultId : String;
        attribute robotId : String;
        attribute recommendedAction : String;
        attribute confidence : Percentage;
        attribute validFor : TimeValue;
    }

    item def DigitalPacket {
        attribute packetId : String;
        attribute source : String;
        attribute destination : String;
        attribute size : BandwidthValue;
        attribute latencyBudget : LatencyValue;
        attribute encrypted : Boolean;
    }

    port def MissionServicePort {
        in item missionOrder : MissionOrder;
        out item missionReport : MissionReport;
        out item missionPlan : MissionPlan;
    }

    port def RobotCommandPort {
        in item commandIn : RobotCommand;
        out item statusOut : RobotStatus;
        out item reportOut : MissionReport;
    }

    port def RobotTelemetryPort {
        in item statusIn : RobotStatus;
        in item sensorIn : SensorFrame;
        out item analyticsOut : CloudAnalyticsResult;
    }

    port def NetworkPort {
        in item inboundPacket : DigitalPacket;
        out item outboundPacket : DigitalPacket;
    }

    port def SensorPort {
        out item frameOut : SensorFrame;
    }

    port def ActuatorPort {
        in item motionIn : MotionCommand;
        in item manipulationIn : ManipulationCommand;
    }

    port def ChargingPort {
        in item suppliedPower : PowerValue;
        out item batteryStatus : Percentage;
    }

    port def OperatorPort {
        in item operatorMission : MissionOrder;
        out item operatorReport : MissionReport;
        out item operatorStatus : RobotStatus;
    }

    interface def MissionSubmissionInterface {
        end requester : OperatorPort;
        end cloud : MissionServicePort;
        flow requester.operatorMission to cloud.missionOrder;
        flow cloud.missionReport to requester.operatorReport;
    }

    interface def CloudRobotCommandInterface {
        end cloud : MissionServicePort;
        end robot : RobotCommandPort;
        flow cloud.missionPlan to robot.commandIn;
        flow robot.statusOut to cloud.missionReport;
    }

    interface def RobotTelemetryInterface {
        end robot : RobotTelemetryPort;
        end cloud : RobotTelemetryPort;
        flow robot.statusIn to cloud.statusIn;
        flow robot.sensorIn to cloud.sensorIn;
        flow cloud.analyticsOut to robot.analyticsOut;
    }

    interface def PacketNetworkInterface {
        end source : NetworkPort;
        end destination : NetworkPort;
        flow source.outboundPacket to destination.inboundPacket;
        flow destination.outboundPacket to source.inboundPacket;
    }

    action def ReceiveMissionOrder {
        in item missionOrder : MissionOrder;
        out item acceptedOrder : MissionOrder;
    }

    action def BuildGlobalMissionPlan {
        in item acceptedOrder : MissionOrder;
        in item fleetStatus : RobotStatus;
        out item missionPlan : MissionPlan;
    }

    action def DispatchMissionPlan {
        in item missionPlan : MissionPlan;
        out item robotCommand : MotionCommand;
    }

    action def FuseSensorData {
        in item lidar : LidarPointCloud;
        in item image : CameraImage;
        in item robotStatus : RobotStatus;
        out item environmentModel : CloudAnalyticsResult;
    }

    action def OptimizeRobotRoute {
        in item missionPlan : MissionPlan;
        in item environmentModel : CloudAnalyticsResult;
        out item optimizedCommand : MotionCommand;
    }

    action def ExecuteLocalMotion {
        in item motionCommand : MotionCommand;
        out item status : RobotStatus;
    }

    action def ExecuteLocalManipulation {
        in item manipulationCommand : ManipulationCommand;
        out item status : RobotStatus;
    }

    action def MonitorRobotHealth {
        in item robotStatus : RobotStatus;
        out item healthRecommendation : CloudAnalyticsResult;
    }

    action def CompleteMission {
        in item robotStatus : RobotStatus;
        in item missionPlan : MissionPlan;
        out item report : MissionReport;
    }

    action def CloudRoboticsPrimaryFunction {
        in item missionOrder : MissionOrder;
        out item missionReport : MissionReport;

        action receive : ReceiveMissionOrder;
        action plan : BuildGlobalMissionPlan;
        action dispatch : DispatchMissionPlan;
        action executeMotion : ExecuteLocalMotion;
        action monitor : MonitorRobotHealth;
        action complete : CompleteMission;

        flow missionOrder to receive.missionOrder;
        flow receive.acceptedOrder to plan.acceptedOrder;
        flow plan.missionPlan to dispatch.missionPlan;
        flow dispatch.robotCommand to executeMotion.motionCommand;
        flow executeMotion.status to monitor.robotStatus;
        flow executeMotion.status to complete.robotStatus;
        flow plan.missionPlan to complete.missionPlan;
        flow complete.report to missionReport;
    }

    state def RobotOperationalStateMachine {
        attribute currentMode : RobotMode;

        state poweredOff;
        state booting;
        state standby;
        state connectingToCloud;
        state cloudReady;
        state executingMission;
        state degradedAutonomy;
        state returningToDock;
        state charging;
        state faulted;

        transition initialToPoweredOff first poweredOff;
        transition powerOn poweredOff then booting;
        transition bootComplete booting then standby;
        transition networkAvailable standby then connectingToCloud;
        transition cloudSessionEstablished connectingToCloud then cloudReady;
        transition missionReceived cloudReady then executingMission;
        transition missionCompleted executingMission then cloudReady;
        transition batteryLow executingMission then returningToDock;
        transition dockingComplete returningToDock then charging;
        transition chargeComplete charging then cloudReady;
        transition cloudLost executingMission then degradedAutonomy;
        transition cloudRestored degradedAutonomy then executingMission;
        transition unrecoverableFault executingMission then faulted;
        transition operatorReset faulted then booting;
    }

    state def CloudServiceStateMachine {
        state offline;
        state initializing;
        state acceptingMissions;
        state planning;
        state dispatching;
        state supervising;
        state reporting;
        state degradedService;

        transition initialToOffline first offline;
        transition startService offline then initializing;
        transition initializationComplete initializing then acceptingMissions;
        transition missionOrderReceived acceptingMissions then planning;
        transition planValidated planning then dispatching;
        transition commandDispatched dispatching then supervising;
        transition missionFinished supervising then reporting;
        transition reportPublished reporting then acceptingMissions;
        transition insufficientConnectivity supervising then degradedService;
        transition connectivityRecovered degradedService then supervising;
    }

    part def CloudComputeCluster {
        attribute clusterId : String;
        attribute availableComputePower : PowerValue;
        attribute storageCapacity : EnergyValue;
        attribute averageProcessingLatency : LatencyValue;
        attribute serviceAvailability : Percentage;

        port missionService : MissionServicePort;
        port telemetryService : RobotTelemetryPort;
        port network : NetworkPort;

        part missionManager {
            attribute activeMissionCount : Integer;
            perform action receiveMission : ReceiveMissionOrder;
            perform action completeMission : CompleteMission;
        }

        part fleetPlanner {
            attribute maximumRobotsPlanned : Integer;
            attribute planningCycleTime : TimeValue;
            perform action buildPlan : BuildGlobalMissionPlan;
            perform action optimizeRoute : OptimizeRobotRoute;
        }

        part perceptionAnalytics {
            attribute supportedSensorStreams : Integer;
            attribute minimumConfidence : Percentage;
            perform action fuseSensors : FuseSensorData;
        }

        part healthMonitor {
            attribute monitoredRobots : Integer;
            attribute alertThreshold : Percentage;
            perform action monitorHealth : MonitorRobotHealth;
        }

        exhibit state serviceStates : CloudServiceStateMachine;
    }

    part def MobileRobot {
        attribute robotId : String;
        attribute payloadCapacity : MassValue;
        attribute maximumSpeed : VelocityValue;
        attribute localizationAccuracy : DistanceValue;
        attribute batteryCapacity : EnergyValue;
        attribute batteryStateOfCharge : Percentage;
        attribute safeStoppingDistance : DistanceValue;

        port command : RobotCommandPort;
        port telemetry : RobotTelemetryPort;
        port network : NetworkPort;
        port charging : ChargingPort;

        part onboardComputer {
            attribute processorPower : PowerValue;
            attribute localDecisionLatency : LatencyValue;
            attribute autonomyFallbackEnabled : Boolean;
        }

        part driveBase {
            attribute maxVelocity : VelocityValue;
            attribute maxAcceleration : AccelerationValue;
            attribute wheelBase : DistanceValue;
            port actuator : ActuatorPort;
            perform action executeMotion : ExecuteLocalMotion;
        }

        part manipulator {
            attribute degreesOfFreedom : Integer;
            attribute maximumReach : DistanceValue;
            attribute payloadLimit : MassValue;
            port actuator : ActuatorPort;
            perform action executeManipulation : ExecuteLocalManipulation;
        }

        part lidarSensor {
            attribute range : DistanceValue;
            attribute scanRate : TimeValue;
            attribute angularResolution : Percentage;
            port sensor : SensorPort;
        }

        part cameraSensor {
            attribute frameRate : TimeValue;
            attribute fieldOfView : Percentage;
            attribute resolutionWidth : Integer;
            attribute resolutionHeight : Integer;
            port sensor : SensorPort;
        }

        part batteryPack {
            attribute capacity : EnergyValue;
            attribute nominalPower : PowerValue;
            attribute temperature : TemperatureValue;
            attribute stateOfCharge : Percentage;
        }

        exhibit state robotStates : RobotOperationalStateMachine;
    }

    part def WirelessGateway {
        attribute gatewayId : String;
        attribute uplinkBandwidth : BandwidthValue;
        attribute downlinkBandwidth : BandwidthValue;
        attribute averageLatency : LatencyValue;
        attribute packetLossRate : Percentage;
        attribute quality : NetworkQuality;

        port robotSide : NetworkPort;
        port cloudSide : NetworkPort;
    }

    part def ChargingDock {
        attribute dockId : String;
        attribute outputPower : PowerValue;
        attribute dockingTolerance : DistanceValue;
        attribute occupied : Boolean;

        port charger : ChargingPort;
        port network : NetworkPort;
    }

    part def HumanOperatorStation {
        attribute stationId : String;
        attribute operatorName : String;
        attribute displayLatency : LatencyValue;

        port operator : OperatorPort;
        port network : NetworkPort;
    }

    part def CloudRoboticsSystem {
        doc
        /* Primary function: accept high-level mission goals from a human or enterprise application, use cloud computing to plan, optimize, supervise, and learn from robot operations, and command one or more connected mobile robots to execute physical tasks safely while streaming telemetry and mission results back to the requester. */

        attribute systemAvailability : Percentage;
        attribute maximumCommandLatency : LatencyValue;
        attribute minimumNetworkBandwidth : BandwidthValue;
        attribute supportedRobotCount : Integer;
        attribute missionCompletionRate : Percentage;

        port externalMissionInterface : OperatorPort;

        part cloud : CloudComputeCluster {
            attribute clusterId = "cloud-cluster-east-01";
            attribute availableComputePower {
                attribute value = 15000.0;
                attribute unit = "W";
            }
            attribute averageProcessingLatency {
                attribute value = 45.0;
                attribute unit = "ms";
            }
            attribute serviceAvailability {
                attribute value = 99.95;
                attribute unit = "%";
            }
        }

        part gateway : WirelessGateway {
            attribute gatewayId = "5g-edge-gateway-01";
            attribute uplinkBandwidth {
                attribute value = 250.0;
                attribute unit = "Mbps";
            }
            attribute downlinkBandwidth {
                attribute value = 500.0;
                attribute unit = "Mbps";
            }
            attribute averageLatency {
                attribute value = 18.0;
                attribute unit = "ms";
            }
            attribute packetLossRate {
                attribute value = 0.1;
                attribute unit = "%";
            }
            attribute quality = NetworkQuality::excellent;
        }

        part operatorStation : HumanOperatorStation {
            attribute stationId = "ops-console-01";
            attribute operatorName = "Fleet Supervisor";
            attribute displayLatency {
                attribute value = 60.0;
                attribute unit = "ms";
            }
        }

        part robotA : MobileRobot {
            attribute robotId = "AMR-001";
            attribute payloadCapacity {
                attribute value = 25.0;
                attribute unit = "kg";
            }
            attribute maximumSpeed {
                attribute value = 1.8;
                attribute unit = "m/s";
            }
            attribute localizationAccuracy {
                attribute value = 0.03;
                attribute unit = "m";
            }
            attribute batteryCapacity {
                attribute value = 1200.0;
                attribute unit = "Wh";
            }
            attribute batteryStateOfCharge {
                attribute value = 86.0;
                attribute unit = "%";
            }
            attribute safeStoppingDistance {
                attribute value = 0.45;
                attribute unit = "m";
            }
        }

        part robotB : MobileRobot {
            attribute robotId = "AMR-002";
            attribute payloadCapacity {
                attribute value = 18.0;
                attribute unit = "kg";
            }
            attribute maximumSpeed {
                attribute value = 1.5;
                attribute unit = "m/s";
            }
            attribute localizationAccuracy {
                attribute value = 0.04;
                attribute unit = "m";
            }
            attribute batteryCapacity {
                attribute value = 900.0;
                attribute unit = "Wh";
            }
            attribute batteryStateOfCharge {
                attribute value = 72.0;
                attribute unit = "%";
            }
            attribute safeStoppingDistance {
                attribute value = 0.40;
                attribute unit = "m";
            }
        }

        part chargingDockA : ChargingDock {
            attribute dockId = "dock-01";
            attribute outputPower {
                attribute value = 650.0;
                attribute unit = "W";
            }
            attribute dockingTolerance {
                attribute value = 0.05;
                attribute unit = "m";
            }
            attribute occupied = false;
        }

        part chargingDockB : ChargingDock {
            attribute dockId = "dock-02";
            attribute outputPower {
                attribute value = 650.0;
                attribute unit = "W";
            }
            attribute dockingTolerance {
                attribute value = 0.05;
                attribute unit = "m";
            }
            attribute occupied = false;
        }

        connection operatorToSystem connect operatorStation.operator to externalMissionInterface;
        connection operatorToCloudNetwork connect operatorStation.network to gateway.cloudSide;
        connection gatewayToCloud connect gateway.cloudSide to cloud.network;
        connection gatewayToRobotA connect gateway.robotSide to robotA.network;
        connection gatewayToRobotB connect gateway.robotSide to robotB.network;
        connection cloudCommandsRobotA connect cloud.missionService to robotA.command;
        connection cloudCommandsRobotB connect cloud.missionService to robotB.command;
        connection robotATelemetryToCloud connect robotA.telemetry to cloud.telemetryService;
        connection robotBTelemetryToCloud connect robotB.telemetry to cloud.telemetryService;
        connection robotACharging connect robotA.charging to chargingDockA.charger;
        connection robotBCharging connect robotB.charging to chargingDockB.charger;

        perform action primaryFunction : CloudRoboticsPrimaryFunction;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : CloudRoboticsSystem;
        doc
        /* The cloud robotics system shall transform high-level mission orders into safe physical robot actions by performing cloud-based mission planning, fleet optimization, remote supervision, and continuous telemetry-based monitoring. */
        require constraint {
            system.supportedRobotCount >= 2
        }
    }

    requirement def CommandLatencyRequirement {
        subject system : CloudRoboticsSystem;
        doc
        /* The system shall deliver mission-critical robot commands from the cloud service to a connected robot within the maximum command latency during normal network operation. */
        require constraint {
            system.maximumCommandLatency.value <= 100.0
        }
    }

    requirement def TelemetryBandwidthRequirement {
        subject system : CloudRoboticsSystem;
        doc
        /* The system shall provide sufficient bidirectional bandwidth for robot telemetry, perception data, cloud analytics, and command dispatch. */
        require constraint {
            system.minimumNetworkBandwidth.value >= 100.0
        }
    }

    requirement def SafetyFallbackRequirement {
        subject robot : MobileRobot;
        doc
        /* Each robot shall continue safe local autonomy, stop, or return to dock if cloud connectivity is degraded or unavailable. */
        require constraint {
            robot.safeStoppingDistance.value <= 0.50
        }
    }

    requirement def BatteryReturnRequirement {
        subject robot : MobileRobot;
        doc
        /* Each robot shall return to an assigned charging dock before its state of charge falls below the safe operating threshold. */
        require constraint {
            robot.batteryStateOfCharge.value >= 15.0
        }
    }

    requirement def MissionReportingRequirement {
        subject system : CloudRoboticsSystem;
        doc
        /* The system shall publish mission status and final reports to the requesting operator station after mission execution, including outcome, duration, and energy consumed. */
        require constraint {
            system.missionCompletionRate.value >= 95.0
        }
    }

    part cloudRoboticsSystem : CloudRoboticsSystem {
        attribute systemAvailability {
            attribute value = 99.9;
            attribute unit = "%";
        }
        attribute maximumCommandLatency {
            attribute value = 85.0;
            attribute unit = "ms";
        }
        attribute minimumNetworkBandwidth {
            attribute value = 250.0;
            attribute unit = "Mbps";
        }
        attribute supportedRobotCount = 2;
        attribute missionCompletionRate {
            attribute value = 97.5;
            attribute unit = "%";
        }
    }

    satisfy PrimaryFunctionRequirement by cloudRoboticsSystem;
    satisfy CommandLatencyRequirement by cloudRoboticsSystem;
    satisfy TelemetryBandwidthRequirement by cloudRoboticsSystem;
    satisfy MissionReportingRequirement by cloudRoboticsSystem;
    satisfy SafetyFallbackRequirement by cloudRoboticsSystem.robotA;
    satisfy SafetyFallbackRequirement by cloudRoboticsSystem.robotB;
    satisfy BatteryReturnRequirement by cloudRoboticsSystem.robotA;
    satisfy BatteryReturnRequirement by cloudRoboticsSystem.robotB;
}
