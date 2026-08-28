package 'Industrial Gasoline Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		attribute def PressureValue :> Real;
		attribute def TemperatureValue :> Real;
		attribute def VolumeFlowRateValue :> Real;
		attribute def VibrationLevelValue :> Real;
		attribute def VolumeValue :> Real;

		item def Gasoline;
		item def StartCommand;
		item def StopCommand;
		item def AlarmSignal;

		port def FluidPort {
			inout item gasoline : Gasoline;
		}
		port def CommandPort {
			in item startCommand : StartCommand;
			in item stopCommand : StopCommand;
			out item alarm : AlarmSignal;
		}
		port def PowerPort {
			in attribute voltage : Real;
		}

		action def PrimePump {
			in inletPressure : PressureValue;
			in minPressure : PressureValue;
			out primed : Boolean;
		}
		action def PumpFuel;

		part def ElectricMotor {
			port powerIn : PowerPort;
			attribute temperature : TemperatureValue;
			attribute vibration : VibrationLevelValue;
			attribute maxTemperature : TemperatureValue = 350;
			attribute maxVibration : VibrationLevelValue = 10;
		}

		part def Impeller {
			attribute rotationalSpeed : Real;
		}

		part def SealedCasing {
			port inlet : FluidPort;
			port discharge : FluidPort;
			attribute sealIntegrity : Boolean = true;
		}

		part def PressureSensor {
			attribute measuredPressure : PressureValue;
		}
		part def FlowSensor {
			attribute measuredFlowRate : VolumeFlowRateValue;
		}
		part def TemperatureSensor {
			attribute measuredTemperature : TemperatureValue;
		}
		part def VibrationSensor {
			attribute measuredVibration : VibrationLevelValue;
		}

		part def GasolinePump {
			part motor : ElectricMotor;
			part impeller : Impeller;
			part casing : SealedCasing;
			part inletPressureSensor : PressureSensor;
			part dischargePressureSensor : PressureSensor;
			part flowSensor : FlowSensor;
			part motorTemperatureSensor : TemperatureSensor;
			part vibrationSensor : VibrationSensor;

			port commandPort : CommandPort;
			port powerPort : PowerPort;

			attribute minPrimingPressure : PressureValue = 50000;

			perform action 'prime pump' : PrimePump;
			perform action 'pump fuel' : PumpFuel;

			exhibit state operationalStates {
				entry; then stopped;

				state stopped;
				accept StartCommand via commandPort
					then priming;

				state priming {
					entry 'prime pump' {
						in inletPressure = inletPressureSensor.measuredPressure;
						in minPressure = minPrimingPressure;
					}
				}
				accept when 'prime pump'.primed
					then running;
				accept when not 'prime pump'.primed
					then faulted;

				state running {
					do 'pump fuel';
				}
				accept StopCommand via commandPort
					then stopped;
				accept when motorTemperatureSensor.measuredTemperature > motor.maxTemperature
					then faulted;
				accept when vibrationSensor.measuredVibration > motor.maxVibration
					then faulted;
				accept when not casing.sealIntegrity
					then faulted;

				state faulted {
					entry send new AlarmSignal() via commandPort;
				}
				accept StopCommand via commandPort
					then stopped;
			}
		}

		part def SupplyTank {
			port outlet : FluidPort;
			attribute volume : VolumeValue;
		}
		part def ReceivingVessel {
			port inlet : FluidPort;
			attribute volume : VolumeValue;
		}
		part def Piping {
			port endA : FluidPort;
			port endB : FluidPort;
		}
		part def ControlSystem {
			port pumpCommandPort : CommandPort;
		}
		part def ElectricalSupply {
			port powerOut : PowerPort;
			attribute outputVoltage : Real = 480;
		}
	}

	package Usages {
		private import Definitions::*;

		part gasolinePump : GasolinePump;
		part supplyTank : SupplyTank;
		part receivingVessel : ReceivingVessel;
		part inletPiping : Piping;
		part dischargePiping : Piping;
		part controlSystem : ControlSystem;
		part electricalSupply : ElectricalSupply;

		connect supplyTank.outlet to inletPiping.endA;
		connect inletPiping.endB to gasolinePump.casing.inlet;
		connect gasolinePump.casing.discharge to dischargePiping.endA;
		connect dischargePiping.endB to receivingVessel.inlet;

		connect controlSystem.pumpCommandPort to gasolinePump.commandPort;
		connect electricalSupply.powerOut to gasolinePump.powerPort;
	}

	package Requirements {
		private import Definitions::*;
		private import Usages::*;

		requirement def 'Safe Pump Operation' {
			doc /* The gasoline pump shall operate safely under all conditions. */
			subject pump : GasolinePump;

			requirement 'Overtemperature Protection' {
				doc /* The pump shall enter the faulted state and raise an alarm if the motor temperature exceeds its maximum. */
				subject pump;
				constraint { pump.motorTemperatureSensor.measuredTemperature <= pump.motor.maxTemperature }
			}
			requirement 'Vibration Protection' {
				doc /* The pump shall enter the faulted state and raise an alarm if vibration exceeds its maximum. */
				subject pump;
				constraint { pump.vibrationSensor.measuredVibration <= pump.motor.maxVibration }
			}
			requirement 'Seal Integrity Protection' {
				doc /* The pump shall enter the faulted state and raise an alarm if the casing seal integrity fails. */
				subject pump;
				constraint { pump.casing.sealIntegrity == true }
			}
		}

		requirement def 'Reliable Fuel Transfer' {
			doc /* The subsystem shall reliably transfer gasoline from the supply tank to the receiving vessel. */
			subject pump : GasolinePump;

			requirement 'Priming Verification' {
				doc /* The pump shall verify sufficient inlet pressure before entering the running state. */
				subject pump;
				constraint { pump.inletPressureSensor.measuredPressure >= pump.minPrimingPressure }
			}
			requirement 'Continuous Flow' {
				doc /* While running, the pump shall provide a positive flow rate of gasoline. */
				subject pump;
				constraint { pump.flowSensor.measuredFlowRate > 0 }
			}
		}

		requirement 'Subsystem Safe Operation' : 'Safe Pump Operation' {
			subject = gasolinePump;
		}
		requirement 'Subsystem Reliable Transfer' : 'Reliable Fuel Transfer' {
			subject = gasolinePump;
		}
	}
}
