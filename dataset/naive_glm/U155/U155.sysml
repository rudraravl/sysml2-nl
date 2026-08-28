package AutoinjectorModel {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Force :> Real { unit "N"; }
    value type Pressure :> Real { unit "Pa"; }
    value type Length :> Real { unit "mm"; }
    value type Volume :> Real { unit "mL"; }
    value type Duration :> Real { unit "s"; }
    value type FlowRate :> Real { unit "mL/s"; }
    value type Mass :> Real { unit "mg"; }

    // ===== Item Types =====
    item def Medication {
        attribute name : String;
        attribute dose : Mass;
        attribute concentration : Real;
    }

    item def Epinephrine :> Medication {
        restructure attribute name = "Epinephrine";
        restructure attribute dose = 0.3 [mg];
    }

    // ===== Port Definitions =====
    port def MechanicalForcePort {
        attribute appliedForce : Force;
    }

    port def FluidFlowPort {
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }

    port def SignalPort {
        attribute signalType : String;
    }

    port def UserContactPort {
        attribute contactForce : Force;
        attribute contactPosition : String;
    }

    // ===== Requirements =====
    requirement def AutoinjectorRequirement {
        doc "The autoinjector shall deliver a fixed dose of medication subcutaneously within 10 seconds."
        attribute maxInjectionTime : Duration = 10 [s];
        attribute requiredDose : Mass = 0.3 [mg];
    }

    requirement def SafetyCapRequirement {
        doc "The safety cap shall prevent activation until manually removed."
        attribute removalForce : Force = 20 [N];
    }

    requirement def ActivationRequirement {
        doc "The activation mechanism shall trigger only when a specific pressure is applied."
        attribute triggerPressure : Pressure = 25 [Pa];
    }

    requirement def NeedleDepthRequirement {
        doc "The needle shall deploy to a precise predetermined depth."
        attribute needleDepth : Length = 15 [mm];
    }

    requirement def NeedleShieldRequirement {
        doc "The needle shield shall lock permanently over the needle after injection."
    }

    requirement def StatusIndicatorRequirement {
        doc "The status indicator shall provide feedback at injection start and completion."
    }

    // ===== Parts =====

    part def SafetyCap {
        port removalPort : MechanicalForcePort;
        attribute isRemoved : Boolean = false;
        attribute removalForce : Force = 20 [N];

        exhibit state capState {
            entry;
            state Installed;
            state Removed;
            transition Installed to Removed
                when removalPort.appliedForce >= removalForce
                do { isRemoved = true; }
        }
    }

    part def ActivationMechanism {
        port triggerPort : MechanicalForcePort;
        port releasePort : MechanicalForcePort;
        attribute isArmed : Boolean = false;
        attribute isTriggered : Boolean = false;
        attribute triggerPressure : Pressure = 25 [Pa];
        attribute triggerThreshold : Force = 15 [N];

        exhibit state activationState {
            state Inert;
            state Armed;
            state Triggered;
            transition Inert to Armed
                when triggerPort.appliedForce >= triggerThreshold
                do { isArmed = true; }
            transition Armed to Triggered
                when triggerPort.appliedForce >= triggerThreshold
                do {
                    isTriggered = true;
                    releasePort.appliedForce = 50 [N];
                }
        }
    }

    part def SpringDrivenPlunger {
        port inputPort : MechanicalForcePort;
        port outputPort : MechanicalForcePort;
        attribute isCompressed : Boolean = true;
        attribute isReleased : Boolean = false;
        attribute springForce : Force = 80 [N];
        attribute strokeLength : Length = 40 [mm];

        exhibit state plungerState {
            state Compressed;
            state Released;
            state Extended;
            transition Compressed to Released
                when inputPort.appliedForce > 0 [N]
                do {
                    isReleased = true;
                    outputPort.appliedForce = springForce;
                }
            transition Released to Extended
                after 0.5 [s]
                do {
                    isCompressed = false;
                    outputPort.appliedForce = 0 [N];
                }
        }
    }

    part def NeedleAssembly {
        port drivePort : MechanicalForcePort;
        port fluidPort : FluidFlowPort;
        attribute isDeployed : Boolean = false;
        attribute needleDepth : Length = 15 [mm];
        attribute needleGauge : Integer = 22;

        exhibit state needleState {
            state Retracted;
            state Deployed;
            transition Retracted to Deployed
                when drivePort.appliedForce > 0 [N]
                do {
                    isDeployed = true;
                    fluidPort.pressure = 100000 [Pa];
                }
        }
    }

    part def MedicationCartridge {
        port plungerPort : MechanicalForcePort;
        port outletPort : FluidFlowPort;
        item containedMedication : Epinephrine;
        attribute initialVolume : Volume = 0.3 [mL];
        attribute remainingVolume : Volume = 0.3 [mL];
        attribute deliveryPressure : Pressure = 100000 [Pa];
        attribute flowRate : FlowRate = 0.03 [mL/s];
        attribute isEmpty : Boolean = false;

        exhibit state cartridgeState {
            state Full;
            state Dispensing;
            state Empty;
            transition Full to Dispensing
                when plungerPort.appliedForce > 0 [N]
                do {
                    outletPort.flowRate = flowRate;
                    outletPort.pressure = deliveryPressure;
                }
            transition Dispensing to Empty
                when remainingVolume <= 0 [mL]
                do {
                    isEmpty = true;
                    outletPort.flowRate = 0 [mL/s];
                    outletPort.pressure = 0 [Pa];
                }
        }

        action dispenseMedication {
            in force : Force;
            out deliveredVolume : Volume;
            while remainingVolume > 0 [mL] {
                remainingVolume := remainingVolume - flowRate * 0.1 [s];
                deliveredVolume := deliveredVolume + flowRate * 0.1 [s];
            }
        }
    }

    part def StatusIndicator {
        port triggerSignal : SignalPort;
        port completionSignal : SignalPort;
        attribute hasClicked : Boolean = false;
        attribute injectionComplete : Boolean = false;

        exhibit state indicatorState {
            state Idle;
            state Active;
            state Complete;
            transition Idle to Active
                when triggerSignal.signalType == "start"
                do {
                    hasClicked = true;
                }
            transition Active to Complete
                when completionSignal.signalType == "complete"
                do {
                    injectionComplete = true;
                }
        }
    }

    part def NeedleShield {
        port deploymentPort : MechanicalForcePort;
        attribute isExtended : Boolean = false;
        attribute isLocked : Boolean = false;
        attribute shieldLength : Length = 20 [mm];

        exhibit state shieldState {
            state Retracted;
            state Extended;
            state Locked;
            transition Retracted to Extended
                when deploymentPort.appliedForce == 0 [N]
                do {
                    isExtended = true;
                }
            transition Extended to Locked
                after 0.2 [s]
                do {
                    isLocked = true;
                }
        }
    }

    part def Autoinjector {
        satisfy AutoinjectorRequirement;
        satisfy SafetyCapRequirement;
        satisfy ActivationRequirement;
        satisfy NeedleDepthRequirement;
        satisfy NeedleShieldRequirement;
        satisfy StatusIndicatorRequirement;

        port userContactPort : UserContactPort;
        port capRemovalPort : MechanicalForcePort;

        part safetyCap : SafetyCap {
            port removalPort : MechanicalForcePort;
        }

        part activationMechanism : ActivationMechanism {
            port triggerPort : MechanicalForcePort;
            port releasePort : MechanicalForcePort;
        }

        part springPlunger : SpringDrivenPlunger {
            port inputPort : MechanicalForcePort;
            port outputPort : MechanicalForcePort;
        }

        part needleAssembly : NeedleAssembly {
            port drivePort : MechanicalForcePort;
            port fluidPort : FluidFlowPort;
        }

        part medicationCartridge : MedicationCartridge {
            port plungerPort : MechanicalForcePort;
            port outletPort : FluidFlowPort;
            item containedMedication : Epinephrine;
        }

        part statusIndicator : StatusIndicator {
            port triggerSignal : SignalPort;
            port completionSignal : SignalPort;
        }

        part needleShield : NeedleShield {
            port deploymentPort : MechanicalForcePort;
        }

        // Connections
        connection userToActivation : UserContactPort ~> MechanicalForcePort
            connect userContactPort to activationMechanism.triggerPort;

        connection capToActivation : MechanicalForcePort ~> MechanicalForcePort
            connect safetyCap.removalPort to activationMechanism.triggerPort;

        connection activationToPlunger : MechanicalForcePort ~> MechanicalForcePort
            connect activationMechanism.releasePort to springPlunger.inputPort;

        connection plungerToNeedle : MechanicalForcePort ~> MechanicalForcePort
            connect springPlunger.outputPort to needleAssembly.drivePort;

        connection plungerToCartridge : MechanicalForcePort ~> MechanicalForcePort
            connect springPlunger.outputPort to medicationCartridge.plungerPort;

        connection cartridgeToNeedle : FluidFlowPort ~> FluidFlowPort
            connect medicationCartridge.outletPort to needleAssembly.fluidPort;

        connection cartridgeToIndicator : FluidFlowPort ~> SignalPort
            connect medicationCartridge.outletPort to statusIndicator.triggerSignal {
                attribute signalType = "start";
            }

        connection cartridgeCompleteToIndicator : FluidFlowPort ~> SignalPort
            connect medicationCartridge.outletPort to statusIndicator.completionSignal {
                attribute signalType = "complete";
            }

        connection needleToShield : MechanicalForcePort ~> MechanicalForcePort
            connect needleAssembly.drivePort to needleShield.deploymentPort;

        // Overall device state machine
        exhibit state deviceLifecycle {
            state Stored;
            state Capped;
            state Armed;
            state Injecting;
            state Complete;
            state SafelyDisposed;

            transition Stored to Capped
                when safetyCap.isRemoved == false;

            transition Capped to Armed
                when safetyCap.isRemoved == true
                do { /* device is now armed */ }

            transition Armed to Injecting
                when activationMechanism.isTriggered == true
                do {
                    statusIndicator.triggerSignal.signalType = "start";
                }

            transition Injecting to Complete
                when medicationCartridge.isEmpty == true
                do {
                    statusIndicator.completionSignal.signalType = "complete";
                }

            transition Complete to SafelyDisposed
                when needleShield.isLocked == true;
        }

        // Injection action sequence
        action performInjection {
            in userForce : Force;
            out doseDelivered : Mass;

            // Step 1: Remove safety cap
            action removeCap {
                out capRemoved : Boolean;
            }

            // Step 2: Press against skin to activate
            action activateDevice {
                in force : Force;
                out triggered : Boolean;
            }

            // Step 3: Spring releases, needle deploys
            action deployNeedle {
                in trigger : Boolean;
                out deployed : Boolean;
            }

            // Step 4: Medication is delivered
            action deliverMedication {
                in needleDeployed : Boolean;
                out deliveredDose : Mass;
            }

            // Step 5: Shield locks over needle
            action lockShield {
                in injectionDone : Boolean;
                out shieldLocked : Boolean;
            }

            flow from removeCap.capRemoved to activateDevice.force;
            flow from activateDevice.triggered to deployNeedle.trigger;
            flow from deployNeedle.deployed to deliverMedication.needleDeployed;
            flow from deliverMedication.deliveredDose to lockShield.injectionDone;
        }
    }
}
