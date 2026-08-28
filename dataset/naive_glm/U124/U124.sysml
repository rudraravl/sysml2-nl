package SurgicalMaskSystem {

    import ScalarValues::*;
    import SI::*;

    unit g_per_m2;

    value type Length :> Real { unit = mm; }
    value type MassPerArea :> Real { unit = g_per_m2; }
    value type Pressure :> Real { unit = Pa; }
    value type Force :> Real { unit = N; }
    value type Temperature :> Real { unit = K; }
    value type Volume :> Real { unit = L; }
    value type Time :> Real { unit = s; }
    value type Percent :> Real;
    value type Efficiency :> Percent;
    value type Dimensionless :> Real;

    item def Air {
        attribute temperature : Temperature;
        attribute humidity : Percent;
    }

    item def AmbientAir :> Air {
        attribute ambientPressure : Pressure;
        item suspendedParticles : Particle[0..*];
    }

    item def FilteredAir :> Air {
        attribute residualParticleCount : Integer;
    }

    item def ExhaledAir :> Air {
        attribute co2Fraction : Dimensionless;
    }

    item def Particle {
        attribute diameter : Length;
        attribute pathogenic : Boolean;
    }

    item def SubMicronParticle :> Particle;

    item def FluidSplash {
        attribute impactPressure : Pressure;
    }

    port def AirEntryPort {
        in item : AmbientAir;
        in item : FluidSplash;
    }

    port def AirExitPort {
        out item : FilteredAir;
    }

    port def ExhalationPort {
        in item : ExhaledAir;
    }

    part def Material {
        attribute basisWeight : MassPerArea;
        attribute thickness : Length;
        attribute tensileStrength : Force;
    }

    part def SpunbondPolypropylene :> Material {
        attribute fluidResistance : Pressure;
    }

    part def MeltblownPolypropylene :> Material {
        attribute electrostaticChargeDensity : Dimensionless;
        attribute fiberDiameter : Length;
    }

    part def AluminumAlloy {
        attribute yieldStrength : Force;
        attribute flexibility : Dimensionless;
    }

    part def ElasticMaterial {
        attribute elongationAtBreak : Percent;
        attribute elasticModulus : Dimensionless;
    }

    part def FilterLayer {
        part material : Material;
        attribute particleFiltrationEfficiency : Efficiency;
        attribute breathability : Pressure;
        port airIn : AirEntryPort;
        port airOut : AirExitPort;
        action def filterAction {
            in inflowingAir : AmbientAir;
            in incomingSplash : FluidSplash;
            out outgoingAir : FilteredAir;
        }
    }

    part def OuterLayer :> FilterLayer {
        part material : SpunbondPolypropylene;
        attribute fluidSplashResistance : Pressure;
        attribute coarseParticleEfficiency : Efficiency;
    }

    part def MiddleLayer :> FilterLayer {
        part material : MeltblownPolypropylene;
        attribute subMicronEfficiency : Efficiency;
    }

    part def InnerLayer :> FilterLayer {
        part material : SpunbondPolypropylene;
        attribute skinContact : Boolean;
        attribute comfortRating : Dimensionless;
    }

    part def NosePiece {
        part wire : AluminumAlloy;
        attribute length : Length;
        attribute moldability : Dimensionless;
        attribute sealQuality : Dimensionless;
        action def moldToNose {
            in facialDimensions : Length;
            out sealAchieved : Boolean;
        }
    }

    part def EarLoop {
        part cord : ElasticMaterial;
        attribute loopLength : Length;
        attribute retentionForce : Force;
    }

    part def Wearer {
        attribute faceWidth : Length;
        attribute noseBridgeHeight : Length;
        attribute tidalVolume : Volume;
    }

    action def DonMask {
        in mask : SurgicalMask;
        out secured : Boolean;
        out sealed : Boolean;
    }

    action def Inhale {
        in ambient : AmbientAir;
        out filtered : FilteredAir;
    }

    action def Exhale {
        in exhaled : ExhaledAir;
        out expelled : ExhaledAir;
    }

    part def SurgicalMask {
        part outer : OuterLayer {
            attribute fluidSplashResistance : Pressure = 1200 [Pa];
            attribute coarseParticleEfficiency : Efficiency = 85;
            attribute particleFiltrationEfficiency : Efficiency = 85;
            attribute breathability : Pressure = 30 [Pa];
            part material : SpunbondPolypropylene {
                attribute basisWeight : MassPerArea = 25 [g_per_m2];
                attribute fluidResistance : Pressure = 1200 [Pa];
            }
        }

        part middle : MiddleLayer {
            attribute subMicronEfficiency : Efficiency = 98.5;
            attribute particleFiltrationEfficiency : Efficiency = 98.5;
            attribute breathability : Pressure = 35 [Pa];
            part material : MeltblownPolypropylene {
                attribute basisWeight : MassPerArea = 25 [g_per_m2];
                attribute electrostaticChargeDensity : Dimensionless = 0.7;
                attribute fiberDiameter : Length = 2 [mm];
            }
        }

        part inner : InnerLayer {
            attribute skinContact : Boolean = true;
            attribute comfortRating : Dimensionless = 8;
            attribute particleFiltrationEfficiency : Efficiency = 90;
            attribute breathability : Pressure = 25 [Pa];
            part material : SpunbondPolypropylene {
                attribute basisWeight : MassPerArea = 20 [g_per_m2];
            }
        }

        part nosePiece : NosePiece {
            attribute length : Length = 90 [mm];
            attribute sealQuality : Dimensionless = 0.9;
            part wire : AluminumAlloy {
                attribute yieldStrength : Force = 2.5 [N];
                attribute flexibility : Dimensionless = 0.9;
            }
        }

        part earLoops : EarLoop[2] {
            attribute loopLength : Length = 175 [mm];
            attribute retentionForce : Force = 3 [N];
            part cord : ElasticMaterial {
                attribute elongationAtBreak : Percent = 300;
            }
        }

        part wearer : Wearer;

        port ambient : AirEntryPort;
        port breathing : AirExitPort;
        port exhale : ExhalationPort;

        connection ambientToOuter {
            connect ambient to outer.airIn;
        }
        connection outerToMiddle {
            connect outer.airOut to middle.airIn;
        }
        connection middleToInner {
            connect middle.airOut to inner.airIn;
        }
        connection innerToUser {
            connect inner.airOut to breathing;
        }

        action don : DonMask;
        action inhale : Inhale;
        action exhale : Exhale;

        state machine operation {
            state OffFace;
            state Donning;
            state Sealed;
            state Inhaling;
            state Exhaling;
            state Removed;

            transition t1 from OffFace to Donning / don;
            transition t2 from Donning to Sealed when don.sealed;
            transition t3 from Sealed to Inhaling / inhale;
            transition t4 from Inhaling to Sealed;
            transition t5 from Sealed to Exhaling / exhale;
            transition t6 from Exhaling to Sealed;
            transition t7 from Sealed to Removed;
            transition t8 from Removed to OffFace;
        }

        satisfy maskFiltration : FiltrationEfficiencyRequirement;
        satisfy maskFluid : FluidResistanceRequirement;
        satisfy maskBreath : BreathabilityRequirement;
        satisfy maskFitment : FitmentRequirement;
    }

    requirement def FiltrationEfficiencyRequirement {
        subject mask : SurgicalMask;
        attribute minSubMicronEfficiency : Efficiency = 98;
        attribute minCoarseEfficiency : Efficiency = 80;
        require constraint {
            mask.middle.subMicronEfficiency >= minSubMicronEfficiency
        }
        require constraint {
            mask.outer.coarseParticleEfficiency >= minCoarseEfficiency
        }
    }

    requirement def FluidResistanceRequirement {
        subject mask : SurgicalMask;
        attribute minFluidResistance : Pressure = 1200 [Pa];
        require constraint {
            mask.outer.fluidSplashResistance >= minFluidResistance
        }
    }

    requirement def BreathabilityRequirement {
        subject mask : SurgicalMask;
        attribute maxTotalBreathability : Pressure = 100 [Pa];
        require constraint {
            (mask.outer.breathability + mask.middle.breathability
             + mask.inner.breathability) <= maxTotalBreathability
        }
    }

    requirement def FitmentRequirement {
        subject mask : SurgicalMask;
        attribute minRetentionForce : Force = 2 [N];
        attribute maxRetentionForce : Force = 4 [N];
        attribute minSealQuality : Dimensionless = 0.8;
        require constraint {
            mask.earLoops.retentionForce >= minRetentionForce
        }
        require constraint {
            mask.earLoops.retentionForce <= maxRetentionForce
        }
        require constraint {
            mask.nosePiece.sealQuality >= minSealQuality
        }
    }
}
