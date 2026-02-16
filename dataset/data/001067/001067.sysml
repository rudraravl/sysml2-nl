package 'Gaseous Ionization Detector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def IonizationDensity :> Real;
	attribute def DetectionEfficiency :> Real;
	attribute def GainFactor :> Real;
	
	item def IonizingParticle {
		attribute particleType : String;
		attribute energy : ISQ::EnergyValue;
		attribute trajectory : String;
	}
	
	item def IonPair {
		attribute electronCharge : ISQ::ElectricChargeValue;
		attribute ionCharge : ISQ::ElectricChargeValue;
		attribute driftVelocity : ISQ::SpeedValue;
	}
	
	item def ElectricalPulse {
		attribute amplitude : ISQ::ElectricPotentialValue;
		attribute risetime : ISQ::TimeValue;
		attribute width : ISQ::TimeValue;
	}
	
	item def CountData {
		attribute eventCount : Integer;
		attribute countRate : ISQ::FrequencyValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	port def RadiationInputPort {
		in item particle : IonizingParticle;
	}
	
	port def HighVoltageInputPort {
		in attribute voltage : ISQ::ElectricPotentialValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def SignalOutputPort {
		out item pulse : ElectricalPulse;
	}
	
	port def DataOutputPort {
		out item data : CountData;
	}
	
	port def GasInputPort {
		in attribute pressure : ISQ::PressureValue;
		in attribute flowRate : ISQ::VolumeFlowRateValue;
	}
	
	part def DetectionChamber {
		attribute volume : ISQ::VolumeValue;
		attribute gasType : String;
		attribute operatingPressure : ISQ::PressureValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		
		port radiationEntry : RadiationInputPort;
		port gasSupply : GasInputPort;
		
		action ionizeGas {
			in particle : IonizingParticle;
			in gasVolume : ISQ::VolumeValue;
			in gasPressure : ISQ::PressureValue;
			out ionPairs : IonPair[*];
		}
	}
	
	part def ElectrodeAssembly {
		attribute anodeMaterial : String;
		attribute cathodeMaterial : String;
		attribute electrodeSpacing : ISQ::LengthValue;
		attribute appliedVoltage : ISQ::ElectricPotentialValue;
		attribute electricFieldStrength : ISQ::ElectricFieldStrengthValue;
		
		port hvConnection : HighVoltageInputPort;
		
		action collectCharge {
			in ionPairs : IonPair[*];
			in fieldStrength : ISQ::ElectricFieldStrengthValue;
			out collectedCurrent : ISQ::ElectricCurrentValue;
		}
		
		action amplifyCharge {
			in primaryCurrent : ISQ::ElectricCurrentValue;
			in gasPressure : ISQ::PressureValue;
			in voltage : ISQ::ElectricPotentialValue;
			out amplifiedCurrent : ISQ::ElectricCurrentValue;
			out gasFactor : GainFactor;
		}
	}
	
	part def HighVoltageSupply {
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		attribute stability : Real;
		attribute ripple : ISQ::ElectricPotentialValue;
		
		port hvOutput : HighVoltageInputPort;
		
		action regulateVoltage {
			in setpoint : ISQ::ElectricPotentialValue;
			out deliveredVoltage : ISQ::ElectricPotentialValue;
		}
	}
	
	part def PreamplifierCircuit {
		attribute inputImpedance : Real;
		attribute voltageGain : GainFactor;
		attribute bandwidth : ISQ::FrequencyValue;
		attribute noiseLevel : ISQ::ElectricPotentialValue;
		
		action amplifySignal {
			in inputCurrent : ISQ::ElectricCurrentValue;
			in gain : GainFactor;
			out outputVoltage : ISQ::ElectricPotentialValue;
		}
		
		action shapeSignal {
			in rawVoltage : ISQ::ElectricPotentialValue;
			in shapingTime : ISQ::TimeValue;
			out shapedPulse : ElectricalPulse;
		}
	}
	
	part def PulseDiscriminator {
		attribute lowerThreshold : ISQ::ElectricPotentialValue;
		attribute upperThreshold : ISQ::ElectricPotentialValue;
		attribute deadTime : ISQ::TimeValue;
		
		action discriminatePulse {
			in pulse : ElectricalPulse;
			in threshold : ISQ::ElectricPotentialValue;
			out accepted : Boolean;
		}
	}
	
	part def CounterModule {
		attribute totalCounts : Integer;
		attribute liveTime : ISQ::TimeValue;
		attribute realTime : ISQ::TimeValue;
		
		action countEvent {
			in accepted : Boolean;
			out eventRegistered : Boolean;
		}
		
		action calculateRate {
			in counts : Integer;
			in timeInterval : ISQ::TimeValue;
			out rate : ISQ::FrequencyValue;
		}
	}
	
	part def GasFlowController {
		attribute gasComposition : String;
		attribute flowSetpoint : ISQ::VolumeFlowRateValue;
		attribute pressureSetpoint : ISQ::PressureValue;
		
		port gasOutput : GasInputPort;
		
		action regulateFlow {
			in setpoint : ISQ::VolumeFlowRateValue;
			out deliveredFlow : ISQ::VolumeFlowRateValue;
		}
	}
	
	action def IonizationProcess {
		in incomingParticle : IonizingParticle;
		in chamberVolume : ISQ::VolumeValue;
		in chamberPressure : ISQ::PressureValue;
		out primaryIonPairs : IonPair[*];
	}
	
	action def ChargeCollectionProcess {
		in ionPairs : IonPair[*];
		in electricField : ISQ::ElectricFieldStrengthValue;
		in driftDistance : ISQ::LengthValue;
		out inducedCurrent : ISQ::ElectricCurrentValue;
	}
	
	action def GasAmplificationProcess {
		in primaryCurrent : ISQ::ElectricCurrentValue;
		in appliedVoltage : ISQ::ElectricPotentialValue;
		in gasPressure : ISQ::PressureValue;
		out amplifiedCurrent : ISQ::ElectricCurrentValue;
		out avalancheGain : GainFactor;
	}
	
	action def SignalProcessingChain {
		in detectedCurrent : ISQ::ElectricCurrentValue;
		in amplifierGain : GainFactor;
		in shapingTime : ISQ::TimeValue;
		out processedPulse : ElectricalPulse;
	}
	
	action def EventDiscriminationAndCounting {
		in pulse : ElectricalPulse;
		in threshold : ISQ::ElectricPotentialValue;
		out countIncrement : Boolean;
		out countData : CountData;
	}
	
	action def DetectRadiationEvent {
		in radiationParticle : IonizingParticle;
		in biasVoltage : ISQ::ElectricPotentialValue;
		in gasPressure : ISQ::PressureValue;
		in discriminatorThreshold : ISQ::ElectricPotentialValue;
		out detectionData : CountData;
		
		first start;
		then action ionization : IonizationProcess {
			in incomingParticle = radiationParticle;
			in chamberVolume;
			in chamberPressure = gasPressure;
			out primaryIonPairs;
		}
		then action collection : ChargeCollectionProcess {
			in ionPairs = ionization.primaryIonPairs;
			in electricField;
			in driftDistance;
			out inducedCurrent;
		}
		then action amplification : GasAmplificationProcess {
			in primaryCurrent = collection.inducedCurrent;
			in appliedVoltage = biasVoltage;
			in gasPressure = gasPressure;
			out amplifiedCurrent;
			out avalancheGain;
		}
		then action signalProcessing : SignalProcessingChain {
			in detectedCurrent = amplification.amplifiedCurrent;
			in amplifierGain;
			in shapingTime;
			out processedPulse;
		}
		then action discrimination : EventDiscriminationAndCounting {
			in pulse = signalProcessing.processedPulse;
			in threshold = discriminatorThreshold;
			out countIncrement;
			out countData;
		}
		then assign detectionData := discrimination.countData;
		then done;
	}
	
	attribute def SystemStatusType :> String;
	attribute def PowerOnSignal;
	attribute def PowerOffSignal;
	attribute def SystemFaultSignal;
	attribute def FaultClearedSignal;
	
	state def DetectorOperationalStates {
		in attribute systemStatus : SystemStatusType;
		in attribute voltageStable : Boolean;
		in attribute gasFlowStable : Boolean;
		in attribute detectionEventCount : Integer;
		
		entry; then standby;
		
		state standby {
			entry assign systemStatus := "Standby";
		}
		
		transition standby_to_initialization
			first standby
			accept powerOnEvent : PowerOnSignal
			then initialization;
		
		state initialization {
			entry assign systemStatus := "Initializing";
		}
		
		transition initialization_to_ready
			first initialization
			if voltageStable and gasFlowStable
			then ready;
		
		state ready {
			entry assign systemStatus := "Ready";
		}
		
		transition ready_to_detecting
			first ready
			then detecting;
		
		state detecting {
			entry assign systemStatus := "Detecting";
		}
		
		transition detecting_to_processing
			first detecting
			if detectionEventCount > 0
			then processing;
		
		state processing {
			entry assign systemStatus := "Processing";
		}
		
		transition processing_to_ready
			first processing
			then ready;
		
		transition detecting_to_ready
			first detecting
			if detectionEventCount == 0
			then ready;
		
		transition ready_to_standby
			first ready
			accept powerOffEvent : PowerOffSignal
			then standby;
		
		state fault {
			entry assign systemStatus := "Fault";
		}
		
		transition standby_to_fault
			first standby
			accept faultEvent : SystemFaultSignal
			then fault;
		
		transition fault_to_standby
			first fault
			accept clearedEvent : FaultClearedSignal
			then standby;
	}
	
	part def GaseousIonizationDetector {
		attribute systemStatus : SystemStatusType;
		attribute detectionEfficiency : DetectionEfficiency;
		attribute operatingMode : String;
		attribute detectorType : String;
		
		port radiationInput : RadiationInputPort;
		port dataOutput : DataOutputPort;
		
		part chamber : DetectionChamber;
		part electrodes : ElectrodeAssembly;
		part hvSupply : HighVoltageSupply;
		part preamplifier : PreamplifierCircuit;
		part discriminator : PulseDiscriminator;
		part counter : CounterModule;
		part gasController : GasFlowController;
		
		connection hvToElectrodes connect hvSupply.hvOutput to electrodes.hvConnection;
		connection gasToDetector connect gasController.gasOutput to chamber.gasSupply;
		connection radiationToChamber connect radiationInput to chamber.radiationEntry;
		
		perform action detectRadiation : DetectRadiationEvent;
		
		exhibit state operationalStates : DetectorOperationalStates;
	}
	
	requirement def PrimaryDetectionRequirement {
		doc /* The gaseous ionization detector system shall detect ionizing radiation 
		     by measuring the ionization produced when radiation interacts with gas molecules 
		     in the detection chamber, producing ion-electron pairs that are collected 
		     and measured as electrical signals. */
		
		subject detector : GaseousIonizationDetector;
		
		require constraint detectionEfficiencyConstraint {
			detector.detectionEfficiency >= 0.85
		}
	}
	
	requirement def SignalAmplificationRequirement {
		doc /* The detector shall provide sufficient gas amplification to produce 
		     measurable electrical pulses from individual radiation events. */
		
		subject detector : GaseousIonizationDetector;
	}
	
	requirement def CountingAccuracyRequirement {
		doc /* The detector system shall accurately count and report radiation events 
		     with minimal dead time losses. */
		
		subject detector : GaseousIonizationDetector;
	}
	
	requirement def GasStabilityRequirement {
		doc /* The detector shall maintain stable gas composition and pressure 
		     throughout operation. */
		
		subject detector : GaseousIonizationDetector;
	}
	
	requirement detectorSystemRequirement {
		doc /* Top-level requirement for gaseous ionization detector system. */
		
		assume constraint radiationEnvironment {
			doc /* Ionizing radiation is present in the measurement environment. */
		}
		
		assume constraint powerAvailability {
			doc /* Stable electrical power is available for high voltage supply. */
		}
		
		require primaryDetection : PrimaryDetectionRequirement;
		require signalAmplification : SignalAmplificationRequirement;
		require countingAccuracy : CountingAccuracyRequirement;
		require gasStability : GasStabilityRequirement;
	}
	
	part proportionalCounterSystem : GaseousIonizationDetector {
		attribute systemStatus := "Standby";
		attribute detectionEfficiency := 0.92;
		attribute operatingMode := "Proportional Counter Mode";
		attribute detectorType := "Cylindrical Proportional Counter";
		
		part chamber : DetectionChamber {
			attribute volume = 785.4 [SI::mL];
			attribute gasType := "P10";
			attribute operatingPressure = 1.013 [SI::bar];
			attribute temperature = 293.15 [SI::K];
		}
		
		part electrodes : ElectrodeAssembly {
			attribute anodeMaterial := "gold-plated tungsten";
			attribute cathodeMaterial := "stainless steel";
			attribute electrodeSpacing = 15.0 [SI::mm];
			attribute appliedVoltage = 1650.0 [SI::V];
			attribute electricFieldStrength = 110000.0 [SI::'V/m'];
		}
		
		part hvSupply : HighVoltageSupply {
			attribute outputVoltage = 1650.0 [SI::V];
			attribute maxCurrent = 5.0E-4 [SI::A];
			attribute stability := 0.0005;
			attribute ripple = 0.05 [SI::V];
		}
		
		part preamplifier : PreamplifierCircuit {
			attribute inputImpedance := 2.0E6;
			attribute voltageGain := 250.0;
			attribute bandwidth = 2.0E6 [SI::Hz];
			attribute noiseLevel = 5.0E-4 [SI::V];
		}
		
		part discriminator : PulseDiscriminator {
			attribute lowerThreshold = 0.08 [SI::V];
			attribute upperThreshold = 4.5 [SI::V];
			attribute deadTime = 1.5E-6 [SI::s];
		}
		
		part counter : CounterModule {
			attribute totalCounts := 0;
			attribute liveTime = 0.0 [SI::s];
			attribute realTime = 0.0 [SI::s];
		}
		
		part gasController : GasFlowController {
			attribute gasComposition := "90% Argon, 10% Methane";
			attribute flowSetpoint = 8.0 [SI::'mL/s'];
			attribute pressureSetpoint = 1.013 [SI::bar];
		}
	}
}
