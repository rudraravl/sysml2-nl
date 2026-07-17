package SmartEnvironmentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityValue :> Real;
    attribute def IlluminanceValue :> ISQ::IlluminanceValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def EnergyValue :> ISQ::EnergyValue;
    attribute def DurationValue :> ISQ::DurationValue;

    enum def OccupancyState {
        vacant;
        occupied;
        transitioning;
    }

    enum def SystemMode {
        comfort;
        eco;
        away;
        sleep;
        manual;
    }

    enum def LightingLevel {
        off = 0;
        low = 25;
        medium = 50;
        high = 75;
        full = 100;
    }

    item def EnvironmentalReading {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute illuminance : IlluminanceValue;
        attribute timestamp : DurationValue;
    }

    item def ControlSignal {
        attribute targetTemperature : TemperatureValue;
        attribute targetLighting : LightingLevel;
        attribute hvacPower : PowerValue;
        attribute mode : SystemMode;
    }

    port def SensorDataPort {
        out reading : EnvironmentalReading;
    }

    port def ActuatorCommandPort {
        in command : ControlSignal;
    }

    port def DataBusPort {
        in dataIn : EnvironmentalReading;
        out dataOut : EnvironmentalReading;
    }

    port def ControlBusPort {
        in cmdIn : ControlSignal;
        out cmdOut : ControlSignal;
    }

    part def TemperatureSensor {
        attribute sensorId : String;
        attribute currentReading : TemperatureValue;
        attribute accuracy : TemperatureValue = 0.3 [K];
        port dataOut : SensorDataPort;
        
        action def MeasureTemperature {
            out measurement : TemperatureValue;
        }
        
        perform action measure : MeasureTemperature[*];
    }

    part def HumiditySensor {
        attribute sensorId : String;
        attribute currentReading : HumidityValue;
        attribute accuracy : Real = 0.02;
        port dataOut : SensorDataPort;
        
        action def MeasureHumidity {
            out measurement : HumidityValue;
        }
        
        perform action measure : MeasureHumidity[*];
    }

    part def LightSensor {
        attribute sensorId : String;
        attribute currentReading : IlluminanceValue;
        attribute range : IlluminanceValue = 10000 [lx];
        port dataOut : SensorDataPort;
        
        action def MeasureIlluminance {
            out measurement : IlluminanceValue;
        }
        
        perform action measure : MeasureIlluminance[*];
    }

    part def MotionSensor {
        attribute sensorId : String;
        attribute detectionRange : LengthValue = 8.0 [m];
        attribute occupancyDetected : OccupancyState;
        port dataOut : SensorDataPort;
        
        action def DetectMotion {
            out status : OccupancyState;
        }
        
        perform action detect : DetectMotion[*];
    }

    part def HVACActuator {
        attribute actuatorId : String;
        attribute maxPower : PowerValue = 5000 [W];
        attribute currentPower : PowerValue;
        attribute operatingTemperature : TemperatureValue;
        port cmdIn : ActuatorCommandPort;
        
        action def RegulateClimate {
            in targetTemp : TemperatureValue;
            in powerLevel : PowerValue;
            out actualTemp : TemperatureValue;
        }
        
        perform action regulate : RegulateClimate[*];
    }

    part def LightingActuator {
        attribute actuatorId : String;
        attribute maxPower : PowerValue = 200 [W];
        attribute currentLevel : LightingLevel;
        attribute currentPower : PowerValue;
        port cmdIn : ActuatorCommandPort;
        
        action def AdjustLighting {
            in targetLevel : LightingLevel;
            out actualLevel : LightingLevel;
            out powerUsed : PowerValue;
        }
        
        perform action adjust : AdjustLighting[*];
    }

    part def EnvironmentController {
        attribute controllerId : String;
        attribute activeMode : SystemMode;
        attribute comfortTemp : TemperatureValue = 295.15 [K];
        attribute ecoTemp : TemperatureValue = 292.15 [K];
        attribute awayTemp : TemperatureValue = 289.15 [K];
        attribute sleepTemp : TemperatureValue = 291.15 [K];
        attribute energyBudget : EnergyValue = 50000 [kJ];
        attribute totalEnergyUsed : EnergyValue;
        
        port sensorBus : DataBusPort[*];
        port actuatorBus : ControlBusPort[*];
        
        action def AggregateReadings {
            in readings : EnvironmentalReading[*];
            out aggregated : EnvironmentalReading;
        }
        
        action def DetermineOptimalControl {
            in currentState : EnvironmentalReading;
            in mode : SystemMode;
            in occupancy : OccupancyState;
            out controlCmd : ControlSignal;
        }
        
        action def DispatchCommands {
            in commands : ControlSignal;
            out hvacCmd : ControlSignal;
            out lightCmd : ControlSignal;
        }
        
        action def ManageEnvironment {
            first start;
            then merge controlLoop;
            
            then action aggregate : AggregateReadings {
                in readings : EnvironmentalReading[*];
                out envState : EnvironmentalReading;
            }
            
            then action determine : DetermineOptimalControl {
                in currentState = aggregate.envState;
                in mode = activeMode;
                in occupancy : OccupancyState;
                out optimalCmd : ControlSignal;
            }
            
            then decide;
                if determine.optimalCmd.mode == SystemMode::comfort then comfortMode;
                if determine.optimalCmd.mode == SystemMode::eco then ecoMode;
                if determine.optimalCmd.mode == SystemMode::away then awayMode;
                if determine.optimalCmd.mode == SystemMode::sleep then sleepMode;
                if determine.optimalCmd.mode == SystemMode::manual then manualMode;
            
            action comfortMode : DispatchCommands {
                in commands = determine.optimalCmd;
            }
            then controlLoop;
            
            action ecoMode : DispatchCommands {
                in commands = determine.optimalCmd;
            }
            then controlLoop;
            
            action awayMode : DispatchCommands {
                in commands = determine.optimalCmd;
            }
            then controlLoop;
            
            action sleepMode : DispatchCommands {
                in commands = determine.optimalCmd;
            }
            then controlLoop;
            
            action manualMode : DispatchCommands {
                in commands = determine.optimalCmd;
            }
            then controlLoop;
        }
        
        perform action manage : ManageEnvironment[*];
    }

    part def SmartEnvironment {
        attribute systemId : String;
        attribute totalPowerConsumption : PowerValue;
        attribute cumulativeEnergy : EnergyValue;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute currentIlluminance : IlluminanceValue;
        attribute currentOccupancy : OccupancyState;
        
        part tempSensor : TemperatureSensor {
            attribute :>> sensorId = "TEMP-01";
            attribute :>> currentReading : TemperatureValue;
        }
        
        part humiditySensor : HumiditySensor {
            attribute :>> sensorId = "HUM-01";
            attribute :>> currentReading : HumidityValue;
        }
        
        part lightSensor : LightSensor {
            attribute :>> sensorId = "LIGHT-01";
            attribute :>> currentReading : IlluminanceValue;
        }
        
        part motionSensor : MotionSensor {
            attribute :>> sensorId = "MOTION-01";
            attribute :>> occupancyDetected : OccupancyState;
        }
        
        part hvacUnit : HVACActuator {
            attribute :>> actuatorId = "HVAC-01";
            attribute :>> currentPower : PowerValue;
            attribute :>> operatingTemperature : TemperatureValue;
        }
        
        part lightingUnit : LightingActuator {
            attribute :>> actuatorId = "LIGHT-ACT-01";
            attribute :>> currentLevel : LightingLevel;
            attribute :>> currentPower : PowerValue;
        }
        
        part controller : EnvironmentController {
            attribute :>> controllerId = "CTRL-01";
            attribute :>> activeMode : SystemMode;
            attribute :>> totalEnergyUsed : EnergyValue;
        }
        
        connection tempSensorLink connect tempSensor.dataOut to controller.sensorBus;
        connection humiditySensorLink connect humiditySensor.dataOut to controller.sensorBus;
        connection lightSensorLink connect lightSensor.dataOut to controller.sensorBus;
        connection motionSensorLink connect motionSensor.dataOut to controller.sensorBus;
        
        connection hvacControlLink connect controller.actuatorBus to hvacUnit.cmdIn;
        connection lightControlLink connect controller.actuatorBus to lightingUnit.cmdIn;
        
        assert constraint energyConstraint {
            cumulativeEnergy <= controller.energyBudget
        }
        
        assert constraint temperatureRange {
            (currentTemperature >= 289.15 [K]) and (currentTemperature <= 299.15 [K])
        }
        
        assert constraint humidityRange {
            (currentHumidity >= 0.3) and (currentHumidity <= 0.7)
        }
    }

    package Requirements {
        requirement <'REQ-SE-001'> primaryFunction {
            doc /* The Smart Environment system shall autonomously monitor and control 
                 * indoor environmental conditions including temperature, humidity, and 
                 * lighting to optimize occupant comfort and minimize energy consumption 
                 * through intelligent adaptation based on occupancy detection and 
                 * user-selected operating modes.
                 */
            subject smartEnv : SmartEnvironment;
        }
        
        requirement <'REQ-SE-002'> temperatureRegulation {
            doc /* The system shall maintain indoor temperature within specified ranges 
                 * for each operating mode: comfort (22±3°C), eco (19±2°C), away (16±2°C), 
                 * and sleep (18±2°C).
                 */
            subject hvac :>> SmartEnvironment::hvacUnit;
            
            assert constraint {
                (hvac.operatingTemperature >= 289.15 [K]) and 
                (hvac.operatingTemperature <= 299.15 [K])
            }
        }
        
        requirement <'REQ-SE-003'> energyEfficiency {
            doc /* The system shall limit cumulative energy consumption to the defined 
                 * budget while maintaining environmental comfort standards.
                 */
            subject smartEnv :>> SmartEnvironment::cumulativeEnergy;
            
            assert constraint {
                smartEnv <= 50000 [kJ]
            }
        }
        
        requirement <'REQ-SE-004'> occupancyAdaptation {
            doc /* The system shall detect occupancy changes and adjust environmental 
                 * controls within 60 seconds to optimize comfort and energy usage.
                 */
            subject controller :>> SmartEnvironment::controller;
        }
        
        requirement <'REQ-SE-005'> multiModeOperation {
            doc /* The system shall support five distinct operating modes (comfort, eco, 
                 * away, sleep, manual) with unique control strategies optimized for 
                 * different usage scenarios.
                 */
            subject controller :>> SmartEnvironment::controller;
        }
        
        requirement <'REQ-SE-006'> lightingControl {
            doc /* The system shall automatically adjust lighting levels based on 
                 * ambient light conditions and occupancy to maintain adequate 
                 * illumination while minimizing energy waste.
                 */
            subject lighting :>> SmartEnvironment::lightingUnit;
            
            assert constraint {
                lighting.currentPower <= 200 [W]
            }
        }
    }

    package SystemArchitecture {
        part smartEnvironmentInstance : SmartEnvironment {
            attribute :>> systemId = "SE-MAIN-001";
            attribute :>> totalPowerConsumption : PowerValue;
            attribute :>> cumulativeEnergy : EnergyValue;
            attribute :>> currentTemperature = 295.15 [K];
            attribute :>> currentHumidity = 0.45;
            attribute :>> currentIlluminance = 500 [lx];
            attribute :>> currentOccupancy = OccupancyState::vacant;
        }
        
        satisfy Requirements::primaryFunction by smartEnvironmentInstance;
        satisfy Requirements::temperatureRegulation by smartEnvironmentInstance.hvacUnit;
        satisfy Requirements::energyEfficiency by smartEnvironmentInstance.cumulativeEnergy;
        satisfy Requirements::occupancyAdaptation by smartEnvironmentInstance.controller;
        satisfy Requirements::multiModeOperation by smartEnvironmentInstance.controller;
        satisfy Requirements::lightingControl by smartEnvironmentInstance.lightingUnit;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import SmartEnvironmentSystem::*;

    part testSubject : EnvironmentController {
    // TODO(human): unsupported input type for commands: ControlSignal (unsupported structured payload members: targetLighting)
    }
}
