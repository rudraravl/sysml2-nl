package 'Effluent Decontamination System' {
	private import ScalarValues::*;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;
	private import ScalarValues::Real;

	attribute def ContaminantConcentration :> Real {
		doc /* Contaminant concentration in parts per million (ppm) */
	}
	attribute def pHValue :> Real {
		doc /* pH measurement on 0-14 scale */
	}
	attribute def FlowRateValue :> Real {
		doc /* Flow rate in liters per minute */
	}
	attribute def VolumeValue :> Real {
		doc /* Volume in liters */
	}
	attribute def DurationValue :> Real {
		doc /* Duration in minutes */
	}
	attribute def IrradianceValue :> Real {
		doc /* UV intensity in watts per square meter */
	}

	item def RawEffluent {
		doc /* Raw contaminated wastewater entering the system */
	}
	item def FilteredEffluent {
		doc /* Effluent after large solid particle removal */
	}
	item def ChemicallyTreatedEffluent {
		doc /* Effluent after chemical neutralization */
	}
	item def BiologicallyTreatedEffluent {
		doc /* Effluent after biological digestion */
	}
	item def SterilizedEffluent {
		doc /* Effluent after UV sterilization */
	}
	item def DischargedEffluent {
		doc /* Final treated effluent approved for discharge */
	}
	item def ChemicalReagent {
		doc /* Chemical reagent for neutralizing contaminants */
	}
	item def Biomass {
		doc /* Concentrated microorganisms for biological treatment */
	}
	item def QualityReport {
		doc /* Report containing quality measurements */
		attribute contaminantLevel : ContaminantConcentration;
		attribute pHLevel : pHValue;
	}
	item def AlarmNotification {
		doc /* Notification sent when quality standards are not met */
		attribute severity : String;
		attribute alarmText : String;
	}

	port def FluidInPort {
		in item fluid;
	}
	port def FluidOutPort {
		out item fluid;
	}
	port def ReportInPort {
		in item report : QualityReport;
	}
	port def ReportOutPort {
		out item report : QualityReport;
	}
	port def ControlOutPort {
		out attribute approved : Boolean;
	}
	port def ControlInPort {
		in attribute approved : Boolean;
	}
	port def AlarmOutPort {
		out item alarm : AlarmNotification;
	}
	port def AlarmInPort {
		in item alarm : AlarmNotification;
	}

	state def TreatmentState {
		doc /* State machine governing sequential effluent treatment */
		state idle;
		state intaking;
		state filtering;
		state chemicalTreating;
		state biologicalTreating;
		state uvSterilizing;
		state qualityMonitoring;
		state discharging;
		state alarmRaised;
		transition idle to intaking;
		transition intaking to filtering;
		transition filtering to chemicalTreating;
		transition chemicalTreating to biologicalTreating;
		transition biologicalTreating to uvSterilizing;
		transition uvSterilizing to qualityMonitoring;
		transition qualityMonitoring to discharging;
		transition qualityMonitoring to alarmRaised;
		transition alarmRaised to idle;
		transition discharging to idle;
	}

	part def IntakePump {
		doc /* Draws raw effluent into the system at specified flow rate */
		attribute nominalFlowRate : FlowRateValue = 1000;
		port inflow : FluidInPort;
		port outflow : FluidOutPort;
	}

	part def PreTreatmentFilter {
		doc /* Removes large solid particles from raw effluent */
		port inflow : FluidInPort;
		port outflow : FluidOutPort;
	}

	part def ChemicalReactor {
		doc /* Introduces chemical reagent to neutralize contaminants */
		attribute reagentDoseVolume : VolumeValue = 50;
		port inflow : FluidInPort;
		port outflow : FluidOutPort;
		port reagentPort : FluidInPort;
	}

	part def BiologicalTreatmentUnit {
		doc /* Uses concentrated biomass to digest and break down organic waste */
		attribute treatmentDuration : DurationValue = 30;
		attribute biomassVolume : VolumeValue = 200;
		port inflow : FluidInPort;
		port outflow : FluidOutPort;
	}

	part def UVSterilizer {
		doc /* Uses high-intensity UV light to disinfect water */
		attribute uvIntensity : IrradianceValue = 40000;
		attribute exposureDuration : DurationValue = 5;
		port inflow : FluidInPort;
		port outflow : FluidOutPort;
	}

	part def QualityMonitor {
		doc /* Measures final contaminant concentration and pH levels */
		attribute contaminantLevel : ContaminantConcentration;
		attribute pHReading : pHValue;
		port inflow : FluidInPort;
		port outflow : FluidOutPort;
		port reportPort : ReportOutPort;
	}

	part def ControlSystem {
		doc /* Central control system that uses quality data to ensure treatment effectiveness */
		attribute maxContaminantLevel : ContaminantConcentration = 10;
		attribute minAcceptablepH : pHValue = 6.5;
		attribute maxAcceptablepH : pHValue = 8.5;
		attribute dischargeApproved : Boolean = false;
		attribute alarmRaised : Boolean = false;
		port reportIn : ReportInPort;
		port controlOut : ControlOutPort;
		port alarmPort : AlarmOutPort;
	}

	part def DischargeValve {
		doc /* Final discharge valve for treated effluent */
		port inflow : FluidInPort;
		port controlIn : ControlInPort;
	}

	part def AlarmIndicator {
		doc /* Alerts operators of system failure when quality standards are not met */
		port alarmIn : AlarmInPort;
	}

	action def IntakeAction {
		doc /* Draws raw effluent into the system */
		in item rawEffluent : RawEffluent;
		out item drawnEffluent : RawEffluent;
	}

	action def FilterAction {
		doc /* Removes large solid particles from effluent */
		in item input : RawEffluent;
		out item filtered : FilteredEffluent;
	}

	action def ChemicalTreatmentAction {
		doc /* Introduces chemical reagent to neutralize contaminants */
		in item input : FilteredEffluent;
		in item reagent : ChemicalReagent;
		out item treated : ChemicallyTreatedEffluent;
	}

	action def BiologicalTreatmentAction {
		doc /* Uses concentrated biomass to digest organic waste */
		in item input : ChemicallyTreatedEffluent;
		in item biomass : Biomass;
		out item treated : BiologicallyTreatedEffluent;
	}

	action def UVSterilizationAction {
		doc /* Uses UV light to disinfect water */
		in item input : BiologicallyTreatedEffluent;
		out item sterilized : SterilizedEffluent;
	}

	action def QualityMonitoringAction {
		doc /* Measures contaminant concentration and pH levels */
		in item input : SterilizedEffluent;
		out item report : QualityReport;
		out item sample : SterilizedEffluent;
	}

	action def DischargeAction {
		doc /* Discharges treated effluent */
		in item input : SterilizedEffluent;
		out item discharged : DischargedEffluent;
	}

	action def TreatmentProcess {
		doc /* Complete sequential treatment process for effluent decontamination */
		in item rawInput : RawEffluent;
		out item treatedOutput : DischargedEffluent;

		action intake : IntakeAction {
			in item rawEffluent = rawInput;
			out item drawnEffluent;
		}
		flow from intake.drawnEffluent to filter.input;

		action filter : FilterAction {
			in item input;
			out item filtered;
		}
		flow from filter.filtered to chemicalTreatment.input;

		action chemicalTreatment : ChemicalTreatmentAction {
			in item input;
			in item reagent;
			out item treated;
		}
		flow from chemicalTreatment.treated to biologicalTreatment.input;

		action biologicalTreatment : BiologicalTreatmentAction {
			in item input;
			in item biomass;
			out item treated;
		}
		flow from biologicalTreatment.treated to uvSterilization.input;

		action uvSterilization : UVSterilizationAction {
			in item input;
			out item sterilized;
		}
		flow from uvSterilization.sterilized to qualityMonitoring.input;

		action qualityMonitoring : QualityMonitoringAction {
			in item input;
			out item report;
			out item sample;
		}
		flow from qualityMonitoring.sample to discharge.input;

		action discharge : DischargeAction {
			in item input;
			out item discharged;
		}
	}

	part def DecontaminationPlant {
		doc /* Multi-stage effluent decontamination system for treating contaminated wastewater to safe discharge levels */

		part intakePump : IntakePump;
		part preFilter : PreTreatmentFilter;
		part chemicalReactor : ChemicalReactor;
		part bioUnit : BiologicalTreatmentUnit;
		part uvSterilizer : UVSterilizer;
		part qualityMonitor : QualityMonitor;
		part controlSystem : ControlSystem;
		part dischargeValve : DischargeValve;
		part alarmIndicator : AlarmIndicator;

		connect intakePump.outflow to preFilter.inflow;
		connect preFilter.outflow to chemicalReactor.inflow;
		connect chemicalReactor.outflow to bioUnit.inflow;
		connect bioUnit.outflow to uvSterilizer.inflow;
		connect uvSterilizer.outflow to qualityMonitor.inflow;
		connect qualityMonitor.outflow to dischargeValve.inflow;

		connect qualityMonitor.reportPort to controlSystem.reportIn;
		connect controlSystem.controlOut to dischargeValve.controlIn;
		connect controlSystem.alarmPort to alarmIndicator.alarmIn;

		state treatmentState : TreatmentState;
	}

	requirement throughputRequirement {
		doc /* The system shall process a minimum of 1000 liters of wastewater per minute */
		subject plant : DecontaminationPlant;
		attribute requiredFlowRate : FlowRateValue = 1000;
		require constraint {
			plant.intakePump.nominalFlowRate >= requiredFlowRate
		}
	}

	requirement contaminantLevelRequirement {
		doc /* Treated effluent shall have contaminant concentration of 10 ppm or less for discharge approval */
		subject plant : DecontaminationPlant;
		attribute maxContaminant : ContaminantConcentration = 10;
		require constraint {
			plant.qualityMonitor.contaminantLevel <= maxContaminant
		}
	}

	requirement pHRangeRequirement {
		doc /* Treated effluent shall have pH within safe discharge range of 6.5 to 8.5 */
		subject plant : DecontaminationPlant;
		attribute minpH : pHValue = 6.5;
		attribute maxpH : pHValue = 8.5;
		require constraint {
			plant.qualityMonitor.pHReading >= minpH and
			plant.qualityMonitor.pHReading <= maxpH
		}
	}

	requirement alarmOnFailureRequirement {
		doc /* The control system shall raise an alarm if treated effluent does not meet contaminant level standard of 10 ppm */
		subject plant : DecontaminationPlant;
		attribute threshold : ContaminantConcentration = 10;
		require constraint {
			plant.qualityMonitor.contaminantLevel <= threshold or
			plant.controlSystem.alarmRaised == true
		}
	}

	requirement dischargeApprovalRequirement {
		doc /* Discharge shall only occur when contaminant level is at or below 10 ppm and pH is within 6.5 to 8.5 */
		subject plant : DecontaminationPlant;
		attribute maxContaminant : ContaminantConcentration = 10;
		attribute minpH : pHValue = 6.5;
		attribute maxpH : pHValue = 8.5;
		require constraint {
			plant.controlSystem.dischargeApproved == true implies
			(plant.qualityMonitor.contaminantLevel <= maxContaminant and
			plant.qualityMonitor.pHReading >= minpH and
			plant.qualityMonitor.pHReading <= maxpH)
		}
	}
}
