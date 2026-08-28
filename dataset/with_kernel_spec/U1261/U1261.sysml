package WirelessCommunicationSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def Frequency : SI::FrequencyUnit;
    attribute def Power : SI::PowerUnit;
    attribute def Length : SI::LengthUnit;

    package Items {
        item def DataFrame {
            attribute payload : String;
            attribute sourceAddress : String;
            attribute destinationAddress : String;
            attribute frameSize : Integer;
            attribute timestamp : Real;
            attribute sequenceNumber : Integer;
        }

        item def ControlFrame {
            attribute frameType : String;
            attribute sourceAddress : String;
            attribute destinationAddress : String;
            attribute timestamp : Real;
        }

        item def ConnectionRequest;
        item def DisconnectionRequest;
        item def ConnectRequest;
        item def DisconnectRequest;
    }

    package Interfaces {
        private import Items::*;

        port def WirelessPort {
            in item rxDataFrame : DataFrame;
            out item txDataFrame : DataFrame;
            in item rxControlFrame : ControlFrame;
            out item txControlFrame : ControlFrame;
        }

        port def BackhaulPort {
            in item rxBackhaulData : DataFrame;
            out item txBackhaulData : DataFrame;
        }
    }

    package Behaviors {
        private import Items::*;

        state def OperationalStateMachine {
            attribute transmissionError : Boolean;
            attribute errorResolved : Boolean;

            state Idle;
            state Active;
            state Error;

            transition from Idle to Active on accept ConnectionRequest;
            transition from Active to Idle on accept DisconnectionRequest;
            transition from Active to Error when transmissionError;
            transition from Error to Idle when errorResolved;
        }

        state def ConnectionStateMachine {
            attribute ackReceived : Boolean;

            state Disconnected;
            state Connecting;
            state Connected;
            state Terminated;

            transition from Disconnected to Connecting on accept ConnectRequest;
            transition from Connecting to Connected when ackReceived;
            transition from Connected to Terminated on accept DisconnectRequest;
        }

        action def CSMA_CA_Protocol {
            in frame : DataFrame;
            in channelBusy : Boolean;
            out ackReceived : Boolean;

            first start;
            then action senseChannel;
            then action backoff;
            then action transmitFrame;
            then action receiveAck;
            then done;
        }

        action def CommunicationSequence {
            in source : String;
            in destination : String;
            in payload : String;

            first start;
            then action initiateConnection;
            then action transmitData;
            then action receiveData;
            then action terminateConnection;
            then done;
        }
    }

    package Components {
        private import Interfaces::*;
        private import Items::*;
        private import Behaviors::*;

        part def Antenna {
            attribute gain : Real;
            attribute operatingFrequency : Frequency;

            port internalPort : ~WirelessPort;
            port airPort : ~WirelessPort;
        }

        part def RadioTransceiver {
            attribute operatingFrequency : Frequency;
            attribute transmitPower : Power;
            attribute receiverSensitivity : Power;

            port basebandPort : ~WirelessPort;
            port rfPort : WirelessPort;
        }

        part def SignalProcessor {
            attribute modulationScheme : String;
            attribute codingRate : Real;

            port dataPort : ~WirelessPort;
            port basebandPort : WirelessPort;
        }

        part def MACUnit {
            attribute macAddress : String;
            attribute csmaCaEnabled : Boolean;
            attribute maxRetransmissions : Integer;

            port dataPort : WirelessPort;
        }

        part def CommunicationModule {
            part antenna : Antenna;
            part transceiver : RadioTransceiver;
            part signalProcessor : SignalProcessor;
            part macUnit : MACUnit;

            port rfPort : WirelessPort;

            connect macUnit.dataPort to signalProcessor.dataPort;
            connect signalProcessor.basebandPort to transceiver.basebandPort;
            connect transceiver.rfPort to antenna.internalPort;
            connect rfPort to antenna.airPort;
        }

        part def BaseStation {
            attribute stationID : String;
            attribute coverageRadius : Length;
            attribute maxConnectedDevices : Integer;
            attribute currentConnectedDevices : Integer;
            attribute operatingFrequency : Frequency;
            attribute transmitPower : Power;

            part commModule : CommunicationModule;

            port wirelessIF : ~WirelessPort;
            port backhaulIF : ~BackhaulPort;

            connect wirelessIF to commModule.rfPort;

            exhibit opState : OperationalStateMachine;
        }

        part def WirelessDevice {
            attribute deviceID : String;
            attribute maxPower : Power;
            attribute batteryLevel : Real;

            part commModule : CommunicationModule;

            port wirelessIF : ~WirelessPort;

            connect wirelessIF to commModule.rfPort;

            exhibit connState : ConnectionStateMachine;
        }

        part def WirelessMedium {
            port baseStationIF : WirelessPort;
            port deviceIF : WirelessPort[1..*];
            attribute frequency : Frequency;
            attribute noiseFloor : Power;
        }
    }

    package System {
        private import Components::*;

        part wirelessSystem {
            part baseStation : BaseStation;
            part medium : WirelessMedium;
            part devices : WirelessDevice[1..*];

            connect baseStation.wirelessIF to medium.baseStationIF;
            connect devices.wirelessIF to medium.deviceIF;
        }
    }

    package Requirements {
        private import Components::*;

        requirement def CoverageRangeRequirement {
            doc /** The base station shall provide wireless coverage over a minimum range. */
            attribute minCoverageRadius : Length;
        }

        requirement def ThroughputRequirement {
            doc /** The system shall support a minimum data throughput. */
            attribute minDataRate : Real;
        }

        requirement def ReliabilityRequirement {
            doc /** The system shall maintain packet loss below a maximum threshold. */
            attribute maxPacketLoss : Real;
        }

        requirement def LatencyRequirement {
            doc /** The system shall maintain communication latency below a maximum. */
            attribute maxLatency : Real;
        }

        requirement coverageReq : CoverageRangeRequirement {
            :>> minCoverageRadius = 500.0;
        }

        requirement throughputReq : ThroughputRequirement {
            :>> minDataRate = 1000000.0;
        }

        requirement reliabilityReq : ReliabilityRequirement {
            :>> maxPacketLoss = 0.01;
        }

        requirement latencyReq : LatencyRequirement {
            :>> maxLatency = 0.05;
        }
    }
}
