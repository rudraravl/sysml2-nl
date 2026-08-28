package 'Industrial Fluid Pumping System' {
	private import ScalarValues::Real;

	package Definitions {
		item def Fluid {
			attribute volume : Real;
			attribute pressure : Real;
		}

		item def RotationalPower {
			attribute torque : Real;
			attribute speed : Real;
		}

		port def FluidInPort {
			in item fluid : Fluid;
		}

		port def FluidOutPort {
			out item fluid : Fluid;
		}

		port def DriveShaftInPort {
			in power : RotationalPower;
		}

		port def DriveShaftOutPort {
			out power : RotationalPower;
		}

		port def PressureSignalOutPort {
			out pressure : Real;
		}

		port def FlowSignalOutPort {
			out flowRate : Real;
		}

		action def GenerateTorque {
			out power : RotationalPower;
		}

		action def PumpFluid {
			in fluidIn : Fluid;
			in powerIn : RotationalPower;
			out fluidOut : Fluid;
			out suctionPressure : Real;
			out dischargePressure : Real;
		}

		action def MeasurePressure {
			in pressureIn : Real;
			out pressureOut : Real;
		}

		action def MeasureFlowRate {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			out flowRate : Real;
		}

		part def SupplyTank {
			port fluidOutPort : FluidOutPort;
			attribute capacity : Real;
			attribute fluidLevel : Real;
		}

		part def ReceivingTank {
			port fluidInPort : FluidInPort;
			attribute capacity : Real;
			attribute fluidLevel : Real;
		}

		part def ScrewRotor {
			port drivePort : DriveShaftInPort;
			attribute rotationalSpeed : Real;
		}

		part def Casing {
			port inletPort : FluidInPort;
			port outletPort : FluidOutPort;
			part rotor : ScrewRotor;
		}

		part def ScrewPump {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			port drivePort : DriveShaftInPort;
			port suctionPressurePort : PressureSignalOutPort;
			port dischargePressurePort : PressureSignalOutPort;

			part casing : Casing;

			attribute inletPressure : Real;
			attribute outletPressure : Real;
			attribute efficiency : Real;
			attribute flowRate : Real;

			perform action pumpFluid : PumpFluid {
				in fluidIn = fluidInPort.fluid;
				in powerIn = drivePort.power;
				out fluidOut = fluidOutPort.fluid;
				out suctionPressure = suctionPressurePort.pressure;
				out dischargePressure = dischargePressurePort.pressure;
			}
		}

		part def ElectricMotor {
			port drivePort : DriveShaftOutPort;
			attribute ratedPower : Real;
			perform action generateTorque : GenerateTorque {
				out power = drivePort.power;
			}
		}

		part def PressureGauge {
			port measurePort : ~PressureSignalOutPort;
			attribute pressureReading : Real;
			perform action measurePressure : MeasurePressure {
				in pressureIn = measurePort.pressure;
				out pressureOut = pressureReading;
			}
		}

		part def FlowMeter {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			port signalPort : FlowSignalOutPort;
			attribute flowRateReading : Real;
			perform action measureFlowRate : MeasureFlowRate {
				in fluidIn = fluidInPort.fluid;
				out fluidOut = fluidOutPort.fluid;
				out flowRate = signalPort.flowRate;
			}
		}

		requirement def FlowRateRequirement {
			doc /* The system shall deliver a consistent flow rate within specified limits. */
			subject pump : ScrewPump;
			attribute minFlowRate : Real;
			attribute maxFlowRate : Real;
		}

		requirement def PressureLimitRequirement {
			doc /* The system shall maintain pressures within rated limits. */
			subject pump : ScrewPump;
			attribute maxSuctionPressure : Real;
			attribute maxDischargePressure : Real;
		}

		requirement def EfficiencyRequirement {
			doc /* The pump shall achieve a minimum level of efficiency. */
			subject pump : ScrewPump;
			attribute minEfficiency : Real;
		}
	}

	package Usages {
		private import Definitions::*;

		part pumpingSystem {
			part supplyTank : SupplyTank {
				attribute capacity = 10.0;
				attribute fluidLevel = 0.8;
			}

			part motor : ElectricMotor {
				attribute ratedPower = 7500.0;
			}

			part pump : ScrewPump {
				attribute inletPressure = 101325.0;
				attribute outletPressure = 1500000.0;
				attribute efficiency = 78.0;
				attribute flowRate = 0.01;

				part inletGauge : PressureGauge;
				part outletGauge : PressureGauge;
			}

			part flowMeter : FlowMeter;

			part receivingTank : ReceivingTank {
				attribute capacity = 10.0;
				attribute fluidLevel = 0.0;
			}

			flow of fluid : Fluid
				from supplyTank.fluidOutPort.fluid
				to pump.fluidInPort.fluid;

			flow of fluid : Fluid
				from pump.fluidOutPort.fluid
				to flowMeter.fluidInPort.fluid;

			flow of fluid : Fluid
				from flowMeter.fluidOutPort.fluid
				to receivingTank.fluidInPort.fluid;

			connect motor.drivePort to pump.drivePort;

			connect pump.suctionPressurePort to pump.inletGauge.measurePort;
			connect pump.dischargePressurePort to pump.outletGauge.measurePort;

			requirement pumpPerformanceSpec {
				doc /* Overall pump performance requirements group */
				subject pump : ScrewPump = pumpingSystem.pump;

				require consistentFlow : FlowRateRequirement {
					subject = pump;
					minFlowRate = 0.008;
					maxFlowRate = 0.012;
				}

				require pressureLimits : PressureLimitRequirement {
					subject = pump;
					maxSuctionPressure = 200000.0;
					maxDischargePressure = 2000000.0;
				}

				require minEfficiencyReq : EfficiencyRequirement {
					subject = pump;
					minEfficiency = 75.0;
				}
			}
		}
	}
}
