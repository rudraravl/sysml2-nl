package 'Proportional Counter Detector System' {
	private import ScalarValues::*;
	private import SI::*;

	attribute def PressureValue :> Real;
	attribute def VoltageValue :> Real;
	attribute def CurrentValue :> Real;
	attribute def PulseHeightValue :> Real;
	attribute def FrequencyValue :> Real;

	item def PowerOn;
	item def SystemReady;
	item def FaultDetected;
	item def ResetSignal;
	item def RadiationEvent;

	item def GasMixture {
		attribute argonFraction : Real = 0.90;
		attribute methaneFraction : Real = 0.10;
		attribute designation : String = "P10";
	}
	item def ElectronIonPair;
	item def AvalancheCharge;
	item def CurrentPulse {
		attribute amplitude : CurrentValue;
	}
	item def VoltagePulseItem {
		attribute height : PulseHeightValue;
	}
	item def AcceptedPulse;
	item def CountData {
		attribute totalCount : Integer;
		attribute countRate : FrequencyValue;
	}

	port def GasFlowPort;
	port def HVPort;
	port def CurrentSignalPort;
	port def VoltageSignalPort;
	port def AcceptedSignalPort;
	port def DataPort;

	part def ElectrodeAssembly {
		part anodeWire;
		part cathodeShell;
		port hvConnection : HVPort;
		port chargeOutput : CurrentSignalPort;
	}

	part def GasFlowController {
		attribute targetPressure : PressureValue;
		port gasOutput : GasFlowPort;
		port statusOutput : DataPort;
	}

	part def HighVoltageSupply {
		attribute outputVoltage : VoltageValue;
		port hvOutput : HVPort;
		port statusOutput : DataPort;
	}

	part def DetectionChamber {
		part electrodeAssembly : ElectrodeAssembly;
		attribute gasMixture : GasMixture;
		attribute pressure : PressureValue;
		port gasInlet : GasFlowPort;
		port gasOutlet : GasFlowPort;
		port hvInput : HVPort;
		port currentOutput : CurrentSignalPort;
	}

	part def PreamplifierCircuit {
		attribute gain : Real;
		port currentInput : CurrentSignalPort;
		port voltageOutput : VoltageSignalPort;
	}

	part def PulseDiscriminator {
		attribute lowerThreshold : PulseHeightValue;
		attribute upperThreshold : PulseHeightValue;
		port voltageInput : VoltageSignalPort;
		port acceptedOutput : AcceptedSignalPort;
	}

	part def CounterModule {
		attribute totalCount : Integer;
		attribute countRate : FrequencyValue;
		port pulseInput : AcceptedSignalPort;
		port dataOutput : DataPort;
	}

	action def GenerateIonPairs {
		in radiation : RadiationEvent;
		in gas : GasMixture;
		out pairs : ElectronIonPair[0..*];
	}
	action def GasAmplificationAction {
		in pairs : ElectronIonPair[0..*];
		in voltage : VoltageValue;
		out charge : AvalancheCharge;
	}
	action def CollectCharge {
		in charge : AvalancheCharge;
		out currentPulse : CurrentPulse;
	}
	action def PreamplifyAction {
		in currentPulse : CurrentPulse;
		out voltagePulse : VoltagePulseItem;
	}
	action def DiscriminatePulseAction {
		in voltagePulse : VoltagePulseItem;
		in lowerThreshold : PulseHeightValue;
		in upperThreshold : PulseHeightValue;
		out acceptedPulse : AcceptedPulse[0..1];
	}
	action def CountAcceptedPulse {
		in acceptedPulse : AcceptedPulse;
		out data : CountData;
	}

	action def DetectRadiation {
		in radiation : RadiationEvent;
		in gas : GasMixture;
		in voltage : VoltageValue;
		in lowerThreshold : PulseHeightValue;
		in upperThreshold : PulseHeightValue;
		out data : CountData;

		action generateIonPairs : GenerateIonPairs {
			in radiation = DetectRadiation::radiation;
			in gas = DetectRadiation::gas;
		}
		flow generateIonPairs.pairs to gasAmplification.pairs;

		action gasAmplification : GasAmplificationAction {
			in voltage = DetectRadiation::voltage;
		}
		flow gasAmplification.charge to collectCharge.charge;

		action collectCharge : CollectCharge;
		flow collectCharge.currentPulse to preamplify.currentPulse;

		action preamplify : PreamplifyAction;
		flow preamplify.voltagePulse to discriminatePulse.voltagePulse;

		action discriminatePulse : DiscriminatePulseAction {
			in lowerThreshold = DetectRadiation::lowerThreshold;
			in upperThreshold = DetectRadiation::upperThreshold;
		}
		flow discriminatePulse.acceptedPulse to countAcceptedPulse.acceptedPulse;

		action countAcceptedPulse : CountAcceptedPulse;
		flow countAcceptedPulse.data to DetectRadiation::data;

		first start;
		then generateIonPairs;
		then gasAmplification;
		then collectCharge;
		then preamplify;
		then discriminatePulse;
		then countAcceptedPulse;
		then done;
	}

	requirement def GasCompositionRequirement {
		doc /* The detection chamber shall be filled with P10 gas mixture (90% Argon, 10% Methane). */
	}
	requirement def GasPressureStabilityRequirement {
		doc /* The gas flow controller shall maintain stable gas pressure during operation. */
	}
	requirement def HVStabilityRequirement {
		doc /* The high voltage supply shall provide stable voltage for consistent gas amplification. */
	}
	requirement def GasAmplificationRequirement {
		doc /* The system shall amplify initial ionization charge via Townsend avalanche by at least 10^3. */
	}
	requirement def EnergyDiscriminationRequirement {
		doc /* The pulse discriminator shall only accept pulses within a predefined energy window. */
	}

	requirement gasCompReq : GasCompositionRequirement;
	requirement gasPressReq : GasPressureStabilityRequirement;
	requirement hvStabReq : HVStabilityRequirement;
	requirement gasAmpReq : GasAmplificationRequirement;
	requirement energyDiscReq : EnergyDiscriminationRequirement;

	part def ProportionalCounterSystem {
		part detectionChamber : DetectionChamber;
		part gasFlowController : GasFlowController;
		part hvSupply : HighVoltageSupply;
		part preamplifier : PreamplifierCircuit;
		part discriminator : PulseDiscriminator;
		part counter : CounterModule;

		satisfy gasCompReq by detectionChamber;
		satisfy gasPressReq by gasFlowController;
		satisfy hvStabReq by hvSupply;
		satisfy gasAmpReq by hvSupply;
		satisfy energyDiscReq by discriminator;

		connect gasFlowController.gasOutput to detectionChamber.gasInlet;
		connect hvSupply.hvOutput to detectionChamber.hvInput;
		connect detectionChamber.electrodeAssembly.chargeOutput to preamplifier.currentInput;
		connect preamplifier.voltageOutput to discriminator.voltageInput;
		connect discriminator.acceptedOutput to counter.pulseInput;

		state systemBehavior {
			entry; then Standby;

			state Standby;
			accept PowerOn
				then Initialization;

			state Initialization;
			accept SystemReady
				then Detecting;
			accept FaultDetected
				then Fault;

			state Detecting;
			accept event : RadiationEvent
				do action processEvent { /* Process radiation event through signal chain */ }
				then Detecting;
			accept FaultDetected
				then Fault;

			state Fault;
			accept ResetSignal
				then Standby;
		}
	}
}
