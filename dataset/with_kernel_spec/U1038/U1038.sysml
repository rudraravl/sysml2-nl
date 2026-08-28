package DomusIntelligentHomeSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    attribute def TemperatureValue :> ISQ::TemperatureValue;
    attribute def HumidityValue :> Real;
    attribute def AirQualityIndex :> Integer;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def LightIntensity :> Real;

    enum def OccupancyStatus { occupied; unoccupied; }
    enum def SecurityState { armed; disarmed; monitoring; }
    enum def SystemMode { active; away; night; }

    attribute def ClimateCommand { targetTemp : TemperatureValue; zoneId : String; }
    attribute def LightingCommand { intensity : LightIntensity; zoneId : String; }
    attribute def SecurityCommand { secState : SecurityState; }
    attribute def PowerData { consumption : PowerValue; subsystemId : String; }

    attribute def AwayTrigger;
    attribute def ArrivalTrigger;
    attribute def NightTrigger;
    attribute def MorningTrigger;

    port def SensorSource {
        out temp : TemperatureValue;
        out humidity : HumidityValue;
        out airQuality : AirQualityIndex;
        out occupancy : OccupancyStatus;
    }
    port def SensorSink {
        in temp : TemperatureValue;
        in humidity : HumidityValue;
        in airQuality : AirQualityIndex;
        in occupancy : OccupancyStatus;
    }

    port def CommandSource {
        out climateCmd : ClimateCommand;
        out lightingCmd : LightingCommand;
        out securityCmd : SecurityCommand;
    }
    port def CommandSink {
        in climateCmd : ClimateCommand;
        in lightingCmd : LightingCommand;
        in securityCmd : SecurityCommand;
    }

    port def PowerSource {
        out powerData : PowerData;
    }
    port def PowerSink {
        in powerData : PowerData;
    }

    part def EnvironmentalSensor {
        port sensorOut : SensorSource;
        attribute tempVal : TemperatureValue;
        attribute humVal : HumidityValue;
        attribute aqVal : AirQualityIndex;
    }
    part def OccupancySensor {
        port sensorOut : SensorSource;
        attribute occStatus : OccupancyStatus;
    }

    part def Zone {
        attribute zoneId : String;
        part envSensor : EnvironmentalSensor;
        part occSensor : OccupancySensor;
        port zoneDataOut : SensorSource;
        connect envSensor.sensorOut to zoneDataOut;
        connect occSensor.sensorOut to zoneDataOut;
    }

    part def HVACSystem {
        port cmdIn : CommandSink;
        port powerOut : PowerSource;
        attribute powerConsumption : PowerValue;
        perform action adjustClimate;
    }

    part def LightingSystem {
        port cmdIn : CommandSink;
        port powerOut : PowerSource;
        attribute powerConsumption : PowerValue;
        perform action adjustLighting;
    }

    part def SecuritySystem {
        port cmdIn : CommandSink;
        port powerOut : PowerSource;
        attribute securityState : SecurityState;
        attribute powerConsumption : PowerValue;
        perform action armSystem;
    }

    part def EnergyManagementSystem {
        port powerIn : PowerSink;
        port powerOut : PowerSource;
        attribute totalConsumption : PowerValue;
        perform action trackPower;
    }

    action def ActivateActiveMode;
    action def ActivateAwayMode;
    action def ActivateNightMode;
    action def ProcessSensorData;
    action def GenerateCommands;

    part def CentralController {
        port sensorIn : SensorSink;
        port cmdOut : CommandSource;
        port powerIn : PowerSink;
        attribute currentMode : SystemMode;
        perform action activateActiveMode : ActivateActiveMode;
        perform action activateAwayMode : ActivateAwayMode;
        perform action activateNightMode : ActivateNightMode;
        perform action processSensorData : ProcessSensorData;
        perform action generateCommands : GenerateCommands;
        exhibit state SystemModes {
            entry; then active;
            state active {
                entry activateActiveMode;
            }
            state away {
                entry activateAwayMode;
            }
            state night {
                entry activateNightMode;
            }
            transition active_to_away
                first active
                accept AwayTrigger
                then away;
            transition away_to_active
                first away
                accept ArrivalTrigger
                then active;
            transition active_to_night
                first active
                accept NightTrigger
                then night;
            transition night_to_active
                first night
                accept MorningTrigger
                then active;
        }
    }

    part def DomusHome {
        part controller : CentralController;
        part livingRoom : Zone { zoneId = "livingRoom"; }
        part masterBedroom : Zone { zoneId = "masterBedroom"; }
        part kitchen : Zone { zoneId = "kitchen"; }
        part bathroom : Zone { zoneId = "bathroom"; }
        part hvac : HVACSystem;
        part lighting : LightingSystem;
        part security : SecuritySystem;
        part energy : EnergyManagementSystem;

        connect controller.cmdOut to hvac.cmdIn;
        connect controller.cmdOut to lighting.cmdIn;
        connect controller.cmdOut to security.cmdIn;

        connect livingRoom.zoneDataOut to controller.sensorIn;
        connect masterBedroom.zoneDataOut to controller.sensorIn;
        connect kitchen.zoneDataOut to controller.sensorIn;
        connect bathroom.zoneDataOut to controller.sensorIn;

        connect hvac.powerOut to energy.powerIn;
        connect lighting.powerOut to energy.powerIn;
        connect security.powerOut to energy.powerIn;
        connect energy.powerOut to controller.powerIn;
    }

    requirement def ClimateControlReq {
        doc /* The HVAC system shall adjust temperature only in occupied zones. */
        attribute zoneOccupancy : OccupancyStatus;
        require constraint { zoneOccupancy == OccupancyStatus::occupied }
    }
    requirement def LightingControlReq {
        doc /* The lighting system shall turn on when a room is occupied and off when unoccupied. */
        attribute lightStatus : Boolean;
        attribute occupancy : OccupancyStatus;
        require constraint {
            (occupancy == OccupancyStatus::occupied implies lightStatus == true) and
            (occupancy == OccupancyStatus::unoccupied implies lightStatus == false)
        }
    }
    requirement def EnergyEfficiencyReq {
        doc /* The system shall minimize power consumption without sacrificing comfort or safety. */
        attribute totalPower : PowerValue;
        attribute maxPower : PowerValue;
        require constraint { totalPower <= maxPower }
    }
    requirement def SecurityModeReq {
        doc /* The security system shall arm automatically when the system enters 'away' mode. */
        attribute systemMode : SystemMode;
        attribute secState : SecurityState;
        require constraint { systemMode == SystemMode::away implies secState == SecurityState::armed }
    }
    requirement def ModeTransitionReq {
        doc /* The system shall transition between active, away, and night modes based on occupancy and time. */
        attribute mode : SystemMode;
        attribute occupancy : OccupancyStatus;
        require constraint {
            (mode == SystemMode::away) implies (occupancy == OccupancyStatus::unoccupied)
        }
    }
}
