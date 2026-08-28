package 'Life Support System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		// --- Value Definitions ---
		attribute def O2LevelValue :> Real;
		attribute def CO2LevelValue :> Real;
		attribute def PressureValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def HumidityValue :> Real;
		attribute def PurityValue :> Real;
		attribute def ContaminantLevel :> Real;

		// --- Item Definitions ---
		item def AtmosphereData {
			attribute o2Level : O2LevelValue;
			attribute co2Level : CO2LevelValue;
			attribute pressure : PressureValue;
			attribute temperature : TemperatureValue;
			attribute humidity : HumidityValue;
		}
		item def WaterQualityData {
			attribute purity : PurityValue;
			attribute contaminantLevel : ContaminantLevel;
		}
		item def OxygenCommand;
		item def CO2RemovalCommand;
		item def ClimateCommand;
		item def WaterReclamationCommand;
		attribute def EmergencyAlert;
		attribute def ShutdownSignal;

		// --- Port Definitions ---
		port def AtmosphereDataOutPort { out atmosphereData : AtmosphereData; }
		port def WaterQualityDataOutPort { out waterQualityData : WaterQualityData; }
		port def AtmosphereDataInPort { in atmosphereData : AtmosphereData; }
		port def WaterQualityDataInPort { in waterQualityData : WaterQualityData; }
		port def OxygenCommandInPort { in oxygenCommand : OxygenCommand; }
		port def CO2RemovalCommandInPort { in co2RemovalCommand : CO2RemovalCommand; }
		port def ClimateCommandInPort { in climateCommand : ClimateCommand; }
		port def WaterReclamationCommandInPort { in waterReclamationCommand : WaterReclamationCommand; }
		port def OxygenCommandOutPort { out oxygenCommand : OxygenCommand; }
		port def CO2RemovalCommandOutPort { out co2RemovalCommand : CO2RemovalCommand; }
		port def ClimateCommandOutPort { out climateCommand : ClimateCommand; }
		port def WaterReclamationCommandOutPort { out waterReclamationCommand : WaterReclamationCommand; }
		port def EmergencyAlertOutPort { out emergencyAlert : EmergencyAlert; }
		port def ShutdownSignalInPort { in shutdownSignal : ShutdownSignal; }

		// --- Action Definitions ---
		action def SenseAtmosphere { out atmosphereData : AtmosphereData; }
		action def SenseWaterQuality { out waterQualityData : WaterQualityData; }
		action def AnalyzeData {
			in atmosphereData : AtmosphereData;
			in waterQualityData : WaterQualityData;
			out oxygenCommand : OxygenCommand;
			out co2RemovalCommand : CO2RemovalCommand;
			out climateCommand : ClimateCommand;
			out waterReclamationCommand : WaterReclamationCommand;
			out emergencyAlert : EmergencyAlert;
		}
		action def GenerateOxygen { in oxygenCommand : OxygenCommand; }
		action def RemoveCO2 { in co2RemovalCommand : CO2RemovalCommand; }
		action def ControlClimate { in climateCommand : ClimateCommand; }
		action def ReclaimWater { in waterReclamationCommand : WaterReclamationCommand; }
		action def PerformSafeShutdown;

		// --- State Definitions ---
		state def LifeSupportControllerStates;

		// --- Part Definitions ---
		part def EnvironmentalMonitoringSubsystem {
			port atmosphereDataPort : AtmosphereDataOutPort;
			port waterQualityDataPort : WaterQualityDataOutPort;
			perform action 'sense atmosphere' : SenseAtmosphere;
			perform action 'sense water quality' : SenseWaterQuality;
		}

		part def LifeSupportControlUnit {
			port atmosphereDataInPort : AtmosphereDataInPort;
			port waterQualityDataInPort : WaterQualityDataInPort;
			port oxygenCommandOutPort : OxygenCommandOutPort;
			port co2RemovalCommandOutPort : CO2RemovalCommandOutPort;
			port climateCommandOutPort : ClimateCommandOutPort;
			port waterReclamationCommandOutPort : WaterReclamationCommandOutPort;
			port emergencyAlertPort : EmergencyAlertOutPort;
			port shutdownSignalPort : ShutdownSignalInPort;
			perform action 'analyze data' : AnalyzeData;
			perform action 'perform safe shutdown' : PerformSafeShutdown;
			exhibit state 'controller states' : LifeSupportControllerStates;
			attribute o2LowThreshold : O2LevelValue = 19.5;
			attribute o2HighThreshold : O2LevelValue = 23.5;
			attribute tempLowThreshold : TemperatureValue = 18;
			attribute tempHighThreshold : TemperatureValue = 27;
			attribute purityMinThreshold : PurityValue = 99.5;
		}

		part def OxygenGenerationSubsystem {
			port oxygenCommandPort : OxygenCommandInPort;
			perform action 'generate oxygen' : GenerateOxygen;
		}
		part def CO2RemovalSubsystem {
			port co2RemovalCommandPort : CO2RemovalCommandInPort;
			perform action 'remove co2' : RemoveCO2;
		}
		part def TemperatureHumidityControlSubsystem {
			port climateCommandPort : ClimateCommandInPort;
			perform action 'control climate' : ControlClimate;
		}
		part def WaterReclamationSubsystem {
			port waterReclamationCommandPort : WaterReclamationCommandInPort;
			perform action 'reclaim water' : ReclaimWater;
		}

		part def LifeSupportSystem {
			part environmentalMonitoring : EnvironmentalMonitoringSubsystem;
			part lifeSupportControlUnit : LifeSupportControlUnit;
			part oxygenGeneration : OxygenGenerationSubsystem;
			part co2Removal : CO2RemovalSubsystem;
			part temperatureHumidityControl : TemperatureHumidityControlSubsystem;
			part waterReclamation : WaterReclamationSubsystem;
		}
	}

	// Public re-export so harness can resolve types from Definitions
	import Definitions::*;

	package Usages {
		private import Definitions::*;

		// --- Requirements (usages, not defs, so they can be satisfied) ---
		requirement MaintainOxygenLevel {
			doc /* The system shall maintain oxygen concentration between 19.5% and 23.5%. */
			subject o2Level : O2LevelValue;
			constraint { o2Level >= 19.5 and o2Level <= 23.5 }
		}
		requirement MaintainTemperature {
			doc /* The system shall maintain temperature between 18C and 27C. */
			subject temperature : TemperatureValue;
			constraint { temperature >= 18 and temperature <= 27 }
		}
		requirement MaintainWaterPurity {
			doc /* The system shall ensure water purity is at least 99.5%. */
			subject purity : PurityValue;
			constraint { purity >= 99.5 }
		}
		requirement AutonomousOperation {
			doc /* The system shall autonomously monitor and adjust the habitat environment without human intervention. */
			subject isAutonomous : Boolean;
			constraint { isAutonomous == true }
		}

		part lifeSupportSystem : LifeSupportSystem {
			// --- Internal connections ---
			flow atmosphereDataFlow of AtmosphereData
				from environmentalMonitoring.atmosphereDataPort.atmosphereData
				to lifeSupportControlUnit.atmosphereDataInPort.atmosphereData;
			flow waterQualityDataFlow of WaterQualityData
				from environmentalMonitoring.waterQualityDataPort.waterQualityData
				to lifeSupportControlUnit.waterQualityDataInPort.waterQualityData;
			flow oxygenCommandFlow of OxygenCommand
				from lifeSupportControlUnit.oxygenCommandOutPort.oxygenCommand
				to oxygenGeneration.oxygenCommandPort.oxygenCommand;
			flow co2RemovalCommandFlow of CO2RemovalCommand
				from lifeSupportControlUnit.co2RemovalCommandOutPort.co2RemovalCommand
				to co2Removal.co2RemovalCommandPort.co2RemovalCommand;
			flow climateCommandFlow of ClimateCommand
				from lifeSupportControlUnit.climateCommandOutPort.climateCommand
				to temperatureHumidityControl.climateCommandPort.climateCommand;
			flow waterReclamationCommandFlow of WaterReclamationCommand
				from lifeSupportControlUnit.waterReclamationCommandOutPort.waterReclamationCommand
				to waterReclamation.waterReclamationCommandPort.waterReclamationCommand;

			part environmentalMonitoring : EnvironmentalMonitoringSubsystem {
				action 'sense atmosphere' : SenseAtmosphere {
					out atmosphereData : AtmosphereData;
				}
				action 'sense water quality' : SenseWaterQuality {
					out waterQualityData : WaterQualityData;
				}
			}

			part lifeSupportControlUnit : LifeSupportControlUnit {
				state 'controller states' : LifeSupportControllerStates {
					entry; then NormalOperating;
					state NormalOperating {
						do 'analyze data';
					}
					accept EmergencyAlert
						then EmergencyMode;
					state EmergencyMode {
						do 'analyze data';
					}
					accept ShutdownSignal
						then SafeShutdown;
					state SafeShutdown {
						do 'perform safe shutdown';
					}
				}
			}

			part oxygenGeneration : OxygenGenerationSubsystem {
				action 'generate oxygen' : GenerateOxygen {
					in oxygenCommand : OxygenCommand;
				}
			}
			part co2Removal : CO2RemovalSubsystem {
				action 'remove co2' : RemoveCO2 {
					in co2RemovalCommand : CO2RemovalCommand;
				}
			}
			part temperatureHumidityControl : TemperatureHumidityControlSubsystem {
				action 'control climate' : ControlClimate {
					in climateCommand : ClimateCommand;
				}
			}
			part waterReclamation : WaterReclamationSubsystem {
				action 'reclaim water' : ReclaimWater {
					in waterReclamationCommand : WaterReclamationCommand;
				}
			}
		}

		// --- Requirement Satisfaction ---
		satisfy MaintainOxygenLevel by lifeSupportSystem;
		satisfy MaintainTemperature by lifeSupportSystem;
		satisfy MaintainWaterPurity by lifeSupportSystem;
		satisfy AutonomousOperation by lifeSupportSystem;
	}
}
