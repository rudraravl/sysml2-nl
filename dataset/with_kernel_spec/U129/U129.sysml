package tDCS_System {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	value def CurrentIntensity :> Real { unit 'mA'; }
	value def ElectricalResistance :> Real { unit 'kOhm'; }
	value def Duration :> Real { unit 'min'; }
	value def RampTime :> Real { unit 's'; }
	
	item def StimulationParameters {
		attribute targetCurrent : CurrentIntensity;
		attribute sessionDuration : Duration;
		attribute rampUpTime : RampTime;
		attribute rampDownTime : RampTime;
	}
	
	item def CurrentFlow {
		attribute intensity : CurrentIntensity;
	}
	
	item def ImpedanceReading {
		attribute resistance : ElectricalResistance;
	}
	
	item def SafetyStatus {
		attribute isSafe : Boolean;
		attribute alertMessage : String;
	}
	
	part def PowerSupply {
		port powerOut {
			out power : Boolean;
		}
	}
	
	part def UserInterface {
		port configIn {
			in parameters : StimulationParameters;
		}
		port configOut {
			out parameters : StimulationParameters;
		}
		port alertIn {
			in alert : SafetyStatus;
		}
	}
	
	part def Electrode {
		port currentIn {
			in current : CurrentFlow;
		}
		port skinContact {
			in impedance : ImpedanceReading;
		}
		port impedanceOut {
			out impedance : ImpedanceReading;
		}
	}
	
	state machine def GeneratorBehavior {
		state Idle;
		state RampUp;
		state Maintain;
		state RampDown;
		state Shutdown;
		
		transition from Idle to RampUp;
		transition from RampUp to Maintain;
		transition from Maintain to RampDown;
		transition from RampDown to Idle;
		transition from any to Shutdown;
	}
	
	part def CurrentGenerator {
		port configIn {
			in parameters : StimulationParameters;
		}
		port powerIn {
			in power : Boolean;
		}
		port currentOut {
			out current : CurrentFlow;
		}
		port statusIn {
			in status : SafetyStatus;
		}
		
		state machine generatorBehavior : GeneratorBehavior;
	}
	
	part def ImpedanceMonitor {
		port impedanceIn {
			in impedance : ImpedanceReading;
		}
		port impedanceOut {
			out impedance : ImpedanceReading;
		}
	}
	
	part def SafetyController {
		port currentIn {
			in current : CurrentFlow;
		}
		port impedanceIn {
			in impedance : ImpedanceReading;
		}
		port statusOut {
			out status : SafetyStatus;
		}
		
		action monitorSafety {
			in current : CurrentFlow;
			in impedance : ImpedanceReading;
			out status : SafetyStatus;
		}
	}
	
	part def Patient {
		port scalpContact {
			in current : CurrentFlow;
			out impedance : ImpedanceReading;
		}
	}
	
	part def Clinician {
		port uiInteraction {
			out parameters : StimulationParameters;
			in alert : SafetyStatus;
		}
	}
	
	constraint def MaxCurrentConstraint {
		in measured : CurrentIntensity;
		in limit : CurrentIntensity;
		measured <= limit;
	}
	
	constraint def ImpedanceRangeConstraint {
		in measured : ElectricalResistance;
		in minLimit : ElectricalResistance;
		in maxLimit : ElectricalResistance;
		measured >= minLimit and measured <= maxLimit;
	}
	
	requirement def SafetyRequirements {
		doc /* The system shall ensure patient safety by monitoring current, impedance, and duration, and initiating emergency shutdown when limits are exceeded. */
	}
	
	requirement def PerformanceRequirements {
		doc /* The system shall deliver a controlled electrical current following a therapeutic profile with ramp-up, steady-state, and ramp-down phases. */
	}
	
	part tDCSDevice {
		part powerSupply : PowerSupply;
		part userInterface : UserInterface;
		part currentGenerator : CurrentGenerator;
		part impedanceMonitor : ImpedanceMonitor;
		part safetyController : SafetyController;
		part anode : Electrode;
		part cathode : Electrode;
		ref patient : Patient;
		ref clinician : Clinician;
		
		flow powerFlow of Boolean from powerSupply.powerOut.power to currentGenerator.powerIn.power;
		flow paramFlowUI of StimulationParameters from userInterface.configOut.parameters to currentGenerator.configIn.parameters;
		flow paramFlowClin of StimulationParameters from clinician.uiInteraction.parameters to userInterface.configIn.parameters;
		
		flow currentFlowAnode of CurrentFlow from currentGenerator.currentOut.current to anode.currentIn.current;
		flow currentFlowCathode of CurrentFlow from currentGenerator.currentOut.current to cathode.currentIn.current;
		flow currentToPatientAnode of CurrentFlow from anode.currentIn.current to patient.scalpContact.current;
		flow currentToPatientCathode of CurrentFlow from cathode.currentIn.current to patient.scalpContact.current;
		
		flow impedanceFromPatientAnode of ImpedanceReading from patient.scalpContact.impedance to anode.skinContact.impedance;
		flow impedanceFromPatientCathode of ImpedanceReading from patient.scalpContact.impedance to cathode.skinContact.impedance;
		flow impedanceFlowAnode of ImpedanceReading from anode.impedanceOut.impedance to impedanceMonitor.impedanceIn.impedance;
		flow impedanceFlowCathode of ImpedanceReading from cathode.impedanceOut.impedance to impedanceMonitor.impedanceIn.impedance;
		flow monitoredImpedance of ImpedanceReading from impedanceMonitor.impedanceOut.impedance to safetyController.impedanceIn.impedance;
		
		flow currentToSafety of CurrentFlow from currentGenerator.currentOut.current to safetyController.currentIn.current;
		flow safetyStatusToGen of SafetyStatus from safetyController.statusOut.status to currentGenerator.statusIn.status;
		flow safetyAlertToUI of SafetyStatus from safetyController.statusOut.status to userInterface.alertIn.alert;
		flow safetyAlertToClin of SafetyStatus from safetyController.statusOut.status to clinician.uiInteraction.alert;
		
		assert constraint currentLimit : MaxCurrentConstraint {
			in measured = currentGenerator.currentOut.current.intensity;
			in limit = 2.0;
		}
		
		assert constraint impedanceRange : ImpedanceRangeConstraint {
			in measured = impedanceMonitor.impedanceOut.impedance.resistance;
			in minLimit = 1.0;
			in maxLimit = 10.0;
		}
		
		requirement safetyReq : SafetyRequirements;
		requirement perfReq : PerformanceRequirements;
	}
}
