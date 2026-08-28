package 'Condensate Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def Condensate;

		port def FluidOutPort {
			out item condensate : Condensate;
		}

		port def FluidInPort {
			in item condensate : Condensate;
		}

		part def PressureTransmitter {
			attribute pressure : Pressure;
		}

		part def FlowTransmitter {
			attribute flowRate : VolumeFlowRate;
		}

		part def CondensateReceiver {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			attribute currentLevel : Length;
			attribute highLevelSetpoint : Length;
			attribute lowLevelSetpoint : Length;
		}

		part def CondensatePump {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			attribute suctionPressure : Pressure;
			attribute dischargePressure : Pressure;
		}

		part def DischargePiping {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			attribute flowRate : VolumeFlowRate;
		}

		part def StorageTank {
			port fluidInPort : FluidInPort;
			attribute capacity : Volume;
			attribute currentVolume : Volume;
		}

		action def StartMotor;
		action def RunPump;
		action def StopMotor;
		action def CheckFaults;

		attribute def Reset;

		state def PumpStates;

		requirement def TransferCondensate {
			doc /* The system shall transfer condensate from the receiver to the storage tank. */
		}
		requirement def AutomaticControl {
			doc /* The pump shall start and stop automatically based on receiver level. */
		}
		requirement def MonitorPerformance {
			doc /* The system shall monitor inlet/outlet pressure and discharge flow rate. */
		}
	}

	package Usages {
		private import Definitions::*;

		part context {
			part receiver : CondensateReceiver {
				attribute highLevelSetpoint : Length = 0.8 [m];
				attribute lowLevelSetpoint : Length = 0.2 [m];
			}
			part pump : CondensatePump;
			part piping : DischargePiping;
			part storageTank : StorageTank;

			part inletPressureTransmitter : PressureTransmitter;
			part outletPressureTransmitter : PressureTransmitter;
			part flowTransmitter : FlowTransmitter;

			flow of condensate : Condensate
				from receiver.fluidOutPort.condensate to pump.fluidInPort.condensate;

			flow of condensate : Condensate
				from pump.fluidOutPort.condensate to piping.fluidInPort.condensate;

			flow of condensate : Condensate
				from piping.fluidOutPort.condensate to storageTank.fluidInPort.condensate;

			bind inletPressureTransmitter.pressure = pump.suctionPressure;
			bind outletPressureTransmitter.pressure = pump.dischargePressure;
			bind flowTransmitter.flowRate = piping.flowRate;

			exhibit state pumpStates : PumpStates {
				entry; then off;
				state off;
				accept when receiver.currentLevel >= receiver.highLevelSetpoint
					do action startMotor : StartMotor
					then starting;
				state starting;
				accept when pump.dischargePressure > 100000 [Pa]
					do action runPump : RunPump
					then running;
				state running {
					do action runPumpAction : RunPump;
				}
				accept when pump.suctionPressure < 10000 [Pa] or pump.dischargePressure < 50000 [Pa]
					do action checkFaults : CheckFaults
					then faulted;
				accept when receiver.currentLevel <= receiver.lowLevelSetpoint
					do action stopMotor : StopMotor
					then stopping;
				state stopping;
				accept when pump.dischargePressure <= 0 [Pa]
					then off;
				state faulted {
					do action stopMotorAction : StopMotor;
				}
				accept Reset
					then off;
			}

			satisfy TransferCondensate;
			satisfy AutomaticControl by pumpStates;
			satisfy MonitorPerformance by inletPressureTransmitter, outletPressureTransmitter, flowTransmitter;
		}
	}
}
