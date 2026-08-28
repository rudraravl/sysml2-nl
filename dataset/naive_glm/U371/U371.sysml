package SafetySyringeModel {

    // ---- Units ----
    unit mm {
        symbol "mm";
    }
    unit mm3 {
        symbol "mm^3";
    }
    unit mL {
        symbol "mL";
    }
    unit N {
        symbol "N";
    }
    unit Pa {
        symbol "Pa";
    }
    unit s {
        symbol "s";
    }

    // ---- Value types ----
    value type Length :> Real {
        unit mm;
    }
    value type Volume :> Real {
        unit mL;
    }
    value type VolumeFlow :> Real {
        unit mL/s;
    }
    value type Force :> Real {
        unit N;
    }
    value type Pressure :> Real {
        unit Pa;
    }
    value type Time :> Real {
        unit s;
    }

    // ---- Enumerations ----
    enum NeedleStatus {
        exposed;
        shielded;
        locked;
    }

    enum SyringeLifecycleState {
        sterileReady;
        primed;
        injecting;
        doseDelivered;
        safetyActivated;
        disposed;
    }

    enum ShieldState {
        retracted;
        extending;
        extended;
        locked;
    }

    // ---- Items ----
    item def Medication {
        attribute name : String;
        attribute concentration : Real; // mg/mL
        attribute nominalDose : Volume = 1.0 [mL];
    }

    // ---- Ports ----
    port def FluidPort {
        attribute pressure : Pressure;
        in out medication : Medication;
    }

    port def MechanicalActuationPort {
        attribute appliedForce : Force;
        attribute displacement : Length;
    }

    port def TriggerPort {
        attribute triggerActive : Boolean;
    }

    port def LockPort {
        attribute locked : Boolean;
    }

    // ---- Requirements ----
    requirement def DosePrecisionRequirement {
        subject syringe : SafetySyringe;
        objective {
            doc /* The syringe shall deliver a dose within +/-2% of the nominal 1 mL volume. */
        }
        constraint { syringe.deliveredDose >= 0.98 [mL] and syringe.deliveredDose <= 1.02 [mL] }
    }

    requirement def AutomaticSafetyRequirement {
        subject syringe : SafetySyringe;
        objective {
            doc /* Upon full plunger depression, the safety shield shall automatically extend and lock over the needle without user action. */
        }
        constraint {
            syringe.plunger.fullyDepressed == true implies
            syringe.shield.state == ShieldState::locked and
            syringe.needle.status == NeedleStatus::locked
        }
    }

    requirement def SingleUseRequirement {
        subject syringe : SafetySyringe;
        objective {
            doc /* After safety activation, the syringe shall be permanently unusable. */
        }
        constraint {
            syringe.lifecycleState == SyringeLifecycleState::safetyActivated implies
            syringe.plunger.locked == true and
            syringe.shield.locked == true
        }
    }

    requirement def SterilityRequirement {
        subject syringe : SafetySyringe;
        objective {
            doc /* The syringe shall be sterile and ready for use prior to priming. */
        }
        constraint { syringe.lifecycleState == SyringeLifecycleState::sterileReady implies syringe.sterile == true }
    }

    requirement def NeedlestickPreventionRequirement {
        subject syringe : SafetySyringe;
        objective {
            doc /* The sharp tip of the needle shall be fully covered after safety activation. */
        }
        constraint {
            syringe.needle.status == NeedleStatus::locked implies
            syringe.shield.coverageLength >= syringe.needle.length
        }
    }

    // ---- Component parts ----
    part def Barrel {
        attribute capacity : Volume = 1.0 [mL];
        attribute innerDiameter : Length = 8.0 [mm];
        attribute barrelLength : Length = 60.0 [mm];
        attribute containedVolume : Volume = 0.0 [mL];
        attribute containedMedication : Medication;

        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        action def Dispense :> Action {
            in requestedVolume : Volume;
            out dispensedVolume : Volume;
            // dispenses medication through fluidOut
        }

        compute availableVolume : Volume = containedVolume;
    }

    part def Plunger {
        attribute strokeLength : Length = 60.0 [mm];
        attribute currentDisplacement : Length = 0.0 [mm];
        attribute fullyDepressed : Boolean = false;
        attribute locked : Boolean = false;
        attribute maxActuationForce : Force = 10.0 [N];

        port actuation : MechanicalActuationPort;
        port triggerOut : TriggerPort;
        port lockIn : LockPort;

        action def Depress :> Action {
            in appliedForce : Force;
            out displacement : Length;
            // converts force into linear displacement
        }

        action def EngageTrigger :> Action {
            in displacement : Length;
            out triggerActive : Boolean;
            // when displacement reaches strokeLength, trigger becomes active
        }
    }

    part def Needle {
        attribute gauge : Real = 21;
        attribute length : Length = 25.0 [mm];
        attribute bevelAngle : Real = 12.0;
        attribute status : NeedleStatus = NeedleStatus::exposed;

        port fluidConnection : FluidPort;

        action def Inject :> Action {
            in medication : Medication;
            in flowRate : VolumeFlow;
            // delivers medication to patient tissue
        }
    }

    part def SafetyShield {
        attribute extendedLength : Length = 30.0 [mm];
        attribute coverageLength : Length = 0.0 [mm];
        attribute deployed : Boolean = false;
        attribute locked : Boolean = false;
        attribute state : ShieldState = ShieldState::retracted;

        port triggerIn : TriggerPort;
        port lockOut : LockPort;

        action def Extend :> Action {
            in triggerActive : Boolean;
            out coverageLength : Length;
            // passively extends over needle
        }

        action def Lock :> Action {
            in coverageLength : Length;
            out locked : Boolean;
            // permanently locks shield in place
        }
    }

    // ---- Top-level system ----
    part def SafetySyringe {
        attribute sterile : Boolean = true;
        attribute deliveredDose : Volume = 0.0 [mL];
        attribute lifecycleState : SyringeLifecycleState = SyringeLifecycleState::sterileReady;

        part barrel : Barrel;
        part plunger : Plunger;
        part needle : Needle;
        part shield : SafetyShield;

        // Connections
        connect plunger.actuation to barrel.fluidIn;
        connect barrel.fluidOut to needle.fluidConnection;
        connect plunger.triggerOut to shield.triggerIn;
        connect shield.lockOut to plunger.lockIn;

        // Behaviors
        action def AdministerDose :> Action {
            in medication : Medication;
            in actuationForce : Force;
            out deliveredDose : Volume;

            perform plunger.Depress {
                in appliedForce = actuationForce;
                out displacement = d : Length;
            }
            perform plunger.EngageTrigger {
                in displacement = d;
                out triggerActive = t : Boolean;
            }
            perform barrel.Dispense {
                in requestedVolume = medication.nominalDose;
                out dispensedVolume = v : Volume;
            }
            perform needle.Inject {
                in medication = medication;
                in flowRate = 0.5 [mL/s];
            }
            perform shield.Extend {
                in triggerActive = t;
                out coverageLength = c : Length;
            }
            perform shield.Lock {
                in coverageLength = c;
                out locked = l : Boolean;
            }
        }

        // State machine
        state def Lifecycle {
            entry; then sterileReady;

            state sterileReady {
                entry {
                    sterile = true;
                    needle.status = NeedleStatus::exposed;
                    shield.state = ShieldState::retracted;
                }
                accept PrimeSignal(medication : Medication) then primed;
            }

            state primed {
                entry {
                    barrel.containedMedication = medication;
                    barrel.containedVolume = medication.nominalDose;
                    sterile = false;
                }
                accept InjectStart(force : Force) then injecting;
            }

            state injecting {
                entry {
                    perform AdministerDose;
                }
                accept PlungerFullyDepressed then doseDelivered;
            }

            state doseDelivered {
                entry {
                    deliveredDose = barrel.containedVolume;
                    plunger.fullyDepressed = true;
                }
                then safetyActivated;
            }

            state safetyActivated {
                entry {
                    needle.status = NeedleStatus::shielded;
                    shield.deployed = true;
                    shield.state = ShieldState::extended;
                    shield.coverageLength = shield.extendedLength;
                    needle.status = NeedleStatus::locked;
                    shield.state = ShieldState::locked;
                    shield.locked = true;
                    plunger.locked = true;
                }
                accept DisposeSignal then disposed;
            }

            state disposed {
                entry {
                    lifecycleState = SyringeLifecycleState::disposed;
                }
            }
        }

        // Requirement satisfaction
        satisfy DosePrecisionRequirement;
        satisfy AutomaticSafetyRequirement;
        satisfy SingleUseRequirement;
        satisfy SterilityRequirement;
        satisfy NeedlestickPreventionRequirement;
    }

    // ---- Signals ----
    signal def PrimeSignal {
        attribute medication : Medication;
    }

    signal def InjectStart {
        attribute force : Force;
    }

    signal def PlungerFullyDepressed;

    signal def DisposeSignal;
}
