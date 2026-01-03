package 'Programmable Logic Controller System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def DigitalInput {
		attribute value : Boolean;
		attribute address : Integer;
	}
	
	item def DigitalOutput {
		attribute value : Boolean;
		attribute address : Integer;
	}
	
	item def AnalogInput {
		attribute value : Real;
		attribute unit : String;
		attribute address : Integer;
	}
	
	item def AnalogOutput {
		attribute value : Real;
		attribute unit : String;
		attribute address : Integer;
	}
	
	attribute def CycleTime :> ISQ::DurationValue;
	
	port def DigitalInputPort {
		in item signal : DigitalInput;
	}
	
	port def DigitalOutputPort {
		out item signal : DigitalOutput;
	}
	
	port def AnalogInputPort {
		in item signal : AnalogInput;
	}
	
	port def AnalogOutputPort {
		out item signal : AnalogOutput;
	}
	
	port def NetworkPort {
		in item commandReceived : DigitalInput;
		out item statusSent : DigitalOutput;
	}
	
	part def InputModule {
		port digitalIn : DigitalInputPort[16];
		port analogIn : AnalogInputPort[8];
		
		attribute scanRate : CycleTime;
		
		perform action acquireInputs {
			out digitalData : Boolean[16];
			out analogData : Real[8];
		}
	}
	
	part def OutputModule {
		port digitalOut : DigitalOutputPort[16];
		port analogOut : AnalogOutputPort[8];
		
		perform action updateOutputs {
			in digitalCommands : Boolean[16];
			in analogCommands : Real[8];
		}
	}
	
	part def CentralProcessingUnit {
		attribute cycleTime : CycleTime;
		attribute programMemory : Integer;
		attribute dataMemory : Integer;
		
		perform action executeUserProgram {
			in inputData : Real[*];
			in programCode : String;
			out outputData : Real[*];
		}
	}
	
	part def CommunicationInterface {
		port ethernet : NetworkPort;
		port serial : NetworkPort;
		
		perform action exchangeData {
			in externalData : DigitalInput[*];
			out systemStatus : DigitalOutput[*];
		}
	}
	
	part def PowerModule {
		attribute inputVoltage : ISQ::VoltageValue;
		attribute outputVoltage : ISQ::VoltageValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		
		perform action supplyPower {
			in demand : ISQ::PowerValue;
			out supplied : ISQ::PowerValue;
		}
	}
	
	action def ScanInputs {
		in cycleTime : CycleTime;
		out digitalInputs : Boolean[*];
		out analogInputs : Real[*];
	}
	
	action def ProcessLogic {
		in digitalInputs : Boolean[*];
		in analogInputs : Real[*];
		in controlProgram : String;
		out digitalOutputs : Boolean[*];
		out analogOutputs : Real[*];
	}
	
	action def UpdateOutputs {
		in digitalOutputs : Boolean[*];
		in analogOutputs : Real[*];
	}
	
	action def CommunicateStatus {
		in systemData : Real[*];
		out messages : DigitalOutput[*];
	}
	
	action def PLCScanCycle {
		first start;
		then merge cycleStart;
		
		then action inputScan : ScanInputs {
			in cycleTime;
			out digitalInputs;
			out analogInputs;
		}
		
		then action programExecution : ProcessLogic {
			in digitalInputs = inputScan.digitalInputs;
			in analogInputs = inputScan.analogInputs;
			in controlProgram;
			out digitalOutputs;
			out analogOutputs;
		}
		
		then action outputUpdate : UpdateOutputs {
			in digitalOutputs = programExecution.digitalOutputs;
			in analogOutputs = programExecution.analogOutputs;
		}
		
		then action communication : CommunicateStatus {
			in systemData;
			out messages;
		}
		
		then decide;
			if operationEnabled then cycleStart;
			if not operationEnabled then halt;
		
		action halt;
		then done;
		
		private attribute operationEnabled : Boolean;
		private attribute cycleTime : CycleTime;
		private attribute controlProgram : String;
		private attribute systemData : Real[*];
	}
	
	item def StartSignal;
	item def StopSignal;
	item def FaultSignal;
	item def ResetSignal;
	
	state def PLCOperationalStates {
		entry; then stopped;
		
		state stopped {
			entry assign mode := "Stopped";
		}
		
		transition stopped_to_running
			first stopped
			accept startCmd : StartSignal
			then running;
		
		state running {
			entry assign mode := "Running";
			do action scanOperation : PLCScanCycle;
		}
		
		transition running_to_error
			first running
			accept faultEvent : FaultSignal
			then error;
		
		state error {
			entry assign mode := "Error";
			do action diagnostics;
		}
		
		transition error_to_stopped
			first error
			accept resetCmd : ResetSignal
			then stopped;
		
		transition running_to_stopped
			first running
			accept stopCmd : StopSignal
			then stopped;
		
		private attribute mode : String;
		
		action def diagnostics;
	}
	
	part def ProgrammableLogicController;
	
	part plcController : ProgrammableLogicController {
		attribute systemIdentifier : String := "PLC-100";
		attribute nominalScanTime : CycleTime;
		attribute operationalMode : String;
		
		part inputs : InputModule {
			attribute :>> scanRate = plcController.nominalScanTime;
		}
		
		part outputs : OutputModule;
		
		part processor : CentralProcessingUnit {
			attribute :>> cycleTime = plcController.nominalScanTime;
			attribute :>> programMemory = 256000;
			attribute :>> dataMemory = 128000;
		}
		
		part communications : CommunicationInterface;
		
		part power : PowerModule {
			attribute :>> inputVoltage = 120.0 [SI::V];
			attribute :>> outputVoltage = 24.0 [SI::V];
			attribute :>> maxCurrent = 5.0 [SI::A];
		}
		
		connection inputToProcessor connect inputs.digitalIn to processor;
		connection processorToOutput connect processor to outputs.digitalOut;
		connection processorToComm connect processor to communications.ethernet;
		connection powerToInputs connect power to inputs;
		connection powerToProcessor connect power to processor;
		connection powerToOutputs connect power to outputs;
		connection powerToComm connect power to communications;
		
		perform action mainCycle : PLCScanCycle;
		
		exhibit state operationalBehavior : PLCOperationalStates;
	}
	
	requirement def PLCSystemRequirements {
		doc /* 
			The Programmable Logic Controller system shall provide reliable 
			industrial automation control through continuous monitoring of 
			input devices and deterministic control of output devices.
		*/
		
		subject plcController : ProgrammableLogicController;
		
		require scanPerformanceRequirement;
		require systemReliabilityRequirement;
		require communicationCapabilityRequirement;
	}
	
	requirement <'PLC-REQ-001'> scanPerformanceRequirement {
		doc /* 
			The PLC shall execute a complete scan cycle including input reading,
			program execution, and output updating within the specified nominal
			scan time under normal operating conditions.
		*/
		
		subject plc : ProgrammableLogicController;
		
		assume constraint normalOperatingConditions {
			doc /* System operates within rated environmental and electrical specifications */
		}
		
		require constraint maximumScanTime {
			plc.nominalScanTime <= 50.0 [SI::ms]
		}
	}
	
	requirement <'PLC-REQ-002'> systemReliabilityRequirement {
		doc /* 
			The PLC shall provide continuous operation with automatic fault
			detection, error logging, and safe shutdown capabilities.
		*/
		
		subject plc : ProgrammableLogicController;
		
		require constraint faultDetectionCapability {
			doc /* System shall detect hardware and software faults within one scan cycle */
		}
		
		require constraint safeStateTransition {
			doc /* System shall transition to safe state within 100 milliseconds of fault detection */
		}
	}
	
	requirement <'PLC-REQ-003'> communicationCapabilityRequirement {
		doc /* 
			The PLC shall support bidirectional communication with supervisory
			control systems and peer devices using standard industrial protocols.
		*/
		
		subject plc : ProgrammableLogicController;
		
		require constraint protocolSupport {
			doc /* Support Ethernet/IP, Modbus TCP, and Profinet protocols */
		}
		
		require constraint communicationLatency {
			doc /* Network communication latency shall not exceed 20 milliseconds */
		}
	}
	
	requirement primarySystemFunction : PLCSystemRequirements {
		doc /* 
			The Programmable Logic Controller system provides deterministic industrial
			automation control by executing a continuous scan cycle that reads digital
			and analog input signals from field sensors and devices, processes these
			inputs according to user-programmed control logic stored in program memory,
			generates appropriate digital and analog output commands to control actuators
			and field devices, and maintains real-time communication with supervisory
			systems and peer controllers, all while ensuring reliable fault-tolerant
			operation and predictable response times for critical control applications.
		*/
		
		subject :>> plcController;
	}
}
