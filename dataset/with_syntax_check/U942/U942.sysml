package WaterMeterSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VolumeReading :> ISQ::VolumeValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeUnit;
	}
	
	attribute def FlowRateReading :> ISQ::VolumeFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowRateUnit;
	}
	
	attribute def PressureReading :> ISQ::PressureValue {
		attribute :>> num : Real;
		attribute :>> mRef : PressureUnit;
	}
	
	item def WaterStream {
		attribute flowRate : FlowRateReading;
		attribute pressure : PressureReading;
	}
	
	item def MeasurementRecord {
		attribute cumulativeVolume : VolumeReading;
		attribute currentFlowRate : FlowRateReading;
		attribute timestamp : String;
	}
	
	port def WaterInPort {
		in item waterIn : WaterStream;
	}
	
	port def WaterOutPort {
		out item waterOut : WaterStream;
	}
	
	port def DataPort {
		out item data : MeasurementRecord;
	}
	
	part def FlowSensor {
		port inlet : WaterInPort;
		port outlet : WaterOutPort;
		port sensorOutput : DataPort;
		
		attribute calibrationFactor : Real;
		attribute currentFlowRate : FlowRateReading;
		
		perform action senseFlow {
			in waterFlow : WaterStream;
			out measuredFlowRate : FlowRateReading;
		}
	}
	
	part def VolumeIntegrator {
		attribute totalVolume : VolumeReading;
		attribute lastUpdateTime : TimeValue;
		
		perform action integrateVolume {
			in flowRate : FlowRateReading;
			in deltaTime : TimeValue;
			out volumeIncrement : VolumeReading;
			out updatedTotal : VolumeReading;
		}
	}
	
	part def DisplayModule {
		attribute displayedVolume : VolumeReading;
		attribute displayedFlowRate : FlowRateReading;
		
		perform action updateDisplay {
			in volume : VolumeReading;
			in flowRate : FlowRateReading;
		}
	}
	
	part def DataLogger {
		attribute logInterval : TimeValue;
		attribute lastLogTime : TimeValue;
		
		perform action logMeasurement {
			in record : MeasurementRecord;
			out logStatus : Boolean;
		}
	}
	
	state def MeterStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_active
			first idle
			accept flowStarted
			then active;
		
		state active {
			do action continuousMeasurement;
		}
		
		transition active_to_idle
			first active
			accept flowStopped
			then idle;
		
		transition active_to_error
			first active
			accept sensorFault
			then error;
		
		state error;
		
		transition error_to_idle
			first error
			accept faultCleared
			then idle;
	}
	
	action def MeasureWaterConsumption {
		in waterInput : WaterStream;
		out consumptionRecord : MeasurementRecord;
		
		first start;
		then merge measurementLoop;
		
		then action detectFlow {
			in water : WaterStream = waterInput;
			out flowActive : Boolean;
			out detectedFlowRate : FlowRateReading;
		}
		
		then decide;
			if detectFlow.flowActive then performMeasurement;
			if not detectFlow.flowActive then waitForFlow;
		
		action performMeasurement {
			action captureFlowRate {
				in flowRate : FlowRateReading = detectFlow.detectedFlowRate;
				out capturedRate : FlowRateReading;
			}
			
			then action calculateVolumeIncrement {
				in rate : FlowRateReading = captureFlowRate.capturedRate;
				in timeStep : TimeValue;
				out volumeDelta : VolumeReading;
			}
			
			then action accumulateVolume {
				in increment : VolumeReading = calculateVolumeIncrement.volumeDelta;
				inout total : VolumeReading;
			}
			
			then action createRecord {
				in volume : VolumeReading = accumulateVolume.total;
				in flowRate : FlowRateReading = captureFlowRate.capturedRate;
				out record : MeasurementRecord;
			}
			
			then action updateOutput {
				in record : MeasurementRecord = createRecord.record;
				out finalRecord : MeasurementRecord;
			}
		}
		then measurementLoop;
		
		action waitForFlow;
		then measurementLoop;
		
		then done;
	}
	
	part def WaterMeter {
		port waterInlet : WaterInPort;
		port waterOutlet : WaterOutPort;
		port measurementOutput : DataPort;
		
		part sensor : FlowSensor {
			port redefines inlet connect waterInlet;
			port redefines outlet connect waterOutlet;
		}
		
		part integrator : VolumeIntegrator;
		
		part display : DisplayModule;
		
		part logger : DataLogger;
		
		connection sensorToIntegrator connect sensor.sensorOutput to integrator;
		connection integratorToDisplay connect integrator to display;
		connection integratorToLogger connect integrator to logger;
		connection integratorToOutput connect integrator to measurementOutput;
		
		perform action measureAndRecord : MeasureWaterConsumption;
		
		exhibit state operationalStates : MeterStates;
	}
	
	requirement def <'WM-REQ-001'> AccuracyRequirement {
		doc /* The water meter shall measure volumetric consumption with accuracy within +/- 2% over the operational flow range. */
		
		subject meter : WaterMeter;
		
		require constraint accuracyBound {
			attribute measuredValue : VolumeReading;
			attribute trueValue : VolumeReading;
			attribute errorPercent : Real;
			
			errorPercent == ((measuredValue.num - trueValue.num) / trueValue.num) * 100.0 and
			errorPercent >= -2.0 and errorPercent <= 2.0
		}
	}
	
	requirement def <'WM-REQ-002'> ContinuousRecordingRequirement {
		doc /* The water meter shall continuously accumulate and record total volume consumed during operation. */
		
		subject meter : WaterMeter;
		
		require constraint volumeAccumulation {
			meter.integrator.totalVolume.num >= 0.0
		}
	}
	
	requirement def <'WM-REQ-003'> OperationalRangeRequirement {
		doc /* The water meter shall operate within flow range of 0.02 to 15.0 cubic meters per hour and pressure range of 0.5 to 16.0 bar. */
		
		subject meter : WaterMeter;
		
		require constraint flowRange {
			attribute minFlow : FlowRateReading;
			attribute maxFlow : FlowRateReading;
			attribute operatingFlow : FlowRateReading;
			
			minFlow.num == 0.02 and
			maxFlow.num == 15.0 and
			operatingFlow.num >= minFlow.num and
			operatingFlow.num <= maxFlow.num
		}
		
		require constraint pressureRange {
			attribute minPressure : PressureReading;
			attribute maxPressure : PressureReading;
			attribute operatingPressure : PressureReading;
			
			minPressure.num == 0.5 and
			maxPressure.num == 16.0 and
			operatingPressure.num >= minPressure.num and
			operatingPressure.num <= maxPressure.num
		}
	}
	
	requirement <'WM-SYS-001'> primaryMeteringRequirement {
		doc /* The water meter system shall accurately measure and record cumulative water consumption for billing and monitoring purposes. */
		
		subject meterSystem : WaterMeter;
		
		assume constraint waterSupplyPresent {
			doc /* Water supply is available at inlet with adequate pressure. */
		}
		
		require AccuracyRequirement;
		require ContinuousRecordingRequirement;
		require OperationalRangeRequirement;
	}
	
	part residentialWaterMeter : WaterMeter {
		perform action measureAndRecord[*] ordered references measureAndRecord {
			first start;
			then merge continuousOperation;
			
			then action checkWaterFlow {
				in waterStream : WaterStream;
				out flowDetected : Boolean;
				out measuredRate : FlowRateReading;
			}
			
			then decide;
				if checkWaterFlow.flowDetected then recordFlow;
				if not checkWaterFlow.flowDetected then idleMode;
			
			action recordFlow {
				action measureInstantaneousFlow {
					in rate : FlowRateReading = checkWaterFlow.measuredRate;
					out instantRate : FlowRateReading;
				}
				
				then action computeVolumeIncrement {
					in flowRate : FlowRateReading = measureInstantaneousFlow.instantRate;
					in samplingInterval : TimeValue;
					out volumeAdded : VolumeReading;
				}
				
				then action updateTotalVolume {
					in increment : VolumeReading = computeVolumeIncrement.volumeAdded;
					inout cumulativeVolume : VolumeReading;
				}
				
				then action generateMeasurementRecord {
					in totalVolume : VolumeReading = updateTotalVolume.cumulativeVolume;
					in currentFlow : FlowRateReading = measureInstantaneousFlow.instantRate;
					out dataRecord : MeasurementRecord;
				}
				
				then action outputToDisplay {
					in record : MeasurementRecord = generateMeasurementRecord.dataRecord;
				}
			}
			then continuousOperation;
			
			action idleMode;
			then continuousOperation;
			
			then done;
		}
		
		part redefines sensor : FlowSensor {
			perform measureAndRecord.recordFlow.measureInstantaneousFlow;
		}
		
		part redefines integrator : VolumeIntegrator {
			perform measureAndRecord.recordFlow.updateTotalVolume;
		}
		
		part redefines display : DisplayModule {
			perform measureAndRecord.recordFlow.outputToDisplay;
		}
		
		part redefines logger : DataLogger {
			perform action logMeasurement[*];
		}
	}
}
