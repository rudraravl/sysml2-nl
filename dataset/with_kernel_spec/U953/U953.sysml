package 'Intelligent Home Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def OccupancyDetected;
	attribute def UnoccupiedTimeout;
	attribute def SleepModeSignal;
	attribute def HomeModeSignal;

	item def MotionDetection {
		attribute roomOccupied : Boolean = true;
		attribute roomId : String = "living_room";
	}

	item def EnvironmentalData {
		attribute temperature : TemperatureValue = 22;
		attribute humidity : Real = 45;
		attribute airQuality : Real = 50;
	}

	item def AmbientLightData {
		attribute brightness : Real = 500;
	}

	item def HVACCommand {
		attribute targetTemperature : TemperatureValue;
		attribute mode : String;
	}

	item def ComfortHVACCommand :> HVACCommand {
		:>> targetTemperature = 22;
		:>> mode = "comfort";
	}

	item def EcoHVACCommand :> HVACCommand {
		:>> targetTemperature = 16;
		:>> mode = "eco";
	}

	item def SleepHVACCommand :> HVACCommand {
		:>> targetTemperature = 18;
		:>> mode = "comfort";
	}

	item def LightingCommand {
		attribute brightness : Real;
		attribute color : String;
		attribute roomId : String;
		attribute on : Boolean;
	}

	item def ComfortLightingCommand :> LightingCommand {
		:>> brightness = 100;
		:>> color = "white";
		:>> roomId = "all";
		:>> on = true;
	}

	item def LightsOffCommand :> LightingCommand {
		:>> brightness = 0;
		:>> color = "white";
		:>> roomId = "all";
		:>> on = false;
	}

	item def SleepLightingCommand :> LightingCommand {
		:>> brightness = 10;
		:>> color = "warm";
		:>> roomId = "bedroom";
		:>> on = true;
	}

	item def SecurityCommand {
		attribute arm : Boolean;
		attribute lockDoors : Boolean;
	}

	item def ArmSecurityCommand :> SecurityCommand {
		:>> arm = true;
		:>> lockDoors = true;
	}

	item def DisarmSecurityCommand :> SecurityCommand {
		:>> arm = false;
		:>> lockDoors = false;
	}

	action def AnalyzeSensorData {
		in motionData : MotionDetection;
		in envData : EnvironmentalData;
		in lightData : AmbientLightData;
	}

	action def SenseMotion {
		out motionData : MotionDetection;
	}

	action def SenseEnvironment {
		out envData : EnvironmentalData;
	}

	action def SenseAmbientLight {
		out lightData : AmbientLightData;
	}

	action def ControlHVAC {
		in hvacCommand : HVACCommand;
	}

	action def ControlLighting {
		in lightingCommand : LightingCommand;
	}

	action def ControlSecurity {
		in securityCommand : SecurityCommand;
	}

	state def ControllerStates;

	part def MotionSensor {
		port motionDataPort { out motionData : MotionDetection; }
		attribute roomId : String;
	}

	part def EnvironmentalSensor {
		port envDataPort { out envData : EnvironmentalData; }
	}

	part def AmbientLightSensor {
		port lightDataPort { out lightData : AmbientLightData; }
	}

	part def HVACController {
		port hvacCmdPort { in hvacCommand : HVACCommand; }
		attribute currentTemperature : TemperatureValue;
		attribute operatingMode : String;
	}

	part def SmartLightingSystem {
		port lightingCmdPort { in lightingCommand : LightingCommand; }
		attribute brightness : Real;
		attribute color : String;
		attribute on : Boolean;
	}

	part def SecuritySystem {
		port securityCmdPort { in securityCommand : SecurityCommand; }
		attribute armed : Boolean;
		attribute doorsLocked : Boolean;
	}

	part def CentralController {
		port motionDataPort { in motionData : MotionDetection; }
		port envDataPort { in envData : EnvironmentalData; }
		port lightDataPort { in lightData : AmbientLightData; }
		port hvacCmdPort { out hvacCommand : HVACCommand; }
		port lightingCmdPort { out lightingCommand : LightingCommand; }
		port securityCmdPort { out securityCommand : SecurityCommand; }

		attribute comfortTemp : TemperatureValue = 22;
		attribute ecoTemp : TemperatureValue = 16;
		attribute sleepTemp : TemperatureValue = 18;
		attribute unoccupiedThreshold : Real = 1800;

		exhibit state 'controller states' : ControllerStates;
	}

	part def Home;

	requirement def ComfortRequirement {
		doc /* The system shall maintain comfortable temperature and humidity when the home is occupied. */
		subject homeSystem : Home;
	}

	requirement def EnergyEfficiencyRequirement {
		doc /* The system shall switch to energy-saving settings when the house is unoccupied. */
		subject homeSystem : Home;
	}

	requirement def SecurityRequirement {
		doc /* The system shall automatically arm the security system after the house has been unoccupied for a set period and disarm when residents return. */
		subject homeSystem : Home;
	}

	requirement def LightingAutomationRequirement {
		doc /* The system shall turn lights on when a room is occupied and off when unoccupied, adjusting for natural daylight. */
		subject homeSystem : Home;
	}

	part homeAutomationSystem : Home {
		part centralController : CentralController {
			exhibit state 'controller states' : ControllerStates {
				entry; then home;

				state home {
					entry action sendComfortCommands {
						action sendHVAC send new ComfortHVACCommand() to hvacCmdPort;
						then action sendLighting send new ComfortLightingCommand() to lightingCmdPort;
						then action sendSecurityDisarm send new DisarmSecurityCommand() to securityCmdPort;
					}
					do action analyzeData : AnalyzeSensorData {
						in motionData = motionDataPort.motionData;
						in envData = envDataPort.envData;
						in lightData = lightDataPort.lightData;
					}
				}
				accept SleepModeSignal
					then sleep;
				accept UnoccupiedTimeout
					then away;

				state away {
					entry action activateAwayMode {
						action sendEcoHVAC send new EcoHVACCommand() to hvacCmdPort;
						then action sendLightsOff send new LightsOffCommand() to lightingCmdPort;
						then action sendArmSecurity send new ArmSecurityCommand() to securityCmdPort;
					}
				}
				accept OccupancyDetected
					then home;

				state sleep {
					entry action activateSleepMode {
						action sendSleepHVAC send new SleepHVACCommand() to hvacCmdPort;
						then action sendBedroomLight send new SleepLightingCommand() to lightingCmdPort;
					}
				}
				accept HomeModeSignal
					then home;
			}
		}

		part motionSensors : MotionSensor[3] {
			action sensingBehavior {
				action sendMotionData send new MotionDetection() to centralController;
			}
		}

		part environmentalSensors : EnvironmentalSensor[2] {
			action sensingBehavior {
				action sendEnvData send new EnvironmentalData() to centralController;
			}
		}

		part ambientLightSensors : AmbientLightSensor[2] {
			action sensingBehavior {
				action sendLightData send new AmbientLightData() to centralController;
			}
		}

		part hvacController : HVACController {
			action hvacBehavior {
				action receiveCommand accept HVACCommand;
				then action controlClimate : ControlHVAC {
					in hvacCommand = hvacCmdPort.hvacCommand;
				}
			}
		}

		part smartLighting : SmartLightingSystem {
			action lightingBehavior {
				action receiveCommand accept LightingCommand;
				then action controlLights : ControlLighting {
					in lightingCommand = lightingCmdPort.lightingCommand;
				}
			}
		}

		part securitySystem : SecuritySystem {
			action securityBehavior {
				action receiveCommand accept SecurityCommand;
				then action controlSecurity : ControlSecurity {
					in securityCommand = securityCmdPort.securityCommand;
				}
			}
		}

		flow motionDataFlow of MotionDetection
			from motionSensors.motionDataPort.motionData to centralController.motionDataPort.motionData;
		flow envDataFlow of EnvironmentalData
			from environmentalSensors.envDataPort.envData to centralController.envDataPort.envData;
		flow lightDataFlow of AmbientLightData
			from ambientLightSensors.lightDataPort.lightData to centralController.lightDataPort.lightData;

		flow hvacCommandFlow of HVACCommand
			from centralController.hvacCmdPort.hvacCommand to hvacController.hvacCmdPort.hvacCommand;
		flow lightingCommandFlow of LightingCommand
			from centralController.lightingCmdPort.lightingCommand to smartLighting.lightingCmdPort.lightingCommand;
		flow securityCommandFlow of SecurityCommand
			from centralController.securityCmdPort.securityCommand to securitySystem.securityCmdPort.securityCommand;
	}

	requirement comfortReq : ComfortRequirement {
		subject :>> homeSystem :>> homeAutomationSystem;
	}
	requirement energyEfficiencyReq : EnergyEfficiencyRequirement {
		subject :>> homeSystem :>> homeAutomationSystem;
	}
	requirement securityReq : SecurityRequirement {
		subject :>> homeSystem :>> homeAutomationSystem;
	}
	requirement lightingAutomationReq : LightingAutomationRequirement {
		subject :>> homeSystem :>> homeAutomationSystem;
	}
}
