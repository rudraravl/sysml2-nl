package 'Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import ScalarFunctions::*;
	
	attribute def SensorID :> String;
	
	attribute def GridCoordinate {
		attribute row : Integer;
		attribute col : Integer;
	}
	
	attribute def TemperatureReading :> TemperatureValue {
		attribute redefines num : Real;
		attribute redefines mRef : TemperatureUnit;
	}
	
	item def RawSensorData {
		attribute reading : TemperatureReading;
		attribute timestamp : TimeValue;
		attribute sensorID : SensorID;
	}
	
	item def ProcessedData {
		attribute value : TemperatureReading;
		attribute position : GridCoordinate;
		attribute quality : Real;
	}
	
	item def AggregatedMeasurement {
		attribute averageValue : TemperatureReading;
		attribute maxValue : TemperatureReading;
		attribute minValue : TemperatureReading;
		attribute variance : Real;
		attribute validSensorCount : Integer;
	}
	
	port def SensorOutputPort {
		out item data : RawSensorData;
	}
	
	port def ProcessorInputPort {
		in item data : RawSensorData;
	}
	
	port def ProcessorOutputPort {
		out item data : ProcessedData;
	}
	
	port def AggregatorInputPort {
		in item data : ProcessedData;
	}
	
	port def UnitOutputPort {
		out item measurement : AggregatedMeasurement;
	}
	
	connection def DataConnection {
		end source : SensorOutputPort[1];
		end target : ProcessorInputPort[1];
	}
	
	connection def ProcessedConnection {
		end source : ProcessorOutputPort[1];
		end target : AggregatorInputPort[1];
	}
	
	part def TemperatureSensor {
		attribute id : SensorID;
		attribute location : GridCoordinate;
		attribute calibrationOffset : TemperatureReading;
		attribute isOperational : Boolean;
		
		port output : SensorOutputPort;
		
		action sense {
			out rawData : RawSensorData;
		}
	}
	
	state def SensorStateMachine {
		entry action initialize;
		
		state Standby;
		
		transition standby_to_active
			first Standby
			accept ActivateSensor
			then Active;
		
		state Active {
			entry action startSensing;
			do action continuousSense;
			exit action stopSensing;
		}
		
		transition active_to_standby
			first Active
			accept DeactivateSensor
			then Standby;
		
		transition active_to_fault
			first Active
			accept SensorError
			then Fault;
		
		state Fault {
			entry action logFault;
			do action attemptRecovery;
		}
		
		transition fault_to_standby
			first Fault
			accept RecoverySuccess
			then Standby;
	}
	
	part def SignalProcessor {
		attribute processorID : String;
		attribute filterCoefficient : Real;
		
		port input : ProcessorInputPort;
		port output : ProcessorOutputPort;
		
		action processSignal {
			in rawData : RawSensorData;
			out processedData : ProcessedData;
			
			action validateData {
				in data : RawSensorData;
				out isValid : Boolean;
			}
			
			then applyCalibration {
				in data : RawSensorData;
				out calibratedData : RawSensorData;
			}
			
			then filterNoise {
				in data : RawSensorData;
				out filteredData : ProcessedData;
			}
			
			flow from validateData.data to applyCalibration.data;
			flow from applyCalibration.calibratedData to filterNoise.data;
			bind filterNoise.filteredData = processedData;
		}
	}
	
	part def DataAggregator {
		attribute aggregatorID : String;
		attribute windowSize : Integer;
		
		port inputs : AggregatorInputPort[*];
		port output : UnitOutputPort;
		
		action aggregateData {
			in measurements : ProcessedData[*];
			out result : AggregatedMeasurement;
			
			action computeAverage {
				in values : ProcessedData[*];
				out avg : TemperatureReading;
			}
			
			then fork;
			
			action computeMax {
				in values : ProcessedData[*];
				out max : TemperatureReading;
			}
			
			then joinNode;
			
			action computeMin {
				in values : ProcessedData[*];
				out min : TemperatureReading;
			}
			
			then joinNode;
			
			action computeVariance {
				in values : ProcessedData[*];
				out variance : Real;
			}
			
			then joinNode;
			
			join joinNode;
			
			then assembleResult {
				in avg : TemperatureReading;
				in max : TemperatureReading;
				in min : TemperatureReading;
				in variance : Real;
				out finalResult : AggregatedMeasurement;
			}
			
			flow from computeAverage.avg to assembleResult.avg;
			flow from computeMax.max to assembleResult.max;
			flow from computeMin.min to assembleResult.min;
			flow from computeVariance.variance to assembleResult.variance;
			bind assembleResult.finalResult = result;
		}
	}
	
	part def SensorGrid {
		attribute gridRows : Integer;
		attribute gridCols : Integer;
		attribute totalSensors : Integer;
		
		part sensors : TemperatureSensor[16];
		part processors : SignalProcessor[16];
		
		connection sensorToProcessor : DataConnection[16]
			connect sensors.output to processors.input;
	}
	
	part def SensingUnit {
		attribute unitID : String;
		attribute measurementRate : FrequencyValue;
		attribute operationalMode : String;
		
		part grid : SensorGrid[1] {
			attribute :>> gridRows = 4;
			attribute :>> gridCols = 4;
			attribute :>> totalSensors = 16;
		}
		
		part aggregator : DataAggregator[1] {
			attribute :>> aggregatorID = "AGG-MAIN";
			attribute :>> windowSize = 100;
		}
		
		port systemOutput : UnitOutputPort;
		
		connection processorToAggregator : ProcessedConnection[16]
			connect grid.processors.output to aggregator.inputs;
		
		bind systemOutput = aggregator.output;
		
		action performMeasurement {
			out measurement : AggregatedMeasurement;
			
			action initializeSensors {
				out initializedGrid : SensorGrid;
			}
			
			then fork;
			
			action collectSensorData {
				in sensorGrid : SensorGrid;
				out rawDataSet : RawSensorData[*];
			}
			
			then joinNode;
			
			action processAllData {
				in rawDataSet : RawSensorData[*];
				out processedDataSet : ProcessedData[*];
			}
			
			then joinNode;
			
			join joinNode;
			
			then aggregateResults {
				in processedDataSet : ProcessedData[*];
				out finalMeasurement : AggregatedMeasurement;
			}
			
			flow from collectSensorData.rawDataSet to processAllData.rawDataSet;
			flow from processAllData.processedDataSet to aggregateResults.processedDataSet;
			bind aggregateResults.finalMeasurement = measurement;
		}
	}
	
	requirement def SensingUnitRequirements {
		doc /* The sensing unit shall measure temperature using a sensor grid and provide aggregated measurements. */
		
		requirement gridCoverageReq {
			doc /* The sensor grid shall contain at least 16 sensors arranged in a 4x4 configuration. */
			subject unit : SensingUnit;
			require constraint {
				unit.grid.totalSensors >= 16
			}
		}
		
		requirement measurementAccuracyReq {
			doc /* Processed measurements shall have quality factor above 0.90. */
			subject data : ProcessedData;
			require constraint {
				data.quality >= 0.90
			}
		}
		
		requirement dataAggregationReq {
			doc /* The aggregator shall compute average, max, min, and variance from all valid sensor readings. */
			subject aggregator : DataAggregator;
		}
		
		requirement sensorRedundancyReq {
			doc /* The system shall operate with at least 12 of 16 sensors functional. */
			subject grid : SensorGrid;
			require constraint {
				grid.sensors->select(s | s.isOperational)->size() >= 12
			}
		}
		
		requirement measurementRateReq {
			doc /* The sensing unit shall provide measurements at a rate of at least 1 Hz. */
			subject unit : SensingUnit;
			require constraint {
				unit.measurementRate >= 1.0[Hz]
			}
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitID = "SU-TEMP-001";
		attribute :>> measurementRate = 10.0[Hz];
		attribute :>> operationalMode = "continuous";
		
		part :>> grid {
			part :>> sensors = (
				s1, s2, s3, s4, s5, s6, s7, s8,
				s9, s10, s11, s12, s13, s14, s15, s16
			);
			
			part s1 : TemperatureSensor {
				attribute :>> id = "TEMP-S01";
				attribute :>> location.row = 1;
				attribute :>> location.col = 1;
				attribute :>> calibrationOffset = 0.0[K];
				attribute :>> isOperational = true;
			}
			
			part s2 : TemperatureSensor {
				attribute :>> id = "TEMP-S02";
				attribute :>> location.row = 1;
				attribute :>> location.col = 2;
				attribute :>> calibrationOffset = 0.1[K];
				attribute :>> isOperational = true;
			}
			
			part s3 : TemperatureSensor {
				attribute :>> id = "TEMP-S03";
				attribute :>> location.row = 1;
				attribute :>> location.col = 3;
				attribute :>> calibrationOffset = -0.05[K];
				attribute :>> isOperational = true;
			}
			
			part s4 : TemperatureSensor {
				attribute :>> id = "TEMP-S04";
				attribute :>> location.row = 1;
				attribute :>> location.col = 4;
				attribute :>> calibrationOffset = 0.15[K];
				attribute :>> isOperational = true;
			}
			
			part s5 : TemperatureSensor {
				attribute :>> id = "TEMP-S05";
				attribute :>> location.row = 2;
				attribute :>> location.col = 1;
				attribute :>> calibrationOffset = 0.0[K];
				attribute :>> isOperational = true;
			}
			
			part s6 : TemperatureSensor {
				attribute :>> id = "TEMP-S06";
				attribute :>> location.row = 2;
				attribute :>> location.col = 2;
				attribute :>> calibrationOffset = -0.1[K];
				attribute :>> isOperational = true;
			}
			
			part s7 : TemperatureSensor {
				attribute :>> id = "TEMP-S07";
				attribute :>> location.row = 2;
				attribute :>> location.col = 3;
				attribute :>> calibrationOffset = 0.05[K];
				attribute :>> isOperational = true;
			}
			
			part s8 : TemperatureSensor {
				attribute :>> id = "TEMP-S08";
				attribute :>> location.row = 2;
				attribute :>> location.col = 4;
				attribute :>> calibrationOffset = 0.0[K];
				attribute :>> isOperational = true;
			}
			
			part s9 : TemperatureSensor {
				attribute :>> id = "TEMP-S09";
				attribute :>> location.row = 3;
				attribute :>> location.col = 1;
				attribute :>> calibrationOffset = 0.2[K];
				attribute :>> isOperational = true;
			}
			
			part s10 : TemperatureSensor {
				attribute :>> id = "TEMP-S10";
				attribute :>> location.row = 3;
				attribute :>> location.col = 2;
				attribute :>> calibrationOffset = -0.15[K];
				attribute :>> isOperational = true;
			}
			
			part s11 : TemperatureSensor {
				attribute :>> id = "TEMP-S11";
				attribute :>> location.row = 3;
				attribute :>> location.col = 3;
				attribute :>> calibrationOffset = 0.0[K];
				attribute :>> isOperational = true;
			}
			
			part s12 : TemperatureSensor {
				attribute :>> id = "TEMP-S12";
				attribute :>> location.row = 3;
				attribute :>> location.col = 4;
				attribute :>> calibrationOffset = 0.1[K];
				attribute :>> isOperational = true;
			}
			
			part s13 : TemperatureSensor {
				attribute :>> id = "TEMP-S13";
				attribute :>> location.row = 4;
				attribute :>> location.col = 1;
				attribute :>> calibrationOffset = -0.05[K];
				attribute :>> isOperational = true;
			}
			
			part s14 : TemperatureSensor {
				attribute :>> id = "TEMP-S14";
				attribute :>> location.row = 4;
				attribute :>> location.col = 2;
				attribute :>> calibrationOffset = 0.0[K];
				attribute :>> isOperational = true;
			}
			
			part s15 : TemperatureSensor {
				attribute :>> id = "TEMP-S15";
				attribute :>> location.row = 4;
				attribute :>> location.col = 3;
				attribute :>> calibrationOffset = 0.15[K];
				attribute :>> isOperational = true;
			}
			
			part s16 : TemperatureSensor {
				attribute :>> id = "TEMP-S16";
				attribute :>> location.row = 4;
				attribute :>> location.col = 4;
				attribute :>> calibrationOffset = -0.1[K];
				attribute :>> isOperational = true;
			}
			
			part :>> processors = (
				p1, p2, p3, p4, p5, p6, p7, p8,
				p9, p10, p11, p12, p13, p14, p15, p16
			);
			
			part p1 : SignalProcessor {
				attribute :>> processorID = "PROC-01";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p2 : SignalProcessor {
				attribute :>> processorID = "PROC-02";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p3 : SignalProcessor {
				attribute :>> processorID = "PROC-03";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p4 : SignalProcessor {
				attribute :>> processorID = "PROC-04";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p5 : SignalProcessor {
				attribute :>> processorID = "PROC-05";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p6 : SignalProcessor {
				attribute :>> processorID = "PROC-06";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p7 : SignalProcessor {
				attribute :>> processorID = "PROC-07";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p8 : SignalProcessor {
				attribute :>> processorID = "PROC-08";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p9 : SignalProcessor {
				attribute :>> processorID = "PROC-09";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p10 : SignalProcessor {
				attribute :>> processorID = "PROC-10";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p11 : SignalProcessor {
				attribute :>> processorID = "PROC-11";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p12 : SignalProcessor {
				attribute :>> processorID = "PROC-12";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p13 : SignalProcessor {
				attribute :>> processorID = "PROC-13";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p14 : SignalProcessor {
				attribute :>> processorID = "PROC-14";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p15 : SignalProcessor {
				attribute :>> processorID = "PROC-15";
				attribute :>> filterCoefficient = 0.85;
			}
			
			part p16 : SignalProcessor {
				attribute :>> processorID = "PROC-16";
				attribute :>> filterCoefficient = 0.85;
			}
		}
	}
	
	satisfy gridCoverageReq : SensingUnitRequirements::gridCoverageReq {
		subject unit = sensingUnitInstance;
	}
	
	satisfy measurementRateReq : SensingUnitRequirements::measurementRateReq {
		subject unit = sensingUnitInstance;
	}
}
