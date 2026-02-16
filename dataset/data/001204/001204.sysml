package 'Pressure Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def PressureSignal {
		attribute value : ISQ::pressure;
		attribute timestamp : Real;
	}
	
	item def ElectricalSignal {
		attribute voltage : Real;
		attribute current : Real;
	}
	
	port def PressureInputPort {
		in item pressureIn : PressureSignal;
	}
	
	port def SignalOutputPort {
		out item signalOut : ElectricalSignal;
	}
	
	port def PowerSupplyPort {
		in item powerIn : ElectricalSignal;
	}
	
	part def SensingElement {
		attribute sensitivity : Real;
		attribute offset : Real;
		
		port pressurePort : PressureInputPort;
		port rawSignalPort : SignalOutputPort;
		
		action convertPressureToSignal {
			in pressureInput : ISQ::pressure;
			out rawVoltage : Real;
		}
	}
	
	part def SignalConditioner {
		attribute gain : Real;
		attribute filterCutoff : Real;
		
		port rawInput : PressureInputPort;
		port conditionedOutput : SignalOutputPort;
		
		action amplifyAndFilter {
			in rawSignal : Real;
			out conditionedSignal : Real;
		}
	}
	
	part def PressureSensor {
		attribute sensorId : String;
		attribute calibrationFactor : Real;
		attribute operatingTemperature : ISQ::temperature;
		attribute measurementRange : ISQ::pressure;
		
		port pressureInterface : PressureInputPort;
		port outputInterface : SignalOutputPort;
		port powerInterface : PowerSupplyPort;
		
		part sensingElement : SensingElement {
			attribute :>> sensitivity = 0.05;
			attribute :>> offset = 0.0;
		}
		
		part signalConditioner : SignalConditioner {
			attribute :>> gain = 100.0;
			attribute :>> filterCutoff = 1000.0;
		}
		
		connect sensingElement.rawSignalPort to signalConditioner.rawInput;
	}
	
	action def MeasurePressure {
		in item appliedPressure : PressureSignal;
		out item measurement : ElectricalSignal;
		
		action detectPressure {
			in item pressure : PressureSignal;
			out item mechanicalDeformation : Real;
		}
		
		then action convertToElectrical {
			in item deformation : Real;
			out item rawVoltage : Real;
		}
		
		then action conditionSignal {
			in item rawSignal : Real;
			out item amplifiedSignal : Real;
		}
		
		then action outputReading {
			in item signal : Real;
			out item finalMeasurement : ElectricalSignal;
		}
		
		flow from detectPressure.mechanicalDeformation to convertToElectrical.deformation;
		flow from convertToElectrical.rawVoltage to conditionSignal.rawSignal;
		flow from conditionSignal.amplifiedSignal to outputReading.signal;
		
		bind detectPressure.pressure = appliedPressure;
		bind outputReading.finalMeasurement = measurement;
	}
	
	state def SensorOperationalStates {
		entry; then powerOn;
		
		state powerOn {
			entry action initializeSensor;
		}
		transition powerOn_to_idle
			first powerOn
			then idle;
		
		state idle;
		transition idle_to_measuring
			first idle
			then measuring;
		
		state measuring {
			entry action startMeasurement;
			do action performMeasurement : MeasurePressure;
			exit action recordMeasurement;
		}
		transition measuring_to_idle
			first measuring
			then idle;
		
		state fault;
		transition to_fault
			first measuring
			then fault;
		
		transition fault_to_idle
			first fault
			then idle;
	}
	
	part def DataProcessor {
		attribute samplingRate : Real;
		attribute bufferSize : Integer;
		
		port dataInput : SignalOutputPort;
		
		action processData {
			in item rawData : ElectricalSignal;
			out item processedData : PressureSignal;
		}
	}
	
	part def ProtectiveHousing {
		attribute material : String;
		attribute ipRating : String;
		attribute maxPressure : ISQ::pressure;
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute serialNumber : String;
		
		part sensor : PressureSensor {
			attribute :>> sensorId = "PS-001";
			attribute :>> calibrationFactor = 1.0;
			attribute :>> operatingTemperature = 298.15[K];
			attribute :>> measurementRange = 500000[Pa];
		}
		
		part processor : DataProcessor {
			attribute :>> samplingRate = 1000.0;
			attribute :>> bufferSize = 256;
		}
		
		part housing : ProtectiveHousing {
			attribute :>> material = "Stainless Steel 316";
			attribute :>> ipRating = "IP67";
			attribute :>> maxPressure = 1000000[Pa];
		}
		
		connect sensor.outputInterface to processor.dataInput;
		
		perform action measurementCycle : MeasurePressure;
		
		exhibit state operationalState : SensorOperationalStates;
	}
	
	requirement def AccuracyRequirement {
		doc /* The pressure sensor shall measure pressure with accuracy within ±0.5% of full scale. */
		
		subject sensor : PressureSensor;
		
		require constraint {
			sensor.calibrationFactor >= 0.995 and sensor.calibrationFactor <= 1.005
		}
	}
	
	requirement def TemperatureRangeRequirement {
		doc /* The sensing unit shall operate within temperature range of -40°C to 85°C. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.operatingTemperature >= 233.15[K] and 
			unit.sensor.operatingTemperature <= 358.15[K]
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall provide measurement output within 10 milliseconds. */
		
		subject unit : SensingUnit;
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitId = "SU-2024-001";
		attribute :>> serialNumber = "SN-123456";
		
		part :>> sensor {
			part :>> sensingElement {
				attribute :>> sensitivity = 0.048;
				attribute :>> offset = 0.02;
			}
			
			part :>> signalConditioner {
				attribute :>> gain = 95.0;
				attribute :>> filterCutoff = 950.0;
			}
		}
		
		part :>> processor {
			attribute :>> samplingRate = 2000.0;
			attribute :>> bufferSize = 512;
		}
	}
	
	individual def TestPressureSource;
	individual def TestSensingUnit :> SensingUnit;
	
	verification sensingUnitAccuracyVerification {
		subject testUnit : SensingUnit;
		
		require accuracyReq : AccuracyRequirement {
			subject sensor : PressureSensor = testUnit.sensor;
		}
		
		require tempRangeReq : TemperatureRangeRequirement {
			subject unit : SensingUnit = testUnit;
		}
	}
	
	individual testSystem : TestSensingUnit :> sensingUnitInstance {
		timeslice calibrationPhase {
			perform action :>> measurementCycle {
				in item :>> appliedPressure : PressureSignal {
					attribute :>> value = 101325[Pa];
					attribute :>> timestamp = 0.0;
				}
				out item :>> measurement : ElectricalSignal {
					attribute :>> voltage = 5.0;
					attribute :>> current = 0.02;
				}
			}
		}
		
		then timeslice operationalPhase {
			perform action :>> measurementCycle {
				in item :>> appliedPressure : PressureSignal {
					attribute :>> value = 300000[Pa];
					attribute :>> timestamp = 1.0;
				}
				out item :>> measurement : ElectricalSignal {
					attribute :>> voltage = 14.8;
					attribute :>> current = 0.02;
				}
			}
		}
		
		then timeslice highPressureTest {
			perform action :>> measurementCycle {
				in item :>> appliedPressure : PressureSignal {
					attribute :>> value = 450000[Pa];
					attribute :>> timestamp = 2.0;
				}
				out item :>> measurement : ElectricalSignal {
					attribute :>> voltage = 22.2;
					attribute :>> current = 0.02;
				}
			}
		}
	}
	
	part multiSensorArray {
		part sensingUnits : SensingUnit[4] {
			attribute :>> unitId;
			part :>> sensor {
				attribute :>> calibrationFactor = 1.0;
				attribute :>> measurementRange = 500000[Pa];
			}
		}
		
		attribute totalArrayMass : ISQ::mass;
		attribute :>> totalArrayMass = 3.2[kg];
	}
}
