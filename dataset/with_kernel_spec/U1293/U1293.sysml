package HomeAutomationSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        attribute def LightLevel :> Real;
        attribute def Percentage :> Real;
        attribute def Concentration :> Real;

        enum def HVACMode { cool; heat; off; }
        enum def SecurityMode { disarmed; armedAway; armedStay; }

        item def SensorData {
            attribute timestamp : Time;
        }
        item def TemperatureData :> SensorData {
            attribute temperature : Temperature;
        }
        item def HumidityData :> SensorData {
            attribute humidity : Percentage;
        }
        item def AirQualityData :> SensorData {
            attribute co2Level : Concentration;
        }
        item def OccupancyData :> SensorData {
            attribute occupied : Boolean;
        }
        item def MotionData :> SensorData {
            attribute motionDetected : Boolean;
        }
        item def LightData :> SensorData {
            attribute lightLevel : LightLevel;
        }
        item def DoorWindowStatusData :> SensorData {
            attribute isClosed : Boolean;
            attribute isLocked : Boolean;
        }

        item def Command {
            attribute commandID : String;
        }
        item def HVACCommand :> Command {
            attribute targetTemperature : Temperature;
            attribute mode : HVACMode;
        }
        item def LightingCommand :> Command {
            attribute brightness : Percentage;
        }
        item def LockCommand :> Command {
            attribute lock : Boolean;
        }
        item def AlarmCommand :> Command {
            attribute activate : Boolean;
        }
        item def ArmCommand :> Command {
            attribute mode : SecurityMode;
        }
        item def DisarmCommand :> Command;

        port def SensorPort {
            out item sensorData : SensorData;
        }
        port def CommandPort {
            in item command : Command;
        }
        
        port def TemperatureSensorPort :> SensorPort { out item tempData : TemperatureData; }
        port def HumiditySensorPort :> SensorPort { out item humData : HumidityData; }
        port def AirQualitySensorPort :> SensorPort { out item airData : AirQualityData; }
        port def OccupancySensorPort :> SensorPort { out item occData : OccupancyData; }
        port def MotionSensorPort :> SensorPort { out item motionData : MotionData; }
        port def LightSensorPort :> SensorPort { out item lightData : LightData; }
        port def DoorWindowSensorPort :> SensorPort { out item doorData : DoorWindowStatusData; }

        port def HVACCommandPort :> CommandPort { in item hvacCmd : HVACCommand; }
        port def LightingCommandPort :> CommandPort { in item lightCmd : LightingCommand; }
        port def LockCommandPort :> CommandPort { in item lockCmd : LockCommand; }
        port def AlarmCommandPort :> CommandPort { in item alarmCmd : AlarmCommand; }

        part def TemperatureSensor {
            port outPort : TemperatureSensorPort;
        }
        part def HumiditySensor {
            port outPort : HumiditySensorPort;
        }
        part def AirQualitySensor {
            port outPort : AirQualitySensorPort;
        }
        part def OccupancySensor {
            port outPort : OccupancySensorPort;
        }
        part def MotionSensor {
            port outPort : MotionSensorPort;
        }
        part def LightSensor {
            port outPort : LightSensorPort;
        }
        part def DoorWindowSensor {
            port outPort : DoorWindowSensorPort;
        }

        part def HVACUnit {
            port cmdIn : HVACCommandPort;
            attribute powerConsumption : Power;
            perform action adjustTemperature;
        }
        part def LightingController {
            port cmdIn : LightingCommandPort;
            attribute powerConsumption : Power;
            attribute brightness : Percentage;
            perform action setBrightness;
        }
        part def SmartLock {
            port cmdIn : LockCommandPort;
            port statusOut : DoorWindowSensorPort;
            perform action lockUnlock;
        }
        part def SecurityPanel {
            port cmdIn : AlarmCommandPort;
            perform action soundAlarm;
        }

        part def CentralController {
            port livingRoomTempIn : TemperatureSensorPort;
            port bedroomTempIn : TemperatureSensorPort;
            port kitchenTempIn : TemperatureSensorPort;
            port livingRoomHumidityIn : HumiditySensorPort;
            port bedroomHumidityIn : HumiditySensorPort;
            port livingRoomAirQualityIn : AirQualitySensorPort;
            port livingRoomOccupancyIn : OccupancySensorPort;
            port bedroomOccupancyIn : OccupancySensorPort;
            port kitchenOccupancyIn : OccupancySensorPort;
            port livingRoomMotionIn : MotionSensorPort;
            port livingRoomLightIn : LightSensorPort;
            port bedroomLightIn : LightSensorPort;
            port kitchenLightIn : LightSensorPort;
            port livingRoomDoorIn : DoorWindowSensorPort;
            port frontDoorStatusIn : DoorWindowSensorPort;
            port backDoorStatusIn : DoorWindowSensorPort;

            port livingRoomHvacCmdOut : HVACCommandPort;
            port bedroomHvacCmdOut : HVACCommandPort;
            port mainHvacCmdOut : HVACCommandPort;
            port livingRoomLightingCmdOut : LightingCommandPort;
            port bedroomLightingCmdOut : LightingCommandPort;
            port kitchenLightingCmdOut : LightingCommandPort;
            port frontDoorLockCmdOut : LockCommandPort;
            port backDoorLockCmdOut : LockCommandPort;
            port alarmCmdOut : AlarmCommandPort;

            attribute currentSecurityMode : SecurityMode;
            attribute energyConsumption : Energy;

            perform action processSensorData;
            perform action controlClimate;
            perform action controlLighting;
            perform action controlSecurity;
            perform action optimizeEnergy;

            action lockAllDoors {
                send new LockCommand() to frontDoorLockCmdOut;
                send new LockCommand() to backDoorLockCmdOut;
            }
            action triggerAlarm {
                send new AlarmCommand() to alarmCmdOut;
            }

            exhibit state securityStateMachine {
                entry action initial;
                state disarmed;
                state armedAway {
                    entry lockAllDoors;
                }
                state armedStay {
                    entry lockAllDoors;
                }
                state alarmState {
                    entry triggerAlarm;
                }
                transition initial then disarmed;
                transition disarmed_To_armedAway
                    first disarmed
                    accept armCmd : ArmCommand
                    if armCmd.mode == SecurityMode::armedAway
                    then armedAway;
                transition disarmed_To_armedStay
                    first disarmed
                    accept armCmd : ArmCommand
                    if armCmd.mode == SecurityMode::armedStay
                    then armedStay;
                transition armedAway_To_disarmed
                    first armedAway
                    accept disarmCmd : DisarmCommand
                    then disarmed;
                transition armedStay_To_disarmed
                    first armedStay
                    accept disarmCmd : DisarmCommand
                    then disarmed;
                transition armedAway_To_alarm
                    first armedAway
                    accept motionData : MotionData via livingRoomMotionIn
                    if motionData.motionDetected
                    do triggerAlarm
                    then alarmState;
                transition alarmState_To_disarmed
                    first alarmState
                    accept disarmCmd : DisarmCommand
                    then disarmed;
            }
        }

        part def Room {
            part tempSensor : TemperatureSensor;
            part humiditySensor : HumiditySensor;
            part airQualitySensor : AirQualitySensor;
            part occupancySensor : OccupancySensor;
            part motionSensor : MotionSensor;
            part lightSensor : LightSensor;
            part doorSensor : DoorWindowSensor;
            part hvacUnit : HVACUnit;
            part lighting : LightingController;

            port tempOut : TemperatureSensorPort = tempSensor.outPort;
            port humidityOut : HumiditySensorPort = humiditySensor.outPort;
            port airQualityOut : AirQualitySensorPort = airQualitySensor.outPort;
            port occupancyOut : OccupancySensorPort = occupancySensor.outPort;
            port motionOut : MotionSensorPort = motionSensor.outPort;
            port lightOut : LightSensorPort = lightSensor.outPort;
            port doorStatusOut : DoorWindowSensorPort = doorSensor.outPort;
            port hvacCmdIn : HVACCommandPort = hvacUnit.cmdIn;
            port lightingCmdIn : LightingCommandPort = lighting.cmdIn;
        }

        part def Home {
            part centralController : CentralController;
            part livingRoom : Room;
            part bedroom : Room;
            part kitchen : Room;
            part mainHVAC : HVACUnit;
            part securityPanel : SecurityPanel;
            part frontDoorLock : SmartLock;
            part backDoorLock : SmartLock;

            connect livingRoom.tempOut to centralController.livingRoomTempIn;
            connect bedroom.tempOut to centralController.bedroomTempIn;
            connect kitchen.tempOut to centralController.kitchenTempIn;
            connect livingRoom.humidityOut to centralController.livingRoomHumidityIn;
            connect bedroom.humidityOut to centralController.bedroomHumidityIn;
            connect livingRoom.airQualityOut to centralController.livingRoomAirQualityIn;
            connect livingRoom.occupancyOut to centralController.livingRoomOccupancyIn;
            connect bedroom.occupancyOut to centralController.bedroomOccupancyIn;
            connect kitchen.occupancyOut to centralController.kitchenOccupancyIn;
            connect livingRoom.motionOut to centralController.livingRoomMotionIn;
            connect livingRoom.lightOut to centralController.livingRoomLightIn;
            connect bedroom.lightOut to centralController.bedroomLightIn;
            connect kitchen.lightOut to centralController.kitchenLightIn;
            connect livingRoom.doorStatusOut to centralController.livingRoomDoorIn;
            connect frontDoorLock.statusOut to centralController.frontDoorStatusIn;
            connect backDoorLock.statusOut to centralController.backDoorStatusIn;

            connect centralController.livingRoomHvacCmdOut to livingRoom.hvacCmdIn;
            connect centralController.bedroomHvacCmdOut to bedroom.hvacCmdIn;
            connect centralController.mainHvacCmdOut to mainHVAC.cmdIn;
            connect centralController.livingRoomLightingCmdOut to livingRoom.lightingCmdIn;
            connect centralController.bedroomLightingCmdOut to bedroom.lightingCmdIn;
            connect centralController.kitchenLightingCmdOut to kitchen.lightingCmdIn;
            connect centralController.frontDoorLockCmdOut to frontDoorLock.cmdIn;
            connect centralController.backDoorLockCmdOut to backDoorLock.cmdIn;
            connect centralController.alarmCmdOut to securityPanel.cmdIn;
        }

        requirement def ClimateControlReq {
            doc /* The system shall maintain the temperature within +/-1 degree of the user's preferred setting when the room is occupied. */
            attribute actualTemp : Temperature;
            attribute setTemp : Temperature;
            require constraint { actualTemp >= setTemp - 1.0 [K] and actualTemp <= setTemp + 1.0 [K] }
        }
        requirement def OccupancyBasedControlReq {
            doc /* The system shall reduce HVAC and lighting usage in unoccupied rooms to conserve energy. */
            attribute occupancy : Boolean;
            attribute hvacPower : Power;
            attribute lightingPower : Power;
            attribute maxHvacPower : Power;
            attribute maxLightingPower : Power;
            require constraint { occupancy == false implies hvacPower <= 0.1 * maxHvacPower }
            require constraint { occupancy == false implies lightingPower <= 0.1 * maxLightingPower }
        }
        requirement def SecurityArmingReq {
            doc /* The system shall lock all exterior doors and activate motion sensors when armed in 'away' mode. */
            attribute securityMode : SecurityMode;
            attribute allDoorsLocked : Boolean;
            attribute motionSensorsActive : Boolean;
            require constraint { securityMode == SecurityMode::armedAway implies (allDoorsLocked == true and motionSensorsActive == true) }
        }
        requirement def IntrusionAlarmReq {
            doc /* The system shall trigger an alarm if motion is detected while armed in 'away' mode. */
            attribute motionDetected : Boolean;
            attribute alarmActive : Boolean;
            attribute securityMode : SecurityMode;
            require constraint { (securityMode == SecurityMode::armedAway and motionDetected) implies alarmActive == true }
        }
        requirement def EnergyOptimizationReq {
            doc /* The system shall minimize total energy consumption while maintaining comfort and security. */
            attribute totalEnergy : Energy;
            attribute baselineEnergy : Energy;
            require constraint { totalEnergy <= baselineEnergy * 0.9 }
        }
        requirement def LightingControlReq {
            doc /* The system shall adjust artificial lighting based on ambient light and occupancy to maintain desired brightness. */
            attribute ambientLight : LightLevel;
            attribute artificialLight : LightLevel;
            attribute desiredLight : LightLevel;
            require constraint { ambientLight + artificialLight >= desiredLight }
        }
    }

    package Usages {
        private import Definitions::*;
        part myHome : Home;
    }
}
