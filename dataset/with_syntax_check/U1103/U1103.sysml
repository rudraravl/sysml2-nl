package 'IrDA Wireless Communication System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def DataRateValue :> ISQ::FrequencyValue;
    attribute def BitErrorRateValue :> Real;
    attribute def ModulationScheme;
    attribute def EncodingScheme;

    item def DataPacket {
        attribute sequenceNumber : Integer;
        attribute payloadSize : ISQ::LengthValue;
        attribute payload : String;
        attribute crc : Integer;
        attribute timestamp : ISQ::TimeValue;
    }

    item def IrDAFrame {
        attribute startFlag : Integer;
        attribute addressField : Integer;
        attribute controlField : Integer;
        attribute dataPacket : DataPacket;
        attribute frameCheckSequence : Integer;
        attribute endFlag : Integer;
    }

    item def InfraredSignal {
        attribute wavelength : ISQ::LengthValue;
        attribute intensity : ISQ::PowerValue;
        attribute modulatedData : IrDAFrame;
        attribute beamAngle : Real;
    }

    port def IrDAPhysicalPort {
        attribute nominalWavelength : ISQ::LengthValue = 880.0[SI::nm];
        attribute beamDivergence : Real = 30.0;
        out item txSignal : InfraredSignal[*];
        in item rxSignal : InfraredSignal[*];
    }

    port def DataInterfacePort {
        out item outgoingData : DataPacket[*];
        in item incomingData : DataPacket[*];
    }

    part def InfraredLED {
        attribute emissionWavelength : ISQ::LengthValue = 880.0[SI::nm];
        attribute maxPower : ISQ::PowerValue = 100.0[SI::mW];
        attribute responseTime : ISQ::TimeValue = 10.0[SI::ns];
        port opticalOutput : IrDAPhysicalPort;
    }

    part def PhotoDetector {
        attribute sensitivity : ISQ::PowerValue = 0.5[SI::mW];
        attribute spectralResponse : ISQ::LengthValue = 880.0[SI::nm];
        attribute responseTime : ISQ::TimeValue = 15.0[SI::ns];
        port opticalInput : IrDAPhysicalPort;
    }

    part def PhysicalLayerProcessor {
        attribute modulationScheme : ModulationScheme;
        attribute encodingScheme : EncodingScheme;
        attribute clockRate : DataRateValue;
        port digitalInterface : DataInterfacePort;
        port ledControl : IrDAPhysicalPort;
        port photoDetectorInput : IrDAPhysicalPort;
    }

    part def LinkAccessProtocolController {
        attribute maxFrameSize : ISQ::LengthValue = 2048.0[SI::m];
        attribute windowSize : Integer = 7;
        attribute retransmissionTimeout : ISQ::TimeValue = 500.0[SI::ms];
        port upperLayer : DataInterfacePort;
        port lowerLayer : DataInterfacePort;
    }

    part def LinkManagementController {
        attribute connectionState : String;
        attribute negotiatedSpeed : DataRateValue;
        attribute qualityOfService : Real;
        port serviceInterface : DataInterfacePort;
        port protocolInterface : DataInterfacePort;
    }

    part def InfraredTransceiver {
        part led : InfraredLED;
        part photoDetector : PhotoDetector;
        part physicalLayer : PhysicalLayerProcessor;
        part lapController : LinkAccessProtocolController;
        part lmController : LinkManagementController;
        port externalPort : IrDAPhysicalPort;
        port applicationInterface : DataInterfacePort;

        connection ledConnection connect physicalLayer.ledControl to led.opticalOutput;
        connection photoConnection connect photoDetector.opticalInput to physicalLayer.photoDetectorInput;
        connection externalTx connect led.opticalOutput to externalPort;
        connection externalRx connect externalPort to photoDetector.opticalInput;
        connection lapToPhysical connect lapController.lowerLayer to physicalLayer.digitalInterface;
        connection lmToLap connect lmController.protocolInterface to lapController.upperLayer;
        connection appToLm connect applicationInterface to lmController.serviceInterface;
    }

    connection def OpticalChannel {
        end source : IrDAPhysicalPort;
        end target : IrDAPhysicalPort;
        attribute pathLength : ISQ::LengthValue;
        attribute attenuation : Real;
        attribute alignment : Real;
    }

    event def InitiateConnection;
    event def TerminateConnection;
    event def DataToSend;

    state def IrDACommunicationStates {
        private attribute linkActive : Boolean;
        private attribute deviceDetected : Boolean;
        private attribute discoveryTimeout : Boolean;
        private attribute parametersAgreed : Boolean;
        private attribute negotiationFailed : Boolean;
        private attribute transmissionComplete : Boolean;
        private attribute signalDetected : Boolean;
        private attribute receptionComplete : Boolean;
        private attribute linkQualityDegraded : Boolean;

        entry; then disconnected;

        state disconnected {
            entry assign linkActive := false;
        }

        transition disconnected_to_discovery
            first disconnected
            accept InitiateConnection
            then discovery;

        state discovery {
            entry action broadcastDiscovery;
            do action scanForDevices;
        }

        transition discovery_to_negotiation
            first discovery
            if deviceDetected
            then negotiation;

        transition discovery_to_disconnected
            first discovery
            if discoveryTimeout
            then disconnected;

        state negotiation {
            entry action exchangeCapabilities;
            do action negotiateParameters;
        }

        transition negotiation_to_connected
            first negotiation
            if parametersAgreed
            then connected;

        transition negotiation_to_disconnected
            first negotiation
            if negotiationFailed
            then disconnected;

        state connected {
            entry assign linkActive := true;

            state idle {
                entry action monitorLink;
            }

            state transmitting {
                entry action encodeAndTransmit;
                do action waitForAcknowledgment;
            }

            state receiving {
                entry action detectAndDecode;
                do action validateFrame;
            }

            transition idle_to_transmitting
                first idle
                accept DataToSend
                then transmitting;

            transition transmitting_to_idle
                first transmitting
                if transmissionComplete
                then idle;

            transition idle_to_receiving
                first idle
                if signalDetected
                then receiving;

            transition receiving_to_idle
                first receiving
                if receptionComplete
                then idle;
        }

        transition connected_to_disconnected
            first connected
            accept TerminateConnection
            then disconnected;

        transition connected_to_disconnected_error
            first connected
            if linkQualityDegraded
            then disconnected;
    }

    action def EncodeFrame {
        in dataPacket : DataPacket;
        out encodedFrame : IrDAFrame;
    }

    action def ModulateSignal {
        in frame : IrDAFrame;
        in carrierPower : ISQ::PowerValue;
        out signal : InfraredSignal;
    }

    action def DemodulateSignal {
        in signal : InfraredSignal;
        out frame : IrDAFrame;
    }

    action def DecodeFrame {
        in receivedFrame : IrDAFrame;
        out dataPacket : DataPacket;
        out crcValid : Boolean;
    }

    action def PerformDeviceDiscovery {
        out deviceFound : Boolean;
        out deviceAddress : Integer;
        out deviceCapabilities : String;
        
        first start;
        then action broadcastXID;
        then action listenForResponse {
            out responseReceived : Boolean;
        }
        then decide;
            if listenForResponse.responseReceived then foundDevice;
            else notFound;
        
        state foundDevice {
            entry assign deviceFound := true;
        }
        state notFound {
            entry assign deviceFound := false;
        }
    }

    action def NegotiateConnection {
        in deviceAddress : Integer;
        in requestedDataRate : DataRateValue;
        out negotiationSuccess : Boolean;
        out agreedDataRate : DataRateValue;
        out sessionId : Integer;

        first start;
        then action sendSNRM;
        then action receiveUA {
            out accepted : Boolean;
        }
        then decide;
            if receiveUA.accepted then success;
            else failure;
        
        state success {
            entry assign negotiationSuccess := true;
        }
        state failure {
            entry assign negotiationSuccess := false;
        }
    }

    action def TransmitData {
        in dataPacket : DataPacket;
        in transmitPower : ISQ::PowerValue;
        out transmissionSuccess : Boolean;

        first start;
        then action encode : EncodeFrame {
            in dataPacket = TransmitData::dataPacket;
            out encodedFrame;
        }
        then action modulate : ModulateSignal {
            in frame = encode.encodedFrame;
            in carrierPower = transmitPower;
            out signal;
        }
        then action transmitSignal;
        then action waitForAck {
            out ackReceived : Boolean;
        }
        then decide;
            if waitForAck.ackReceived then success;
            else retry;
        
        action retry : TransmitData;
        then success;
        
        state success {
            entry assign transmissionSuccess := true;
        }
    }

    action def ReceiveData {
        out dataPacket : DataPacket;
        out receptionSuccess : Boolean;

        first start;
        then action detectSignal {
            out signal : InfraredSignal;
        }
        then action demodulate : DemodulateSignal {
            in signal = detectSignal.signal;
            out frame;
        }
        then action decode : DecodeFrame {
            in receivedFrame = demodulate.frame;
            out dataPacket;
            out crcValid;
        }
        then decide;
            if decode.crcValid then sendAck;
            else sendNak;
        
        action sendAck {
            entry assign receptionSuccess := true;
        }
        action sendNak {
            entry assign receptionSuccess := false;
        }
    }

    action def ManageIrDACommunication {
        in attribute dataToTransmit : DataPacket[*];
        out attribute receivedData : DataPacket[*] := ();
        in attribute targetDataRate : DataRateValue;
        in attribute maxTransmitPower : ISQ::PowerValue;

        private attribute linkEstablished : Boolean := false;
        private attribute currentDataRate : DataRateValue;
        private attribute transmitQueue : DataPacket[*] := ();

        first start;
        then action discover : PerformDeviceDiscovery {
            out deviceFound;
            out deviceAddress;
            out deviceCapabilities;
        }

        then decide;
            if discover.deviceFound then negotiate;
            else start;

        action negotiate : NegotiateConnection {
            in deviceAddress = discover.deviceAddress;
            in requestedDataRate = targetDataRate;
            out negotiationSuccess;
            out agreedDataRate;
            out sessionId;
        }

        then decide;
            if negotiate.negotiationSuccess then establishLink;
            else start;

        state establishLink {
            entry assign linkEstablished := true;
            entry assign currentDataRate := negotiate.agreedDataRate;
        }

        then merge communicationLoop;

        loop while linkEstablished {
            for packet in dataToTransmit {
                action transmit : TransmitData {
                    in dataPacket = packet;
                    in transmitPower = maxTransmitPower;
                    out transmissionSuccess;
                }
                then action receive : ReceiveData {
                    out dataPacket;
                    out receptionSuccess;
                }
                then decide;
                    if receive.receptionSuccess then storeData;
                    else continueLoop;
                
                action storeData {
                    entry assign receivedData := receivedData->including(receive.dataPacket);
                }
                then continueLoop;
                
                merge continueLoop;
            }
            accept TerminateConnection;
            then assign linkEstablished := false;
        }

        then done;
    }

    part def IrDAWirelessSystem {
        doc /* 
            Primary Function: Enable wireless point-to-point data communication between 
            devices using infrared light transmission following IrDA protocol standards.
            
            The system establishes a half-duplex communication link operating at distances 
            up to 1 meter with data rates from 9.6 kbps to 4 Mbps. It performs automatic 
            device discovery, connection negotiation, reliable data transfer with error 
            detection and correction, and graceful disconnection. The infrared physical 
            layer uses 880nm wavelength LED emission with a 30-degree cone angle, ensuring 
            line-of-sight communication while maintaining eye safety standards.
        */

        attribute systemDataRate : DataRateValue = 115200.0[SI::Hz];
        attribute maxRange : ISQ::LengthValue = 1.0[SI::m];
        attribute operatingWavelength : ISQ::LengthValue = 880.0[SI::nm];

        part deviceA : InfraredTransceiver;
        part deviceB : InfraredTransceiver;

        connection opticalLink : OpticalChannel connect 
            deviceA.externalPort to deviceB.externalPort {
            attribute :>> pathLength = 0.5[SI::m];
            attribute :>> attenuation = 0.1;
            attribute :>> alignment = 15.0;
        }

        perform action communicationSession : ManageIrDACommunication {
            in targetDataRate = systemDataRate;
            in maxTransmitPower = 100.0[SI::mW];
        }

        state behavior : IrDACommunicationStates;
    }

    requirement def CommunicationRangeRequirement {
        doc /* The system shall support reliable communication over a minimum distance of 1 meter. */
        attribute requiredRange : ISQ::LengthValue;
        subject system : IrDAWirelessSystem;
        require constraint { system.maxRange >= requiredRange }
    }

    requirement def DataRateRequirement {
        doc /* The system shall support configurable data rates from 9.6 kbps to 4 Mbps. */
        attribute minDataRate : DataRateValue;
        attribute maxDataRate : DataRateValue;
        subject system : IrDAWirelessSystem;
        require constraint { 
            system.systemDataRate >= minDataRate and 
            system.systemDataRate <= maxDataRate 
        }
    }

    requirement def BitErrorRateRequirement {
        doc /* The system shall maintain a bit error rate below 10^-9 under normal operating conditions. */
        attribute maxBER : BitErrorRateValue;
        subject system : IrDAWirelessSystem;
    }

    requirement def PhysicalLayerRequirement {
        doc /* The system shall use 880nm wavelength infrared emission with 30-degree beam angle. */
        attribute nominalWavelength : ISQ::LengthValue;
        attribute maxBeamAngle : Real;
        subject transceiver : InfraredTransceiver;
        require constraint {
            transceiver.led.emissionWavelength == nominalWavelength and
            transceiver.led.opticalOutput.beamDivergence <= maxBeamAngle
        }
    }

    requirement def ProtocolComplianceRequirement {
        doc /* The system shall comply with IrDA protocol stack specifications. */
        subject system : IrDAWirelessSystem;
        require rangeReq : CommunicationRangeRequirement {
            requiredRange = 1.0[SI::m];
        }
        require dataRateReq : DataRateRequirement {
            minDataRate = 9600.0[SI::Hz];
            maxDataRate = 4000000.0[SI::Hz];
        }
        require berReq : BitErrorRateRequirement {
            maxBER = 1.0e-9;
        }
        require physicalReq : PhysicalLayerRequirement {
            nominalWavelength = 880.0[SI::nm];
            maxBeamAngle = 30.0;
        }
    }

    requirement def SafetyRequirement {
        doc /* The system shall comply with IEC 60825-1 Class 1 eye safety standards. */
        attribute maxPermissibleExposure : ISQ::PowerValue;
        subject transceiver : InfraredTransceiver;
        require constraint {
            transceiver.led.maxPower <= maxPermissibleExposure
        }
    }

    part irdaSystem : IrDAWirelessSystem;

    satisfy ProtocolComplianceRequirement by irdaSystem;
    satisfy SafetyRequirement by irdaSystem.deviceA {
        maxPermissibleExposure = 100.0[SI::mW];
    }
}
