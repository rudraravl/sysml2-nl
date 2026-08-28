package IcePackModel {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQThermodynamics::*;

    // ---- Value types with units ----
    value type TemperatureValue :> Real { unit 'K'; }
    value type DurationValue :> Real { unit 'h'; }
    value type VolumeValue :> Real { unit 'm^3'; }
    value type MassValue :> Real { unit 'kg'; }
    value type EnergyValue :> Real { unit 'J'; }
    value type LatentHeatValue :> Real { unit 'J/kg'; }
    value type SpecificHeatValue :> Real { unit 'J/(kg*K)'; }
    value type ThermalConductivityValue :> Real { unit 'W/(m*K)'; }
    value type HeatFluxValue :> Real { unit 'W'; }
    value type ThicknessValue :> Real { unit 'm'; }
    value type AreaValue :> Real { unit 'm^2'; }
    value type DensityValue :> Real { unit 'kg/m^3'; }
    value type PressureValue :> Real { unit 'Pa'; }

    // ---- Item types ----
    item def CoolantGel {
        attribute latentHeatOfFusion : LatentHeatValue = 336000 [J/kg];
        attribute specificHeatFrozen : SpecificHeatValue = 2100 [J/(kg*K)];
        attribute specificHeatLiquid : SpecificHeatValue = 4200 [J/(kg*K)];
        attribute meltingPoint : TemperatureValue = 273.15 [K];
        attribute density : DensityValue = 1050 [kg/m^3];
        attribute mass : MassValue;
        attribute phase : FrozenPhase;
    }

    enum def FrozenPhase { frozen; melting; liquid; }

    item def PolyethyleneMaterial {
        attribute thermalConductivity : ThermalConductivityValue = 0.46 [W/(m*K)];
        attribute thickness : ThicknessValue = 0.0015 [m];
        attribute tensileStrength : PressureValue = 30000000 [Pa];
    }

    item def InsulationMaterial {
        attribute thermalConductivity : ThermalConductivityValue = 0.04 [W/(m*K)];
        attribute thickness : ThicknessValue = 0.01 [m];
    }

    // ---- Port definitions ----
    port def ThermalPort {
        attribute temperature : TemperatureValue;
        out heatFlux : HeatFluxValue;
    }

    // ---- Parts ----
    part def Pouch {
        attribute material : PolyethyleneMaterial;
        attribute internalVolume : VolumeValue = 0.0005 [m^3];
        attribute leakProof : Boolean = true;
        attribute flexible : Boolean = true;
        port thermalInner : ThermalPort;
        port thermalOuter : ThermalPort;
    }

    part def InsulationLayer {
        attribute material : InsulationMaterial;
        attribute surfaceArea : AreaValue = 0.03 [m^2];
        port innerSurface : ThermalPort;
        port outerSurface : ThermalPort;
    }

    part def CoolantCore {
        item gel : CoolantGel {
            attribute mass = 0.525 [kg];
        }
        attribute currentTemperature : TemperatureValue;
        attribute meltFraction : Real = 0.0;
        port thermalInterface : ThermalPort;
    }

    // ---- Ice Pack assembly ----
    part def IcePack {
        part coolantCore : CoolantCore {
            attribute currentTemperature = 253.15 [K];
        }
        part pouch : Pouch;
        part insulation : InsulationLayer;

        // Connections between parts
        connection coolantCore.thermalInterface to pouch.thermalInner;
        connection pouch.thermalOuter to insulation.innerSurface;
        connection insulation.outerSurface to environmentPort;

        port environmentPort : ThermalPort;

        // State machine for lifecycle
        behavior lifecycle :>> stateBehavior {
            state frozen {
                entry coolantCore.currentTemperature := 253.15 [K];
                coolantCore.gel.phase := FrozenPhase::frozen;
                transition melting_transition
                    if coolantCore.currentTemperature >= 273.15 [K] then melting;
            }
            state melting {
                entry coolantCore.gel.phase := FrozenPhase::melting;
                do {
                    // Absorb latent heat while melting
                    coolantCore.meltFraction := coolantCore.meltFraction + (incomingHeatFlux / (coolantCore.gel.mass * coolantCore.gel.latentHeatOfFusion)) * 0.0002778;
                    if coolantCore.meltFraction >= 1.0 then transition to liquid;
                }
                transition liquid_transition
                    if coolantCore.meltFraction >= 1.0 then liquid;
            }
            state liquid {
                entry coolantCore.gel.phase := FrozenPhase::liquid;
                transition ambient_transition
                    if coolantCore.currentTemperature >= 295.15 [K] then ambient;
            }
            state ambient {
                // Pack has warmed to ambient; ready for refreezing
            }
            transition init
                first then frozen;
        }

        attribute incomingHeatFlux : HeatFluxValue;
    }

    // ---- Requirements ----
    requirement def CoolingDurationRequirement {
        subject icePack : IcePack;
        objective {
            doc /* The ice pack shall maintain its core temperature below 4°C (277.15 K) for at least 3 hours under nominal ambient conditions. */
        }
        constraint { icePack.coolantCore.currentTemperature <= 277.15 [K] }
        constraint { duration >= 3.0 [h] }
    }

    requirement def LeakProofRequirement {
        subject pouch : Pouch;
        objective {
            doc /* The pouch shall be leak-proof under normal handling and flexing. */
        }
        constraint { pouch.leakProof == true }
    }

    requirement def InsulationRequirement {
        subject insulation : InsulationLayer;
        objective {
            doc /* The insulation layer shall reduce heat flux to extend cooling time. */
        }
        constraint { insulation.material.thermalConductivity <= 0.05 [W/(m*K)] }
    }

    requirement def LatentHeatRequirement {
        subject gel : CoolantGel;
        objective {
            doc /* The coolant gel shall have a latent heat of fusion sufficient for sustained cooling. */
        }
        constraint { gel.latentHeatOfFusion >= 300000 [J/kg] }
    }

    // ---- Verification ----
    verification CoolingDurationTest {
        objective {
            doc /* Verify the ice pack maintains below 277.15 K for at least 3 hours in a 295.15 K ambient environment. */
        }
        subject icePack : IcePack;
    }

    verification LeakTest {
        objective {
            doc /* Verify the pouch does not leak under flexing and pressure. */
        }
        subject pouch : Pouch;
    }
}
