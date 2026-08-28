package 'Industrial Mixing System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    item def Recipe {
        attribute targetTemp : TemperatureValue;
        attribute mixDuration : DurationValue;
        attribute mixSpeed : AngularVelocityValue;
        attribute targetViscosity : DynamicViscosityValue;
        attribute ingredientVolumes : VolumeValue[4];
    }
    
    attribute def RecipeLoadedSignal;
    attribute def DispenseCompleteSignal;
    attribute def TempReachedSignal;
    attribute def MixCompleteSignal;
    attribute def QualityPassSignal;
    attribute def QualityFailSignal;
    attribute def DischargeCompleteSignal;
    attribute def CleanCompleteSignal;
    attribute def AlarmSignal;
    attribute def ResetSignal;
    
    action def DispenseAction;
    action def RegulateTempAction;
    action def MixAction;
    action def QualityCheckAction;
    action def DischargeAction;
    action def CleanAction;
    
    part def MixingVessel {
        attribute capacity : VolumeValue = 1000 [L];
        attribute material : String = "Stainless Steel";
        in item ingredientFlow [4];
        in item heatFlow;
        in item coolFlow;
        in item dischargeCmd;
        out item dischargeFlow;
        attribute currentLevel : VolumeValue;
        attribute currentTemp : TemperatureValue;
        attribute currentViscosity : DynamicViscosityValue;
    }
    
    part def MixingMotor {
        attribute power : PowerValue = 15 [kW];
        attribute maxSpeed : AngularVelocityValue = 500 [1/min];
        attribute currentSpeed : AngularVelocityValue;
        in item motorControl;
    }
    
    part def HeatingSystem {
        in item heatControl;
        out item heatFlow;
    }
    
    part def CoolingSystem {
        in item coolControl;
        out item coolFlow;
    }
    
    part def IngredientDispenser {
        attribute dispenseVolume : VolumeValue;
        in item dispenseControl;
        out item dispenseFlow;
    }
    
    part def TemperatureSensor {
        out item tempReading;
    }
    part def SpeedSensor {
        out item speedReading;
    }
    part def LevelSensor {
        out item levelReading;
    }
    part def ViscositySensor {
        out item viscosityReading;
    }
    
    part def ProcessController {
        out item dispenseCmd [4];
        out item heatCmd;
        out item coolCmd;
        out item motorCmd;
        out item dischargeCmd;
        out item cleanCmd;
        
        in item tempIn;
        in item speedIn;
        in item levelIn;
        in item viscosityIn;
        
        exhibit state controllerStates {
            entry; then standby;
            state standby;
            accept RecipeLoadedSignal then dispense;
            
            state dispense {
                entry action dispenseAction : DispenseAction;
            }
            accept DispenseCompleteSignal then tempControl;
            
            state tempControl {
                entry action regulateTempAction : RegulateTempAction;
            }
            accept TempReachedSignal then mixing;
            
            state mixing {
                entry action mixAction : MixAction;
            }
            accept MixCompleteSignal then qualityCheck;
            
            state qualityCheck {
                entry action qualityCheckAction : QualityCheckAction;
            }
            accept QualityPassSignal then discharge;
            accept QualityFailSignal then mixing;
            
            state discharge {
                entry action dischargeAction : DischargeAction;
            }
            accept DischargeCompleteSignal then cleaning;
            
            state cleaning {
                entry action cleanAction : CleanAction;
            }
            accept CleanCompleteSignal then standby;
            
            accept AlarmSignal then alarm;
            state alarm;
            accept ResetSignal then standby;
        }
    }
    
    requirement ConsistentBatchesReq {
        doc /* The system shall produce consistent batches of blended liquid products. */
    }
    
    requirement TemperatureControlReq {
        doc /* The system shall precisely regulate mixture temperature according to recipe specifications. */
    }
    
    requirement QualityCheckReq {
        doc /* The system shall ensure batch meets required viscosity standards before discharge. */
    }
    
    part mixingSystem {
        satisfy ConsistentBatchesReq;
        
        part vessel : MixingVessel;
        part motor : MixingMotor;
        part heater : HeatingSystem {
            satisfy TemperatureControlReq;
        }
        part cooler : CoolingSystem;
        part dispensers : IngredientDispenser[4];
        part controller : ProcessController;
        part tempSensor : TemperatureSensor;
        part speedSensor : SpeedSensor;
        part levelSensor : LevelSensor;
        part viscositySensor : ViscositySensor {
            satisfy QualityCheckReq;
        }
        
        connect controller.dispenseCmd to dispensers.dispenseControl;
        connect dispensers.dispenseFlow to vessel.ingredientFlow;
        
        connect controller.heatCmd to heater.heatControl;
        connect heater.heatFlow to vessel.heatFlow;
        
        connect controller.coolCmd to cooler.coolControl;
        connect cooler.coolFlow to vessel.coolFlow;
        
        connect controller.motorCmd to motor.motorControl;
        
        connect tempSensor.tempReading to controller.tempIn;
        connect speedSensor.speedReading to controller.speedIn;
        connect levelSensor.levelReading to controller.levelIn;
        connect viscositySensor.viscosityReading to controller.viscosityIn;
        
        connect controller.dischargeCmd to vessel.dischargeCmd;
    }
}
