package EAT_System {
    public import ISQ::*;
    public import ScalarValues::*;

    // ---- Value Types ----
    value type TemperatureValue :> Real {
        in unit : TemperatureUnit[1] default Celsius::degC;
    }
    value type HumidityValue :> Real {
        in unit : HumidityUnit[1] default Percent::percent;
    }
    value type PowerValue :> Real {
        in unit : PowerUnit[1] default SI::W;
    }
    value type DurationValue :> Real {
        in unit : TimeUnit[1] default SI::h;
    }
    value type FrequencyValue :> Real {
        in unit : FrequencyUnit[1] default SI::Hz;
    }
    value type MassValue :> Real {
        in unit : MassUnit[1] default SI::kg;
    }

    attribute def TemperatureUnit :> Units::TemperatureUnit;
    attribute def HumidityUnit;
    attribute def PowerUnit :> Units::PowerUnit;
    attribute def TimeUnit :> Units::TimeUnit;
    attribute def FrequencyUnit :> Units::FrequencyUnit;
    attribute def MassUnit :> Units::MassUnit;

    // ---- Item Definitions ----
    item def TestSpecimen {
        attribute mass : MassValue;
        attribute identifier : String;
    }
    item def TestPlan {
        attribute targetTemp : TemperatureValue;
        attribute targetHumidity : HumidityValue;
        attribute duration : DurationValue;
        attribute toleranceTemp : TemperatureValue default 2.0 [degC];
        attribute toleranceHumidity : HumidityValue default 5.0 [percent];
    }
    item def EnvironmentalData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute timestamp : DurationValue;
    }

    // ---- Port Definitions ----
    port def TempSensorPort {
        out tempReading : TemperatureValue;
    }
    port def HumiditySensorPort {
        out humidityReading : HumidityValue;
    }
    port def PowerControlPort {
        in powerCommand : PowerValue;
    }
    port def DataPort {
        out data : EnvironmentalData;
    }
    port def ControlSignalPort {
        out targetTemp : TemperatureValue;
        out targetHumidity : HumidityValue;
    }
    port def SafetySignalPort {
        out overTempAlarm : Boolean;
        out emergencyStop : Boolean;
    }
    port def SpecimenPort {
        inout specimen : TestSpecimen;
    }

    // ---- Requirements ----
    requirement def ReliabilityTestRequirement {
        doc /* The EAT system shall reliably test specimens under accelerated environmental conditions. */
        subject eatSystem : EnvironmentalAcceleratedTestingSystem;
        objective {
            constraint { eatSystem.chamber.currentTemp <= 200.0 [degC] }
            constraint { eatSystem.chamber.currentHumidity <= 100.0 [percent] }
        }
    }

    requirement def TemperatureControlRequirement {
        doc /* The system shall maintain chamber temperature within tolerance of the test plan target. */
        subject controlSystem : ControlSystem;
        attribute tolerance : TemperatureValue default 2.0 [degC];
        objective {
            constraint { abs(controlSystem.measuredTemp - controlSystem.targetTemp) <= tolerance }
        }
    }

    requirement def HumidityControlRequirement {
        doc /* The system shall maintain chamber humidity within tolerance of the test plan target. */
        subject controlSystem : ControlSystem;
        attribute tolerance : HumidityValue default 5.0 [percent];
        objective {
            constraint { abs(controlSystem.measuredHumidity - controlSystem.targetHumidity) <= tolerance }
        }
    }

    requirement def SafetyShutdownRequirement {
        doc /* The safety system shall trigger emergency shutdown when temperature exceeds safe limit. */
        subject safetySystem : SafetySystem;
        attribute safeLimit : TemperatureValue default 150.0 [degC];
        objective {
            constraint { safetySystem.chamberTemp > safeLimit implies safetySystem.emergencyStop == true }
        }
    }

    requirement def DataAcquisitionRequirement {
        doc /* The data acquisition system shall record temperature and humidity at high frequency. */
        subject das : DataAcquisitionSystem;
        attribute minFrequency : FrequencyValue default 10.0 [Hz];
        objective {
            constraint { das.samplingFrequency >= minFrequency }
        }
    }

    // ---- Part Definitions ----
    part def EnvironmentalAcceleratedTestingSystem {
        attribute systemId : String;
        attribute maxTemp : TemperatureValue default 200.0 [degC];
        attribute maxHumidity : HumidityValue default 98.0 [percent];

        part chamber : EnvironmentalChamber;
        part heatingSystem : HeatingSystem;
        part coolingSystem : CoolingSystem;
        part humiditySystem : HumidityControlSystem;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part controlSystem : ControlSystem;
        part dataAcquisition : DataAcquisitionSystem;
        part safetySystem : SafetySystem;
        part loadingSystem : SpecimenLoadingSystem;

        // Connections
        connection tempSensorToControl connect tempSensor.readPort to controlSystem.tempInput;
        connection humiditySensorToControl connect humiditySensor.readPort to controlSystem.humidityInput;
        connection controlToHeater connect controlSystem.heaterPower to heatingSystem.powerIn;
        connection controlToCooler connect controlSystem.coolerPower to coolingSystem.powerIn;
        connection controlToHumidity connect controlSystem.humidifierPower to humiditySystem.powerIn;
        connection tempSensorToSafety connect tempSensor.readPort to safetySystem.tempInput;
        connection safetyToControl connect safetySystem.safetyOut to controlSystem.safetyIn;
        connection tempSensorToDAS connect tempSensor.readPort to dataAcquisition.tempInput;
        connection humiditySensorToDAS connect humiditySensor.readPort to dataAcquisition.humidityInput;
        connection loadingToChamber connect loadingSystem.specimenPort to chamber.specimenPort;

        // Requirement satisfaction
        satisfy ReliabilityTestRequirement by self;
        satisfy TemperatureControlRequirement by controlSystem;
        satisfy HumidityControlRequirement by controlSystem;
        satisfy SafetyShutdownRequirement by safetySystem;
        satisfy DataAcquisitionRequirement by dataAcquisition;

        // System-level state machine
        behavior stateMachine EATOperation {
            entry action { /* initialize system */ }
            state Loading {
                entry action { loadingSystem.load(); }
            }
            state Preheating {
                entry action { controlSystem.startPreheat(); }
            }
            state Stabilizing {
                entry action { controlSystem.stabilize(); }
            }
            state ActiveTesting {
                entry action { controlSystem.runTest(); }
            }
            state Cooldown {
                entry action { controlSystem.cooldown(); }
            }
            state Unloading {
                entry action { loadingSystem.unload(); }
            }
            transition Loading to Preheating when controlSystem.loadingComplete;
            transition Preheating to Stabilizing when controlSystem.preheatComplete;
            transition Stabilizing to ActiveTesting when controlSystem.environmentStable;
            transition ActiveTesting to Cooldown when controlSystem.testComplete;
            transition Cooldown to Unloading when controlSystem.cooldownComplete;
            transition any to Unloading when safetySystem.emergencyStop;
        }
    }

    part def EnvironmentalChamber {
        attribute currentTemp : TemperatureValue default 25.0 [degC];
        attribute currentHumidity : HumidityValue default 50.0 [percent];
        attribute volume : Real; // in liters
        attribute insulated : Boolean default true;

        port specimenPort : SpecimenPort;
        port internalTempPort : TempSensorPort;
        port internalHumidityPort : HumiditySensorPort;

        action def ConditionAir {
            in targetTemp : TemperatureValue;
            in targetHumidity : HumidityValue;
        }
    }

    part def HeatingSystem {
        attribute maxPower : PowerValue default 5000.0 [W];
        attribute currentPower : PowerValue default 0.0 [W];
        attribute active : Boolean default false;

        port powerIn : PowerControlPort;

        action def Heat {
            in powerLevel : PowerValue;
        }
    }

    part def CoolingSystem {
        attribute maxPower : PowerValue default 4000.0 [W];
        attribute currentPower : PowerValue default 0.0 [W];
        attribute active : Boolean default false;

        port powerIn : PowerControlPort;

        action def Cool {
            in powerLevel : PowerValue;
        }
    }

    part def HumidityControlSystem {
        attribute maxPower : PowerValue default 2000.0 [W];
        attribute currentPower : PowerValue default 0.0 [W];
        attribute active : Boolean default false;

        port powerIn : PowerControlPort;

        action def Humidify {
            in powerLevel : PowerValue;
        }
        action def Dehumidify {
            in powerLevel : PowerValue;
        }
    }

    part def TemperatureSensor {
        attribute accuracy : TemperatureValue default 0.5 [degC];
        attribute samplingRate : FrequencyValue default 10.0 [Hz];

        port readPort : TempSensorPort;

        action def ReadTemperature {
            out reading : TemperatureValue;
        }
    }

    part def HumiditySensor {
        attribute accuracy : HumidityValue default 2.0 [percent];
        attribute samplingRate : FrequencyValue default 10.0 [Hz];

        port readPort : HumiditySensorPort;

        action def ReadHumidity {
            out reading : HumidityValue;
        }
    }

    part def ControlSystem {
        attribute targetTemp : TemperatureValue default 25.0 [degC];
        attribute targetHumidity : HumidityValue default 50.0 [percent];
        attribute measuredTemp : TemperatureValue default 25.0 [degC];
        attribute measuredHumidity : HumidityValue default 50.0 [percent];
        attribute loadingComplete : Boolean default false;
        attribute preheatComplete : Boolean default false;
        attribute environmentStable : Boolean default false;
        attribute testComplete : Boolean default false;
        attribute cooldownComplete : Boolean default false;
        attribute emergencyActive : Boolean default false;

        port tempInput : TempSensorPort;
        port humidityInput : HumiditySensorPort;
        port heaterPower : PowerControlPort;
        port coolerPower : PowerControlPort;
        port humidifierPower : PowerControlPort;
        port safetyIn : SafetySignalPort;

        action def LoadTestPlan {
            in plan : TestPlan;
            then SetTargets;
        }
        action SetTargets {
            out newTargetTemp : TemperatureValue;
            out newTargetHumidity : HumidityValue;
        }
        action def StartPreheat { }
        action def Stabilize { }
        action def RunTest { }
        action def Cooldown { }

        behavior stateMachine ControllerMode {
            state Idle;
            state Preheating;
            state Stabilizing;
            state Testing;
            state Cooldown;
            state Emergency;
            transition Idle to Preheating when loadingComplete;
            transition Preheating to Stabilizing when preheatComplete;
            transition Stabilizing to Testing when environmentStable;
            transition Testing to Cooldown when testComplete;
            transition Cooldown to Idle when cooldownComplete;
            transition any to Emergency when safetyIn.emergencyStop;
        }
    }

    part def DataAcquisitionSystem {
        attribute samplingFrequency : FrequencyValue default 10.0 [Hz];
        attribute storageCapacity : Real; // in GB
        attribute recording : Boolean default false;

        port tempInput : TempSensorPort;
        port humidityInput : HumiditySensorPort;
        port dataOut : DataPort;

        action def RecordData {
            in temp : TemperatureValue;
            in humidity : HumidityValue;
            out recorded : EnvironmentalData;
        }
        action def StartRecording { }
        action def StopRecording { }
    }

    part def SafetySystem {
        attribute safeTempLimit : TemperatureValue default 150.0 [degC];
        attribute chamberTemp : TemperatureValue default 25.0 [degC];
        attribute overTempAlarm : Boolean default false;
        attribute emergencyStop : Boolean default false;

        port tempInput : TempSensorPort;
        port safetyOut : SafetySignalPort;

        action def MonitorTemperature {
            in temp : TemperatureValue;
            out alarm : Boolean;
            out stop : Boolean;
        }
        action def TriggerShutdown { }
    }

    part def SpecimenLoadingSystem {
        attribute capacity : MassValue default 50.0 [kg];
        attribute loaded : Boolean default false;

        port specimenPort : SpecimenPort;

        action def Load {
            in specimen : TestSpecimen;
        }
        action def Unload {
            out specimen : TestSpecimen;
        }
    }

    // ---- Example Test Plan ----
    item standardTestPlan : TestPlan {
        : targetTemp = 125.0 [degC];
        : targetHumidity = 85.0 [percent];
        : duration = 168.0 [h];
        : toleranceTemp = 2.0 [degC];
        : toleranceHumidity = 5.0 [percent];
    }
}
