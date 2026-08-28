package Gelesis100 {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ============================================================
    // Value Types
    // ============================================================

    value def pH :> Real;
    value def SwellingRatio :> Real;
    value def Viscosity :> Real;
    value def Elasticity :> Real;
    value def DegradationLevel :> Real;
    value def SatietyLevel :> Real;
    value def CapsuleCount :> Integer;
    value def AbsorptionRate :> Real;

    // ============================================================
    // Item Definitions
    // ============================================================

    item def CapsuleShell {
        attribute dissolvesBelow : pH = 3.0;
        attribute shellMass : Mass = 75 [mg];
        attribute material : String = "gelatin-based enteric shell";
    }

    item def SuperabsorbentParticle {
        attribute composition : String = "cross-linked cellulose and citric acid";
        attribute dryDiameter : Length = 0.5 [mm];
        attribute dryMass : Mass = 0.5 [mg];
        attribute swellingCapacity : SwellingRatio = 100;
        attribute hydrated : Boolean = false;
    }

    item def Water {
        attribute volume : Volume;
    }

    item def GastricFluid {
        attribute pH : pH = 1.5;
        attribute volume : Volume;
        attribute temperature : Temperature = 37 [degC];
    }

    item def Food {
        attribute volume : Volume;
        attribute viscosity : Viscosity = 10 [cP];
    }

    item def GelMatrix {
        attribute volume : Volume;
        attribute viscosity : Viscosity;
        attribute elasticity : Elasticity;
        attribute degradationLevel : DegradationLevel = 0.0;
        attribute particleCount : CapsuleCount;
    }

    item def DegradedMaterial {
        attribute volume : Volume;
        attribute degradationLevel : DegradationLevel = 1.0;
    }

    item def SatietySignal {
        attribute level : SatietyLevel;
    }

    item def BloodstreamMarker {
        attribute concentration : MassConcentration = 0 [mg/L];
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def IngestionPort {
        in item capsules : Gelesis100Capsule[0..*];
        in item water : Water[0..*];
        in item food : Food[0..*];
    }

    port def GastricReleasePort {
        out item releasedParticles : SuperabsorbentParticle[0..*];
    }

    port def FluidExchangePort {
        in item gastricFluid : GastricFluid;
        out item absorbedFluid : GastricFluid;
    }

    port def GelTransitPort {
        in item gelIn : GelMatrix[0..*];
        out item gelOut : GelMatrix[0..*];
    }

    port def EliminationPort {
        out item degradedMaterial : DegradedMaterial[0..*];
    }

    port def SatietyPort {
        out signal satiety : SatietySignal;
    }

    port def SystemicCheckPort {
        out item marker : BloodstreamMarker;
    }

    // ============================================================
    // Part Definitions
    // ============================================================

    part def Gelesis100Capsule {
        attribute capsuleMass : Mass = 250 [mg];
        attribute particleCount : CapsuleCount = 100;
        attribute dosagePerMeal : CapsuleCount = 3;
        attribute waterRequired : Volume = 250 [mL];

        part shell : CapsuleShell;
        part particles : SuperabsorbentParticle[*] = SuperabsorbentParticle{dryMass = 0.5 [mg]} [*];

        port releasePort : GastricReleasePort;

        action def DissolveShell {
            in shell : CapsuleShell;
            in fluid : GastricFluid;
            out particles : SuperabsorbentParticle[*];
            precondition fluid.pH < shell.dissolvesBelow;
        }

        perform DissolveShell;
    }

    part def Stomach {
        attribute pH : pH = 1.5;
        attribute capacity : Volume = 1000 [mL];
        attribute currentVolume : Volume = 0 [mL];
        attribute residenceTime : Duration = 30 [min];

        in port ingestion : IngestionPort;
        port fluidPort : FluidExchangePort;
        port pyloricPort : GelTransitPort;
        port satietyOutput : SatietyPort;

        item storedFluid : GastricFluid;
        item storedFood : Food;
        item gelMatrix : GelMatrix;

        action def HydrateParticles {
            in particles : SuperabsorbentParticle[*];
            in fluid : GastricFluid;
            in water : Water;
            out gel : GelMatrix;
            attribute targetSwelling : SwellingRatio = 100;
            // Each particle swells to ~100x its original size
        }

        action def MixWithFood {
            in gel : GelMatrix;
            in food : Food;
            out mixedGel : GelMatrix;
            // Increases meal volume and viscosity
        }

        action def InduceSatiety {
            in gel : GelMatrix;
            out signal : SatietySignal;
            // Physical presence in stomach triggers fullness
        }

        state machine StomachBehavior {
            entry;
            state Empty;
            state CapsuleIngested;
            state ShellDissolving;
            state ParticlesHydrating;
            state GelFormed;
            state MixedWithFood;
            state SatietyInduced;
            state Emptying;

            transition Empty -> CapsuleIngested
                when ingestion.capsules->notEmpty();
            transition CapsuleIngested -> ShellDissolving
                when pH < 3.0;
            transition ShellDissolving -> ParticlesHydrating
                when releasePort.releasedParticles->notEmpty();
            transition ParticlesHydrating -> GelFormed
                when gelMatrix.volume >= 100 * (particles.dryMass->sum());
            transition GelFormed -> MixedWithFood
                when storedFood->notEmpty();
            transition MixedWithFood -> SatietyInduced
                when satietyOutput.satiety.level > 0.7;
            transition SatietyInduced -> Emptying
                when residenceTime elapsed;
            transition Emptying -> Empty
                when pyloricPort.gelOut->isEmpty();
        }

        perform HydrateParticles;
        perform MixWithFood;
        perform InduceSatiety;
        perform StomachBehavior;
    }

    part def SmallIntestine {
        attribute pH : pH = 6.5;
        attribute length : Length = 6 [m];
        attribute residenceTime : Duration = 180 [min];
        attribute degradationRate : AbsorptionRate = 0.3;

        in port intake : GelTransitPort;
        port output : GelTransitPort;
        port systemicCheck : SystemicCheckPort;

        item gelMatrix : GelMatrix;

        action def DegradeGel {
            in gel : GelMatrix;
            out degradedGel : GelMatrix;
            // Gradual degradation of gel matrix
        }

        action def VerifyNonSystemic {
            in gel : GelMatrix;
            out marker : BloodstreamMarker;
            // Confirm no absorption into bloodstream
        }

        state machine SmallIntestineBehavior {
            entry;
            state Idle;
            state Receiving;
            state Degrading;
            state Passing;

            transition Idle -> Receiving
                when intake.gelIn->notEmpty();
            transition Receiving -> Degrading
                when gelMatrix->notEmpty();
            transition Degrading -> Passing
                when gelMatrix.degradationLevel > 0.3;
            transition Passing -> Idle
                when output.gelOut->notEmpty();
        }

        perform DegradeGel;
        perform VerifyNonSystemic;
        perform SmallIntestineBehavior;
    }

    part def LargeIntestine {
        attribute pH : pH = 7.0;
        attribute length : Length = 1.5 [m];
        attribute residenceTime : Duration = 36 [h];
        attribute degradationRate : AbsorptionRate = 0.7;

        in port intake : GelTransitPort;
        port eliminationPort : EliminationPort;

        item gelMatrix : GelMatrix;
        item degradedMaterial : DegradedMaterial;

        action def CompleteDegradation {
            in gel : GelMatrix;
            out material : DegradedMaterial;
            // Final breakdown of gel matrix
        }

        action def Eliminate {
            in material : DegradedMaterial;
            out expelled : DegradedMaterial;
            // Natural elimination from body
        }

        state machine LargeIntestineBehavior {
            entry;
            state Idle;
            state Receiving;
            state FinalDegradation;
            state Eliminating;

            transition Idle -> Receiving
                when intake.gelIn->notEmpty();
            transition Receiving -> FinalDegradation
                when gelMatrix->notEmpty();
            transition FinalDegradation -> Eliminating
                when gelMatrix.degradationLevel > 0.9;
            transition Eliminating -> Idle
                when eliminationPort.degradedMaterial->notEmpty();
        }

        perform CompleteDegradation;
        perform Eliminate;
        perform LargeIntestineBehavior;
    }

    part def GastrointestinalTract {
        part stomach : Stomach;
        part smallIntestine : SmallIntestine;
        part largeIntestine : LargeIntestine;

        connection stomachToSmallIntestine : GelTransitPort connect
            stomach.pyloricPort to smallIntestine.intake;
        connection smallToLargeIntestine : GelTransitPort connect
            smallIntestine.output to largeIntestine.intake;
    }

    part def Patient {
        attribute bodyWeight : Mass = 80 [kg];
        attribute targetWeightReduction : Mass = 5 [kg];

        part giTract : GastrointestinalTract;
        port ingestionPort : IngestionPort;
        port satietyReception : SatietyPort;
        port eliminationReception : EliminationPort;

        action def ConsumeCapsules {
            out capsules : Gelesis100Capsule[*];
            out water : Water;
            // Take capsules with water before meals
        }

        action def ConsumeMeal {
            in satiety : SatietySignal;
            out food : Food;
            // Reduced food intake due to satiety
        }

        perform ConsumeCapsules;
        perform ConsumeMeal;

        connection ingestToStomach : IngestionPort connect
            ingestionPort to giTract.stomach.ingestion;
        connection satietyFeedback : SatietyPort connect
            giTract.stomach.satietyOutput to satietyReception;
        connection eliminationFeedback : EliminationPort connect
            giTract.largeIntestine.eliminationPort to eliminationReception;
    }

    part def Gelesis100Therapy {
        attribute therapyName : String = "Gelesis100";
        attribute therapyType : String = "non-systemic hydrogel-based therapy";
        attribute indication : String = "weight management";

        part capsules : Gelesis100Capsule[*];
        part patient : Patient;

        action def AdministerTherapy {
            in capsules : Gelesis100Capsule[*];
            out patient : Patient;
            // Administer capsules with water before meals
        }

        perform AdministerTherapy;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def CapsuleDissolutionRequirement {
        subject capsule : Gelesis100Capsule;
        objective {
            doc /* The capsule shell shall dissolve in the stomach's acidic environment (pH < 3.0) within 5 minutes of ingestion. */
        }
        require capsule.shell.dissolvesBelow <= 3.0;
    }

    requirement def ParticleSwellingRequirement {
        subject particle : SuperabsorbentParticle;
        objective {
            doc /* Particles shall swell to approximately 100 times their original size upon hydration. */
        }
        require particle.swellingCapacity >= 100;
    }

    requirement def SatietyInductionRequirement {
        subject stomach : Stomach;
        objective {
            doc /* The gel matrix shall induce a feeling of fullness (satiety level >= 0.7) to help reduce food intake. */
        }
        require stomach.satietyOutput.satiety.level >= 0.7;
    }

    requirement def NonSystemicRequirement {
        subject therapy : Gelesis100Therapy;
        objective {
            doc /* The therapy shall not be absorbed into the bloodstream; it shall work mechanically and locally within the GI tract. */
        }
        require therapy.patient.giTract.smallIntestine.systemicCheck.marker.concentration == 0 [mg/L];
    }

    requirement def DegradationRequirement {
        subject gel : GelMatrix;
        objective {
            doc /* The gel matrix shall degrade during transit through the small and large intestines before elimination. */
        }
        require gel.degradationLevel >= 0.9;
    }

    requirement def EliminationRequirement {
        subject material : DegradedMaterial;
        objective {
            doc /* Degraded material shall be naturally eliminated from the body. */
        }
        require material.degradationLevel == 1.0;
    }

    requirement def SafetyRequirement {
        subject therapy : Gelesis100Therapy;
        objective {
            doc /* The therapy shall provide a safe approach to weight management with no systemic absorption. */
        }
        satisfy NonSystemicRequirement;
        satisfy EliminationRequirement;
    }

    // ============================================================
    // Requirement Satisfaction
    // ============================================================

    part def Gelesis100System :> Gelesis100Therapy {
        satisfy CapsuleDissolutionRequirement by capsules;
        satisfy ParticleSwellingRequirement by capsules.particles;
        satisfy SatietyInductionRequirement by patient.giTract.stomach;
        satisfy NonSystemicRequirement by self;
        satisfy DegradationRequirement by patient.giTract.largeIntestine.gelMatrix;
        satisfy EliminationRequirement by patient.giTract.largeIntestine.degradedMaterial;
        satisfy SafetyRequirement by self;
    }

}
