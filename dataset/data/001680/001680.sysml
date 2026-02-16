package RotomaticSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def FlourIngredient {
		attribute mass : MassValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def WaterIngredient {
		attribute volume : VolumeValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def OilIngredient {
		attribute volume : VolumeValue;
	}
	
	item def DoughMixture {
		attribute totalMass : MassValue;
		attribute hydrationRatio : Real;
		attribute consistency : Real;
	}
	
	item def DoughBall {
		attribute mass : MassValue;
		attribute diameter : LengthValue;
	}
	
	item def FlattenedDough {
		attribute thickness : LengthValue;
		attribute diameter : LengthValue;
	}
	
	item def CookedFlatbread {
		attribute surfaceTemperature : ThermodynamicTemperatureValue;
		attribute cookingLevel : Real;
		attribute moisture : Real;
	}
	
	item def RecipeSettings {
		attribute flourAmount : MassValue;
		attribute waterAmount : VolumeValue;
		attribute oilAmount : VolumeValue;
		attribute thickness : LengthValue;
		attribute cookingTemperature : ThermodynamicTemperatureValue;
		attribute cookingDuration : TimeValue;
		attribute quantity : Integer;
	}
	
	port def IngredientPort;
	port def DoughPort;
	port def FlatbreadPort;
	port def ControlPort;
	
	part def FlourDispenser {
		out port flourOut : IngredientPort;
		attribute capacity : MassValue;
		attribute currentLevel : MassValue;
		
		action def DispenseFlour {
			in requestedAmount : MassValue;
			out flour : FlourIngredient;
		}
	}
	
	part def WaterDispenser {
		out port waterOut : IngredientPort;
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		
		action def DispenseWater {
			in requestedAmount : VolumeValue;
			out water : WaterIngredient;
		}
	}
	
	part def OilDispenser {
		out port oilOut : IngredientPort;
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		
		action def DispenseOil {
			in requestedAmount : VolumeValue;
			out oil : OilIngredient;
		}
	}
	
	part def MixingUnit {
		in port flourIn : IngredientPort;
		in port waterIn : IngredientPort;
		in port oilIn : IngredientPort;
		out port doughOut : DoughPort;
		
		attribute mixingSpeed : AngularVelocityValue;
		attribute mixingDuration : TimeValue;
		
		action def MixIngredients {
			in flour : FlourIngredient;
			in water : WaterIngredient;
			in oil : OilIngredient;
			out dough : DoughMixture;
		}
	}
	
	part def KneadingUnit {
		in port doughIn : DoughPort;
		out port kneadedDoughOut : DoughPort;
		
		attribute kneadingCycles : Integer;
		attribute kneadingForce : ForceValue;
		
		action def KneadDough {
			in rawDough : DoughMixture;
			out kneadedDough : DoughMixture;
		}
	}
	
	part def DoughDivider {
		in port bulkDoughIn : DoughPort;
		out port doughBallOut : DoughPort;
		
		attribute portionMass : MassValue;
		
		action def DivideDough {
			in bulkDough : DoughMixture;
			out doughBall : DoughBall;
		}
	}
	
	part def RollingUnit {
		in port doughBallIn : DoughPort;
		out port flattenedDoughOut : DoughPort;
		
		attribute targetThickness : LengthValue;
		attribute rollingPressure : PressureValue;
		
		action def RollDough {
			in doughBall : DoughBall;
			in thickness : LengthValue;
			out flattenedDough : FlattenedDough;
		}
	}
	
	part def CookingPlate {
		in port doughIn : DoughPort;
		out port flatbreadOut : FlatbreadPort;
		
		attribute plateTemperature : ThermodynamicTemperatureValue;
		attribute cookingTime : TimeValue;
		
		action def CookFlatbread {
			in flattenedDough : FlattenedDough;
			in temperature : ThermodynamicTemperatureValue;
			in duration : TimeValue;
			out cookedFlatbread : CookedFlatbread;
		}
	}
	
	part def OutputTray {
		in port flatbreadIn : FlatbreadPort;
		
		attribute capacity : Integer;
		attribute currentCount : Integer;
		
		action def CollectFlatbread {
			in flatbread : CookedFlatbread;
		}
	}
	
	part def SystemController {
		in port userInput : ControlPort;
		out port dispenserControl : ControlPort;
		out port mixerControl : ControlPort;
		out port kneaderControl : ControlPort;
		out port dividerControl : ControlPort;
		out port rollerControl : ControlPort;
		out port cookerControl : ControlPort;
		
		attribute currentRecipe : RecipeSettings;
		attribute remainingCount : Integer;
		attribute operatingMode : String;
		attribute ingredientsAvailable : Boolean;
		attribute systemReady : Boolean;
		attribute dispenseComplete : Boolean;
		attribute mixComplete : Boolean;
		attribute kneadComplete : Boolean;
		attribute divideComplete : Boolean;
		attribute rollComplete : Boolean;
		attribute cookComplete : Boolean;
		attribute collectComplete : Boolean;
	}
	
	action def ProduceFlatbread {
		in recipe : RecipeSettings;
		out completedFlatbread : CookedFlatbread;
		
		first start;
		then action dispenseFlour : FlourDispenser::DispenseFlour {
			in requestedAmount = recipe.flourAmount;
			out flour;
		}
		then action dispenseWater : WaterDispenser::DispenseWater {
			in requestedAmount = recipe.waterAmount;
			out water;
		}
		then action dispenseOil : OilDispenser::DispenseOil {
			in requestedAmount = recipe.oilAmount;
			out oil;
		}
		then action mixIngredients : MixingUnit::MixIngredients {
			in flour = dispenseFlour.flour;
			in water = dispenseWater.water;
			in oil = dispenseOil.oil;
			out dough;
		}
		then action kneadDough : KneadingUnit::KneadDough {
			in rawDough = mixIngredients.dough;
			out kneadedDough;
		}
		then merge portionLoop;
		then action divideDough : DoughDivider::DivideDough {
			in bulkDough = kneadDough.kneadedDough;
			out doughBall;
		}
		then action rollDough : RollingUnit::RollDough {
			in doughBall = divideDough.doughBall;
			in thickness = recipe.thickness;
			out flattenedDough;
		}
		then action cookFlatbread : CookingPlate::CookFlatbread {
			in flattenedDough = rollDough.flattenedDough;
			in temperature = recipe.cookingTemperature;
			in duration = recipe.cookingDuration;
			out cookedFlatbread;
		}
		then action collectFlatbread : OutputTray::CollectFlatbread {
			in flatbread = cookFlatbread.cookedFlatbread;
		}
		then decide;
			if portionsRemaining > 0 then portionLoop;
			if portionsRemaining <= 0 then done;
		
		private attribute portionsRemaining : Integer;
	}
	
	action def ProduceBatch {
		in recipe : RecipeSettings;
		out batch : CookedFlatbread[*] := ();
		
		for count in 1..recipe.quantity {
			perform produceSingle : ProduceFlatbread {
				in recipe = self.recipe;
				out completedFlatbread;
			}
			then assign batch := batch->including(produceSingle.completedFlatbread);
		}
	}
	
	part def Rotimatic {
		attribute maxFlourCapacity : MassValue;
		attribute maxWaterCapacity : VolumeValue;
		attribute maxOilCapacity : VolumeValue;
		attribute maxOutputCapacity : Integer;
		attribute averageProductionTime : TimeValue;
		
		part flourDispenser : FlourDispenser {
			attribute :>> capacity = 2000.0[g];
			perform productionBatch.produceSingle[*].dispenseFlour;
		}
		
		part waterDispenser : WaterDispenser {
			attribute :>> capacity = 1000.0[ml];
			perform productionBatch.produceSingle[*].dispenseWater;
		}
		
		part oilDispenser : OilDispenser {
			attribute :>> capacity = 200.0[ml];
			perform productionBatch.produceSingle[*].dispenseOil;
		}
		
		part mixingUnit : MixingUnit {
			attribute :>> mixingSpeed = 120.0[rpm];
			attribute :>> mixingDuration = 180.0[s];
			perform productionBatch.produceSingle[*].mixIngredients;
		}
		
		part kneadingUnit : KneadingUnit {
			attribute :>> kneadingCycles = 50;
			perform productionBatch.produceSingle[*].kneadDough;
		}
		
		part doughDivider : DoughDivider {
			attribute :>> portionMass = 60.0[g];
			perform productionBatch.produceSingle[*].divideDough;
		}
		
		part rollingUnit : RollingUnit {
			perform productionBatch.produceSingle[*].rollDough;
		}
		
		part cookingPlate : CookingPlate {
			attribute :>> plateTemperature = 493.15[K];
			attribute :>> cookingTime = 45.0[s];
			perform productionBatch.produceSingle[*].cookFlatbread;
		}
		
		part outputTray : OutputTray {
			attribute :>> capacity = 20;
			perform productionBatch.produceSingle[*].collectFlatbread;
		}
		
		part systemController : SystemController;
		
		connect flourDispenser.flourOut to mixingUnit.flourIn;
		connect waterDispenser.waterOut to mixingUnit.waterIn;
		connect oilDispenser.oilOut to mixingUnit.oilIn;
		connect mixingUnit.doughOut to kneadingUnit.doughIn;
		connect kneadingUnit.kneadedDoughOut to doughDivider.bulkDoughIn;
		connect doughDivider.doughBallOut to rollingUnit.doughBallIn;
		connect rollingUnit.flattenedDoughOut to cookingPlate.doughIn;
		connect cookingPlate.flatbreadOut to outputTray.flatbreadIn;
		
		perform action productionBatch : ProduceBatch;
	}
	
	requirement def AutomatedFlatbreadProduction {
		doc /* The system shall automatically produce fresh flatbreads from stored ingredients without manual intervention during the production cycle. */
		
		require constraint fullyAutomated {
			doc /* All production steps from ingredient dispensing through cooking and collection shall be automated. */
		}
	}
	
	requirement def ConsistentQuality {
		doc /* The system shall produce flatbreads with consistent thickness, diameter, and cooking level across all units in a batch. */
		
		attribute thicknessTolerance : LengthValue;
		attribute diameterTolerance : LengthValue;
		attribute cookingLevelTolerance : Real;
		
		require constraint thicknessConsistency {
			doc /* Flatbread thickness variation shall be within specified tolerance. */
		}
		
		require constraint cookingConsistency {
			doc /* Cooking level variation shall be within specified tolerance. */
		}
	}
	
	requirement def IngredientManagement {
		doc /* The system shall accurately dispense and manage ingredient quantities according to recipe specifications. */
		
		require constraint accurateDispensing {
			doc /* Ingredient dispensing accuracy shall be within 2 percent of target amounts. */
		}
		
		require constraint levelMonitoring {
			doc /* The system shall monitor ingredient levels and provide alerts when levels fall below minimum thresholds. */
		}
	}
	
	requirement def ProductionThroughput {
		doc /* The system shall maintain specified production throughput for continuous operation. */
		
		attribute maxCycleTime : TimeValue;
		attribute minBatchSize : Integer;
		
		require constraint cycleTimeCompliance {
			doc /* Single flatbread production cycle shall not exceed maximum cycle time. */
		}
	}
	
	requirement <'ROT-001'> primaryFunctionRequirement : AutomatedFlatbreadProduction {
		subject rotimatic;
		doc /* The Rotimatic shall automatically produce fresh flatbreads by dispensing precise quantities of flour, water, and oil, mixing and kneading them into dough, dividing the dough into portions, rolling each portion into a thin flatbread, cooking it on a heated plate to the specified level, and collecting the finished products in an output tray, repeating the process for the requested quantity. */
	}
	
	requirement <'ROT-002'> qualityRequirement : ConsistentQuality {
		subject rotimatic;
		attribute :>> thicknessTolerance = 0.3[mm];
		attribute :>> diameterTolerance = 5.0[mm];
		attribute :>> cookingLevelTolerance = 0.05;
	}
	
	requirement <'ROT-003'> ingredientRequirement : IngredientManagement {
		subject rotimatic;
	}
	
	requirement <'ROT-004'> throughputRequirement : ProductionThroughput {
		subject rotimatic;
		attribute :>> maxCycleTime = 90.0[s];
		attribute :>> minBatchSize = 10;
	}
	
	part rotimatic : Rotimatic {
		attribute :>> maxFlourCapacity = 2000.0[g];
		attribute :>> maxWaterCapacity = 1000.0[ml];
		attribute :>> maxOilCapacity = 200.0[ml];
		attribute :>> maxOutputCapacity = 20;
		attribute :>> averageProductionTime = 75.0[s];
	}
}
