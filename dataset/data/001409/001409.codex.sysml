package EcosystemSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percent {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def Area {
        :> ISQ::area;
        unit = "ha";
    }

    attribute def MassFlowRate {
        :> ISQ::massFlowRate;
        unit = "kg/h";
    }

    attribute def EnergyFlowRate {
        :> ISQ::power;
        unit = "kW";
    }

    attribute def PopulationCount {
        :> ScalarValues::Integer;
    }

    attribute def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = "degC";
    }

    attribute def WaterVolume {
        :> ISQ::volume;
        unit = "m^3";
    }

    item def SolarEnergy {
        attribute irradiance : EnergyFlowRate;
    }

    item def Water {
        attribute volume : WaterVolume;
        attribute dissolvedOxygen : Percent;
        attribute temperature : Temperature;
    }

    item def Nutrients {
        attribute nitrogenMassFlow : MassFlowRate;
        attribute phosphorusMassFlow : MassFlowRate;
    }

    item def Biomass {
        attribute dryMassFlow : MassFlowRate;
        attribute carbonFraction : Percent;
    }

    item def Detritus {
        attribute organicMassFlow : MassFlowRate;
    }

    item def Oxygen {
        attribute oxygenMassFlow : MassFlowRate;
    }

    item def CarbonDioxide {
        attribute carbonMassFlow : MassFlowRate;
    }

    item def SpeciesPopulation {
        attribute individuals : PopulationCount;
        attribute healthIndex : Percent;
    }

    port def EnergyInputPort {
        in item energy : SolarEnergy;
    }

    port def MatterInputPort {
        in item water : Water;
        in item nutrients : Nutrients;
        in item carbonDioxide : CarbonDioxide;
    }

    port def MatterOutputPort {
        out item oxygen : Oxygen;
        out item biomass : Biomass;
        out item detritus : Detritus;
    }

    port def TrophicExchangePort {
        inout item biomass : Biomass;
        inout item nutrients : Nutrients;
        inout item detritus : Detritus;
    }

    port def HabitatConditionPort {
        inout item water : Water;
        inout item oxygen : Oxygen;
    }

    part def SunlightSource {
        attribute dailyEnergySupply : EnergyFlowRate = 850 [kW];

        port energyOut : EnergyInputPort {
            out item energy : SolarEnergy;
        }
    }

    part def Atmosphere {
        attribute ambientTemperature : Temperature = 21 [degC];
        attribute carbonDioxideAvailability : Percent = 100 [%];

        port gasExchange : MatterInputPort {
            out item carbonDioxide : CarbonDioxide;
        }

        port oxygenReceive : MatterOutputPort {
            in item oxygen : Oxygen;
        }
    }

    part def WaterCycle {
        attribute storedWater : WaterVolume = 120000 [m^3];
        attribute rechargeRate : MassFlowRate = 4200 [kg/h];

        port hydrology : HabitatConditionPort;
        port matterSupply : MatterInputPort {
            out item water : Water;
        }
    }

    part def SoilSubsystem {
        attribute fertileArea : Area = 300 [ha];
        attribute soilMoisture : Percent = 61 [%];
        attribute nutrientAvailability : Percent = 76 [%];

        port rootZone : TrophicExchangePort;
        port matterSupply : MatterInputPort {
            out item nutrients : Nutrients;
        }
    }

    part def PrimaryProducers {
        attribute producerPopulation : PopulationCount = 2500000;
        attribute canopyCoverage : Percent = 84 [%];
        attribute photosyntheticEfficiency : Percent = 18 [%];

        port energyIn : EnergyInputPort;
        port matterIn : MatterInputPort;
        port trophicOut : TrophicExchangePort;
        port oxygenOut : MatterOutputPort;

        action photosynthesize {
            in item solarEnergy : SolarEnergy;
            in item water : Water;
            in item nutrients : Nutrients;
            in item carbonDioxide : CarbonDioxide;
            out item plantBiomass : Biomass;
            out item oxygen : Oxygen;
        }

        state producerOperatingState {
            state Dormant;
            state Growth;
            state Stress;
            state Regeneration;

            initial then Dormant;

            transition Dormant_to_Growth
                first Dormant
                then Growth
                accept when matterIn.water.volume > 50000 [m^3] and energyIn.energy.irradiance > 250 [kW];

            transition Growth_to_Stress
                first Growth
                then Stress
                accept when matterIn.water.temperature > 35 [degC] or matterIn.nutrients.nitrogenMassFlow < 60 [kg/h];

            transition Stress_to_Regeneration
                first Stress
                then Regeneration
                accept when matterIn.water.temperature <= 30 [degC] and matterIn.nutrients.nitrogenMassFlow >= 100 [kg/h];

            transition Regeneration_to_Growth
                first Regeneration
                then Growth
                accept after 14 [d];
        }
    }

    part def HerbivoreCommunity {
        attribute herbivorePopulation : PopulationCount = 18000;
        attribute grazingPressure : Percent = 42 [%];

        port forageExchange : TrophicExchangePort;
        port habitatConditions : HabitatConditionPort;

        action consumePlantBiomass {
            in item plantBiomass : Biomass;
            out item animalBiomass : Biomass;
            out item detritus : Detritus;
        }

        state herbivoreState {
            state Foraging;
            state Reproducing;
            state Migrating;
            state Declining;

            initial then Foraging;

            transition Foraging_to_Reproducing
                first Foraging
                then Reproducing
                accept when forageExchange.biomass.dryMassFlow > 600 [kg/h] and habitatConditions.water.dissolvedOxygen > 65 [%];

            transition Reproducing_to_Foraging
                first Reproducing
                then Foraging
                accept after 30 [d];

            transition Foraging_to_Migrating
                first Foraging
                then Migrating
                accept when forageExchange.biomass.dryMassFlow < 220 [kg/h];

            transition Migrating_to_Declining
                first Migrating
                then Declining
                accept after 21 [d];
        }
    }

    part def PredatorCommunity {
        attribute predatorPopulation : PopulationCount = 850;
        attribute predationBalanceIndex : Percent = 70 [%];

        port preyExchange : TrophicExchangePort;
        port habitatConditions : HabitatConditionPort;

        action regulateHerbivorePopulation {
            in item herbivoreBiomass : Biomass;
            out item predatorBiomass : Biomass;
            out item detritus : Detritus;
        }

        state predatorState {
            state Hunting;
            state Stabilizing;
            state ScarcityResponse;

            initial then Hunting;

            transition Hunting_to_Stabilizing
                first Hunting
                then Stabilizing
                accept when preyExchange.biomass.dryMassFlow >= 160 [kg/h];

            transition Stabilizing_to_ScarcityResponse
                first Stabilizing
                then ScarcityResponse
                accept when preyExchange.biomass.dryMassFlow < 80 [kg/h];

            transition ScarcityResponse_to_Hunting
                first ScarcityResponse
                then Hunting
                accept when preyExchange.biomass.dryMassFlow >= 140 [kg/h];
        }
    }

    part def DecomposerCommunity {
        attribute decomposerActivity : Percent = 81 [%];
        attribute decompositionRate : MassFlowRate = 340 [kg/h];

        port detritusIn : TrophicExchangePort;
        port nutrientsOut : TrophicExchangePort;

        action recycleOrganicMatter {
            in item detritus : Detritus;
            out item nutrients : Nutrients;
            out item carbonDioxide : CarbonDioxide;
        }

        state decomposerState {
            state Active;
            state LimitedByMoisture;
            state LimitedByTemperature;

            initial then Active;

            transition Active_to_LimitedByMoisture
                first Active
                then LimitedByMoisture
                accept when decomposerActivity < 45 [%];

            transition LimitedByMoisture_to_Active
                first LimitedByMoisture
                then Active
                accept when decomposerActivity >= 65 [%];

            transition Active_to_LimitedByTemperature
                first Active
                then LimitedByTemperature
                accept when decompositionRate < 120 [kg/h];

            transition LimitedByTemperature_to_Active
                first LimitedByTemperature
                then Active
                accept when decompositionRate >= 250 [kg/h];
        }
    }

    part def EcosystemBoundary {
        attribute protectedArea : Area = 350 [ha];
        attribute biodiversityIndex : Percent = 78 [%];
        attribute resilienceIndex : Percent = 72 [%];

        port sunlight : EnergyInputPort;
        port atmosphericExchange : MatterInputPort;
        port oxygenRelease : MatterOutputPort;
        port hydrologicExchange : HabitatConditionPort;
        port nutrientExchange : TrophicExchangePort;
    }

    part def Ecosystem {
        attribute totalArea : Area = 350 [ha];
        attribute netPrimaryProductivity : MassFlowRate = 780 [kg/h];
        attribute carryingCapacityIndex : Percent = 74 [%];

        part boundary : EcosystemBoundary;
        part sunlightSource : SunlightSource;
        part atmosphere : Atmosphere;
        part waterCycle : WaterCycle;
        part soil : SoilSubsystem;
        part producers : PrimaryProducers;
        part herbivores : HerbivoreCommunity;
        part predators : PredatorCommunity;
        part decomposers : DecomposerCommunity;

        port externalEnergyIn : EnergyInputPort;
        port externalMatterIn : MatterInputPort;
        port externalMatterOut : MatterOutputPort;

        connect sunlightSource.energyOut to producers.energyIn;
        connect atmosphere.gasExchange to producers.matterIn;
        connect waterCycle.matterSupply to producers.matterIn;
        connect soil.matterSupply to producers.matterIn;
        connect producers.trophicOut to herbivores.forageExchange;
        connect herbivores.forageExchange to predators.preyExchange;
        connect producers.oxygenOut to atmosphere.oxygenReceive;
        connect herbivores.forageExchange to decomposers.detritusIn;
        connect predators.preyExchange to decomposers.detritusIn;
        connect decomposers.nutrientsOut to soil.rootZone;
        connect waterCycle.hydrology to herbivores.habitatConditions;
        connect waterCycle.hydrology to predators.habitatConditions;
        connect externalEnergyIn to boundary.sunlight;
        connect externalMatterIn to boundary.atmosphericExchange;
        connect boundary.oxygenRelease to externalMatterOut;

        action maintainEcosystemFunction {
            in item solarEnergy : SolarEnergy;
            in item water : Water;
            in item nutrients : Nutrients;
            in item carbonDioxide : CarbonDioxide;
            out item oxygen : Oxygen;
            out item biomass : Biomass;
            out item recycledDetritus : Detritus;

            first producers.photosynthesize;
            then herbivores.consumePlantBiomass;
            then predators.regulateHerbivorePopulation;
            then decomposers.recycleOrganicMatter;
        }

        state ecosystemOperatingMode {
            state Balanced;
            state ProductiveGrowth;
            state ResourceStress;
            state Recovery;
            state Degraded;

            initial then Balanced;

            transition Balanced_to_ProductiveGrowth
                first Balanced
                then ProductiveGrowth
                accept when netPrimaryProductivity > 900 [kg/h] and boundary.biodiversityIndex > 80 [%];

            transition ProductiveGrowth_to_Balanced
                first ProductiveGrowth
                then Balanced
                accept when netPrimaryProductivity <= 850 [kg/h];

            transition Balanced_to_ResourceStress
                first Balanced
                then ResourceStress
                accept when waterCycle.storedWater < 60000 [m^3] or soil.nutrientAvailability < 45 [%];

            transition ResourceStress_to_Recovery
                first ResourceStress
                then Recovery
                accept when waterCycle.storedWater >= 90000 [m^3] and soil.nutrientAvailability >= 60 [%];

            transition Recovery_to_Balanced
                first Recovery
                then Balanced
                accept when boundary.resilienceIndex >= 70 [%];

            transition ResourceStress_to_Degraded
                first ResourceStress
                then Degraded
                accept after 120 [d];

            transition Degraded_to_Recovery
                first Degraded
                then Recovery
                accept when boundary.biodiversityIndex >= 55 [%] and decomposers.decompositionRate >= 220 [kg/h];
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject ecosystem : Ecosystem;

        doc /* The ecosystem shall transform solar energy, water, carbon dioxide, and mineral nutrients into living biomass while maintaining trophic balance, recycling organic matter, supporting biodiversity, and releasing oxygen as a beneficial output. */

        require constraint {
            ecosystem.netPrimaryProductivity >= 500 [kg/h] and
            ecosystem.boundary.biodiversityIndex >= 60 [%] and
            ecosystem.boundary.resilienceIndex >= 55 [%]
        }
    }

    requirement def NutrientRecyclingRequirement {
        subject decomposers : DecomposerCommunity;
        subject soil : SoilSubsystem;

        doc /* Decomposer activity shall return nutrients to the soil subsystem at a rate sufficient to sustain primary producer growth. */

        require constraint {
            decomposers.decompositionRate >= 200 [kg/h] and
            soil.nutrientAvailability >= 50 [%]
        }
    }

    requirement def HydrologicSupportRequirement {
        subject waterCycle : WaterCycle;

        doc /* The water cycle shall maintain enough stored water and habitat quality to support producer, herbivore, predator, and decomposer communities. */

        require constraint {
            waterCycle.storedWater >= 75000 [m^3] and
            waterCycle.rechargeRate >= 2500 [kg/h]
        }
    }

    requirement def BiodiversityBalanceRequirement {
        subject ecosystem : Ecosystem;

        doc /* The ecosystem shall maintain producer, herbivore, predator, and decomposer populations within ranges that support stable energy transfer and prevent trophic collapse. */

        require constraint {
            ecosystem.producers.producerPopulation >= 1000000 and
            ecosystem.herbivores.herbivorePopulation >= 5000 and
            ecosystem.predators.predatorPopulation >= 250 and
            ecosystem.decomposers.decomposerActivity >= 50 [%]
        }
    }

    satisfy PrimaryFunctionRequirement by Ecosystem;
    satisfy NutrientRecyclingRequirement by DecomposerCommunity;
    satisfy HydrologicSupportRequirement by WaterCycle;
    satisfy BiodiversityBalanceRequirement by Ecosystem;

}