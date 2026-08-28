package IndustrialAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def ControlSignal :> Real;
    attribute def DiscreteValue :> Boolean;
    attribute def ScanCycleDuration :> ISQ::DurationValue;

    item def SensorReading;
    item def TemperatureReading :> SensorReading {
        attribute value : TemperatureValue;
    }
    item def PressureReading :> SensorReading {
        attribute value : PressureValue;
    }
    item def ActuatorCommand;
    item def ValveCommand :> ActuatorCommand {
        attribute value : ControlSignal;
    }
    item def MotorCommand :> ActuatorCommand {
        attribute value : ControlSignal;
    }

    port def AnalogInputPort {
        in reading : SensorReading;
    }
    port def TemperatureInputPort :> AnalogInputPort {
        redefines in reading : TemperatureReading;
    }
    port def PressureInputPort :> AnalogInputPort {
        redefines in reading : PressureReading;
    }
    port def DiscreteInputPort {
        in reading : SensorReading;
    }
    port def AnalogOutputPort {
        out command : ActuatorCommand;
    }
    port def ValveOutputPort :> AnalogOutputPort {
        redefines out command : ValveCommand;
    }
    port def MotorOutputPort :> AnalogOutputPort {
        redefines out command : MotorCommand;
    }
    port def DiscreteOutputPort {
        out command : ActuatorCommand;
    }
    port def EthernetPort;
    port def FieldbusPort;
    port def SerialPort;
    port def InternalDataPort;

    part def Sensor {
        out port sensorOut : AnalogInputPort;
    }
    part def TemperatureTransducer :> Sensor {
        out port sensorOut : TemperatureInputPort;
    }
    part def PressureTransducer :> Sensor {
        out port sensorOut : PressureInputPort;
    }

    part def Actuator {
        in port actuatorIn : AnalogOutputPort;
    }
    part def ControlValve :> Actuator {
        in port actuatorIn : ValveOutputPort;
    }
    part def MotorDrive :> Actuator {
        in port actuatorIn : MotorOutputPort;
    }

    action def ScanCycle {
        in inputs : SensorReading[*];
        out outputs : ActuatorCommand[*];
        action scanInputs {
            in s : SensorReading[*] = inputs;
        }
        action executeProgram {
            in s : SensorReading[*] = scanInputs.s;
            out c : ActuatorCommand[*];
        }
        action updateOutputs {
            in c : ActuatorCommand[*] = executeProgram.c;
            out o : ActuatorCommand[*] = outputs;
        }
        action handleCommsAndDiagnostics;
        first start;
        then scanInputs;
        then executeProgram;
        then updateOutputs;
        then handleCommsAndDiagnostics;
        then done;
    }

    part def ProcessorModule {
        attribute programMemory : String;
        attribute scanCycleDuration : ScanCycleDuration = 0.01[SI::s];
        
        port dataIn : InternalDataPort;
        port dataOut : InternalDataPort;
    }

    part def InputModule {
        in port discIn : DiscreteInputPort[0..*];
        in port anaIn : AnalogInputPort[0..*];
        out port dataOut : InternalDataPort;
    }
    part def OutputModule {
        in port dataIn : InternalDataPort;
        out port discOut : DiscreteOutputPort[0..*];
        out port anaOut : AnalogOutputPort[0..*];
    }
    part def CommunicationModule {
        port ethPort : EthernetPort;
        port fieldbusPort : FieldbusPort;
        port serialPort : SerialPort;
    }

    attribute def StartSignal;
    attribute def StopSignal;
    attribute def PauseSignal;
    attribute def ResumeSignal;
    attribute def FaultSignal;
    attribute def ResetSignal;

    state def ControllerStates;

    part def AutomationController {
        part processor : ProcessorModule;
        part inputModules : InputModule;
        part outputModules : OutputModule;
        part commModule : CommunicationModule;
        
        connect inputModules.dataOut to processor.dataIn;
        connect processor.dataOut to outputModules.dataIn;
        
        perform action scanCycle : ScanCycle;
        
        exhibit state controllerStates : ControllerStates {
            entry; then initializing;
            state initializing;
            accept StartSignal then running;
            state running {
                do scanCycle;
            }
            accept PauseSignal then paused;
            accept StopSignal then stopped;
            accept FaultSignal then faulted;
            state paused;
            accept ResumeSignal then running;
            accept StopSignal then stopped;
            state stopped;
            accept StartSignal then initializing;
            state faulted;
            accept ResetSignal then initializing;
        }
    }

    part def AutomationSystem {
        part controller : AutomationController;
        part tempSensor : TemperatureTransducer;
        part pressSensor : PressureTransducer;
        part valve : ControlValve;
        part motor : MotorDrive;
        
        connect tempSensor.sensorOut to controller.inputModules.anaIn;
        connect pressSensor.sensorOut to controller.inputModules.anaIn;
        connect controller.outputModules.anaOut to valve.actuatorIn;
        connect controller.outputModules.anaOut to motor.actuatorIn;
    }

    requirement def ReliableExecutionRequirement {
        subject sys : AutomationSystem;
        requirement {
            doc /* The system shall reliably and repetitively execute automation tasks. */
        }
    }
    
    requirement def ScanCycleRequirement {
        subject controller : AutomationController;
        requirement {
            doc /* The controller shall execute a complete scan cycle within a fixed duration. */
        }
    }
}
