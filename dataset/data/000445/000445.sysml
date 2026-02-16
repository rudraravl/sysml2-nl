package 'EAT_SET_System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
	attribute def TestDuration :> ISQ::TimeValue;
	attribute def StressLevel;
	
	item def TestSpecimen {
		attribute specimenID : String;
		attribute materialType : String;
		attribute mass : MassValue;
		attribute initialCondition : String;
	}
	
	item def EnvironmentalProfile {
		attribute targetTemperature : ThermodynamicTemperatureValue;
		attribute targetHumidity : Real;
		attribute dwellTime : TimeValue;
		attribute cycleCount : Integer;
	}
	
	item def TestResults {
		attribute specimenID : String;
		attribute degradationLevel : Real;
		attribute failureMode : String;
		attribute testComplete : Boolean;
	}
	
	port def EnvironmentalControlPort {
		in attribute setpoint : ThermodynamicTemperatureValue;
		out attribute actualTemperature : ThermodynamicTemperatureValue;
		out attribute actualHumidity : Real;
	}
	
	port def SpecimenPort {
		in item specimen : TestSpecimen;
		out item results : TestResults;
	}
	
	port def PowerPort {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
		attribute power : PowerValue;
	}
	
	part def EnvironmentalChamber {
		doc /* Provides controlled temperature and humidity environment for accelerated testing */
		
		port envControl : EnvironmentalControlPort;
		port specimenInterface : SpecimenPort;
		port powerInput : PowerPort;
		
		attribute chamberVolume : VolumeValue;
		attribute maxTemperature : ThermodynamicTemperatureValue;
		attribute minTemperature : ThermodynamicTemperatureValue;
		attribute temperatureUniformity : ThermodynamicTemperatureValue;
		
		part heatingSystem {
			attribute heaterPower : PowerValue;
			attribute heaterCount : Integer;
		}
		
		part coolingSystem {
			attribute coolingCapacity : PowerValue;
			attribute refrigerantType : String;
		}
		
		part humidityControl {
			attribute humidifierCapacity : Real;
			attribute dehumidifierCapacity : Real;
		}
		
		part insulation {
			attribute thermalResistance : Real;
			attribute thickness : LengthValue;
		}
	}
	
	part def TemperatureSensor {
		port sensingPort : EnvironmentalControlPort;
		
		attribute sensorType : String;
		attribute accuracy : ThermodynamicTemperatureValue;
		attribute responseTime : TimeValue;
		attribute calibrationDate : String;
		
		perform action measureTemperature {
			out measuredTemp : ThermodynamicTemperatureValue;
			out timestamp : TimeValue;
		}
	}
	
	part def HumiditySensor {
		attribute accuracy : Real;
		attribute range : Real;
		
		perform action measureHumidity {
			out measuredHumidity : Real;
		}
	}
	
	part def ControlSystem {
		port controlPort : EnvironmentalControlPort;
		
		attribute controlAlgorithm : String;
		attribute pidGainP : Real;
		attribute pidGainI : Real;
		attribute pidGainD : Real;
		attribute updateRate : FrequencyValue;
		
		perform action regulateEnvironment {
			in currentTemp : ThermodynamicTemperatureValue;
			in targetTemp : ThermodynamicTemperatureValue;
			in currentHumidity : Real;
			in targetHumidity : Real;
			out heatingPower : PowerValue;
			out coolingPower : PowerValue;
			out humidityCommand : Real;
		}
	}
	
	part def DataAcquisitionSystem {
		attribute samplingRate : FrequencyValue;
		attribute storageCapacity : Real;
		attribute dataFormat : String;
		
		perform action recordTestData {
			in timestamp : TimeValue;
			in temperature : ThermodynamicTemperatureValue;
			in humidity : Real;
			in specimenID : String;
			out dataRecord : String;
		}
	}
	
	part def SafetySystem {
		attribute maxSafeTemperature : ThermodynamicTemperatureValue;
		attribute minSafeTemperature : ThermodynamicTemperatureValue;
		attribute emergencyShutdownActive : Boolean;
		attribute alarmActive : Boolean;
		
		perform action monitorSafety {
			in currentTemp : ThermodynamicTemperatureValue;
			in maxAllowedTemp : ThermodynamicTemperatureValue;
			in minAllowedTemp : ThermodynamicTemperatureValue;
			out shutdownSignal : Boolean;
			out alarmSignal : Boolean;
		}
	}
	
	part def SpecimenLoadingSystem {
		attribute maxLoadCapacity : Integer;
		attribute currentLoadCount : Integer;
		
		perform action loadSpecimen {
			in specimen : TestSpecimen;
			out loadConfirmed : Boolean;
		}
		
		perform action unloadSpecimen {
			in specimenID : String;
			out specimen : TestSpecimen;
		}
	}
	
	requirement def TemperatureAccuracyRequirement {
		doc /* The system shall maintain temperature within plus or minus 1 degree C of setpoint during steady state operation */
		
		subject chamber : EnvironmentalChamber;
		
		require constraint {
			chamber.envControl.actualTemperature >= chamber.envControl.setpoint - 1.0 and
			chamber.envControl.actualTemperature <= chamber.envControl.setpoint + 1.0
		}
	}
	
	requirement def TemperatureRangeRequirement {
		doc /* The system shall operate over a temperature range from -40 to +180 degrees C */
		
		subject chamber : EnvironmentalChamber;
		
		require constraint {
			chamber.minTemperature <= -40.0 and
			chamber.maxTemperature >= 180.0
		}
	}
	
	requirement def HumidityControlRequirement {
		doc /* The system shall control relative humidity from 10% to 95% RH with plus or minus 3% accuracy */
		
		subject chamber : EnvironmentalChamber;
		
		require constraint {
			chamber.envControl.actualHumidity >= chamber.humidityControl.dehumidifierCapacity - 3.0 and
			chamber.envControl.actualHumidity <= chamber.humidityControl.humidifierCapacity + 3.0
		}
	}
	
	requirement def SafetyShutdownRequirement {
		doc /* The system shall automatically shut down if temperature exceeds safe operating limits */
		
		subject safety : SafetySystem;
		
		require constraint {
			safety.emergencyShutdownActive == true
		}
	}
	
	requirement def DataLoggingRequirement {
		doc /* The system shall record test data at minimum 1 Hz sampling rate throughout test duration */
		
		subject dataSystem : DataAcquisitionSystem;
		
		require constraint {
			dataSystem.samplingRate >= 1.0
		}
	}
	
	part def EAT_SET_System {
		doc /* Environmental Accelerated Testing - Stress and Endurance Tester
		     
		     Primary Function: Subject test specimens to precisely controlled elevated temperature 
		     and humidity environments to accelerate aging processes and evaluate material performance, 
		     reliability, and degradation characteristics under thermal and environmental stress 
		     conditions over compressed time periods. The system simulates years of field exposure 
		     in days or weeks to predict product lifetime and identify failure modes. */
		
		part chamber : EnvironmentalChamber {
			:>> chamberVolume = 1.0;
			:>> maxTemperature = 200.0;
			:>> minTemperature = -50.0;
			:>> temperatureUniformity = 2.0;
		}
		
		part tempSensor : TemperatureSensor {
			:>> sensorType = "Type K Thermocouple";
			:>> accuracy = 0.5;
			:>> responseTime = 2.0;
		}
		
		part humiditySensor : HumiditySensor {
			:>> accuracy = 2.0;
			:>> range = 95.0;
		}
		
		part controller : ControlSystem {
			:>> controlAlgorithm = "PID";
			:>> pidGainP = 1.5;
			:>> pidGainI = 0.3;
			:>> pidGainD = 0.1;
			:>> updateRate = 10.0;
		}
		
		part dataSystem : DataAcquisitionSystem {
			:>> samplingRate = 5.0;
			:>> storageCapacity = 1000000.0;
			:>> dataFormat = "CSV";
		}
		
		part safety : SafetySystem {
			:>> maxSafeTemperature = 210.0;
			:>> minSafeTemperature = -60.0;
			:>> emergencyShutdownActive = false;
			:>> alarmActive = false;
		}
		
		part loadingSystem : SpecimenLoadingSystem {
			:>> maxLoadCapacity = 20;
			:>> currentLoadCount = 0;
		}
		
		connection tempSensing connect tempSensor.sensingPort to chamber.envControl;
		connection controlLoop connect controller.controlPort to chamber.envControl;
		
		perform action executeAcceleratedTest {
			first start;
			
			then action initializeTest {
				out testProfile : EnvironmentalProfile;
				out specimens : TestSpecimen[*];
			}
			
			then action loadSpecimens {
				in specimenList : TestSpecimen[*] = initializeTest.specimens;
				
				for specimen in specimenList {
					action load : SpecimenLoadingSystem::loadSpecimen {
						in specimen;
						out loadConfirmed;
					}
				}
			}
			
			then action configureEnvironment {
				in profile : EnvironmentalProfile = initializeTest.testProfile;
				out targetTemp : TemperatureSetpoint;
				out targetHumidity : Real;
				out duration : TestDuration;
			}
			
			then merge beginCycle;
			
			then action controlEnvironment {
				in setpointTemp : TemperatureSetpoint = configureEnvironment.targetTemp;
				in setpointHumidity : Real = configureEnvironment.targetHumidity;
				
				action measureTemp : TemperatureSensor::measureTemperature {
					out measuredTemp;
					out timestamp;
				}
				
				then action measureHum : HumiditySensor::measureHumidity {
					out measuredHumidity;
				}
				
				then action regulate : ControlSystem::regulateEnvironment {
					in currentTemp = measureTemp.measuredTemp;
					in targetTemp = setpointTemp;
					in currentHumidity = measureHum.measuredHumidity;
					in targetHumidity = setpointHumidity;
					out heatingPower;
					out coolingPower;
					out humidityCommand;
				}
				
				then action checkSafety : SafetySystem::monitorSafety {
					in currentTemp = measureTemp.measuredTemp;
					in maxAllowedTemp = safety.maxSafeTemperature;
					in minAllowedTemp = safety.minSafeTemperature;
					out shutdownSignal;
					out alarmSignal;
				}
			}
			
			then action logData : DataAcquisitionSystem::recordTestData {
				in timestamp = controlEnvironment.measureTemp.timestamp;
				in temperature = controlEnvironment.measureTemp.measuredTemp;
				in humidity = controlEnvironment.measureHum.measuredHumidity;
				out dataRecord;
			}
			
			then decide;
				if logData.timestamp < configureEnvironment.duration and 
				   controlEnvironment.checkSafety.shutdownSignal == false
				then beginCycle;
				if logData.timestamp >= configureEnvironment.duration or
				   controlEnvironment.checkSafety.shutdownSignal == true
				then coolDown;
			
			action coolDown {
				doc /* Controlled cooling to ambient temperature for safe specimen removal */
				
				action coolToAmbient {
					in currentTemp : ThermodynamicTemperatureValue;
					out finalTemp : ThermodynamicTemperatureValue;
				}
			}
			
			then action unloadSpecimens {
				in specimenCount : Integer = loadingSystem.currentLoadCount;
				out results : TestResults[*];
			}
			
			then action generateReport {
				in testData : TestResults[*] = unloadSpecimens.results;
				out finalReport : String;
			}
			
			then done;
		}
		
		state machine def OperationalStates {
			entry; then idle;
			
			state idle {
				doc /* System powered but not actively testing */
			}
			
			transition idle_to_loading
				first idle
				then loading;
			
			state loading {
				doc /* Specimens being loaded into chamber */
			}
			
			transition loading_to_preheating
				first loading
				if loadingSystem.currentLoadCount > 0
				then preheating;
			
			state preheating {
				doc /* Chamber heating to test temperature */
			}
			
			transition preheating_to_stabilizing
				first preheating
				if chamber.envControl.actualTemperature >= chamber.envControl.setpoint - 5.0
				then stabilizing;
			
			state stabilizing {
				doc /* Temperature stabilizing within tolerance */
			}
			
			transition stabilizing_to_testing
				first stabilizing
				if chamber.envControl.actualTemperature >= chamber.envControl.setpoint - 1.0 and
				   chamber.envControl.actualTemperature <= chamber.envControl.setpoint + 1.0
				then testing;
			
			state testing {
				doc /* Active accelerated aging test in progress */
			}
			
			transition testing_to_cooling
				first testing
				then cooling;
			
			state cooling {
				doc /* Controlled cooldown after test completion */
			}
			
			transition cooling_to_unloading
				first cooling
				if chamber.envControl.actualTemperature <= 40.0
				then unloading;
			
			state unloading {
				doc /* Specimens being removed from chamber */
			}
			
			transition unloading_to_idle
				first unloading
				if loadingSystem.currentLoadCount == 0
				then idle;
			
			transition emergency_shutdown
				first preheating, stabilizing, testing
				if safety.emergencyShutdownActive == true
				then cooling;
		}
		
		attribute currentTestProfile : EnvironmentalProfile;
		attribute testStartTime : TimeValue;
		attribute totalTestsCompleted : Integer;
		
		satisfy TemperatureAccuracyRequirement by chamber;
		satisfy TemperatureRangeRequirement by chamber;
		satisfy HumidityControlRequirement by chamber;
		satisfy SafetyShutdownRequirement by safety;
		satisfy DataLoggingRequirement by dataSystem;
	}
	
	occurrence def AcceleratedAgingTestSequence {
		ref part system : EAT_SET_System;
		
		message loadCommand
			from system.loadingSystem
			to system.chamber.specimenInterface;
		
		then message environmentalSetpoint
			from system.controller.controlPort
			to system.chamber.envControl;
		
		then message temperatureReading
			from system.tempSensor.sensingPort
			to system.controller.controlPort;
		
		then message humidityReading
			from system.humiditySensor
			to system.controller;
		
		then message controlCommand
			from system.controller.controlPort
			to system.chamber.envControl;
		
		then message dataRecord
			from system.chamber.envControl
			to system.dataSystem;
		
		then message safetyCheck
			from system.tempSensor.sensingPort
			to system.safety;
	}
	
	part eatSetInstance : EAT_SET_System {
		:>> currentTestProfile {
			:>> targetTemperature = 125.0;
			:>> targetHumidity = 85.0;
			:>> dwellTime = 168.0;
			:>> cycleCount = 10;
		}
		:>> testStartTime = 0.0;
		:>> totalTestsCompleted = 0;
	}
}
