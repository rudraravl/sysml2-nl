package 'Agricultural Robot System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def BatteryCharge :> Real;
	attribute def SoilMoisture :> Real;
	attribute def CropHealth :> Real;
	attribute def HarvestYield :> Real;

	enum def OperationMode {
		enum idle;
		enum surveying;
		enum planting;
		enum watering;
		enum harvesting;
		enum charging;
		enum error;
	}

	enum def CropStatus {
		enum seedling;
		enum growing;
		enum mature;
		enum harvested;
	}

	item def FieldData {
		attribute soilMoisture : SoilMoisture;
		attribute cropHealth : CropHealth;
		attribute location : Position;
	}

	item def Position {
		attribute x : LengthValue;
		attribute y : LengthValue;
	}

	item def HarvestData {
		attribute yield : HarvestYield;
		attribute timestamp : DurationValue;
		attribute position : Position;
	}

	port def SensorPort {
		out fieldData : FieldData;
	}

	port def ActuatorPort {
		in command : OperationMode;
	}

	port def PowerPort {
		attribute voltage : Real;
		attribute current : Real;
	}

	port def NavigationPort {
		in targetPosition : Position;
		out currentPosition : Position;
	}

	action def SurveyField {
		out fieldData : FieldData;
	}

	action def PlantSeeds {
		in position : Position;
	}

	action def WaterCrops {
		in soilMoisture : SoilMoisture;
		in position : Position;
	}

	action def HarvestCrops {
		in cropHealth : CropHealth;
		out harvestData : HarvestData;
	}

	action def NavigateToPosition {
		in targetPosition : Position;
		in currentPosition : Position;
	}

	action def ChargeBattery {
		in currentCharge : BatteryCharge;
		out finalCharge : BatteryCharge;
	}

	package LogicalModel {
		action def PerformAgriculturalTask;
		action def MonitorField;
		action def ExecutePlanting;
		action def ExecuteWatering;
		action def ExecuteHarvesting;

		part def FieldOperator;

		action agriculturalOperation : PerformAgriculturalTask {
			first start;
			then merge continueOperation;
			then action monitor : MonitorField {
				out fieldCondition : FieldData;
			}
			then decide;
				if monitor.fieldCondition.soilMoisture < 30.0 then water;
				if monitor.fieldCondition.cropHealth >= 90.0 then harvest;
				if monitor.fieldCondition.cropHealth < 10.0 then plant;
			action plant : ExecutePlanting;
			then continueOperation;
			action water : ExecuteWatering;
			then continueOperation;
			action harvest : ExecuteHarvesting;
			then continueOperation;
		}

		part fieldOperator : FieldOperator {
			perform agriculturalOperation.monitor;
			perform agriculturalOperation.plant;
			perform agriculturalOperation.water;
			perform agriculturalOperation.harvest;
		}
	}

	package PhysicalModel {
		private import LogicalModel::*;

		part def Sensor {
			attribute sensorId : String;
			port sensorOutput : SensorPort;
		}

		part def SoilSensor :> Sensor {
			attribute measurementDepth : LengthValue;
		}

		part def VisionSensor :> Sensor {
			attribute resolution : String;
			attribute fieldOfView : AngleValue;
		}

		part def GPSModule {
			attribute accuracy : LengthValue;
			port navPort : NavigationPort;
		}

		part def PlantingMechanism {
			attribute seedCapacity : Integer;
			attribute plantingRate : FrequencyValue;

			action executePlant : PlantSeeds {
				in plantPosition : Position;
			}
		}

		part def WateringSystem {
			attribute waterCapacity : VolumeValue;
			attribute flowRate : Real;

			action executeWater : WaterCrops {
				in moisture : SoilMoisture;
				in waterPosition : Position;
			}
		}

		part def HarvestingMechanism {
			attribute storageCapacity : VolumeValue;
			attribute harvestingSpeed : SpeedValue;

			action executeHarvest : HarvestCrops {
				in health : CropHealth;
				out harvest : HarvestData;
			}
		}

		part def BatteryPack {
			attribute capacity : EnergyValue;
			attribute chargeLevel : BatteryCharge;
			port powerOutput : PowerPort;
		}

		part def ControlUnit {
			attribute processorSpeed : FrequencyValue;
			port controlPort : ActuatorPort;

			perform action controlLoop {
				first start;
				then merge loop;
				then action survey : SurveyField;
				then decide;
					if survey.fieldData.soilMoisture < 30.0 then waterCrops;
					if survey.fieldData.cropHealth >= 90.0 then harvestCrops;
					if survey.fieldData.cropHealth < 10.0 then plantSeeds;
				action plantSeeds : PlantSeeds;
				then loop;
				action waterCrops : WaterCrops;
				then loop;
				action harvestCrops : HarvestCrops;
				then loop;
			}
		}

		part def MobilitySystem {
			attribute maxSpeed : SpeedValue;
			attribute wheelDiameter : LengthValue;

			action navigate : NavigateToPosition;
		}

		part def AgriculturalRobot {
			attribute robotId : String;
			attribute operationalMode : OperationMode;
			attribute batteryCharge : BatteryCharge;

			part soilSensor : SoilSensor {
				:>> measurementDepth = 0.2[m];
				:>> sensorId = "SOIL-01";
			}

			part visionSensor : VisionSensor {
				:>> resolution = "1920x1080";
				:>> fieldOfView = 120.0[deg];
				:>> sensorId = "VIS-01";
			}

			part gpsModule : GPSModule {
				:>> accuracy = 0.02[m];
			}

			part planter : PlantingMechanism {
				:>> seedCapacity = 1000;
				:>> plantingRate = 5.0[Hz];
			}

			part wateringSystem : WateringSystem {
				:>> waterCapacity = 100.0[L];
				:>> flowRate = 2.0;
			}

			part harvester : HarvestingMechanism {
				:>> storageCapacity = 200.0[L];
				:>> harvestingSpeed = 0.5[m/s];
			}

			part battery : BatteryPack {
				:>> capacity = 100000.0[J];
				:>> chargeLevel = 100.0;
			}

			part controller : ControlUnit {
				:>> processorSpeed = 3.0[Hz];
			}

			part mobility : MobilitySystem {
				:>> maxSpeed = 2.0[m/s];
				:>> wheelDiameter = 0.5[m];
			}

			connection powerDistribution connect battery.powerOutput to controller.controlPort;
			connection sensorData1 connect soilSensor.sensorOutput to controller.controlPort;
			connection sensorData2 connect visionSensor.sensorOutput to controller.controlPort;
			connection navigationData connect gpsModule.navPort to controller.controlPort;
		}

		part def Field {
			attribute fieldSize : AreaValue;
			attribute cropType : String;
			attribute currentStatus : CropStatus;
		}

		part def ChargingStation {
			attribute chargingPower : PowerValue;
			port chargingPort : PowerPort;
		}

		part agriculturalRobotSystem : AgriculturalRobot {
			:>> robotId = "AGRI-BOT-001";
			:>> operationalMode = OperationMode::idle;
			:>> batteryCharge = 100.0;

			perform agriculturalOperation.monitor;
			perform agriculturalOperation.plant;
			perform agriculturalOperation.water;
			perform agriculturalOperation.harvest;
		}

		part field : Field {
			:>> fieldSize = 5000.0[m^2];
			:>> cropType = "Wheat";
			:>> currentStatus = CropStatus::growing;
		}

		part chargingStation : ChargingStation {
			:>> chargingPower = 10000.0[W];
		}

		connection fieldOperations connect agriculturalRobotSystem to field;
		connection chargingLink connect chargingStation.chargingPort to agriculturalRobotSystem.battery.powerOutput;

		allocation def LogicalToPhysical {
			end logical : LogicalModel::FieldOperator;
			end physical : AgriculturalRobot;
		}

		allocate fieldOperator to agriculturalRobotSystem {
			allocate fieldOperator.monitor to agriculturalRobotSystem.controller.controlLoop.survey;
			allocate fieldOperator.plant to agriculturalRobotSystem.planter.executePlant;
			allocate fieldOperator.water to agriculturalRobotSystem.wateringSystem.executeWater;
			allocate fieldOperator.harvest to agriculturalRobotSystem.harvester.executeHarvest;
		}
	}

	requirement def SystemRequirement {
		doc /* Base requirement for agricultural robot system */
		subject robot : PhysicalModel::AgriculturalRobot;
	}

	requirement operationalEfficiency : SystemRequirement {
		doc /* Robot must maintain minimum operational efficiency */
		subject agriRobot : PhysicalModel::AgriculturalRobot;

		require constraint {
			agriRobot.harvester.harvestingSpeed >= 0.3[m/s]
		}
	}

	requirement batteryCapacity : SystemRequirement {
		doc /* Robot must have sufficient battery capacity for extended operation */
		subject agriRobot : PhysicalModel::AgriculturalRobot;

		require constraint {
			agriRobot.battery.capacity >= 80000.0[J]
		}
	}

	requirement navigationAccuracy : SystemRequirement {
		doc /* Robot must maintain precise navigation for accurate field operations */
		subject agriRobot : PhysicalModel::AgriculturalRobot;

		require constraint {
			agriRobot.gpsModule.accuracy <= 0.05[m]
		}
	}

	requirement wateringCapacity : SystemRequirement {
		doc /* Robot must have adequate water capacity for field coverage */
		subject agriRobot : PhysicalModel::AgriculturalRobot;

		require constraint {
			agriRobot.wateringSystem.waterCapacity >= 80.0[L]
		}
	}

	verification def VerifyAgriculturalRobotPerformance {
		subject testRobot : PhysicalModel::AgriculturalRobot;

		objective verifyEfficiency {
			verify operationalEfficiency;
		}

		objective verifyBattery {
			verify batteryCapacity;
		}

		objective verifyNavigation {
			verify navigationAccuracy;
		}

		objective verifyWatering {
			verify wateringCapacity;
		}
	}

	individual def TestField :> PhysicalModel::Field;
	individual def TestAgriculturalRobot :> PhysicalModel::AgriculturalRobot;

	individual testScenario : TestAgriculturalRobot :> PhysicalModel::agriculturalRobotSystem {
		:>> robotId = "TEST-AGRI-001";
		:>> batteryCharge = 100.0;

		timeslice initialization {
			:>> operationalMode = OperationMode::idle;
		}
		then timeslice fieldSurvey {
			:>> operationalMode = OperationMode::surveying;
			perform action surveyTask : SurveyField {
				out surveyData : FieldData {
					:>> soilMoisture = 25.0;
					:>> cropHealth = 95.0;
					:>> location.x = 10.0[m];
					:>> location.y = 15.0[m];
				}
			}
		}
		then timeslice harvestOperation {
			:>> operationalMode = OperationMode::harvesting;
			perform action harvestTask : HarvestCrops {
				in cropHealth = 95.0;
				out harvestResult : HarvestData {
					:>> yield = 150.0;
				}
			}
		}
		then timeslice returnToStation {
			:>> operationalMode = OperationMode::idle;
		}
	}
}
