package MarineChronometer {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQEnergy::*;
    import ISQThermodynamics::*;

    // ---- Value types ----
    value def Torque :> Real { unit = "N*m"; }
    value def AngularVelocity :> Real { unit = "rad/s"; }
    value def AngularPosition :> Real { unit = "deg"; }
    value def SpringConstant :> Real { unit = "N*m/rad"; }
    value def MomentOfInertia :> Real { unit = "kg*m^2"; }
    value def PowerReserveDuration :> Duration { unit = "h"; }
    value def DailyRateError :> Real { unit = "s/day"; }
    value def TemperatureRange {
        attribute min : Temperature;
        attribute max : Temperature;
    }

    // ---- Items ----
    item def MechanicalEnergy;
    item def TorqueImpulse;

    // ---- Port definitions ----
    port def EnergyPort {
        out energy : MechanicalEnergy;
        attribute torque : Torque;
    }

    port def DrivePort {
        out torque : Torque;
        in angularVelocity : AngularVelocity;
    }

    port def ImpulsePort {
        out impulse : TorqueImpulse;
        attribute magnitude : Torque;
    }

    port def TemperatureSensePort {
        in ambientTemperature : Temperature;
    }

    // ---- Requirements ----
    requirement def PowerReserveRequirement {
        doc "The chronometer shall maintain a power reserve of at least 48 hours when fully wound.";
        subject chronometer : MarineChronometerDevice;
        objective {
            chronometer.powerReserveDuration >= 48 [h]
        }
    }

    requirement def AccuracyRequirement {
        doc "The chronometer shall maintain a daily rate error not exceeding 2 seconds per day under nominal conditions.";
        subject chronometer : MarineChronometerDevice;
        objective {
            chronometer.dailyRateError <= 2 [s/day]
        }
    }

    requirement def TemperatureCompensationRequirement {
        doc "The chronometer shall compensate for ambient temperatures between -5 degC and 40 degC without loss of specified accuracy.";
        subject chronometer : MarineChronometerDevice;
        objective {
            chronometer.operatingTempRange.min >= -5 [degC] and
            chronometer.operatingTempRange.max <= 40 [degC]
        }
    }

    requirement def GimbalStabilityRequirement {
        doc "The chronometer shall remain level under ship roll and pitch of up to 30 degrees.";
        subject chronometer : MarineChronometerDevice;
        objective {
            chronometer.maxTiltAngle <= 30 [deg]
        }
    }

    requirement def TorqueEqualizationRequirement {
        doc "The fusee shall deliver substantially constant torque to the gear train across the full power reserve.";
        subject fusee : Fusee;
        objective {
            abs(fusee.outputTorque - fusee.nominalOutputTorque) <= 0.0005 [N*m]
        }
    }

    // ---- Part definitions ----

    part def Mainspring {
        attribute maxTorque : Torque = 0.05 [N*m];
        attribute minTorque : Torque = 0.005 [N*m];
        attribute currentTorque : Torque;
        attribute storedEnergy : MechanicalEnergy;
        attribute powerReserveDuration : PowerReserveDuration = 50 [h];
        port energyOut : EnergyPort;

        action def Wind {
            in targetEnergy : MechanicalEnergy;
            then StoreEnergy;
            action StoreEnergy;
        }

        action def Release {
            out releasedEnergy : MechanicalEnergy;
        }
    }

    part def Fusee {
        attribute nominalOutputTorque : Torque = 0.012 [N*m];
        attribute outputTorque : Torque;
        attribute chainEngagedRadius : Length;
        port energyIn : EnergyPort;
        port driveOut : DrivePort;

        action def EqualizeTorque {
            in inputTorque : Torque;
            out outputTorque : Torque;
            // As mainspring torque decreases, chain engages smaller fusee radius,
            // keeping output torque approximately constant.
        }
    }

    part def GearTrain {
        attribute gearRatioHour : Real = 1/12;
        attribute gearRatioMinute : Real = 1/720;
        attribute gearRatioSecond : Real = 1/43200;
        attribute efficiency : Real = 0.92;
        port driveIn : DrivePort;
        port driveOut : DrivePort;
        port dialDriveOut : DrivePort;

        action def TransmitMotion {
            in inputTorque : Torque;
            in inputAngularVelocity : AngularVelocity;
            out outputTorque : Torque;
            out outputAngularVelocity : AngularVelocity;
        }
    }

    part def Dial {
        attribute hourHandAngle : AngularPosition;
        attribute minuteHandAngle : AngularPosition;
        attribute secondHandAngle : AngularPosition;
        port driveIn : DrivePort;

        action def DisplayTime {
            in driveTorque : Torque;
            in driveAngularVelocity : AngularVelocity;
            then UpdateHands;
            action UpdateHands {
                out hourHandAngle : AngularPosition;
                out minuteHandAngle : AngularPosition;
                out secondHandAngle : AngularPosition;
            }
        }
    }

    part def BalanceWheel {
        attribute momentOfInertia : MomentOfInertia = 0.00002 [kg*m^2];
        attribute oscillationFrequency : Frequency = 5 [Hz];
        attribute amplitude : AngularPosition = 270 [deg];
        port impulseIn : ImpulsePort;

        action def Oscillate {
            out angularPosition : AngularPosition;
            out angularVelocity : AngularVelocity;
        }
    }

    part def Hairspring {
        attribute springConstant : SpringConstant = 0.002 [N*m/rad];
        attribute thermalCoefficient : Real = 0.00001 / "K";

        action def ProvideRestoringTorque {
            in angularPosition : AngularPosition;
            out restoringTorque : Torque;
        }
    }

    part def Oscillator {
        part balanceWheel : BalanceWheel;
        part hairspring : Hairspring;
        port impulseIn : ImpulsePort;

        connection balanceWheel.impulseIn to self.impulseIn;

        action def MaintainOscillation {
            then balanceWheel.Oscillate;
            then hairspring.ProvideRestoringTorque;
        }
    }

    part def DetentEscapement {
        attribute impulseMagnitude : Torque = 0.0008 [N*m];
        attribute impulsesPerSecond : Real = 10;
        port driveIn : DrivePort;
        port impulseOut : ImpulsePort;

        action def ReleaseImpulse {
            in driveTorque : Torque;
            out impulse : TorqueImpulse;
            // Releases one impulse per oscillation, giving the balance wheel a small push.
        }

        action def Tick {
            // Characteristic tick action produced with each impulse release.
        }
    }

    part def BimetallicCompensator {
        attribute compensationRange : TemperatureRange;
        attribute lowTempCompensation : Length;
        attribute highTempCompensation : Length;
        port tempIn : TemperatureSensePort;

        action def Compensate {
            in ambientTemperature : Temperature;
            out compensationAdjustment : Length;
            // Adjusts effective hairspring length to counteract thermal expansion effects.
        }
    }

    part def GimbalMount {
        attribute maxTilt : AngularPosition = 30 [deg];
        attribute rollAngle : AngularPosition;
        attribute pitchAngle : AngularPosition;
        attribute isolationEfficiency : Real = 0.85;

        action def Stabilize {
            in shipRoll : AngularPosition;
            in shipPitch : AngularPosition;
            out chronometerTilt : AngularPosition;
            // Two-axis pivot keeps the chronometer level despite ship motion.
        }
    }

    part def MarineChronometerDevice {
        attribute powerReserveDuration : PowerReserveDuration;
        attribute dailyRateError : DailyRateError;
        attribute operatingTempRange : TemperatureRange;
        attribute maxTiltAngle : AngularPosition;
        attribute started : Boolean = false;
        attribute wound : Boolean = false;

        part mainspring : Mainspring;
        part fusee : Fusee;
        part gearTrain : GearTrain;
        part dial : Dial;
        part oscillator : Oscillator;
        part detentEscapement : DetentEscapement;
        part compensator : BimetallicCompensator;
        part gimbalMount : GimbalMount;

        connection mainspring.energyOut to fusee.energyIn;
        connection fusee.driveOut to gearTrain.driveIn;
        connection gearTrain.driveOut to detentEscapement.driveIn;
        connection detentEscapement.impulseOut to oscillator.impulseIn;
        connection gearTrain.dialDriveOut to dial.driveIn;

        satisfy PowerReserveRequirement by self;
        satisfy AccuracyRequirement by self;
        satisfy TemperatureCompensationRequirement by self;
        satisfy GimbalStabilityRequirement by self;
        satisfy TorqueEqualizationRequirement by fusee;

        action def WindChronometer {
            then mainspring.Wind;
        }

        action def StartChronometer {
            out startedFlag : Boolean;
        }

        action def RunChronometer {
            then fusee.EqualizeTorque;
            then gearTrain.TransmitMotion;
            then detentEscapement.ReleaseImpulse;
            then oscillator.MaintainOscillation;
            then dial.DisplayTime;
            then detentEscapement.Tick;
        }

        state machinedef ChronometerStates {
            initial state Unwound;
            state Wound;
            state Running;
            state Depleted;

            transition Unwound to Wound when wound;
            transition Wound to Running when started;
            transition Running to Depleted when mainspring.powerReserveDuration == 0 [h];
            transition Depleted to Unwound when wound;
        }
    }
}
