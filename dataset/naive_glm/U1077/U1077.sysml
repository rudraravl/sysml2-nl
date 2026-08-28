package HomePlugSystem {
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    value type FrequencyMHz :> Real {
        doc { Frequency value in megahertz (MHz). }
    }
    value type VoltageV :> Real {
        doc { Voltage value in volts (V). }
    }
    value type PowerW :> Real {
        doc { Power value in watts (W). }
    }
    value type DataRateMbps :> Real {
        doc { Data rate value in megabits per second (Mbps). }
    }
    value type TimeMs :> Real {
        doc { Time value in milliseconds (ms). }
    }

    // ===== Item Definitions =====
    item def EthernetFrame {
        attribute payload : String;
        attribute frameSize : Integer;
    }

    item def AddressedFrame {
        attribute destMAC : String;
        attribute srcMAC : String;
        attribute payload : String;
        attribute frameSize : Integer;
    }

    item def EncryptedFrame {
        attribute destMAC : String;
        attribute srcMAC : String;
        attribute encryptedPayload : String;
        attribute frameSize : Integer;
    }

    item def PowerlineSignal {
        attribute frame : EncryptedFrame;
        attribute frequency : FrequencyMHz;
        attribute signalStrength : Real;
    }

    item def ACLinePower {
        attribute voltage : VoltageV;
        attribute frequency : FrequencyMHz;
    }

    item def DCPower {
        attribute voltage : VoltageV;
        attribute current : Real;
    }

    // ===== Port Definitions =====
    port def EthernetPortDef {
        in frame : EthernetFrame;
        out frame : EthernetFrame;
    }

    port def AddressedFramePortDef {
        in frame : AddressedFrame;
        out frame : AddressedFrame;
    }

    port def EncryptedFramePortDef {
        in frame : EncryptedFrame;
        out frame : EncryptedFrame;
    }

    port def PowerlineSignalPortDef {
        in signal : PowerlineSignal;
        out signal : PowerlineSignal;
    }

    port def ACInputPortDef {
        in power : ACLinePower;
    }

    port def ACOutletPortDef {
        out power : ACLinePower;
    }

    port def DCInputPortDef {
        in power : DCPower;
    }

    port def DCOutputPortDef {
        out power : DCPower;
    }

    // ===== Requirements =====
    requirement def NetworkCreationReq {
        doc {
            The HomePlug system shall create a local area network
            using existing electrical wiring, with at least two
            HomePlug adapters.
        }
        attribute minAdapters : Integer = 2;
    }

    requirement def FrequencyBandReq {
        doc {
            The PHY module shall transmit powerline signals in the
            2-30 MHz band to avoid interfering with standard AC power.
        }
        attribute minFrequency : FrequencyMHz = 2.0;
        attribute maxFrequency : FrequencyMHz = 30.0;
    }

    requirement def SecurityReq {
        doc {
            The Security module shall encrypt all data transmitted
            over the powerline using a shared AES-128 key to prevent
            eavesdropping and unauthorized access.
        }
        attribute encryptionStandard : String = "AES-128";
    }

    requirement def MACAddressingReq {
        doc {
            The MAC layer shall handle network addressing to ensure
            data is sent to the correct adapter on the powerline network.
        }
    }

    requirement def PowerConversionReq {
        doc {
            The Power Management unit shall convert AC wall power
            into DC power for the adapter's internal electronics.
        }
        attribute inputVoltage : VoltageV = 120.0;
        attribute outputDCVoltage : VoltageV = 12.0;
    }

    requirement def NoNewCablesReq {
        doc {
            The system shall allow network connections between
            devices without running new Ethernet cables through the house.
        }
    }

    // ===== Internal Module Definitions =====

    part def PowerManagement {
        attribute inputACVoltage : VoltageV = 120.0;
        attribute outputDCVoltage : VoltageV = 12.0;
        attribute conversionEfficiency : Real = 0.85;
        attribute maxOutputPower : PowerW = 5.0;

        port acIn : ACInputPortDef;
        port dcOut : DCOutputPortDef;

        action convertACtoDC {
            in ac : ACLinePower;
            out dc : DCPower;
        }
    }

    part def PHYModule {
        attribute minFrequency : FrequencyMHz = 2.0;
        attribute maxFrequency : FrequencyMHz = 30.0;
        attribute modulationScheme : String = "OFDM";
        attribute maxDataRate : DataRateMbps = 500.0;
        attribute signalGain : Real = 10.0;

        port signalPort : PowerlineSignalPortDef;
        port dcIn : DCInputPortDef;
        port dataPort : EncryptedFramePortDef;

        action modulate {
            in frame : EncryptedFrame;
            out signal : PowerlineSignal;
        }

        action demodulate {
            in signal : PowerlineSignal;
            out frame : EncryptedFrame;
        }
    }

    part def MACModule {
        attribute macAddress : String;
        attribute addressTable : String[0..*];

        port dcIn : DCInputPortDef;
        port ethPort : EthernetPortDef;
        port macPort : AddressedFramePortDef;

        action addMACAddress {
            in frame : EthernetFrame;
            out addressedFrame : AddressedFrame;
        }

        action extractPayload {
            in addressedFrame : AddressedFrame;
            out frame : EthernetFrame;
        }
    }

    part def SecurityModule {
        attribute sharedKey : String;
        attribute encryptionStandard : String = "AES-128";
        attribute keyLength : Integer = 128;

        port dcIn : DCInputPortDef;
        port plainPort : AddressedFramePortDef;
        port cipherPort : EncryptedFramePortDef;

        action encrypt {
            in plain : AddressedFrame;
            out cipher : EncryptedFrame;
        }

        action decrypt {
            in cipher : EncryptedFrame;
            out plain : AddressedFrame;
        }
    }

    // ===== HomePlug Adapter =====
    part def HomePlugAdapter {
        attribute macAddress : String;
        attribute networkKey : String;
        attribute isInitialized : Boolean = false;
        attribute hasDataToSend : Boolean = false;
        attribute signalDetected : Boolean = false;
        attribute transmitComplete : Boolean = false;
        attribute receiveComplete : Boolean = false;

        port ethPort : EthernetPortDef;
        port powerlineSignalPort : PowerlineSignalPortDef;
        port acInlet : ACInputPortDef;

        part powerMgmt : PowerManagement;
        part phy : PHYModule;
        part mac : MACModule;
        part security : SecurityModule;

        // AC power from wall to power management
        connection pwAc connect acInlet to powerMgmt.acIn;

        // DC power distribution to internal modules
        connection pwDc1 connect powerMgmt.dcOut to phy.dcIn;
        connection pwDc2 connect powerMgmt.dcOut to mac.dcIn;
        connection pwDc3 connect powerMgmt.dcOut to security.dcIn;

        // Data path: Ethernet <-> MAC <-> Security <-> PHY <-> Powerline
        connection dpEth1 connect ethPort to mac.ethPort;
        connection dpMac1 connect mac.macPort to security.plainPort;
        connection dpSec1 connect security.cipherPort to phy.dataPort;
        connection dpPhy1 connect phy.signalPort to powerlineSignalPort;

        // State machine for adapter lifecycle
        stateMachine adapterState {
            initial;
            state Initializing;
            state Idle;
            state Transmitting;
            state Receiving;

            transition from initial to Initializing;
            transition from Initializing to Idle when this.isInitialized;
            transition from Idle to Transmitting when this.hasDataToSend;
            transition from Transmitting to Idle when this.transmitComplete;
            transition from Idle to Receiving when this.signalDetected;
            transition from Receiving to Idle when this.receiveComplete;
        }

        // Transmit sequence action: encrypt, modulate, send
        action transmitSequence {
            in ethFrame : EthernetFrame;
            out powerlineSignal : PowerlineSignal;
        }

        // Receive sequence action: demodulate, decrypt, send to device
        action receiveSequence {
            in powerlineSignal : PowerlineSignal;
            out ethFrame : EthernetFrame;
        }
    }

    // ===== External Parts =====

    part def WallOutlet {
        attribute outletId : String;
        attribute room : String;
        port acOutput : ACOutletPortDef;
        port powerlinePort : PowerlineSignalPortDef;
    }

    part def ElectricalWiring {
        attribute numOutlets : Integer = 4;
        attribute wireMaterial : String = "copper";
        attribute totalWireLength : Real;

        part livingRoomOutlet : WallOutlet;
        part officeOutlet : WallOutlet;
        part bedroomOutlet : WallOutlet;
        port powerlineConduit : PowerlineSignalPortDef;

        // Internal wiring connects all outlets through the powerline conduit
        connection wr1 connect livingRoomOutlet.powerlinePort to powerlineConduit;
        connection wr2 connect officeOutlet.powerlinePort to powerlineConduit;
        connection wr3 connect bedroomOutlet.powerlinePort to powerlineConduit;
    }

    part def NetworkDevice {
        attribute deviceName : String;
        attribute macAddress : String;
        port ethPort : EthernetPortDef;
    }

    part def InternetRouter {
        attribute deviceName : String = "Internet Gateway";
        attribute macAddress : String;
        attribute wanConnected : Boolean = true;
        port ethPort : EthernetPortDef;
    }

    // ===== Top-Level System =====
    part def HomePlugSystem {
        attribute networkName : String = "HomeLAN";
        attribute adapterCount : Integer = 2;

        part internetRouter : InternetRouter;
        part routerAdapter : HomePlugAdapter;
        part deviceAdapter : HomePlugAdapter;
        part smartTV : NetworkDevice;
        part electricalWiring : ElectricalWiring;

        // Connect internet router to router adapter via Ethernet
        connection sysEth1 connect internetRouter.ethPort to routerAdapter.ethPort;

        // Connect adapters to electrical wiring for powerline communication
        connection sysPL1 connect routerAdapter.powerlineSignalPort to electricalWiring.powerlineConduit;
        connection sysPL2 connect deviceAdapter.powerlineSignalPort to electricalWiring.powerlineConduit;

        // Connect device adapter to smart TV via Ethernet
        connection sysEth2 connect deviceAdapter.ethPort to smartTV.ethPort;

        // AC power to adapters from wall outlets
        connection sysAc1 connect electricalWiring.livingRoomOutlet.acOutput to routerAdapter.acInlet;
        connection sysAc2 connect electricalWiring.bedroomOutlet.acOutput to deviceAdapter.acInlet;
    }

    // ===== Requirement Satisfaction =====
    satisfy NetworkCreationReq by HomePlugSystem;
    satisfy NoNewCablesReq by HomePlugSystem;
    satisfy FrequencyBandReq by PHYModule;
    satisfy SecurityReq by SecurityModule;
    satisfy MACAddressingReq by MACModule;
    satisfy PowerConversionReq by PowerManagement;
}
