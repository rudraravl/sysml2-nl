package CapillaryIrrigationSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----
    value type Volume :> Real { unit 'm3'; }
    value type VolumeFlowRate :> Real { unit 'm3/s'; }
    value type Length :> Real { unit 'm'; }
    value type MoistureFraction :> Real { unit '1'; min 0.0; max 1.0; }
    value type Pressure :> Real { unit 'Pa'; }
    value type Density :> Real { unit 'kg/m3'; }
    value type MassFlowRate :> Real { unit 'kg/s'; }
    value type Duration :> Real { unit 's'; }
    value type Area :> Real { unit 'm2'; }

    // ---- Item Types ----
    item def Water;
    item def SoilMixture;
    item def CapillaryMedium;

    // ---- Port Definitions ----
    port def LiquidPort {
        out item water : Water;
        attribute volumetricFlowRate : VolumeFlowRate;
    }

    port def WickInterfacePort {
        out item medium : CapillaryMedium;
        attribute capillaryFlowRate : VolumeFlowRate;
        attribute isSaturated : Boolean;
    }

    port def SoilContactPort {
        in item water : Water;
        attribute moistureLevel : MoistureFraction;
        attribute targetMoisture : MoistureFraction;
    }

    // ---- Part Definitions ----

    part def Reservoir {
        attribute capacity : Volume = 0.020 [m3]; // 20 liters
        attribute currentVolume : Volume = 0.020 [m3];
        attribute waterDensity : Density = 1000 [kg/m3];
        attribute refillThreshold : Volume = 0.001 [m3];

        port liquidOut : LiquidPort {
            redefines volumetricFlowRate = currentVolume / 86400 [s]; // nominal daily draw
        }

        action def releaseWater {
            in waterDemand : VolumeFlowRate;
            out releasedVolume : Volume;
            // Water exits reservoir passively by gravity and capillary suction
        }

        attribute isDepleted : Boolean = (currentVolume <= 0.0 [m3]);

        action def refill {
            in refillAmount : Volume;
            // Manually refill the reservoir
        }
    }

    part def Wick {
        attribute length : Length = 0.50 [m];
        attribute crossSectionalArea : Area = 0.0001 [m2];
        attribute material : String = "felted cotton fiber";
        attribute porosity : Real = 0.65;
        attribute capillaryRiseHeight : Length = 0.45 [m];
        attribute maxFlowRate : VolumeFlowRate = 1.0e-8 [m3/s];
        attribute isPrimed : Boolean = false;

        port reservoirEnd : WickInterfacePort {
            redefines capillaryFlowRate = maxFlowRate;
            redefines isSaturated = isPrimed;
        }

        port soilEnd : WickInterfacePort {
            redefines capillaryFlowRate = maxFlowRate;
            redefines isSaturated = isPrimed;
        }

        action def prime {
            // Saturate the wick to initiate capillary action
            then assign isPrimed = true;
        }

        action def transportWater {
            in reservoirPressure : Pressure;
            in soilMoisture : MoistureFraction;
            out deliveredFlow : VolumeFlowRate;

            // Capillary action draws water along wick length
            // Flow rate decreases as soil moisture approaches saturation
            if soilMoisture < 0.30 then
                assign deliveredFlow = maxFlowRate;
            else if soilMoisture < 0.60 then
                assign deliveredFlow = maxFlowRate * (1.0 - soilMoisture) / 0.60;
            else
                assign deliveredFlow = 0.0 [m3/s];
        }
    }

    part def PlantingBed {
        attribute bedArea : Area = 1.0 [m2];
        attribute soilDepth : Length = 0.25 [m];
        attribute soilVolume : Volume = bedArea * soilDepth;
        attribute currentMoisture : MoistureFraction = 0.20;
        attribute targetMoisture : MoistureFraction = 0.50;
        attribute fieldCapacity : MoistureFraction = 0.60;
        attribute wiltingPoint : MoistureFraction = 0.15;
        attribute evaporationRate : VolumeFlowRate = 5.0e-9 [m3/s];
        attribute plantUptakeRate : VolumeFlowRate = 8.0e-9 [m3/s];

        port soilContact : SoilContactPort {
            redefines moistureLevel = currentMoisture;
            redefines targetMoisture = targetMoisture;
        }

        part def Plant {
            attribute rootDepth : Length = 0.15 [m];
            attribute waterUptakeRate : VolumeFlowRate = 4.0e-9 [m3/s];
            action def absorbWater {
                in soilMoisture : MoistureFraction;
                out uptake : VolumeFlowRate;
                if soilMoisture > wiltingPoint then
                    assign uptake = waterUptakeRate;
                else
                    assign uptake = 0.0 [m3/s];
            }
        }

        part plants : Plant[4];

        action def updateMoisture {
            in inflow : VolumeFlowRate;
            in outflow : VolumeFlowRate;
            // Soil moisture balance: inflow from wick minus plant uptake and evaporation
            assign currentMoisture = currentMoisture + (inflow - outflow) * 3600 [s] / soilVolume;
        }

        action def receiveWater {
            in deliveredFlow : VolumeFlowRate;
            // Water released from wick into soil
        }
    }

    // ---- Top-level System ----
    part def CapillaryIrrigationSystem {
        attribute systemName : String = "Passive Capillary Irrigation System";
        attribute isPassive : Boolean = true;
        attribute requiresPower : Boolean = false;
        attribute hasPump : Boolean = false;
        attribute hasElectronics : Boolean = false;

        part reservoir : Reservoir;
        part wick : Wick;
        part plantingBed : PlantingBed;

        connection reservoirToWick : LiquidPort connect reservoir.liquidOut to wick.reservoirEnd;
        connection wickToSoil : WickInterfacePort connect wick.soilEnd to plantingBed.soilContact;

        // ---- State Machine ----
        state def IrrigationStates {
            entry; then Initializing;

            state Initializing {
                entry action {
                    // Prime the wick by saturating it with water
                    perform wick.prime();
                }
                transition Initializing to ActiveWicking
                    when wick.isPrimed == true;
            }

            state ActiveWicking {
                entry action {
                    // System actively wicks water from reservoir to soil
                }
                do action {
                    // Continuous capillary transport
                    perform wick.transportWater(
                        reservoirPressure => 101325 [Pa],
                        soilMoisture => plantingBed.currentMoisture
                    );
                    perform plantingBed.updateMoisture(
                        inflow => wick.soilEnd.capillaryFlowRate,
                        outflow => plantingBed.evaporationRate + plantingBed.plantUptakeRate
                    );
                }
                transition ActiveWicking to Equilibrium
                    when plantingBed.currentMoisture >= plantingBed.targetMoisture * 0.95
                        and plantingBed.currentMoisture <= plantingBed.targetMoisture * 1.05;

                transition ActiveWicking to Depleted
                    when reservoir.isDepleted == true;
            }

            state Equilibrium {
                entry action {
                    // Water supply matches demand; moisture stable
                }
                do action {
                    // Maintain equilibrium; wick flow self-regulates
                    perform wick.transportWater(
                        reservoirPressure => 101325 [Pa],
                        soilMoisture => plantingBed.currentMoisture
                    );
                    perform plantingBed.updateMoisture(
                        inflow => wick.soilEnd.capillaryFlowRate,
                        outflow => plantingBed.evaporationRate + plantingBed.plantUptakeRate
                    );
                }
                transition Equilibrium to ActiveWicking
                    when plantingBed.currentMoisture < plantingBed.targetMoisture * 0.90;

                transition Equilibrium to Depleted
                    when reservoir.isDepleted == true;
            }

            state Depleted {
                entry action {
                    // Reservoir empty; system ceases to function
                }
                transition Depleted to Initializing
                    when reservoir.currentVolume > reservoir.refillThreshold
                    accept refill;
            }
        }

        stateMachine operation : IrrigationStates;

        // ---- Requirements ----
        requirement def PassiveOperationReq {
            doc "The system shall operate without pumps, electronics, or external power.";
            subject system : CapillaryIrrigationSystem;
            objective {
                assert system.requiresPower == false;
                assert system.hasPump == false;
                assert system.hasElectronics == false;
            }
        }

        requirement def ConsistentMoistureReq {
            doc "The system shall maintain soil moisture at a stable level ideal for plant growth.";
            subject system : CapillaryIrrigationSystem;
            attribute minMoisture : MoistureFraction = 0.40;
            attribute maxMoisture : MoistureFraction = 0.60;
            objective {
                assert system.plantingBed.currentMoisture >= minMoisture;
                assert system.plantingBed.currentMoisture <= maxMoisture;
            }
        }

        requirement def CapillaryTransportReq {
            doc "The wick shall transport water from the reservoir to the planting bed via capillary action against gravity.";
            subject wick : Wick;
            objective {
                assert wick.capillaryRiseHeight >= wick.length;
                assert wick.isPrimed == true;
            }
        }

        requirement def SelfRegulationReq {
            doc "The system shall self-regulate water delivery: increasing flow when soil is dry and reducing flow when soil is moist.";
            subject system : CapillaryIrrigationSystem;
            objective {
                assert system.plantingBed.currentMoisture < system.plantingBed.targetMoisture
                    implies system.wick.soilEnd.capillaryFlowRate > 0.0 [m3/s];
                assert system.plantingBed.currentMoisture >= system.plantingBed.fieldCapacity
                    implies system.wick.soilEnd.capillaryFlowRate == 0.0 [m3/s];
            }
        }

        requirement def ReservoirCapacityReq {
            doc "The reservoir shall hold sufficient water to sustain plants for at least 7 days without refill.";
            subject reservoir : Reservoir;
            attribute minDuration : Duration = 604800 [s]; // 7 days
            attribute dailyDemand : VolumeFlowRate = 1.3e-8 [m3/s];
            objective {
                assert reservoir.capacity >= dailyDemand * minDuration;
            }
        }

        requirement def DepletedStateReq {
            doc "When the reservoir is depleted, the system shall enter a depleted state and cease operation until manually refilled.";
            subject system : CapillaryIrrigationSystem;
            objective {
                assert system.reservoir.isDepleted == true
                    implies system.operation.isActive(Depleted) == true;
            }
        }

        requirement def InitializationReq {
            doc "The system shall be initialized by priming the wick before active wicking begins.";
            subject system : CapillaryIrrigationSystem;
            objective {
                assert system.operation.isActive(Initializing) == true
                    implies system.wick.isPrimed == false;
                assert system.operation.isActive(ActiveWicking) == true
                    implies system.wick.isPrimed == true;
            }
        }

        // ---- Requirement Satisfaction ----
        satisfy PassiveOperationReq by system;
        satisfy ConsistentMoistureReq by system;
        satisfy CapillaryTransportReq by wick;
        satisfy SelfRegulationReq by system;
        satisfy ReservoirCapacityReq by reservoir;
        satisfy DepletedStateReq by system;
        satisfy InitializationReq by system;
    }
}
