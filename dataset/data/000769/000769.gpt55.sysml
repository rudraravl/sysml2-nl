package SpeculumHighLevelModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    unit def millimeter :> metre {
        attribute conversionFactor: Real = 0.001;
        attribute symbol: String = "mm";
    }

    unit def newton :> kilogram * metre / second^2 {
        attribute symbol: String = "N";
    }

    unit def degree {
        attribute conversionFactor: Real = 0.0174532925199433;
        attribute symbol: String = "deg";
    }

    unit def secondUnit :> second {
        attribute symbol: String = "s";
    }

    unit def lux {
        attribute symbol: String = "lx";
    }

    unit def kilopascal {
        attribute conversionFactor: Real = 1000.0;
        attribute symbol: String = "kPa";
    }

    attribute def Length_mm :> Real {
        attribute unitSymbol: String = "mm";
    }

    attribute def Force_N :> Real {
        attribute unitSymbol: String = "N";
    }

    attribute def Angle_deg :> Real {
        attribute unitSymbol: String = "deg";
    }

    attribute def Time_s :> Real {
        attribute unitSymbol: String = "s";
    }

    attribute def Illuminance_lx :> Real {
        attribute unitSymbol: String = "lx";
    }

    attribute def Pressure_kPa :> Real {
        attribute unitSymbol: String = "kPa";
    }

    attribute def Temperature_C :> Real {
        attribute unitSymbol: String = "degC";
    }

    item def ManualInput {
        attribute gripForce: Force_N;
        attribute thumbForce: Force_N;
        attribute releaseForce: Force_N;
    }

    item def OpeningCommand {
        attribute requestedOpening: Length_mm;
        attribute requestedAngle: Angle_deg;
    }

    item def LockCommand {
        attribute lockRequested: Boolean;
        attribute releaseRequested: Boolean;
    }

    item def BladeMotion {
        attribute upperBladeAngle: Angle_deg;
        attribute lowerBladeAngle: Angle_deg;
        attribute apertureWidth: Length_mm;
        attribute motionTime: Time_s;
    }

    item def TissueContactLoad {
        attribute distributedForce: Force_N;
        attribute peakPressure: Pressure_kPa;
        attribute contactLength: Length_mm;
    }

    item def VisualAccess {
        attribute fieldWidth: Length_mm;
        attribute fieldLength: Length_mm;
        attribute unobstructed: Boolean;
    }

    item def Illumination {
        attribute illuminanceAtField: Illuminance_lx;
        attribute enabled: Boolean;
    }

    item def SterileBarrierStatus {
        attribute sterile: Boolean;
        attribute packageIntact: Boolean;
        attribute singleUse: Boolean;
    }

    item def DeviceStatus {
        attribute closed: Boolean;
        attribute inserted: Boolean;
        attribute locked: Boolean;
        attribute apertureWidth: Length_mm;
        attribute illuminationOn: Boolean;
        attribute safeToWithdraw: Boolean;
    }

    port def ClinicianHandPort {
        in item manualInput: ManualInput;
        in item openingCommand: OpeningCommand;
        in item lockCommand: LockCommand;
        out item deviceStatus: DeviceStatus;
    }

    port def MechanicalActuationPort {
        in item manualInput: ManualInput;
        in item openingCommand: OpeningCommand;
        in item lockCommand: LockCommand;
        out item bladeMotion: BladeMotion;
    }

    port def BladeMotionPort {
        in item bladeMotion: BladeMotion;
        out item tissueContactLoad: TissueContactLoad;
        out item visualAccess: VisualAccess;
    }

    port def LockInterfacePort {
        in item bladeMotion: BladeMotion;
        in item lockCommand: LockCommand;
        out item deviceStatus: DeviceStatus;
    }

    port def TissueInterfacePort {
        out item tissueContactLoad: TissueContactLoad;
        out item visualAccess: VisualAccess;
    }

    port def VisualFieldPort {
        out item visualAccess: VisualAccess;
        out item illumination: Illumination;
    }

    port def LightPort {
        in item deviceStatus: DeviceStatus;
        out item illumination: Illumination;
    }

    port def SterilityPort {
        out item sterileBarrierStatus: SterileBarrierStatus;
    }

    part def HandleAssembly {
        attribute handleLength: Length_mm = 95.0;
        attribute handleWidth: Length_mm = 24.0;
        attribute maximumGripForce: Force_N = 75.0;
        attribute oneHandOperable: Boolean = true;

        port clinicianInterface: ClinicianHandPort;
        port actuationOut: MechanicalActuationPort;

        action def ConvertGripToOpening {
            in item manualInput: ManualInput;
            in item openingCommand: OpeningCommand;
            out item bladeMotion: BladeMotion;

            attribute mechanicalAdvantage: Real = 2.8;
            attribute responseTime: Time_s = 0.5;
        }
    }

    part def UpperBlade {
        attribute bladeLength: Length_mm = 105.0;
        attribute bladeWidth: Length_mm = 22.0;
        attribute leadingEdgeRadius: Length_mm = 3.0;
        attribute surfaceRoughnessRa: Length_mm = 0.001;
        attribute transparentMaterial: Boolean = true;

        port motionIn: BladeMotionPort;
        port tissueContact: TissueInterfacePort;
        port visualBoundary: VisualFieldPort;
    }

    part def LowerBlade {
        attribute bladeLength: Length_mm = 110.0;
        attribute bladeWidth: Length_mm = 24.0;
        attribute leadingEdgeRadius: Length_mm = 3.0;
        attribute surfaceRoughnessRa: Length_mm = 0.001;
        attribute transparentMaterial: Boolean = true;

        port motionIn: BladeMotionPort;
        port tissueContact: TissueInterfacePort;
        port visualBoundary: VisualFieldPort;
    }

    part def PivotJoint {
        attribute pivotPinDiameter: Length_mm = 4.0;
        attribute angularTravel: Angle_deg = 42.0;
        attribute frictionTorqueNominal: Real = 0.08;
        attribute backlashAngle: Angle_deg = 1.0;

        port actuationIn: MechanicalActuationPort;
        port upperBladeOut: BladeMotionPort;
        port lowerBladeOut: BladeMotionPort;
    }

    part def RatchetLock {
        attribute numberOfTeeth: Integer = 8;
        attribute openingIncrement: Length_mm = 4.0;
        attribute maximumHeldForce: Force_N = 45.0;
        attribute releaseTravel: Length_mm = 6.0;
        attribute audibleFeedback: Boolean = true;

        port lockControl: LockInterfacePort;
        port handRelease: ClinicianHandPort;
    }

    part def LightModule {
        attribute integrated: Boolean = true;
        attribute nominalIlluminance: Illuminance_lx = 900.0;
        attribute minimumIlluminance: Illuminance_lx = 400.0;
        attribute maximumSurfaceTemperature: Temperature_C = 41.0;
        attribute batteryPowered: Boolean = true;

        port powerAndControl: LightPort;
        port lightOutput: VisualFieldPort;

        action def IlluminateExaminationField {
            in item deviceStatus: DeviceStatus;
            out item illumination: Illumination;
        }
    }

    part def SterilePackage {
        attribute packageMaterial: String = "sealed medical pouch";
        attribute singleUseSterile: Boolean = true;
        attribute shelfLifeMonths: Integer = 36;

        port sterilityOut: SterilityPort;
    }

    part def PatientTissueInterface {
        attribute compliantContact: Boolean = true;
        attribute nominalContactLength: Length_mm = 90.0;
        attribute maximumAllowedPeakPressure: Pressure_kPa = 18.0;
        attribute maximumAllowedDistributedForce: Force_N = 30.0;

        port upperContactIn: TissueInterfacePort;
        port lowerContactIn: TissueInterfacePort;
        port visualFieldOut: VisualFieldPort;
    }

    action def InsertClosedSpeculum {
        in item sterileBarrierStatus: SterileBarrierStatus;
        out item deviceStatus: DeviceStatus;

        attribute closedInsertionWidth: Length_mm = 28.0;
        attribute insertionTime: Time_s = 5.0;
    }

    action def OpenBladesToCreateAccess {
        in item manualInput: ManualInput;
        in item openingCommand: OpeningCommand;
        out item bladeMotion: BladeMotion;
        out item tissueContactLoad: TissueContactLoad;
        out item visualAccess: VisualAccess;

        attribute minimumUsefulAperture: Length_mm = 20.0;
        attribute maximumAperture: Length_mm = 46.0;
        attribute maximumOpeningAngle: Angle_deg = 42.0;
    }

    action def HoldApertureForExamination {
        in item lockCommand: LockCommand;
        in item bladeMotion: BladeMotion;
        out item deviceStatus: DeviceStatus;
        out item visualAccess: VisualAccess;

        attribute stableHoldDuration: Time_s = 600.0;
        attribute permittedApertureDrift: Length_mm = 2.0;
    }

    action def ReleaseAndCloseSpeculum {
        in item lockCommand: LockCommand;
        out item bladeMotion: BladeMotion;
        out item deviceStatus: DeviceStatus;

        attribute maximumClosingTime: Time_s = 2.0;
        attribute controlledClosure: Boolean = true;
    }

    action def WithdrawClosedSpeculum {
        in item deviceStatus: DeviceStatus;
        out item sterileBarrierStatus: SterileBarrierStatus;

        attribute withdrawalRequiresClosedBlades: Boolean = true;
    }

    action def ExposeExaminationField {
        in item manualInput: ManualInput;
        in item openingCommand: OpeningCommand;
        in item lockCommand: LockCommand;
        out item visualAccess: VisualAccess;
        out item tissueContactLoad: TissueContactLoad;
        out item deviceStatus: DeviceStatus;

        first start;
        then insert: InsertClosedSpeculum;
        then open: OpenBladesToCreateAccess;
        then hold: HoldApertureForExamination;
        then release: ReleaseAndCloseSpeculum;
        then withdraw: WithdrawClosedSpeculum;
        then done;
    }

    state def SpeculumUseStateMachine {
        attribute apertureWidth: Length_mm;
        attribute lockEngaged: Boolean;
        attribute inserted: Boolean;
        attribute sterile: Boolean;

        entry action initialize {
            apertureWidth = 0.0;
            lockEngaged = false;
            inserted = false;
            sterile = true;
        }

        state SterilePackaged;
        state ReadyClosed;
        state InsertedClosed;
        state Opening;
        state LockedOpen;
        state ExaminationAccessProvided;
        state Releasing;
        state Closing;
        state WithdrawnClosed;
        state Discarded;

        transition initial then SterilePackaged;

        transition unpack
            first SterilePackaged
            accept Unpack
            then ReadyClosed;

        transition insertClosed
            first ReadyClosed
            accept Insert
            then InsertedClosed;

        transition beginOpening
            first InsertedClosed
            accept ApplyOpeningForce
            then Opening;

        transition engageLock
            first Opening
            accept LockAtRequestedAperture
            then LockedOpen;

        transition provideAccess
            first LockedOpen
            accept ConfirmVisualField
            then ExaminationAccessProvided;

        transition startRelease
            first ExaminationAccessProvided
            accept ReleaseRatchet
            then Releasing;

        transition closeBlades
            first Releasing
            accept ControlledClose
            then Closing;

        transition confirmClosed
            first Closing
            accept ClosedConfirmed
            then WithdrawnClosed;

        transition discard
            first WithdrawnClosed
            accept Dispose
            then Discarded;
    }

    part def SpeculumSystem {
        doc /* High-level primary function: the speculum gently separates and holds apart compliant tissue to create a stable visual and physical access path for clinical examination while limiting tissue load and permitting controlled release and withdrawal. */

        attribute deviceName: String = "Bivalve clinical speculum";
        attribute intendedUse: String = "High-level examination access device";
        attribute reusable: Boolean = false;
        attribute sterileAtPointOfUse: Boolean = true;
        attribute minimumUsefulAperture: Length_mm = 20.0;
        attribute maximumAperture: Length_mm = 46.0;
        attribute closedInsertionWidth: Length_mm = 28.0;
        attribute maximumTissueForce: Force_N = 30.0;
        attribute maximumPeakPressure: Pressure_kPa = 18.0;
        attribute nominalBladeLength: Length_mm = 110.0;
        attribute lockHoldDuration: Time_s = 600.0;

        port clinicianPort: ClinicianHandPort;
        port tissuePort: TissueInterfacePort;
        port visualPort: VisualFieldPort;
        port sterilityPort: SterilityPort;

        part handle: HandleAssembly;
        part upperBlade: UpperBlade;
        part lowerBlade: LowerBlade;
        part pivot: PivotJoint;
        part lock: RatchetLock;
        part light: LightModule;
        part package: SterilePackage;
        part patientInterface: PatientTissueInterface;

        perform primaryFunction: ExposeExaminationField;
        exhibit useStates: SpeculumUseStateMachine;

        connect clinicianPort to handle.clinicianInterface;
        connect handle.actuationOut to pivot.actuationIn;
        connect pivot.upperBladeOut to upperBlade.motionIn;
        connect pivot.lowerBladeOut to lowerBlade.motionIn;
        connect upperBlade.tissueContact to patientInterface.upperContactIn;
        connect lowerBlade.tissueContact to patientInterface.lowerContactIn;
        connect upperBlade.visualBoundary to visualPort;
        connect lowerBlade.visualBoundary to visualPort;
        connect patientInterface.visualFieldOut to visualPort;
        connect clinicianPort to lock.handRelease;
        connect lock.lockControl to pivot.actuationIn;
        connect light.lightOutput to visualPort;
        connect package.sterilityOut to sterilityPort;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The speculum shall create and maintain a stable examination field by separating tissue with two opposed blades while allowing the clinician to control opening, locking, release, and closure. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.minimumUsefulAperture >= 20.0 and
            speculum.maximumAperture >= speculum.minimumUsefulAperture and
            speculum.maximumTissueForce <= 30.0
        }
    }

    requirement def ClosedInsertionProfileRequirement {
        doc /* The speculum shall present a closed insertion profile small enough to support gentle placement before blade opening. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.closedInsertionWidth <= 30.0
        }
    }

    requirement def TissueLoadLimitRequirement {
        doc /* The speculum shall limit contact load at the tissue interface during opening and locked examination. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.maximumTissueForce <= 30.0 and
            speculum.maximumPeakPressure <= 18.0
        }
    }

    requirement def ApertureControlRequirement {
        doc /* The speculum shall provide controlled incremental blade opening and stable lock positions over the intended aperture range. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.maximumAperture <= 50.0 and
            speculum.minimumUsefulAperture >= 20.0 and
            speculum.lockHoldDuration >= 600.0
        }
    }

    requirement def ReleaseAndWithdrawalRequirement {
        doc /* The speculum shall allow deliberate release of the lock and controlled closure before withdrawal. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.lock.releaseTravel <= 8.0 and
            speculum.maximumAperture > 0.0
        }
    }

    requirement def IlluminationRequirement {
        doc /* If the integrated light is enabled, the speculum shall illuminate the examination field without excessive surface temperature. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.light.minimumIlluminance >= 400.0 and
            speculum.light.maximumSurfaceTemperature <= 41.0
        }
    }

    requirement def SterilityRequirement {
        doc /* The speculum shall be provided sterile at point of use and maintain sterile barrier integrity until opened. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.sterileAtPointOfUse == true and
            speculum.package.singleUseSterile == true
        }
    }

    requirement def OneHandOperationRequirement {
        doc /* The speculum shall allow a clinician to open and lock the blades using one hand while preserving visual access. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.handle.oneHandOperable == true and
            speculum.handle.maximumGripForce <= 75.0
        }
    }

    requirement def SmoothContactSurfaceRequirement {
        doc /* Blade surfaces and leading edges shall be smooth and rounded to reduce localized tissue loading. */

        subject speculum: SpeculumSystem;

        require constraint {
            speculum.upperBlade.leadingEdgeRadius >= 3.0 and
            speculum.lowerBlade.leadingEdgeRadius >= 3.0 and
            speculum.upperBlade.surfaceRoughnessRa <= 0.001 and
            speculum.lowerBlade.surfaceRoughnessRa <= 0.001
        }
    }

    part speculumSystem: SpeculumSystem;

    satisfy PrimaryFunctionRequirement by speculumSystem;
    satisfy ClosedInsertionProfileRequirement by speculumSystem;
    satisfy TissueLoadLimitRequirement by speculumSystem;
    satisfy ApertureControlRequirement by speculumSystem;
    satisfy ReleaseAndWithdrawalRequirement by speculumSystem;
    satisfy IlluminationRequirement by speculumSystem;
    satisfy SterilityRequirement by speculumSystem;
    satisfy OneHandOperationRequirement by speculumSystem;
    satisfy SmoothContactSurfaceRequirement by speculumSystem;
}
