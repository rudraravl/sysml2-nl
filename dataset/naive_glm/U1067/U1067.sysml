package NestThermostatSystem {
    import ScalarValues::*;
    
    value type Temperature :> Real { unit "Celsius"; }
    value type Humidity :> Real { unit "Percent"; }
    value type Distance :> Real { unit "Meter"; }
    
    item def TemperatureSample {
        value temp : Temperature;
    }
    item def HumiditySample {
        value humidity : Humidity;
    }
    item def OccupancySample {
        value occupied : Boolean;
        value distance : Distance;
    }
    item def UserCommand {
        value setpoint : Temperature;
        value mode : String;
    }
    item def ScheduleEntry {
        value time : String;
        value setpoint : Temperature;
    }
    
    requirement def ClimateControlRequirement {
        doc "Maintain comfortable temperature while optimizing energy consumption."
    }
    
    requirement def LearningRequirement {
        doc "Learn user habits and temperature preferences over time to build an optimized schedule."
    }
    
    part def HVACSystem {
        in port furnaceControl : Boolean;
        in port acControl : Boolean;
        in port fanControl : Boolean;
        
        attribute isHeating : Boolean;
        attribute isCooling : Boolean;
    }
    
    part def Sensor {
        abstract;
    }
    
    part def TemperatureSensor :> Sensor {
        out port tempReading : TemperatureSample;
    }
    
    part def HumiditySensor :> Sensor {
        out port humidityReading : HumiditySample;
    }
    
    part def OccupancySensor :> Sensor {
        attribute range : Distance = 6.0;
        out port occupancyReading : OccupancySample;
    }
    
    part def TouchDisplay {
        in port currentTemp : Temperature;
        in port currentMode : String;
        out port userCommand : UserCommand;
    }
    
    part def WiFiModule {
        port internetPort;
        out port remoteCommand : UserCommand;
        in port systemStatus : String;
    }
    
    part def LearningModule {
        in port manualAdjustments : UserCommand;
        in port occupancyPatterns : OccupancySample;
        out port optimizedSchedule : ScheduleEntry;
    }
    
    part def ControlProcessor {
        in port tempInput : TemperatureSample;
        in port humidityInput : HumiditySample;
        in port occupancyInput : OccupancySample;
        in port userCmdInput : UserCommand;
        in port learnedSchedule : ScheduleEntry;
        
        out port furnaceCmd : Boolean;
        out port acCmd : Boolean;
        out port displayTemp : Temperature;
        out port displayMode : String;
        out port wifiStatus : String;
        
        attribute setpoint : Temperature = 22.0;
        attribute ecoModeTimeout : Integer = 120;
        attribute timeSinceLastOccupancy : Integer = 0;
        attribute currentMode : String = "Idle";
        
        state climateControl {
            entry { currentMode = "Idle"; }
            state Idle {
                entry { furnaceCmd = false; acCmd = false; }
                transition to Heating
                    when tempInput.temp < setpoint;
                transition to Cooling
                    when tempInput.temp > setpoint;
                transition to EcoMode
                    when occupancyInput.occupied == false and timeSinceLastOccupancy > ecoModeTimeout;
                transition to AwayMode
                    when userCmdInput.mode == "Away";
            }
            state Heating {
                entry { furnaceCmd = true; acCmd = false; currentMode = "Heating"; }
                transition to Idle
                    when tempInput.temp >= setpoint;
            }
            state Cooling {
                entry { furnaceCmd = false; acCmd = true; currentMode = "Cooling"; }
                transition to Idle
                    when tempInput.temp <= setpoint;
            }
            state EcoMode {
                entry { furnaceCmd = false; acCmd = false; currentMode = "Eco"; }
                transition to Idle
                    when occupancyInput.occupied == true;
            }
            state AwayMode {
                entry { furnaceCmd = false; acCmd = false; currentMode = "Away"; }
                transition to Idle
                    when userCmdInput.mode == "Home";
            }
        }
    }
    
    part def NestThermostat {
        part controlProcessor : ControlProcessor;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part occupancySensor : OccupancySensor;
        part display : TouchDisplay;
        part wifi : WiFiModule;
        part learningModule : LearningModule;
        
        connection tempSensorToProcessor connect tempSensor.tempReading to controlProcessor.tempInput;
        connection humiditySensorToProcessor connect humiditySensor.humidityReading to controlProcessor.humidityInput;
        connection occupancySensorToProcessor connect occupancySensor.occupancyReading to controlProcessor.occupancyInput;
        connection displayToProcessor connect display.userCommand to controlProcessor.userCmdInput;
        connection wifiToProcessor connect wifi.remoteCommand to controlProcessor.userCmdInput;
        connection learningToProcessor connect learningModule.optimizedSchedule to controlProcessor.learnedSchedule;
        connection processorToDisplayTemp connect controlProcessor.displayTemp to display.currentTemp;
        connection processorToDisplayMode connect controlProcessor.displayMode to display.currentMode;
        connection processorToWifi connect controlProcessor.wifiStatus to wifi.systemStatus;
        connection displayToLearning connect display.userCommand to learningModule.manualAdjustments;
        connection occupancyToLearning connect occupancySensor.occupancyReading to learningModule.occupancyPatterns;
    }
    
    part def NestSystem {
        part thermostat : NestThermostat;
        part hvac : HVACSystem;
        
        connection processorToHVACFurnace connect thermostat.controlProcessor.furnaceCmd to hvac.furnaceControl;
        connection processorToHVACAC connect thermostat.controlProcessor.acCmd to hvac.acControl;
        
        satisfy ClimateControlRequirement by thermostat;
        satisfy LearningRequirement by thermostat.learningModule;
    }
}
