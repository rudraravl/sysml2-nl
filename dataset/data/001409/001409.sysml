package 'Ecosystem System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NutrientConcentration :> Real;
    attribute def PopulationDensity :> Real;
    attribute def BiomassAmount :> MassValue;
    attribute def EnergyRate :> PowerValue;
    attribute def WaterVolume :> VolumeValue;
    
    attribute def SoilProperties {
        attribute nitrogenContent : NutrientConcentration;
        attribute phosphorusContent : NutrientConcentration;
        attribute organicContent : Real;
        attribute moistureLevel : Real;
    }
    
    attribute def EnvironmentalConditions {
        attribute ambientTemperature : TemperatureValue;
        attribute rainfall : Real;
        attribute solarIntensity : EnergyRate;
        attribute relativeHumidity : Real;
    }
    
    item def WaterResource {
        attribute volume : WaterVolume;
        attribute purity : Real;
    }
    
    item def NutrientMatter {
        attribute nitrogenMass : MassValue;
        attribute phosphorusMass : MassValue;
        attribute potassiumMass : MassValue;
    }
    
    item def DeadOrganicMatter {
        attribute carbonMass : MassValue;
        attribute decayRate : Real;
    }
    
    port def EnergyFlowPort {
        in energyInput : EnergyRate;
        out energyOutput : EnergyRate;
    }
    
    port def NutrientFlowPort {
        in nutrientInput : NutrientMatter;
        out nutrientOutput : NutrientMatter;
    }
    
    port def WaterFlowPort {
        in waterInput : WaterResource;
        out waterOutput : WaterResource;
    }
    
    port def BiomassFlowPort {
        out biomassProduced : BiomassAmount;
        in biomassConsumed : BiomassAmount;
    }
    
    part def ProducerOrganism {
        attribute populationSize : PopulationDensity;
        attribute biomass : BiomassAmount;
        attribute productivityRate : Real;
        
        port energyIn : EnergyFlowPort;
        port nutrientIn : NutrientFlowPort;
        port waterIn : WaterFlowPort;
        port biomassOut : BiomassFlowPort;
    }
    
    part def ConsumerOrganism {
        attribute populationSize : PopulationDensity;
        attribute biomass : BiomassAmount;
        attribute consumptionRate : Real;
        
        port foodIn : BiomassFlowPort;
        port energyOut : EnergyFlowPort;
        port wasteOut : NutrientFlowPort;
    }
    
    part def DecomposerOrganism {
        attribute populationSize : PopulationDensity;
        attribute processingCapacity : Real;
        
        port organicIn : NutrientFlowPort;
        port nutrientOut : NutrientFlowPort;
        port energyOut : EnergyFlowPort;
    }
    
    part def SoilSubsystem {
        attribute properties : SoilProperties;
        attribute waterCapacity : Real;
        
        port nutrientStore : NutrientFlowPort;
        port waterStore : WaterFlowPort;
    }
    
    part def AtmosphereSubsystem {
        attribute oxygenConcentration : Real;
        attribute carbonDioxideConcentration : Real;
        
        port gasExchange : EnergyFlowPort;
    }
    
    action def PerformPhotosynthesis {
        in solarEnergy : EnergyRate;
        in waterInput : WaterResource;
        in nutrients : NutrientMatter;
        out oxygenProduced : VolumeValue;
        out biomassGrowth : BiomassAmount;
    }
    
    action def ConsumeFood {
        in foodBiomass : BiomassAmount;
        out consumerGrowth : BiomassAmount;
        out wasteProduced : DeadOrganicMatter;
        out energyReleased : EnergyRate;
    }
    
    action def DecomposeOrganic {
        in deadMatter : DeadOrganicMatter;
        in decompositionRate : Real;
        out recycledNutrients : NutrientMatter;
    }
    
    action def CycleWater {
        in precipitation : Real;
        in evaporation : Real;
        in soilMoisture : Real;
        out availableWater : WaterResource;
    }
    
    action def RegulatePopulations {
        in currentPopulation : PopulationDensity;
        in birthRate : Real;
        in mortalityRate : Real;
        in resourceAvailability : Real;
        out newPopulation : PopulationDensity;
    }
    
    action def MaintainEcosystemBalance {
        first start;
        then merge cycleBegin;
        
        action captureEnergy : PerformPhotosynthesis {
            in solarEnergy = 800.0[W/m^2];
            in waterInput : WaterResource;
            in nutrients : NutrientMatter;
            out oxygenProduced;
            out biomassGrowth;
        }
        
        then action transferEnergyPrimary : ConsumeFood {
            in foodBiomass = captureEnergy.biomassGrowth;
            out consumerGrowth;
            out wasteProduced;
            out energyReleased;
        }
        
        then action transferEnergySecondary : ConsumeFood {
            in foodBiomass = transferEnergyPrimary.consumerGrowth;
            out consumerGrowth;
            out wasteProduced;
            out energyReleased;
        }
        
        then action recycleNutrients : DecomposeOrganic {
            in deadMatter = transferEnergySecondary.wasteProduced;
            in decompositionRate = 0.75;
            out recycledNutrients;
        }
        
        then action manageWater : CycleWater {
            in precipitation = 100.0;
            in evaporation = 60.0;
            in soilMoisture = 0.65;
            out availableWater;
        }
        
        then action controlProducerPopulation : RegulatePopulations {
            in currentPopulation = 45000.0;
            in birthRate = 0.06;
            in mortalityRate = 0.04;
            in resourceAvailability = 0.85;
            out newPopulation;
        }
        
        then action controlConsumerPopulation : RegulatePopulations {
            in currentPopulation = 4500.0;
            in birthRate = 0.10;
            in mortalityRate = 0.08;
            in resourceAvailability = 0.75;
            out newPopulation;
        }
        
        then decide;
            if controlConsumerPopulation.newPopulation > 0.0 then cycleBegin;
            else done;
    }
    
    connection def EnergyConnection {
        end source : EnergyFlowPort;
        end target : EnergyFlowPort;
    }
    
    connection def BiomassConnection {
        end source : BiomassFlowPort;
        end target : BiomassFlowPort;
    }
    
    connection def NutrientConnection {
        end source : NutrientFlowPort;
        end target : NutrientFlowPort;
    }
    
    connection def WaterConnection {
        end source : WaterFlowPort;
        end target : WaterFlowPort;
    }
    
    part def TerrestrialEcosystem {
        doc /* 
            A terrestrial ecosystem is a complex network of living organisms interacting 
            with their physical environment. Its primary function is to sustain life through 
            continuous energy flow and nutrient cycling.
            
            The system captures solar energy via photosynthesis in producer organisms, 
            transfers energy through food chains via consumption, and recycles nutrients 
            through decomposition. This creates a self-regulating cycle maintaining 
            ecological balance and biodiversity.
        */
        
        attribute environmentalState : EnvironmentalConditions;
        attribute totalArea : AreaValue;
        attribute diversityIndex : Real;
        
        part producers : ProducerOrganism[*] {
            attribute populationSize = 45000.0;
            attribute biomass = 90000.0[kg];
            attribute productivityRate = 0.04;
        }
        
        part primaryConsumers : ConsumerOrganism[*] {
            attribute populationSize = 4500.0;
            attribute biomass = 22500.0[kg];
            attribute consumptionRate = 0.12;
        }
        
        part secondaryConsumers : ConsumerOrganism[*] {
            attribute populationSize = 450.0;
            attribute biomass = 4500.0[kg];
            attribute consumptionRate = 0.18;
        }
        
        part decomposers : DecomposerOrganism[*] {
            attribute populationSize = 900000.0;
            attribute processingCapacity = 0.75;
        }
        
        part soil : SoilSubsystem {
            attribute properties : SoilProperties {
                attribute nitrogenContent = 0.12;
                attribute phosphorusContent = 0.04;
                attribute organicContent = 4.5;
                attribute moistureLevel = 0.65;
            }
            attribute waterCapacity = 0.55;
        }
        
        part atmosphere : AtmosphereSubsystem {
            attribute oxygenConcentration = 21.0;
            attribute carbonDioxideConcentration = 0.04;
        }
        
        connection energyFlow1 : EnergyConnection 
            connect producers.energyIn to primaryConsumers.energyOut;
        
        connection energyFlow2 : EnergyConnection 
            connect primaryConsumers.energyOut to secondaryConsumers.energyOut;
        
        connection biomassFlow1 : BiomassConnection 
            connect producers.biomassOut to primaryConsumers.foodIn;
        
        connection biomassFlow2 : BiomassConnection 
            connect primaryConsumers.foodIn to secondaryConsumers.foodIn;
        
        connection nutrientRecycle1 : NutrientConnection 
            connect decomposers.nutrientOut to soil.nutrientStore;
        
        connection nutrientRecycle2 : NutrientConnection 
            connect soil.nutrientStore to producers.nutrientIn;
        
        connection wasteFlow1 : NutrientConnection 
            connect primaryConsumers.wasteOut to decomposers.organicIn;
        
        connection wasteFlow2 : NutrientConnection 
            connect secondaryConsumers.wasteOut to decomposers.organicIn;
        
        connection waterFlow : WaterConnection 
            connect soil.waterStore to producers.waterIn;
        
        perform action sustainEcosystem : MaintainEcosystemBalance;
    }
    
    part ecosystemInstance : TerrestrialEcosystem {
        attribute environmentalState : EnvironmentalConditions {
            attribute ambientTemperature = 298.15[K];
            attribute rainfall = 120.0;
            attribute solarIntensity = 800.0[W/m^2];
            attribute relativeHumidity = 0.68;
        }
        attribute totalArea = 10000.0[m^2];
        attribute diversityIndex = 0.78;
    }
    
    requirement def PrimaryFunction;
    requirement def EnergyFlowRequirement;
    requirement def NutrientCyclingRequirement;
    requirement def PopulationStabilityRequirement;
    
    requirement <'EF-1'> ecosystemEnergyFlow : EnergyFlowRequirement {
        doc /* The ecosystem shall maintain continuous energy flow from solar input 
               through all trophic levels with minimum 10% transfer efficiency between levels. */
        subject ecosystemInstance;
    }
    
    requirement <'NC-1'> ecosystemNutrientCycling : NutrientCyclingRequirement {
        doc /* The ecosystem shall recycle at least 75% of organic matter back into 
               available nutrients through decomposition processes. */
        subject ecosystemInstance;
        require constraint {
            ecosystemInstance.decomposers.processingCapacity >= 0.75
        }
    }
    
    requirement <'PS-1'> ecosystemPopulationStability : PopulationStabilityRequirement {
        doc /* The ecosystem shall maintain population levels within 15% of equilibrium 
               values to ensure long-term sustainability. */
        subject ecosystemInstance;
    }
    
    requirement <'PF-1'> ecosystemPrimaryFunction : PrimaryFunction {
        doc /* The primary function of the terrestrial ecosystem is to sustain life by 
               continuously cycling energy and nutrients through producer, consumer, and 
               decomposer organisms while maintaining ecological balance and biodiversity. */
        subject ecosystemInstance;
        
        require ecosystemEnergyFlow;
        require ecosystemNutrientCycling;
        require ecosystemPopulationStability;
    }
}
