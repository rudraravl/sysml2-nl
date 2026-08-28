package 'MHD Drive System' {
	private import ScalarValues::*;

	unit def Kelvin;
	unit def MeterPerSecond;
	unit def Ampere;
	unit def Tesla;
	unit def Newton;

	value def TemperatureK :> Real;
	value def VelocityMps :> Real;
	value def CurrentA :> Real;
	value def MagneticFluxDensityT :> Real;
	value def ThrustForceN :> Real;

	item def Seawater;
	item def Coolant;
	item def ThrustCommand;
	item def SensorFeedback;

	port def SeawaterInPort {
		in item seawater : Seawater;
	}
	port def SeawaterOutPort {
		out item seawater : Seawater;
		attribute velocity : VelocityMps;
	}
	port def CoolantPort {
		out item coolantOut : Coolant;
		in item coolantIn : Coolant;
		attribute temperature : TemperatureK;
	}
	port def ElectricalPowerPort {
		out item current : CurrentA;
	}
	port def ControlPort {
		in item command : ThrustCommand;
	}
	port def FeedbackPort {
		out item feedback : SensorFeedback;
	}

	part def SuperconductingMagnet {
		port coolantPort : ~CoolantPort;
		port powerPort : ~ElectricalPowerPort;
		attribute magneticField : MagneticFluxDensityT;
	}

	part def ElectrodeAssembly {
		part anode;
		part cathode;
		port powerPort : ~ElectricalPowerPort;
	}

	part def CryogenicCoolingSystem {
		port coolantPort : CoolantPort;
	}

	part def PowerSupply {
		port magnetPowerPort : ElectricalPowerPort;
		port electrodePowerPort : ElectricalPowerPort;
		port controlPort : ControlPort;
	}

	part def FlowSensor {
		port feedbackPort : FeedbackPort;
	}

	part def ThrustSensor {
		port feedbackPort : FeedbackPort;
	}

	part def ThrustChannel {
		port seawaterIn : SeawaterInPort;
		port seawaterOut : SeawaterOutPort;
		part leftMagnet : SuperconductingMagnet;
		part rightMagnet : SuperconductingMagnet;
		part electrodes : ElectrodeAssembly;
		part flowSensor : FlowSensor;
		part thrustSensor : ThrustSensor;
	}

	part def ControlUnit {
		port commandPort : ControlPort;
		port powerSupplyControlPort : ~ControlPort;
		port flowFeedbackPort : ~FeedbackPort;
		port thrustFeedbackPort : ~FeedbackPort;
	}

	action def coolMagnets;
	action def energizeMagnets;
	action def applyThrust;
	action def monitorSensors;
	action def rampDownPower;
	action def warmUpMagnets;

	state def MHDStateMachine {
		state initializing {
			entry action coolMagnets;
			entry action energizeMagnets;
		}
		state operational {
			entry action applyThrust;
			entry action monitorSensors;
		}
		state shutdown {
			entry action rampDownPower;
			entry action warmUpMagnets;
		}

		transition from initializing to operational;
		transition from operational to shutdown;
		transition from shutdown to initializing;
	}

	part def MHDDrive {
		port commandPort : ControlPort;

		part channel : ThrustChannel;
		part coolingSystem : CryogenicCoolingSystem;
		part powerSupply : PowerSupply;
		part controlUnit : ControlUnit;

		connect commandPort to controlUnit.commandPort;

		connect coolingSystem.coolantPort to channel.leftMagnet.coolantPort;
		connect coolingSystem.coolantPort to channel.rightMagnet.coolantPort;

		connect powerSupply.magnetPowerPort to channel.leftMagnet.powerPort;
		connect powerSupply.magnetPowerPort to channel.rightMagnet.powerPort;
		connect powerSupply.electrodePowerPort to channel.electrodes.powerPort;

		connect controlUnit.powerSupplyControlPort to powerSupply.controlPort;
		connect channel.flowSensor.feedbackPort to controlUnit.flowFeedbackPort;
		connect channel.thrustSensor.feedbackPort to controlUnit.thrustFeedbackPort;

		state mhdStateMachine : MHDStateMachine;
	}

	requirement def PropulsionRequirement {
		subject drive : MHDDrive;
		doc "Thrust shall be generated via Lorentz force from the interaction of electric current and magnetic field in seawater.";
		constraint { drive.channel.seawaterOut.velocity > 0 }
	}

	requirement def CoolingRequirement {
		subject coolingSystem : CryogenicCoolingSystem;
		doc "The superconducting magnets shall be maintained at approximately 4 Kelvin.";
		constraint { coolingSystem.coolantPort.temperature <= 4.0 }
	}

	requirement def SilentOperationRequirement {
		subject drive : MHDDrive;
		doc "The propulsion system shall operate with no moving parts in the propulsion stream to ensure silent operation.";
	}
}
