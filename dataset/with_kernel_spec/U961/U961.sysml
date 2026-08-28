package 'HighPrecisionLinearActuator' {
	private import ScalarValues::*;
	
	unit mm;
	unit N;
	unit Nm;
	unit V;
	unit A;
	
	value def Position :> Real { unit mm; }
	value def Force :> Real { unit N; }
	value def Torque :> Real { unit Nm; }
	value def Voltage :> Real { unit V; }
	value def Current :> Real { unit A; }
	
	item def CommandSignal {
		attribute targetPosition : Position;
		attribute targetForce : Force;
	}
	item def ControlSignal {
		attribute voltage : Voltage;
		attribute current : Current;
	}
	item def ElectricalPower {
		attribute voltage : Voltage;
		attribute current : Current;
	}
	item def RotationalMotion {
		attribute torque : Torque;
		attribute speed : Real;
	}
	item def LinearOutput {
		attribute position : Position;
		attribute force : Force;
	}
	item def PositionFeedback {
		attribute actualPosition : Position;
	}
	item def ForceFeedback {
		attribute actualForce : Force;
	}
	
	part def ControlProcessor {
		port commandPort {
			in cmd : CommandSignal;
		}
		port posFeedbackPort {
			in posFb : PositionFeedback;
		}
		port forceFeedbackPort {
			in forceFb : ForceFeedback;
		}
		port controlOutPort {
			out ctrl : ControlSignal;
		}
	}
	
	part def PowerAmplifier {
		port controlInPort {
			in ctrl : ControlSignal;
		}
		port powerInPort {
			in pwr : ElectricalPower;
		}
		port motorOutPort {
			out motorPwr : ElectricalPower;
		}
	}
	
	part def ElectricMotor {
		port powerInPort {
			in pwr : ElectricalPower;
		}
		port mechOutPort {
			out rot : RotationalMotion;
		}
	}
	
	part def TransmissionMechanism {
		port rotInPort {
			in rot : RotationalMotion;
		}
		port linOutPort {
			out lin : LinearOutput;
		}
	}
	
	part def PositionSensor {
		port mechInPort {
			in lin : LinearOutput;
		}
		port dataOutPort {
			out posFb : PositionFeedback;
		}
	}
	
	part def ForceSensor {
		port mechInPort {
			in lin : LinearOutput;
		}
		port dataOutPort {
			out forceFb : ForceFeedback;
		}
	}
	
	state def ActuatorStates {
		state Initializing;
		state Ready;
		state Active;
		state Holding;
		state Fault;
		
		transition from Initializing to Ready;
		transition from Ready to Active;
		transition from Active to Holding;
		transition from Holding to Active;
		transition from Ready to Fault;
		transition from Active to Fault;
		transition from Holding to Fault;
		transition from Fault to Initializing;
	}
	
	part def LinearActuator {
		port extCmdPort {
			in cmd : CommandSignal;
		}
		port extPwrPort {
			in pwr : ElectricalPower;
		}
		port extLinOutPort {
			out lin : LinearOutput;
		}
		
		part ctrlProc : ControlProcessor;
		part pwrAmp : PowerAmplifier;
		part motor : ElectricMotor;
		part trans : TransmissionMechanism;
		part posSensor : PositionSensor;
		part forceSensor : ForceSensor;
		
		bind extCmdPort = ctrlProc.commandPort;
		bind extPwrPort = pwrAmp.powerInPort;
		bind trans.linOutPort = extLinOutPort;
		
		flow ctrlFlow of ControlSignal 
			from ctrlProc.controlOutPort.ctrl to pwrAmp.controlInPort.ctrl;
		flow motorPwrFlow of ElectricalPower 
			from pwrAmp.motorOutPort.motorPwr to motor.powerInPort.pwr;
		flow rotFlow of RotationalMotion 
			from motor.mechOutPort.rot to trans.rotInPort.rot;
		flow linPosTap of LinearOutput 
			from trans.linOutPort.lin to posSensor.mechInPort.lin;
		flow linForceTap of LinearOutput 
			from trans.linOutPort.lin to forceSensor.mechInPort.lin;
		flow posFbFlow of PositionFeedback 
			from posSensor.dataOutPort.posFb to ctrlProc.posFeedbackPort.posFb;
		flow forceFbFlow of ForceFeedback 
			from forceSensor.dataOutPort.forceFb to ctrlProc.forceFeedbackPort.forceFb;
		
		exhibit ActuatorStates;
	}
	
	requirement MaxForceRequirement {
		doc /* The actuator shall deliver up to 8000 N of force. */
		subject actuator : LinearActuator;
		attribute maxForce : Force = 8000;
	}
	
	requirement TravelRangeRequirement {
		doc /* The actuator shall operate over a 200 mm range. */
		subject actuator : LinearActuator;
		attribute strokeRange : Position = 200;
	}
	
	requirement AccuracyRequirement {
		doc /* The actuator shall maintain a positioning accuracy of 0.05 mm. */
		subject actuator : LinearActuator;
		attribute positioningAccuracy : Position = 0.05;
	}
	
	part actuatorInstance : LinearActuator {
		satisfy MaxForceRequirement;
		satisfy TravelRangeRequirement;
		satisfy AccuracyRequirement;
	}
}
