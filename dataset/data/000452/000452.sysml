package Gelesis100WeightManagementSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def IngestionCommand;
    attribute def HydrationTrigger;
    attribute def TransitSignal;
    
    attribute def SatietyIndex :> Real;
    attribute def ExpansionRatio :> Real;
    attribute def pHLevel :> Real;
    
    item def CelluloseCrosslinkedPolymer {
        attribute polymerMass : MassValue;
        attribute crosslinkDensity : Real;
    }
    
    item def CitricAcidCrosslinker {
        attribute concentration : Real;
    }
    
    item def HydrogelCapsule {
        attribute dryMass : MassValue;
        attribute capsuleShellMaterial : String;
        part activeIngredient {
            part cellulose : CelluloseCrosslinkedPolymer;
            part crosslinker : CitricAcidCrosslinker;
        }
    }
    
    item def HydratedGelMatrix {
        attribute expandedVolume : VolumeValue;
        attribute waterContent : MassValue;
        attribute viscosity : Real;
    }
    
    item def GastricFluid {
        attribute volume : VolumeValue;
        attribute acidity : pHLevel;
        attribute temperature : TemperatureValue;
    }
    
    item def IngestedFood {
        attribute foodMass : MassValue;
        attribute foodVolume : VolumeValue;
    }
    
    port def OralIntakePort {
        in item capsules : HydrogelCapsule[*];
        in item water : VolumeValue;
    }
    
    port def GastricEnvironmentPort {
        in item gastricFluid : GastricFluid;
        in item food : IngestedFood;
        out attribute satietySignal : SatietyIndex;
    }
    
    port def IntestinalTransitPort {
        out item gelResidue : HydratedGelMatrix;
    }
    
    part def OralCavity {
        port intakePort : OralIntakePort;
    }
    
    part def Stomach {
        port gastricPort : GastricEnvironmentPort;
        attribute capacity : VolumeValue;
        attribute emptyingRate : Real;
    }
    
    part def SmallIntestine {
        port transitPort : IntestinalTransitPort;
        attribute peristalticActivity : Real;
    }
    
    part def LargeIntestine {
        attribute absorptionRate : Real;
    }
    
    action def IngestCapsulesAction {
        in capsuleDose : HydrogelCapsule[*];
        in waterVolume : VolumeValue;
        out ingestedCapsules : HydrogelCapsule[*];
    }
    
    action def DissolveShellAction {
        in capsules : HydrogelCapsule[*];
        in gastricEnvironment : GastricFluid;
        out releasedHydrogel : CelluloseCrosslinkedPolymer[*];
        attribute dissolutionTime : TimeValue;
    }
    
    action def AbsorbWaterAction {
        in hydrogelParticles : CelluloseCrosslinkedPolymer[*];
        in availableWater : GastricFluid;
        out hydratedGel : HydratedGelMatrix;
        attribute absorptionRate : Real;
        attribute expansionFactor : ExpansionRatio;
    }
    
    action def FormGelNetworkAction {
        in hydratedGel : HydratedGelMatrix;
        in foodContent : IngestedFood;
        out gelFoodMatrix : HydratedGelMatrix;
        attribute matrixVolume : VolumeValue;
    }
    
    action def InduceSatietyAction {
        in gelMatrix : HydratedGelMatrix;
        in stomachCapacity : VolumeValue;
        out satietyLevel : SatietyIndex;
        out volumeOccupied : VolumeValue;
    }
    
    action def TransitThroughGIAction {
        in gelMatrix : HydratedGelMatrix;
        out transitingGel : HydratedGelMatrix;
        attribute transitDuration : TimeValue;
    }
    
    action def DegradeGelAction {
        in gelMatrix : HydratedGelMatrix;
        out degradedFragments : HydratedGelMatrix[*];
        attribute degradationRate : Real;
    }
    
    action def EliminateAction {
        in fragments : HydratedGelMatrix[*];
        out eliminatedMaterial : HydratedGelMatrix[*];
    }
    
    action def GelSystemLifecycle {
        first start;
        then action ingestedState {
            assign phase = "ingested";
        }
        accept gastricEntry : HydrationTrigger;
        then action dissolvingState {
            assign phase = "dissolving";
            action dissolve : DissolveShellAction;
        }
        then decide;
            if shellDissolved then hydratingState;
        action hydratingState {
            assign phase = "hydrating";
            action absorb : AbsorbWaterAction;
        }
        then decide;
            if fullyHydrated then expandedState;
        action expandedState {
            assign phase = "expanded";
            action formNetwork : FormGelNetworkAction;
            action provideSatiety : InduceSatietyAction;
        }
        accept transitTrigger : TransitSignal;
        then action transitingState {
            assign phase = "transiting";
            action transit : TransitThroughGIAction;
        }
        then decide;
            if intestinalEnvironment then degradingState;
        action degradingState {
            assign phase = "degrading";
            action degrade : DegradeGelAction;
        }
        then decide;
            if fullyDegraded then eliminatedState;
        action eliminatedState {
            assign phase = "eliminated";
            action eliminate : EliminateAction;
        }
        then done;
        
        attribute phase : String;
        attribute shellDissolved : Boolean;
        attribute fullyHydrated : Boolean;
        attribute intestinalEnvironment : Boolean;
        attribute fullyDegraded : Boolean;
    }
    
    action def DeliverWeightManagementTherapy {
        in therapeuticDose : HydrogelCapsule[*];
        in waterIntake : VolumeValue;
        in gastricConditions : GastricFluid;
        in mealContent : IngestedFood;
        out therapeuticSatiety : SatietyIndex;
        out caloricIntakeReduction : Real;
        
        first start;
        then action ingestDose : IngestCapsulesAction {
            in capsuleDose = therapeuticDose;
            in waterVolume = waterIntake;
            out ingestedCapsules;
        }
        then action dissolveShell : DissolveShellAction {
            in capsules = ingestDose.ingestedCapsules;
            in gastricEnvironment = gastricConditions;
            out releasedHydrogel;
        }
        then action hydrateGel : AbsorbWaterAction {
            in hydrogelParticles = dissolveShell.releasedHydrogel;
            in availableWater = gastricConditions;
            out hydratedGel;
        }
        then action formMatrix : FormGelNetworkAction {
            in hydratedGel = hydrateGel.hydratedGel;
            in foodContent = mealContent;
            out gelFoodMatrix;
        }
        then action induceSatiety : InduceSatietyAction {
            in gelMatrix = formMatrix.gelFoodMatrix;
            in stomachCapacity = 1.5 [SI::L];
            out satietyLevel;
            out volumeOccupied;
        }
        then assign therapeuticSatiety := induceSatiety.satietyLevel;
        then action transitGI : TransitThroughGIAction {
            in gelMatrix = formMatrix.gelFoodMatrix;
            out transitingGel;
        }
        then action degradeGel : DegradeGelAction {
            in gelMatrix = transitGI.transitingGel;
            out degradedFragments;
        }
        then action eliminateWaste : EliminateAction {
            in fragments = degradeGel.degradedFragments;
            out eliminatedMaterial;
        }
        then done;
    }
    
    part gelesis100System {
        doc /*
            Gelesis100 is a non-systemic, superabsorbent hydrogel therapy for weight management.
            Its primary function is to promote satiety and reduce caloric intake by creating a 
            three-dimensional elastic gel matrix in the stomach. When ingested with water before meals,
            the hydrogel capsules release cellulose-based particles that rapidly absorb gastric fluids,
            expanding to approximately 100 times their original volume. This expanded gel occupies 
            significant gastric volume, intermixes with ingested food to increase meal volume and 
            viscosity, and induces mechanical distension of the stomach wall, triggering satiety signals.
            The gel maintains its structure during gastric residence, then transits through the 
            gastrointestinal tract where it gradually degrades and is eliminated without systemic 
            absorption, providing a mechanical approach to appetite control and portion reduction.
        */
        
        part therapeuticCapsules : HydrogelCapsule[4] {
            attribute dryMass = 0.75 [SI::g];
            attribute capsuleShellMaterial = "hydroxypropyl methylcellulose";
            part activeIngredient {
                part cellulose : CelluloseCrosslinkedPolymer {
                    attribute polymerMass = 0.7 [SI::g];
                    attribute crosslinkDensity = 0.12;
                }
                part crosslinker : CitricAcidCrosslinker {
                    attribute concentration = 0.05;
                }
            }
        }
        
        part oralCavity : OralCavity {
            port intakePort;
        }
        
        part stomach : Stomach {
            port gastricPort;
            attribute capacity = 1.5 [SI::L];
            attribute emptyingRate = 0.3;
        }
        
        part smallIntestine : SmallIntestine {
            port transitPort;
            attribute peristalticActivity = 0.6;
        }
        
        part largeIntestine : LargeIntestine {
            attribute absorptionRate = 0.0;
        }
        
        connection oralToGastric connect oralCavity.intakePort to stomach.gastricPort;
        connection gastricToIntestinal connect stomach to smallIntestine.transitPort;
        connection smallToLarge connect smallIntestine to largeIntestine;
        
        perform action primaryTherapeuticFunction : DeliverWeightManagementTherapy {
            in therapeuticDose = therapeuticCapsules;
            in waterIntake = 500.0 [SI::ml];
            out therapeuticSatiety;
            out caloricIntakeReduction;
        }
        
        perform action systemLifecycle : GelSystemLifecycle;
    }
    
    requirement def TherapeuticEfficacyRequirement {
        doc /* The system shall provide clinically significant satiety enhancement to support weight management. */
        
        require constraint satietyThreshold {
            therapeuticSatiety >= 0.65
        }
        
        require constraint volumeExpansion {
            expandedVolume >= 200.0 [SI::ml]
        }
    }
    
    requirement def SafetyAndTolerabilityRequirement {
        doc /* The system shall be safe with no systemic absorption and complete gastrointestinal elimination. */
        
        require constraint noAbsorption {
            absorptionRate == 0.0
        }
        
        require constraint completeElimination {
            eliminatedMaterial.expandedVolume >= 0.95 * expandedVolume
        }
    }
    
    requirement def PerformanceSpecificationRequirement {
        doc /* The system shall achieve target hydration kinetics and gel properties within physiological conditions. */
        
        require constraint hydrationTime {
            dissolutionTime <= 30.0 [SI::min]
        }
        
        require constraint expansionRatio {
            expansionFactor >= 80.0
        }
        
        require constraint pHStability {
            acidity >= 1.0 and acidity <= 3.5
        }
    }
    
    requirement gelesis100SystemRequirements {
        subject gelesis100System;
        doc /* Complete requirements specification for Gelesis100 weight management system. */
        
        require efficacy : TherapeuticEfficacyRequirement;
        require safety : SafetyAndTolerabilityRequirement;
        require performance : PerformanceSpecificationRequirement;
    }
}
