package IndustrialAutomationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    def Temperature :> Real { unit 'C'; }
    def Pressure :> Real { unit 'bar'; }
    def Voltage :> Real { unit 'V'; }
    def Current :> Real { unit 'A'; }
    def Duration :> Real { unit 'ms'; }
    def DiscreteState :> Integer;

    // Items
    item def SensorSignal {
        attribute value : Real;
    }
    item def ActuatorCommand {
        attribute value : Real;
    }
    item def NetworkPacket {
        attribute payload : String;
    }

    // Ports
    port def AnalogInputPort {
        in item signal : SensorSignal;
        attribute voltage : Voltage;
    }
    port def DiscreteInputPort {
        in item signal : SensorSignal;
        attribute state : DiscreteState;
    }
    port def AnalogOutputPort {
        out item command : ActuatorCommand;
        attribute current : Current;
    }
    port def DiscreteOutputPort {
        out item command : ActuatorCommand;
        attribute state : DiscreteState;
    }
    port def NetworkPort {
        inout item packet : NetworkPacket;
    }
    port def InternalBusPort {
        inout item data : NetworkPacket;
    }

    // Requirements
    requirement def ControlSystemRequirement {
        doc "The system shall monitor and control physical processes by executing a user-defined control program.";
    }
    requirement def ScanCycleRequirement {
        attribute cycleTime : Duration = 10;
        doc "The controller shall execute a scan cycle with a fixed duration.";
    }
    requirement def StateMachineRequirement {
        doc "The controller shall manage operational status using a state machine with idle, initializing, running, paused, stopped, and faulted states.";
    }

    // Modules
    part def ProcessorModule {
        attribute memory : String;
        attribute program : String;
        port busPort : InternalBusPort;

        action def ScanInputsAction {
            in inputValues : SensorSignal;
        }
        action def ExecuteProgramAction {
            in inputValues : SensorSignal;
            out outputCommands : ActuatorCommand;
        }
        action def UpdateOutputsAction {
            in outputCommands : ActuatorCommand;
        }
        action def HandleCommsDiagnosticsAction;

        action def ScanCycle {
            action scanInputs : ScanInputsAction;
            action executeProgram : ExecuteProgramAction;
            action updateOutputs : UpdateOutputsAction;
            action handleCommsDiag : HandleCommsDiagnosticsAction;

            then scanInputs;
            then executeProgram;
            then updateOutputs;
            then handleCommsDiag;
        }
    }

    part def InputModule {
        port busPort : InternalBusPort;
        port analogIn : AnalogInputPort;
        port discreteIn : DiscreteInputPort;
    }

    part def OutputModule {
        port busPort : InternalBusPort;
        port analogOut : AnalogOutputPort;
        port discreteOut : DiscreteOutputPort;
    }

    part def CommunicationModule {
        port busPort : InternalBusPort;
        port networkPort : NetworkPort;
    }

    // Controller
    part def AutomationController {
        requirement req1 : ControlSystemRequirement;
        requirement req2 : ScanCycleRequirement;
        requirement req3 : StateMachineRequirement;

        part processor : ProcessorModule;
        part inputs : InputModule;
        part outputs : OutputModule;
        part comms : CommunicationModule;

        connection procToIn : processor.busPort to inputs.busPort;
        connection procToOut : processor.busPort to outputs.busPort;
        connection procToComms : processor.busPort to comms.busPort;

        state machine ControllerStateMachine {
            state idle;
            state initializing;
            state running {
                do : ProcessorModule::ScanCycle;
            }
            state paused;
            state stopped;
            state faulted;

            transition from initial to initializing;
            transition from initializing to running;
            transition from running to paused;
            transition from paused to running;
            transition from running to stopped;
            transition from stopped to idle;
            transition from running to faulted;
            transition from paused to faulted;
            transition from faulted to stopped;
        }
    }

    // Environment
    part def Sensor {
        port sensorOut : AnalogInputPort;
    }
    part def Actuator {
        port actuatorIn : AnalogOutputPort;
    }
    part def OperatorPanel {
        port panelNet : NetworkPort;
    }

    part System : AutomationController {
        part tempSensor : Sensor;
        part valve : Actuator;
        part panel : OperatorPanel;

        connection sensorToController : tempSensor.sensorOut to inputs.analogIn;
        connection controllerToActuator : outputs.analogOut to valve.actuatorIn;
        connection panelToController : panel.panelNet to comms.networkPort;
    }
}
