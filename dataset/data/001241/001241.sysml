package 'Sensing Unit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SensorID :> String;
	attribute def Timestamp :> Real;
	
	attribute def SensorReading {
		attribute value : TemperatureValue;
		attribute timestamp : Timestamp;
		attribute sensorId : SensorID;
		attribute isValid : Boolean;
	}
	
	attribute def AggregatedMeasurement {
		attribute averageValue : TemperatureValue;
		attribute minValue : TemperatureValue;
		attribute maxValue : TemperatureValue;
		attribute sampleCount : Integer;
		attribute timestamp : Timestamp;
	}
	
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	
	port def SensorDataPort {
		out reading : SensorReading;
	}
	
	port def AggregatedDataPort {
		out measurement : AggregatedMeasurement;
	}
	
	port def ControlPort {
		in calibrationCommand : Real;
		out status : Boolean;
	}
	
	connection def SensorDataConnection {
		end source : SensorDataPort;
		end target : SensorDataPort;
	}
	
	part def Sensor {
		attribute id : SensorID;
		attribute isActive : Boolean default = true;
		attribute calibrationOffset : TemperatureValue default = 0.0[K];
		attribute measurementRange : TemperatureValue[2];
		attribute currentReading : SensorReading;
		
		port dataOut : SensorDataPort;
		port control : ControlPort;
		
		action measure {
			out reading : SensorReading;
			attribute rawValue : TemperatureValue;
			attribute :>> reading.value = rawValue + calibrationOffset;
			attribute :>> reading.sensorId = id;
			attribute :>> reading.isValid = isActive;
			bind reading = currentReading;
		}
		
		action calibrate {
			in offset : Real;
			out calibrationSuccess : Boolean;
			attribute :>> calibrationOffset = offset[K];
			attribute :>> calibrationSuccess = true;
		}
		
		state machine SensorStateMachine {
			initial state idle;
			
			transition idle_to_measuring
				first idle
				accept MeasureCommand
				then measuring;
			
			state measuring {
				entry performMeasurement : measure;
			}
			
			transition measuring_to_idle
				first measuring
				accept MeasurementComplete
				then idle;
			
			state calibrating;
			
			transition idle_to_calibrating
				first idle
				accept CalibrateCommand
				then calibrating;
			
			transition calibrating_to_idle
				first calibrating
				accept CalibrationComplete
				then idle;
			
			state fault;
			
			transition any_to_fault
				accept FaultDetected
				then fault;
			
			transition fault_to_idle
				first fault
				accept Reset
				then idle;
		}
	}
	
	part def TemperatureSensor :> Sensor {
		attribute :>> measurementRange = (-40.0[K], 125.0[K]);
	}
	
	part def DataAggregator {
		in port sensorInputs : SensorDataPort[*];
		out port aggregatedOutput : AggregatedDataPort;
		
		attribute bufferSize : Integer default = 100;
		attribute readingBuffer : SensorReading[*];
		attribute currentAggregation : AggregatedMeasurement;
		
		action collectReadings {
			in readings : SensorReading[*];
			out bufferedReadings : SensorReading[*];
			attribute validReadings : SensorReading[*];
			attribute :>> bufferedReadings = validReadings;
		}
		
		action computeStatistics {
			in readings : SensorReading[*];
			out aggregated : AggregatedMeasurement;
			attribute values : TemperatureValue[*];
			attribute :>> aggregated.averageValue = sum(values) / size(values);
			attribute :>> aggregated.sampleCount = size(values);
		}
		
		action aggregateData {
			in item sensorData : SensorReading[*];
			out item result : AggregatedMeasurement;
			
			action collect : collectReadings {
				in readings = sensorData;
				out bufferedReadings;
			}
			
			succession collect then compute;
			
			action compute : computeStatistics {
				in readings = collect.bufferedReadings;
				out aggregated;
			}
			
			bind compute.aggregated = result;
		}
	}
	
	part def SensorArray {
		attribute arraySize : Integer;
		attribute sensorType : String;
		
		part sensors : TemperatureSensor[*];
		part aggregator : DataAggregator[1];
		
		port arrayOutput : AggregatedDataPort;
		port arrayControl : ControlPort;
		
		connect sensors.dataOut to aggregator.sensorInputs;
		connect aggregator.aggregatedOutput to arrayOutput;
	}
	
	part def SensingController {
		port controlPort : ControlPort;
		port arrayControlPort : ControlPort;
		
		attribute measurementSchedule : Real;
		
		action scheduleMeasurements {
			in interval : Real;
			out triggerTime : Timestamp;
		}
		
		action processCommand {
			in command : String;
			out response : String;
		}
		
		action initSystem;
		
		state machine ControllerStateMachine {
			initial state initializing {
				entry initSystem;
			}
			
			transition init_to_ready
				first initializing
				accept InitComplete
				then ready;
			
			state ready;
			
			transition ready_to_operating
				first ready
				accept StartOperation
				then operating;
			
			state operating {
				state continuousMeasurement {
					entry scheduleMeasurements;
				}
			}
			
			transition operating_to_ready
				first operating
				accept StopOperation
				then ready;
			
			state maintenance;
			
			transition ready_to_maintenance
				first ready
				accept MaintenanceRequest
				then maintenance;
			
			transition maintenance_to_ready
				first maintenance
				accept MaintenanceComplete
				then ready;
		}
	}
	
	part def PowerSupply {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute powerRating : ISQ::PowerValue;
		
		action supplyPower {
			out power : ISQ::PowerValue;
		}
	}
	
	part def SensingUnit {
		attribute unitId : String;
		attribute measurementInterval : Real default = 1.0;
		
		part sensorArray : SensorArray[1];
		part controller : SensingController[1];
		part powerSupply : PowerSupply[1];
		
		port dataOutput : AggregatedDataPort;
		port commandInput : ControlPort;
		
		connect sensorArray.arrayOutput to dataOutput;
		connect commandInput to controller.controlPort;
		connect controller.arrayControlPort to sensorArray.arrayControl;
	}
	
	requirement def SensingUnitRequirements {
		doc /* The sensing unit shall meet operational requirements */
		
		requirement measurementAccuracy {
			doc /* The sensor array shall provide measurements with accuracy within ±2% of full scale */
			subject sensingUnit : SensingUnit;
		}
		
		requirement dataUpdateRate {
			doc /* The sensing unit shall provide updated measurements at least once per second */
			subject sensingUnit : SensingUnit;
			require constraint {
				sensingUnit.measurementInterval <= 1.0
			}
		}
		
		requirement sensorRedundancy {
			doc /* The sensor array shall contain at least 3 active sensors for redundancy */
			subject array : SensorArray;
		}
		
		requirement faultTolerance {
			doc /* The sensing unit shall continue operation with at least 2 functional sensors */
			subject sensingUnit : SensingUnit;
		}
	}
	
	part temperatureSensingUnit : SensingUnit {
		attribute :>> unitId = "TSU-001";
		attribute :>> measurementInterval = 0.5;
		
		part :>> sensorArray : SensorArray {
			attribute :>> arraySize = 4;
			attribute :>> sensorType = "Temperature";
			
			part :>> sensors : TemperatureSensor[4] {
				part sensor1 : TemperatureSensor {
					attribute :>> id = "TEMP-01";
					attribute :>> measurementRange = (-40.0[K], 125.0[K]);
				}
				part sensor2 : TemperatureSensor {
					attribute :>> id = "TEMP-02";
					attribute :>> measurementRange = (-40.0[K], 125.0[K]);
				}
				part sensor3 : TemperatureSensor {
					attribute :>> id = "TEMP-03";
					attribute :>> measurementRange = (-40.0[K], 125.0[K]);
				}
				part sensor4 : TemperatureSensor {
					attribute :>> id = "TEMP-04";
					attribute :>> measurementRange = (-40.0[K], 125.0[K]);
				}
			}
			
			part :>> aggregator {
				attribute :>> bufferSize = 200;
			}
		}
		
		part :>> controller {
			attribute :>> measurementSchedule = 0.5;
		}
		
		part :>> powerSupply {
			attribute :>> voltage = 24.0[V];
			attribute :>> current = 2.0[A];
			attribute :>> powerRating = 48.0[W];
		}
	}
	
	action def SensingOperation {
		in item unit : SensingUnit;
		out item measurements : AggregatedMeasurement[*];
		
		action startUnit {
			in item sensingUnit : SensingUnit;
		}
		
		then fork;
		
		then action measureContinuously {
			action triggerMeasurement {
				in item sensors : Sensor[*];
				out item readings : SensorReading[*];
			}
			
			then action aggregate {
				in item readings : SensorReading[*];
				out item result : AggregatedMeasurement;
			}
		}
		
		then action monitorHealth {
			action checkSensors {
				in item sensors : Sensor[*];
				out item status : Boolean[*];
			}
			
			then action handleFaults {
				in item status : Boolean[*];
			}
		}
		
		join joinNode;
		
		then action stopUnit {
			in item sensingUnit : SensingUnit;
		}
	}
	
	verification sensingUnitVerification : SensingUnitRequirements {
		subject testUnit :> temperatureSensingUnit;
	}
}
