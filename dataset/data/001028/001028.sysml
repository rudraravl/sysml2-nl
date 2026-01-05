package 'Displacement Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DisplacementValue :> ISQ::LengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : ISQ::LengthUnit;
	}
	
	attribute def VoltageValue :> ISQ::QuantityValue {
		attribute num : Real;
		attribute mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> ISQ::DerivedUnit;
	
	item def PhysicalDisplacement {
		attribute delta : DisplacementValue;
	}
	
	item def ElectricalSignal {
		attribute voltage : VoltageValue;
	}
	
	item def DisplacementReading {
		attribute measured : DisplacementValue;
		attribute timestamp : Real;
	}
	
	port def MechanicalInputPort {
		in item displacement : PhysicalDisplacement;
	}
	
	port def SensorOutputPort {
		out item signal : ElectricalSignal;
	}
	
	port def MeasurementOutputPort {
		out item reading : DisplacementReading;
	}
	
	action def SenseDisplacement {
		in displacement : PhysicalDisplacement;
		out voltage : VoltageValue;
		
		action acquireDisplacement {
			in item inputDisplacement : PhysicalDisplacement;
			out item measuredValue : DisplacementValue;
		}
		
		succession flow from acquireDisplacement.measuredValue to convertToVoltage.displacementInput;
		
		action convertToVoltage {
			in item displacementInput : DisplacementValue;
			out item voltageOutput : VoltageValue;
		}
		
		bind acquireDisplacement.inputDisplacement = displacement;
		bind convertToVoltage.voltageOutput = voltage;
	}
	
	action def ConditionSignal {
		in rawSignal : ElectricalSignal;
		out conditionedSignal : ElectricalSignal;
		
		action amplify {
			in item inputSignal : ElectricalSignal;
			out item amplifiedSignal : ElectricalSignal;
		}
		
		succession flow from amplify.amplifiedSignal to filter.noisySignal;
		
		action filter {
			in item noisySignal : ElectricalSignal;
			out item cleanSignal : ElectricalSignal;
		}
		
		bind amplify.inputSignal = rawSignal;
		bind filter.cleanSignal = conditionedSignal;
	}
	
	action def ProcessMeasurement {
		in conditionedSignal : ElectricalSignal;
		out reading : DisplacementReading;
		
		action convertToDisplacement {
			in item voltageInput : VoltageValue;
			out item displacementOutput : DisplacementValue;
		}
		
		succession flow from convertToDisplacement.displacementOutput to createReading.displacement;
		
		action createReading {
			in item displacement : DisplacementValue;
			out item output : DisplacementReading;
		}
		
		bind convertToDisplacement.voltageInput = conditionedSignal.voltage;
		bind createReading.output = reading;
	}
	
	part def DisplacementSensor {
		attribute sensitivity : Real default 0.1;
		attribute measurementRange : DisplacementValue;
		attribute accuracy : DisplacementValue;
		
		port mechanicalInput : MechanicalInputPort;
		port sensorOutput : SensorOutputPort;
		
		perform sense : SenseDisplacement {
			in displacement :>> mechanicalInput.displacement;
			out voltage;
		}
	}
	
	part def SignalConditioner {
		attribute gain : Real default 10.0;
		attribute offset : VoltageValue;
		
		port signalInput : SensorOutputPort;
		port conditionedOutput : SensorOutputPort;
		
		perform condition : ConditionSignal {
			in rawSignal :>> signalInput.signal;
			out conditionedSignal;
		}
	}
	
	part def MeasurementProcessor {
		attribute samplingRate : Real default 1000.0;
		attribute resolution : Real default 16.0;
		
		port analogInput : SensorOutputPort;
		port measurementOutput : MeasurementOutputPort;
		
		perform process : ProcessMeasurement {
			in conditionedSignal :>> analogInput.signal;
			out reading;
		}
	}
	
	part def SensingUnit {
		part sensor : DisplacementSensor {
			attribute :>> measurementRange {
				attribute :>> num = 100.0;
				attribute :>> mRef = mm;
			}
			attribute :>> accuracy {
				attribute :>> num = 0.01;
				attribute :>> mRef = mm;
			}
			attribute :>> sensitivity = 0.05;
		}
		
		part conditioner : SignalConditioner {
			attribute :>> gain = 10.0;
			attribute :>> offset {
				attribute num = 0.0;
				attribute mRef = V;
			}
		}
		
		part processor : MeasurementProcessor {
			attribute :>> samplingRate = 1000.0;
			attribute :>> resolution = 16.0;
		}
		
		port mechanicalInput : MechanicalInputPort;
		port measurementOutput : MeasurementOutputPort;
		
		connect sensor.mechanicalInput to mechanicalInput;
		connect sensor.sensorOutput to conditioner.signalInput;
		connect conditioner.conditionedOutput to processor.analogInput;
		connect processor.measurementOutput to measurementOutput;
		
		action performMeasurement : PerformMeasurement {
			in displacement : PhysicalDisplacement;
			out reading : DisplacementReading;
		}
	}
	
	action def PerformMeasurement {
		in displacement : PhysicalDisplacement;
		out reading : DisplacementReading;
		
		fork;
		
		then action sensing : SenseDisplacement {
			in displacement;
			out voltage;
		}
		
		then joinNode;
		
		action conditioning : ConditionSignal {
			in rawSignal;
			out conditionedSignal;
		}
		
		then joinNode;
		
		flow from sensing.voltage to conditioning.rawSignal.voltage;
		
		action processing : ProcessMeasurement {
			in conditionedSignal;
			out reading;
		}
		
		then joinNode;
		
		flow from conditioning.conditionedSignal to processing.conditionedSignal;
		
		join joinNode;
		then done;
		
		bind processing.reading = reading;
	}
	
	requirement def SensingAccuracyRequirement {
		doc /* The sensing unit shall measure displacement with accuracy better than 0.05 mm. */
		
		subject sensingSystem : SensingUnit;
		
		require constraint {
			sensingSystem.sensor.accuracy.num <= 0.05
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensing unit shall measure displacement over a range of at least 100 mm. */
		
		subject sensingSystem : SensingUnit;
		
		require constraint {
			sensingSystem.sensor.measurementRange.num >= 100.0
		}
	}
	
	requirement def SamplingRateRequirement {
		doc /* The measurement processor shall sample at a minimum rate of 1000 Hz. */
		
		subject processorSystem : MeasurementProcessor;
		
		require constraint {
			processorSystem.samplingRate >= 1000.0
		}
	}
	
	attribute mm : ISQ::LengthUnit;
	attribute V : VoltageUnit;
	
	part sensingUnit : SensingUnit {
		satisfy SensingAccuracyRequirement;
		satisfy MeasurementRangeRequirement;
		satisfy SamplingRateRequirement;
	}
	
	individual def TestSensingUnit :> SensingUnit;
	
	individual testUnit : TestSensingUnit :> sensingUnit {
		timeslice measurement1 {
			perform action :>> performMeasurement {
				in :>> displacement {
					attribute :>> delta {
						attribute :>> num = 25.5;
						attribute :>> mRef = mm;
					}
				}
				out :>> reading {
					attribute :>> measured {
						attribute :>> num = 25.5;
						attribute :>> mRef = mm;
					}
					attribute :>> timestamp = 1.0;
				}
			}
		}
		then timeslice measurement2 {
			perform action :>> performMeasurement {
				in :>> displacement {
					attribute :>> delta {
						attribute :>> num = 50.0;
						attribute :>> mRef = mm;
					}
				}
				out :>> reading {
					attribute :>> measured {
						attribute :>> num = 50.0;
						attribute :>> mRef = mm;
					}
					attribute :>> timestamp = 2.0;
				}
			}
		}
		then timeslice measurement3 {
			perform action :>> performMeasurement {
				in :>> displacement {
					attribute :>> delta {
						attribute :>> num = 75.25;
						attribute :>> mRef = mm;
					}
				}
				out :>> reading {
					attribute :>> measured {
						attribute :>> num = 75.25;
						attribute :>> mRef = mm;
					}
					attribute :>> timestamp = 3.0;
				}
			}
		}
	}
}
