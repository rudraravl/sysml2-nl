package LevelSensingUnitModel {
	import ScalarValues::*;
	import ISQ::*;
	import ISQSpace::*;
	import ISQTime::*;

	// ---------- Value Types ----------
	value def VoltageValue :> Real { unit 'V'; }
	value def CurrentValue :> Real { unit 'A'; }
	value def DistanceValue :> Real { unit 'm'; }
	value def TimeValue :> Real {> Duration, unit 's'; }
	value def TemperatureValue :> Real { unit 'degC'; }
	value def FrequencyValue :> Real { unit 'Hz'; }
	value def GainValue :> Real { unit '1'; }
	value def OffsetValue :> Real { unit 'm'; }
	value def AccuracyValue :> Real { unit 'm'; }
	value def ResponseTimeValue :> Real {> Duration, unit 's'; }

	// ---------- Item Types ----------
	item def RawDistanceMeasurement {
		attribute rawDistance : DistanceValue;
		attribute timestamp : DateTime;
	}
	item def ConditionedDistanceMeasurement {
		attribute filteredDistance : DistanceValue;
		attribute timestamp : DateTime;
		attribute qualityFlag : Boolean;
	}
	item def ProcessedLevelReading {
		attribute level : DistanceValue;
		attribute temperature : TemperatureValue;
		attribute timestamp : DateTime;
		attribute valid : Boolean;
		attribute confidence : Real;
	}
	item def TriggerSignal;
	item def ResetCommand;
	item def CalibrationRequest;
	item def PowerOn;
	item def PowerOff;
	item def ErrorNotification {
		attribute errorCode : String;
		attribute description : String;
		attribute timestamp : DateTime;
	}
	item def SelfTestResult {
		attribute passed : Boolean;
		attribute details : String;
	}

	// ---------- Port Definitions ----------
	port def RawDistanceOut { out rawDistance : RawDistanceMeasurement; }
	port def RawDistanceIn { in rawDistance : RawDistanceMeasurement; }
	port def ConditionedDistanceOut { out conditionedDistance : ConditionedDistanceMeasurement; }
	port def ConditionedDistanceIn { in conditionedDistance : ConditionedDistanceMeasurement; }
	port def LevelReadingOut { out levelReading : ProcessedLevelReading; }
	port def LevelReadingIn { in levelReading : ProcessedLevelReading; }
	port def TriggerPort { in trigger : TriggerSignal; }
	port def ResetPort { in resetCmd : ResetCommand; }
	port def CalibrationPort { in calibReq : CalibrationRequest; }
	port def ErrorPort { out errorNotif : ErrorNotification; }
	port def PowerInputPort { in powerIn : PowerOn; }
	port def PowerOutputPort { out powerOut : PowerOn; }
	port def RegulatedPowerPort { out regulatedPower : PowerOn; }
	port def RegulatedPowerInPort { in regulatedPowerIn : PowerOn; }

	// ---------- Requirements ----------
	requirement def MeasurementAccuracyRequirement {
		attribute id = "REQ-001";
		attribute text = "The system shall measure liquid level with an accuracy of +/- 2 mm over the full range.";
		attribute maxError : AccuracyValue = 0.002 [m];
	}
	requirement def MeasurementRangeRequirement {
		attribute id = "REQ-002";
		attribute text = "The system shall measure liquid levels from 0 to 10 meters.";
		attribute minRange : DistanceValue = 0 [m];
		attribute maxRange : DistanceValue = 10 [m];
	}
	requirement def ResponseTimeRequirement {
		attribute id = "REQ-003";
		attribute text = "The system shall provide a validated level reading within 500 ms of receiving a trigger.";
		attribute maxResponseTime : ResponseTimeValue = 0.5 [s];
	}
	requirement def SelfTestRequirement {
		attribute id = "REQ-004";
		attribute text = "The system shall perform a self-test upon startup and report any detected faults.";
	}
	requirement def ErrorDetectionRequirement {
		attribute id = "REQ-005";
		attribute text = "The system shall detect measurement errors including out-of-range conditions and emit an error notification.";
	}
	requirement def PowerSupplyRequirement {
		attribute id = "REQ-006";
		attribute text = "The power supply shall accept a standard input voltage of 24 VDC and provide regulated power to all internal components.";
		attribute inputVoltage : VoltageValue = 24 [V];
		attribute outputVoltage : VoltageValue = 5 [V];
	}
	requirement def CalibrationRequirement {
		attribute id = "REQ-007";
		attribute text = "The system shall support a calibration mode when not yet calibrated, using a calibration matrix for high accuracy.";
	}
	requirement def TemperatureCompensationRequirement {
		attribute id = "REQ-008";
		attribute text = "The data processor shall perform temperature compensation to correct for environmental variations.";
	}
	requirement def AveragingRequirement {
		attribute id = "REQ-009";
		attribute text = "The data processor shall average multiple readings over a time window to provide a stable output.";
		attribute windowSize : Integer = 10;
	}
	requirement def OutputRequirement {
		attribute id = "REQ-010";
		attribute text = "The system shall provide a timestamped, validated, and highly accurate level reading to an external system.";
	}

	requirement group def LevelSensingUnitRequirements {
		satisfy MeasurementAccuracyRequirement;
		satisfy MeasurementRangeRequirement;
		satisfy ResponseTimeRequirement;
		satisfy SelfTestRequirement;
		satisfy ErrorDetectionRequirement;
		satisfy PowerSupplyRequirement;
		satisfy CalibrationRequirement;
		satisfy TemperatureCompensationRequirement;
		satisfy AveragingRequirement;
		satisfy OutputRequirement;
	}

	// ---------- Ultrasonic Sensor ----------
	part def UltrasonicSensor {
		attribute maxRange : DistanceValue = 10 [m];
		attribute minRange : DistanceValue = 0.05 [m];
		attribute pulseFrequency : FrequencyValue = 40000 [Hz];
		attribute beamAngle : Real = 12;
		attribute isCalibrated : Boolean = false;

		port distanceOut : RawDistanceOut;
		port powerIn : RegulatedPowerInPort;

		attribute currentDistance : DistanceValue;
		attribute timeOfFlight : TimeValue;
		attribute lastTimestamp : DateTime;

		action def EmitPulse {
			out pulseSent : Boolean;
		}
		action def ReceiveEcho {
			in pulseSent : Boolean;
			out tof : TimeValue;
		}
		action def CalculateDistance {
			in tof : TimeValue;
			out distance : DistanceValue;
		}
		action def PerformMeasurement :> Action {
			perform emit : EmitPulse;
			then perform receive : ReceiveEcho {
				in pulseSent = emit.pulseSent;
				out tof;
			}
			then perform calc : CalculateDistance {
				in tof = receive.tof;
				out distance;
			}
			then assign currentDistance := calc.distance;
			then assign lastTimestamp := now;
			then send RawDistanceMeasurement{rawDistance = currentDistance, timestamp = lastTimestamp} via distanceOut.rawDistance;
		}

		assert constraint { currentDistance >= minRange and currentDistance <= maxRange }
	}

	// ---------- Signal Conditioner ----------
	part def SignalConditioner {
		attribute filterCutoff : FrequencyValue = 1000 [Hz];
		attribute gain : GainValue = 2.0;
		attribute offsetCorrection : OffsetValue = 0.0 [m];
		attribute noiseThreshold : DistanceValue = 0.001 [m];

		port rawIn : RawDistanceIn;
		port conditionedOut : ConditionedDistanceOut;
		port powerIn : RegulatedPowerInPort;

		attribute lastRaw : DistanceValue;
		attribute lastFiltered : DistanceValue;
		attribute qualityFlag : Boolean;

		action def FilterNoise {
			in rawDist : DistanceValue;
			out filtered : DistanceValue;
		}
		action def AmplifySignal {
			in filtered : DistanceValue;
			out amplified : DistanceValue;
		}
		action def CorrectOffset {
			in amplified : DistanceValue;
			out corrected : DistanceValue;
		}
		action def EvaluateQuality {
			in corrected : DistanceValue;
			out quality : Boolean;
		}
		action def ConditionSignal :> Action {
			accept rawDistance : RawDistanceMeasurement via rawIn.rawDistance;
			then perform filter : FilterNoise {
				in rawDist = rawDistance.rawDistance;
				out filtered;
			}
			then perform amplify : AmplifySignal {
				in filtered = filter.filtered;
				out amplified;
			}
			then perform correct : CorrectOffset {
				in amplified = amplify.amplified;
				out corrected;
			}
			then perform eval : EvaluateQuality {
				in corrected = correct.corrected;
				out quality;
			}
			then assign lastFiltered := correct.corrected;
			then assign qualityFlag := eval.quality;
			then send ConditionedDistanceMeasurement{filteredDistance = lastFiltered, timestamp = rawDistance.timestamp, qualityFlag = qualityFlag} via conditionedOut.conditionedDistance;
		}
	}

	// ---------- Data Processor ----------
	part def DataProcessor {
		attribute calibrationMatrix : Real[3,3] = [1.0, 0.0, 0.0; 0.0, 1.0, 0.0; 0.0, 0.0, 1.0];
		attribute isCalibrated : Boolean = false;
		attribute averagingWindow : Integer = 10;
		attribute readingBuffer : DistanceValue[0..*];
		attribute currentTemperature : TemperatureValue = 20 [degC];
		attribute temperatureCoefficient : Real = 0.0009;
		attribute maxResponseTime : ResponseTimeValue = 0.5 [s];
		attribute lastLevel : DistanceValue;
		attribute lastConfidence : Real;
		attribute lastValid : Boolean;

		port conditionedIn : ConditionedDistanceIn;
		port levelOut : LevelReadingOut;
		port triggerIn : TriggerPort;
		port resetIn : ResetPort;
		port calibrationIn : CalibrationPort;
		port errorOut : ErrorPort;
		port powerIn : RegulatedPowerInPort;

		action def ApplyCalibrationMatrix {
			in distance : DistanceValue;
			in matrix : Real[3,3];
			out calibrated : DistanceValue;
		}
		action def ApplyTemperatureCompensation {
			in calibrated : DistanceValue;
			in temperature : TemperatureValue;
			in coefficient : Real;
			out compensated : DistanceValue;
		}
		action def AverageReadings {
			in buffer : DistanceValue[0..*];
			in windowSize : Integer;
			out averaged : DistanceValue;
		}
		action def ValidateReading {
			in averaged : DistanceValue;
			in maxRange : DistanceValue;
			out valid : Boolean;
			out confidence : Real;
		}
		action def ProcessReading :> Action {
			accept conditioned : ConditionedDistanceMeasurement via conditionedIn.conditionedDistance;
			then perform calib : ApplyCalibrationMatrix {
				in distance = conditioned.filteredDistance;
				in matrix = calibrationMatrix;
				out calibrated;
			}
			then perform tempComp : ApplyTemperatureCompensation {
				in calibrated = calib.calibrated;
				in temperature = currentTemperature;
				in coefficient = temperatureCoefficient;
				out compensated;
			}
			then assign readingBuffer := readingBuffer.append(tempComp.compensated);
			then perform avg : AverageReadings {
				in buffer = readingBuffer;
				in windowSize = averagingWindow;
				out averaged;
			}
			then perform validate : ValidateReading {
				in averaged = avg.averaged;
				in maxRange = 10 [m];
				out valid;
				out confidence;
			}
			then assign lastLevel := avg.averaged;
			then assign lastValid := validate.valid;
			then assign lastConfidence := validate.confidence;
			then if validate.valid {
				send ProcessedLevelReading{level = lastLevel, temperature = currentTemperature, timestamp = conditioned.timestamp, valid = lastValid, confidence = lastConfidence} via levelOut.levelReading;
			} else {
				send ErrorNotification{errorCode = "ERR_RANGE", description = "Measurement exceeds maximum range", timestamp = conditioned.timestamp} via errorOut.errorNotif;
			}
		}
		action def RunCalibration :> Action {
			accept calibReq : CalibrationRequest via calibrationIn.calibReq;
			then assign isCalibrated := true;
		}
	}

	// ---------- Power Supply ----------
	part def PowerSupply {
		attribute inputVoltage : VoltageValue = 24 [V];
		attribute outputVoltage : VoltageValue = 5 [V];
		attribute outputCurrent : CurrentValue = 2 [A];
		attribute isPowered : Boolean = false;

		port powerInput : PowerInputPort;
		port sensorPower : RegulatedPowerPort;
		port conditionerPower : RegulatedPowerPort;
		port processorPower : RegulatedPowerPort;

		action def RegulatePower {
			in input : PowerOn;
			out regulated : PowerOn;
		}
		action def PowerUp :> Action {
			accept powerOn : PowerOn via powerInput.powerIn;
			then assign isPowered := true;
			then perform reg1 : RegulatePower {
				in input = powerOn;
				out regulated;
			}
			then send PowerOn{} via sensorPower.regulatedPower;
			then send PowerOn{} via conditionerPower.regulatedPower;
			then send PowerOn{} via processorPower.regulatedPower;
		}
	}

	// ---------- Level Sensing Unit ----------
	part def LevelSensingUnit {
		satisfy LevelSensingUnitRequirements;

		attribute systemId : String = "LSU-001";
		attribute firmwareVersion : String = "2.1.0";
		attribute isCalibrated : Boolean = false;
		attribute maxRange : DistanceValue = 10 [m];
		attribute maxResponseTime : ResponseTimeValue = 0.5 [s];

		port externalPower : PowerInputPort;
		port externalTrigger : TriggerPort;
		port externalReset : ResetPort;
		port externalCalibration : CalibrationPort;
		port externalLevelOut : LevelReadingOut;
		port externalErrorOut : ErrorPort;

		part sensor : UltrasonicSensor {
			port distanceOut : RawDistanceOut;
			port powerIn : RegulatedPowerInPort;
		}
		part conditioner : SignalConditioner {
			port rawIn : RawDistanceIn;
			port conditionedOut : ConditionedDistanceOut;
			port powerIn : RegulatedPowerInPort;
		}
		part processor : DataProcessor {
			port conditionedIn : ConditionedDistanceIn;
			port levelOut : LevelReadingOut;
			port triggerIn : TriggerPort;
			port resetIn : ResetPort;
			port calibrationIn : CalibrationPort;
			port errorOut : ErrorPort;
			port powerIn : RegulatedPowerInPort;
		}
		part powerSupply : PowerSupply {
			port powerInput : PowerInputPort;
			port sensorPower : RegulatedPowerPort;
			port conditionerPower : RegulatedPowerPort;
			port processorPower : RegulatedPowerPort;
		}

		connection powerInputConn connect externalPower to powerSupply.powerInput;
		connection triggerConn connect externalTrigger to processor.triggerIn;
		connection resetConn connect externalReset to processor.resetIn;
		connection calibrationConn connect externalCalibration to processor.calibrationIn;
		connection levelOutConn connect processor.levelOut to externalLevelOut;
		connection errorOutConn connect processor.errorOut to externalErrorOut;

		connection rawDistanceConn connect sensor.distanceOut to conditioner.rawIn;
		connection conditionedDistanceConn connect conditioner.conditionedOut to processor.conditionedIn;

		connection sensorPowerConn connect powerSupply.sensorPower to sensor.powerIn;
		connection conditionerPowerConn connect powerSupply.conditionerPower to conditioner.powerIn;
		connection processorPowerConn connect powerSupply.processorPower to processor.powerIn;

		// ---------- State Machine ----------
		state def LevelSensingUnitStateMachine {
			entry; then Off;

			state Off;
			transition onPowerOn first Off then PoweringUp {
				accept powerOn : PowerOn via externalPower.powerIn;
			}

			state PoweringUp {
				entry perform powerSupply.PowerUp;
				then SelfTest;
			}

			state SelfTest {
				entry {
					perform sensor.PerformMeasurement;
				}
				attribute selfTestResult : SelfTestResult;
				do assign selfTestResult := SelfTestResult{passed = true, details = "All components OK"};
			}
			transition selfTestPass first SelfTest then Initializing {
				when selfTestResult.passed == true
			}
			transition selfTestFail first SelfTest then Fault {
				when selfTestResult.passed == false
			}

			state Initializing {
				entry {
					assign isCalibrated := processor.isCalibrated;
				}
			}
			transition notCalibrated first Initializing then CalibrationMode {
				when isCalibrated == false
			}
			transition alreadyCalibrated first Initializing then Ready {
				when isCalibrated == true
			}

			state CalibrationMode {
				entry perform processor.RunCalibration;
				do {
					accept calibReq : CalibrationRequest via externalCalibration.calibReq;
				}
			}
			transition calibrationDone first CalibrationMode then Ready {
				when processor.isCalibrated == true
			}

			state Ready {
				attribute waitingForTrigger : Boolean = true;
			}
			transition triggerReceived first Ready then Measuring {
				accept trigger : TriggerSignal via externalTrigger.trigger;
			}

			state Measuring {
				entry perform sensor.PerformMeasurement;
				do perform processor.ProcessReading;
			}
			transition measurementComplete first Measuring then Ready {
				when processor.lastValid == true
			}
			transition measurementError first Measuring then ErrorState {
				when processor.lastValid == false
			}

			state ErrorState {
				entry {
					send ErrorNotification{errorCode = "ERR_MEASUREMENT", description = "Measurement error detected", timestamp = now} via externalErrorOut.errorNotif;
				}
			}
			transition resetFromError first ErrorState then Initializing {
				accept resetCmd : ResetCommand via externalReset.resetCmd;
			}

			state Fault {
				entry {
					send ErrorNotification{errorCode = "ERR_FAULT", description = "Self-test failure", timestamp = now} via externalErrorOut.errorNotif;
				}
			}
			transition resetFromFault first Fault then PoweringUp {
				accept resetCmd : ResetCommand via externalReset.resetCmd;
			}

			transition resetFromReady first Ready then Initializing {
				accept resetCmd : ResetCommand via externalReset.resetCmd;
			}
			transition resetFromMeasuring first Measuring then Initializing {
				accept resetCmd : ResetCommand via externalReset.resetCmd;
			}
		}

		exhibit state LevelSensingUnitStateMachine;

		assert constraint { maxRange == 10 [m] }
		assert constraint { maxResponseTime <= 0.5 [s] }
	}
}
