package SmallholdingSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Area :> ISQ::area {
        unit = SI::hectare;
    }

    attribute def Mass :> ISQ::mass {
        unit = SI::kilogram;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::litre;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::litrePerHour;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def Money {
        attribute amount : Real;
        attribute currency : String = "USD";
    }

    item def Water {
        attribute volume : Volume;
        attribute potable : Boolean;
        attribute temperature : Temperature;
    }

    item def Rainwater :> Water {
        attribute collectedFromRoof : Boolean = true;
    }

    item def IrrigationWater :> Water {
        attribute nutrientEnhanced : Boolean;
    }

    item def Feed {
        attribute mass : Mass;
        attribute proteinFraction : Real;
        attribute dryMatterFraction : Real;
    }

    item def Seed {
        attribute species : String;
        attribute mass : Mass;
        attribute germinationRate : Real;
    }

    item def CropProduce {
        attribute cropName : String;
        attribute mass : Mass;
        attribute foodGrade : Boolean;
        attribute harvestedDate : String;
    }

    item def AnimalProduct {
        attribute productName : String;
        attribute mass : Mass;
        attribute dailyYield : Mass;
        attribute foodGrade : Boolean;
    }

    item def Compost {
        attribute mass : Mass;
        attribute maturityFraction : Real;
        attribute nitrogenFraction : Real;
    }

    item def Manure {
        attribute mass : Mass;
        attribute moistureFraction : Real;
    }

    item def Energy {
        attribute power : Power;
        attribute source : String;
    }

    item def MarketGoods {
        attribute description : String;
        attribute produceMass : Mass;
        attribute estimatedValue : Money;
    }

    port def WaterInPort {
        in item water : Water;
    }

    port def WaterOutPort {
        out item water : Water;
    }

    port def FeedInPort {
        in item feed : Feed;
    }

    port def FeedOutPort {
        out item feed : Feed;
    }

    port def SeedInPort {
        in item seed : Seed;
    }

    port def ProduceOutPort {
        out item produce : CropProduce;
    }

    port def AnimalProductOutPort {
        out item product : AnimalProduct;
    }

    port def ManureOutPort {
        out item manure : Manure;
    }

    port def CompostInPort {
        in item compost : Compost;
    }

    port def CompostOutPort {
        out item compost : Compost;
    }

    port def EnergyOutPort {
        out item energy : Energy;
    }

    port def EnergyInPort {
        in item energy : Energy;
    }

    part def RainwaterHarvestingSystem {
        attribute roofCatchmentArea : Area;
        attribute tankCapacity : Volume;
        attribute storedVolume : Volume;
        attribute filtrationEnabled : Boolean;

        port outlet : WaterOutPort;

        action collectRainwater {
            in attribute rainfallDepth : ISQ::length;
            out item collectedWater : Rainwater;
        }

        action filterStoredWater {
            in item rawWater : Rainwater;
            out item filteredWater : Rainwater;
        }
    }

    part def IrrigationSystem {
        attribute maximumFlowRate : FlowRate;
        attribute soilMoistureSetpoint : Real;
        attribute activeZoneCount : Integer;

        port waterIn : WaterInPort;
        port irrigationOut : WaterOutPort;
        port energyIn : EnergyInPort;

        action distributeWater {
            in item sourceWater : Water;
            in attribute targetSoilMoisture : Real;
            out item appliedWater : IrrigationWater;
        }
    }

    part def VegetableGarden {
        attribute growingArea : Area;
        attribute bedCount : Integer;
        attribute soilOrganicMatterFraction : Real;
        attribute expectedSeasonalYield : Mass;

        port seedIn : SeedInPort;
        port waterIn : WaterInPort;
        port compostIn : CompostInPort;
        port produceOut : ProduceOutPort;

        action sowSeeds {
            in item seedBatch : Seed;
            out attribute plantedRows : Integer;
        }

        action growCrops {
            in item irrigation : Water;
            in item soilAmendment : Compost;
            out attribute cropHealthIndex : Real;
        }

        action harvestCrops {
            out item harvestedProduce : CropProduce;
        }

        state def CropProductionState {
            state Idle;
            state Prepared;
            state Planted;
            state Growing;
            state ReadyForHarvest;
            state Harvested;

            transition first Idle then Prepared;
            transition first Prepared then Planted;
            transition first Planted then Growing;
            transition first Growing then ReadyForHarvest;
            transition first ReadyForHarvest then Harvested;
            transition first Harvested then Prepared;
        }
    }

    part def Orchard {
        attribute treeCount : Integer;
        attribute orchardArea : Area;
        attribute annualFruitYield : Mass;
        attribute pollinatorHabitatArea : Area;

        port waterIn : WaterInPort;
        port compostIn : CompostInPort;
        port produceOut : ProduceOutPort;

        action pruneTrees {
            out attribute prunedTreeCount : Integer;
        }

        action harvestFruit {
            out item fruit : CropProduce;
        }
    }

    part def PoultryFlock {
        attribute birdCount : Integer;
        attribute coopArea : Area;
        attribute dailyFeedDemand : Mass;
        attribute dailyEggYield : Mass;

        port feedIn : FeedInPort;
        port waterIn : WaterInPort;
        port productOut : AnimalProductOutPort;
        port manureOut : ManureOutPort;

        action feedBirds {
            in item ration : Feed;
            out attribute fedBirdCount : Integer;
        }

        action collectEggs {
            out item eggs : AnimalProduct;
        }

        action cleanCoop {
            out item beddingManure : Manure;
        }

        state def FlockCareState {
            state Resting;
            state Feeding;
            state Laying;
            state Cleaning;
            state HealthCheck;

            transition first Resting then Feeding;
            transition first Feeding then Laying;
            transition first Laying then Cleaning;
            transition first Cleaning then HealthCheck;
            transition first HealthCheck then Resting;
        }
    }

    part def GoatHerd {
        attribute goatCount : Integer;
        attribute pastureArea : Area;
        attribute dailyFeedDemand : Mass;
        attribute dailyMilkYield : Mass;

        port feedIn : FeedInPort;
        port waterIn : WaterInPort;
        port productOut : AnimalProductOutPort;
        port manureOut : ManureOutPort;

        action grazePasture {
            out attribute pastureUtilizationFraction : Real;
        }

        action milkGoats {
            out item milk : AnimalProduct;
        }

        action collectManure {
            out item herdManure : Manure;
        }
    }

    part def FeedStorage {
        attribute storageCapacity : Mass;
        attribute currentStock : Mass;
        attribute spoilageRiskIndex : Real;

        port feedOut : FeedOutPort;

        action dispenseFeed {
            in attribute requestedMass : Mass;
            out item ration : Feed;
        }
    }

    part def CompostingSystem {
        attribute compostBayCount : Integer;
        attribute activeCompostMass : Mass;
        attribute targetMoistureFraction : Real;
        attribute targetMaturityFraction : Real;

        port manureIn : ManureOutPort;
        port compostOut : CompostOutPort;
        port waterIn : WaterInPort;

        action mixOrganicWaste {
            in item manureInput : Manure;
            out item mixedCompost : Compost;
        }

        action cureCompost {
            in item immatureCompost : Compost;
            out item matureCompost : Compost;
        }
    }

    part def SolarPowerSystem {
        attribute panelArea : Area;
        attribute peakPower : Power;
        attribute batteryCapacityWh : Real;
        attribute stateOfChargeFraction : Real;

        port energyOut : EnergyOutPort;

        action generatePower {
            in attribute solarIrradiance : Real;
            out item electricalEnergy : Energy;
        }
    }

    part def FarmManagementController {
        attribute dailyLaborAvailableHours : Real;
        attribute soilMoistureThreshold : Real;
        attribute feedReorderThreshold : Mass;
        attribute surplusTargetMass : Mass;

        action scheduleDailyWork {
            out attribute taskCount : Integer;
        }

        action evaluateSelfProvisioning {
            in item crops : CropProduce;
            in item animalProducts : AnimalProduct;
            out attribute householdFoodCoverageFraction : Real;
        }

        action prepareMarketSurplus {
            in item crops : CropProduce;
            in item animalProducts : AnimalProduct;
            out item goods : MarketGoods;
        }

        state def SmallholdingOperatingState {
            state Monitoring;
            state Watering;
            state FeedingAnimals;
            state Harvesting;
            state Composting;
            state PreparingSurplus;
            state Maintenance;

            transition first Monitoring then Watering;
            transition first Watering then FeedingAnimals;
            transition first FeedingAnimals then Harvesting;
            transition first Harvesting then Composting;
            transition first Composting then PreparingSurplus;
            transition first PreparingSurplus then Maintenance;
            transition first Maintenance then Monitoring;
        }
    }

    part def Smallholding {
        attribute totalArea : Area = 4.0 [SI::hectare];
        attribute primaryFunction : String = "Produce household food, maintain soil fertility, manage water and energy flows, and generate limited market surplus from integrated crop and livestock operations.";
        attribute householdSize : Integer = 5;
        attribute annualFoodProductionTarget : Mass = 3500.0 [SI::kilogram];
        attribute minimumWaterReserve : Volume = 8000.0 [SI::litre];

        part rainwaterSystem : RainwaterHarvestingSystem {
            attribute roofCatchmentArea = 220.0 [SI::squareMetre];
            attribute tankCapacity = 30000.0 [SI::litre];
            attribute storedVolume = 18000.0 [SI::litre];
            attribute filtrationEnabled = true;
        }

        part irrigationSystem : IrrigationSystem {
            attribute maximumFlowRate = 1200.0 [SI::litrePerHour];
            attribute soilMoistureSetpoint = 0.28;
            attribute activeZoneCount = 6;
        }

        part vegetableGarden : VegetableGarden {
            attribute growingArea = 0.35 [SI::hectare];
            attribute bedCount = 42;
            attribute soilOrganicMatterFraction = 0.065;
            attribute expectedSeasonalYield = 1800.0 [SI::kilogram];
        }

        part orchard : Orchard {
            attribute treeCount = 64;
            attribute orchardArea = 0.6 [SI::hectare];
            attribute annualFruitYield = 950.0 [SI::kilogram];
            attribute pollinatorHabitatArea = 0.08 [SI::hectare];
        }

        part poultry : PoultryFlock {
            attribute birdCount = 36;
            attribute coopArea = 48.0 [SI::squareMetre];
            attribute dailyFeedDemand = 5.4 [SI::kilogram];
            attribute dailyEggYield = 1.8 [SI::kilogram];
        }

        part goats : GoatHerd {
            attribute goatCount = 7;
            attribute pastureArea = 1.4 [SI::hectare];
            attribute dailyFeedDemand = 18.0 [SI::kilogram];
            attribute dailyMilkYield = 9.5 [SI::kilogram];
        }

        part feedStorage : FeedStorage {
            attribute storageCapacity = 1800.0 [SI::kilogram];
            attribute currentStock = 740.0 [SI::kilogram];
            attribute spoilageRiskIndex = 0.12;
        }

        part composting : CompostingSystem {
            attribute compostBayCount = 3;
            attribute activeCompostMass = 2600.0 [SI::kilogram];
            attribute targetMoistureFraction = 0.55;
            attribute targetMaturityFraction = 0.85;
        }

        part solarPower : SolarPowerSystem {
            attribute panelArea = 38.0 [SI::squareMetre];
            attribute peakPower = 6200.0 [SI::watt];
            attribute batteryCapacityWh = 14000.0;
            attribute stateOfChargeFraction = 0.71;
        }

        part controller : FarmManagementController {
            attribute dailyLaborAvailableHours = 7.5;
            attribute soilMoistureThreshold = 0.22;
            attribute feedReorderThreshold = 250.0 [SI::kilogram];
            attribute surplusTargetMass = 600.0 [SI::kilogram];
        }

        connect rainwaterSystem.outlet to irrigationSystem.waterIn;
        connect irrigationSystem.irrigationOut to vegetableGarden.waterIn;
        connect irrigationSystem.irrigationOut to orchard.waterIn;
        connect rainwaterSystem.outlet to poultry.waterIn;
        connect rainwaterSystem.outlet to goats.waterIn;

        connect solarPower.energyOut to irrigationSystem.energyIn;

        connect feedStorage.feedOut to poultry.feedIn;
        connect feedStorage.feedOut to goats.feedIn;

        connect poultry.manureOut to composting.manureIn;
        connect goats.manureOut to composting.manureIn;
        connect composting.compostOut to vegetableGarden.compostIn;
        connect composting.compostOut to orchard.compostIn;

        action operateSmallholding {
            first start;
            then controller.scheduleDailyWork;
            then rainwaterSystem.collectRainwater;
            then solarPower.generatePower;
            then irrigationSystem.distributeWater;
            then vegetableGarden.growCrops;
            then orchard.pruneTrees;
            then feedStorage.dispenseFeed;
            then poultry.feedBirds;
            then goats.grazePasture;
            then poultry.collectEggs;
            then goats.milkGoats;
            then poultry.cleanCoop;
            then goats.collectManure;
            then composting.mixOrganicWaste;
            then composting.cureCompost;
            then vegetableGarden.harvestCrops;
            then orchard.harvestFruit;
            then controller.evaluateSelfProvisioning;
            then controller.prepareMarketSurplus;
            then done;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The smallholding shall function as an integrated food-production and resource-cycling system that supplies household food, uses local water and energy resources, maintains soil fertility, supports livestock care, and produces managed surplus for local sale or exchange. */
    }

    requirement def WaterResilienceRequirement {
        doc /* The smallholding shall store sufficient harvested water to maintain crop and livestock operations during short dry periods. */

        require constraint {
            Smallholding::rainwaterSystem::tankCapacity >= Smallholding::minimumWaterReserve
        }
    }

    requirement def FoodProductionRequirement {
        doc /* The smallholding shall produce a combined annual crop and animal-product yield sufficient to cover a substantial fraction of household food demand. */

        require constraint {
            Smallholding::vegetableGarden::expectedSeasonalYield
            + Smallholding::orchard::annualFruitYield
            + Smallholding::poultry::dailyEggYield * 365.0
            + Smallholding::goats::dailyMilkYield * 305.0
            >= Smallholding::annualFoodProductionTarget
        }
    }

    requirement def SoilFertilityRequirement {
        doc /* The smallholding shall recycle livestock manure into mature compost for use in vegetable and orchard production. */

        require constraint {
            Smallholding::composting::targetMaturityFraction >= 0.80
        }
    }

    requirement def AnimalCareRequirement {
        doc /* The smallholding shall provide livestock with daily feed and water flows through managed storage, harvested water, and routine husbandry behaviors. */

        require constraint {
            Smallholding::feedStorage::storageCapacity
            >= (Smallholding::poultry::dailyFeedDemand + Smallholding::goats::dailyFeedDemand) * 30.0
        }
    }

    requirement def RenewableEnergyRequirement {
        doc /* The smallholding shall use on-site renewable electrical generation to support irrigation pumping and basic farm control loads. */

        require constraint {
            Smallholding::solarPower::peakPower >= 5000.0 [SI::watt]
        }
    }

    satisfy PrimaryFunctionRequirement by Smallholding;
    satisfy WaterResilienceRequirement by Smallholding::rainwaterSystem;
    satisfy FoodProductionRequirement by Smallholding;
    satisfy SoilFertilityRequirement by Smallholding::composting;
    satisfy AnimalCareRequirement by Smallholding;
    satisfy RenewableEnergyRequirement by Smallholding::solarPower;
}