package RotimaticSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    doc /* 
     * High-level primary function:
     * The Rotimatic system automatically transforms user-loaded dry flour, water, and oil
     * into cooked flatbreads by metering ingredients, kneading dough, portioning dough balls,
     * flattening each portion, cooking it on heated plates, and dispensing finished rotis.
     */

    attribute def gram :> mass;
    attribute def milliliter :> volume;
    attribute def degreeCelsius :> temperature;
    attribute def second :> time;
    attribute def watt :> power;
    attribute def newton :> force;
    attribute def millimeter :> length;
    attribute def percent;
    attribute def count;

    item def Flour {
        attribute mass : gram;
        attribute flourType : FlourKind;
        attribute hydrationAbsorption : percent;
    }

    enum def FlourKind {
        enum wholeWheat;
        enum multigrain;
        enum millet;
        enum glutenFree;
    }

    item def Water {
        attribute volume : milliliter;
        attribute temperature : degreeCelsius;
    }

    item def Oil {
        attribute volume : milliliter;
    }

    item def Dough {
        attribute mass : gram;
        attribute hydration : percent;
        attribute kneadTime : second;
        attribute elasticityIndex : percent;
    }

    item def DoughPortion {
        attribute mass : gram;
        attribute diameter : millimeter;
        attribute thickness : millimeter;
    }

    item def UncookedFlatbread {
        attribute diameter : millimeter;
        attribute thickness : millimeter;
        attribute moisture : percent;
    }

    item def CookedRoti {
        attribute diameter : millimeter;
        attribute thickness : millimeter;
        attribute surfaceTemperature : degreeCelsius;
        attribute browningLevel : percent;
        attribute softnessIndex : percent;
    }

    item def WasteResidue {
        attribute mass : gram;
        attribute source : String;
    }

    item def UserCommand {
        attribute rotiCount : count;
        attribute roastLevel : RoastLevel;
        attribute thicknessSetting : ThicknessSetting;
        attribute oilEnabled : Boolean;
    }

    enum def RoastLevel {
        enum light;
        enum medium;
        enum dark;
    }

    enum def ThicknessSetting {
        enum thin;
        enum regular;
        enum thick;
    }

    item def StatusMessage {
        attribute code : String;
        attribute text : String;
        attribute severity : StatusSeverity;
    }

    enum def StatusSeverity {
        enum info;
        enum warning;
        enum fault;
    }

    item def ElectricalPower {
        attribute voltage : volt;
        attribute current : ampere;
        attribute consumedPower : watt;
    }

    item def ThermalEnergy {
        attribute heaterPower : watt;
        attribute targetTemperature : degreeCelsius;
        attribute measuredTemperature : degreeCelsius;
    }

    item def MechanicalWork {
        attribute torqueDemand : newton;
        attribute duration : second;
    }

    port def IngredientInputPort {
        in item flour : Flour;
        in item water : Water;
        in item oil : Oil;
    }

    port def FoodOutputPort {
        out item cookedRoti : CookedRoti;
        out item wasteResidue : WasteResidue;
    }

    port def PowerPort {
        in item electricalPower : ElectricalPower;
    }

    port def UserInterfacePort {
        in item command : UserCommand;
        out item status : StatusMessage;
    }

    port def SensorDataPort {
        out attribute temperature : degreeCelsius;
        out attribute mass : gram;
        out attribute motorLoad : percent;
        out attribute doorClosed : Boolean;
        out attribute trayPresent : Boolean;
    }

    port def ControlPort {
        in item command : UserCommand;
        out item status : StatusMessage;
    }

    port def DoughTransferPort {
        out item dough : Dough;
        in item doughIn : Dough;
    }

    port def PortionTransferPort {
        out item portion : DoughPortion;
        in item portionIn : DoughPortion;
    }

    port def FlatbreadTransferPort {
        out item flatbread : UncookedFlatbread;
        in item flatbreadIn : UncookedFlatbread;
    }

    port def RotiTransferPort {
        out item roti : CookedRoti;
        in item rotiIn : CookedRoti;
    }

    part def Rotimatic {
        port powerPort : PowerPort;
        port ingredientInput : IngredientInputPort;
        port foodOutput : FoodOutputPort;
        port userInterface : UserInterfacePort;

        attribute maximumRotiBatch : count = 20 [count];
        attribute nominalRotiDiameter : millimeter = 150 [millimeter];
        attribute nominalRotiThickness : millimeter = 2.2 [millimeter];
        attribute nominalCookingTemperature : degreeCelsius = 220 [degreeCelsius];
        attribute standbyPower : watt = 8 [watt];
        attribute peakPower : watt = 1800 [watt];

        part controller : EmbeddedController;
        part flourReservoir : FlourReservoir;
        part waterReservoir : WaterReservoir;
        part oilReservoir : OilReservoir;
        part meteringSubsystem : IngredientMeteringSubsystem;
        part kneadingSubsystem : KneadingSubsystem;
        part portioningSubsystem : PortioningSubsystem;
        part flatteningSubsystem : FlatteningSubsystem;
        part cookingSubsystem : CookingSubsystem;
        part dispensingSubsystem : DispensingSubsystem;
        part sensorSuite : SensorSuite;
        part safetySubsystem : SafetySubsystem;
        part cleaningSubsystem : CleaningSubsystem;

        connect userInterface.command to controller.control.command;
        connect controller.control.status to userInterface.status;

        connect ingredientInput.flour to flourReservoir.flourIn;
        connect ingredientInput.water to waterReservoir.waterIn;
        connect ingredientInput.oil to oilReservoir.oilIn;

        connect flourReservoir.flourOut to meteringSubsystem.flourIn;
        connect waterReservoir.waterOut to meteringSubsystem.waterIn;
        connect oilReservoir.oilOut to meteringSubsystem.oilIn;

        connect meteringSubsystem.doughOut to kneadingSubsystem.doughIn;
        connect kneadingSubsystem.doughOut to portioningSubsystem.doughIn;
        connect portioningSubsystem.portionOut to flatteningSubsystem.portionIn;
        connect flatteningSubsystem.flatbreadOut to cookingSubsystem.flatbreadIn;
        connect cookingSubsystem.rotiOut to dispensingSubsystem.rotiIn;
        connect dispensingSubsystem.rotiOut to foodOutput.cookedRoti;
        connect cleaningSubsystem.wasteOut to foodOutput.wasteResidue;

        connect sensorSuite.sensorData to controller.sensorData;
        connect safetySubsystem.safetyStatus to controller.safetyStatus;

        connect powerPort.electricalPower to controller.powerIn;
        connect powerPort.electricalPower to cookingSubsystem.powerIn;
        connect powerPort.electricalPower to kneadingSubsystem.powerIn;
        connect powerPort.electricalPower to flatteningSubsystem.powerIn;
        connect powerPort.electricalPower to portioningSubsystem.powerIn;
    }

    part def EmbeddedController {
        port control : ControlPort;
        port sensorData : SensorDataPort;
        port safetyStatus : SensorDataPort;
        port powerIn : PowerPort;

        attribute selectedRotiCount : count;
        attribute completedRotiCount : count;
        attribute targetHydration : percent;
        attribute targetThickness : millimeter;
        attribute targetCookingTemperature : degreeCelsius;

        action prepareBatch {
            in item command : UserCommand;
            out attribute batchAccepted : Boolean;

            first start;
            then validateCommand;
            then calculateRecipe;
            then reserveIngredients;
            then batchAccepted = true;
        }

        action calculateRecipe {
            in item command : UserCommand;
            out attribute flourPerRoti : gram;
            out attribute waterPerRoti : milliliter;
            out attribute oilPerRoti : milliliter;
            out attribute cookTemperature : degreeCelsius;

            first start;
            then setBaseFlourMass;
            then adjustHydrationForThickness;
            then adjustTemperatureForRoastLevel;
        }

        state def ControllerStateMachine {
            state off;
            state standby;
            state acceptingBatch;
            state producing;
            state pausedForRefill;
            state cleaning;
            state faulted;

            transition initial then off;
            transition off_to_standby first off accept PowerApplied then standby;
            transition standby_to_accepting first standby accept UserCommandReceived then acceptingBatch;
            transition accepting_to_producing first acceptingBatch if safetyStatus.doorClosed and safetyStatus.trayPresent then producing;
            transition producing_to_refill first producing if sensorData.mass < 50 [gram] then pausedForRefill;
            transition refill_to_producing first pausedForRefill if sensorData.mass >= 50 [gram] then producing;
            transition producing_to_standby first producing if completedRotiCount == selectedRotiCount then standby;
            transition standby_to_cleaning first standby accept CleanRequested then cleaning;
            transition cleaning_to_standby first cleaning accept CleaningComplete then standby;
            transition any_to_fault first off accept CriticalFault then faulted;
            transition fault_reset first faulted accept FaultCleared then standby;
        }
    }

    part def FlourReservoir {
        port flourIn : IngredientInputPort;
        port flourOut : IngredientInputPort;

        attribute capacity : gram = 1200 [gram];
        attribute currentMass : gram;
        attribute minimumOperationalMass : gram = 50 [gram];

        requirement flourStorageRequirement {
            doc /* The flour reservoir shall store enough flour for at least 15 regular rotis before refill. */
            require constraint { capacity >= 900 [gram] }
        }
    }

    part def WaterReservoir {
        port waterIn : IngredientInputPort;
        port waterOut : IngredientInputPort;

        attribute capacity : milliliter = 1000 [milliliter];
        attribute currentVolume : milliliter;
        attribute minimumOperationalVolume : milliliter = 40 [milliliter];
    }

    part def OilReservoir {
        port oilIn : IngredientInputPort;
        port oilOut : IngredientInputPort;

        attribute capacity : milliliter = 120 [milliliter];
        attribute currentVolume : milliliter;
    }

    part def IngredientMeteringSubsystem {
        port flourIn : IngredientInputPort;
        port waterIn : IngredientInputPort;
        port oilIn : IngredientInputPort;
        port doughOut : DoughTransferPort;

        attribute flourDoseAccuracy : gram = 2 [gram];
        attribute waterDoseAccuracy : milliliter = 1 [milliliter];
        attribute oilDoseAccuracy : milliliter = 0.5 [milliliter];

        action meterIngredients {
            in attribute targetFlour : gram;
            in attribute targetWater : milliliter;
            in attribute targetOil : milliliter;
            out item roughDough : Dough;

            first start;
            then dispenseFlour;
            then dispenseWater;
            then dispenseOil;
            then combineIngredients;
        }

        requirement meteringAccuracyRequirement {
            doc /* Ingredient metering shall maintain dose error low enough to preserve roti texture. */
            require constraint { flourDoseAccuracy <= 3 [gram] and waterDoseAccuracy <= 2 [milliliter] }
        }
    }

    part def KneadingSubsystem {
        port powerIn : PowerPort;
        port doughIn : DoughTransferPort;
        port doughOut : DoughTransferPort;

        attribute kneadMotorPower : watt = 120 [watt];
        attribute nominalKneadTime : second = 90 [second];
        attribute targetElasticity : percent = 75 [percent];

        action kneadDough {
            in item roughDough : Dough;
            out item kneadedDough : Dough;

            first start;
            then rotatePaddle;
            then senseMotorLoad;
            then adjustKneadDuration;
            then verifyElasticity;
        }

        state def KneaderStateMachine {
            state idle;
            state receivingIngredients;
            state kneading;
            state doughReady;
            state jamDetected;

            transition initial then idle;
            transition idle_to_receiving first idle accept DoughLoaded then receivingIngredients;
            transition receiving_to_kneading first receivingIngredients then kneading;
            transition kneading_to_ready first kneading if targetElasticity >= 70 [percent] then doughReady;
            transition kneading_to_jam first kneading if motorLoad > 90 [percent] then jamDetected;
            transition jam_to_idle first jamDetected accept JamCleared then idle;
        }
    }

    part def PortioningSubsystem {
        port powerIn : PowerPort;
        port doughIn : DoughTransferPort;
        port portionOut : PortionTransferPort;

        attribute nominalPortionMass : gram = 45 [gram];
        attribute portionMassTolerance : gram = 3 [gram];

        action portionDough {
            in item kneadedDough : Dough;
            out item portion : DoughPortion;

            first start;
            then advanceDough;
            then measureMass;
            then cutPortion;
            then shapePortion;
        }

        requirement portionMassRequirement {
            doc /* Each dough portion shall be controlled to produce a consistent roti size. */
            require constraint { portionMassTolerance <= 4 [gram] }
        }
    }

    part def FlatteningSubsystem {
        port powerIn : PowerPort;
        port portionIn : PortionTransferPort;
        port flatbreadOut : FlatbreadTransferPort;

        attribute pressForce : newton = 350 [newton];
        attribute targetDiameter : millimeter = 150 [millimeter];
        attribute targetThicknessThin : millimeter = 1.6 [millimeter];
        attribute targetThicknessRegular : millimeter = 2.2 [millimeter];
        attribute targetThicknessThick : millimeter = 3.0 [millimeter];

        action flattenPortion {
            in item portion : DoughPortion;
            in attribute selectedThickness : millimeter;
            out item flatbread : UncookedFlatbread;

            first start;
            then centerPortion;
            then lowerPress;
            then holdPressure;
            then liftPress;
            then transferFlatbread;
        }

        requirement thicknessRequirement {
            doc /* The flattening subsystem shall form a circular flatbread within regular thickness tolerance. */
            require constraint { targetThicknessRegular >= 2.0 [millimeter] and targetThicknessRegular <= 2.5 [millimeter] }
        }
    }

    part def CookingSubsystem {
        port powerIn : PowerPort;
        port flatbreadIn : FlatbreadTransferPort;
        port rotiOut : RotiTransferPort;

        attribute upperHeaterPower : watt = 850 [watt];
        attribute lowerHeaterPower : watt = 850 [watt];
        attribute targetPlateTemperature : degreeCelsius = 220 [degreeCelsius];
        attribute temperatureTolerance : degreeCelsius = 8 [degreeCelsius];
        attribute nominalCookTime : second = 75 [second];

        part upperPlate : HeatedPlate;
        part lowerPlate : HeatedPlate;
        part turningMechanism : TurningMechanism;

        action cookFlatbread {
            in item flatbread : UncookedFlatbread;
            in attribute roastLevel : RoastLevel;
            out item cookedRoti : CookedRoti;

            first start;
            then preheatPlates;
            then placeFlatbread;
            then cookFirstSide;
            then turnFlatbread;
            then cookSecondSide;
            then puffAssistHeatPulse;
            then verifyBrowning;
            then releaseRoti;
        }

        state def CookingStateMachine {
            state idle;
            state preheating;
            state ready;
            state cookingFirstSide;
            state flipping;
            state cookingSecondSide;
            state releasing;
            state overTemperatureFault;

            transition initial then idle;
            transition idle_to_preheating first idle accept BatchAccepted then preheating;
            transition preheating_to_ready first preheating if targetPlateTemperature >= 212 [degreeCelsius] then ready;
            transition ready_to_first first ready accept FlatbreadLoaded then cookingFirstSide;
            transition first_to_flipping first cookingFirstSide after 32 [second] then flipping;
            transition flipping_to_second first flipping then cookingSecondSide;
            transition second_to_releasing first cookingSecondSide after 35 [second] then releasing;
            transition releasing_to_ready first releasing then ready;
            transition any_to_overtemp first idle if targetPlateTemperature > 250 [degreeCelsius] then overTemperatureFault;
            transition overtemp_to_idle first overTemperatureFault accept TemperatureSafe then idle;
        }

        requirement cookingTemperatureRequirement {
            doc /* Cooking plates shall regulate temperature to cook roti without scorching. */
            require constraint { temperatureTolerance <= 10 [degreeCelsius] }
        }
    }

    part def HeatedPlate {
        attribute diameter : millimeter = 170 [millimeter];
        attribute surfaceTemperature : degreeCelsius;
        attribute heaterPower : watt = 850 [watt];

        action regulateTemperature {
            in attribute target : degreeCelsius;
            out item thermalEnergy : ThermalEnergy;

            first start;
            then readTemperatureSensor;
            then computeHeaterDutyCycle;
            then applyPower;
        }
    }

    part def TurningMechanism {
        attribute turnDuration : second = 2 [second];
        attribute gripForce : newton = 12 [newton];

        action flipFlatbread {
            in item partiallyCookedFlatbread : UncookedFlatbread;
            out item invertedFlatbread : UncookedFlatbread;

            first start;
            then engageEdge;
            then lift;
            then rotate;
            then place;
            then release;
        }
    }

    part def DispensingSubsystem {
        port rotiIn : RotiTransferPort;
        port rotiOut : RotiTransferPort;

        attribute stackCapacity : count = 20 [count];
        attribute dispenseTime : second = 3 [second];

        action dispenseRoti {
            in item cookedRoti : CookedRoti;
            out item dispensedRoti : CookedRoti;

            first start;
            then moveToOutputTray;
            then confirmTrayPresent;
            then releaseToStack;
        }
    }

    part def SensorSuite {
        port sensorData : SensorDataPort;

        part flourMassSensor : MassSensor;
        part waterLevelSensor : VolumeSensor;
        part oilLevelSensor : VolumeSensor;
        part plateTemperatureSensor : TemperatureSensor;
        part motorLoadSensor : LoadSensor;
        part doorInterlockSensor : BooleanSensor;
        part outputTraySensor : BooleanSensor;
    }

    part def MassSensor {
        attribute measuredMass : gram;
        attribute accuracy : gram = 2 [gram];
    }

    part def VolumeSensor {
        attribute measuredVolume : milliliter;
        attribute accuracy : milliliter = 5 [milliliter];
    }

    part def TemperatureSensor {
        attribute measuredTemperature : degreeCelsius;
        attribute accuracy : degreeCelsius = 2 [degreeCelsius];
    }

    part def LoadSensor {
        attribute measuredLoad : percent;
        attribute overloadThreshold : percent = 90 [percent];
    }

    part def BooleanSensor {
        attribute sensed : Boolean;
    }

    part def SafetySubsystem {
        port safetyStatus : SensorDataPort;

        attribute doorClosed : Boolean;
        attribute trayPresent : Boolean;
        attribute overTemperatureLimit : degreeCelsius = 250 [degreeCelsius];
        attribute motorOverloadLimit : percent = 95 [percent];

        action evaluateSafety {
            in attribute doorClosedInput : Boolean;
            in attribute trayPresentInput : Boolean;
            in attribute measuredTemperature : degreeCelsius;
            in attribute measuredMotorLoad : percent;
            out item status : StatusMessage;

            first start;
            then checkDoorInterlock;
            then checkTrayPresence;
            then checkTemperatureLimit;
            then checkMotorLoadLimit;
            then publishSafetyStatus;
        }

        requirement safetyRequirement {
            doc /* The system shall inhibit heater and actuator motion when the access door is open. */
            require constraint { doorClosed == true }
        }
    }

    part def CleaningSubsystem {
        port wasteOut : FoodOutputPort;

        attribute cleaningCycleTime : second = 180 [second];
        attribute removableTrayCapacity : gram = 100 [gram];

        action cleanFoodPath {
            out item residue : WasteResidue;

            first start;
            then coolCookingPlates;
            then scrapeLooseFlour;
            then purgeDoughPath;
            then moveResidueToTray;
            then reportCleaningComplete;
        }
    }

    action def AutomaticRotiProduction {
        in item command : UserCommand;
        in item flour : Flour;
        in item water : Water;
        in item oil : Oil;
        out item cookedRoti : CookedRoti;

        first acceptBatch;
        then meterIngredients;
        then kneadDough;
        then portionDough;
        then flattenPortion;
        then cookFlatbread;
        then dispenseRoti;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall automatically produce cooked rotis from stored flour, water, and optional oil according to user-selected count, roast level, and thickness. */
        subject rotimatic : Rotimatic;
        require constraint { rotimatic.maximumRotiBatch >= 1 [count] }
    }

    requirement def BatchCapacityRequirement {
        doc /* The system shall support a user-selected batch of at least 10 rotis without manual intervention when reservoirs are sufficiently filled. */
        subject rotimatic : Rotimatic;
        require constraint { rotimatic.maximumRotiBatch >= 10 [count] }
    }

    requirement def CookingPerformanceRequirement {
        doc /* Each dispensed roti shall be cooked through, circular, and soft enough for immediate consumption. */
        require constraint {
            CookedRoti::diameter >= 130 [millimeter] and
            CookedRoti::diameter <= 170 [millimeter] and
            CookedRoti::softnessIndex >= 65 [percent]
        }
    }

    requirement def UserFeedbackRequirement {
        doc /* The system shall notify the user of refill, cleaning, completion, and fault states. */
        require constraint { true }
    }

    requirement def PowerRequirement {
        doc /* The system shall operate from household electrical power while limiting peak power consumption. */
        subject rotimatic : Rotimatic;
        require constraint { rotimatic.peakPower <= 1800 [watt] }
    }

    requirement def FoodPathRequirement {
        doc /* Food-contact subsystems shall transfer dough and roti through a controlled path from ingredient reservoirs to output tray. */
        subject rotimatic : Rotimatic;
        require constraint { rotimatic.nominalRotiDiameter == 150 [millimeter] }
    }

    satisfy PrimaryFunctionRequirement by AutomaticRotiProduction;
    satisfy BatchCapacityRequirement by Rotimatic;
    satisfy PowerRequirement by Rotimatic;
    satisfy FoodPathRequirement by Rotimatic;
}