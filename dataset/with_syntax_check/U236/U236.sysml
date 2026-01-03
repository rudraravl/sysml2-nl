package 'Headache Hat System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PainLevel :> Integer {
		doc /* Subjective pain scale from 0 (no pain) to 10 (severe pain). */
	}
	
	attribute def TherapyMode;
	attribute def SessionStatus;
	
	part def CoolingGelPack {
		doc /* Reusable gel pack that stores thermal energy when frozen and releases cold during therapy. */
		attribute currentTemperature : ISQ::TemperatureValue;
		attribute thermalCapacity : ISQ::EnergyValue;
		attribute mass : ISQ::MassValue;
		
		attribute def ThermalStateKind;
		attribute thermalState : ThermalStateKind;
	}
	
	part def FabricShell {
		doc /* Soft, adjustable fabric housing that holds gel packs and conforms to head shape. */
		attribute material : String;
		attribute adjustable : Boolean;
		port gelPackSlot[4] {
			attribute slotPosition : String;
		}
	}
	
	part def CompressionStrap {
		doc /* Adjustable elastic strap providing gentle compression therapy. */
		attribute tension : ISQ::ForceValue;
		attribute adjustmentRange : ISQ::LengthValue;
	}
	
	part def TemperatureSensor {
		doc /* Monitors surface temperature at skin contact points. */
		attribute measuredTemperature : ISQ::TemperatureValue;
		attribute sampleRate : ISQ::FrequencyValue;
		port sensorOutput {
			out temperature : ISQ::TemperatureValue;
		}
	}
	
	port def TherapyControlPort {
		in startTherapy : Boolean;
		in stopTherapy : Boolean;
		out sessionActive : Boolean;
	}
	
	port def TemperatureMonitorPort {
		in skinTemperature : ISQ::TemperatureValue;
		out safetyAlert : Boolean;
	}
	
	action def PrepareGelPacks {
		doc /* Freeze gel packs to therapeutic temperature before use. */
		inout packs : CoolingGelPack[4];
		in freezingDuration : ISQ::TimeValue;
		out packsReady : Boolean;
	}
	
	action def MonitorSkinTemperature {
		doc /* Continuously monitor skin temperature to ensure safety. */
		in currentTemp : ISQ::TemperatureValue;
		in minSafeTemp : ISQ::TemperatureValue;
		out isSafe : Boolean;
	}
	
	action def ApplyCompression {
		doc /* Apply gentle, consistent compression to trigger pressure point relief. */
		in targetPressure : ISQ::PressureValue;
		out appliedForce : ISQ::ForceValue;
	}
	
	action def ConductColdTherapy {
		doc /* Transfer cooling effect from gel packs to targeted head regions. */
		in gelPackTemp : ISQ::TemperatureValue;
		in contactArea : ISQ::AreaValue;
		in duration : ISQ::TimeValue;
		out heatTransferred : ISQ::EnergyValue;
	}
	
	action def ProvideHeadacheRelief {
		doc /* 
		Primary therapeutic action combining cold therapy and compression 
		to reduce headache pain over a treatment session.
		*/
		in initialPainLevel : PainLevel;
		in sessionDuration : ISQ::TimeValue;
		in targetTemperature : ISQ::TemperatureValue;
		out finalPainLevel : PainLevel;
		out sessionComplete : SessionStatus;
		
		private attribute elapsedTime : ISQ::TimeValue := 0.0 [SI::s];
		private attribute currentSkinTemp : ISQ::TemperatureValue;
		private attribute safetyStatus : Boolean := true;
		
		first start;
		
		then action checkPreparation {
			doc /* Verify gel packs are properly frozen before starting. */
			out ready : Boolean;
		}
		
		then decide;
			if checkPreparation.ready then beginSession;
			else abortSession;
		
		action beginSession {
			doc /* Initialize therapy session with gel pack application. */
		}
		
		then action applyCompression : ApplyCompression {
			in targetPressure = 5000.0 [SI::Pa];
			out appliedForce;
		}
		
		then merge therapyLoop;
		
		then action conductCooling : ConductColdTherapy {
			in gelPackTemp = targetTemperature;
			in contactArea = 0.015 [SI::m^2];
			in duration = 60.0 [SI::s];
			out heatTransferred;
		}
		
		then action monitorSafety : MonitorSkinTemperature {
			in currentTemp = currentSkinTemp;
			in minSafeTemp = 273.15 [SI::K];
			out isSafe;
		}
		
		then assign elapsedTime := elapsedTime + 60.0 [SI::s];
		then assign safetyStatus := monitorSafety.isSafe;
		
		then decide;
			if elapsedTime >= sessionDuration and safetyStatus then completeSession;
			if not safetyStatus then emergencyStop;
			if elapsedTime < sessionDuration and safetyStatus then therapyLoop;
		
		action completeSession {
			doc /* Normal completion of therapy session. */
		}
		then assign finalPainLevel := if initialPainLevel > 3 then initialPainLevel - 4 else 0;
		then assign sessionComplete := "Success";
		then done;
		
		action emergencyStop {
			doc /* Immediate termination due to safety concern. */
		}
		then assign finalPainLevel := initialPainLevel;
		then assign sessionComplete := "Aborted - Safety";
		then done;
		
		action abortSession {
			doc /* Session cannot start due to improper preparation. */
		}
		then assign finalPainLevel := initialPainLevel;
		then assign sessionComplete := "Aborted - Not Ready";
		then done;
	}
	
	part def HeadacheHat {
		doc /* 
		Wearable therapeutic device combining targeted cold therapy and gentle 
		compression to provide non-pharmaceutical headache relief through 
		controlled application of cooling gel packs to key pressure points 
		on the head.
		*/
		
		attribute recommendedSessionDuration : ISQ::TimeValue := 1200.0 [SI::s];
		attribute therapeuticTemperature : ISQ::TemperatureValue := 277.15 [SI::K];
		
		part shell : FabricShell {
			attribute material = "Neoprene";
			attribute adjustable = true;
		}
		
		part gelPacks : CoolingGelPack[4] {
			attribute mass = 0.15 [SI::kg];
			attribute thermalCapacity = 50000.0 [SI::J];
		}
		
		part strap : CompressionStrap {
			attribute tension = 8.0 [SI::N];
			attribute adjustmentRange = 0.1 [SI::m];
		}
		
		part sensors : TemperatureSensor[2] {
			attribute sampleRate = 0.1 [SI::Hz];
		}
		
		port therapyControl : TherapyControlPort;
		port tempMonitor : TemperatureMonitorPort;
		
		perform action deliverTherapy[*] ordered references provideHeadacheRelief;
		
		connect shell.gelPackSlot[1] to gelPacks[1];
		connect shell.gelPackSlot[2] to gelPacks[2];
		connect shell.gelPackSlot[3] to gelPacks[3];
		connect shell.gelPackSlot[4] to gelPacks[4];
		
		connect sensors[1].sensorOutput.temperature to tempMonitor.skinTemperature;
	}
	
	action provideHeadacheRelief : ProvideHeadacheRelief {
		in initialPainLevel : PainLevel = 7;
		in sessionDuration = 1200.0 [SI::s];
		in targetTemperature = 277.15 [SI::K];
		out finalPainLevel : PainLevel;
		out sessionComplete : SessionStatus;
	}
	
	requirement def TherapeuticEffectivenessRequirement {
		doc /* 
		The system shall effectively reduce headache pain through combined 
		cold and compression therapy.
		*/
		subject hat : HeadacheHat;
	}
	
	requirement def TemperatureSafetyRequirement {
		doc /* 
		The system shall maintain safe skin contact temperatures to prevent 
		cold injury.
		*/
		subject hat : HeadacheHat;
	}
	
	requirement def ComfortRequirement {
		doc /* 
		The system shall provide therapy without causing excessive discomfort 
		or pressure.
		*/
		subject hat : HeadacheHat;
	}
	
	requirement def UsabilityRequirement {
		doc /* 
		The system shall be easy to prepare, apply, and use without assistance.
		*/
		subject hat : HeadacheHat;
	}
	
	requirement <'REQ-001'> painReductionRequirement : TherapeuticEffectivenessRequirement {
		doc /* 
		The Headache Hat shall reduce user-reported pain levels by at least 
		3 points on a 0-10 scale after a 20-minute therapy session for users 
		with initial pain levels of 5 or higher.
		*/
		subject hat : HeadacheHat;
	}
	
	requirement <'REQ-002'> temperatureRangeRequirement : TemperatureSafetyRequirement {
		doc /* 
		The gel pack surface temperature in contact with skin shall remain 
		between 273.15 K (0°C) and 283.15 K (10°C) throughout the therapy 
		session to ensure safety and effectiveness.
		*/
		subject hat : HeadacheHat;
		assume constraint gelPacksFrozen {
			doc /* Gel packs must be frozen to at least 253.15 K before use. */
		}
		require constraint skinTempMonitored {
			doc /* Skin temperature must be continuously monitored. */
		}
	}
	
	requirement <'REQ-003'> compressionLimitRequirement : ComfortRequirement {
		doc /* 
		The compression strap shall apply pressure not exceeding 7 kPa to 
		prevent discomfort and ensure adequate blood circulation.
		*/
		subject hat : HeadacheHat;
	}
	
	requirement <'REQ-004'> sessionDurationRequirement : TherapeuticEffectivenessRequirement {
		doc /* 
		The system shall maintain therapeutic cooling for a minimum of 
		20 minutes from a fully frozen state to allow sufficient treatment time.
		*/
		subject hat : HeadacheHat;
	}
	
	requirement <'REQ-005'> preparationSimplicityRequirement : UsabilityRequirement {
		doc /* 
		The gel packs shall be removable and freezer-safe, requiring only 
		standard household freezer storage (253.15 K) for 2 hours to prepare.
		*/
		subject hat : HeadacheHat;
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the Headache Hat system. */
		subject hat : HeadacheHat;
		require painReductionRequirement;
		require temperatureRangeRequirement;
		require compressionLimitRequirement;
		require sessionDurationRequirement;
		require preparationSimplicityRequirement;
	}
}
