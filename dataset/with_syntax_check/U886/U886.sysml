package 'Soil Moisture Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	attribute def PercentUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[1];
	}
	
	attribute def PercentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : PercentUnit;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	attribute def TemperatureValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	attribute def TimeValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	attribute def CapacitanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	attribute def CurrentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	attribute def LengthValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	attribute def VolumetricWaterContentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MeasurementUnit;
	}
	
	item def SoilSample {
		attribute moisture : VolumetricWaterContentValue;
		attribute temperature : TemperatureValue;
		attribute depth : LengthValue;
	}
	
	item def MoistureReading {
		attribute moistureLevel : PercentValue;
		attribute rawVoltage : VoltageValue;
		attribute timestamp : TimeValue;
		attribute sensorTemperature : TemperatureValue;
	}
	
	port def PowerPort {
		attribute supplyVoltage : VoltageValue;
		attribute currentDraw : CurrentValue;
	}
	
	port def DataOutputPort {
		out item reading : MoistureReading;
	}
	
	port def SoilInterfacePort {
		in item sample : SoilSample;
	}
	
	part def CapacitiveSensor {
		port soilInterface : SoilInterfacePort;
		attribute operatingFrequency : FrequencyValue;
		attribute capacitance : CapacitanceValue;
		
		action measureCapacitance {
			in soilMoisture : VolumetricWaterContentValue;
			out measuredCapacitance : CapacitanceValue;
		}
	}
	
	part def SignalProcessor {
		attribute conversionFactor : Real;
		attribute offsetVoltage : VoltageValue;
		
		action processSignal {
			in rawCapacitance : CapacitanceValue;
			in temperature : TemperatureValue;
			out calibratedVoltage : VoltageValue;
			out moisturePercent : PercentValue;
		}
	}
	
	part def TemperatureSensor {
		attribute accuracy : TemperatureValue;
		
		action measureTemperature {
			out temp : TemperatureValue;
		}
	}
	
	part def Microcontroller {
		port powerIn : PowerPort;
		port dataOut : DataOutputPort;
		
		action collectData {
			in voltage : VoltageValue;
			in moisture : PercentValue;
			in temp : TemperatureValue;
			out reading : MoistureReading;
		}
	}
	
	state def SensorOperationStates {
		entry; then idle;
		state idle;
		transition powerOn first idle then calibrating;
		state calibrating;
		transition calibrationComplete first calibrating then measuring;
		state measuring;
		transition measurementCaptured first measuring then processing;
		state processing;
		transition processingComplete first processing then reporting;
		state reporting;
		transition reportComplete first reporting then measuring;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The sensor shall measure soil moisture with accuracy within +/- 3 percent VWC */
		subject sensor : SoilMoistureSensor;
		require constraint {
			sensor.measurementAccuracy.num <= 3.0
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensor shall provide a reading within 2 seconds of activation */
		subject sensor : SoilMoistureSensor;
		require constraint {
			sensor.responseTime.num <= 2.0
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The sensor shall operate in soil moisture range from 0 to 100 percent VWC */
		subject sensor : SoilMoistureSensor;
		require constraint {
			sensor.minMeasurableRange.num >= 0.0 and
			sensor.maxMeasurableRange.num <= 100.0
		}
	}
	
	part def SoilMoistureSensor {
		port powerPort : PowerPort;
		port dataPort : DataOutputPort;
		port soilPort : SoilInterfacePort;
		
		attribute measurementAccuracy : PercentValue;
		attribute responseTime : TimeValue;
		attribute minMeasurableRange : PercentValue;
		attribute maxMeasurableRange : PercentValue;
		attribute operatingTemperatureMin : TemperatureValue;
		attribute operatingTemperatureMax : TemperatureValue;
		
		part capacitiveSensor : CapacitiveSensor[1];
		part signalProcessor : SignalProcessor[1];
		part tempSensor : TemperatureSensor[1];
		part microcontroller : Microcontroller[1];
		
		connect soilPort to capacitiveSensor.soilInterface;
		connect powerPort to microcontroller.powerIn;
		connect dataPort to microcontroller.dataOut;
		
		state behavior : SensorOperationStates;
		
		action performMeasurement {
			in item soil : SoilSample;
			out item measurement : MoistureReading;
			
			action sense : CapacitiveSensor::measureCapacitance {
				in :>> soilMoisture = soil.moisture;
				out capacitance : CapacitanceValue;
			}
			then fork;
			
			action measureTemp : TemperatureSensor::measureTemperature {
				out temperature : TemperatureValue;
			}
			then joinNode;
			
			action process : SignalProcessor::processSignal {
				in :>> rawCapacitance = sense.capacitance;
				in :>> temperature = measureTemp.temperature;
				out voltage : VoltageValue;
				out moisture : PercentValue;
			}
			then joinNode;
			
			join joinNode;
			then action collect : Microcontroller::collectData {
				in :>> voltage = process.voltage;
				in :>> moisture = process.moisture;
				in :>> temp = measureTemp.temperature;
				out :>> reading;
			}
			
			bind collect.reading = measurement;
		}
	}
	
	part def SensingUnit {
		port powerInput : PowerPort;
		port measurementOutput : DataOutputPort;
		port soilInput : SoilInterfacePort;
		
		part sensor : SoilMoistureSensor[1];
		
		connect powerInput to sensor.powerPort;
		connect measurementOutput to sensor.dataPort;
		connect soilInput to sensor.soilPort;
		
		perform action measure {
			in item soilSample : SoilSample;
			out item moistureData : MoistureReading;
			
			action executeMeasurement : SoilMoistureSensor::performMeasurement {
				in :>> soil = soilSample;
				out :>> measurement;
			}
			
			bind executeMeasurement.measurement = moistureData;
		}
	}
	
	part sensingUnit : SensingUnit {
		part :>> sensor {
			attribute :>> measurementAccuracy {
				attribute :>> num = 3.0;
			}
			attribute :>> responseTime {
				attribute :>> num = 1.5;
			}
			attribute :>> minMeasurableRange {
				attribute :>> num = 0.0;
			}
			attribute :>> maxMeasurableRange {
				attribute :>> num = 100.0;
			}
			attribute :>> operatingTemperatureMin {
				attribute :>> num = 233.15;
			}
			attribute :>> operatingTemperatureMax {
				attribute :>> num = 333.15;
			}
			
			part :>> capacitiveSensor {
				attribute :>> operatingFrequency {
					attribute :>> num = 70.0e6;
				}
			}
			
			part :>> signalProcessor {
				attribute :>> conversionFactor = 0.0012;
				attribute :>> offsetVoltage {
					attribute :>> num = 0.5;
				}
			}
			
			part :>> tempSensor {
				attribute :>> accuracy {
					attribute :>> num = 0.5;
				}
			}
			
			part :>> microcontroller {
				port :>> powerIn {
					attribute :>> supplyVoltage {
						attribute :>> num = 3.3;
					}
					attribute :>> currentDraw {
						attribute :>> num = 0.025;
					}
				}
			}
		}
		
		satisfy measurementReq : MeasurementAccuracyRequirement {
			subject sensor = sensingUnit.sensor;
		}
		
		satisfy responseReq : ResponseTimeRequirement {
			subject sensor = sensingUnit.sensor;
		}
		
		satisfy rangeReq : OperatingRangeRequirement {
			subject sensor = sensingUnit.sensor;
		}
	}
	
	individual def FieldTest :> SensingUnit;
	individual def TestSoil :> SoilSample;
	
	individual fieldTest : FieldTest :> sensingUnit {
		timeslice drySoilTest {
			perform action testMeasure : SensingUnit::measure {
				in individual testSoil : TestSoil {
					attribute :>> moisture {
						attribute :>> num = 0.15;
					}
					attribute :>> temperature {
						attribute :>> num = 298.15;
					}
					attribute :>> depth {
						attribute :>> num = 0.1;
					}
				}
				out individual expectedReading : MoistureReading {
					attribute :>> moistureLevel {
						attribute :>> num = 15.0;
					}
				}
			}
		}
		then timeslice wetSoilTest {
			perform action testMeasure2 : SensingUnit::measure {
				in individual testSoil2 : TestSoil {
					attribute :>> moisture {
						attribute :>> num = 0.45;
					}
					attribute :>> temperature {
						attribute :>> num = 295.15;
					}
					attribute :>> depth {
						attribute :>> num = 0.1;
					}
				}
				out individual expectedReading2 : MoistureReading {
					attribute :>> moistureLevel {
						attribute :>> num = 45.0;
					}
				}
			}
		}
	}
}
