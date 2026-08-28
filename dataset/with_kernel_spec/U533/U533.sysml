package 'Industrial Fluid Pumping System' {
	private import ScalarValues::*;

	package Definitions {
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def SpeedValue :> Real;
		attribute def LengthValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def TorqueValue :> Real;

		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
		}

		port def FluidPort {
			out item fluid : Fluid;
		}
		port def PressureSignalPort {
			out pressure : PressureValue;
		}
		port def FlowRateSignalPort {
			out flowRate : FlowRateValue;
		}
		port def MotorCommandPort {
			in speedCommand : SpeedValue;
			out actualSpeed : SpeedValue;
			out status : String;
		}
		port def MechanicalPort {
			attribute torque : TorqueValue;
			attribute speed : SpeedValue;
		}

		part def LobeRotor {
			port mechanicalIn : ~MechanicalPort;
			attribute lobeCount : Integer = 2;
			attribute clearance : LengthValue;
		}

		part def PumpChamber {
			part drivingRotor : LobeRotor;
			part drivenRotor : LobeRotor;
			connection def RotorSync {
				end : LobeRotor;
				end : LobeRotor;
			}
			connection rotorSync : RotorSync connect drivingRotor to drivenRotor;
		}

		part def LobePump {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			part chamber : PumpChamber;
			perform action pumpOperation : PumpOperation;
		}

		action def PumpOperation {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}

		part def GearSet {
			port mechanicalIn : ~MechanicalPort;
			port mechanicalOut : MechanicalPort;
			attribute ratio : Real;
		}

		part def Driveshaft {
			port mechanicalIn : ~MechanicalPort;
			port mechanicalOut : MechanicalPort;
			attribute length : LengthValue;
		}

		part def ElectricMotor {
			port motorCommandPort : MotorCommandPort;
			port mechanicalOut : MechanicalPort;
			attribute nominalSpeed : SpeedValue;
		}

		part def SourceReservoir {
			port outletPort : FluidPort;
			port returnPort : ~FluidPort;
			attribute capacity : VolumeValue;
			item storedFluid : Fluid;
		}

		part def DestinationReceiver {
			port inletPort : ~FluidPort;
			attribute capacity : VolumeValue;
			item storedFluid : Fluid;
		}

		part def PressureSensor {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port signalPort : PressureSignalPort;
			attribute measuredPressure : PressureValue;
		}

		part def FlowMeter {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port signalPort : FlowRateSignalPort;
			attribute measuredFlowRate : FlowRateValue;
		}

		part def PressureReliefValve {
			port inletPort : ~FluidPort;
			port returnPort : FluidPort;
			attribute setPressure : PressureValue;
			attribute isOpen : Boolean;
		}

		part def PumpController {
			port motorPort : ~MotorCommandPort;
			port inletPressurePort : ~PressureSignalPort;
			port outletPressurePort : ~PressureSignalPort;
			port flowRatePort : ~FlowRateSignalPort;
		}

		attribute def StartCommand;
		attribute def PrimingComplete;
		attribute def StopCommand;
		attribute def ShutdownComplete;
		attribute def FaultSignal;
		attribute def ResetCommand;

		state def SystemStates;

		requirement def RotorSynchronization {
			doc /* The driving and driven rotors shall maintain a fixed angular relationship with zero backlash. */
		}
		requirement def MinimalClearance {
			doc /* The clearance between rotor lobes and chamber wall shall be minimal to ensure volumetric efficiency. */
		}
		requirement def OverPressureProtection {
			doc /* The system shall prevent pressure from exceeding the relief valve set point. */
		}
	}

	package Usages {
		private import Definitions::*;

		part pumpingSystem {
			requirement req1 : RotorSynchronization;
			requirement req2 : MinimalClearance;
			requirement req3 : OverPressureProtection;

			part sourceReservoir : SourceReservoir {
				attribute capacity = 500;
				item storedFluid : Fluid;
			}

			part lobePump : LobePump {
				perform action pumpOperation : PumpOperation {
					in fluidIn = inletPort.fluid;
					out fluidOut = outletPort.fluid;
				}
				part chamber : PumpChamber {
					part drivingRotor : LobeRotor {
						attribute clearance = 0.1;
					}
					part drivenRotor : LobeRotor {
						attribute clearance = 0.1;
					}
				}
			}

			part electricMotor : ElectricMotor {
				attribute nominalSpeed = 1800;
			}

			part gearSet : GearSet {
				attribute ratio = 2.0;
			}

			part driveshaft : Driveshaft {
				attribute length = 200;
			}

			part inletPressureSensor : PressureSensor;
			part outletPressureSensor : PressureSensor;
			part flowMeter : FlowMeter;
			part pressureReliefValve : PressureReliefValve {
				attribute setPressure = 10;
			}

			part destinationReceiver : DestinationReceiver {
				attribute capacity = 1000;
				item storedFluid : Fluid;
			}

			part pumpController : PumpController;

			exhibit state systemStates : SystemStates {
				entry; then idle;

				state idle;
				accept StartCommand then priming;

				state priming;
				accept PrimingComplete then operating;

				state operating;
				accept when outletPressureSensor.measuredPressure > pressureReliefValve.setPressure then pressureRelief;
				accept StopCommand then shuttingDown;
				accept FaultSignal then fault;

				state pressureRelief;
				accept when outletPressureSensor.measuredPressure < 8.0 then operating;
				accept StopCommand then shuttingDown;
				accept FaultSignal then fault;

				state shuttingDown;
				accept ShutdownComplete then idle;

				state fault;
				accept ResetCommand then idle;
			}

			flow of fluid : Fluid
				from sourceReservoir.outletPort.fluid to inletPressureSensor.fluidInPort.fluid;
			flow of fluid : Fluid
				from inletPressureSensor.fluidOutPort.fluid to lobePump.inletPort.fluid;

			flow of fluid : Fluid
				from lobePump.outletPort.fluid to outletPressureSensor.fluidInPort.fluid;

			flow of fluid : Fluid
				from outletPressureSensor.fluidOutPort.fluid to flowMeter.fluidInPort.fluid;

			flow of fluid : Fluid
				from flowMeter.fluidOutPort.fluid to destinationReceiver.inletPort.fluid;

			flow of fluid : Fluid
				from lobePump.outletPort.fluid to pressureReliefValve.inletPort.fluid;

			flow of fluid : Fluid
				from pressureReliefValve.returnPort.fluid to sourceReservoir.returnPort.fluid;

			bind inletPressureSensor.signalPort.pressure = pumpController.inletPressurePort.pressure;
			bind outletPressureSensor.signalPort.pressure = pumpController.outletPressurePort.pressure;
			bind flowMeter.signalPort.flowRate = pumpController.flowRatePort.flowRate;
			connect electricMotor.motorCommandPort to pumpController.motorPort;

			connect electricMotor.mechanicalOut to gearSet.mechanicalIn;
			connect gearSet.mechanicalOut to driveshaft.mechanicalIn;
			connect driveshaft.mechanicalOut to lobePump.chamber.drivingRotor.mechanicalIn;

			satisfy req1 by lobePump.chamber.rotorSync;
			satisfy req2 by lobePump.chamber.drivingRotor.clearance;
			satisfy req3 by pressureReliefValve;
		}
	}
}
