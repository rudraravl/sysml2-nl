package 'Industrial Fluid Transfer System' {
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ScalarValues::Boolean;
	private import ISQ::*;

	package Definitions {
		item def Liquid {
			attribute temperature : TemperatureValue;
			attribute volume : VolumeValue;
		}

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def RunningSignal;
		attribute def StoppedSignal;
		attribute def HighPressureModeCommand;
		attribute def NormalPressureModeCommand;

		attribute def SinusoidalFlowProfile {
			attribute meanFlowRate : VolumeFlowRateValue;
			attribute amplitude : VolumeFlowRateValue;
			attribute frequency : FrequencyValue;
			attribute phaseShift : Real;
		}

		port def FluidPort {
			out item liquid : Liquid;
		}

		port def MechanicalPowerPort {
			out torque : TorqueValue;
			out angularVelocity : AngularVelocityValue;
		}

		action def GenerateTorque {
			out torque : TorqueValue;
			out angularVelocity : AngularVelocityValue;
		}

		action def GenerateSinusoidalFlow {
			in inletLiquid : Liquid;
			in driveTorque : TorqueValue;
			in driveSpeed : AngularVelocityValue;
			out outletLiquid : Liquid;
		}

		state machine def PumpOperationStateMachine {
			state stopped;
			state starting;
			state running {
				state normalMode;
				state highPressureMode;
				transition t1 from normalMode to highPressureMode accept highPressureModeCommand : HighPressureModeCommand;
				transition t2 from highPressureMode to normalMode accept normalPressureModeCommand : NormalPressureModeCommand;
			}
			state stopping;
			transition t3 from stopped to starting accept startCommand : StartCommand;
			transition t4 from starting to running accept runningSignal : RunningSignal;
			transition t5 from running to stopping accept stopCommand : StopCommand;
			transition t6 from stopping to stopped accept stoppedSignal : StoppedSignal;
		}

		part def SourceReservoir {
			port outletPort : FluidPort;
			attribute capacity : VolumeValue;
			attribute liquidLevel : VolumeValue;
			item storedLiquid : Liquid;
		}

		part def ProcessVessel {
			port inletPort : ~FluidPort;
			attribute operatingPressure : PressureValue;
			attribute maxPressure : PressureValue;
			attribute capacity : VolumeValue;
			item containedLiquid : Liquid;
		}

		part def SinusoidalRotor {
			attribute lobeCount : Integer = 2;
			attribute rotorDiameter : LengthValue;
			attribute rotorLength : LengthValue;
		}

		part def Stator {
			attribute innerDiameter : LengthValue;
			attribute housingLength : LengthValue;
		}

		part def SealingSystem {
			attribute sealPressureRating : PressureValue;
			attribute leakageRate : VolumeFlowRateValue;
			attribute integrity : Boolean = true;
		}

		part def ElectricMotor {
			port powerOutPort : MechanicalPowerPort;
			attribute ratedTorque : TorqueValue;
			attribute ratedAngularVelocity : AngularVelocityValue;
			perform action generateTorque : GenerateTorque {
				out torque = powerOutPort.torque;
				out angularVelocity = powerOutPort.angularVelocity;
			}
		}

		part def SinusoidalPump {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			port shaftPort : ~MechanicalPowerPort;
			part rotor : SinusoidalRotor;
			part stator : Stator;
			part sealing : SealingSystem;
			attribute displacementVolume : VolumeValue;
			attribute maxPressure : PressureValue;
			attribute efficiency : Real = 0.85;
			attribute flowProfile : SinusoidalFlowProfile;
			perform action generateSinusoidalFlow : GenerateSinusoidalFlow {
				in inletLiquid = inletPort.liquid;
				in driveTorque = shaftPort.torque;
				in driveSpeed = shaftPort.angularVelocity;
				out outletLiquid = outletPort.liquid;
			}
			state machine pumpOperation : PumpOperationStateMachine;
		}

		part def FluidTransferSystem {
			part reservoir : SourceReservoir;
			part motor : ElectricMotor;
			part pump : SinusoidalPump;
			part vessel : ProcessVessel;
			flow of liquid : Liquid
				from reservoir.outletPort.liquid to pump.inletPort.liquid;
			flow of liquid : Liquid
				from pump.outletPort.liquid to vessel.inletPort.liquid;
			connect motor.powerOutPort to pump.shaftPort;
		}
	}

	package Usages {
		private import Definitions::*;

		part context : FluidTransferSystem;
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def SinusoidalFlowRequirement {
			doc /* The pump shall generate a precisely controlled, sinusoidal flow profile. */
			subject pump : SinusoidalPump;
			attribute targetWaveform : String = "sinusoidal";
		}

		requirement def PressureLimitRequirement {
			doc /* The system shall operate within specified pressure limits. */
			subject vessel : ProcessVessel;
			attribute maxAllowedPressure : PressureValue = 10.0;
			require constraint { vessel.operatingPressure <= maxAllowedPressure }
		}

		requirement def EfficiencyRequirement {
			doc /* The pump shall operate with high volumetric efficiency. */
			subject pump : SinusoidalPump;
			attribute minEfficiency : Real = 0.90;
			require constraint { pump.efficiency >= minEfficiency }
		}

		requirement systemSpecification {
			doc /* Overall industrial fluid transfer system performance requirements. */
			subject system : context;
			require sinusoidalFlow : SinusoidalFlowRequirement {
				subject = system.pump;
			}
			require pressureLimit : PressureLimitRequirement {
				subject = system.vessel;
			}
			require efficiency : EfficiencyRequirement {
				subject = system.pump;
			}
		}
	}
}
