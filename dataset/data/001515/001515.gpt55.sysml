package OneNetBasedSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def FrequencyMHz :> Real {
        doc /* Radio frequency expressed in megahertz. */
        unit = "MHz";
    }

    attribute def DataRateKbps :> Real {
        doc /* Data throughput expressed in kilobits per second. */
        unit = "kbps";
    }

    attribute def TimeMs :> Real {
        doc /* Time duration expressed in milliseconds. */
        unit = "ms";
    }

    attribute def TimeS :> Real {
        doc /* Time duration expressed in seconds. */
        unit = "s";
    }

    attribute def PowerdBm :> Real {
        doc /* RF transmit or receive power expressed in dBm. */
        unit = "dBm";
    }

    attribute def VoltageV :> Real {
        doc /* Electrical potential expressed in volts. */
        unit = "V";
    }

    attribute def CurrentmA :> Real {
        doc /* Electrical current expressed in milliamperes. */
        unit = "mA";
    }

    attribute def EnergyWh :> Real {
        doc /* Stored or consumed electrical energy expressed in watt-hours. */
        unit = "Wh";
    }

    attribute def TemperatureC :> Real {
        doc /* Temperature expressed in degrees Celsius. */
        unit = "degC";
    }

    attribute def Percent :> Real {
        doc /* Ratio expressed as a percentage. */
        unit = "%";
    }

    attribute def Count :> Integer {
        doc /* Dimensionless count. */
    }

    attribute def ByteCount :> Integer {
        doc /* Number of bytes. */
        unit = "byte";
    }

    attribute def NodeAddress :> Integer {
        doc /* Logical ONE-NET node address. */
    }

    attribute def NetworkIdentifier :> Integer {
        doc /* Logical ONE-NET network identifier. */
    }

    enum def NodeRole {
        enum coordinator;
        enum repeater;
        enum sensor;
        enum actuator;
        enum gateway;
        enum commissioningTool;
    }

    enum def PacketKind {
        enum discovery;
        enum joinRequest;
        enum joinGrant;
        enum heartbeat;
        enum sensorReport;
        enum actuatorCommand;
        enum acknowledgment;
        enum routeUpdate;
        enum networkStatus;
        enum faultReport;
    }

    enum def SecurityStateKind {
        enum unprovisioned;
        enum joining;
        enum authenticated;
        enum quarantined;
        enum revoked;
    }

    enum def ReliabilityClass {
        enum bestEffort;
        enum acknowledged;
        enum repeated;
        enum routedAcknowledged;
    }

    enum def ActuatorCommandKind {
        enum turnOn;
        enum turnOff;
        enum setLevel;
        enum lock;
        enum unlock;
        enum reset;
    }

    enum def SensorKind {
        enum temperature;
        enum occupancy;
        enum doorContact;
        enum humidity;
        enum energyMeter;
    }

    enum def LinkQualityKind {
        enum excellent;
        enum good;
        enum marginal;
        enum unavailable;
    }

    item def OneNetPacket {
        attribute networkId : NetworkIdentifier;
        attribute sourceAddress : NodeAddress;
        attribute destinationAddress : NodeAddress;
        attribute sequenceNumber : Count;
        attribute packetKind : PacketKind;
        attribute reliability : ReliabilityClass;
        attribute payloadLength : ByteCount;
        attribute encrypted : Boolean;
        attribute authenticated : Boolean;
        attribute hopLimit : Count;
        attribute createdAge : TimeMs;
    }

    item def SensorSample {
        attribute sensorKind : SensorKind;
        attribute producingNode : NodeAddress;
        attribute temperature : TemperatureC;
        attribute relativeHumidity : Percent;
        attribute occupancyDetected : Boolean;
        attribute doorClosed : Boolean;
        attribute energyConsumption : EnergyWh;
        attribute sampleAge : TimeMs;
    }

    item def ActuatorCommand {
        attribute commandKind : ActuatorCommandKind;
        attribute targetNode : NodeAddress;
        attribute requestedLevel : Percent;
        attribute commandTimeout : TimeMs;
        attribute requiresAcknowledgment : Boolean;
    }

    item def NetworkHealthReport {
        attribute networkId : NetworkIdentifier;
        attribute joinedNodeCount : Count;
        attribute averageLinkMargin : PowerdBm;
        attribute packetDeliveryRatio : Percent;
        attribute unauthorizedJoinAttempts : Count;
        attribute degradedRouteCount : Count;
        attribute oldestHeartbeatAge : TimeS;
    }

    item def SecurityCredential {
        attribute networkId : NetworkIdentifier;
        attribute nodeAddress : NodeAddress;
        attribute keyVersion : Count;
        attribute valid : Boolean;
    }

    item def PowerStatus {
        attribute supplyVoltage : VoltageV;
        attribute averageCurrent : CurrentmA;
        attribute batteryRemaining : Percent;
        attribute externalPowerPresent : Boolean;
    }

    item def CommissioningIntent {
        attribute requestedNetworkId : NetworkIdentifier;
        attribute desiredNodeRole : NodeRole;
        attribute installerAuthorized : Boolean;
    }

    port def OneNetRadioPort {
        out item transmittedPacket : OneNetPacket;
        in item receivedPacket : OneNetPacket;

        attribute centerFrequency : FrequencyMHz = 915.0;
        attribute channelSpacing : FrequencyMHz = 0.025;
        attribute nominalDataRate : DataRateKbps = 38.4;
        attribute transmitPower : PowerdBm = 10.0;
        attribute receiverSensitivity : PowerdBm = -105.0;
        attribute linkQuality : LinkQualityKind;
    }

    port def SensorDataPort {
        out item sample : SensorSample;
    }

    port def ActuatorControlPort {
        in item command : ActuatorCommand;
        out item resultPacket : OneNetPacket;
    }

    port def ManagementPort {
        in item commissioningIntent : CommissioningIntent;
        in item credential : SecurityCredential;
        out item health : NetworkHealthReport;
        out item statusPacket : OneNetPacket;
    }

    port def PowerPort {
        in item supply : PowerStatus;
        out item demand : PowerStatus;
    }

    port def CloudServicePort {
        out item outboundHealth : NetworkHealthReport;
        out item outboundSample : SensorSample;
        in item inboundCommand : ActuatorCommand;
    }

    port def HumanInterfacePort {
        in item operatorIntent : CommissioningIntent;
        out item visibleHealth : NetworkHealthReport;
    }

    action def EncodeOneNetPacket {
        in item applicationPayload : OneNetPacket;
        in item credential : SecurityCredential;
        out item encodedPacket : OneNetPacket;

        attribute maximumPayloadLength : ByteCount = 32;
        attribute encryptionEnabled : Boolean = true;
        attribute authenticationTagLength : ByteCount = 4;
    }

    action def ValidateOneNetPacket {
        in item candidatePacket : OneNetPacket;
        in item credential : SecurityCredential;
        out item acceptedPacket : OneNetPacket;
        out item rejected : Boolean;

        attribute maximumAcceptableAge : TimeMs = 2000.0;
        attribute duplicateWindowSize : Count = 16;
    }

    action def RouteOneNetPacket {
        in item incomingPacket : OneNetPacket;
        out item forwardedPacket : OneNetPacket;
        out item deliveredPacket : OneNetPacket;

        attribute maximumHopLimit : Count = 4;
        attribute routeRefreshInterval : TimeS = 60.0;
    }

    action def CollectSensorSample {
        out item collectedSample : SensorSample;

        attribute samplingPeriod : TimeS = 30.0;
        attribute measurementAccuracy : TemperatureC = 0.5;
    }

    action def ApplyActuatorCommand {
        in item requestedCommand : ActuatorCommand;
        out item acknowledgment : OneNetPacket;

        attribute actuationDeadline : TimeMs = 500.0;
        attribute defaultLevel : Percent = 100.0;
    }

    action def AggregateNetworkHealth {
        in item nodeStatus : OneNetPacket;
        out item healthReport : NetworkHealthReport;

        attribute reportingPeriod : TimeS = 60.0;
        attribute minimumAcceptableDeliveryRatio : Percent = 95.0;
    }

    action def CommissionNode {
        in item intent : CommissioningIntent;
        in item credential : SecurityCredential;
        out item joinGrantPacket : OneNetPacket;

        attribute joinWindowDuration : TimeS = 120.0;
        attribute installerAuthenticationRequired : Boolean = true;
    }

    state def NodeProtocolLifecycle {
        attribute securityState : SecurityStateKind = SecurityStateKind::unprovisioned;
        attribute missedHeartbeatCount : Count = 0;

        entry action InitializeRadio;
        state Unprovisioned;
        state DiscoveringNetwork;
        state RequestingJoin;
        state AuthenticatedOperational;
        state SleepingLowPower;
        state RoutingPacket;
        state FaultIsolated;
        state Revoked;

        transition first Unprovisioned;
        transition Unprovisioned to DiscoveringNetwork
            accept PacketKind::discovery;
        transition DiscoveringNetwork to RequestingJoin
            accept PacketKind::joinRequest;
        transition RequestingJoin to AuthenticatedOperational
            accept PacketKind::joinGrant
            do action StoreCredential;
        transition AuthenticatedOperational to SleepingLowPower
            accept PacketKind::heartbeat
            do action ReduceReceiverDutyCycle;
        transition SleepingLowPower to AuthenticatedOperational
            accept PacketKind::sensorReport
            do action WakeRadio;
        transition AuthenticatedOperational to RoutingPacket
            accept PacketKind::routeUpdate
            do action UpdateRouteTable;
        transition RoutingPacket to AuthenticatedOperational
            accept PacketKind::acknowledgment;
        transition AuthenticatedOperational to FaultIsolated
            accept PacketKind::faultReport
            do action DisableApplicationOutput;
        transition FaultIsolated to RequestingJoin
            accept PacketKind::joinRequest
            do action ClearTransientFault;
        transition AuthenticatedOperational to Revoked
            accept SecurityStateKind::revoked
            do action EraseCredential;
    }

    state def CoordinatorNetworkLifecycle {
        attribute openJoinWindow : Boolean = false;
        attribute joinedNodes : Count = 0;

        entry action StartCoordinatorServices;
        state Booting;
        state NetworkFormed;
        state CommissioningOpen;
        state Monitoring;
        state Degraded;
        state Maintenance;

        transition first Booting;
        transition Booting to NetworkFormed
            do action SelectNetworkIdentifier;
        transition NetworkFormed to CommissioningOpen
            accept CommissioningIntent
            do action OpenJoinWindow;
        transition CommissioningOpen to Monitoring
            accept PacketKind::joinGrant
            do action RegisterNewNode;
        transition Monitoring to Degraded
            accept PacketKind::faultReport
            do action MarkRouteDegraded;
        transition Degraded to Monitoring
            accept PacketKind::routeUpdate
            do action ConfirmDeliveryRestored;
        transition Monitoring to Maintenance
            accept PacketKind::networkStatus
            do action PublishHealthReport;
        transition Maintenance to Monitoring
            do action ResumeNormalScheduling;
    }

    part def RadioTransceiver {
        port radio : OneNetRadioPort;
        port power : PowerPort;

        attribute centerFrequency : FrequencyMHz = 915.0;
        attribute channelCount : Count = 25;
        attribute nominalDataRate : DataRateKbps = 38.4;
        attribute maximumTransmitPower : PowerdBm = 10.0;
        attribute receiveSensitivity : PowerdBm = -105.0;
        attribute dutyCycleLimit : Percent = 10.0;
    }

    part def SecurityEngine {
        port management : ManagementPort;

        attribute keyVersion : Count = 1;
        attribute replayProtectionWindow : Count = 16;
        attribute authenticationRequired : Boolean = true;
        attribute encryptionRequired : Boolean = true;

        action validatePacket : ValidateOneNetPacket;
        action encodePacket : EncodeOneNetPacket;
    }

    part def RoutingManager {
        port radio : OneNetRadioPort;
        port management : ManagementPort;

        attribute maximumHops : Count = 4;
        attribute routeTableCapacity : Count = 64;
        attribute routeRefreshPeriod : TimeS = 60.0;
        attribute minimumUsableLinkMargin : PowerdBm = 10.0;

        action routePacket : RouteOneNetPacket;
    }

    part def PowerManager {
        port powerInput : PowerPort;
        port managedPower : PowerPort;

        attribute nominalSupplyVoltage : VoltageV = 3.3;
        attribute sleepCurrent : CurrentmA = 0.015;
        attribute receiveCurrent : CurrentmA = 18.0;
        attribute transmitCurrent : CurrentmA = 32.0;
        attribute lowBatteryThreshold : Percent = 15.0;
    }

    part def SensorInterface {
        port sensorOut : SensorDataPort;
        port power : PowerPort;

        attribute sensorKind : SensorKind;
        attribute samplingPeriod : TimeS = 30.0;
        attribute measurementLatency : TimeMs = 100.0;

        action collect : CollectSensorSample;
    }

    part def ActuatorInterface {
        port control : ActuatorControlPort;
        port power : PowerPort;

        attribute responseDeadline : TimeMs = 500.0;
        attribute commandedLevel : Percent = 0.0;
        attribute failSafeLevel : Percent = 0.0;

        action applyCommand : ApplyActuatorCommand;
    }

    part def OneNetNode {
        port radio : OneNetRadioPort;
        port management : ManagementPort;
        port power : PowerPort;

        attribute nodeAddress : NodeAddress;
        attribute networkId : NetworkIdentifier;
        attribute role : NodeRole;
        attribute heartbeatPeriod : TimeS = 60.0;
        attribute securityState : SecurityStateKind = SecurityStateKind::unprovisioned;
        attribute localPacketDeliveryRatio : Percent = 100.0;

        part transceiver : RadioTransceiver;
        part security : SecurityEngine;
        part routing : RoutingManager;
        part powerManager : PowerManager;

        connection radioConnector connect radio to transceiver.radio;
        connection securityManagementConnector connect management to security.management;
        connection routingManagementConnector connect management to routing.management;
        connection routingRadioConnector connect transceiver.radio to routing.radio;
        connection powerConnector connect power to powerManager.powerInput;
        connection managedPowerConnector connect powerManager.managedPower to transceiver.power;

        perform state nodeProtocol : NodeProtocolLifecycle;
    }

    part def SensorNode :> OneNetNode {
        attribute role : NodeRole = NodeRole::sensor;
        attribute reportingPeriod : TimeS = 30.0;

        port sensorData : SensorDataPort;

        part sensing : SensorInterface {
            attribute sensorKind : SensorKind = SensorKind::temperature;
            attribute samplingPeriod : TimeS = 30.0;
        }

        connection sensorPowerConnector connect powerManager.managedPower to sensing.power;
        connection sensorDataConnector connect sensorData to sensing.sensorOut;
    }

    part def OccupancySensorNode :> SensorNode {
        attribute nodeAddress : NodeAddress = 21;
        attribute role : NodeRole = NodeRole::sensor;
        part sensing redefines sensing {
            attribute sensorKind : SensorKind = SensorKind::occupancy;
            attribute samplingPeriod : TimeS = 10.0;
        }
    }

    part def DoorContactSensorNode :> SensorNode {
        attribute nodeAddress : NodeAddress = 22;
        attribute role : NodeRole = NodeRole::sensor;
        part sensing redefines sensing {
            attribute sensorKind : SensorKind = SensorKind::doorContact;
            attribute samplingPeriod : TimeS = 5.0;
        }
    }

    part def TemperatureSensorNode :> SensorNode {
        attribute nodeAddress : NodeAddress = 23;
        attribute role : NodeRole = NodeRole::sensor;
        part sensing redefines sensing {
            attribute sensorKind : SensorKind = SensorKind::temperature;
            attribute samplingPeriod : TimeS = 30.0;
        }
    }

    part def ActuatorNode :> OneNetNode {
        attribute role : NodeRole = NodeRole::actuator;
        attribute defaultAcknowledgmentTimeout : TimeMs = 750.0;

        port actuatorControl : ActuatorControlPort;

        part actuator : ActuatorInterface;

        connection actuatorPowerConnector connect powerManager.managedPower to actuator.power;
        connection actuatorControlConnector connect actuatorControl to actuator.control;
    }

    part def LightingActuatorNode :> ActuatorNode {
        attribute nodeAddress : NodeAddress = 31;
        attribute role : NodeRole = NodeRole::actuator;
        part actuator redefines actuator {
            attribute responseDeadline : TimeMs = 400.0;
            attribute failSafeLevel : Percent = 0.0;
        }
    }

    part def DoorLockActuatorNode :> ActuatorNode {
        attribute nodeAddress : NodeAddress = 32;
        attribute role : NodeRole = NodeRole::actuator;
        part actuator redefines actuator {
            attribute responseDeadline : TimeMs = 600.0;
            attribute failSafeLevel : Percent = 0.0;
        }
    }

    part def RepeaterNode :> OneNetNode {
        attribute role : NodeRole = NodeRole::repeater;
        attribute routingPriority : Count = 10;
        attribute mainsPowered : Boolean = true;
        attribute forwardCapacityPerMinute : Count = 240;
    }

    part def CoordinatorNode :> OneNetNode {
        attribute role : NodeRole = NodeRole::coordinator;
        attribute networkId : NetworkIdentifier = 1001;
        attribute nodeAddress : NodeAddress = 1;
        attribute maximumJoinedNodes : Count = 64;
        attribute commissioningWindow : TimeS = 120.0;

        action commission : CommissionNode;
        action aggregateHealth : AggregateNetworkHealth;

        perform state coordinatorLifecycle : CoordinatorNetworkLifecycle;
    }

    part def InternetGateway {
        port oneNetRadio : OneNetRadioPort;
        port cloud : CloudServicePort;
        port management : ManagementPort;
        port power : PowerPort;

        attribute role : NodeRole = NodeRole::gateway;
        attribute networkId : NetworkIdentifier = 1001;
        attribute localBufferCapacity : Count = 512;
        attribute cloudPublishPeriod : TimeS = 60.0;
        attribute commandBridgeLatency : TimeMs = 1000.0;

        part transceiver : RadioTransceiver;
        part security : SecurityEngine;
        part routing : RoutingManager;
        part powerManager : PowerManager;

        connection gatewayRadioConnector connect oneNetRadio to transceiver.radio;
        connection gatewaySecurityConnector connect management to security.management;
        connection gatewayRoutingManagementConnector connect management to routing.management;
        connection gatewayRoutingRadioConnector connect transceiver.radio to routing.radio;
        connection gatewayPowerConnector connect power to powerManager.powerInput;
        connection gatewayTransceiverPowerConnector connect powerManager.managedPower to transceiver.power;
    }

    part def CommissioningConsole {
        port humanInterface : HumanInterfacePort;
        port management : ManagementPort;
        port radio : OneNetRadioPort;

        attribute authorizedInstallerPresent : Boolean = true;
        attribute commissioningSessionTimeout : TimeS = 300.0;
        attribute displayedNodeCapacity : Count = 64;
    }

    part def OneNetBasedControlSystem {
        doc /* A ONE-NET-based monitoring and control system whose primary high-level function is to securely exchange low-power wireless messages among sensors, actuators, repeaters, a coordinator, and an Internet gateway so that distributed devices can be commissioned, monitored, commanded, and supervised as one managed network. */

        attribute networkId : NetworkIdentifier = 1001;
        attribute primaryFunction : String = "Secure low-power wireless monitoring and control of distributed devices using ONE-NET messaging.";
        attribute operatingFrequency : FrequencyMHz = 915.0;
        attribute nominalDataRate : DataRateKbps = 38.4;
        attribute maximumNodeCount : Count = 64;
        attribute requiredDeliveryRatio : Percent = 95.0;
        attribute normalHeartbeatPeriod : TimeS = 60.0;

        port installerInterface : HumanInterfacePort;
        port cloudInterface : CloudServicePort;
        port facilityPower : PowerPort;

        part coordinator : CoordinatorNode;
        part gateway : InternetGateway;
        part hallwayRepeater : RepeaterNode {
            attribute nodeAddress : NodeAddress = 11;
            attribute networkId : NetworkIdentifier = 1001;
        }
        part northRepeater : RepeaterNode {
            attribute nodeAddress : NodeAddress = 12;
            attribute networkId : NetworkIdentifier = 1001;
        }
        part occupancySensor : OccupancySensorNode {
            attribute networkId : NetworkIdentifier = 1001;
        }
        part doorContactSensor : DoorContactSensorNode {
            attribute networkId : NetworkIdentifier = 1001;
        }
        part temperatureSensor : TemperatureSensorNode {
            attribute networkId : NetworkIdentifier = 1001;
        }
        part lightingActuator : LightingActuatorNode {
            attribute networkId : NetworkIdentifier = 1001;
        }
        part doorLockActuator : DoorLockActuatorNode {
            attribute networkId : NetworkIdentifier = 1001;
        }
        part commissioningConsole : CommissioningConsole;

        connection installerConnector connect installerInterface to commissioningConsole.humanInterface;
        connection consoleManagementConnector connect commissioningConsole.management to coordinator.management;
        connection gatewayCloudConnector connect cloudInterface to gateway.cloud;

        connection coordinatorGatewayRf connect coordinator.radio to gateway.oneNetRadio;
        connection coordinatorHallwayRepeaterRf connect coordinator.radio to hallwayRepeater.radio;
        connection coordinatorNorthRepeaterRf connect coordinator.radio to northRepeater.radio;
        connection hallwayOccupancyRf connect hallwayRepeater.radio to occupancySensor.radio;
        connection hallwayDoorContactRf connect hallwayRepeater.radio to doorContactSensor.radio;
        connection northTemperatureRf connect northRepeater.radio to temperatureSensor.radio;
        connection hallwayLightingRf connect hallwayRepeater.radio to lightingActuator.radio;
        connection northDoorLockRf connect northRepeater.radio to doorLockActuator.radio;
        connection gatewayLightingRf connect gateway.oneNetRadio to lightingActuator.radio;
        connection gatewayDoorLockRf connect gateway.oneNetRadio to doorLockActuator.radio;
        connection commissioningRadioRf connect commissioningConsole.radio to coordinator.radio;

        connection systemPowerToCoordinator connect facilityPower to coordinator.power;
        connection systemPowerToGateway connect facilityPower to gateway.power;
        connection systemPowerToHallwayRepeater connect facilityPower to hallwayRepeater.power;
        connection systemPowerToNorthRepeater connect facilityPower to northRepeater.power;
        connection systemPowerToLightingActuator connect facilityPower to lightingActuator.power;
        connection systemPowerToDoorLockActuator connect facilityPower to doorLockActuator.power;

        action operateNetwork {
            first start;
            then openCommissioningWindow;
            then authenticateJoiningNodes;
            then collectDistributedSamples;
            then routeSensorReports;
            then bridgeReportsToCloud;
            then receiveCloudCommands;
            then routeActuatorCommands;
            then confirmAcknowledgments;
            then publishNetworkHealth;
        }

        action openCommissioningWindow : CommissionNode;
        action authenticateJoiningNodes : ValidateOneNetPacket;
        action collectDistributedSamples : CollectSensorSample;
        action routeSensorReports : RouteOneNetPacket;
        action bridgeReportsToCloud : AggregateNetworkHealth;
        action receiveCloudCommands : EncodeOneNetPacket;
        action routeActuatorCommands : RouteOneNetPacket;
        action confirmAcknowledgments : ValidateOneNetPacket;
        action publishNetworkHealth : AggregateNetworkHealth;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide a ONE-NET-based high-level function for secure, low-power wireless monitoring and control of distributed sensors and actuators. */

        subject system : OneNetBasedControlSystem;

        require constraint {
            system.maximumNodeCount >= 32
        }

        require constraint {
            system.requiredDeliveryRatio >= 95.0
        }

        require constraint {
            system.nominalDataRate >= 38.4
        }
    }

    requirement def SecurePacketExchangeRequirement {
        doc /* Every application-level ONE-NET packet carrying a sensor report or actuator command shall be authenticated, encrypted, and replay-protected before being accepted by the receiving node. */

        subject packet : OneNetPacket;

        require constraint {
            packet.authenticated == true and packet.encrypted == true and packet.createdAge <= 2000.0
        }
    }

    requirement def CommissioningRequirement {
        doc /* The coordinator shall admit new nodes only during an authorized commissioning window and shall assign each joined node to the configured ONE-NET network identifier. */

        subject coordinator : CoordinatorNode;

        require constraint {
            coordinator.networkId == 1001 and coordinator.commissioningWindow <= 120.0
        }
    }

    requirement def LowPowerNodeRequirement {
        doc /* Battery-capable sensor nodes shall minimize energy consumption by using periodic sampling, heartbeat reporting, and low-power sleep between ONE-NET radio exchanges. */

        subject node : SensorNode;

        require constraint {
            node.reportingPeriod >= 5.0 and node.heartbeatPeriod <= 60.0
        }
    }

    requirement def RoutingRequirement {
        doc /* The ONE-NET routing function shall forward messages through repeaters when direct communication is marginal while limiting route depth to four hops. */

        subject routing : RoutingManager;

        require constraint {
            routing.maximumHops <= 4 and routing.routeTableCapacity >= 32
        }
    }

    requirement def HealthMonitoringRequirement {
        doc /* The gateway shall publish network health including joined node count, delivery ratio, degraded routes, and unauthorized join attempts at least once per minute. */

        subject gateway : InternetGateway;

        require constraint {
            gateway.cloudPublishPeriod <= 60.0
        }
    }

    requirement def ActuatorResponseRequirement {
        doc /* Actuator nodes shall apply authenticated commands and return acknowledgments within the configured response deadline. */

        subject actuatorNode : ActuatorNode;

        require constraint {
            actuatorNode.defaultAcknowledgmentTimeout <= 750.0
        }
    }

    satisfy PrimaryFunctionSatisfaction by OneNetBasedControlSystem;
    satisfy SecurePacketExchangeSatisfaction by SecurityEngine;
    satisfy CommissioningSatisfaction by CoordinatorNode;
    satisfy LowPowerNodeSatisfaction by SensorNode;
    satisfy RoutingSatisfaction by RoutingManager;
    satisfy HealthMonitoringSatisfaction by InternetGateway;
    satisfy ActuatorResponseSatisfaction by ActuatorNode;

}
