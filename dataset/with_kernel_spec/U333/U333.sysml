package OmmayaReservoirSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PunctureCount :> Integer;

    item def Fluid;
    item def Medication :> Fluid {
        attribute volume : VolumeValue;
        attribute concentration : Real;
    }
    item def CerebrospinalFluid :> Fluid {
        attribute pressure : Real;
    }
    item def DiagnosticSample :> CerebrospinalFluid;

    attribute def NeedleInserted;
    attribute def NeedleWithdrawn;
    attribute def InjectMedication;
    attribute def AspirateFluid;

    part def NonCoringNeedle {
        attribute gauge : LengthValue;
        attribute isInserted : Boolean = false;
    }

    port def FluidPort {
        inout fluid : Fluid;
    }

    port def AccessPort {
        in insertedNeedle : NonCoringNeedle;
    }

    connection def FluidConnection {
        end source : FluidPort;
        end target : FluidPort;
    }

    part def SelfSealingSeptum {
        attribute material : String = "Medical-grade silicone";
        attribute maxPunctures : PunctureCount = 200;
        attribute punctureCount : PunctureCount = 0;
        attribute integrityIntact : Boolean = true;
        port accessPort : AccessPort;
    }

    part def ReservoirDome {
        attribute material : String = "Medical-grade silicone";
        attribute capacity : VolumeValue;
        attribute fluidVolume : VolumeValue;
        part septum : SelfSealingSeptum;
        port fluidPort : FluidPort;
        port accessPort : AccessPort;
        connect septum.accessPort to accessPort;
    }

    part def VentricularCatheter {
        attribute material : String = "Medical-grade silicone";
        attribute length : LengthValue;
        attribute innerDiameter : LengthValue;
        attribute isPatent : Boolean = true;
        port proximalPort : FluidPort;
        port distalPort : FluidPort;
    }

    action def Puncture {
        in septum : SelfSealingSeptum;
        out newCount : PunctureCount;
    }

    action def SelfSeal {
        in septum : SelfSealingSeptum;
    }

    action def VerifySeal {
        in septum : SelfSealingSeptum;
    }

    action def ConfirmNeedlePlacement;

    action def DeliverMedication {
        in medication : Medication;
        in reservoirDome : ReservoirDome;
        in ventricularCatheter : VentricularCatheter;
    }

    action def AspirateCSF {
        in reservoirDome : ReservoirDome;
        in ventricularCatheter : VentricularCatheter;
        out sample : DiagnosticSample;
    }

    action def CheckPatency {
        in catheter : VentricularCatheter;
        out isPatent : Boolean;
    }

    part def OmmayaReservoir {
        attribute material : String = "Medical-grade silicone";
        part dome : ReservoirDome;
        part catheter : VentricularCatheter;
        connection domeToCatheter : FluidConnection
            connect dome.fluidPort to catheter.proximalPort;

        action verifySeal { in septum : SelfSealingSeptum; }
        action punctureAction { in septum : SelfSealingSeptum; }
        action confirmPlacement;
        action deliverMedication { in reservoirDome : ReservoirDome; in ventricularCatheter : VentricularCatheter; }
        action aspirateCSF { in reservoirDome : ReservoirDome; in ventricularCatheter : VentricularCatheter; }

        exhibit state operationalState {
            entry; then sealed;

            state sealed {
                entry verifySeal { in septum = dome.septum; }
            }

            accept NeedleInserted
                if dome.septum.punctureCount < dome.septum.maxPunctures
                   and catheter.isPatent == true
                then accessed;

            state accessed {
                entry punctureAction { in septum = dome.septum; }
                do confirmPlacement;
                accept InjectMedication then delivering;
                accept AspirateFluid then sampling;
                accept NeedleWithdrawn then sealed;
            }

            state delivering {
                do deliverMedication { in reservoirDome = dome; in ventricularCatheter = catheter; }
                accept NeedleWithdrawn then sealed;
            }

            state sampling {
                do aspirateCSF { in reservoirDome = dome; in ventricularCatheter = catheter; }
                accept NeedleWithdrawn then sealed;
            }
        }
    }

    requirement def BiocompatibilityRequirement {
        subject reservoir : OmmayaReservoir;
        text "All implanted components shall be constructed from medical-grade biocompatible materials suitable for long-term subcutaneous and intraventricular placement.";
    }

    requirement def SeptumIntegrityRequirement {
        subject septum : SelfSealingSeptum;
        attribute requiredPunctures : PunctureCount = 200;
        text "The self-sealing septum shall withstand at least requiredPunctures punctures without compromising its seal integrity or allowing leakage of cerebrospinal fluid.";
    }

    requirement def CatheterPatencyRequirement {
        subject catheter : VentricularCatheter;
        text "The ventricular catheter shall remain patent (unblocked) to allow continuous bidirectional flow of fluid between the reservoir and the lateral ventricle.";
    }

    requirement def MedicationDeliveryRequirement {
        subject reservoir : OmmayaReservoir;
        text "The system shall allow delivery of medication into the cerebrospinal fluid through the ventricular catheter for distribution throughout the central nervous system.";
    }

    requirement def FluidSamplingRequirement {
        subject reservoir : OmmayaReservoir;
        text "The system shall allow withdrawal of cerebrospinal fluid samples through the ventricular catheter for diagnostic analysis without repeated spinal taps.";
    }

    part ommayaReservoir : OmmayaReservoir {
        :>> dome.capacity = 2.0 [mL];
        :>> catheter.length = 60.0 [mm];
        :>> catheter.innerDiameter = 1.0 [mm];
    }

    requirement biocompatibilityReq : BiocompatibilityRequirement {
        subject :>> reservoir = ommayaReservoir;
    }

    requirement septumIntegrityReq : SeptumIntegrityRequirement {
        subject :>> septum = ommayaReservoir.dome.septum;
    }

    requirement catheterPatencyReq : CatheterPatencyRequirement {
        subject :>> catheter = ommayaReservoir.catheter;
    }

    requirement medicationDeliveryReq : MedicationDeliveryRequirement {
        subject :>> reservoir = ommayaReservoir;
    }

    requirement fluidSamplingReq : FluidSamplingRequirement {
        subject :>> reservoir = ommayaReservoir;
    }
}
