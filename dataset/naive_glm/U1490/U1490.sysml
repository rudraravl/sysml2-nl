package MechanicalSafetyReliefSystem {

import ScalarValues::*;

// ============================================================
// Units
// ============================================================

unit pascal;
unit newton;
unit meter;
unit millimeter = 0.001 [meter];
unit bar = 100000 [pascal];
unit kilonewton = 1000 [newton];
unit kilogram_per_second;
unit newton_per_millimeter;
unit kelvin;

// ============================================================
// Value Types
// ============================================================

value type Pressure :> Real {
    unit pascal;
}

value type Force :> Real {
    unit newton;
}

value type Length :> Real {
    unit meter;
}

value type MassFlowRate :> Real {
    unit kilogram_per_second;
}

value type SpringConstant :> Real {
    unit newton_per_millimeter;
}

value type Temperature :> Real {
    unit kelvin;
}

// ============================================================
// Items
// ============================================================

item def PressurizedFluid {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute flowRate : MassFlowRate;
    attribute density : Real;
}

// ============================================================
// Ports
// ============================================================

port def FluidPort {
    attribute pressure : Pressure;
    in item : PressurizedFluid;
    out item : PressurizedFluid;
}

// ============================================================
// Connections
// ============================================================

connection def FluidConnection {
    end source : FluidPort;
    end target : FluidPort;
    item flow : PressurizedFluid;
}

// ============================================================
// Requirements
// ============================================================

requirement def OverpressureProtectionRequirement {
    doc /* The system shall automatically protect the pressurized vessel
            from catastrophic failure due to over-pressurization by venting
            excess pressure to a safe discharge location when operational
            limits are exceeded. */
    subject reliefSystem : MechanicalSafetyReliefSystem;
}

requirement def SetPressureRequirement {
    doc /* When the pressure inside the vessel reaches the predetermined
            set pressure, the fluid force shall overcome the spring force,
            causing the valve disc to lift off its seat, transitioning the
            valve from fullyClosed to opening. */
    subject valve : SafetyValve;
    attribute setPressure : Pressure;
}

requirement def BlowdownPressureRequirement {
    doc /* Once the pressure falls to the lower safe threshold known as the
            blowdown pressure, the spring force shall once again overcome the
            fluid pressure, pushing the valve disc back down through the
            closing state until fullyClosed, re-sealing the vessel. */
    subject valve : SafetyValve;
    attribute blowdownPressure : Pressure;
}

requirement def MaximumDischargeCapacityRequirement {
    doc /* When in the fullyOpen state, the valve shall vent fluid from the
            vessel through the valve outlet into the discharge system at its
            maximum rated capacity. */
    subject valve : SafetyValve;
    attribute maxRatedCapacity : MassFlowRate;
}

requirement def AutomaticReseatingRequirement {
    doc /* The automatic reseating shall allow the protected system to
            return to normal operation without manual intervention. */
    subject valve : SafetyValve;
}

requirement def ContinuousMonitoringRequirement {
    doc /* The safety valve shall be installed directly on the vessel to
            continuously monitor its internal pressure. */
    subject valve : SafetyValve;
}

requirement def NormalSealRequirement {
    doc /* Under normal operating conditions, the force of the pre-loaded
            spring shall be greater than the force exerted by the fluid
            pressure, holding the valve disc firmly shut and creating a
            tight seal. */
    subject valve : SafetyValve;
}

// ============================================================
// Protected Vessel
// ============================================================

part def ProtectedVessel {
    port outletPort : FluidPort;

    attribute internalPressure : Pressure;
    attribute safeOperatingPressure : Pressure = 7 [bar];
    attribute maxAllowablePressure : Pressure = 12 [bar];
    attribute volume : Real = 500;

    action def BuildUpPressure {
        in initialPressure : Pressure;
        out finalPressure : Pressure;
    }

    action def RelievePressure {
        out relievedPressure : Pressure;
    }

    state machine VesselOperatingStates {
        state normal;
        state overpressure;

        transition normal -> overpressure
            when (internalPressure > safeOperatingPressure);
        transition overpressure -> normal
            when (internalPressure <= safeOperatingPressure);
    }
}

// ============================================================
// Safety Valve Body
// ============================================================

part def SafetyValveBody {
    attribute material : String;
    attribute inletDiameter : Length = 50 [millimeter];
    attribute outletDiameter : Length = 80 [millimeter];
    attribute ratedCapacity : MassFlowRate = 5 [kilogram_per_second];
    attribute bodyStrength : Pressure = 20 [bar];
}

// ============================================================
// Pressure Sensor
// ============================================================

part def PressureSensor {
    attribute measuredPressure : Pressure;
    attribute measurementRange : Pressure = 15 [bar];
    attribute accuracy : Real = 0.5;

    action def MeasurePressure {
        in fluid : PressurizedFluid;
        out measuredPressure : Pressure;
    }

    perform action measure : MeasurePressure;
}

// ============================================================
// Valve Disc
// ============================================================

part def ValveDisc {
    attribute discDiameter : Length = 40 [millimeter];
    attribute seatDiameter : Length = 38 [millimeter];
    attribute sealIntegrity : Boolean = true;
    attribute liftPosition : Length = 0 [millimeter];
    attribute maxLift : Length = 5 [millimeter];

    action def Lift {
        in targetLift : Length;
        out newLiftPosition : Length;
    }

    action def Reseal {
        out newLiftPosition : Length;
    }
}

// ============================================================
// Spring Mechanism
// ============================================================

part def SpringMechanism {
    attribute springConstant : SpringConstant = 200 [newton_per_millimeter];
    attribute preloadForce : Force = 1000 [newton];
    attribute maxCompression : Length = 10 [millimeter];
    attribute currentCompression : Length = 0 [millimeter];

    action def ApplyForce {
        in compression : Length;
        out appliedForce : Force;
    }

    action def ReturnForce {
        out returnForce : Force;
    }

    perform action applyForce : ApplyForce;
    perform action returnForce : ReturnForce;
}

// ============================================================
// Safety Valve
// ============================================================

part def SafetyValve {
    port inletPort : FluidPort;
    port outletPort : FluidPort;

    part body : SafetyValveBody;
    part pressureSensor : PressureSensor;
    part valveDisc : ValveDisc;
    part spring : SpringMechanism;

    attribute setPressure : Pressure = 10 [bar];
    attribute blowdownPressure : Pressure = 8 [bar];
    attribute currentPressure : Pressure;
    attribute discLift : Length = 0 [millimeter];
    attribute springForce : Force;
    attribute fluidForce : Force;
    attribute isSealed : Boolean = true;

    action def MonitorPressure {
        in fluid : PressurizedFluid;
        out pressure : Pressure;
    }

    action def OpenValve {
        out lift : Length;
    }

    action def CloseValve {
        out lift : Length;
    }

    action def VentFluid {
        in fluid : PressurizedFluid;
        out dischargedFluid : PressurizedFluid;
    }

    state machine ValveStates {
        state fullyClosed {
            entry {
                springForce = spring.preloadForce;
                isSealed = true;
            }
        }

        state opening {
            entry {
                valveDisc.Lift;
                isSealed = false;
            }
        }

        state fullyOpen {
            entry {
                body.ratedCapacity;
                VentFluid;
            }
        }

        state closing {
            entry {
                valveDisc.Reseal;
            }
        }

        transition fullyClosed -> opening
            when (currentPressure >= setPressure);

        transition opening -> fullyOpen
            when (discLift >= valveDisc.maxLift);

        transition fullyOpen -> closing
            when (currentPressure <= blowdownPressure);

        transition closing -> fullyClosed
            when (discLift <= 0 [millimeter]);
    }
}

// ============================================================
// Discharge System
// ============================================================

part def DischargeSystem {
    port inletPort : FluidPort;

    attribute dischargeCapacity : MassFlowRate = 5 [kilogram_per_second];
    attribute dischargeLocation : String;
    attribute isSafeDischargeLocation : Boolean = true;

    action def VentFluid {
        in fluid : PressurizedFluid;
    }

    action def DisperseToAtmosphere {
        in fluid : PressurizedFluid;
    }

    perform action vent : VentFluid;
    perform action disperse : DisperseToAtmosphere;
}

// ============================================================
// Top-Level System
// ============================================================

part def MechanicalSafetyReliefSystem {
    part protectedVessel : ProtectedVessel;
    part safetyValve : SafetyValve;
    part dischargeSystem : DischargeSystem;

    connection : FluidConnection connect
        protectedVessel.outletPort to safetyValve.inletPort;
    connection : FluidConnection connect
        safetyValve.outletPort to dischargeSystem.inletPort;

    satisfy overpressureReq : OverpressureProtectionRequirement by self;
    satisfy setPressureReq : SetPressureRequirement by safetyValve;
    satisfy blowdownReq : BlowdownPressureRequirement by safetyValve;
    satisfy maxCapacityReq : MaximumDischargeCapacityRequirement by safetyValve;
    satisfy autoReseatingReq : AutomaticReseatingRequirement by safetyValve;
    satisfy continuousMonitoringReq : ContinuousMonitoringRequirement by safetyValve;
    satisfy normalSealReq : NormalSealRequirement by safetyValve;
}

}
