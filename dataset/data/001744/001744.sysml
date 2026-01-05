package AquariumSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def WaterQuality {
        attribute temperature : TemperatureValue;
        attribute pH : Real;
        attribute ammonia : Real;
        attribute nitrite : Real;
        attribute nitrate : Real;
        attribute dissolvedOxygen : Real;
    }

    attribute def WaterLevel {
        attribute current : LengthValue;
        attribute maximum : LengthValue;
        attribute minimum : LengthValue;
    }

    enum def SystemMode {
        normal;
        maintenance;
        emergency;
    }

    attribute def MaintenanceRequest;
    attribute def EmergencyAlert;
    attribute def ShutdownCommand;

    item def Water {
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
        attribute quality : WaterQuality;
    }

    item def Fish {
        attribute species : String;
        attribute count : Integer;
    }

    item def Food {
        attribute mass : MassValue;
    }

    port def WaterFlowPort {
        attribute flowRate : VolumeFlowRateValue;
    }

    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    port def SensorPort {
        out reading : Real;
    }

    port def ControlPort {
        in command : Boolean;
    }

    part def Tank {
        attribute capacity : VolumeValue;
        port waterIn : WaterFlowPort;
        port waterOut : WaterFlowPort;
    }

    part def Pump {
        attribute maxFlowRate : VolumeFlowRateValue;
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        port power : PowerPort;
        port control : ControlPort;
    }

    part def Filter {
        attribute filterType : String;
        attribute efficiency : Real;
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
    }

    part def Heater {
        attribute targetTemperature : TemperatureValue;
        attribute heatingPower : PowerValue;
        port power : PowerPort;
        port control : ControlPort;
    }

    part def LightingSystem {
        attribute intensity : Real;
        attribute spectrum : String;
        port power : PowerPort;
        port control : ControlPort;
    }

    part def Aerator {
        attribute oxygenationRate : Real;
        port power : PowerPort;
        port control : ControlPort;
    }

    part def TemperatureSensor {
        port reading : SensorPort;
    }

    part def PHSensor {
        port reading : SensorPort;
    }

    part def WaterLevelSensor {
        port reading : SensorPort;
    }

    part def AutoFeeder {
        attribute capacity : MassValue;
        attribute feedAmount : MassValue;
        port power : PowerPort;
        port control : ControlPort;
    }

    part def ControlUnit {
        attribute mode : SystemMode;
        port power : PowerPort;
        port tempSensorIn : SensorPort;
        port phSensorIn : SensorPort;
        port levelSensorIn : SensorPort;
        port pumpControl : ControlPort;
        port heaterControl : ControlPort;
        port lightControl : ControlPort;
        port aeratorControl : ControlPort;
        port feederControl : ControlPort;
    }

    action def MonitorWaterQuality {
        in currentTemp : TemperatureValue;
        in currentPH : Real;
        in currentLevel : LengthValue;
        out qualityStatus : String;
        out adjustmentNeeded : Boolean;
    }

    action def RegulateTemperature {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        in tolerance : TemperatureValue;
        out heaterOn : Boolean;
    }

    action def ControlLighting {
        in currentTime : TimeValue;
        in lightOnTime : TimeValue;
        in lightOffTime : TimeValue;
        out lightOn : Boolean;
    }

    action def FeedFish {
        in feedingTime : TimeValue;
        in currentTime : TimeValue;
        out dispenseFood : Boolean;
    }

    action def MaintainOxygenLevel {
        in currentOxygen : Real;
        in targetOxygen : Real;
        out aeratorOn : Boolean;
    }

    state def AquariumOperatingStates {
        entry; then startup;

        state startup {
            entry assign systemMode := SystemMode::normal;
        }
        then normalOperation;

        state normalOperation {
            state monitoring;
            state regulating;
            state feeding;
        }

        accept maintReq : MaintenanceRequest then maintenance;

        state maintenance {
            entry assign systemMode := SystemMode::maintenance;
        }
        then normalOperation;

        accept emergAlert : EmergencyAlert then emergency;

        state emergency {
            entry assign systemMode := SystemMode::emergency;
        }
        then normalOperation;

        accept shutCmd : ShutdownCommand then shutdown;

        state shutdown;
        then done;

        attribute systemMode : SystemMode;
    }

    action def MaintainAquariumEnvironment {
        in targetQuality : WaterQuality;
        in targetLevel : WaterLevel;
        in lightOnTime : TimeValue;
        in lightOffTime : TimeValue;
        in feedingTime : TimeValue;

        first start;
        then merge continuousOperation;

        then action monitor : MonitorWaterQuality {
            in currentTemp : TemperatureValue;
            in currentPH : Real;
            in currentLevel : LengthValue;
            out qualityStatus : String;
            out adjustmentNeeded : Boolean;
        }

        then decide;
            if monitor.adjustmentNeeded then adjustEnvironment;
            if !monitor.adjustmentNeeded then continuousOperation;

        action adjustEnvironment {
            action regulateTemp : RegulateTemperature {
                in currentTemp : TemperatureValue;
                in targetTemp : TemperatureValue;
                in tolerance : TemperatureValue;
                out heaterOn : Boolean;
            }
            then action maintainOxygen : MaintainOxygenLevel {
                in currentOxygen : Real;
                in targetOxygen : Real;
                out aeratorOn : Boolean;
            }
        }
        then continuousOperation;

        action controlLight : ControlLighting {
            in currentTime : TimeValue;
            in lightOnTime = lightOnTime;
            in lightOffTime = lightOffTime;
            out lightOn : Boolean;
        }

        action feedAction : FeedFish {
            in feedingTime = feedingTime;
            in currentTime : TimeValue;
            out dispenseFood : Boolean;
        }

        then continuousOperation;
    }

    requirement def AquariumSystemRequirements {
        doc /* The aquarium system shall maintain a stable aquatic environment for fish and aquatic life. */

        requirement <'1'> waterQualityRequirement {
            doc /* The system shall maintain water quality parameters within acceptable ranges for aquatic life. */

            require constraint {
                18.0 <= waterQuality.temperature.num <= 28.0 and
                6.5 <= waterQuality.pH <= 7.5 and
                waterQuality.ammonia <= 0.25 and
                waterQuality.nitrite <= 0.5 and
                waterQuality.nitrate <= 40.0 and
                waterQuality.dissolvedOxygen >= 5.0
            }

            attribute waterQuality : WaterQuality;
        }

        requirement <'2'> temperatureControlRequirement {
            doc /* The system shall maintain water temperature within +/- 1 degree Celsius of target. */

            require constraint {
                (actualTemperature.num - targetTemperature.num) <= 1.0 and
                (actualTemperature.num - targetTemperature.num) >= -1.0
            }

            attribute actualTemperature : TemperatureValue;
            attribute targetTemperature : TemperatureValue;
        }

        requirement <'3'> waterLevelRequirement {
            doc /* The system shall maintain water level between minimum and maximum thresholds. */

            require constraint {
                waterLevel.current >= waterLevel.minimum and
                waterLevel.current <= waterLevel.maximum
            }

            attribute waterLevel : WaterLevel;
        }

        requirement <'4'> lightingRequirement {
            doc /* The system shall provide appropriate lighting cycles for aquatic life. */

            require constraint {
                lightingDuration >= 8.0[SI::h] and
                lightingDuration <= 12.0[SI::h]
            }

            attribute lightingDuration : TimeValue;
        }

        requirement <'5'> feedingRequirement {
            doc /* The system shall provide regular feeding at scheduled intervals. */

            require constraint {
                feedingInterval >= 8.0[SI::h] and
                feedingInterval <= 24.0[SI::h]
            }

            attribute feedingInterval : TimeValue;
        }
    }

    part def Aquarium {
        attribute capacity : VolumeValue;
        attribute targetWaterQuality : WaterQuality;
        attribute currentWaterLevel : WaterLevel;

        part tank : Tank;
        part lifeSupportSystem {
            part pump : Pump;
            part bioFilter : Filter;
            part mechanicalFilter : Filter;
            part heater : Heater;
            part aerator : Aerator;
        }
        part lightingSubsystem : LightingSystem;
        part feedingSubsystem : AutoFeeder;
        part monitoringSystem {
            part tempSensor : TemperatureSensor;
            part phSensor : PHSensor;
            part levelSensor : WaterLevelSensor;
        }
        part controller : ControlUnit;
    }

    part aquarium : Aquarium {
        doc /* 
            The aquarium system maintains a controlled aquatic environment for fish and other aquatic organisms.
            Its primary function is to continuously monitor and regulate water quality, temperature, lighting, 
            and feeding to ensure optimal living conditions for aquatic life through automated control systems 
            and life support equipment.
        */

        attribute capacity = 200.0[SI::L];
        attribute targetWaterQuality {
            attribute temperature = 24.0[SI::'°C'];
            attribute pH = 7.0;
            attribute ammonia = 0.0;
            attribute nitrite = 0.0;
            attribute nitrate = 20.0;
            attribute dissolvedOxygen = 7.0;
        }
        attribute currentWaterLevel {
            attribute current = 180.0[SI::cm];
            attribute maximum = 200.0[SI::cm];
            attribute minimum = 150.0[SI::cm];
        }

        part tank : Tank {
            attribute capacity = 200.0[SI::L];
        }

        part lifeSupportSystem {
            part pump : Pump {
                attribute maxFlowRate = 500.0[SI::L/SI::h];
            }

            part bioFilter : Filter {
                attribute filterType = "Biological";
                attribute efficiency = 0.95;
            }

            part mechanicalFilter : Filter {
                attribute filterType = "Mechanical";
                attribute efficiency = 0.90;
            }

            part heater : Heater {
                attribute targetTemperature = 24.0[SI::'°C'];
                attribute heatingPower = 100.0[SI::W];
            }

            part aerator : Aerator {
                attribute oxygenationRate = 0.8;
            }

            connection waterCirculation connect pump.outlet to bioFilter.inlet;
            connection connect bioFilter.outlet to mechanicalFilter.inlet;
            connection connect mechanicalFilter.outlet to tank.waterIn;
            connection connect tank.waterOut to pump.inlet;
        }

        part lightingSubsystem : LightingSystem {
            attribute intensity = 0.75;
            attribute spectrum = "Full Spectrum";
        }

        part feedingSubsystem : AutoFeeder {
            attribute capacity = 500.0[SI::g];
            attribute feedAmount = 5.0[SI::g];
        }

        part monitoringSystem {
            part tempSensor : TemperatureSensor;
            part phSensor : PHSensor;
            part levelSensor : WaterLevelSensor;
        }

        part controller : ControlUnit {
            attribute mode = SystemMode::normal;

            perform action maintainEnvironment : MaintainAquariumEnvironment {
                in targetQuality = aquarium.targetWaterQuality;
                in targetLevel = aquarium.currentWaterLevel;
                in lightOnTime = 8.0[SI::h];
                in lightOffTime = 20.0[SI::h];
                in feedingTime = 12.0[SI::h];
            }
        }

        connection sensorFeedback1 connect monitoringSystem.tempSensor.reading to controller.tempSensorIn;
        connection sensorFeedback2 connect monitoringSystem.phSensor.reading to controller.phSensorIn;
        connection sensorFeedback3 connect monitoringSystem.levelSensor.reading to controller.levelSensorIn;

        connection controlSignal1 connect controller.pumpControl to lifeSupportSystem.pump.control;
        connection controlSignal2 connect controller.heaterControl to lifeSupportSystem.heater.control;
        connection controlSignal3 connect controller.lightControl to lightingSubsystem.control;
        connection controlSignal4 connect controller.aeratorControl to lifeSupportSystem.aerator.control;
        connection controlSignal5 connect controller.feederControl to feedingSubsystem.control;

        satisfy sysReqs : AquariumSystemRequirements;
    }
}
