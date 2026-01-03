package ExhaustGasTemperatureGaugeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureValue :> Real;
	
	attribute def VoltageValue :> Real;
	
	attribute def CurrentValue :> Real;
	
	item def ExhaustGasFlow {
		attribute temperature : TemperatureValue;
		attribute velocity : Real;
		attribute pressure : Real;
	}
	
	item def TemperatureSignal {
		attribute value : TemperatureValue;
		attribute timestamp : Real;
	}
	
	item def DisplayData {
		attribute temperature : TemperatureValue;
		attribute warningActive : ScalarValues::Boolean;
	}
	
	port def ExhaustSensingPort {
		in item exhaustFlow : ExhaustGasFlow;
		attribute measuredTemp : TemperatureValue;
	}
	
	port def AnalogSignalPort {
		out item signal : TemperatureSignal;
	}
	
	port def DigitalDataPort {
		in item signal : TemperatureSignal;
	}
	
	port def DisplayPort {
		out item displayData : DisplayData;
	}
	
	port def PowerPort {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}
	
	part def Thermocouple {
		port sensingPort : ExhaustSensingPort;
		port signalOutput : AnalogSignalPort;
		
		attribute sensorType : String = "Type K Thermocouple";
		attribute responseTime : Real = 0.5;
		
		action measureTemperature {
			in exhaustGas : ExhaustGasFlow;
			out tempSignal : TemperatureSignal;
		}
	}
	
	part def SignalConditioner {
		port analogInput : DigitalDataPort;
		port digitalOutput : AnalogSignalPort;
		
		attribute amplificationGain : Real = 100.0;
		attribute filterCutoffFrequency : Real = 10.0;
		
		action conditionSignal {
			in rawSignal : TemperatureSignal;
			out conditionedSignal : TemperatureSignal;
		}
	}
	
	part def MicroController {
		port dataInput : DigitalDataPort;
		port dataOutput : AnalogSignalPort;
		
		attribute processorSpeed : Real = 16.0;
		attribute adcResolution : Real = 12.0;
		attribute warningThreshold : TemperatureValue = 900.0;
		
		action processTemperatureData {
			in inputSignal : TemperatureSignal;
			out processedData : DisplayData;
		}
	}
	
	part def DisplayUnit {
		port displayInput : DigitalDataPort;
		port displayOutput : DisplayPort;
		
		attribute displayType : String = "LCD Digital Display";
		attribute updateRate : Real = 5.0;
		attribute backlightEnabled : ScalarValues::Boolean = true;
		
		action updateDisplay {
			in data : DisplayData;
		}
	}
	
	part def WarningIndicator {
		attribute ledColor : String = "Red";
		attribute blinkRate : Real = 2.0;
		
		action activateWarning {
			in warningCondition : ScalarValues::Boolean;
		}
	}
	
	part def PowerSupply {
		port powerInput : PowerPort;
		port powerOutput : PowerPort;
		
		attribute inputVoltage : VoltageValue = 12.0;
		attribute outputVoltage : VoltageValue = 5.0;
		attribute maxCurrent : CurrentValue = 2.0;
	}
	
	part def ExhaustGasTemperatureGauge {
		part sensor : Thermocouple;
		part conditioner : SignalConditioner;
		part controller : MicroController;
		part display : DisplayUnit;
		part warning : WarningIndicator;
		part power : PowerSupply;
		
		port exhaustInput : ExhaustSensingPort;
		port gaugeDisplay : DisplayPort;
		port powerIn : PowerPort;
		
		connect exhaustInput to sensor.sensingPort;
		connect sensor.signalOutput to conditioner.analogInput;
		connect conditioner.digitalOutput to controller.dataInput;
		connect controller.dataOutput to display.displayInput;
		connect display.displayOutput to gaugeDisplay;
		connect powerIn to power.powerInput;
		
		perform action monitorExhaustTemperature {
			first start;
			then merge continuousMonitoring;
			
			then action sense : Thermocouple::measureTemperature {
				in exhaustGas = exhaustInput.exhaustFlow;
				out tempSignal : TemperatureSignal;
			}
			
			then action condition : SignalConditioner::conditionSignal {
				in rawSignal = sense.tempSignal;
				out conditionedSignal : TemperatureSignal;
			}
			
			then action process : MicroController::processTemperatureData {
				in inputSignal = condition.conditionedSignal;
				out processedData : DisplayData;
			}
			
			then action displayUpdate : DisplayUnit::updateDisplay {
				in data = process.processedData;
			}
			
			then decide;
				if process.processedData.warningActive == true then activateWarning;
				if process.processedData.warningActive == false then continuousMonitoring;
			
			action activateWarning : WarningIndicator::activateWarning {
				in warningCondition = process.processedData.warningActive;
			}
			then continuousMonitoring;
		}
	}
	
	part gaugeSystem : ExhaustGasTemperatureGauge {
		attribute normalOperatingTemp : TemperatureValue = 650.0;
		attribute maxSafeTemp : TemperatureValue = 900.0;
		attribute criticalTemp : TemperatureValue = 1000.0;
	}
	
	requirement def MeasurementAccuracy {
		doc /* The gauge shall measure exhaust gas temperature with specified accuracy across the operating range. */
		
		subject gauge : ExhaustGasTemperatureGauge;
		
		require constraint accuracySpec {
			doc /* Temperature measurement accuracy shall be within ±2% or ±5°C, whichever is greater. */
		}
	}
	
	requirement def ResponseTime {
		doc /* The gauge shall respond to temperature changes within specified time. */
		
		subject gauge : ExhaustGasTemperatureGauge;
		
		require constraint responseSpec {
			doc /* The system shall update displayed temperature within 1 second of actual temperature change. */
		}
	}
	
	requirement def OperatingRange {
		doc /* The gauge shall operate across the full exhaust temperature range. */
		
		subject gauge : ExhaustGasTemperatureGauge;
		
		require constraint rangeSpec {
			doc /* The gauge shall measure temperatures from 0°C to 1200°C continuously. */
		}
	}
	
	requirement def WarningFunction {
		doc /* The gauge shall provide warning indication when temperature exceeds threshold. */
		
		subject gauge : ExhaustGasTemperatureGauge;
		
		require constraint warningThresholdSpec {
			doc /* Warning shall activate when exhaust temperature exceeds 900°C. */
		}
		
		require constraint warningVisibilitySpec {
			doc /* Warning indication shall be clearly visible to operator under all lighting conditions. */
		}
	}
	
	requirement def PowerRequirement {
		doc /* The gauge shall operate within specified power parameters. */
		
		subject gauge : ExhaustGasTemperatureGauge;
		
		require constraint voltageSpec {
			doc /* The gauge shall operate on 12V DC power supply with ±10% tolerance. */
		}
		
		require constraint currentSpec {
			doc /* Maximum current draw shall not exceed 2.0 Amperes during normal operation. */
		}
	}
	
	requirement primaryFunction {
		doc /* 
			The exhaust gas temperature gauge system shall continuously monitor the temperature 
			of engine exhaust gases using a thermocouple sensor, process and condition the 
			temperature signal through electronic circuitry, and display the current temperature 
			value to the operator on a digital display. The system shall provide a visual warning 
			indication when the exhaust temperature exceeds a predefined safety threshold to alert 
			the operator of potentially dangerous operating conditions that could damage the engine 
			or exhaust system components.
		*/
		
		subject system : ExhaustGasTemperatureGauge;
		
		require MeasurementAccuracy;
		require ResponseTime;
		require OperatingRange;
		require WarningFunction;
		require PowerRequirement;
	}
}
