package ShirleyDrainSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    value type Volume :> Real {
        unit mm3;
    }
    value type Pressure :> Real {
        unit Pa;
    }
    value type Length :> Real {
        unit mm;
    }
    value type Diameter :> Real {
        unit mm;
    }
    value type Elevation :> Real {
        unit mm;
    }
    value type FlowRate :> Real {
        unit mm3/s;
    }
    value type Mass :> Real {
        unit kg;
    }

    // ===== Item Types =====

    item def SerousFluid;
    item def Air;

    // ===== Port Definitions =====

    port def FluidPort {
        out item serousFluid : SerousFluid;
        in item air : Air;
        ref attr pressure : Pressure;
        ref attr flowRate : FlowRate;
    }

    port def PatientPort :> FluidPort;
    port def ReservoirPort :> FluidPort;
    port def AtmospherePort {
        out item air : Air;
        in item serousFluid : SerousFluid;
    }

    // ===== Requirements =====

    requirement def DrainageRequirement {
        doc "The system shall continuously drain serous fluid from a body cavity using gravity."
        subject drainSystem : ShirleyDrainSystem;
        objective {
            drainSystem.reservoir.currentVolume >= 0 [mm3] and
            drainSystem.reservoir.currentVolume <= 400_000 [mm3];
        }
    }

    requirement def AntiRefluxRequirement {
        doc "The system shall prevent backflow of fluid from the reservoir to the patient."
        subject valve : AntiRefluxValve;
        objective {
            valve.state == ValveState::closed implies valve.patientSidePressure <= valve.reservoirSidePressure;
        }
    }

    requirement def GraduationRequirement {
        doc "The reservoir shall have graduations every 10 mL."
        subject reservoir : CollectionReservoir;
        objective {
            reservoir.graduationInterval == 10_000 [mm3];
        }
    }

    requirement def GravityOperationRequirement {
        doc "The system shall operate using gravity with the reservoir below the patient."
        subject drainSystem : ShirleyDrainSystem;
        objective {
            drainSystem.reservoirElevation < drainSystem.patientElevation;
        }
    }

    // ===== Enumerations =====

    enum def ValveState { open; closed; }
    enum def ReservoirState { empty; filling; full; vented; }

    // ===== Part Definitions =====

    part def DrainCatheter {
        attribute material : String = "Medical-grade silicone";
        attribute length : Length = 500 [mm];
        attribute innerDiameter : Diameter = 4 [mm];
        attribute outerDiameter : Diameter = 6 [mm];
        attribute perforationCount : Integer = 40;
        attribute perforationDiameter : Diameter = 1 [mm];
        attribute flexibility : Real = 0.85;

        port patientEnd : PatientPort;
        port valveEnd : FluidPort;

        action def ConductFluid {
            in item fluid : SerousFluid;
            out item drainedFluid : SerousFluid;
        }

        perform ConductFluid conductFluid {
            in item fluid = patientEnd.serousFluid;
            out item drainedFluid = valveEnd.serousFluid;
        }
    }

    part def AntiRefluxValve {
        attribute openingThreshold : Pressure = 50 [Pa];
        attribute maxBackflowPressure : Pressure = 0 [Pa];
        attribute state : ValveState = ValveState::closed;

        port patientSide : FluidPort;
        port reservoirSide : FluidPort;

        state def ValveStateMachine {
            entry; then closed;

            state closed {
                entry { state = ValveState::closed; }
                transition closed -> open
                    when patientSide.pressure > reservoirSide.pressure + openingThreshold;
            }

            state open {
                entry { state = ValveState::open; }
                transition open -> closed
                    when patientSide.pressure <= reservoirSide.pressure;
            }
        }

        exhibit ValveStateMachine valveBehavior;

        action def RegulateFlow {
            in item fluid : SerousFluid;
            out item regulatedFluid : SerousFluid;
        }

        perform RegulateFlow regulateFlow {
            in item fluid = patientSide.serousFluid;
            out item regulatedFluid = reservoirSide.serousFluid;
        }
    }

    part def CollectionReservoir {
        attribute capacity : Volume = 400_000 [mm3];
        attribute currentVolume : Volume = 0 [mm3];
        attribute graduationInterval : Volume = 10_000 [mm3];
        attribute material : String = "Rigid transparent polymer";
        attribute state : ReservoirState = ReservoirState::empty;
        ref attr reservoirElevation : Elevation;

        port inlet : FluidPort;
        port vent : AtmospherePort;

        state def ReservoirStateMachine {
            entry; then empty;

            state empty {
                entry { state = ReservoirState::empty; currentVolume = 0 [mm3]; }
                transition empty -> filling
                    when inlet.flowRate > 0 [mm3/s];
            }

            state filling {
                entry { state = ReservoirState::filling; }
                do { currentVolume = currentVolume + inlet.flowRate * 1 [s]; }
                transition filling -> full
                    when currentVolume >= capacity;
                transition filling -> vented
                    when vent.air != null;
            }

            state full {
                entry { state = ReservoirState::full; }
                transition full -> vented
                    when vent.air != null;
            }

            state vented {
                entry { state = ReservoirState::vented; }
                transition vented -> filling
                    when currentVolume < capacity and inlet.flowRate > 0 [mm3/s];
            }
        }

        exhibit ReservoirStateMachine reservoirBehavior;

        action def CollectFluid {
            in item fluid : SerousFluid;
            in item airIn : Air;
            out item displacedAir : Air;
        }

        perform CollectFluid collectFluid {
            in item fluid = inlet.serousFluid;
            in item airIn = vent.air;
            out item displacedAir = vent.serousFluid;
        }
    }

    part def PatientBodyCavity {
        attribute cavityType : String = "chest or abdomen";
        ref attr patientElevation : Elevation;
        attribute cavityPressure : Pressure = 101325 [Pa];

        port cavityPort : PatientPort {
            redefines pressure = cavityPressure;
        }

        item def BodyFluid :> SerousFluid;

        item bodyFluid : BodyFluid;

        action def ProduceFluid {
            out item fluid : BodyFluid;
        }

        perform ProduceFluid produceFluid {
            out item fluid = bodyFluid;
        }
    }

    // ===== Top-level System =====

    part def ShirleyDrainSystem {
        attribute systemName : String = "Shirley Drain System";
        attribute operationMode : String = "Passive gravity drainage";
        ref attr patientElevation : Elevation = 1000 [mm];
        ref attr reservoirElevation : Elevation = 0 [mm];
        attribute pressureGradient : Pressure = patientElevation * 9.81 [kg/(m*s^2)] - reservoirElevation * 9.81 [kg/(m*s^2)];

        part patientCavity : PatientBodyCavity {
            redefines patientElevation = patientElevation;
        }

        part catheter : DrainCatheter;

        part antiRefluxValve : AntiRefluxValve;

        part reservoir : CollectionReservoir {
            redefines reservoirElevation = reservoirElevation;
        }

        // Connections
        connection patientToCatheter connect patientCavity.cavityPort to catheter.patientEnd {
            item serousFluid flows from patientCavity.cavityPort to catheter.patientEnd;
        }

        connection catheterToValve connect catheter.valveEnd to antiRefluxValve.patientSide {
            item serousFluid flows from catheter.valveEnd to antiRefluxValve.patientSide;
        }

        connection valveToReservoir connect antiRefluxValve.reservoirSide to reservoir.inlet {
            item serousFluid flows from antiRefluxValve.reservoirSide to reservoir.inlet;
        }

        connection reservoirVent connect reservoir.vent to environment {
            item air flows from environment to reservoir.vent;
            item serousFluid flows from reservoir.vent to environment;
        }

        // System-level action
        action def DrainageOperation {
            in item fluid : SerousFluid;
            out item collectedFluid : SerousFluid;
        }

        perform DrainageOperation drainageOperation {
            in item fluid = patientCavity.bodyFluid;
            out item collectedFluid = reservoir.inlet.serousFluid;
        }

        satisfy DrainageRequirement;
        satisfy GravityOperationRequirement;
    }

    // ===== Requirement Satisfaction =====

    part def Environment {
        port atmosphere : AtmospherePort;
    }

    // ===== Verification =====

    verification def VerifyGravityOperation {
        subject drainSystem : ShirleyDrainSystem;
        objective {
            drainSystem.reservoirElevation < drainSystem.patientElevation;
        }
        return success : Boolean = drainSystem.reservoirElevation < drainSystem.patientElevation;
    }

    verification def VerifyAntiReflux {
        subject valve : AntiRefluxValve;
        objective {
            valve.state == ValveState::closed implies valve.patientSidePressure <= valve.reservoirSidePressure;
        }
        return success : Boolean = (valve.state == ValveState::closed) implies (valve.patientSide.pressure <= valve.reservoirSide.pressure);
    }

    verification def VerifyGraduations {
        subject reservoir : CollectionReservoir;
        objective {
            reservoir.graduationInterval == 10_000 [mm3];
        }
        return success : Boolean = reservoir.graduationInterval == 10_000 [mm3];
    }
}
