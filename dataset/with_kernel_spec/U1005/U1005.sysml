package BuildingAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQTemperature::*;
    private import ISQPower::*;

    item def TemperatureData {
        attribute value : TemperatureValue;
    }
    item def HumidityData {
        attribute value : Real;
    }
    item def OccupancyData {
        attribute isOccupied : Boolean;
    }
    item def LightLevelData {
        attribute value : Real;
    }
    item def AirQualityData {
        attribute co2Level : Real;
    }
    item def PowerData {
        attribute value : PowerValue;
    }
    item def HVACCommand {
        attribute targetTemperature : TemperatureValue;
        attribute fanSpeed : Real;
        attribute mode : Integer;
    }
    item def LightingCommand {
        attribute brightness : Real;
    }
    item def SecurityCommand {
        attribute armed : Boolean;
    }
    item def EmergencyAlert;
    item def EmergencyResolvedAlert;

    action def ProcessData {
        in tempData : TemperatureData;
        in humData : HumidityData;
        in occData : OccupancyData;
        in lightData : LightLevelData;
        in airData : AirQualityData;
        in powerData : PowerData;
        out hvacCmd : HVACCommand;
        out lightCmd : LightingCommand;
        out secCmd : SecurityCommand;
    }

    action def ControlHVAC {
        in currentTemp : TemperatureValue;
        in isOccupied : Boolean;
        out cmd : HVACCommand;
    }

    action def ControlLighting {
        in ambientLight : Real;
        in isOccupied : Boolean;
        out cmd : LightingCommand;
    }

    action def ControlSecurity {
        in isOccupied : Boolean;
        out cmd : SecurityCommand;
    }

    part def TemperatureSensor {
        port sensorPort {
            out sensorData : TemperatureData;
        }
    }
    part def HumiditySensor {
        port sensorPort {
            out sensorData : HumidityData;
        }
    }
    part def OccupancySensor {
        port sensorPort {
            out sensorData : OccupancyData;
        }
    }
    part def LightSensor {
        port sensorPort {
            out sensorData : LightLevelData;
        }
    }
    part def AirQualitySensor {
        port sensorPort {
            out sensorData : AirQualityData;
        }
    }
    part def EnergyMeter {
        port meterPort {
            out meterData : PowerData;
        }
    }
    part def HVACUnit {
        port hvacPort {
            in hvacCmd : HVACCommand;
        }
    }
    part def LightingFixture {
        port lightPort {
            in lightCmd : LightingCommand;
        }
    }
    part def SecuritySystem {
        port secPort {
            in secCmd : SecurityCommand;
        }
    }

    part def CentralController {
        attribute isOccupied : Boolean = false;
        attribute emergencyActive : Boolean = false;
        attribute targetTemp : TemperatureValue = 22.0;
        attribute maxPower : PowerValue = 50.0;

        port tempIn {
            in tempData : TemperatureData;
        }
        port humIn {
            in humData : HumidityData;
        }
        port occIn {
            in occData : OccupancyData;
        }
        port lightIn {
            in lightData : LightLevelData;
        }
        port airIn {
            in airData : AirQualityData;
        }
        port powerIn {
            in powerData : PowerData;
        }
        port hvacOut {
            out hvacCmd : HVACCommand;
        }
        port lightOut {
            out lightCmd : LightingCommand;
        }
        port secOut {
            out secCmd : SecurityCommand;
        }

        perform action processData : ProcessData;

        exhibit state basState {
            entry; then normal;
            state normal {
                entry; then occupied;
                state occupied;
                accept when isOccupied == false then unoccupied;
                state unoccupied;
                accept when isOccupied == true then occupied;
                accept when emergencyActive == true then emergency;
            }
            state emergency;
            accept when emergencyActive == false then normal;
        }
    }

    part def Building {
        part controller : CentralController;
        part tempSensors : TemperatureSensor[*];
        part humSensors : HumiditySensor[*];
        part occSensors : OccupancySensor[*];
        part lightSensors : LightSensor[*];
        part airSensors : AirQualitySensor[*];
        part hvacUnits : HVACUnit[*];
        part lightingFixtures : LightingFixture[*];
        part securitySystem : SecuritySystem;
        part energyMeter : EnergyMeter;

        connection tempConn connect tempSensors.sensorPort to controller.tempIn;
        connection humConn connect humSensors.sensorPort to controller.humIn;
        connection occConn connect occSensors.sensorPort to controller.occIn;
        connection lightConn connect lightSensors.sensorPort to controller.lightIn;
        connection airConn connect airSensors.sensorPort to controller.airIn;
        connection powerConn connect energyMeter.meterPort to controller.powerIn;
        connection hvacConn connect controller.hvacOut to hvacUnits.hvacPort;
        connection lightingConn connect controller.lightOut to lightingFixtures.lightPort;
        connection securityConn connect controller.secOut to securitySystem.secPort;
    }

    part building : Building;

    requirement def OccupantComfortReq {
        doc /* The BAS shall maintain indoor temperature between 20 and 24 degrees Celsius and humidity between 30 and 60 percent during occupied hours. */
        attribute indoorTemp : TemperatureValue;
        attribute indoorHumidity : Real;
        attribute minTemp : TemperatureValue = 20.0;
        attribute maxTemp : TemperatureValue = 24.0;
        attribute minHumidity : Real = 30.0;
        attribute maxHumidity : Real = 60.0;
        require constraint { indoorTemp >= minTemp && indoorTemp <= maxTemp && indoorHumidity >= minHumidity && indoorHumidity <= maxHumidity }
    }

    requirement def EnergyEfficiencyReq {
        doc /* The BAS shall minimize power consumption during unoccupied mode. */
        attribute unoccupiedPower : PowerValue;
        attribute maxUnoccupiedPower : PowerValue = 30.0;
        require constraint { unoccupiedPower <= maxUnoccupiedPower }
    }

    requirement def LightingControlReq {
        doc /* The BAS shall adjust lighting to maintain at least 300 lux in occupied spaces. */
        attribute workspaceIlluminance : Real;
        attribute minIlluminance : Real = 300.0;
        require constraint { workspaceIlluminance >= minIlluminance }
    }

    requirement def AirQualityReq {
        doc /* The BAS shall maintain CO2 concentration below 1000 ppm in occupied areas. */
        attribute co2Level : Real;
        attribute maxCO2 : Real = 1000.0;
        require constraint { co2Level <= maxCO2 }
    }

    requirement def SecurityReq {
        doc /* The BAS shall arm the security system during unoccupied periods. */
        attribute isOccupied : Boolean;
        attribute securityArmed : Boolean;
        require constraint { isOccupied == false implies securityArmed == true }
    }

    requirement def EmergencyResponseReq {
        doc /* The BAS shall enter emergency mode upon detecting critical events. */
        attribute emergencyDetected : Boolean;
        attribute systemInEmergencyMode : Boolean;
        require constraint { emergencyDetected == true implies systemInEmergencyMode == true }
    }
}
