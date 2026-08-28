package WordCatheterTreatmentSystem {
    private import ScalarValues::*;
    private import SI::*;

    item def SalineSolution;
    item def AbscessFluid;

    port def SalinePort {
        inout item saline : SalineSolution;
    }
    port def FluidOutPort {
        out item fluid : AbscessFluid;
    }
    port def FluidInPort {
        in item fluid : AbscessFluid;
    }

    part def InflationSyringe {
        port salineOutPort : SalinePort;
        attribute capacity : Real = 10.0 [mL];
        attribute currentVolume : Real = 10.0 [mL];
    }

    part def CollectionReservoir {
        port fluidInPort : FluidInPort;
        attribute capacity : Real = 100.0 [mL];
        attribute collectedVolume : Real = 0.0 [mL];
        item collectedFluid : AbscessFluid;
    }

    part def InflatableBulb {
        port inflatePort : SalinePort;
        attribute inflated : Boolean = false;
        attribute inflationVolume : Real = 0.0 [mL];
    }

    part def DrainageLumen {
        port lumenInPort : FluidInPort;
        port lumenOutPort : FluidOutPort;
        attribute patent : Boolean = true;
    }

    state def CatheterLifecycle {
        initial state Uninflated;
        transition to_inflated from Uninflated to Inflated;
        state Inflated;
        transition to_deflated from Inflated to Deflated;
        state Deflated;
        transition to_removed from Deflated to Removed;
        state Removed;
    }

    part def WordCatheter {
        attribute material : String = "Medical-grade silicone";
        attribute length : Real = 5.0 [cm];
        attribute treatmentDurationWeeks : Real = 4.0;

        port salineInPort : SalinePort;
        port drainageOutPort : FluidOutPort;

        part bulb : InflatableBulb;
        part drainageLumen : DrainageLumen;

        exhibit state lifecycle : CatheterLifecycle;

        flow from salineInPort.saline to bulb.inflatePort.saline;
        flow from drainageLumen.lumenOutPort.fluid to drainageOutPort.fluid;
    }

    part def Patient {
        port abscessCavity : FluidOutPort;
    }

    part def HealthcareProfessional;

    action def MakeIncision {
        in part patient : Patient;
        in part clinician : HealthcareProfessional;
    }
    action def InsertCatheter {
        in part patient : Patient;
        in part clinician : HealthcareProfessional;
        inout part catheter : WordCatheter;
    }
    action def InflateBulb {
        in part syringe : InflationSyringe;
        inout part catheter : WordCatheter;
    }
    action def MonitorDrainage {
        in part catheter : WordCatheter;
        out attribute isPatent : Boolean;
    }
    action def DeflateBulb {
        inout part catheter : WordCatheter;
    }
    action def RemoveCatheter {
        in part patient : Patient;
        in part clinician : HealthcareProfessional;
        inout part catheter : WordCatheter;
    }

    action def TreatmentProcess {
        in part patient : Patient;
        in part clinician : HealthcareProfessional;
        inout part catheter : WordCatheter;
        in part syringe : InflationSyringe;

        action makeIncision : MakeIncision {
            in part patient = patient;
            in part clinician = clinician;
        }
        then action insertCatheter : InsertCatheter {
            in part patient = patient;
            in part clinician = clinician;
            inout part catheter = catheter;
        }
        then action inflateBulb : InflateBulb {
            in part syringe = syringe;
            inout part catheter = catheter;
        }
        then action monitorDrainage : MonitorDrainage {
            in part catheter = catheter;
        }
        then action deflateBulb : DeflateBulb {
            inout part catheter = catheter;
        }
        then action removeCatheter : RemoveCatheter {
            in part patient = patient;
            in part clinician = clinician;
            inout part catheter = catheter;
        }
    }

    requirement def DrainageRequirement {
        doc /* The catheter must maintain a patent drainage lumen for the duration of treatment. */
        subject catheter : WordCatheter;
        require catheter.drainageLumen.patent == true;
    }

    requirement def AnchoringRequirement {
        doc /* The bulb must be inflatable with saline and remain inflated for several weeks. */
        subject catheter : WordCatheter;
        require catheter.bulb.inflated == true;
    }

    requirement def MaterialRequirement {
        doc /* The catheter must be constructed from biocompatible, medical-grade silicone. */
        subject catheter : WordCatheter;
        require catheter.material == "Medical-grade silicone";
    }

    part treatmentSystem {
        part clinician : HealthcareProfessional;
        part patient : Patient;
        part catheter : WordCatheter;
        part syringe : InflationSyringe;
        part reservoir : CollectionReservoir;

        flow of saline : SalineSolution
            from syringe.salineOutPort.saline
            to catheter.salineInPort.saline;

        flow of fluid : AbscessFluid
            from patient.abscessCavity.fluid
            to catheter.drainageLumen.lumenInPort.fluid;

        flow of fluid : AbscessFluid
            from catheter.drainageOutPort.fluid
            to reservoir.fluidInPort.fluid;

        perform action treatment : TreatmentProcess {
            in part patient = patient;
            in part clinician = clinician;
            inout part catheter = catheter;
            in part syringe = syringe;
        }

        requirement drainageReq : DrainageRequirement {
            :>> subject = catheter;
        }
        requirement anchoringReq : AnchoringRequirement {
            :>> subject = catheter;
        }
        requirement materialReq : MaterialRequirement {
            :>> subject = catheter;
        }
    }
}
