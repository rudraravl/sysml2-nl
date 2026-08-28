package BuildingAutomationSystem {
    import ScalarValues::*;

    // ============================================================
    // Units
    // ============================================================
    unit 'degC' :> Real;
    unit 'percent' :> Real;
    unit 'ppm' :> Real;
    unit 'lux' :> Real;
    unit 'kW' :> Real;
    unit 'Hz' :> Real;
    unit 'rpm' :> Real;

    // ============================================================
    // Value Types
    // ============================================================
    value def TemperatureValue :> Real;
    value def HumidityValue :> Real;
    value def CO2LevelValue :> Real;
    value def IlluminanceValue :> Real;
    value def PowerValue :> Real;
    value def FanSpeedValue :> Real;
    value def BrightnessLevelValue :> Real;
    value def FrequencyValue :> Real;

    // ============================================================
    // Item Definitions (Sensor Data and Commands)
    // ============================================================
    item def TemperatureReading {
        attribute value : TemperatureValue;
        attribute zoneId : String;
        attribute timestamp : String;
    }

    item def HumidityReading {
        attribute value : HumidityValue;
        attribute zoneId : String;
        attribute timestamp : String;
    }

    item def OccupancyReading {
        attribute isOccupied : Boolean;
        attribute zoneId : String;
        attribute timestamp : String;
    }

    item def IlluminanceReading {
        attribute value : IlluminanceValue;
        attribute zoneId : String;
        attribute timestamp : String;
    }

    item def CO2Reading {
        attribute value : CO2LevelValue;
        attribute zoneId : String;
        attribute timestamp : String;
    }

    item def PowerReading {
        attribute value : PowerValue;
        attribute zoneId : String;
        attribute timestamp : String;
    }

    item def HVACCommand {
        attribute zoneId : String;
        attribute mode : String;  // "heat", "cool", "ventilate", "off"
        attribute targetTemperature : TemperatureValue;
        attribute fanSpeed : FanSpeedValue;
    }

    item def LightingCommand {
        attribute zoneId : String;
        attribute isOn : Boolean;
        attribute brightness : BrightnessLevelValue;
    }

    item def SecurityCommand {
        attribute zoneId : String;
        attribute armState : Boolean;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def TempSensorPort {
        out reading : TemperatureReading;
    }
    port def HumiditySensorPort {
        out reading : HumidityReading;
    }
    port def OccupancySensorPort {
        out reading : OccupancyReading;
    }
    port def IlluminanceSensorPort {
        out reading : IlluminanceReading;
    }
    port def CO2SensorPort {
        out reading : CO2Reading;
    }
    port def PowerSensorPort {
        out reading : PowerReading;
    }
    port def HVACCmdPort {
        in command : HVACCommand;
    }
    port def LightingCmdPort {
        in command : LightingCommand;
    }
    port def SecurityCmdPort {
        in command : SecurityCommand;
    }

    // ============================================================
    // Sensor Parts
    // ============================================================
    part def TemperatureSensor {
        attribute zoneId : String;
        attribute samplingRate : FrequencyValue = 1.0;
        port sensorOut : TempSensorPort;

        action def sample {
            out reading : TemperatureReading;
        }
    }

    part def HumiditySensor {
        attribute zoneId : String;
        attribute samplingRate : FrequencyValue = 1.0;
        port sensorOut : HumiditySensorPort;

        action def sample {
            out reading : HumidityReading;
        }
    }

    part def OccupancySensor {
        attribute zoneId : String;
        attribute samplingRate : FrequencyValue = 2.0;
        port sensorOut : OccupancySensorPort;

        action def detect {
            out reading : OccupancyReading;
        }
    }

    part def IlluminanceSensor {
        attribute zoneId : String;
        attribute samplingRate : FrequencyValue = 2.0;
        port sensorOut : IlluminanceSensorPort;

        action def sample {
            out reading : IlluminanceReading;
        }
    }

    part def CO2Sensor {
        attribute zoneId : String;
        attribute samplingRate : FrequencyValue = 0.5;
        port sensorOut : CO2SensorPort;

        action def sample {
            out reading : CO2Reading;
        }
    }

    part def EnergyMeter {
        attribute zoneId : String;
        attribute samplingRate : FrequencyValue = 0.2;
        attribute instantaneousPower : PowerValue;
        port meterOut : PowerSensorPort;

        action def measure {
            out reading : PowerReading;
        }
    }

    // ============================================================
    // Actuator / Subsystem Parts
    // ============================================================
    part def HVACUnit {
        attribute zoneId : String;
        attribute currentMode : String;
        attribute currentTargetTemp : TemperatureValue;
        attribute currentFanSpeed : FanSpeedValue;
        port cmdIn : HVACCmdPort;

        state machine HVACUnitStateMachine {
            initial Off;
            state Off;
            state Heating;
            state Cooling;
            state Ventilating;

            transition Off -> Heating when cmdIn.command.mode == "heat";
            transition Off -> Cooling when cmdIn.command.mode == "cool";
            transition Off -> Ventilating when cmdIn.command.mode == "ventilate";
            transition Heating -> Off when cmdIn.command.mode == "off";
            transition Cooling -> Off when cmdIn.command.mode == "off";
            transition Ventilating -> Off when cmdIn.command.mode == "off";

            state Heating {
                entry action { /* energize heating coil, set fan */ }
                exit action { /* de-energize heating coil */ }
            }
            state Cooling {
                entry action { /* energize compressor, set fan */ }
                exit action { /* de-energize compressor */ }
            }
            state Ventilating {
                entry action { /* activate ventilation fan */ }
                exit action { /* deactivate ventilation fan */ }
            }
        }
    }

    part def LightingFixture {
        attribute zoneId : String;
        attribute isOn : Boolean;
        attribute currentBrightness : BrightnessLevelValue;
        port cmdIn : LightingCmdPort;

        state machine LightingFixtureStateMachine {
            initial Off;
            state Off;
            state On;

            transition Off -> On when cmdIn.command.isOn == true;
            transition On -> Off when cmdIn.command.isOn == false;

            state On {
                entry action { /* set brightness to cmdIn.command.brightness */ }
                exit action { /* turn fixture off */ }
            }
        }
    }

    part def SecurityPanel {
        attribute zoneId : String;
        attribute isArmed : Boolean;
        port cmdIn : SecurityCmdPort;

        state machine SecurityPanelStateMachine {
            initial Disarmed;
            state Disarmed;
            state Armed;

            transition Disarmed -> Armed when cmdIn.command.armState == true;
            transition Armed -> Disarmed when cmdIn.command.armState == false;

            state Armed {
                entry action { /* enable intrusion detectors, alert monitoring */ }
                exit action { /* disable intrusion detectors */ }
            }
            state Disarmed {
                entry action { /* maintain access control only */ }
            }
        }
    }

    // ============================================================
    // Central Controller
    // ============================================================
    part def CentralController {
        // Input ports (multiplexed to support multiple sensors)
        port tempSensorIn : TempSensorPort[0..*];
        port humiditySensorIn : HumiditySensorPort[0..*];
        port occupancySensorIn : OccupancySensorPort[0..*];
        port illuminanceSensorIn : IlluminanceSensorPort[0..*];
        port co2SensorIn : CO2SensorPort[0..*];
        port powerMeterIn : PowerSensorPort;

        // Output ports (multiplexed to support multiple actuators)
        port hvacCmdOut : HVACCmdPort[0..*];
        port lightingCmdOut : LightingCmdPort[0..*];
        port securityCmdOut : SecurityCmdPort;

        // Operational parameters and setpoints
        attribute occupiedTempSetpoint : TemperatureValue = 22.0;
        attribute unoccupiedTempSetpoint : TemperatureValue = 18.0;
        attribute occupiedBrightnessLevel : BrightnessLevelValue = 80.0;
        attribute unoccupiedBrightnessLevel : BrightnessLevelValue = 0.0;
        attribute co2Threshold : CO2LevelValue = 1000.0;
        attribute co2VentilationFanSpeed : FanSpeedValue = 100.0;
        attribute powerThreshold : PowerValue = 500.0;
        attribute operatingSchedule : String = "weekday";
        attribute currentTimeOfDay : String = "day";
        attribute emergencyDetected : Boolean = false;
        attribute buildingOccupied : Boolean = false;

        // Internal actions
        action def evaluateSensorData {
            in tempReadings : TemperatureReading[0..*];
            in humidityReadings : HumidityReading[0..*];
            in occupancyReadings : OccupancyReading[0..*];
            in illuminanceReadings : IlluminanceReading[0..*];
            in co2Readings : CO2Reading[0..*];
            in powerReading : PowerReading;
            out buildingOccupied : Boolean;
        }

        action def generateHVACCommands {
            in occupied : Boolean;
            in tempReadings : TemperatureReading[0..*];
            in co2Readings : CO2Reading[0..*];
            in co2Threshold : CO2LevelValue;
            in occupiedTempSetpoint : TemperatureValue;
            in unoccupiedTempSetpoint : TemperatureValue;
            out commands : HVACCommand[0..*];
        }

        action def generateLightingCommands {
            in occupied : Boolean;
            in illuminanceLevels : IlluminanceReading[0..*];
            in occupiedBrightnessLevel : BrightnessLevelValue;
            in unoccupiedBrightnessLevel : BrightnessLevelValue;
            out commands : LightingCommand[0..*];
        }

        action def generateSecurityCommand {
            in occupied : Boolean;
            in timeOfDay : String;
            in operatingSchedule : String;
            out command : SecurityCommand;
        }

        action def evaluateEnergyConsumption {
            in powerReading : PowerReading;
            in powerThreshold : PowerValue;
            out commands : HVACCommand[0..*];
        }

        action def detectEmergency {
            in co2Readings : CO2Reading[0..*];
            in powerReading : PowerReading;
            out emergencyDetected : Boolean;
        }

        // Controller behavior
        state machine ControllerStateMachine {
            initial Normal;
            state Normal;
            state Emergency;

            state Normal {
                initial Unoccupied;
                state Occupied;
                state Unoccupied;

                transition Unoccupied -> Occupied when buildingOccupied;
                transition Occupied -> Unoccupied when !buildingOccupied;

                state Occupied {
                    entry action { /* engage occupied climate and lighting setpoints */ }
                    exit action { /* save occupancy-based settings */ }
                }
                state Unoccupied {
                    entry action { /* engage energy-saving setpoints */ }
                    exit action { /* restore settings before occupied */ }
                }
            }

            state Emergency {
                entry action { /* override HVAC, lighting, security for safety */ }
                exit action { /* restore previous operating mode */ }
            }

            transition Normal -> Emergency when emergencyDetected;
            transition Emergency -> Normal when !emergencyDetected;
        }
    }

    // ============================================================
    // Building Automation System (Top-Level Composite)
    // ============================================================
    part def BuildingAutomationSystem {
        part centralController : CentralController;

        // Sensors
        part tempSensors : TemperatureSensor[4];
        part humiditySensors : HumiditySensor[4];
        part occupancySensors : OccupancySensor[8];
        part illuminanceSensors : IlluminanceSensor[6];
        part co2Sensors : CO2Sensor[4];
        part energyMeter : EnergyMeter;

        // Subsystems
        part hvacUnits : HVACUnit[4];
        part lightingFixtures : LightingFixture[8];
        part securityPanels : SecurityPanel;

        // Sensor -> Controller connections
        connect tempSensors.sensorOut to centralController.tempSensorIn;
        connect humiditySensors.sensorOut to centralController.humiditySensorIn;
        connect occupancySensors.sensorOut to centralController.occupancySensorIn;
        connect illuminanceSensors.sensorOut to centralController.illuminanceSensorIn;
        connect co2Sensors.sensorOut to centralController.co2SensorIn;
        connect energyMeter.meterOut to centralController.powerMeterIn;

        // Controller -> Actuator connections
        connect centralController.hvacCmdOut to hvacUnits.cmdIn;
        connect centralController.lightingCmdOut to lightingFixtures.cmdIn;
        connect centralController.securityCmdOut to securityPanels.cmdIn;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def OccupantComfortRequirement {
        doc /* The system shall maintain comfortable indoor environmental conditions for building occupants. */;
        attribute minTemperature : TemperatureValue = 18.0;
        attribute maxTemperature : TemperatureValue = 26.0;
        attribute minHumidity : HumidityValue = 30.0;
        attribute maxHumidity : HumidityValue = 60.0;
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall minimize building energy consumption while meeting comfort and safety requirements. */;
        attribute maxPowerThreshold : PowerValue = 500.0;
    }

    requirement def SecurityRequirement {
        doc /* The system shall arm the security system during unoccupied hours and disarm during occupied hours. */;
    }

    requirement def EmergencyResponseRequirement {
        doc /* The system shall enter an emergency mode in response to critical events, overriding normal operation. */;
    }

    requirement def HVACControlRequirement {
        doc /* The system shall control HVAC units to heat, cool, or ventilate based on sensor data and schedule. */;
    }

    requirement def LightingControlRequirement {
        doc /* The system shall adjust lighting fixture brightness based on ambient light and occupancy. */;
    }

    requirement def AirQualityRequirement {
        doc /* The system shall monitor CO2 levels and increase ventilation when CO2 exceeds threshold. */;
        attribute co2Threshold : CO2LevelValue = 1000.0;
    }

    requirement def OperatingScheduleRequirement {
        doc /* The system shall switch between occupied and unoccupied modes based on time of day and occupancy. */;
    }

    requirement def AutonomousOperationRequirement {
        doc /* The system shall operate autonomously without requiring human intervention. */;
    }

    requirement OccupantComfortReq : OccupantComfortRequirement {
        doc /* Comfort requirement instance for the building. */;
    }
    requirement EnergyEfficiencyReq : EnergyEfficiencyRequirement;
    requirement SecurityReq : SecurityRequirement;
    requirement EmergencyResponseReq : EmergencyResponseRequirement;
    requirement HVACControlReq : HVACControlRequirement;
    requirement LightingControlReq : LightingControlRequirement;
    requirement AirQualityReq : AirQualityRequirement;
    requirement OperatingScheduleReq : OperatingScheduleRequirement;
    requirement AutonomousOperationReq : AutonomousOperationRequirement;

    // ============================================================
    // Satisfaction Relationships
    // ============================================================
    satisfy OccupantComfortReq by centralController;
    satisfy EnergyEfficiencyReq by centralController;
    satisfy SecurityReq by securityPanels;
    satisfy EmergencyResponseReq by centralController;
    satisfy HVACControlReq by hvacUnits;
    satisfy LightingControlReq by lightingFixtures;
    satisfy AirQualityReq by co2Sensors;
    satisfy OperatingScheduleReq by centralController;
    satisfy AutonomousOperationReq by centralController;
}
