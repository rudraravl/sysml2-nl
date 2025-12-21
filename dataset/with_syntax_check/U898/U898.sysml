package StudFinderSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;

	attribute def ScanPosition;
	attribute def DetectionConfidence;
	attribute def CalibrationData;

	item def CapacitanceReading {
		attribute value : Real;
		attribute timestamp : ISQ::TimeValue;
	}

	item def StudLocation {
		attribute position : ISQ::LengthValue;
		attribute confidence : DetectionConfidence;
		attribute edgeType : EdgeType;
	}

	enumeration EdgeType {
		leftEdge;
		rightEdge;
		center;
	}

	enumeration OperatingMode {
		off;
		calibrating;
		scanning;
		detected;
	}

	port def SensorDataPort {
		out reading : CapacitanceReading;
	}

	port def IndicatorPort {
		in signal : Boolean;
		in intensity : Real;
	}

	port def PowerPort {
		out voltage : ISQ::ElectricPotentialValue;
		out current : ISQ::ElectricCurrentValue;
	}

	part def CapacitiveSensor {
		attribute sensitivity : Real;
		attribute samplingRate : ISQ::FrequencyValue;
		port dataOut : SensorDataPort;
		port powerIn : PowerPort;

		action measureCapacitance {
			out reading : CapacitanceReading;
		}
	}

	part def SignalProcessor {
		attribute filterCoefficient : Real;
		attribute detectionThreshold : Real;

		action filterSignal {
			in rawReading : CapacitanceReading;
			out filteredReading : CapacitanceReading;
		}

		action detectStud {
			in reading : CapacitanceReading;
			in baseline : CalibrationData;
			out detected : Boolean;
			out location : StudLocation;
		}
	}

	part def VisualIndicator {
		attribute ledCount : Integer;
		port indicatorIn : IndicatorPort;

		action displayPattern {
			in intensity : Real;
		}
	}

	part def AudioIndicator {
		attribute frequency : ISQ::FrequencyValue;
		port indicatorIn : IndicatorPort;

		action emitTone {
			in active : Boolean;
			in pitch : ISQ::FrequencyValue;
		}
	}

	part def BatteryPack {
		attribute capacity : ISQ::ElectricChargeValue;
		attribute nominalVoltage : ISQ::ElectricPotentialValue;
		attribute chargeLevel : Real;
		port powerOut : PowerPort;

		state batteryState {
			entry; then charged;

			state charged;
			transition charged_to_normal
				first charged
				accept when chargeLevel < 0.9
				then normal;

			state normal;
			transition normal_to_low
				first normal
				accept when chargeLevel < 0.3
				then low;

			state low;
			transition low_to_depleted
				first low
				accept when chargeLevel < 0.1
				then depleted;

			state depleted;
		}
	}

	action def CalibrateBaseline {
		in sampleCount : Integer;
		out baseline : CalibrationData;
	}

	action def ScanForStud {
		in scanPosition : ISQ::LengthValue;
		in baseline : CalibrationData;
		out studDetected : Boolean;
		out studLocation : StudLocation;
	}

	action def IndicateDetection {
		in detected : Boolean;
		in location : StudLocation;
	}

	action def PerformStudDetection {
		in scanRange : ISQ::LengthValue;
		in scanResolution : ISQ::LengthValue;
		out detectedStuds : StudLocation[*];

		first start;
		then action calibrate : CalibrateBaseline {
			in sampleCount = 50;
			out baseline;
		}

		private attribute baselineData := calibrate.baseline;
		private attribute currentPosition : ISQ::LengthValue := 0.0[mm];
		private attribute foundStuds : StudLocation[*] := ();

		then merge continueScan;

		then action scan : ScanForStud {
			in scanPosition = currentPosition;
			in baseline = baselineData;
			out studDetected;
			out studLocation;
		}

		then decide;
			if scan.studDetected then recordStud;
			if !scan.studDetected then advancePosition;

		action recordStud {
			then action indicate : IndicateDetection {
				in detected = scan.studDetected;
				in location = scan.studLocation;
			}
			then assign foundStuds := foundStuds->including(scan.studLocation);
		}
		then advancePosition;

		action advancePosition {
			then assign currentPosition := currentPosition + scanResolution;
		}

		then decide;
			if currentPosition < scanRange then continueScan;
			if currentPosition >= scanRange then complete;

		action complete {
			then assign detectedStuds := foundStuds;
		}
		then done;
	}

	attribute def PowerOnSignal;
	attribute def PowerOffSignal;

	part def StudFinder {
		attribute operatingVoltage : ISQ::ElectricPotentialValue;
		attribute maxScanDepth : ISQ::LengthValue;
		attribute detectionAccuracy : ISQ::LengthValue;

		part sensor : CapacitiveSensor {
			attribute :>> sensitivity = 0.95;
			attribute :>> samplingRate = 1000.0[Hz];
		}

		part processor : SignalProcessor {
			attribute :>> filterCoefficient = 0.8;
			attribute :>> detectionThreshold = 0.15;
		}

		part visualDisplay : VisualIndicator {
			attribute :>> ledCount = 7;
		}

		part audioAlert : AudioIndicator {
			attribute :>> frequency = 2000.0[Hz];
		}

		part battery : BatteryPack {
			attribute :>> capacity = 500.0[SI::mA]*1.0[SI::h];
			attribute :>> nominalVoltage = 9.0[V];
			attribute :>> chargeLevel = 1.0;
		}

		connect battery.powerOut to sensor.powerIn;

		state operatingState {
			entry; then off;

			state off;
			transition off_to_calibrating
				first off
				accept powerOnCmd : PowerOnSignal
				then calibrating;

			state calibrating {
				entry action performCalibration : CalibrateBaseline {
					in sampleCount = 50;
					out baseline;
				}
			}
			transition calibrating_to_scanning
				first calibrating
				then scanning;

			state scanning {
				do action continuousDetection : PerformStudDetection {
					in scanRange = 400.0[mm];
					in scanResolution = 1.0[mm];
					out detectedStuds;
				}
			}
			transition scanning_to_off
				first scanning
				accept powerOffCmd : PowerOffSignal
				then off;
		}
	}

	part studFinderDevice : StudFinder {
		attribute :>> operatingVoltage = 9.0[V];
		attribute :>> maxScanDepth = 38.0[mm];
		attribute :>> detectionAccuracy = 13.0[mm];
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The stud finder shall detect and locate wooden or metal studs behind wall surfaces. */
		subject device : StudFinder;
	}

	requirement def ScanDepthRequirement {
		doc /* The stud finder shall detect studs through wall material up to 38mm depth. */
		subject device : StudFinder;
		require constraint {
			device.maxScanDepth >= 38.0[mm]
		}
	}

	requirement def AccuracyRequirement {
		doc /* The stud finder shall locate stud edges with accuracy within 13mm. */
		subject device : StudFinder;
		require constraint {
			device.detectionAccuracy <= 13.0[mm]
		}
	}

	requirement def PowerRequirement {
		doc /* The stud finder shall operate on 9V battery power. */
		subject device : StudFinder;
		require constraint {
			device.operatingVoltage == 9.0[V]
		}
	}

	requirement studFinderSystemRequirements {
		doc /* The stud finder system shall accurately detect and indicate the location of structural studs behind wall surfaces to assist in safe and precise mounting operations. */

		subject studFinderDevice;

		require primaryFunctionReq : PrimaryFunctionRequirement {
			redefines device = studFinderDevice;
		}

		require scanDepthReq : ScanDepthRequirement {
			redefines device = studFinderDevice;
		}

		require accuracyReq : AccuracyRequirement {
			redefines device = studFinderDevice;
		}

		require powerReq : PowerRequirement {
			redefines device = studFinderDevice;
		}

		assume constraint {
			studFinderDevice.battery.chargeLevel > 0.1
		}
	}
}
