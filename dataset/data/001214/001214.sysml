package 'Quartz Thermometer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FrequencyHz;
	attribute def TemperatureCelsius;
	attribute def VoltageVolts;
	attribute def CurrentMilliamps;
	
	item def FrequencySignal {
		attribute frequency : FrequencyHz;
	}
	
	item def TemperatureReading {
		attribute temperature : TemperatureCelsius;
	}
	
	item def PowerSignal {
		attribute voltage : VoltageVolts;
		attribute current : CurrentMilliamps;
	}
	
	port def FrequencyOutputPort {
		out item frequencySignal : FrequencySignal;
	}
	
	port def FrequencyInputPort {
		in item frequencySignal : FrequencySignal;
	}
	
	port def TemperatureOutputPort {
		out item temperatureReading : TemperatureReading;
	}
	
	port def DisplayInputPort {
		in item temperatureReading : TemperatureReading;
	}
	
	port def PowerInputPort {
		in item powerSignal : PowerSignal;
	}
	
	port def PowerOutputPort {
		out item powerSignal : PowerSignal;
	}
	
	action def GenerateOscillation {
		in ambientTemp : TemperatureCelsius;
		out outputFreq : FrequencyHz;
	}
	
	action def MeasureFrequency {
		in inputFreq : FrequencyHz;
		out measuredFreq : FrequencyHz;
	}
	
	action def ConvertFrequencyToTemperature {
		in frequency : FrequencyHz;
		out temperature : TemperatureCelsius;
	}
	
	action def DisplayTemperature {
		in temperature : TemperatureCelsius;
	}
	
	action def SupplyPower {
		out voltage : VoltageVolts;
		out current : CurrentMilliamps;
	}
	
	part def QuartzCrystalOscillator {
		attribute nominalFrequency : FrequencyHz;
		attribute temperatureCoefficient : Real;
		port frequencyOut : FrequencyOutputPort;
		port powerIn : PowerInputPort;
		
		perform action oscillate : GenerateOscillation {
			in ambientTemp : TemperatureCelsius;
			out outputFreq : FrequencyHz;
		}
	}
	
	part def FrequencyMeasurementCircuit {
		attribute measurementPeriod : ISQ::TimeValue;
		port frequencyIn : FrequencyInputPort;
		port frequencyOut : FrequencyOutputPort;
		port powerIn : PowerInputPort;
		
		perform action measure : MeasureFrequency {
			in inputFreq : FrequencyHz;
			out measuredFreq : FrequencyHz;
		}
	}
	
	part def MicroprocessorUnit {
		attribute calibrationCoefficients : Real[*];
		port frequencyIn : FrequencyInputPort;
		port temperatureOut : TemperatureOutputPort;
		port powerIn : PowerInputPort;
		
		perform action convert : ConvertFrequencyToTemperature {
			in frequency : FrequencyHz;
			out temperature : TemperatureCelsius;
		}
	}
	
	part def LCDDisplay {
		attribute displayResolution : Real;
		attribute updateRate : ISQ::FrequencyValue;
		port temperatureIn : DisplayInputPort;
		port powerIn : PowerInputPort;
		
		perform action display : DisplayTemperature {
			in temperature : TemperatureCelsius;
		}
	}
	
	part def BatteryPowerSource {
		attribute batteryVoltage : VoltageVolts;
		attribute batteryCapacity : ISQ::EnergyValue;
		port powerOut : PowerOutputPort;
		
		perform action supply : SupplyPower {
			out voltage : VoltageVolts;
			out current : CurrentMilliamps;
		}
	}
	
	part def QuartzThermometer {
		doc /* A quartz thermometer measures temperature by exploiting the temperature-dependent 
		       frequency characteristics of a quartz crystal oscillator. The crystal's resonant 
		       frequency varies predictably with ambient temperature, enabling precise temperature 
		       measurement through frequency counting and calibrated conversion. */
		
		part crystalOscillator : QuartzCrystalOscillator {
			attribute :>> nominalFrequency = 32768.0;
			attribute :>> temperatureCoefficient = -0.034;
		}
		
		part frequencyCircuit : FrequencyMeasurementCircuit {
			attribute :>> measurementPeriod = 1.0 [SI::s];
		}
		
		part processor : MicroprocessorUnit {
			attribute :>> calibrationCoefficients = (25.0, -29.41, 0.001);
		}
		
		part displayUnit : LCDDisplay {
			attribute :>> displayResolution = 0.1;
			attribute :>> updateRate = 1.0 [SI::Hz];
		}
		
		part battery : BatteryPowerSource {
			attribute :>> batteryVoltage = 3.0;
			attribute :>> batteryCapacity = 10800.0 [SI::J];
		}
		
		connection oscillatorToCircuit connect crystalOscillator.frequencyOut to frequencyCircuit.frequencyIn;
		connection circuitToProcessor connect frequencyCircuit.frequencyOut to processor.frequencyIn;
		connection processorToDisplay connect processor.temperatureOut to displayUnit.temperatureIn;
		connection powerToOscillator connect battery.powerOut to crystalOscillator.powerIn;
		connection powerToCircuit connect battery.powerOut to frequencyCircuit.powerIn;
		connection powerToProcessor connect battery.powerOut to processor.powerIn;
		connection powerToDisplay connect battery.powerOut to displayUnit.powerIn;
		
		action measureAndDisplayTemperature {
			doc /* Primary function: continuously measure ambient temperature and display the result. */
			
			first start;
			then merge continueMeasurement;
			
			action generateFrequency : GenerateOscillation {
				in ambientTemp : TemperatureCelsius;
				out outputFreq : FrequencyHz;
			}
			
			flow generateFrequency.outputFreq to measureFreq.inputFreq;
			
			action measureFreq : MeasureFrequency {
				in inputFreq : FrequencyHz;
				out measuredFreq : FrequencyHz;
			}
			
			flow measureFreq.measuredFreq to convertTemp.frequency;
			
			action convertTemp : ConvertFrequencyToTemperature {
				in frequency : FrequencyHz;
				out temperature : TemperatureCelsius;
			}
			
			flow convertTemp.temperature to showTemp.temperature;
			
			action showTemp : DisplayTemperature {
				in temperature : TemperatureCelsius;
			}
			
			then continueMeasurement;
		}
		
		state thermometerLifecycle {
			entry; then off;
			
			state off;
			state operational {
				entry; then initializeSystem;
				state initializeSystem;
				then measureLoop;
				state measureLoop {
					do measureAndDisplayTemperature;
				}
			}
			state lowPower;
			
			transition powerOn first off accept PowerOnEvent then operational;
			transition enterLowPower first operational accept EnterLowPowerEvent then lowPower;
			transition exitLowPower first lowPower accept ExitLowPowerEvent then operational;
			transition powerOff first operational accept PowerOffEvent then off;
		}
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* Defines the required measurement accuracy for the thermometer. */
		attribute accuracyTolerance : TemperatureCelsius;
		attribute operatingRangeLow : TemperatureCelsius;
		attribute operatingRangeHigh : TemperatureCelsius;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* Defines the required response time for temperature updates. */
		attribute maxResponseTime : ISQ::TimeValue;
	}
	
	requirement def PowerConsumptionRequirement {
		doc /* Defines the maximum allowable power consumption. */
		attribute maxPowerConsumption : ISQ::PowerValue;
	}
	
	requirement def DisplayResolutionRequirement {
		doc /* Defines the minimum display resolution. */
		attribute minResolution : TemperatureCelsius;
	}
	
	requirement <'REQ-001'> measurementAccuracy : MeasurementAccuracyRequirement {
		doc /* The quartz thermometer shall measure temperature with an accuracy of ±0.1°C 
		       over the operating range of -10°C to 60°C. */
		attribute :>> accuracyTolerance = 0.1;
		attribute :>> operatingRangeLow = -10.0;
		attribute :>> operatingRangeHigh = 60.0;
	}
	
	requirement <'REQ-002'> responseTime : ResponseTimeRequirement {
		doc /* The thermometer shall update the displayed temperature within 2 seconds 
		       of a temperature change. */
		attribute :>> maxResponseTime = 2.0 [SI::s];
	}
	
	requirement <'REQ-003'> powerConsumption : PowerConsumptionRequirement {
		doc /* The thermometer shall consume no more than 15 milliwatts during continuous operation. */
		attribute :>> maxPowerConsumption = 0.015 [SI::W];
	}
	
	requirement <'REQ-004'> displayResolution : DisplayResolutionRequirement {
		doc /* The display shall show temperature readings with a resolution of at least 0.1°C. */
		attribute :>> minResolution = 0.1;
	}
	
	requirement <'REQ-SYS'> systemRequirement {
		doc /* The quartz thermometer system shall accurately measure and continuously display 
		       ambient temperature by detecting frequency variations in a temperature-sensitive 
		       quartz crystal oscillator. */
		
		require measurementAccuracy;
		require responseTime;
		require powerConsumption;
		require displayResolution;
		
		assume constraint operatingEnvironment {
			doc /* The system operates in a stable electromagnetic environment with minimal vibration. */
		}
	}
	
	part thermometerInstance : QuartzThermometer {
		satisfy systemRequirement by measureAndDisplayTemperature;
	}
}
