package Saqiya {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Torque :> Real { unit 'N*m'; }
    value def RotationalSpeed :> Real { unit 'rpm'; }
    value def LinearVelocity :> Real { unit 'm/s'; }
    value def LinearDisplacement :> Real { unit 'm'; }
    value def VolumetricFlowRate :> Real { unit 'm3/s'; }
    value def Pressure :> Real { unit 'Pa'; }
    value def Length :> Real { unit 'm'; }
    value def Force :> Real { unit 'N'; }
    value def Volume :> Real { unit 'm3'; }
    value def CrankAngle :> Real { unit 'deg'; }
    value def Duration :> Real { unit 's'; }

    // ===== Item Types =====
    item def Water;

    item def RotaryMotion {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
        attribute angle : CrankAngle;
    }

    item def LinearMotion {
        attribute position : LinearDisplacement;
        attribute velocity : LinearVelocity;
        attribute force : Force;
    }

    // ===== Port Definitions =====
    port def RotaryOut { out motion : RotaryMotion; }
    port def RotaryIn { in motion : RotaryMotion; }
    port def LinearOut { out motion : LinearMotion; }
    port def LinearIn { in motion : LinearMotion; }
    port def WaterOut { out item water : Water; }
    port def WaterIn { in item water : Water; }

    // ===== Part Definitions =====
    part def Animal {
        attribute species : String;
        attribute draftForce : Force;
        attribute walkingSpeed : RotationalSpeed;
        port powerOut : RotaryOut;

        action def WalkInCircle {
            out rotaryMotion : RotaryMotion;
        }
    }

    part def DriveWheel {
        attribute wheelRadius : Length;
        attribute gearRatio : Real;
        attribute outputSpeed : RotationalSpeed;
        attribute outputTorque : Torque;
        port driveInput : RotaryIn;
        port driveOutput : RotaryOut;
    }

    part def Crankshaft {
        attribute crankRadius : Length;
        attribute angularPosition : CrankAngle;
        port crankInput : RotaryIn;
        port crankOutput : LinearOut;
    }

    part def ConnectingRod {
        attribute rodLength : Length;
        port rodInput : LinearIn;
        port rodOutput : LinearOut;
    }

    part def Piston {
        attribute pistonDiameter : Length;
        attribute stroke : Length;
        attribute currentPosition : LinearDisplacement;
        port pistonInput : LinearIn;
    }

    part def Cylinder {
        attribute bore : Length;
        attribute chamberVolume : Volume;
        port waterIntake : WaterIn;
        port waterDischarge : WaterOut;
    }

    part def IntakeValve {
        attribute isOpen : Boolean;
        port fromRiver : WaterIn;
        port toCylinder : WaterOut;
    }

    part def DischargeValve {
        attribute isOpen : Boolean;
        port fromCylinder : WaterIn;
        port toAqueduct : WaterOut;
    }

    // ===== State Machine =====
    state def SaqiyaStates {
        state idle {
            entry { /* system at rest; animal not harnessed; valves closed */ }
        }
        state starting {
            entry { /* animal begins walking; wheel accelerates; crankshaft spins up */ }
        }
        state running {
            entry { /* steady-state pumping; piston reciprocates; water lifted continuously */ }
        }
        state stopped {
            entry { /* operator halts animal; wheel decelerates; pumping ceases */ }
        }
        state maintenance {
            entry { /* system inspected; valves and piston serviced; worn parts replaced */ }
        }

        transition idle to starting when animalStartsWalking;
        transition starting to running when steadyStateAchieved;
        transition running to stopped when operatorCommandsStop;
        transition stopped to maintenance when maintenanceScheduled;
        transition maintenance to idle when maintenanceComplete;
        transition stopped to idle when systemReset;
    }

    // ===== System =====
    part def SaqiyaSystem {
        port riverIntake : WaterIn;
        port aqueductOutlet : WaterOut;

        attribute nominalFlowRate : VolumetricFlowRate;
        attribute liftHeight : Length;

        part animal : Animal {
            attribute species := "Ox";
            attribute draftForce := 800 [N];
            attribute walkingSpeed := 4 [rpm];
        }

        part wheel : DriveWheel {
            attribute wheelRadius := 2.0 [m];
            attribute gearRatio := 3.0;
        }

        part crankshaft : Crankshaft {
            attribute crankRadius := 0.5 [m];
        }

        part connectingRod : ConnectingRod {
            attribute rodLength := 1.5 [m];
        }

        part piston : Piston {
            attribute pistonDiameter := 0.3 [m];
            attribute stroke := 1.0 [m];
        }

        part cylinder : Cylinder {
            attribute bore := 0.3 [m];
        }

        part intakeValve : IntakeValve {
            attribute isOpen := false;
        }

        part dischargeValve : DischargeValve {
            attribute isOpen := false;
        }

        // Power transmission chain
        connect animal.powerOut to wheel.driveInput;
        connect wheel.driveOutput to crankshaft.crankInput;
        connect crankshaft.crankOutput to connectingRod.rodInput;
        connect connectingRod.rodOutput to piston.pistonInput;

        // Water flow path: river -> intake valve -> cylinder -> discharge valve -> aqueduct
        connect riverIntake to intakeValve.fromRiver;
        connect intakeValve.toCylinder to cylinder.waterIntake;
        connect cylinder.waterDischarge to dischargeValve.fromCylinder;
        connect dischargeValve.toAqueduct to aqueductOutlet;

        exhibit SaqiyaStates;
    }

    // ===== Requirements =====
    requirement def LiftWaterRequirement {
        doc "The saqiya shall lift water from a low-level river source to an elevated aqueduct for irrigation.";
        subject system : SaqiyaSystem;
    }

    requirement def RotaryToLinearRequirement {
        doc "The crank-and-connecting-rod mechanism shall convert the continuous rotary motion of the drive wheel into reciprocating linear motion of the piston.";
        subject system : SaqiyaSystem;
    }

    requirement def PumpingCycleRequirement {
        doc "The piston shall draw water from the river through the intake valve on the suction stroke and push water through the discharge valve to the aqueduct on the compression stroke.";
        subject system : SaqiyaSystem;
    }

    requirement def OperationalStatesRequirement {
        doc "The system shall operate in idle, starting, running, stopped, and maintenance states with defined transitions between them.";
        subject system : SaqiyaSystem;
    }

    requirement def AnimalPowerRequirement {
        doc "The system shall be powered by an animal walking in a continuous circle to turn the horizontal wooden drive wheel.";
        subject system : SaqiyaSystem;
    }

    requirement def FlowRateRequirement {
        doc "The system shall achieve a nominal volumetric flow rate sufficient for irrigation at the specified lift height.";
        subject system : SaqiyaSystem;
        attribute minFlowRate : VolumetricFlowRate;
    }
}
