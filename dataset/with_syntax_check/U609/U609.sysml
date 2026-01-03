package BarometerSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AtmosphericPressure :> ISQ::PressureValue;
	attribute def AmbientTemperature :> ISQ::TemperatureValue;
	attribute def Altitude :> ISQ::LengthValue;
	
	value def PressureReading {
		attribute pressure : AtmosphericPressure;
		attribute temperature : AmbientTemperature;
		attribute timestamp : ISQ::TimeValue;
	}
	
	value def AltitudeEstimate {
		attribute altitude : Altitude;
		attribute confidence : Real;
	}
	
	item def PressureSignal {
		attribute rawValue : AtmosphericPressure;
		attribute quality : Real;
	}
	
	item def TemperatureSignal {
		attribute rawValue : AmbientTemperature;
	}
	
	item def CalibrationParameters {
		attribute seaLevelPressure : AtmosphericPressure;
		attribute temperatureOffset : AmbientTemperature;
	}
	
	port def SensorOutputPort {
		out item pressureSignal : PressureSignal;
		out item temperatureSignal : TemperatureSignal;
	}
	
	port def ProcessorInputPort {
		in item pressureSignal : PressureSignal;
		in item temperatureSignal : TemperatureSignal;
	}
	
	port def DataOutputPort {
		out item reading : PressureReading;
		out item altitudeEstimate : AltitudeEstimate;
	}
	
	part def PressureSensor {
		port sensorOut : SensorOutputPort;
		
		attribute measurementRange : AtmosphericPressure[2];
		attribute accuracy : AtmosphericPressure;
		
		action sensePressure {
			out rawPressure : AtmosphericPressure;
			out rawTemperature : AmbientTemperature;
		}
	}
	
	part def DataProcessor {
		port processorIn : ProcessorInputPort;
		port processorOut : DataOutputPort;
		
		attribute calibration : CalibrationParameters;
		attribute measurementHistory : PressureReading[*];
		
		action compensatePressure {
			in rawPressure : AtmosphericPressure;
			in rawTemperature : AmbientTemperature;
			out compensatedPressure : AtmosphericPressure;
		}
		
		action calculateAltitude {
			in pressure : AtmosphericPressure;
			in temperature : AmbientTemperature;
			in seaLevelPressure : AtmosphericPressure;
			out altitude : Altitude;
		}
		
		action filterData {
			in currentReading : PressureReading;
			in history : PressureReading[*];
			out filteredReading : PressureReading;
		}
	}
	
	part def UserInterface {
		attribute displayedPressure : AtmosphericPressure;
		attribute displayedAltitude : Altitude;
		
		action updateDisplay {
			in reading : PressureReading;
			in altitude : AltitudeEstimate;
		}
	}
	
	part def PowerManagement {
		attribute batteryVoltage : ISQ::VoltageValue;
		attribute operatingMode : String;
		attribute powerAvailable : Boolean;
		
		action managePower {
			in currentDraw : ISQ::ElectricCurrentValue;
			out powerStatus : Boolean;
		}
		
		state powerStates {
			entry; then standby;
			
			state standby;
			state active;
			state lowPower;
			state shutdown;
			
			transition wakeUp
				first standby
				then active;
			
			transition enterLowPower
				first active
				then lowPower;
			
			transition resume
				first lowPower
				then active;
			
			transition powerOff
				first active
				then shutdown;
		}
	}
	
	part def Barometer {
		part sensor : PressureSensor {
			attribute measurementRange = (30000.0, 110000.0);
			attribute accuracy = 50.0;
		}
		
		part processor : DataProcessor {
			attribute calibration : CalibrationParameters {
				attribute seaLevelPressure = 101325.0;
				attribute temperatureOffset = 0.0;
			}
		}
		
		part display : UserInterface;
		part power : PowerManagement;
		
		connection sensorToProcessor 
			connect sensor.sensorOut.pressureSignal to processor.processorIn.pressureSignal;
		
		connection sensorToProcessorTemp 
			connect sensor.sensorOut.temperatureSignal to processor.processorIn.temperatureSignal;
		
		action measureAtmosphericPressure {
			first start;
			
			then action initialize {
				action loadCalibration {
					out calibrationData : CalibrationParameters;
				}
				then action selfTest {
					out testPassed : Boolean;
				}
			}
			
			then merge continuousMeasurement;
			
			then action acquireSensorData {
				action readSensor : PressureSensor::sensePressure {
					out rawPressure : AtmosphericPressure;
					out rawTemperature : AmbientTemperature;
				}
			}
			
			then action processRawData {
				action compensate : DataProcessor::compensatePressure {
					in rawPressure = acquireSensorData.readSensor.rawPressure;
					in rawTemperature = acquireSensorData.readSensor.rawTemperature;
					out compensatedPressure : AtmosphericPressure;
				}
				
				then action filter : DataProcessor::filterData {
					in currentReading : PressureReading {
						attribute pressure = compensate.compensatedPressure;
						attribute temperature = acquireSensorData.readSensor.rawTemperature;
					}
					in history = processor.measurementHistory;
					out filteredReading : PressureReading;
				}
			}
			
			then action computeAltitude : DataProcessor::calculateAltitude {
				in pressure = processRawData.filter.filteredReading.pressure;
				in temperature = processRawData.filter.filteredReading.temperature;
				in seaLevelPressure = processor.calibration.seaLevelPressure;
				out altitude : Altitude;
			}
			
			then action presentResults : UserInterface::updateDisplay {
				in reading = processRawData.filter.filteredReading;
				in altitude : AltitudeEstimate {
					attribute altitude = computeAltitude.altitude;
					attribute confidence = 0.95;
				}
			}
			
			then decide;
				if power.powerAvailable then continuousMeasurement;
				else done;
		}
		
		state operatingModes {
			entry; then idle;
			
			state idle;
			state measuring {
				do perform measureAtmosphericPressure;
			}
			state calibrating;
			state error;
			
			transition startMeasurement
				first idle
				then measuring;
			
			transition stopMeasurement
				first measuring
				then idle;
			
			transition enterCalibration
				first idle
				then calibrating;
			
			transition calibrationComplete
				first calibrating
				then idle;
			
			transition errorDetected
				first measuring
				then error;
			
			transition errorRecovered
				first error
				then idle;
		}
	}
	
	requirement def MeasurePressureRequirement;
	requirement def TemperatureCompensationRequirement;
	requirement def AltitudeCalculationRequirement;
	requirement def DataFilteringRequirement;
	requirement def PowerManagementRequirement;
	requirement def SystemRequirement;
	
	requirement <'BR-001'> measurePressureRequirement : MeasurePressureRequirement {
		doc /* The barometer shall continuously measure atmospheric pressure with an accuracy of ±50 Pa over the range of 300 hPa to 1100 hPa. */
		
		subject barometer : Barometer;
		
		require constraint {
			barometer.sensor.accuracy <= 50.0
		}
	}
	
	requirement <'BR-002'> temperatureCompensationRequirement : TemperatureCompensationRequirement {
		doc /* The barometer shall compensate pressure measurements for temperature variations to ensure accuracy across the operating temperature range. */
		
		subject barometer : Barometer;
	}
	
	requirement <'BR-003'> altitudeCalculationRequirement : AltitudeCalculationRequirement {
		doc /* The barometer shall calculate altitude from atmospheric pressure using the barometric formula with temperature compensation. */
		
		subject barometer : Barometer;
	}
	
	requirement <'BR-004'> dataFilteringRequirement : DataFilteringRequirement {
		doc /* The barometer shall filter measurement data to reduce noise and provide stable readings. */
		
		subject barometer : Barometer;
	}
	
	requirement <'BR-005'> powerManagementRequirement : PowerManagementRequirement {
		doc /* The barometer shall manage power consumption to maximize battery life while maintaining measurement accuracy. */
		
		subject barometer : Barometer;
	}
	
	requirement barometerSystemRequirements : SystemRequirement {
		doc /* The barometer system shall measure atmospheric pressure, compensate for temperature, calculate altitude, and present data to the user in a continuous, power-efficient manner. */
		
		assume constraint calibrationDataAvailable {
			doc /* Valid calibration data including sea level pressure reference must be available. */
		}
		
		assume constraint operatingEnvironment {
			doc /* The barometer operates within specified temperature and pressure ranges. */
		}
		
		require measurePressureRequirement;
		require temperatureCompensationRequirement;
		require altitudeCalculationRequirement;
		require dataFilteringRequirement;
		require powerManagementRequirement;
	}
	
	part barometerSystem : Barometer {
		perform action operation : measureAtmosphericPressure;
	}
}
