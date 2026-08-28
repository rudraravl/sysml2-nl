package IndustrialMixingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value type VolumeUnit > Real {
        unit L;
    }

    value type MassUnit > Real {
        unit kg;
    }

    value type PowerUnit > Real {
        unit kW;
    }

    value type RotationalSpeedUnit > Real {
        unit rpm;
    }

    value type TemperatureUnit > Real {
        unit 'degC';
    }

    value type ViscosityUnit > Real {
        unit 'Pa*s';
    }

    value type DurationUnit > Real {
        unit min;
    }

    value type PressureUnit > Real {
        unit bar;
    }

    value type PercentUnit > Real {
        unit '%';
    }

    // ===== Item Types =====

    item def Ingredient {
        attribute name : String;
        attribute density : MassUnit;
        attribute targetVolume : VolumeUnit;
    }

    item def LiquidIngredient :> Ingredient;
    item def SemiLiquidIngredient :> Ingredient;

    item def Mixture {
        attribute volume : VolumeUnit;
        attribute temperature : TemperatureUnit;
        attribute viscosity : ViscosityUnit;
    }

    item def FinishedProduct :> Mixture {
        attribute qualityPassed : Boolean;
    }

    item def CleaningSolution {
        attribute concentration : PercentUnit;
    }

    item def ThermalFluid {
        attribute type : String;
        attribute flowRate : Real;
    }

    // ===== Port Definitions =====

    port def FluidPort {
        out item : Mixture;
        in item : Mixture;
    }

    port def IngredientPort {
        out item : Ingredient;
    }

    port def ThermalPort {
        out item : ThermalFluid;
    }

    port def ControlPort {
        in command : ControlCommand;
        out feedback : SensorFeedback;
    }

    port def PowerPort {
        out power : PowerUnit;
    }

    port def SignalPort {
        out signal : Real;
    }

    // ===== Control and Signal Items =====

    item def ControlCommand {
        attribute commandType : String;
        attribute parameter : Real;
    }

    item def SensorFeedback {
        attribute sensorType : String;
        attribute value : Real;
        attribute unit : String;
        attribute timestamp : Real;
    }

    item def Recipe {
        attribute recipeId : String;
        attribute ingredientSet : Ingredient[4];
        attribute targetTemperature : TemperatureUnit;
        attribute mixingSpeed : RotationalSpeedUnit;
        attribute mixingDuration : DurationUnit;
        attribute targetViscosity : ViscosityUnit;
        attribute toleranceViscosity : ViscosityUnit;
    }

    item def AlarmEvent {
        attribute alarmId : String;
        attribute severity : Integer;
        attribute description : String;
        attribute timestamp : Real;
    }

    // ===== Requirements =====

    requirement def VesselCapacityRequirement {
        doc "The mixing vessel shall have a capacity of at least 1000 liters."
        attribute minCapacity : VolumeUnit = 1000 [L];
        subject vessel : MixingVessel;
        require vessel.capacity >= minCapacity;
    }

    requirement def MotorPowerRequirement {
        doc "The mixing motor shall have a power rating of at least 15 kW."
        attribute minPower : PowerUnit = 15 [kW];
        subject motor : MixingMotor;
        require motor.powerRating >= minPower;
    }

    requirement def MotorSpeedRequirement {
        doc "The mixing motor shall be capable of running at up to 500 RPM."
        attribute maxSpeed : RotationalSpeedUnit = 500 [rpm];
        subject motor : MixingMotor;
        require motor.maxSpeed >= maxSpeed;
    }

    requirement def DispenserCountRequirement {
        doc "The system shall include four dedicated automated ingredient dispensers."
        attribute requiredCount : Integer = 4;
        subject system : MixingSystem;
        require system.dispenserCount == requiredCount;
    }

    requirement def TemperatureControlRequirement {
        doc "The system shall maintain mixture temperature within +/- 2 degrees C of target."
        attribute tolerance : TemperatureUnit = 2 ['degC'];
        subject system : MixingSystem;
        require abs(system.currentTemperature - system.targetTemperature) <= tolerance;
    }

    requirement def QualityCheckRequirement {
        doc "The system shall verify batch viscosity meets recipe specifications before discharge."
        subject system : MixingSystem;
        require system.measuredViscosity >= system.recipe.targetViscosity - system.recipe.toleranceViscosity;
    }

    requirement def CleaningCycleRequirement {
        doc "The system shall perform a cleaning cycle after each successful discharge."
        subject system : MixingSystem;
        require system.cleaningPerformed == true after system.dischargeCompleted;
    }

    requirement def AlarmStateRequirement {
        doc "The system shall enter an alarm state upon detection of any process anomaly."
        subject system : MixingSystem;
        require system.anomalyDetected implies system.state == "Alarm";
    }

    // ===== Part Definitions =====

    part def MixingVessel {
        attribute capacity : VolumeUnit = 1000 [L];
        attribute material : String = "Stainless Steel 316L";
        attribute currentVolume : VolumeUnit;
        attribute currentTemperature : TemperatureUnit;
        attribute currentViscosity : ViscosityUnit;
        
        port ingredientIn : IngredientPort[4];
        port mixtureOut : FluidPort;
        port thermalIn : ThermalPort;
        port coolingIn : ThermalPort;
        port controlInterface : ControlPort;
        
        exhibit state VesselBehavior {
            entry; then Idle;
            
            state Idle;
            state Filling;
            state Processing;
            state Discharging;
            state Cleaning;
            
            transition idle_to_filling
                source Idle
                target Filling
                when controlInterface.command.commandType == "startFilling";
            
            transition filling_to_processing
                source Filling
                target Processing
                when currentVolume >= controlInterface.command.parameter;
            
            transition processing_to_discharging
                source Processing
                target Discharging
                when controlInterface.command.commandType == "discharge";
            
            transition discharging_to_cleaning
                source Discharging
                target Cleaning
                when currentVolume <= 1 [L];
            
            transition cleaning_to_idle
                source Cleaning
                target Idle
                when controlInterface.command.commandType == "cleaningComplete";
        }
    }

    part def MixingMotor {
        attribute powerRating : PowerUnit = 15 [kW];
        attribute maxSpeed : RotationalSpeedUnit = 500 [rpm];
        attribute currentSpeed : RotationalSpeedUnit;
        attribute running : Boolean = false;
        
        port powerIn : PowerPort;
        port controlInterface : ControlPort;
        port speedSignal : SignalPort;
        
        exhibit state MotorBehavior {
            entry; then Stopped;
            
            state Stopped {
                entry action { currentSpeed = 0 [rpm]; running = false; }
            }
            
            state Running {
                entry action { running = true; }
            }
            
            state Faulted {
                entry action { running = false; }
            }
            
            transition stopped_to_running
                source Stopped
                target Running
                when controlInterface.command.commandType == "startMotor"
                do action { currentSpeed = controlInterface.command.parameter [rpm]; }
                send speedSignal.signal := currentSpeed;
            
            transition running_to_stopped
                source Running
                target Stopped
                when controlInterface.command.commandType == "stopMotor";
            
            transition any_to_faulted
                source Running
                target Faulted
                when currentSpeed > maxSpeed;
        }
    }

    part def HeatingSystem {
        attribute maxHeatingRate : TemperatureUnit = 5 ['degC'];
        attribute currentOutput : PercentUnit;
        attribute active : Boolean = false;
        
        port thermalOut : ThermalPort;
        port controlInterface : ControlPort;
        
        exhibit state HeaterBehavior {
            entry; then Off;
            
            state Off {
                entry action { active = false; currentOutput = 0 [%]; }
            }
            
            state Heating {
                entry action { active = true; }
            }
            
            transition off_to_heating
                source Off
                target Heating
                when controlInterface.command.commandType == "heat"
                do action { currentOutput = controlInterface.command.parameter [%]; }
                send thermalOut.item := ThermalFluid { type = "hot", flowRate = currentOutput / 100.0; };
            
            transition heating_to_off
                source Heating
                target Off
                when controlInterface.command.commandType == "stopHeating";
        }
    }

    part def CoolingSystem {
        attribute maxCoolingRate : TemperatureUnit = 5 ['degC'];
        attribute currentOutput : PercentUnit;
        attribute active : Boolean = false;
        
        port thermalOut : ThermalPort;
        port controlInterface : ControlPort;
        
        exhibit state CoolerBehavior {
            entry; then Off;
            
            state Off {
                entry action { active = false; currentOutput = 0 [%]; }
            }
            
            state Cooling {
                entry action { active = true; }
            }
            
            transition off_to_cooling
                source Off
                target Cooling
                when controlInterface.command.commandType == "cool"
                do action { currentOutput = controlInterface.command.parameter [%]; }
                send thermalOut.item := ThermalFluid { type = "cold", flowRate = currentOutput / 100.0; };
            
            transition cooling_to_off
                source Cooling
                target Off
                when controlInterface.command.commandType == "stopCooling";
        }
    }

    part def IngredientDispenser {
        attribute dispenserId : Integer;
        attribute ingredientType : String;
        attribute maxVolume : VolumeUnit = 250 [L];
        attribute dispensedVolume : VolumeUnit;
        attribute accuracy : PercentUnit = 0.5 [%];
        
        port ingredientOut : IngredientPort;
        port controlInterface : ControlPort;
        
        exhibit state DispenserBehavior {
            entry; then Ready;
            
            state Ready;
            state Dispensing;
            state Complete;
            state Error;
            
            transition ready_to_dispensing
                source Ready
                target Dispensing
                when controlInterface.command.commandType == "dispense"
                do action { dispensedVolume = 0 [L]; }
                send ingredientOut.item := Ingredient { name = ingredientType, targetVolume = controlInterface.command.parameter [L]; };
            
            transition dispensing_to_complete
                source Dispensing
                target Complete
                when dispensedVolume >= controlInterface.command.parameter [L];
            
            transition complete_to_ready
                source Complete
                target Ready
                when controlInterface.command.commandType == "reset";
            
            transition any_to_error
                source Dispensing
                target Error
                when dispensedVolume > maxVolume;
        }
    }

    part def TemperatureSensor {
        attribute sensorId : String = "TEMP_001";
        attribute range : TemperatureUnit = 200 ['degC'];
        attribute accuracy : TemperatureUnit = 0.1 ['degC'];
        attribute currentValue : TemperatureUnit;
        
        port feedbackOut : ControlPort;
        
        action def sense : TemperatureUnit {
            in vesselTemp : TemperatureUnit;
            return measured : TemperatureUnit;
        }
    }

    part def SpeedSensor {
        attribute sensorId : String = "SPD_001";
        attribute maxRange : RotationalSpeedUnit = 600 [rpm];
        attribute accuracy : RotationalSpeedUnit = 1 [rpm];
        attribute currentValue : RotationalSpeedUnit;
        
        port feedbackOut : ControlPort;
        
        action def sense : RotationalSpeedUnit {
            in motorSpeed : RotationalSpeedUnit;
            return measured : RotationalSpeedUnit;
        }
    }

    part def LevelSensor {
        attribute sensorId : String = "LVL_001";
        attribute maxRange : VolumeUnit = 1000 [L];
        attribute accuracy : VolumeUnit = 0.5 [L];
        attribute currentValue : VolumeUnit;
        
        port feedbackOut : ControlPort;
        
        action def sense : VolumeUnit {
            in vesselLevel : VolumeUnit;
            return measured : VolumeUnit;
        }
    }

    part def ViscositySensor {
        attribute sensorId : String = "VIS_001";
        attribute maxRange : ViscosityUnit = 1000 ['Pa*s'];
        attribute accuracy : ViscosityUnit = 0.5 ['Pa*s'];
        attribute currentValue : ViscosityUnit;
        
        port feedbackOut : ControlPort;
        
        action def sense : ViscosityUnit {
            in mixtureViscosity : ViscosityUnit;
            return measured : ViscosityUnit;
        }
    }

    part def ProcessController {
        attribute controllerId : String = "PLC_MAIN";
        attribute state : String;
        attribute currentRecipe : Recipe;
        attribute measuredTemperature : TemperatureUnit;
        attribute measuredSpeed : RotationalSpeedUnit;
        attribute measuredLevel : VolumeUnit;
        attribute measuredViscosity : ViscosityUnit;
        attribute targetTemperature : TemperatureUnit;
        attribute anomalyDetected : Boolean = false;
        attribute cleaningPerformed : Boolean = false;
        attribute dischargeCompleted : Boolean = false;
        attribute extendedMixingCount : Integer = 0;
        attribute maxExtendedMixing : Integer = 3;
        
        port vesselControl : ControlPort;
        port motorControl : ControlPort;
        port heaterControl : ControlPort;
        port coolerControl : ControlPort;
        port dispenserControl : ControlPort[4];
        port tempFeedback : ControlPort;
        port speedFeedback : ControlPort;
        port levelFeedback : ControlPort;
        port viscosityFeedback : ControlPort;
        
        exhibit state ControllerStateMachine {
            entry; then Standby;
            
            state Standby {
                doc "Awaiting recipe input."
                entry action { state = "Standby"; }
            }
            
            state RecipeLoaded {
                entry action { state = "RecipeLoaded"; }
            }
            
            state Dispensing {
                entry action { state = "Dispensing"; }
                do action {
                    var i : Integer;
                    for i in 1..4 {
                        send dispenserControl[i].command := ControlCommand { commandType = "dispense", parameter = currentRecipe.ingredientSet[i].targetVolume; };
                    }
                }
            }
            
            state TemperatureRegulation {
                entry action { state = "TemperatureRegulation"; }
                do action {
                    if measuredTemperature < targetTemperature {
                        send heaterControl.command := ControlCommand { commandType = "heat", parameter = 80.0; };
                    } else {
                        send coolerControl.command := ControlCommand { commandType = "cool", parameter = 80.0; };
                    }
                }
            }
            
            state Mixing {
                entry action { state = "Mixing"; }
                do action {
                    send motorControl.command := ControlCommand { commandType = "startMotor", parameter = currentRecipe.mixingSpeed; };
                }
            }
            
            state QualityCheck {
                entry action { state = "QualityCheck"; }
                do action {
                    if measuredViscosity >= currentRecipe.targetViscosity - currentRecipe.toleranceViscosity {
                        // Quality passed
                    } else {
                        // Quality failed - will extend mixing
                    }
                }
            }
            
            state Discharging {
                entry action { state = "Discharging"; }
                do action {
                    send vesselControl.command := ControlCommand { commandType = "discharge", parameter = 0.0; };
                    send motorControl.command := ControlCommand { commandType = "stopMotor", parameter = 0.0; };
                }
            }
            
            state Cleaning {
                entry action { state = "Cleaning"; }
                do action {
                    send vesselControl.command := ControlCommand { commandType = "cleaningComplete", parameter = 0.0; };
                    cleaningPerformed = true;
                }
            }
            
            state Alarm {
                entry action { state = "Alarm"; }
                do action {
                    send motorControl.command := ControlCommand { commandType = "stopMotor", parameter = 0.0; };
                    send heaterControl.command := ControlCommand { commandType = "stopHeating", parameter = 0.0; };
                    send coolerControl.command := ControlCommand { commandType = "stopCooling", parameter = 0.0; };
                }
            }
            
            transition standby_to_recipeLoaded
                source Standby
                target RecipeLoaded
                when currentRecipe != null;
            
            transition recipeLoaded_to_dispensing
                source RecipeLoaded
                target Dispensing;
            
            transition dispensing_to_tempRegulation
                source Dispensing
                target TemperatureRegulation
                when measuredLevel >= currentRecipe.ingredientSet.targetVolume.sum;
            
            transition tempRegulation_to_mixing
                source TemperatureRegulation
                target Mixing
                when abs(measuredTemperature - targetTemperature) <= 2 ['degC'];
            
            transition mixing_to_qualityCheck
                source Mixing
                target QualityCheck
                when currentRecipe.mixingDuration elapsed;
            
            transition qualityCheck_to_discharging
                source QualityCheck
                target Discharging
                when measuredViscosity >= currentRecipe.targetViscosity - currentRecipe.toleranceViscosity;
            
            transition qualityCheck_to_mixing_extended
                source QualityCheck
                target Mixing
                when measuredViscosity < currentRecipe.targetViscosity - currentRecipe.toleranceViscosity
                    and extendedMixingCount < maxExtendedMixing
                do action { extendedMixingCount = extendedMixingCount + 1; };
            
            transition qualityCheck_to_alarm
                source QualityCheck
                target Alarm
                when measuredViscosity < currentRecipe.targetViscosity - currentRecipe.toleranceViscosity
                    and extendedMixingCount >= maxExtendedMixing;
            
            transition discharging_to_cleaning
                source Discharging
                target Cleaning
                when measuredLevel <= 1 [L]
                do action { dischargeCompleted = true; };
            
            transition cleaning_to_standby
                source Cleaning
                target Standby
                when cleaningPerformed == true
                do action { cleaningPerformed = false; dischargeCompleted = false; extendedMixingCount = 0; };
            
            transition any_to_alarm
                source Standby
                target Alarm
                when anomalyDetected == true;
            
            transition any_to_alarm_2
                source Dispensing
                target Alarm
                when anomalyDetected == true;
            
            transition any_to_alarm_3
                source TemperatureRegulation
                target Alarm
                when anomalyDetected == true;
            
            transition any_to_alarm_4
                source Mixing
                target Alarm
                when anomalyDetected == true;
            
            transition alarm_to_standby
                source Alarm
                target Standby
                when anomalyDetected == false;
        }
    }

    part def DischargeValve {
        attribute valveId : String = "VALVE_DISCHARGE";
        attribute open : Boolean = false;
        attribute flowRate : VolumeUnit;
        
        port mixtureOut : FluidPort;
        port controlInterface : ControlPort;
        
        exhibit state ValveBehavior {
            entry; then Closed;
            
            state Closed {
                entry action { open = false; flowRate = 0 [L]; }
            }
            
            state Open {
                entry action { open = true; flowRate = 50 [L]; }
            }
            
            transition closed_to_open
                source Closed
                target Open
                when controlInterface.command.commandType == "openValve";
            
            transition open_to_closed
                source Open
                target Closed
                when controlInterface.command.commandType == "closeValve";
        }
    }

    part def CleaningSystem {
        attribute cleaningSolutionTank : VolumeUnit = 100 [L];
        attribute pressure : PressureUnit = 3 [bar];
        attribute active : Boolean = false;
        
        port cleaningOut : FluidPort;
        port controlInterface : ControlPort;
        
        exhibit state CleaningBehavior {
            entry; then Inactive;
            
            state Inactive {
                entry action { active = false; }
            }
            
            state Cleaning {
                entry action { active = true; }
                do action {
                    send cleaningOut.item := Mixture { volume = 50 [L], temperature = 60 ['degC'], viscosity = 1 ['Pa*s']; };
                }
            }
            
            transition inactive_to_cleaning
                source Inactive
                target Cleaning
                when controlInterface.command.commandType == "startCleaning";
            
            transition cleaning_to_inactive
                source Cleaning
                target Inactive
                when controlInterface.command.commandType == "stopCleaning";
        }
    }

    // ===== Top-Level System =====

    part def MixingSystem {
        attribute systemId : String = "MIX_SYS_001";
        attribute dispenserCount : Integer = 4;
        attribute currentTemperature : TemperatureUnit;
        attribute targetTemperature : TemperatureUnit;
        attribute measuredViscosity : ViscosityUnit;
        attribute state : String;
        attribute anomalyDetected : Boolean = false;
        attribute cleaningPerformed : Boolean = false;
        attribute dischargeCompleted : Boolean = false;
        
        part vessel : MixingVessel;
        part motor : MixingMotor;
        part heater : HeatingSystem;
        part cooler : CoolingSystem;
        part dispensers : IngredientDispenser[4] {
            attribute dispenserId : Integer;
        }
        part dischargeValve : DischargeValve;
        part cleaningSystem : CleaningSystem;
        
        part controller : ProcessController;
        
        part tempSensor : TemperatureSensor;
        part speedSensor : SpeedSensor;
        part levelSensor : LevelSensor;
        part viscositySensor : ViscositySensor;
        
        // Connections from controller to actuators
        connection controller.vesselControl to vessel.controlInterface;
        connection controller.motorControl to motor.controlInterface;
        connection controller.heaterControl to heater.controlInterface;
        connection controller.coolerControl to cooler.controlInterface;
        connection controller.dispenserControl to dispensers.controlInterface;
        connection controller.vesselControl to dischargeValve.controlInterface;
        connection controller.vesselControl to cleaningSystem.controlInterface;
        
        // Connections from sensors to controller
        connection tempSensor.feedbackOut to controller.tempFeedback;
        connection speedSensor.feedbackOut to controller.speedFeedback;
        connection levelSensor.feedbackOut to controller.levelFeedback;
        connection viscositySensor.feedbackOut to controller.viscosityFeedback;
        
        // Connections from dispensers to vessel
        connection dispensers.ingredientOut to vessel.ingredientIn;
        
        // Connections from thermal systems to vessel
        connection heater.thermalOut to vessel.thermalIn;
        connection cooler.thermalOut to vessel.coolingIn;
        
        // Connection from vessel to discharge valve
        connection vessel.mixtureOut to dischargeValve.mixtureOut;
        
        // Connection from cleaning system to vessel
        connection cleaningSystem.cleaningOut to vessel.mixtureOut;
        
        // Connection from motor to vessel (mechanical coupling implied)
        connection motor.speedSignal to speedSensor.feedbackOut;
        
        // Requirements satisfaction
        satisfy VesselCapacityRequirement by vessel;
        satisfy MotorPowerRequirement by motor;
        satisfy MotorSpeedRequirement by motor;
        satisfy DispenserCountRequirement by self;
        satisfy TemperatureControlRequirement by self;
        satisfy QualityCheckRequirement by self;
        satisfy CleaningCycleRequirement by self;
        satisfy AlarmStateRequirement by self;
    }

}
