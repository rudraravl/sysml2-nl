package SmallholdingFarm {
    import ScalarValues::*;

    // ---- Units ----
    unit def cubicMeter;
    unit def kilogram;
    unit def kelvin;
    unit def second;
    unit def percent;
    unit def squareMeter;

    // ---- Value types ----
    value def Volume :> Real { unit cubicMeter; }
    value def Mass :> Real { unit kilogram; }
    value def Temperature :> Real { unit kelvin; }
    value def Duration :> Real { unit second; }
    value def Percentage :> Real { unit percent; }
    value def Area :> Real { unit squareMeter; }

    // ---- Items ----
    item def FreshWater;
    item def Manure;
    item def AnimalFeed;
    item def HarvestedCrop;
    item def AnimalProduct;
    item def StoredProduce;

    // ---- Ports ----
    port def WaterOutPort {
        out item water : FreshWater;
    }
    port def WaterInPort {
        in item water : FreshWater;
    }
    port def ManureOutPort {
        out item manure : Manure;
    }
    port def ManureInPort {
        in item manure : Manure;
    }
    port def CropOutPort {
        out item crop : HarvestedCrop;
    }
    port def CropInPort {
        in item crop : HarvestedCrop;
    }
    port def ProductOutPort {
        out item product : AnimalProduct;
    }
    port def ProductInPort {
        in item product : AnimalProduct;
    }
    port def FeedInPort {
        in item feed : AnimalFeed;
    }

    // ---- Well ----
    part def Well {
        attribute waterReserve : Volume = 1000;
        attribute maxDrawRate : Volume = 0.01;

        port waterOut : WaterOutPort;

        action def drawWater {
            in requestedVolume : Volume;
            out deliveredWater : FreshWater;
            constraint { requestedVolume <= waterReserve }
        }
        perform drawWater;
    }

    // ---- Water Distribution System ----
    part def WaterDistributionSystem {
        attribute northAllocation : Volume = 0;
        attribute southAllocation : Volume = 0;
        attribute livestockAllocation : Volume = 0;
        attribute pipeEfficiency : Percentage = 95;

        port waterIn : WaterInPort;
        port fieldNorthWaterOut : WaterOutPort;
        port fieldSouthWaterOut : WaterOutPort;
        port livestockWaterOut : WaterOutPort;

        action def distributeWater {
            in incomingWater : FreshWater;
            in northNeed : Volume;
            in southNeed : Volume;
            in livestockNeed : Volume;
            out toNorth : FreshWater;
            out toSouth : FreshWater;
            out toLivestock : FreshWater;
        }
        perform distributeWater;
    }

    // ---- Cultivation Field ----
    part def CultivationField {
        attribute fieldId : String;
        attribute cropType : String;
        attribute area : Area;
        attribute soilMoisture : Percentage = 40;
        attribute fertilityLevel : Percentage = 50;
        attribute optimalMoisture : Percentage = 60;
        attribute waterNeedPerArea : Volume = 0.005;

        port waterIn : WaterInPort;
        port manureIn : ManureInPort;
        port cropOut : CropOutPort;

        action def assessConditions {
            out moisture : Percentage;
            out fertility : Percentage;
        }
        action def irrigate {
            in water : FreshWater;
            in volume : Volume;
        }
        action def applyFertilizer {
            in manure : Manure;
            in amount : Mass;
        }
        action def harvest {
            out crop : HarvestedCrop;
        }

        perform assessConditions;
    }

    // ---- Livestock Shelter ----
    part def LivestockShelter {
        attribute species : String;
        attribute animalCount : Integer;
        attribute dailyWaterNeedPerAnimal : Volume = 0.01;
        attribute dailyFeedNeedPerAnimal : Mass = 0.15;
        attribute dailyWaterNeed : Volume;
        attribute dailyFeedNeed : Mass;

        port waterIn : WaterInPort;
        port feedIn : FeedInPort;
        port manureOut : ManureOutPort;
        port productOut : ProductOutPort;

        action def waterAnimals {
            in water : FreshWater;
        }
        action def feedAnimals {
            in feed : AnimalFeed;
        }
        action def collectManure {
            out manure : Manure;
        }
        action def collectProducts {
            out product : AnimalProduct;
        }

        perform collectManure;
        perform collectProducts;
    }

    // ---- Storage Facility ----
    part def StorageFacility {
        attribute internalTemperature : Temperature = 277;
        attribute targetTemperature : Temperature = 277;
        attribute capacity : Volume;
        attribute storedMass : Mass = 0;
        attribute humidity : Percentage = 65;

        port cropIn : CropInPort;
        port productIn : ProductInPort;

        action def storeProduce {
            in crop : HarvestedCrop;
            in product : AnimalProduct;
        }
        action def regulateTemperature {
            in target : Temperature;
        }
        action def retrieveProduce {
            out produce : StoredProduce;
        }

        perform regulateTemperature;
    }

    // ---- Farm Operation Cycle (composite action) ----
    action def FarmOperationCycle {
        in northMoisture : Percentage;
        in southMoisture : Percentage;
        in northFertility : Percentage;
        in southFertility : Percentage;
        in livestockWaterNeed : Volume;
        in availableManure : Mass;
        out northWaterNeed : Volume;
        out southWaterNeed : Volume;
        out northFertilizerNeed : Mass;
        out southFertilizerNeed : Mass;
        out harvestedCrops : HarvestedCrop[0..*];
        out animalProducts : AnimalProduct[0..*];

        action assessEnvironment;
        action planAllocation;
        action executeTasks;
        action harvestAndCollect;

        first assessEnvironment then planAllocation;
        then executeTasks then harvestAndCollect;
    }

    // ---- State Machine ----
    state def FarmOperation {
        entry;
        state Assessing {
            entry;
        }
        state Planning {
            entry;
        }
        state Executing {
            entry;
        }
        state Harvesting {
            entry;
        }

        transition Assessing -> Planning;
        transition Planning -> Executing;
        transition Executing -> Harvesting;
        transition Harvesting -> Assessing;
    }

    // ---- Constraints ----
    constraint def WaterConservationConstraint {
        in waterDrawn : Volume;
        in waterDelivered : Volume;
        in efficiency : Percentage;
        constraint { waterDelivered >= waterDrawn * (efficiency / 100.0) }
    }

    constraint def FertilityConstraint {
        in fertility : Percentage;
        in minFertility : Percentage;
        constraint { fertility >= minFertility }
    }

    // ---- Requirements ----
    requirement def SustainabilityRequirement {
        doc "The farm shall operate as a self-sufficient agricultural ecosystem.";
    }

    requirement def WaterConservationRequirement {
        doc "The farm shall conserve water through efficient distribution.";
        attribute maxWaterLoss : Percentage = 5;
    }

    requirement def SoilFertilityRequirement {
        doc "The farm shall maintain soil fertility using organic manure.";
        attribute minFertilityLevel : Percentage = 40;
    }

    requirement def AnimalWelfareRequirement {
        doc "The farm shall ensure humane treatment of animals with adequate water and feed.";
        attribute minDailyWaterPerAnimal : Volume = 0.01;
        attribute minDailyFeedPerAnimal : Mass = 0.1;
    }

    requirement def StorageTemperatureRequirement {
        doc "The storage facility shall maintain temperature-controlled conditions for produce longevity.";
        attribute targetTemperature : Temperature = 277;
        attribute tolerance : Temperature = 2;
    }

    requirement def ResourceCyclingRequirement {
        doc "The farm shall cycle manure from livestock to fields as organic fertilizer.";
    }

    // ---- Farm (top-level integration) ----
    part def SmallholdingFarm {
        exhibit FarmOperation;

        part well : Well {
            attribute waterReserve = 1200;
        }
        part distribution : WaterDistributionSystem;
        part northField : CultivationField {
            attribute fieldId = "North";
            attribute cropType = "Maize";
            attribute area = 20000;
        }
        part southField : CultivationField {
            attribute fieldId = "South";
            attribute cropType = "Vegetables";
            attribute area = 15000;
        }
        part shelter : LivestockShelter {
            attribute species = "Poultry";
            attribute animalCount = 50;
            attribute dailyWaterNeed = 0.5;
            attribute dailyFeedNeed = 7.5;
        }
        part storage : StorageFacility {
            attribute capacity = 20;
        }

        // Connections
        connection wellToDistribution connect well.waterOut to distribution.waterIn;
        connection distributionToNorth connect distribution.fieldNorthWaterOut to northField.waterIn;
        connection distributionToSouth connect distribution.fieldSouthWaterOut to southField.waterIn;
        connection distributionToShelter connect distribution.livestockWaterOut to shelter.waterIn;
        connection shelterManureToNorth connect shelter.manureOut to northField.manureIn;
        connection shelterManureToSouth connect shelter.manureOut to southField.manureIn;
        connection northCropToStorage connect northField.cropOut to storage.cropIn;
        connection southCropToStorage connect southField.cropOut to storage.cropIn;
        connection shelterProductToStorage connect shelter.productOut to storage.productIn;

        // Requirement usages
        requirement farmSustainability : SustainabilityRequirement {
            subject farm : SmallholdingFarm;
        }
        requirement farmWaterConservation : WaterConservationRequirement {
            subject dist : WaterDistributionSystem;
        }
        requirement northFertilityReq : SoilFertilityRequirement {
            subject field : CultivationField;
        }
        requirement southFertilityReq : SoilFertilityRequirement {
            subject field : CultivationField;
        }
        requirement farmAnimalWelfare : AnimalWelfareRequirement {
            subject shelt : LivestockShelter;
        }
        requirement farmStorage : StorageTemperatureRequirement {
            subject stor : StorageFacility;
        }
        requirement farmResourceCycling : ResourceCyclingRequirement {
            subject farm : SmallholdingFarm;
        }

        // Satisfaction
        satisfy farmSustainability by self;
        satisfy farmWaterConservation by distribution;
        satisfy northFertilityReq by northField;
        satisfy southFertilityReq by southField;
        satisfy farmAnimalWelfare by shelter;
        satisfy farmStorage by storage;
        satisfy farmResourceCycling by self;
    }
}
