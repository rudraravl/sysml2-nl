package BLE_Communication_System {
    import ScalarValues::*;

    // ===== Units =====
    unit mW;
    unit GHz;
    unit ms;
    unit degC;
    unit percent;
    unit V;
    unit byte;
    unit dBm;
    unit hour;

    // ===== Value Types =====
    attribute def Power :> Real { unit mW; }
    attribute def TxPower :> Real { unit dBm; }
    attribute def Frequency :> Real { unit GHz; }
    attribute def TimeDuration :> Real { unit ms; }
    attribute def OperationalLife :> Real { unit hour; }
    attribute def Temperature :> Real { unit degC; }
    attribute def Humidity :> Real { unit percent; }
    attribute def BatteryLevel :> Real { unit percent; }
    attribute def Voltage :> Real { unit V; }
    attribute def DataSize :> Real { unit byte; }

    // ===== Structured Data (Attributes) =====
    attribute def SecurityKey {
        attribute keyId : String;
        attribute keyValue : String;
        attribute length : DataSize = 16;
    }

    attribute def ServiceDescriptor {
        attribute serviceName : String;
        attribute serviceUUID : String;
        attribute characteristicUUIDs : String[0..*];
    }

    // ===== Items (Flow Payloads) =====
    item def SensorData {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
        attribute batteryLevel : BatteryLevel;
        attribute timestamp : TimeDuration;
    }

    item def AdvertisementPacket {
        attribute deviceName : String;
        attribute serviceUUID : String;
        attribute txPower : TxPower;
        attribute advInterval : TimeDuration;
    }

    item def DataPacket {
        attribute payload : SensorData;
        attribute sequenceNumber : Integer;
        attribute encrypted : Boolean;
        attribute checksum : Integer;
    }

    item def ControlCommand {
        attribute commandType : String;
        attribute parameter : String;
    }

    item def ConnectionRequest {
        attribute initiatorAddress : String;
        attribute targetAddress : String;
        attribute interval : TimeDuration;
    }

    item def PairingRequest {
        attribute deviceAddress : String;
        attribute capability : String;
    }

    // ===== Ports =====
    port def RadioPort {
        inout item advertisement : AdvertisementPacket;
        inout item data : DataPacket;
        inout item connectionReq : ConnectionRequest;
    }

    port def HostPort {
        in item command : ControlCommand;
        out item event : String;
        out item data : DataPacket;
    }

    port def InternalPort {
        inout item command : ControlCommand;
        inout item event : String;
        inout item data : DataPacket;
        inout item pairing : PairingRequest;
    }

    // ===== Layered Architecture: Physical Radio =====
    part def PhysicalRadio {
        attribute frequency : Frequency = 2.4;
        attribute txPower : TxPower = -10;
        attribute channel : Integer = 37;
        port radioInterface : RadioPort;
        port upperInterface : InternalPort;

        exhibit {
            entry; then Idle;
            state Idle;
            state Transmitting {
                entry / send radioInterface.advertisement;
            }
            state Receiving {
                entry / accept radioInterface.data;
            }
            transition from Idle to Transmitting when txTrigger;
            transition from Transmitting to Idle when txComplete;
            transition from Idle to Receiving when rxTrigger;
            transition from Receiving to Idle when rxComplete;
        }
    }

    // ===== Layered Architecture: Link Layer =====
    part def LinkLayer {
        attribute deviceAddress : String;
        attribute connectionInterval : TimeDuration = 30;
        attribute slaveLatency : Integer = 0;
        attribute supervisionTimeout : TimeDuration = 6000;
        port upper : InternalPort;
        port lower : RadioPort;

        exhibit {
            entry; then Standby;
            state Standby;
            state Advertising {
                entry / send lower.advertisement;
            }
            state Scanning {
                entry / accept lower.advertisement;
            }
            state Initiating {
                entry / send lower.connectionReq;
            }
            state Connected;
            transition from Standby to Advertising when startAdv;
            transition from Advertising to Connected when connectionReq;
            transition from Standby to Scanning when startScan;
            transition from Scanning to Initiating when deviceFound;
            transition from Initiating to Connected when connectionAck;
            transition from Connected to Standby when disconnect;
        }
    }

    // ===== Layered Architecture: Host Controller =====
    part def HostController {
        port upper : HostPort;
        port lower : InternalPort;
        attribute pendingCommands : Integer = 0;

        exhibit {
            entry; then Ready;
            state Ready;
            state Processing {
                entry / accept lower.command;
            }
            state Dispatching {
                entry / send lower.event;
            }
            transition from Ready to Processing when commandReceived;
            transition from Processing to Dispatching when commandParsed;
            transition from Dispatching to Ready when eventSent;
        }
    }

    // ===== Layered Architecture: Role Manager =====
    part def RoleManager {
        attribute role : String;
        port host : InternalPort;

        exhibit {
            entry; then Inactive;
            state Inactive;
            state Peripheral;
            state Central;
            transition from Inactive to Peripheral when setPeripheral;
            transition from Inactive to Central when setCentral;
        }
    }

    // ===== Layered Architecture: GATT Manager =====
    part def GATTManager {
        attribute services : ServiceDescriptor[0..*];
        port host : InternalPort;

        exhibit {
            entry; then Uninitialized;
            state Uninitialized;
            state Configured;
            state Serving;
            transition from Uninitialized to Configured when servicesDefined;
            transition from Configured to Serving when connectionUp;
            transition from Serving to Configured when connectionDown;
        }
    }

    // ===== Layered Architecture: Security Manager =====
    part def SecurityManager {
        attribute paired : Boolean = false;
        attribute encrypted : Boolean = false;
        attribute key : SecurityKey;
        port host : InternalPort;

        exhibit {
            entry; then Unpaired;
            state Unpaired;
            state Pairing {
                entry / accept host.pairing;
            }
            state Paired;
            state Encrypting {
                entry / generateKey;
            }
            state Encrypted;
            transition from Unpaired to Pairing when pairRequest;
            transition from Pairing to Paired when pairSuccess;
            transition from Paired to Encrypting when enableEncryption;
            transition from Encrypting to Encrypted when keyGenerated;
            transition from Encrypted to Paired when disableEncryption;
        }

        action generateKey {
            in out key : SecurityKey;
        }
    }

    // ===== Sensors =====
    part def TemperatureSensor {
        attribute reading : Temperature = 22.0;
        exhibit {
            entry; then Idle;
            state Idle;
            state Sampling {
                entry / sample;
            }
            transition from Idle to Sampling when sampleTrigger;
            transition from Sampling to Idle when sampleDone;
        }
        action sample;
    }

    part def HumiditySensor {
        attribute reading : Humidity = 45.0;
        exhibit {
            entry; then Idle;
            state Idle;
            state Sampling {
                entry / sample;
            }
            transition from Idle to Sampling when sampleTrigger;
            transition from Sampling to Idle when sampleDone;
        }
        action sample;
    }

    part def BatteryMonitor {
        attribute voltage : Voltage = 3.0;
        attribute level : BatteryLevel = 100;
        exhibit {
            entry; then Monitoring;
            state Monitoring;
            state LowBattery;
            transition from Monitoring to LowBattery when level < 20;
            transition from LowBattery to Monitoring when level >= 20;
        }
    }

    // ===== Base BLE Device =====
    part def BLEDevice {
        attribute deviceName : String;
        port radioPort : RadioPort;
        port hostPort : HostPort;

        part physicalRadio : PhysicalRadio;
        part linkLayer : LinkLayer;
        part hostController : HostController;
        part roleManager : RoleManager;
        part gattManager : GATTManager;
        part securityManager : SecurityManager;

        connection radioInternal connect physicalRadio.upperInterface to linkLayer.lower;
        connection hostInternal connect hostController.lower to linkLayer.upper;
        connection roleInternal connect roleManager.host to hostController.lower;
        connection gattInternal connect gattManager.host to hostController.lower;
        connection securityInternal connect securityManager.host to hostController.lower;
        connection radioDelegation connect physicalRadio.radioInterface to radioPort;
        connection hostDelegation connect hostController.upper to hostPort;
    }

    // ===== Peripheral Device: BLE Sensor Node =====
    part def PeripheralDevice :> BLEDevice {
        attribute deviceName : String = "BLE_Sensor_Node";
        attribute batteryVoltage : Voltage = 3.0;
        attribute batteryLevel : BatteryLevel = 100;
        attribute powerConsumption : Power = 12.0;
        attribute operationalLife : OperationalLife = 8760;
        attribute advInterval : TimeDuration = 100;

        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part batteryMonitor : BatteryMonitor;

        exhibit {
            entry; then PoweredOff;
            state PoweredOff;
            state Initializing {
                entry / initSensors;
            }
            state Advertising {
                entry / send radioPort.advertisement;
            }
            state Connected;
            state DataExchange {
                entry / send radioPort.data;
            }
            state Sleeping;
            transition from PoweredOff to Initializing when powerOn;
            transition from Initializing to Advertising when initComplete;
            transition from Advertising to Connected when connectionEstablished;
            transition from Connected to DataExchange when dataRequested;
            transition from DataExchange to Sleeping when dataSent;
            transition from Sleeping to Advertising when wakeUp;
            transition from Advertising to Sleeping when advTimeout;
        }

        action initSensors;
    }

    // ===== Central Device: BLE Gateway =====
    part def CentralDevice :> BLEDevice {
        attribute deviceName : String = "BLE_Gateway";
        attribute maxConnections : Integer = 7;
        attribute activeConnections : Integer = 0;
        attribute connectedDevices : String[0..7];
        attribute scanWindow : TimeDuration = 200;

        exhibit {
            entry; then PoweredOff;
            state PoweredOff;
            state Initializing;
            state Scanning {
                entry / accept radioPort.advertisement;
            }
            state Connecting {
                entry / send radioPort.connectionReq;
            }
            state Connected;
            state Managing {
                entry / accept radioPort.data;
            }
            transition from PoweredOff to Initializing when powerOn;
            transition from Initializing to Scanning when initComplete;
            transition from Scanning to Connecting when deviceDiscovered;
            transition from Connecting to Connected when connectionEstablished;
            transition from Connected to Managing when ready;
            transition from Managing to Scanning when scanMore;
            transition from Managing to Connected when dataReceived;
        }
    }

    // ===== System =====
    part def BLESystem {
        attribute systemName : String = "BLE_IoT_Network";
        attribute operatingFrequency : Frequency = 2.4;
        attribute maxNodes : Integer = 7;

        part gateway : CentralDevice;
        part sensorNodes : PeripheralDevice[1..7];

        connection def RadioLink {
            end sensorEnd : RadioPort;
            end gatewayEnd : RadioPort;
        }

        connection radioLinks : RadioLink[*] connect sensorNodes.radioPort to gateway.radioPort;
    }

    // ===== Requirements =====
    requirement def PowerEfficiencyRequirement {
        doc "The peripheral device shall operate with strict power constraints to ensure long battery life of months to years.";
        subject peripheralDevice : PeripheralDevice;
        attribute maxPowerConsumption : Power = 15;
        attribute minOperationalLife : OperationalLife = 4380;
        constraint { peripheralDevice.powerConsumption <= maxPowerConsumption }
        constraint { peripheralDevice.operationalLife >= minOperationalLife }
    }

    requirement def ConnectionCapacityRequirement {
        doc "The central gateway shall manage up to seven simultaneous peripheral connections.";
        subject centralDevice : CentralDevice;
        attribute maxConnections : Integer = 7;
        constraint { centralDevice.activeConnections <= maxConnections }
    }

    requirement def SecurityRequirement {
        doc "All data exchange between connected devices shall be secured with authentication and encryption.";
        subject securityManager : SecurityManager;
        constraint { securityManager.encrypted == true }
        constraint { securityManager.paired == true }
    }

    requirement def AdvertisingRequirement {
        doc "The peripheral device shall periodically broadcast advertisement packets announcing its presence and services.";
        subject peripheralDevice : PeripheralDevice;
        attribute advInterval : TimeDuration = 100;
        constraint { peripheralDevice.advInterval <= advInterval }
    }

    requirement def FrequencyRequirement {
        doc "The physical radio shall operate in the 2.4 GHz ISM band.";
        subject physicalRadio : PhysicalRadio;
        attribute operatingFrequency : Frequency = 2.4;
        constraint { physicalRadio.frequency == operatingFrequency }
    }

    requirement def DataExchangeRequirement {
        doc "Connected devices shall exchange structured sensor data packets containing temperature, humidity, and battery level.";
        subject peripheralDevice : PeripheralDevice;
        constraint { peripheralDevice.temperatureSensor.reading.isDefined }
        constraint { peripheralDevice.humiditySensor.reading.isDefined }
        constraint { peripheralDevice.batteryMonitor.level.isDefined }
    }

    requirement def LayeredArchitectureRequirement {
        doc "Each BLE device shall implement physical radio, link layer, host controller, role manager, GATT manager, and security manager layers.";
        subject device : BLEDevice;
        constraint { device.physicalRadio.isDefined }
        constraint { device.linkLayer.isDefined }
        constraint { device.hostController.isDefined }
        constraint { device.roleManager.isDefined }
        constraint { device.gattManager.isDefined }
        constraint { device.securityManager.isDefined }
    }

    // ===== Requirement Satisfaction =====
    part def BLE_System_Specification {
        part system : BLESystem;

        satisfy PowerEfficiencyRequirement by system.sensorNodes;
        satisfy ConnectionCapacityRequirement by system.gateway;
        satisfy SecurityRequirement by system.sensorNodes.securityManager;
        satisfy SecurityRequirement by system.gateway.securityManager;
        satisfy AdvertisingRequirement by system.sensorNodes;
        satisfy FrequencyRequirement by system.sensorNodes.physicalRadio;
        satisfy FrequencyRequirement by system.gateway.physicalRadio;
        satisfy DataExchangeRequirement by system.sensorNodes;
        satisfy LayeredArchitectureRequirement by system.sensorNodes;
        satisfy LayeredArchitectureRequirement by system.gateway;
    }
}
