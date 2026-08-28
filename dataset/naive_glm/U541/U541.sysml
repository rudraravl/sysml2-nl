package HydraulicPlungerSystem {
    import SI::*;
    import ISQ::*;
    import ScalarValues::*;

    // ---- Item Definitions ----
    item def HydraulicFluid {
        attribute density : MassDensity;
        attribute bulkModulus : Pressure;
        attribute viscosity : DynamicViscosity;
    }

    // ---- Value Type Specializations ----
    attribute def PlungerForce :> Force;
    attribute def PlungerPressure :> Pressure;
    attribute def StrokeLength :> Length;
    attribute def PlungerArea :> Area;
    attribute def PlungerVelocity :> Velocity;
    attribute def FlowRate :> VolumeFlowRate;

    // ---- Port Definitions ----
    port def FluidPort {
        flow item fluid : HydraulicFluid;
        attribute pressure : PlungerPressure;
        attribute flowRate : FlowRate;
    }

    port def MechanicalPort {
        attribute force : PlungerForce;
        attribute displacement : StrokeLength;
        attribute velocity : PlungerVelocity;
    }

    // ---- Part Definitions ----
    part def PlungerHead {
        attribute surfaceArea : PlungerArea;
        attribute position : StrokeLength;
        attribute maxTravel : StrokeLength;
    }

    part def Shaft {
        attribute length : StrokeLength;
        attribute diameter : Length;
        attribute material : String;
    }

    part def Seal {
        attribute material : String;
        attribute maxOperatingPressure : PlungerPressure;
        attribute leakRate : FlowRate;
    }

    part def Cylinder {
        attribute boreDiameter : Length;
        attribute internalLength : StrokeLength;
        attribute maxStrokeLength : StrokeLength;
        attribute maxSafePressure : PlungerPressure;

        port fluidOutlet : FluidPort;
        port fluidInlet : FluidPort;

        constraint { maxStrokeLength <= internalLength }
    }

    part def PlungerAssembly {
        part head : PlungerHead {
            attribute surfaceArea = 0.001 [m^2];
            attribute maxTravel = 0.1 [m];
        }
        part shaft : Shaft {
            attribute length = 0.3 [m];
            attribute diameter = 0.02 [m];
            attribute material = "Stainless Steel";
        }
        part seal : Seal {
            attribute material = "Nitrile Rubber";
            attribute maxOperatingPressure = 20 [MPa];
            attribute leakRate = 0.0 [m^3/s];
        }

        port mechanicalInput : MechanicalPort;

        attribute appliedForce : PlungerForce;
        attribute currentPressure : PlungerPressure;
        attribute currentVelocity : PlungerVelocity;
        attribute currentPosition : StrokeLength;

        constraint PressureGeneration {
            currentPressure == appliedForce / head.surfaceArea
        }

        constraint StrokeLimit {
            head.position >= 0 [m] and head.position <= head.maxTravel
        }

        connection shaftToHead connect shaft to head;
        connection sealToHead connect seal to head;
    }

    part def PlungerSystem {
        part cylinder : Cylinder {
            attribute boreDiameter = 0.05 [m];
            attribute internalLength = 0.15 [m];
            attribute maxStrokeLength = 0.1 [m];
            attribute maxSafePressure = 25 [MPa];
        }
        part plunger : PlungerAssembly;

        port externalForceInput : MechanicalPort;
        port highPressureOutlet : FluidPort;
        port lowPressureInlet : FluidPort;

        attribute systemPressure : PlungerPressure;
        attribute cycleCount : Integer;
        attribute maxSystemPressure : PlungerPressure = cylinder.maxSafePressure;

        constraint SafeOperation {
            systemPressure < maxSystemPressure
        }

        connection applyForce connect externalForceInput to plunger.mechanicalInput;
        connection dischargeFluid connect cylinder.fluidOutlet to highPressureOutlet;
        connection intakeFluid connect lowPressureInlet to cylinder.fluidInlet;

        exhibit state machine PlungerCycle {
            state idle;
            state extending;
            state extended;
            state retracting;

            transition idle to extending
                when externalForceInput.force > 0 [N]
                do action { plunger.currentVelocity := 0.05 [m/s]; }

            transition extending to extended
                when plunger.head.position >= plunger.head.maxTravel
                do action { plunger.currentVelocity := 0 [m/s]; }

            transition extended to retracting
                when externalForceInput.force == 0 [N]
                do action { plunger.currentVelocity := -0.05 [m/s]; }

            transition retracting to idle
                when plunger.head.position <= 0 [m]
                do action {
                    plunger.currentVelocity := 0 [m/s];
                    plunger.head.position := 0 [m];
                    cycleCount := cycleCount + 1;
                }

            do action {
                plunger.head.position := plunger.head.position + plunger.currentVelocity * 0.001 [s];
                plunger.currentPosition := plunger.head.position;
                plunger.appliedForce := externalForceInput.force;
                plunger.currentPressure := plunger.appliedForce / plunger.head.surfaceArea;
                systemPressure := plunger.currentPressure;
            }
        }
    }

    // ---- Requirements ----
    requirement def PressureGenerationRequirement {
        subject plungerSystem : PlungerSystem;
        attribute requiredPressure : PlungerPressure;
        require constraint {
            plungerSystem.systemPressure == plungerSystem.plunger.appliedForce / plungerSystem.plunger.head.surfaceArea
        }
    }

    requirement def StrokeLimitRequirement {
        subject plungerSystem : PlungerSystem;
        require constraint {
            plungerSystem.plunger.head.position >= 0 [m] and
            plungerSystem.plunger.head.position <= plungerSystem.cylinder.maxStrokeLength
        }
    }

    requirement def MaxPressureSafetyRequirement {
        subject plungerSystem : PlungerSystem;
        attribute maxAllowablePressure : PlungerPressure = 25 [MPa];
        require constraint {
            plungerSystem.systemPressure < maxAllowablePressure
        }
    }

    requirement def SealIntegrityRequirement {
        subject plungerAssembly : PlungerAssembly;
        require constraint {
            plungerAssembly.currentPressure <= plungerAssembly.seal.maxOperatingPressure
        }
    }

    requirement def CycleCompletionRequirement {
        subject plungerSystem : PlungerSystem;
        require constraint {
            plungerSystem.cycleCount >= 1
        }
    }

    requirement def PositiveDisplacementRequirement {
        subject plungerSystem : PlungerSystem;
        require constraint {
            plungerSystem.plunger.head.surfaceArea > 0 [m^2] and
            plungerSystem.cylinder.maxStrokeLength > 0 [m]
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction satisfy PressureGenerationRequirement for plungerSystem : PlungerSystem;
    satisfaction satisfy StrokeLimitRequirement for plungerSystem : PlungerSystem;
    satisfaction satisfy MaxPressureSafetyRequirement for plungerSystem : PlungerSystem;
    satisfaction satisfy SealIntegrityRequirement for plungerAssembly : PlungerAssembly;
    satisfaction satisfy CycleCompletionRequirement for plungerSystem : PlungerSystem;
    satisfaction satisfy PositiveDisplacementRequirement for plungerSystem : PlungerSystem;
}
