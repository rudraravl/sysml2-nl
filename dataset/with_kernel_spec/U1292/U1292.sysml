package SmartHomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        value def TemperatureValue :> Real;
        value def HumidityValue :> Real;
        value def LightLevel :> Real;

        item def ThermostatCommand {
            attribute setPoint : TemperatureValue;
        }
        item def LightCommand {
            attribute level : LightLevel;
        }
        item def LockCommand {
            attribute locked : Boolean;
        }
        item def AccessEvent {
            attribute timestamp : String;
            attribute userId : String;
            attribute lockAction : String;
        }
        item def AutomationRule {
            attribute name : String;
            attribute enabled : Boolean;
        }
        item def DeviceStatus {
            attribute deviceId : String;
            attribute status : String;
        }

        attribute def PowerOff;
        attribute def PowerOn;
        attribute def MotionDetected;
        attribute def NoMotion;
        attribute def TargetReached;
        attribute def RuleTriggered;
        attribute def ConnectionLost;
        attribute def ConnectionRestored;

        port def SensorDataPort {
            out temp : TemperatureValue;
            out humidity : HumidityValue;
        }
        port def OccupancyDataPort {
            out occupied : Boolean;
        }
        port def ThermostatCommandPort {
            in command : ThermostatCommand;
        }
        port def LightCommandPort {
            in command : LightCommand;
        }
        port def LockCommandPort {
            in command : LockCommand;
        }
        port def DashboardPort {
            in deviceStatus : DeviceStatus;
            out overrideCommand : String;
        }

        action def 'Sense Environment' {
            out temp : TemperatureValue;
            out humidity : HumidityValue;
        }
        action def 'Detect Occupancy' {
            out occupied : Boolean;
        }
        action def 'Regulate Temperature' {
            in setPoint : TemperatureValue;
            out currentTemp : TemperatureValue;
        }
        action def 'Illuminate' {
            in level : LightLevel;
        }
        action def 'Log Access' {
            in accessEvent : AccessEvent;
            out logEntry : AccessEvent;
        }
        action def 'Evaluate Rules' {
            in livingRoomTemp : TemperatureValue;
            in livingRoomOccupied : Boolean;
            in bedroomTemp : TemperatureValue;
            in bedroomOccupied : Boolean;
            in energySavingTemp : TemperatureValue;
            out triggered : Boolean;
        }
        action def 'Execute Automation' {
            in triggered : Boolean;
            in energySavingTemp : TemperatureValue;
            out thermostatCmd : ThermostatCommand;
            out livingRoomLightCmd : LightCommand;
            out bedroomLightCmd : LightCommand;
            out lockCmd : LockCommand;
        }
        action def 'Route Data' {
            in sensorData : String;
            out routedData : String;
        }
        action def 'Route Commands' {
            in command : String;
            out routedCommand : String;
        }
        action def 'Display Status' {
            in status : DeviceStatus;
        }
        action def 'Process Override' {
            in overrideCommand : String;
            out processedCommand : String;
        }

        part def TemperatureHumiditySensor {
            attribute sensorId : String;
            attribute location : String;
            port dataOut : SensorDataPort;
            perform action 'sense environment' : 'Sense Environment';
            exhibit state sensorStates {
                entry; then active;
                state active {
                    do 'sense environment';
                }
                accept PowerOff then inactive;
                state inactive;
                accept PowerOn then active;
            }
        }

        part def OccupancySensor {
            attribute sensorId : String;
            attribute location : String;
            port dataOut : OccupancyDataPort;
            perform action 'detect occupancy' : 'Detect Occupancy';
            exhibit state occupancyStates {
                entry; then unoccupied;
                state unoccupied;
                accept MotionDetected then occupied;
                state occupied {
                    do 'detect occupancy';
                }
                accept NoMotion then unoccupied;
            }
        }

        part def SmartThermostat {
            attribute deviceId : String;
            attribute currentSetPoint : TemperatureValue;
            attribute energySavingSetPoint : TemperatureValue;
            port cmdIn : ThermostatCommandPort;
            perform action 'regulate temperature' : 'Regulate Temperature';
            exhibit state thermostatStates {
                entry; then idle;
                state idle;
                accept when cmdIn.command.setPoint != currentSetPoint then regulating;
                state regulating {
                    do 'regulate temperature';
                }
                accept TargetReached then idle;
            }
        }

        part def SmartLight {
            attribute deviceId : String;
            attribute location : String;
            attribute currentLevel : LightLevel;
            port cmdIn : LightCommandPort;
            perform action 'illuminate' : 'Illuminate';
            exhibit state lightStates {
                entry; then off;
                state off;
                accept when cmdIn.command.level > 0.0 then on;
                state on {
                    do 'illuminate';
                }
                accept when cmdIn.command.level == 0.0 then off;
            }
        }

        part def SmartDoorLock {
            attribute deviceId : String;
            attribute isLocked : Boolean;
            attribute accessLog : AccessEvent[0..*];
            port cmdIn : LockCommandPort;
            perform action 'log access' : 'Log Access';
            exhibit state lockStates {
                entry; then locked;
                state locked;
                accept when cmdIn.command.locked == false then unlocked;
                state unlocked;
                accept when cmdIn.command.locked == true do 'log access' then locked;
            }
        }

        part def AutomationController {
            attribute rules : AutomationRule[0..*];
            attribute energySavingTemp : TemperatureValue;
            attribute comfortTemp : TemperatureValue;
            port livingRoomSensorIn : ~SensorDataPort;
            port bedroomSensorIn : ~SensorDataPort;
            port livingRoomOccupancyIn : ~OccupancyDataPort;
            port bedroomOccupancyIn : ~OccupancyDataPort;
            port thermostatCmdOut : ~ThermostatCommandPort;
            port livingRoomLightCmdOut : ~LightCommandPort;
            port bedroomLightCmdOut : ~LightCommandPort;
            port lockCmdOut : ~LockCommandPort;
            perform action 'evaluate rules' : 'Evaluate Rules';
            perform action 'execute automation' : 'Execute Automation';
            exhibit state controllerStates {
                entry; then monitoring;
                state monitoring {
                    do 'evaluate rules';
                }
                accept RuleTriggered then executing;
                state executing {
                    do 'execute automation';
                }
                then monitoring;
            }
        }

        part def UserDashboard {
            attribute dashboardId : String;
            attribute isActive : Boolean;
            port dashPort : DashboardPort;
            perform action 'display status' : 'Display Status';
            perform action 'process override' : 'Process Override';
        }

        part def CentralHub {
            attribute hubId : String;
            attribute isOnline : Boolean;
            port livingRoomSensorIF : ~SensorDataPort;
            port bedroomSensorIF : ~SensorDataPort;
            port livingRoomOccupancyIF : ~OccupancyDataPort;
            port bedroomOccupancyIF : ~OccupancyDataPort;
            port thermostatIF : ~ThermostatCommandPort;
            port livingRoomLightIF : ~LightCommandPort;
            port bedroomLightIF : ~LightCommandPort;
            port doorLockIF : ~LockCommandPort;
            port dashboardIF : ~DashboardPort;
            part automationController : AutomationController;
            connect livingRoomSensorIF to automationController.livingRoomSensorIn;
            connect bedroomSensorIF to automationController.bedroomSensorIn;
            connect livingRoomOccupancyIF to automationController.livingRoomOccupancyIn;
            connect bedroomOccupancyIF to automationController.bedroomOccupancyIn;
            connect automationController.thermostatCmdOut to thermostatIF;
            connect automationController.livingRoomLightCmdOut to livingRoomLightIF;
            connect automationController.bedroomLightCmdOut to bedroomLightIF;
            connect automationController.lockCmdOut to doorLockIF;
            perform action 'route data' : 'Route Data';
            perform action 'route commands' : 'Route Commands';
            exhibit state hubStates {
                entry; then online;
                state online {
                    do 'route data';
                    do 'route commands';
                }
                accept ConnectionLost then offline;
                state offline;
                accept ConnectionRestored then online;
            }
        }

        part def Room {
            attribute name : String;
            part tempHumiditySensor : TemperatureHumiditySensor;
            part occupancySensor : OccupancySensor;
            part smartLight : SmartLight;
        }

        part def SmartHome {
            attribute homeId : String;
            part centralHub : CentralHub;
            part livingRoom : Room;
            part bedroom : Room;
            part thermostat : SmartThermostat;
            part frontDoorLock : SmartDoorLock;
            part userDashboard : UserDashboard;
        }
    }

    package Requirements {
        private import ScalarValues::*;
        private import ISQ::*;
        private import Definitions::*;

        requirement def CentralizedControlReqDef {
            doc /* The system shall provide centralized control of all connected smart devices through a single Central Hub. */
            attribute connectedDevices : Integer;
            attribute minConnectedDevices : Integer;
            require constraint { connectedDevices >= minConnectedDevices }
        }

        requirement def SensorDataCollectionReqDef {
            doc /* The system shall continuously collect temperature, humidity, and occupancy data from sensors distributed throughout the home. */
            attribute dataCollectionInterval : Time;
            attribute maxCollectionInterval : Time;
            require constraint { dataCollectionInterval <= maxCollectionInterval }
        }

        requirement def AutomationRuleExecutionReqDef {
            doc /* The Automation Controller shall execute user-defined rules to automatically control devices based on sensor data. */
            attribute ruleExecutionTime : Time;
            attribute maxRuleExecutionTime : Time;
            require constraint { ruleExecutionTime <= maxRuleExecutionTime }
        }

        requirement def EnergySavingReqDef {
            doc /* The system shall adjust the Smart Thermostat to an energy-saving temperature when a room is vacant. */
            attribute vacantRoomTemp : TemperatureValue;
            attribute energySavingSetPoint : TemperatureValue;
            require constraint { vacantRoomTemp == energySavingSetPoint }
        }

        requirement def OccupancyLightingReqDef {
            doc /* The system shall turn on Smart Lights when occupancy is detected. */
            attribute detectedOccupancy : Boolean;
            attribute lightActivated : Boolean;
            require constraint { detectedOccupancy implies lightActivated }
        }

        requirement def DoorLockControlReqDef {
            doc /* The Smart Door Lock shall support remote locking and unlocking and shall log all access events. */
            attribute remoteLockCapability : Boolean;
            attribute accessLogEnabled : Boolean;
            require constraint { remoteLockCapability and accessLogEnabled }
        }

        requirement def UserDashboardReqDef {
            doc /* The User Dashboard shall display real-time status of all devices and allow manual override of automated actions. */
            attribute statusDisplayEnabled : Boolean;
            attribute overrideCapability : Boolean;
            require constraint { statusDisplayEnabled and overrideCapability }
        }

        requirement def DashboardResponseTimeReqDef {
            doc /* The User Dashboard shall respond to user inputs within 2 seconds. */
            attribute responseTime : Time;
            attribute maxResponseTime : Time;
            require constraint { responseTime <= maxResponseTime }
        }

        requirement def SystemReliabilityReqDef {
            doc /* The system shall operate continuously without failure for at least 1 year. */
            attribute operationalDays : Integer;
            attribute minOperationalDays : Integer;
            require constraint { operationalDays >= minOperationalDays }
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        part smartHome : SmartHome {
            satisfy CentralizedControlReqDef;
            satisfy SensorDataCollectionReqDef;
            satisfy SystemReliabilityReqDef;

            part centralHub : CentralHub {
                part automationController : AutomationController {
                    satisfy AutomationRuleExecutionReqDef;
                    satisfy EnergySavingReqDef;
                    satisfy OccupancyLightingReqDef;
                    attribute energySavingTemp = 18.0;
                    attribute comfortTemp = 22.0;
                }
            }

            part livingRoom : Room {
                attribute name = "Living Room";
                part tempHumiditySensor : TemperatureHumiditySensor {
                    attribute sensorId = "THS-LR-001";
                    attribute location = "Living Room";
                }
                part occupancySensor : OccupancySensor {
                    attribute sensorId = "OCC-LR-001";
                    attribute location = "Living Room";
                }
                part smartLight : SmartLight {
                    attribute deviceId = "LT-LR-001";
                    attribute location = "Living Room";
                    attribute currentLevel = 0.0;
                }
            }

            part bedroom : Room {
                attribute name = "Bedroom";
                part tempHumiditySensor : TemperatureHumiditySensor {
                    attribute sensorId = "THS-BR-001";
                    attribute location = "Bedroom";
                }
                part occupancySensor : OccupancySensor {
                    attribute sensorId = "OCC-BR-001";
                    attribute location = "Bedroom";
                }
                part smartLight : SmartLight {
                    attribute deviceId = "LT-BR-001";
                    attribute location = "Bedroom";
                    attribute currentLevel = 0.0;
                }
            }

            part thermostat : SmartThermostat {
                attribute deviceId = "TSTAT-001";
                attribute currentSetPoint = 22.0;
                attribute energySavingSetPoint = 18.0;
            }

            part frontDoorLock : SmartDoorLock {
                attribute deviceId = "LOCK-FD-001";
                attribute isLocked = true;
                satisfy DoorLockControlReqDef;
            }

            part userDashboard : UserDashboard {
                attribute dashboardId = "DASH-001";
                attribute isActive = true;
                satisfy UserDashboardReqDef;
                satisfy DashboardResponseTimeReqDef;
            }

            connect livingRoom.tempHumiditySensor.dataOut to centralHub.livingRoomSensorIF;
            connect livingRoom.occupancySensor.dataOut to centralHub.livingRoomOccupancyIF;
            connect bedroom.tempHumiditySensor.dataOut to centralHub.bedroomSensorIF;
            connect bedroom.occupancySensor.dataOut to centralHub.bedroomOccupancyIF;
            connect centralHub.thermostatIF to thermostat.cmdIn;
            connect centralHub.livingRoomLightIF to livingRoom.smartLight.cmdIn;
            connect centralHub.bedroomLightIF to bedroom.smartLight.cmdIn;
            connect centralHub.doorLockIF to frontDoorLock.cmdIn;
            connect centralHub.dashboardIF to userDashboard.dashPort;
        }
    }
}
