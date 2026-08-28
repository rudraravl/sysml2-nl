package CMM_Positioning_System {
    import ScalarValues::*;
    import ISQBase::*;
    import ISQSpaceAndTime::*;
    import ISQElectromagnetism::*;

    // ---------- Value Types with Units ----------
    public value def LengthValue :> Length {
        unit mm;
    }
    public value def VelocityValue :> Velocity {
        unit 'mm/s';
    }
    public value def VoltageValue :> ElectricPotential {
        unit V;
    }
    public value def CurrentValue :> ElectricCurrent {
        unit A;
    }
    public value def PowerValue :> Power {
        unit W;
    }
    public value def FrequencyValue :> Frequency {
        unit Hz;
    }

    public value def Position3D {
        x : LengthValue;
        y : LengthValue;
        z : LengthValue;
    }

    public value def PositionError {
        ex : LengthValue;
        ey : LengthValue;
        ez : LengthValue;
    }

    public enum def AxisId { X; Y; Z; }

    // ---------- Item Types ----------
    public item def TargetCommand {
        targetPosition : Position3D;
        timestamp : Time;
    }

    public item def PositionFeedback {
        actualPosition : Position3D;
        valid : Boolean;
    }

    public item def DriveSignal {
        axis : AxisId;
        velocity : VelocityValue;
        active : Boolean;
    }

    public item def ElectricalPower {
        voltage : VoltageValue;
        current : CurrentValue;
    }

    // ---------- Requirements ----------
    requirement def WorkspaceRequirement {
        subject system : PositioningSystem;
        attribute xRange : LengthValue = 500 [mm];
        attribute yRange : LengthValue = 500 [mm];
        attribute zRange : LengthValue = 300 [mm];
        objective {
            system.workspace.x == xRange and
            system.workspace.y == yRange and
            system.workspace.z == zRange;
        }
    }

    requirement def AccuracyRequirement {
        subject system : PositioningSystem;
        attribute tolerance : LengthValue = 1 [um];
        objective {
            system.achievedTolerance <= tolerance;
        }
    }

    requirement def ProbeTipRequirement {
        subject probe : Probe;
        attribute tipDiameter : LengthValue = 1 [mm];
        objective {
            probe.tipDiameter == tipDiameter;
        }
    }

    requirement def ClosedLoopRequirement {
        subject controller : MotionController;
        attribute loopRate : FrequencyValue = 1000 [Hz];
        objective {
            controller.loopRate >= loopRate and
            controller.closedLoopEnabled == true;
        }
    }

    requirement def PowerSupplyRequirement {
        subject supply : PowerSupply;
        attribute outputVoltage : VoltageValue = 24 [V];
        objective {
            supply.outputVoltage == outputVoltage;
        }
    }

    // ---------- Part Definitions ----------
    part def Probe {
        attribute tipDiameter : LengthValue = 1 [mm];
        attribute mounted : Boolean = false;
        port in mount : MechanicalInterface;
        port out tip : MechanicalInterface;
        port out probeInterface : ProbeInterface;
    }

    part def LinearActuator {
        attribute axis : AxisId;
        attribute stroke : LengthValue;
        attribute position : LengthValue = 0 [mm];
        attribute maxVelocity : VelocityValue = 500 [mm/s];
        port in driveIn : DriveSignal;
        port in powerIn : ElectricalPower;
        port out shaftOut : MechanicalInterface;
        exhibit state def ActuatorBehavior {
            entry; then Idle;
            state Idle {
                entry { position = 0 [mm]; }
                accept DriveSignal via driveIn
                    when driveIn.active == true
                    then Moving;
            }
            state Moving {
                do action Move {
                    in ds : DriveSignal;
                    // integrate velocity over time to update position
                }
                accept DriveSignal via driveIn
                    when driveIn.active == false
                    then Idle;
            }
        }
    }

    part def ActuatorAssembly {
        attribute workspace : Position3D = (x = 500 [mm], y = 500 [mm], z = 300 [mm]);
        part xActuator : LinearActuator {
            attribute axis = AxisId::X;
            attribute stroke = 500 [mm];
        }
        part yActuator : LinearActuator {
            attribute axis = AxisId::Y;
            attribute stroke = 500 [mm];
        }
        part zActuator : LinearActuator {
            attribute axis = AxisId::Z;
            attribute stroke = 300 [mm];
        }
        port in driveIn : DriveSignal;
        port in powerIn : ElectricalPower;
        port out probeMount : MechanicalInterface;
        connection driveToX flow DriveSignal from driveIn to xActuator.driveIn;
        connection driveToY flow DriveSignal from driveIn to yActuator.driveIn;
        connection driveToZ flow DriveSignal from driveIn to zActuator.driveIn;
        connection powerToX flow ElectricalPower from powerIn to xActuator.powerIn;
        connection powerToY flow ElectricalPower from powerIn to yActuator.powerIn;
        connection powerToZ flow ElectricalPower from powerIn to zActuator.powerIn;
        connection xToY from xActuator.shaftOut to yActuator.shaftOut;
        connection yToZ from yActuator.shaftOut to zActuator.shaftOut;
        connection zToMount from zActuator.shaftOut to probeMount;
    }

    part def PositionSensor {
        attribute resolution : LengthValue = 0.1 [um];
        attribute sampleRate : FrequencyValue = 1000 [Hz];
        attribute actualPosition : Position3D = (x = 0 [mm], y = 0 [mm], z = 0 [mm]);
        port in powerIn : ElectricalPower;
        port in probeInterface : ProbeInterface;
        port out feedbackOut : PositionFeedback;
        exhibit state def SensorBehavior {
            entry; then Idle;
            state Idle {
                entry { actualPosition = (x = 0 [mm], y = 0 [mm], z = 0 [mm]); }
                accept ElectricalPower via powerIn then Sampling;
            }
            state Sampling {
                do action Sample {
                    // read probe interface and update actualPosition
                    out fb : PositionFeedback = (actualPosition = actualPosition, valid = true);
                }
                then Sampling;
            }
        }
    }

    part def MotionController {
        attribute tolerance : LengthValue = 1 [um];
        attribute loopRate : FrequencyValue = 1000 [Hz];
        attribute closedLoopEnabled : Boolean = true;
        attribute targetPosition : Position3D = (x = 0 [mm], y = 0 [mm], z = 0 [mm]);
        attribute actualPosition : Position3D = (x = 0 [mm], y = 0 [mm], z = 0 [mm]);
        attribute positionError : PositionError = (ex = 0 [mm], ey = 0 [mm], ez = 0 [mm]);
        port in commandIn : TargetCommand;
        port in feedbackIn : PositionFeedback;
        port in powerIn : ElectricalPower;
        port out driveOut : DriveSignal;

        exhibit state def ControllerBehavior {
            entry; then Idle;

            state Idle {
                entry { closedLoopEnabled = false; }
                accept TargetCommand via commandIn {
                    targetPosition = commandIn.targetPosition;
                } then Tracking;
            }

            state Tracking {
                entry { closedLoopEnabled = true; }
                do action ComputeCorrection {
                    in target : Position3D;
                    in actual : Position3D;
                    out error : PositionError;
                    out driveX : DriveSignal;
                    out driveY : DriveSignal;
                    out driveZ : DriveSignal;
                    // error = target - actual
                    error = (ex = target.x - actual.x, ey = target.y - actual.y, ez = target.z - actual.z);
                    driveX = (axis = AxisId::X, velocity = error.ex * 10 [1/s], active = (abs(error.ex) > tolerance));
                    driveY = (axis = AxisId::Y, velocity = error.ey * 10 [1/s], active = (abs(error.ey) > tolerance));
                    driveZ = (axis = AxisId::Z, velocity = error.ez * 10 [1/s], active = (abs(error.ez) > tolerance));
                }
                accept PositionFeedback via feedbackIn {
                    actualPosition = feedbackIn.actualPosition;
                } then Tracking;
                when abs(positionError.ex) <= tolerance and
                     abs(positionError.ey) <= tolerance and
                     abs(positionError.ez) <= tolerance
                    then Idle;
            }
        }
    }

    part def PowerSupply {
        attribute inputVoltage : VoltageValue = 230 [V];
        attribute outputVoltage : VoltageValue = 24 [V];
        attribute maxPower : PowerValue = 200 [W];
        port in mainIn : ElectricalPower;
        port out controllerOut : ElectricalPower;
        port out actuatorOut : ElectricalPower;
        port out sensorOut : ElectricalPower;
        exhibit state def SupplyBehavior {
            entry; then Off;
            state Off {
                accept ElectricalPower via mainIn then On;
            }
            state On {
                do action Regulate {
                    // distribute regulated 24V power to all outputs
                }
            }
        }
    }

    // ---------- Interfaces ----------
    port def MechanicalInterface {
        attribute position : Position3D;
    }
    port def ProbeInterface {
        attribute contact : Boolean;
    }

    // ---------- Top-Level System ----------
    part def PositioningSystem {
        attribute workspace : Position3D = (x = 500 [mm], y = 500 [mm], z = 300 [mm]);
        attribute achievedTolerance : LengthValue = 1 [um];

        port in commandPort : TargetCommand;
        port in powerPort : ElectricalPower;

        part motionController : MotionController;
        part actuatorAssembly : ActuatorAssembly;
        part probe : Probe;
        part positionSensor : PositionSensor;
        part powerSupply : PowerSupply;

        satisfy WorkspaceRequirement by system;
        satisfy AccuracyRequirement by system;
        satisfy ProbeTipRequirement by probe;
        satisfy ClosedLoopRequirement by motionController;
        satisfy PowerSupplyRequirement by powerSupply;

        connection commandToController flow TargetCommand
            from commandPort to motionController.commandIn;
        connection powerToSupply flow ElectricalPower
            from powerPort to powerSupply.mainIn;
        connection supplyToController flow ElectricalPower
            from powerSupply.controllerOut to motionController.powerIn;
        connection supplyToActuators flow ElectricalPower
            from powerSupply.actuatorOut to actuatorAssembly.powerIn;
        connection supplyToSensor flow ElectricalPower
            from powerSupply.sensorOut to positionSensor.powerIn;
        connection controllerToActuators flow DriveSignal
            from motionController.driveOut to actuatorAssembly.driveIn;
        connection actuatorsToProbe from actuatorAssembly.probeMount to probe.mount;
        connection probeToSensor from probe.probeInterface to positionSensor.probeInterface;
        connection sensorToController flow PositionFeedback
            from positionSensor.feedbackOut to motionController.feedbackIn;
    }
}
