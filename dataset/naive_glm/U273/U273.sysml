package NeedleFreeJetInjector {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQForce::*;
    import ISQPressure::*;
    import ISQVolume::*;
    import ISQMass::*;
    import ISQVelocity::*;

    // ---- Value Types ----
    attribute def DoseVolume :> VolumeValue;
    attribute def InjectionPressure :> PressureValue;
    attribute def JetVelocity :> VelocityValue;
    attribute def PenetrationDepth :> LengthValue;
    attribute def ActuationForce :> ForceValue;
    attribute def ResponseTime :> TimeValue;
    attribute def OrificeDiameter :> LengthValue;
    attribute def GasChargePressure :> PressureValue;
    attribute def PistonStroke :> LengthValue;

    // ---- Item Types ----
    item def LiquidMedication {
        attribute doseVolume : DoseVolume;
        attribute viscosity : Real; // dynamic viscosity in mPa·s (simplified)
    }
    item def CompressedGas {
        attribute chargePressure : GasChargePressure;
        attribute gasType : String = "CO2";
    }
    item def HighPressureGas :> CompressedGas {
        attribute releasedPressure : InjectionPressure;
    }
    item def MedicationJet :> LiquidMedication {
        attribute velocity : JetVelocity;
        attribute orificeDiameter : OrificeDiameter;
    }

    // ---- Port Definitions ----
    port def GasFlowPort {
        out gasFlow : HighPressureGas;
    }
    port def GasSupplyPort {
        out gasSupply : CompressedGas;
    }
    port def MechanicalForcePort {
        out appliedForce : ActuationForce;
    }
    port def FluidFlowPort {
        out medicationFlow : LiquidMedication;
    }
    port def JetPort {
        out jet : MedicationJet;
    }
    port def SkinContactPort {
        in contactConfirmed : Boolean;
    }
    port def TriggerSignalPort {
        out triggerActivated : Boolean;
    }
    port def SafetySignalPort {
        out safetyVerified : Boolean;
    }

    // ---- Requirements ----
    requirement def DoseAccuracyRequirement {
        attribute targetDose : DoseVolume = 0.5 [mL];
        attribute tolerance : DoseVolume = 0.05 [mL];
        constraint { abs(deliveredDose - targetDose) <= tolerance }
        attribute deliveredDose : DoseVolume;
    }
    requirement def DeliveryDepthRequirement {
        attribute targetDepth : PenetrationDepth = 4.0 [mm];
        attribute depthTolerance : PenetrationDepth = 1.5 [mm];
        constraint { abs(actualDepth - targetDepth) <= depthTolerance }
        attribute actualDepth : PenetrationDepth;
    }
    requirement def JetVelocityRequirement {
        attribute minVelocity : JetVelocity = 100.0 [m/s];
        constraint { actualVelocity >= minVelocity }
        attribute actualVelocity : JetVelocity;
    }
    requirement def InjectionTimeRequirement {
        attribute maxInjectionTime : ResponseTime = 0.5 [s];
        constraint { actualInjectionTime <= maxInjectionTime }
        attribute actualInjectionTime : ResponseTime;
    }
    requirement def SafetyInterlockRequirement {
        constraint { injectionPermitted == (skinContactConfirmed == true) }
        attribute skinContactConfirmed : Boolean;
        attribute injectionPermitted : Boolean;
    }

    // ---- Part Definitions ----
    part def MedicationAmpoule {
        port fluidOut : FluidFlowPort;
        attribute capacity : DoseVolume = 0.5 [mL];
        attribute fillVolume : DoseVolume = 0.5 [mL];
        attribute sterile : Boolean = true;
        attribute isDisposable : Boolean = true;
        attribute remainingVolume : DoseVolume;
    }
    part def CompressedGasCartridge {
        port gasOut : GasSupplyPort;
        attribute chargePressure : GasChargePressure = 8.0 [MPa];
        attribute gasType : String = "CO2";
        attribute isDisposable : Boolean = true;
        attribute chargeRemaining : Real = 1.0;
    }
    part def TriggerMechanism {
        port triggerSignal : TriggerSignalPort;
        attribute actuationForce : ActuationForce = 15.0 [N];
        attribute isArmed : Boolean = false;
    }
    part def SafetyInterlock {
        port skinContact : SkinContactPort;
        port safetySignal : SafetySignalPort;
        attribute contactThreshold : ActuationForce = 5.0 [N];
        attribute contactForce : ActuationForce;
        attribute isVerified : Boolean = false;
    }
    part def PistonChamber {
        port gasIn : GasFlowPort;
        port forceOut : MechanicalForcePort;
        attribute chamberVolume : VolumeValue = 2.0 [mL];
        attribute boreDiameter : LengthValue = 8.0 [mm];
        attribute maxPressure : InjectionPressure = 8.0 [MPa];
    }
    part def Piston {
        port forceIn : MechanicalForcePort;
        port fluidPush : FluidFlowPort;
        attribute strokeLength : PistonStroke = 12.0 [mm];
        attribute sealIntegrity : Boolean = true;
        attribute position : LengthValue = 0.0 [mm];
    }
    part def MicroOrificeNozzle {
        port fluidIn : FluidFlowPort;
        port jetOut : JetPort;
        attribute orificeDiameter : OrificeDiameter = 0.15 [mm];
        attribute orificeLength : LengthValue = 0.5 [mm];
        attribute targetJetVelocity : JetVelocity = 150.0 [m/s];
    }

    // ---- State Machine for Injection Sequence ----
    state def InjectionSequence {
        entry; then Idle;
        state Idle {
            entry { /* device ready, waiting for trigger */ }
        }
        transition Idle_to_Triggered first Idle {
            when trigger.triggerSignal.triggerActivated == true
        } then Triggered;
        state Triggered {
            entry { /* trigger activated, check safety */ }
        }
        transition Triggered_to_SafetyCheck first Triggered {
            accept triggerActivation
        } then SafetyCheck;
        state SafetyCheck {
            entry { /* verify skin contact via interlock */ }
        }
        transition SafetyCheck_to_GasRelease first SafetyCheck {
            when safetyInterlock.safetySignal.safetyVerified == true
        } then GasRelease;
        transition SafetyCheck_to_Aborted first SafetyCheck {
            when safetyInterlock.safetySignal.safetyVerified == false
        } then Aborted;
        state GasRelease {
            entry { /* release compressed gas into piston chamber */ }
        }
        transition GasRelease_to_PistonDrive first GasRelease {
            accept gasReleased
        } then PistonDrive;
        state PistonDrive {
            entry { /* piston moves forward, pressurizing medication */ }
        }
        transition PistonDrive_to_JetFormation first PistonDrive {
            accept pistonAtFullStroke
        } then JetFormation;
        state JetFormation {
            entry { /* medication accelerated through orifice */ }
        }
        transition JetFormation_to_Injecting first JetFormation {
            accept jetFormed
        } then Injecting;
        state Injecting {
            entry { /* jet penetrates skin, delivers dose */ }
        }
        transition Injecting_to_Complete first Injecting {
            accept doseDelivered
        } then InjectionComplete;
        state InjectionComplete {
            entry { /* injection finished, device safe */ }
        }
        state Aborted {
            entry { /* safety not confirmed, injection aborted */ }
        }
        transition Aborted_to_Idle first Aborted {
            accept reset
        } then Idle;
        transition Complete_to_Idle first InjectionComplete {
            accept reset
        } then Idle;
    }

    // ---- Top-level System ----
    part def NeedleFreeJetInjector {
        // Requirements satisfaction
        satisfy DoseAccuracyRequirement {
            attribute deliveredDose = medicationAmpoule.fillVolume;
        }
        satisfy DeliveryDepthRequirement {
            attribute actualDepth = 4.0 [mm];
        }
        satisfy JetVelocityRequirement {
            attribute actualVelocity = microOrificeNozzle.targetJetVelocity;
        }
        satisfy InjectionTimeRequirement {
            attribute actualInjectionTime = 0.3 [s];
        }
        satisfy SafetyInterlockRequirement {
            attribute skinContactConfirmed = safetyInterlock.isVerified;
            attribute injectionPermitted = safetyInterlock.isVerified;
        }

        // Parts
        part medicationAmpoule : MedicationAmpoule {
            attribute remainingVolume = 0.5 [mL];
        }
        part compressedGasCartridge : CompressedGasCartridge;
        part trigger : TriggerMechanism;
        part safetyInterlock : SafetyInterlock;
        part pistonChamber : PistonChamber;
        part piston : Piston;
        part microOrificeNozzle : MicroOrificeNozzle;

        // Behavioral state machine
        exhibit behavior injectionProcess : InjectionSequence;

        // Connections
        connection triggerToSafety : TriggerSignalPort connect trigger.triggerSignal to safetyInterlock.safetySignal;
        connection gasCartridgeToChamber : GasSupplyPort connect compressedGasCartridge.gasOut to pistonChamber.gasIn;
        connection chamberToPiston : MechanicalForcePort connect pistonChamber.forceOut to piston.forceIn;
        connection pistonToAmpoule : FluidFlowPort connect piston.fluidPush to medicationAmpoule.fluidOut;
        connection ampouleToNozzle : FluidFlowPort connect medicationAmpoule.fluidOut to microOrificeNozzle.fluidIn;

        // Skin contact connection (external)
        connection skinContactLink : SkinContactPort connect safetyInterlock.skinContact to self.skinContactInterface;
        port skinContactInterface : SkinContactPort;
    }
}
