package 'Shirley Drain System' {
    private import ScalarValues::*;
    private import SI::*;

    item def SerousFluid;
    item def Air;

    port def FluidPort {
        out item fluid : SerousFluid;
        attribute pressure : Real;
    }

    port def GasPort {
        out item gas : Air;
        attribute pressure : Real;
    }

    part def Patient {
        attribute elevation : Real = 1.0 [SI::m];
        part bodyCavity {
            item fluid : SerousFluid;
            attribute internalPressure : Real = 101325.0 [SI::Pa];
            port drainagePort : FluidPort;
        }
    }

    part def DrainCatheter {
        attribute material : String = "Medical-grade silicone";
        attribute isFlexible : Boolean = true;
        attribute perforationCount : Integer = 6;
        port distalPort : ~FluidPort;
        port proximalPort : FluidPort;
    }

    part def AntiRefluxValve {
        port inletPort : ~FluidPort;
        port outletPort : FluidPort;
        attribute crackingPressure : Real = 100.0 [SI::Pa];
        attribute isOpen : Boolean = false;

        state machine def ValveBehavior {
            state Closed;
            state Open;
            transition openTransition :> Closed to Open {
                guard inletPort.pressure > outletPort.pressure + crackingPressure;
            }
            transition closeTransition :> Open to Closed {
                guard inletPort.pressure <= outletPort.pressure + crackingPressure;
            }
        }

        satisfy antiRefluxReq;
    }

    part def CollectionReservoir {
        attribute elevation : Real = 0.5 [SI::m];
        attribute maxCapacity : Real = 400.0 [SI::mL];
        attribute graduationInterval : Real = 10.0 [SI::mL];
        attribute currentVolume : Real = 0.0 [SI::mL];
        item collectedFluid : SerousFluid;
        port inletPort : ~FluidPort;
        port ventPort : GasPort;

        satisfy measurementReq;
    }

    part def Atmosphere {
        port airPort : ~GasPort;
    }

    part def ShirleyDrainSystem {
        part catheter : DrainCatheter;
        part valve : AntiRefluxValve;
        part reservoir : CollectionReservoir;

        flow of fluid : SerousFluid
            from catheter.proximalPort.fluid to valve.inletPort.fluid;
        flow of fluid : SerousFluid
            from valve.outletPort.fluid to reservoir.inletPort.fluid;

        satisfy continuousDrainageReq;
        satisfy gravityOperationReq;
    }

    part def DrainageContext {
        part patient : Patient;
        part drainSystem : ShirleyDrainSystem;
        part atmosphere : Atmosphere;

        flow of fluid : SerousFluid
            from patient.bodyCavity.drainagePort.fluid
            to drainSystem.catheter.distalPort.fluid;
        flow of air : Air
            from drainSystem.reservoir.ventPort.gas
            to atmosphere.airPort.gas;
    }

    requirement def ContinuousDrainageDef {
        attribute description : String = 'The system shall drain serous fluid continuously from the patient body cavity.';
        subject drainSystem : ShirleyDrainSystem;
    }
    requirement continuousDrainageReq : ContinuousDrainageDef;

    requirement def GravityOperationDef {
        attribute description : String = 'The system shall operate passively using gravity without mechanical suction.';
        subject drainSystem : ShirleyDrainSystem;
    }
    requirement gravityOperationReq : GravityOperationDef;

    requirement def AntiRefluxDef {
        attribute description : String = 'The valve shall prevent fluid backflow to the patient.';
        subject valve : AntiRefluxValve;
    }
    requirement antiRefluxReq : AntiRefluxDef;

    requirement def MeasurementDef {
        attribute description : String = 'The reservoir shall measure fluid volume with 10 mL graduations up to 400 mL.';
        subject reservoir : CollectionReservoir;
    }
    requirement measurementReq : MeasurementDef;
}
