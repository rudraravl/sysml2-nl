package HomePlugNetworkingSystem {
    private import ScalarValues::Integer;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    private import ScalarValues::Real;

    attribute def Voltage :> Real;
    attribute def Current :> Real;
    attribute def Frequency :> Real;

    item def EthernetPacket {
        attribute sourceMAC : String;
        attribute destMAC : String;
        attribute payload : String;
    }

    item def PowerlineSignal {
        attribute frequencyBand : String = "2-30 MHz";
        attribute modulationScheme : String = "OFDM";
    }

    item def ACPower {
        attribute voltage : Voltage = 120;
        attribute frequency : Frequency = 60;
    }

    item def DCPower {
        attribute voltage : Voltage = 12;
        attribute current : Current;
    }

    attribute def EncryptionKey {
        attribute keyValue : String;
        attribute algorithm : String = "AES-128";
    }

    attribute def MACAddress {
        attribute address : String;
    }

    port def EthernetPort {
        in item rxPacket : EthernetPacket;
        out item txPacket : EthernetPacket;
    }

    port def PowerlinePort {
        in item rxSignal : PowerlineSignal;
        out item txSignal : PowerlineSignal;
    }

    port def ACPowerPort {
        in item power : ACPower;
    }

    port def DCPowerPort {
        out item power : DCPower;
    }

    connection def EthernetLink {
        end port end1 : EthernetPort;
        end port end2 : EthernetPort;
    }

    connection def PowerlineLink {
        end port end1 : PowerlinePort;
        end port end2 : PowerlinePort;
    }

    part def PowerManagement {
        port acIn : ACPowerPort;
        port dcOut : DCPowerPort;
        attribute inputVoltage : Voltage = 120;
        attribute outputVoltage : Voltage = 12;
        action convertACtoDC {
            in item ac : ACPower;
            out item dc : DCPower;
        }
    }

    part def SecurityModule {
        port dcIn : DCPowerPort;
        attribute sharedKey : EncryptionKey;
        action encrypt {
            in item plainData : EthernetPacket;
            out item encryptedData : EthernetPacket;
        }
        action decrypt {
            in item encryptedData : EthernetPacket;
            out item plainData : EthernetPacket;
        }
    }

    part def MACLayer {
        port dcIn : DCPowerPort;
        attribute macAddress : MACAddress;
        action addressPacket {
            in item data : EthernetPacket;
            out item addressedData : EthernetPacket;
        }
        action filterPacket {
            in item data : EthernetPacket;
            out item filteredData : EthernetPacket;
        }
    }

    part def PHYModule {
        port dcIn : DCPowerPort;
        attribute operatingBand : String = "2-30 MHz";
        action modulate {
            in item digitalData : EthernetPacket;
            out item analogSignal : PowerlineSignal;
        }
        action demodulate {
            in item analogSignal : PowerlineSignal;
            out item digitalData : EthernetPacket;
        }
    }

    action def PowerOnSelfTest;
    action def InitializeHardware;
    action def TransmitData;
    action def ReceiveData;

    state machine def AdapterStateMachine {
        state Initializing {
            entry action powerOnSelfTest : PowerOnSelfTest;
            do action initializeHardware : InitializeHardware;
        }
        state Idle;
        state Transmitting {
            do action transmitData : TransmitData;
        }
        state Receiving {
            do action receiveData : ReceiveData;
        }

        transition init_to_idle from Initializing to Idle;
        transition idle_to_tx from Idle to Transmitting;
        transition tx_to_idle from Transmitting to Idle;
        transition idle_to_rx from Idle to Receiving;
        transition rx_to_idle from Receiving to Idle;
    }

    part def HomePlugAdapter {
        port ethPort : EthernetPort;
        port powerlinePort : PowerlinePort;
        port acPort : ACPowerPort;

        part powerMgmt : PowerManagement;
        part phy : PHYModule;
        part mac : MACLayer;
        part security : SecurityModule;

        connect acPort to powerMgmt.acIn;
        connect powerMgmt.dcOut to phy.dcIn;
        connect powerMgmt.dcOut to mac.dcIn;
        connect powerMgmt.dcOut to security.dcIn;

        flow EthernetPacket from ethPort.rxPacket to security.encrypt.plainData;
        flow EthernetPacket from security.encrypt.encryptedData to mac.addressPacket.data;
        flow EthernetPacket from mac.addressPacket.addressedData to phy.modulate.digitalData;
        flow PowerlineSignal from phy.modulate.analogSignal to powerlinePort.txSignal;

        flow PowerlineSignal from powerlinePort.rxSignal to phy.demodulate.analogSignal;
        flow EthernetPacket from phy.demodulate.digitalData to security.decrypt.encryptedData;
        flow EthernetPacket from security.decrypt.plainData to mac.filterPacket.data;
        flow EthernetPacket from mac.filterPacket.filteredData to ethPort.txPacket;

        state machine adapterState : AdapterStateMachine;
    }

    part def ElectricalWiring {
        attribute wireCount : Integer = 3;
        attribute totalOutlets : Integer;
        port linePort : PowerlinePort [*];
    }

    part def Router {
        port ethPort : EthernetPort;
        attribute ssid : String;
    }

    part def EndDevice {
        port ethPort : EthernetPort;
        attribute deviceName : String;
    }

    part def Computer :> EndDevice {
        attribute deviceName : String = "PC";
    }

    part def SmartTV :> EndDevice {
        attribute deviceName : String = "SmartTV";
    }

    part HomeNetwork {
        part router : Router;
        part adapter1 : HomePlugAdapter;
        part adapter2 : HomePlugAdapter;
        part device : SmartTV;
        part wiring : ElectricalWiring;

        connection ethLink1 : EthernetLink {
            end end1 ::> router.ethPort;
            end end2 ::> adapter1.ethPort;
        }
        connection plLink1 : PowerlineLink {
            end end1 ::> adapter1.powerlinePort;
            end end2 ::> wiring.linePort;
        }
        connection plLink2 : PowerlineLink {
            end end1 ::> adapter2.powerlinePort;
            end end2 ::> wiring.linePort;
        }
        connection ethLink2 : EthernetLink {
            end end1 ::> adapter2.ethPort;
            end end2 ::> device.ethPort;
        }
    }

    requirement def SecureCommunication {
        doc /* All data transmitted over the powerline shall be encrypted using a shared key. */
        attribute requiredKey : EncryptionKey;
    }

    requirement def NetworkConnectivity {
        doc /* The system shall enable Ethernet devices to communicate over existing electrical wiring using at least two HomePlug adapters. */
        attribute minAdapters : Integer = 2;
    }

    requirement def AvoidInterference {
        doc /* The powerline signal shall use the frequency band 2-30 MHz to avoid interfering with standard AC power. */
        attribute minFreq : Frequency = 2.0;
        attribute maxFreq : Frequency = 30.0;
    }

    requirement def PowerConversion {
        doc /* The Power Management unit shall convert 120V AC power to 12V DC power for adapter electronics. */
        attribute inputAC : Voltage = 120;
        attribute outputDC : Voltage = 12;
    }

    requirement secureCommReq : SecureCommunication;
    requirement connectivityReq : NetworkConnectivity;
    requirement interferenceReq : AvoidInterference;
    requirement powerReq : PowerConversion;

    satisfy secureCommReq by HomePlugAdapter::security;
    satisfy interferenceReq by HomePlugAdapter::phy;
    satisfy powerReq by HomePlugAdapter::powerMgmt;
    satisfy connectivityReq by HomeNetwork;
}
