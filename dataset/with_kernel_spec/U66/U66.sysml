package Gelesis100Therapy {
    private import ScalarValues::*;
    
    attribute def VolumeValue :> Real { doc /* liters */ }
    attribute def TimeValue :> Real { doc /* minutes */ }
    attribute def ViscosityValue :> Real { doc /* Pascal-seconds */ }
    attribute def DimensionlessRatio :> Real;
    
    item def Water;
    item def GastricFluid;
    item def Food;
    item def DegradedMaterial;
    item def CrossLinkedCellulose;
    item def CitricAcid;
    
    item def SuperabsorbentMaterial {
        item crossLinkedCellulose : CrossLinkedCellulose;
        item citricAcid : CitricAcid;
    }
    
    item def HydrogelParticle :> SuperabsorbentMaterial {
        attribute dryVolume : VolumeValue;
        attribute hydratedVolume : VolumeValue;
        attribute swellingFactor : DimensionlessRatio = 100;
    }
    
    item def GelMatrix {
        attribute volume : VolumeValue;
        attribute viscosity : ViscosityValue;
    }
    
    port def ParticlePort {
        out item particles : HydrogelParticle[1..*];
    }
    
    port def GelPort {
        out item gel : GelMatrix;
    }
    
    port def WastePort {
        out item degraded : DegradedMaterial;
    }
    
    part def CapsuleShell {
        attribute dissolutionTime : TimeValue;
    }
    
    part def Gelesis100Capsule {
        part shell : CapsuleShell;
        item superabsorbentMaterial : SuperabsorbentMaterial;
        item particles : HydrogelParticle[1..*];
        port particleOut : ParticlePort;
        attribute dosageCount : Integer;
        flow of releasedParticles : HydrogelParticle from particles to particleOut.particles;
    }
    
    part def Stomach {
        item gastricFluid : GastricFluid;
        item food : Food;
        item water : Water;
        item particles : HydrogelParticle[1..*];
        item gel : GelMatrix;
        port particleIn : ~ParticlePort;
        port gelOut : GelPort;
        attribute pH : Real;
        flow of receivedParticles : HydrogelParticle from particleIn.particles to particles;
        flow of stomachGel : GelMatrix from gel to gelOut.gel;
    }
    
    part def SmallIntestine {
        item gel : GelMatrix;
        item degraded : DegradedMaterial;
        port gelIn : ~GelPort;
        port gelOut : GelPort;
        port wasteOut : WastePort;
        attribute transitTime : TimeValue;
        flow of receivedGel : GelMatrix from gelIn.gel to gel;
        flow of passedGel : GelMatrix from gel to gelOut.gel;
        flow of intestineWaste : DegradedMaterial from degraded to wasteOut.degraded;
    }
    
    part def LargeIntestine {
        item gel : GelMatrix;
        item degraded : DegradedMaterial;
        port gelIn : ~GelPort;
        port wasteIn : ~WastePort;
        flow of receivedGel : GelMatrix from gelIn.gel to gel;
        flow of receivedWaste : DegradedMaterial from wasteIn.degraded to degraded;
    }
    
    part def HumanBody {
        part stomach : Stomach;
        part smallIntestine : SmallIntestine;
        part largeIntestine : LargeIntestine;
        flow of stomachToSmallIntestine : GelMatrix
            from stomach.gelOut.gel to smallIntestine.gelIn.gel;
        flow of smallToLargeGel : GelMatrix
            from smallIntestine.gelOut.gel to largeIntestine.gelIn.gel;
        flow of smallToLargeWaste : DegradedMaterial
            from smallIntestine.wasteOut.degraded to largeIntestine.wasteIn.degraded;
    }
    
    action def SwallowCapsule {
        in capsule : Gelesis100Capsule;
        in water : Water;
    }
    
    action def DissolveShell {
        in gastricFluid : GastricFluid;
        out particles : HydrogelParticle[1..*];
    }
    
    action def Absorb {
        in particles : HydrogelParticle[1..*];
        in fluid : GastricFluid;
        in water : Water;
        out hydratedParticles : HydrogelParticle[1..*];
    }
    
    action def HydrateAndSwell {
        in particles : HydrogelParticle[1..*];
        in water : Water;
        in gastricFluid : GastricFluid;
        out gel : GelMatrix;
    }
    
    action def MixWithFood {
        in gel : GelMatrix;
        in food : Food;
        out mixedGel : GelMatrix;
    }
    
    action def InduceSatiety {
        in gel : GelMatrix;
    }
    
    action def DegradeGel {
        in gel : GelMatrix;
        out degraded : DegradedMaterial;
    }
    
    action def Eliminate {
        in degraded : DegradedMaterial;
    }
    
    state machine def TherapyLifecycle {
        state Ingested;
        state ShellDissolving;
        state Hydrating;
        state Swollen;
        state GelFormed;
        state InducingSatiety;
        state TransitIntestines;
        state Degrading;
        state Eliminated;
        
        transition t1 from Ingested to ShellDissolving;
        transition t2 from ShellDissolving to Hydrating;
        transition t3 from Hydrating to Swollen;
        transition t4 from Swollen to GelFormed;
        transition t5 from GelFormed to InducingSatiety;
        transition t6 from InducingSatiety to TransitIntestines;
        transition t7 from TransitIntestines to Degrading;
        transition t8 from Degrading to Eliminated;
    }
    
    requirement def NonSystemicRequirement {
        doc /* The therapy shall act locally within the GI tract and not be absorbed into the bloodstream. */
        subject body : HumanBody;
    }
    
    requirement def SwellingRequirement {
        doc /* Particles shall swell to approximately 100 times their original volume upon hydration. */
        attribute minSwellingFactor : DimensionlessRatio = 100;
        subject capsule : Gelesis100Capsule;
    }
    
    requirement def SatietyRequirement {
        doc /* The expanded gel matrix shall induce satiety and reduce food intake. */
        subject body : HumanBody;
    }
    
    requirement def DegradationRequirement {
        doc /* The gel matrix shall degrade in the intestines and be eliminated from the body. */
        subject body : HumanBody;
    }
    
    part context {
        part capsule : Gelesis100Capsule;
        part body : HumanBody;
        item water : Water;
        item food : Food;
        
        flow of waterIntake : Water from water to body.stomach.water;
        flow of foodIntake : Food from food to body.stomach.food;
        flow of particleRelease : HydrogelParticle
            from capsule.particleOut.particles
            to body.stomach.particleIn.particles;
        
        perform action swallow : SwallowCapsule {
            in capsule = capsule;
            in water = water;
        }
        
        perform action dissolve : DissolveShell {
            in gastricFluid = body.stomach.gastricFluid;
            out particles = capsule.particles;
        }
        
        perform action absorb : Absorb {
            in particles = body.stomach.particles;
            in fluid = body.stomach.gastricFluid;
            in water = body.stomach.water;
            out hydratedParticles = body.stomach.particles;
        }
        
        perform action hydrate : HydrateAndSwell {
            in particles = body.stomach.particles;
            in water = body.stomach.water;
            in gastricFluid = body.stomach.gastricFluid;
            out gel = body.stomach.gel;
        }
        
        perform action mix : MixWithFood {
            in gel = body.stomach.gel;
            in food = body.stomach.food;
            out mixedGel = body.stomach.gel;
        }
        
        perform action induce : InduceSatiety {
            in gel = body.stomach.gel;
        }
        
        perform action degrade : DegradeGel {
            in gel = body.smallIntestine.gel;
            out degraded = body.smallIntestine.degraded;
        }
        
        perform action eliminate : Eliminate {
            in degraded = body.largeIntestine.degraded;
        }
        
        state machine therapySM : TherapyLifecycle;
        
        requirement nonSystemic : NonSystemicRequirement {
            subject body = body;
        }
        requirement swellingReq : SwellingRequirement {
            subject capsule = capsule;
        }
        requirement satietyReq : SatietyRequirement {
            subject body = body;
        }
        requirement degradationReq : DegradationRequirement {
            subject body = body;
        }
    }
}
