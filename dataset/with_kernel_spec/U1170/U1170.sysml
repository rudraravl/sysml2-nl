package 'PLC System Model' {
	private import ScalarValues::*;
	
	value def Voltage :> Real;
	value def Time :> Real;
	
	unit V;
	unit ms;
	
	attribute def DigitalSignal :> Boolean;
	attribute def AnalogSignal :> Real;
	
	attribute def StartSignal;
	attribute def StopSignal;
	attribute def ResetSignal;
	attribute def FaultSignal;
	
	attribute def UserProgram;
	attribute def ProcessData;
	item def ControlData;
	
	requirement def PLC_Requirement {
		doc /* The system shall be a modular, reliable, and deterministic industrial computer. */
	}
	
	requirement def CPU_Requirement {
		doc /* The CPU shall execute user-defined control programs and store working data. */
	}
	
	requirement def IO_Capacity_Requirement {
		doc /* The system shall handle up to 16 digital and 8 analog inputs and outputs. */
	}
	
	requirement def Scan_Cycle_Requirement {
		doc /* The scan cycle shall complete in under 50 milliseconds. */
		attribute maxCycleTime : Time = 50 [ms];
	}
	
	requirement def State_Machine_Requirement {
		doc /* The PLC shall operate in Stopped, Running, or Error states. */
	}
	
	port def PowerPort {
		attribute voltage : Voltage;
	}
	
	port def CommPort {
		in item dataIn : ControlData;
		out item dataOut : ControlData;
	}
	
	port def DigitalInPort {
		in attribute signal : DigitalSignal;
	}
	
	port def AnalogInPort {
		in attribute signal : AnalogSignal;
	}
	
	port def DigitalOutPort {
		out attribute signal : DigitalSignal;
	}
	
	port def AnalogOutPort {
		out attribute signal : AnalogSignal;
	}
	
	action def ReadInputs;
	action def ExecuteProgram;
	action def UpdateOutputs;
	action def HandleComms;
	
	part def PowerModule {
		attribute inputVoltage : Voltage = 120 [V];
		attribute outputVoltage : Voltage = 24 [V];
		port powerIn : PowerPort;
		port powerOut : PowerPort;
	}
	
	part def InputModule {
		port powerIn : PowerPort;
		port digitalIn[16] : DigitalInPort;
		port analogIn[8] : AnalogInPort;
		port dataOut : CommPort;
	}
	
	part def OutputModule {
		port powerIn : PowerPort;
		port digitalOut[16] : DigitalOutPort;
		port analogOut[8] : AnalogOutPort;
		port dataIn : CommPort;
	}
	
	part def CommunicationInterface {
		port powerIn : PowerPort;
		port ethernet : CommPort;
		port serial : CommPort;
		port plcComm : CommPort;
	}
	
	part def ExternalControlSystem {
		port networkPort : CommPort;
	}
	
	part def CPU {
		port powerIn : PowerPort;
		port inputBus : CommPort;
		port outputBus : CommPort;
		port commBus : CommPort;
		
		attribute program : UserProgram;
		attribute data : ProcessData;
		
		state def CPU_States;
		state cpuStates : CPU_States {
			entry; then Stopped;
			state Stopped;
			accept StartSignal 
				then Running;
			state Running {
				entry; then Read;
				state Read {
					do action ReadInputs;
				}
				transition 
					first Read 
					then Execute;
				state Execute {
					do action ExecuteProgram;
				}
				transition 
					first Execute 
					then Update;
				state Update {
					do action UpdateOutputs;
				}
				transition 
					first Update 
					then Communicate;
				state Communicate {
					do action HandleComms;
				}
				transition 
					first Communicate 
					then Read;
			}
			accept StopSignal 
				then Stopped;
			accept FaultSignal 
				then Error;
			state Error;
			accept ResetSignal 
				then Stopped;
		}
	}
	
	part def PLC {
		part powerSupply : PowerModule;
		part cpu : CPU;
		part inputModule : InputModule;
		part outputModule : OutputModule;
		part commInterface : CommunicationInterface;
		part externalControl : ExternalControlSystem;
		
		connect powerSupply.powerOut to cpu.powerIn;
		connect powerSupply.powerOut to inputModule.powerIn;
		connect powerSupply.powerOut to outputModule.powerIn;
		connect powerSupply.powerOut to commInterface.powerIn;
		
		connect inputModule.dataOut to cpu.inputBus;
		connect cpu.outputBus to outputModule.dataIn;
		connect cpu.commBus to commInterface.plcComm;
		connect commInterface.ethernet to externalControl.networkPort;
	}
	
	part plc : PLC;
	
	satisfy PLC_Requirement by plc;
	satisfy CPU_Requirement by plc.cpu;
	satisfy IO_Capacity_Requirement by plc.inputModule;
	satisfy IO_Capacity_Requirement by plc.outputModule;
	satisfy Scan_Cycle_Requirement by plc;
	satisfy State_Machine_Requirement by plc;
}
