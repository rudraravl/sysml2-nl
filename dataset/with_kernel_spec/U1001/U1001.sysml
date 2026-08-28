package BLECommunicationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def BLE_Packet;
    item def SensorData {
        attribute temperature : Real [K];
        attribute humidity : Real [1];
        attribute batteryLevel : Real [1];
    }
    item def AdvertisingData {
        attribute deviceName : String;
        attribute serviceUUID : String;
    }

    port def RadioPort {
        in item rxPacket : BLE_Packet;
        out item txPacket : BLE_Packet;
    }
    port def HostPort {
        in item command : String;
        out item evt : String;
    }
    port def GATTPort {
        in item readRequest : String;
        out item notification : SensorData;
    }

    requirement def LowPowerRequirement {
        doc /* Peripheral device average power consumption shall not exceed 10 mW during active transmission and 10 µW in sleep mode. */
        attribute maxActivePower : Real = 0.01;
        attribute maxSleepPower : Real = 0.00001;
    }

    requirement def MultiConnectionRequirement {
        doc /* The central gateway shall support simultaneous connections to a maximum of seven peripheral devices. */
        attribute maxPeripherals : Integer = 7;
    }

    requirement def SecurityRequirement {
        doc /* All data exchanges shall be secured using AES-CCM encryption with authenticated pairing. */
        attribute encryptionStandard : String = "AES-CCM";
        attribute minKeyLength : Integer = 128;
    }

    requirement def FrequencyBandRequirement {
        doc /* The system shall operate in the 2.4 GHz ISM band. */
        attribute operatingFrequency : Real = 2.4e9;
    }

    part def PhysicalRadio {
        attribute frequency : Real = 2.4e9;
        attribute txPower : Real;
        attribute txRequest : Boolean = false;
        attribute rxRequest : Boolean = false;
        attribute txComplete : Boolean = false;
        attribute rxComplete : Boolean = false;
        port radioPort : RadioPort;

        state radioState {
            state idle;
            state transmitting;
            state receiving;
            transition t1 : idle -> transmitting when txRequest;
            transition t2 : idle -> receiving when rxRequest;
            transition t3 : transmitting -> idle when txComplete;
            transition t4 : receiving -> idle when rxComplete;
        }
    }

    part def LinkLayer {
        attribute deviceAddress : String;
        attribute connectionInterval : Real;
        port radioPort : ~RadioPort;
        port hostPort : HostPort;
    }

    part def HostController {
        port linkPort : ~HostPort;
        port appPort : HostPort;
    }

    part def RoleManager {
        attribute role : String;
        attribute initiateConnection : Boolean = false;
    }

    part def GATTManager {
        attribute services : String[*];
        port hostPort : ~HostPort;
        port gattPort : GATTPort;
    }

    part def SecurityManager {
        attribute paired : Boolean = false;
        attribute encrypted : Boolean = false;
        attribute encryptionKey : String;
        port hostPort : ~HostPort;
    }

    part def BLE_Device {
        part physicalRadio : PhysicalRadio;
        part linkLayer : LinkLayer;
        part hostController : HostController;
        part roleManager : RoleManager;
        part gattManager : GATTManager;
        part securityManager : SecurityManager;

        connect physicalRadio.radioPort to linkLayer.radioPort;
        connect linkLayer.hostPort to hostController.linkPort;
        connect hostController.appPort to gattManager.hostPort;
        connect hostController.appPort to securityManager.hostPort;
    }

    part def BLE_SensorNode :> BLE_Device {
        attribute power : Real;
        attribute batteryCapacity : Real;
        attribute connectionRequest : Boolean = false;
        attribute linkEstablished : Boolean = false;
        attribute disconnectReceived : Boolean = false;
        attribute timeout : Boolean = false;
        attribute wakeUpTimer : Boolean = false;
        item collectedData : SensorData;

        satisfy LowPowerRequirement;
        satisfy SecurityRequirement;
        satisfy FrequencyBandRequirement;

        state peripheralBehavior {
            state advertising {
                entry / send new BLE_Packet() to physicalRadio.radioPort;
            }
            state connecting;
            state connected {
                entry / send new SensorData() to gattManager.gattPort;
            }
            state sleep;

            transition t1 : advertising -> connecting when connectionRequest;
            transition t2 : connecting -> connected when linkEstablished;
            transition t3 : connected -> advertising when disconnectReceived;
            transition t4 : advertising -> sleep when timeout;
            transition t5 : sleep -> advertising when wakeUpTimer;
        }
    }

    part def BLE_Gateway :> BLE_Device {
        attribute maxConnections : Integer = 7;
        attribute activeConnections : Integer = 0;
        attribute targetDeviceFound : Boolean = false;
        attribute connectionAccepted : Boolean = false;
        attribute dataAvailable : Boolean = false;
        attribute allDataProcessed : Boolean = false;

        satisfy MultiConnectionRequirement;
        satisfy SecurityRequirement;
        satisfy FrequencyBandRequirement;

        state gatewayBehavior {
            state scanning;
            state connecting;
            state connected;
            state dataProcessing;

            transition t1 : scanning -> connecting when targetDeviceFound;
            transition t2 : connecting -> connected when connectionAccepted;
            transition t3 : connected -> dataProcessing when dataAvailable;
            transition t4 : dataProcessing -> scanning when allDataProcessed;
        }
    }

    connection def BLE_Connection {
        attribute frequency : Real = 2.4e9;
        attribute encryptionEnabled : Boolean = true;
        end peripheralEnd : RadioPort;
        end centralEnd : ~RadioPort;
    }

    part bleSystem {
        part gateway : BLE_Gateway;
        part sensorNode1 : BLE_SensorNode;
        part sensorNode2 : BLE_SensorNode;

        connection link1 : BLE_Connection connect sensorNode1.physicalRadio.radioPort to gateway.physicalRadio.radioPort;
        connection link2 : BLE_Connection connect sensorNode2.physicalRadio.radioPort to gateway.physicalRadio.radioPort;
    }
}
