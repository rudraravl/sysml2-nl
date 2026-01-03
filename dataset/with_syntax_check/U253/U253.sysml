package HyfrecatorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VoltageValue :> ISQ::ElectricPotentialDifferenceValue;
	attribute def CurrentValue :> ISQ::ElectricCurrentValue;
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	attribute def PowerValue :> ISQ::PowerValue;
	attribute def ResistanceValue :> ISQ::ResistanceValue;
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def TimeValue :> ISQ::TimeValue;
	
	enum def OperatingMode {
		enum standby;
		enum desiccation;
		enum fulguration;
		enum cutting;
		enum coagulation;
	}
	
	enum def SystemStatus {
		enum off;
		enum ready;
		enum active;
		enum fault;
	}
	
	item def HighFrequencySignal {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
		attribute frequency : FrequencyValue;
		attribute power : PowerValue;
	}
	
	item def TissueContact {
		attribute impedance : ResistanceValue;
		attribute temperature : TemperatureValue;
		attribute contactDetected : Boolean;
	}
	
	item def ControlCommand {
		attribute mode : OperatingMode;
		attribute powerLevel : PowerValue;
		attribute duration : TimeValue;
	}
	
	item def StatusFeedback {
		attribute systemStatus : SystemStatus;
		attribute outputPower : PowerValue;
		attribute tissueTemperature : TemperatureValue;
		attribute faultCode : Integer;
	}
	
	port def PowerInputPort {
		in item acInput : HighFrequencySignal;
	}
	
	port def RFOutputPort {
		out item rfSignal : HighFrequencySignal;
	}
	
	port def ControlInterfacePort {
		in item command : ControlCommand;
		out item feedback : StatusFeedback;
	}
	
	port def TissueInterfacePort {
		out item energy : HighFrequencySignal;
		in item contact : TissueContact;
	}
	
	part def PowerSupply {
		port acIn : PowerInputPort;
		port dcOut {
			out item dcPower : HighFrequencySignal;
		}
		
		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute efficiency : Real;
		
		perform action convertACToDC {
			in acSignal : HighFrequencySignal;
			out dcSignal : HighFrequencySignal;
			
			first start;
			then action rectifySignal {
				in ac : HighFrequencySignal = acSignal;
				out rectifiedSignal : HighFrequencySignal;
			}
			then action filterSignal {
				in signal : HighFrequencySignal = rectifySignal.rectifiedSignal;
				out filteredSignal : HighFrequencySignal;
			}
			then action regulateSignal {
				in signal : HighFrequencySignal = filterSignal.filteredSignal;
				out regulatedSignal : HighFrequencySignal;
			}
			then assign dcSignal := regulateSignal.regulatedSignal;
			then done;
		}
	}
	
	part def RFOscillator {
		port dcIn {
			in item dcPower : HighFrequencySignal;
		}
		port rfOut : RFOutputPort;
		
		attribute operatingFrequency : FrequencyValue;
		attribute maxPower : PowerValue;
		attribute waveformType : String;
		
		perform action generateRF {
			in dcInput : HighFrequencySignal;
			in targetPower : PowerValue;
			in mode : OperatingMode;
			out rfOutput : HighFrequencySignal;
			
			first start;
			then action oscillate {
				in power : PowerValue = targetPower;
				out baseSignal : HighFrequencySignal;
			}
			then action modulate {
				in signal : HighFrequencySignal = oscillate.baseSignal;
				in operatingMode : OperatingMode = mode;
				out modulated : HighFrequencySignal;
			}
			then action amplify {
				in signal : HighFrequencySignal = modulate.modulated;
				out amplified : HighFrequencySignal;
			}
			then assign rfOutput := amplify.amplified;
			then done;
		}
	}
	
	part def SafetyMonitor {
		port monitorIn {
			in item tissueData : TissueContact;
			in item outputSignal : HighFrequencySignal;
		}
		port safetyOut {
			out item shutdownCommand : Boolean;
			out item warningSignal : Boolean;
		}
		
		attribute maxTemperature : TemperatureValue;
		attribute maxCurrent : CurrentValue;
		attribute maxPower : PowerValue;
		
		perform action monitorSafety {
			in tissue : TissueContact;
			in signal : HighFrequencySignal;
			out shutdown : Boolean;
			out warning : Boolean;
			
			first start;
			then merge checkConditions;
			then action evaluateTemperature {
				in temp : TemperatureValue = tissue.temperature;
				out tempExceeded : Boolean;
			}
			then action evaluateCurrent {
				in current : CurrentValue = signal.current;
				out currentExceeded : Boolean;
			}
			then action evaluatePower {
				in power : PowerValue = signal.power;
				out powerExceeded : Boolean;
			}
			then decide;
				if evaluateTemperature.tempExceeded or evaluateCurrent.currentExceeded or evaluatePower.powerExceeded then triggerShutdown;
				else continueMonitoring;
			action triggerShutdown {
				assign shutdown := true;
				assign warning := true;
			}
			then done;
			action continueMonitoring {
				assign shutdown := false;
				assign warning := false;
			}
			then checkConditions;
		}
	}
	
	part def ControlUnit {
		port userInterface : ControlInterfacePort;
		port systemControl {
			out item controlSignal : ControlCommand;
			in item systemFeedback : StatusFeedback;
		}
		port safetyInput {
			in item safetyStatus : Boolean;
		}
		
		attribute currentMode : OperatingMode;
		attribute currentStatus : SystemStatus;
		attribute selectedPower : PowerValue;
		
		state machine operationControl {
			initial state init;
			
			state offState {
				entry action enterOff {
					assign currentStatus := SystemStatus::off;
				}
			}
			
			state readyState {
				entry action enterReady {
					assign currentStatus := SystemStatus::ready;
				}
			}
			
			state activeState {
				entry action enterActive {
					assign currentStatus := SystemStatus::active;
				}
				
				do action executeOperation {
					in command : ControlCommand;
					out control : ControlCommand;
					
					first start;
					then merge operationLoop;
					then action processCommand {
						in cmd : ControlCommand = command;
						out processedCmd : ControlCommand;
					}
					then action deliverControl {
						in cmd : ControlCommand = processCommand.processedCmd;
						out deliveredCmd : ControlCommand;
					}
					then assign control := deliverControl.deliveredCmd;
					then operationLoop;
				}
			}
			
			state faultState {
				entry action enterFault {
					assign currentStatus := SystemStatus::fault;
				}
			}
			
			transition init_to_off
				first init
				then offState;
			
			transition off_to_ready
				first offState
				accept powerOn : Boolean
				if powerOn
				then readyState;
			
			transition ready_to_active
				first readyState
				accept activationCommand : ControlCommand
				if activationCommand.mode != OperatingMode::standby
				then activeState;
			
			transition active_to_ready
				first activeState
				accept deactivationCommand : ControlCommand
				if deactivationCommand.mode == OperatingMode::standby
				then readyState;
			
			transition any_to_fault
				first readyState
				accept safetyTrigger : Boolean
				if safetyTrigger
				then faultState;
			
			transition fault_to_off
				first faultState
				accept faultCleared : Boolean
				if faultCleared
				then offState;
		}
	}
	
	part def Handpiece {
		port rfIn : RFOutputPort;
		port tissueOut : TissueInterfacePort;
		
		part electrode : Electrode;
		
		attribute insulationIntegrity : Boolean;
		attribute electrodeCondition : String;
		
		perform action deliverEnergy {
			in rfInput : HighFrequencySignal;
			out tissueEffect : TissueContact;
			
			first start;
			then action transferEnergy {
				in signal : HighFrequencySignal = rfInput;
				out transferred : HighFrequencySignal;
			}
			then action applyToTissue {
				in energy : HighFrequencySignal = transferEnergy.transferred;
				out contact : TissueContact;
			}
			then assign tissueEffect := applyToTissue.contact;
			then done;
		}
	}
	
	part def Electrode {
		attribute material : String;
		attribute geometry : String;
		attribute surfaceArea : Real;
		
		perform action conductEnergy {
			in energy : HighFrequencySignal;
			out tissueResponse : TissueContact;
		}
	}
	
	part def Hyfrecator {
		doc /* 
		A Hyfrecator is a low-power, high-frequency electrosurgical device designed 
		for superficial tissue treatment. Its primary function is to deliver controlled 
		high-frequency electrical energy through a handheld electrode to biological tissue, 
		causing localized tissue destruction through desiccation (drying) or fulguration 
		(sparking). The system converts standard electrical power into high-frequency 
		alternating current, typically operating between 100 kHz and 2 MHz, and delivers 
		this energy precisely to target tissue areas for minor surgical procedures such as 
		removing skin lesions, controlling bleeding, or destroying abnormal tissue.
		*/
		
		part powerSupply : PowerSupply;
		part rfOscillator : RFOscillator;
		part safetyMonitor : SafetyMonitor;
		part controlUnit : ControlUnit;
		part handpiece : Handpiece;
		
		port mainPower : PowerInputPort;
		port userControl : ControlInterfacePort;
		port tissueApplication : TissueInterfacePort;
		
		connection powerConnection
			connect mainPower to powerSupply.acIn;
		
		connection dcPowerConnection
			connect powerSupply.dcOut to rfOscillator.dcIn;
		
		connection rfOutputConnection
			connect rfOscillator.rfOut to handpiece.rfIn;
		
		connection tissueOutputConnection
			connect handpiece.tissueOut to tissueApplication;
		
		connection controlInputConnection
			connect userControl to controlUnit.userInterface;
		
		connection safetyMonitorConnection
			connect tissueApplication to safetyMonitor.monitorIn;
		
		connection safetyToControlConnection
			connect safetyMonitor.safetyOut to controlUnit.safetyInput;
		
		perform action performTreatment {
			doc /* 
			Primary treatment workflow: initialize system, detect tissue contact, 
			deliver controlled energy, monitor safety parameters, and complete treatment.
			*/
			
			first start;
			
			then action initializeSystem {
				out systemReady : Boolean;
			}
			
			then action waitForContact {
				in ready : Boolean = initializeSystem.systemReady;
				out contactEstablished : TissueContact;
			}
			
			then decide;
				if waitForContact.contactEstablished.contactDetected then deliverTreatment;
				else waitForContact;
			
			action deliverTreatment {
				in contact : TissueContact = waitForContact.contactEstablished;
				
				first action configureParameters {
					in mode : OperatingMode;
					out powerSetting : PowerValue;
					out frequencySetting : FrequencyValue;
				}
				
				then action generateHighFrequency {
					in power : PowerValue = configureParameters.powerSetting;
					in frequency : FrequencyValue = configureParameters.frequencySetting;
					out rfEnergy : HighFrequencySignal;
				}
				
				then merge treatmentLoop;
				
				then action applyEnergy {
					in energy : HighFrequencySignal = generateHighFrequency.rfEnergy;
					in tissueContact : TissueContact = contact;
					out tissueResponse : TissueContact;
				}
				
				then action monitorConditions {
					in response : TissueContact = applyEnergy.tissueResponse;
					out safetyOk : Boolean;
					out treatmentComplete : Boolean;
				}
				
				then decide;
					if monitorConditions.safetyOk and not monitorConditions.treatmentComplete then treatmentLoop;
					if not monitorConditions.safetyOk then emergencyStop;
					if monitorConditions.treatmentComplete then finalizeTreatment;
				
				action emergencyStop {
					in reason : Boolean = monitorConditions.safetyOk;
				}
				then done;
				
				action finalizeTreatment;
				then done;
			}
			
			then done;
		}
	}
	
	requirement def SafetyRequirement {
		doc /* Safety requirements for electrosurgical operation */
		subject device : Hyfrecator;
	}
	
	requirement def PerformanceRequirement {
		doc /* Performance requirements for tissue treatment */
		subject device : Hyfrecator;
	}
	
	requirement def OperationalRequirement {
		doc /* Operational requirements for clinical use */
		subject device : Hyfrecator;
	}
	
	requirement <'REQ-001'> tissueContactDetection : SafetyRequirement {
		doc /* The system shall detect tissue contact before delivering RF energy to prevent accidental activation. */
		subject hyfrecatorDevice : Hyfrecator;
		
		require constraint {
			hyfrecatorDevice.handpiece.tissueOut.contact.contactDetected == true
		}
	}
	
	requirement <'REQ-002'> powerLimitation : SafetyRequirement {
		doc /* The system shall limit maximum output power to 50 watts to ensure safe superficial tissue treatment. */
		subject hyfrecatorDevice : Hyfrecator;
		
		require constraint {
			hyfrecatorDevice.rfOscillator.maxPower <= 50.0
		}
	}
	
	requirement <'REQ-003'> operatingFrequencyRange : PerformanceRequirement {
		doc /* The system shall operate within 100 kHz to 2 MHz frequency range for effective tissue desiccation and fulguration. */
		subject hyfrecatorDevice : Hyfrecator;
		
		require constraint {
			hyfrecatorDevice.rfOscillator.operatingFrequency >= 100000.0 and
			hyfrecatorDevice.rfOscillator.operatingFrequency <= 2000000.0
		}
	}
	
	requirement <'REQ-004'> emergencyShutdown : SafetyRequirement {
		doc /* The system shall automatically shut down within 100 milliseconds upon detecting unsafe tissue temperature or current levels. */
		subject hyfrecatorDevice : Hyfrecator;
		
		require constraint {
			hyfrecatorDevice.safetyMonitor.monitorSafety.shutdown == true
		}
	}
	
	requirement <'REQ-005'> multipleOperatingModes : OperationalRequirement {
		doc /* The system shall support multiple operating modes including desiccation, fulguration, cutting, and coagulation. */
		subject hyfrecatorDevice : Hyfrecator;
		
		require constraint {
			hyfrecatorDevice.controlUnit.currentMode == OperatingMode::desiccation or
			hyfrecatorDevice.controlUnit.currentMode == OperatingMode::fulguration or
			hyfrecatorDevice.controlUnit.currentMode == OperatingMode::cutting or
			hyfrecatorDevice.controlUnit.currentMode == OperatingMode::coagulation
		}
	}
	
	requirement <'REQ-006'> temperatureMonitoring : SafetyRequirement {
		doc /* The system shall continuously monitor tissue temperature and prevent excessive heating beyond 100 degrees Celsius. */
		subject hyfrecatorDevice : Hyfrecator;
		
		require constraint {
			hyfrecatorDevice.safetyMonitor.maxTemperature <= 373.15
		}
	}
	
	requirement primaryMission {
		doc /* 
		Primary mission: Deliver controlled high-frequency electrical energy to biological 
		tissue for therapeutic destruction through desiccation or fulguration in minor 
		surgical procedures, while maintaining patient safety and treatment precision.
		*/
		
		assume constraint clinicalEnvironment {
			doc /* System operates in controlled clinical environment with trained medical personnel. */
		}
		
		assume constraint properMaintenance {
			doc /* Electrodes and handpiece are properly maintained and sterilized. */
		}
		
		require tissueContactDetection;
		require powerLimitation;
		require operatingFrequencyRange;
		require emergencyShutdown;
		require multipleOperatingModes;
		require temperatureMonitoring;
	}
	
	part hyfrecatorDevice : Hyfrecator {
		satisfy primaryMission by self;
	}
}
