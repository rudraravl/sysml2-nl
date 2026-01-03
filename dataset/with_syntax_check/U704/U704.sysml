package 'Hall Effect Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import UnitsAndScales::*;
	
	attribute def MagneticFluxDensityValue :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : SI::T;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : SI::V;
	}
	
	attribute def CurrentValue :> ScalarQuantityValue {
		attribute redefines num : Real;
		attribute redefines mRef : SI::A;
	}
	
	item def MagneticField {
		attribute fieldStrength : MagneticFluxDensityValue;
	}
	
	item def ElectricalSignal {
		attribute outputVoltage : VoltageValue;
	}
	
	port def SensorInputPort {
		in item magneticField : MagneticField;
	}
	
	port def SensorOutputPort {
		out item electricalSignal : ElectricalSignal;
	}
	
	port def PowerSupplyPort {
		in attribute supplyVoltage : VoltageValue;
		in attribute supplyCurrent : CurrentValue;
	}
	
	part def HallEffectSensor {
		port inputPort : SensorInputPort;
		port outputPort : SensorOutputPort;
		port powerPort : PowerSupplyPort;
		
		attribute sensitivity : Real;
		attribute operatingTemperatureRange : Real[2];
		attribute responseTime : DurationValue;
		attribute hallVoltage : VoltageValue;
		
		perform action senseField : SenseMagneticField;
	}
	
	action def SenseMagneticField {
		in item inputField : MagneticField;
		in attribute biasCurrent : CurrentValue;
		out item outputSignal : ElectricalSignal;
		
		action applyBiasCurrent {
			in biasCurrentValue : CurrentValue;
		}
		then action detectMagneticField {
			in magneticFieldInput : MagneticField;
			out hallVoltageGenerated : VoltageValue;
		}
		then action amplifySignal {
			in rawVoltage : VoltageValue;
			out amplifiedVoltage : VoltageValue;
		}
		then action conditionSignal {
			in inputVoltage : VoltageValue;
			out conditionedSignal : ElectricalSignal;
		}
		
		flow from applyBiasCurrent to detectMagneticField;
		flow from detectMagneticField.hallVoltageGenerated to amplifySignal.rawVoltage;
		flow from amplifySignal.amplifiedVoltage to conditionSignal.inputVoltage;
		
		bind inputField = detectMagneticField.magneticFieldInput;
		bind biasCurrent = applyBiasCurrent.biasCurrentValue;
		bind outputSignal = conditionSignal.conditionedSignal;
	}
	
	part def SignalConditioner {
		port signalInput : SensorOutputPort;
		port signalOutput : SensorOutputPort;
		
		attribute gain : Real;
		attribute offsetVoltage : VoltageValue;
		
		perform action conditionOutput : ConditionOutput;
	}
	
	action def ConditionOutput {
		in item rawSignal : ElectricalSignal;
		out item processedSignal : ElectricalSignal;
		
		action filterNoise {
			in noisySignal : ElectricalSignal;
			out filteredSignal : ElectricalSignal;
		}
		then action linearize {
			in nonlinearSignal : ElectricalSignal;
			out linearSignal : ElectricalSignal;
		}
		then action calibrate {
			in uncalibratedSignal : ElectricalSignal;
			out calibratedSignal : ElectricalSignal;
		}
		
		flow from filterNoise.filteredSignal to linearize.nonlinearSignal;
		flow from linearize.linearSignal to calibrate.uncalibratedSignal;
		
		bind rawSignal = filterNoise.noisySignal;
		bind processedSignal = calibrate.calibratedSignal;
	}
	
	part def SensingUnit {
		port measurementInput : SensorInputPort;
		port measurementOutput : SensorOutputPort;
		port power : PowerSupplyPort;
		
		part hallSensor : HallEffectSensor[1];
		part signalProcessor : SignalConditioner[1];
		
		connection inputConnection 
			connect measurementInput to hallSensor.inputPort;
		
		connection sensorToProcessor 
			connect hallSensor.outputPort to signalProcessor.signalInput;
		
		connection outputConnection 
			connect signalProcessor.signalOutput to measurementOutput;
		
		connection powerConnection 
			connect power to hallSensor.powerPort;
		
		perform action measureQuantity : MeasureQuantity;
	}
	
	action def MeasureQuantity {
		in item fieldToMeasure : MagneticField;
		out item measurement : ElectricalSignal;
		
		action acquireField : SenseMagneticField {
			in item :>> inputField;
			out item :>> outputSignal;
		}
		then action processSignal : ConditionOutput {
			in item :>> rawSignal;
			out item :>> processedSignal;
		}
		
		flow from acquireField.outputSignal to processSignal.rawSignal;
		
		bind fieldToMeasure = acquireField.inputField;
		bind measurement = processSignal.processedSignal;
	}
	
	requirement def SensingAccuracyRequirement {
		doc /* The sensing unit shall measure magnetic flux density with accuracy within 2% of full scale. */
		
		subject sensingUnit : SensingUnit;
		
		require constraint {
			sensingUnit.hallSensor.sensitivity >= 0.98 and 
			sensingUnit.hallSensor.sensitivity <= 1.02
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall respond to changes in magnetic field within 10 microseconds. */
		
		subject sensingUnit : SensingUnit;
		
		require constraint {
			sensingUnit.hallSensor.responseTime.num <= 10.0e-6
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The sensing unit shall operate over a temperature range of -40 to 125 degrees Celsius. */
		
		subject sensingUnit : SensingUnit;
		
		require constraint {
			sensingUnit.hallSensor.operatingTemperatureRange[1] <= -40.0 and
			sensingUnit.hallSensor.operatingTemperatureRange[2] >= 125.0
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		part :>> hallSensor {
			attribute :>> sensitivity = 1.0;
			attribute :>> operatingTemperatureRange = (-40.0, 125.0);
			attribute :>> responseTime = 8.0e-6[s];
		}
		
		part :>> signalProcessor {
			attribute :>> gain = 100.0;
			attribute :>> offsetVoltage = 0.0[V];
		}
		
		perform action :>> measureQuantity {
			in item :>> fieldToMeasure : MagneticField {
				attribute :>> fieldStrength = 50.0[T];
			}
		}
	}
	
	requirement sensingAccuracy : SensingAccuracyRequirement {
		subject testUnit :>> sensingUnitInstance;
	}
	
	requirement responseTime : ResponseTimeRequirement {
		subject testUnit :>> sensingUnitInstance;
	}
	
	requirement operatingRange : OperatingRangeRequirement {
		subject testUnit :>> sensingUnitInstance;
	}
}
