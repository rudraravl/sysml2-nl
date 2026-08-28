package TourniquetSystem {
    import ScalarValues::*;
    import SI::*;
    import SI::N;
    import SI::Pa;
    import SI::m;
    import SI::s;
    import SI::rad;
    import SI::kg;

    value def Force :> Real { unit N; }
    value def Pressure :> Real { unit Pa; }
    value def Length :> Real { unit m; }
    value def Duration :> Real { unit s; }
    value def RotAngle :> Real { unit rad; }
    value def Mass :> Real { unit kg; }

    item def Blood;
    item def Limb;
    item def TensionFlow :> Force;
    item def PressureFlow :> Pressure;

    attribute def MaterialSpec {
        attribute material : String;
        attribute tensileStrength : Force;
        attribute workingLoad : Force;
    }

    enum def ClipShape { C_SHAPED; FORKED; }

    enum def LockState { UNLOCKED; LOCKED; }

    part def CompressionStrap {
        attribute width : Length = 0.05 [m];
        attribute length : Length = 1.0 [m];
        attribute thickness : Length = 0.002 [m];
        attribute mass : Mass = 0.08 [kg];
        attribute materialSpec : MaterialSpec {
            attribute material = "reinforced nylon webbing";
            attribute tensileStrength = 2500 [N];
            attribute workingLoad = 800 [N];
        }
        attribute currentTension : Force = 0 [N];
        attribute appliedPressure : Pressure = 0 [Pa];

        port in tensionIn : TensionFlow;
        port out pressureOut : PressureFlow;

        action def DistributePressure {
            in strapTension : Force;
            out limbPressure : Pressure;
        }

        perform DistributePressure {
            in strapTension = currentTension;
            out limbPressure = appliedPressure;
        }
    }

    part def WindlassMechanism {
        attribute rodLength : Length = 0.15 [m];
        attribute rodDiameter : Length = 0.012 [m];
        attribute handleLength : Length = 0.06 [m];
        attribute mechanicalAdvantage : Real = 8.0;
        attribute maxRotation : RotAngle = 4.712 [rad];
        attribute currentRotation : RotAngle = 0 [rad];
        attribute generatedTension : Force = 0 [N];

        port in appliedTorque : Force;
        port out tensionOut : TensionFlow;

        action def Tighten {
            in torque : Force;
            in rotation : RotAngle;
            out tension : Force;
        }

        perform Tighten {
            in torque = appliedTorque;
            in rotation = currentRotation;
            out tension = generatedTension;
        }
    }

    part def SecuringClip {
        attribute clipShape : ClipShape = ClipShape::C_SHAPED;
        attribute lockState : LockState = LockState::UNLOCKED;
        attribute retentionForce : Force = 1200 [N];
        attribute materialSpec : MaterialSpec {
            attribute material = "glass-filled polymer";
            attribute tensileStrength = 3000 [N];
            attribute workingLoad = 1500 [N];
        }

        port in windlassRotation : RotAngle;
        port out lockSignal : Boolean;

        action def EngageLock {
            in rotation : RotAngle;
            inout state : LockState;
        }

        perform EngageLock {
            in rotation = windlassRotation;
            inout state = lockState;
        }
    }

    part def TimeMarker {
        attribute tabColor : String = "white";
        attribute writableArea : Length = 0.03 [m];
        attribute applicationTime : Duration = 0 [s];
        attribute isMarked : Boolean = false;

        action def RecordTime {
            in time : Duration;
            out marked : Boolean;
        }

        perform RecordTime {
            in time = applicationTime;
            out marked = isMarked;
        }
    }

    part def Tourniquet {
        attribute deviceMass : Mass = 0.18 [kg];
        attribute targetLimbPressure : Pressure = 40000 [Pa];
        attribute maxOperatingTension : Force = 600 [N];

        part compressionStrap : CompressionStrap;
        part windlass : WindlassMechanism;
        part securingClip : SecuringClip;
        part timeMarker : TimeMarker;

        connection windlassTensionToStrap connect windlass.tensionOut to compressionStrap.tensionIn;
        connection strapPressureToLimb connect compressionStrap.pressureOut to limbPressurePort;
        connection windlassRotationToClip connect windlass.currentRotation to securingClip.windlassRotation;

        port out limbPressurePort : PressureFlow;

        attribute positionedOnLimb : Boolean = false;
        attribute windlassTurning : Boolean = false;
        attribute bleedingStopped : Boolean = false;
        attribute releasedByProfessional : Boolean = false;

        exhibit state TourniquetStates {
            state idle;
            state positioned;
            state tightening;
            state secured;
            state released;

            entry idle {
                compressionStrap.currentTension = 0 [N];
                compressionStrap.appliedPressure = 0 [Pa];
                windlass.currentRotation = 0 [rad];
                windlass.generatedTension = 0 [N];
                securingClip.lockState = LockState::UNLOCKED;
                positionedOnLimb = false;
                windlassTurning = false;
                bleedingStopped = false;
                releasedByProfessional = false;
            }

            transition idle to positioned
                when positionedOnLimb
                do { positionedOnLimb = true; }

            transition positioned to tightening
                when windlassTurning
                do {
                    windlassTurning = true;
                    windlass.currentRotation = windlass.currentRotation + 0.785 [rad];
                    windlass.generatedTension = windlass.appliedTorque * windlass.mechanicalAdvantage;
                    compressionStrap.currentTension = windlass.generatedTension;
                    compressionStrap.appliedPressure = compressionStrap.currentTension / compressionStrap.width;
                }

            transition tightening to secured
                when bleedingStopped
                do {
                    securingClip.lockState = LockState::LOCKED;
                    timeMarker.applicationTime = 0 [s];
                    timeMarker.isMarked = true;
                    bleedingStopped = true;
                }

            transition secured to released
                when releasedByProfessional
                do {
                    securingClip.lockState = LockState::UNLOCKED;
                    windlass.currentRotation = 0 [rad];
                    windlass.generatedTension = 0 [N];
                    compressionStrap.currentTension = 0 [N];
                    compressionStrap.appliedPressure = 0 [Pa];
                    releasedByProfessional = true;
                }
        }
    }

    requirement def OccludeArterialFlow {
        subject device : Tourniquet;
        objective {
            doc "The tourniquet shall apply sufficient pressure to occlude arterial blood flow in a limb."
            assert device.compressionStrap.appliedPressure >= device.targetLimbPressure
        }
    }

    requirement def MaintainCompression {
        subject device : Tourniquet;
        objective {
            doc "Once secured, the tourniquet shall maintain compression without unwinding."
            assert device.securingClip.lockState == LockState::LOCKED
            assert device.compressionStrap.currentTension >= 200 [N]
        }
    }

    requirement def SingleHandOperation {
        subject device : Tourniquet;
        objective {
            doc "The tourniquet shall be operable by a single person under field conditions."
            assert device.deviceMass <= 0.25 [kg]
        }
    }

    requirement def RecordApplicationTime {
        subject device : Tourniquet;
        objective {
            doc "The tourniquet shall provide a writable time marker to record application time."
            assert device.timeMarker.isMarked == true
        }
    }

    requirement def WithstandHighTension {
        subject device : Tourniquet;
        objective {
            doc "The compression strap shall withstand operating tension without tearing."
            assert device.compressionStrap.currentTension <= device.compressionStrap.materialSpec.tensileStrength
        }
    }

    satisfaction satisfyOccludeArterialFlow : OccludeArterialFlow by Tourniquet;
    satisfaction satisfyMaintainCompression : MaintainCompression by Tourniquet;
    satisfaction satisfySingleHandOperation : SingleHandOperation by Tourniquet;
    satisfaction satisfyRecordApplicationTime : RecordApplicationTime by Tourniquet;
    satisfaction satisfyWithstandHighTension : WithstandHighTension by Tourniquet;
}
