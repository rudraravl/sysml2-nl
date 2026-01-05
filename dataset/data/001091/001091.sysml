package 'Hygrometer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RelativeHumidity :> Real {
		doc /* Relative humidity as a percentage from 0 to 100 */
	}
	
	attribute def CalibrationData {
		attribute calibrationFactor : Real;
		attribute offsetCorrection : RelativeHumidity;
		attribute lastCalibrationDate : String;
		attribute driftRate : Real;
	}
	
	attribute def SensorReading {
		attribute timestamp : String;
		attribute humidity : RelativeHumidity;
		attribute temperature : TemperatureValue;
		attribute status : SensorStatus;
	}
	
	enum def SensorStatus {
		operational;
		warming_up;
		calibrating;
		error;
	}
	
	enum def DisplayMode {
		humidity_only;
		temperature_only;
		combined;
		trend_graph;
	}
	
	port def EnvironmentPort {
		in ambientHumidity : RelativeHumidity;
		in ambientTemperature : TemperatureValue;
	}
	
	port def SensorOutputPort {
		out rawVoltage : ElectricPotentialValue;
	}
	
	port def DataPort {
		out reading : SensorReading;
	}
	
	port def DisplayInputPort {
		in displayData : SensorReading;
		in mode : DisplayMode;
	}
	
	port def PowerPort {
		in supplyVoltage : ElectricPotentialValue;
	}
	
	action def SenseEnvironment {
		in humidity : RelativeHumidity;
		in temperature : TemperatureValue;
		out sensorVoltage : ElectricPotentialValue;
	}
	
	action def ConvertSignal {
		in analogVoltage : ElectricPotentialValue;
		in calibration : CalibrationData;
		out digitalHumidity : RelativeHumidity;
	}
	
	action def CompensateTemperature {
		in rawHumidity : RelativeHumidity;
		in currentTemperature : TemperatureValue;
		out compensatedHumidity : RelativeHumidity;
	}
	
	action def GenerateReading {
		in humidity : RelativeHumidity;
		in temperature : TemperatureValue;
		in sensorStatus : SensorStatus;
		out reading : SensorReading;
	}
	
	action def UpdateDisplay {
		in reading : SensorReading;
		in displayMode : DisplayMode;
	}
	
	action def LogData {
		in reading : SensorReading;
	}
	
	part def CapacitiveSensor {
		attribute responseTime : TimeValue;
		attribute accuracy : RelativeHumidity;
		attribute operatingRange : HumidityRange;
		
		port envInput : EnvironmentPort;
		port sensorOut : SensorOutputPort;
		port power : PowerPort;
		
		perform action sense : SenseEnvironment {
			in humidity = envInput.ambientHumidity;
			in temperature = envInput.ambientTemperature;
			out sensorVoltage = sensorOut.rawVoltage;
		}
	}
	
	attribute def HumidityRange {
		attribute min : RelativeHumidity;
		attribute max : RelativeHumidity;
	}
	
	part def SignalProcessor {
		attribute conversionResolution : Integer;
		attribute samplingRate : FrequencyValue;
		
		port analogIn : SensorOutputPort;
		port dataOut : DataPort;
		port power : PowerPort;
		
		private attribute calibration : CalibrationData {
			attribute :>> calibrationFactor = 1.0;
			attribute :>> offsetCorrection = 0.0;
			attribute :>> lastCalibrationDate = "2024-01-01";
			attribute :>> driftRate = 0.001;
		}
		
		action def ProcessSignal {
			in rawVoltage : ElectricPotentialValue;
			in ambientTemp : TemperatureValue;
			out processedReading : SensorReading;
			
			action convert : ConvertSignal {
				in analogVoltage = rawVoltage;
				in calibration = calibration;
				out digitalHumidity;
			}
			flow convert.digitalHumidity to compensate.rawHumidity;
			
			action compensate : CompensateTemperature {
				in rawHumidity;
				in currentTemperature = ambientTemp;
				out compensatedHumidity;
			}
			flow compensate.compensatedHumidity to generate.humidity;
			
			action generate : GenerateReading {
				in humidity;
				in temperature = ambientTemp;
				in sensorStatus = SensorStatus::operational;
				out reading = processedReading;
			}
		}
	}
	
	part def TemperatureSensor {
		attribute accuracy : TemperatureValue;
		attribute range : TemperatureRange;
		
		port envInput : EnvironmentPort;
		port power : PowerPort;
		
		action def MeasureTemperature {
			in ambientTemp : TemperatureValue;
			out temperature : TemperatureValue;
		}
	}
	
	attribute def TemperatureRange {
		attribute minimum : TemperatureValue;
		attribute maximum : TemperatureValue;
	}
	
	part def DisplayUnit {
		attribute screenSize : LengthValue;
		attribute refreshRate : FrequencyValue;
		
		port displayIn : DisplayInputPort;
		port power : PowerPort;
		
		private attribute currentMode : DisplayMode = DisplayMode::combined;
		
		perform action display : UpdateDisplay {
			in reading = displayIn.displayData;
			in displayMode = currentMode;
		}
	}
	
	part def DataLogger {
		attribute storageCapacity : Integer;
		attribute loggingInterval : TimeValue;
		
		port dataIn : DataPort;
		port power : PowerPort;
		
		perform action log : LogData {
			in reading = dataIn.reading;
		}
	}
	
	part def PowerSupply {
		attribute outputVoltage : ElectricPotentialValue;
		attribute outputCurrent : ElectricCurrentValue;
		
		port powerOut : PowerPort;
	}
	
	state def HygrometerStateMachine {
		entry; then PowerOff;
		
		state PowerOff;
		
		state Initializing {
			entry action { doc /* Initialize sensor and calibration */ }
		}
		
		state Ready;
		
		state Measuring {
			entry action { doc /* Begin continuous measurement cycle */ }
		}
		
		state Calibrating {
			entry action { doc /* Perform calibration routine */ }
		}
		
		state Error {
			entry action { doc /* Handle error condition */ }
		}
		
		transition powerOn accept at PowerOff if true then Initializing;
		transition initComplete accept at Initializing if true then Ready;
		transition startMeasure accept at Ready if true then Measuring;
		transition beginCalibration accept at Ready if true then Calibrating;
		transition calibrationDone accept at Calibrating if true then Ready;
		transition measurementError accept at Measuring if true then Error;
		transition errorRecovery accept at Error if true then Ready;
		transition shutdown accept at Ready if true then PowerOff;
	}
	
	part def Hygrometer {
		doc /* 
			A hygrometer system that continuously measures and displays 
			relative humidity and temperature in an environment. The system 
			senses environmental conditions using a capacitive humidity sensor, 
			processes the analog signals with temperature compensation and 
			calibration correction, displays the results to the user, and 
			logs data for historical analysis.
		*/
		
		part sensor : CapacitiveSensor {
			attribute :>> responseTime = 8.0[SI::s];
			attribute :>> accuracy = 2.0;
			attribute :>> operatingRange {
				attribute :>> min = 0.0;
				attribute :>> max = 100.0;
			}
		}
		
		part tempSensor : TemperatureSensor {
			attribute :>> accuracy = 0.3[SI::K];
			attribute :>> range {
				attribute :>> minimum = 243.15[SI::K];
				attribute :>> maximum = 333.15[SI::K];
			}
		}
		
		part processor : SignalProcessor {
			attribute :>> conversionResolution = 12;
			attribute :>> samplingRate = 1.0[SI::Hz];
		}
		
		part display : DisplayUnit {
			attribute :>> screenSize = 0.05[SI::m];
			attribute :>> refreshRate = 2.0[SI::Hz];
		}
		
		part logger : DataLogger {
			attribute :>> storageCapacity = 10000;
			attribute :>> loggingInterval = 60.0[SI::s];
		}
		
		part power : PowerSupply {
			attribute :>> outputVoltage = 5.0[SI::V];
			attribute :>> outputCurrent = 0.5[SI::A];
		}
		
		port environmentInterface : EnvironmentPort;
		
		state lifecycle : HygrometerStateMachine;
		
		bind environmentInterface to sensor.envInput;
		bind environmentInterface to tempSensor.envInput;
		
		connect sensor.sensorOut to processor.analogIn;
		connect processor.dataOut to display.displayIn;
		connect processor.dataOut to logger.dataIn;
		
		connect power.powerOut to sensor.power;
		connect power.powerOut to processor.power;
		connect power.powerOut to display.power;
		connect power.powerOut to logger.power;
		
		perform action operateHygrometer {
			action acquireData {
				action senseHumidity : sensor::sense {
					in humidity = environmentInterface.ambientHumidity;
					in temperature = environmentInterface.ambientTemperature;
					out sensorVoltage;
				}
				
				action measureTemp : tempSensor::MeasureTemperature {
					in ambientTemp = environmentInterface.ambientTemperature;
					out temperature;
				}
			}
			flow acquireData.senseHumidity.sensorVoltage to processData.rawVoltage;
			flow acquireData.measureTemp.temperature to processData.ambientTemp;
			
			action processData : processor::ProcessSignal {
				in rawVoltage;
				in ambientTemp;
				out processedReading;
			}
			flow processData.processedReading to updateDisplay.reading;
			flow processData.processedReading to logReading.reading;
			
			action updateDisplay : display::display {
				in reading;
				in displayMode = display.currentMode;
			}
			
			action logReading : logger::log {
				in reading;
			}
		}
	}
	
	requirement def MeasurementAccuracy {
		doc /* The hygrometer shall measure relative humidity with accuracy within ±2% RH */
		subject hygrometer : Hygrometer;
		require constraint {
			hygrometer.sensor.accuracy <= 2.0
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The hygrometer shall respond to humidity changes within 10 seconds */
		subject hygrometer : Hygrometer;
		require constraint {
			hygrometer.sensor.responseTime <= 10.0[SI::s]
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The hygrometer shall operate across 0-100% RH range */
		subject hygrometer : Hygrometer;
		require constraint {
			hygrometer.sensor.operatingRange.min == 0.0 and
			hygrometer.sensor.operatingRange.max == 100.0
		}
	}
	
	requirement def TemperatureCompensation {
		doc /* The hygrometer shall compensate humidity readings for temperature variations */
		subject hygrometer : Hygrometer;
	}
	
	requirement <'HYG-SYS-001'> hygrometerSystemRequirement {
		doc /* 
			The hygrometer system shall continuously measure environmental 
			relative humidity and temperature, process sensor data with 
			temperature compensation and calibration correction, display 
			real-time readings to the user, and maintain a historical log 
			of measurements for analysis and trending.
		*/
		
		require measurementAccuracy : MeasurementAccuracy;
		require responseTime : ResponseTimeRequirement;
		require operatingRange : OperatingRangeRequirement;
		require tempCompensation : TemperatureCompensation;
	}
	
	part hygrometerSystem : Hygrometer {
		satisfy hygrometerSystemRequirement;
	}
}
