package AngularRateSensingUnit {
	import ScalarValues::*;
	import ISQ::*;
	import ScalarFunctions::*;

	// ---------- Value Types with Units ----------
	value type AngularRate :> Real {
		unit 'rad/s';
	}
	value type Voltage :> Real {
		unit 'V';
	}
	value type Frequency :> Real {
		unit 'Hz';
	}
	value type TimeStamp :> Real {
		unit 's';
	}
	value type AccuracyPercent :> Real {
		unit '%';
	}
	value type Temperature :> Real {
		unit 'degC';
	}

	// ---------- Item Types ----------
	item RawAngularRateSignal {
		value magnitude : AngularRate;
		value noiseLevel : AngularRate;
	}
	item AmplifiedSignal {
		value magnitude : AngularRate;
		value gain : Real;
	}
	item FilteredSignal {
		value magnitude : AngularRate;
		value cutoffFrequency : Frequency;
	}
	item AnalogMeasurement {
		value magnitude : AngularRate;
	}
	item DigitalMeasurement {
		value magnitude : AngularRate;
		value timestamp : TimeStamp;
		value valid : Boolean;
	}
	item PowerOnEvent;
	item ResetEvent;
	item FaultEvent;
	item CalibrationCompleteEvent;
	item MeasurementCycleCompleteEvent;

	// ---------- Port Definitions ----------
	port def PowerPort {
		out voltage : Voltage;
	}
	port def AnalogOutputPort {
		out analogSignal : AnalogMeasurement;
	}
	port def DigitalOutputPort {
		out digitalStream : DigitalMeasurement;
	}
	port def RawSignalPort {
		out raw : RawAngularRateSignal;
	}
	port def FilteredSignalPort {
		out filtered : FilteredSignal;
	}
	port def DigitalStreamPort {
		out digital : DigitalMeasurement;
	}

	// ---------- Sub-Parts ----------
	part GyroscopicElement {
		attribute maxRate : AngularRate = 500 [AngularRate];
		attribute operatingTemperature : Temperature;
		port rawOut : RawSignalPort;

		action def DetectRotation {
			in physicalRotation : AngularRate;
			out raw : RawAngularRateSignal;
		}

		action detect : DetectRotation {
			out raw : RawAngularRateSignal;
		}
	}

	part SignalProcessor {
		attribute gain : Real = 100.0;
		attribute cutoffFrequency : Frequency = 100 [Frequency];
		port rawIn : RawSignalPort;
		port filteredOut : FilteredSignalPort;

		action def Amplify {
			in raw : RawAngularRateSignal;
			out amplified : AmplifiedSignal;
		}

		action def LowPassFilter {
			in amplified : AmplifiedSignal;
			out filtered : FilteredSignal;
		}

		action amplify : Amplify;
		action filter : LowPassFilter;

		flow from rawIn.raw to amplify.in.raw;
		flow from amplify.out.amplified to filter.in.amplified;
		flow from filter.out.filtered to filteredOut.filtered;
	}

	part ADC {
		attribute samplingRate : Frequency = 1000 [Frequency];
		attribute resolutionBits : Integer = 16;
		port analogIn : FilteredSignalPort;
		port digitalOut : DigitalStreamPort;

		action def Convert {
			in analog : FilteredSignal;
			out digital : DigitalMeasurement;
		}

		action convert : Convert;

		flow from analogIn.filtered to convert.in.analog;
		flow from convert.out.digital to digitalOut.digital;
	}

	part PowerSupply {
		attribute nominalVoltage : Voltage = 5 [Voltage];
		attribute regulationTolerance : Voltage = 0.05 [Voltage];
		port supplyOut : PowerPort;

		action def Regulate {
			in inputVoltage : Voltage;
			out regulatedVoltage : Voltage;
		}

		action regulate : Regulate;

		flow from regulate.out.regulatedVoltage to supplyOut.voltage;
	}

	part DataProcessor {
		attribute clockFrequency : Frequency = 8 [Frequency];
		port digitalIn : DigitalStreamPort;
		port processedOut : DigitalOutputPort;

		action def ProcessData {
			in digital : DigitalMeasurement;
			out processed : DigitalMeasurement;
		}

		action process : ProcessData;

		flow from digitalIn.digital to process.in.digital;
		flow from process.out.processed to processedOut.digitalStream;
	}

	// ---------- Angular Rate Sensor (Core) ----------
	part AngularRateSensor {
		part gyroscopicElement : GyroscopicElement;
		part signalProcessor : SignalProcessor;
		part adc : ADC;
		part powerSupply : PowerSupply;

		port powerIn : PowerPort;
		port analogOut : AnalogOutputPort;
		port digitalOut : DigitalStreamPort;

		// Internal connections
		connection powerToGyro
			from powerSupply.supplyOut.voltage to gyroscopicElement.powerIn.voltage;
		connection powerToProcessor
			from powerSupply.supplyOut.voltage to signalProcessor.powerIn.voltage;
		connection powerToADC
			from powerSupply.supplyOut.voltage to adc.powerIn.voltage;
		connection rawToProcessor
			from gyroscopicElement.rawOut.raw to signalProcessor.rawIn.raw;
		connection filteredToADC
			from signalProcessor.filteredOut.filtered to adc.analogIn.filtered;
		connection filteredToAnalogOut
			from signalProcessor.filteredOut.filtered to analogOut.analogSignal;
		connection digitalToOut
			from adc.digitalOut.digital to digitalOut.digital;
	}

	// ---------- Top-Level Angular Rate Sensing Unit ----------
	part AngularRateSensingUnit {
		part sensor : AngularRateSensor;
		part dataProcessor : DataProcessor;
		part powerSupply : PowerSupply;

		port externalPower : PowerPort;
		port analogOutput : AnalogOutputPort;
		port digitalOutput : DigitalOutputPort;

		attribute manufacturer : String = "SensorCorp";
		attribute modelNumber : String = "ARS-500";
		attribute maxMeasurableRate : AngularRate = 500 [AngularRate];
		attribute accuracy : AccuracyPercent = 1.0 [AccuracyPercent];

		// External connections
		connection externalPowerFeed
			from externalPower.voltage to powerSupply.supplyIn.inputVoltage;
		connection internalPowerFeed
			from powerSupply.supplyOut.voltage to sensor.powerIn.voltage;
		connection sensorAnalogOut
			from sensor.analogOut.analogSignal to analogOutput.analogSignal;
		connection sensorDigitalOut
			from sensor.digitalOut.digital to dataProcessor.digitalIn.digital;
		connection processorOut
			from dataProcessor.processedOut.digitalStream to digitalOutput.digitalStream;

		// ---------- State Machine: Operation Lifecycle ----------
		state def OperationLifecycle {
			entry action { send PowerOnEvent(); }
			then off;

			state off {
				entry action { /* Unit unpowered */ }
			}
			state warmup {
				entry action { /* Stabilize components */ }
				do action { sensor.powerSupply.regulate(); }
			}
			state selfCalibration {
				entry action { /* Correct inherent biases */ }
				do action { sensor.gyroscopicElement.detect(); }
				exit action { send CalibrationCompleteEvent(); }
			}
			state measuring {
				entry action { /* Begin continuous measurement */ }
				do action { sensor.signalProcessor.amplify(); }
			}
			state fault {
				entry action { /* Enter safe state */ }
				do action { /* Await reset */ }
			}

			transition off_to_warmup
				from off to warmup
				when trigger : PowerOnEvent;
			transition warmup_to_calibration
				from warmup to selfCalibration
				after 5 [s];
			transition calibration_to_measuring
				from selfCalibration to measuring
				when trigger : CalibrationCompleteEvent;
			transition measuring_to_fault
				from measuring to fault
				when trigger : FaultEvent;
			transition fault_to_off
				from fault to off
				when trigger : ResetEvent;

			// Measuring composite state with cyclic behavior
			state measuring {
				state acquiring {
					do action { sensor.gyroscopicElement.detect(); }
				}
				state processing {
					do action { sensor.signalProcessor.amplify(); sensor.signalProcessor.filter(); }
				}
				state outputting {
					do action { sensor.adc.convert(); dataProcessor.process(); }
				}

				transition acquire_to_process
					from acquiring to processing;
				transition process_to_output
					from processing to outputting;
				transition output_to_acquire
					from outputting to acquiring
					when trigger : MeasurementCycleCompleteEvent;
			}
		}

		state operation : OperationLifecycle;

		// ---------- Fault Detection Action ----------
		action def DetectFault {
			in measurement : DigitalMeasurement;
			out fault : FaultEvent;
			condition : measurement.magnitude > 500 [AngularRate] or measurement.valid == false;
		}

		action faultMonitor : DetectFault {
			in measurement : DigitalMeasurement;
			out fault : FaultEvent;
		}
	}

	// ---------- Requirements ----------
	requirement def PerformanceRequirements {
		attribute maxRate : AngularRate = 500 [AngularRate];
		attribute minAccuracy : AccuracyPercent = 1.0 [AccuracyPercent];

		requirement
			"The unit shall measure angular rates up to 500 rad/s." {
				subject : AngularRateSensingUnit.maxMeasurableRate;
				assert : maxMeasurableRate >= maxRate;
		}

		requirement
			"The unit shall achieve accuracy of at least ±1% of full scale." {
				subject : AngularRateSensingUnit.accuracy;
				assert : accuracy <= minAccuracy;
		}
	}

	requirement def OperationalRequirements {
		attribute warmupDuration : TimeStamp = 5 [s];

		requirement
			"The unit shall enter a warmup state upon power application." {
				subject : AngularRateSensingUnit.operation;
				assert : OperationLifecycle::off_to_warmup.exists;
		}

		requirement
			"The unit shall perform self-calibration before continuous measuring." {
				subject : AngularRateSensingUnit.operation;
				assert : OperationLifecycle::warmup_to_calibration.exists
					and OperationLifecycle::calibration_to_measuring.exists;
		}

		requirement
			"The unit shall enter a fault state upon error detection and remain until reset." {
				subject : AngularRateSensingUnit.operation;
				assert : OperationLifecycle::measuring_to_fault.exists
					and OperationLifecycle::fault_to_off.exists;
		}
	}

	requirement def InterfaceRequirements {
		requirement
			"The unit shall provide a continuous analog output of the processed measurement." {
				subject : AngularRateSensingUnit.analogOutput;
				assert : analogOutput.analogSignal.exists;
		}

		requirement
			"The unit shall provide a timestamped digital data stream." {
				subject : AngularRateSensingUnit.digitalOutput;
				assert : digitalOutput.digitalStream.exists;
		}
	}

	requirement performanceSpec : PerformanceRequirements;
	requirement operationalSpec : OperationalRequirements;
	requirement interfaceSpec : InterfaceRequirements;

	satisfy performanceSpec by AngularRateSensingUnit;
	satisfy operationalSpec by AngularRateSensingUnit;
	satisfy interfaceSpec by AngularRateSensingUnit;
}
