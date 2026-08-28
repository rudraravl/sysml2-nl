package IrDA_Wireless_Communication_System {

    import ScalarValues::*;

    // ===== Value Types =====

    value type Wavelength :> Real { unit "nm"; }
    value type BeamAngle :> Real { unit "deg"; }
    value type LinkDistance :> Real { unit "m"; }
    value type DataRate :> Real { unit "bps"; }
    value type PulseFrequency :> Real { unit "Hz"; }
    value type VoltageLevel :> Real { unit "V"; }
    value type DriveCurrent :> Real { unit "mA"; }
    value type TimeDuration :> Real { unit "s"; }
    value type SignalPower :> Real { unit "dBm"; }
    value type BitErrorRate :> Real { }
    value type QualityFactor :> Real { }

    // ===== Enumerations =====

    enum def ConnectionState {
        enum disconnected;
        enum discovery;
        enum negotiation;
        enum connected;
    }

    enum def ActivityState {
        enum idle;
        enum transmitting;
        enum receiving;
    }

    enum def ModulationScheme {
        enum RZI;
        enum NRZI;
    }

    enum def FrameType {
        enum data;
        enum ack;
        enum nack;
        enum beacon;
        enum negotiation;
    }

    // ===== Item Types =====

    item def IRPulse {
        attribute wavelength : Wavelength;
        attribute intensity : SignalPower;
        attribute pulseWidth : TimeDuration;
    }

    item def IRBeam {
        attribute pulses : IRPulse[0..*];
        attribute beamAngle : BeamAngle;
        attribute carrierWavelength : Wavelength;
    }

    item def ElectricalSignal {
        attribute voltage : VoltageLevel;
        attribute duration : TimeDuration;
    }

    item def UserData {
        attribute content : String;
        attribute byteLength : Integer;
    }

    item def DataFrame {
        attribute frameType : FrameType;
        attribute destinationAddress : String;
        attribute sourceAddress : String;
        attribute payload : String;
        attribute checksum : Integer;
        attribute sequenceNumber : Integer;
        attribute retryCount : Integer;
    }

    item def DiscoveryBeacon {
        attribute deviceId : String;
        attribute supportedRates : DataRate[1..*];
        attribute deviceClass : String;
    }

    item def NegotiationMessage {
        attribute proposedRate : DataRate;
        attribute maxFrameSize : Integer;
        attribute ackTimeout : TimeDuration;
        attribute accepted : Boolean;
    }

    item def LinkStatus {
        attribute state : ConnectionState;
        attribute activity : ActivityState;
        attribute signalQuality : QualityFactor;
        attribute linkDistance : LinkDistance;
    }

    // ===== Port Definitions =====

    port def OpticalPort {
        out IRBeam;
        in IRBeam;
    }

    port def ElectricalPort {
        out ElectricalSignal;
        in ElectricalSignal;
    }

    port def FramePort {
        out DataFrame;
        in DataFrame;
    }

    port def ManagementPort {
        out DiscoveryBeacon;
        in DiscoveryBeacon;
        out NegotiationMessage;
        in NegotiationMessage;
        out UserData;
        in UserData;
    }

    port def UserPort {
        out UserData;
        in UserData;
        out LinkStatus;
        in LinkStatus;
    }

    // ===== Part Definitions =====

    part def InfraredLED {
        doc "Transmitter component that converts electrical data into pulses of infrared light at 880nm within a 30-degree cone.";

        attribute wavelength : Wavelength = 880 [nm];
        attribute beamAngle : BeamAngle = 30 [deg];
        attribute forwardVoltage : VoltageLevel = 1.5 [V];
        attribute forwardCurrent : DriveCurrent = 100 [mA];
        attribute radiantIntensity : SignalPower = 10 [dBm];

        port opticalOut : OpticalPort;
        port driveIn : ElectricalPort;

        action def EmitPulse {
            in drive : ElectricalSignal;
            out beam : IRBeam;
        }

        action emitPulse : EmitPulse;
    }

    part def PhotoDetector {
        doc "Receiver component sensitive to 880nm infrared that converts incoming light pulses back into electrical data.";

        attribute sensitivityWavelength : Wavelength = 880 [nm];
        attribute responsivity : Real = 0.5;
        attribute responseTime : TimeDuration = 0.000005 [s];
        attribute noiseFloor : SignalPower = -40 [dBm];
        attribute activeArea : Real = 7.0;

        port opticalIn : OpticalPort;
        port signalOut : ElectricalPort;

        action def DetectPulse {
            in beam : IRBeam;
            out signal : ElectricalSignal;
        }

        action detectPulse : DetectPulse;
    }

    part def PhysicalLayerProcessor {
        doc "Low-level controller managing the LED and photodetector, handling modulation and demodulation of digital data into precise flashing patterns.";

        attribute modulationScheme : ModulationScheme = ModulationScheme::RZI;
        attribute baudRate : DataRate = 115200 [bps];
        attribute pulseWidth : TimeDuration = 0.0000016 [s];
        attribute carrierFrequency : PulseFrequency = 38 [Hz];

        port ledDrive : ElectricalPort;
        port detectorInput : ElectricalPort;
        port frameUp : FramePort;

        action def Modulate {
            in frame : DataFrame;
            out signal : ElectricalSignal;
        }

        action def Demodulate {
            in signal : ElectricalSignal;
            out frame : DataFrame;
        }

        action modulate : Modulate;
        action demodulate : Demodulate;
    }

    part def LinkAccessProtocolController {
        doc "Manages connection reliability by packaging user data into formal frames with addresses and error-checking sequences, handling retransmissions of corrupted data.";

        attribute maxRetransmissions : Integer = 3;
        attribute maxFrameSize : Integer = 2048;
        attribute windowSize : Integer = 7;
        attribute ackTimeout : TimeDuration = 0.5 [s];
        attribute crcPolynomial : Integer = 0x8408;

        port phyInterface : FramePort;
        port mgmtInterface : ManagementPort;

        action def PackageFrame {
            in userData : UserData;
            in destAddress : String;
            out frame : DataFrame;
        }

        action def UnpackageFrame {
            in frame : DataFrame;
            out userData : UserData;
        }

        action def VerifyCRC {
            in frame : DataFrame;
            out valid : Boolean;
        }

        action def RequestRetransmission {
            in sequenceNumber : Integer;
            out nack : DataFrame;
        }

        action packageFrame : PackageFrame;
        action unpackageFrame : UnpackageFrame;
        action verifyCRC : VerifyCRC;
        action requestRetransmission : RequestRetransmission;
    }

    part def LinkManagementController {
        doc "High-level coordinator responsible for finding other IrDA devices, negotiating communication parameters, and maintaining the overall connection state.";

        attribute deviceAddress : String = "IrDA-001";
        attribute discoveryTimeout : TimeDuration = 1.0 [s];
        attribute negotiationTimeout : TimeDuration = 2.0 [s];
        attribute maxLinkDistance : LinkDistance = 1.0 [m];
        attribute minSignalQuality : QualityFactor = 0.3;
        attribute currentRate : DataRate = 115200 [bps];
        attribute currentState : ConnectionState = ConnectionState::disconnected;
        attribute currentActivity : ActivityState = ActivityState::idle;

        port lapInterface : ManagementPort;
        port userInterface : UserPort;

        action def DiscoverDevices {
            out beacon : DiscoveryBeacon;
            in response : DiscoveryBeacon;
        }

        action def NegotiateParameters {
            in proposal : NegotiationMessage;
            out response : NegotiationMessage;
        }

        action def MonitorLink {
            in status : LinkStatus;
            out dropLink : Boolean;
        }

        action discoverDevices : DiscoverDevices;
        action negotiateParameters : NegotiateParameters;
        action monitorLink : MonitorLink;

        state connectionLifecycle {
            initial;

            state disconnected {
                entry action { /* Reset all connection parameters to defaults */ }
                exit action { /* Prepare transceiver subsystems for discovery */ }
            }

            state discovery {
                entry action { /* Begin broadcasting discovery beacons via infrared LED */ }
                do action { /* Listen for discovery responses from nearby IrDA devices */ }
                exit action { /* Select target device from received responses */ }
            }

            state negotiation {
                entry action { /* Send negotiation proposal with supported data rates and parameters */ }
                do action { /* Exchange parameter negotiation messages with peer device */ }
                exit action { /* Confirm and store agreed communication parameters */ }
            }

            state connected {
                entry action { /* Establish data link using negotiated parameters */ }

                initial connectedInitial;

                state idle {
                    entry action { /* Begin monitoring link quality and signal strength */ }
                    do action { /* Continuously check for incoming signals and maintain link */ }
                    exit action { /* Prepare transceiver for data transfer mode */ }
                }

                state transmitting {
                    entry action { /* Activate LED and begin modulating data frames for transmission */ }
                    do action { /* Send frames via infrared pulses and process acknowledgments */ }
                    exit action { /* Flush transmission buffers and return to monitoring */ }
                }

                state receiving {
                    entry action { /* Activate photodetector and prepare demodulator for incoming data */ }
                    do action { /* Demodulate incoming infrared pulses and process frames */ }
                    exit action { /* Deliver received user data to upper layer interface */ }
                }

                transition from connectedInitial to idle;
                transition from idle to transmitting when { dataToSend };
                transition from transmitting to idle when { transmissionComplete };
                transition from idle to receiving when { incomingSignalDetected };
                transition from receiving to idle when { receptionComplete };

                exit action { /* Tear down data link and release all communication resources */ }
            }

            transition from initial to disconnected;
            transition from disconnected to discovery when { userRequestsConnection };
            transition from discovery to negotiation when { deviceFound };
            transition from discovery to disconnected when { discoveryTimeoutExpired };
            transition from negotiation to connected when { negotiationSuccessful };
            transition from negotiation to disconnected when { negotiationFailed };
            transition from connected to disconnected when { userTerminates or linkLost };
        }
    }

    // ===== Top-level Transceiver =====

    part def InfraredTransceiver {
        doc "Self-contained infrared transceiver unit responsible for both sending and receiving data via infrared light beams, supporting half-duplex communication up to 1 meter.";

        attribute maxRange : LinkDistance = 1.0 [m];
        attribute halfDuplex : Boolean = true;
        attribute supportedRates : DataRate[1..*] = { 9600, 19200, 38400, 115200, 576000 };
        attribute active : Boolean = false;

        port externalOptical : OpticalPort;
        port userPort : UserPort;

        part led : InfraredLED {
            attribute wavelength = 880 [nm];
            attribute beamAngle = 30 [deg];
        }

        part detector : PhotoDetector {
            attribute sensitivityWavelength = 880 [nm];
        }

        part phy : PhysicalLayerProcessor {
            attribute modulationScheme = ModulationScheme::RZI;
            attribute baudRate = 115200 [bps];
        }

        part lap : LinkAccessProtocolController {
            attribute maxRetransmissions = 3;
            attribute maxFrameSize = 2048;
        }

        part lmc : LinkManagementController {
            attribute maxLinkDistance = 1.0 [m];
            attribute discoveryTimeout = 1.0 [s];
            attribute negotiationTimeout = 2.0 [s];
        }

        connection ledEmission from led.opticalOut to externalOptical;
        connection detectorReception from externalOptical to detector.opticalIn;
        connection ledDrive from phy.ledDrive to led.driveIn;
        connection detectorSignal from detector.signalOut to phy.detectorInput;
        connection phyToLap from phy.frameUp to lap.phyInterface;
        connection lapToLmc from lap.mgmtInterface to lmc.lapInterface;
        connection userToLmc from lmc.userInterface to userPort;
    }

    // ===== Device Context =====

    part def IrDADevice {
        doc "An electronic device such as a laptop, printer, or remote control equipped with IrDA wireless communication capability.";

        attribute deviceName : String;
        attribute deviceClass : String;

        port userInterface : UserPort;
        port opticalInterface : OpticalPort;

        part transceiver : InfraredTransceiver;

        connection userConnection from transceiver.userPort to userInterface;
        connection opticalConnection from transceiver.externalOptical to opticalInterface;
    }

    // ===== Requirements =====

    requirement def IrDACommunicationRequirement {
        doc "The system shall provide short-range, point-to-point data exchange between electronic devices using beams of infrared light.";
        subject transceiver : InfraredTransceiver;
    }

    requirement def WavelengthRequirement :> IrDACommunicationRequirement {
        doc "The infrared LED shall emit light at a wavelength of 880nm.";
        attribute requiredWavelength : Wavelength = 880 [nm];
        require { transceiver.led.wavelength == requiredWavelength }
    }

    requirement def BeamAngleRequirement :> IrDACommunicationRequirement {
        doc "The infrared LED shall emit light in a narrow 30-degree cone to focus the signal towards a receiving device.";
        attribute requiredBeamAngle : BeamAngle = 30 [deg];
        require { transceiver.led.beamAngle == requiredBeamAngle }
    }

    requirement def MaxRangeRequirement :> IrDACommunicationRequirement {
        doc "The system shall support reliable communication over a short distance of up to 1 meter.";
        attribute requiredRange : LinkDistance = 1.0 [m];
        require { transceiver.maxRange <= requiredRange }
    }

    requirement def HalfDuplexRequirement :> IrDACommunicationRequirement {
        doc "The system shall operate in half-duplex mode, transmitting data in one direction at a time.";
        require { transceiver.halfDuplex == true }
    }

    requirement def ReliabilityRequirement :> IrDACommunicationRequirement {
        doc "The system shall ensure reliable data delivery by packaging data into frames with error-checking and handling retransmissions of corrupted frames.";
        attribute maxBitErrorRate : BitErrorRate = 1.0e-8;
        require { transceiver.lap.maxRetransmissions >= 3 }
    }

    requirement def DiscoveryRequirement :> IrDACommunicationRequirement {
        doc "The system shall enter a discovery phase to find other nearby IrDA devices before establishing a connection.";
        require { transceiver.lmc.discoveryTimeout <= 1.0 [s] }
    }

    requirement def NegotiationRequirement :> IrDACommunicationRequirement {
        doc "The system shall negotiate communication parameters including common data speed with the peer device before establishing a connected link.";
        require { transceiver.lmc.negotiationTimeout <= 2.0 [s] }
    }

    requirement def LinkMonitoringRequirement :> IrDACommunicationRequirement {
        doc "The system shall automatically drop the connection if devices move too far apart or signal quality degrades below acceptable threshold.";
        require { transceiver.lmc.maxLinkDistance <= 1.0 [m] }
    }

    requirement def LineOfSightRequirement :> IrDACommunicationRequirement {
        doc "The system shall require line-of-sight between communicating devices for proper infrared data exchange.";
        require { transceiver.maxRange <= 1.0 [m] }
    }

    requirement def ModulationRequirement :> IrDACommunicationRequirement {
        doc "The physical layer processor shall encode digital data into precise flashing patterns for infrared transmission and decode incoming patterns back to digital data.";
        require { transceiver.phy.modulationScheme == ModulationScheme::RZI }
    }

    // ===== Verifications =====

    verification def VerifyWavelength {
        subject led : InfraredLED;
        objective { led.wavelength == 880 [nm] }
    }

    verification def VerifyBeamAngle {
        subject led : InfraredLED;
        objective { led.beamAngle == 30 [deg] }
    }

    verification def VerifyMaxRange {
        subject transceiver : InfraredTransceiver;
        objective { transceiver.maxRange <= 1.0 [m] }
    }

    verification def VerifyHalfDuplex {
        subject transceiver : InfraredTransceiver;
        objective { transceiver.halfDuplex == true }
    }

    verification def VerifyReliability {
        subject transceiver : InfraredTransceiver;
        objective { transceiver.lap.maxRetransmissions >= 3 }
    }

    verification def VerifyDiscoveryTimeout {
        subject transceiver : InfraredTransceiver;
        objective { transceiver.lmc.discoveryTimeout <= 1.0 [s] }
    }

    verification def VerifyNegotiationTimeout {
        subject transceiver : InfraredTransceiver;
        objective { transceiver.lmc.negotiationTimeout <= 2.0 [s] }
    }
}
