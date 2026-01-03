package DeepBrainStimulationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NeuralSignal;
	attribute def StimulationCommand;
	attribute def TherapyMode;
	attribute def BatteryStatus;
	attribute def PowerOn;
	attribute def ProgrammingRequest;
	attribute def ProgrammingComplete;
	attribute def TherapyStart;
	attribute def TherapyStop;
	
	attribute def StimulationParameters {
		attribute amplitude : ISQ::ElectricCurrentValue;
		attribute frequency : ISQ::FrequencyValue;
		attribute pulseWidth : ISQ::DurationValue;
	}
	
	item def NeuralTissue {
		attribute pathologicalActivity : Real;
		attribute normalActivity : Real;
	}
	
	item def ElectrodeContact {
		attribute surfaceArea : ISQ::AreaValue;
		attribute impedance : ISQ::ElectricResistanceValue;
	}
	
	port def StimulationPort {
		out stimPulse : StimulationParameters;
		in tissueImpedance : ISQ::ElectricResistanceValue;
	}
	
	port def SensingPort {
		in neuralSignal : NeuralSignal;
		out sampledActivity : Real;
	}
	
	port def TelemetryPort {
		in programmingData : StimulationParameters;
		out deviceData : BatteryStatus;
	}
	
	port def PowerPort {
		out powerSupply : ISQ::PowerValue;
		in powerDemand : ISQ::PowerValue;
	}
	
	part def ImplantablePulseGenerator {
		attribute deviceId : String;
		attribute batteryLevel : Real;
		attribute currentParameters : StimulationParameters;
		
		port telemetryInterface : TelemetryPort;
		port powerOutput : PowerPort;
		port stimulationChannel[4] : StimulationPort;
		port sensingChannel[4] : SensingPort;
		
		part battery {
			attribute capacity : ISQ::EnergyValue;
			attribute voltage : ISQ::ElectricPotentialValue;
			attribute remainingCharge : Real;
		}
		
		part stimulationCircuit {
			attribute numberOfChannels : Integer;
			attribute maxCurrent : ISQ::ElectricCurrentValue;
			attribute maxVoltage : ISQ::ElectricPotentialValue;
		}
		
		part sensingCircuit {
			attribute samplingRate : ISQ::FrequencyValue;
			attribute amplificationGain : Real;
		}
		
		part telemetryModule {
			attribute communicationFrequency : ISQ::FrequencyValue;
			attribute dataRate : Real;
		}
	}
	
	part def LeadAssembly {
		attribute leadLength : ISQ::LengthValue;
		attribute numberOfContacts : Integer;
		attribute totalImpedance : ISQ::ElectricResistanceValue;
		
		port proximalConnector : StimulationPort;
		port distalContacts[4] : StimulationPort;
		
		part leadBody {
			attribute diameter : ISQ::LengthValue;
			attribute material : String;
		}
		
		part contacts : ElectrodeContact[4] {
			attribute :>> surfaceArea : ISQ::AreaValue;
			attribute :>> impedance : ISQ::ElectricResistanceValue;
		}
	}
	
	part def TargetBrainRegion {
		attribute regionName : String;
		attribute volume : ISQ::VolumeValue;
		attribute baselineActivity : Real;
		
		port neuralInterface[4] : SensingPort;
		port stimulationInterface[4] : StimulationPort;
		
		part tissue : NeuralTissue {
			attribute :>> pathologicalActivity = 85.0;
			attribute :>> normalActivity = 45.0;
		}
	}
	
	part def ExternalProgrammer {
		attribute programmerModel : String;
		
		port telemetryInterface : TelemetryPort;
		
		part userInterface {
			attribute displayResolution : String;
		}
		
		part communicationModule {
			attribute protocol : String;
			attribute range : ISQ::LengthValue;
		}
	}
	
	action def SenseNeuralActivity {
		in targetRegion : TargetBrainRegion;
		out activityLevel : Real;
		out pathologyDetected : Boolean;
	}
	
	action def CalculateStimulationParameters {
		in measuredActivity : Real;
		in pathologyPresent : Boolean;
		in baselineParameters : StimulationParameters;
		out adjustedAmplitude : ISQ::ElectricCurrentValue;
		out adjustedFrequency : ISQ::FrequencyValue;
		out adjustedPulseWidth : ISQ::DurationValue;
	}
	
	action def GenerateStimulationPulse {
		in amplitude : ISQ::ElectricCurrentValue;
		in frequency : ISQ::FrequencyValue;
		in pulseWidth : ISQ::DurationValue;
		in tissueImpedance : ISQ::ElectricResistanceValue;
		out stimulationPulse : StimulationParameters;
		out deliveredCharge : Real;
	}
	
	action def DeliverTherapeuticStimulation {
		in stimulationPulse : StimulationParameters;
		in targetTissue : NeuralTissue;
		out modulatedActivity : Real;
		out therapeuticEffect : Real;
	}
	
	action def MonitorSafety {
		in deliveredCharge : Real;
		in tissueImpedance : ISQ::ElectricResistanceValue;
		in batteryLevel : Real;
		out safetyStatus : Boolean;
		out alertCondition : Boolean;
	}
	
	action def ClosedLoopNeuromodulation {
		first start;
		then merge continuousOperation;
		
		then action sense : SenseNeuralActivity {
			in targetRegion;
			out activityLevel : Real;
			out pathologyDetected : Boolean;
		}
		
		then action calculate : CalculateStimulationParameters {
			in measuredActivity = sense.activityLevel;
			in pathologyPresent = sense.pathologyDetected;
			in baselineParameters;
			out adjustedAmplitude : ISQ::ElectricCurrentValue;
			out adjustedFrequency : ISQ::FrequencyValue;
			out adjustedPulseWidth : ISQ::DurationValue;
		}
		
		then action generate : GenerateStimulationPulse {
			in amplitude = calculate.adjustedAmplitude;
			in frequency = calculate.adjustedFrequency;
			in pulseWidth = calculate.adjustedPulseWidth;
			in tissueImpedance;
			out stimulationPulse : StimulationParameters;
			out deliveredCharge : Real;
		}
		
		then action deliver : DeliverTherapeuticStimulation {
			in stimulationPulse = generate.stimulationPulse;
			in targetTissue;
			out modulatedActivity : Real;
			out therapeuticEffect : Real;
		}
		
		then action monitor : MonitorSafety {
			in deliveredCharge = generate.deliveredCharge;
			in tissueImpedance;
			in batteryLevel;
			out safetyStatus : Boolean;
			out alertCondition : Boolean;
		}
		
		then decide;
			if monitor.safetyStatus then continuousOperation;
			if !monitor.safetyStatus then done;
	}
	
	state def IPGOperationalStates {
		entry; then off;
		
		state off;
		transition off_to_standby
			first off
			accept powerOn : PowerOn
			then standby;
		
		state standby {
			entry; then idle;
			
			state idle;
			transition idle_to_programming
				first idle
				accept programmingRequest : ProgrammingRequest
				then programming;
			
			state programming;
			transition programming_to_idle
				first programming
				accept programmingComplete : ProgrammingComplete
				then idle;
		}
		
		transition standby_to_therapy
			first standby
			accept therapyStart : TherapyStart
			then therapy;
		
		state therapy {
			entry; then sensing;
			
			state sensing;
			state stimulating;
			state safetyCheck;
			
			transition sensing_to_stimulating
				first sensing
				then stimulating;
			
			transition stimulating_to_sensing
				first stimulating
				then sensing;
			
			transition to_safetyCheck
				first stimulating
				then safetyCheck;
			
			transition safetyCheck_to_sensing
				first safetyCheck
				then sensing;
		}
		
		transition therapy_to_standby
			first therapy
			accept therapyStop : TherapyStop
			then standby;
		
		state batteryLow;
		state batteryDepleted;
		
		transition to_batteryLow
			first therapy
			then batteryLow;
		
		transition batteryLow_to_off
			first batteryLow
			then batteryDepleted;
	}
	
	part def DBSTherapySystem;
	
	part dbsSystem : DBSTherapySystem {
		attribute systemIdentifier : String;
		attribute implantationDate : String;
		attribute patientId : String;
		
		part ipg : ImplantablePulseGenerator {
			attribute :>> deviceId = "IPG-2024-001";
			attribute :>> batteryLevel = 78.0;
			
			perform action therapy : ClosedLoopNeuromodulation;
			exhibit state operationalBehavior : IPGOperationalStates;
		}
		
		part leftLead : LeadAssembly {
			attribute :>> numberOfContacts = 4;
		}
		
		part rightLead : LeadAssembly {
			attribute :>> numberOfContacts = 4;
		}
		
		part leftSubthalamicNucleus : TargetBrainRegion {
			attribute :>> regionName = "Left Subthalamic Nucleus";
			attribute :>> baselineActivity = 45.0;
		}
		
		part rightSubthalamicNucleus : TargetBrainRegion {
			attribute :>> regionName = "Right Subthalamic Nucleus";
			attribute :>> baselineActivity = 47.0;
		}
		
		part clinicianProgrammer : ExternalProgrammer {
			attribute :>> programmerModel = "Medtronic N'Vision 8840";
		}
		
		connect ipg.stimulationChannel[1] to leftLead.proximalConnector;
		connect ipg.stimulationChannel[2] to rightLead.proximalConnector;
		connect leftLead.distalContacts[1] to leftSubthalamicNucleus.stimulationInterface[1];
		connect rightLead.distalContacts[1] to rightSubthalamicNucleus.stimulationInterface[1];
		connect leftSubthalamicNucleus.neuralInterface[1] to ipg.sensingChannel[1];
		connect rightSubthalamicNucleus.neuralInterface[1] to ipg.sensingChannel[2];
		connect clinicianProgrammer.telemetryInterface to ipg.telemetryInterface;
	}
	
	requirement def TherapeuticRequirement;
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def ReliabilityRequirement;
	
	requirement <'DBS-REQ-001'> primaryTherapeuticFunction : TherapeuticRequirement {
		doc /* The Deep Brain Stimulation system shall deliver precisely controlled 
		     electrical stimulation to targeted brain structures to modulate abnormal 
		     neural activity, thereby reducing motor symptoms in patients with movement 
		     disorders such as Parkinson's disease, essential tremor, and dystonia. */
		
		subject system : DBSTherapySystem = dbsSystem;
	}
	
	requirement <'DBS-REQ-002'> chargeDensitySafety : SafetyRequirement {
		doc /* The system shall limit the charge density delivered per phase to prevent 
		     neural tissue damage, maintaining charge density below 30 microcoulombs 
		     per square centimeter per phase at the electrode-tissue interface. */
		
		subject system : DBSTherapySystem = dbsSystem;
	}
	
	requirement <'DBS-REQ-003'> impedanceMonitoring : SafetyRequirement {
		doc /* The system shall continuously monitor electrode impedance and halt 
		     stimulation if impedance falls outside the range of 500 to 2000 ohms, 
		     indicating potential lead fracture, migration, or short circuit. */
		
		subject lead1 : LeadAssembly = dbsSystem.leftLead;
		subject lead2 : LeadAssembly = dbsSystem.rightLead;
	}
	
	requirement <'DBS-REQ-004'> batteryLongevity : ReliabilityRequirement {
		doc /* The implantable pulse generator battery shall provide continuous 
		     therapeutic stimulation for a minimum of 5 years under typical 
		     stimulation parameters before requiring surgical replacement or recharging. */
		
		subject generator : ImplantablePulseGenerator = dbsSystem.ipg;
	}
	
	requirement <'DBS-REQ-005'> closedLoopAdaptation : PerformanceRequirement {
		doc /* The system shall implement closed-loop control by continuously sensing 
		     neural activity and automatically adjusting stimulation parameters to 
		     maintain optimal therapeutic effect while minimizing side effects. */
		
		subject generator : ImplantablePulseGenerator = dbsSystem.ipg;
	}
	
	requirement <'DBS-REQ-006'> programmability : PerformanceRequirement {
		doc /* The system shall allow non-invasive programming of all stimulation 
		     parameters through wireless telemetry, enabling clinicians to optimize 
		     therapy without additional surgical procedures. */
		
		subject programmer : ExternalProgrammer = dbsSystem.clinicianProgrammer;
	}
	
	requirement <'DBS-REQ-007'> systemMission {
		doc /* The Deep Brain Stimulation system shall provide safe, effective, and 
		     reliable neuromodulation therapy by delivering adaptive electrical 
		     stimulation to specific brain targets, continuously monitoring system 
		     performance, and enabling clinical optimization to restore normal motor 
		     function in patients with debilitating movement disorders. */
		
		subject system : DBSTherapySystem = dbsSystem;
		
		require primaryTherapeuticFunction;
		require chargeDensitySafety;
		require impedanceMonitoring;
		require batteryLongevity;
		require closedLoopAdaptation;
		require programmability;
	}
}
