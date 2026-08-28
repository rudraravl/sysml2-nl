package SmartEnvironmentControlSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    package Units {
        attribute def CelsiusUnit :> Unit {
            :>> symbol = "°C";
        }
        attribute def PercentUnit :> Unit {
            :>> symbol = "%";
        }
        attribute def LuxUnit :> Unit {
            :>> symbol = "lx";
        }
        attribute def WattUnit :> Unit {
            :>> symbol = "W";
        }
        attribute def WattHourUnit :> Unit {
            :>> symbol = "Wh";
        }
        attribute def SecondsUnit :> Unit {
            :>> symbol = "s";
        }
    }

    package ValueTypes {
        import Units::*;

        attribute def Temperature :> Real {
            :>> unit = CelsiusUnit;
        }
        attribute def Humidity :> Real {
            :>> unit = PercentUnit;
        }
        attribute def Illuminance :> Real {
            :>> unit = LuxUnit;
        }
        attribute def Power :> Real {
            :>> unit = WattUnit;
        }
        attribute def Energy :> Real {
            :>> unit = WattHourUnit;
        }
        attribute def TimeSeconds :> Real {
            :>> unit = SecondsUnit;
        }
    }

    package Enums {
        enum def OperatingMode {
            literal Comfort;
            literal Eco;
            literal Away;
            literal Sleep;
            literal Manual;
        }
        enum def LightLevel {
            literal Off;
            literal Low;
            literal Medium;
            literal High;
            literal Full;
        }
        enum def OccupancyState {
            literal Occupied;
            literal Vacant;
        }
        enum def HvacCommandKind {
            literal Heat;
            literal Cool;
            literal Ventilate;
            literal Standby;
        }
    }

    package Items {
        import ValueTypes::*;
        import Enums::*;

        item def TemperatureReading {
            attribute value : Temperature;
            attribute timestamp : TimeSeconds;
        }
        item def HumidityReading {
            attribute value : Humidity;
            attribute timestamp : TimeSeconds;
        }
        item def IlluminanceReading {
            attribute value : Illuminance;
            attribute timestamp : TimeSeconds;
        }
        item def OccupancyReading {
            attribute state : OccupancyState;
            attribute timestamp : TimeSeconds;
        }
        item def HvacControlCommand {
            attribute command : HvacCommandKind;
            attribute targetTemperature : Temperature;
        }
        item def LightingControlCommand {
            attribute level : LightLevel;
        }
        item def ModeSelection {
            attribute mode : OperatingMode;
        }
        item def EnergyReport {
            attribute consumed : Energy;
            attribute budget : Energy;
            attribute interval : TimeSeconds;
        }
    }

    package Ports {
        import Items::*;

        port def TemperatureSensorPort {
            out reading : TemperatureReading;
        }
        port def HumiditySensorPort {
            out reading : HumidityReading;
        }
        port def LightSensorPort {
            out reading : IlluminanceReading;
        }
        port def MotionSensorPort {
            out reading : OccupancyReading;
        }
        port def HvacCommandPort {
            in command : HvacControlCommand;
        }
        port def LightingCommandPort {
            in command : LightingControlCommand;
        }
        port def ModeSelectionPort {
            in selection : ModeSelection;
        }
        port def EnergyReportPort {
            out report : EnergyReport;
        }
    }

    package Behaviors {
        import Items::*;
        import ValueTypes::*;
        import Enums::*;

        action def SampleTemperature {
            out reading : TemperatureReading;
        }
        action def SampleHumidity {
            out reading : HumidityReading;
        }
        action def SampleIlluminance {
            out reading : IlluminanceReading;
        }
        action def SampleOccupancy {
            out reading : OccupancyReading;
        }

        action def EvaluateComfortRules {
            in temp : Temperature;
            in humidity : Humidity;
            in light : Illuminance;
            in occupied : Boolean;
            out hvacCmd : HvacControlCommand;
            out lightCmd : LightingControlCommand;
        }
        action def EvaluateEcoRules {
            in temp : Temperature;
            in light : Illuminance;
            in occupied : Boolean;
            out hvacCmd : HvacControlCommand;
            out lightCmd : LightingControlCommand;
        }
        action def EvaluateAwayRules {
            in temp : Temperature;
            out hvacCmd : HvacControlCommand;
            out lightCmd : LightingControlCommand;
        }
        action def EvaluateSleepRules {
            in temp : Temperature;
            in occupied : Boolean;
            out hvacCmd : HvacControlCommand;
            out lightCmd : LightingControlCommand;
        }
        action def EvaluateManualRules {
            in temp : Temperature;
            in light : Illuminance;
            in occupied : Boolean;
            out hvacCmd : HvacControlCommand;
            out lightCmd : LightingControlCommand;
        }
        action def ComputeEnergyUsage {
            in hvacPower : Power;
            in lightingPower : Power;
            in interval : TimeSeconds;
            out report : EnergyReport;
        }
    }

    package StateMachines {
        import Enums::*;
        import Items::*;
        import ValueTypes::*;

        state def ControllerStateMachine {
            attribute currentMode : OperatingMode := Comfort;
            attribute occupied : Boolean := false;
            attribute lastMotion : TimeSeconds := 0;

            entry; 

            state ComfortMode {
                entry; 
                transition ComfortMode to EcoMode 
                    when (currentMode == Eco);
                transition ComfortMode to AwayMode 
                    when (currentMode == Away);
                transition ComfortMode to SleepMode 
                    when (currentMode == Sleep);
                transition ComfortMode to ManualMode 
                    when (currentMode == Manual);
            }
            state EcoMode {
                entry; 
                transition EcoMode to ComfortMode 
                    when (currentMode == Comfort);
                transition EcoMode to AwayMode 
                    when (currentMode == Away);
                transition EcoMode to SleepMode 
                    when (currentMode == Sleep);
                transition EcoMode to ManualMode 
                    when (currentMode == Manual);
            }
            state AwayMode {
                entry; 
                transition AwayMode to ComfortMode 
                    when (currentMode == Comfort);
                transition AwayMode to EcoMode 
                    when (currentMode == Eco);
                transition AwayMode to SleepMode 
                    when (currentMode == Sleep);
                transition AwayMode to ManualMode 
                    when (currentMode == Manual);
            }
            state SleepMode {
                entry; 
                transition SleepMode to ComfortMode 
                    when (currentMode == Comfort);
                transition SleepMode to EcoMode 
                    when (currentMode == Eco);
                transition SleepMode to AwayMode 
                    when (currentMode == Away);
                transition SleepMode to ManualMode 
                    when (currentMode == Manual);
            }
            state ManualMode {
                entry; 
                transition ManualMode to ComfortMode 
                    when (currentMode == Comfort);
                transition ManualMode to EcoMode 
                    when (currentMode == Eco);
                transition ManualMode to AwayMode 
                    when (currentMode == Away);
                transition ManualMode to SleepMode 
                    when (currentMode == Sleep);
            }

            transition initial to ComfortMode;
        }

        state def HvacStateMachine {
            attribute activeCommand : HvacCommandKind := Standby;
            attribute setpoint : Temperature := 22.0;

            entry; 

            state Heating {
                entry; 
                transition Heating to Cooling 
                    when (activeCommand == Cool);
                transition Heating to Ventilating 
                    when (activeCommand == Ventilate);
                transition Heating to Standby 
                    when (activeCommand == Standby);
            }
            state Cooling {
                entry; 
                transition Cooling to Heating 
                    when (activeCommand == Heat);
                transition Cooling to Ventilating 
                    when (activeCommand == Ventilate);
                transition Cooling to Standby 
                    when (activeCommand == Standby);
            }
            state Ventilating {
                entry; 
                transition Ventilating to Heating 
                    when (activeCommand == Heat);
                transition Ventilating to Cooling 
                    when (activeCommand == Cool);
                transition Ventilating to Standby 
                    when (activeCommand == Standby);
            }
            state Standby {
                entry; 
                transition Standby to Heating 
                    when (activeCommand == Heat);
                transition Standby to Cooling 
                    when (activeCommand == Cool);
                transition Standby to Ventilating 
                    when (activeCommand == Ventilate);
            }

            transition initial to Standby;
        }

        state def LightingStateMachine {
            attribute activeLevel : LightLevel := Off;

            entry; 

            state Off {
                entry; 
                transition Off to Low 
                    when (activeLevel == Low);
                transition Off to Medium 
                    when (activeLevel == Medium);
                transition Off to High 
                    when (activeLevel == High);
                transition Off to Full 
                    when (activeLevel == Full);
            }
            state Low {
                entry; 
                transition Low to Off 
                    when (activeLevel == Off);
                transition Low to Medium 
                    when (activeLevel == Medium);
                transition Low to High 
                    when (activeLevel == High);
                transition Low to Full 
                    when (activeLevel == Full);
            }
            state Medium {
                entry; 
                transition Medium to Off 
                    when (activeLevel == Off);
                transition Medium to Low 
                    when (activeLevel == Low);
                transition Medium to High 
                    when (activeLevel == High);
                transition Medium to Full 
                    when (activeLevel == Full);
            }
            state High {
                entry; 
                transition High to Off 
                    when (activeLevel == Off);
                transition High to Low 
                    when (activeLevel == Low);
                transition High to Medium 
                    when (activeLevel == Medium);
                transition High to Full 
                    when (activeLevel == Full);
            }
            state Full {
                entry; 
                transition Full to Off 
                    when (activeLevel == Off);
                transition Full to Low 
                    when (activeLevel == Low);
                transition Full to Medium 
                    when (activeLevel == Medium);
                transition Full to High 
                    when (activeLevel == High);
            }

            transition initial to Off;
        }
    }

    package Parts {
        import Ports::*;
        import Items::*;
        import ValueTypes::*;
        import Enums::*;
        import Behaviors::*;
        import StateMachines::*;

        part def TemperatureSensor {
            port sensorOut : TemperatureSensorPort;
            attribute currentValue : Temperature := 21.0;
            attribute samplingInterval : TimeSeconds := 5.0;
            exhibit state def SensorBehavior {
                entry; 
                state Sampling {
                    do SampleTemperature;
                    transition Sampling to Sampling 
                        when (true);
                }
                transition initial to Sampling;
            }
        }

        part def HumiditySensor {
            port sensorOut : HumiditySensorPort;
            attribute currentValue : Humidity := 50.0;
            attribute samplingInterval : TimeSeconds := 10.0;
            exhibit state def SensorBehavior {
                entry; 
                state Sampling {
                    do SampleHumidity;
                    transition Sampling to Sampling 
                        when (true);
                }
                transition initial to Sampling;
            }
        }

        part def LightSensor {
            port sensorOut : LightSensorPort;
            attribute currentValue : Illuminance := 300.0;
            attribute samplingInterval : TimeSeconds := 5.0;
            exhibit state def SensorBehavior {
                entry; 
                state Sampling {
                    do SampleIlluminance;
                    transition Sampling to Sampling 
                        when (true);
                }
                transition initial to Sampling;
            }
        }

        part def MotionSensor {
            port sensorOut : MotionSensorPort;
            attribute currentState : OccupancyState := Vacant;
            attribute samplingInterval : TimeSeconds := 2.0;
            exhibit state def SensorBehavior {
                entry; 
                state Sampling {
                    do SampleOccupancy;
                    transition Sampling to Sampling 
                        when (true);
                }
                transition initial to Sampling;
            }
        }

        part def HvacUnit {
            port commandIn : HvacCommandPort;
            attribute currentCommand : HvacCommandKind := Standby;
            attribute setpoint : Temperature := 22.0;
            attribute powerDraw : Power := 0.0;
            attribute maxHeatingPower : Power := 1500.0;
            attribute maxCoolingPower : Power := 1200.0;
            attribute ventilationPower : Power := 50.0;
            exhibit HvacStateMachine;
        }

        part def LightingUnit {
            port commandIn : LightingCommandPort;
            attribute currentLevel : LightLevel := Off;
            attribute powerDraw : Power := 0.0;
            attribute offPower : Power := 0.0;
            attribute lowPower : Power := 8.0;
            attribute mediumPower : Power := 20.0;
            attribute highPower : Power := 40.0;
            attribute fullPower : Power := 80.0;
            exhibit LightingStateMachine;
        }

        part def CentralController {
            port tempIn : TemperatureSensorPort;
            port humidityIn : HumiditySensorPort;
            port lightIn : LightSensorPort;
            port motionIn : MotionSensorPort;
            port hvacOut : HvacCommandPort;
            port lightingOut : LightingCommandPort;
            port modeIn : ModeSelectionPort;
            port energyOut : EnergyReportPort;

            attribute currentMode : OperatingMode := Comfort;
            attribute comfortSetpoint : Temperature := 22.0;
            attribute ecoSetpointMin : Temperature := 19.0;
            attribute ecoSetpointMax : Temperature := 26.0;
            attribute awaySetpoint : Temperature := 16.0;
            attribute sleepSetpoint : Temperature := 20.0;
            attribute manualSetpoint : Temperature := 22.0;
            attribute occupied : Boolean := false;
            attribute lastMotionTime : TimeSeconds := 0.0;
            attribute awayTimeout : TimeSeconds := 1800.0;
            attribute naturalLightThreshold : Illuminance := 500.0;
            attribute energyBudget : Energy := 5000.0;
            attribute energyConsumed : Energy := 0.0;
            attribute reportingInterval : TimeSeconds := 60.0;

            exhibit ControllerStateMachine;

            private action decideHvacCommand {
                in mode : OperatingMode;
                in temp : Temperature;
                in occ : Boolean;
                out cmd : HvacControlCommand;
            }
            private action decideLightingCommand {
                in mode : OperatingMode;
                in light : Illuminance;
                in occ : Boolean;
                out cmd : LightingControlCommand;
            }
        }

        part def UserInterface {
            port modeOut : ModeSelectionPort;
            attribute selectedMode : OperatingMode := Comfort;
            attribute availableModes : OperatingMode[5] = (Comfort, Eco, Away, Sleep, Manual);
        }

        part def EnergyMonitor {
            port reportOut : EnergyReportPort;
            attribute totalConsumed : Energy := 0.0;
            attribute budget : Energy := 5000.0;
            attribute interval : TimeSeconds := 60.0;
            exhibit state def MonitorBehavior {
                entry; 
                state Monitoring {
                    do ComputeEnergyUsage;
                    transition Monitoring to Monitoring 
                        when (true);
                }
                transition initial to Monitoring;
            }
        }

        part def SmartEnvironmentController {
            part temperatureSensor : TemperatureSensor;
            part humiditySensor : HumiditySensor;
            part lightSensor : LightSensor;
            part motionSensor : MotionSensor;
            part hvac : HvacUnit;
            part lighting : LightingUnit;
            part controller : CentralController;
            part userInterface : UserInterface;
            part energyMonitor : EnergyMonitor;

            connection tempSensorToController 
                connect temperatureSensor.sensorOut to controller.tempIn;
            connection humiditySensorToController 
                connect humiditySensor.sensorOut to controller.humidityIn;
            connection lightSensorToController 
                connect lightSensor.sensorOut to controller.lightIn;
            connection motionSensorToController 
                connect motionSensor.sensorOut to controller.motionIn;
            connection controllerToHvac 
                connect controller.hvacOut to hvac.commandIn;
            connection controllerToLighting 
                connect controller.lightingOut to lighting.commandIn;
            connection uiToController 
                connect userInterface.modeOut to controller.modeIn;
            connection controllerToEnergyMonitor 
                connect controller.energyOut to energyMonitor.reportOut;
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Enums::*;

        requirement def ClimateControlRequirement {
            attribute id : String = "REQ-001";
            doc /* The system shall autonomously maintain occupant comfort while minimizing energy consumption. */
            subject system : SmartEnvironmentController;
            objective {
                doc "Maintain indoor temperature within the configured comfort band for the selected mode.";
            }
        }

        requirement def ComfortModeRequirement {
            attribute id : String = "REQ-002";
            doc /* In Comfort mode, the system shall maintain temperature around 22°C. */
            attribute targetTemperature : Temperature := 22.0;
            attribute tolerance : Temperature := 1.0;
        }

        requirement def EcoModeRequirement {
            attribute id : String = "REQ-003";
            doc /* In Eco mode, the system shall allow a wider temperature range to save energy. */
            attribute minTemperature : Temperature := 19.0;
            attribute maxTemperature : Temperature := 26.0;
        }

        requirement def AwayModeRequirement {
            attribute id : String = "REQ-004";
            doc /* In Away mode, the system shall set to a minimal energy state. */
            attribute awayTemperature : Temperature := 16.0;
            attribute awayLightLevel : LightLevel = Off;
        }

        requirement def SleepModeRequirement {
            attribute id : String = "REQ-005";
            doc /* In Sleep mode, the system shall maintain a comfortable sleeping temperature. */
            attribute sleepTemperature : Temperature := 20.0;
            attribute sleepLightLevel : LightLevel = Low;
        }

        requirement def ManualModeRequirement {
            attribute id : String = "REQ-006";
            doc /* In Manual mode, the system shall allow direct user control of setpoints and lighting. */
        }

        requirement def MotionAdaptationRequirement {
            attribute id : String = "REQ-007";
            doc /* The system shall use motion sensor data to detect occupancy and adjust the environment accordingly. */
            attribute vacancyTimeout : TimeSeconds := 1800.0;
        }

        requirement def NaturalLightAdaptationRequirement {
            attribute id : String = "REQ-008";
            doc /* The system shall consider natural light before activating artificial lighting. */
            attribute naturalLightThreshold : Illuminance := 500.0;
        }

        requirement def EnergyBudgetRequirement {
            attribute id : String = "REQ-009";
            doc /* The system shall operate within a defined energy budget. */
            attribute budget : Energy := 5000.0;
        }

        requirement def LightingLevelsRequirement {
            attribute id : String = "REQ-010";
            doc /* The lighting system shall support off, low, medium, high, and full brightness levels. */
            attribute supportedLevels : LightLevel[5] = (Off, Low, Medium, High, Full);
        }

        requirement def SensorSuiteRequirement {
            attribute id : String = "REQ-011";
            doc /* The system shall include temperature, humidity, light, and motion sensors. */
        }

        requirement def HvacControlRequirement {
            attribute id : String = "REQ-012";
            doc /* The HVAC unit shall regulate temperature based on controller commands. */
        }

        requirement package SystemRequirements {
            satisfy ClimateControlRequirement;
            satisfy ComfortModeRequirement;
            satisfy EcoModeRequirement;
            satisfy AwayModeRequirement;
            satisfy SleepModeRequirement;
            satisfy ManualModeRequirement;
            satisfy MotionAdaptationRequirement;
            satisfy NaturalLightAdaptationRequirement;
            satisfy EnergyBudgetRequirement;
            satisfy LightingLevelsRequirement;
            satisfy SensorSuiteRequirement;
            satisfy HvacControlRequirement;
        }
    }

    package Configurations {
        import Parts::*;
        import ValueTypes::*;

        part def DefaultConfiguration :> SmartEnvironmentController {
            :>> controller.comfortSetpoint = 22.0;
            :>> controller.ecoSetpointMin = 19.0;
            :>> controller.ecoSetpointMax = 26.0;
            :>> controller.awaySetpoint = 16.0;
            :>> controller.sleepSetpoint = 20.0;
            :>> controller.awayTimeout = 1800.0;
            :>> controller.naturalLightThreshold = 500.0;
            :>> controller.energyBudget = 5000.0;
            :>> hvac.maxHeatingPower = 1500.0;
            :>> hvac.maxCoolingPower = 1200.0;
            :>> lighting.fullPower = 80.0;
        }
    }
}
