package GastrointestinalSystem {

    import ScalarValues::*;

    // ============================================================
    // Value Types
    // ============================================================

    value def MassValue :> Real;
    value def VolumeValue :> Real;
    value def DurationValue :> Real;
    value def AreaValue :> Real;
    value def pHValue :> Real;
    value def ConcentrationValue :> Real;
    value def FractionValue :> Real;
    value def CountValue :> Integer;

    // ============================================================
    // Items
    // ============================================================

    item def Food {
        attribute mass : MassValue;
        attribute carbohydrateContent : MassValue;
        attribute proteinContent : MassValue;
        attribute fatContent : MassValue;
        attribute fiberContent : MassValue;
        attribute pathogenLoad : CountValue;
    }

    item def Saliva {
        attribute volume : VolumeValue;
        attribute amylaseActivity : Real;
    }

    item def GastricJuice {
        attribute volume : VolumeValue;
        attribute acidity : pHValue;
        attribute pepsinConcentration : ConcentrationValue;
        attribute hclConcentration : ConcentrationValue;
    }

    item def PancreaticJuice {
        attribute volume : VolumeValue;
        attribute alkalinity : pHValue;
        attribute proteaseActivity : Real;
        attribute lipaseActivity : Real;
        attribute amylaseActivity : Real;
        attribute bicarbonateConcentration : ConcentrationValue;
    }

    item def Bile {
        attribute volume : VolumeValue;
        attribute bileSaltConcentration : ConcentrationValue;
        attribute bilirubinConcentration : ConcentrationValue;
    }

    item def Bolus {
        attribute mass : MassValue;
        attribute viscosity : Real;
        attribute acidity : pHValue;
        attribute carbohydrateDigestion : FractionValue;
        attribute salivaryMixing : FractionValue;
    }

    item def Chyme {
        attribute mass : MassValue;
        attribute viscosity : Real;
        attribute acidity : pHValue;
        attribute proteinDigestion : FractionValue;
        attribute pathogenLoad : CountValue;
        attribute waterContent : FractionValue;
    }

    item def EmulsifiedChyme {
        attribute mass : MassValue;
        attribute acidity : pHValue;
        attribute fatEmulsification : FractionValue;
        attribute proteinDigestion : FractionValue;
        attribute carbohydrateDigestion : FractionValue;
        attribute waterContent : FractionValue;
    }

    item def DigestedChyme {
        attribute mass : MassValue;
        attribute acidity : pHValue;
        attribute residualFiber : MassValue;
        attribute waterContent : FractionValue;
    }

    item def FecalMatter {
        attribute mass : MassValue;
        attribute waterContent : FractionValue;
        attribute bacterialBiomass : MassValue;
        attribute fiberContent : MassValue;
    }

    item def Nutrient {
        attribute mass : MassValue;
    }

    item def Glucose :> Nutrient;
    item def AminoAcid :> Nutrient;
    item def FattyAcid :> Nutrient;
    item def Vitamin :> Nutrient;
    item def Mineral :> Nutrient;
    item def WaterNutrient :> Nutrient;
    item def Electrolyte :> Nutrient;

    item def Bloodstream {
        attribute glucoseMass : MassValue;
        attribute aminoAcidMass : MassValue;
        attribute fattyAcidMass : MassValue;
        attribute vitaminMass : MassValue;
        attribute mineralMass : MassValue;
        attribute waterVolume : VolumeValue;
        attribute electrolyteMass : MassValue;
    }

    // ============================================================
    // Ports
    // ============================================================

    port def FoodIntakePort {
        in food : Food;
    }

    port def BolusOutPort {
        out bolus : Bolus;
    }

    port def BolusInPort {
        in bolus : Bolus;
    }

    port def ChymeOutPort {
        out chyme : Chyme;
    }

    port def ChymeInPort {
        in chyme : Chyme;
    }

    port def EmulsifiedChymeOutPort {
        out chyme : EmulsifiedChyme;
    }

    port def EmulsifiedChymeInPort {
        in chyme : EmulsifiedChyme;
    }

    port def DigestedChymeOutPort {
        out chyme : DigestedChyme;
    }

    port def DigestedChymeInPort {
        in chyme : DigestedChyme;
    }

    port def FecalOutPort {
        out fecal : FecalMatter;
    }

    port def NutrientOutPort {
        out nutrients : Bloodstream;
    }

    port def NutrientInPort {
        in nutrients : Bloodstream;
    }

    port def PancreaticJuiceOutPort {
        out juice : PancreaticJuice;
    }

    port def PancreaticJuiceInPort {
        in juice : PancreaticJuice;
    }

    port def BileOutPort {
        out bile : Bile;
    }

    port def BileInPort {
        in bile : Bile;
    }

    // ============================================================
    // Actions
    // ============================================================

    action def Mastication {
        in food : Food;
        in saliva : Saliva;
        out bolus : Bolus;
    }

    action def Peristalsis {
        in payload : Bolus;
        out payload : Bolus;
    }

    action def GastricMixing {
        in bolus : Bolus;
        in juice : GastricJuice;
        out chyme : Chyme;
    }

    action def Neutralization {
        in chyme : Chyme;
        in juice : PancreaticJuice;
        out chyme : EmulsifiedChyme;
    }

    action def Emulsification {
        in chyme : EmulsifiedChyme;
        in bile : Bile;
        out chyme : EmulsifiedChyme;
    }

    action def NutrientAbsorption {
        in chyme : EmulsifiedChyme;
        out chyme : DigestedChyme;
        out nutrients : Bloodstream;
    }

    action def WaterReabsorption {
        in chyme : DigestedChyme;
        out fecal : FecalMatter;
    }

    action def Fermentation {
        in chyme : DigestedChyme;
        out chyme : DigestedChyme;
    }

    action def HepaticMetabolism {
        in nutrients : Bloodstream;
        out nutrients : Bloodstream;
    }

    action def BileProduction {
        out bile : Bile;
    }

    action def BileConcentration {
        in bile : Bile;
        out bile : Bile;
    }

    action def PancreaticSecretion {
        out juice : PancreaticJuice;
    }

    action def Elimination {
        in fecal : FecalMatter;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def DigestionRequirement {
        doc { The GI tract shall mechanically and chemically digest ingested food into absorbable nutrients. }
        attribute digestionEfficiency : FractionValue;
        require digestionEfficiency >= 0.85;
    }

    requirement def AbsorptionRequirement {
        doc { The small intestine shall absorb glucose, amino acids, fatty acids, vitamins, and minerals into the bloodstream. }
        attribute absorptionEfficiency : FractionValue;
        require absorptionEfficiency >= 0.90;
    }

    requirement def HydrationRequirement {
        doc { The large intestine shall reabsorb water and electrolytes from liquid waste. }
        attribute waterReabsorptionEfficiency : FractionValue;
        require waterReabsorptionEfficiency >= 0.80;
    }

    requirement def PathogenControlRequirement {
        doc { Gastric juices shall reduce pathogen load via acidic denaturation. }
        attribute pathogenReduction : FractionValue;
        require pathogenReduction >= 0.99;
    }

    requirement def WasteProcessingRequirement {
        doc { The large intestine shall form, store, and expel fecal matter. }
        attribute storageCapacity : VolumeValue;
        attribute maxRetentionDuration : DurationValue;
    }

    requirement def CoordinationRequirement {
        doc { Organs shall coordinate via peristalsis to move material along the tract. }
        attribute peristalsisFrequency : Real;
    }

    // ============================================================
    // Parts
    // ============================================================

    part def OralCavity {
        port foodIn : FoodIntakePort;
        port bolusOut : BolusOutPort;

        attribute chewingDuration : DurationValue;
        attribute salivaryMixing : FractionValue;
        attribute foodArrived : Boolean;
        item secretedSaliva : Saliva;

        action masticate : Mastication {
            in food = foodIn.food;
            in saliva = secretedSaliva;
            out bolus = bolusOut.bolus;
        }

        state OralState {
            state idle;
            state chewing;
            state swallowing;
            transition idle -> chewing when foodArrived;
            transition chewing -> swallowing after chewingDuration;
            transition swallowing -> idle;
        }
    }

    part def Esophagus {
        port bolusIn : BolusInPort;
        port bolusOut : BolusOutPort;

        attribute transitDuration : DurationValue;
        attribute bolusReceived : Boolean;

        action transport : Peristalsis {
            in payload = bolusIn.bolus;
            out payload = bolusOut.bolus;
        }

        state EsophagealState {
            state relaxed;
            state contracting;
            transition relaxed -> contracting when bolusReceived;
            transition contracting -> relaxed after transitDuration;
        }
    }

    part def Stomach {
        port bolusIn : BolusInPort;
        port chymeOut : ChymeOutPort;

        attribute capacity : VolumeValue;
        attribute fillLevel : VolumeValue;
        attribute digestingDuration : DurationValue;
        item gastricJuice : GastricJuice;
        attribute bolusPresent : Boolean;

        action gastricMix : GastricMixing {
            in bolus = bolusIn.bolus;
            in juice = gastricJuice;
            out chyme = chymeOut.chyme;
        }

        state StomachState {
            state empty;
            state filling;
            state digesting;
            state emptying;
            transition empty -> filling when bolusPresent;
            transition filling -> digesting when fillLevel >= capacity;
            transition digesting -> emptying after digestingDuration;
            transition emptying -> empty when fillLevel <= 0;
        }
    }

    part def Duodenum {
        port chymeIn : ChymeInPort;
        port pancreaticJuiceIn : PancreaticJuiceInPort;
        port bileIn : BileInPort;
        port chymeOut : EmulsifiedChymeOutPort;

        attribute processingDuration : DurationValue;
        attribute chymeAcidity : pHValue;
        attribute chymeArrived : Boolean;

        action neutralize : Neutralization {
            in chyme = chymeIn.chyme;
            in juice = pancreaticJuiceIn.juice;
            out chyme = chymeOut.chyme;
        }

        action emulsify : Emulsification {
            in chyme = chymeOut.chyme;
            in bile = bileIn.bile;
            out chyme = chymeOut.chyme;
        }

        state DuodenalState {
            state idle;
            state receiving;
            state processing;
            state discharging;
            transition idle -> receiving when chymeArrived;
            transition receiving -> processing when chymeAcidity >= 6.0;
            transition processing -> discharging after processingDuration;
            transition discharging -> idle;
        }
    }

    part def Jejunum {
        port chymeIn : EmulsifiedChymeInPort;
        port chymeOut : EmulsifiedChymeOutPort;
        port nutrientsOut : NutrientOutPort;

        attribute surfaceArea : AreaValue;
        attribute absorptionRate : Real;
        attribute transitDuration : DurationValue;
        attribute chymeArrived : Boolean;

        action absorb : NutrientAbsorption {
            in chyme = chymeIn.chyme;
            out chyme = chymeOut.chyme;
            out nutrients = nutrientsOut.nutrients;
        }

        state JejunalState {
            state active;
            state inactive;
            transition inactive -> active when chymeArrived;
            transition active -> inactive after transitDuration;
        }
    }

    part def Ileum {
        port chymeIn : EmulsifiedChymeInPort;
        port chymeOut : DigestedChymeOutPort;
        port nutrientsOut : NutrientOutPort;

        attribute surfaceArea : AreaValue;
        attribute absorptionRate : Real;
        attribute transitDuration : DurationValue;
        attribute chymeArrived : Boolean;

        action absorb : NutrientAbsorption {
            in chyme = chymeIn.chyme;
            out chyme = chymeOut.chyme;
            out nutrients = nutrientsOut.nutrients;
        }

        state IlealState {
            state active;
            state inactive;
            transition inactive -> active when chymeArrived;
            transition active -> inactive after transitDuration;
        }
    }

    part def SmallIntestine {
        part duodenum : Duodenum;
        part jejunum : Jejunum;
        part ileum : Ileum;

        port chymeIn : ChymeInPort;
        port chymeOut : DigestedChymeOutPort;
        port pancreaticJuiceIn : PancreaticJuiceInPort;
        port bileIn : BileInPort;
        port nutrientsOut : NutrientOutPort;

        connection chymeIn to duodenum.chymeIn;
        connection duodenum.chymeOut to jejunum.chymeIn;
        connection jejunum.chymeOut to ileum.chymeIn;
        connection ileum.chymeOut to chymeOut;
        connection pancreaticJuiceIn to duodenum.pancreaticJuiceIn;
        connection bileIn to duodenum.bileIn;
        connection jejunum.nutrientsOut to nutrientsOut;
        connection ileum.nutrientsOut to nutrientsOut;
    }

    part def LargeIntestine {
        port chymeIn : DigestedChymeInPort;
        port fecalOut : FecalOutPort;

        attribute waterReabsorptionRate : Real;
        attribute bacterialPopulation : CountValue;
        attribute storageDuration : DurationValue;
        attribute fermentDuration : DurationValue;
        attribute reabsorbDuration : DurationValue;
        attribute chymeArrived : Boolean;
        attribute defecationSignal : Boolean;

        action ferment : Fermentation {
            in chyme = chymeIn.chyme;
            out chyme = chymeIn.chyme;
        }

        action reabsorb : WaterReabsorption {
            in chyme = chymeIn.chyme;
            out fecal = fecalOut.fecal;
        }

        action eliminate : Elimination {
            in fecal = fecalOut.fecal;
        }

        state ColonState {
            state receiving;
            state fermenting;
            state concentrating;
            state storing;
            state defecating;
            transition receiving -> fermenting when chymeArrived;
            transition fermenting -> concentrating after fermentDuration;
            transition concentrating -> storing after reabsorbDuration;
            transition storing -> defecating when defecationSignal;
            transition defecating -> receiving;
        }
    }

    part def Pancreas {
        port juiceOut : PancreaticJuiceOutPort;

        attribute secretionRate : Real;

        action secrete : PancreaticSecretion {
            out juice = juiceOut.juice;
        }
    }

    part def Liver {
        port nutrientsIn : NutrientInPort;
        port nutrientsOut : NutrientOutPort;
        port bileOut : BileOutPort;

        attribute metabolicRate : Real;

        action metabolize : HepaticMetabolism {
            in nutrients = nutrientsIn.nutrients;
            out nutrients = nutrientsOut.nutrients;
        }

        action produceBile : BileProduction {
            out bile = bileOut.bile;
        }
    }

    part def Gallbladder {
        port bileIn : BileInPort;
        port bileOut : BileOutPort;

        attribute concentrationFactor : Real;

        action concentrate : BileConcentration {
            in bile = bileIn.bile;
            out bile = bileOut.bile;
        }
    }

    // ============================================================
    // Top-level Assembly
    // ============================================================

    part def GastrointestinalTract {
        part mouth : OralCavity;
        part esophagus : Esophagus;
        part stomach : Stomach;
        part smallIntestine : SmallIntestine;
        part largeIntestine : LargeIntestine;
        part pancreas : Pancreas;
        part liver : Liver;
        part gallbladder : Gallbladder;

        connection mouth.bolusOut to esophagus.bolusIn;
        connection esophagus.bolusOut to stomach.bolusIn;
        connection stomach.chymeOut to smallIntestine.chymeIn;
        connection smallIntestine.chymeOut to largeIntestine.chymeIn;
        connection pancreas.juiceOut to smallIntestine.pancreaticJuiceIn;
        connection liver.bileOut to gallbladder.bileIn;
        connection gallbladder.bileOut to smallIntestine.bileIn;
        connection smallIntestine.nutrientsOut to liver.nutrientsIn;
    }

    // ============================================================
    // Requirement Usages
    // ============================================================

    requirement digestionReq : DigestionRequirement;
    requirement absorptionReq : AbsorptionRequirement;
    requirement hydrationReq : HydrationRequirement;
    requirement pathogenReq : PathogenControlRequirement;
    requirement wasteReq : WasteProcessingRequirement;
    requirement coordinationReq : CoordinationRequirement;

    // ============================================================
    // Instance with Satisfaction
    // ============================================================

    part humanGI : GastrointestinalTract {
        satisfy digestionReq;
        satisfy absorptionReq;
        satisfy hydrationReq;
        satisfy pathogenReq;
        satisfy wasteReq;
        satisfy coordinationReq;
    }
}
