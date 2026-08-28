package StirrupPumpFirefightingSystem {

    import ScalarValues::*;

    package Units {
        unit kg;
        unit m;
        unit s;
        unit Pa = kg / (m * s * s);
        unit N = kg * m / (s * s);
        unit L = (m * m * m) / 1000;
        unit m2 = m * m;
        unit m3 = m * m * m;
        unit mps = m / s;
        unit m3ps = m3 / s;
    }

    package ValueTypes {
        import Units::*;
        value type Pressure :> Real { unit Pa; }
        value type Force :> Real { unit N; }
        value type Length :> Real { unit m; }
        value type Volume :> Real { unit L; }
        value type Area :> Real { unit m2; }
        value type Mass :> Real { unit kg; }
        value type Time :> Real { unit s; }
        value type Velocity :> Real { unit mps; }
        value type FlowRate :> Real { unit m3ps; }
    }

    package Items {
        import ValueTypes::*;
        item def Water {
            attribute density : Real;
        }
        item def PressurizedWater :> Water {
            ref attribute pressure : Pressure;
        }
    }

    package Ports {
        import ValueTypes::*;
        import Items::*;
        port def FluidInPort {
            in item water : Water;
            attribute pressure : Pressure;
            attribute flowRate : FlowRate;
        }
        port def FluidOutPort {
            out item water : PressurizedWater;
            attribute pressure : Pressure;
            attribute flowRate : FlowRate;
        }
        interface def FluidInterface {
            end source : FluidOutPort;
            end target : FluidInPort;
        }
    }

    package Components {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;

        part def FluidReservoir {
            attribute capacity : Volume;
            attribute currentLevel : Volume;
            attribute emptyMass : Mass;
            attribute material : String;
            port outlet : FluidOutPort;
            action def drawWater {
                in ref item drawnWater : Water;
                attribute amount : Volume;
            }
        }

        part def CheckValve {
            attribute name : String;
            attribute crackingPressure : Pressure;
            attribute isOpen : Boolean;
            attribute diameter : Length;
            port inlet : FluidInPort;
            port outlet : FluidOutPort;
            action def open;
            action def close;
        }

        part def Cylinder {
            attribute bore : Length;
            attribute stroke : Length;
            attribute material : String;
            attribute workingPressure : Pressure;
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
            attribute volume : Volume = (3.14159 * bore * bore / 4) * stroke;
        }

        part def Piston {
            attribute diameter : Length;
            attribute area : Area;
            attribute material : String;
            attribute sealType : String;
            attribute position : Length;
            attribute velocity : Velocity;
            attribute maxStroke : Length;
            action def moveUp;
            action def moveDown;
        }

        part def THandle {
            attribute height : Length;
            attribute gripLength : Length;
            attribute gripDiameter : Length;
            attribute material : String;
        }

        part def Footplate {
            attribute length : Length;
            attribute width : Length;
            attribute thickness : Length;
            attribute material : String;
            attribute mass : Mass;
        }

        part def StirrupPump {
            attribute maxPressure : Pressure;
            attribute nominalFlowRate : FlowRate;
            attribute weight : Mass;
            attribute pistonDiameter : Length;
            attribute strokeLength : Length;
            part footplate : Footplate;
            part cylinder : Cylinder;
            part piston : Piston;
            part handle : THandle;
            part inletValve : CheckValve;
            part outletValve : CheckValve;
            port reservoirInlet : FluidInPort;
            port hoseOutlet : FluidOutPort;
            state pumpOperation {
                state Intake {
                    entry {
                        /* piston begins upward stroke;
                           inlet valve opens;
                           outlet valve remains closed */
                    }
                    do {
                        /* vacuum created in cylinder;
                           water drawn from reservoir through inlet */
                    }
                    exit {
                        /* inlet valve closes when piston reaches top */
                    }
                }
                state Discharge {
                    entry {
                        /* piston begins downward stroke;
                           outlet valve opens;
                           inlet valve closes */
                    }
                    do {
                        /* water compressed in cylinder;
                           pressurized water expelled through outlet */
                    }
                    exit {
                        /* outlet valve closes when piston reaches bottom */
                    }
                }
                transition Intake -> Discharge when piston.position >= piston.maxStroke;
                transition Discharge -> Intake when piston.position <= 0;
            }
            action def pumpCycle {
                /* complete intake stroke followed by discharge stroke */
            }
        }

        part def DeliveryHose {
            attribute length : Length;
            attribute innerDiameter : Length;
            attribute maxWorkingPressure : Pressure;
            attribute material : String;
            attribute weight : Mass;
            port inlet : FluidInPort;
            port nozzle : FluidOutPort;
            action def deliverWater {
                in ref item pressurizedWater : PressurizedWater;
            }
        }
    }

    package System {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Components::*;

        part def StirrupPumpFirefightingSystem {
            attribute systemName : String;
            attribute application : String;
            part reservoir : FluidReservoir;
            part pump : StirrupPump;
            part hose : DeliveryHose;
            connect reservoir.outlet to pump.reservoirInlet;
            connect pump.hoseOutlet to hose.inlet;
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Items::*;
        import Components::*;
        import System::*;

        requirement def ProvidePressurizedWater {
            doc /* The system shall deliver pressurized water to extinguish fires. */;
            subject sys : StirrupPumpFirefightingSystem;
            attribute requiredPressure : Pressure;
            attribute requiredFlowRate : FlowRate;
        }

        requirement def ManualOperation {
            doc /* The pump shall be manually operable by a single operator using a T-handle. */;
            subject pump : StirrupPump;
            attribute operatorForce : Force;
        }

        requirement def Portability {
            doc /* The system shall be portable for deployment at fire scenes. */;
            subject sys : StirrupPumpFirefightingSystem;
            attribute maxWeight : Mass;
        }

        requirement def DrawFromLocalSource {
            doc /* The system shall draw water from a local source via the reservoir. */;
            subject sys : StirrupPumpFirefightingSystem;
        }

        requirement def TwoStrokeCycle {
            doc /* The pump shall operate on a two-stroke intake/discharge cycle using a pair of one-way check valves. */;
            subject pump : StirrupPump;
        }

        requirement def ContinuousFlow {
            doc /* The pump shall repeat the two-stroke cycle continuously to generate a steady flow of water. */;
            subject pump : StirrupPump;
        }

        requirement def StabilityDuringOperation {
            doc /* The pump shall provide a footplate for the operator to stand on for stability during pumping. */;
            subject pump : StirrupPump;
        }
    }
}
