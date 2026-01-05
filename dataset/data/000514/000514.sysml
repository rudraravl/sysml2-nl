package 'TranscranialDirectCurrentStimulationSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def StimulationMode {
		attribute anodal : Boolean;
		attribute cathodal : Boolean;
		attribute bilateral : Boolean;
	}
	
	attribute def SafetyStatus {
		attribute withinLimits : Boolean;
		attribute impedanceNormal : Boolean;
		attribute temperatureNormal : Boolean;
	}
	
	item def ElectricalCurrent {
		attribute magnitude : ISQ::ElectricCurrentValue;
		attribute polarity : String;
	}
	
	item def StimulationParameters {
		attribute currentIntensity : ISQ::ElectricCurrentValue;
		attribute duration : ISQ::DurationValue;
		attribute rampUpTime : ISQ::DurationValue;
		attribute rampDownTime : ISQ::DurationValue;
		attribute mode : StimulationMode;
	}
	
	item def ImpedanceReading {
		attribute resistance : ISQ::ResistanceValue;
		attribute timestamp : ISQ::DurationValue;
	}
	
	item def SafetyAlert {
		attribute alertType : String;
		attribute severity : Integer;
		attribute alertMessage : String;
	}
	
	port def PowerPort {
		out item voltage : ISQ::ElectricPotentialValue;
		out item current : ISQ::ElectricCurrentValue;
	}
	
	port def ControlPort {
		in item parameters : StimulationParameters;
		out item status : SafetyStatus;
	}
	
	port def ElectrodePort {
		out item stimulusCurrent : ElectricalCurrent;
		in item impedance : ImpedanceReading;
	}
	
	part def PowerSupply {
		port powerOut : PowerPort;
		
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		
		action regulatePower {
			in requiredCurrent : ISQ::ElectricCurrentValue;
			out suppliedVoltage : ISQ::ElectricPotentialValue;
			out suppliedCurrent : ISQ::ElectricCurrentValue;
		}
	}
	
	part def CurrentGenerator {
		port powerIn : ~PowerPort;
		port controlIn : ~ControlPort;
		port electrodeOut : ElectrodePort;
		
		attribute setpointCurrent : ISQ::ElectricCurrentValue;
		attribute actualCurrent : ISQ::ElectricCurrentValue;
		
		action generateCurrent {
			in parameters : StimulationParameters;
			in powerVoltage : ISQ::ElectricPotentialValue;
			out outputCurrent : ElectricalCurrent;
			
			first start;
			then action rampUp {
				in rampTime : ISQ::DurationValue = parameters.rampUpTime;
				in targetCurrent : ISQ::ElectricCurrentValue = parameters.currentIntensity;
			}
			then action maintainStimulation {
				in steadyCurrent : ISQ::ElectricCurrentValue = parameters.currentIntensity;
				in stimDuration : ISQ::DurationValue = parameters.duration;
			}
			then action rampDown {
				in rampTime : ISQ::DurationValue = parameters.rampDownTime;
			}
			then done;
		}
	}
	
	part def Electrode {
		port electrodeConnection : ~ElectrodePort;
		
		attribute area : ISQ::AreaValue;
		attribute position : String;
		attribute contactImpedance : ISQ::ResistanceValue;
		
		action deliverStimulation {
			in current : ElectricalCurrent;
			out impedanceReading : ImpedanceReading;
		}
	}
	
	part def ImpedanceMonitor {
		attribute currentImpedance : ISQ::ResistanceValue;
		attribute impedanceThresholdLow : ISQ::ResistanceValue;
		attribute impedanceThresholdHigh : ISQ::ResistanceValue;
		
		action measureImpedance {
			in electrodeReading : ImpedanceReading;
			out impedanceValue : ISQ::ResistanceValue;
			out isNormal : Boolean;
		}
	}
	
	part def SafetyController {
		port controlOut : ControlPort;
		
		attribute maxCurrentLimit : ISQ::ElectricCurrentValue;
		attribute maxDuration : ISQ::DurationValue;
		attribute emergencyShutdownActive : Boolean;
		
		state def SafetyStateMachine {
			entry; then Monitoring;
			
			state Monitoring {
				entry action checkSafety;
			}
			accept when emergencyShutdownActive
				then AlertState;
			
			state AlertState {
				entry action raiseAlert;
			}
			then Shutdown;
			
			state Shutdown {
				entry action initiateShutdown;
			}
		}
		
		action monitorSafety {
			in currentLevel : ISQ::ElectricCurrentValue;
			in impedanceStatus : Boolean;
			in elapsedTime : ISQ::DurationValue;
			out safetyStatus : SafetyStatus;
			out alert : SafetyAlert;
			
			first start;
			then merge checkConditions;
			then decide;
				if currentLevel > maxCurrentLimit then raiseAlert;
				if not impedanceStatus then raiseAlert;
				if elapsedTime > maxDuration then initiateShutdown;
				if safetyStatus.withinLimits then checkConditions;
			
			action raiseAlert {
				out emergencyAlert : SafetyAlert;
			}
			then initiateShutdown;
			
			action initiateShutdown;
			then done;
		}
	}
	
	part def UserInterface {
		attribute selectedParameters : StimulationParameters;
		attribute displayedStatus : SafetyStatus;
		
		action configureSession {
			out sessionParameters : StimulationParameters;
		}
		
		action displayStatus {
			in systemStatus : SafetyStatus;
			in currentReading : ISQ::ElectricCurrentValue;
		}
	}
	
	part def tDCSDevice {
		part powerSupply : PowerSupply;
		part currentGenerator : CurrentGenerator;
		part anodeElectrode : Electrode {
			attribute :>> position = "Anode";
		}
		part cathodeElectrode : Electrode {
			attribute :>> position = "Cathode";
		}
		part impedanceMonitor : ImpedanceMonitor;
		part safetyController : SafetyController;
		part userInterface : UserInterface;
		
		connect powerSupply.powerOut to currentGenerator.powerIn;
		connect safetyController.controlOut to currentGenerator.controlIn;
		connect currentGenerator.electrodeOut to anodeElectrode.electrodeConnection;
		
		perform action operateTDCS {
			first start;
			then action initializeSystem {
				action performSelfTest;
				then action checkElectrodeContact;
			}
			then action configureStimulation : userInterface.configureSession {
				out stimulationParams : StimulationParameters;
			}
			then action validateParameters {
				in params : StimulationParameters = configureStimulation.stimulationParams;
				out isValid : Boolean;
			}
			then decide;
				if validateParameters.isValid then deliverTherapy;
				if not validateParameters.isValid then reportError;
			
			action deliverTherapy {
				action monitorContinuously : safetyController.monitorSafety;
				action generateStimulus : currentGenerator.generateCurrent;
				action measureImpedanceContinuously : impedanceMonitor.measureImpedance;
				action updateDisplay : userInterface.displayStatus;
			}
			then action completeSession;
			then done;
			
			action reportError;
			then done;
		}
	}
	
	part patient;
	
	part tDCSSystem : tDCSDevice {
		perform action therapeuticStimulation references operateTDCS;
	}
	
	requirement def SafetyRequirement {
		doc /* The tDCS system shall limit current to safe therapeutic levels. */
		
		subject system : tDCSDevice;
		
		require constraint {
			system.currentGenerator.actualCurrent <= 2.0
		}
	}
	
	requirement def ImpedanceRequirement {
		doc /* The system shall monitor electrode impedance continuously. */
		
		subject monitor : ImpedanceMonitor;
		
		require constraint {
			monitor.currentImpedance >= monitor.impedanceThresholdLow and
			monitor.currentImpedance <= monitor.impedanceThresholdHigh
		}
	}
	
	requirement def DurationRequirement {
		doc /* Stimulation duration shall not exceed prescribed therapeutic limits. */
		
		subject controller : SafetyController;
		
		require constraint {
			controller.maxDuration <= 1800.0
		}
	}
	
	requirement therapeuticStimulationRequirement : SafetyRequirement {
		subject tDCSSystem;
		
		doc /* 
		The transcranial direct-current stimulation system shall deliver controlled,
		low-intensity electrical current through scalp electrodes to modulate neuronal
		activity in targeted brain regions, while continuously monitoring safety parameters
		and maintaining current within therapeutic ranges of 1-2 mA for durations up to 30 minutes.
		*/
	}
}
