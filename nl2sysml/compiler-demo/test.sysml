// Create a part called AvionicMotor. It uses electrical power to generate mechanical torque. It has three properties: rated power in kilowatts, nominal voltage in volts, and maximum speed in RPM.
package AvionicMotorSystem {
	private import SI::*;
	private import ISQ::*;
	private import ScalarValues::*;

	doc /* 
	 * This model describes an Avionic Motor system, which converts electrical power 
	 * into mechanical torque. It includes the motor's physical properties, behavior,
	 * performance requirements, and its usage within a simple actuator assembly.
	 */

	// Custom unit definition for Revolutions Per Minute (RPM)
	attribute <'rpm'> 'revolutions per minute' : AngularVelocityUnit = (2 * pi / 60) * rad/s;

	// Port definitions for electrical and mechanical interfaces
	port def ElectricalPort {
		in voltage :> electricPotential;
		in current :> electricCurrent;
	}

	port def MechanicalPort {
		out torque :> torque;
		out speed :> angularVelocity;
	}

	// Signals to control the motor's state
	signal def PowerOn;
	signal def PowerOff;

	// Behavior model for the motor's operational states
	state def MotorOperatingState {
		entry; 
		then Off;

		state Off {
			doc /* Motor is powered down and inactive. */
		}
		transition from Off to Running on PowerOn;

		state Running {
			doc /* Motor is powered on and converting energy. */
		}
		transition from Running to Off on PowerOff;
	}

	// Requirement definition for motor performance
	requirement def PerformanceRequirement {
		doc /* Specifies the minimum performance criteria for an avionic motor. */
		subject motor : AvionicMotor;

		attribute requiredMinPower :> power;
		attribute requiredMaxSpeed :> angularVelocity;
		attribute requiredVoltage :> electricPotential;

		require constraint PowerCapability {
			doc /* The motor's rated power must meet or exceed the requirement. */
			motor.ratedPower >= requiredMinPower
		}
		require constraint SpeedCapability {
			doc /* The motor's maximum speed must meet or exceed the requirement. */
			motor.maximumSpeed >= requiredMaxSpeed
		}
		require constraint VoltageCompatibility {
			doc /* The motor's nominal voltage must match the required system voltage. */
			motor.nominalVoltage == requiredVoltage
		}
	}

	// Core part definition for the Avionic Motor
	part def AvionicMotor {
		doc /* Converts electrical power to mechanical torque for avionics applications. */

		// Physical and performance properties
		attribute ratedPower :> power;
		attribute nominalVoltage :> electricPotential;
		attribute maximumSpeed :> angularVelocity;
		attribute efficiency : Real = 0.95; // Default efficiency

		// Interface ports
		port electricalIn : ElectricalPort;
		port mechanicalOut : MechanicalPort;

		// Internal behavior
		exhibit state machine : MotorOperatingState;

		// Constraint defining the physical relationship between power, torque, and speed
		constraint PowerConversion {
			doc /* Torque is a function of input power and output speed, adjusted for efficiency. */
			mechanicalOut.torque * mechanicalOut.speed == 
			electricalIn.voltage * electricalIn.current * efficiency
		}

		// Constraint ensuring operation does not exceed physical limits
		constraint SpeedLimit {
			mechanicalOut.speed <= maximumSpeed
		}
	}

	// Supporting parts for a system-level context
	part def PowerSupply {
		port electricalOut : ElectricalPort {
			direction = out;
		}
	}

	part def MechanicalLoad {
		port mechanicalIn : MechanicalPort {
			direction = in;
		}
	}

	// System-level assembly demonstrating the motor's usage
	part def ActuatorAssembly {
		doc /* An assembly combining a power supply, motor, and load. */

		// Component instances
		part motor : AvionicMotor {
			attribute redefines ratedPower = 15[kW];
			attribute redefines nominalVoltage = 270[V];
			attribute redefines maximumSpeed = 8000[rpm];
			attribute redefines efficiency = 0.92;
		}
		part psu : PowerSupply;
		part load : MechanicalLoad;

		// Connections between components
		connect psu.electricalOut to motor.electricalIn;
		connect motor.mechanicalOut to load.mechanicalIn;

		// Specific requirement instance for the motor in this assembly
		requirement motorPerformance : PerformanceRequirement {
			subject redefines motor = self.motor;
			attribute redefines requiredMinPower = 14[kW];
			attribute redefines requiredMaxSpeed = 7500[rpm];
			attribute redefines requiredVoltage = 270[V];
		}
	}
}
