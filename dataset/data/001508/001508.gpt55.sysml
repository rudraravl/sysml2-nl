package MyriaNedBasedSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    doc /* A high-level SysML v2 model of a MyriaNed-based system whose primary function is cooperative environmental monitoring: many small autonomous wireless nodes sense local conditions, exchange compact MyriaNed frames with nearby nodes, converge distributed network state by gossiping, and deliver aggregated events to a gateway. */

    unit def percent;
    unit def byte;
    unit def frame;
    unit def hop;
    unit def dBm;
    unit def packet;

    attribute def NodeIdentifier :> ScalarValues::Integer;
    attribute def SequenceNumber :> ScalarValues::Integer;
    attribute def HopCount :> ScalarValues::Integer;
    attribute def PayloadSize :> ScalarValues::Real;
    attribute def LinkQuality :> ScalarValues::Real;
    attribute def PacketDeliveryRatio :> ScalarValues::Real;
    attribute def RadioPowerLevel :> ScalarValues::Real;
    attribute def BatteryStateOfCharge :> ScalarValues::Real;
    attribute def AirTemperature :> ISQ::thermodynamicTemperature;
    attribute def RelativeHumidity :> ScalarValues::Real;
    attribute def Illuminance :> ScalarValues::Real;
    attribute def CarbonDioxideConcentration :> ScalarValues::Real;
    attribute def ElectricalVoltage :> ISQ::electricPotential;
    attribute def ElectricalCurrent :> ISQ::electricCurrent;
    attribute def ElectricalPower :> ISQ::power;
    attribute def EnergyCapacity :> ISQ::energy;
    attribute def DataRate :> ScalarValues::Real;

    enum def NodeRole {
        enum coordinator;
        enum router;
        enum endpoint;
        enum actuatorEndpoint;
        enum gatewayBridge;
    }

    enum def FrameKind {
        enum neighborAdvertisement;
        enum sensorReport;
        enum actuatorCommand;
        enum timeSync;
        enum healthReport;
        enum networkSummary;
    }

    enum def NodeHealth {
        enum nominal;
        enum lowBattery;
        enum degradedLink;
        enum sensorFault;
        enum radioFault;
        enum isolated;
    }

    enum def ActuatorMode {
        enum off;
        enum automatic;
        enum forcedOn;
        enum forcedOff;
        enum faultSafe;
    }

    item def EnvironmentalSample {
        attribute sampleNodeId : NodeIdentifier;
        attribute sequence : SequenceNumber;
        attribute measuredAt :> ISQ::time;
        attribute airTemperature : AirTemperature;
        attribute relativeHumidity : RelativeHumidity;
        attribute illuminance : Illuminance;
        attribute co2 : CarbonDioxideConcentration;
        attribute batteryVoltage : ElectricalVoltage;
        attribute batterySoc : BatteryStateOfCharge;
    }

    item def MyriaNedPayload {
        attribute payloadKind : FrameKind;
        attribute payloadBytes : PayloadSize;
        attribute encodedTemperature : AirTemperature;
        attribute encodedHumidity : RelativeHumidity;
        attribute encodedIlluminance : Illuminance;
        attribute encodedNodeHealth : NodeHealth;
    }

    item def MyriaNedFrame {
        attribute sourceNodeId : NodeIdentifier;
        attribute destinationNodeId : NodeIdentifier;
        attribute previousHopNodeId : NodeIdentifier;
        attribute sequence : SequenceNumber;
        attribute hopCount : HopCount;
        attribute kind : FrameKind;
        attribute payloadSize : PayloadSize;
        item payload : MyriaNedPayload;
    }

    item def NeighborObservation {
        attribute observerNodeId : NodeIdentifier;
        attribute neighborNodeId : NodeIdentifier;
        attribute rssi : RadioPowerLevel;
        attribute linkQuality : LinkQuality;
        attribute lastHeardAge :> ISQ::time;
    }

    item def NetworkStateSummary {
        attribute reportingGatewayId : NodeIdentifier;
        attribute knownNodeCount : ScalarValues::Integer;
        attribute averageLinkQuality : LinkQuality;
        attribute minimumBatterySoc : BatteryStateOfCharge;
        attribute maximumSampleAge :> ISQ::time;
        attribute aggregatePacketDeliveryRatio : PacketDeliveryRatio;
    }

    item def ApplicationEvent {
        attribute originatingNodeId : NodeIdentifier;
        attribute eventSequence : SequenceNumber;
        attribute eventTime :> ISQ::time;
        attribute priority : ScalarValues::Integer;
        attribute descriptionCode : ScalarValues::String;
        attribute reportedTemperature : AirTemperature;
        attribute reportedHumidity : RelativeHumidity;
        attribute reportedCo2 : CarbonDioxideConcentration;
    }

    item def ActuatorCommand {
        attribute targetNodeId : NodeIdentifier;
        attribute commandSequence : SequenceNumber;
        attribute requestedMode : ActuatorMode;
        attribute requestedDutyCycle : ScalarValues::Real;
        attribute validFor :> ISQ::time;
    }

    item def ElectricalPowerFlow {
        attribute voltage : ElectricalVoltage;
        attribute current : ElectricalCurrent;
        attribute power : ElectricalPower;
    }

    port def MyriaNedMeshPort {
        in item receivedFrame : MyriaNedFrame;
        out item transmittedFrame : MyriaNedFrame;
        in item neighborObservation : NeighborObservation;
        out item advertisement : NeighborObservation;
    }

    port def SensorSamplePort {
        out item sample : EnvironmentalSample;
    }

    port def SensorInputPort {
        in item sample : EnvironmentalSample;
    }

    port def ActuatorCommandPort {
        in item command : ActuatorCommand;
    }

    port def LocalActuatorDrivePort {
        out item command : ActuatorCommand;
    }

    port def GatewayApplicationPort {
        out item event : ApplicationEvent;
        out item networkState : NetworkStateSummary;
        in item command : ActuatorCommand;
    }

    port def DcPowerPort {
        inout item powerFlow : ElectricalPowerFlow;
    }

    port def RadioMacPort {
        in item txFrame : MyriaNedFrame;
        out item rxFrame : MyriaNedFrame;
        out item neighbor : NeighborObservation;
    }

    port def ProcessorRadioPort {
        out item txFrame : MyriaNedFrame;
        in item rxFrame : MyriaNedFrame;
        in item neighbor : NeighborObservation;
    }

    action def AcquireEnvironmentalSample {
        in attribute nodeId : NodeIdentifier;
        in attribute currentTime :> ISQ::time;
        out item sample : EnvironmentalSample;
    }

    action def EncodeMyriaNedSensorReport {
        in item sample : EnvironmentalSample;
        in attribute destinationNodeId : NodeIdentifier;
        out item frame : MyriaNedFrame;
    }

    action def AdvertiseNeighbors {
        in attribute nodeId : NodeIdentifier;
        in attribute linkQuality : LinkQuality;
        out item advertisement : NeighborObservation;
    }

    action def MergeDistributedState {
        in item receivedFrame : MyriaNedFrame;
        in item neighborObservation : NeighborObservation;
        out item updatedSummary : NetworkStateSummary;
    }

    action def GossipFrameToNeighbors {
        in item frame : MyriaNedFrame;
        in attribute allowedHopBudget : HopCount;
        out item forwardedFrame : MyriaNedFrame;
    }

    action def GenerateApplicationEvent {
        in item sample : EnvironmentalSample;
        in item summary : NetworkStateSummary;
        out item event : ApplicationEvent;
    }

    action def DecodeActuatorCommand {
        in item receivedFrame : MyriaNedFrame;
        out item command : ActuatorCommand;
    }

    action def ApplyActuatorCommand {
        in item command : ActuatorCommand;
        out attribute appliedMode : ActuatorMode;
    }

    action def NodeCooperativeMonitoringBehavior {
        in attribute nodeId : NodeIdentifier;
        in attribute currentTime :> ISQ::time;
        out item transmittedFrame : MyriaNedFrame;
        out item localSample : EnvironmentalSample;

        action acquire : AcquireEnvironmentalSample {
            in nodeId = nodeId;
            in currentTime = currentTime;
        }

        action encode : EncodeMyriaNedSensorReport {
            in sample = acquire.sample;
            in destinationNodeId = 0;
        }

        action gossip : GossipFrameToNeighbors {
            in frame = encode.frame;
            in allowedHopBudget = 8 [hop];
        }

        bind localSample = acquire.sample;
        bind transmittedFrame = gossip.forwardedFrame;
    }

    action def GatewayAggregationBehavior {
        in item meshFrame : MyriaNedFrame;
        in item neighborObservation : NeighborObservation;
        out item networkSummary : NetworkStateSummary;
        out item applicationEvent : ApplicationEvent;

        action merge : MergeDistributedState {
            in receivedFrame = meshFrame;
            in neighborObservation = neighborObservation;
        }

        action eventize : GenerateApplicationEvent {
            in summary = merge.updatedSummary;
        }

        bind networkSummary = merge.updatedSummary;
        bind applicationEvent = eventize.event;
    }

    state def MyriaNedNodeLifecycle {
        attribute wakeInterval :> ISQ::time = 30 [SI::s];
        attribute joinTimeout :> ISQ::time = 120 [SI::s];

        state poweredOff;
        state booting;
        state discoveringNeighbors;
        state joinedMesh;
        state sleeping;
        state sensing;
        state gossiping;
        state applyingActuation;
        state degraded;
        state isolated;

        transition initial then poweredOff;
        transition powerApplied first poweredOff then booting;
        transition bootComplete first booting then discoveringNeighbors;
        transition meshNeighborFound first discoveringNeighbors then joinedMesh;
        transition noNeighborBeforeTimeout first discoveringNeighbors then isolated;
        transition scheduledWake first sleeping then sensing;
        transition sampleReady first sensing then gossiping;
        transition gossipComplete first gossiping then sleeping;
        transition commandReceived first joinedMesh then applyingActuation;
        transition actuationComplete first applyingActuation then sleeping;
        transition linkQualityLow first joinedMesh then degraded;
        transition linkRecovered first degraded then joinedMesh;
        transition isolatedNeighborRecovered first isolated then discoveringNeighbors;
    }

    state def GatewayLifecycle {
        state offline;
        state initializing;
        state listeningToMesh;
        state aggregating;
        state publishing;
        state faulted;

        transition initial then offline;
        transition powerApplied first offline then initializing;
        transition initialized first initializing then listeningToMesh;
        transition frameReceived first listeningToMesh then aggregating;
        transition aggregationComplete first aggregating then publishing;
        transition publishComplete first publishing then listeningToMesh;
        transition unrecoverableFault first listeningToMesh then faulted;
    }

    part def EnvironmentalSensorSuite {
        attribute samplePeriod :> ISQ::time = 60 [SI::s];
        attribute temperatureAccuracy : AirTemperature = 0.5 [SI::K];
        attribute humidityAccuracy : RelativeHumidity = 3 [percent];
        attribute illuminanceRange : Illuminance = 100000;
        attribute co2Range : CarbonDioxideConcentration = 5000;

        port sampleOut : SensorSamplePort;
        port power : DcPowerPort;

        perform action acquire : AcquireEnvironmentalSample;
    }

    part def MyriaNedRadioTransceiver {
        attribute centerFrequency :> ISQ::frequency = 868 [SI::MHz];
        attribute channelBandwidth :> ISQ::frequency = 125 [SI::kHz];
        attribute nominalDataRate : DataRate = 38.4;
        attribute txPower : RadioPowerLevel = 10 [dBm];
        attribute receiverSensitivity : RadioPowerLevel = -100 [dBm];
        attribute maximumPayload : PayloadSize = 64 [byte];

        port mesh : MyriaNedMeshPort;
        port mac : RadioMacPort;
        port power : DcPowerPort;
    }

    part def LowPowerMicrocontroller {
        attribute clockFrequency :> ISQ::frequency = 16 [SI::MHz];
        attribute sleepCurrent : ElectricalCurrent = 5 [SI::uA];
        attribute activeCurrent : ElectricalCurrent = 8 [SI::mA];
        attribute frameCacheSize : ScalarValues::Integer = 32;
        attribute maximumHopBudget : HopCount = 8 [hop];

        port sensorIn : SensorInputPort;
        port radio : ProcessorRadioPort;
        port actuatorDrive : LocalActuatorDrivePort;
        port power : DcPowerPort;

        perform action nodeBehavior : NodeCooperativeMonitoringBehavior;
    }

    part def BatteryPowerUnit {
        attribute nominalVoltage : ElectricalVoltage = 3.6 [SI::V];
        attribute usableEnergy : EnergyCapacity = 21.6 [SI::kJ];
        attribute stateOfCharge : BatteryStateOfCharge = 100 [percent];
        attribute lowBatteryThreshold : BatteryStateOfCharge = 20 [percent];

        port dcOut : DcPowerPort;
    }

    part def EnvironmentalActuator {
        attribute defaultMode : ActuatorMode = ActuatorMode::automatic;
        attribute maximumDutyCycle : ScalarValues::Real = 100 [percent];
        attribute failSafeDutyCycle : ScalarValues::Real = 0 [percent];

        port commandIn : ActuatorCommandPort;
        port power : DcPowerPort;

        perform action apply : ApplyActuatorCommand;
    }

    part def MyriaNedWirelessNode {
        attribute nodeId : NodeIdentifier;
        attribute role : NodeRole = NodeRole::router;
        attribute health : NodeHealth = NodeHealth::nominal;
        attribute configuredSamplePeriod :> ISQ::time = 60 [SI::s];
        attribute targetEndToEndLatency :> ISQ::time = 10 [SI::s];
        attribute minimumAcceptableLinkQuality : LinkQuality = 60 [percent];
        attribute expectedBatteryLife :> ISQ::time = 365 [SI::d];

        port mesh : MyriaNedMeshPort;

        part controller : LowPowerMicrocontroller;
        part radio : MyriaNedRadioTransceiver;
        part sensors : EnvironmentalSensorSuite;
        part battery : BatteryPowerUnit;
        part actuator : EnvironmentalActuator;

        connection sensorToController connect sensors.sampleOut to controller.sensorIn;
        connection controllerToRadio connect controller.radio to radio.mac;
        connection radioToMesh connect radio.mesh to mesh;
        connection batteryToController connect battery.dcOut to controller.power;
        connection batteryToRadio connect battery.dcOut to radio.power;
        connection batteryToSensors connect battery.dcOut to sensors.power;
        connection batteryToActuator connect battery.dcOut to actuator.power;
        connection controllerToActuator connect controller.actuatorDrive to actuator.commandIn;

        exhibit state lifecycle : MyriaNedNodeLifecycle;
        perform action cooperativeMonitoring : NodeCooperativeMonitoringBehavior;
    }

    part def GatewayComputeModule {
        attribute retainedHistory :> ISQ::time = 7 [SI::d];
        attribute publishInterval :> ISQ::time = 5 [SI::s];
        attribute maximumTrackedNodes : ScalarValues::Integer = 200;
        attribute applicationEventLatencyBudget :> ISQ::time = 2 [SI::s];

        port radio : ProcessorRadioPort;
        port application : GatewayApplicationPort;
        port power : DcPowerPort;

        perform action aggregate : GatewayAggregationBehavior;
    }

    part def MyriaNedGateway {
        attribute gatewayId : NodeIdentifier = 0;
        attribute role : NodeRole = NodeRole::gatewayBridge;
        attribute nominalEndToEndLatency :> ISQ::time = 8 [SI::s];
        attribute targetPacketDeliveryRatio : PacketDeliveryRatio = 95 [percent];

        port mesh : MyriaNedMeshPort;
        port application : GatewayApplicationPort;

        part radio : MyriaNedRadioTransceiver {
            attribute txPower : RadioPowerLevel = 14 [dBm];
        }

        part compute : GatewayComputeModule;
        part powerSupply : BatteryPowerUnit {
            attribute nominalVoltage : ElectricalVoltage = 5 [SI::V];
            attribute usableEnergy : EnergyCapacity = 360 [SI::kJ];
        }

        connection meshToRadio connect mesh to radio.mesh;
        connection radioToCompute connect radio.mac to compute.radio;
        connection computeToApplication connect compute.application to application;
        connection gatewayPowerToRadio connect powerSupply.dcOut to radio.power;
        connection gatewayPowerToCompute connect powerSupply.dcOut to compute.power;

        exhibit state gatewayState : GatewayLifecycle;
        perform action gatewayAggregation : GatewayAggregationBehavior;
    }

    part def OperatorMonitoringConsole {
        attribute refreshPeriod :> ISQ::time = 5 [SI::s];
        attribute alarmTemperatureThreshold : AirTemperature = 318.15 [SI::K];
        attribute alarmCo2Threshold : CarbonDioxideConcentration = 1200;
        attribute displayedNodeCapacity : ScalarValues::Integer = 200;

        port gatewayApplication : GatewayApplicationPort;
    }

    connection def WirelessNeighborLink {
        end nodeA : MyriaNedMeshPort;
        end nodeB : MyriaNedMeshPort;
        attribute nominalRange :> ISQ::length = 50 [SI::m];
        attribute expectedRssi : RadioPowerLevel = -70 [dBm];
        attribute expectedPdr : PacketDeliveryRatio = 97 [percent];
    }

    connection def ApplicationBackhaul {
        end gatewaySide : GatewayApplicationPort;
        end consoleSide : GatewayApplicationPort;
        attribute backhaulLatency :> ISQ::time = 1 [SI::s];
        attribute retainedSummaryInterval :> ISQ::time = 5 [SI::s];
    }

    part def MyriaNedMeshSensingSystem {
        doc /* Primary high-level function: create a self-organizing MyriaNed wireless mesh that cooperatively collects environmental measurements, distributes those measurements among neighboring nodes through gossip-style frame exchange, and provides consolidated network state and application events to an operator gateway. */

        attribute supportsCooperativeEnvironmentalMonitoring : ScalarValues::Boolean = true;
        attribute selfOrganizingMesh : ScalarValues::Boolean = true;
        attribute primaryFunctionLatencyBudget :> ISQ::time = 10 [SI::s];
        attribute requiredPacketDeliveryRatio : PacketDeliveryRatio = 95 [percent];
        attribute nominalNodeSpacing :> ISQ::length = 25 [SI::m];
        attribute deploymentAreaLength :> ISQ::length = 120 [SI::m];
        attribute deploymentAreaWidth :> ISQ::length = 80 [SI::m];

        port applicationInterface : GatewayApplicationPort;

        part node01 : MyriaNedWirelessNode {
            attribute nodeId : NodeIdentifier = 1;
            attribute role : NodeRole = NodeRole::endpoint;
            attribute configuredSamplePeriod :> ISQ::time = 60 [SI::s];
        }

        part node02 : MyriaNedWirelessNode {
            attribute nodeId : NodeIdentifier = 2;
            attribute role : NodeRole = NodeRole::router;
            attribute configuredSamplePeriod :> ISQ::time = 45 [SI::s];
        }

        part node03 : MyriaNedWirelessNode {
            attribute nodeId : NodeIdentifier = 3;
            attribute role : NodeRole = NodeRole::router;
            attribute configuredSamplePeriod :> ISQ::time = 60 [SI::s];
        }

        part node04 : MyriaNedWirelessNode {
            attribute nodeId : NodeIdentifier = 4;
            attribute role : NodeRole = NodeRole::actuatorEndpoint;
            attribute configuredSamplePeriod :> ISQ::time = 30 [SI::s];
        }

        part node05 : MyriaNedWirelessNode {
            attribute nodeId : NodeIdentifier = 5;
            attribute role : NodeRole = NodeRole::endpoint;
            attribute configuredSamplePeriod :> ISQ::time = 90 [SI::s];
        }

        part node06 : MyriaNedWirelessNode {
            attribute nodeId : NodeIdentifier = 6;
            attribute role : NodeRole = NodeRole::router;
            attribute configuredSamplePeriod :> ISQ::time = 60 [SI::s];
        }

        part gateway : MyriaNedGateway;
        part console : OperatorMonitoringConsole;

        connection link01_02 : WirelessNeighborLink connect node01.mesh to node02.mesh {
            attribute nominalRange :> ISQ::length = 24 [SI::m];
            attribute expectedRssi : RadioPowerLevel = -58 [dBm];
            attribute expectedPdr : PacketDeliveryRatio = 99 [percent];
        }

        connection link02_03 : WirelessNeighborLink connect node02.mesh to node03.mesh {
            attribute nominalRange :> ISQ::length = 28 [SI::m];
            attribute expectedRssi : RadioPowerLevel = -62 [dBm];
            attribute expectedPdr : PacketDeliveryRatio = 98 [percent];
        }

        connection link03_04 : WirelessNeighborLink connect node03.mesh to node04.mesh {
            attribute nominalRange :> ISQ::length = 22 [SI::m];
            attribute expectedRssi : RadioPowerLevel = -55 [dBm];
            attribute expectedPdr : PacketDeliveryRatio = 99 [percent];
        }

        connection link04_05 : WirelessNeighborLink connect node04.mesh to node05.mesh {
            attribute nominalRange :> ISQ::length = 31 [SI::m];
            attribute expectedRssi : RadioPowerLevel = -68 [dBm];
            attribute expectedPdr : PacketDeliveryRatio = 96 [percent];
        }

        connection link05_06 : WirelessNeighborLink connect node05.mesh to node06.mesh {
            attribute nominalRange :> ISQ::length = 27 [SI::m];
            attribute expectedRssi : RadioPowerLevel = -63 [dBm];
            attribute expectedPdr : PacketDeliveryRatio = 98 [percent];
        }

        connection link06_02 : WirelessNeighborLink connect node06.mesh to node02.mesh {
            attribute nominalRange :> ISQ::length = 35 [SI::m];
            attribute expectedRssi : RadioPowerLevel = -72 [dBm];
            attribute expectedPdr : PacketDeliveryRatio = 95 [percent];
        }

        connection link03_gateway : WirelessNeighborLink connect node03.mesh to gateway.mesh {
            attribute nominalRange :> ISQ::length = 18 [SI::m];
            attribute expectedRssi : RadioPowerLevel = -50 [dBm];
            attribute expectedPdr : PacketDeliveryRatio = 99 [percent];
        }

        connection link06_gateway : WirelessNeighborLink connect node06.mesh to gateway.mesh {
            attribute nominalRange :> ISQ::length = 26 [SI::m];
            attribute expectedRssi : RadioPowerLevel = -60 [dBm];
            attribute expectedPdr : PacketDeliveryRatio = 98 [percent];
        }

        connection gatewayToConsole : ApplicationBackhaul connect gateway.application to console.gatewayApplication;
        connection systemApplicationInterface connect gateway.application to applicationInterface;

        perform action primaryFunction : GatewayAggregationBehavior;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall perform cooperative environmental monitoring by using MyriaNed-style distributed wireless nodes to sense local environmental conditions, disseminate compact reports across a self-organizing mesh, and expose consolidated events and network state through a gateway. */
        subject system : MyriaNedMeshSensingSystem;
        require constraint {
            system.supportsCooperativeEnvironmentalMonitoring == true and
            system.selfOrganizingMesh == true
        }
    }

    requirement def MeshLatencyRequirement {
        doc /* Environmental samples shall normally reach the gateway within the high-level latency budget for monitoring and response. */
        subject system : MyriaNedMeshSensingSystem;
        require constraint {
            system.primaryFunctionLatencyBudget <= 10 [SI::s]
        }
    }

    requirement def ReliabilityRequirement {
        doc /* The deployed MyriaNed mesh shall maintain sufficient delivery probability for sensor reports under nominal neighbor-link conditions. */
        subject system : MyriaNedMeshSensingSystem;
        require constraint {
            system.requiredPacketDeliveryRatio >= 95 [percent]
        }
    }

    requirement def NodeEnergyRequirement {
        doc /* Battery-powered nodes shall support long-duration low-power operation by sleeping between sensing and gossiping intervals. */
        subject node : MyriaNedWirelessNode;
        require constraint {
            node.expectedBatteryLife >= 365 [SI::d] and
            node.configuredSamplePeriod >= 30 [SI::s]
        }
    }

    requirement def GatewayAggregationRequirement {
        doc /* The gateway shall aggregate MyriaNed frames into network-state summaries and application events for an operator console. */
        subject gateway : MyriaNedGateway;
        require constraint {
            gateway.targetPacketDeliveryRatio >= 95 [percent] and
            gateway.nominalEndToEndLatency <= 10 [SI::s]
        }
    }

    part myriaNedDeployment : MyriaNedMeshSensingSystem;

    requirement primaryFunctionSatisfied : PrimaryFunctionRequirement {
        subject system = myriaNedDeployment;
    }

    requirement meshLatencySatisfied : MeshLatencyRequirement {
        subject system = myriaNedDeployment;
    }

    requirement reliabilitySatisfied : ReliabilityRequirement {
        subject system = myriaNedDeployment;
    }

    requirement gatewayAggregationSatisfied : GatewayAggregationRequirement {
        subject gateway = myriaNedDeployment.gateway;
    }
}
