package IrDACommunicationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQSpace::*;
    private import SI::*;

    item def DigitalData;
    item def IrFrame {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute payload : DigitalData;
        attribute checksum : String;
    }
    item def IrBeam {
        attribute wavelength : Length = 880 [nm];
        attribute beamAngle : Angle = 30 [deg];
        attribute intensity : Real;
    }
    item def DiscoveryBeacon;
    item def NegotiationPacket {
        attribute dataRate : Real;
        attribute maxTurnTime : Real;
    }
    item def ControlCommand;

    attribute def StartDiscovery;
    attribute def DeviceFound;
    attribute def NegotiationSuccess;
    attribute def NegotiationFail;
    attribute def SendData;
    attribute def ReceiveData;
    attribute def TransmissionComplete;
    attribute def ReceptionComplete;
    attribute def DisconnectSignal;
    attribute def SignalLost;

    interface def OpticalInterface {
        in item lightIn : IrBeam;
        out item lightOut : IrBeam;
    }
    interface def DigitalInterface {
        in item dataIn : DigitalData;
        out item dataOut : DigitalData;
    }
    interface def FrameInterface {
        in item frameIn : IrFrame;
        out item frameOut : IrFrame;
    }
    interface def ControlInterface {
        in item cmdIn : ControlCommand;
        out item cmdOut : ControlCommand;
    }

    action def Transmit {
        in item data : DigitalData;
        out item light : IrBeam;
    }
    action def Receive {
        in item light : IrBeam;
        out item data : DigitalData;
    }
    action def Modulate {
        in item digital : DigitalData;
        out item signal : DigitalData;
    }
    action def Demodulate {
        in item signal : DigitalData;
        out item digital : DigitalData;
    }
    action def PackageFrame {
        in item data : DigitalData;
        out item frame : IrFrame;
    }
    action def UnpackFrame {
        in item frame : IrFrame;
        out item data : DigitalData;
    }
    action def ErrorCheck {
        in item frame : IrFrame;
        out isValid : Boolean;
    }
    action def Retransmit {
        in item frame : IrFrame;
    }
    action def DiscoverDevices {
        out item beacon : DiscoveryBeacon;
    }
    action def NegotiateParameters {
        in item beacon : DiscoveryBeacon;
        out item packet : NegotiationPacket;
    }
    action def MonitorLink {
        out quality : Real;
    }

    part def InfraredLED {
        attribute wavelength : Length = 880 [nm];
        attribute coneAngle : Angle = 30 [deg];
        port digitalIn : DigitalInterface;
        port opticalOut : OpticalInterface;
        perform action transmit : Transmit;
    }

    part def PhotoDetector {
        attribute sensitivity : Length = 880 [nm];
        attribute detectionAngle : Angle = 30 [deg];
        port opticalIn : OpticalInterface;
        port digitalOut : DigitalInterface;
        perform action receive : Receive;
    }

    part def PhysicalLayerProcessor {
        port ledInterface : DigitalInterface;
        port pdInterface : DigitalInterface;
        port lapInterface : DigitalInterface;
        perform action modulate : Modulate;
        perform action demodulate : Demodulate;
    }

    part def LinkAccessProtocolController {
        port phyInterface : DigitalInterface;
        port lmInterface : FrameInterface;
        attribute retryCount : Integer = 3;
        perform action packageFrame : PackageFrame;
        perform action unpackFrame : UnpackFrame;
        perform action errorCheck : ErrorCheck;
        perform action retransmit : Retransmit;
    }

    state def IrDAConnectionStates {
        entry; then disconnected;
        state disconnected;
        accept StartDiscovery
            then discovery;
        state discovery {
            do action discoverDevices;
            accept DeviceFound
                then negotiation;
        }
        state negotiation {
            do action negotiateParameters;
            accept NegotiationSuccess
                then connected;
            accept NegotiationFail
                then disconnected;
        }
        state connected parallel {
            state dataFlow {
                entry; then idle;
                state idle;
                accept SendData then transmitting;
                accept ReceiveData then receiving;
                state transmitting {
                    do action packageFrame;
                    do action modulate;
                    do action transmit;
                }
                accept TransmissionComplete then idle;
                state receiving {
                    do action receive;
                    do action demodulate;
                    do action errorCheck;
                }
                accept ReceptionComplete then idle;
            }
            state linkMonitor {
                do action monitorLink : MonitorLink;
                accept when monitorLink.quality < 0.2
                    then disconnected;
            }
        }
        accept DisconnectSignal then disconnected;
        accept SignalLost then disconnected;
    }

    part def LinkManagementController {
        port lapInterface : FrameInterface;
        port ctrlInterface : ControlInterface;
        port discoveryInterface : OpticalInterface;
        attribute maxRange : Length = 1 [m];
        attribute currentSpeed : Real;
        attribute signalQuality : Real;
        perform action discoverDevices : DiscoverDevices;
        perform action negotiateParameters : NegotiateParameters;
        perform action monitorLink : MonitorLink;
        exhibit state connectionLifecycle : IrDAConnectionStates;
    }

    part def InfraredTransceiver {
        attribute deviceId : String;
        attribute maxDataRate : Real = 115200;
        port irPort : OpticalInterface;
        port userPort : DigitalInterface;
        port ctrlPort : ControlInterface;
        attribute maxDistance : Length = 1 [m];

        part led : InfraredLED;
        part photodetector : PhotoDetector;
        part phy : PhysicalLayerProcessor;
        part lap : LinkAccessProtocolController;
        part lmc : LinkManagementController;

        connect lmc.lapInterface to lap.lmInterface;
        connect lap.phyInterface to phy.lapInterface;
        connect phy.ledInterface to led.digitalIn;
        connect phy.pdInterface to photodetector.digitalOut;
        connect led.opticalOut to irPort;
        connect photodetector.opticalIn to irPort;
        connect lmc.discoveryInterface to irPort;
        connect lmc.ctrlInterface to ctrlPort;
        connect userPort to lap.lmInterface;
    }

    part def IrDASystem {
        part deviceA : InfraredTransceiver;
        part deviceB : InfraredTransceiver;
        connect deviceA.irPort to deviceB.irPort;

        requirement def ShortRangeCommunication {
            subject transceiver : InfraredTransceiver;
            doc /* The system shall support reliable half-duplex communication up to 1 meter. */
            attribute maxDistance : Length = 1 [m];
            constraint { transceiver.maxDistance <= 1 [m] }
        }

        requirement def LineOfSightAlignment {
            subject led : InfraredLED;
            doc /* The LED shall emit infrared light at 880 nm within a 30-degree cone. */
            constraint { led.wavelength == 880 [nm] }
            constraint { led.coneAngle == 30 [deg] }
        }

        requirement def WavelengthMatch {
            subject led : InfraredLED;
            subject detector : PhotoDetector;
            doc /* The photodetector sensitivity shall match the LED emission wavelength. */
            constraint { led.wavelength == detector.sensitivity }
        }

        requirement shortRangeReq : ShortRangeCommunication;
        requirement lineOfSightReq : LineOfSightAlignment;
        requirement wavelengthMatchReq : WavelengthMatch;

        satisfy shortRangeReq by deviceA.maxDistance;
        satisfy shortRangeReq by deviceB.maxDistance;
        satisfy lineOfSightReq by deviceA.led.coneAngle;
        satisfy lineOfSightReq by deviceB.led.coneAngle;
        satisfy wavelengthMatchReq by deviceA.led.wavelength;
        satisfy wavelengthMatchReq by deviceA.photodetector.sensitivity;
    }
}
