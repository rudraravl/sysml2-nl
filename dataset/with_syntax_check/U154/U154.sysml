package AutoclaveTapeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def IndicatorColor {
		attribute red : Real;
		attribute green : Real;
		attribute blue : Real;
	}
	
	enum def SterilizationStatus {
		enum notSterilized;
		enum sterilized;
	}
	
	attribute def SteamTemperature :> ISQ::thermodynamicTemperature;
	attribute def SteamPressure :> ISQ::pressure;
	attribute def ExposureDuration :> ISQ::time;
	
	item def SteamConditions {
		attribute temperature : SteamTemperature;
		attribute pressure : SteamPressure;
		attribute duration : ExposureDuration;
	}
	
	item def SterilizationCommand;
	item def CompletionSignal;
	
	port def SteamExposurePort {
		in item steamConditions : SteamConditions;
	}
	
	port def IndicatorOutputPort {
		out attribute status : SterilizationStatus;
		out attribute color : IndicatorColor;
	}
	
	port def ControlPort {
		in item command : SterilizationCommand;
		out item completion : CompletionSignal;
	}
	
	part def ChemicalIndicator {
		attribute currentColor : IndicatorColor;
		attribute status : SterilizationStatus = SterilizationStatus::notSterilized;
		attribute activationTemperature : SteamTemperature = 394.15[SI::K];
		attribute activationPressure : SteamPressure = 205000.0[SI::Pa];
		attribute requiredExposure : ExposureDuration = 900.0[SI::s];
		
		port exposurePort : SteamExposurePort;
		port indicatorPort : IndicatorOutputPort;
	}
	
	part def AdhesiveBacking {
		attribute bondStrength : ISQ::pressure;
		attribute maxTemperature : SteamTemperature;
	}
	
	part def AutoclaveTape {
		part indicator : ChemicalIndicator;
		part adhesive : AdhesiveBacking {
			attribute bondStrength = 100000.0[SI::Pa];
			attribute maxTemperature = 423.15[SI::K];
		}
		
		attribute tapeLength : ISQ::length;
		attribute tapeWidth : ISQ::length;
	}
	
	part def SteamGenerator {
		attribute setpointTemperature : SteamTemperature;
		attribute setpointPressure : SteamPressure;
		
		port steamOutput : SteamExposurePort;
		
		perform action generateSteam : ProduceSteam;
	}
	
	part def AutoclaveChamber {
		attribute chamberVolume : ISQ::volume;
		attribute currentTemperature : SteamTemperature;
		attribute currentPressure : SteamPressure;
		
		port steamInput : SteamExposurePort;
		part loadedTape : AutoclaveTape {
			attribute tapeLength = 0.5[SI::m];
			attribute tapeWidth = 0.025[SI::m];
		}
	}
	
	part def ControlSystem {
		attribute cycleStartTime : ISQ::time;
		attribute cycleEndTime : ISQ::time;
		
		port controlPort : ControlPort;
		
		perform action manageCycle : ExecuteSterilizationCycle;
	}
	
	action def ProduceSteam {
		in targetTemp : SteamTemperature;
		in targetPressure : SteamPressure;
		out steamOutput : SteamConditions;
		
		first start;
		then action heatWater {
			assign steamOutput.temperature := targetTemp;
		}
		then action pressurize {
			assign steamOutput.pressure := targetPressure;
		}
		then done;
	}
	
	action def MonitorIndicator {
		in exposureConditions : SteamConditions;
		in activationTemp : SteamTemperature;
		in activationPressure : SteamPressure;
		in requiredDuration : ExposureDuration;
		out indicatorStatus : SterilizationStatus;
	}
	
	action def ChangeIndicatorColor {
		in currentStatus : SterilizationStatus;
		out newColor : IndicatorColor;
		
		decide;
			if currentStatus == SterilizationStatus::sterilized then setGreen;
			if currentStatus == SterilizationStatus::notSterilized then setBeige;
		
		action setGreen {
			assign newColor.red := 0.0;
			assign newColor.green := 1.0;
			assign newColor.blue := 0.0;
		}
		
		action setBeige {
			assign newColor.red := 0.96;
			assign newColor.green := 0.96;
			assign newColor.blue := 0.86;
		}
	}
	
	action def ExecuteSterilizationCycle {
		in command : SterilizationCommand;
		in tapeIndicator : ChemicalIndicator;
		out completion : CompletionSignal;
		
		first start;
		then merge cycleLoop;
		
		then action monitorConditions : MonitorIndicator {
			in exposureConditions;
			in activationTemp = tapeIndicator.activationTemperature;
			in activationPressure = tapeIndicator.activationPressure;
			in requiredDuration = tapeIndicator.requiredExposure;
			out indicatorStatus;
		}
		
		then action updateColor : ChangeIndicatorColor {
			in currentStatus = monitorConditions.indicatorStatus;
			out newColor;
		}
		
		then decide;
			if monitorConditions.indicatorStatus == SterilizationStatus::sterilized then completeCycle;
			if monitorConditions.indicatorStatus == SterilizationStatus::notSterilized then cycleLoop;
		
		action completeCycle {
			send completion;
		}
		
		then done;
	}
	
	state def IndicatorLifecycle {
		entry; then inactive;
		
		state inactive {
			entry assign currentColor.red := 0.96;
			entry assign currentColor.green := 0.96;
			entry assign currentColor.blue := 0.86;
			entry assign status := SterilizationStatus::notSterilized;
		}
		
		transition inactive_to_exposing
			first inactive
			accept steamConditions : SteamConditions
			then exposing;
		
		state exposing {
			entry assign exposureStartTime := 0.0[SI::s];
		}
		
		transition exposing_to_activated
			first exposing
			if steamConditions.temperature >= activationTemperature and
			   steamConditions.pressure >= activationPressure and
			   steamConditions.duration >= requiredExposure
			then activated;
		
		state activated {
			entry assign currentColor.red := 0.0;
			entry assign currentColor.green := 1.0;
			entry assign currentColor.blue := 0.0;
			entry assign status := SterilizationStatus::sterilized;
		}
		
		transition activated_to_complete
			first activated
			then complete;
		
		state complete;
	}
	
	part autoclaveTapeSystem {
		part controller : ControlSystem;
		part generator : SteamGenerator {
			attribute setpointTemperature = 394.15[SI::K];
			attribute setpointPressure = 205000.0[SI::Pa];
		}
		part chamber : AutoclaveChamber {
			attribute chamberVolume = 0.5[SI::m^3];
			attribute currentTemperature = 293.15[SI::K];
			attribute currentPressure = 101325.0[SI::Pa];
		}
		
		connection steamFlow connect generator.steamOutput to chamber.steamInput;
		connection tapeExposure connect chamber.steamInput to chamber.loadedTape.indicator.exposurePort;
		
		perform action sterilizationProcess[*] ordered references controller.manageCycle;
	}
	
	requirement def SterilizationIndicatorRequirement {
		doc /* The autoclave tape shall provide visual confirmation of sterilization exposure. */
		
		subject tape : AutoclaveTape;
		
		require constraint colorChangeRequirement {
			doc /* The indicator shall change from beige to green when exposed to proper sterilization conditions. */
		}
		
		require constraint temperatureThreshold {
			doc /* The indicator shall activate at steam temperature of 121°C (394.15 K). */
		}
		
		require constraint pressureThreshold {
			doc /* The indicator shall activate at steam pressure of 15 psi (205 kPa). */
		}
		
		require constraint exposureTime {
			doc /* The indicator shall require minimum 15 minutes exposure to activate. */
		}
	}
	
	requirement def AdhesivePerformanceRequirement {
		doc /* The adhesive backing shall maintain bond integrity throughout sterilization. */
		
		subject adhesive : AdhesiveBacking;
		
		require constraint bondStrengthRequirement {
			doc /* The adhesive shall maintain minimum bond strength of 100 kPa. */
		}
		
		require constraint temperatureResistance {
			doc /* The adhesive shall withstand temperatures up to 150°C (423.15 K). */
		}
	}
	
	requirement <'REQ-001'> autoclaveTapeSystemRequirement : SterilizationIndicatorRequirement {
		subject autoclaveTapeSystem.chamber.loadedTape;
		
		assume constraint properSteamConditions {
			doc /* Steam generator provides saturated steam at specified conditions. */
		}
		
		require constraint visualConfirmation {
			doc /* Tape indicator provides clear visual evidence of sterilization completion. */
		}
	}
	
	requirement <'REQ-002'> adhesiveRequirement : AdhesivePerformanceRequirement {
		subject autoclaveTapeSystem.chamber.loadedTape.adhesive;
		
		require constraint maintainBond {
			doc /* Adhesive maintains secure attachment during entire sterilization cycle. */
		}
	}
	
	occurrence def SterilizationCycleInteraction {
		ref part system :>> autoclaveTapeSystem;
		
		message startCycleCommand of SterilizationCommand
			from system.controller.controlPort;
		
		then message steamGeneration of SteamConditions
			from system.generator.steamOutput to system.chamber.steamInput;
		
		then message tapeExposureEvent of SteamConditions
			from system.chamber.steamInput to system.chamber.loadedTape.indicator.exposurePort;
		
		then message indicatorResponse of system.chamber.loadedTape.indicator.status
			from system.chamber.loadedTape.indicator.indicatorPort;
		
		then message cycleCompletion of CompletionSignal
			from system.controller.controlPort;
	}
}
