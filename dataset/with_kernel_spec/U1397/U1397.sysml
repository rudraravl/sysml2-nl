package 'Hydraulic Concrete Pumping Subsystem' {
	private import ISQ::*;
	private import ScalarValues::*;

	package Definitions {
		item def WetConcrete {
			attribute aggregateSize : LengthValue;
			attribute slump : LengthValue;
		}
		item def ElectricalPower;
		item def HydraulicPower;

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def SpeedCommand;
		attribute def ClearFaultCommand;
		attribute def PrimingComplete;
		attribute def ShutdownComplete;
		attribute def CleaningComplete;
		attribute def FaultSignal;

		port def ConcretePort {
			inout item concrete : WetConcrete;
		}
		port def HydraulicPort {
			inout item power : HydraulicPower;
		}
		port def ElectricalPort {
			inout item power : ElectricalPower;
		}
		port def ControlInPort {
			in startCmd : StartCommand;
			in stopCmd : StopCommand;
			in speedCmd : SpeedCommand;
			in clearFault : ClearFaultCommand;
		}
		port def ControlOutPort {
			out startCmd : StartCommand;
			out stopCmd : StopCommand;
			out speedCmd : SpeedCommand;
			out clearFault : ClearFaultCommand;
		}
		port def PressureSignalPort {
			out pressure : PressureValue;
		}
		port def FlowSignalPort {
			out flowRate : VolumeFlowRateValue;
		}

		part def ConcreteHopper {
			attribute level : VolumeValue;
			attribute aggregateSize : LengthValue;
			attribute slump : LengthValue;
			port concreteOut : ConcretePort;
		}

		part def HydraulicPowerPack {
			attribute ratedPower : PowerValue;
			port electricalIn : ElectricalPort;
			port hydraulicOut : HydraulicPort;
		}

		part def ConcretePump {
			attribute maxPressure : PressureValue;
			port concreteIn : ConcretePort;
			port concreteOut : ConcretePort;
			port hydraulicIn : HydraulicPort;
			port controlIn : ControlInPort;
			port pressureTap : ConcretePort;
			port flowTap : ConcretePort;
		}

		part def DeliveryHose {
			attribute length : LengthValue;
			attribute maxPressure : PressureValue;
			port concreteIn : ConcretePort;
			port concreteOut : ConcretePort;
		}

		part def DischargePoint {
			port concreteIn : ConcretePort;
		}

		part def PressureSensor {
			attribute reading : PressureValue;
			port sense : ConcretePort;
			port signalOut : PressureSignalPort;
		}

		part def FlowSensor {
			attribute reading : VolumeFlowRateValue;
			port sense : ConcretePort;
			port signalOut : FlowSignalPort;
		}

		part def PumpController {
			port controlOut : ControlOutPort;
			port pressureIn : PressureSignalPort;
			port flowIn : FlowSignalPort;
			port operatorIn : ControlInPort;
		}

		part def OperatorConsole {
			port commandOut : ControlOutPort;
		}

		part def ElectricalSupply {
			port powerOut : ElectricalPort;
		}

		action def PrimePump;
		action def PumpConcrete {
			in concrete : WetConcrete;
			out pressurizedConcrete : WetConcrete;
		}
		action def CleanCycle;
		action def ShutdownSequence;
		action def MonitorPressure {
			out pressure : PressureValue;
		}
		action def MonitorFlow {
			out flowRate : VolumeFlowRateValue;
		}

		state def PumpLifecycleStates;

		requirement def MaxPressureLimit {
			text: "System pressure must not exceed the maximum rated pressure during operation.";
		}
		requirement def AggregateSizeLimit {
			text: "Concrete aggregate size must not exceed the maximum specified size.";
		}
		requirement def SlumpRange {
			text: "Concrete slump must be within the specified range for workability.";
		}
		requirement def CleaningCycleRequired {
			text: "A cleaning cycle must be executed after every pumping operation or fault before returning to stopped.";
		}
	}

	package Usages {
		private import Definitions::*;

		part hopper : ConcreteHopper;
		part powerPack : HydraulicPowerPack;
		part hose : DeliveryHose;
		part discharge : DischargePoint;
		part controller : PumpController;
		part pressureSensor : PressureSensor;
		part flowSensor : FlowSensor;
		part operatorConsole : OperatorConsole;
		part electricalSupply : ElectricalSupply;

		part pump : ConcretePump {
			exhibit state lifecycle : PumpLifecycleStates {
				entry; then stopped;

				state stopped;
				accept StartCommand
					then priming;

				state priming {
					entry action prime : PrimePump;
				}
				accept PrimingComplete
					then operating;

				state operating {
					do action pumpConcrete : PumpConcrete;
					do action monitorPressure : MonitorPressure;
					do action monitorFlow : MonitorFlow;
				}
				accept when pressureSensor.reading > pump.maxPressure
					do send new FaultSignal() to controller
					then faulted;
				accept StopCommand
					then shutdown;

				state faulted;
				accept ClearFaultCommand
					then shutdown;

				state shutdown {
					entry action shutdownSeq : ShutdownSequence;
				}
				accept ShutdownComplete
					then cleaning;

				state cleaning {
					entry action clean : CleanCycle;
				}
				accept CleaningComplete
					then stopped;
			}
		}

		connect electricalSupply.powerOut to powerPack.electricalIn;
		connect powerPack.hydraulicOut to pump.hydraulicIn;
		connect hopper.concreteOut to pump.concreteIn;
		connect pump.concreteOut to hose.concreteIn;
		connect hose.concreteOut to discharge.concreteIn;
		connect pump.pressureTap to pressureSensor.sense;
		connect pump.flowTap to flowSensor.sense;
		connect pressureSensor.signalOut to controller.pressureIn;
		connect flowSensor.signalOut to controller.flowIn;
		connect operatorConsole.commandOut to controller.operatorIn;
		connect controller.controlOut to pump.controlIn;

		flow electricalSupply.powerOut.power to powerPack.electricalIn.power;
		flow powerPack.hydraulicOut.power to pump.hydraulicIn.power;
		flow hopper.concreteOut.concrete to pump.concreteIn.concrete;
		flow pump.concreteOut.concrete to hose.concreteIn.concrete;
		flow hose.concreteOut.concrete to discharge.concreteIn.concrete;

		satisfy MaxPressureLimit by pump;
		satisfy AggregateSizeLimit by hopper;
		satisfy SlumpRange by hopper;
		satisfy CleaningCycleRequired by pump;
	}
}
