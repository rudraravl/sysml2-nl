package 'Gyroscope Navigation System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package ValueTypes {
		private import ScalarValues::*;
		private import ISQ::*;

		attribute def AngularRateValue :> Real;
		attribute def AngleValue :> Real;
		attribute def VoltageValue :> Real;
		attribute def CorrectionValue :> Real;

		attribute def 'Raw Rotation Signal' {
			attribute rollVoltage : VoltageValue;
			attribute pitchVoltage : VoltageValue;
			attribute yawVoltage : VoltageValue;
		}
		attribute def 'Conditioned Signal' {
			attribute rollRate : AngularRateValue;
			attribute pitchRate : AngularRateValue;
			attribute yawRate : AngularRateValue;
		}
		attribute def 'Bias Correction Data' {
			attribute rollCorrection : CorrectionValue;
			attribute pitchCorrection : CorrectionValue;
			attribute yawCorrection : CorrectionValue;
		}
		attribute def 'Attitude Data' {
			attribute roll : AngleValue;
			attribute pitch : AngleValue;
			attribute yaw : AngleValue;
		}
		attribute def 'Gyro Output Data' {
			attribute rollRate : AngularRateValue;
			attribute pitchRate : AngularRateValue;
			attribute yawRate : AngularRateValue;
			attribute attitude : 'Attitude Data';
			attribute status : String;
		}
		attribute def 'Power Input' {
			attribute voltage : VoltageValue;
			attribute current : Real;
		}
	}

	package Definitions {
		private import ScalarValues::*;
		private import ISQ::*;
		private import ValueTypes::*;

		attribute def 'Init Command';
		attribute def 'Calibrate Command';
		attribute def 'Operate Command';
		attribute def 'Stop Command';

		action def 'Detect Rotation' {
			out rawSignal : 'Raw Rotation Signal';
		}
		action def 'Amplify and Filter' {
			in rawSignal : 'Raw Rotation Signal';
			out conditionedSignal : 'Conditioned Signal';
		}
		action def 'Apply Bias Corrections' {
			in conditionedSignal : 'Conditioned Signal';
			in correctionData : 'Bias Correction Data';
			out correctedRollRate : AngularRateValue;
			out correctedPitchRate : AngularRateValue;
			out correctedYawRate : AngularRateValue;
		}
		action def 'Compute Calibration' {
			out correctionData : 'Bias Correction Data';
		}
		action def 'Integrate Rates' {
			in rollRate : AngularRateValue;
			in pitchRate : AngularRateValue;
			in yawRate : AngularRateValue;
			in deltaT : TimeValue;
			in prevAttitude : 'Attitude Data';
			out attitude : 'Attitude Data';
		}
		action def 'Provide Output Data' {
			in rollRate : AngularRateValue;
			in pitchRate : AngularRateValue;
			in yawRate : AngularRateValue;
			in attitude : 'Attitude Data';
			in status : String;
			out data : 'Gyro Output Data';
		}
		action def 'Perform Self Test';
		action def 'Reset Registers';

		action def 'Initialization Sequence' {
			perform action 'self test' : 'Perform Self Test';
			then perform action 'reset registers' : 'Reset Registers';
		}
		action def 'Operational Sequence' {
			perform action 'detect rotation' : 'Detect Rotation';
			then perform action 'amplify and filter' : 'Amplify and Filter';
			then perform action 'apply bias corrections' : 'Apply Bias Corrections';
			then perform action 'integrate rates' : 'Integrate Rates';
			then perform action 'provide output data' : 'Provide Output Data';
		}

		port def 'Power Port';
		port def 'Command Port';
		port def 'Data Output Port';
		port def 'Raw Signal Port';
		port def 'Conditioned Signal Port';
		port def 'Correction Data Port';

		part def 'Sensing Element' {
			perform action 'detect rotation' : 'Detect Rotation';
			port rawOut : 'Raw Signal Port';
		}
		part def 'Signal Conditioner' {
			perform action 'amplify and filter' : 'Amplify and Filter';
			port rawIn : ~'Raw Signal Port';
			port conditionedOut : 'Conditioned Signal Port';
		}
		part def 'Calibration Module' {
			perform action 'compute calibration' : 'Compute Calibration';
			port correctionOut : 'Correction Data Port';
		}
		part def 'Digital Processor' {
			perform action 'apply bias corrections' : 'Apply Bias Corrections';
			perform action 'integrate rates' : 'Integrate Rates';
			perform action 'provide output data' : 'Provide Output Data';
			port conditionedIn : ~'Conditioned Signal Port';
			port correctionIn : ~'Correction Data Port';
			port dataOut : 'Data Output Port';
			attribute currentAttitude : 'Attitude Data';
			attribute status : String := "off";
			attribute deltaT : TimeValue;
		}

		state def 'Gyro Operational Modes' {
			action 'initialization sequence' : 'Initialization Sequence';
			action 'operational sequence' : 'Operational Sequence';
			action 'compute calibration' : 'Compute Calibration';

			entry;
			then 'initialization';

			state 'initialization' {
				do 'initialization sequence';
			}
			accept 'Calibrate Command'
				then 'calibration mode';
			accept 'Operate Command'
				then 'operational';

			state 'calibration mode' {
				do 'compute calibration';
			}
			accept 'Operate Command'
				then 'operational';

			state 'operational' {
				do 'operational sequence';
			}
			accept 'Calibrate Command'
				then 'calibration mode';
			accept 'Stop Command'
				then 'shutdown';

			state 'shutdown';
			accept 'Init Command'
				then 'initialization';
		}

		part def 'Gyroscope Unit' {
			part sensingElement : 'Sensing Element';
			part signalConditioner : 'Signal Conditioner';
			part calibrationModule : 'Calibration Module';
			part digitalProcessor : 'Digital Processor';
			exhibit state 'operational modes' : 'Gyro Operational Modes';
			port powerPort : 'Power Port';
			port commandPort : 'Command Port';
			port dataPort : 'Data Output Port';
			connect sensingElement.rawOut to signalConditioner.rawIn;
			connect signalConditioner.conditionedOut to digitalProcessor.conditionedIn;
			connect calibrationModule.correctionOut to digitalProcessor.correctionIn;
			connect digitalProcessor.dataOut to dataPort;
		}

		part def 'Navigation Computer' {
			port dataIn : ~'Data Output Port';
		}
		part def 'Power Source' {
			port powerOut : ~'Power Port';
		}

		part def 'Gyroscope Navigation System' {
			part gyroscope : 'Gyroscope Unit';
			part navigationComputer : 'Navigation Computer';
			part powerSource : 'Power Source';
			connect powerSource.powerOut to gyroscope.powerPort;
			connect gyroscope.dataPort to navigationComputer.dataIn;
		}
	}

	import Definitions::*;

	package Usages {
		private import Definitions::*;

		part 'gyro system 1' : 'Gyroscope Navigation System';

		action 'initialization sequence' : 'Initialization Sequence';
		action 'operational sequence' : 'Operational Sequence';
		action 'compute calibration' : 'Compute Calibration';

		state 'gyro states' : 'Gyro Operational Modes' {
			entry;
			then 'initialization';
			state 'initialization' {
				do 'initialization sequence';
			}
			accept 'Calibrate Command'
				then 'calibration mode';
			accept 'Operate Command'
				then 'operational';
			state 'calibration mode' {
				do 'compute calibration';
			}
			accept 'Operate Command'
				then 'operational';
			state 'operational' {
				do 'operational sequence';
			}
			accept 'Calibrate Command'
				then 'calibration mode';
			accept 'Stop Command'
				then 'shutdown';
			state 'shutdown';
			accept 'Init Command'
				then 'initialization';
		}
	}

	package Requirements {
		private import Definitions::*;

		requirement def 'Gyroscope System Requirements' {
			doc
			/* The gyroscope navigation system shall measure rotation and track orientation in 3D space. */
			requirement 'Measure3DRotation' {
				doc
				/* The system shall detect rotation in three-dimensional space using a sensing element. */
			}
			requirement 'SignalConditioning' {
				doc
				/* The system shall amplify and filter the raw rotation signal to produce a clean conditioned signal. */
			}
			requirement 'BiasCorrection' {
				doc
				/* The system shall apply bias corrections to compensate for inherent sensor drift ensuring long-term accuracy. */
			}
			requirement 'CalibrationMode' {
				doc
				/* The system shall provide a calibration module that can be run on command to determine correction data. */
			}
			requirement 'IntegrateRates' {
				doc
				/* The system shall integrate corrected rates of rotation over time to calculate roll pitch and yaw angles. */
			}
			requirement 'OperationalModes' {
				doc
				/* The system shall support initialization calibration and operational modes controlled by external commands. */
			}
			requirement 'ContinuousOutput' {
				doc
				/* The system shall provide a constant stream of data including angular rotation rates attitude and operational status. */
			}
			requirement 'ExternalPower' {
				doc
				/* The system shall receive power from an external source. */
			}
			requirement 'NavigationInterface' {
				doc
				/* The system shall provide output data to a main navigation computer for stabilization and guidance. */
			}
		}

		requirement gyroReq : 'Gyroscope System Requirements';
	}
}
