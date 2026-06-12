package SixLoWPANSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent :> ScalarValues::Real;
    attribute def dBm :> ScalarValues::Real;
    attribute def ByteCount :> ScalarValues::Integer;
    attribute def PacketCount :> ScalarValues::Integer;
    attribute def HopCount :> ScalarValues::Integer;
    attribute def IPv6Address :> ScalarValues::String;
    attribute def PanIdentifier :> ScalarValues::String;
    attribute def LinkLayerAddress :> ScalarValues::String;

    item def TemperatureSample {
        attribute value : Real;
        attribute unit : String = "degC";
        attribute measuredAt : String;
        attribute sourceNode : IPv6Address;
        attribute sequenceNumber : Integer;
    }

    item def HumiditySample {
        attribute value : Percent;
        attribute measuredAt : String;
        attribute sourceNode : IPv6Address;
        attribute sequenceNumber : Integer;
    }

    item def SensorReport {
        attribute sourceIPv6 : IPv6Address;
        attribute destinationIPv6 : IPv6Address;
        attribute sequenceNumber : Integer;
        attribute payloadSize : ByteCount;
        item temperature : TemperatureSample;
        item humidity : HumiditySample;
    }

    item def IPv6Datagram {
        attribute sourceAddress : IPv6Address;
        attribute destinationAddress : IPv6Address;
        attribute trafficClass : Integer;
        attribute hopLimit : HopCount;
        attribute payloadLength : ByteCount;
        item payload : SensorReport;
    }

    item def CompressedSixLoWPANFrame {
        attribute panId : PanIdentifier;
        attribute sourceLinkAddress : LinkLayerAddress;
        attribute destinationLinkAddress : LinkLayerAddress;
        attribute compressedHeaderSize : ByteCount;
        attribute framePayloadSize : ByteCount;
        attribute fragmentTag : Integer;
        attribute fragmentOffset : ByteCount;
        item datagram : IPv6Datagram;
    }

    item def RadioSignal {
        attribute centerFrequency : FrequencyValue;
        attribute channelNumber : Integer;
        attribute receivedPower : dBm;
        attribute signalToNoiseRatio : Real;
        item frame : CompressedSixLoWPANFrame;
    }

    item def CloudApplicationMessage {
        attribute deviceId : String;
        attribute endpointUri : String;
        attribute bodySize : ByteCount;
        item report : SensorReport;
    }

    port def SensorDataPort {
        out item report : SensorReport;
    }

    port def IPv6Port {
        inout item datagram : IPv6Datagram;
    }

    port def SixLoWPANRadioPort {
        inout item signal : RadioSignal;
    }

    port def GatewayBackhaulPort {
        out item message : CloudApplicationMessage;
        in item controlDatagram : IPv6Datagram;
    }

    port def PowerPort {
        in item supplyVoltage : VoltageValue;
        in item supplyCurrent : CurrentValue;
    }

    part def EnvironmentalSensor {
        attribute samplePeriod : TimeValue = 60 [SI::s];
        attribute temperatureAccuracy : Real = 0.5;
        attribute humidityAccuracy : Percent = 3.0;
        port dataOut : SensorDataPort;

        action senseEnvironment {
            out item report : SensorReport;
            action readTemperature;
            action readHumidity;
            action timestampSample;
            action assembleReport;
            flow from assembleReport to report;
        }
    }

    part def SixLoWPANNetworkInterface {
        attribute ipv6Address : IPv6Address;
        attribute linkAddress : LinkLayerAddress;
        attribute panId : PanIdentifier;
        attribute mtu : ByteCount = 1280;
        attribute maxFrameSize : ByteCount = 127;
        attribute nominalDataRate : Real = 250000.0;
        port ipv6 : IPv6Port;
        port radio : SixLoWPANRadioPort;

        action compressIPv6Header {
            in item datagram : IPv6Datagram;
            out item frame : CompressedSixLoWPANFrame;
            action applyContextBasedAddressCompression;
            action elideUdpHeaderFields;
            action fragmentIfRequired;
        }

        action decompressIPv6Header {
            in item frame : CompressedSixLoWPANFrame;
            out item datagram : IPv6Datagram;
            action reassembleFragments;
            action restoreIPv6Header;
            action validateHopLimit;
        }
    }

    part def MeshRouter {
        attribute ipv6Address : IPv6Address;
        attribute linkAddress : LinkLayerAddress;
        attribute routingRank : Integer;
        attribute parentCount : Integer;
        attribute packetForwardingCapacity : PacketCount = 50;
        port radioA : SixLoWPANRadioPort;
        port radioB : SixLoWPANRadioPort;
        port power : PowerPort;

        action forwardFrame {
            in item inbound : RadioSignal;
            out item outbound : RadioSignal;
            action verifyPanIdentifier;
            action updateLinkMetrics;
            action selectNextHop;
            action retransmitFrame;
        }

        state def RouterStateMachine {
            state booting;
            state joiningNetwork;
            state routing;
            state degraded;
            state offline;

            transition first booting;
            transition booting then joiningNetwork;
            transition joiningNetwork then routing;
            transition routing then degraded if packetForwardingCapacity < 10;
            transition degraded then routing if packetForwardingCapacity >= 10;
            transition routing then offline if packetForwardingCapacity == 0;
        }
    }

    part def SensorNode {
        attribute nodeId : String;
        attribute ipv6Address : IPv6Address;
        attribute linkAddress : LinkLayerAddress;
        attribute batteryCapacity : Real = 2400.0;
        attribute sleepCurrent : CurrentValue = 3 [SI::uA];
        attribute transmitCurrent : CurrentValue = 18 [SI::mA];

        part sensor : EnvironmentalSensor;
        part interface : SixLoWPANNetworkInterface;
        port power : PowerPort;

        connect sensor.dataOut to interface.ipv6;

        action collectAndTransmit {
            action wakeRadio;
            action acquireMeasurements;
            action buildIPv6Datagram;
            action compressForSixLoWPAN;
            action transmitRadioFrame;
            action enterLowPowerSleep;
            succession wakeRadio then acquireMeasurements;
            succession acquireMeasurements then buildIPv6Datagram;
            succession buildIPv6Datagram then compressForSixLoWPAN;
            succession compressForSixLoWPAN then transmitRadioFrame;
            succession transmitRadioFrame then enterLowPowerSleep;
        }

        state def SensorNodeStateMachine {
            state sleeping;
            state sampling;
            state transmitting;
            state waitingForAck;
            state fault;

            transition first sleeping;
            transition sleeping then sampling;
            transition sampling then transmitting;
            transition transmitting then waitingForAck;
            transition waitingForAck then sleeping;
            transition waitingForAck then transmitting if true;
            transition sampling then fault if false;
        }
    }

    part def BorderRouter {
        attribute meshPrefix : IPv6Address = "fd00:6lowpan:mesh::/64";
        attribute gatewayAddress : IPv6Address = "fd00:6lowpan:mesh::1";
        attribute backhaulAddress : IPv6Address = "2001:db8:cloud::10";
        attribute routingTableEntries : Integer;
        port meshRadio : SixLoWPANRadioPort;
        port backhaul : GatewayBackhaulPort;
        port power : PowerPort;

        part interface : SixLoWPANNetworkInterface;

        connect meshRadio to interface.radio;

        action bridgeMeshToCloud {
            in item datagram : IPv6Datagram;
            out item message : CloudApplicationMessage;
            action reassembleSixLoWPANFragments;
            action decompressHeaders;
            action validateIPv6Packet;
            action translateToApplicationMessage;
            action publishToCloudEndpoint;
        }

        action bridgeCloudToMesh {
            in item command : IPv6Datagram;
            out item signal : RadioSignal;
            action validateDestinationNode;
            action compressCommandHeader;
            action selectMeshNextHop;
            action transmitIntoMesh;
        }
    }

    part def CloudMonitoringService {
        attribute serviceUri : String = "coaps://monitoring.example.net/ingest";
        attribute retainedReportCount : PacketCount;
        port ingress : GatewayBackhaulPort;

        action receiveTelemetry {
            in item message : CloudApplicationMessage;
            action authenticateGateway;
            action validateReportSchema;
            action storeTimeSeriesData;
            action evaluateAlertRules;
        }
    }

    part def SixLoWPANEnvironmentalMonitoringSystem {
        attribute primaryFunction : String =
            "Provide low-power IPv6 connectivity over an IEEE 802.15.4 mesh so distributed environmental sensor nodes can collect measurements and deliver them to an IP-based monitoring service.";
        attribute operatingPanId : PanIdentifier = "0x6A10";
        attribute channel : Integer = 20;
        attribute nominalFrequency : FrequencyValue = 2450 [SI::MHz];

        part sensorNode1 : SensorNode {
            attribute nodeId = "env-node-001";
            attribute ipv6Address = "fd00:6lowpan:mesh::101";
            attribute linkAddress = "02-00-00-00-00-01";
        }

        part sensorNode2 : SensorNode {
            attribute nodeId = "env-node-002";
            attribute ipv6Address = "fd00:6lowpan:mesh::102";
            attribute linkAddress = "02-00-00-00-00-02";
        }

        part sensorNode3 : SensorNode {
            attribute nodeId = "env-node-003";
            attribute ipv6Address = "fd00:6lowpan:mesh::103";
            attribute linkAddress = "02-00-00-00-00-03";
        }

        part router1 : MeshRouter {
            attribute ipv6Address = "fd00:6lowpan:mesh::201";
            attribute linkAddress = "02-00-00-00-02-01";
            attribute routingRank = 2;
            attribute parentCount = 1;
        }

        part router2 : MeshRouter {
            attribute ipv6Address = "fd00:6lowpan:mesh::202";
            attribute linkAddress = "02-00-00-00-02-02";
            attribute routingRank = 3;
            attribute parentCount = 2;
        }

        part borderRouter : BorderRouter;
        part cloudService : CloudMonitoringService;

        connect sensorNode1.interface.radio to router1.radioA;
        connect sensorNode2.interface.radio to router1.radioB;
        connect sensorNode3.interface.radio to router2.radioA;
        connect router1.radioA to borderRouter.meshRadio;
        connect router2.radioB to router1.radioB;
        connect borderRouter.backhaul to cloudService.ingress;

        action monitorEnvironment {
            action collectFromNode1 : sensorNode1.collectAndTransmit;
            action collectFromNode2 : sensorNode2.collectAndTransmit;
            action collectFromNode3 : sensorNode3.collectAndTransmit;
            action routeViaMesh;
            action bridgeAtBorderRouter : borderRouter.bridgeMeshToCloud;
            action ingestAtCloud : cloudService.receiveTelemetry;

            succession collectFromNode1 then routeViaMesh;
            succession collectFromNode2 then routeViaMesh;
            succession collectFromNode3 then routeViaMesh;
            succession routeViaMesh then bridgeAtBorderRouter;
            succession bridgeAtBorderRouter then ingestAtCloud;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : SixLoWPANEnvironmentalMonitoringSystem;
        doc
            /* The system shall provide low-power IPv6-based wireless connectivity for environmental sensing devices using 6LoWPAN over an IEEE 802.15.4 mesh network. */
        require constraint {
            system.primaryFunction != ""
        }
    }

    requirement def IPv6ConnectivityRequirement {
        subject system : SixLoWPANEnvironmentalMonitoringSystem;
        doc
            /* Each sensor node shall be addressable by an IPv6 address within the mesh prefix. */
        require constraint {
            system.sensorNode1.ipv6Address != "" and
            system.sensorNode2.ipv6Address != "" and
            system.sensorNode3.ipv6Address != ""
        }
    }

    requirement def LowPowerOperationRequirement {
        subject node : SensorNode;
        doc
            /* A sensor node shall support low-power sleep operation between periodic sensing and transmission cycles. */
        require constraint {
            node.sleepCurrent < 10 [SI::uA]
        }
    }

    requirement def FrameSizeRequirement {
        subject interface : SixLoWPANNetworkInterface;
        doc
            /* The 6LoWPAN network interface shall adapt IPv6 datagrams to IEEE 802.15.4 frames no larger than 127 octets. */
        require constraint {
            interface.maxFrameSize <= 127
        }
    }

    requirement def SamplingRequirement {
        subject sensor : EnvironmentalSensor;
        doc
            /* Each environmental sensor shall produce temperature and humidity reports at least once every 60 seconds during normal operation. */
        require constraint {
            sensor.samplePeriod <= 60 [SI::s]
        }
    }

    requirement def MeshForwardingRequirement {
        subject router : MeshRouter;
        doc
            /* Mesh routers shall forward valid 6LoWPAN frames toward the border router using link metrics and next-hop selection. */
        require constraint {
            router.parentCount >= 1
        }
    }

    requirement def CloudDeliveryRequirement {
        subject system : SixLoWPANEnvironmentalMonitoringSystem;
        doc
            /* Sensor reports received by the border router shall be converted into application messages and delivered to the cloud monitoring service. */
        require constraint {
            system.cloudService.serviceUri != ""
        }
    }

    satisfy PrimaryFunctionRequirement by SixLoWPANEnvironmentalMonitoringSystem;
    satisfy IPv6ConnectivityRequirement by SixLoWPANEnvironmentalMonitoringSystem;
    satisfy LowPowerOperationRequirement by SensorNode;
    satisfy FrameSizeRequirement by SixLoWPANNetworkInterface;
    satisfy SamplingRequirement by EnvironmentalSensor;
    satisfy MeshForwardingRequirement by MeshRouter;
    satisfy CloudDeliveryRequirement by SixLoWPANEnvironmentalMonitoringSystem;

}