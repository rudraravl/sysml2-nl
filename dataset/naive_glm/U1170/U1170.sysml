package PLCSystem {
    import ScalarValues::*;

    // =========================================================================
    // Value Types (units)
    // =========================================================================

    attribute def Voltage :> Real {
        doc "Electric potential difference, measured in Volts (V)";
    }

    attribute def Current :> Real {
        doc "Electric current, measured in Amperes (A)";
    }

    attribute def Power :> Real {
        doc "Electric power, measured in Watts (W)";
    }

    attribute def Frequency :> Real {
        doc "Frequency, measured in Hertz (Hz)";
    }

    attribute def TimeMs :> Real {
        doc "Time, measured in milliseconds (ms)";
    }

    attribute def DataRate :> Real {
        doc "Data rate, measured in Megabits per second (Mbps)";
    }

    attribute def BaudRate :> Real {
        doc "Serial baud rate, measured in bits per second (bps)";
    }

    attribute def ScanTime :> Real {
        doc "PLC scan cycle duration, measured in milliseconds (ms)";
    }

    // =========================================================================
    // Items
    // =========================================================================

    item def DigitalSignal {
        attribute signalId : Integer;
        attribute value : Boolean;
        attribute active : Boolean;
        attribute timestamp : TimeMs;
    }

    item def AnalogSignal {
        attribute signalId : Integer;
        attribute scaledValue : Real [0.0 .. 100.0];
        attribute rawValue : Real;
        attribute unitScale : String;
        attribute timestamp : TimeMs;
    }

    item def ControlProgram {
        attribute instructions : String;
        attribute compiled : Boolean;
        attribute checksum : String;
        attribute version : Integer;
        attribute sizeBytes : Integer;
    }

    item def ProgramData {
        attribute values : String;
        attribute lastUpdated : TimeMs;
        attribute retained : Boolean;
    }

    item def DiagnosticReport {
        attribute code : Integer;
        attribute description : String;
        attribute severity : String;
        attribute timestamp : TimeMs;
    }

    item def NetworkMessage {
        attribute payload : String;
        attribute source : String;
        attribute destination : String;
        attribute sequenceNumber : Integer;
    }

    // =========================================================================
    // Ports
    // =========================================================================

    port def DigitalInputPort {
        doc "Single digital (on/off) input port";
        attribute signalId : Integer;
        attribute value : Boolean;
        attribute active : Boolean;
    }

    port def AnalogInputPort {
        doc "Single analog (variable-level) input port";
        attribute signalId : Integer;
        attribute scaledValue : Real [0.0 .. 100.0];
        attribute rangeMin : Real;
        attribute rangeMax : Real;
    }

    port def DigitalOutputPort {
        doc "Single digital output port driven to external equipment";
        attribute signalId : Integer;
        attribute value : Boolean;
        attribute driveCurrent : Current;
    }

    port def AnalogOutputPort {
        doc "Single analog output port for variable-level control";
        attribute signalId : Integer;
        attribute scaledValue : Real [0.0 .. 100.0];
        attribute rangeMin : Real;
        attribute rangeMax : Real;
    }

    port def PowerInputPort {
        doc "Power input port";
        attribute voltage : Voltage;
        attribute maxCurrent : Current;
    }

    port def PowerOutputPort {
        doc "Regulated DC power output port";
        attribute voltage : Voltage;
        attribute maxCurrent : Current;
    }

    port def EthernetCommPort {
        doc "Ethernet network interface port";
        attribute ipAddress : String;
        attribute portNumber : Integer;
        attribute dataRate : DataRate;
    }

    port def SerialCommPort {
        doc "RS-232 / RS-485 serial port";
        attribute baudRate : BaudRate;
        attribute parity : String;
        attribute stopBits : Integer;
    }

    port def BackplanePort {
        doc "Internal backplane data interface between modules";
        attribute slotAddress : Integer;
    }

    // =========================================================================
    // Connections
    // =========================================================================

    connection def BackplaneLink {
        doc "Internal backplane data link between PLC modules";
        end source : BackplanePort;
        end target : BackplanePort;
    }

    connection def PowerLink {
        doc "Internal DC power distribution link";
        end source : PowerOutputPort;
        end target : PowerInputPort;
    }

    // =========================================================================
    // Action Definitions
    // =========================================================================

    action def ReadInputs {
        doc "Read and buffer all digital and analog input signals";
        in digitalPorts : DigitalInputPort[*];
        in analogPorts : AnalogInputPort[*];
        out digitalImage : DigitalSignal[*];
        out analogImage : AnalogSignal[*];
    }

    action def ExecuteControlProgram {
        doc "Execute the user's control program against the input image";
        in program : ControlProgram;
        in inputDigital : DigitalSignal[*];
        in inputAnalog : AnalogSignal[*];
        out outputDigital : DigitalSignal[*];
        out outputAnalog : AnalogSignal[*];
    }

    action def UpdateOutputs {
        doc "Drive output ports from the output image";
        in outputDigital : DigitalSignal[*];
        in outputAnalog : AnalogSignal[*];
    }

    action def HandleCommunications {
        doc "Exchange network messages with central control system";
        in incomingMessages : NetworkMessage[*];
        out outgoingMessages : NetworkMessage[*];
    }

    action def ScanCycle {
        doc "One complete PLC scan cycle: read inputs, execute program, update outputs, then handle communications";
        action read : ReadInputs;
        action execute : ExecuteControlProgram;
        action writeOutputs : UpdateOutputs;
        action communicate : HandleCommunications;

        flow from read.digitalImage to execute.inputDigital;
        flow from read.analogImage to execute.inputAnalog;
        flow from execute.outputDigital to writeOutputs.outputDigital;
        flow from execute.outputAnalog to writeOutputs.outputAnalog;
    }

    action def ACtoDCConversion {
        doc "Convert 120V AC input into regulated 24V DC";
        in inputAC : Voltage;
        out outputDC : Voltage;
    }

    action def LogFault {
        doc "Record a diagnostic report when a fault is detected";
        in code : Integer;
        out report : DiagnosticReport;
    }

    // =========================================================================
    // Subsystem parts
    // =========================================================================

    part def Memory {
        doc "Generic memory component";
        attribute capacity : Integer;
        attribute type : String;
    }

    part def ProgramMemory :> Memory {
        doc "Non-volatile memory storing the user-defined control program";
        redefines type = "NAND Flash";
        attribute program : ControlProgram;
        attribute protected : Boolean = true;
    }

    part def DataMemory :> Memory {
        doc "Volatile memory holding the data the program is currently working with";
        redefines type = "SRAM";
        attribute data : ProgramData;
    }

    // -- CPU --
    part def CPU {
        doc "Central Processing Unit - the brain of the PLC, containing program and working data memory";
        attribute clockRate : Frequency;
        attribute currentScanTime : ScanTime;
        attribute maxScanTime : ScanTime = 50;
        attribute faultDetected : Boolean = false;
        attribute lastDiagnostic : DiagnosticReport;
        attribute userProgram : ControlProgram;
        attribute programCounter : Integer;
        attribute watchdogEnabled : Boolean = true;

        port backplane : BackplanePort;
        port powerIn : PowerInputPort;

        part programStorage : ProgramMemory {
            redefines capacity = 262144;
        }
        part dataStorage : DataMemory {
            redefines capacity = 131072;
        }

        item inputImageDigital : DigitalSignal[16];
        item inputImageAnalog : AnalogSignal[8];
        item outputImageDigital : DigitalSignal[16];
        item outputImageAnalog : AnalogSignal[8];

        action executeScan : ScanCycle;
        action logFault : LogFault;

        exhibit state machine {
            initial state Initializing {
                entry / initializeHardware();
                do / loadProgram();
            }
            state Stopped {
                entry / freezeOutputs();
                do / awaitCommands();
            }
            state Running {
                entry / startScanTimer();
                do / executeScan;
                exit / recordScanTime();
            }
            state Error {
                entry / logFault();
                do / awaitReset();
                exit / clearFault();
            }

            transition from Initializing to Stopped when initComplete();
            transition from Stopped to Running when startCommand();
            transition from Running to Stopped when stopCommand();
            transition from Running to Error when faultDetected == true;
            transition from Error to Stopped when resetCommand();
        }
    }

    // -- Input Module --
    part def InputModule {
        doc "Input module - connection to the outside world for reading sensors and switches; handles 16 digital and 8 analog signals";
        attribute id : String;
        attribute maxDigitalInputs : Integer = 16;
        attribute maxAnalogInputs : Integer = 8;
        attribute samplingInterval : TimeMs = 1;
        attribute opticalIsolation : Boolean = true;
        attribute activeDigitalCount : Integer;
        attribute activeAnalogCount : Integer;

        port digitalInputs[16] : DigitalInputPort;
        port analogInputs[8] : AnalogInputPort;
        port backplane : BackplanePort;
        port powerIn : PowerInputPort;

        item digitalBuffer[16] : DigitalSignal;
        item analogBuffer[8] : AnalogSignal;

        action refreshInputs : ReadInputs;
    }

    // -- Output Module --
    part def OutputModule {
        doc "Output module - sends control commands to external equipment; 16 digital outputs and 8 analog outputs";
        attribute id : String;
        attribute maxDigitalOutputs : Integer = 16;
        attribute maxAnalogOutputs : Integer = 8;
        attribute maxDigitalCurrent : Current = 2;
        attribute faultProtected : Boolean = true;
        attribute activeDigitalCount : Integer;
        attribute activeAnalogCount : Integer;

        port digitalOutputs[16] : DigitalOutputPort;
        port analogOutputs[8] : AnalogOutputPort;
        port backplane : BackplanePort;
        port powerIn : PowerInputPort;

        item digitalBuffer[16] : DigitalSignal;
        item analogBuffer[8] : AnalogSignal;

        action driveOutputs : UpdateOutputs;
    }

    // -- Power Module --
    part def PowerModule {
        doc "Power module - converts 120V AC input into stable 24V DC for all other components";
        attribute id : String;
        attribute inputVoltage : Voltage = 120;
        attribute outputVoltage : Voltage = 24;
        attribute outputCurrent : Current;
        attribute efficiency : Real [0.0 .. 1.0] = 0.92;
        attribute thermalShutdownThreshold : TimeMs;
        attribute active : Boolean = true;
        attribute inputType : String = "AC";

        port acInput : PowerInputPort;
        port dc0 : PowerOutputPort;
        port dc1 : PowerOutputPort;
        port dc2 : PowerOutputPort;
        port dc3 : PowerOutputPort;
        port backplane : BackplanePort;

        action convert : ACtoDCConversion;
    }

    // -- Communication Interface --
    part def CommunicationInterface {
        doc "Communication interface - enables network connectivity via Ethernet and serial ports";
        attribute id : String;
        attribute macAddress : String;
        attribute ipAddress : String;
        attribute activeConnections : Integer;
        attribute protocol : String;
        attribute encryptionEnabled : Boolean = false;

        port ethernet : EthernetCommPort;
        port serial : SerialCommPort;
        port backplane : BackplanePort;
        port powerIn : PowerInputPort;

        action exchangeMessages : HandleCommunications;
    }

    // =========================================================================
    // Top-level PLC assembly
    // =========================================================================

    part def PLC {
        doc "Programmable Logic Controller - modular, high-speed, deterministic industrial computer for automation and control";
        attribute modelNumber : String = "PLC-1000";
        attribute serialNumber : String;
        attribute firmwareVersion : String = "1.4.2";
        attribute systemStatus : String;
        attribute maxScanTime : ScanTime = 50;
        attribute operatingTemperature : Real;

        // ---- Internal modules ----
        part powerSupply : PowerModule {
            redefines id = "PS-24V-10A";
            redefines inputVoltage = 120;
            redefines outputVoltage = 24;
            redefines outputCurrent = 10;
        }

        part processor : CPU {
            redefines clockRate = 100;
            redefines maxScanTime = 50;
        }

        part inputs : InputModule {
            redefines id = "IM-16D8A";
            redefines samplingInterval = 1;
        }

        part outputs : OutputModule {
            redefines id = "OM-16D8A";
            redefines maxDigitalCurrent = 2;
        }

        part comms : CommunicationInterface {
            redefines id = "CI-ETH-RS232";
            redefines macAddress = "00:80:A3:01:00:00";
            redefines ipAddress = "192.168.1.10";
            redefines protocol = "Modbus TCP";
        }

        // ---- External interface ports of the PLC ----
        port extDigitalIn[16] : DigitalInputPort;
        port extAnalogIn[8] : AnalogInputPort;
        port extDigitalOut[16] : DigitalOutputPort;
        port extAnalogOut[8] : AnalogOutputPort;
        port extPowerIn : PowerInputPort;
        port extEthernet : EthernetCommPort;
        port extSerial : SerialCommPort;

        // Bind external ports to internal module ports
        bind extDigitalIn = inputs.digitalInputs;
        bind extAnalogIn = inputs.analogInputs;
        bind extDigitalOut = outputs.digitalOutputs;
        bind extAnalogOut = outputs.analogOutputs;
        bind extPowerIn = powerSupply.acInput;
        bind extEthernet = comms.ethernet;
        bind extSerial = comms.serial;

        // ---- Internal backplane data connections ----
        connection : BackplaneLink connect inputs.backplane to processor.backplane;
        connection : BackplaneLink connect processor.backplane to outputs.backplane;
        connection : BackplaneLink connect processor.backplane to comms.backplane;
        connection : BackplaneLink connect powerSupply.backplane to processor.backplane;

        // ---- Internal DC power distribution connections ----
        connection : PowerLink connect powerSupply.dc0 to processor.powerIn;
        connection : PowerLink connect powerSupply.dc1 to inputs.powerIn;
        connection : PowerLink connect powerSupply.dc2 to outputs.powerIn;
        connection : PowerLink connect powerSupply.dc3 to comms.powerIn;

        // ---- Exhibited PLC-level state machine ----
        exhibit state machine {
            initial state PowerOn {
                entry / powerUpSequence();
                do / verifyModules();
            }
            state Stopped {
                doc "PLC is powered but not actively scanning; outputs held in safe state";
                entry / holdSafeState();
                do / listenForCommands();
            }
            state Running {
                doc "PLC is actively executing the scan cycle";
                entry / startScanCycle();
                do / runContinuousScan();
                exit / finalizeCycle();
            }
            state Error {
                doc "A fault has been detected; PLC halted and waiting for reset";
                entry / freezeAllOutputs();
                do / broadcastDiagnostic();
                exit / clearFaultState();
            }

            transition from PowerOn to Stopped when powerStable();
            transition from Stopped to Running when startCommand();
            transition from Running to Stopped when stopCommand();
            transition from Running to Error when faultDetected();
            transition from Error to Stopped when resetCommand();
        }

        // Satisfy requirements at the system level
        satisfy scanCycleReq by processor;
        satisfy digitalInputsReq by inputs;
        satisfy analogInputsReq by inputs;
        satisfy digitalOutputsReq by outputs;
        satisfy analogOutputsReq by outputs;
        satisfy powerReq by powerSupply;
        satisfy commReq by comms;
        satisfy stateReq by PLC;
        satisfy safetyReq by PLC;
    }

    // =========================================================================
    // Requirements
    // =========================================================================

    requirement def ScanCycleRequirement {
        doc "The PLC scan cycle shall complete in under 50 milliseconds";
        attribute maxScanTime : ScanTime;
        constraint { maxScanTime < 50; }
    }

    requirement def DigitalInputCountRequirement {
        doc "The input module shall handle up to 16 digital (on/off) signals from sensors and switches";
        attribute minDigitalInputs : Integer;
        constraint { minDigitalInputs >= 16; }
    }

    requirement def AnalogInputCountRequirement {
        doc "The input module shall handle up to 8 analog (variable-level) signals";
        attribute minAnalogInputs : Integer;
        constraint { minAnalogInputs >= 8; }
    }

    requirement def DigitalOutputCountRequirement {
        doc "The output module shall provide 16 digital outputs for turning devices on and off";
        attribute minDigitalOutputs : Integer;
        constraint { minDigitalOutputs >= 16; }
    }

    requirement def AnalogOutputCountRequirement {
        doc "The output module shall provide 8 analog outputs for variable-signal control";
        attribute minAnalogOutputs : Integer;
        constraint { minAnalogOutputs >= 8; }
    }

    requirement def PowerConversionRequirement {
        doc "The power module shall convert a 120V AC input into stable 24V DC for all components";
        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        constraint { inputVoltage == 120; }
        constraint { outputVoltage == 24; }
    }

    requirement def CommunicationRequirement {
        doc "The PLC shall provide Ethernet and serial communication for monitoring by a central control system";
        attribute hasEthernet : Boolean;
        attribute hasSerial : Boolean;
        constraint { hasEthernet == true; }
        constraint { hasSerial == true; }
    }

    requirement def StateMachineRequirement {
        doc "The PLC shall operate in Stopped, Running, and Error states with deterministic transitions";
        attribute supportedStates : String;
        constraint { supportedStates == "Stopped, Running, Error"; }
    }

    requirement def SafetyResponseRequirement {
        doc "Upon fault detection the PLC shall enter the Error state, freeze all outputs, and remain there until a reset command";
        attribute faultFreezesOutputs : Boolean;
        attribute errorRequiresReset : Boolean;
        constraint { faultFreezesOutputs == true; }
        constraint { errorRequiresReset == true; }
    }

    // Requirement usages
    requirement scanCycleReq : ScanCycleRequirement {
        redefines maxScanTime = 50;
    }

    requirement digitalInputsReq : DigitalInputCountRequirement {
        redefines minDigitalInputs = 16;
    }

    requirement analogInputsReq : AnalogInputCountRequirement {
        redefines minAnalogInputs = 8;
    }

    requirement digitalOutputsReq : DigitalOutputCountRequirement {
        redefines minDigitalOutputs = 16;
    }

    requirement analogOutputsReq : AnalogOutputCountRequirement {
        redefines minAnalogOutputs = 8;
    }

    requirement powerReq : PowerConversionRequirement {
        redefines inputVoltage = 120;
        redefines outputVoltage = 24;
        redefines outputCurrent = 10;
    }

    requirement commReq : CommunicationRequirement {
        redefines hasEthernet = true;
        redefines hasSerial = true;
    }

    requirement stateReq : StateMachineRequirement {
        redefines supportedStates = "Stopped, Running, Error";
    }

    requirement safetyReq : SafetyResponseRequirement {
        redefines faultFreezesOutputs = true;
        redefines errorRequiresReset = true;
    }
}
