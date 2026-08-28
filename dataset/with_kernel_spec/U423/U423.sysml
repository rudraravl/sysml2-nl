package 'Trimprob Diagnostic System' {
	private import ScalarValues::*;
	private import SequenceFunctions::*;

	attribute def FrequencyValue :> Real;
	attribute def PowerValue :> Real;
	attribute def TimeValue :> Real;
	attribute def MassValue :> Real;
	attribute def AnomalyScoreValue :> Real;
	attribute def ConfidenceLevelValue :> Real;

	unit Hz;
	unit W;
	unit s;
	unit kg;
	unit h;

	attribute def PowerOnSignal;
	attribute def StartScanSignal;
	attribute def ScanCompleteSignal;
	attribute def AnalysisCompleteSignal;
	attribute def DisplayCompleteSignal;
	attribute def PowerOffSignal;

	item def EMSignal {
		attribute frequency : FrequencyValue;
		attribute power : PowerValue;
	}

	item def TissueResponse {
		attribute frequency : FrequencyValue;
		attribute amplitude : Real;
		attribute phase : Real;
	}

	item def ScanCommand {
		attribute startFrequency : FrequencyValue;
		attribute endFrequency : FrequencyValue;
		attribute stepSize : FrequencyValue;
		attribute emissionPower : PowerValue;
	}

	item def DiagnosticResult {
		attribute anomalyScore : AnomalyScoreValue;
		attribute confidence : ConfidenceLevelValue;
	}

	item def DisplayData {
		attribute anomalyScore : AnomalyScoreValue;
		attribute confidence : ConfidenceLevelValue;
		attribute timestamp : TimeValue;
	}

	port def SignalOutPort {
		out signal : EMSignal;
	}
	port def SignalInPort {
		in signal : EMSignal;
	}
	port def ResponseOutPort {
		out response : TissueResponse;
	}
	port def ResponseInPort {
		in response : TissueResponse;
	}
	port def CommandOutPort {
		out command : ScanCommand;
	}
	port def CommandInPort {
		in command : ScanCommand;
	}
	port def ResultOutPort {
		out result : DiagnosticResult;
	}
	port def ResultInPort {
		in result : DiagnosticResult;
	}
	port def DisplayOutPort {
		out data : DisplayData;
	}
	port def DisplayInPort {
		in data : DisplayData;
	}
	port def PowerOutPort {
		out supply : PowerValue;
	}
	port def PowerInPort {
		in supply : PowerValue;
	}

	calc def ResonancePatternRecognition {
		in responses : TissueResponse[*];
		return score : AnomalyScoreValue;
	}

	calc def ComputeConfidence {
		in anomalyScore : AnomalyScoreValue;
		return confidence : ConfidenceLevelValue;
	}

	part def SignalGenerator {
		port commandIn : CommandInPort;
		port signalOut : SignalOutPort;
		port powerIn : PowerInPort;
	}

	part def ProbeHead {
		port signalIn : SignalInPort;
		port responseOut : ResponseOutPort;
		port powerIn : PowerInPort;
	}

	part def ResponseAnalyzer {
		port responseIn : ResponseInPort;
		port resultOut : ResultOutPort;
		port powerIn : PowerInPort;
	}

	part def ControlProcessor {
		port scanCommandOut : CommandOutPort;
		port resultIn : ResultInPort;
		port displayOut : DisplayOutPort;
		port powerIn : PowerInPort;
		attribute scanResponses : TissueResponse[*] := ();
		attribute diagnosis : DiagnosticResult;
		attribute displayData : DisplayData;
	}

	part def BatteryPack {
		port powerOut : PowerOutPort;
		attribute capacity : TimeValue = 4 [h];
	}

	part def DisplayScreen {
		port displayIn : DisplayInPort;
		port powerIn : PowerInPort;
	}

	action def PerformFrequencySweep {
		in startFreq : FrequencyValue;
		in endFreq : FrequencyValue;
		in stepFreq : FrequencyValue;
		in emissionPower : PowerValue;
		out responses : TissueResponse[*];
	}

	action def AnalyzeData {
		in responses : TissueResponse[*];
		out result : DiagnosticResult;
	}

	action def DisplayDiagnosis {
		in result : DiagnosticResult;
		out data : DisplayData;
	}

	part def TrimprobDevice {
		attribute weight : MassValue = 1.5 [kg];
		attribute minFrequency : FrequencyValue = 10000 [Hz];
		attribute maxFrequency : FrequencyValue = 500000 [Hz];
		attribute sweepStep : FrequencyValue = 1000 [Hz];
		attribute emissionLimit : PowerValue = 0.001 [W];
		attribute scanDurationLimit : TimeValue = 120 [s];

		part controlProcessor : ControlProcessor;
		part signalGenerator : SignalGenerator;
		part probeHead : ProbeHead;
		part responseAnalyzer : ResponseAnalyzer;
		part batteryPack : BatteryPack;
		part displayScreen : DisplayScreen;

		connect controlProcessor.scanCommandOut to signalGenerator.commandIn;
		connect signalGenerator.signalOut to probeHead.signalIn;
		connect probeHead.responseOut to responseAnalyzer.responseIn;
		connect responseAnalyzer.resultOut to controlProcessor.resultIn;
		connect controlProcessor.displayOut to displayScreen.displayIn;
		connect batteryPack.powerOut to signalGenerator.powerIn;
		connect batteryPack.powerOut to probeHead.powerIn;
		connect batteryPack.powerOut to responseAnalyzer.powerIn;
		connect batteryPack.powerOut to controlProcessor.powerIn;
		connect batteryPack.powerOut to displayScreen.powerIn;

		state def OperationalStates;
		state operationalState : OperationalStates {
			entry; then off;
			state off;
			accept PowerOnSignal then ready;
			state ready;
			accept StartScanSignal then scanning;
			state scanning {
				entry action sweep : PerformFrequencySweep {
					in startFreq = minFrequency;
					in endFreq = maxFrequency;
					in stepFreq = sweepStep;
					in emissionPower = emissionLimit;
				}
			}
			accept ScanCompleteSignal then analyzing;
			state analyzing {
				entry action analyze : AnalyzeData {
					in responses = controlProcessor.scanResponses;
				}
			}
			accept AnalysisCompleteSignal then displaying;
			state displaying {
				entry action show : DisplayDiagnosis {
					in result = controlProcessor.diagnosis;
				}
			}
			accept DisplayCompleteSignal then ready;
			accept PowerOffSignal then off;
		}
	}

	part trimprob : TrimprobDevice;

	requirement def EmissionSafetyRequirement {
		subject device : TrimprobDevice;
		doc /* The device shall not emit electromagnetic power greater than 1 milliwatt during operation. */
		constraint { device.emissionLimit <= 0.001 [W] }
	}
	requirement emissionSafety : EmissionSafetyRequirement;

	requirement def BatteryLifeRequirement {
		subject battery : BatteryPack;
		doc /* The rechargeable battery pack shall provide at least four hours of continuous use. */
		constraint { battery.capacity >= 4 [h] }
	}
	requirement batteryLife : BatteryLifeRequirement;

	requirement def ScanDurationRequirement {
		subject device : TrimprobDevice;
		doc /* The complete scan, analysis, and display cycle shall complete within approximately two minutes. */
		constraint { device.scanDurationLimit <= 120 [s] }
	}
	requirement scanDuration : ScanDurationRequirement;

	requirement def PortabilityRequirement {
		subject device : TrimprobDevice;
		doc /* The device shall be lightweight and portable for handheld clinical use. */
		constraint { device.weight < 2.0 [kg] }
	}
	requirement portability : PortabilityRequirement;

	requirement def NonInvasiveRequirement {
		subject device : TrimprobDevice;
		doc /* The device shall detect pathological conditions without requiring surgery or biopsies. */
	}
	requirement nonInvasive : NonInvasiveRequirement;

	satisfy emissionSafety by trimprob;
	satisfy batteryLife by trimprob.batteryPack;
	satisfy scanDuration by trimprob;
	satisfy portability by trimprob;
	satisfy nonInvasive by trimprob;
}
