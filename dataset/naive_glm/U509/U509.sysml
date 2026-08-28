package ManualHandPumpSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    value type PressureValue :> ISQ::Pressure;
    value type ForceValue :> ISQ::Force;
    value type VolumeValue :> ISQ::Volume;
    value type LengthValue :> ISQ::Length;

    item def Fluid {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
    }

    port def FluidPort {
        in out fluid : Fluid;
        attribute pressure : PressureValue;
    }

    port def MechanicalPort {
        in out force : ForceValue;
        in out displacement : LengthValue;
    }

    requirement def ManualOperationReq {
        doc /* The system shall operate entirely manually without external power. */
    }

    requirement def MinPressureReq {
        doc /* The pump shall deliver a minimum output pressure of 300 kPa. */
        attribute minPressure : PressureValue = 300 [kPa];
        attribute outputPressure : PressureValue;
        constraint { outputPressure >= minPressure }
    }

    requirement def MaxOperatorForceReq {
        doc /* The pump shall be operable with a maximum human input force of 150 N. */
        attribute maxForce : ForceValue = 150 [N];
        attribute operatorForce : ForceValue;
        constraint { operatorForce <= maxForce }
    }

    part def HandleAssembly {
        port operatorPort : MechanicalPort;
        port pistonPort : MechanicalPort;
        attribute operatorForce : ForceValue;
        attribute handleDisplacement : LengthValue;
    }

    part def Piston {
        port handlePort : MechanicalPort;
        port cylinderPort : MechanicalPort;
        attribute position : LengthValue;
    }

    part def PumpCylinder {
        port pistonPort : MechanicalPort;
        port fluidPort : FluidPort;
        attribute internalPressure : PressureValue;
        attribute internalVolume : VolumeValue;
    }

    part def CheckValve {
        attribute crackingPressure : PressureValue;
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute isOpen : Boolean = false;

        state ValveState {
            state Closed;
            state Open;
            transition openValve from Closed to Open when inlet.pressure - outlet.pressure > crackingPressure;
            transition closeValve from Open to Closed when inlet.pressure - outlet.pressure <= crackingPressure;
        }
    }

    part def Reservoir {
        attribute fluidVolume : VolumeValue = 0.01 [m3];
        port outlet : FluidPort;
        attribute outputPressure : PressureValue = 101.325 [kPa];
    }

    part def DischargeManifold {
        attribute pressure : PressureValue = 300 [kPa];
        port inlet : FluidPort;
        attribute fluidVolume : VolumeValue;
    }

    part def HandPump {
        part handle : HandleAssembly;
        part piston : Piston;
        part cylinder : PumpCylinder;
        part inletValve : CheckValve {
            :>> crackingPressure = 5 [kPa];
        }
        part outletValve : CheckValve {
            :>> crackingPressure = 150 [kPa];
        }

        port inletPort : FluidPort;
        port outletPort : FluidPort;

        attribute outputPressure : PressureValue;
        attribute operatorForce : ForceValue;

        connection handleToPiston connect handle.pistonPort to piston.handlePort;
        connection pistonToCylinder connect piston.cylinderPort to cylinder.pistonPort;

        connection inletToValve connect inletPort to inletValve.inlet;
        connection valveToCylinder connect inletValve.outlet to cylinder.fluidPort;
        connection cylinderToValve connect cylinder.fluidPort to outletValve.inlet;
        connection valveToOutlet connect outletValve.outlet to outletPort;

        state PumpingCycle {
            state Idle;
            state Upstroke {
                entry / {
                    cylinder.internalPressure = 80 [kPa];
                }
                do / {
                    inletValve.isOpen = true;
                    outletValve.isOpen = false;
                }
            }
            state Downstroke {
                entry / {
                    cylinder.internalPressure = 350 [kPa];
                }
                do / {
                    inletValve.isOpen = false;
                    outletValve.isOpen = true;
                }
            }
            transition t1 from Idle to Upstroke when handle.operatorForce > 0 [N] && handle.handleDisplacement > 0 [m];
            transition t2 from Upstroke to Downstroke when handle.handleDisplacement == 0 [m];
            transition t3 from Downstroke to Upstroke when handle.handleDisplacement > 0 [m];
            transition t4 from Downstroke to Idle when handle.operatorForce == 0 [N];
        }
    }

    part def HandPumpSystem {
        part handPump : HandPump;
        part sourceReservoir : Reservoir;
        part dischargeManifold : DischargeManifold;

        connection reservoirToPump connect sourceReservoir.outlet to handPump.inletPort;
        connection pumpToManifold connect handPump.outletPort to dischargeManifold.inlet;

        requirement manualOpReq : ManualOperationReq;
        requirement minPressReq : MinPressureReq;
        requirement maxForceReq : MaxOperatorForceReq;

        satisfy manualOpReq by handPump;
        satisfy minPressReq by handPump;
        satisfy maxForceReq by handPump;
    }
}
