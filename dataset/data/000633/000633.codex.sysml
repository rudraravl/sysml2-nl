package HyalobarrierSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MassFraction :> Real {
        unit = "%";
    }

    attribute def Volume :> Real {
        unit = "mL";
    }

    attribute def Duration :> Real {
        unit = "min";
    }

    attribute def TimeSpan :> Real {
        unit = "day";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def Viscosity :> Real {
        unit = "Pa*s";
    }

    attribute def pH :> Real;

    attribute def SterilityAssuranceLevel :> Real;

    item def CrossLinkedHyaluronicAcidGel {
        attribute concentration : MassFraction;
        attribute volume : Volume;
        attribute viscosity : Viscosity;
        attribute pHValue : pH;
        attribute residenceTime : TimeSpan;
        attribute sterile : Boolean;
        attribute biodegradable : Boolean;
    }

    item def PhysiologicalFluid {
        attribute temperature : Temperature;
        attribute pHValue : pH;
    }

    item def TissueSurface {
        attribute injured : Boolean;
        attribute adhesionRisk : Real;
        attribute coveredByBarrier : Boolean;
    }

    item def DegradationProduct {
        attribute biocompatible : Boolean;
        attribute absorbable : Boolean;
    }

    item def ApplicatorForce {
        attribute magnitude : Real;
    }

    port def GelDeliveryPort {
        out item gel : CrossLinkedHyaluronicAcidGel;
    }

    port def TissueInterfacePort {
        in item targetTissue : TissueSurface;
        out item treatedTissue : TissueSurface;
    }

    port def BiologicalEnvironmentPort {
        in item fluid : PhysiologicalFluid;
        out item degradationProduct : DegradationProduct;
    }

    port def ControlPort {
        in item applicationForce : ApplicatorForce;
    }

    part def HyalobarrierSystem {
        attribute nominalGelVolume : Volume = 10.0;
        attribute nominalResidenceTime : TimeSpan = 7.0;
        attribute storageTemperatureMin : Temperature = 2.0;
        attribute storageTemperatureMax : Temperature = 25.0;
        attribute sterileBarrierIntact : Boolean;
        attribute readyForUse : Boolean;

        port deliveryPort : GelDeliveryPort;
        port tissuePort : TissueInterfacePort;
        port environmentPort : BiologicalEnvironmentPort;
        port controlPort : ControlPort;

        part sterileSyringe : SterileSyringe;
        part gelReservoir : GelReservoir;
        part cannula : DeliveryCannula;
        part antiAdhesionGel : HyalobarrierGel;
        part treatedSite : SurgicalTissueSite;
        part biologicalResorptionProcess : ResorptionProcess;

        connect gelReservoir.outputPort to cannula.inputPort;
        connect cannula.outputPort to deliveryPort;
        connect deliveryPort to tissuePort;
        connect tissuePort to treatedSite.interfacePort;
        connect environmentPort to biologicalResorptionProcess.environmentPort;
        connect antiAdhesionGel.materialPort to biologicalResorptionProcess.gelPort;

        perform action ApplyHyalobarrier;
        exhibit state HyalobarrierLifecycle;
    }

    part def SterileSyringe {
        attribute singleUse : Boolean = true;
        attribute sterile : Boolean = true;
        attribute capacity : Volume = 10.0;
        attribute sterilityAssurance : SterilityAssuranceLevel = 1.0E-6;

        port plungerPort : ControlPort;
        port reservoirPort : GelDeliveryPort;
    }

    part def GelReservoir {
        attribute fillVolume : Volume = 10.0;
        attribute sealed : Boolean = true;

        port outputPort : GelDeliveryPort;

        item gelCharge : CrossLinkedHyaluronicAcidGel {
            concentration = 4.0;
            volume = 10.0;
            viscosity = 85.0;
            pHValue = 7.2;
            residenceTime = 7.0;
            sterile = true;
            biodegradable = true;
        }
    }

    part def DeliveryCannula {
        attribute atraumaticTip : Boolean = true;
        attribute internalDeadVolume : Volume = 0.2;

        port inputPort : GelDeliveryPort;
        port outputPort : GelDeliveryPort;
    }

    part def HyalobarrierGel {
        attribute crossLinked : Boolean = true;
        attribute transparent : Boolean = true;
        attribute bioresorbable : Boolean = true;
        attribute formsTemporaryPhysicalBarrier : Boolean = true;
        attribute expectedBarrierDuration : TimeSpan = 7.0;

        port materialPort : BiologicalEnvironmentPort;

        item material : CrossLinkedHyaluronicAcidGel {
            concentration = 4.0;
            volume = 10.0;
            viscosity = 85.0;
            pHValue = 7.2;
            residenceTime = 7.0;
            sterile = true;
            biodegradable = true;
        }
    }

    part def SurgicalTissueSite {
        attribute procedureCompleted : Boolean;
        attribute bleedingControlled : Boolean;
        attribute adhesionRiskBeforeTreatment : Real = 0.8;
        attribute adhesionRiskAfterTreatment : Real = 0.2;

        port interfacePort : TissueInterfacePort;

        item peritonealSurface : TissueSurface {
            injured = true;
            adhesionRisk = 0.8;
            coveredByBarrier = false;
        }
    }

    part def ResorptionProcess {
        attribute hydrolysisDominant : Boolean = true;
        attribute enzymaticContribution : Boolean = true;
        attribute completeResorptionTarget : TimeSpan = 28.0;

        port gelPort : BiologicalEnvironmentPort;
        port environmentPort : BiologicalEnvironmentPort;

        item resorbedProduct : DegradationProduct {
            biocompatible = true;
            absorbable = true;
        }
    }

    action def ApplyHyalobarrier {
        in item sourceGel : CrossLinkedHyaluronicAcidGel;
        in item exposedTissue : TissueSurface;
        in item environment : PhysiologicalFluid;
        out item protectedTissue : TissueSurface;
        out item remainingGel : CrossLinkedHyaluronicAcidGel;

        first start;
        then verifySterilePackage;
        then prepareApplicator;
        then positionCannulaAtTargetSite;
        then expressGelLayer;
        then conformGelToTissueSurface;
        then maintainTemporarySeparation;
        then gradualResorption;
        then done;

        action verifySterilePackage {
            in item sourceGel : CrossLinkedHyaluronicAcidGel;
            out verified : Boolean;
        }

        action prepareApplicator {
            in verified : Boolean;
            out ready : Boolean;
        }

        action positionCannulaAtTargetSite {
            in ready : Boolean;
            in item exposedTissue : TissueSurface;
            out positioned : Boolean;
        }

        action expressGelLayer {
            in positioned : Boolean;
            in item sourceGel : CrossLinkedHyaluronicAcidGel;
            out item appliedGel : CrossLinkedHyaluronicAcidGel;
        }

        action conformGelToTissueSurface {
            in item appliedGel : CrossLinkedHyaluronicAcidGel;
            in item exposedTissue : TissueSurface;
            out item coveredTissue : TissueSurface;
        }

        action maintainTemporarySeparation {
            in item coveredTissue : TissueSurface;
            out item protectedTissue : TissueSurface;
        }

        action gradualResorption {
            in item protectedTissue : TissueSurface;
            in item environment : PhysiologicalFluid;
            out item remainingGel : CrossLinkedHyaluronicAcidGel;
        }
    }

    state def HyalobarrierLifecycle {
        entry action initialize;

        state Packaged;
        state ReadyForApplication;
        state AppliedToTissue;
        state BarrierFunctionActive;
        state Resorbing;
        state Resorbed;

        transition initial then Packaged;

        transition Packaged_to_Ready
            first Packaged
            accept after 1.0 [sterileBarrierIntact == true]
            then ReadyForApplication;

        transition Ready_to_Applied
            first ReadyForApplication
            accept ApplyHyalobarrier
            then AppliedToTissue;

        transition Applied_to_Active
            first AppliedToTissue
            accept after 0.1
            then BarrierFunctionActive;

        transition Active_to_Resorbing
            first BarrierFunctionActive
            accept after 7.0
            then Resorbing;

        transition Resorbing_to_Resorbed
            first Resorbing
            accept after 28.0
            then Resorbed;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Hyalobarrier system shall provide a sterile, bioresorbable hyaluronic-acid gel barrier that is applied to injured surgical tissue surfaces to temporarily separate adjacent tissues during early healing and reduce the likelihood of post-surgical adhesion formation. */

        subject system : HyalobarrierSystem;

        require constraint {
            system.antiAdhesionGel.formsTemporaryPhysicalBarrier == true
        }

        require constraint {
            system.antiAdhesionGel.bioresorbable == true
        }

        require constraint {
            system.nominalResidenceTime >= 7.0
        }
    }

    requirement def SterilityRequirement {
        doc /* The system shall maintain sterility of the gel until application. */

        subject system : HyalobarrierSystem;

        require constraint {
            system.gelReservoir.gelCharge.sterile == true and
            system.sterileSyringe.sterile == true and
            system.sterileSyringe.sterilityAssurance <= 1.0E-6
        }
    }

    requirement def BiocompatibilityRequirement {
        doc /* The gel and its degradation products shall be biocompatible and absorbable in the physiological environment. */

        subject system : HyalobarrierSystem;

        require constraint {
            system.antiAdhesionGel.material.biodegradable == true and
            system.biologicalResorptionProcess.resorbedProduct.biocompatible == true and
            system.biologicalResorptionProcess.resorbedProduct.absorbable == true
        }
    }

    requirement def ApplicationRequirement {
        doc /* The system shall allow controlled placement of a conforming gel layer over injured tissue using a sterile applicator. */

        subject system : HyalobarrierSystem;

        require constraint {
            system.sterileSyringe.singleUse == true and
            system.cannula.atraumaticTip == true and
            system.gelReservoir.fillVolume >= system.nominalGelVolume
        }
    }

    requirement def AdhesionRiskReductionRequirement {
        doc /* The treated tissue site shall have a lower modeled adhesion risk after gel placement than before treatment. */

        subject site : SurgicalTissueSite;

        require constraint {
            site.adhesionRiskAfterTreatment < site.adhesionRiskBeforeTreatment
        }
    }

    satisfy PrimaryFunctionRequirement by HyalobarrierSystem;
    satisfy SterilityRequirement by HyalobarrierSystem;
    satisfy BiocompatibilityRequirement by HyalobarrierSystem;
    satisfy ApplicationRequirement by HyalobarrierSystem;
    satisfy AdhesionRiskReductionRequirement by SurgicalTissueSite;

    part hyalobarrierProduct : HyalobarrierSystem {
        sterileBarrierIntact = true;
        readyForUse = true;
    }
}