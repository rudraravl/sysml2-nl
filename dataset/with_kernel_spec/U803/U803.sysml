package PIR_Sensor_System {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ScalarValues::*;

		item def InfraredRadiation;
		attribute def VoltageSignal :> Real;
		attribute def DigitalOutput :> Boolean;
		attribute def PowerSignal :> Real;

		attribute def PowerApplied;
		attribute def WarmUpComplete;
		attribute def MotionDetectedSignal;
		attribute def ProcessingComplete;

		action def FocusIR {
			in ambientIR : InfraredRadiation;
			out focusedIR : InfraredRadiation;
		}

		action def ConvertIRToVoltage {
			in focusedIR : InfraredRadiation;
			out rawVoltage : VoltageSignal;
		}

		action def AmplifySignal {
			in rawVoltage : VoltageSignal;
			out amplifiedVoltage : VoltageSignal;
		}

		action def ProcessSignal {
			in amplifiedVoltage : VoltageSignal;
			out motionDetected : DigitalOutput;
		}

		action def RegulateVoltage {
			in inputPower : PowerSignal;
			out regulatedPower : PowerSignal;
		}

		action def DetectMotion {
			in ambientIR : InfraredRadiation;
			out motionDetected : DigitalOutput;
		}

		state def PIR_OperationalStates;

		part def PIR_Sensor_Unit {
			attribute warmUpTime : Real;
			attribute processingTime : Real;
			attribute detectionThreshold : VoltageSignal;

			port powerInput : PowerSignal;
			port irInput : InfraredRadiation;
			port digitalOutput : DigitalOutput;

			perform action detectMotion : DetectMotion;
			exhibit state operationalStates : PIR_OperationalStates;
		}

		part def Fresnel_Lens_Array {
			port ambientIRPort : InfraredRadiation;
			port focusedIRPort : InfraredRadiation;
			perform action focusIR : FocusIR;
		}

		part def Pyroelectric_Sensor_Element {
			port focusedIRPort : InfraredRadiation;
			port rawVoltagePort : VoltageSignal;
			port powerPort : PowerSignal;
			perform action convertIRToVoltage : ConvertIRToVoltage;
		}

		part def Signal_Amplifier {
			attribute gain : Real;
			port rawVoltagePort : VoltageSignal;
			port amplifiedVoltagePort : VoltageSignal;
			port powerPort : PowerSignal;
			perform action amplifySignal : AmplifySignal;
		}

		part def Signal_Processor {
			attribute threshold : VoltageSignal;
			port amplifiedVoltagePort : VoltageSignal;
			port motionDetectedPort : DigitalOutput;
			port powerPort : PowerSignal;
			perform action processSignal : ProcessSignal;
		}

		part def Voltage_Regulator {
			port inputPowerPort : PowerSignal;
			port regulatedPowerPort : PowerSignal;
			perform action regulateVoltage : RegulateVoltage;
		}

		requirement def WarmUpTimeRequirement {
			doc /* The unit shall complete warm-up within 30 seconds of power application. */
			attribute maxWarmUpTime : Real;
		}

		requirement def DetectionSensitivityRequirement {
			doc /* The unit shall detect motion when infrared irradiance change exceeds a minimum threshold. */
			attribute minIRChange : Real;
		}

		requirement def PowerStabilityRequirement {
			doc /* The regulated voltage shall remain stable within nominal tolerance for reliable operation. */
			attribute nominalVoltage : VoltageSignal;
			attribute tolerance : VoltageSignal;
		}

		requirement def PowerConsumptionRequirement {
			doc /* The unit shall consume less than a maximum power during monitoring. */
			attribute maxPower : PowerSignal;
		}

		requirement def DetectionRangeRequirement {
			doc /* The unit shall detect motion within a specified range. */
			attribute range : Real;
		}
	}

	package Usages {
		private import Definitions::*;

		requirement warmUpTimeReq : WarmUpTimeRequirement {
			maxWarmUpTime = 30.0;
		}

		requirement detectionSensitivityReq : DetectionSensitivityRequirement {
			minIRChange = 0.1;
		}

		requirement powerStabilityReq : PowerStabilityRequirement {
			nominalVoltage = 3.3;
			tolerance = 0.1;
		}

		requirement powerConsumptionReq : PowerConsumptionRequirement {
			maxPower = 0.5;
		}

		requirement detectionRangeReq : DetectionRangeRequirement {
			range = 10.0;
		}

		part pirSensor : PIR_Sensor_Unit {
			warmUpTime = 30.0;
			processingTime = 0.5;
			detectionThreshold = 0.5;

			part fresnelLens : Fresnel_Lens_Array;
			part pyroelectricSensor1 : Pyroelectric_Sensor_Element;
			part pyroelectricSensor2 : Pyroelectric_Sensor_Element;
			part signalAmplifier : Signal_Amplifier {
				gain = 100.0;
			}
			part signalProcessor : Signal_Processor {
				threshold = pirSensor.detectionThreshold;
			}
			part voltageRegulator : Voltage_Regulator;

			flow pirSensor::powerInput to voltageRegulator.inputPowerPort;
			flow voltageRegulator.regulatedPowerPort to pyroelectricSensor1.powerPort;
			flow voltageRegulator.regulatedPowerPort to pyroelectricSensor2.powerPort;
			flow voltageRegulator.regulatedPowerPort to signalAmplifier.powerPort;
			flow voltageRegulator.regulatedPowerPort to signalProcessor.powerPort;

			flow pirSensor::irInput to fresnelLens.ambientIRPort;
			flow fresnelLens.focusedIRPort to pyroelectricSensor1.focusedIRPort;
			flow fresnelLens.focusedIRPort to pyroelectricSensor2.focusedIRPort;
			flow pyroelectricSensor1.rawVoltagePort to signalAmplifier.rawVoltagePort;
			flow pyroelectricSensor2.rawVoltagePort to signalAmplifier.rawVoltagePort;
			flow signalAmplifier.amplifiedVoltagePort to signalProcessor.amplifiedVoltagePort;
			flow signalProcessor.motionDetectedPort to pirSensor::digitalOutput;

			action detectMotion : DetectMotion {
				in ambientIR = pirSensor::irInput;
				out motionDetected = pirSensor::digitalOutput;

				action focusIR : FocusIR {
					in ambientIR = detectMotion::ambientIR;
					out focusedIR;
				}
				flow focusIR.focusedIR to convertIRToVoltage.focusedIR;
				action convertIRToVoltage : ConvertIRToVoltage {
					in focusedIR;
					out rawVoltage;
				}
				flow convertIRToVoltage.rawVoltage to amplifySignal.rawVoltage;
				action amplifySignal : AmplifySignal {
					in rawVoltage;
					out amplifiedVoltage;
				}
				flow amplifySignal.amplifiedVoltage to processSignal.amplifiedVoltage;
				action processSignal : ProcessSignal {
					in amplifiedVoltage;
					out motionDetected;
				}
				bind processSignal.motionDetected = detectMotion::motionDetected;
			}

			exhibit state operationalStates : PIR_OperationalStates {
				entry; then warmUp;
				state warmUp;
				accept WarmUpComplete then monitoring;
				state monitoring;
				accept MotionDetectedSignal then detection;
				state detection;
				accept ProcessingComplete then monitoring;
			}

			satisfy warmUpTimeReq by pirSensor;
			satisfy detectionSensitivityReq by signalProcessor;
			satisfy powerStabilityReq by voltageRegulator;
			satisfy powerConsumptionReq by pirSensor;
			satisfy detectionRangeReq by pirSensor;
		}
	}
}
