// Create a part called AvionicMotor. It uses electrical power to generate mechanical torque. It has three properties: rated power in kilowatts, nominal voltage in volts, and maximum speed in RPM.
package AvionicSystems {
	private import SI::*;
	private import ISQ::*;

	attribute <'rpm'> 'revolutions per minute' : AngularVelocityUnit = (2 * ScalarValues::pi / 60) * rad/s;

	item def ElectricalSignal {
		attribute voltage :> electricPotential;
		attribute current :> electricCurrent;
	}

	item def MechanicalShaftLoad {
		attribute torque :> torque;
		attribute speed :> angularVelocity;
	}

	port def ElectricalConnector {
		in item signal : ElectricalSignal;
	}

	port def MechanicalShaftConnector {
		out item load : MechanicalShaftLoad;
	}

	action def ConvertPower {
		in voltage :> electricPotential;
		in current :> electricCurrent;
		out torque :> torque;
		out speed :> angularVelocity;
		attribute efficiency : ScalarValues::Real = 0.95;
	}

	part def AvionicMotor {
		doc /* An electric motor designed for avionic applications,
		     * converting electrical power into mechanical torque. */

		attribute ratedPower :> power { :>> kW; }
		attribute nominalVoltage :> electricPotential { :>> V; }
		attribute maxSpeed :> angularVelocity { :>> rpm; }

		port electricalInput : ElectricalConnector;
		port mechanicalOutput : MechanicalShaftConnector;

		perform convert : ConvertPower {
			in voltage = self.electricalInput.signal.voltage;
			in current = self.electricalInput.signal.current;
			out torque = self.mechanicalOutput.load.torque;
			out speed = self.mechanicalOutput.load.speed;
		}

		constraint PowerConversion {
			doc /* Output mechanical power is input electrical power times efficiency. */
			mechanicalOutput.load.torque * mechanicalOutput.load.speed ==
			electricalInput.signal.voltage * electricalInput.signal.current * convert.efficiency
		}
	}

	requirement def MotorSpecification {
		subject motor : AvionicMotor;
		attribute requiredMinPower : PowerValue;
		attribute requiredMaxSpeed : AngularVelocityValue;

		require constraint PowerOutputConstraint {
			doc /* The motor's rated power must meet or exceed the minimum requirement. */
			motor.ratedPower >= requiredMinPower
		}

		require constraint SpeedCapabilityConstraint {
			doc /* The motor's maximum speed must meet or exceed the required speed. */
			motor.maxSpeed >= requiredMaxSpeed
		}
	}

	part def FlightControlActuator {
		part motor : AvionicMotor {
			attribute redefines ratedPower = 7.5 [kW];
			attribute redefines nominalVoltage = 28 [V];
			attribute redefines maxSpeed = 12000 [rpm];
		}

		part powerSupply {
			out port powerOut : ElectricalConnector;
		}

		part controlSurfaceLinkage {
			in port mechanicalIn : MechanicalShaftConnector;
		}

		connect powerSupply.powerOut to motor.electricalInput;
		connect motor.mechanicalOutput to controlSurfaceLinkage.mechanicalIn;
	}

	requirement highPerformanceMotorReq : MotorSpecification {
		doc /* Defines the performance requirements for the flight control actuator motor. */
		subject redefines motor = FlightControlActuator.motor;
		attribute redefines requiredMinPower = 7.0 [kW];
		attribute redefines requiredMaxSpeed = 10000 [rpm];
	}
}
