package SmartHomeSystem {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    value type TemperatureValue > Real { unit 'degC'; }
    value type HumidityValue > Real { unit '%'; }
    value type LightLevelValue > Real { unit 'lux'; }
    value type PowerValue > Real { unit 'kW'; }
    value type AirQualityValue > Real { unit 'ppm'; }

    // Items
    item def EnvironmentalData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute airQuality : AirQualityValue;
        attribute naturalLight : LightLevelValue;
    }

    item def OccupancyData {
        attribute isOccupied : Boolean;
        attribute isSleeping : Boolean;
        attribute isVacant : Boolean;
    }

    item def ClimateCommand {
        attribute targetTemp : TemperatureValue;
        attribute fanSpeed : Integer;
    }

    item def LightingCommand {
        attribute brightness : Real; // 0.0 to 1.0
        attribute isOn : Boolean;
    }

    item def SecurityCommand {
        attribute mode : String; // "disarmed", "armed_home", "armed_away"
    }

    item def SecurityAlert {
        attribute alertType : String;
        attribute location : String;
    }

    item def PowerData {
        attribute currentConsumption : PowerValue;
        attribute peakThreshold : PowerValue;
    }

    item def LoadShedCommand {
        attribute reduceLoadBy : PowerValue;
    }

    // Ports
    port def EnvironmentalDataOut {
        out data : EnvironmentalData;
    }
    port def EnvironmentalDataIn {
        in data : EnvironmentalData;
    }
    port def OccupancyDataOut {
        out data : OccupancyData;
    }
    port def OccupancyDataIn {
        in data : OccupancyData;
    }
    port def ClimateCmdOut {
        out cmd : ClimateCommand;
    }
    port def ClimateCmdIn {
        in cmd : ClimateCommand;
    }
    port def LightingCmdOut {
        out cmd : LightingCommand;
    }
    port def LightingCmdIn {
        in cmd : LightingCommand;
    }
    port def SecurityCmdOut {
        out cmd : SecurityCommand;
    }
    port def SecurityCmdIn {
        in cmd : SecurityCommand;
    }
    port def SecurityAlertOut {
        out alert : SecurityAlert;
    }
    port def SecurityAlertIn {
        in alert : SecurityAlert;
    }
    port def PowerDataOut {
        out data : PowerData;
    }
    port def PowerDataIn {
        in data : PowerData;
    }
    port def LoadShedCmdOut {
        out cmd : LoadShedCommand;
    }
    port def LoadShedCmdIn {
        in cmd : LoadShedCommand;
    }

    // Requirements
    requirement def ComfortRequirement {
        doc /* The system shall maintain a comfortable environment. */
        subject : SmartHome;
        objective {
            doc /* Temperature must be maintained within user preferences. */
        }
    }

    requirement def SecurityRequirement {
        doc /* The system shall secure the home. */
        subject : SmartHome;
        objective {
            doc /* System must arm when vacant and alert on breach. */
        }
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall optimize energy usage. */
        subject : SmartHome;
        objective {
            doc /* System must prevent overloading and reduce load during peak times. */
        }
    }

    // Parts
    part def EnvironmentalSensor {
        port dataOut : EnvironmentalDataOut;
        attribute measuredData : EnvironmentalData;
        
        action def senseEnvironment {
            in currentTemp : TemperatureValue;
            out data : EnvironmentalData;
        }
    }

    part def OccupancySensor {
        port dataOut : OccupancyDataOut;
        attribute measuredData : OccupancyData;
    }

    part def ClimateControlSystem {
        port cmdIn : ClimateCmdIn;
        port loadShedIn : LoadShedCmdIn;
        
        state machine ClimateBehavior {
            state Idle;
            state Heating;
            state Cooling;
            transition idle_to_heating initial to Heating when cmdIn.cmd.targetTemp > 20;
            transition heating_to_idle Heating to Idle when cmdIn.cmd.targetTemp <= 20;
        }
    }

    part def LightingSystem {
        port cmdIn : LightingCmdIn;
        
        state machine LightingBehavior {
            state Off;
            state On;
            transition initial to Off;
            transition off_to_on Off to On when cmdIn.cmd.isOn == true;
            transition on_to_off On to Off when cmdIn.cmd.isOn == false;
        }
    }

    part def SecuritySystem {
        port cmdIn : SecurityCmdIn;
        port alertOut : SecurityAlertOut;
        
        state machine SecurityBehavior {
            state Disarmed;
            state ArmedHome;
            state ArmedAway;
            transition initial to Disarmed;
            transition disarmed_to_away Disarmed to ArmedAway when cmdIn.cmd.mode == "armed_away";
            transition disarmed_to_home Disarmed to ArmedHome when cmdIn.cmd.mode == "armed_home";
            transition home_to_disarmed ArmedHome to Disarmed when cmdIn.cmd.mode == "disarmed";
            transition away_to_disarmed ArmedAway to Disarmed when cmdIn.cmd.mode == "disarmed";
        }
    }

    part def EnergyManagementSystem {
        port dataOut : PowerDataOut;
        attribute powerData : PowerData;
    }

    part def HomeAutomationController {
        port envIn : EnvironmentalDataIn;
        port occIn : OccupancyDataIn;
        port powerIn : PowerDataIn;
        port alertIn : SecurityAlertIn;
        
        port climateOut : ClimateCmdOut;
        port lightingOut : LightingCmdOut;
        port securityOut : SecurityCmdOut;
        port loadShedOut : LoadShedCmdOut;
        
        attribute targetTemp : TemperatureValue = 22;
        
        state machine ControllerBehavior {
            state Occupied {
                // send climate commands, lighting on
            }
            state Vacant {
                // send security armed_away, lower temp
            }
            state Sleeping {
                // send security armed_home, lights off
            }
            
            transition initial to Occupied;
            transition occupied_to_vacant Occupied to Vacant when occIn.data.isVacant == true;
            transition vacant_to_occupied Vacant to Occupied when occIn.data.isOccupied == true;
            transition occupied_to_sleeping Occupied to Sleeping when occIn.data.isSleeping == true;
            transition sleeping_to_occupied Sleeping to Occupied when occIn.data.isSleeping == false;
        }
    }

    part def SmartHome {
        requirement comfortReq : ComfortRequirement;
        requirement securityReq : SecurityRequirement;
        requirement energyReq : EnergyEfficiencyRequirement;
        
        part controller : HomeAutomationController;
        part envSensor : EnvironmentalSensor;
        part occSensor : OccupancySensor;
        part climate : ClimateControlSystem;
        part lighting : LightingSystem;
        part security : SecuritySystem;
        part energy : EnergyManagementSystem;
        
        connection envSensor.dataOut to controller.envIn;
        connection occSensor.dataOut to controller.occIn;
        connection energy.dataOut to controller.powerIn;
        connection security.alertOut to controller.alertIn;
        
        connection controller.climateOut to climate.cmdIn;
        connection controller.lightingOut to lighting.cmdIn;
        connection controller.securityOut to security.cmdIn;
        connection controller.loadShedOut to climate.loadShedIn;
    }
}
