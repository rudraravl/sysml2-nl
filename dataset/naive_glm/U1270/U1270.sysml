package IoT6LoWPANNetwork {
    import ScalarValues::*;

    // ===== Units =====
    unit degC;
    unit pct;
    unit kbps;
    unit sec;
    unit B;

    // ===== Value Types =====
    value def Temperature :> Real { unit degC; }
    value def Humidity :> Real { unit pct; }
    value def BatteryCharge :> Real { unit pct; }
    value def TransmissionRate :> Real { unit kbps; }
    value def Duration :> Real { unit sec; }
    value def DataSize :> Real { unit B; }

    // ===== Item Definitions =====
    item def SensorReading {
        attribute nodeId : String;
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute timestamp : String;
    }

    item def IPv6Packet {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute header : String;
        attribute payload : SensorReading;
        attribute size : DataSize;
    }

    item def CompressedPacket {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute compressedHeader : String;
        attribute payload : SensorReading;
        attribute originalSize : DataSize;
        attribute compressedSize : DataSize;
    }

    item def Fragment {
        attribute fragmentId : String;
        attribute sequenceNumber : Integer;
        attribute totalFragments : Integer;
        attribute sourceNodeId : String;
        attribute data : String;
        attribute fragmentSize : DataSize;
    }

    // ===== Port Definitions =====
    port def MeshPort {
        out txFragment : Fragment;
        in rxFragment : Fragment;
    }

    port def EthernetPort {
        out txPacket : IPv6Packet;
        in rxPacket : IPv6Packet;
    }

    // ===== Interface Definitions =====
    interface def MeshInterface {
        end source : MeshPort;
        end target : MeshPort;
        flow source.txFragment to target.rxFragment;
    }

    interface def InternetInterface {
        end source : EthernetPort;
        end target : EthernetPort;
        flow source.txPacket to target.rxPacket;
    }

    // ===== Sensor Node =====
    part def SensorNode {
        attribute nodeId : String;
        attribute batteryLevel : BatteryCharge := 100;
        attribute wakeInterval : Duration := 60;
        attribute maxFragmentSize : DataSize := 80;
        attribute meshAddress : String;

        port meshPort : MeshPort;

        part tempSensor {
            attribute currentValue : Temperature;
            action def senseTemperature {
                out value : Temperature;
            }
        }

        part humidSensor {
            attribute currentValue : Humidity;
            action def senseHumidity {
                out value : Humidity;
            }
        }

        part ipv6Packager {
            action def packageReading {
                in reading : SensorReading;
                out packet : IPv6Packet;
            }
        }

        part compressionEngine {
            action def compress {
                in packet : IPv6Packet;
                out compressed : CompressedPacket;
            }
        }

        part fragmentationEngine {
            action def fragment {
                in compressed : CompressedPacket;
                out fragments : Fragment[*];
            }
        }

        part radio {
            attribute txRate : TransmissionRate := 250;
            action def transmit {
                in fragments : Fragment[*];
            }
            action def receive {
                out fragment : Fragment;
            }
        }

        part powerSupply {
            attribute charge : BatteryCharge;
            attribute voltage : Real;
        }

        exhibit state def SensorNodeStates {
            entry action initialize;

            state Sleeping {
                do sleepTimer;
            }

            state Waking {
                do powerOn;
            }

            state Measuring {
                do takeMeasurement;
            }

            state Packaging {
                do createIPv6Packet;
            }

            state Compressing {
                do compressHeader;
            }

            state Fragmenting {
                do fragmentPacket;
            }

            state Transmitting {
                do sendFragments;
            }

            transition from Sleeping to Waking
                when batteryLevel > 5;

            transition from Waking to Measuring;
            transition from Measuring to Packaging;
            transition from Packaging to Compressing;
            transition from Compressing to Fragmenting;
            transition from Fragmenting to Transmitting;
            transition from Transmitting to Sleeping;
        }

        action def initialize;
        action def sleepTimer;
        action def powerOn;

        action def takeMeasurement {
            out reading : SensorReading;
        }

        action def createIPv6Packet {
            in reading : SensorReading;
            out packet : IPv6Packet;
        }

        action def compressHeader {
            in packet : IPv6Packet;
            out compressed : CompressedPacket;
        }

        action def fragmentPacket {
            in compressed : CompressedPacket;
            out fragments : Fragment[*];
        }

        action def sendFragments {
            in fragments : Fragment[*];
        }
    }

    // ===== Border Router =====
    part def BorderRouter {
        attribute routerId : String;
        attribute bufferCapacity : DataSize := 1024;
        attribute meshAddress : String;
        attribute ipAddress : String;

        port meshPort : MeshPort;
        port ethernetPort : EthernetPort;

        part fragmentBuffer {
            attribute storedFragments : Fragment[*];
            action def bufferFragment {
                in fragment : Fragment;
            }
            action def checkCompleteness {
                in fragments : Fragment[*];
                out complete : Boolean;
            }
        }

        part reassemblyEngine {
            action def reassemble {
                in fragments : Fragment[*];
                out compressed : CompressedPacket;
            }
        }

        part decompressionEngine {
            action def decompress {
                in compressed : CompressedPacket;
                out packet : IPv6Packet;
            }
        }

        part forwardingEngine {
            action def forward {
                in packet : IPv6Packet;
                out forwarded : IPv6Packet;
            }
        }

        exhibit state def BorderRouterStates {
            entry action bootUp;

            state Listening {
                do listenForFragments;
            }

            state Buffering {
                do bufferIncomingFragments;
            }

            state Reassembling {
                do reassemblePacket;
            }

            state Decompressing {
                do decompressPacket;
            }

            state Forwarding {
                do forwardPacket;
            }

            transition from Listening to Buffering
                when fragmentReceived;

            transition from Buffering to Reassembling
                when allFragmentsReceived;

            transition from Reassembling to Decompressing
                when reassemblyComplete;

            transition from Decompressing to Forwarding
                when decompressionComplete;

            transition from Forwarding to Listening
                when packetForwarded;
        }

        action def bootUp;
        action def listenForFragments;

        action def bufferIncomingFragments {
            in fragment : Fragment;
        }

        action def reassemblePacket {
            in fragments : Fragment[*];
            out compressed : CompressedPacket;
        }

        action def decompressPacket {
            in compressed : CompressedPacket;
            out packet : IPv6Packet;
        }

        action def forwardPacket {
            in packet : IPv6Packet;
        }
    }

    // ===== Cloud Server =====
    part def CloudServer {
        attribute serverId : String;
        attribute storageCapacity : DataSize := 1000000;
        attribute ipAddress : String;
        attribute domainName : String;

        port ethernetPort : EthernetPort;

        part dataRepository {
            attribute storedReadings : SensorReading[*];
            action def store {
                in reading : SensorReading;
            }
            action def retrieve {
                in nodeId : String;
                out readings : SensorReading[*];
            }
        }

        part analyticsEngine {
            action def analyze {
                in readings : SensorReading[*];
                out analysisReport : String;
            }
            action def detectAnomaly {
                in reading : SensorReading;
                out anomalyDetected : Boolean;
            }
        }

        part monitoringInterface {
            action def display {
                in reading : SensorReading;
            }
            action def query {
                in nodeId : String;
                out readings : SensorReading[*];
            }
        }

        exhibit state def CloudServerStates {
            entry action startServer;

            state Idle {
                do waitForData;
            }

            state Receiving {
                do receivePacket;
            }

            state Storing {
                do storeReading;
            }

            state Analyzing {
                do runAnalysis;
            }

            state Publishing {
                do publishData;
            }

            transition from Idle to Receiving
                when packetReceived;

            transition from Receiving to Storing;
            transition from Storing to Analyzing;
            transition from Analyzing to Publishing;
            transition from Publishing to Idle;
        }

        action def startServer;
        action def waitForData;

        action def receivePacket {
            in packet : IPv6Packet;
            out reading : SensorReading;
        }

        action def storeReading {
            in reading : SensorReading;
        }

        action def runAnalysis {
            in readings : SensorReading[*];
            out report : String;
        }

        action def publishData {
            in report : String;
        }
    }

    // ===== Network Assembly =====
    part IoTNetwork {
        attribute networkId : String;
        attribute protocol : String := "6LoWPAN";
        attribute operatingFrequency : Real := 2400;

        part sensorNodes : SensorNode[*];

        part borderRouter : BorderRouter;

        part cloudServer : CloudServer;

        connection meshNetwork : MeshInterface
            connect sensorNodes.meshPort to borderRouter.meshPort;

        connection internetLink : InternetInterface
            connect borderRouter.ethernetPort to cloudServer.ethernetPort;
    }

    // ===== Requirements =====
    requirement def LowPowerDutyCycle {
        subject node : SensorNode;
        doc "Each sensor node shall spend the majority of its operating time in a low-power sleep state, waking periodically to take readings.";
        assume node.batteryLevel > 0;
    }

    requirement def IPv6PacketFormation {
        subject packager;
        doc "Sensor nodes shall package sensor readings into standard IPv6 packets prior to compression.";
    }

    requirement def HeaderCompression {
        subject engine;
        doc "The compression engine shall compress IPv6 packet headers to reduce size for low-power wireless transmission.";
    }

    requirement def PacketFragmentationReq {
        subject engine;
        doc "The fragmentation engine shall break compressed packets into fragments that fit within the maximum wireless frame size.";
    }

    requirement def MeshTransmission {
        subject node : SensorNode;
        doc "Sensor nodes shall transmit fragments to the border router via a 6LoWPAN mesh network.";
    }

    requirement def FragmentReassembly {
        subject router : BorderRouter;
        doc "The border router shall reassemble received fragments into the original compressed packet in correct sequence order.";
    }

    requirement def HeaderDecompression {
        subject router : BorderRouter;
        doc "The border router shall decompress compressed headers to reconstruct the complete IPv6 packet.";
    }

    requirement def InternetForwarding {
        subject router : BorderRouter;
        doc "The border router shall forward reconstructed IPv6 packets to the cloud server over a standard internet connection.";
    }

    requirement def DataStorage {
        subject server : CloudServer;
        doc "The cloud server shall store all received sensor readings in a persistent data repository.";
    }

    requirement def DataAnalysis {
        subject server : CloudServer;
        doc "The cloud server shall analyze stored sensor data and make it available for monitoring applications.";
    }

    requirement def EndToEndConnectivity {
        subject network : IoTNetwork;
        doc "The system shall provide seamless communication between battery-operated sensor devices and the global internet using the 6LoWPAN protocol.";
    }
}
