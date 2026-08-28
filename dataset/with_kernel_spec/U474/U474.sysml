package 'Automated Bilge Pumping System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		item def Water;

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def FaultSignal;
		attribute def ResetCommand;
		attribute def PrimingComplete;

		port def WaterFlowPort {
			inout water : Water;
		}
		port def PowerPort {
			inout power : ElectricPotential;
		}
		port def CommandPort {
			inout start : StartCommand;
			inout stop : StopCommand;
		}
		port def FaultPort {
			out fault : FaultSignal;
		}

		action def PrimePump;
		action def PumpWater;
		action def SignalError;

		part def BilgeCompartment {
			attribute waterLevel : Length;
			port waterOut : WaterFlowPort;
		}

		part def DischargeOutlet {
			port waterIn : WaterFlowPort;
		}

		part def PowerSupply {
			attribute voltage : ElectricPotential = 12 [V];
			port powerOut : PowerPort;
		}

		part def FloatSwitch {
			attribute highWaterMark : Length = 0.5 [m];
			attribute lowWaterMark : Length = 0.1 [m];
			port cmdOut : CommandPort;
			exhibit state floatSwitchStates : FloatSwitchStates;
		}

		part def PumpController;

		part def BilgePump {
			attribute primingDuration : Duration = 2 [s];
			attribute maxBackPressure : Pressure = 50000 [Pa];
			attribute dryRunDetected : Boolean;
			attribute overPressureDetected : Boolean;
			part controller : PumpController;
			port waterIn : WaterFlowPort;
			port waterOut : WaterFlowPort;
			port powerIn : PowerPort;
			port cmdIn : CommandPort;
			port faultOut : FaultPort;
			exhibit state pumpStates : PumpStates;
		}

		state def FloatSwitchStates;
		state def PumpStates;
		state def ControllerStates;

		requirement def AutoPumpingRequirement {
			doc /* The system shall automatically pump out bilge water when the water level reaches the high-water mark. */
		}
		requirement def FaultShutdownRequirement {
			doc /* The pump shall shut down upon detection of dry-run or excessive back-pressure conditions. */
		}
		requirement def LowWaterStopRequirement {
			doc /* The pump shall stop pumping when the water level drops to the low-water mark. */
		}
		requirement def StandbyRequirement {
			doc /* The system shall return to a standby state ready for the next pumping cycle after operation. */
		}
		requirement def PowerSupplyRequirement {
			doc /* The pump shall operate on a 12-volt DC power supply provided by the vessel power system. */
		}
	}

	package Usages {
		private import Definitions::*;

		action primePump : PrimePump;
		action pumpWater : PumpWater;
		action signalError : SignalError;

		part bilgeSystem {
			part compartment : BilgeCompartment;
			part floatSwitch : FloatSwitch;
			part pump : BilgePump;
			part power : PowerSupply;
			part outlet : DischargeOutlet;

			connect compartment.waterOut to pump.waterIn;
			connect pump.waterOut to outlet.waterIn;
			connect power.powerOut to pump.powerIn;
			connect floatSwitch.cmdOut to pump.cmdIn;
		}

		state floatSwitchStates : FloatSwitchStates {
			in compartment : BilgeCompartment;
			in floatSwitch : FloatSwitch;
			in pump : BilgePump;
			entry; then inactive;
			state inactive;
			accept when compartment.waterLevel >= floatSwitch.highWaterMark
				do send new StartCommand() to pump
				then active;
			state active;
			accept when compartment.waterLevel <= floatSwitch.lowWaterMark
				do send new StopCommand() to pump
				then inactive;
		}

		state pumpStates : PumpStates {
			in pump : BilgePump;
			entry; then standby;
			state standby;
			accept StartCommand
				then priming;
			state priming;
			accept after 2 [s]
				then running;
			state running {
				do pumpWater;
			}
			accept when pump.dryRunDetected or pump.overPressureDetected
				do send new FaultSignal() to pump.controller
				then faulted;
			accept StopCommand
				then standby;
			state faulted {
				entry signalError;
			}
			accept ResetCommand
				then standby;
		}

		state controllerStates : ControllerStates {
			in controller : PumpController;
			entry; then normal;
			state normal;
			accept FaultSignal
				then faulted;
			state faulted;
			accept ResetCommand
				then normal;
		}

		satisfy AutoPumpingRequirement by floatSwitchStates;
		satisfy LowWaterStopRequirement by floatSwitchStates;
		satisfy FaultShutdownRequirement by pumpStates;
		satisfy StandbyRequirement by pumpStates;
		satisfy PowerSupplyRequirement by bilgeSystem.power;
	}
}
