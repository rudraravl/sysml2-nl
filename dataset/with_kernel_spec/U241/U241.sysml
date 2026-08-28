package AutoDisableSyringeEcosystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    // ---- Value Types ----
    alias VolumeValue for ISQ::VolumeValue;
    alias TemperatureValue for ISQ::ThermodynamicTemperatureValue;
    alias PressureValue for ISQ::PressureValue;
    alias LengthValue for ISQ::LengthValue;
    alias MassValue for ISQ::MassValue;
    alias TimeValue for ISQ::TimeValue;

    attribute def DoseVolume :> VolumeValue;
    attribute def MoldingTemp :> TemperatureValue;
    attribute def StartAdminister;
    attribute def DisposeEvent;

    // ---- Item Types ----
    item def PolypropyleneResin;
    item def EthyleneOxideGas;
    item def TyvekPackagingMaterial;
    item def AcceptedProduct;
    item def RejectedProduct;

    // ---- Syringe Component Definitions ----
    part def Barrel {
        attribute material : String = "Medical-grade polypropylene";
        attribute capacity : VolumeValue = 5.0 [mL];
        attribute innerDiameter : LengthValue = 10.0 [mm];
        attribute length : LengthValue = 80.0 [mm];
        port materialPort;
    }

    part def Plunger {
        attribute material : String = "Medical-grade polypropylene";
        attribute strokeLength : LengthValue = 60.0 [mm];
        attribute sealMaterial : String = "Silicone rubber";
        port materialPort;
    }

    part def Needle {
        attribute material : String = "Stainless steel";
        attribute gauge : Integer = 23;
        attribute length : LengthValue = 25.0 [mm];
        attribute sterile : Boolean = true;
        port materialPort;
    }

    part def AutoDisableMechanism {
        attribute lockEngaged : Boolean = false;
        attribute activationDose : VolumeValue = 5.0 [mL];
        port controlPort;

        action def EngageLock {
            in dose : VolumeValue;
            out locked : Boolean;
        }

        action engageLock : EngageLock {
            in dose;
            out locked = true;
        }
    }

    // ---- Auto-Disable Syringe ----
    part def AutoDisableSyringe {
        port medIn;
        port medOut;

        part barrel : Barrel;
        part plunger : Plunger;
        part needle : Needle;
        part mechanism : AutoDisableMechanism;

        attribute capacity : VolumeValue = 5.0 [mL];
        attribute currentDose : VolumeValue = 0.0 [mL];
        attribute isLocked : Boolean = false;

        connect barrel.materialPort to plunger.materialPort;
        connect plunger.materialPort to mechanism.controlPort;
        connect barrel.materialPort to needle.materialPort;

        action def AdministerMedication {
            in requestedDose : VolumeValue;
            out deliveredDose : VolumeValue;
        }

        action administer : AdministerMedication {
            in requestedDose;
            out deliveredDose = requestedDose;
        }

        state def Lifecycle {
            entry; then ready;
            state ready;
            state administering;
            state locked;
            state disposed;
            
            transition first ready accept StartAdminister then administering;
            transition first administering if mechanism.lockEngaged then locked;
            transition first locked accept DisposeEvent then disposed;
        }
    }

    // ---- Packaged Syringe ----
    part def SyringePackaging {
        attribute material : String = "Tyvek";
        attribute sealed : Boolean = false;
        attribute sterile : Boolean = false;
    }

    part def PackagedSyringe {
        part syringe : AutoDisableSyringe;
        part packaging : SyringePackaging;
        attribute inspected : Boolean = false;
        attribute passedInspection : Boolean = false;
    }

    // ---- Manufacturing Action Definitions ----
    action def MoldComponents {
        in rawMaterial : PolypropyleneResin;
        out barrel : Barrel;
        out plunger : Plunger;
    }

    action def AssembleSyringe {
        in barrel : Barrel;
        in plunger : Plunger;
        in needle : Needle;
        out syringe : AutoDisableSyringe;
    }

    action def Sterilize {
        in syringe : AutoDisableSyringe;
        in sterilant : EthyleneOxideGas;
        out sterileSyringe : AutoDisableSyringe;
    }

    action def PackageSyringe {
        in syringe : AutoDisableSyringe;
        in packagingMaterial : TyvekPackagingMaterial;
        out packagedSyringe : PackagedSyringe;
    }

    action def Inspect {
        in packagedSyringe : PackagedSyringe;
        out accepted : PackagedSyringe;
        out rejected : PackagedSyringe;
    }

    // ---- Manufacturing Station Definitions ----
    part def MoldingStation {
        port rawMaterialIn;
        port barrelOut;
        port plungerOut;

        attribute moldTemp : TemperatureValue = 473.15 [K];
        attribute injectionPressure : PressureValue = 100.0 [MPa];

        action moldComponents : MoldComponents;
    }

    part def AssemblyStation {
        port barrelIn;
        port plungerIn;
        port needleIn;
        port syringeOut;

        attribute assemblyForce : PressureValue = 50.0 [kPa];

        action assembleSyringe : AssembleSyringe;
    }

    part def SterilizationChamber {
        port syringeIn;
        port gasIn;
        port sterileSyringeOut;

        attribute gasType : String = "Ethylene Oxide";
        attribute chamberTemp : TemperatureValue = 328.15 [K];
        attribute exposureTime : TimeValue = 3600.0 [s];

        action sterilize : Sterilize;
    }

    part def PackagingStation {
        port syringeIn;
        port packagingMaterialIn;
        port packagedSyringeOut;

        attribute sealIntegrity : Boolean = true;

        action packageSyringe : PackageSyringe;
    }

    part def QualityInspectionUnit {
        port packagedSyringeIn;
        port acceptedOut;
        port rejectedOut;

        attribute passRate : Real = 0.98;

        action inspect : Inspect;
    }

    part def DisposalBin {
        port wasteIn;
    }

    // ---- Manufacturing System ----
    part def SyringeManufacturingSystem {
        part molding : MoldingStation;
        part assembly : AssemblyStation;
        part sterilization : SterilizationChamber;
        part packaging : PackagingStation;
        part inspection : QualityInspectionUnit;
        part disposal : DisposalBin;

        port rawMaterialSupply;
        port needleSupply;
        port packagingMaterialSupply;
        port acceptedProduct;
        port rejectedProduct;

        connect rawMaterialSupply to molding.rawMaterialIn;
        connect molding.barrelOut to assembly.barrelIn;
        connect molding.plungerOut to assembly.plungerIn;
        connect needleSupply to assembly.needleIn;
        connect assembly.syringeOut to sterilization.syringeIn;
        connect sterilization.sterileSyringeOut to packaging.syringeIn;
        connect packagingMaterialSupply to packaging.packagingMaterialIn;
        connect packaging.packagedSyringeOut to inspection.packagedSyringeIn;
        connect inspection.acceptedOut to acceptedProduct;
        connect inspection.rejectedOut to disposal.wasteIn;
    }

    // ---- Manufacturing Process Action ----
    action def ManufactureSyringe {
        action mold : MoldComponents;
        action assemble : AssembleSyringe;
        action sterilize : Sterilize;
        action packageSyringe : PackageSyringe;
        action inspect : Inspect;

        flow mold.barrel to assemble.barrel;
        flow mold.plunger to assemble.plunger;
        flow assemble.syringe to sterilize.syringe;
        flow sterilize.sterileSyringe to packageSyringe.syringe;
        flow packageSyringe.packagedSyringe to inspect.packagedSyringe;

        first start then mold then assemble then sterilize then packageSyringe then inspect then done;
    }

    // ---- Clinical Use ----
    part def Patient;

    action def Administer {
        in syringe : AutoDisableSyringe;
        in patient : Patient;
        out dose : VolumeValue;
    }

    action def DisposeSyringe {
        in syringe : AutoDisableSyringe;
    }

    action def ClinicalUse {
        action administer : Administer;
        action dispose : DisposeSyringe;

        first start then administer then dispose then done;
    }

    // ---- Requirements ----
    requirement def SingleUseRequirement {
        doc /* The syringe must be permanently disabled after a single full dose delivery. */
        subject syringe : AutoDisableSyringe;
        constraint { syringe.isLocked == true }
    }

    requirement def AutoDisableRequirement {
        doc /* The auto-disable mechanism must engage when plunger travel reaches 100% of dose volume. */
        subject mechanism : AutoDisableMechanism;
        constraint { mechanism.lockEngaged == true }
    }

    requirement def SterilityRequirement {
        doc /* Packaged syringes must maintain sterility with SAL <= 10^-6. */
        subject packaging : SyringePackaging;
        constraint { packaging.sterile == true }
    }

    requirement def DimensionalAccuracyRequirement {
        doc /* Barrel and plunger dimensions must be within +/- 0.05mm tolerance. */
        subject barrel : Barrel;
        constraint { barrel.innerDiameter >= 9.95 [mm] and barrel.innerDiameter <= 10.05 [mm] }
    }

    requirement def PackageIntegrityRequirement {
        doc /* Packaging shall maintain sterility until opened. */
        subject packaging : SyringePackaging;
        constraint { packaging.sealed == true }
    }

    // ---- Individual Definitions ----
    individual def ProductionLine :> SyringeManufacturingSystem;
    individual def ClinicalSyringe :> AutoDisableSyringe;

    individual productionLine : ProductionLine {
        perform ManufactureSyringe;
    }

    individual clinicalSyringe : ClinicalSyringe {
        perform ClinicalUse;
    }
}
