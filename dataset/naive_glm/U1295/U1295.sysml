package IntelligentHomeControlSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQTime::*;
    import ISQThermodynamics::*;

    // ===== Value Types =====
    attribute def TemperatureValue :> Real { unit '°C'; }
    attribute def HumidityValue :> Real { unit '%'; }
    attribute def LightLevelValue :> Real { unit 'lux'; }
    attribute def PowerValue :> Real { unit 'W'; }
    attribute def EnergyValue :> Real { unit 'kWh'; }
    attribute def BrightnessValue :> Real { unit '%'; }

    // ===== Item Types =====
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute timestamp : DateTime;
    }
    item def HumidityReading {
        attribute value : HumidityValue;
        attribute timestamp : DateTime;
    }
    item def LightReading {
        attribute value : LightLevelValue;
        attribute timestamp : DateTime;
    }
    item def OccupancyReading {
        attribute isOccupied : Boolean;
        attribute timestamp : DateTime;
    }
    item def ClimateCommand {
        attribute targetTemp : TemperatureValue;
        attribute mode : ClimateMode;
    }
    enum ClimateMode { heating, cooling, off, energySaving; }
    item def LightingCommand {
        attribute zoneId : String;
        attribute brightness : BrightnessValue;
        attribute status : Boolean;
    }
    item def SecurityCommand {
        attribute arm : Boolean;
    }
    item def UserPreference {
        attribute preferredTemp : TemperatureValue;
        attribute preferredLightLevel : LightLevelValue;
        attribute awayModeEnabled : Boolean;
    }
    item def SystemStatus {
        attribute currentTemp : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute currentLightLevel : LightLevelValue;
        attribute occupancy : Boolean;
        attribute energyConsumption : EnergyValue;
        attribute securityArmed : Boolean;
    }

    // ===== Ports =====
    port def SensorOut {
        out tempReading : TemperatureReading;
        out humidityReading : HumidityReading;
        out lightReading : LightReading;
        out occupancyReading : OccupancyReading;
    }
    port def TempSensorOut {
        out tempReading : TemperatureReading;
    }
    port def HumiditySensorOut {
        out humidityReading : HumidityReading;
    }
    port def LightSensorOut {
        out lightReading : LightReading;
    }
    port def OccupancySensorOut {
        out occupancyReading : OccupancyReading;
    }
    port def ControllerSensorIn {
        in tempReading : TemperatureReading;
        in humidityReading : HumidityReading;
        in lightReading : LightReading;
        in occupancyReading : OccupancyReading;
    }
    port def ControllerActuatorOut {
        out climateCommand : ClimateCommand;
        out lightingCommand : LightingCommand;
        out securityCommand : SecurityCommand;
    }
    port def ClimateActuatorIn {
        in climateCommand : ClimateCommand;
    }
    port def LightingActuatorIn {
        in lightingCommand : LightingCommand;
    }
    port def SecurityActuatorIn {
        in securityCommand : SecurityCommand;
    }
    port def UserInterfacePort {
        in preference : UserPreference;
        out status : SystemStatus;
    }

    // ===== Parts: Sensors =====
    part def TemperatureSensor {
        port sensorOut : TempSensorOut;
        attribute measuredTemp : TemperatureValue;
        exhibit state sensorBehavior {
            entry action { send sensorOut.tempReading(TemperatureReading{value = measuredTemp, timestamp = now()}); }
            transition idle -> idle after 5 [s] { send sensorOut.tempReading(TemperatureReading{value = measuredTemp, timestamp = now()}); }
        }
    }
    part def HumiditySensor {
        port sensorOut : HumiditySensorOut;
        attribute measuredHumidity : HumidityValue;
        exhibit state sensorBehavior {
            entry action { send sensorOut.humidityReading(HumidityReading{value = measuredHumidity, timestamp = now()}); }
            transition idle -> idle after 5 [s] { send sensorOut.humidityReading(HumidityReading{value = measuredHumidity, timestamp = now()}); }
        }
    }
    part def LightSensor {
        port sensorOut : LightSensorOut;
        attribute measuredLight : LightLevelValue;
        exhibit state sensorBehavior {
            entry action { send sensorOut.lightReading(LightReading{value = measuredLight, timestamp = now()}); }
            transition idle -> idle after 5 [s] { send sensorOut.lightReading(LightReading{value = measuredLight, timestamp = now()}); }
        }
    }
    part def OccupancySensor {
        port sensorOut : OccupancySensorOut;
        attribute detectedOccupancy : Boolean;
        exhibit state sensorBehavior {
            entry action { send sensorOut.occupancyReading(OccupancyReading{isOccupied = detectedOccupancy, timestamp = now()}); }
            transition idle -> idle after 2 [s] { send sensorOut.occupancyReading(OccupancyReading{isOccupied = detectedOccupancy, timestamp = now()}); }
        }
    }

    // ===== Parts: Actuators =====
    part def ClimateActuator {
        port actuatorIn : ClimateActuatorIn;
        attribute currentMode : ClimateMode;
        attribute currentTargetTemp : TemperatureValue;
        exhibit state actuationBehavior {
            entry action { currentMode = ClimateMode::off; }
            state waiting;
            transition waiting -> waiting when actuatorIn.climateCommand? {
                actuatorIn.climateCommand? then {
                    currentTargetTemp = actuatorIn.climateCommand.targetTemp;
                    currentMode = actuatorIn.climateCommand.mode;
                }
            }
        }
    }
    part def LightingActuator {
        port actuatorIn : LightingActuatorIn;
        attribute zoneBrightness : BrightnessValue;
        attribute zoneStatus : Boolean;
        exhibit state actuationBehavior {
            entry action { zoneBrightness = 0; zoneStatus = false; }
            state waiting;
            transition waiting -> waiting when actuatorIn.lightingCommand? {
                actuatorIn.lightingCommand? then {
                    zoneBrightness = actuatorIn.lightingCommand.brightness;
                    zoneStatus = actuatorIn.lightingCommand.status;
                }
            }
        }
    }
    part def SecurityActuator {
        port actuatorIn : SecurityActuatorIn;
        attribute armed : Boolean;
        exhibit state actuationBehavior {
            entry action { armed = false; }
            state waiting;
            transition waiting -> waiting when actuatorIn.securityCommand? {
                actuatorIn.securityCommand? then {
                    armed = actuatorIn.securityCommand.arm;
                }
            }
        }
    }

    // ===== Part: Central Controller =====
    part def CentralController {
        port sensorIn : ControllerSensorIn;
        port actuatorOut : ControllerActuatorOut;
        port uiPort : UserInterfacePort;

        attribute currentTemp : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute currentLightLevel : LightLevelValue;
        attribute isOccupied : Boolean;
        attribute preferredTemp : TemperatureValue;
        attribute preferredLightLevel : LightLevelValue;
        attribute awayModeEnabled : Boolean;
        attribute energyConsumption : EnergyValue;
        attribute securityArmed : Boolean;

        exhibit state controllerStateMachine {
            entry action {
                currentTemp = 22.0;
                currentHumidity = 50.0;
                currentLightLevel = 300.0;
                isOccupied = false;
                preferredTemp = 22.0;
                preferredLightLevel = 400.0;
                awayModeEnabled = false;
                energyConsumption = 0.0;
                securityArmed = false;
            }

            state Uninitialized;
            state Monitoring;
            state Away;

            transition Uninitialized -> Monitoring when sensorIn.occupancyReading? {
                sensorIn.occupancyReading? then {
                    isOccupied = sensorIn.occupancyReading.isOccupied;
                    if isOccupied {
                        // enter monitoring
                    }
                }
            }

            transition Monitoring -> Away when sensorIn.occupancyReading? {
                sensorIn.occupancyReading? then {
                    isOccupied = sensorIn.occupancyReading.isOccupied;
                    if !isOccupied && awayModeEnabled {
                        send actuatorOut.securityCommand(SecurityCommand{arm = true});
                        securityArmed = true;
                        send actuatorOut.climateCommand(ClimateCommand{targetTemp = preferredTemp - 4.0, mode = ClimateMode::energySaving});
                    }
                }
            }

            transition Away -> Monitoring when sensorIn.occupancyReading? {
                sensorIn.occupancyReading? then {
                    isOccupied = sensorIn.occupancyReading.isOccupied;
                    if isOccupied {
                        send actuatorOut.securityCommand(SecurityCommand{arm = false});
                        securityArmed = false;
                        send actuatorOut.climateCommand(ClimateCommand{targetTemp = preferredTemp, mode = ClimateMode::heating});
                    }
                }
            }

            // Continuous monitoring adjustments
            state Monitoring {
                entry action {
                    send actuatorOut.climateCommand(ClimateCommand{targetTemp = preferredTemp, mode = ClimateMode::heating});
                    send actuatorOut.lightingCommand(LightingCommand{zoneId = "living", brightness = 80.0, status = true});
                }
                do action {
                    if sensorIn.tempReading? {
                        sensorIn.tempReading? then {
                            currentTemp = sensorIn.tempReading.value;
                            if currentTemp < preferredTemp {
                                send actuatorOut.climateCommand(ClimateCommand{targetTemp = preferredTemp, mode = ClimateMode::heating});
                            } else if currentTemp > preferredTemp {
                                send actuatorOut.climateCommand(ClimateCommand{targetTemp = preferredTemp, mode = ClimateMode::cooling});
                            }
                        }
                    }
                    if sensorIn.lightReading? {
                        sensorIn.lightReading? then {
                            currentLightLevel = sensorIn.lightReading.value;
                            if currentLightLevel < preferredLightLevel {
                                send actuatorOut.lightingCommand(LightingCommand{zoneId = "living", brightness = 90.0, status = true});
                            } else {
                                send actuatorOut.lightingCommand(LightingCommand{zoneId = "living", brightness = 40.0, status = true});
                            }
                        }
                    }
                    if sensorIn.humidityReading? {
                        sensorIn.humidityReading? then {
                            currentHumidity = sensorIn.humidityReading.value;
                        }
                    }
                }
            }

            state Away {
                entry action {
                    send actuatorOut.climateCommand(ClimateCommand{targetTemp = preferredTemp - 4.0, mode = ClimateMode::energySaving});
                    send actuatorOut.lightingCommand(LightingCommand{zoneId = "living", brightness = 0.0, status = false});
                    send actuatorOut.securityCommand(SecurityCommand{arm = true});
                    securityArmed = true;
                }
            }

            // Handle user preferences
            transition first Uninitialized -> Uninitialized when uiPort.preference? {
                uiPort.preference? then {
                    preferredTemp = uiPort.preference.preferredTemp;
                    preferredLightLevel = uiPort.preference.preferredLightLevel;
                    awayModeEnabled = uiPort.preference.awayModeEnabled;
                }
            }
            transition Monitoring -> Monitoring when uiPort.preference? {
                uiPort.preference? then {
                    preferredTemp = uiPort.preference.preferredTemp;
                    preferredLightLevel = uiPort.preference.preferredLightLevel;
                    awayModeEnabled = uiPort.preference.awayModeEnabled;
                }
            }
            transition Away -> Away when uiPort.preference? {
                uiPort.preference? then {
                    preferredTemp = uiPort.preference.preferredTemp;
                    preferredLightLevel = uiPort.preference.preferredLightLevel;
                    awayModeEnabled = uiPort.preference.awayModeEnabled;
                }
            }
        }
    }

    // ===== Part: User Interface =====
    part def UserInterface {
        port uiPort : UserInterfacePort;
        attribute displayedStatus : SystemStatus;
        exhibit state uiBehavior {
            state idle;
            transition idle -> idle when uiPort.status? {
                uiPort.status? then {
                    displayedStatus = uiPort.status;
                }
            }
        }
    }

    // ===== Requirements =====
    requirement def ComfortRequirement {
        doc "The system shall maintain the home temperature within the user's preferred range when occupied."
        attribute preferredTempRange : TemperatureValue;
        subject controller : CentralController;
        require constraint { controller.currentTemp >= preferredTempRange - 1.0 and controller.currentTemp <= preferredTempRange + 1.0 }
    }
    requirement def EnergyEfficiencyRequirement {
        doc "The system shall reduce energy consumption when the home is unoccupied and away mode is enabled."
        subject controller : CentralController;
        require constraint { controller.isOccupied == false and controller.awayModeEnabled == true implies controller.energyConsumption < 1.0 }
    }
    requirement def SecurityRequirement {
        doc "The system shall arm the security system when the home is unoccupied and away mode is enabled."
        subject controller : CentralController;
        require constraint { controller.isOccupied == false and controller.awayModeEnabled == true implies controller.securityArmed == true }
    }
    requirement def OccupancyResponseRequirement {
        doc "The system shall transition to monitoring state within 5 seconds of detecting occupancy."
        subject controller : CentralController;
        require constraint { controller.isOccupied == true implies controller.controllerStateMachine.currentState == "Monitoring" }
    }
    requirement def UserInteractionRequirement {
        doc "The system shall allow users to set preferences and view current system status."
        subject ui : UserInterface;
        subject controller : CentralController;
        require constraint { ui.uiPort.preference.isSet and ui.displayedStatus.currentTemp == controller.currentTemp }
    }

    // ===== Top-level System =====
    part def IntelligentHomeSystem {
        requirement comfortReq : ComfortRequirement { preferredTempRange = 22.0; }
        requirement energyReq : EnergyEfficiencyRequirement;
        requirement securityReq : SecurityRequirement;
        requirement occupancyReq : OccupancyResponseRequirement;
        requirement userReq : UserInteractionRequirement;

        part controller : CentralController {
            satisfy comfortReq;
            satisfy energyReq;
            satisfy securityReq;
            satisfy occupancyReq;
            satisfy userReq;
        }
        part ui : UserInterface;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part lightSensor : LightSensor;
        part occupancySensor : OccupancySensor;
        part climateActuator : ClimateActuator;
        part lightingActuator : LightingActuator;
        part securityActuator : SecurityActuator;

        // Connections from sensors to controller
        connection tempSensor.sensorOut.tempReading to controller.sensorIn.tempReading;
        connection humiditySensor.sensorOut.humidityReading to controller.sensorIn.humidityReading;
        connection lightSensor.sensorOut.lightReading to controller.sensorIn.lightReading;
        connection occupancySensor.sensorOut.occupancyReading to controller.sensorIn.occupancyReading;

        // Connections from controller to actuators
        connection controller.actuatorOut.climateCommand to climateActuator.actuatorIn.climateCommand;
        connection controller.actuatorOut.lightingCommand to lightingActuator.actuatorIn.lightingCommand;
        connection controller.actuatorOut.securityCommand to securityActuator.actuatorIn.securityCommand;

        // Connection between controller and user interface
        connection controller.uiPort.status to ui.uiPort.status;
        connection ui.uiPort.preference to controller.uiPort.preference;
    }
}
