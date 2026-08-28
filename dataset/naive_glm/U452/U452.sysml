package TherapeuticWeightedBlanket {

    import ScalarValues::*;

    // ---- Value types with units ----
    value def MassValue :> Real { unit 'kg'; }
    value def AreaValue :> Real { unit 'm2'; }
    value def PressureValue :> Real { unit 'Pa'; }
    value def TemperatureValue :> Real {> Real { unit 'K'; }
    value def PercentValue :> Real { unit '%'; }
    value def LengthValue :> Real { unit 'm'; }
    value def DensityValue :> Real { unit 'kg/m3'; }

    // ---- Items ----
    item def GlassBead {
        attribute density : DensityValue = 2500;
        attribute beadDiameter : LengthValue = 0.001;
    }
    item def CottonFabric {
        attribute breathability : Real = 0.85;
        attribute threadCount : Integer = 300;
    }
    item def PolyesterFabric {
        attribute breathability : Real = 0.65;
        attribute threadCount : Integer = 200;
    }
    item def Air {
        attribute temperature : TemperatureValue;
    }

    // ---- Requirements ----
    requirement def TherapeuticGoal {
        doc /* The blanket shall reduce stress and anxiety and promote relaxation and comfort. */
        subject blanket : TherapeuticWeightedBlanketSystem;
        require { blanket.therapeuticEffectActive implies blanket.user.stressLevel < blanket.user.initialStressLevel; }
    }

    requirement def WeightCalibration {
        doc /* Total weight shall be approximately 10 percent of user body mass. */
        subject blanket : TherapeuticWeightedBlanketSystem;
        attribute bodyMass : MassValue;
        attribute targetWeight : MassValue = bodyMass * 0.10;
        require { blanket.totalWeight >= targetWeight * 0.95 and blanket.totalWeight <= targetWeight * 1.05; }
    }

    requirement def UniformDistribution {
        doc /* Weight shall be distributed uniformly across the surface. */
        subject blanket : TherapeuticWeightedBlanketSystem;
        require { blanket.compartmentGrid.distributionUniformity >= 0.95; }
    }

    requirement def BreathabilityRequirement {
        doc /* Materials shall be breathable to prevent overheating. */
        subject blanket : TherapeuticWeightedBlanketSystem;
        require { blanket.outerLayer.material.breathability >= 0.70; }
    }

    requirement def SafePressure {
        doc /* Applied pressure shall remain within safe therapeutic range. */
        subject blanket : TherapeuticWeightedBlanketSystem;
        attribute maxSafePressure : PressureValue = 1500;
        require { blanket.appliedPressure <= maxSafePressure; }
    }

    // ---- Ports ----
    port def ThermalPort {
        attribute temperature : TemperatureValue;
        out heatFlow : Real;
    }

    port def PressurePort {
        out appliedPressure : PressureValue;
    }

    port def UserContactPort {
        in receivedPressure : PressureValue;
        in receivedHeatFlow : Real;
    }

    // ---- Parts ----
    part def CottonLayer {
        attribute material : CottonFabric;
        attribute thickness : LengthValue = 0.002;
        port outerSurface : ThermalPort;
    }

    part def PolyesterLayer {
        attribute material : PolyesterFabric;
        attribute thickness : LengthValue = 0.0015;
        port innerSurface : ThermalPort;
    }

    part def Compartment {
        attribute sideLength : LengthValue = 0.10;
        attribute fillMass : MassValue = 0.05;
        attribute area : AreaValue = sideLength * sideLength;
        item beads : GlassBead[*];
    }

    part def CompartmentGrid {
        attribute rows : Integer = 20;
        attribute columns : Integer = 15;
        attribute distributionUniformity : Real = 0.98;
        attribute gridArea : AreaValue = rows * columns * (0.10 * 0.10);
        part compartments : Compartment[rows * columns];
    }

    part def User {
        attribute bodyMass : MassValue;
        attribute initialStressLevel : Real = 0.7;
        attribute stressLevel : Real;
        port contact : UserContactPort;
    }

    part def TherapeuticWeightedBlanketSystem {
        attribute totalWeight : MassValue;
        attribute appliedPressure : PressureValue;
        attribute surfaceArea : AreaValue;
        attribute therapeuticEffectActive : Boolean = false;
        attribute userBodyMass : MassValue;

        port pressureOutput : PressurePort;
        port thermalOutput : ThermalPort;

        part outerLayer : CottonLayer;
        part innerLayer : PolyesterLayer;
        part compartmentGrid : CompartmentGrid;
        part user : User {
            redefines bodyMass = userBodyMass;
        }

        // ---- State machine ----
        state def Lifecycle {
            entry; then Stored;

            state Stored {
                entry { therapeuticEffectActive = false; }
            }

            transition from Stored to ReadyForUse
                accept prepare;

            state ReadyForUse {
                entry { therapeuticEffectActive = false; }
            }

            transition from ReadyForUse to InUse
                accept deploy;

            state InUse {
                entry { therapeuticEffectActive = true; }
                do applyTherapeuticEffect;
                exit { therapeuticEffectActive = false; }
            }

            transition from InUse to ReadyForUse
                accept remove;

            transition from ReadyForUse to Maintenance
                accept clean;

            transition from InUse to Maintenance
                accept clean;

            state Maintenance {
                entry { therapeuticEffectActive = false; }
            }

            transition from Maintenance to Stored
                accept store;
        }

        state machine lifecycle : Lifecycle;

        // ---- Actions ----
        action applyTherapeuticEffect {
            in userMass : MassValue;
            out pressure : PressureValue;
        }

        action def ComputePressure {
            in blanketWeight : MassValue;
            in area : AreaValue;
            out pressure : PressureValue;
        }

        // ---- Connections ----
        connection pressureLink connect pressureOutput to user.contact;
        connection thermalLink connect thermalOutput to user.contact;
        connection outerToGrid connect outerLayer.innerSurface to innerLayer.innerSurface;
        connection innerToGrid connect innerLayer.innerSurface to compartmentGrid;
    }

    // ---- Connection definitions ----
    connection def PressureLink {
        end source : PressurePort;
        end sink : UserContactPort;
    }

    connection def ThermalLink {
        end source : ThermalPort;
        end sink : UserContactPort;
    }

    connection def FabricBond {
        end layerA : ThermalPort;
        end layerB : ThermalPort;
    }

    // ---- Usage context ----
    part def BlanketUsageContext {
        part blanket : TherapeuticWeightedBlanketSystem {
            redefines userBodyMass = 70;
            redefines totalWeight = 7.0;
            redefinitions surfaceArea = 1.8;
            redefinitions appliedPressure = totalWeight * 9.81 / surfaceArea;
        }

        requirement weightReq : WeightCalibration {
            subject = blanket;
            attribute bodyMass = 70;
        }

        requirement uniformReq : UniformDistribution {
            subject = blanket;
        }

        requirement breathReq : BreathabilityRequirement {
            subject = blanket;
        }

        requirement safeReq : SafePressure {
            subject = blanket;
        }

        requirement goalReq : TherapeuticGoal {
            subject = blanket;
        }
    }

}
