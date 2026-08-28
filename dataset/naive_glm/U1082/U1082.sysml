package HomeOfTheFuture {
    import ISQ::*;
    import ScalarValues::*;

    // Value Types
    value def TemperatureValue :> Real { unit 'C'; }
    value def HumidityValue :> Real { unit '%'; }
    value def LightLevel :> Real { unit 'lux'; }
    value def PowerValue :> Real { unit 'kW'; }
    value def EnergyValue :> Real { unit 'kWh'; }
    value def AirQualityIndex :> Real { unit 'AQI'; }
    value def TimeValue :> Real { unit 'h'; }

    // Items
    item def EnvironmentalData {
        attribute temp : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute airQuality : AirQualityIndex;
        attribute ambientLight : LightLevel;
    }
    item def OccupancyData {
        attribute isOccupied : Boolean;
        attribute roomId : String;
    }
    item def UserPreferences {
        attribute desiredTemp : TemperatureValue;
        attribute wakeTime : TimeValue;
        attribute leaveTime : TimeValue;
        attribute returnTime : TimeValue;
    }
    item def ClimateCommand {
        attribute mode : String; // "comfort", "economy"
    }
    item def LightingCommand {
        attribute scene : String; // "morning", "evening", "night"
    }
    item def SecurityCommand {
        attribute state : String; // "arm_away", "arm_stay", "disarm"
    }
    item def PowerCommand {
        attribute targetAppliance : String;
        attribute action : String;
    }

    // Ports
    port def DataOutPort {
        out item data;
    }
    port def DataInPort {
        in item data;
    }
    port def PowerOutPort {
        out attribute power : PowerValue;
    }
    port def PowerInPort {
        in attribute power : PowerValue;
    }

    // Sensors
    part def EnvironmentalSensor {
        port dataOut : DataOutPort;
        attribute currentData : EnvironmentalData;
        action def senseEnvironment {
            out data : EnvironmentalData;
        }
        perform senseEnvironment;
    }
    part def OccupancySensor {
        port dataOut : DataOutPort;
        attribute currentData : OccupancyData;
        action def detectOccupancy {
            out data : OccupancyData;
        }
        perform detectOccupancy;
    }

    // Subsystems
    part def ClimateControlSystem {
        port dataIn : DataInPort;
        port cmdIn : DataInPort;
        attribute currentMode : String = "comfort";
        state def ClimateBehavior {
            entry; then Comfort;
            state Comfort;
            state Economy;
            transition comfort_to_economy
                first Comfort if currentMode == "economy" then Economy;
            transition economy_to_comfort
                first Economy if currentMode == "comfort" then Comfort;
        }
        perform ClimateBehavior;
    }

    part def IntelligentLightingSystem {
        port dataIn : DataInPort;
        port cmdIn : DataInPort;
        attribute currentScene : String = "morning";
        state def LightingBehavior {
            entry; then Morning;
            state Morning;
            state Evening;
            state Night;
            transition morning_to_evening
                first Morning if currentScene == "evening" then Evening;
            transition evening_to_night
                first Evening if currentScene == "night" then Night;
            transition night_to_morning
                first Night if currentScene == "morning" then Morning;
        }
        perform LightingBehavior;
    }

    part def SecuritySystem {
        port dataIn : DataInPort;
        port cmdIn : DataInPort;
        attribute currentState : String = "disarmed";
        attribute alarmTriggered : Boolean = false;
        state def SecurityBehavior {
            entry; then Disarmed;
            state Disarmed;
            state ArmedAway;
            state ArmedStay;
            state AlarmActive;
            transition disarmed_to_away
                first Disarmed if currentState == "arm_away" then ArmedAway;
            transition disarmed_to_stay
                first Disarmed if currentState == "arm_stay" then ArmedStay;
            transition away_to_alarm
                first ArmedAway if alarmTriggered == true then AlarmActive;
            transition stay_to_alarm
                first ArmedStay if alarmTriggered == true then AlarmActive;
            transition alarm_to_disarmed
                first AlarmActive if currentState == "disarm" then Disarmed;
        }
        perform SecurityBehavior;
    }

    part def SolarPanel {
        port powerOut : PowerOutPort;
        attribute currentPower : PowerValue;
    }
    part def HomeBattery {
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        attribute storedEnergy : EnergyValue;
    }
    part def SmartAppliance {
        port cmdIn : DataInPort;
        port powerIn : PowerInPort;
        attribute isRunning : Boolean = false;
    }

    part def EnergyManagementSystem {
        port solarIn : PowerInPort;
        port batteryIn : PowerOutPort;
        port batteryOut : PowerInPort;
        port gridIn : PowerInPort;
        port applianceCmdOut : DataOutPort;
        attribute solarPower : PowerValue;
        attribute batteryLevel : EnergyValue;
        attribute gridPower : PowerValue;
        attribute powerMode : String = "solar";
        state def EnergyBehavior {
            entry; then SolarPriority;
            state SolarPriority;
            state BatteryDischarge;
            state GridDraw;
            transition solar_to_battery
                first SolarPriority if powerMode == "battery" then BatteryDischarge;
            transition battery_to_grid
                first BatteryDischarge if powerMode == "grid" then GridDraw;
            transition grid_to_solar
                first GridDraw if powerMode == "solar" then SolarPriority;
        }
        perform EnergyBehavior;
    }

    // Central Hub
    part def CentralIntelligenceHub {
        port sensorDataIn : DataInPort;
        port climateCmdOut : DataOutPort;
        port lightingCmdOut : DataOutPort;
        port securityCmdOut : DataOutPort;
        port applianceCmdOut : DataOutPort;
        
        attribute preferences : UserPreferences;
        attribute learnedPatterns : String;
        
        action def processData {
            in data;
            out climateCmd : ClimateCommand;
            out lightingCmd : LightingCommand;
            out securityCmd : SecurityCommand;
        }
        perform processData;
    }

    // Home Assembly
    part def HomeOfTheFutureSystem {
        part hub : CentralIntelligenceHub;
        part envSensors[*] : EnvironmentalSensor;
        part occSensors[*] : OccupancySensor;
        part climate : ClimateControlSystem;
        part lighting : IntelligentLightingSystem;
        part security : SecuritySystem;
        part energy : EnergyManagementSystem;
        part solar : SolarPanel;
        part battery : HomeBattery;
        part appliances[*] : SmartAppliance;

        connection envSensorToHub connect envSensors.dataOut to hub.sensorDataIn;
        connection occSensorToHub connect occSensors.dataOut to hub.sensorDataIn;
        connection hubToClimate connect hub.climateCmdOut to climate.cmdIn;
        connection hubToLighting connect hub.lightingCmdOut to lighting.cmdIn;
        connection hubToSecurity connect hub.securityCmdOut to security.cmdIn;
        connection hubToEnergy connect hub.applianceCmdOut to energy.applianceCmdOut;
        
        connection solarToEnergy connect solar.powerOut to energy.solarIn;
        connection energyToBatteryIn connect energy.batteryIn to battery.powerIn;
        connection batteryToEnergy connect battery.powerOut to energy.batteryOut;
        connection energyToAppliances connect energy.applianceCmdOut to appliances.cmdIn;
    }

    // Requirements
    requirement def HomeOfTheFutureRequirements {
        requirement CentralIntelligenceReq {
            doc /* The system shall have a central intelligence hub to orchestrate the home environment. */
        }
        requirement SensorIntegrationReq {
            doc /* The system shall gather information from environmental and occupancy sensors. */
        }
        requirement ClimateControlReq {
            doc /* The climate control system shall adjust heating, cooling, and ventilation based on occupancy and preferences. */
        }
        requirement IntelligentLightingReq {
            doc /* The lighting system shall adapt based on time of day, natural sunlight, and occupancy. */
        }
        requirement SecurityReq {
            doc /* The security system shall monitor for unauthorized entry and support armed away and armed stay states. */
        }
        requirement EnergyManagementReq {
            doc /* The energy management system shall prioritize renewable energy, store excess power, and schedule smart appliances. */
        }
    }
}
