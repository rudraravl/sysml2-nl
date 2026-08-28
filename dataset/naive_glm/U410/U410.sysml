package MedicalSyringeSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceAndTime::*;
    import ISQMechanics::*;

    // ---- Value Types ----
    value type VolumeCapacity :> Volume;
    value type InternalDiameter :> Length;
    value type PlungerForce :> Force;
    value type InternalPressure :> Pressure;
    value type FluidVolume :> Volume;
    value type FlowRate :> VolumeFlowRate;
    value type NeedleGauge :> Real;
    value type SterilityLevel :> String;
    value type AccuracyTolerance :> Real;

    item def MedicalFluid {
        attribute name : String;
        attribute viscosity : Real;
        attribute density : MassDensity;
        attribute isSterile : Boolean;
    }

    // ---- Port Definitions ----
    port def FluidPort {
        out item fluid : MedicalFluid[0..*];
        attribute pressure : InternalPressure;
    }

    port def MechanicalPort {
        in attribute appliedForce : PlungerForce;
        out attribute displacement : Length;
    }

    // ---- Barrel Chamber ----
    part def BarrelChamber {
        attribute maxCapacity : VolumeCapacity = 10.0 [mL];
        attribute internalDiameter : InternalDiameter = 8.0 [mm];
        attribute wallThickness : Length = 1.0 [mm];
        attribute materialStrength : Pressure = 5.0 [MPa];
        attribute currentVolume : FluidVolume = 0.0 [mL];
        attribute isSterile : Boolean = true;

        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port plungerInterface : MechanicalPort;

        action def HoldFluid {
            in fluid : MedicalFluid;
            in volume : FluidVolume;
            out storedFluid : MedicalFluid;
        }

        action def TransferFluid {
            in fluid : MedicalFluid;
            in direction : String;
            out transferredFluid : MedicalFluid;
        }
    }

    // ---- Plunger Assembly ----
    part def PlungerAssembly {
        attribute strokeLength : Length = 60.0 [mm];
        attribute sealDiameter : InternalDiameter = 8.0 [mm];
        attribute maxForce : PlungerForce = 50.0 [N];
        attribute currentPosition : Length = 0.0 [mm];
        attribute sealIntegrity : Boolean = true;

        port actuationPort : MechanicalPort;
        port barrelInterface : MechanicalPort;

        action def MovePlunger {
            in force : PlungerForce;
            in direction : String;
            out newPosition : Length;
        }

        action def CreateSeal {
            in pressure : InternalPressure;
            out sealEffective : Boolean;
        }
    }

    // ---- Needle Tip ----
    part def NeedleTip {
        attribute gauge : NeedleGauge = 21.0;
        attribute length : Length = 25.0 [mm];
        attribute innerDiameter : InternalDiameter = 0.5 [mm];
        attribute sharpness : Real = 0.95;
        attribute isSterile : Boolean = true;

        port needleInlet : FluidPort;
        port needleOutlet : FluidPort;

        action def ChannelFluid {
            in fluid : MedicalFluid;
            in flow : FlowRate;
            out channeledFluid : MedicalFluid;
        }

        action def Penetrate {
            in targetMaterial : String;
            out penetrationDepth : Length;
        }
    }

    // ---- Syringe System ----
    part def SyringeSystem {
        attribute systemAccuracy : AccuracyTolerance = 0.02;
        attribute maxOperatingPressure : InternalPressure = 300.0 [kPa];
        attribute maxOperatingForce : PlungerForce = 50.0 [N];
        attribute sterilityLevel : SterilityLevel = "sterile";
        attribute totalFluidPathSterile : Boolean = true;

        part barrel : BarrelChamber {
            redef port fluidInlet : FluidPort;
            redef port fluidOutlet : FluidPort;
            redef port plungerInterface : MechanicalPort;
        }

        part plunger : PlungerAssembly {
            redef port actuationPort : MechanicalPort;
            redef port barrelInterface : MechanicalPort;
        }

        part needle : NeedleTip {
            redef port needleInlet : FluidPort;
            redef port needleOutlet : FluidPort;
        }

        connection barrelToNeedle connect barrel.fluidOutlet to needle.needleInlet {
            attribute sealIntegrity : Boolean = true;
        }

        connection plungerToBarrel connect plunger.barrelInterface to barrel.plungerInterface {
            attribute couplingForce : PlungerForce;
        }

        flow through barrelToNeedle of MedicalFluid;
        flow through plungerToBarrel of MechanicalPort;

        // ---- State Machine ----
        state def SyringeLifecycle {
            entry action initializeSyringe {
                barrel.currentVolume := 0.0 [mL];
                plunger.currentPosition := 0.0 [mm];
            }

            state ready {
                entry action setReady {
                    barrel.currentVolume := 0.0 [mL];
                }
                accept PullPlunger
                    then drawing;
            }

            state drawing {
                entry action startAspiration {
                    plunger.MovePlunger(plunger.actuationPort.appliedForce, "backward");
                    barrel.TransferFluid(barrel.fluidInlet.fluid, "in");
                }
                do action aspirateFluid {
                    barrel.currentVolume := barrel.currentVolume + (plunger.currentPosition * barrel.internalDiameter * barrel.internalDiameter * 3.14159 / 4.0);
                }
                accept TargetVolumeReached
                    then loaded;
            }

            state loaded {
                entry action confirmLoad {
                    barrel.currentVolume := barrel.maxCapacity;
                }
                accept PushPlunger
                    then injecting;
            }

            state injecting {
                entry action startInjection {
                    plunger.MovePlunger(plunger.actuationPort.appliedForce, "forward");
                    barrel.TransferFluid(barrel.fluidOutlet.fluid, "out");
                    needle.ChannelFluid(needle.needleInlet.fluid, 1.0 [mL/s]);
                }
                do action expelFluid {
                    barrel.currentVolume := barrel.currentVolume - (plunger.currentPosition * barrel.internalDiameter * barrel.internalDiameter * 3.14159 / 4.0);
                }
                accept FluidDepleted
                    then depleted;
            }

            state depleted {
                entry action setDepleted {
                    barrel.currentVolume := 0.0 [mL];
                    plunger.currentPosition := 0.0 [mm];
                }
                accept ResetSyringe
                    then ready;
            }
        }

        part behavior controller : SyringeLifecycle;

        // ---- Requirements ----
        requirement def AccuracyRequirement {
            attribute tolerance : AccuracyTolerance = 0.02;
            subject syringe : SyringeSystem;
            objective {
                doc "The syringe shall deliver fluid with an accuracy of at least 98% of the target volume."
            }
            require syringe.systemAccuracy <= tolerance;
        }

        requirement def StructuralIntegrityRequirement {
            attribute maxPressure : InternalPressure = 300.0 [kPa];
            attribute maxForce : PlungerForce = 50.0 [N];
            subject syringe : SyringeSystem;
            objective {
                doc "The syringe shall maintain structural integrity under operational pressures without leaking."
            }
            require syringe.maxOperatingPressure <= maxPressure;
            require syringe.maxOperatingForce <= maxForce;
            require barrel.wallThickness >= 1.0 [mm];
            require plunger.sealIntegrity == true;
        }

        requirement def SterilityRequirement {
            attribute requiredSterility : SterilityLevel = "sterile";
            subject syringe : SyringeSystem;
            objective {
                doc "The syringe shall maintain sterility throughout the entire fluid path."
            }
            require syringe.sterilityLevel == requiredSterility;
            require syringe.totalFluidPathSterile == true;
            require barrel.isSterile == true;
            require needle.isSterile == true;
        }

        requirement def FluidHandlingRequirement {
            attribute maxCapacity : VolumeCapacity = 10.0 [mL];
            subject syringe : SyringeSystem;
            objective {
                doc "The syringe shall handle medical fluids within defined capacity and property limits."
            }
            require barrel.maxCapacity == maxCapacity;
            require barrel.currentVolume <= barrel.maxCapacity;
        }

        requirement accuracyReq : AccuracyRequirement {
            subject = SyringeSystem;
        }

        requirement structuralReq : StructuralIntegrityRequirement {
            subject = SyringeSystem;
        }

        requirement sterilityReq : SterilityRequirement {
            subject = SyringeSystem;
        }

        requirement fluidHandlingReq : FluidHandlingRequirement {
            subject = SyringeSystem;
        }

        satisfaction satisfyAccuracy by syringe satisfies accuracyReq;
        satisfaction satisfyStructural by syringe satisfies structuralReq;
        satisfaction satisfySterility by syringe satisfies sterilityReq;
        satisfaction satisfyFluidHandling by syringe satisfies fluidHandlingReq;
    }
}
