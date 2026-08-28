package SmartHomeSystem {
    private import ScalarValues::*;

    // ===== Item and Value Types =====
    item def Data;
    item def Command;
    item def SensorReading;

    attribute def AutomationRule {
        attribute ruleId : String;
        attribute condition : String;
        attribute ruleAction : String;
        attribute enabled : Boolean = true;
    }

    attribute def BrightnessValue :> Real;
    attribute def TemperatureValue :> Real;

    attribute def PairingModeSignal;
    attribute def InitCompleteSignal;
    attribute def PairingCompleteSignal;
    attribute def FaultSignal;
    attribute def RecoveryCompleteSignal;

    // ===== Communication Ports =====
    abstract port def CommunicationPort {
        in item rxData : Data;
        out item txData : Data;
    }

    port def ZigbeePort :> CommunicationPort;
    port def ZWavePort :> CommunicationPort;
    port def WiFiPort :> CommunicationPort;
    port def BluetoothPort :> CommunicationPort;

    // ===== Smart Device Definitions =====
    abstract part def SmartDevice {
        port commPort : CommunicationPort;
        attribute deviceId : String;
        attribute zoneName : String;
        attribute isOnline : Boolean = false;
    }

    part def SmartLightBulb :> SmartDevice {
        attribute brightness : BrightnessValue = 0;
        attribute isOn : Boolean = false;
        in item setBrightnessCmd : Command;
        in item toggleCmd : Command;
    }

    part def TemperatureSensor :> SmartDevice {
        attribute currentTemp : TemperatureValue;
        out item tempReading : SensorReading;
    }

    part def MotionSensor :> SmartDevice {
        attribute motionDetected : Boolean = false;
        out item motionEvent : SensorReading;
    }

    part def SmartThermostat :> SmartDevice {
        attribute targetTemp : TemperatureValue;
        attribute currentTemp : TemperatureValue;
        in item setTargetTempCmd : Command;
    }

    part def DoorLock :> SmartDevice {
        attribute isLocked : Boolean = true;
        in item lockCmd : Command;
        in item unlockCmd : Command;
    }

    // ===== Zone Definition =====
    part def Zone {
        attribute zoneName : String;
        part devices : SmartDevice [0..*];
    }

    // ===== Automation Actions =====
    action def MonitorSensors {
        out readings : SensorReading [0..*];
    }

    action def EvaluateRules {
        in readings : SensorReading [0..*];
        in rules : AutomationRule [0..*];
        out commands : Command [0..*];
    }

    action def ExecuteCommands {
        in commands : Command [0..*];
    }

    action def AutomationCycle {
        doc /** Continuous cycle: monitor sensors, evaluate rules, execute commands, repeat. */
        action monitor : MonitorSensors;
        action evaluate : EvaluateRules;
        action execute : ExecuteCommands;
        flow from monitor.readings to evaluate.readings;
        flow from evaluate.commands to execute.commands;
    }

    // ===== User Interfaces =====
    abstract part def UserInterface {
        port wifiPort : WiFiPort;
        out item userCommand : Command;
        in item statusUpdate : Data;
    }

    part def MobileApp :> UserInterface;
    part def WebDashboard :> UserInterface;
    part def VoiceAssistant :> UserInterface {
        attribute wakeWord : String = "Hey Homey";
    }

    // ===== Cloud Service =====
    part def CloudService {
        port cloudPort : WiFiPort;
        in item backupData : Data;
        out item remoteCommand : Command;
        attribute isReachable : Boolean = false;
    }

    // ===== Local Database =====
    part def LocalDatabase {
        attribute deviceRecords : String [0..*];
        attribute ruleRecords : AutomationRule [0..*];
        in item storeData : Data;
        out item retrieveData : Data;
    }

    // ===== Homey Hub =====
    part def HomeyHub {
        port zigbee : ZigbeePort [0..*];
        port zwave : ZWavePort [0..*];
        port wifi : WiFiPort [0..*];
        port bluetooth : BluetoothPort [0..*];
        port cloudLink : WiFiPort;

        attribute maxDevices : Integer = 100;
        attribute connectedDeviceCount : Integer = 0;
        attribute currentHour : Integer = 0;

        part automationController {
            attribute rules : AutomationRule [0..*];
            perform action cycle : AutomationCycle;
        }

        part database : LocalDatabase;

        exhibit state hubStates {
            entry; then initializing;

            state initializing;
            accept InitCompleteSignal then operating;
            accept PairingModeSignal then pairing;
            accept FaultSignal then error;

            state pairing;
            accept PairingCompleteSignal then operating;
            accept FaultSignal then error;

            state operating {
                do automationController.cycle;
            }
            accept PairingModeSignal then pairing;
            accept FaultSignal then error;

            state error;
            accept RecoveryCompleteSignal then operating;
        }
    }

    // ===== System Definition =====
    part def SmartHomeSystem {
        part hub : HomeyHub;
        part cloud : CloudService;
        part mobileApp : MobileApp;
        part webDashboard : WebDashboard;
        part voiceAssistant : VoiceAssistant;

        part livingRoom : Zone {
            :>> zoneName = "Living Room";
            part light1 : SmartLightBulb { :>> zoneName = "Living Room"; }
            part light2 : SmartLightBulb { :>> zoneName = "Living Room"; }
            part tempSensor : TemperatureSensor { :>> zoneName = "Living Room"; }
            part thermostat : SmartThermostat { :>> zoneName = "Living Room"; }
        }

        part bedroom : Zone {
            :>> zoneName = "Bedroom";
            part light : SmartLightBulb { :>> zoneName = "Bedroom"; }
            part tempSensor : TemperatureSensor { :>> zoneName = "Bedroom"; }
        }

        part entrance : Zone {
            :>> zoneName = "Entrance";
            part motionSensor : MotionSensor { :>> zoneName = "Entrance"; }
            part doorLock : DoorLock { :>> zoneName = "Entrance"; }
            part light : SmartLightBulb { :>> zoneName = "Entrance"; }
        }

        attribute entranceLightRule : AutomationRule {
            :>> ruleId = "rule_001";
            :>> condition = "entrance.motionSensor.motionDetected and currentHour >= 19";
            :>> ruleAction = "livingRoom.light1.setBrightness(50)";
        }

        connect hub.zigbee to livingRoom.light1.commPort;
        connect hub.zigbee to livingRoom.light2.commPort;
        connect hub.zigbee to bedroom.light.commPort;
        connect hub.zigbee to entrance.light.commPort;
        connect hub.zwave to entrance.doorLock.commPort;
        connect hub.zigbee to entrance.motionSensor.commPort;
        connect hub.zigbee to livingRoom.tempSensor.commPort;
        connect hub.zigbee to bedroom.tempSensor.commPort;
        connect hub.zwave to livingRoom.thermostat.commPort;

        connect hub.cloudLink to cloud.cloudPort;

        connect hub.wifi to mobileApp.wifiPort;
        connect hub.wifi to webDashboard.wifiPort;
        connect hub.wifi to voiceAssistant.wifiPort;
    }

    // ===== Requirements =====
    requirement def DeviceSupportRequirement {
        doc /** The hub shall support up to 100 connected smart devices. */
        subject hub : HomeyHub;
        attribute maxSupported : Integer = 100;
        constraint { hub.connectedDeviceCount <= maxSupported }
    }

    requirement def ProtocolSupportRequirement {
        doc /** The hub shall communicate using Zigbee, Z-Wave, WiFi, and Bluetooth protocols. */
        subject hub : HomeyHub;
    }

    requirement def AutomationCycleRequirement {
        doc /** The automation controller shall continuously monitor sensors, evaluate rules, and execute commands. */
        subject hub : HomeyHub;
    }

    requirement def HubStateRequirement {
        doc /** The hub shall operate in initializing, pairing, operating, and error states. */
        subject hub : HomeyHub;
    }

    requirement def CloudBackupRequirement {
        doc /** The hub shall maintain a connection to a cloud service for remote access and data backup. */
        subject hub : HomeyHub;
    }

    requirement def ZoneManagementRequirement {
        doc /** The system shall organize devices into logical zones and manage them accordingly. */
        subject system : SmartHomeSystem;
    }
}
