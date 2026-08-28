package ProjectileLaunchingSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    attribute def Mass :> Real { unit 'kg'; }
    attribute def Length :> Real { unit 'm'; }
    attribute def Velocity :> Real { unit 'm/s'; }
    attribute def Force :> Real { unit 'N'; }
    attribute def Energy :> Real { unit 'J'; }
    attribute def Angle :> Real { unit 'rad'; }
    attribute def SpringConstant :> Real { unit 'N/m'; }
    attribute def Stress :> Real { unit 'Pa'; }

    // ---- Item types ----
    item def Projectile {
        attribute mass : Mass;
        attribute diameter : Length;
    }

    item def StandardBall :> Projectile {
        redefines mass = 0.05 [kg];
        redefines diameter = 0.025 [m];
    }

    item def HeavyBall :> Projectile {
        redefines mass = 0.10 [kg];
        redefines diameter = 0.035 [m];
    }

    // ---- Enumerations ----
    enum def OperationalState {
        ready = 0,
        loading = 1,
        drawn = 2,
        aimed = 3,
        launching = 4,
        fault = 5
    }

    enum def SafetyState {
        engaged = 0,
        disengaged = 1
    }

    enum def TriggerState {
        locked = 0,
        released = 1
    }

    // ---- Requirements ----
    requirement def StructuralIntegrity {
        doc { The frame must withstand maximum tension without yielding. }
        attribute maxStress : Stress = 2.7e8 [Pa];
        subject frame : Frame;
        requirement {
            subject frame;
            frame.peakStress <= maxStress
        }
    }

    requirement def EnergyStorage {
        doc { The elastic system must store sufficient energy for long-range launches. }
        attribute minStoredEnergy : Energy = 120.0 [J];
        subject elasticSystem : ElasticSystem;
        requirement {
            subject elasticSystem;
            elasticSystem.storedEnergy >= minStoredEnergy
        }
    }

    requirement def SafetyRequirement {
        doc { The system must prevent accidental firing when safety lock is engaged. }
        subject triggerMechanism : TriggerMechanism;
        requirement {
            subject triggerMechanism;
            triggerMechanism.safety == SafetyState::engaged implies triggerMechanism.trigger == TriggerState::locked
        }
    }

    requirement def LaunchPerformance {
        doc { The system must launch a standard projectile at a minimum velocity. }
        attribute minMuzzleVelocity : Velocity = 60.0 [m/s];
        subject system : ProjectileLauncher;
        requirement {
            subject system;
            system.muzzleVelocity >= minMuzzleVelocity
        }
    }

    // ---- Part definitions ----
    part def Frame {
        attribute material : String = "AluminumAlloy6061-T6";
        attribute yieldStrength : Stress = 2.7e8 [Pa];
        attribute peakStress : Stress;
        attribute height : Length = 0.6 [m];
        attribute width : Length = 0.5 [m];
        attribute mass : Mass = 1.2 [kg];

        port in tensionPort : Force;
        port out stressPort : Stress;

        action computeStress {
            in tension : Force;
            out stress : Stress;
        }
    }

    part def ElasticCord {
        attribute springConstant : SpringConstant = 500.0 [N/m];
        attribute naturalLength : Length = 0.3 [m];
        attribute maxStretch : Length = 0.4 [m];
        attribute currentStretch : Length;
        attribute storedEnergy : Energy;
        attribute tension : Force;

        port in stretchPort : Length;
        port out energyPort : Energy;
        port out tensionPort : Force;

        action updateState {
            in stretch : Length;
            out energy : Energy;
            out force : Force;
        }
    }

    part def ElasticSystem {
        part cordA : ElasticCord;
        part cordB : ElasticCord;
        attribute totalStoredEnergy : Energy;
        attribute totalTension : Force;

        port in drawPort : Length;
        port out energyPort : Energy;
        port out tensionPort : Force;

        action computeEnergy {
            in drawDistance : Length;
            out totalEnergy : Energy;
            out totalForce : Force;
        }
    }

    part def Pouch {
        attribute capacity : Mass = 0.15 [kg];
        attribute loaded : Boolean = false;
        item heldProjectile : Projectile[0..1];

        port in projectilePort : Projectile;
        port out loadedPort : Boolean;

        action loadProjectile {
            in p : Projectile;
            out success : Boolean;
        }

        action releaseProjectile {
            out p : Projectile;
        }
    }

    part def TriggerMechanism {
        attribute safety : SafetyState = SafetyState::engaged;
        attribute trigger : TriggerState = TriggerState::locked;

        port in safetyCommand : SafetyState;
        port in releaseCommand : Boolean;
        port out triggerStatePort : TriggerState;

        action engageSafety { out s : SafetyState; }
        action disengageSafety { out s : SafetyState; }
        action release { out t : TriggerState; }
        action reset { out t : TriggerState; out s : SafetyState; }
    }

    part def AimingAssembly {
        attribute elevationAngle : Angle = 0.0 [rad];
        attribute azimuthAngle : Angle = 0.0 [rad];

        port in elevationCommand : Angle;
        port in azimuthCommand : Angle;
        port out anglePort : Angle;

        action aim {
            in elev : Angle;
            in azim : Angle;
            out finalAngle : Angle;
        }
    }

    part def ProjectileLauncher {
        requirement structuralReq : StructuralIntegrity;
        requirement energyReq : EnergyStorage;
        requirement safetyReq : SafetyRequirement;
        requirement performanceReq : LaunchPerformance;

        attribute currentState : OperationalState = OperationalState::ready;
        attribute muzzleVelocity : Velocity;
        attribute drawDistance : Length = 0.35 [m];

        part frame : Frame {
            redefines peakStress = 1.8e8 [Pa];
        }

        part elasticSystem : ElasticSystem {
            part cordA : ElasticCord {
                redefines springConstant = 500.0 [N/m];
                redefines naturalLength = 0.3 [m];
            }
            part cordB : ElasticCord {
                redefines springConstant = 500.0 [N/m];
                redefines naturalLength = 0.3 [m];
            }
            redefines totalStoredEnergy = 122.5 [J];
            redefines totalTension = 350.0 [N];
        }

        part pouch : Pouch;

        part triggerMechanism : TriggerMechanism;

        part aimingAssembly : AimingAssembly;

        // Connections
        connection drawToCordA : Length connect elasticSystem.drawPort to elasticSystem.cordA.stretchPort;
        connection drawToCordB : Length connect elasticSystem.drawPort to elasticSystem.cordB.stretchPort;
        connection cordAEnergy : Energy connect elasticSystem.cordA.energyPort to elasticSystem.energyPort;
        connection cordBEnergy : Energy connect elasticSystem.cordB.energyPort to elasticSystem.energyPort;
        connection cordATension : Force connect elasticSystem.cordA.tensionPort to elasticSystem.tensionPort;
        connection cordBTension : Force connect elasticSystem.cordB.tensionPort to elasticSystem.tensionPort;
        connection tensionToFrame : Force connect elasticSystem.tensionPort to frame.tensionPort;
        connection frameStress : Stress connect frame.stressPort to frame.peakStress;
        connection triggerState : TriggerState connect triggerMechanism.triggerStatePort to pouch.loadedPort;
        connection aimAngle : Angle connect aimingAssembly.anglePort to aimingAssembly.elevationCommand;

        // State machine
        state def LauncherBehavior {
            entry action { currentState := OperationalState::ready; }

            state ready {
                entry action { currentState := OperationalState::ready; }
                transition to loading
                    when (pouch.loaded == true)
                    accept LoadCommand;
            }

            state loading {
                entry action { currentState := OperationalState::loading; }
                do action { pouch.loadProjectile(in p := StandardBall); }
                transition to drawn
                    when (pouch.loaded == true)
                    accept DrawCommand;
                transition to fault
                    when (pouch.loaded == false)
                    accept LoadFailure;
            }

            state drawn {
                entry action { currentState := OperationalState::drawn; }
                do action { elasticSystem.computeEnergy(in drawDistance := drawDistance); }
                transition to aimed
                    when (elasticSystem.totalStoredEnergy >= 120.0 [J])
                    accept AimCommand;
                transition to fault
                    when (elasticSystem.totalStoredEnergy < 120.0 [J])
                    accept InsufficientEnergy;
            }

            state aimed {
                entry action { currentState := OperationalState::aimed; }
                do action { aimingAssembly.aim(in elev := 0.5 [rad], in azim := 0.0 [rad]); }
                transition to launching
                    when (triggerMechanism.safety == SafetyState::disengaged)
                    accept ReleaseCommand;
                transition to fault
                    when (triggerMechanism.safety == SafetyState::engaged)
                    accept AccidentalFireAttempt;
            }

            state launching {
                entry action { currentState := OperationalState::launching; }
                do action {
                    triggerMechanism.release();
                    pouch.releaseProjectile();
                    muzzleVelocity := 65.0 [m/s];
                }
                transition to ready
                    when (pouch.loaded == false)
                    accept LaunchComplete;
            }

            state fault {
                entry action { currentState := OperationalState::fault; }
                transition to ready
                    accept ResetCommand
                    do action {
                        triggerMechanism.reset();
                        pouch.loaded := false;
                        elasticSystem.totalStoredEnergy := 0.0 [J];
                    }
            }
        }

        exhibit state behavior : LauncherBehavior;

        // Port for external commands
        port in commandPort : String;
        port out statusPort : OperationalState;
    }

    // ---- Top-level package items ----
    item def LoadCommand;
    item def DrawCommand;
    item def AimCommand;
    item def ReleaseCommand;
    item def ResetCommand;
    item def LaunchComplete;
    item def LoadFailure;
    item def InsufficientEnergy;
    item def AccidentalFireAttempt;

    // ---- Instantiation ----
    part launcherInstance : ProjectileLauncher {
        redefines muzzleVelocity = 65.0 [m/s];
    }
}
