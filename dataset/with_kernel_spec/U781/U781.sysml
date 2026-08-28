package 'Nano-Tetherball Sensing Unit' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SI::*;

	package Definitions {
		attribute def StartMeasurement;
		attribute def StopMeasurement;
		attribute def ErrorDetected;
		attribute def ResetSignal;

		part def Nanoparticle {
			out displacement : LengthValue;
		}

		part def Tether {
			in displacement : LengthValue;
		}

		part def PiezoelectricTransducer {
			in displacement : LengthValue;
			out rawVoltage : ElectricPotentialValue;
		}

		part def SignalConditioner {
			in rawVoltage : ElectricPotentialValue;
			out conditionedVoltage : ElectricPotentialValue;
		}

		part def AnalogToDigitalConverter {
			in conditionedVoltage : ElectricPotentialValue;
			out digitalSignal : Integer;
		}

		part def Controller {
			in digitalSignal : Integer;
			perform action calibrate : Calibrate;
			perform action verifyAccuracy : VerifyAccuracy;
			exhibit state operationalStates : OperationalStates;
		}

		part def NanoTetherballSensingUnit {
			part nanoparticle : Nanoparticle;
			part tether : Tether;
			part transducer : PiezoelectricTransducer;
			part conditioner : SignalConditioner;
			part adc : AnalogToDigitalConverter;
			part controller : Controller;

			flow nanoparticle.displacement to transducer.displacement;
			flow transducer.rawVoltage to conditioner.rawVoltage;
			flow conditioner.conditionedVoltage to adc.conditionedVoltage;
			flow adc.digitalSignal to controller.digitalSignal;
		}

		action def DetectDisplacement {
			in displacement : LengthValue;
			out rawVoltage : ElectricPotentialValue;
		}

		action def ConditionSignal {
			in rawVoltage : ElectricPotentialValue;
			out conditionedVoltage : ElectricPotentialValue;
		}

		action def ConvertToDigital {
			in conditionedVoltage : ElectricPotentialValue;
			out digitalSignal : Integer;
		}

		action def MeasureForce {
			in displacement : LengthValue;
			out digitalSignal : Integer;
			action detectDisplacement : DetectDisplacement {
				in displacement = MeasureForce::displacement;
			}
			action conditionSignal : ConditionSignal;
			action convertToDigital : ConvertToDigital {
				out digitalSignal = MeasureForce::digitalSignal;
			}
			flow detectDisplacement.rawVoltage to conditionSignal.rawVoltage;
			flow conditionSignal.conditionedVoltage to convertToDigital.conditionedVoltage;
		}

		action def Calibrate {
			in referenceForce : ForceValue;
		}

		action def VerifyAccuracy {
			in measuredForce : ForceValue;
			in referenceForce : ForceValue;
		}

		state def OperationalStates {
			entry; then idle;
			state idle;
			transition idle_to_active
				first idle
				accept StartMeasurement
				then active;
			state active {
				do action measureForce : MeasureForce;
			}
			transition active_to_idle
				first active
				accept StopMeasurement
				then idle;
			transition active_to_fault
				first active
				accept ErrorDetected
				then fault;
			state fault;
			transition fault_to_idle
				first fault
				accept ResetSignal
				then idle;
		}

		requirement def HighAccuracyReq {
			doc /* The sensor must measure forces with high accuracy. */
			attribute accuracy : ForceValue = 0.001 [N];
		}

		requirement def FastSamplingRateReq {
			doc /* The sensor must have a fast sampling rate. */
			attribute samplingRate : Integer = 1000;
		}

		requirement def TemperatureRangeReq {
			doc /* The sensor must operate within a specific temperature range. */
			attribute minTemp : TemperatureValue = 233.15 [K];
			attribute maxTemp : TemperatureValue = 358.15 [K];
		}

		requirement def CalibrationReq {
			doc /* The sensor must include a process for calibration against a known reference force. */
		}

		requirement def VerificationReq {
			doc /* The sensor must include a process for verifying its measurement accuracy. */
		}
	}

	public import Definitions::*;

	package Usages {
		private import Definitions::*;

		part sensingUnit : NanoTetherballSensingUnit;

		satisfy HighAccuracyReq by sensingUnit;
		satisfy FastSamplingRateReq by sensingUnit;
		satisfy TemperatureRangeReq by sensingUnit;
		satisfy CalibrationReq by sensingUnit.controller.calibrate;
		satisfy VerificationReq by sensingUnit.controller.verifyAccuracy;
	}
}
