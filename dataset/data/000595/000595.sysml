package EffluentDecontaminationSystem {
	private import ISQ::*;
	private import ScalarValues::*;
	
	attribute def StartCmd;
	attribute def StopCmd;
	attribute def AlarmSignal;
	
	attribute def ContaminantConcentration {
		attribute value : Real;
		attribute unit : String = "ppm";
	}
	
	attribute def FlowRate {
		attribute value : Real;
		attribute unit : String = "L/min";
	}
	
	item def RawEffluent {
		attribute contaminantLevel : ContaminantConcentration;
		attribute flowRate : FlowRate;
		attribute temperature : TemperatureValue;
		attribute pH : Real;
	}
	
	item def TreatedEffluent {
		attribute contaminantLevel : ContaminantConcentration;
		attribute flowRate : FlowRate;
		attribute temperature : TemperatureValue;
		attribute pH : Real;
	}
	
	item def ChemicalReagent {
		attribute dosage : MassValue;
		attribute concentration : Real;
	}
	
	part def IntakePump {
		port inlet : RawEffluent;
		port outlet : RawEffluent;
		attribute maxFlowRate : FlowRate;
	}
	
	part def PreTreatmentFilter {
		port inlet : RawEffluent;
		port outlet : RawEffluent;
		attribute filterSize : LengthValue;
	}
	
	part def ChemicalReactor {
		port effluentInlet : RawEffluent;
		port effluentOutlet : RawEffluent;
		port reagentInlet : ChemicalReagent;
		attribute reactionTime : TimeValue;
		attribute operatingTemperature : TemperatureValue;
	}
	
	part def BiologicalTreatmentUnit {
		port inlet : RawEffluent;
		port outlet : RawEffluent;
		attribute retentionTime : TimeValue;
		attribute biomassConcentration : Real;
	}
	
	part def UVSterilizer {
		port inlet : RawEffluent;
		port outlet : TreatedEffluent;
		attribute uvIntensity : PowerValue;
		attribute exposureTime : TimeValue;
	}
	
	part def QualityMonitor {
		port sampleInlet : TreatedEffluent;
		attribute measuredContaminantLevel : ContaminantConcentration;
		attribute measuredpH : Real;
	}
	
	part def ControlSystem {
		port commandInput : StartCmd;
		port alarmOutput : AlarmSignal;
	}
	
	action def PumpEffluent {
		in rawInput : RawEffluent;
		out pumpedOutput : RawEffluent;
	}
	
	action def FilterSolids {
		in unfilteredInput : RawEffluent;
		out filteredOutput : RawEffluent;
	}
	
	action def ChemicalNeutralization {
		in contaminatedInput : RawEffluent;
		in reagent : ChemicalReagent;
		out neutralizedOutput : RawEffluent;
	}
	
	action def BiologicalDigestion {
		in organicInput : RawEffluent;
		out digestedOutput : RawEffluent;
	}
	
	action def UVDisinfection {
		in treatedInput : RawEffluent;
		out sterilizedOutput : TreatedEffluent;
	}
	
	action def MonitorQuality {
		in sampleInput : TreatedEffluent;
		out contaminantReading : ContaminantConcentration;
		out pHReading : Real;
	}
	
	action def RaiseAlarm {
		in qualityFailure : Boolean;
		out alarm : AlarmSignal;
	}
	
	action def DecontaminateEffluent {
		in rawEffluentInput : RawEffluent;
		in chemicalReagentInput : ChemicalReagent;
		in startSignal : StartCmd;
		in stopSignal : StopCmd;
		out cleanEffluentOutput : TreatedEffluent;
		out alarmSignalOutput : AlarmSignal;
		
		first start;
		then merge continueProcessing;
		then action processEffluent {
			action pump : PumpEffluent {
				in rawInput = rawEffluentInput;
				out pumpedOutput : RawEffluent;
			}
			flow pump.pumpedOutput to filter.unfilteredInput;
			
			action filter : FilterSolids {
				in unfilteredInput : RawEffluent;
				out filteredOutput : RawEffluent;
			}
			flow filter.filteredOutput to neutralize.contaminatedInput;
			
			action neutralize : ChemicalNeutralization {
				in contaminatedInput : RawEffluent;
				in reagent = chemicalReagentInput;
				out neutralizedOutput : RawEffluent;
			}
			flow neutralize.neutralizedOutput to digest.organicInput;
			
			action digest : BiologicalDigestion {
				in organicInput : RawEffluent;
				out digestedOutput : RawEffluent;
			}
			flow digest.digestedOutput to sterilize.treatedInput;
			
			action sterilize : UVDisinfection {
				in treatedInput : RawEffluent;
				out sterilizedOutput : TreatedEffluent;
			}
			flow sterilize.sterilizedOutput to monitor.sampleInput;
			
			action monitor : MonitorQuality {
				in sampleInput : TreatedEffluent;
				out contaminantReading : ContaminantConcentration;
				out pHReading : Real;
			}
		}
		then decide;
			if processEffluent.monitor.contaminantReading.value <= 10.0 then cleanOutput;
			if processEffluent.monitor.contaminantReading.value > 10.0 then raiseAlarmAction;
		action cleanOutput {
			then assign cleanEffluentOutput = processEffluent.sterilize.sterilizedOutput;
		}
		then continueProcessing;
		action raiseAlarmAction : RaiseAlarm {
			in qualityFailure = true;
			out alarm : AlarmSignal;
		}
		then assign alarmSignalOutput = raiseAlarmAction.alarm;
		then continueProcessing;
	}
	
	part def EffluentDecontaminationSystemDef {
		port rawEffluentInlet : RawEffluent;
		port treatedEffluentOutlet : TreatedEffluent;
		port chemicalReagentInlet : ChemicalReagent;
		port systemStart : StartCmd;
		port systemStop : StopCmd;
		port systemAlarm : AlarmSignal;
		
		part intakePump : IntakePump;
		part preTreatmentFilter : PreTreatmentFilter;
		part chemicalReactor : ChemicalReactor;
		part biologicalUnit : BiologicalTreatmentUnit;
		part uvSterilizer : UVSterilizer;
		part qualityMonitor : QualityMonitor;
		part controlSystem : ControlSystem;
		
		connect rawEffluentInlet to intakePump.inlet;
		connect intakePump.outlet to preTreatmentFilter.inlet;
		connect preTreatmentFilter.outlet to chemicalReactor.effluentInlet;
		connect chemicalReagentInlet to chemicalReactor.reagentInlet;
		connect chemicalReactor.effluentOutlet to biologicalUnit.inlet;
		connect biologicalUnit.outlet to uvSterilizer.inlet;
		connect uvSterilizer.outlet to qualityMonitor.sampleInlet;
		connect uvSterilizer.outlet to treatedEffluentOutlet;
		connect systemStart to controlSystem.commandInput;
		connect controlSystem.alarmOutput to systemAlarm;
		
		perform action decontaminationProcess[*] ordered references DecontaminateEffluent;
	}
	
	part system : EffluentDecontaminationSystemDef {
		part p : IntakePump {
			perform decontaminationProcess.processEffluent.pump;
		}
		part f : PreTreatmentFilter {
			perform decontaminationProcess.processEffluent.filter;
		}
		part r : ChemicalReactor {
			perform decontaminationProcess.processEffluent.neutralize;
		}
		part b : BiologicalTreatmentUnit {
			perform decontaminationProcess.processEffluent.digest;
		}
		part u : UVSterilizer {
			perform decontaminationProcess.processEffluent.sterilize;
		}
		part m : QualityMonitor {
			perform decontaminationProcess.processEffluent.monitor;
		}
		part c : ControlSystem {
			perform decontaminationProcess.raiseAlarmAction;
		}
	}
	
	requirement def ContaminantRemovalRequirement {
		doc /* The system shall reduce contaminant concentration to safe discharge levels. */
		attribute maxAllowableConcentration : Real;
	}
	
	requirement def ThroughputRequirement {
		doc /* The system shall process a minimum volume of effluent per hour. */
		attribute minThroughput : FlowRate;
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall raise an alarm if treated effluent exceeds contamination thresholds. */
	}
	
	requirement <'EDS-REQ-001'> contaminantRemoval : ContaminantRemovalRequirement {
		subject sys : EffluentDecontaminationSystemDef;
		maxAllowableConcentration = 10.0;
		require constraint {
			sys.treatedEffluentOutlet.contaminantLevel.value <= maxAllowableConcentration
		}
	}
	
	requirement <'EDS-REQ-002'> systemThroughput : ThroughputRequirement {
		subject sys : EffluentDecontaminationSystemDef;
		attribute minThroughput : FlowRate {
			attribute value = 1000.0;
			attribute unit = "L/min";
		}
	}
	
	requirement <'EDS-REQ-003'> alarmActivation : SafetyRequirement {
		subject sys : EffluentDecontaminationSystemDef;
	}
}
