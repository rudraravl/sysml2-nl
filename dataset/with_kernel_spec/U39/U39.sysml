package 'Artificial Urinary Sphincter' {
	private import ScalarValues::*;
	
	item def SalineFluid;
	item def ActivationSignal;
	item def InflateCommand;
	item def DeflateCommand;
	item def PressureReading;
	
	value def PressureValue {
		unit mmHg;
	}
	
	value def DurationValue {
		unit s;
	}
	
	part def InflatableCuff {
		port salineInPort { in saline : SalineFluid; }
		port salineOutPort { out saline : SalineFluid; }
		attribute cuffPressure : PressureValue;
	}
	
	part def FluidReservoir {
		port salineOutPort { out saline : SalineFluid; }
		port salineInPort { in saline : SalineFluid; }
	}
	
	part def ControlPump {
		port salineInPort { in saline : SalineFluid; }
		port salineOutPort { out saline : SalineFluid; }
		port commandPort { in command : InflateCommand; }
	}
	
	part def ReleaseValve {
		port salineInPort { in saline : SalineFluid; }
		port salineOutPort { out saline : SalineFluid; }
		port commandPort { in command : DeflateCommand; }
	}
	
	part def PressureSensor {
		port pressurePort { out reading : PressureReading; }
		attribute sensedPressure : PressureValue;
	}
	
	part def ActivationButton {
		port signalPort { out signal : ActivationSignal; }
	}
	
	part def ControlModule {
		port activationPort { in signal : ActivationSignal; }
		port pressurePort { in reading : PressureReading; }
		port pumpCommandPort { out pumpCommand : InflateCommand; }
		port valveCommandPort { out valveCommand : DeflateCommand; }
	}
	
	part def Patient {
		port buttonPort { out signal : ActivationSignal; }
	}
	
	state def AUSStates {
		in aus : AUS;
		entry; then inflated;
		state inflated {
			do action maintainContinence { /* Continence maintained */ }
		}
		accept ActivationSignal
			do send new DeflateCommand() to aus.valve
			then deflated;
		state deflated {
			do action allowVoiding { /* Voiding allowed */ }
		}
		after 120 [s]
			do send new InflateCommand() to aus.pump
			then inflated;
	}
	
	part def AUS {
		part cuff : InflatableCuff;
		part reservoir : FluidReservoir;
		part pump : ControlPump;
		part valve : ReleaseValve;
		part controlModule : ControlModule;
		part pressureSensor : PressureSensor;
		part activationButton : ActivationButton;
		part patient : Patient;
		
		flow patientToButton of ActivationSignal from patient.buttonPort.signal to activationButton.signalPort.signal;
		
		flow salineToPump of SalineFluid from reservoir.salineOutPort.saline to pump.salineInPort.saline;
		flow salineToCuff of SalineFluid from pump.salineOutPort.saline to cuff.salineInPort.saline;
		flow salineToValve of SalineFluid from cuff.salineOutPort.saline to valve.salineInPort.saline;
		flow salineToReservoir of SalineFluid from valve.salineOutPort.saline to reservoir.salineInPort.saline;
		
		flow activationFlow of ActivationSignal from activationButton.signalPort.signal to controlModule.activationPort.signal;
		flow pressureFlow of PressureReading from pressureSensor.pressurePort.reading to controlModule.pressurePort.reading;
		flow pumpCommandFlow of InflateCommand from controlModule.pumpCommandPort.pumpCommand to pump.commandPort.command;
		flow valveCommandFlow of DeflateCommand from controlModule.valveCommandPort.valveCommand to valve.commandPort.command;
		
		exhibit ausStates : AUSStates {
			in aus = this;
		}
		
		satisfy continenceReq by this;
		satisfy voidingReq by this;
	}
	
	requirement def ContinenceRequirement {
		subject aus : AUS;
		objective {
			doc "The AUS shall maintain continence when the cuff is inflated."
		}
	}
	
	requirement def VoidingRequirement {
		subject aus : AUS;
		objective {
			doc "The AUS shall allow voiding when the activation button is pressed and automatically reinflate after 120 seconds."
		}
	}
	
	requirement continenceReq : ContinenceRequirement;
	requirement voidingReq : VoidingRequirement;
}
