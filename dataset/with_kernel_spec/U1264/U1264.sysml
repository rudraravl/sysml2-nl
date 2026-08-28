package X10HomeAutomation {
    enum def X10Function {
        ON;
        OFF;
        DIM;
        BRIGHT;
    }
    item def X10Command {
        attribute houseCode : ScalarValues::String;
        attribute unitCode : ScalarValues::Integer;
        attribute func : X10Function;
    }
    item def X10Signal {
        doc /* X10 signal: 120 kHz carrier modulated onto 120V/60Hz AC power line. */
        attribute carrierFrequency : ScalarValues::Real = 120;
        attribute voltage : ScalarValues::Real = 120;
        attribute lineFrequency : ScalarValues::Real = 60;
        attribute payload : X10Command;
    }

    requirement def X10SystemRequirements {
        requirement deviceCapacity {
            doc /* The system shall support up to 256 individual devices. */
        }
        requirement signalSpec {
            doc /* The signal shall be modulated at 120 kHz. */
        }
        requirement powerSpec {
            doc /* The system shall operate on 120V/60Hz AC wiring. */
        }
        requirement twoWayCommunication {
            doc /* The transceiver shall support receiving status signals from modules. */
        }
    }

    port def CommandPort {
        inout item command : X10Command;
    }
    port def SignalPort {
        inout item signal : X10Signal;
    }
    port def PowerPort {
        inout item powerSignal : X10Signal;
    }

    part def MainController {
        port commandOut : CommandPort;
    }

    part def Transceiver {
        port commandIn : CommandPort;
        port signalOut : SignalPort;
        port signalIn : SignalPort;
    }

    part def PowerLineInterface {
        port signalIn : SignalPort;
        port powerOut : PowerPort;
    }

    part def ElectricalWiring {
        port busPort : PowerPort;
    }

    abstract part def X10Module {
        port powerIn : PowerPort;
        attribute houseCode : ScalarValues::String;
        attribute unitCode : ScalarValues::Integer;
        attribute maxLoad : ScalarValues::Real;

        state def ModuleBehavior {
            state Idle;
            state Receiving;
            state Executing;

            transition first Idle
                accept sig : X10Signal via powerIn
                then Receiving;

            transition first Receiving
                if sig.payload.houseCode == houseCode
                then Executing;

            transition first Receiving
                if sig.payload.houseCode != houseCode
                then Idle;

            transition first Executing
                then Idle;
        }

        state moduleState : ModuleBehavior;
    }

    part def LampModule :> X10Module {
        attribute :>> maxLoad = 300;
        attribute brightness : ScalarValues::Real = 1.0;
    }

    part def ApplianceModule :> X10Module {
        attribute :>> maxLoad = 1800;
    }

    part def WallSwitch :> X10Module {
        attribute :>> maxLoad = 500;
        attribute manualOverride : ScalarValues::Boolean = false;
    }

    part def ControlledDevice {
        attribute deviceType : ScalarValues::String;
    }

    part def X10System {
        requirement req : X10SystemRequirements;

        part controller : MainController;
        part transceiver : Transceiver;
        part powerLineInterface : PowerLineInterface;
        part wiring : ElectricalWiring;

        part lampModule1 : LampModule {
            attribute houseCode = "A";
            attribute unitCode = 1;
            part controlledLamp : ControlledDevice {
                attribute deviceType = "Lamp";
            }
        }
        part applianceModule1 : ApplianceModule {
            attribute houseCode = "A";
            attribute unitCode = 2;
            part controlledFan : ControlledDevice {
                attribute deviceType = "Fan";
            }
        }
        part wallSwitch1 : WallSwitch {
            attribute houseCode = "A";
            attribute unitCode = 3;
            part controlledLight : ControlledDevice {
                attribute deviceType = "Light";
            }
        }

        connect controller.commandOut to transceiver.commandIn;
        connect transceiver.signalOut to powerLineInterface.signalIn;
        connect powerLineInterface.powerOut to wiring.busPort;
        connect wiring.busPort to lampModule1.powerIn;
        connect wiring.busPort to applianceModule1.powerIn;
        connect wiring.busPort to wallSwitch1.powerIn;
    }
}
