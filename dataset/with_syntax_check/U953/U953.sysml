package DemoticHomeAutomationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RoomOccupancy {
		attribute isOccupied : Boolean;
		attribute personCount : Integer;
		attribute lastDetectionTime : TimeValue;
	}
	
	attribute def ClimateConditions {
		attribute temperature : TemperatureValue;
		attribute humidity : Real;
		attribute airQuality : Real;
	}
	
	attribute def LightingState {
		attribute brightness : Real;
		attribute colorTemperature : Real;
		attribute isOn : Boolean;
	}
	
	attribute def SecurityStatus {
		attribute isArmed : Boolean;
		attribute intrusionDetected : Boolean;
		attribute doorLocked : Boolean;
	}
	
	item def ClimateCommand {
		attribute targetTemperature : TemperatureValue;
		attribute targetHumidity : Real;
		attribute fanSpeed : Real;
	}
	
	item def LightingCommand {
		attribute targetBrightness : Real;
		attribute targetColorTemp : Real;
		attribute powerOn : Boolean;
	}
	
	item def SecurityCommand {
		attribute armSystem : Boolean;
		attribute lockDoors : Boolean;
		attribute activateAlarm : Boolean;
	}
	
	enum def SystemMode {
		home;
		away;
		sleep;
		vacation;
	}
	
	port def OccupancySensorPort {
		out occupancyData : RoomOccupancy;
	}
	
	port def ClimateSensorPort {
		out climateData : ClimateConditions;
	}
	
	port def LightSensorPort {
		out lightData : LightingState;
	}
	
	port def ClimateControlPort {
		in climateCmd : ClimateCommand;
	}
	
	port def LightControlPort {
		in lightCmd : LightingCommand;
	}
	
	port def SecurityControlPort {
		in securityCmd : SecurityCommand;
	}
	
	part def MotionSensor {
		port occupancyOut : OccupancySensorPort;
		attribute detectionRange : LengthValue;
		attribute sensitivity : Real;
		
		action detectMotion {
			out detected : RoomOccupancy;
		}
	}
	
	part def EnvironmentalSensor {
		port climateOut : ClimateSensorPort;
		attribute measurementAccuracy : Real;
		
		action measureEnvironment {
			out conditions : ClimateConditions;
		}
	}
	
	part def AmbientLightSensor {
		port lightOut : LightSensorPort;
		attribute luxRange : Real;
		
		action measureAmbientLight {
			out lightLevel : LightingState;
		}
	}
	
	part def HVACController {
		port climateIn : ClimateControlPort;
		attribute currentPower : PowerValue;
		attribute efficiency : Real;
		
		action adjustClimate {
			in command : ClimateCommand;
			out powerConsumption : PowerValue;
		}
	}
	
	part def SmartLighting {
		port lightIn : LightControlPort;
		attribute currentPower : PowerValue;
		attribute maxBrightness : Real;
		
		action adjustLights {
			in command : LightingCommand;
			out powerConsumption : PowerValue;
		}
	}
	
	part def SecuritySystem {
		port securityIn : SecurityControlPort;
		attribute alarmActive : Boolean;
		attribute camerasActive : Boolean;
		
		action manageSecurity {
			in command : SecurityCommand;
			out status : SecurityStatus;
		}
	}
	
	part def DemoticController {
		attribute operatingMode : SystemMode;
		attribute userPreferences : ClimateConditions;
		attribute energyBudget : EnergyValue;
		attribute totalPowerUsage : PowerValue;
		
		port occupancyInput : OccupancySensorPort;
		port climateInput : ClimateSensorPort;
		port lightInput : LightSensorPort;
		port hvacOutput : ClimateControlPort;
		port lightingOutput : LightControlPort;
		port securityOutput : SecurityControlPort;
		
		action evaluateConditions {
			in occupancy : RoomOccupancy;
			in climate : ClimateConditions;
			in lighting : LightingState;
			in mode : SystemMode;
			out climateAction : ClimateCommand;
			out lightAction : LightingCommand;
			out securityAction : SecurityCommand;
		}
		
		action optimizeEnergy {
			in currentUsage : PowerValue;
			in budget : EnergyValue;
			in occupancy : RoomOccupancy;
			out adjustedClimate : ClimateCommand;
			out adjustedLighting : LightingCommand;
		}
	}
	
	part def DemoticHome {
		part motionDetector : MotionSensor;
		part envSensor : EnvironmentalSensor;
		part lightSensor : AmbientLightSensor;
		part hvacUnit : HVACController;
		part lightingSystem : SmartLighting;
		part securityUnit : SecuritySystem;
		part centralController : DemoticController;
		
		connect motionDetector.occupancyOut to centralController.occupancyInput;
		connect envSensor.climateOut to centralController.climateInput;
		connect lightSensor.lightOut to centralController.lightInput;
		connect centralController.hvacOutput to hvacUnit.climateIn;
		connect centralController.lightingOutput to lightingSystem.lightIn;
		connect centralController.securityOutput to securityUnit.securityIn;
	}
	
	action def AutomateHomeEnvironment {
		first start;
		then merge operationLoop;
		
		action collectSensorData {
			out occupancyInfo : RoomOccupancy;
			out climateInfo : ClimateConditions;
			out lightInfo : LightingState;
		}
		then action analyzeEnvironment {
			in occupancy : RoomOccupancy = collectSensorData.occupancyInfo;
			in climate : ClimateConditions = collectSensorData.climateInfo;
			in light : LightingState = collectSensorData.lightInfo;
			out climateStrategy : ClimateCommand;
			out lightStrategy : LightingCommand;
			out securityStrategy : SecurityCommand;
		}
		then decide;
			if analyzeEnvironment.occupancy.isOccupied then occupiedMode;
			if not analyzeEnvironment.occupancy.isOccupied then unoccupiedMode;
		
		action occupiedMode {
			action adjustComfort {
				in climateCmd : ClimateCommand = analyzeEnvironment.climateStrategy;
				in lightCmd : LightingCommand = analyzeEnvironment.lightStrategy;
			}
			then action disarmSecurity {
				in secCmd : SecurityCommand = analyzeEnvironment.securityStrategy;
			}
		}
		then operationLoop;
		
		action unoccupiedMode {
			action minimizeEnergy {
				in climateCmd : ClimateCommand = analyzeEnvironment.climateStrategy;
				in lightCmd : LightingCommand = analyzeEnvironment.lightStrategy;
			}
			then action armSecurity {
				in secCmd : SecurityCommand = analyzeEnvironment.securityStrategy;
			}
		}
		then operationLoop;
	}
	
	requirement def ComfortMaintenance {
		doc /* The system shall maintain indoor climate within user-defined comfort parameters when occupants are present. */
		
		require constraint temperatureComfort {
			293.15[K] <= centralController.climateInput.climateData.temperature and
			centralController.climateInput.climateData.temperature <= 297.15[K]
		}
		
		require constraint humidityComfort {
			30.0 <= centralController.climateInput.climateData.humidity and
			centralController.climateInput.climateData.humidity <= 60.0
		}
	}
	
	requirement def EnergyOptimization {
		doc /* The system shall reduce energy consumption by at least 40% when the home is unoccupied. */
		
		attribute energyReductionTarget : Real = 0.4;
		
		require constraint unoccupiedEnergyReduction {
			not centralController.occupancyInput.occupancyData.isOccupied implies
			centralController.totalPowerUsage <= 0.6 * centralController.totalPowerUsage
		}
	}
	
	requirement def SecurityAutomation {
		doc /* The system shall automatically arm security and lock doors when no occupancy is detected for more than 5 minutes. */
		
		attribute armingDelay : TimeValue = 300.0[s];
	}
	
	requirement def ResponsiveControl {
		doc /* The system shall respond to environmental changes within 15 seconds of detection. */
		
		attribute maxResponseTime : TimeValue = 15.0[s];
	}
	
	requirement <'DEM-SYS-001'> demoticSystemRequirements {
		doc /* The demotic home automation system shall provide intelligent, energy-efficient management 
		       of climate, lighting, and security based on occupancy and environmental conditions to 
		       enhance comfort, safety, and sustainability. */
		
		subject homeSystem : DemoticHome;
		
		assume constraint sensorsOperational {
			homeSystem.motionDetector.detectionRange > 0.0[m] and
			homeSystem.envSensor.measurementAccuracy > 0.0
		}
		
		require comfortReq : ComfortMaintenance;
		require energyReq : EnergyOptimization;
		require securityReq : SecurityAutomation;
		require responseReq : ResponsiveControl;
	}
	
	part automatedHome : DemoticHome {
		perform action homeAutomation[*] ordered references AutomateHomeEnvironment;
		
		part :>> motionDetector {
			detectionRange := 8.0[m];
			sensitivity := 0.85;
			perform homeAutomation.collectSensorData;
		}
		
		part :>> envSensor {
			measurementAccuracy := 0.95;
			perform homeAutomation.collectSensorData;
		}
		
		part :>> lightSensor {
			luxRange := 1000.0;
			perform homeAutomation.collectSensorData;
		}
		
		part :>> centralController {
			userPreferences.temperature := 295.15[K];
			userPreferences.humidity := 45.0;
			energyBudget := 50.0[kW*h];
			perform homeAutomation.analyzeEnvironment;
		}
		
		part :>> hvacUnit {
			efficiency := 0.92;
			perform homeAutomation.occupiedMode.adjustComfort;
			perform homeAutomation.unoccupiedMode.minimizeEnergy;
		}
		
		part :>> lightingSystem {
			maxBrightness := 100.0;
			perform homeAutomation.occupiedMode.adjustComfort;
			perform homeAutomation.unoccupiedMode.minimizeEnergy;
		}
		
		part :>> securityUnit {
			perform homeAutomation.occupiedMode.disarmSecurity;
			perform homeAutomation.unoccupiedMode.armSecurity;
		}
	}
}
