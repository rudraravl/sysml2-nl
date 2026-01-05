package HomeySmartHomeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    enum def DeviceStatus {
        offline;
        online;
        pairing;
        error;
    }

    enum def ProtocolType {
        zigbee;
        zwave;
        wifi;
        bluetooth;
        infrared;
    }

    enum def AutomationTrigger {
        timeScheduled;
        sensorEvent;
        userCommand;
        conditionMet;
    }

    attribute def DeviceID :> String;
    attribute def ZoneID :> String;

    attribute def ResponseTime :> TimeValue;
    attribute def DataThroughput :> Real;

    item def SensorReading {
        attribute timestamp : String;
        attribute value : Real;
        attribute unit : String;
    }

    item def DeviceCommand {
        attribute targetID : DeviceID;
        attribute action : String;
        attribute parameters : Real[0..*];
    }

    item def AutomationRule {
        attribute ruleID : String;
        attribute trigger : AutomationTrigger;
        attribute conditions : String[0..*];
        attribute actions : DeviceCommand[1..*];
        attribute enabled : Boolean;
    }

    item def SmartDevice {
        attribute deviceID : DeviceID;
        attribute deviceName : String;
        attribute status : DeviceStatus;
        attribute protocol : ProtocolType;
        attribute powerDraw : PowerValue;
    }

    item def SmartLight :> SmartDevice {
        attribute brightness : Real;
        attribute colorTemp : Real;
        attribute isOn : Boolean;
    }

    item def TemperatureSensor :> SmartDevice {
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
    }

    item def MotionSensor :> SmartDevice {
        attribute motionDetected : Boolean;
        attribute lastTrigger : String;
    }

    item def SmartThermostat :> SmartDevice {
        attribute targetTemp : TemperatureValue;
        attribute currentTemp : TemperatureValue;
        attribute mode : String;
    }

    item def DoorLock :> SmartDevice {
        attribute locked : Boolean;
        attribute batteryLevel : Real;
    }

    port def WirelessPort {
        attribute protocol : ProtocolType;
        attribute signalStrength : Real;
    }

    port def NetworkPort {
        attribute ipAddress : String;
        attribute bandwidth : DataThroughput;
    }

    port def UserInterfacePort {
        attribute sessionActive : Boolean;
        attribute userCount : Integer;
    }

    part def CommunicationModule {
        attribute maxDevices : Integer;
        attribute activeConnections : Integer;

        port zigbee : WirelessPort {
            attribute :>> protocol = ProtocolType::zigbee;
        }
        port zwave : WirelessPort {
            attribute :>> protocol = ProtocolType::zwave;
        }
        port wifi : WirelessPort {
            attribute :>> protocol = ProtocolType::wifi;
        }
        port bluetooth : WirelessPort {
            attribute :>> protocol = ProtocolType::bluetooth;
        }
    }

    part def AutomationController {
        attribute rulesCount : Integer;
        attribute executionQueueSize : Integer;
        attribute averageResponseTime : ResponseTime;
    }

    part def CloudInterface {
        attribute cloudConnected : Boolean;
        attribute syncInterval : TimeValue;
        port network : NetworkPort;
    }

    part def LocalDatabase {
        attribute deviceRecords : Integer;
        attribute automationRules : Integer;
        attribute historySize : Real;
    }

    part def UserInterfaceModule {
        attribute mobileAppActive : Boolean;
        attribute webDashboardActive : Boolean;
        attribute voiceControlEnabled : Boolean;
        port ui : UserInterfacePort;
    }

    action def ScanDevices {
        in protocol : ProtocolType;
        out discoveredDevices : DeviceID[0..*];
    }

    action def PairDevice {
        in deviceID : DeviceID;
        in protocol : ProtocolType;
        out pairingSuccess : Boolean;
    }

    action def MonitorSensors {
        out readings : SensorReading[0..*];
    }

    action def EvaluateAutomations {
        in readings : SensorReading[0..*];
        in rules : AutomationRule[0..*];
        out triggeredRules : AutomationRule[0..*];
    }

    action def ExecuteCommands {
        in commands : DeviceCommand[0..*];
        out executionResults : Boolean[0..*];
    }

    action def SyncWithCloud {
        in localData : String;
        out syncSuccess : Boolean;
    }

    action def AutomationCycle {
        first start;
        then merge continueMonitoring;
        then action monitor : MonitorSensors {
            out sensorData : SensorReading[0..*];
        }
        then action evaluate : EvaluateAutomations {
            in readings = monitor.sensorData;
            in rules : AutomationRule[0..*];
            out triggered : AutomationRule[0..*];
        }
        then decide;
            if evaluate.triggered->notEmpty() then executeActions;
            else continueMonitoring;
        action executeActions : ExecuteCommands {
            in commands : DeviceCommand[0..*];
        }
        then continueMonitoring;
    }

    state def HomeyOperationalState {
        entry; then initializing;

        state initializing {
            entry; do action init : ScanDevices;
        }
        transition init_to_ready
            first initializing
            then ready;

        state ready;
        transition ready_to_pairing
            first ready
            accept at pairRequest : DeviceCommand
            then pairing;
        transition ready_to_operating
            first ready
            accept at startAutomation : DeviceCommand
            then operating;

        state pairing {
            entry; do action pairAction : PairDevice;
        }
        transition pairing_to_ready
            first pairing
            if pairAction.pairingSuccess
            then ready;

        state operating {
            entry; do action automate : AutomationCycle;
        }
        transition operating_to_ready
            first operating
            accept at stopAutomation : DeviceCommand
            then ready;
        transition operating_to_error
            first operating
            accept at systemFault : DeviceCommand
            then error;

        state error {
            entry; do action diagnose : ScanDevices;
        }
        transition error_to_ready
            first error
            accept at recoveryComplete : DeviceCommand
            then ready;
    }

    part def HomeyHub {
        attribute firmwareVersion : String;
        attribute systemUptime : TimeValue;
        attribute totalDevicesManaged : Integer;
        attribute totalAutomations : Integer;
        attribute systemPower : PowerValue;

        part commModule : CommunicationModule {
            attribute :>> maxDevices = 100;
            attribute :>> activeConnections;
        }

        part automationCtrl : AutomationController {
            attribute :>> rulesCount;
            attribute :>> executionQueueSize;
            perform action automationLoop : AutomationCycle;
        }

        part cloudInterface : CloudInterface {
            attribute :>> cloudConnected;
            attribute :>> syncInterval = 300 [s];
        }

        part database : LocalDatabase {
            attribute :>> deviceRecords;
            attribute :>> automationRules;
        }

        part userInterface : UserInterfaceModule {
            attribute :>> mobileAppActive;
            attribute :>> webDashboardActive;
            attribute :>> voiceControlEnabled;
        }

        perform state lifecycle : HomeyOperationalState;

        connection commToAutomation connect commModule to automationCtrl;
        connection automationToDatabase connect automationCtrl to database;
        connection cloudToDatabase connect cloudInterface to database;
        connection uiToAutomation connect userInterface to automationCtrl;
    }

    part def HomeZone {
        attribute zoneID : ZoneID;
        attribute zoneName : String;
        attribute deviceCount : Integer;
    }

    part homeySmartHome {
        attribute totalPowerConsumption : PowerValue;
        attribute averageTemperature : TemperatureValue;

        part hub : HomeyHub {
            attribute :>> firmwareVersion = "v12.5.3";
            attribute :>> totalDevicesManaged;
            attribute :>> totalAutomations;
            attribute :>> systemPower = 15 [W];
        }

        part livingRoom : HomeZone {
            attribute :>> zoneID = "zone_lr";
            attribute :>> zoneName = "Living Room";

            part ceilingLights : SmartLight[4] {
                attribute :>> protocol = ProtocolType::zigbee;
                attribute :>> brightness;
                attribute :>> isOn;
            }

            part tempSensor : TemperatureSensor {
                attribute :>> protocol = ProtocolType::zigbee;
                attribute :>> temperature;
                attribute :>> humidity;
            }

            part motionSensor : MotionSensor {
                attribute :>> protocol = ProtocolType::zwave;
                attribute :>> motionDetected;
            }
        }

        part bedroom : HomeZone {
            attribute :>> zoneID = "zone_br";
            attribute :>> zoneName = "Bedroom";

            part bedLights : SmartLight[2] {
                attribute :>> protocol = ProtocolType::wifi;
                attribute :>> brightness;
                attribute :>> isOn;
            }

            part thermostat : SmartThermostat {
                attribute :>> protocol = ProtocolType::wifi;
                attribute :>> targetTemp;
                attribute :>> currentTemp;
            }
        }

        part entrance : HomeZone {
            attribute :>> zoneID = "zone_ent";
            attribute :>> zoneName = "Entrance";

            part doorLock : DoorLock {
                attribute :>> protocol = ProtocolType::zwave;
                attribute :>> locked;
                attribute :>> batteryLevel;
            }

            part motionSensor : MotionSensor {
                attribute :>> protocol = ProtocolType::zigbee;
                attribute :>> motionDetected;
            }
        }

        connection hubToLivingRoom connect hub.commModule to livingRoom;
        connection hubToBedroom connect hub.commModule to bedroom;
        connection hubToEntrance connect hub.commModule to entrance;
    }

    requirement <'REQ-HOMEY-001'> primaryFunction {
        doc /* The Homey smart home hub shall serve as a unified central controller 
             * that integrates diverse smart home devices across multiple wireless 
             * protocols and executes automated control sequences based on sensor 
             * inputs, user-defined rules, and scheduled events to provide seamless 
             * home automation.
             */
        subject system :> homeySmartHome.hub;
    }

    requirement <'REQ-HOMEY-002'> multiProtocolSupport {
        doc /* The system shall support simultaneous communication with devices 
             * using Zigbee, Z-Wave, WiFi, and Bluetooth protocols.
             */
        subject comm :> homeySmartHome.hub.commModule;
    }

    requirement <'REQ-HOMEY-003'> deviceCapacity {
        doc /* The hub shall support management of at least 100 connected 
             * smart devices simultaneously.
             */
        subject hub :> homeySmartHome.hub;

        assert constraint {
            hub.commModule.maxDevices >= 100
        }
    }

    requirement <'REQ-HOMEY-004'> automationResponse {
        doc /* The automation controller shall evaluate sensor inputs and 
             * execute corresponding device commands within 2 seconds.
             */
        subject ctrl :> homeySmartHome.hub.automationCtrl;

        assert constraint {
            ctrl.averageResponseTime <= 2 [s]
        }
    }

    requirement <'REQ-HOMEY-005'> cloudConnectivity {
        doc /* The system shall maintain cloud connectivity for remote access 
             * and synchronization with external services.
             */
        subject cloud :> homeySmartHome.hub.cloudInterface;

        assert constraint {
            cloud.cloudConnected == true
        }
    }

    requirement <'REQ-HOMEY-006'> userAccess {
        doc /* The system shall provide user control through mobile application, 
             * web dashboard, and voice assistant integration.
             */
        subject ui :> homeySmartHome.hub.userInterface;
    }

    requirement <'REQ-HOMEY-007'> powerEfficiency {
        doc /* The hub shall operate with a maximum power consumption of 20 watts 
             * during normal operation.
             */
        subject hub :> homeySmartHome.hub;

        assert constraint {
            hub.systemPower <= 20 [W]
        }
    }

    satisfy primaryFunction by homeySmartHome.hub;
    satisfy multiProtocolSupport by homeySmartHome.hub.commModule;
    satisfy deviceCapacity by homeySmartHome.hub;
    satisfy automationResponse by homeySmartHome.hub.automationCtrl;
    satisfy cloudConnectivity by homeySmartHome.hub.cloudInterface;
    satisfy userAccess by homeySmartHome.hub.userInterface;
    satisfy powerEfficiency by homeySmartHome.hub;
}
