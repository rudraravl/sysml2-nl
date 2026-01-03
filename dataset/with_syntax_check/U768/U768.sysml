package 'Mass Flow Sensing Unit' {
	private import ScalarValues::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MassFlowRateUnit :> DerivedUnit {
		private attribute massPF: QuantityPowerFactor[1] {
			:>> quantity = isq.M;
			:>> exponent = 1;
		}
		private attribute durationPF: QuantityPowerFactor[1] {
			:>> quantity = isq.T;
			:>> exponent = -1;
		}
		attribute :>> quantityDimension {
			:>> quantityPowerFactors = (massPF, durationPF);
		}
	}
	
	attribute <'kg/s'> kilogramPerSecond : MassFlowRateUnit = kg / s;
	
	attribute def MassFlowRateValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MassFlowRateUnit;
	}
	
	attribute def TemperatureUnit :> SimpleUnit;
	
	attribute def TemperatureValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TemperatureUnit;
	}
	
	attribute def PressureUnit :> DerivedUnit {
		private attribute lengthPF: QuantityPowerFactor[1] {
			:>> quantity = isq.L;
			:>> exponent = -1;
		}
		private attribute massPF: QuantityPowerFactor[1] {
			:>> quantity = isq.M;
			:>> exponent = 1;
		}
		private attribute durationPF: QuantityPowerFactor[1] {
			:>> quantity = isq.T;
			:>> exponent = -2;
		}
		attribute :>> quantityDimension {
			:>> quantityPowerFactors = (lengthPF, massPF, durationPF);
		}
	}
	
	attribute <'kPa'> kilopascal : PressureUnit = 1000.0 * (kg / (m * s^2));
	
	attribute def PressureValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : PressureUnit;
	}
	
	attribute def AccuracyValue :> DimensionOneValue;
	
	item def ProcessFluid {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute density : Real;
	}
	
	port def FluidPort {
		in item fluid : ProcessFluid;
		attribute flowRate : MassFlowRateValue;
	}
	
	port def DataOutputPort {
		out attribute massFlowRate : MassFlowRateValue;
		out attribute temperature : TemperatureValue;
		out attribute pressure : PressureValue;
		out attribute status : SensorStatus;
	}
	
	enum def SensorStatus {
		enum Initializing;
		enum Ready;
		enum Measuring;
		enum Fault;
	}
	
	action def MeasureFlow {
		in fluidInput : ProcessFluid;
		in inputFlowRate : MassFlowRateValue;
		out measuredFlowRate : MassFlowRateValue;
		out measuredTemperature : TemperatureValue;
		out measuredPressure : PressureValue;
	}
	
	part def MassFlowSensor {
		attribute accuracy : AccuracyValue;
		attribute rangeMin : MassFlowRateValue;
		attribute rangeMax : MassFlowRateValue;
		attribute responseTime : DurationValue;
		attribute currentStatus : SensorStatus default SensorStatus::Initializing;
		
		port inlet : FluidPort;
		port outlet : FluidPort;
		port dataOutput : DataOutputPort;
		
		perform action sensingOperation : MeasureFlow {
			in fluidInput = inlet.fluid;
			in inputFlowRate = inlet.flowRate;
			out :>> measuredFlowRate;
			out :>> measuredTemperature;
			out :>> measuredPressure;
		}
	}
	
	part def SignalProcessor {
		port sensorInput : DataOutputPort;
		port processedOutput : DataOutputPort;
		
		attribute filterCoefficient : Real default 0.9;
		
		perform action processSignal {
			in rawFlowRate : MassFlowRateValue;
			in rawTemperature : TemperatureValue;
			in rawPressure : PressureValue;
			out filteredFlowRate : MassFlowRateValue;
			out filteredTemperature : TemperatureValue;
			out filteredPressure : PressureValue;
		}
	}
	
	part def SensingUnit {
		attribute unitID : String;
		attribute calibrationDate : String;
		
		port fluidInlet : FluidPort;
		port fluidOutlet : FluidPort;
		port dataInterface : DataOutputPort;
		
		part sensor : MassFlowSensor {
			attribute :>> accuracy = 0.015[one];
			attribute :>> rangeMin = 0.0['kg/s'];
			attribute :>> rangeMax = 100.0['kg/s'];
			attribute :>> responseTime = 0.1[s];
		}
		
		part processor : SignalProcessor {
			attribute :>> filterCoefficient = 0.92;
		}
		
		connection fluidInput
			connect fluidInlet to sensor.inlet;
		
		connection fluidOutput
			connect sensor.outlet to fluidOutlet;
		
		connection sensorData
			connect sensor.dataOutput to processor.sensorInput;
		
		connection processedData
			connect processor.processedOutput to dataInterface;
		
		perform action operationSequence {
			action initialize {
				out initStatus : SensorStatus = SensorStatus::Initializing;
			}
			then action startMeasuring {
				in :>> initStatus;
				out measureStatus : SensorStatus = SensorStatus::Measuring;
			}
			then action continuousMeasure {
				in :>> measureStatus;
				in fluidStream : ProcessFluid;
				out flowData : MassFlowRateValue;
			}
			then action processData {
				in :>> flowData;
				out finalData : MassFlowRateValue;
			}
		}
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The mass flow sensor shall measure flow rate with accuracy better than 2% of full scale. */
		
		subject sensor : MassFlowSensor;
		
		require constraint {
			sensor.accuracy <= 0.02[one]
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensing unit shall respond to flow changes within 100 milliseconds. */
		
		subject unit : SensingUnit;
		
		require constraint {
			unit.sensor.responseTime <= 0.1[s]
		}
	}
	
	requirement def MeasurementRangeRequirement {
		doc /* The sensor shall measure mass flow rate from 0 to 100 kg/s. */
		
		subject sensor : MassFlowSensor;
		
		require constraint {
			sensor.rangeMin.num == 0.0 and
			sensor.rangeMax.num >= 100.0
		}
	}
	
	part def FluidSource {
		port outflow : FluidPort;
	}
	
	part def FluidDestination {
		port inflow : FluidPort;
	}
	
	connection def FluidConnection {
		end source : FluidPort;
		end destination : FluidPort;
	}
	
	part sensingSystem : SensingUnit {
		attribute :>> unitID = "MFS-2024-001";
		attribute :>> calibrationDate = "2024-01-15";
		
		part source : FluidSource;
		part destination : FluidDestination;
		
		connection inputLine : FluidConnection
			connect source.outflow to fluidInlet;
		
		connection outputLine : FluidConnection
			connect fluidOutlet to destination.inflow;
		
		satisfy accuracyReq;
		satisfy responseReq;
		satisfy rangeReq;
	}
	
	requirement accuracyReq : MeasurementAccuracyRequirement {
		subject testSensor :> sensor = sensingSystem.sensor;
	}
	
	requirement responseReq : ResponseTimeRequirement {
		subject testUnit :> unit = sensingSystem;
	}
	
	requirement rangeReq : MeasurementRangeRequirement {
		subject testSensor :> sensor = sensingSystem.sensor;
	}
	
	individual def WaterFluid :> ProcessFluid;
	individual def TestSensingUnit :> SensingUnit;
	
	individual testSystem : TestSensingUnit :> sensingSystem {
		attribute :>> unitID = "MFS-TEST-001";
		
		timeslice lowFlowTest {
			perform action :>> operationSequence {
				action :>> continuousMeasure {
					in individual waterSample : WaterFluid {
						:>> temperature = 298.15[K];
						:>> pressure = 101.325[kPa];
						:>> density = 997.0;
					}
					in individual :>> fluidStream = waterSample;
					out :>> flowData = 25.5['kg/s'];
				}
			}
		}
		
		then timeslice highFlowTest {
			perform action :>> operationSequence {
				action :>> continuousMeasure {
					in individual waterSample : WaterFluid {
						:>> temperature = 303.15[K];
						:>> pressure = 150.0[kPa];
						:>> density = 995.0;
					}
					in individual :>> fluidStream = waterSample;
					out :>> flowData = 75.8['kg/s'];
				}
			}
		}
	}
}
