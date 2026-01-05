package OilRefinerySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def CrudeComposition {
        attribute apiGravity : Real;
        attribute sulfurContent : Real;
        attribute viscosity : Real;
    }

    attribute def ProductSpecification {
        attribute octaneNumber : Real;
        attribute cetaneIndex : Real;
        attribute flashPoint : TemperatureValue;
    }

    item def CrudeOil {
        attribute composition : CrudeComposition;
        attribute flowRate : VolumeFlowRateValue;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    item def Naphtha {
        attribute flowRate : VolumeFlowRateValue;
        attribute temperature : TemperatureValue;
    }

    item def Kerosene {
        attribute flowRate : VolumeFlowRateValue;
        attribute temperature : TemperatureValue;
    }

    item def Diesel {
        attribute flowRate : VolumeFlowRateValue;
        attribute specification : ProductSpecification;
    }

    item def Gasoline {
        attribute flowRate : VolumeFlowRateValue;
        attribute specification : ProductSpecification;
    }

    item def AtmosphericResidue {
        attribute flowRate : VolumeFlowRateValue;
        attribute temperature : TemperatureValue;
    }

    item def VacuumGasOil {
        attribute flowRate : VolumeFlowRateValue;
        attribute temperature : TemperatureValue;
    }

    item def VacuumResidue {
        attribute flowRate : VolumeFlowRateValue;
    }

    item def ControlSignal {
        attribute setpoint : Real;
        attribute processVariable : Real;
    }

    port def CrudeIntakePort {
        in item crudeIn : CrudeOil;
    }

    port def ProductPort {
        out item productOut;
    }

    port def IntermediatePort {
        in item feedIn;
        out item productOut;
    }

    port def ControlPort {
        in item controlIn : ControlSignal;
        out item statusOut : ControlSignal;
    }

    part def AtmosphericDistillationColumn {
        port crudeIntake : CrudeIntakePort;
        port naphthaOut : ProductPort;
        port keroseneOut : ProductPort;
        port dieselOut : ProductPort;
        port residueOut : ProductPort;
        port control : ControlPort;

        attribute operatingTemp : TemperatureValue;
        attribute operatingPressure : PressureValue;
        attribute numberOfTrays : Integer;

        perform action distillCrude {
            in crudeInput : CrudeOil;
            out naphthaOutput : Naphtha;
            out keroseneOutput : Kerosene;
            out dieselOutput : Diesel;
            out residueOutput : AtmosphericResidue;

            first start;
            then action preheatCrude {
                in crude : CrudeOil = crudeInput;
                out heatedCrude : CrudeOil;
            }
            then action flashVaporization {
                in heated : CrudeOil = preheatCrude.heatedCrude;
                out vaporPhase : CrudeOil;
                out liquidPhase : CrudeOil;
            }
            then action fractionateLights {
                in vapor : CrudeOil = flashVaporization.vaporPhase;
                out naphtha : Naphtha;
                out kerosene : Kerosene;
                out diesel : Diesel;
            }
            then assign naphthaOutput := fractionateLights.naphtha;
            then assign keroseneOutput := fractionateLights.kerosene;
            then assign dieselOutput := fractionateLights.diesel;
            then assign residueOutput := flashVaporization.liquidPhase;
            then done;
        }
    }

    part def VacuumDistillationColumn {
        port residueIntake : IntermediatePort;
        port gasOilOut : ProductPort;
        port vacuumResidueOut : ProductPort;
        port control : ControlPort;

        attribute vacuumPressure : PressureValue;
        attribute operatingTemp : TemperatureValue;

        perform action distillResidue {
            in residueInput : AtmosphericResidue;
            out gasOilOutput : VacuumGasOil;
            out vacuumResidueOutput : VacuumResidue;

            first start;
            then action heatResidue {
                in residue : AtmosphericResidue = residueInput;
                out heatedResidue : AtmosphericResidue;
            }
            then action vacuumFlash {
                in heated : AtmosphericResidue = heatResidue.heatedResidue;
                out gasOil : VacuumGasOil;
                out bottomResidue : VacuumResidue;
            }
            then assign gasOilOutput := vacuumFlash.gasOil;
            then assign vacuumResidueOutput := vacuumFlash.bottomResidue;
            then done;
        }
    }

    part def FluidCatalyticCrackingUnit {
        port gasOilIntake : IntermediatePort;
        port gasolineOut : ProductPort;
        port lightGasOut : ProductPort;
        port control : ControlPort;

        attribute reactorTemp : TemperatureValue;
        attribute catalystCirculationRate : MassFlowRateValue;
        attribute conversionEfficiency : Real;

        perform action crackGasOil {
            in gasOilInput : VacuumGasOil;
            out gasolineOutput : Gasoline;
            out lightGasOutput : CrudeOil;

            first start;
            then action vaporizeGasOil {
                in gasOil : VacuumGasOil = gasOilInput;
                out vaporizedGasOil : VacuumGasOil;
            }
            then action catalyticReaction {
                in vaporized : VacuumGasOil = vaporizeGasOil.vaporizedGasOil;
                out crackedProducts : CrudeOil;
            }
            then action separateProducts {
                in cracked : CrudeOil = catalyticReaction.crackedProducts;
                out gasoline : Gasoline;
                out lightGas : CrudeOil;
            }
            then assign gasolineOutput := separateProducts.gasoline;
            then assign lightGasOutput := separateProducts.lightGas;
            then done;
        }
    }

    part def Hydrotreater {
        port feedIntake : IntermediatePort;
        port treatedProductOut : ProductPort;
        port control : ControlPort;

        attribute hydrogenPressure : PressureValue;
        attribute reactorTemp : TemperatureValue;
        attribute sulfurRemovalEfficiency : Real;

        perform action treatProduct {
            in untreatedInput : Diesel;
            out treatedOutput : Diesel;

            first start;
            then action addHydrogen {
                in product : Diesel = untreatedInput;
                out hydrogenatedProduct : Diesel;
            }
            then action desulfurize {
                in hydrogenated : Diesel = addHydrogen.hydrogenatedProduct;
                out desulfurizedProduct : Diesel;
            }
            then action stabilize {
                in desulfurized : Diesel = desulfurize.desulfurizedProduct;
                out stabilizedProduct : Diesel;
            }
            then assign treatedOutput := stabilize.stabilizedProduct;
            then done;
        }
    }

    part def StorageTank {
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute productType : String;
        attribute maxFillRate : VolumeFlowRateValue;

        state tankOperation {
            entry; then empty;

            state empty;
            transition emptyToFilling first empty
                if currentLevel < capacity * 0.05
                then filling;

            state filling;
            transition fillingToOperational first filling
                if currentLevel >= capacity * 0.2 and currentLevel < capacity * 0.9
                then operational;

            state operational;
            transition operationalToNearFull first operational
                if currentLevel >= capacity * 0.9
                then nearFull;
            transition operationalToFilling first operational
                if currentLevel < capacity * 0.2
                then filling;

            state nearFull;
            transition nearFullToFull first nearFull
                if currentLevel >= capacity * 0.98
                then full;
            transition nearFullToOperational first nearFull
                if currentLevel < capacity * 0.9
                then operational;

            state full;
            transition fullToOperational first full
                if currentLevel < capacity * 0.95
                then operational;
        }
    }

    part def DistributedControlSystem {
        attribute scanRate : FrequencyValue;
        attribute numberOfControlLoops : Integer;

        perform action controlRefinery {
            in processData : ControlSignal[*];
            out controlCommands : ControlSignal[*];

            first start;
            then merge continuousControl;
            then action acquireData {
                in sensors : ControlSignal[*] = processData;
                out currentState : ControlSignal[*];
            }
            then action computeControl {
                in state : ControlSignal[*] = acquireData.currentState;
                out commands : ControlSignal[*];
            }
            then decide;
                if computeControl.commands->exists(c | c.processVariable > c.setpoint * 1.1) then alarm;
                if computeControl.commands->forAll(c | c.processVariable <= c.setpoint * 1.1) then normalOperation;

            action alarm {
                out emergencyCommands : ControlSignal[*];
            }
            then continuousControl;

            action normalOperation {
                out standardCommands : ControlSignal[*] = computeControl.commands;
            }
            then assign controlCommands := normalOperation.standardCommands;
            then continuousControl;
        }

        state controlSystemState {
            entry; then initialization;

            state initialization;
            transition initToNormal first initialization then normalOperation;

            state normalOperation;
            transition normalToAlarm first normalOperation
                if processData->exists(d | d.processVariable > d.setpoint * 1.15)
                then alarmState;

            state alarmState;
            transition alarmToShutdown first alarmState
                if processData->exists(d | d.processVariable > d.setpoint * 1.3)
                then emergencyShutdown;
            transition alarmToNormal first alarmState
                if processData->forAll(d | d.processVariable <= d.setpoint * 1.1)
                then normalOperation;

            state emergencyShutdown;
            transition shutdownToInit first emergencyShutdown then initialization;
        }
    }

    part def SafetyInterlockSystem {
        attribute tripSetpoints : Real[*];
        attribute emergencyShutdownActive : Boolean;

        state safetyState {
            entry; then monitoring;

            state monitoring;
            transition monitorToPrealarm first monitoring
                if tripSetpoints->exists(s | s > 0.9)
                then prealarm;

            state prealarm;
            transition prealarmToTrip first prealarm
                if tripSetpoints->exists(s | s >= 1.0)
                then trip;
            transition prealarmToMonitor first prealarm
                if tripSetpoints->forAll(s | s < 0.85)
                then monitoring;

            state trip;
            transition tripToReset first trip then reset;

            state reset;
            transition resetToMonitor first reset
                if emergencyShutdownActive == false
                then monitoring;
        }
    }

    part oilRefinery {
        port crudeSupply : CrudeIntakePort;
        port gasolineProduct : ProductPort;
        port dieselProduct : ProductPort;
        port keroseneProduct : ProductPort;

        part atmosphericColumn : AtmosphericDistillationColumn {
            :>> operatingTemp = 350.0 [K];
            :>> operatingPressure = 150.0 [kPa];
            :>> numberOfTrays = 40;
        }

        part vacuumColumn : VacuumDistillationColumn {
            :>> vacuumPressure = 5.0 [kPa];
            :>> operatingTemp = 400.0 [K];
        }

        part fccUnit : FluidCatalyticCrackingUnit {
            :>> reactorTemp = 520.0 [K];
            :>> conversionEfficiency = 0.75;
        }

        part dieselHydrotreater : Hydrotreater {
            :>> hydrogenPressure = 5000.0 [kPa];
            :>> reactorTemp = 350.0 [K];
            :>> sulfurRemovalEfficiency = 0.995;
        }

        part naphthaHydrotreater : Hydrotreater {
            :>> hydrogenPressure = 3000.0 [kPa];
            :>> reactorTemp = 300.0 [K];
            :>> sulfurRemovalEfficiency = 0.99;
        }

        part crudeStorage : StorageTank[3] {
            :>> capacity = 100000.0 [m^3];
            :>> productType = "Crude Oil";
            :>> maxFillRate = 500.0 [m^3/h];
        }

        part gasolineStorage : StorageTank[4] {
            :>> capacity = 50000.0 [m^3];
            :>> productType = "Gasoline";
            :>> maxFillRate = 300.0 [m^3/h];
        }

        part dieselStorage : StorageTank[3] {
            :>> capacity = 40000.0 [m^3];
            :>> productType = "Diesel";
            :>> maxFillRate = 250.0 [m^3/h];
        }

        part keroseneStorage : StorageTank[2] {
            :>> capacity = 30000.0 [m^3];
            :>> productType = "Kerosene";
            :>> maxFillRate = 200.0 [m^3/h];
        }

        part controlSystem : DistributedControlSystem {
            :>> scanRate = 1.0 [Hz];
            :>> numberOfControlLoops = 150;
        }

        part safetySystem : SafetyInterlockSystem {
            :>> emergencyShutdownActive = false;
        }

        connect crudeSupply to atmosphericColumn.crudeIntake;
        connect atmosphericColumn.residueOut to vacuumColumn.residueIntake;
        connect vacuumColumn.gasOilOut to fccUnit.gasOilIntake;
        connect atmosphericColumn.dieselOut to dieselHydrotreater.feedIntake;
        connect atmosphericColumn.naphthaOut to naphthaHydrotreater.feedIntake;
        connect fccUnit.gasolineOut to gasolineStorage.productType;
        connect dieselHydrotreater.treatedProductOut to dieselStorage.productType;
        connect atmosphericColumn.keroseneOut to keroseneStorage.productType;
        connect gasolineStorage.productType to gasolineProduct;
        connect dieselStorage.productType to dieselProduct;
        connect keroseneStorage.productType to keroseneProduct;

        perform action refineOperation {
            first start;
            then merge continuousRefining;

            then action receiveCrude {
                out crude : CrudeOil;
            }

            then action primaryDistillation : atmosphericColumn.distillCrude {
                in crudeInput = receiveCrude.crude;
                out naphthaOutput;
                out keroseneOutput;
                out dieselOutput;
                out residueOutput;
            }

            then action secondaryDistillation : vacuumColumn.distillResidue {
                in residueInput = primaryDistillation.residueOutput;
                out gasOilOutput;
                out vacuumResidueOutput;
            }

            then action catalyticCracking : fccUnit.crackGasOil {
                in gasOilInput = secondaryDistillation.gasOilOutput;
                out gasolineOutput;
                out lightGasOutput;
            }

            then action treatDiesel : dieselHydrotreater.treatProduct {
                in untreatedInput = primaryDistillation.dieselOutput;
                out treatedOutput;
            }

            then action treatNaphtha : naphthaHydrotreater.treatProduct {
                in untreatedInput = primaryDistillation.naphthaOutput;
                out treatedOutput;
            }

            then action storeProducts {
                in gasoline : Gasoline = catalyticCracking.gasolineOutput;
                in diesel : Diesel = treatDiesel.treatedOutput;
                in kerosene : Kerosene = primaryDistillation.keroseneOutput;
            }

            then continuousRefining;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The oil refinery shall convert crude oil into valuable refined petroleum products 
                including gasoline, diesel, and kerosene through distillation, cracking, and treatment processes. */
        subject refinery : oilRefinery;
    }

    requirement def ThroughputRequirement {
        doc /* The refinery shall process a minimum of 200,000 barrels per day of crude oil. */
        subject refinery : oilRefinery;
        require constraint {
            refinery.crudeSupply.crudeIn.flowRate >= 200000.0 * (0.159 [m^3]) / (1.0 [day])
        }
    }

    requirement def ProductQualityRequirement {
        doc /* All refined products shall meet specified quality standards before storage and distribution. */
        subject treater : Hydrotreater;
        require constraint {
            treater.sulfurRemovalEfficiency >= 0.99
        }
    }

    requirement def SafetyRequirement {
        doc /* The refinery shall maintain safe operating conditions and execute emergency shutdown 
                when process variables exceed critical thresholds. */
        subject safety : SafetyInterlockSystem;
        require constraint {
            safety.emergencyShutdownActive or safety.tripSetpoints->forAll(s | s < 1.0)
        }
    }

    requirement def EnvironmentalComplianceRequirement {
        doc /* Sulfur content in diesel fuel shall not exceed 10 ppm to meet environmental regulations. */
        subject hydrotreater : Hydrotreater;
        require constraint {
            hydrotreater.sulfurRemovalEfficiency >= 0.995
        }
    }

    requirement def StorageCapacityRequirement {
        doc /* The refinery shall maintain sufficient storage capacity for 7 days of production at nominal throughput. */
        subject refinery : oilRefinery;
        require constraint {
            refinery.gasolineStorage.capacity >= 7.0 * 50000.0 [m^3] and
            refinery.dieselStorage.capacity >= 7.0 * 30000.0 [m^3]
        }
    }

    requirement refineryOperationalRequirements {
        doc /* Top-level requirements governing oil refinery operations, safety, quality, and environmental compliance. */

        require PrimaryFunctionRequirement;
        require ThroughputRequirement;
        require ProductQualityRequirement;
        require SafetyRequirement;
        require EnvironmentalComplianceRequirement;
        require StorageCapacityRequirement;
    }
}
