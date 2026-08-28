package GreenPeakMeshNetwork {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQTemperature::*;
    private import ISQElectricity::*;
    private import ISQTime::*;

    unit def Celsius;
    unit def Percent;
    unit def Volt;
    unit def Second;

    attribute def TemperatureValue :> Real {
        doc /* Ambient temperature in degrees Celsius */
        :>> unit = Celsius;
    }
    attribute def HumidityValue :> Real {
        doc /* Relative humidity percentage */
        :>> unit = Percent;
    }
    attribute def BatteryLevelValue :> Real {
        doc /* Battery remaining charge percentage */
        :>> unit = Percent;
    }
    attribute def VoltageValue :> Real {
        doc /* Electrical voltage */
        :>> unit = Volt;
    }
    attribute def TimeValue :> Real {
        doc /* Elapsed time in seconds */
        :>> unit = Second;
    }
    attribute def NodeAddressValue :> Integer {
        doc /* 16-bit short network address per IEEE 802.15.4 */
    }
    attribute def PanIdValue :> Integer {
        doc /* 16-bit PAN identifier */
    }
    attribute def ChannelValue :> Integer {
        doc /* IEEE 802.15.4 channel number 11..26 */
    }

    item def SensorReading {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute batteryLevel : BatteryLevelValue;
        attribute timestamp : TimeValue;
    }
    item def WirelessFrame {
        attribute sourceAddress : NodeAddressValue;
        attribute destinationAddress : NodeAddressValue;
        attribute panId : PanIdValue;
        attribute payload : SensorReading;
    }
    item def BeaconFrame {
        attribute sourceAddress : NodeAddressValue;
        attribute panId : PanIdValue;
        attribute channel : ChannelValue;
    }
    item def AckFrame {
        attribute sourceAddress : NodeAddressValue;
        attribute destinationAddress : NodeAddressValue;
    }
    item def RouteRequest {
        attribute sourceAddress : NodeAddressValue;
        attribute destinationAddress : NodeAddressValue;
        attribute hopCount : Integer;
    }
    item def RouteReply {
        attribute sourceAddress : NodeAddressValue;
        attribute destinationAddress : NodeAddressValue;
        attribute route : NodeAddressValue[0..*];
    }
    item def JoinRequest {
        attribute sourceAddress : NodeAddressValue;
        attribute panId : PanIdValue;
    }

    port def RFPort {
        doc /* IEEE 802.15.4 wireless communication port */
        out frame : WirelessFrame;
        in incoming : WirelessFrame;
        in beacon : BeaconFrame;
        out ack : AckFrame;
        in ackIn : AckFrame;
    }
    port def SensorPort {
        out reading : SensorReading;
    }
    port def PowerPort {
        out batteryStatus : BatteryLevelValue;
        in powerDemand : VoltageValue;
    }
    port def ControlPort {
        in command : String;
        out status : String;
    }

    enum def NodeRole {
        coordinator;
        router;
        endDevice;
    }

    part def BatteryPack {
        doc /* Long-life battery pack powering a sensor node */
        attribute nominalVoltage : VoltageValue = 3.0;
        attribute capacity : Real = 2.0;
        attribute currentLevel : BatteryLevelValue = 100;
        port powerOut : PowerPort;
        perform action discharge {
            out attribute level : BatteryLevelValue;
            first start;
            then action measureCharge;
            then action reportLevel;
            then done;
        }
    }

    part def EnvironmentalSensor {
        doc /* Measures ambient temperature, humidity, and battery level */
        port sensorOut : SensorPort;
        port powerIn : PowerPort;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute batteryLevel : BatteryLevelValue;
        perform action takeReading {
            out attribute reading : SensorReading;
            first start;
            then action measureTemperature;
            then action measureHumidity;
            then action measureBatteryLevel;
            then action assembleReading;
            then done;
        }
    }

    part def Microcontroller {
        doc /* Central processing unit managing node operations and mesh routing */
        attribute nodeAddress : NodeAddressValue;
        attribute panId : PanIdValue;
        attribute channel : ChannelValue = 15;
        attribute role : NodeRole = NodeRole::endDevice;
        port rfControl : ControlPort;
        port sensorIn : SensorPort;
        port powerStatus : PowerPort;
        port rfData : RFPort;
        attribute routingTable : NodeAddressValue[0..*];
        perform action packageData {
            in sensorReading : SensorReading;
            out frame : WirelessFrame;
            first start;
            then action buildPayload;
            then action setAddress;
            then action finalizeFrame;
            then done;
        }
        perform action routeFrame {
            in incomingFrame : WirelessFrame;
            out forwardedFrame : WirelessFrame;
            first start;
            then action inspectDestination;
            then action lookupRoute;
            then action forwardFrame;
            then done;
        }
        state NodePowerCycle {
            doc /* Power-saving duty cycle: sleep, wake, sense, transmit, listen, sleep */
            then Sleeping;
            state Sleeping {
                doc /* Deep sleep to conserve energy */
                entry action enterLowPowerMode;
                after 30 then Waking;
            }
            state Waking {
                entry action initializeSubsystem;
                then Sensing;
            }
            state Sensing {
                entry action triggerSensorReading;
                accept readingDone : SensorReading
                then Packaging;
            }
            state Packaging {
                entry action packageSensorData;
                then Transmitting;
            }
            state Transmitting {
                entry action sendWirelessFrame;
                accept ackReceived : AckFrame
                then Listening;
                after 5 then Listening;
            }
            state Listening {
                entry action enableReceiver;
                accept incomingFrame : WirelessFrame
                then Relaying;
                after 3 then Sleeping;
            }
            state Relaying {
                entry action routeIncomingFrame;
                then Listening;
            }
        }
    }

    part def RFTransceiver {
        doc /* IEEE 802.15.4 compliant radio transceiver */
        attribute operatingChannel : ChannelValue = 15;
        attribute transmitPower : Real = 0;
        port rfInterface : RFPort;
        port control : ControlPort;
        perform action transmit {
            in frame : WirelessFrame;
            out ack : AckFrame;
            first start;
            then action encodeFrame;
            then action modulateSignal;
            then action sendOverAir;
            then action waitForAck;
            then done;
        }
        perform action receive {
            out frame : WirelessFrame;
            first start;
            then action listenForSignal;
            then action demodulateSignal;
            then action decodeFrame;
            then done;
        }
    }

    part def WirelessSensorNode {
        doc /* Autonomous wireless sensor node forming the mesh network */
        attribute nodeAddress : NodeAddressValue;
        attribute panId : PanIdValue;
        attribute role : NodeRole;
        part batteryPack : BatteryPack;
        part environmentalSensor : EnvironmentalSensor;
        part microcontroller : Microcontroller;
        part rfTransceiver : RFTransceiver;
        connect batteryPack.powerOut to environmentalSensor.powerIn;
        connect batteryPack.powerOut to microcontroller.powerStatus;
        connect environmentalSensor.sensorOut to microcontroller.sensorIn;
        connect microcontroller.rfData to rfTransceiver.rfInterface;
        connect microcontroller.rfControl to rfTransceiver.control;
    }

    part def CoordinatorNode :> WirelessSensorNode {
        doc /* Central coordinator that establishes and manages the network */
        :>> role = NodeRole::coordinator;
        attribute networkPanId : PanIdValue;
        attribute networkChannel : ChannelValue;
        perform action establishNetwork {
            first start;
            then action selectPanId;
            then action selectChannel;
            then action broadcastBeacon;
            then action acceptJoinRequests;
            then done;
        }
        perform action assignAddress;
        perform action processCollectedData;
        state CoordinatorOperation {
            then NetworkActive;
            state NetworkActive {
                entry action issueBeacon;
                accept joinReq : JoinRequest
                do action assignAddress;
                accept dataFrame : WirelessFrame
                do action processCollectedData;
            }
        }
    }

    part def RouterNode :> WirelessSensorNode {
        doc /* Router node that relays messages to extend network range */
        :>> role = NodeRole::router;
        attribute neighborTable : NodeAddressValue[0..*];
        perform action relayMessage {
            in frame : WirelessFrame;
            out forwarded : WirelessFrame;
            first start;
            then action receiveFrame;
            then action checkRoutingTable;
            then action retransmitFrame;
            then done;
        }
        state RouterOperation {
            then ListeningForFrames;
            state ListeningForFrames {
                accept frame : WirelessFrame
                then Relaying;
                after 60 then RouterSleep;
            }
            state Relaying {
                entry action relayMessage;
                then ListeningForFrames;
            }
            state RouterSleep {
                after 10 then ListeningForFrames;
            }
        }
    }

    part def EndDeviceNode :> WirelessSensorNode {
        doc /* End device focused on sensing and sending its own data */
        :>> role = NodeRole::endDevice;
        perform action takeReading;
        perform action transmitFrame;
        state EndDeviceOperation {
            then DeepSleep;
            state DeepSleep {
                after 300 then WakeAndSense;
            }
            state WakeAndSense {
                entry action takeReading;
                then SendData;
            }
            state SendData {
                entry action transmitFrame;
                accept ack : AckFrame
                then BriefListen;
                after 5 then DeepSleep;
            }
            state BriefListen {
                accept incoming : WirelessFrame
                then DeepSleep;
                after 3 then DeepSleep;
            }
        }
    }

    part def GreenPeakMeshNetwork {
        doc /* Self-healing wireless mesh network of GreenPeak sensor nodes */
        attribute panId : PanIdValue;
        attribute channel : ChannelValue;
        part coordinator : CoordinatorNode[1];
        part routers : RouterNode[0..*];
        part endDevices : EndDeviceNode[0..*];
        connect coordinator.rfTransceiver.rfInterface to routers.rfTransceiver.rfInterface;
        connect routers.rfTransceiver.rfInterface to endDevices.rfTransceiver.rfInterface;
        connect routers.rfTransceiver.rfInterface to routers.rfTransceiver.rfInterface;
        perform action selfHeal {
            doc /* Network self-healing when a router becomes unavailable */
            first start;
            then action detectRouteFailure;
            then action broadcastRouteRequest;
            then action collectRouteReplies;
            then action updateRoutingTables;
            then done;
        }
        perform action registerNode;
        state NetworkLifecycle {
            then Initializing;
            state Initializing {
                entry action coordinator.establishNetwork;
                then Active;
            }
            state Active {
                accept routeReq : RouteRequest
                do action selfHeal;
                accept joinReq : JoinRequest
                do action registerNode;
            }
        }
    }

    requirement def UltraLowPowerRequirement {
        doc /* Nodes must achieve multi-year battery life through duty-cycled sleep */
        subject node : WirelessSensorNode;
        attribute minBatteryLife : TimeValue = 63072000;
        requirement {
            node.batteryPack.currentLevel >= 0;
        }
    }
    requirement def MeshReliabilityRequirement {
        doc /* Network must deliver messages via multi-hop routing with self-healing */
        subject network : GreenPeakMeshNetwork;
        requirement {
            network.coordinator.nodeAddress isSet;
        }
    }
    requirement def EnvironmentalMonitoringRequirement {
        doc /* Each node must measure temperature and humidity and report wirelessly */
        subject node : WirelessSensorNode;
        requirement {
            node.environmentalSensor.temperature isSet;
        }
        requirement {
            node.environmentalSensor.humidity isSet;
        }
    }
    requirement def IEEE802154ComplianceRequirement {
        doc /* RF transceiver must communicate using IEEE 802.15.4 standard */
        subject transceiver : RFTransceiver;
        requirement {
            transceiver.operatingChannel >= 11;
        }
        requirement {
            transceiver.operatingChannel <= 26;
        }
    }

    part greenPeakDeployment : GreenPeakMeshNetwork {
        :>> panId = 41963;
        :>> channel = 15;
        part :>> coordinator {
            :>> nodeAddress = 0;
            :>> panId = 41963;
            :>> networkPanId = 41963;
            :>> networkChannel = 15;
        }
        part :>> routers {
            :>> panId = 41963;
            :>> channel = 15;
        }
        part :>> endDevices {
            :>> panId = 41963;
            :>> channel = 15;
        }
    }

    verification UltraLowPowerVerification {
        subject greenPeakDeployment.coordinator;
        objective {
            doc /* Verify coordinator node meets ultra-low-power duty cycle */
        }
        return verdict;
    }
    verification MeshReliabilityVerification {
        subject greenPeakDeployment;
        objective {
            doc /* Verify multi-hop routing and self-healing capability */
        }
        return verdict;
    }
    verification EnvironmentalMonitoringVerification {
        subject greenPeakDeployment.endDevices;
        objective {
            doc /* Verify end device measures and reports environmental data */
        }
        return verdict;
    }
    verification IEEE802154Verification {
        subject greenPeakDeployment.coordinator.rfTransceiver;
        objective {
            doc /* Verify transceiver operates within IEEE 802.15.4 channel range */
        }
        return verdict;
    }
}
