package 'Generalized Automation Language System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SequenceFunctions::*;

    attribute def ProgramCode;
    attribute def InstructionSet;
    attribute def VariableTable;
    attribute def ExecutionContext;
    
    attribute def CycleTime :> TimeValue;
    attribute def ScanRate :> FrequencyValue;
    attribute def MemorySize :> Integer;
    attribute def ProcessValue :> Real;
    attribute def DigitalState :> Boolean;
    
    enum def ExecutionMode {
        run;
        stop;
        pause;
        step;
    }
    
    enum def SystemState {
        idle;
        initializing;
        running;
        paused;
        faulted;
        stopped;
    }
    
    port def AnalogInputPort {
        in attribute value : ProcessValue;
        attribute channelID : Integer;
        attribute scalingFactor : Real;
        attribute offset : Real;
    }
    
    port def AnalogOutputPort {
        out attribute value : ProcessValue;
        attribute channelID : Integer;
        attribute range : Real;
    }
    
    port def DiscreteInputPort {
        in attribute signalState : DigitalState;
        attribute channelID : Integer;
    }
    
    port def DiscreteOutputPort {
        out attribute signalState : DigitalState;
        attribute channelID : Integer;
    }
    
    port def CommunicationPort {
        in attribute receivedData : String;
        out attribute transmittedData : String;
        attribute protocol : String;
        attribute address : String;
    }
    
    part def InputModule {
        port analogInputs : AnalogInputPort[16];
        port discreteInputs : DiscreteInputPort[32];
        attribute moduleID : String;
        attribute scanTime : CycleTime;
    }
    
    part def OutputModule {
        port analogOutputs : AnalogOutputPort[16];
        port discreteOutputs : DiscreteOutputPort[32];
        attribute moduleID : String;
        attribute updateRate : ScanRate;
    }
    
    part def ProcessorModule {
        attribute cpuSpeed : FrequencyValue;
        attribute memoryCapacity : MemorySize;
        attribute programMemory : ProgramCode;
        attribute dataMemory : VariableTable;
    }
    
    part def CommunicationModule {
        port ethernet : CommunicationPort;
        port serial : CommunicationPort;
        port fieldbus : CommunicationPort;
        attribute networkAddress : String;
    }
    
    action def ScanInputs {
        in inputModule : InputModule;
        out analogValues : ProcessValue[*];
        out discreteStates : DigitalState[*];
    }
    
    action def ExecuteProgram {
        in programCode : ProgramCode;
        in analogInputs : ProcessValue[*];
        in discreteInputs : DigitalState[*];
        in variables : VariableTable;
        out analogOutputs : ProcessValue[*];
        out discreteOutputs : DigitalState[*];
        out updatedVariables : VariableTable;
    }
    
    action def UpdateOutputs {
        in outputModule : OutputModule;
        in analogCommands : ProcessValue[*];
        in discreteCommands : DigitalState[*];
    }
    
    action def HandleCommunications {
        in commModule : CommunicationModule;
        in outgoingMessages : String[*];
        out incomingMessages : String[*];
    }
    
    action def PerformDiagnostics {
        in processor : ProcessorModule;
        in inputs : InputModule;
        in outputs : OutputModule;
        out healthStatus : SystemState;
        out faultCodes : Integer[*];
    }
    
    action def AutomationScanCycle {
        in cycleTime : CycleTime;
        in program : ProgramCode;
        in inputMod : InputModule;
        in outputMod : OutputModule;
        in commMod : CommunicationModule;
        in processorMod : ProcessorModule;
        out cycleStatus : SystemState;
        
        private attribute currentVariables : VariableTable;
        
        first start;
        then action scanPhase : ScanInputs {
            in inputModule = inputMod;
            out analogValues;
            out discreteStates;
        }
        then action executePhase : ExecuteProgram {
            in programCode = program;
            in analogInputs = scanPhase.analogValues;
            in discreteInputs = scanPhase.discreteStates;
            in variables = currentVariables;
            out analogOutputs;
            out discreteOutputs;
            out updatedVariables;
        }
        then assign currentVariables := executePhase.updatedVariables;
        then action updatePhase : UpdateOutputs {
            in outputModule = outputMod;
            in analogCommands = executePhase.analogOutputs;
            in discreteCommands = executePhase.discreteOutputs;
        }
        then action commPhase : HandleCommunications {
            in commModule = commMod;
            in outgoingMessages;
            out incomingMessages;
        }
        then action diagnosticPhase : PerformDiagnostics {
            in processor = processorMod;
            in inputs = inputMod;
            in outputs = outputMod;
            out healthStatus;
            out faultCodes;
        }
        then assign cycleStatus := diagnosticPhase.healthStatus;
        then done;
    }
    
    attribute def StartCommand;
    attribute def InitComplete;
    attribute def InitFault;
    attribute def PauseCommand;
    attribute def StopCommand;
    attribute def FaultDetected;
    attribute def ResumeCommand;
    attribute def ResetCommand;
    attribute def ClearFault;
    
    state def ControllerStateMachine {
        entry; then idle;
        
        state idle {
            entry assign operatingState := SystemState::idle;
        }
        
        transition idle_to_init
            first idle
            accept startCommand : StartCommand
            then initializing;
        
        state initializing {
            entry assign operatingState := SystemState::initializing;
            do action initializeSystem;
        }
        
        transition init_to_running
            first initializing
            accept initComplete : InitComplete
            then running;
        
        transition init_to_fault
            first initializing
            accept initFault : InitFault
            then faulted;
        
        state running {
            entry assign operatingState := SystemState::running;
            do action executeScanCycle;
        }
        
        transition running_to_paused
            first running
            accept pauseCommand : PauseCommand
            then paused;
        
        transition running_to_stopped
            first running
            accept stopCommand : StopCommand
            then stopped;
        
        transition running_to_fault
            first running
            accept faultDetected : FaultDetected
            then faulted;
        
        state paused {
            entry assign operatingState := SystemState::paused;
        }
        
        transition paused_to_running
            first paused
            accept resumeCommand : ResumeCommand
            then running;
        
        transition paused_to_stopped
            first paused
            accept stopCommand : StopCommand
            then stopped;
        
        state stopped {
            entry assign operatingState := SystemState::stopped;
            do action shutdownSystem;
        }
        
        transition stopped_to_idle
            first stopped
            accept resetCommand : ResetCommand
            then idle;
        
        state faulted {
            entry assign operatingState := SystemState::faulted;
            do action handleFault;
        }
        
        transition fault_to_idle
            first faulted
            accept clearFault : ClearFault
            then idle;
        
        attribute operatingState : SystemState;
    }
    
    part def AutomationController {
        attribute controllerID : String;
        attribute firmwareVersion : String;
        attribute scanCycleTime : CycleTime;
        attribute currentMode : ExecutionMode;
        
        part processor : ProcessorModule {
            attribute cpuSpeed = 1000.0;
            attribute memoryCapacity = 512;
        }
        
        part inputIO : InputModule[1..4] {
            attribute scanTime = 10.0;
        }
        
        part outputIO : OutputModule[1..4] {
            attribute updateRate = 100.0;
        }
        
        part communications : CommunicationModule {
            attribute networkAddress = "192.168.1.100";
        }
        
        perform action scanCycle : AutomationScanCycle[*] {
            in cycleTime = scanCycleTime;
            in program = processor.programMemory;
            in inputMod = inputIO[1];
            in outputMod = outputIO[1];
            in commMod = communications;
            in processorMod = processor;
            out cycleStatus;
        }
        
        exhibit state controllerBehavior : ControllerStateMachine;
    }
    
    part def FieldSensor {
        port output : AnalogOutputPort;
        attribute sensorType : String;
        attribute measurementRange : Real;
        attribute accuracy : Real;
    }
    
    part def FieldActuator {
        port input : AnalogInputPort;
        attribute actuatorType : String;
        attribute controlRange : Real;
        attribute responseTime : TimeValue;
    }
    
    requirement def AutomationSystemRequirements {
        doc /* The automation system shall execute control programs in a deterministic, 
               cyclic manner to coordinate industrial process control. */
        
        requirement <'ASR-001'> deterministicExecution {
            doc /* The system shall complete each scan cycle within the configured cycle time. */
            subject controller : AutomationController;
            require constraint {
                controller.scanCycle.cycleTime <= controller.scanCycleTime
            }
        }
        
        requirement <'ASR-002'> programExecution {
            doc /* The system shall execute user-defined control programs written in 
                   the generalized automation language. */
            subject controller : AutomationController;
        }
        
        requirement <'ASR-003'> ioProcessing {
            doc /* The system shall read all inputs, execute control logic, and 
                   update all outputs in each scan cycle. */
            subject controller : AutomationController;
        }
        
        requirement <'ASR-004'> communicationSupport {
            doc /* The system shall support multiple communication protocols for 
                   data exchange and remote monitoring. */
            subject controller : AutomationController;
        }
        
        requirement <'ASR-005'> faultDetection {
            doc /* The system shall detect faults and transition to a safe state 
                   while logging diagnostic information. */
            subject controller : AutomationController;
        }
        
        requirement <'ASR-006'> stateManagement {
            doc /* The system shall support multiple operating modes including 
                   run, stop, pause, and step. */
            subject controller : AutomationController;
        }
    }
    
    part industrialAutomationSystem {
        part controller : AutomationController {
            attribute controllerID = "PLC-001";
            attribute firmwareVersion = "2.5.3";
            attribute scanCycleTime = 20.0;
            attribute currentMode = ExecutionMode::run;
        }
        
        part temperatureSensor : FieldSensor[8] {
            attribute sensorType = "Thermocouple";
            attribute measurementRange = 1000.0;
            attribute accuracy = 0.5;
        }
        
        part pressureSensor : FieldSensor[4] {
            attribute sensorType = "Pressure Transducer";
            attribute measurementRange = 500.0;
            attribute accuracy = 0.25;
        }
        
        part controlValve : FieldActuator[6] {
            attribute actuatorType = "Pneumatic Control Valve";
            attribute controlRange = 100.0;
            attribute responseTime = 200.0;
        }
        
        part motorDrive : FieldActuator[3] {
            attribute actuatorType = "Variable Frequency Drive";
            attribute controlRange = 60.0;
            attribute responseTime = 50.0;
        }
        
        connection sensorConnection1 connect temperatureSensor[1].output to controller.inputIO[1].analogInputs[1];
        connection sensorConnection2 connect temperatureSensor[2].output to controller.inputIO[1].analogInputs[2];
        connection sensorConnection3 connect pressureSensor[1].output to controller.inputIO[1].analogInputs[3];
        
        connection actuatorConnection1 connect controller.outputIO[1].analogOutputs[1] to controlValve[1].input;
        connection actuatorConnection2 connect controller.outputIO[1].analogOutputs[2] to controlValve[2].input;
        connection actuatorConnection3 connect controller.outputIO[1].analogOutputs[3] to motorDrive[1].input;
    }
    
    requirement systemMission : AutomationSystemRequirements {
        assume constraint validCycleTime {
            industrialAutomationSystem.controller.scanCycleTime > 0.0
        }
        require deterministicExecution;
        require programExecution;
        require ioProcessing;
        require communicationSupport;
        require faultDetection;
        require stateManagement;
    }
}
