package CarbonNanotubeElectronicSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ChiralVector {
		attribute n : Integer;
		attribute m : Integer;
	}
	
	attribute def BandgapType {
		attribute isMetallic : Boolean;
		attribute isSemiconducting : Boolean;
		attribute bandgapEnergy : Real;
	}
	
	value def ElectricalConductanceValue :> ISQ::ElectricConductanceValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::SiemensUnit;
	}
	
	value def CarrierMobilityValue :> ISQ::AreaPerTimeValue {
		attribute :>> num : Real;
	}
	
	value def ResistanceValue :> ISQ::ElectricResistanceValue {
		attribute :>> num : Real;
		attribute :>> mRef : SI::OhmUnit;
	}
	
	value def CurrentDensityValue :> ISQ::ElectricCurrentPerAreaValue {
		attribute :>> num : Real;
	}
	
	item def ElectronFlow;
	item def GateSignal;
	item def DrainOutput;
	
	port def SourcePort {
		in item electronInput : ElectronFlow;
		attribute voltage : ISQ::ElectricPotentialDifferenceValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def DrainPort {
		out item electronOutput : ElectronFlow;
		attribute voltage : ISQ::ElectricPotentialDifferenceValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def GatePort {
		in item controlSignal : GateSignal;
		attribute voltage : ISQ::ElectricPotentialDifferenceValue;
	}
	
	part def CarbonNanotube {
		doc /* A carbon nanotube is a cylindrical nanostructure composed of rolled graphene sheets
		       with unique electrical properties determined by its chirality. */
		
		attribute diameter : ISQ::LengthValue;
		attribute length : ISQ::LengthValue;
		attribute chirality : ChiralVector;
		attribute bandgap : BandgapType;
		attribute intrinsicResistance : ResistanceValue;
		attribute carrierMobility : CarrierMobilityValue;
		attribute maxCurrentDensity : CurrentDensityValue;
		
		port sourceEnd : SourcePort;
		port drainEnd : DrainPort;
		
		assert constraint chiralityDeterminesBandgap {
			doc /* The electronic properties are determined by chiral indices (n,m).
			       If (n-m) is divisible by 3, the nanotube is metallic; otherwise semiconducting. */
			((chirality.n - chirality.m) % 3 == 0) implies bandgap.isMetallic
		}
		
		assert constraint diameterFromChirality {
			doc /* Diameter is determined by chiral vector and carbon-carbon bond length (0.142 nm). */
			diameter.num >= 0.4 and diameter.num <= 50.0
		}
		
		assert constraint currentDensityLimit {
			doc /* Carbon nanotubes can sustain extremely high current densities. */
			maxCurrentDensity.num >= 1.0e9
		}
	}
	
	part def GateElectrode {
		attribute material : String;
		attribute thickness : ISQ::LengthValue;
		attribute workFunction : Real;
		
		port gateControl : GatePort;
	}
	
	part def DielectricLayer {
		attribute material : String;
		attribute thickness : ISQ::LengthValue;
		attribute dielectricConstant : Real;
		attribute breakdownField : Real;
	}
	
	part def MetalContact {
		attribute material : String;
		attribute contactResistance : ResistanceValue;
		
		port contactInterface : SourcePort;
	}
	
	part def Substrate {
		attribute material : String;
		attribute thickness : ISQ::LengthValue;
	}
	
	action def ApplyGateVoltage {
		in gateVoltage : ISQ::ElectricPotentialDifferenceValue;
		in thresholdVoltage : ISQ::ElectricPotentialDifferenceValue;
		out isChannelOpen : Boolean;
		
		first start;
		then decide checkThreshold;
			if gateVoltage.num >= thresholdVoltage.num then openChannel;
			else closeChannel;
		
		action openChannel {
			assign isChannelOpen := true;
		}
		then merge;
		
		action closeChannel {
			assign isChannelOpen := false;
		}
		then merge;
		then done;
	}
	
	action def CalculateChannelCurrent {
		in sourceDrainVoltage : ISQ::ElectricPotentialDifferenceValue;
		in gateVoltage : ISQ::ElectricPotentialDifferenceValue;
		in channelResistance : ResistanceValue;
		in thresholdVoltage : ISQ::ElectricPotentialDifferenceValue;
		in transconductance : ElectricalConductanceValue;
		out drainCurrent : ISQ::ElectricCurrentValue;
		
		private attribute effectiveConductance : ElectricalConductanceValue;
		private attribute gateEffect : Real;
		
		first start;
		then assign gateEffect := (gateVoltage.num - thresholdVoltage.num);
		then assign effectiveConductance.num := transconductance.num * gateEffect;
		then decide operatingRegime;
			if gateVoltage.num < thresholdVoltage.num then cutoffRegion;
			if gateVoltage.num >= thresholdVoltage.num then activeRegion;
		
		action cutoffRegion {
			assign drainCurrent.num := 0.0;
		}
		then merge;
		
		action activeRegion {
			assign drainCurrent.num := sourceDrainVoltage.num / channelResistance.num * (1.0 + gateEffect);
		}
		then merge;
		then done;
	}
	
	action def TransportElectrons {
		in sourceVoltage : ISQ::ElectricPotentialDifferenceValue;
		in drainVoltage : ISQ::ElectricPotentialDifferenceValue;
		in gateVoltage : ISQ::ElectricPotentialDifferenceValue;
		in nanotubeResistance : ResistanceValue;
		in thresholdVoltage : ISQ::ElectricPotentialDifferenceValue;
		in transconductance : ElectricalConductanceValue;
		out outputCurrent : ISQ::ElectricCurrentValue;
		
		private attribute voltageDifference : ISQ::ElectricPotentialDifferenceValue;
		
		first start;
		then action applyGate : ApplyGateVoltage {
			in gateVoltage = gateVoltage;
			in thresholdVoltage = thresholdVoltage;
			out isChannelOpen;
		}
		then assign voltageDifference.num := sourceVoltage.num - drainVoltage.num;
		then action calculateCurrent : CalculateChannelCurrent {
			in sourceDrainVoltage = voltageDifference;
			in gateVoltage = gateVoltage;
			in channelResistance = nanotubeResistance;
			in thresholdVoltage = thresholdVoltage;
			in transconductance = transconductance;
			out drainCurrent;
		}
		then assign outputCurrent := calculateCurrent.drainCurrent;
		then done;
	}
	
	state def CNTTransistorStates {
		entry; then off;
		
		state off {
			doc /* Channel is non-conducting, gate voltage below threshold. */
		}
		
		state subthreshold {
			doc /* Weak conduction regime with exponential current-voltage relationship. */
		}
		
		state on {
			doc /* Channel is conducting, gate voltage above threshold. */
			entry; then linear;
			
			state linear {
				doc /* Linear region where drain current increases with drain voltage. */
			}
			
			state saturation {
				doc /* Saturation region where drain current is relatively constant. */
			}
		}
	}
	
	part carbonNanotubeTransistor : CarbonNanotube {
		doc /* A field-effect transistor using a semiconducting carbon nanotube as the channel material,
		       enabling high-performance electronic switching and amplification at the nanoscale. */
		
		attribute :>> diameter = 1.4 [nm];
		attribute :>> length = 500.0 [nm];
		attribute :>> chirality = ChiralVector {
			attribute :>> n = 19;
			attribute :>> m = 0;
		}
		attribute :>> bandgap = BandgapType {
			attribute :>> isMetallic = false;
			attribute :>> isSemiconducting = true;
			attribute :>> bandgapEnergy = 0.5;
		}
		attribute :>> intrinsicResistance = ResistanceValue { attribute :>> num = 6500.0; }
		attribute :>> carrierMobility = CarrierMobilityValue { attribute :>> num = 100000.0; }
		attribute :>> maxCurrentDensity = CurrentDensityValue { attribute :>> num = 1.0e9; }
		
		attribute thresholdVoltage : ISQ::ElectricPotentialDifferenceValue = 0.3 [V];
		attribute transconductance : ElectricalConductanceValue {
			attribute :>> num = 5.0e-6;
		}
		
		perform action electronTransport[*] ordered references TransportElectrons;
		
		part sourceContact : MetalContact {
			attribute :>> material = "Palladium";
			attribute :>> contactResistance = ResistanceValue { attribute :>> num = 100.0; }
			perform electronTransport;
		}
		
		part drainContact : MetalContact {
			attribute :>> material = "Palladium";
			attribute :>> contactResistance = ResistanceValue { attribute :>> num = 100.0; }
		}
		
		part gateElectrode : GateElectrode {
			attribute :>> material = "Aluminum";
			attribute :>> thickness = 50.0 [nm];
			attribute :>> workFunction = 4.3;
			perform electronTransport.applyGate;
		}
		
		part gateDielectric : DielectricLayer {
			attribute :>> material = "HfO2";
			attribute :>> thickness = 10.0 [nm];
			attribute :>> dielectricConstant = 25.0;
			attribute :>> breakdownField = 5.0e6;
		}
		
		part substrate : Substrate {
			attribute :>> material = "Silicon";
			attribute :>> thickness = 500.0 [um];
		}
		
		connect sourceContact.contactInterface to sourceEnd;
		connect drainContact.contactInterface to drainEnd;
		connect gateElectrode.gateControl to gateElectrode.gateControl;
	}
	
	requirement def <'CNT-FET-001'> SwitchingFunctionRequirement {
		doc /* The carbon nanotube transistor shall modulate electrical current flow between 
		       source and drain terminals in response to gate voltage control signals. */
		
		subject transistor : CarbonNanotube;
		
		require constraint {
			transistor.bandgap.isSemiconducting
		}
	}
	
	requirement def <'CNT-FET-002'> ThresholdVoltageRequirement {
		doc /* The transistor shall exhibit a well-defined threshold voltage below 0.5V 
		       for low-power operation. */
		
		subject transistor : CarbonNanotube;
		
		require constraint {
			transistor.thresholdVoltage.num <= 0.5
		}
	}
	
	requirement def <'CNT-FET-003'> OnOffRatioRequirement {
		doc /* The transistor shall achieve an on-off current ratio greater than 10^5 
		       for effective digital switching. */
		
		subject transistor : CarbonNanotube;
		
		require constraint {
			transistor.carrierMobility.num >= 10000.0
		}
	}
	
	requirement def <'CNT-FET-004'> CurrentDensityRequirement {
		doc /* The carbon nanotube channel shall support current densities exceeding 
		       10^9 A/cm^2 without degradation. */
		
		subject transistor : CarbonNanotube;
		
		require constraint {
			transistor.maxCurrentDensity.num >= 1.0e9
		}
	}
	
	requirement def <'CNT-FET-005'> GeometricRequirement {
		doc /* The nanotube diameter shall be between 0.4 nm and 50 nm, and length 
		       shall be optimized for the target application. */
		
		subject transistor : CarbonNanotube;
		
		require constraint {
			transistor.diameter.num >= 0.4 and 
			transistor.diameter.num <= 50.0 and
			transistor.length.num >= 100.0 and
			transistor.length.num <= 10000.0
		}
	}
	
	requirement <'CNT-FET-SYS'> carbonNanotubeTransistorSystemRequirement {
		doc /* The carbon nanotube field-effect transistor system shall function as a 
		       high-performance electronic switch, leveraging the exceptional electrical 
		       properties of semiconducting carbon nanotubes to enable voltage-controlled 
		       modulation of current flow for applications in nanoelectronics, high-frequency 
		       circuits, and low-power computing devices. */
		
		subject system = carbonNanotubeTransistor;
		
		assume constraint validChirality {
			system.chirality.n >= 0 and 
			system.chirality.m >= 0 and
			system.chirality.n >= system.chirality.m
		}
		
		assume constraint semiconductingNanotube {
			system.bandgap.isSemiconducting and
			not system.bandgap.isMetallic
		}
		
		require SwitchingFunctionRequirement;
		require ThresholdVoltageRequirement;
		require OnOffRatioRequirement;
		require CurrentDensityRequirement;
		require GeometricRequirement;
	}
}
