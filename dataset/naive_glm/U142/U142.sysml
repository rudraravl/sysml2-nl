package AirlockSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----
    value type Pressure :> Real { unit 'Pa'; }
    value type PressureDifference :> Real { unit 'Pa'; }
    value type Time :> Real { unit 's'; }

    // ---- Item Definitions ----
    item def Atmosphere;

    // ---- Port Definitions ----
    port def FluidPort {
        out item flow: Atmosphere;
        attribute pressure: Pressure;
    }

    port def ControlPort {
        in attribute command: String;
        out attribute status: String;
    }

    port def SensorPort {
        out attribute pressureReading: Pressure;
    }

    port def DoorStatusPort {
        out attribute locked: Boolean;
        out attribute sealed: Boolean;
        out attribute open: Boolean;
    }

    port def DoorCommandPort {
        in attribute lock: Boolean;
        in attribute seal: Boolean;
        in attribute open: Boolean;
    }

    port def ValveCommandPort {
        in attribute open: Boolean;
    }

    // ---- Requirements ----
    requirement def SafePassage {
        subject airlock: AirlockSystem;
        doc /* The airlock shall provide safe passage for people and equipment between the pressurized habitat and the vacuum of space. */
    }

    requirement def DoorInterlockRequirement :> SafePassage {
        doc /* The airlock shall ensure that both doors are never unlocked or open at the same time, preventing catastrophic depressurization of the habitat. */
    }

    requirement def PressureLockRequirement :> SafePassage {
        doc /* Doors shall remain locked and sealed when a significant pressure difference exists across them. */
        attribute maxSafePressureDiff: PressureDifference = 100 [Pa];
    }

    requirement def EgressCycleRequirement :> SafePassage {
        doc /* The egress cycle shall vent the chamber atmosphere to space until internal pressure matches vacuum before unlocking and opening the outer door. */
    }

    requirement def IngressCycleRequirement :> SafePassage {
        doc /* The ingress cycle shall fill the chamber with habitat air until internal pressure matches habitat pressure before unlocking and opening the inner door. */
    }

    requirement def AutomatedCycleRequirement :> SafePassage {
        doc /* The airlock shall execute a complete automated cycle upon receiving a single egress or ingress command. */
    }

    // ---- Part Definitions ----
    part def PressureSensor {
        port sensorOut: SensorPort;
        attribute reading: Pressure = 101325 [Pa];
        attribute updateRate: Time = 0.1 [s];

        action def ReadPressure {
            out attribute measured: Pressure;
        }

        perform ReadPressure;
    }

    part def Valve {
        port valveCmd: ValveCommandPort;
        port fluidConnection: FluidPort;
        attribute isOpen: Boolean = false;
        attribute maxFlowRate: Real = 0.5;

        action def SetValve {
            in cmd: Boolean;
            then { isOpen = cmd; }
        }
    }

    part def Door {
        port doorCmd: DoorCommandPort;
        port doorStatus: DoorStatusPort;
        port sideA: FluidPort;
        port sideB: FluidPort;
        attribute locked: Boolean = true;
        attribute sealed: Boolean = true;
        attribute isOpen: Boolean = false;
        attribute pressureDiff: PressureDifference = 0 [Pa];
        attribute maxSafePressureDiff: PressureDifference = 100 [Pa];

        action def LockDoor { in cmd: Boolean; then { locked = cmd; } }
        action def SealDoor { in cmd: Boolean; then { sealed = cmd; } }
        action def OpenDoor {
            in cmd: Boolean;
            if cmd && !locked && !sealed && pressureDiff <= maxSafePressureDiff {
                isOpen = true;
            } else {
                isOpen = false;
            }
        }

        state def DoorStateMachine {
            state LockedSealedClosed {
                entry { locked = true; sealed = true; isOpen = false; }
            }
            state UnlockedSealedClosed {
                entry { locked = false; sealed = true; isOpen = false; }
            }
            state UnlockedOpen {
                entry { locked = false; sealed = false; isOpen = true; }
            }
            state FaultLocked {
                entry { locked = true; sealed = true; isOpen = false; }
            }

            transition LockedSealedClosed -> UnlockedSealedClosed
                when doorCmd.lock == false && pressureDiff <= maxSafePressureDiff;
            transition UnlockedSealedClosed -> UnlockedOpen
                when doorCmd.seal == false && doorCmd.open == true;
            transition UnlockedOpen -> UnlockedSealedClosed
                when doorCmd.open == false;
            transition UnlockedSealedClosed -> LockedSealedClosed
                when doorCmd.lock == true;
            transition any -> FaultLocked when pressureDiff > maxSafePressureDiff;
        }

        perform DoorStateMachine;
    }

    part def Chamber {
        port habitatPort: FluidPort;
        port spacePort: FluidPort;
        port ventPort: FluidPort;
        port fillPort: FluidPort;
        attribute internalPressure: Pressure = 101325 [Pa];
        attribute habitatPressure: Pressure = 101325 [Pa];
        attribute vacuumPressure: Pressure = 0 [Pa];
        attribute volume: Real = 10.0;

        action def UpdatePressure {
            in ventOpen: Boolean;
            in fillOpen: Boolean;
            if ventOpen && internalPressure > vacuumPressure {
                internalPressure = internalPressure - 1000.0 [Pa];
            }
            if fillOpen && internalPressure < habitatPressure {
                internalPressure = internalPressure + 1000.0 [Pa];
            }
        }
    }

    part def AirlockController {
        port controlIn: ControlPort;
        port innerDoorCmdOut: DoorCommandPort;
        port outerDoorCmdOut: DoorCommandPort;
        port ventValveCmdOut: ValveCommandPort;
        port fillValveCmdOut: ValveCommandPort;
        port sensorIn: SensorPort;

        attribute currentPressure: Pressure = 101325 [Pa];
        attribute habitatPressure: Pressure = 101325 [Pa];
        attribute vacuumPressure: Pressure = 0 [Pa];
        attribute equalizationTolerance: Pressure = 100 [Pa];
        attribute innerDoorOpen: Boolean = false;
        attribute outerDoorOpen: Boolean = false;
        attribute cycleActive: Boolean = false;

        action def ExecuteEgress {
            // Seal and lock inner door
            innerDoorCmdOut.lock = true;
            innerDoorCmdOut.seal = true;
            innerDoorCmdOut.open = false;
            // Vent chamber to space
            ventValveCmdOut.open = true;
            fillValveCmdOut.open = false;
            // Wait for pressure equalization with vacuum
            while currentPressure > vacuumPressure + equalizationTolerance {
                currentPressure = sensorIn.pressureReading;
            }
            ventValveCmdOut.open = false;
            // Unlock and open outer door
            outerDoorCmdOut.lock = false;
            outerDoorCmdOut.seal = false;
            outerDoorCmdOut.open = true;
        }

        action def ExecuteIngress {
            // Seal and lock outer door
            outerDoorCmdOut.lock = true;
            outerDoorCmdOut.seal = true;
            outerDoorCmdOut.open = false;
            // Fill chamber from habitat
            fillValveCmdOut.open = true;
            ventValveCmdOut.open = false;
            // Wait for pressure equalization with habitat
            while currentPressure < habitatPressure - equalizationTolerance {
                currentPressure = sensorIn.pressureReading;
            }
            fillValveCmdOut.open = false;
            // Unlock and open inner door
            innerDoorCmdOut.lock = false;
            innerDoorCmdOut.seal = false;
            innerDoorCmdOut.open = true;
        }

        state machine ControllerStateMachine {
            state Idle {
                entry { cycleActive = false; }
            }
            state Egress_SealInner {
                entry {
                    innerDoorCmdOut.lock = true;
                    innerDoorCmdOut.seal = true;
                    innerDoorCmdOut.open = false;
                }
            }
            state Egress_Vent {
                entry {
                    ventValveCmdOut.open = true;
                    fillValveCmdOut.open = false;
                }
            }
            state Egress_OpenOuter {
                entry {
                    ventValveCmdOut.open = false;
                    outerDoorCmdOut.lock = false;
                    outerDoorCmdOut.seal = false;
                    outerDoorCmdOut.open = true;
                }
            }
            state Egress_Complete;
            state Ingress_SealOuter {
                entry {
                    outerDoorCmdOut.lock = true;
                    outerDoorCmdOut.seal = true;
                    outerDoorCmdOut.open = false;
                }
            }
            state Ingress_Fill {
                entry {
                    fillValveCmdOut.open = true;
                    ventValveCmdOut.open = false;
                }
            }
            state Ingress_OpenInner {
                entry {
                    fillValveCmdOut.open = false;
                    innerDoorCmdOut.lock = false;
                    innerDoorCmdOut.seal = false;
                    innerDoorCmdOut.open = true;
                }
            }
            state Ingress_Complete;
            state Fault {
                entry {
                    innerDoorCmdOut.lock = true;
                    innerDoorCmdOut.seal = true;
                    innerDoorCmdOut.open = false;
                    outerDoorCmdOut.lock = true;
                    outerDoorCmdOut.seal = true;
                    outerDoorCmdOut.open = false;
                    ventValveCmdOut.open = false;
                    fillValveCmdOut.open = false;
                }
            }

            transition Idle -> Egress_SealInner when controlIn.command == "egress";
            transition Idle -> Ingress_SealOuter when controlIn.command == "ingress";

            transition Egress_SealInner -> Egress_Vent
                when innerDoorCmdOut.lock == true && innerDoorCmdOut.seal == true;

            transition Egress_Vent -> Egress_OpenOuter
                when currentPressure <= vacuumPressure + equalizationTolerance;

            transition Egress_OpenOuter -> Egress_Complete
                when outerDoorCmdOut.open == true;

            transition Egress_Complete -> Idle;

            transition Ingress_SealOuter -> Ingress_Fill
                when outerDoorCmdOut.lock == true && outerDoorCmdOut.seal == true;

            transition Ingress_Fill -> Ingress_OpenInner
                when currentPressure >= habitatPressure - equalizationTolerance;

            transition Ingress_OpenInner -> Ingress_Complete
                when innerDoorCmdOut.open == true;

            transition Ingress_Complete -> Idle;

            transition any -> Fault
                when (innerDoorOpen == true && outerDoorOpen == true);
        }

        perform ControllerStateMachine;
    }

    // ---- Top-Level Airlock System ----
    part def AirlockSystem {
        part chamber: Chamber;
        part innerDoor: Door;
        part outerDoor: Door;
        part pressureSensor: PressureSensor;
        part ventValve: Valve;
        part fillValve: Valve;
        part controller: AirlockController;

        port userControl: ControlPort;

        // Control connections
        connection controller.controlIn to userControl;
        connection controller.innerDoorCmdOut to innerDoor.doorCmd;
        connection controller.outerDoorCmdOut to outerDoor.doorCmd;
        connection controller.ventValveCmdOut to ventValve.valveCmd;
        connection controller.fillValveCmdOut to fillValve.valveCmd;
        connection pressureSensor.sensorOut to controller.sensorIn;

        // Fluid connections
        connection chamber.habitatPort to innerDoor.sideA;
        connection innerDoor.sideB to chamber.fillPort;
        connection chamber.spacePort to outerDoor.sideA;
        connection outerDoor.sideB to chamber.ventPort;
        connection chamber.ventPort to ventValve.fluidConnection;
        connection chamber.fillPort to fillValve.fluidConnection;

        // Door status feedback to controller
        connection innerDoor.doorStatus to controller.sensorIn;
        connection outerDoor.doorStatus to controller.sensorIn;

        // Requirement satisfaction
        satisfy SafePassage by AirlockSystem;
        satisfy DoorInterlockRequirement by AirlockSystem;
        satisfy PressureLockRequirement by AirlockSystem;
        satisfy EgressCycleRequirement by AirlockSystem;
        satisfy IngressCycleRequirement by AirlockSystem;
        satisfy AutomatedCycleRequirement by AirlockSystem;
    }
}
