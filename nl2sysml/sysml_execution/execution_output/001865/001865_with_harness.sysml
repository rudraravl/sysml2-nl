package SmallholdingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SeasonType;
    attribute def CropVariety;
    attribute def AnimalSpecies;
    attribute def SoilQuality;
    attribute def WaterQuality;
    
    item def FreshWater {
        attribute quality : WaterQuality;
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue;
    }
    
    item def CropPlant {
        attribute variety : CropVariety;
        attribute maturityLevel : Real;
        attribute waterNeed : Real;
        attribute mass : MassValue;
    }
    
    item def Animal {
        attribute species : AnimalSpecies;
        attribute count : Integer;
        attribute feedNeed : MassValue;
        attribute waterNeed : VolumeValue;
    }
    
    item def FoodProduce {
        attribute mass : MassValue;
        attribute harvestDate : String;
        attribute produceType : String;
    }
    
    item def OrganicFertilizer {
        attribute mass : MassValue;
        attribute nitrogenContent : Real;
    }
    
    port def WaterSupplyPort {
        out item water : FreshWater;
    }
    
    port def WaterIntakePort {
        in item water : FreshWater;
    }
    
    port def FeedSupplyPort {
        out item feed : FoodProduce;
    }
    
    port def FeedIntakePort {
        in item feed : FoodProduce;
    }
    
    port def FertilizerPort {
        out item fertilizer : OrganicFertilizer;
    }
    
    part def WellSystem {
        attribute depth : LengthValue;
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        port waterOutput : WaterSupplyPort;
        
        action def ExtractWater {
            in requestedVolume : VolumeValue;
            out suppliedWater : FreshWater;
        }
    }
    
    part def CultivationField {
        attribute area : AreaValue;
        attribute soilQuality : SoilQuality;
        attribute moistureLevel : Real;
        port waterInput : WaterIntakePort;
        port fertilizerInput : FertilizerPort;
        
        part crops : CropPlant[*];
        
        action def CultivateCrops {
            in waterSupply : FreshWater;
            in fertilizer : OrganicFertilizer;
            in sunlightHours : TimeValue;
            in season : SeasonType;
            out harvest : FoodProduce;
        }
    }
    
    part def LivestockShelter {
        attribute capacity : Integer;
        attribute currentOccupancy : Integer;
        port feedInput : FeedIntakePort;
        port waterInput : WaterIntakePort;
        port fertilizerOutput : FertilizerPort;
        
        part animals : Animal[*];
        
        action def ManageAnimals {
            in feed : FoodProduce;
            in water : FreshWater;
            out animalProducts : FoodProduce;
            out manure : OrganicFertilizer;
        }
    }
    
    part def WaterDistributionSystem {
        attribute flowRate : Real;
        attribute pressure : PressureValue;
        port waterSource : WaterIntakePort;
        port fieldOutput : WaterSupplyPort[*];
        port shelterOutput : WaterSupplyPort;
        
        action def DistributeWater {
            in sourceWater : FreshWater;
            in fieldDemands : Real[*];
            in shelterDemand : VolumeValue;
            out fieldWater : FreshWater[*];
            out shelterWater : FreshWater;
        }
    }
    
    part def StorageFacility {
        attribute capacity : MassValue;
        attribute currentStock : MassValue;
        attribute temperature : TemperatureValue;
        
        action def StoreHarvest {
            in produce : FoodProduce;
            out storedProduce : FoodProduce;
        }
        
        action def RetrieveProduce {
            in requestedAmount : MassValue;
            out retrievedProduce : FoodProduce;
        }
    }
    
    action def AssessSeasonalConditions {
        out currentSeason : SeasonType;
        out ambientTemp : TemperatureValue;
        out rainfall : VolumeValue;
    }
    
    action def CalculateWaterRequirements {
        in cropNeeds : Real[*];
        in animalNeeds : VolumeValue[*];
        in evaporation : VolumeValue;
        out totalRequired : VolumeValue;
    }
    
    action def DistributeResources {
        in waterAvailable : VolumeValue;
        in waterRequired : VolumeValue;
        in fertilizerAvailable : MassValue;
        out irrigationPlan : Real[*];
        out animalWaterPlan : VolumeValue[*];
        out fertilizationPlan : MassValue[*];
    }
    
    action def ExecuteHarvest {
        in fieldYields : FoodProduce[*];
        out combinedHarvest : FoodProduce;
    }
    
    action def CollectAnimalProducts {
        in animalOutputs : FoodProduce[*];
        out combinedProducts : FoodProduce;
    }
    
    action def ManageSmallholdingOperations {
        first start;
        then merge dailyCycle;
        
        action assessConditions : AssessSeasonalConditions {
            out season : SeasonType;
            out temp : TemperatureValue;
            out rain : VolumeValue;
        }
        
        then action calculateNeeds : CalculateWaterRequirements {
            in cropNeeds : Real[*];
            in animalNeeds : VolumeValue[*];
            in evaporation : VolumeValue;
            out totalRequired : VolumeValue;
        }
        
        then action planResources : DistributeResources {
            in waterAvailable : VolumeValue;
            in waterRequired = calculateNeeds.totalRequired;
            in fertilizerAvailable : MassValue;
            out irrigationPlan : Real[*];
            out animalWaterPlan : VolumeValue[*];
            out fertilizationPlan : MassValue[*];
        }
        
        then action parallelOperations {
            action irrigateFields {
                in plan = planResources.irrigationPlan;
            }
            action feedAnimals {
                in waterPlan = planResources.animalWaterPlan;
            }
            action applyFertilizer {
                in plan = planResources.fertilizationPlan;
            }
        }
        
        then action harvestCrops : ExecuteHarvest {
            in fieldYields : FoodProduce[*];
            out combinedHarvest : FoodProduce;
        }
        
        then action collectProducts : CollectAnimalProducts {
            in animalOutputs : FoodProduce[*];
            out combinedProducts : FoodProduce;
        }
        
        then dailyCycle;
    }
    
    part def Smallholding {
        attribute totalLandArea : AreaValue;
        attribute operatingYears : Integer;
        
        part well : WellSystem;
        part waterDistribution : WaterDistributionSystem;
        part northField : CultivationField;
        part southField : CultivationField;
        part shelter : LivestockShelter;
        part storage : StorageFacility;
    }
    
    part smallholding : Smallholding {
        attribute :>> totalLandArea = 5.0 [SI::ha];
        attribute :>> operatingYears = 3;
        
        part :>> well {
            attribute :>> depth = 30.0 [SI::m];
            attribute :>> capacity = 75000.0 [SI::L];
            attribute :>> currentLevel = 68000.0 [SI::L];
        }
        
        part :>> waterDistribution {
            attribute :>> flowRate = 120.0;
            attribute :>> pressure = 250.0 [SI::kPa];
        }
        
        part :>> northField {
            attribute :>> area = 2.0 [SI::ha];
            attribute :>> moistureLevel = 0.65;
        }
        
        part :>> southField {
            attribute :>> area = 1.8 [SI::ha];
            attribute :>> moistureLevel = 0.58;
        }
        
        part :>> shelter {
            attribute :>> capacity = 40;
            attribute :>> currentOccupancy = 35;
        }
        
        part :>> storage {
            attribute :>> capacity = 8000.0 [SI::kg];
            attribute :>> currentStock = 2400.0 [SI::kg];
            attribute :>> temperature = 285.0 [SI::K];
        }
        
        connect well.waterOutput to waterDistribution.waterSource;
        connect waterDistribution.fieldOutput[1] to northField.waterInput;
        connect waterDistribution.fieldOutput[2] to southField.waterInput;
        connect waterDistribution.shelterOutput to shelter.waterInput;
        connect shelter.fertilizerOutput to northField.fertilizerInput;
        connect shelter.fertilizerOutput to southField.fertilizerInput;
        
        perform action operate : ManageSmallholdingOperations;
    }
    
    requirement def SustainableFoodProductionRequirement {
        doc /* The smallholding shall sustainably produce food by integrating crop cultivation 
                and livestock management to meet household nutritional needs throughout the year. */
        
        require constraint adequateWaterSupply {
            doc /* Water supply must satisfy at least 95% of combined crop and livestock requirements 
                    during peak demand periods. */
        }
        
        require constraint soilFertility {
            doc /* Soil quality must be maintained through organic fertilization to support 
                    continuous crop production. */
        }
        
        require constraint cropDiversity {
            doc /* Multiple crop varieties shall be cultivated to ensure year-round food availability 
                    and nutritional diversity. */
        }
    }
    
    requirement def ResourceEfficiencyRequirement {
        doc /* The smallholding shall optimize resource utilization to minimize waste and 
                maximize productivity per unit area. */
        
        require constraint waterUseEfficiency {
            doc /* Water usage efficiency shall exceed 80% through appropriate irrigation scheduling 
                    and distribution. */
        }
        
        require constraint nutrientCycling {
            doc /* Animal waste shall be converted to fertilizer to reduce external input dependency 
                    by at least 60%. */
        }
        
        require constraint storageCapacity {
            doc /* Storage capacity shall accommodate peak harvest volumes with 20% reserve margin. */
        }
    }
    
    requirement def AnimalWelfareRequirement {
        doc /* The smallholding shall ensure humane treatment and proper care of all livestock. */
        
        require constraint adequateNutrition {
            doc /* Animals shall receive nutritionally balanced feed and clean water daily according 
                    to species-specific requirements. */
        }
        
        require constraint shelterConditions {
            doc /* Shelter capacity shall not exceed design limits and maintain appropriate temperature 
                    and ventilation. */
        }
        
        require constraint healthMonitoring {
            doc /* Animal health shall be monitored regularly to prevent disease and ensure productivity. */
        }
    }
    
    requirement def EnvironmentalStewardshipRequirement {
        doc /* The smallholding shall operate in harmony with natural ecosystems and minimize 
                environmental impact. */
        
        require constraint soilConservation {
            doc /* Soil erosion shall be prevented through appropriate cultivation practices and 
                    ground cover management. */
        }
        
        require constraint waterConservation {
            doc /* Groundwater extraction shall not exceed natural recharge rates to ensure 
                    long-term sustainability. */
        }
        
        require constraint biodiversity {
            doc /* Farming practices shall support local biodiversity through habitat preservation 
                    and minimal chemical use. */
        }
    }
    
    requirement smallholdingSystemRequirements {
        subject smallholding;
        
        doc /* The smallholding system shall produce diverse food products sustainably by integrating 
                crop cultivation and livestock management while efficiently managing water, soil, and 
                biological resources to meet household nutritional needs and maintain environmental balance. */
        
        require sustainableProduction : SustainableFoodProductionRequirement;
        require resourceEfficiency : ResourceEfficiencyRequirement;
        require animalWelfare : AnimalWelfareRequirement;
        require environmentalStewardship : EnvironmentalStewardshipRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SmallholdingSystem::*;
}
