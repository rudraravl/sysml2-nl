package PumpingSubsystemModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def FluidPressureValue :> PressureValue;
	attribute def FluidFlowRateValue :> VolumeFlowRateValue;
	attribute def FluidDensityValue :> DensityValue;
	attribute def SpecificPumpPowerValue :> SpecificEnergyValue;
	attribute def PumpEfficiencyValue :> Real;

	item def Fluid {
		attribute density : FluidDensityValue;
		attribute pressure : FluidPressureValue;
		attribute temperature : TemperatureValue;
	}

	port def FluidInPort {
		in item fluidIn : Fluid;
		in attribute inletPressure : FluidPressureValue;
		in attribute inletFlowRate : FluidFlowRateValue;
	}

	port def FluidOutPort {
		out item fluidOut : Fluid;
		out attribute outletPressure : FluidPressureValue;
		out attribute outletFlowRate : FluidFlowRateValue;
	}

	interface def FluidInterface {
		end port source : FluidOutPort;
		end port sink : FluidInPort;
		connect source.fluidOut to sink.fluidIn;
	}

	port def PowerPort {
		in attribute powerInput : PowerValue;
	}

	constraint def SpecificPumpPowerConstraint {
		in specificPower : SpecificPumpPowerValue;
		in pressureRise : FluidPressureValue;
		in density : FluidDensityValue;
		in efficiency : PumpEfficiencyValue;

		specificPower == pressureRise / (density * efficiency)
	}

	constraint def HydraulicPowerConstraint {
		in hydraulicPower : PowerValue;
		in flowRate : FluidFlowRateValue;
		in pressureRise : FluidPressureValue;

		hydraulicPower == flowRate * pressureRise
	}

	constraint def MassFlowConstraint {
		in massFlow : MassFlowValue;
		in volumeFlow : FluidFlowRateValue;
		in density : FluidDensityValue;

		massFlow == volumeFlow * density
	}

	requirement def PumpingPerformanceRequirement {
		doc /* The pumping subsystem shall deliver fluid at specified flow rate and pressure rise while maintaining specific pump power within limits. */

		attribute requiredFlowRate : FluidFlowRateValue;
		attribute requiredPressureRise : FluidPressureValue;
		attribute maxSpecificPower : SpecificPumpPowerValue;
		attribute minEfficiency : PumpEfficiencyValue;
	}

	action def PumpFluid {
		in inletFluid : Fluid;
		in specificPower : SpecificPumpPowerValue;
		in efficiency : PumpEfficiencyValue;
		in targetFlowRate : FluidFlowRateValue;
		out outletFluid : Fluid;
		out pressureRise : FluidPressureValue;
		out hydraulicPower : PowerValue;

		attribute inletPressure : FluidPressureValue = inletFluid.pressure;
		attribute fluidDensity : FluidDensityValue = inletFluid.density;
		attribute massFlow : MassFlowValue;

		assert constraint massFlowCalc : MassFlowConstraint {
			in massFlow = PumpFluid::massFlow;
			in volumeFlow = targetFlowRate;
			in density = fluidDensity;
		}

		assert constraint specificPowerCalc : SpecificPumpPowerConstraint {
			in specificPower = PumpFluid::specificPower;
			in pressureRise = PumpFluid::pressureRise;
			in density = fluidDensity;
			in efficiency = PumpFluid::efficiency;
		}

		assert constraint hydraulicPowerCalc : HydraulicPowerConstraint {
			in hydraulicPower = PumpFluid::hydraulicPower;
			in flowRate = targetFlowRate;
			in pressureRise = PumpFluid::pressureRise;
		}
	}

	action def MonitorPressure {
		in fluidStream : Fluid;
		out pressureReading : FluidPressureValue;
	}

	action def MonitorFlowRate {
		in fluidStream : Fluid;
		out flowReading : FluidFlowRateValue;
	}

	action def ControlPumpSpeed {
		in commandedSpeed : AngularVelocityValue;
		out actualSpeed : AngularVelocityValue;
	}

	state def PumpOperatingStates {
		entry; then idle;

		state idle;

		transition idle_to_starting
			first idle
			accept StartCommand
			then starting;

		state starting;

		transition starting_to_running
			first starting
			then running;

		state running {
			do action pumpingAction : PumpFluid;
		}

		transition running_to_stopping
			first running
			accept StopCommand
			then stopping;

		state stopping;

		transition stopping_to_idle
			first stopping
			then idle;
	}

	part def SourceReservoir {
		port outlet : FluidOutPort {
			out item redefines fluidOut : Fluid;
			out attribute redefines outletPressure;
			out attribute redefines outletFlowRate;
		}
		attribute storedVolume : VolumeValue;
		attribute fluidLevel : LengthValue;
	}

	part def DestinationReservoir {
		port inlet : FluidInPort {
			in item redefines fluidIn : Fluid;
			in attribute redefines inletPressure;
			in attribute redefines inletFlowRate;
		}
		attribute receivedVolume : VolumeValue;
	}

	part def CentrifugalPump {
		port inlet : FluidInPort;
		port outlet : FluidOutPort;
		port powerInput : PowerPort;

		attribute specificPumpPower : SpecificPumpPowerValue;
		attribute pumpEfficiency : PumpEfficiencyValue;
		attribute operatingSpeed : AngularVelocityValue;
		attribute impellerDiameter : LengthValue;
		attribute designFlowRate : FluidFlowRateValue;
		attribute designPressureRise : FluidPressureValue;

		perform pumpingOperation : PumpFluid;
		state pumpStates : PumpOperatingStates;
	}

	part def ElectricMotor {
		port shaft : PowerPort;

		attribute ratedPower : PowerValue;
		attribute voltage : VoltageValue;
		attribute current : ElectricCurrentValue;
		attribute motorEfficiency : PumpEfficiencyValue;
		attribute rotationalSpeed : AngularVelocityValue;

		perform driveLoad;
	}

	part def PressureSensor {
		port sensing : FluidInPort;

		attribute measuredPressure : FluidPressureValue;

		perform measurePressure : MonitorPressure;
	}

	part def FlowMeter {
		port sensing : FluidInPort;

		attribute measuredFlowRate : FluidFlowRateValue;

		perform measureFlow : MonitorFlowRate;
	}

	part def ControlValve {
		port inlet : FluidInPort;
		port outlet : FluidOutPort;

		attribute valvePosition : Real;
		attribute flowCoefficient : Real;

		perform regulateFlow;
	}

	part def PumpingSubsystem {
		requirement performanceReq : PumpingPerformanceRequirement {
			attribute redefines requiredFlowRate = 0.08 [m^3/s];
			attribute redefines requiredPressureRise = 600000.0 [Pa];
			attribute redefines maxSpecificPower = 750.0 [J/kg];
			attribute redefines minEfficiency = 0.78;
		}

		part source : SourceReservoir {
			port redefines outlet {
				out item redefines fluidOut : Fluid {
					attribute redefines density = 998.0 [kg/m^3];
					attribute redefines pressure = 101325.0 [Pa];
					attribute redefines temperature = 298.15 [K];
				}
				out attribute redefines outletPressure = 101325.0 [Pa];
				out attribute redefines outletFlowRate = 0.08 [m^3/s];
			}
			attribute redefines storedVolume = 15.0 [m^3];
			attribute redefines fluidLevel = 3.0 [m];
		}

		part pump : CentrifugalPump {
			attribute redefines specificPumpPower = 720.0 [J/kg];
			attribute redefines pumpEfficiency = 0.82;
			attribute redefines operatingSpeed = 1800.0 [rad/s];
			attribute redefines impellerDiameter = 0.25 [m];
			attribute redefines designFlowRate = 0.08 [m^3/s];
			attribute redefines designPressureRise = 580000.0 [Pa];

			perform action redefines pumpingOperation : PumpFluid {
				in inletFluid = source.outlet.fluidOut;
				in specificPower = pump.specificPumpPower;
				in efficiency = pump.pumpEfficiency;
				in targetFlowRate = pump.designFlowRate;
				out outletFluid;
				out pressureRise;
				out hydraulicPower;
			}
		}

		part motor : ElectricMotor {
			attribute redefines ratedPower = 50000.0 [W];
			attribute redefines voltage = 480.0 [V];
			attribute redefines current = 75.0 [A];
			attribute redefines motorEfficiency = 0.93;
			attribute redefines rotationalSpeed = 1800.0 [rad/s];
		}

		part dischargePressureSensor : PressureSensor {
			attribute redefines measuredPressure = 681325.0 [Pa];

			perform action redefines measurePressure : MonitorPressure;
		}

		part dischargeFlowMeter : FlowMeter {
			attribute redefines measuredFlowRate = 0.08 [m^3/s];

			perform action redefines measureFlow : MonitorFlowRate;
		}

		part dischargeValve : ControlValve {
			attribute redefines valvePosition = 0.85;
			attribute redefines flowCoefficient = 120.0;
		}

		part destination : DestinationReservoir {
			attribute redefines receivedVolume = 8.0 [m^3];
		}

		interface sourceToInlet : FluidInterface connect
			source ::> source.outlet to
			sink ::> pump.inlet;

		interface outletToSensor : FluidInterface connect
			source ::> pump.outlet to
			sink ::> dischargePressureSensor.sensing;

		interface sensorToMeter : FluidInterface connect
			source ::> dischargePressureSensor.sensing to
			sink ::> dischargeFlowMeter.sensing;

		interface meterToValve : FluidInterface connect
			source ::> dischargeFlowMeter.sensing to
			sink ::> dischargeValve.inlet;

		interface valveToDestination : FluidInterface connect
			source ::> dischargeValve.outlet to
			sink ::> destination.inlet;

		bind motor.shaft.powerInput = pump.powerInput.powerInput;
		bind motor.rotationalSpeed = pump.operatingSpeed;

		satisfy performanceReq by pump.specificPumpPower;
	}

	package LogicalModel {
		action def TransferFluid;
		action def GeneratePressure;

		part def FluidTransferSystem;

		action transferFluid : TransferFluid {
			action generatePressure : GeneratePressure;
		}

		part fluidTransferSystem : FluidTransferSystem {
			perform transferFluid.generatePressure;
		}
	}

	package PhysicalModel {
		private import LogicalModel::*;

		part def PumpAssembly;

		part pumpAssembly : PumpAssembly {
			part centrifugalPump : CentrifugalPump {
				perform transferFluid.generatePressure;
			}
		}

		allocation def LogicalToPhysical {
			end logical : FluidTransferSystem;
			end physical : PumpAssembly;
		}

		allocation fluidTransferAllocation : LogicalToPhysical
			allocate fluidTransferSystem to pumpAssembly {
			allocate fluidTransferSystem.generatePressure to pumpAssembly.centrifugalPump.generatePressure;
		}
	}
}
