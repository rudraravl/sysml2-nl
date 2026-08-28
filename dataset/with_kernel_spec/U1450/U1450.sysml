package MechanicalHydraulicPowertrain {
	package Definitions {
		private import ISQ::*;
		private import SI::*;

		alias Torque for TorqueValue;
		alias RotationalSpeed for AngularVelocityValue;
		alias Pressure for PressureValue;
		alias Force for ForceValue;
		alias FlowRate for VolumeFlowRateValue;
		alias Energy for EnergyValue;
		alias MomentOfInertia for MomentOfInertiaValue;

		attribute def FuelCmd;
		attribute def StartCmd;
		attribute def StopCmd;

		port def RotationalPowerPort {
			out torque: Torque;
			out speed: RotationalSpeed;
		}

		port def HydraulicPowerPort {
			out pressure: Pressure;
			out flow: FlowRate;
		}

		action def GenerateRotationalPower {
			in fuelCmd: FuelCmd;
			out torque: Torque;
			out speed: RotationalSpeed;
		}

		action def AdjustSpeedTorque {
			in inTorque: Torque;
			in inSpeed: RotationalSpeed;
			out outTorque: Torque;
			out outSpeed: RotationalSpeed;
		}

		action def StoreKineticEnergy {
			in inTorque: Torque;
			in inSpeed: RotationalSpeed;
			out outTorque: Torque;
			out outSpeed: RotationalSpeed;
		}

		action def ConvertToHydraulicPower {
			in inTorque: Torque;
			in inSpeed: RotationalSpeed;
			out pressure: Pressure;
			out flow: FlowRate;
		}

		action def ConvertToLinearForce {
			in pressure: Pressure;
			in flow: FlowRate;
			out force: Force;
		}

		action def ProvideHydraulicForce {
			in fuelCmd: FuelCmd;
			out force: Force;
		}

		part def Engine {
			port outRotational: RotationalPowerPort;
			perform generateRotationalPower;
			action generateRotationalPower: GenerateRotationalPower;
		}

		part def Transmission {
			port inRotational: RotationalPowerPort;
			port outRotational: RotationalPowerPort;
			perform adjustSpeedTorque;
			action adjustSpeedTorque: AdjustSpeedTorque;
		}

		part def Flywheel {
			port inRotational: RotationalPowerPort;
			port outRotational: RotationalPowerPort;
			attribute maxSafeSpeed: RotationalSpeed = 3000[rad/s];
			attribute momentOfInertia: MomentOfInertia = 2.5[kg*m^2];
			perform storeKineticEnergy;
			action storeKineticEnergy: StoreKineticEnergy;
		}

		part def HydraulicPump {
			port inRotational: RotationalPowerPort;
			port outHydraulic: HydraulicPowerPort;
			perform convertToHydraulicPower;
			action convertToHydraulicPower: ConvertToHydraulicPower;
		}

		part def HydraulicActuator {
			port inHydraulic: HydraulicPowerPort;
			attribute outForce: Force;
			perform convertToLinearForce;
			action convertToLinearForce: ConvertToLinearForce;
		}

		part def Powertrain {
			part engine: Engine;
			part transmission: Transmission;
			part flywheel: Flywheel;
			part hydraulicPump: HydraulicPump;
			part hydraulicActuator: HydraulicActuator;

			connect engine.outRotational to transmission.inRotational;
			connect transmission.outRotational to flywheel.inRotational;
			connect flywheel.outRotational to hydraulicPump.inRotational;
			connect hydraulicPump.outHydraulic to hydraulicActuator.inHydraulic;
		}

		requirement def FlywheelSafetyLimit {
			doc /* The flywheel shall not exceed its maximum safe operating speed. */
			subject flywheel: Flywheel;
			attribute maxSafeSpeed: RotationalSpeed;
			attribute actualSpeed: RotationalSpeed;
			require constraint { actualSpeed <= maxSafeSpeed }
		}

		requirement def PowerDeliveryRequirement {
			doc /* The system shall deliver a minimum linear force of 10000 N at the actuator. */
			subject actuator: HydraulicActuator;
			attribute actualForce: Force;
			attribute minRequiredForce: Force = 10000[N];
			require constraint { actualForce >= minRequiredForce }
		}

		requirement def EnergyStorageRequirement {
			doc /* The flywheel shall store at least 500 kJ of rotational energy at nominal operating speed. */
			subject flywheel: Flywheel;
			attribute storedEnergy: Energy;
			attribute minStoredEnergy: Energy = 500[kJ];
			require constraint { storedEnergy >= minStoredEnergy }
		}

		state def PowertrainLifecycle {
			state standby;
			state startingUp;
			state running;
			state shuttingDown;

			transition standby to startingUp accept startCmd : StartCmd;
			transition startingUp to running;
			transition running to shuttingDown accept stopCmd : StopCmd;
			transition shuttingDown to standby;
		}
	}

	package Usages {
		private import Definitions::*;

		part powertrain: Powertrain {
			perform lifecycle: PowertrainLifecycle;
		}

		action provideHydraulicForce: ProvideHydraulicForce {
			in fuelCmd: FuelCmd;
			out force: Force;

			action generateRotationalPower: GenerateRotationalPower {
				in fuelCmd = provideHydraulicForce::fuelCmd;
			}
			flow generateRotationalPower.torque to adjustSpeedTorque.inTorque;
			flow generateRotationalPower.speed to adjustSpeedTorque.inSpeed;

			action adjustSpeedTorque: AdjustSpeedTorque;
			flow adjustSpeedTorque.outTorque to storeKineticEnergy.inTorque;
			flow adjustSpeedTorque.outSpeed to storeKineticEnergy.inSpeed;

			action storeKineticEnergy: StoreKineticEnergy;
			flow storeKineticEnergy.outTorque to convertToHydraulicPower.inTorque;
			flow storeKineticEnergy.outSpeed to convertToHydraulicPower.inSpeed;

			action convertToHydraulicPower: ConvertToHydraulicPower;
			flow convertToHydraulicPower.pressure to convertToLinearForce.pressure;
			flow convertToHydraulicPower.flow to convertToLinearForce.flow;

			action convertToLinearForce: ConvertToLinearForce {
				out force = provideHydraulicForce::force;
			}
		}

		requirement flywheelSafety: FlywheelSafetyLimit {
			subject flywheel = powertrain.flywheel;
			attribute redefines maxSafeSpeed = 3000[rad/s];
			attribute redefines actualSpeed = powertrain.flywheel.outRotational.speed;
		}

		requirement powerDelivery: PowerDeliveryRequirement {
			subject actuator = powertrain.hydraulicActuator;
			attribute redefines actualForce = powertrain.hydraulicActuator.outForce;
		}

		requirement energyStorage: EnergyStorageRequirement {
			subject flywheel = powertrain.flywheel;
			attribute redefines storedEnergy = 0.5 * powertrain.flywheel.momentOfInertia * (powertrain.flywheel.maxSafeSpeed * powertrain.flywheel.maxSafeSpeed);
		}
	}
}
