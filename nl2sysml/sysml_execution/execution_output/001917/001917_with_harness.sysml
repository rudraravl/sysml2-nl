package 'ISRU Propellant Production System' {
    attribute def reset;

    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def ExtractionEfficiency :> Real;
    attribute def ConversionEfficiency :> Real;
    attribute def StorageLevel :> Real;

    item def LunarRegolith {
        attribute mass : MassValue;
        attribute waterIceContent : Real;
        attribute mineralComposition : String;
    }

    item def ExtractedWater {
        attribute mass : MassValue;
        attribute purity : Real;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def GaseousOxygen {
        attribute mass : MassValue;
        attribute purity : Real;
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def GaseousHydrogen {
        attribute mass : MassValue;
        attribute purity : Real;
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def LiquidOxygen {
        attribute mass : MassValue;
        attribute volume : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def LiquidHydrogen {
        attribute mass : MassValue;
        attribute volume : VolumeValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }

    item def ElectricalPower {
        attribute voltage : ElectricPotentialDifferenceValue;
        attribute current : ElectricCurrentValue;
        attribute power : PowerValue;
    }

    port def RegolithInputPort {
        in item regolith : LunarRegolith;
    }

    port def RegolithOutputPort {
        out item regolith : LunarRegolith;
    }

    port def WaterOutputPort {
        out item water : ExtractedWater;
    }

    port def WaterInputPort {
        in item water : ExtractedWater;
    }

    port def OxygenGasOutputPort {
        out item oxygen : GaseousOxygen;
    }

    port def HydrogenGasOutputPort {
        out item hydrogen : GaseousHydrogen;
    }

    port def OxygenGasInputPort {
        in item oxygen : GaseousOxygen;
    }

    port def HydrogenGasInputPort {
        in item hydrogen : GaseousHydrogen;
    }

    port def LiquidOxygenOutputPort {
        out item liquidOxygen : LiquidOxygen;
    }

    port def LiquidHydrogenOutputPort {
        out item liquidHydrogen : LiquidHydrogen;
    }

    port def LiquidOxygenInputPort {
        in item liquidOxygen : LiquidOxygen;
    }

    port def LiquidHydrogenInputPort {
        in item liquidHydrogen : LiquidHydrogen;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def PowerOutputPort {
        out item power : ElectricalPower;
    }

    part def ExcavationRobot {
        port regolithOutput : RegolithOutputPort;
        port powerInput : PowerInputPort;
        attribute excavationRate : MassFlowValue;
        attribute operatingDepth : LengthValue;
        attribute bucketCapacity : VolumeValue;
    }

    part def ThermalExtractor {
        port regolithInput : RegolithInputPort;
        port waterOutput : WaterOutputPort;
        port powerInput : PowerInputPort;
        attribute heatingTemperature : ThermodynamicTemperatureValue;
        attribute extractionEfficiency : ExtractionEfficiency;
        attribute processingRate : MassFlowValue;
    }

    part def WaterElectrolyzer {
        port waterInput : WaterInputPort;
        port oxygenOutput : OxygenGasOutputPort;
        port hydrogenOutput : HydrogenGasOutputPort;
        port powerInput : PowerInputPort;
        attribute operatingVoltage : ElectricPotentialDifferenceValue;
        attribute operatingCurrent : ElectricCurrentValue;
        attribute conversionEfficiency : ConversionEfficiency;
    }

    part def OxygenLiquefier {
        port gasInput : OxygenGasInputPort;
        port liquidOutput : LiquidOxygenOutputPort;
        port powerInput : PowerInputPort;
        attribute coolingTemperature : ThermodynamicTemperatureValue;
        attribute liquefactionRate : MassFlowValue;
    }

    part def HydrogenLiquefier {
        port gasInput : HydrogenGasInputPort;
        port liquidOutput : LiquidHydrogenOutputPort;
        port powerInput : PowerInputPort;
        attribute coolingTemperature : ThermodynamicTemperatureValue;
        attribute liquefactionRate : MassFlowValue;
    }

    part def OxygenStorageTank {
        port liquidInput : LiquidOxygenInputPort;
        attribute capacity : VolumeValue;
        attribute currentLevel : StorageLevel;
        attribute storagePressure : PressureValue;
        attribute storageTemperature : ThermodynamicTemperatureValue;
    }

    part def HydrogenStorageTank {
        port liquidInput : LiquidHydrogenInputPort;
        attribute capacity : VolumeValue;
        attribute currentLevel : StorageLevel;
        attribute storagePressure : PressureValue;
        attribute storageTemperature : ThermodynamicTemperatureValue;
    }

    part def SolarPowerArray {
        port powerOutput : PowerOutputPort;
        attribute panelArea : AreaValue;
        attribute conversionEfficiency : Real;
        attribute outputPower : PowerValue;
    }

    part def PowerDistributionUnit {
        port solarInput : PowerInputPort;
        port excavatorOutput : PowerOutputPort;
        port extractorOutput : PowerOutputPort;
        port electrolyzerOutput : PowerOutputPort;
        port liquefierOutput : PowerOutputPort;
        attribute totalPowerAvailable : PowerValue;
        attribute powerAllocation : Real[4];
    }

    action def ExcavateRegolith {
        in targetMass : MassValue;
        in excavationDepth : LengthValue;
        out collectedRegolith : LunarRegolith;
    }

    action def ExtractWater {
        in regolith : LunarRegolith;
        in heatingTemp : ThermodynamicTemperatureValue;
        out extractedWater : ExtractedWater;
        out wasteRegolith : LunarRegolith;
    }

    action def ElectrolyzeWater {
        in water : ExtractedWater;
        in voltage : ElectricPotentialDifferenceValue;
        in current : ElectricCurrentValue;
        out oxygen : GaseousOxygen;
        out hydrogen : GaseousHydrogen;
    }

    action def LiquefyOxygenGas {
        in gas : GaseousOxygen;
        in coolingTemp : ThermodynamicTemperatureValue;
        out liquidProduct : LiquidOxygen;
    }

    action def LiquefyHydrogenGas {
        in gas : GaseousHydrogen;
        in coolingTemp : ThermodynamicTemperatureValue;
        out liquidProduct : LiquidHydrogen;
    }

    action def StoreOxygenProduct {
        in liquid : LiquidOxygen;
        out storedMass : MassValue;
        out currentCapacity : Real;
    }

    action def StoreHydrogenProduct {
        in liquid : LiquidHydrogen;
        out storedMass : MassValue;
        out currentCapacity : Real;
    }

    action def MonitorSystem {
        out excavationStatus : String;
        out extractionStatus : String;
        out electrolysisStatus : String;
        out storageStatus : String;
        out powerStatus : String;
    }

    action def ISRUProductionCycle {
        first start;
        then merge continuousProduction;

        action excavate : ExcavateRegolith {
            in targetMass = 1000.0 [kg];
            in excavationDepth = 2.0 [m];
            out collectedRegolith;
        }

        then action extract : ExtractWater {
            in regolith = excavate.collectedRegolith;
            in heatingTemp = 373.15 [K];
            out extractedWater;
            out wasteRegolith;
        }

        then action electrolyze : ElectrolyzeWater {
            in water = extract.extractedWater;
            in voltage = 2.0 [V];
            in current = 100.0 [A];
            out oxygen;
            out hydrogen;
        }

        then {
            action liquefyOxygen : LiquefyOxygenGas {
                in gas = electrolyze.oxygen;
                in coolingTemp = 90.2 [K];
                out liquidProduct;
            }
            action liquefyHydrogen : LiquefyHydrogenGas {
                in gas = electrolyze.hydrogen;
                in coolingTemp = 20.3 [K];
                out liquidProduct;
            }
        }

        then {
            action storeOxygen : StoreOxygenProduct {
                in liquid = liquefyOxygen.liquidProduct;
                out storedMass;
                out currentCapacity;
            }
            action storeHydrogen : StoreHydrogenProduct {
                in liquid = liquefyHydrogen.liquidProduct;
                out storedMass;
                out currentCapacity;
            }
        }

        then action monitor : MonitorSystem {
            out excavationStatus;
            out extractionStatus;
            out electrolysisStatus;
            out storageStatus;
            out powerStatus;
        }

        then decide;
            if monitor.storageStatus == "Full" then shutdown;
            else continuousProduction;

        action shutdown;
        then done;
    }

    state def ISRUSystemStates {
        entry; then standby;

        state standby {
            entry assign systemMode = "Standby";
        }

        transition standby_to_initialization
            first standby
            accept powerOn : ElectricalPower
            if powerOn.power >= 50.0 [kW]
            then initialization;

        state initialization {
            entry assign systemMode = "Initializing";
            do action systemCheck;
        }

        transition initialization_to_excavation
            first initialization
            if systemsOperational == true
            then excavation;

        state excavation {
            entry assign systemMode = "Excavating";
            do action excavateRegolith : ExcavateRegolith;
        }

        transition excavation_to_extraction
            first excavation
            if regolithCollected == true
            then extraction;

        state extraction {
            entry assign systemMode = "Extracting Water";
            do action extractWater : ExtractWater;
        }

        transition extraction_to_electrolysis
            first extraction
            if waterExtracted == true
            then electrolysis;

        state electrolysis {
            entry assign systemMode = "Electrolyzing Water";
            do action electrolyzeWater : ElectrolyzeWater;
        }

        transition electrolysis_to_liquefaction
            first electrolysis
            if gasesProduced == true
            then liquefaction;

        state liquefaction {
            entry assign systemMode = "Liquefying Gases";
            do action liquefyGases;
        }

        transition liquefaction_to_storage
            first liquefaction
            if liquidsReady == true
            then storage;

        state storage {
            entry assign systemMode = "Storing Products";
            do action storeProducts;
        }

        transition storage_to_excavation
            first storage
            if storageFull == false
            then excavation;

        transition storage_to_complete
            first storage
            if storageFull == true
            then complete;

        state complete {
            entry assign systemMode = "Production Complete";
        }

        transition complete_to_standby
            first complete
            accept reset
            then standby;

        transition emergency_shutdown
            first excavation, extraction, electrolysis, liquefaction, storage
            accept emergencyStop
            then standby;

        attribute systemMode : String;
        attribute systemsOperational : Boolean;
        attribute regolithCollected : Boolean;
        attribute waterExtracted : Boolean;
        attribute gasesProduced : Boolean;
        attribute liquidsReady : Boolean;
        attribute storageFull : Boolean;
    }

    part def ISRUPlant {
        part excavator : ExcavationRobot {
            perform productionCycle.excavate;
        }

        part extractor : ThermalExtractor {
            perform productionCycle.extract;
        }

        part electrolyzer : WaterElectrolyzer {
            perform productionCycle.electrolyze;
        }

        part oxygenLiquefier : OxygenLiquefier {
            perform productionCycle.liquefyOxygen;
        }

        part hydrogenLiquefier : HydrogenLiquefier {
            perform productionCycle.liquefyHydrogen;
        }

        part oxygenTank : OxygenStorageTank {
            perform productionCycle.storeOxygen;
        }

        part hydrogenTank : HydrogenStorageTank {
            perform productionCycle.storeHydrogen;
        }

        part solarArray : SolarPowerArray;

        part powerDistribution : PowerDistributionUnit;

        perform action productionCycle : ISRUProductionCycle;

        exhibit state systemBehavior : ISRUSystemStates;

        connection excavatorToExtractor
            connect excavator.regolithOutput to extractor.regolithInput;

        connection extractorToElectrolyzer
            connect extractor.waterOutput to electrolyzer.waterInput;

        connection electrolyzerToOxygenLiquefier
            connect electrolyzer.oxygenOutput to oxygenLiquefier.gasInput;

        connection electrolyzerToHydrogenLiquefier
            connect electrolyzer.hydrogenOutput to hydrogenLiquefier.gasInput;

        connection oxygenLiquefierToTank
            connect oxygenLiquefier.liquidOutput to oxygenTank.liquidInput;

        connection hydrogenLiquefierToTank
            connect hydrogenLiquefier.liquidOutput to hydrogenTank.liquidInput;

        connection solarToPowerDistribution
            connect solarArray.powerOutput to powerDistribution.solarInput;

        connection powerToExcavator
            connect powerDistribution.excavatorOutput to excavator.powerInput;

        connection powerToExtractor
            connect powerDistribution.extractorOutput to extractor.powerInput;

        connection powerToElectrolyzer
            connect powerDistribution.electrolyzerOutput to electrolyzer.powerInput;

        connection powerToLiquefiers
            connect powerDistribution.liquefierOutput to oxygenLiquefier.powerInput;
    }

    requirement def PropellantProductionRequirement {
        doc /* The ISRU plant shall produce liquid oxygen and liquid hydrogen propellants 
               from lunar regolith at a combined rate sufficient to support mission operations. */

        subject plant : ISRUPlant;

        require constraint {
            plant.oxygenTank.currentLevel >= 0.8 and
            plant.hydrogenTank.currentLevel >= 0.8
        }
    }

    requirement def ExtractionEfficiencyRequirement {
        doc /* The water extraction process shall achieve a minimum efficiency 
               of 85% from regolith containing at least 5% water ice. */

        subject extractor : ThermalExtractor;

        require constraint {
            extractor.extractionEfficiency >= 0.85
        }
    }

    requirement def PowerAvailabilityRequirement {
        doc /* The solar power array shall provide sufficient power to operate 
               all ISRU subsystems simultaneously during lunar daylight periods. */

        subject powerSystem : SolarPowerArray;

        require constraint {
            powerSystem.outputPower >= 100.0 [kW]
        }
    }

    requirement def StorageCapacityRequirement {
        doc /* The cryogenic storage tanks shall maintain propellants at required 
               temperatures and pressures for a minimum of 30 days. */

        subject oxygenTank : OxygenStorageTank;
        subject hydrogenTank : HydrogenStorageTank;

        require constraint {
            oxygenTank.storageTemperature <= 95.0 [K] and
            hydrogenTank.storageTemperature <= 25.0 [K]
        }
    }

    part lunarISRUFacility : ISRUPlant {
        satisfy PropellantProductionRequirement;
        satisfy ExtractionEfficiencyRequirement;
        satisfy PowerAvailabilityRequirement;
        satisfy StorageCapacityRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import 'ISRU Propellant Production System'::*;

    part testSubject : ISRUPlant {
        exhibit state systemBehavior : ISRUSystemStates;
    }

    action orchestrator {
        attribute testTargetMass : MassValue;
        attribute testExcavationDepth : LengthValue;
        action excavateProbe : ExcavateRegolith {
            in targetMass = testTargetMass;
            in excavationDepth = testExcavationDepth;
        }
        first excavateProbe;
    }
}
