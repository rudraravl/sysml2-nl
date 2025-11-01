// Describe a car that includes an electric motor, battery pack, and regenerative braking.
package 'ElectricVehicleSystem' {
	import ISQ::*;
	import ScalarValues::*;

	// Value and Item Definitions
	attribute def StateOfCharge :> Real {
		unit = ISQ::Units::Percent;
	}

	item def ElectricalPower {
		attribute value : PowerValue;
	}

	item def MechanicalTorque {
		attribute value : TorqueValue;
	}

	item def BrakeCommand {
		attribute pressure : Percentage;
	}

	// Port Definitions
	port def ElectricalPort {
		inout power : ElectricalPower;
	}

	port def MechanicalPort {
		out torque : MechanicalTorque;
	}

	port def ControlPort {
		in command : BrakeCommand;
	}

	// Component Definitions
	abstract part def VehicleComponent;

	part def BatteryPack :> VehicleComponent {
		port powerPort : ElectricalPort;
		attribute stateOfCharge : StateOfCharge = 100.0;
		attribute capacity : EnergyValue = 75.0 {
			unit = ISQ::Units::'kilowatt-hour';
		}
	}

	part def ElectricMotor :> VehicleComponent {
		port electricalPort : ElectricalPort;
		port mechanicalPort : MechanicalPort;
	}

	part def PowerControlUnit :> VehicleComponent {
		port batteryConnection : ~ElectricalPort;
		port motorConnection : ~ElectricalPort;
		port brakeSensorInput : ControlPort;

		state machine PowertrainController {
			initial state Off;

			state Off {
				transition to Idle on powerOn;
			}

			state Idle {
				transition to Accelerating on acceleratorPressed;
				transition to Off on powerOff;
			}

			state Accelerating {
				transition to Cruising on acceleratorSteady;
				transition to RegenerativeBraking on brakePressed;
				transition to Idle on acceleratorReleased;
			}

			state Cruising {
				transition to Accelerating on acceleratorPressed;
				transition to RegenerativeBraking on brakePressed;
				transition to Idle on acceleratorReleased;
			}

			state RegenerativeBraking {
				transition to Idle on brakeReleased;
				transition to Accelerating on acceleratorPressed;
			}
		}
	}

	part def BrakingSystem :> VehicleComponent {
		port commandOutput : ~ControlPort;
	}

	part def WheelAssembly :> VehicleComponent {
		port torqueInput : ~MechanicalPort;
	}

	// System Assembly
	part def ElectricCar {
		satisfy MainSystem;

		part components : VehicleComponent[*];
		part battery : BatteryPack subsets components;
		part motor : ElectricMotor subsets components;
		part pcu : PowerControlUnit subsets components;
		part brakes : BrakingSystem subsets components;
		part wheels : WheelAssembly[4] :> components;

		connect pcu.batteryConnection to battery.powerPort;
		connect pcu.motorConnection to motor.electricalPort;
		connect motor.mechanicalPort to wheels.torqueInput;
		connect brakes.commandOutput to pcu.brakeSensorInput;

		// Flow during acceleration
		flow 'PropulsionPower' of ElectricalPower
			from battery.powerPort
			to pcu.batteryConnection
			to pcu.motorConnection
			to motor.electricalPort;

		// Flow during regenerative braking
		flow 'RegenPower' of ElectricalPower
			from motor.electricalPort
			to pcu.motorConnection
			to pcu.batteryConnection
			to battery.powerPort;

		flow 'DriveTorque' of MechanicalTorque
			from motor.mechanicalPort
			to wheels.torqueInput;
	}

	// Requirements
	requirement def VehicleFunctionality {
		text "The vehicle shall provide electric propulsion and energy recovery capabilities.";
	}

	requirement MainSystem : VehicleFunctionality {
		id = "EV-1";
		text "The car shall be powered by an electric motor using energy from a battery pack.";

		requirement Powertrain {
			id = "EV-1.1";
			text "The powertrain shall consist of a battery pack, a power control unit, and an electric motor.";
		}
	}

	requirement RegenerativeBraking : VehicleFunctionality {
		id = "EV-2";
		text "The car shall implement a regenerative braking system to recover kinetic energy during deceleration.";
		subject ElectricCar;

		requirement EnergyRecovery {
			id = "EV-2.1";
			text "The system shall recover at least 15% of the kinetic energy during a standard braking maneuver.";
			attribute targetRecovery : Percentage = 15.0;
		}
	}
}
