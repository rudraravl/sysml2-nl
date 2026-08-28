package 'Sustainable Smallholding Farm' {
	private import ScalarValues::*;

	attribute def Liter :> Real;
	attribute def Kilogram :> Real;
	attribute def Celsius :> Real;
	attribute def Hectare :> Real;

	attribute def WaterVolume :> Real;
	attribute def MassQuantity :> Real;
	attribute def TemperatureValue :> Real;
	attribute def FieldArea :> Real;

	item def FreshWater {
		attribute volume : WaterVolume;
	}
	item def Manure {
		attribute mass : MassQuantity;
	}
	item def FoodItem;
	item def HarvestedCrop :> FoodItem {
		attribute name : String;
		attribute yieldMass : MassQuantity;
	}
	item def AnimalProduct :> FoodItem {
		attribute name : String;
		attribute quantity : MassQuantity;
	}

	port def WaterPort {
		out item water : FreshWater;
	}
	port def WaterInPort {
		in item water : FreshWater;
	}
	port def ManurePort {
		out item manure : Manure;
	}
	port def ManureInPort {
		in item manure : Manure;
	}
	port def CropPort {
		out item crop : HarvestedCrop;
	}
	port def ProductPort {
		out item product : AnimalProduct;
	}
	port def FoodInPort {
		in item food : FoodItem;
	}

	part def Well {
		port waterOut : WaterPort;
		attribute maxCapacity : WaterVolume = 10000;
		attribute currentLevel : WaterVolume = 8000;
	}

	part def WaterDistributionSystem {
		port waterIn : WaterInPort;
		port toNorthField : WaterPort;
		port toSouthField : WaterPort;
		port toLivestock : WaterPort;
		attribute northFieldAllocation : WaterVolume = 0;
		attribute southFieldAllocation : WaterVolume = 0;
		attribute livestockAllocation : WaterVolume = 0;
	}

	part def CultivationField {
		port irrigationIn : WaterInPort;
		port fertilizerIn : ManureInPort;
		port cropOut : CropPort;
		attribute name : String;
		attribute area : FieldArea;
		attribute soilMoisture : WaterVolume = 0;
		attribute fertilityLevel : Real = 0.5;
		attribute cropType : String;
	}

	part def NorthField :> CultivationField {
		attribute redefines name = "North Field";
		attribute redefines area = 1.5;
		attribute redefines cropType = "Wheat";
	}

	part def SouthField :> CultivationField {
		attribute redefines name = "South Field";
		attribute redefines area = 1.0;
		attribute redefines cropType = "Vegetables";
	}

	part def LivestockShelter {
		port waterIn : WaterInPort;
		port manureOut : ManurePort;
		port productOut : ProductPort;
		attribute animalCount : Integer = 20;
		attribute dailyWaterNeed : WaterVolume = 200;
		attribute dailyFeedNeed : MassQuantity = 40;
		attribute manureProduced : MassQuantity = 0;
	}

	part def StorageFacility {
		port foodIn : FoodInPort;
		attribute temperature : TemperatureValue = 4;
		attribute capacity : MassQuantity = 2000;
		attribute currentStock : MassQuantity = 0;
	}

	requirement def SustainabilityRequirement {
		doc /* The farm must operate as a self-sufficient agricultural ecosystem. */
	}

	requirement def WaterConservationRequirement {
		doc /* Water from the well must be efficiently distributed to crops and livestock. */
		subject distributionSystem : WaterDistributionSystem;
	}

	requirement def SoilFertilityRequirement {
		doc /* Manure from livestock must be used as organic fertilizer for the fields. */
		subject shelter : LivestockShelter;
	}

	requirement def AnimalWelfareRequirement {
		doc /* Animals must receive adequate water and feed daily. */
		subject shelter : LivestockShelter;
	}

	requirement def StorageRequirement {
		doc /* All harvested food must be stored at controlled temperature. */
		subject storage : StorageFacility;
	}

	state def FarmOperationalStates;
	state farmStates : FarmOperationalStates {
		entry; then assessing;
		state assessing;
		transition assessing -> planning;
		state planning;
		transition planning -> executing;
		state executing;
		transition executing -> harvesting;
		state harvesting;
		transition harvesting -> storing;
		state storing;
		transition storing -> assessing;
	}

	action def AssessEnvironmentalConditions {
		out temperature : TemperatureValue;
		out humidity : Real;
		out rainfall : WaterVolume;
		out northSoilMoisture : WaterVolume;
		out southSoilMoisture : WaterVolume;
	}

	action def CalculateWaterNeeds {
		in northSoilMoisture : WaterVolume;
		in southSoilMoisture : WaterVolume;
		in animalCount : Integer;
		out northFieldWater : WaterVolume;
		out southFieldWater : WaterVolume;
		out livestockWater : WaterVolume;
	}

	action def PlanResourceAllocation {
		in totalWaterAvailable : WaterVolume;
		in northFieldWater : WaterVolume;
		in southFieldWater : WaterVolume;
		in livestockWater : WaterVolume;
		in manureAvailable : MassQuantity;
		out northAllocation : WaterVolume;
		out southAllocation : WaterVolume;
		out livestockAllocation : WaterVolume;
		out northFertilizer : MassQuantity;
		out southFertilizer : MassQuantity;
	}

	action def IrrigateFields {
		in waterAmount : WaterVolume;
	}

	action def FeedLivestock {
		in feedAmount : MassQuantity;
	}

	action def ApplyFertilizer {
		in fertilizerAmount : MassQuantity;
	}

	action def HarvestCrops {
		out crop : HarvestedCrop;
	}

	action def CollectAnimalProducts {
		out product : AnimalProduct;
	}

	action def StoreProduce {
		in foodItem : FoodItem;
	}

	action def FarmOperationalCycle {
		action assessConditions : AssessEnvironmentalConditions;
		action calculateNeeds : CalculateWaterNeeds;
		action planAllocation : PlanResourceAllocation;
		action irrigateNorth : IrrigateFields;
		action irrigateSouth : IrrigateFields;
		action feedAnimals : FeedLivestock;
		action fertilizeNorth : ApplyFertilizer;
		action fertilizeSouth : ApplyFertilizer;
		action harvestNorth : HarvestCrops;
		action harvestSouth : HarvestCrops;
		action collectProducts : CollectAnimalProducts;
		action storeNorthCrop : StoreProduce;
		action storeSouthCrop : StoreProduce;
		action storeProducts : StoreProduce;

		flow assessConditions.northSoilMoisture to calculateNeeds.northSoilMoisture;
		flow assessConditions.southSoilMoisture to calculateNeeds.southSoilMoisture;
		flow calculateNeeds.northFieldWater to planAllocation.northFieldWater;
		flow calculateNeeds.southFieldWater to planAllocation.southFieldWater;
		flow calculateNeeds.livestockWater to planAllocation.livestockWater;
		flow planAllocation.northAllocation to irrigateNorth.waterAmount;
		flow planAllocation.southAllocation to irrigateSouth.waterAmount;
		flow planAllocation.livestockAllocation to feedAnimals.feedAmount;
		flow planAllocation.northFertilizer to fertilizeNorth.fertilizerAmount;
		flow planAllocation.southFertilizer to fertilizeSouth.fertilizerAmount;
		flow harvestNorth.crop to storeNorthCrop.foodItem;
		flow harvestSouth.crop to storeSouthCrop.foodItem;
		flow collectProducts.product to storeProducts.foodItem;
	}

	part def SustainableFarm {
		doc /* An integrated and sustainable smallholding farm. */

		part well : Well;
		part distributionSystem : WaterDistributionSystem;
		part northField : NorthField;
		part southField : SouthField;
		part livestockShelter : LivestockShelter;
		part storageFacility : StorageFacility;

		connect well.waterOut to distributionSystem.waterIn;
		connect distributionSystem.toNorthField to northField.irrigationIn;
		connect distributionSystem.toSouthField to southField.irrigationIn;
		connect distributionSystem.toLivestock to livestockShelter.waterIn;
		connect livestockShelter.manureOut to northField.fertilizerIn;
		connect livestockShelter.manureOut to southField.fertilizerIn;
		connect northField.cropOut to storageFacility.foodIn;
		connect southField.cropOut to storageFacility.foodIn;
		connect livestockShelter.productOut to storageFacility.foodIn;

		perform action operationalCycle : FarmOperationalCycle;
		exhibit farmStates;

		requirement sustainability : SustainabilityRequirement;
		requirement waterConservation : WaterConservationRequirement {
			subject distributionSystem = distributionSystem;
		}
		requirement soilFertility : SoilFertilityRequirement {
			subject shelter = livestockShelter;
		}
		requirement animalWelfare : AnimalWelfareRequirement {
			subject shelter = livestockShelter;
		}
		requirement storageReq : StorageRequirement {
			subject storage = storageFacility;
		}
	}

	verification WaterDistributionVerification {
		doc /* Verify water distribution does not exceed well capacity. */
		subject distributionSystem : WaterDistributionSystem;
		objective {
			success if distributionSystem.northFieldAllocation +
				distributionSystem.southFieldAllocation +
				distributionSystem.livestockAllocation <= 10000;
		}
	}

	verification ManureCyclingVerification {
		doc /* Verify manure is produced and applied to fields. */
		subject shelter : LivestockShelter;
		objective {
			success if shelter.manureProduced > 0;
		}
	}
}
