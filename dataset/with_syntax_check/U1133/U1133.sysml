package 'Mix Automation System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def RecipeIdentifier :> String;
    
    attribute def MixRecipe {
        attribute recipeId : RecipeIdentifier;
        attribute ingredientCount : Integer;
        attribute targetTemperature : ThermodynamicTemperatureValue;
        attribute mixingDuration : TimeValue;
        attribute mixingSpeed : AngularVelocityValue;
        attribute targetViscosity : Real;
    }
    
    attribute def IngredientSpec {
        attribute name : String;
        attribute targetVolume : VolumeValue;
        attribute density : DensityValue;
        attribute optimalTemperature : ThermodynamicTemperatureValue;
    }
    
    attribute def QualityMetrics {
        attribute homogeneity : Real;
        attribute viscosity : Real;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute uniformity : Real;
    }
    
    item def Ingredient {
        attribute specification : IngredientSpec;
        attribute actualVolume : VolumeValue;
        attribute currentTemperature : ThermodynamicTemperatureValue;
    }
    
    item def MixedBatch {
        attribute batchId : String;
        attribute totalVolume : VolumeValue;
        attribute quality : QualityMetrics;
        attribute timestamp : String;
    }
    
    port def IngredientInputPort {
        in item ingredient : Ingredient;
    }
    
    port def ProductOutputPort {
        out item batch : MixedBatch;
    }
    
    port def RecipeControlPort {
        in attribute recipe : MixRecipe;
        out attribute status : String;
    }
    
    port def SensorDataPort {
        out attribute temperature : ThermodynamicTemperatureValue;
        out attribute speed : AngularVelocityValue;
        out attribute level : LengthValue;
        out attribute viscosity : Real;
    }
    
    part def TemperatureSensor {
        attribute sensorId : String;
        port dataOut : SensorDataPort;
        
        action def MeasureTemperature {
            out reading : ThermodynamicTemperatureValue;
        }
    }
    
    part def ViscositySensor {
        attribute sensorId : String;
        port dataOut : SensorDataPort;
        
        action def MeasureViscosity {
            out reading : Real;
        }
    }
    
    part def LevelSensor {
        attribute sensorId : String;
        port dataOut : SensorDataPort;
        
        action def MeasureLevel {
            out reading : LengthValue;
        }
    }
    
    part def SpeedSensor {
        attribute sensorId : String;
        port dataOut : SensorDataPort;
        
        action def MeasureSpeed {
            out reading : AngularVelocityValue;
        }
    }
    
    part def HeatingSystem {
        attribute maxPower : PowerValue;
        attribute currentPower : PowerValue;
        
        action def ApplyHeat {
            in targetTemperature : ThermodynamicTemperatureValue;
            in currentTemperature : ThermodynamicTemperatureValue;
            out powerOutput : PowerValue;
        }
    }
    
    part def CoolingSystem {
        attribute coolingCapacity : PowerValue;
        attribute currentCoolingRate : PowerValue;
        
        action def ApplyCooling {
            in targetTemperature : ThermodynamicTemperatureValue;
            in currentTemperature : ThermodynamicTemperatureValue;
            out coolingOutput : PowerValue;
        }
    }
    
    part def MixingMotor {
        attribute ratedPower : PowerValue;
        attribute maxSpeed : AngularVelocityValue;
        attribute currentSpeed : AngularVelocityValue;
        attribute torque : TorqueValue;
        
        action def Drive {
            in commandedSpeed : AngularVelocityValue;
            out actualSpeed : AngularVelocityValue;
            out outputTorque : TorqueValue;
        }
    }
    
    part def MixingVessel {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute vesselTemperature : ThermodynamicTemperatureValue;
        attribute material : String;
        
        port ingredientIn : IngredientInputPort[4];
        port productOut : ProductOutputPort;
    }
    
    part def IngredientDispenser {
        attribute dispenserId : String;
        attribute maxFlowRate : VolumeFlowRateValue;
        port output : IngredientInputPort;
        
        action def Dispense {
            in ingredient : Ingredient;
            in targetVolume : VolumeValue;
            out actualVolume : VolumeValue;
            out dispensingTime : TimeValue;
        }
    }
    
    part def ProcessController {
        port recipeControl : RecipeControlPort;
        port tempSensorData : SensorDataPort;
        port speedSensorData : SensorDataPort;
        port levelSensorData : SensorDataPort;
        port viscositySensorData : SensorDataPort;
        
        attribute activeRecipe : MixRecipe;
        attribute processState : String;
        attribute alarmStatus : String;
        
        action def ExecuteRecipe {
            in recipe : MixRecipe;
            out heatingCommand : PowerValue;
            out coolingCommand : PowerValue;
            out speedCommand : AngularVelocityValue;
            out dispensingSequence : VolumeValue[*];
        }
    }
    
    action def ValidateRecipe {
        in recipe : MixRecipe;
        out isValid : Boolean;
        out validationErrors : String[*];
    }
    
    action def DispenseAllIngredients {
        in recipe : MixRecipe;
        in dispensers : IngredientDispenser[*];
        out totalVolume : VolumeValue;
        out dispensingComplete : Boolean;
    }
    
    action def RegulateTemperature {
        in targetTemp : ThermodynamicTemperatureValue;
        in currentTemp : ThermodynamicTemperatureValue;
        in heater : HeatingSystem;
        in cooler : CoolingSystem;
        out achievedTemp : ThermodynamicTemperatureValue;
        out stabilized : Boolean;
    }
    
    action def PerformMixing {
        in duration : TimeValue;
        in speed : AngularVelocityValue;
        in motor : MixingMotor;
        out mixingComplete : Boolean;
        out actualDuration : TimeValue;
    }
    
    action def AssessQuality {
        in mixingTime : TimeValue;
        in mixingSpeed : AngularVelocityValue;
        in temperature : ThermodynamicTemperatureValue;
        in viscosity : Real;
        out quality : QualityMetrics;
        out meetsStandards : Boolean;
    }
    
    action def DischargeBatch {
        in vessel : MixingVessel;
        in qualityMetrics : QualityMetrics;
        out batch : MixedBatch;
    }
    
    action def AutomatedMixingProcess {
        in recipe : MixRecipe;
        out finalBatch : MixedBatch;
        
        first start;
        
        then action validateRecipe : ValidateRecipe {
            in recipe = AutomatedMixingProcess::recipe;
            out isValid;
        }
        
        then decide;
            if validateRecipe.isValid then initialize;
            if not validateRecipe.isValid then abort;
        
        action initialize {
            doc /* Initialize vessel, verify sensors, prepare dispensers */
        }
        
        then action dispenseIngredients : DispenseAllIngredients {
            in recipe = AutomatedMixingProcess::recipe;
            out totalVolume;
            out dispensingComplete;
        }
        
        then action preHeat : RegulateTemperature {
            in targetTemp = recipe.targetTemperature;
            out achievedTemp;
            out stabilized;
        }
        
        then merge mixingCycle;
        
        action mixingCycle {
            action monitorTemp {
                doc /* Continuously monitor temperature during mixing */
            }
            
            then action adjustTemperature : RegulateTemperature {
                in targetTemp = recipe.targetTemperature;
            }
            
            then action mix : PerformMixing {
                in duration = recipe.mixingDuration;
                in speed = recipe.mixingSpeed;
                out mixingComplete;
            }
            
            then action assessQuality : AssessQuality {
                out quality;
                out meetsStandards;
            }
            
            then decide;
                if assessQuality.meetsStandards then discharge;
                if not assessQuality.meetsStandards then extendMixing;
            
            action extendMixing {
                doc /* Extend mixing time to improve quality */
            }
            then mixingCycle;
        }
        
        action discharge : DischargeBatch {
            out batch;
        }
        
        flow discharge.batch to AutomatedMixingProcess::finalBatch;
        
        then action cleanup {
            doc /* Clean vessel and prepare for next batch */
        }
        
        then done;
        
        action abort {
            doc /* Abort process due to invalid recipe */
        }
        then done;
    }
    
    state machine def MixingSystemController {
        initial state Offline;
        
        state Standby {
            doc /* System powered, awaiting recipe */
        }
        
        state Dispensing {
            doc /* Dispensing ingredients into vessel */
            entry action entryActivateDispensers {
                doc /* Activate dispensers */
            }
        }
        
        state Heating {
            doc /* Heating mixture to target temperature */
            do action doRegulateTemperature {
                doc /* Monitor and regulate temperature */
            }
        }
        
        state Mixing {
            doc /* Actively mixing ingredients */
            do action doDriveMotor {
                doc /* Drive motor at specified speed */
            }
        }
        
        state QualityCheck {
            doc /* Assessing mixture quality */
        }
        
        state Discharging {
            doc /* Discharging finished batch */
            exit action exitCloseValve {
                doc /* Close discharge valve */
            }
        }
        
        state Cleaning {
            doc /* Cleaning vessel between batches */
        }
        
        state Alarm {
            doc /* System in alarm state */
        }
        
        transition powerOn first Offline then Standby;
        transition recipeLoaded first Standby then Dispensing;
        transition dispensingComplete first Dispensing then Heating;
        transition temperatureReached first Heating then Mixing;
        transition mixingComplete first Mixing then QualityCheck;
        transition qualityAccepted first QualityCheck then Discharging;
        transition qualityRejected first QualityCheck then Mixing;
        transition dischargingComplete first Discharging then Cleaning;
        transition cleaningComplete first Cleaning then Standby;
        transition alarmTriggered first Mixing then Alarm;
        transition alarmCleared first Alarm then Standby;
        transition powerOff first Standby then Offline;
    }
    
    part mixAutomationSystem {
        doc /* 
            The Mix Automation System is an industrial process control system designed 
            to automatically blend multiple liquid or semi-liquid ingredients into a 
            homogeneous mixture according to precise recipes.
            
            Its primary function is to execute automated mixing operations by:
            1. Precisely dispensing multiple ingredients in specified quantities
            2. Heating or cooling the mixture to optimal processing temperature
            3. Mechanically mixing ingredients at controlled speeds and durations
            4. Continuously monitoring quality parameters (temperature, viscosity, homogeneity)
            5. Discharging finished batches that meet quality standards
            
            The system ensures consistent product quality, reduces manual intervention,
            minimizes waste, and maintains full traceability of each production batch.
        */
        
        part vessel : MixingVessel {
            :>> capacity = 1000.0 [L];
            :>> material = "Stainless Steel 316L";
        }
        
        part dispenserA : IngredientDispenser {
            :>> dispenserId = "DISP-A";
            :>> maxFlowRate = 50.0 [L/min];
        }
        
        part dispenserB : IngredientDispenser {
            :>> dispenserId = "DISP-B";
            :>> maxFlowRate = 50.0 [L/min];
        }
        
        part dispenserC : IngredientDispenser {
            :>> dispenserId = "DISP-C";
            :>> maxFlowRate = 30.0 [L/min];
        }
        
        part dispenserD : IngredientDispenser {
            :>> dispenserId = "DISP-D";
            :>> maxFlowRate = 20.0 [L/min];
        }
        
        part mixMotor : MixingMotor {
            :>> ratedPower = 15.0 [kW];
            :>> maxSpeed = 500.0 [rpm];
        }
        
        part heater : HeatingSystem {
            :>> maxPower = 25.0 [kW];
        }
        
        part cooler : CoolingSystem {
            :>> coolingCapacity = 20.0 [kW];
        }
        
        part tempSensor : TemperatureSensor {
            :>> sensorId = "TE-101";
        }
        
        part speedSensor : SpeedSensor {
            :>> sensorId = "SE-101";
        }
        
        part levelSensor : LevelSensor {
            :>> sensorId = "LE-101";
        }
        
        part viscositySensor : ViscositySensor {
            :>> sensorId = "VE-101";
        }
        
        part controller : ProcessController;
        
        connect dispenserA.output to vessel.ingredientIn[1];
        connect dispenserB.output to vessel.ingredientIn[2];
        connect dispenserC.output to vessel.ingredientIn[3];
        connect dispenserD.output to vessel.ingredientIn[4];
        
        connect tempSensor.dataOut to controller.tempSensorData;
        connect speedSensor.dataOut to controller.speedSensorData;
        connect levelSensor.dataOut to controller.levelSensorData;
        connect viscositySensor.dataOut to controller.viscositySensorData;
        
        exhibit stateController : MixingSystemController;
        
        perform action mixingOperations : AutomatedMixingProcess[*] ordered;
    }
    
    requirement def FunctionalRequirement;
    
    requirement automatedMixingCapability : FunctionalRequirement {
        doc /* 
            The Mix Automation System shall automatically blend multiple ingredients 
            into a homogeneous mixture by precisely dispensing, heating, and mixing 
            according to recipe specifications, with continuous quality monitoring.
        */
        
        subject mixAutomationSystem;
    }
    
    requirement def QualityRequirement;
    
    requirement mixHomogeneity : QualityRequirement {
        doc /* 
            The system shall produce batches with homogeneity >= 98% as measured 
            by the quality assessment process.
        */
        
        subject batch : MixedBatch;
        
        require constraint {
            batch.quality.homogeneity >= 0.98
        }
    }
    
    requirement def TemperatureControlRequirement;
    
    requirement temperatureAccuracy : TemperatureControlRequirement {
        doc /* 
            The system shall maintain mixture temperature within +/- 1.5 K of 
            the target temperature specified in the recipe.
        */
        
        attribute targetTemp : ThermodynamicTemperatureValue;
        attribute actualTemp : ThermodynamicTemperatureValue;
        
        require constraint {
            abs(actualTemp - targetTemp) <= 1.5 [K]
        }
    }
    
    requirement def DispensingPrecisionRequirement;
    
    requirement dispensingAccuracy : DispensingPrecisionRequirement {
        doc /* 
            Each ingredient shall be dispensed within +/- 0.5% of the specified 
            volume to ensure recipe accuracy.
        */
        
        attribute targetVolume : VolumeValue;
        attribute actualVolume : VolumeValue;
        
        require constraint {
            abs(actualVolume - targetVolume) / targetVolume <= 0.005
        }
    }
    
    requirement def PerformanceRequirement;
    
    requirement batchCycleTime : PerformanceRequirement {
        doc /* 
            The system shall complete a full batch cycle (dispense, heat, mix, 
            discharge, clean) within 45 minutes for standard recipes.
        */
        
        attribute cycleTime : TimeValue;
        
        require constraint {
            cycleTime <= 45.0 [min]
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for Mix Automation System */
        
        require automatedMixingCapability;
        require mixHomogeneity;
        require temperatureAccuracy;
        require dispensingAccuracy;
        require batchCycleTime;
    }
}
