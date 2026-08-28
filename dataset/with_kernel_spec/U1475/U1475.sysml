package ElectricPropellerPropulsionSystem {
	doc /* This model describes an electrically-powered propeller propulsion system for a large drone, airboat, or small electric aircraft. Its purpose is to convert electrical energy into forward thrust. */
	private import ISQ::*;
	private import ScalarValues::*;
	private import SI::*;

	package ValueTypes {
		attribute def ElectricalPower :> ISQ::PowerValue;
		attribute def ControlSignal :> ScalarValues::Real;
		attribute def Torque :> ISQ::TorqueValue;
		attribute def AngularVelocity :> ISQ::AngularVelocityValue;
		attribute def Thrust :> ISQ::ForceValue;
		attribute def Diameter :> ISQ::LengthValue;
		attribute def BladeLength :> ISQ::LengthValue;
		attribute def BladeStress :> ISQ::PressureValue;
		attribute def YieldStrength :> ISQ::PressureValue;
		attribute def StartSignal;
		attribute def StopSignal;
	}

	package PortDefinitions {
		private import ValueTypes::*;
		port def ElectricalPowerPort {
			in power : ElectricalPower;
		}
		port def ControlSignalPort {
			in signal : ControlSignal;
		}
		port def MechanicalPowerInPort {
			in torque : Torque;
			in speed : AngularVelocity;
		}
		port def MechanicalPowerOutPort {
			out torque : Torque;
			out speed : AngularVelocity;
		}
		port def ThrustPort {
			out thrust : Thrust;
		}
	}

	package ActionDefinitions {
		private import ValueTypes::*;

		action def 'Convert Electrical to Mechanical' {
			in power : ElectricalPower;
			in signal : ControlSignal;
			out torque : Torque;
			out speed : AngularVelocity;
		}
		action def 'Transfer Mechanical Power' {
			in torque : Torque;
			in speed : AngularVelocity;
			out shaftTorque : Torque;
			out shaftSpeed : AngularVelocity;
		}
		action def 'Generate Thrust' {
			in torque : Torque;
			in speed : AngularVelocity;
			out thrust : Thrust;
		}
		action def 'Provide Propulsion' {
			in power : ElectricalPower;
			in signal : ControlSignal;
			out thrust : Thrust;
			action 'convert electrical to mechanical' : 'Convert Electrical to Mechanical';
			action 'transfer mechanical power' : 'Transfer Mechanical Power';
			action 'generate thrust' : 'Generate Thrust';
			flow 'convert electrical to mechanical'.torque to 'transfer mechanical power'.torque;
			flow 'convert electrical to mechanical'.speed to 'transfer mechanical power'.speed;
			flow 'transfer mechanical power'.shaftTorque to 'generate thrust'.torque;
			flow 'transfer mechanical power'.shaftSpeed to 'generate thrust'.speed;
		}
	}

	package PartDefinitions {
		private import ValueTypes::*;
		private import PortDefinitions::*;
		private import ActionDefinitions::*;

		part def PropellerBlade {
			doc /* Individual aerodynamically-shaped blade attached to the hub. */
			attribute length : BladeLength;
			attribute rootStress : BladeStress;
			attribute yieldStrength : YieldStrength;
			port rootPort : MechanicalPowerInPort;
		}

		part def PropellerHub {
			doc /* Central hub that holds four blades and transfers drive torque to them. */
			port shaftPort : MechanicalPowerInPort;
			port blade1Port : MechanicalPowerOutPort;
			port blade2Port : MechanicalPowerOutPort;
			port blade3Port : MechanicalPowerOutPort;
			port blade4Port : MechanicalPowerOutPort;
			part blade1 : PropellerBlade;
			part blade2 : PropellerBlade;
			part blade3 : PropellerBlade;
			part blade4 : PropellerBlade;
			connect shaftPort to blade1Port;
			connect shaftPort to blade2Port;
			connect shaftPort to blade3Port;
			connect shaftPort to blade4Port;
			connect blade1Port to blade1.rootPort;
			connect blade2Port to blade2.rootPort;
			connect blade3Port to blade3.rootPort;
			connect blade4Port to blade4.rootPort;
		}

		part def PropellerAssembly {
			doc /* 2.4-meter diameter propeller assembly consisting of a hub and four blades. */
			port mechInPort : MechanicalPowerInPort;
			port thrustPort : ThrustPort;
			attribute diameter : Diameter;
			part hub : PropellerHub;
			perform action 'generate thrust' : 'Generate Thrust' {
				in torque = mechInPort.torque;
				in speed = mechInPort.speed;
				out thrust = thrustPort.thrust;
			}
			connect mechInPort to hub.shaftPort;
		}

		part def DriveShaft {
			doc /* Solid rotating shaft that transfers torque from the motor to the propeller. */
			port mechInPort : MechanicalPowerInPort;
			port mechOutPort : MechanicalPowerOutPort;
			perform action 'transfer mechanical power' : 'Transfer Mechanical Power' {
				in torque = mechInPort.torque;
				in speed = mechInPort.speed;
				out shaftTorque = mechOutPort.torque;
				out shaftSpeed = mechOutPort.speed;
			}
		}

		part def ElectricMotor {
			doc /* High-power electric motor that converts electrical energy and control signal into rotational mechanical power. */
			port elecPowerPort : ElectricalPowerPort;
			port controlPort : ControlSignalPort;
			port mechOutPort : MechanicalPowerOutPort;
			perform action 'convert electrical to mechanical' : 'Convert Electrical to Mechanical' {
				in power = elecPowerPort.power;
				in signal = controlPort.signal;
				out torque = mechOutPort.torque;
				out speed = mechOutPort.speed;
			}
		}

		part def PropulsionSystem {
			doc /* Complete electrically-powered propeller propulsion module. */
			port elecPowerPort : ElectricalPowerPort;
			port controlPort : ControlSignalPort;
			port thrustPort : ThrustPort;
			attribute rotationalSpeed : AngularVelocity;
			attribute maximumThrust : Thrust = 5000.0 [N];
			attribute minRotationalSpeed : AngularVelocity = 52.36 [rad/s];
			attribute maxRotationalSpeed : AngularVelocity = 314.16 [rad/s];
			part electricMotor : ElectricMotor;
			part driveShaft : DriveShaft;
			part propellerAssembly : PropellerAssembly;
			connect elecPowerPort to electricMotor.elecPowerPort;
			connect controlPort to electricMotor.controlPort;
			connect electricMotor.mechOutPort to driveShaft.mechInPort;
			connect driveShaft.mechOutPort to propellerAssembly.mechInPort;
			connect propellerAssembly.thrustPort to thrustPort;
			perform action 'provide propulsion' : 'Provide Propulsion' {
				in power = elecPowerPort.power;
				in signal = controlPort.signal;
				out thrust = thrustPort.thrust;
			}
		}
	}

	package RequirementDefinitions {
		private import PartDefinitions::*;

		requirement def ThrustCapability {
			doc /* The system shall be capable of producing up to 5000 Newtons of thrust. */
			subject system : PropulsionSystem;
			require constraint {
				system.maximumThrust <= 5000.0 [N]
			}
		}

		requirement def PropellerSize {
			doc /* The propeller shall have a diameter of 2.4 meters. */
			subject propeller : PropellerAssembly;
			require constraint {
				propeller.diameter == 2.4 [m]
			}
		}

		requirement def OperatingRange {
			doc /* The system shall operate continuously over rotational speeds from 500 to 3000 RPM (approximately 52.36 to 314.16 rad/s). */
			subject system : PropulsionSystem;
			require constraint {
				system.minRotationalSpeed >= 52.36 [rad/s] and
				system.maxRotationalSpeed <= 314.16 [rad/s]
			}
		}

		requirement def BladeStructuralIntegrity {
			doc /* Each blade shall withstand operational stress without exceeding its yield strength. */
			subject blade : PropellerBlade;
			require constraint {
				blade.rootStress <= blade.yieldStrength
			}
		}
	}

	package Usages {
		private import PartDefinitions::*;
		private import RequirementDefinitions::*;

		part propulsionSystem : PropulsionSystem {
			part :>> propellerAssembly {
				attribute :>> diameter = 2.4 [m];
				part :>> hub {
					part :>> blade1 {
						attribute :>> yieldStrength = 240000000.0 [Pa];
					}
					part :>> blade2 {
						attribute :>> yieldStrength = 240000000.0 [Pa];
					}
					part :>> blade3 {
						attribute :>> yieldStrength = 240000000.0 [Pa];
					}
					part :>> blade4 {
						attribute :>> yieldStrength = 240000000.0 [Pa];
					}
				}
			}
		}

		requirement thrustCapability : ThrustCapability;
		requirement propellerSize : PropellerSize;
		requirement operatingRange : OperatingRange;
		requirement bladeStructuralIntegrity : BladeStructuralIntegrity;

		satisfy thrustCapability by propulsionSystem;
		satisfy propellerSize by propulsionSystem.propellerAssembly;
		satisfy operatingRange by propulsionSystem;
		satisfy bladeStructuralIntegrity by propulsionSystem.propellerAssembly.hub.blade1;
		satisfy bladeStructuralIntegrity by propulsionSystem.propellerAssembly.hub.blade2;
		satisfy bladeStructuralIntegrity by propulsionSystem.propellerAssembly.hub.blade3;
		satisfy bladeStructuralIntegrity by propulsionSystem.propellerAssembly.hub.blade4;
	}
}
