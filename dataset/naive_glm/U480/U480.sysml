package ChainPumpSystem {
    import ScalarValues::*;

    value type Height :> Real { unit 'm'; }
    value type FlowRate :> Real { unit 'L/s'; }
    value type Torque :> Real { unit 'N*m'; }
    value type RotationalSpeed :> Real { unit 'rpm'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type Viscosity :> Real { unit 'Pa*s'; }
    value type Diameter :> Real { unit 'm'; }
    value type Pitch :> Real { unit 'm'; }
    value type Angle :> Real { unit 'deg'; }
    value type LinearSpeed :> Real { unit 'm/s'; }
    value type Volume :> Real { unit 'L'; }
    value type Density :> Real { unit 'kg/m^3'; }
    value type Length :> Real { unit 'm'; }
    value type Mass :> Real { unit 'kg'; }

    item def Water {
        attribute viscosity : Viscosity = 0.001 [Pa*s];
        attribute density : Density = 1000 [kg/m^3];
    }

    enum def OperatingState {
        off;
        starting;
        running;
        faulted;
        stopping;
    }

    port def ElectricalPowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def MechanicalPowerPort {
        attribute torque : Torque;
        attribute speed : RotationalSpeed;
    }

    port def FluidFlowPort {
        item flow : Water;
        attribute flowRate : FlowRate;
    }

    requirement def LiftHeightRequirement {
        doc "The system shall lift water to a height of at least 10 meters.";
        attribute minLiftHeight : Height = 10 [m];
    }

    requirement def FlowRateRequirement {
        doc "The system shall deliver a flow rate of at least 5 liters per second.";
        attribute minFlowRate : FlowRate = 5 [L/s];
    }

    requirement def ContinuousOperationRequirement {
        doc "The system shall operate continuously and reliably without interruption.";
    }

    requirement def FluidCompatibilityRequirement {
        doc "The system shall handle low-viscosity fluids such as water.";
        attribute maxViscosity : Viscosity = 0.01 [Pa*s];
    }

    requirement def LeakTightnessRequirement {
        doc "Disks shall fit snugly inside the housing tube to minimize back-leakage.";
        attribute maxLeakFraction : Real = 0.05;
    }

    part def ElectricMotor {
        port in electricalIn : ElectricalPowerPort;
        port out mechanicalOut : MechanicalPowerPort;
        attribute ratedPower : Power = 750 [W];
        attribute ratedSpeed : RotationalSpeed = 1450 [rpm];
        attribute ratedTorque : Torque = 4.94 [N*m];
        attribute efficiency : Real = 0.85;

        action def convertPower {
            in electrical : ElectricalPowerPort;
            out mechanical : MechanicalPowerPort;
        }
    }

    part def GearReducer {
        port in inputMech : MechanicalPowerPort;
        port out outputMech : MechanicalPowerPort;
        attribute gearRatio : Real = 10.0;
        attribute efficiency : Real = 0.95;

        action def reduceSpeed {
            in input : MechanicalPowerPort;
            out output : MechanicalPowerPort;
        }
    }

    part def DriveSprocket {
        port in inputMech : MechanicalPowerPort;
        port out chainDrive : MechanicalPowerPort;
        attribute teeth : Integer = 12;
        attribute pitchDiameter : Diameter = 0.12 [m];

        action def engageChain {
            in mech : MechanicalPowerPort;
            out chain : MechanicalPowerPort;
        }
    }

    part def ChainDisk {
        attribute material : String = "rubber";
        attribute diameter : Diameter = 0.10 [m];
        attribute thickness : Length = 0.02 [m];
        attribute sealClearance : Length = 0.001 [m];
    }

    part def ChainLoop {
        port in driveInput : MechanicalPowerPort;
        part disks : ChainDisk[8];
        attribute pitch : Pitch = 0.30 [m];
        attribute totalLength : Length = 30 [m];
        attribute linearSpeed : LinearSpeed = 0.5 [m/s];

        action def moveChain {
            in drive : MechanicalPowerPort;
            out motion : LinearSpeed;
        }
    }

    part def HousingTube {
        attribute tubeLength : Length = 12 [m];
        attribute innerDiameter : Diameter = 0.10 [m];
        attribute inclinationAngle : Angle = 60 [deg];
        port in lowerEnd : FluidFlowPort;
        port out upperEnd : FluidFlowPort;

        action def liftWaterColumn {
            in lowerFlow : FluidFlowPort;
            out upperFlow : FluidFlowPort;
        }
    }

    part def LowerReservoir {
        item waterSupply : Water;
        attribute reservoirVolume : Volume = 1000 [L];
        port out outlet : FluidFlowPort;
    }

    part def UpperDischargeSpout {
        port in inlet : FluidFlowPort;
        port out discharge : FluidFlowPort;
        attribute spoutDiameter : Diameter = 0.08 [m];
    }

    part def ElectricDriveUnit {
        part motor : ElectricMotor;
        part gearReducer : GearReducer;
        part driveSprocket : DriveSprocket;

        connection motor.mechanicalOut to gearReducer.inputMech;
        connection gearReducer.outputMech to driveSprocket.inputMech;
    }

    state def PumpOperation {
        entry; then off;

        state off {
            entry;
        }
        state starting {
            entry;
        }
        state running {
            entry;
        }
        state faulted {
            entry;
        }
        state stopping {
            entry;
        }

        transition off_to_starting
            first off
            when powerInput.voltage > 0 [V]
            then starting;

        transition starting_to_running
            first starting
            when driveUnit.motor.mechanicalOut.speed > 100 [rpm]
            then running;

        transition running_to_faulted
            first running
            when driveUnit.motor.electricalIn.current > 10 [A]
            then faulted;

        transition running_to_stopping
            first running
            when powerInput.voltage == 0 [V]
            then stopping;

        transition stopping_to_off
            first stopping
            when driveUnit.motor.mechanicalOut.speed == 0 [rpm]
            then off;

        transition faulted_to_off
            first faulted
            when powerInput.voltage == 0 [V]
            then off;
    }

    part def ChainPumpSystem {
        attribute actualLiftHeight : Height = 10 [m];
        attribute actualFlowRate : FlowRate = 5 [L/s];
        attribute operatingState : OperatingState = OperatingState::off;
        item handledFluid : Water;

        port in powerInput : ElectricalPowerPort;
        port out waterOutput : FluidFlowPort;

        requirement liftHeightReq : LiftHeightRequirement;
        requirement flowRateReq : FlowRateRequirement;
        requirement continuousOpReq : ContinuousOperationRequirement;
        requirement fluidCompatReq : FluidCompatibilityRequirement;
        requirement leakTightnessReq : LeakTightnessRequirement;

        satisfy liftHeightReq by actualLiftHeight;
        satisfy flowRateReq by actualFlowRate;
        satisfy continuousOpReq by operatingState;
        satisfy fluidCompatReq by handledFluid.viscosity;
        satisfy leakTightnessReq by housingTube.innerDiameter;

        part driveUnit : ElectricDriveUnit;
        part housingTube : HousingTube;
        part chain : ChainLoop;
        part reservoir : LowerReservoir;
        part dischargeSpout : UpperDischargeSpout;

        connection powerInput to driveUnit.motor.electricalIn;
        connection driveUnit.driveSprocket.chainDrive to chain.driveInput;
        connection reservoir.outlet to housingTube.lowerEnd;
        connection housingTube.upperEnd to dischargeSpout.inlet;
        connection dischargeSpout.discharge to waterOutput;

        exhibit PumpOperation;

        action pumpWater {
            in sourceWater : Water;
            out deliveredWater : Water;

            action trapWaterColumn {
                in inflow : Water;
                out trappedColumn : Water;
            }

            action liftColumn {
                in trapped : Water;
                out lifted : Water;
            }

            action releaseWater {
                in lifted : Water;
                out discharged : Water;
            }

            flow from trapWaterColumn.trappedColumn to liftColumn.trapped;
            flow from liftColumn.lifted to releaseWater.lifted;
        }

        perform pumpWater;
    }
}
