// Describe a car that includes an electric motor, battery pack, and regenerative braking.
package 'Electric Vehicle with Regenerative Braking' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	// Value Type Definitions for clarity and type safety
	attribute def StateOfCharge {
		attribute value : Real[0.0..100.0]; // Percentage
	}

	attribute def VehicleSpeed :> ISQ::SpeedValue;
	attribute def MotorPower :> ISQ::PowerValue;
	attribute def BatteryCapacity :> ISQ::EnergyValue;
	attribute def BrakeCommandValue {
		attribute intensity : Real[0.0..1.0]; // Normalized brake pedal input
	}

	// Item Definitions for Flows
	item def ElectricalPower;
	item def MechanicalPower;
	item def BrakeCommand;

	// Port Definitions for standardized interfaces
	port def ElectricalPort {
		inout item power : ElectricalPower;
	}

	port def MechanicalPort {
		inout item power : MechanicalPower;
	}

	port def CommandPort {
		in item command : BrakeCommand;
	}

	// Part Definitions for Vehicle Components
	part def BatteryPack {
		attribute capacity : BatteryCapacity = 80 [kWh];
		attribute stateOfCharge : StateOfCharge = { value = 90.0 };
		attribute maxChargeRate : ISQ::PowerValue = 50 [kW];
		attribute maxDischargeRate : ISQ::PowerValue = 250 [kW];
		port powerConnector : ElectricalPort;
	}

	part def PowerElectronicsUnit {
		attribute efficiency : Real = 0.97;
		port batterySide : ElectricalPort;
		port motorSide : ElectricalPort;
	}

	part def MotorGenerator {
		attribute maxPower : MotorPower = 200 [kW];
		attribute maxRegenPower : MotorPower = 60 [kW];
		port electricalConnector : ElectricalPort;
		port driveShaft : MechanicalPort;

		state machine OperatingMode {
			initial Off;
			state Off;
			state Motoring; // Consuming electrical power to produce mechanical power
			state Generating; // Consuming mechanical power to produce electrical power

			transition from Off to Motoring on receive(PowerOn);
			transition from Motoring to Generating on receive(RegenBrake);
			transition from Generating to Motoring on receive(Accelerate);
			transition from Generating to Off on receive(PowerOff);
			transition from Motoring to Off on receive(PowerOff);
		}
	}

	part def Drivetrain {
		attribute gearRatio : Real = 9.1;
		port motorInput : MechanicalPort;
		port wheelOutput : MechanicalPort;
	}

	part def BrakeController {
		port brakePedalInput : CommandPort;

		action determineBrakingStrategy {
			in brakeCmd : BrakeCommand;
			in currentSpeed : VehicleSpeed;
			in batterySoC : StateOfCharge;
			out regenTorqueCmd : Real;
			out frictionBrakeCmd : Real;

			decide 'Brake Blending Logic';
				if currentSpeed.num > 5.0 and batterySoC.value < 98.0 then
					'Prioritize Regen';
				else
					'Use Friction Brakes';

			accept 'Prioritize Regen' {
				// Calculate how much regen is possible
				let regenPortion = brakeCmd.intensity * 0.8; // Example: 80% of braking via regen
				let frictionPortion = brakeCmd.intensity * 0.2;
				regenTorqueCmd = regenPortion;
				frictionBrakeCmd = frictionPortion;
			}

			accept 'Use Friction Brakes' {
				// Use only friction brakes at low speed or full battery
				regenTorqueCmd = 0.0;
				frictionBrakeCmd = brakeCmd.intensity;
			}
		}
	}

	// Top-level Electric Car Assembly
	part def ElectricCar {
		attribute currentSpeed : VehicleSpeed = 0 [km/h];

		part battery : BatteryPack;
		part peu : PowerElectronicsUnit;
		part motor : MotorGenerator;
		part drivetrain : Drivetrain;
		part brakeController : BrakeController;

		port brakePedal : CommandPort;

		// Structural Connections
		connect battery.powerConnector to peu.batterySide;
		connect peu.motorSide to motor.electricalConnector;
		connect motor.driveShaft to drivetrain.motorInput;
		connect brakePedal to brakeController.brakePedalInput;

		// Flow for Propulsion (Battery -> Wheels)
		flow of ElectricalPower
			from battery.powerConnector.power
			to peu.batterySide.power;
		flow of ElectricalPower
			from peu.motorSide.power
			to motor.electricalConnector.power;
		flow of MechanicalPower
			from motor.driveShaft.power
			to drivetrain.motorInput.power;

		// Flow for Regenerative Braking (Wheels -> Battery)
		flow of MechanicalPower
			from drivetrain.motorInput.power
			to motor.driveShaft.power;
		flow of ElectricalPower
			from motor.electricalConnector.power
			to peu.motorSide.power;
		flow of ElectricalPower
			from peu.batterySide.power
			to battery.powerConnector.power;

		// Flow for Control Signal
		flow of BrakeCommand
			from brakePedal.command
			to brakeController.brakePedalInput.command;
	}

	// Requirements
	requirement def RegenEfficiency {
		doc "The regenerative braking system must recover electrical energy
		     when the vehicle is decelerating, provided the battery is not
			 at maximum charge.";
		id = "EV-REQ-001";
		subject car : ElectricCar;
		require constraint {
			car.motor.maxRegenPower.num > 0
		}
	}

	requirement def BatteryRange {
		doc "The vehicle shall have a minimum range of 400 km on a full charge.";
		id = "EV-REQ-002";
		subject car : ElectricCar;
		require constraint {
			car.battery.capacity.num >= 75.0 // Assuming kWh
		}
	}

	// Instantiation of the system and its requirements
	part myEv : ElectricCar;

	requirement rangeRequirement : BatteryRange {
		subject car = myEv;
	}

	requirement regenRequirement : RegenEfficiency {
		subject car = myEv;
	}
}
