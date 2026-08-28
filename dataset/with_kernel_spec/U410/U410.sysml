package MedicalSyringeSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def Volume :> Real;
    attribute def Force :> Real;
    attribute def Pressure :> Real;
    attribute def Length :> Real;
    attribute def DynamicViscosity :> Real;
    attribute def MassDensity :> Real;

    item def MedicalFluid {
        attribute viscosity : DynamicViscosity;
        attribute density : MassDensity;
    }

    port def FluidPort {
        inout item fluid : MedicalFluid;
    }

    port def MechanicalPort {
        inout force : Force;
        inout displacement : Length;
    }

    part def BarrelChamber {
        attribute maxCapacity : Volume;
        attribute internalDiameter : Length;
        port plungerInterface : MechanicalPort;
        port needleInterface : FluidPort;
    }

    part def PlungerAssembly {
        attribute sealDiameter : Length;
        attribute appliedForce : Force;
        port barrelInterface : MechanicalPort;
    }

    part def NeedleTip {
        attribute gauge : Real;
        attribute tipDiameter : Length;
        port barrelInterface : FluidPort;
        port externalInterface : FluidPort;
    }

    action def AspirateFluid {
        in fluid : MedicalFluid;
        out volume : Volume;
    }

    action def InjectFluid {
        in fluid : MedicalFluid;
        out volume : Volume;
    }

    attribute def PullSignal;
    attribute def TargetVolumeReached;
    attribute def PushSignal;
    attribute def EmptySignal;
    attribute def ResetSignal;

    state def SyringeStates {
        entry; then ready;
        state ready;
        transition ready_to_drawing
            first ready
            accept PullSignal
            then drawing;
        state drawing;
        transition drawing_to_loaded
            first drawing
            accept TargetVolumeReached
            then loaded;
        state loaded;
        transition loaded_to_injecting
            first loaded
            accept PushSignal
            then injecting;
        state injecting;
        transition injecting_to_depleted
            first injecting
            accept EmptySignal
            then depleted;
        state depleted;
        transition depleted_to_ready
            first depleted
            accept ResetSignal
            then ready;
    }

    part def Syringe {
        attribute targetVolume : Volume;
        attribute currentVolume : Volume;
        attribute deliveredVolume : Volume;
        attribute internalPressure : Pressure;
        attribute fluidPathSterility : Boolean;
        attribute maxOperatingPressure : Pressure;
        attribute maxAppliedForce : Force;
        attribute minAppliedForce : Force;
        attribute deliveryError : Volume;

        part barrel : BarrelChamber;
        part plunger : PlungerAssembly;
        part needle : NeedleTip;

        perform action aspirate : AspirateFluid;
        perform action inject : InjectFluid;

        connect plunger.barrelInterface to barrel.plungerInterface;
        connect barrel.needleInterface to needle.barrelInterface;

        exhibit state syringeStates : SyringeStates;
    }

    requirement def FluidDeliveryAccuracy {
        doc /* The syringe must deliver fluid with high accuracy */
        subject syringe : Syringe;
        attribute maxError : Volume;
    }

    requirement def StructuralIntegrity {
        doc /* The syringe must withstand operational pressures without leaking */
        subject syringe : Syringe;
        attribute maxPressure : Pressure;
    }

    requirement def SterilityMaintenance {
        doc /* The fluid path must remain sterile throughout operation */
        subject syringe : Syringe;
    }

    requirement def OperationalForceLimits {
        doc /* The syringe must operate within defined force limits */
        subject syringe : Syringe;
        attribute maxForce : Force;
        attribute minForce : Force;
    }

    part medicalSyringe : Syringe {
        attribute targetVolume = 5;
        attribute currentVolume = 0;
        attribute deliveredVolume = 0;
        attribute internalPressure = 0;
        attribute fluidPathSterility = true;
        attribute maxOperatingPressure = 300000;
        attribute maxAppliedForce = 50;
        attribute minAppliedForce = 2;
        attribute deliveryError = 0.1;

        part barrel : BarrelChamber {
            attribute maxCapacity = 10;
            attribute internalDiameter = 15;
        }
        part plunger : PlungerAssembly {
            attribute sealDiameter = 14.5;
            attribute appliedForce = 5;
        }
        part needle : NeedleTip {
            attribute gauge = 20;
            attribute tipDiameter = 0.5;
        }
    }

    requirement syringeSpecification {
        doc /* Overall syringe design requirements group */
        subject syringe : Syringe;
        requirement fluidAccuracy : FluidDeliveryAccuracy {
            subject = medicalSyringe;
            attribute maxError = 0.1;
        }
        requirement integrity : StructuralIntegrity {
            subject = medicalSyringe;
            attribute maxPressure = 300000;
        }
        requirement sterility : SterilityMaintenance {
            subject = medicalSyringe;
        }
        requirement forceLimits : OperationalForceLimits {
            subject = medicalSyringe;
            attribute maxForce = 50;
            attribute minForce = 2;
        }
    }
}
