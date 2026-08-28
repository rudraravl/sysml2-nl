package 'Electroosmotic Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		value type VoltageValue :> ISQ::electricPotentialDifference;
		value type FlowRateValue :> ISQ::volumeFlowRate;
		value type PressureValue :> ISQ::pressure;

		item def Fluid {
			attribute pH : Real;
			attribute ionicStrength : Real;
		}

		port def FluidPort {
			out item fluid : Fluid;
		}

		port def ElectricalPort {
			out voltage : VoltageValue;
		}

		connection def ElectricalConnection {
			end : ElectricalPort[1];
			end : ~ElectricalPort[1];
		}

		part def SourceReservoir {
			port fluidOutPort : FluidPort;
		}

		part def CollectionChamber {
			port fluidInPort : ~FluidPort;
		}

		part def PowerSupply {
			port voltageOutPort : ElectricalPort;
		}

		part def Microchannel;
		part def Electrode;

		action def PumpFluid {
			in fluidIn : Fluid;
			in voltage : VoltageValue;
			out fluidOut : Fluid;
		}

		action def PrimePump {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}

		attribute def PumpStartSignal;
		attribute def PumpStopSignal;
		attribute def HighFlowCommand;
		attribute def LowFlowCommand;
		attribute def NormalFlowCommand;
		attribute def FaultSignal;
		attribute def ResetSignal;

		state def PumpStates;

		part def ElectroosmoticPump {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port voltageInPort : ~ElectricalPort;

			attribute microchannelFull : Boolean;

			part microchannel : Microchannel;
			part anode : Electrode;
			part cathode : Electrode;

			perform action pumpFluid : PumpFluid {
				in fluidIn = fluidInPort.fluid;
				in voltage = voltageInPort.voltage;
				out fluidOut = fluidOutPort.fluid;
			}

			exhibit state pumpStates : PumpStates {
				entry; then idle;
				state idle;
				accept PumpStartSignal then priming;
				state priming {
					do action primePump : PrimePump {
						in fluidIn = fluidInPort.fluid;
						out fluidOut = fluidOutPort.fluid;
					}
				}
				accept when microchannelFull then operating;
				state operating {
					entry; then normal;
					state normal;
					accept HighFlowCommand then highFlow;
					accept LowFlowCommand then lowFlow;
					state highFlow;
					accept NormalFlowCommand then normal;
					accept LowFlowCommand then lowFlow;
					state lowFlow;
					accept NormalFlowCommand then normal;
					accept HighFlowCommand then highFlow;
				}
				accept PumpStopSignal then idle;
				accept FaultSignal then fault;
				state fault;
				accept ResetSignal then idle;
			}
		}

		part def FlowSensor {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute flowRate : FlowRateValue;
		}

		part def PressureSensor {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute pressure : PressureValue;
		}

		requirement def ContinuousOperation {
			doc /* The system shall be capable of operating continuously for extended periods without mechanical wear. */
		}

		requirement def BackPressureHandling {
			doc /* The pump shall maintain fluid transport against a specified maximum back pressure. */
		}

		requirement def FaultSafety {
			doc /* Upon detection of a fault condition, the system shall transition to a safe shutdown state immediately. */
		}
	}

	package Usages {
		private import Definitions::*;

		part context {
			part sourceReservoir : SourceReservoir;
			part pump : ElectroosmoticPump;
			part powerSupply : PowerSupply;
			part collectionChamber : CollectionChamber;
			part flowSensor : FlowSensor;
			part pressureSensor : PressureSensor;

			flow of fluid : Fluid from sourceReservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;
			flow of fluid : Fluid from pump.fluidOutPort.fluid to flowSensor.fluidInPort.fluid;
			flow of fluid : Fluid from flowSensor.fluidOutPort.fluid to pressureSensor.fluidInPort.fluid;
			flow of fluid : Fluid from pressureSensor.fluidOutPort.fluid to collectionChamber.fluidInPort.fluid;

			connection : ElectricalConnection connect powerSupply.voltageOutPort to pump.voltageInPort;

			requirement continuousOp : ContinuousOperation;
			requirement backPressure : BackPressureHandling;
			requirement faultSafety : FaultSafety;
		}
	}
}
