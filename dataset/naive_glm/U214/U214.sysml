package TourniquetModel {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceOfVolume::*;
    import ISQSpaceOfMass::*;

    // ---------- Value Types with Units ----------
    value def PressureValue :> Real {
        unit mmHg;
    }
    value def ForceValue :> Real {
        unit N;
    }
    value def LengthValue :> Real {
        unit cm;
    }
    value def DurationValue :> Real {
        unit min;
    }
    value def TensionValue :> Real {
        unit N;
    }
    value def TorqueValue :> Real {
        unit 'N*m';
    }
    value def AngleValue :> Real {
        unit 'rad';
    }

    // ---------- Enumerations ----------
    enum def BleedingStatus {
        ACTIVE;
        REDUCED;
        OCCLUDED;
    }
    enum def ApplicationMode {
        ONE_HANDED;
        TWO_HANDED;
    }
    enum def DeploymentContext {
        SELF_APPLICATION;
        BYSTANDER_APPLICATION;
        FIRST_RESPONDER_APPLICATION;
    }

    // ---------- Item Types ----------
    item def Limb {
        attribute circumference : LengthValue;
        attribute arterialPressure : PressureValue;
    }
    item def BloodFlow {
        attribute status : BleedingStatus;
        attribute flowRate : VolumeValue;
    }

    // ---------- Port Definitions ----------
    port def MechanicalInterface {
        attribute transmittedForce : ForceValue;
    }
    port def StrapInterface {
        attribute appliedTension : TensionValue;
    }
    port def WindlassInterface {
        attribute appliedTorque : TorqueValue;
        attribute rotationAngle : AngleValue;
    }
    port def ClipInterface {
        attribute locked : Boolean;
    }
    port def PressurePadInterface {
        attribute distributedPressure : PressureValue;
    }

    // ---------- Requirements ----------
    requirement def StopArterialBleeding {
        doc /* The tourniquet shall stop arterial blood flow from a limb. */
        subject tourniquet : TourniquetAssembly;
        objective {
            tourniquet.appliedPressure >= 250 [mmHg] and
            tourniquet.appliedPressure <= 450 [mmHg] and
            tourniquet.bleedingStatus == BleedingStatus::OCCLUDED;
        }
    }

    requirement def RapidApplication {
        doc /* The tourniquet shall be applicable within a short time window. */
        subject tourniquet : TourniquetAssembly;
        objective {
            tourniquet.applicationTime <= 1.0 [min];
        }
    }

    requirement def OneHandedOperation {
        doc /* The tourniquet shall support one-handed self-application. */
        subject tourniquet : TourniquetAssembly;
        objective {
            tourniquet.supportedModes == ApplicationMode::ONE_HANDED;
        }
    }

    requirement def TensionRetention {
        doc /* The securing clip shall retain windlass tension without slipping. */
        subject clip : SecuringClip;
        objective {
            clip.slipForce >= 500 [N];
        }
    }

    requirement def SingleUseReliability {
        doc /* The tourniquet shall be a reliable single-use life-saving tool. */
        subject tourniquet : TourniquetAssembly;
        objective {
            tourniquet.isSingleUse == true and
            tourniquet.failureProbability <= 0.01;
        }
    }

    requirement def MinimizeTissueDamage {
        doc /* The applied pressure shall minimize unnecessary tissue damage. */
        subject tourniquet : TourniquetAssembly;
        objective {
            tourniquet.appliedPressure <= 450 [mmHg];
        }
    }

    // ---------- Part Definitions ----------
    part def PressurePad {
        attribute contactArea : Real = 25.0 [cm^2];
        port padInterface : PressurePadInterface;
        attribute distributedPressure : PressureValue;
    }

    part def Strap {
        attribute material : String = "High-strength nylon";
        attribute length : LengthValue = 95.0 [cm];
        attribute width : LengthValue = 3.8 [cm];
        attribute maxTension : TensionValue = 2000.0 [N];
        attribute currentTension : TensionValue;
        port strapEndA : StrapInterface;
        port strapEndB : StrapInterface;
        part pressurePad : PressurePad {
            redefines padInterface.distributedPressure = pressurePad.distributedPressure;
        }
    }

    part def Windlass {
        attribute material : String = "Anodized aluminum";
        attribute length : LengthValue = 11.5 [cm];
        attribute diameter : LengthValue = 1.2 [cm];
        attribute maxTorque : TorqueValue = 15.0 ['N*m'];
        attribute currentTorque : TorqueValue;
        attribute rotationAngle : AngleValue;
        port windlassInterface : WindlassInterface;
    }

    part def SecuringClip {
        attribute material : String = "Reinforced polymer";
        attribute slipForce : ForceValue = 600.0 [N];
        attribute locked : Boolean = false;
        port clipInterface : ClipInterface;
    }

    part def TimeMarker {
        attribute applicationTime : DurationValue;
        attribute recorded : Boolean = false;
    }

    part def TourniquetAssembly {
        attribute isSingleUse : Boolean = true;
        attribute failureProbability : Real = 0.005;
        attribute supportedModes : ApplicationMode = ApplicationMode::ONE_HANDED;
        attribute applicationTime : DurationValue;
        attribute appliedPressure : PressureValue;
        attribute bleedingStatus : BleedingStatus = BleedingStatus::ACTIVE;
        attribute deploymentContext : DeploymentContext;

        port externalMechanical : MechanicalInterface;

        part strap : Strap {
            redefines currentTension = strapEndA.appliedTension;
        }
        part windlass : Windlass {
            redefines currentTorque = windlassInterface.appliedTorque;
        }
        part securingClip : SecuringClip;
        part timeMarker : TimeMarker;

        // ---------- Connections ----------
        connection def StrapToWindlass {
            end strapEnd : StrapInterface;
            end windlassEnd : WindlassInterface;
        }
        connection def WindlassToClip {
            end windlassEnd : WindlassInterface;
            end clipEnd : ClipInterface;
        }
        connection def StrapToPressurePad {
            end strapEnd : StrapInterface;
            end padEnd : PressurePadInterface;
        }

        connection strapWindlassLink : StrapToWindlass
            connect strap.strapEndA to windlass.windlassInterface;
        connection windlassClipLink : WindlassToClip
            connect windlass.windlassInterface to securingClip.clipInterface;
        connection strapPadLink : StrapToPressurePad
            connect strap.strapEndB to strap.pressurePad.padInterface;

        // ---------- State Machine ----------
        state def TourniquetLifecycle {
            entry action {
                appliedPressure = 0.0 [mmHg];
                bleedingStatus = BleedingStatus::ACTIVE;
            }

            state stowed {
                entry action { /* Device is packed and ready */ }
                transition stowed_to_positioning
                    first stowed
                    accept ApplyRequest
                    then positioning;
            }

            state positioning {
                entry action {
                    deploymentContext = DeploymentContext::SELF_APPLICATION;
                    strap.currentTension = 5.0 [N];
                }
                do action PositionOnLimb {
                    /* Wrap strap around limb and secure initial fit */
                    strap.pressurePad.distributedPressure = 10.0 [mmHg];
                }
                transition positioning_to_tightening
                    first positioning
                    accept StrapSecured
                    then tightening;
            }

            state tightening {
                entry action {
                    windlass.rotationAngle = 0.0 ['rad'];
                }
                do action TightenWindlass {
                    /* Rotate windlass repeatedly to increase pressure */
                    while (bleedingStatus != BleedingStatus::OCCLUDED and
                           appliedPressure < 450.0 [mmHg]) {
                        windlass.rotationAngle += 1.57 ['rad'];
                        windlass.currentTorque += 0.5 ['N*m'];
                        strap.currentTension += 50.0 [N];
                        appliedPressure += 25.0 [mmHg];
                        strap.pressurePad.distributedPressure = appliedPressure;
                        if (appliedPressure >= 250.0 [mmHg]) {
                            bleedingStatus = BleedingStatus::REDUCED;
                        }
                        if (appliedPressure >= 350.0 [mmHg]) {
                            bleedingStatus = BleedingStatus::OCCLUDED;
                        }
                    }
                }
                transition tightening_to_monitoring
                    first tightening
                    accept BleedingCheckComplete
                    then monitoring;
            }

            state monitoring {
                entry action {
                    /* User checks for cessation of bleeding after each turn */
                }
                do action MonitorBleeding {
                    if (bleedingStatus == BleedingStatus::OCCLUDED) {
                        securingClip.locked = true;
                    }
                }
                transition monitoring_to_secured
                    first monitoring
                    accept BleedingStopped
                    then secured;
                transition monitoring_to_tightening
                    first monitoring
                    accept BleedingContinues
                    then tightening;
            }

            state secured {
                entry action {
                    securingClip.locked = true;
                    timeMarker.applicationTime = applicationTime;
                    timeMarker.recorded = true;
                }
                do action MaintainTension {
                    /* Securing clip holds windlass tension without slipping */
                    assert securingClip.locked == true;
                }
                transition secured_to_complete
                    first secured
                    accept ReleaseRequest
                    then complete;
            }

            state complete {
                entry action {
                    isSingleUse = true;
                }
            }
        }

        // ---------- Actions ----------
        action def ApplyTourniquet {
            in limb : Limb;
            out success : Boolean;
            attribute startTime : DurationValue;
            attribute endTime : DurationValue;

            perform action Position {
                /* Position device on limb */
            }
            perform action SecureStrap {
                /* Secure strap around limb */
            }
            perform action RotateWindlass {
                /* Rotate windlass to tighten */
            }
            perform action CheckBleeding {
                /* Check for cessation of bleeding */
            }
            perform action LockWindlass {
                /* Lock windlass in securing clip */
            }
            perform action NoteTime {
                /* Note time of application */
            }

            success = (bleedingStatus == BleedingStatus::OCCLUDED and
                       securingClip.locked == true);
        }

        // ---------- Requirement Satisfaction ----------
        satisfy StopArterialBleeding by tourniquet::self;
        satisfy RapidApplication by tourniquet::self;
        satisfy OneHandedOperation by tourniquet::self;
        satisfy SingleUseReliability by tourniquet::self;
        satisfy MinimizeTissueDamage by tourniquet::self;
        satisfy TensionRetention by securingClip;

        // ---------- Lifecycle Instance ----------
        part tourniquetLifecycle : TourniquetLifecycle;
    }

    // ---------- Top-level Instance ----------
    part emergencyTourniquet : TourniquetAssembly {
        redefines deploymentContext = DeploymentContext::FIRST_RESPONDER_APPLICATION;
        redefines supportedModes = ApplicationMode::ONE_HANDED;
    }
}
