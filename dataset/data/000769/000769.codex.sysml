package SpeculumSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Force {
        :> scalar;
        unit = "N";
    }

    attribute def Torque {
        :> scalar;
        unit = "N*m";
    }

    attribute def Angle {
        :> scalar;
        unit = "deg";
    }

    attribute def Length {
        :> scalar;
        unit = "mm";
    }

    attribute def Pressure {
        :> scalar;
        unit = "kPa";
    }

    attribute def Temperature {
        :> scalar;
        unit = "degC";
    }

    attribute def LuminousFlux {
        :> scalar;
        unit = "lm";
    }

    attribute def Time {
        :> scalar;
        unit = "s";
    }

    item def MechanicalLoad {
        attribute spreadingForce : Force;
        attribute insertionForce : Force;
        attribute hingeTorque : Torque;
    }

    item def IlluminationEnergy {
        attribute luminousFlux : LuminousFlux;
        attribute sourceTemperature : Temperature;
    }

    item def AnatomicalAccess {
        attribute openingWidth : Length;
        attribute bladeAngle : Angle;
        attribute stabilized : Boolean;
    }

    item def SterilityStatus {
        attribute sterile : Boolean;
        attribute singleUse : Boolean;
        attribute contaminationDetected : Boolean;
    }

    item def UserCommand {
        attribute squeezeHandle : Boolean;
        attribute releaseHandle : Boolean;
        attribute engageLock : Boolean;
        attribute disengageLock : Boolean;
        attribute enableLight : Boolean;
    }

    port def HandInterfacePort {
        in command : UserCommand;
        out tactileLoad : MechanicalLoad;
    }

    port def TissueInterfacePort {
        out access : AnatomicalAccess;
        out appliedLoad : MechanicalLoad;
        in tissueResistance : MechanicalLoad;
    }

    port def LightOutputPort {
        out light : IlluminationEnergy;
    }

    port def SterilityPort {
        out status : SterilityStatus;
    }

    part def Speculum {
        attribute nominalClosedWidth : Length = 18 [mm];
        attribute maximumOpeningWidth : Length = 42 [mm];
        attribute safeSpreadingForceLimit : Force = 22 [N];
        attribute maximumBladeAngle : Angle = 38 [deg];
        attribute minimumBladeAngle : Angle = 0 [deg];
        attribute intendedUseTemperatureMin : Temperature = 15 [degC];
        attribute intendedUseTemperatureMax : Temperature = 35 [degC];

        port handInterface : HandInterfacePort;
        port tissueInterface : TissueInterfacePort;
        port sterilityInterface : SterilityPort;

        part upperBlade : Blade {
            attribute bladeRole = "upper";
            attribute length = 95 [mm];
            attribute distalWidth = 22 [mm];
            attribute surfaceFinishRoughness = 0.8 [um];
        }

        part lowerBlade : Blade {
            attribute bladeRole = "lower";
            attribute length = 100 [mm];
            attribute distalWidth = 24 [mm];
            attribute surfaceFinishRoughness = 0.8 [um];
        }

        part hinge : PivotHinge {
            attribute pinDiameter = 4 [mm];
            attribute maximumAllowedTorque = 1.2 [N*m];
        }

        part handleAssembly : HandleAssembly {
            attribute gripLength = 85 [mm];
            attribute ergonomicOffset = 12 [mm];
        }

        part lockingMechanism : LockingMechanism {
            attribute toothPitch = 1.5 [mm];
            attribute lockHoldingForce = 30 [N];
        }

        part illuminationModule : IlluminationModule {
            attribute nominalLuminousFlux = 18 [lm];
            attribute maximumSurfaceTemperature = 41 [degC];
        }

        part materialSet : BiocompatibleMaterialSet {
            attribute patientContactMaterial = "medical grade polymer or stainless steel";
            attribute latexFree = true;
            attribute corrosionResistant = true;
        }

        part sterilityBarrier : SterilityBarrier {
            attribute sterile = true;
            attribute singleUse = true;
            attribute packageIntegrityRequired = true;
        }

        connect handInterface to handleAssembly.handPort;
        connect handleAssembly.motionPort to hinge.actuationPort;
        connect hinge.upperBladePort to upperBlade.rootPort;
        connect hinge.lowerBladePort to lowerBlade.rootPort;
        connect upperBlade.tissuePort to tissueInterface;
        connect lowerBlade.tissuePort to tissueInterface;
        connect lockingMechanism.lockPort to hinge.lockPort;
        connect illuminationModule.lightPort to upperBlade.lightGuidePort;
        connect sterilityBarrier.statusPort to sterilityInterface;

        perform action deploySpeculum;
        exhibit state speculumOperationalState;
    }

    part def Blade {
        attribute bladeRole : String;
        attribute length : Length;
        attribute distalWidth : Length;
        attribute surfaceFinishRoughness : Real;
        attribute edgeRadius : Length = 2 [mm];
        attribute currentAngle : Angle;

        port rootPort : TissueInterfacePort;
        port tissuePort : TissueInterfacePort;
        port lightGuidePort : LightOutputPort;
    }

    part def PivotHinge {
        attribute pinDiameter : Length;
        attribute maximumAllowedTorque : Torque;
        attribute currentAngle : Angle;
        attribute rotationalFrictionTorque : Torque = 0.08 [N*m];

        port actuationPort : HandInterfacePort;
        port upperBladePort : TissueInterfacePort;
        port lowerBladePort : TissueInterfacePort;
        port lockPort : HandInterfacePort;
    }

    part def HandleAssembly {
        attribute gripLength : Length;
        attribute ergonomicOffset : Length;
        attribute inputForce : Force;
        attribute mechanicalAdvantage : Real = 2.8;

        port handPort : HandInterfacePort;
        port motionPort : HandInterfacePort;
    }

    part def LockingMechanism {
        attribute toothPitch : Length;
        attribute lockHoldingForce : Force;
        attribute engaged : Boolean = false;

        port lockPort : HandInterfacePort;
    }

    part def IlluminationModule {
        attribute nominalLuminousFlux : LuminousFlux;
        attribute maximumSurfaceTemperature : Temperature;
        attribute energized : Boolean = false;
        attribute batteryRuntime : Time = 900 [s];

        port lightPort : LightOutputPort;
    }

    part def BiocompatibleMaterialSet {
        attribute patientContactMaterial : String;
        attribute latexFree : Boolean;
        attribute corrosionResistant : Boolean;
        attribute smoothPatientContactSurfaces : Boolean = true;
    }

    part def SterilityBarrier {
        attribute sterile : Boolean;
        attribute singleUse : Boolean;
        attribute packageIntegrityRequired : Boolean;
        attribute contaminationDetected : Boolean = false;

        port statusPort : SterilityPort;
    }

    action def InsertClosedSpeculum {
        in closedWidth : Length;
        in insertionForce : Force;
        out positioned : Boolean;

        assert constraint {
            closedWidth <= 20 [mm] and insertionForce <= 12 [N]
        }

        positioned = true;
    }

    action def OpenBlades {
        in commandedHandleForce : Force;
        in tissueResistance : Force;
        out achievedOpeningWidth : Length;
        out appliedSpreadingForce : Force;

        appliedSpreadingForce = commandedHandleForce * 2.8;
        achievedOpeningWidth = 18 [mm] + commandedHandleForce * 0.9 [mm/N];

        assert constraint {
            appliedSpreadingForce <= 22 [N] and achievedOpeningWidth <= 42 [mm]
        }
    }

    action def LockOpening {
        in requestedOpeningWidth : Length;
        out locked : Boolean;

        assert constraint {
            requestedOpeningWidth >= 20 [mm] and requestedOpeningWidth <= 42 [mm]
        }

        locked = true;
    }

    action def IlluminateField {
        in enable : Boolean;
        out deliveredLight : LuminousFlux;
        out surfaceTemperature : Temperature;

        deliveredLight = 18 [lm];
        surfaceTemperature = 33 [degC];

        assert constraint {
            enable implies deliveredLight >= 10 [lm] and surfaceTemperature <= 41 [degC]
        }
    }

    action def ReleaseAndRemove {
        in lockDisengaged : Boolean;
        out closed : Boolean;
        out removed : Boolean;

        assert constraint {
            lockDisengaged == true
        }

        closed = true;
        removed = true;
    }

    action def deploySpeculum {
        first start;

        then insertClosed : InsertClosedSpeculum {
            in closedWidth = 18 [mm];
            in insertionForce = 8 [N];
        }

        then openForAccess : OpenBlades {
            in commandedHandleForce = 6 [N];
            in tissueResistance = 4 [N];
        }

        then stabilizeOpening : LockOpening {
            in requestedOpeningWidth = openForAccess.achievedOpeningWidth;
        }

        then provideIllumination : IlluminateField {
            in enable = true;
        }

        then completeAccess;

        flow openForAccess.achievedOpeningWidth to stabilizeOpening.requestedOpeningWidth;
    }

    state def SpeculumOperationalState {
        entry action {
            sterileReady = true;
        }

        state Packaged;
        state ReadyForUse;
        state InsertedClosed;
        state Opening;
        state LockedOpen;
        state Illuminating;
        state Released;
        state Removed;
        state Discarded;

        initial then Packaged;

        transition Packaged_to_Ready
            first Packaged
            accept UserCommand
            if sterilityVerified == true
            then ReadyForUse;

        transition Ready_to_Inserted
            first ReadyForUse
            accept UserCommand
            if command.squeezeHandle == false
            then InsertedClosed;

        transition Inserted_to_Opening
            first InsertedClosed
            accept UserCommand
            if command.squeezeHandle == true
            then Opening;

        transition Opening_to_Locked
            first Opening
            accept UserCommand
            if command.engageLock == true
            then LockedOpen;

        transition Locked_to_Illuminating
            first LockedOpen
            accept UserCommand
            if command.enableLight == true
            then Illuminating;

        transition Illuminating_to_Released
            first Illuminating
            accept UserCommand
            if command.disengageLock == true
            then Released;

        transition Released_to_Removed
            first Released
            accept UserCommand
            if command.releaseHandle == true
            then Removed;

        transition Removed_to_Discarded
            first Removed
            then Discarded;
    }

    requirement def PrimaryFunctionRequirement {
        subject device : Speculum;

        doc /* The system shall provide controlled, temporary separation of opposing blades to create and maintain an illuminated access pathway for visual examination of an internal anatomical cavity while limiting applied force and preserving sterile patient-contact surfaces. */

        require constraint {
            device.maximumOpeningWidth >= 40 [mm]
        }

        require constraint {
            device.safeSpreadingForceLimit <= 22 [N]
        }

        require constraint {
            device.illuminationModule.nominalLuminousFlux >= 10 [lm]
        }

        require constraint {
            device.sterilityBarrier.sterile == true
        }
    }

    requirement def PatientContactSafetyRequirement {
        subject device : Speculum;

        doc /* Patient-contact components shall be smooth, biocompatible, latex-free, and free of sharp exposed edges during insertion, opening, holding, release, and removal. */

        require constraint {
            device.upperBlade.edgeRadius >= 2 [mm] and
            device.lowerBlade.edgeRadius >= 2 [mm] and
            device.materialSet.latexFree == true and
            device.materialSet.smoothPatientContactSurfaces == true
        }
    }

    requirement def ControlledOpeningRequirement {
        subject device : Speculum;

        doc /* The handle, hinge, and locking mechanism shall convert user hand force into gradual blade separation and maintain the selected opening without continuous user force. */

        require constraint {
            device.handleAssembly.mechanicalAdvantage >= 2.0 and
            device.lockingMechanism.lockHoldingForce >= device.safeSpreadingForceLimit and
            device.hinge.maximumAllowedTorque >= 1.0 [N*m]
        }
    }

    requirement def ThermalIlluminationRequirement {
        subject device : Speculum;

        doc /* The illumination module shall provide useful light at the examination field without exceeding the allowable patient-contact surface temperature. */

        require constraint {
            device.illuminationModule.nominalLuminousFlux >= 10 [lm] and
            device.illuminationModule.maximumSurfaceTemperature <= 41 [degC]
        }
    }

    requirement def SingleUseSterilityRequirement {
        subject device : Speculum;

        doc /* A single-use sterile speculum shall maintain sterility before use and shall be discarded after removal. */

        require constraint {
            device.sterilityBarrier.sterile == true and
            device.sterilityBarrier.singleUse == true and
            device.sterilityBarrier.packageIntegrityRequired == true
        }
    }

    part speculumSystem : Speculum {
        attribute nominalClosedWidth = 18 [mm];
        attribute maximumOpeningWidth = 42 [mm];
        attribute safeSpreadingForceLimit = 22 [N];
        attribute maximumBladeAngle = 38 [deg];
    }

    satisfy PrimaryFunctionRequirement by speculumSystem;
    satisfy PatientContactSafetyRequirement by speculumSystem;
    satisfy ControlledOpeningRequirement by speculumSystem;
    satisfy ThermalIlluminationRequirement by speculumSystem;
    satisfy SingleUseSterilityRequirement by speculumSystem;

}