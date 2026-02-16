package 'Air-Fuel Ratio Meter System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def AirFuelRatio :> Real;
	attribute def Voltage :> Real;
	attribute def OxygenConcentration :> Real;
	attribute def Temperature :> ThermodynamicTemperatureValue;
	attribute def SampleRate :> Real;
	
	item def ExhaustGas {
		attribute oxygenLevel : OxygenConcentration;
		attribute temperature : Temperature;
		attribute pressure : PressureValue;
	}
	
	item def SensorVoltage {
		attribute value : Voltage;
		attribute timestamp : Real;
	}
	
	item def AFRData {
		attribute ratio : AirFuelRatio;
		attribute lambda : Real;
		attribute isLean : Boolean;
		attribute isRich : Boolean;
	}
	
	port def ExhaustInputPort {
		in item exhaustStream : ExhaustGas;
		attribute sensorTemperature : Temperature;
	}
	
	port def VoltageOutputPort {
		out item voltageSignal : SensorVoltage;
		attribute signalQuality : Real;
	}
	
	port def DataInputPort {
		in item inputSignal : SensorVoltage;
	}
	
	port def AFROutputPort {
		out item afrReading : AFRData;
	}
	
	port def DisplayInputPort {
		in item displayData : AFRData;
	}
	
	part def WidebandOxygenSensor {
		port exhaustPort : ExhaustInputPort;
		port signalPort : VoltageOutputPort;
		
		attribute heaterActive : Boolean;
		attribute operatingTemperature : Temperature;
		attribute calibrationFactor : Real;
		
		action senseExhaust {
			in exhaustGas : ExhaustGas;
			out sensorVoltage : SensorVoltage;
			
			first start;
			then action activateHeater {
				out heaterStatus : Boolean;
			}
			then action waitForOperatingTemp {
				in currentTemp : Temperature;
			}
			then action measureOxygen {
				in gas : ExhaustGas = exhaustGas;
				out rawVoltage : Voltage;
			}
			then action outputSignal {
				in voltage : Voltage = measureOxygen.rawVoltage;
				out signal : SensorVoltage = sensorVoltage;
			}
			then done;
		}
	}
	
	part def SignalConditioner {
		port inputPort : DataInputPort;
		port outputPort : VoltageOutputPort;
		
		attribute filterCutoffFrequency : Real;
		attribute amplificationGain : Real;
		
		action conditionSignal {
			in rawSignal : SensorVoltage;
			out conditionedSignal : SensorVoltage;
			
			first start;
			then action filterNoise {
				in signal : SensorVoltage = rawSignal;
				out filteredSignal : SensorVoltage;
			}
			then action amplify {
				in signal : SensorVoltage = filterNoise.filteredSignal;
				out amplifiedSignal : SensorVoltage = conditionedSignal;
			}
			then done;
		}
	}
	
	part def AFRProcessor {
		port sensorInputPort : DataInputPort;
		port afrOutputPort : AFROutputPort;
		
		attribute stoichiometricRatio : AirFuelRatio = 14.7;
		attribute conversionTable : Real[*];
		
		action processAFR {
			in voltageSignal : SensorVoltage;
			out afrData : AFRData;
			
			first start;
			then action convertVoltageToLambda {
				in voltage : Voltage = voltageSignal.value;
				out lambda : Real;
			}
			then action calculateAFR {
				in lambdaValue : Real = convertVoltageToLambda.lambda;
				out ratio : AirFuelRatio;
			}
			then action classifyMixture {
				in afrValue : AirFuelRatio = calculateAFR.ratio;
				out classification : AFRData = afrData;
			}
			then done;
		}
	}
	
	part def DisplayController {
		port dataInputPort : DisplayInputPort;
		
		attribute displayRefreshRate : SampleRate;
		attribute displayBrightness : Real;
		
		state def DisplayStates {
			entry; then idle;
			
			state idle {
				entry action initializeDisplay;
			}
			
			transition idle_to_active
				first idle
				accept newData : AFRData
				then active;
			
			state active {
				entry action updateDisplay;
				do action refreshDisplay;
			}
			
			transition active_to_idle
				first active
				then idle;
		}
		
		action displayAFR {
			in afrData : AFRData;
			
			first start;
			then action formatData {
				in data : AFRData = afrData;
				out formattedText : String;
			}
			then action renderToScreen {
				in text : String = formatData.formattedText;
			}
			then action updateIndicators {
				in isLean : Boolean = afrData.isLean;
				in isRich : Boolean = afrData.isRich;
			}
			then done;
		}
	}
	
	part def AFRMeterSystem {
		part sensor : WidebandOxygenSensor;
		part conditioner : SignalConditioner;
		part processor : AFRProcessor;
		part display : DisplayController;
		
		connect sensor.signalPort to conditioner.inputPort;
		connect conditioner.outputPort to processor.sensorInputPort;
		connect processor.afrOutputPort to display.dataInputPort;
		
		action measureAndDisplayAFR {
			first start;
			then loop {
				action sense : sensor.senseExhaust;
				flow sense.sensorVoltage to condition.rawSignal;
				
				then action condition : conditioner.conditionSignal;
				flow condition.conditionedSignal to process.voltageSignal;
				
				then action process : processor.processAFR;
				flow process.afrData to show.afrData;
				
				then action show : display.displayAFR;
			}
		}
		
		perform action measureAndDisplayAFR;
	}
	
	requirement def MeasurementAccuracy {
		doc /* The air-fuel ratio meter shall measure AFR with an accuracy of ±0.1 ratio units across the range of 10.0 to 20.0. */
		
		subject meter : AFRMeterSystem;
		
		require constraint {
			doc /* Measurement error <= 0.1 AFR units */
		}
	}
	
	requirement def ResponseTime {
		doc /* The system shall update the displayed AFR within 100 milliseconds of a change in exhaust gas composition. */
		
		subject meter : AFRMeterSystem;
		
		require constraint {
			doc /* Update latency <= 100 ms */
		}
	}
	
	requirement def OperatingRange {
		doc /* The meter shall operate accurately with exhaust gas temperatures from 200°C to 900°C. */
		
		subject meter : AFRMeterSystem;
		
		require constraint {
			doc /* 200°C <= exhaust temperature <= 900°C */
		}
	}
	
	requirement def DisplayUpdateRate {
		doc /* The display shall refresh at a minimum rate of 10 Hz to provide real-time feedback. */
		
		subject display : DisplayController;
		
		require constraint {
			doc /* Display refresh rate >= 10 Hz */
		}
	}
}
