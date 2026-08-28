package 'Pulse Duplicator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		item def Fluid;

		item def PressureWaveform {
			attribute systolicPressure : PressureValue;
			attribute diastolicPressure : PressureValue;
		}

		item def ControlCommand {
			attribute heartRate : FrequencyValue;
			attribute duration : TimeValue;
			item waveform : PressureWaveform;
		}

		item def SensorData {
			attribute pressure : PressureValue;
			attribute flowRate : VolumeFlowRateValue;
		}

		port def FluidPort {
			out item fluid : Fluid;
		}

		port def CommandPort {
			out item command : ControlCommand;
		}

		port def DataPort {
			out item data : SensorData;
		}

		attribute def StartTest;
		attribute def TestComplete;
		attribute def ResetSystem;

		action def GeneratePulse {
			in command : ControlCommand;
			in inFluid : Fluid;
			out outFluid : Fluid;
		}

		action def MeasurePressure {
			in fluid : Fluid;
			out pressure : PressureValue;
		}

		action def MeasureFlow {
			in fluid : Fluid;
			out flowRate : VolumeFlowRateValue;
		}

		action def CalculateGradient {
			in upstreamPressure : PressureValue;
			in downstreamPressure : PressureValue;
			out gradient : PressureValue;
		}

		action def CollectData {
			in data : SensorData;
		}

		part def SystemController {
			port commandOut : CommandPort;
			port dataIn : ~DataPort;

			attribute desiredHeartRate : FrequencyValue = 70;
			attribute testDuration : TimeValue = 10;
			attribute systolicPressure : PressureValue = 16;
			attribute diastolicPressure : PressureValue = 11;

			exhibit state controllerStates {
				entry; then idle;
				state idle;
				accept StartTest
					do send new ControlCommand() via commandOut
					then running;
				state running {
					do action collectData : CollectData {
						in data = dataIn.data;
					}
				}
				accept TestComplete
					then idle;
			}
		}

		part def PulsatilePump {
			port commandIn : ~CommandPort;
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;

			perform action generatePulse : GeneratePulse {
				in command = commandIn.command;
				in inFluid = fluidIn.fluid;
				out outFluid = fluidOut.fluid;
			}
		}

		part def ComplianceChamber {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			attribute compliance : Real;
		}

		part def TestValve {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
		}

		part def PressureSensor {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port dataOut : DataPort;

			perform action measurePressure : MeasurePressure {
				in fluid = fluidIn.fluid;
				out pressure = dataOut.data.pressure;
			}
		}

		part def FlowMeter {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			port dataOut : DataPort;

			perform action measureFlow : MeasureFlow {
				in fluid = fluidIn.fluid;
				out flowRate = dataOut.data.flowRate;
			}
		}

		part def ResistanceValve {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			attribute resistance : Real;
		}

		part def FluidReservoir {
			port fluidIn : ~FluidPort;
			port fluidOut : FluidPort;
			attribute volume : VolumeValue;
		}

		state def SystemLifecycle;

		requirement def HemodynamicSimulationRequirement {
			id = "REQ-001";
			text = "The system shall replicate pulsating blood flow and pressure conditions of a human heart.";
		}

		requirement def PressureGradientRequirement {
			id = "REQ-002";
			text = "The system shall measure the pressure gradient across the test valve.";
		}

		requirement def FlowRateRequirement {
			id = "REQ-003";
			text = "The system shall measure the volume flow rate through the test valve.";
		}

		requirement def AdjustableParametersRequirement {
			id = "REQ-004";
			text = "The system shall allow adjustment of heart rate, systolic and diastolic pressures, and test duration.";
		}

		requirement def ContinuousDataCollectionRequirement {
			id = "REQ-005";
			text = "The system shall continuously collect pressure and flow data for the test duration.";
		}
	}

	package Usages {
		private import Definitions::*;

		part pulseDuplicator {
			part controller : SystemController;
			part pump : PulsatilePump;
			part compliance : ComplianceChamber;
			part upstreamSensor : PressureSensor;
			part testValve : TestValve;
			part downstreamSensor : PressureSensor;
			part flowMeter : FlowMeter;
			part resistance : ResistanceValve;
			part reservoir : FluidReservoir;

			flow of command : ControlCommand
				from controller.commandOut.command to pump.commandIn.command;

			flow of fluid : Fluid
				from reservoir.fluidOut.fluid to pump.fluidIn.fluid;

			flow of fluid : Fluid
				from pump.fluidOut.fluid to compliance.fluidIn.fluid;

			flow of fluid : Fluid
				from compliance.fluidOut.fluid to upstreamSensor.fluidIn.fluid;

			flow of fluid : Fluid
				from upstreamSensor.fluidOut.fluid to testValve.fluidIn.fluid;

			flow of fluid : Fluid
				from testValve.fluidOut.fluid to downstreamSensor.fluidIn.fluid;

			flow of fluid : Fluid
				from downstreamSensor.fluidOut.fluid to flowMeter.fluidIn.fluid;

			flow of fluid : Fluid
				from flowMeter.fluidOut.fluid to resistance.fluidIn.fluid;

			flow of fluid : Fluid
				from resistance.fluidOut.fluid to reservoir.fluidIn.fluid;

			flow of data : SensorData
				from upstreamSensor.dataOut.data to controller.dataIn.data;

			flow of data : SensorData
				from downstreamSensor.dataOut.data to controller.dataIn.data;

			flow of data : SensorData
				from flowMeter.dataOut.data to controller.dataIn.data;

			exhibit state lifecycle : SystemLifecycle {
				entry; then idle;
				state idle;
				accept StartTest
					then running;
				state running {
					do action calculateGradient : CalculateGradient {
						in upstreamPressure = upstreamSensor.measurePressure.pressure;
						in downstreamPressure = downstreamSensor.measurePressure.pressure;
						out gradient;
					}
				}
				accept TestComplete
					then complete;
				state complete;
				accept ResetSystem
					then idle;
			}

			requirement HemodynamicSimulationRequirement : Definitions::HemodynamicSimulationRequirement;
			requirement PressureGradientRequirement : Definitions::PressureGradientRequirement;
			requirement FlowRateRequirement : Definitions::FlowRateRequirement;
			requirement AdjustableParametersRequirement : Definitions::AdjustableParametersRequirement;
			requirement ContinuousDataCollectionRequirement : Definitions::ContinuousDataCollectionRequirement;

			satisfy HemodynamicSimulationRequirement by pump;
			satisfy PressureGradientRequirement by upstreamSensor;
			satisfy PressureGradientRequirement by downstreamSensor;
			satisfy FlowRateRequirement by flowMeter;
			satisfy AdjustableParametersRequirement by controller;
			satisfy ContinuousDataCollectionRequirement by lifecycle.running;
		}
	}
}
