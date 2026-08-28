package 'Pulser Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Fluid;

		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def VolumeValue :> Real;
		attribute def PressureSetpoint :> Real;
		attribute def PumpCommand :> Real;
		attribute def ElectricalPower :> Real;

		attribute def 'Start Signal';
		attribute def 'Priming Complete';
		attribute def 'High Pressure Alert';
		attribute def 'Low Flow Alert';
		attribute def 'Reset Signal';

		port def FluidPort {
			inout fluid : Fluid;
		}
		port def PressureFeedbackPort {
			inout pressure : PressureValue;
		}
		port def PressureCommandPort {
			inout command : PumpCommand;
		}
		port def PowerPort {
			inout power : ElectricalPower;
		}
		port def FlowMeasurementPort {
			inout flowRate : FlowRateValue;
			inout totalVolume : VolumeValue;
		}

		part def SupplyTank {
			port fluidOut : FluidPort;
		}
		part def CheckValve {
			port fluidIn : FluidPort;
			port fluidOut : FluidPort;
		}
		part def PulserPump {
			port fluidIn : FluidPort;
			port fluidOut : FluidPort;
			port powerIn : PowerPort;
			port commandIn : PressureCommandPort;
			perform action 'pulse diaphragm' : 'Pulse Diaphragm';
		}
		part def Accumulator {
			port fluidIn : FluidPort;
			port fluidOut : FluidPort;
		}
		part def FlowMeter {
			port fluidIn : FluidPort;
			port fluidOut : FluidPort;
			port measurementOut : FlowMeasurementPort;
			perform action 'measure flow' : 'Measure Flow';
		}
		part def DischargeManifold {
			port fluidIn : FluidPort;
			port fluidOut : FluidPort;
			port pressureOut : PressureFeedbackPort;
		}
		part def PressureSensor {
			port pressureIn : PressureFeedbackPort;
			port signalOut : PressureFeedbackPort;
			perform action 'sense pressure' : 'Sense Pressure';
		}
		part def PowerSupply {
			port powerOut : PowerPort;
		}
		part def Controller {
			port pressureIn : PressureFeedbackPort;
			port commandOut : PressureCommandPort;
			perform action 'control pressure' : 'Control Pressure';
			exhibit state 'controller states' : 'Controller States';
		}

		action def 'Pulse Diaphragm';
		action def 'Measure Flow' {
			out flowRate : FlowRateValue;
			out totalVolume : VolumeValue;
		}
		action def 'Sense Pressure' {
			out pressure : PressureValue;
		}
		action def 'Control Pressure' {
			in actualPressure : PressureValue;
			in setpoint : PressureSetpoint;
			out command : PumpCommand;
		}

		state def 'Controller States';
		state def 'System States';

		requirement def 'Pressure Control Requirement' {
			doc /* The system shall maintain discharge pressure within +/- 5% of the setpoint during running state. */
			subject subsystem;
		}
		requirement def 'Flow Measurement Requirement' {
			doc /* The system shall measure and report flow rate and total volume transferred. */
			subject meter;
		}
		requirement def 'Fault Handling Requirement' {
			doc /* The system shall enter a fault state if pressure exceeds a maximum limit or flow rate falls below a minimum limit. */
			subject subsystem;
		}
	}

	package Usages {
		private import Definitions::*;

		part pulserSubsystem {
			part supplyTank : SupplyTank;
			part inletCheckValve : CheckValve;
			part pulserPump : PulserPump;
			part outletCheckValve : CheckValve;
			part accumulator : Accumulator;
			part flowMeter : FlowMeter;
			part dischargeManifold : DischargeManifold;
			part pressureSensor : PressureSensor;
			part powerSupply : PowerSupply;

			action 'pulse diaphragm' : 'Pulse Diaphragm';
			action 'measure flow' : 'Measure Flow';
			action 'sense pressure' : 'Sense Pressure';
			action 'control pressure' : 'Control Pressure';

			part controller : Controller {
				state 'controller states' : 'Controller States' {
					entry; then idle;
					state idle;
					accept 'Start Signal' then active;
					state active {
						do 'control pressure';
					}
					accept 'Reset Signal' then idle;
				}
			}

			flow supplyToInletFlow of Fluid
				from supplyTank.fluidOut.fluid
				to inletCheckValve.fluidIn.fluid;
			flow inletToPumpFlow of Fluid
				from inletCheckValve.fluidOut.fluid
				to pulserPump.fluidIn.fluid;
			flow pumpToOutletFlow of Fluid
				from pulserPump.fluidOut.fluid
				to outletCheckValve.fluidIn.fluid;
			flow outletToAccumulatorFlow of Fluid
				from outletCheckValve.fluidOut.fluid
				to accumulator.fluidIn.fluid;
			flow accumulatorToFlowMeterFlow of Fluid
				from accumulator.fluidOut.fluid
				to flowMeter.fluidIn.fluid;
			flow flowMeterToDischargeFlow of Fluid
				from flowMeter.fluidOut.fluid
				to dischargeManifold.fluidIn.fluid;

			flow powerFlow of ElectricalPower
				from powerSupply.powerOut.power
				to pulserPump.powerIn.power;

			flow manifoldPressureFlow of PressureValue
				from dischargeManifold.pressureOut.pressure
				to pressureSensor.pressureIn.pressure;
			flow pressureFeedbackFlow of PressureValue
				from pressureSensor.signalOut.pressure
				to controller.pressureIn.pressure;
			flow commandFlow of PumpCommand
				from controller.commandOut.command
				to pulserPump.commandIn.command;

			state 'system states' : 'System States' {
				entry; then idle;
				state idle;
				accept 'Start Signal' then priming;
				state priming {
					do 'pulse diaphragm';
				}
				accept 'Priming Complete' then running;
				state running {
					do 'control pressure';
					do 'measure flow';
					do 'sense pressure';
				}
				accept 'High Pressure Alert' then fault;
				accept 'Low Flow Alert' then fault;
				state fault;
				accept 'Reset Signal' then idle;
			}
		}

		requirement 'pressure control req' : 'Pressure Control Requirement' {
			subject :>> subsystem = pulserSubsystem;
		}
		requirement 'flow measurement req' : 'Flow Measurement Requirement' {
			subject :>> meter = pulserSubsystem.flowMeter;
		}
		requirement 'fault handling req' : 'Fault Handling Requirement' {
			subject :>> subsystem = pulserSubsystem;
		}
	}
}
