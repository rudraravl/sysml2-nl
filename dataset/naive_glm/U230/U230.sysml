package ObstetricalForcepsSystem {

    import ScalarValues::*;

    // =================================================
    // Units
    // =================================================

    unit N;
    unit Pa;
    unit mm;
    unit deg;
    unit g;
    unit Nmm;

    // =================================================
    // Value Types
    // =================================================

    value type ForceValue :> Real {
        unit : N;
    }

    value type PressureValue :> Real {
        unit : Pa;
    }

    value type LengthValue :> Real {
        unit : mm;
    }

    value type AngleValue :> Real {
        unit : deg;
    }

    value type MassValue :> Real {
        unit : g;
    }

    value type TorqueValue :> Real {
        unit : Nmm;
    }

    // =================================================
    // Item Definitions
    // =================================================

    item def FetalHead {
        attribute headDiameter : LengthValue = 95;
        attribute occiputPosition : AngleValue = 0;
        attribute descentStation : LengthValue = 0;
        attribute fetalMass : MassValue = 3400;
        attribute mispositioned : Boolean = false;
        attribute isDelivered : Boolean = false;
        attribute requiresAssistance : Boolean = true;
    }

    item def BirthCanal {
        attribute canalDiameter : LengthValue = 100;
        attribute maternalPushingSufficient : Boolean = false;
    }

    // =================================================
    // Port Definitions
    // =================================================

    port def ClinicianControlPort {
        out gripForce : ForceValue;
        out tractionForce : ForceValue;
        out rotationTorque : TorqueValue;
        out lockCommand : Boolean;
    }

    port def BladeContactPort {
        in contactForce : ForceValue;
        out measuredPressure : PressureValue;
        out appliedToHead : Boolean;
    }

    port def LockInterfacePort {
        in lockCommand : Boolean;
        out lockEngaged : Boolean;
    }

    // =================================================
    // Part Definitions – Forceps Components
    // =================================================

    part def ForcepsBlade {
        attribute bladeCurvatureRadius : LengthValue = 90;
        attribute maxSafePressure : PressureValue = 60000;
        attribute currentPressure : PressureValue = 0;
        attribute isAppliedToHead : Boolean = false;

        constraint safePressureConstraint:
            currentPressure <= maxSafePressure;

        port contactPort : BladeContactPort;

        action applyToHead {
            in target : FetalHead;
            then isAppliedToHead = true;
        }

        action removeFromHead {
            then isAppliedToHead = false;
        }

        action computePressure {
            in appliedForce : ForceValue;
            then currentPressure = appliedForce * 12000;
        }
    }

    part def ForcepsHandle {
        attribute handleLength : LengthValue = 120;
        attribute gripTexture : String = "knurled";
        attribute gripDiameter : LengthValue = 25;
    }

    part def LockMechanism {
        attribute isEngaged : Boolean = false;
        attribute lockCommand : Boolean = false;
        attribute maxLockingForce : ForceValue = 500;

        port lockCommandPort : LockInterfacePort;
        port leftLockPort : LockInterfacePort;
        port rightLockPort : LockInterfacePort;

        action engage {
            then isEngaged = true;
        }

        action disengage {
            then isEngaged = false;
        }

        state lockStateMachine {
            state disengaged {
                entry: isEngaged = false;
            }
            state engaged {
                entry: isEngaged = true;
            }
            transition from disengaged to engaged
                when lockCommand == true;
            transition from engaged to disengaged
                when lockCommand == false;
        }
    }

    part def ForcepsHalf {
        attribute side : String;
        part blade : ForcepsBlade;
        part handle : ForcepsHandle;

        port contactPort : BladeContactPort;
        port controlPort : ~ClinicianControlPort;
        port articulationPort : ~LockInterfacePort;
    }

    part def ObstetricalForceps {
        part leftHalf : ForcepsHalf {
            attribute side = "left";
        }
        part rightHalf : ForcepsHalf {
            attribute side = "right";
        }
        part centralLock : LockMechanism;

        port controlPort : ~ClinicianControlPort;

        connection controlDistLeft: controlPort = leftHalf.controlPort;
        connection controlDistRight: controlPort = rightHalf.controlPort;
        connection lockCmdLeft: centralLock.leftLockPort = leftHalf.articulationPort;
        connection lockCmdRight: centralLock.rightLockPort = rightHalf.articulationPort;
    }

    // =================================================
    // Clinician
    // =================================================

    part def Clinician {
        attribute experienceLevel : String = "obstetrician";
        attribute maxTractionForce : ForceValue = 150;
        attribute maxRotationTorque : TorqueValue = 50;
        attribute maxGripForce : ForceValue = 80;

        port controlPort : ClinicianControlPort;
        port leftMonitorPort : ~BladeContactPort;
        port rightMonitorPort : ~BladeContactPort;

        action assessFetus {
            in head : FetalHead;
            in canal : BirthCanal;
            out forcepsAppropriate : Boolean;
            then {
                if (head.requiresAssistance and head.headDiameter <= canal.canalDiameter) {
                    forcepsAppropriate = true;
                } else {
                    forcepsAppropriate = false;
                }
            }
        }

        action applyLeftBlade {
            in blade : ForcepsBlade;
            in head : FetalHead;
            then blade.isAppliedToHead = true;
        }

        action applyRightBlade {
            in blade : ForcepsBlade;
            in head : FetalHead;
            then blade.isAppliedToHead = true;
        }

        action engageLock {
            in lock : LockMechanism;
            then lock.isEngaged = true;
        }

        action disengageLock {
            in lock : LockMechanism;
            then lock.isEngaged = false;
        }

        action applyTraction {
            in force : ForceValue;
            out appliedForce : ForceValue;
            then appliedForce = force;
        }

        action rotateHead {
            in torque : TorqueValue;
            out appliedTorque : TorqueValue;
            then appliedTorque = torque;
        }

        action removeBlade {
            in blade : ForcepsBlade;
            then blade.isAppliedToHead = false;
        }
    }

    // =================================================
    // Action Definitions
    // =================================================

    action def MonitorBladePressure {
        in currentPressure : PressureValue;
        in maxSafePressure : PressureValue;
        out isSafe : Boolean;
        out alertTriggered : Boolean;

        action checkPressure {
            if (currentPressure <= maxSafePressure) {
                isSafe = true;
                alertTriggered = false;
            } else {
                isSafe = false;
                alertTriggered = true;
            }
        }
        then checkPressure;
    }

    // =================================================
    // Delivery Procedure
    // =================================================

    part def DeliveryProcedure {
        part clinician : Clinician;
        part forceps : ObstetricalForceps;
        item fetalHead : FetalHead;
        item birthCanal : BirthCanal;

        attribute assessmentComplete : Boolean = false;
        attribute forcepsAppropriate : Boolean = false;
        attribute leftBladeApplied : Boolean = false;
        attribute rightBladeApplied : Boolean = false;
        attribute lockEngaged : Boolean = false;
        attribute rotationNeeded : Boolean = false;
        attribute tractionApplied : Boolean = false;
        attribute headDelivered : Boolean = false;
        attribute lockDisengaged : Boolean = false;
        attribute leftBladeRemoved : Boolean = false;
        attribute rightBladeRemoved : Boolean = false;
        attribute procedureComplete : Boolean = false;
        attribute pressureIsSafe : Boolean = true;
        attribute alertTriggered : Boolean = false;

        connection controlLink: clinician.controlPort = forceps.controlPort;
        connection pressureLinkLeft: forceps.leftHalf.blade.contactPort = clinician.leftMonitorPort;
        connection pressureLinkRight: forceps.rightHalf.blade.contactPort = clinician.rightMonitorPort;

        action assessPhase {
            then clinician.assessFetus(fetalHead, birthCanal, forcepsAppropriate);
            then assessmentComplete = true;
        }

        action applicationPhase {
            then clinician.applyLeftBlade(forceps.leftHalf.blade, fetalHead);
            then leftBladeApplied = true;
            then clinician.applyRightBlade(forceps.rightHalf.blade, fetalHead);
            then rightBladeApplied = true;
        }

        action lockingPhase {
            then clinician.engageLock(forceps.centralLock);
            then lockEngaged = true;
        }

        action rotationTractionPhase {
            then {
                if (fetalHead.mispositioned) {
                    rotationNeeded = true;
                    then clinician.rotateHead(clinician.maxRotationTorque);
                }
            }
            then clinician.applyTraction(clinician.maxTractionForce);
            then forceps.leftHalf.blade.currentPressure = 45000;
            then forceps.rightHalf.blade.currentPressure = 42000;
            then tractionApplied = true;
            then {
                if (forceps.leftHalf.blade.currentPressure <= forceps.leftHalf.blade.maxSafePressure and
                    forceps.rightHalf.blade.currentPressure <= forceps.rightHalf.blade.maxSafePressure) {
                    pressureIsSafe = true;
                    alertTriggered = false;
                } else {
                    pressureIsSafe = false;
                    alertTriggered = true;
                }
            }
            then {
                headDelivered = true;
                fetalHead.isDelivered = true;
            }
        }

        action releasePhase {
            then clinician.disengageLock(forceps.centralLock);
            then lockDisengaged = true;
            then clinician.removeBlade(forceps.leftHalf.blade);
            then leftBladeRemoved = true;
            then clinician.removeBlade(forceps.rightHalf.blade);
            then rightBladeRemoved = true;
        }

        state procedureStateMachine {
            state AssessmentPhase {
                entry: assessmentComplete = false;
                do: assessPhase;
            }
            state ApplicationPhase {
                entry: leftBladeApplied = false;
                do: applicationPhase;
            }
            state LockingPhase {
                entry: lockEngaged = false;
                do: lockingPhase;
            }
            state RotationTractionPhase {
                entry: headDelivered = false;
                do: rotationTractionPhase;
            }
            state ReleasePhase {
                entry: leftBladeRemoved = false;
                do: releasePhase;
            }
            state Complete {
                entry: procedureComplete = true;
            }
            state Aborted {
                entry: procedureComplete = false;
            }

            transition from AssessmentPhase to ApplicationPhase
                when assessmentComplete == true and forcepsAppropriate == true;
            transition from AssessmentPhase to Aborted
                when assessmentComplete == true and forcepsAppropriate == false;
            transition from ApplicationPhase to LockingPhase
                when leftBladeApplied == true and rightBladeApplied == true;
            transition from LockingPhase to RotationTractionPhase
                when lockEngaged == true;
            transition from RotationTractionPhase to ReleasePhase
                when headDelivered == true and pressureIsSafe == true;
            transition from RotationTractionPhase to Aborted
                when pressureIsSafe == false;
            transition from ReleasePhase to Complete
                when leftBladeRemoved == true and rightBladeRemoved == true;
        }
    }

    // =================================================
    // Requirements
    // =================================================

    requirement def SafePressureLimit {
        doc: "The pressure applied by the forceps blades to the fetal head must remain within safe limits to prevent trauma.";
        subject forceps : ObstetricalForceps;
        requirement pressureLimit:
            forceps.leftHalf.blade.currentPressure <= forceps.leftHalf.blade.maxSafePressure and
            forceps.rightHalf.blade.currentPressure <= forceps.rightHalf.blade.maxSafePressure;
    }

    requirement def ControlledTraction {
        doc: "Traction force applied by the clinician must be controlled and synchronized with maternal efforts.";
        subject clinician : Clinician;
        requirement tractionLimit:
            clinician.maxTractionForce <= 150;
    }

    requirement def SecureLocking {
        doc: "The central lock must securely articulate the two forceps halves before traction is applied.";
        subject forceps : ObstetricalForceps;
        requirement lockBeforeTraction:
            forceps.centralLock.isEngaged == true;
    }

    requirement def IndividualBladeApplication {
        doc: "Each blade shall be applied individually to the sides of the fetal head, one at a time.";
        subject forceps : ObstetricalForceps;
        requirement sequentialApplication:
            forceps.leftHalf.blade.isAppliedToHead == true and
            forceps.rightHalf.blade.isAppliedToHead == true;
    }

    requirement def BladeCurvatureFit {
        doc: "Each blade shall be curved to fit around the fetal head safely.";
        subject forceps : ObstetricalForceps;
        requirement curvatureRadius:
            forceps.leftHalf.blade.bladeCurvatureRadius >= 80 and
            forceps.rightHalf.blade.bladeCurvatureRadius >= 80;
    }

    requirement def InterlockingDesign {
        doc: "The forceps shall consist of two interlocking components with a central lock mechanism.";
        subject forceps : ObstetricalForceps;
        requirement twoHalvesWithLock:
            forceps.leftHalf.side == "left" and
            forceps.rightHalf.side == "right";
    }

    requirement def PressureMonitoring {
        doc: "During the rotation and traction phase, the pressure applied by the blades shall be continuously monitored to ensure it remains within safe limits.";
        subject procedure : DeliveryProcedure;
        requirement continuousMonitoring:
            procedure.pressureIsSafe == true;
    }

    requirement def LockDisengagement {
        doc: "Once the head is delivered, the lock shall be disengaged and the blades removed individually.";
        subject procedure : DeliveryProcedure;
        requirement releaseSequence:
            procedure.lockDisengaged == true and
            procedure.leftBladeRemoved == true and
            procedure.rightBladeRemoved == true;
    }
}
