package SinglePhotonCountingSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def WavelengthValue :> Real;
	attribute def TemperatureValue :> Real;
	attribute def CountValue :> Integer;
	attribute def RateValue :> Real;
	attribute def VoltageValue :> Real;
	attribute def TimeValue :> Real;

	attribute def ElectricalPulse {
		attribute amplitude : VoltageValue;
	}
	attribute def DigitalPulse;
	attribute def ValidPhotonPulse;
	attribute def DataPackage {
		attribute photonCount : CountValue;
		attribute detectionRate : RateValue;
	}

	attribute def StartMeasurementCmd;
	attribute def StopMeasurementCmd;
	attribute def CalibrateCmd;
	attribute def PowerOnCmd;
	attribute def CooldownComplete;
	attribute def DarkCountAlert;
	attribute def ResetCmd;
	attribute def CalibrationComplete;
	attribute def PhotonStrike;

	requirement def PhotonDetectionRequirement {
		doc /* The system shall detect individual photons in the visible spectrum (380-750 nm). */
	}
	requirement def ThermalStabilityRequirement {
		doc /* The detector shall be cooled to -20C (253.15 K) to minimize dark counts. */
	}
	requirement def CountingRateRequirement {
		doc /* The counting logic shall count up to 10 million photons per second. */
	}
	requirement def SignalConditioningRequirement {
		doc /* The signal conditioner shall amplify and shape detector pulses into clean digital signals. */
	}
	requirement def NoiseRejectionRequirement {
		doc /* The pulse discriminator shall reject low-amplitude noise and count only legitimate photon pulses. */
	}
	requirement def CalibrationRequirement {
		doc /* The system shall periodically calibrate and correct for background dark count rate. */
	}
	requirement def OperationalStatesRequirement {
		doc /* The system shall transition through initializing, cooldown, standby, calibrating, measuring, and error states. */
	}

	port def DetectorOutPort {
		out pulse : ElectricalPulse;
	}
	port def SignalInPort {
		in pulse : ElectricalPulse;
	}
	port def SignalOutPort {
		out pulse : DigitalPulse;
	}
	port def DiscInPort {
		in pulse : DigitalPulse;
	}
	port def DiscOutPort {
		out pulse : ValidPhotonPulse;
	}
	port def CountInPort {
		in pulse : ValidPhotonPulse;
	}
	port def DataOutPort {
		out data : DataPackage;
	}
	port def DataInPort {
		in data : DataPackage;
	}
	port def CoolingOutPort {
		out signal : VoltageValue;
	}
	port def CoolingInPort {
		in signal : VoltageValue;
	}
	port def TempFeedbackOutPort {
		out temp : TemperatureValue;
	}
	port def TempFeedbackInPort {
		in temp : TemperatureValue;
	}

	part def PhotonDetectorModule {
		doc /* Silicon avalanche photodiode operating in Geiger mode for single photon detection. */
		attribute targetTemp : TemperatureValue := 253.15;
		attribute currentTemp : TemperatureValue;
		attribute darkCountRate : RateValue;
		attribute wavelengthMin : WavelengthValue := 380.0;
		attribute wavelengthMax : WavelengthValue := 750.0;

		port detectorOut : DetectorOutPort;
		port coolingIn : CoolingInPort;
		port tempFeedbackOut : TempFeedbackOutPort;

		action detectPhoton;

		exhibit state DetectorStates {
			entry; then idle;
			state idle;
			accept PowerOnCmd then cooling;
			state cooling;
			accept CooldownComplete then ready;
			state ready;
		}
	}

	part def ThermalController {
		port coolingOut : CoolingOutPort;
		port tempFeedbackIn : TempFeedbackInPort;
		attribute setPoint : TemperatureValue := 253.15;

		action controlTemperature;
	}

	part def SignalConditioner {
		port signalIn : SignalInPort;
		port signalOut : SignalOutPort;
		attribute gain : Real := 1000.0;

		action amplifyAndShape;
	}

	part def PulseDiscriminator {
		port discIn : DiscInPort;
		port discOut : DiscOutPort;
		attribute threshold : VoltageValue := 0.5;

		action validatePulse;
	}

	part def CountingLogic {
		attribute maxRate : RateValue := 10000000.0;
		attribute count : CountValue := 0;
		attribute measurementTime : TimeValue := 1.0;

		port countIn : CountInPort;
		port dataOut : DataOutPort;

		action accumulate;
		action computeRate;
		action generateData;

		exhibit state CountingStates {
			entry; then standby;
			state standby;
			accept StartMeasurementCmd
				do assign count := 0
				then counting;
			state counting;
			accept pulse : ValidPhotonPulse
				do assign count := count + 1
				then counting;
			accept StopMeasurementCmd
				then dataGen;
			state dataGen {
				do generateData;
			}
			then standby;
		}
	}

	part def DataInterface {
		port dataIn : DataInPort;
		port externalOut : DataOutPort;

		action transmitData;
	}

	part def CalibrationModule {
		attribute darkCountRate : RateValue := 0.0;
		attribute baselineCount : CountValue := 0;

		action calibrate;
		action measureDarkCount;
	}

	part def SinglePhotonCounter {
		part detector : PhotonDetectorModule;
		part thermalController : ThermalController;
		part signalConditioner : SignalConditioner;
		part discriminator : PulseDiscriminator;
		part countingLogic : CountingLogic;
		part dataInterface : DataInterface;
		part calibrationModule : CalibrationModule;

		port systemDataOut : DataOutPort;

		connect detector.detectorOut to signalConditioner.signalIn;
		connect signalConditioner.signalOut to discriminator.discIn;
		connect discriminator.discOut to countingLogic.countIn;
		connect countingLogic.dataOut to dataInterface.dataIn;
		connect dataInterface.externalOut to systemDataOut;
		connect thermalController.coolingOut to detector.coolingIn;
		connect detector.tempFeedbackOut to thermalController.tempFeedbackIn;

		exhibit state SystemStates {
			entry; then off;
			state off;
			accept PowerOnCmd then initializing;
			state initializing;
			accept CooldownComplete then standby;
			state standby;
			accept StartMeasurementCmd then measuring;
			accept CalibrateCmd then calibrating;
			accept DarkCountAlert then error;
			state measuring;
			accept StopMeasurementCmd then standby;
			accept DarkCountAlert then error;
			state calibrating;
			accept CalibrationComplete then standby;
			accept DarkCountAlert then error;
			state error;
			accept ResetCmd then standby;
		}
	}
}
