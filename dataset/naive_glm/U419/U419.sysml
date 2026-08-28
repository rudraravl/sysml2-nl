package TractionSplintSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit N;
    unit mm;
    unit kg;
    unit Nm;
    unit deg;

    // ===== Value Types =====
    value type ForceValue :> Real {
        unit N;
    }
    value type LengthValue :> Real {
        unit mm;
    }
    value type MassValue :> Real {
        unit kg;
    }
    value type TorqueValue :> Real {
        unit Nm;
    }
    value type AngleValue :> Real {
        unit deg;
    }

    // ===== Item Definitions =====
    item def TensionSignal {
        attribute value : ForceValue;
    }
    item def AdjustmentCommand {
        attribute targetLength : LengthValue;
        attribute targetForce : ForceValue;
    }
    item def DeployCommand;
    item def ReleaseCommand;
    item def SecureStrapCommand;
    item def TransportCompleteSignal;

    // ===== Port Definitions =====
    port def MechanicalInterface {
        inout transmittedForce : ForceValue;
    }
    port def TensionOutput {
        out tensionReading : TensionSignal;
    }
    port def OperatorControl {
        in command : AdjustmentCommand;
    }

    // ===== Component Part Definitions =====
    part def ProximalAnchorPad {
        attribute contactArea : LengthValue = 120.0;
        attribute paddingThickness : LengthValue = 25.0;
        attribute isSecured : Boolean = false;
        port mechanicalInterface : MechanicalInterface;

        action applyCounterForce {
            in force : ForceValue;
        }
        action secureToGroin;
        action release;
    }

    part def DistalAnkleHitch {
        attribute strapWidth : LengthValue = 50.0;
        attribute maxCircumference : LengthValue = 400.0;
        attribute isSecured : Boolean = false;
        port mechanicalInterface : MechanicalInterface;

        action secureToAnkle;
        action transmitTraction {
            in force : ForceValue;
        }
        action release;
    }

    part def TelescopicFrame {
        attribute minLength : LengthValue = 600.0;
        attribute maxLength : LengthValue = 1100.0;
        attribute currentLength : LengthValue = 800.0;
        attribute material : String = "aluminum";
        attribute isLocked : Boolean = false;
        port proximalEnd : MechanicalInterface;
        port distalEnd : MechanicalInterface;

        action extend {
            in delta : LengthValue;
        }
        action shorten {
            in delta : LengthValue;
        }
        action adjustToLength {
            in targetLength : LengthValue;
        }
        action lock;
        action unlock;
    }

    part def RatchetWindlass {
        attribute maxTorque : TorqueValue = 5.0;
        attribute currentTorque : TorqueValue = 0.0;
        attribute ratchetAngle : AngleValue = 0.0;
        attribute gearRatio : Real = 10.0;
        attribute isEngaged : Boolean = false;
        port drivePort : MechanicalInterface;
        port outputPort : MechanicalInterface;

        action turn {
            in turns : Real;
        }
        action release {
            in turns : Real;
        }
        action applyTension {
            in targetForce : ForceValue;
        }
        action engage;
        action disengage;
    }

    part def TensionIndicator {
        attribute maxReading : ForceValue = 200.0;
        attribute currentReading : ForceValue = 0.0;
        attribute safeRangeMin : ForceValue = 20.0;
        attribute safeRangeMax : ForceValue = 150.0;
        attribute isWithinSafeRange : Boolean = true;
        port sensorPort : MechanicalInterface;
        port displayPort : TensionOutput;

        action update {
            in sensedForce : ForceValue;
        }
        action display;
        action checkSafeRange;
    }

    part def SupportStrap {
        attribute position : LengthValue;
        attribute width : LengthValue = 40.0;
        attribute isSecured : Boolean = false;
        port frameInterface : MechanicalInterface;

        action secure;
        action release;
    }

    // ===== Requirement Definitions =====
    requirement def ProvideControlledTraction {
        subject splint : TractionSplint;
        doc /* The splint shall apply a controlled, steady pulling force to realign the fractured femur. */;
        constraint { splint.appliedForce >= 0.0 and splint.appliedForce <= 200.0 }
    }

    requirement def BePortable {
        subject splint : TractionSplint;
        doc /* The splint shall be lightweight and portable for field deployment. */;
        constraint { splint.totalMass <= 2.5 }
    }

    requirement def BeAdjustable {
        subject splint : TractionSplint;
        doc /* The frame shall be telescopic and adjustable to fit patient leg length. */;
        constraint { splint.frame.currentLength >= 600.0 and splint.frame.currentLength <= 1100.0 }
    }

    requirement def IndicateTension {
        subject splint : TractionSplint;
        doc /* A built-in tension indicator shall display the applied force within a safe therapeutic range. */;
        constraint { splint.indicator.currentReading == splint.appliedForce }
    }

    requirement def ImmobilizeLimb {
        subject splint : TractionSplint;
        doc /* The splint shall immobilize the injured limb using four support straps along the frame. */;
        constraint { splint.straps->size() == 4 }
    }

    requirement def SafeTractionRange {
        subject splint : TractionSplint;
        doc /* The applied traction force shall remain within the safe therapeutic range during transport. */;
        constraint { splint.appliedForce >= splint.indicator.safeRangeMin and splint.appliedForce <= splint.indicator.safeRangeMax }
    }

    // ===== Main System =====
    part def TractionSplint {
        attribute totalMass : MassValue = 2.0;
        attribute appliedForce : ForceValue = 0.0;
        attribute isDeployed : Boolean = false;
        attribute patientLegLength : LengthValue = 800.0;

        part anchorPad : ProximalAnchorPad;
        part ankleHitch : DistalAnkleHitch;
        part frame : TelescopicFrame;
        part windlass : RatchetWindlass;
        part indicator : TensionIndicator;
        part straps[4] : SupportStrap;

        port patientInterface : MechanicalInterface;
        port operatorDisplay : TensionOutput;
        port operatorControl : OperatorControl;

        connection frameToAnchor connect frame.proximalEnd to anchorPad.mechanicalInterface;
        connection frameToWindlass connect frame.distalEnd to windlass.drivePort;
        connection windlassToHitch connect windlass.outputPort to ankleHitch.mechanicalInterface;
        connection windlassToIndicator connect windlass.outputPort to indicator.sensorPort;
        connection indicatorToDisplay connect indicator.displayPort to ~operatorDisplay;
        connection anchorToPatient connect anchorPad.mechanicalInterface to patientInterface;
        connection hitchToPatient connect ankleHitch.mechanicalInterface to patientInterface;

        action deploy {
            in legLength : LengthValue;
        }
        action positionOnPatient;
        action secureAnchors;
        action applyTractionForce {
            in targetForce : ForceValue;
        }
        action secureStraps;
        action monitorTension;
        action adjustTension {
            in deltaForce : ForceValue;
        }
        action releaseTension;

        // Operational State Machine
        state def OperationalState {
            state stowed {
                entry;
            }
            state adjusting {
                entry;
            }
            state positioning {
                entry;
            }
            state securingAnchors {
                entry;
            }
            state applyingTraction {
                entry;
            }
            state fullySecured {
                entry;
            }
            state monitoring {
                entry;
            }
            state released {
                entry;
            }

            transition first stowed then adjusting
                accept DeployCommand;

            transition first adjusting then positioning
                when frame.currentLength >= frame.minLength
                    and frame.currentLength <= frame.maxLength
                    and frame.isLocked == true;

            transition first positioning then securingAnchors
                accept DeployCommand;

            transition first securingAnchors then applyingTraction
                accept DeployCommand
                when anchorPad.isSecured == true and ankleHitch.isSecured == true;

            transition first applyingTraction then fullySecured
                when indicator.currentReading >= indicator.safeRangeMin
                    and indicator.currentReading <= indicator.safeRangeMax;

            transition first fullySecured then monitoring
                accept DeployCommand
                when straps->select(s | s.isSecured == false)->size() == 0;

            transition first monitoring then applyingTraction
                when indicator.currentReading < indicator.safeRangeMin;

            transition first monitoring then released
                accept ReleaseCommand;
        }

        exhibit OperationalState;

        // Requirement Satisfaction
        requirement tractionRequirement : ProvideControlledTraction {
            subject splint = self;
        }
        requirement portabilityRequirement : BePortable {
            subject splint = self;
        }
        requirement adjustabilityRequirement : BeAdjustable {
            subject splint = self;
        }
        requirement tensionIndicationRequirement : IndicateTension {
            subject splint = self;
        }
        requirement immobilizationRequirement : ImmobilizeLimb {
            subject splint = self;
        }
        requirement safeTractionRequirement : SafeTractionRange {
            subject splint = self;
        }
    }

    // ===== Patient Context =====
    part def Patient {
        attribute hasFemurFracture : Boolean = false;
        attribute painLevel : Integer = 0;
        part injuredLeg : Leg;
    }

    part def Leg {
        attribute length : LengthValue;
        attribute circumference : LengthValue;
        port splintInterface : MechanicalInterface;
    }

    // ===== Deployment Context =====
    part def FieldDeployment {
        attribute location : String = "field";
        attribute responderName : String;
        part patient : Patient;
        part splint : TractionSplint;

        connection splintToLeg connect splint.patientInterface to patient.injuredLeg.splintInterface;

        action performFieldTraction {
            action retrieveSplint;
            action measureLeg {
                in patient : Patient;
                out legLength : LengthValue;
            }
            action adjustSplint {
                in legLength : LengthValue;
            }
            action positionSplint;
            action secureAnchorPad;
            action secureAnkleHitch;
            action windTraction {
                in targetForce : ForceValue;
            }
            action verifyTension;
            action secureSupportStraps;
            action transportPatient;
            action releaseAtFacility;

            first retrieveSplint then measureLeg;
            first measureLeg then adjustSplint;
            first adjustSplint then positionSplint;
            first positionSplint then secureAnchorPad;
            first secureAnchorPad then secureAnkleHitch;
            first secureAnkleHitch then windTraction;
            first windTraction then verifyTension;
            first verifyTension then secureSupportStraps;
            first secureSupportStraps then transportPatient;
            first transportPatient then releaseAtFacility;
        }
    }
}
