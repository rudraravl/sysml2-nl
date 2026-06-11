package LowDeadSpaceSyringeSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Volume_ml :> Real {
        unit = "mL";
    }

    attribute def Pressure_kPa :> Real {
        unit = "kPa";
    }

    attribute def Force_N :> Real {
        unit = "N";
    }

    attribute def Length_mm :> Real {
        unit = "mm";
    }

    attribute def Area_mm2 :> Real {
        unit = "mm^2";
    }

    attribute def DoseAccuracyPercent :> Real {
        unit = "%";
    }

    attribute def FrictionForce_N :> Real {
        unit = "N";
    }

    enum def SyringeStateKind {
        enum idle;
        enum filling;
        enum primed;
        enum injecting;
        enum depleted;
        enum disposed;
    }

    enum def FluidSterilityKind {
        enum sterile;
        enum contaminated;
    }

    enum def ConnectionStateKind {
        enum disconnected;
        enum attached;
        enum locked;
    }

    item def InjectableFluid {
        attribute volume : Volume_ml;
        attribute viscosity : Real;
        attribute sterility : FluidSterilityKind;
        attribute isMedication : Boolean;
    }

    item def ExpelledDose {
        attribute deliveredVolume : Volume_ml;
        attribute residualVolume : Volume_ml;
        attribute deliveryPressure : Pressure_kPa;
    }

    item def UserFingerForce {
        attribute magnitude : Force_N;
        attribute directionAlongAxis : Boolean;
    }

    item def NeedleInterfaceFluid {
        attribute flowVolume : Volume_ml;
        attribute flowPressure : Pressure_kPa;
        attribute containsAir : Boolean;
    }

    port def FluidPort {
        out item fluidOut : NeedleInterfaceFluid;
        in item fluidIn : InjectableFluid;
    }

    port def MechanicalForcePort {
        in item appliedForce : UserFingerForce;
    }

    port def NeedleHubPort {
        out item injectedFluid : NeedleInterfaceFluid;
        attribute connectionState : ConnectionStateKind;
    }

    port def VentlessSealPort {
        out item containedFluid : InjectableFluid;
        attribute leakFree : Boolean;
    }

    action def DrawFluid {
        inout item reservoirFluid : InjectableFluid;
        out item chamberFluid : InjectableFluid;
        in attribute requestedFillVolume : Volume_ml;
        out attribute actualFillVolume : Volume_ml;

        constraint fillConservation {
            actualFillVolume <= requestedFillVolume;
            actualFillVolume <= reservoirFluid.volume;
            chamberFluid.volume == actualFillVolume;
        }
    }

    action def PrimeSyringe {
        inout item chamberFluid : InjectableFluid;
        out item primingExpelledFluid : NeedleInterfaceFluid;
        in attribute primingVolume : Volume_ml;
        out attribute airRemoved : Boolean;

        constraint primingLimit {
            primingVolume >= 0.01;
            primingVolume <= 0.10;
            primingExpelledFluid.flowVolume == primingVolume;
            airRemoved == true;
        }
    }

    action def InjectDose {
        in item plungerForce : UserFingerForce;
        inout item chamberFluid : InjectableFluid;
        out item dose : ExpelledDose;
        in attribute intendedDoseVolume : Volume_ml;
        in attribute deadSpaceVolume : Volume_ml;
        in attribute barrelVolume : Volume_ml;
        out attribute doseAccuracy : DoseAccuracyPercent;

        constraint doseDelivery {
            dose.deliveredVolume <= intendedDoseVolume;
            dose.residualVolume == deadSpaceVolume;
            dose.deliveredVolume == chamberFluid.volume - deadSpaceVolume;
            doseAccuracy == 100.0 * dose.deliveredVolume / intendedDoseVolume;
            dose.deliveryPressure >= 20.0;
        }
    }

    action def DisposeSyringe {
        inout attribute state : SyringeStateKind;
        out attribute reusable : Boolean;

        constraint singleUse {
            state == SyringeStateKind::disposed;
            reusable == false;
        }
    }

    part def Needle {
        attribute gauge : Integer;
        attribute internalVolume : Volume_ml = 0.002;
        attribute length : Length_mm = 16.0;
        attribute hubResidualVolume : Volume_ml = 0.001;
        attribute tipSterile : Boolean = true;

        port hub : NeedleHubPort;
        port lumen : FluidPort;
    }

    part def LowDeadSpaceNeedleHub {
        attribute sweptHubVolume : Volume_ml = 0.003;
        attribute unsweptHubVolume : Volume_ml = 0.001;
        attribute taperSeatLength : Length_mm = 4.0;
        attribute connectionState : ConnectionStateKind = ConnectionStateKind::disconnected;

        port syringeSide : FluidPort;
        port needleSide : NeedleHubPort;
    }

    part def Barrel {
        attribute nominalCapacity : Volume_ml = 1.0;
        attribute usableVolume : Volume_ml = 1.0;
        attribute innerDiameter : Length_mm = 4.7;
        attribute sweptCrossSection : Area_mm2 = 17.35;
        attribute graduationResolution : Volume_ml = 0.01;
        attribute containedVolume : Volume_ml = 0.0;
        attribute maxRatedPressure : Pressure_kPa = 600.0;
        attribute transparent : Boolean = true;
        attribute sterileInterior : Boolean = true;

        port distalOutlet : FluidPort;
        port proximalOpening : VentlessSealPort;
    }

    part def PlungerRod {
        attribute travel : Length_mm = 0.0;
        attribute maxTravel : Length_mm = 58.0;
        attribute thumbPadArea : Area_mm2 = 120.0;
        attribute appliedForce : Force_N = 0.0;

        port thumbInput : MechanicalForcePort;
    }

    part def LowDeadSpaceStopper {
        attribute sealDiameter : Length_mm = 4.7;
        attribute sweptTipLength : Length_mm = 3.5;
        attribute distalTipConformsToNozzle : Boolean = true;
        attribute residualCavityVolume : Volume_ml = 0.002;
        attribute staticFriction : FrictionForce_N = 1.2;
        attribute dynamicFriction : FrictionForce_N = 0.8;
        attribute leakFree : Boolean = true;

        port sealInterface : VentlessSealPort;
    }

    part def LowDeadSpaceNozzle {
        attribute nozzleInternalVolume : Volume_ml = 0.004;
        attribute distalCavityVolume : Volume_ml = 0.001;
        attribute luerTaperCompatible : Boolean = true;
        attribute outletDiameter : Length_mm = 0.45;
        attribute deadSpaceContribution : Volume_ml = 0.005;

        port barrelSide : FluidPort;
        port hubSide : FluidPort;
    }

    part def LowDeadSpaceSyringe {
        attribute nominalDoseCapacity : Volume_ml = 1.0;
        attribute maximumResidualVolume : Volume_ml = 0.035;
        attribute actualResidualVolume : Volume_ml = 0.011;
        attribute minimumDeliverableDose : Volume_ml = 0.05;
        attribute maximumDeliverableDose : Volume_ml = 1.0;
        attribute doseAccuracyAtFullScale : DoseAccuracyPercent = 98.9;
        attribute state : SyringeStateKind = SyringeStateKind::idle;
        attribute sterileFluidPath : Boolean = true;
        attribute singleUse : Boolean = true;

        part barrel : Barrel;
        part plungerRod : PlungerRod;
        part stopper : LowDeadSpaceStopper;
        part nozzle : LowDeadSpaceNozzle;
        part hub : LowDeadSpaceNeedleHub;
        part needle : Needle;

        port userForceInput : MechanicalForcePort;
        port medicationInterface : FluidPort;
        port patientInterface : NeedleHubPort;

        connect userForceInput to plungerRod.thumbInput;
        connect plungerRod.thumbInput to stopper.sealInterface;
        connect stopper.sealInterface to barrel.proximalOpening;
        connect barrel.distalOutlet to nozzle.barrelSide;
        connect nozzle.hubSide to hub.syringeSide;
        connect hub.needleSide to needle.hub;
        connect needle.lumen to patientInterface;
        connect medicationInterface to barrel.distalOutlet;

        constraint residualVolumeBudget {
            actualResidualVolume == stopper.residualCavityVolume
                                + nozzle.deadSpaceContribution
                                + hub.unsweptHubVolume
                                + needle.hubResidualVolume
                                + needle.internalVolume;
            actualResidualVolume <= maximumResidualVolume;
        }

        constraint doseCapacity {
            maximumDeliverableDose <= nominalDoseCapacity;
            minimumDeliverableDose > actualResidualVolume;
            barrel.usableVolume == nominalDoseCapacity;
        }

        constraint sterilePath {
            sterileFluidPath == barrel.sterileInterior
                              and stopper.leakFree
                              and needle.tipSterile;
        }

        action drawMedication : DrawFluid {
            in requestedFillVolume = nominalDoseCapacity;
            out actualFillVolume = barrel.containedVolume;
        }

        action prime : PrimeSyringe {
            in primingVolume = 0.03;
        }

        action inject : InjectDose {
            in intendedDoseVolume = barrel.containedVolume;
            in deadSpaceVolume = actualResidualVolume;
            in barrelVolume = barrel.usableVolume;
            out doseAccuracy = doseAccuracyAtFullScale;
        }

        action discard : DisposeSyringe {
            inout state = state;
        }

        state machine lifecycle {
            state idle;
            state filling;
            state primed;
            state injecting;
            state depleted;
            state disposed;

            initial then idle;

            transition idle_to_filling
                first idle
                accept fillCommand
                do drawMedication
                then filling;

            transition filling_to_primed
                first filling
                accept primeCommand
                do prime
                then primed;

            transition primed_to_injecting
                first primed
                accept thumbForceApplied
                do inject
                then injecting;

            transition injecting_to_depleted
                first injecting
                if barrel.containedVolume <= actualResidualVolume
                then depleted;

            transition depleted_to_disposed
                first depleted
                accept disposalCommand
                do discard
                then disposed;
        }
    }

    part def Clinician {
        attribute canApplyControlledForce : Boolean = true;
        attribute maxThumbForce : Force_N = 80.0;

        port handForce : MechanicalForcePort;
    }

    part def PatientInjectionSite {
        attribute acceptableInjectionPressure : Pressure_kPa = 500.0;
        attribute receivesSterileFluid : Boolean = true;

        port tissueInterface : NeedleHubPort;
    }

    part def VialOrReservoir {
        attribute availableVolume : Volume_ml = 10.0;
        attribute fluidSterility : FluidSterilityKind = FluidSterilityKind::sterile;

        port outlet : FluidPort;
    }

    part def LowDeadSpaceSyringeSystem {
        attribute primaryFunction : String =
            "Contain, measure, and deliver an injectable fluid dose while minimizing residual dead-space volume after plunger depression.";
        attribute deliveredDoseTarget : Volume_ml = 0.50;
        attribute residualWasteLimit : Volume_ml = 0.035;
        attribute operatingPressureLimit : Pressure_kPa = 600.0;

        part syringe : LowDeadSpaceSyringe;
        part clinician : Clinician;
        part reservoir : VialOrReservoir;
        part patientSite : PatientInjectionSite;

        connect clinician.handForce to syringe.userForceInput;
        connect reservoir.outlet to syringe.medicationInterface;
        connect syringe.patientInterface to patientSite.tissueInterface;

        constraint highLevelFunctionSatisfied {
            syringe.actualResidualVolume <= residualWasteLimit;
            syringe.nominalDoseCapacity >= deliveredDoseTarget;
            syringe.sterileFluidPath == true;
            syringe.singleUse == true;
        }

        action performInjection {
            first syringe.drawMedication;
            then syringe.prime;
            then syringe.inject;
            then syringe.discard;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : LowDeadSpaceSyringeSystem;

        doc /* The low dead space syringe system shall contain, measure, and deliver an injectable fluid dose to a patient while reducing the volume of medication retained in the syringe, hub, and needle after injection. */

        require constraint {
            system.syringe.actualResidualVolume <= system.residualWasteLimit;
            system.syringe.sterileFluidPath == true;
            system.syringe.nominalDoseCapacity >= system.deliveredDoseTarget;
        }
    }

    requirement def ResidualVolumeRequirement {
        subject syringe : LowDeadSpaceSyringe;

        doc /* The syringe shall have a total post-injection residual volume no greater than 0.035 mL. */

        require constraint {
            syringe.actualResidualVolume <= 0.035;
        }
    }

    requirement def DoseDeliveryRequirement {
        subject syringe : LowDeadSpaceSyringe;

        doc /* The syringe shall deliver at least 98 percent of a full nominal fill volume when operated through complete plunger travel after priming. */

        require constraint {
            syringe.doseAccuracyAtFullScale >= 98.0;
        }
    }

    requirement def SterileSingleUseRequirement {
        subject syringe : LowDeadSpaceSyringe;

        doc /* The syringe shall maintain a sterile fluid path before use and shall be intended for single use only. */

        require constraint {
            syringe.sterileFluidPath == true;
            syringe.singleUse == true;
        }
    }

    requirement def PressureSafetyRequirement {
        subject system : LowDeadSpaceSyringeSystem;

        doc /* The injection fluid path shall remain within rated pressure limits during intended manual operation. */

        require constraint {
            system.operatingPressureLimit <= system.syringe.barrel.maxRatedPressure;
            system.patientSite.acceptableInjectionPressure <= system.syringe.barrel.maxRatedPressure;
        }
    }

    satisfy PrimaryFunctionRequirement by LowDeadSpaceSyringeSystem;
    satisfy ResidualVolumeRequirement by LowDeadSpaceSyringe;
    satisfy DoseDeliveryRequirement by LowDeadSpaceSyringe;
    satisfy SterileSingleUseRequirement by LowDeadSpaceSyringe;
    satisfy PressureSafetyRequirement by LowDeadSpaceSyringeSystem;
}