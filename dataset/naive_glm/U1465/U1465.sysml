package MechanicalPendulumClock {

    import ScalarValues::*;

    // ===== Units =====
    unit kg;
    unit m;
    unit s;
    unit rad;
    unit N;
    unit J;
    unit W;
    unit Hz;
    unit Nm;
    unit radPerS;

    // ===== Value Types =====
    value def MassValue :> Real { unit kg; }
    value def LengthValue :> Real { unit m; }
    value def AngleValue :> Real { unit rad; }
    value def AngularVelocityValue :> Real { unit radPerS; }
    value def TorqueValue :> Real { unit Nm; }
    value def EnergyValue :> Real { unit J; }
    value def TimeValue :> Real { unit s; }
    value def FrequencyValue :> Real { unit Hz; }
    value def ForceValue :> Real { unit N; }
    value def PowerValue :> Real { unit W; }

    // ===== Item Definitions =====
    item def StoredEnergy {
        attribute amount : EnergyValue;
    }
    item def AppliedTorque {
        attribute magnitude : TorqueValue;
    }
    item def GearRotationStep {
        attribute angle : AngleValue;
        attribute sourceGear : String;
    }
    item def PendulumImpulse {
        attribute force : ForceValue;
        attribute duration : TimeValue;
    }
    item def SwingSignal {
        attribute angle : AngleValue;
        attribute direction : String;
    }
    item def LockSignal {
        attribute isLocked : Boolean;
    }
    item def TimeDisplayUpdate {
        attribute hourAngle : AngleValue;
        attribute minuteAngle : AngleValue;
        attribute secondAngle : AngleValue;
    }

    // ===== Port Definitions =====
    port def TorqueOutPort {
        out item : AppliedTorque;
    }
    port def TorqueInPort {
        in item : AppliedTorque;
    }
    port def RotationOutPort {
        out item : GearRotationStep;
    }
    port def RotationInPort {
        in item : GearRotationStep;
    }
    port def ImpulseOutPort {
        out item : PendulumImpulse;
    }
    port def ImpulseInPort {
        in item : PendulumImpulse;
    }
    port def SwingOutPort {
        out item : SwingSignal;
    }
    port def SwingInPort {
        in item : SwingSignal;
    }
    port def LockOutPort {
        out item : LockSignal;
    }
    port def LockInPort {
        in item : LockSignal;
    }
    port def DisplayOutPort {
        out item : TimeDisplayUpdate;
    }
    port def DisplayInPort {
        in item : TimeDisplayUpdate;
    }

    // ===== Requirements =====
    requirement def TimekeepingAccuracyRequirement {
        doc /* The clock shall maintain time within plus or minus 2 minutes per day. */
        attribute maxDailyDrift : TimeValue = 120 [s];
        subject clock : MechanicalPendulumClock;
    }

    requirement def PowerSourceDurationRequirement {
        doc /* The power source shall sustain continuous operation for at least 24 hours before requiring rewind. */
        attribute minRunTime : TimeValue = 86400 [s];
        subject powerSource : PowerSource;
    }

    requirement def PendulumPeriodRequirement {
        doc /* The pendulum shall oscillate with a stable period determined primarily by its length. */
        attribute nominalPeriod : TimeValue = 1.0 [s];
        subject pendulum : Pendulum;
    }

    requirement def EscapementRegulationRequirement {
        doc /* The escapement shall release exactly one escape wheel tooth per pendulum swing. */
        attribute teethPerSwing : Integer = 1;
        subject escapement : EscapementMechanism;
    }

    requirement def DisplayResolutionRequirement {
        doc /* The time display shall continuously show hours, minutes, and seconds on a dial. */
        subject display : TimeDisplay;
    }

    // ===== Part: Power Source =====
    part def PowerSource {
        attribute storedEnergy : EnergyValue = 5000 [J];
        attribute maxEnergy : EnergyValue = 5000 [J];
        attribute outputTorque : TorqueValue = 0.05 [Nm];
        attribute isDepleted : Boolean = false;
        attribute runTimeRemaining : TimeValue = 86400 [s];

        port torqueOut : TorqueOutPort;

        action def ReleaseEnergy {
            in currentEnergy : EnergyValue;
            out releasedTorque : AppliedTorque;
        }

        action def Rewind {
            in targetEnergy : EnergyValue;
            out restoredEnergy : StoredEnergy;
        }

        exhibit state PowerStateBehavior {
            entry; then Powered;

            state Powered {
                entry { attribute isDepleted = false; }
                do ReleaseEnergy;
                transition Powered to Depleted
                    when storedEnergy <= 0 [J];
            }

            state Depleted {
                entry { attribute isDepleted = true; }
                transition Depleted to Powered
                    when storedEnergy > 0 [J];
            }
        }
    }

    // ===== Part: Gear Train =====
    part def GearTrain {
        attribute inputTorque : TorqueValue;
        attribute outputTorque : TorqueValue;
        attribute currentAngle : AngleValue = 0 [rad];
        attribute isLocked : Boolean = true;
        attribute totalRatio : Real = 7200.0;

        port torqueIn : TorqueInPort;
        port lockIn : LockInPort;
        port rotationToEscapement : RotationOutPort;
        port rotationToDisplay : RotationOutPort;

        part greatWheel {
            attribute teeth : Integer = 120;
            attribute ratio : Real = 120.0;
            attribute currentAngle : AngleValue = 0 [rad];
        }

        part centerWheel {
            attribute teeth : Integer = 80;
            attribute ratio : Real = 8.0;
            attribute currentAngle : AngleValue = 0 [rad];
        }

        part thirdWheel {
            attribute teeth : Integer = 60;
            attribute ratio : Real = 7.5;
            attribute currentAngle : AngleValue = 0 [rad];
        }

        part escapeWheel {
            attribute teeth : Integer = 30;
            attribute ratio : Real = 2.0;
            attribute currentAngle : AngleValue = 0 [rad];
        }

        action def StepGears {
            in input : AppliedTorque;
            in lock : LockSignal;
            out escapementRotation : GearRotationStep;
            out displayRotation : GearRotationStep;
        }

        action def ComputeRatios {
            in wheel1Teeth : Integer;
            in wheel2Teeth : Integer;
            out ratio : Real;
        }

        exhibit state GearTrainBehavior {
            entry; then Idle;

            state Idle {
                entry { attribute isLocked = true; }
                transition Idle to Stepping
                    when lockIn.item.isLocked == false;
            }

            state Stepping {
                entry { attribute isLocked = false; }
                do StepGears;
                transition Stepping to Idle
                    when lockIn.item.isLocked == true;
            }
        }
    }

    // ===== Part: Pendulum =====
    part def Pendulum {
        attribute length : LengthValue = 0.248 [m];
        attribute mass : MassValue = 1.0 [kg];
        attribute swingAngle : AngleValue = 0 [rad];
        attribute maxSwingAngle : AngleValue = 0.1 [rad];
        attribute period : TimeValue = 1.0 [s];
        attribute angularVelocity : AngularVelocityValue = 0 [radPerS];
        attribute gravitationalAccel : Real = 9.81;

        port impulseIn : ImpulseInPort;
        port swingOut : SwingOutPort;

        part rod {
            attribute length : LengthValue = 0.248 [m];
            attribute mass : MassValue = 0.2 [kg];
        }

        part bob {
            attribute mass : MassValue = 0.8 [kg];
            attribute diameter : LengthValue = 0.05 [m];
        }

        action def ComputePeriod {
            in len : LengthValue;
            in g : Real;
            out computedPeriod : TimeValue;
        }

        action def Swing {
            in impulse : PendulumImpulse;
            out swing : SwingSignal;
        }

        action def ApplyImpulse {
            in impulse : PendulumImpulse;
            in currentVelocity : AngularVelocityValue;
            out newVelocity : AngularVelocityValue;
        }

        exhibit state PendulumSwingBehavior {
            entry; then SwingingLeft;

            state SwingingLeft {
                entry { attribute angularVelocity = -0.3 [radPerS]; }
                do Swing;
                transition SwingingLeft to SwingingRight
                    when swingAngle <= -maxSwingAngle;
            }

            state SwingingRight {
                entry { attribute angularVelocity = 0.3 [radPerS]; }
                do Swing;
                transition SwingingRight to SwingingLeft
                    when swingAngle >= maxSwingAngle;
            }
        }
    }

    // ===== Part: Escapement Mechanism =====
    part def EscapementMechanism {
        attribute escapeWheelTeeth : Integer = 30;
        attribute teethPerSwing : Integer = 1;
        attribute stepAngle : AngleValue = 0.209 [rad];
        attribute isLocked : Boolean = true;
        attribute impulseForce : ForceValue = 0.02 [N];
        attribute impulseDuration : TimeValue = 0.01 [s];

        port rotationIn : RotationInPort;
        port swingIn : SwingInPort;
        port impulseOut : ImpulseOutPort;
        port lockOut : LockOutPort;

        part escapeWheel {
            attribute teeth : Integer = 30;
            attribute currentAngle : AngleValue = 0 [rad];
        }

        part palletFork {
            attribute lockAngle : AngleValue = 0.05 [rad];
            attribute currentAngle : AngleValue = 0 [rad];
        }

        part crutch {
            attribute length : LengthValue = 0.1 [m];
        }

        action def Escape {
            in gearRotation : GearRotationStep;
            in pendulumSwing : SwingSignal;
            out impulse : PendulumImpulse;
            out lock : LockSignal;
        }

        action def AdvanceEscapeWheel {
            in currentAngle : AngleValue;
            in step : AngleValue;
            out newAngle : AngleValue;
        }

        action def GiveImpulse {
            in swingDirection : String;
            out impulse : PendulumImpulse;
        }

        exhibit state EscapementBehavior {
            entry; then Locked;

            state Locked {
                entry { attribute isLocked = true; }
                do GiveImpulse;
                transition Locked to Unlocked
                    when swingIn.item.angle != 0 [rad];
            }

            state Unlocked {
                entry { attribute isLocked = false; }
                do AdvanceEscapeWheel;
                transition Unlocked to Locked
                    when escapeWheel.currentAngle >= stepAngle;
            }
        }
    }

    // ===== Part: Time Display =====
    part def TimeDisplay {
        attribute hourAngle : AngleValue = 0 [rad];
        attribute minuteAngle : AngleValue = 0 [rad];
        attribute secondAngle : AngleValue = 0 [rad];
        attribute currentTime : TimeValue = 0 [s];
        attribute hourRatio : Real = 1.0 / 12.0;
        attribute minuteRatio : Real = 1.0;
        attribute secondRatio : Real = 60.0;

        port displayIn : DisplayInPort;

        part hourHand {
            attribute angle : AngleValue = 0 [rad];
            attribute length : LengthValue = 0.05 [m];
        }

        part minuteHand {
            attribute angle : AngleValue = 0 [rad];
            attribute length : LengthValue = 0.07 [m];
        }

        part secondHand {
            attribute angle : AngleValue = 0 [rad];
            attribute length : LengthValue = 0.08 [m];
        }

        part dial {
            attribute markings : Integer = 12;
            attribute diameter : LengthValue = 0.2 [m];
        }

        action def UpdateDisplay {
            in rotation : GearRotationStep;
            out display : TimeDisplayUpdate;
        }

        action def AdvanceHands {
            in stepAngle : AngleValue;
            out hourUpdate : AngleValue;
            out minuteUpdate : AngleValue;
            out secondUpdate : AngleValue;
        }

        exhibit state DisplayBehavior {
            entry; then Updating;

            state Updating {
                entry { attribute currentTime = 0 [s]; }
                do UpdateDisplay;
                transition Updating to Updating
                    when displayIn.item.secondAngle != secondAngle;
            }
        }
    }

    // ===== System: Mechanical Pendulum Clock =====
    part def MechanicalPendulumClock {
        attribute manufacturer : String = "Heritage Clockworks";
        attribute model : String = "Regulator-1";
        attribute isRunning : Boolean = false;
        attribute serialNumber : String;

        part powerSource : PowerSource;
        part gearTrain : GearTrain;
        part pendulum : Pendulum;
        part escapement : EscapementMechanism;
        part timeDisplay : TimeDisplay;

        connection powerToGear connect powerSource.torqueOut to gearTrain.torqueIn;
        connection gearToEscapement connect gearTrain.rotationToEscapement to escapement.rotationIn;
        connection escapementLockToGear connect escapement.lockOut to gearTrain.lockIn;
        connection escapementToPendulum connect escapement.impulseOut to pendulum.impulseIn;
        connection pendulumToEscapement connect pendulum.swingOut to escapement.swingIn;
        connection gearToDisplay connect gearTrain.rotationToDisplay to timeDisplay.displayIn;

        action def StartClock {
            in initialEnergy : EnergyValue;
            out status : Boolean;
        }

        action def StopClock {
            out status : Boolean;
        }

        action def RewindClock {
            in addedEnergy : EnergyValue;
            out newEnergyLevel : EnergyValue;
        }

        exhibit state ClockOperationBehavior {
            entry; then Stopped;

            state Stopped {
                entry { attribute isRunning = false; }
                transition Stopped to Running
                    when powerSource.storedEnergy > 0 [J];
            }

            state Running {
                entry { attribute isRunning = true; }
                do StartClock;
                transition Running to Stopped
                    when powerSource.storedEnergy <= 0 [J];
            }

            transition Running to Running
                when pendulum.swingAngle != 0 [rad];
        }

        satisfy TimekeepingAccuracyRequirement by self;
        satisfy PowerSourceDurationRequirement by powerSource;
        satisfy PendulumPeriodRequirement by pendulum;
        satisfy EscapementRegulationRequirement by escapement;
        satisfy DisplayResolutionRequirement by timeDisplay;
    }
}
