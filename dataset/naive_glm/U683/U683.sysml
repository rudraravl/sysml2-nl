package FluxgateCompassSystem {
	import ScalarValues::*;
	import ISQ::*;
	import ISQ::ElectricCurrent;
	import ISQ::ElectricPotential;
	import ISQ::MagneticFluxDensity;
	import ISQ::ThermodynamicTemperature;
	import ISQ::Frequency;
	import ISQ::Angle;

	// ---- Value Types ----
	value type DriveVoltage :> ElectricPotential { unit 'V'; }
	value type PickupVoltage :> ElectricPotential { unit 'uV'; }
	value type AxisFieldStrength :> MagneticFluxDensity { unit 'uT'; }
	value type HeadingAngle :> Angle { unit 'deg'; }
	value type ExcitationFrequency :> Frequency { unit 'kHz'; }
	value type DriveCurrent :> ElectricCurrent { unit 'mA'; }
	value type CoreTemp :> ThermodynamicTemperature { unit 'degC'; }
	value type DigitalFieldCode :> Integer;
	value type CalibrationCoefficient :> Real;

	item def MagneticFieldVector {
		attribute bx : AxisFieldStrength;
		attribute by : AxisFieldStrength;
		attribute bz : AxisFieldStrength;
	}

	item def RawPickupSignals {
		attribute vx : PickupVoltage;
		attribute vy : PickupVoltage;
		attribute vz : PickupVoltage;
	}

	item def ProcessedFieldData {
		attribute bx : AxisFieldStrength;
		attribute by : AxisFieldStrength;
		attribute bz : AxisFieldStrength;
		attribute valid : Boolean;
	}

	item def CorrectedFieldData {
		attribute bx : AxisFieldStrength;
		attribute by : AxisFieldStrength;
		attribute bz : AxisFieldStrength;
	}

	item def HeadingSolution {
		attribute heading : HeadingAngle;
		attribute confidence : Real;
		attribute timestamp : Integer;
	}

	item def CalibrationDataSet {
		attribute hardIronX : AxisFieldStrength;
		attribute hardIronY : AxisFieldStrength;
		attribute hardIronZ : AxisFieldStrength;
		attribute softIronXX : CalibrationCoefficient;
		attribute softIronYY : CalibrationCoefficient;
		attribute softIronZZ : CalibrationCoefficient;
		attribute tempCoeffX : CalibrationCoefficient;
		attribute tempCoeffY : CalibrationCoefficient;
		attribute tempCoeffZ : CalibrationCoefficient;
		attribute referenceTemp : CoreTemp;
	}

	item def ExcitationCommand {
		attribute enable : Boolean;
		attribute frequency : ExcitationFrequency;
		attribute amplitude : DriveVoltage;
	}

	// ---- Port Definitions ----
	port def DrivePort {
		out driveSignal : DriveVoltage;
		in driveCurrent : DriveCurrent;
	}

	port def PickupPort {
		in pickupSignals : RawPickupSignals;
	}

	port def AnalogSignalPort {
		out rawSignals : RawPickupSignals;
	}

	port def DigitalFieldPort {
		out fieldData : ProcessedFieldData;
	}

	port def CorrectedFieldPort {
		out correctedData : CorrectedFieldData;
	}

	port def HeadingOutputPort {
		out headingSolution : HeadingSolution;
	}

	port def CalibrationPort {
		out calibrationData : CalibrationDataSet;
	}

	port def TemperaturePort {
		out temperature : CoreTemp;
	}

	port def CommandPort {
		in command : ExcitationCommand;
	}

	// ---- Parts ----
	part def FluxgateCore {
		attribute saturated : Boolean;
		attribute axisLabel : String;
	}

	part def DriveCoil {
		attribute inductance : Real;
		attribute turns : Integer;
	}

	part def PickupCoil {
		attribute turns : Integer;
		attribute sensitivity : Real;
	}

	part def FluxgateSensor {
		part xCore : FluxgateCore { :>> axisLabel = "X"; }
		part yCore : FluxgateCore { :>> axisLabel = "Y"; }
		part zCore : FluxgateCore { :>> axisLabel = "Z"; }

		part xDriveCoil : DriveCoil { :>> turns = 200; :>> inductance = 0.5e-3; }
		part yDriveCoil : DriveCoil { :>> turns = 200; :>> inductance = 0.5e-3; }
		part zDriveCoil : DriveCoil { :>> turns = 200; :>> inductance = 0.5e-3; }

		part xPickupCoil : PickupCoil { :>> turns = 1000; :>> sensitivity = 1.0; }
		part yPickupCoil : PickupCoil { :>> turns = 1000; :>> sensitivity = 1.0; }
		part zPickupCoil : PickupCoil { :>> turns = 1000; :>> sensitivity = 1.0; }

		port driveInput : DrivePort;
		port pickupOutput : AnalogSignalPort;

		attribute ambientField : MagneticFieldVector;

		action measureField {
			in drive : DriveVoltage;
			out signals : RawPickupSignals;
		}

		state sensorBehavior {
			entry;
			do measureField;
			exit;
		}
	}

	part def ExcitationCircuit {
		port commandInput : CommandPort;
		port driveOutput : DrivePort;

		attribute nominalFrequency : ExcitationFrequency = 10.0 [kHz];
		attribute nominalAmplitude : DriveVoltage = 5.0 [V];
		attribute enabled : Boolean;

		action generateExcitation {
			out driveSignal : DriveVoltage;
		}

		state excitationControl {
			state Off;
			state Running {
				do generateExcitation;
			}
			transition Off -> Running when commandInput.command.enable;
			transition Running -> Off when not commandInput.command.enable;
		}
	}

	part def SignalProcessor {
		port analogInput : AnalogSignalPort;
		port digitalOutput : DigitalFieldPort;

		attribute gain : Real = 1000.0;
		attribute filterCutoff : Frequency = 50.0 [Hz];
		attribute adcResolution : Integer = 16;

		action amplify {
			in raw : RawPickupSignals;
			out amplified : RawPickupSignals;
		}

		action filterNoise {
			in amplified : RawPickupSignals;
			out filtered : RawPickupSignals;
		}

		action convertToDigital {
			in filtered : RawPickupSignals;
			out digital : ProcessedFieldData;
		}

		action processSignals {
			in raw : RawPickupSignals;
			out data : ProcessedFieldData;
			then amplify;
			then filterNoise;
			then convertToDigital;
		}

		state processingLoop {
			do processSignals;
		}
	}

	part def TemperatureSensor {
		port tempOutput : TemperaturePort;
		attribute measuredTemp : CoreTemp = 25.0 [degC];

		action senseTemperature {
			out temp : CoreTemp;
		}

		state sensing {
			do senseTemperature;
		}
	}

	part def CalibrationModule {
		port tempInput : TemperaturePort;
		port calibOutput : CalibrationPort;

		attribute storedCalibration : CalibrationDataSet;
		attribute calibrated : Boolean = false;

		action loadCalibration {
			out data : CalibrationDataSet;
		}

		action applyTemperatureCompensation {
			in base : CalibrationDataSet;
			in temp : CoreTemp;
			out adjusted : CalibrationDataSet;
		}

		state calibrationReady {
			do loadCalibration;
		}
	}

	part def HeadingCalculator {
		port fieldInput : DigitalFieldPort;
		port calibInput : CalibrationPort;
		port headingOutput : HeadingOutputPort;

		attribute updateRate : Frequency = 10.0 [Hz];
		attribute lastHeading : HeadingAngle;

		action applyHardIronCorrection {
			in raw : ProcessedFieldData;
			in calib : CalibrationDataSet;
			out partiallyCorrected : CorrectedFieldData;
		}

		action applySoftIronCorrection {
			in partiallyCorrected : CorrectedFieldData;
			in calib : CalibrationDataSet;
			out fullyCorrected : CorrectedFieldData;
		}

		action computeHeading {
			in corrected : CorrectedFieldData;
			out solution : HeadingSolution;
		}

		action calculateHeading {
			in field : ProcessedFieldData;
			in calib : CalibrationDataSet;
			out solution : HeadingSolution;
			then applyHardIronCorrection;
			then applySoftIronCorrection;
			then computeHeading;
		}

		state computing {
			do calculateHeading;
		}
	}

	part def FluxgateCompass {
		part sensor : FluxgateSensor;
		part excitation : ExcitationCircuit;
		part processor : SignalProcessor;
		part tempSensor : TemperatureSensor;
		part calibration : CalibrationModule;
		part calculator : HeadingCalculator;

		port externalHeading : HeadingOutputPort;
		port systemCommand : CommandPort;

		connection driveLink connect excitation.driveOutput to sensor.driveInput;
		connection pickupLink connect sensor.pickupOutput to processor.analogInput;
		connection digitalLink connect processor.digitalOutput to calculator.fieldInput;
		connection tempLink connect tempSensor.tempOutput to calibration.tempInput;
		connection calibLink connect calibration.calibOutput to calculator.calibInput;
		connection headingLink connect calculator.headingOutput to externalHeading;
		connection commandLink connect systemCommand to excitation.commandInput;

		state lifecycle {
			state Off;
			state Initializing;
			state SelfTest;
			state LoadingCalibration;
			state Measuring;
			state Standby;

			transition Off -> Initializing when systemCommand.command.enable;
			transition Initializing -> SelfTest when true;
			transition SelfTest -> LoadingCalibration when true;
			transition LoadingCalibration -> Measuring when calibration.calibrated;
			transition Measuring -> Standby when not systemCommand.command.enable;
			transition Standby -> Measuring when systemCommand.command.enable;
			transition any -> Off when false;

			state Measuring {
				do {
					sensor.measureField;
					processor.processSignals;
					calibration.applyTemperatureCompensation;
					calculator.calculateHeading;
				}
			}
		}
	}

	// ---- Requirements ----
	requirement def ProvideHeadingInformation {
		doc /* The system shall provide continuous heading information for navigation. */
		subject compass : FluxgateCompass;
		requirement headingRange :> HeadingAngle {
			doc /* Heading shall be reported in the range 0 to 360 degrees. */
			attribute minHeading : HeadingAngle = 0.0 [deg];
			attribute maxHeading : HeadingAngle = 360.0 [deg];
		}
	}

	requirement def MeasureThreeAxisField {
		doc /* The fluxgate sensor shall measure the magnetic field along three perpendicular axes. */
		subject sensor : FluxgateSensor;
		requirement axisCount {
			attribute count : Integer = 3;
		}
	}

	requirement def DriveCoreSaturation {
		doc /* The excitation circuit shall drive the sensor cores into saturation at high frequency. */
		subject excitation : ExcitationCircuit;
		requirement minFrequency :> ExcitationFrequency {
			attribute value : ExcitationFrequency = 5.0 [kHz];
		}
	}

	requirement def ProcessRawSignals {
		doc /* The signal processor shall amplify, filter, and digitize pickup coil voltages. */
		subject processor : SignalProcessor;
		requirement minResolution {
			attribute bits : Integer = 12;
		}
	}

	requirement def CorrectDistortions {
		doc /* The system shall correct hard iron, soft iron, and temperature-induced distortions. */
		subject calib : CalibrationModule;
	}

	requirement def ComputeHeadingFromXY {
		doc /* The heading calculator shall compute heading from corrected X and Y field components. */
		subject calc : HeadingCalculator;
	}

	requirement def LifecycleCompliance {
		doc /* The system shall follow the defined lifecycle: power-on, initialize, self-test, load calibration, measure, with standby capability. */
		subject compass : FluxgateCompass;
	}

	requirement headingRequirement : ProvideHeadingInformation {
		subject :>> compass = FluxgateCompass;
	}
	requirement sensorRequirement : MeasureThreeAxisField {
		subject :>> sensor = FluxgateSensor;
	}
	requirement excitationRequirement : DriveCoreSaturation {
		subject :>> excitation = ExcitationCircuit;
	}
	requirement processorRequirement : ProcessRawSignals {
		subject :>> processor = SignalProcessor;
	}
	requirement correctionRequirement : CorrectDistortions {
		subject :>> calib = CalibrationModule;
	}
	requirement calcRequirement : ComputeHeadingFromXY {
		subject :>> calc = HeadingCalculator;
	}
	requirement lifecycleRequirement : LifecycleCompliance {
		subject :>> compass = FluxgateCompass;
	}
}
