package FourBarLinkage {
    private import ISQ::*;
    private import SI::*;
    private import ScalarFunctions::*;

    value def Efficiency :> Real {
        unit one;
    }

    value def Stroke :> Length {
        doc Output stroke of the linear mechanism
        unit centimeter;
    }

    item def RigidBody {
        attribute mass : Mass;
        attribute materialStrength : Pressure;
    }

    port def MechanicalPivot {
        attribute positionX : Length;
        attribute positionY : Length;
        attribute angle : Angle;
        attribute angularVelocity : AngularVelocity;
        attribute torque : Torque;
        attribute reactionForceX : Force;
        attribute reactionForceY : Force;
    }

    port def LinearOutputPort {
        attribute positionX : Length;
        attribute velocity : Speed;
        attribute force : Force;
    }

    part def GroundFrame :> RigidBody {
        attribute pivot1X : Length = 0 [millimeter];
        attribute pivot1Y : Length = 0 [millimeter];
        attribute pivot2X : Length = 300 [millimeter];
        attribute pivot2Y : Length = 0 [millimeter];
        attribute mass : Mass = 75 [kilogram];
        attribute materialStrength : Pressure = 250 [megapascal];
        port groundPivot1 : MechanicalPivot;
        port groundPivot2 : MechanicalPivot;
    }

    part def CrankLink :> RigidBody {
        attribute crankRadius : Length = 80 [millimeter];
        attribute mass : Mass = 2.5 [kilogram];
        attribute materialStrength : Pressure = 350 [megapascal];
        attribute currentAngle : Angle;
        attribute angularVelocity : AngularVelocity;
        port groundPivot : MechanicalPivot;
        port couplerPivot : MechanicalPivot;
    }

    part def CouplerLink :> RigidBody {
        attribute couplerLength : Length = 250 [millimeter];
        attribute mass : Mass = 6.0 [kilogram];
        attribute materialStrength : Pressure = 350 [megapascal];
        port crankPivot : MechanicalPivot;
        port rockerPivot : MechanicalPivot;
    }

    part def RockerLink :> RigidBody {
        attribute rockerLength : Length = 200 [millimeter];
        attribute mass : Mass = 4.5 [kilogram];
        attribute materialStrength : Pressure = 350 [megapascal];
        attribute currentAngle : Angle;
        attribute maxSwingAngle : Angle = 35 [degree];
        attribute currentTorque : Torque;
        port groundPivot : MechanicalPivot;
        port couplerPivot : MechanicalPivot;
        port outputPivot : MechanicalPivot;
    }

    part def ElectricMotor {
        attribute nominalTorque : Torque = 5.0 [newton_meter];
        attribute nominalSpeed : AngularVelocity = 10.0 [radian_per_second];
        attribute motorEfficiency : Real = 0.92;
        attribute powerOn : Boolean;
        attribute shaftAngle : Angle;
        attribute shaftAngularVelocity : AngularVelocity;
        port drivePort : MechanicalPivot;
    }

    part def LinearOutputMechanism {
        attribute mechanismMass : Mass = 3.0 [kilogram];
        attribute outputStroke : Stroke;
        attribute outputForce : Force;
        attribute outputSpeed : Speed;
        attribute mechanismEfficiency : Real = 0.95;
        port inputPivot : MechanicalPivot;
        port outputPort : LinearOutputPort;
    }

    action def ComputeStrokeFromRocker {
        in rockerLength : Length;
        in maxSwing : Angle;
        out strokeValue : Length;
        compute strokeValue := 2.0 * rockerLength * sin(maxSwing / 2.0);
    }

    action def ComputeOutputForce {
        in inputTorque : Torque;
        in mechanismEfficiency : Real;
        in rockerLength : Length;
        out outputForce : Force;
        compute outputForce := (inputTorque * mechanismEfficiency) / (rockerLength);
    }

    state def OperatingStates {
        attribute powerOn : Boolean;
        attribute jamDetected : Boolean;
        attribute startCmd : Boolean;
        attribute stopCmd : Boolean;
        attribute resetCmd : Boolean;

        state Off {
            entry { powerOn := false; }
        }
        state Idle;
        state Running;
        state Jammed;

        transition from Off to Idle when startCmd;
        transition from Idle to Running when powerOn;
        transition from Running to Jammed when jamDetected;
        transition from Jammed to Idle when resetCmd;
        transition from Idle to Off when stopCmd;
    }

    requirement def StrokeRange {
        doc Output stroke must be between 5 cm and 40 cm
        subject linkage;
        attribute minStroke : Length = 5 [centimeter];
        attribute maxStroke : Length = 40 [centimeter];
        constraint strokeRange {
            (linkage.outputStroke >= minStroke) and
            (linkage.outputStroke <= maxStroke)
        }
    }

    requirement def SmoothOperation {
        doc The linkage must operate smoothly without jamming
        subject linkage;
        attribute jamFree : Boolean;
        constraint noJam {
            linkage.jamFree == true
        }
    }

    requirement def EfficiencySpec {
        doc At least 82 percent of motor torque must be converted to usable output force
        subject linkage;
        attribute minEfficiency : Real = 0.82;
        constraint minEff {
            linkage.efficiency >= minEfficiency
        }
    }

    part fourBarLinkageMechanism {
        attribute efficiency : Real = 0.85;
        attribute outputStroke : Stroke = 25 [centimeter];
        attribute jamFree : Boolean = true;
        attribute inputTorque : Torque = 5.0 [newton_meter];

        part groundFrame : GroundFrame;
        part motor : ElectricMotor;
        part crank : CrankLink;
        part coupler : CouplerLink;
        part rocker : RockerLink;
        part outputMechanism : LinearOutputMechanism;

        satisfy StrokeRange;
        satisfy SmoothOperation;
        satisfy EfficiencySpec;

        connection motor.drivePort to crank.groundPivot;
        connection groundFrame.groundPivot1 to crank.groundPivot;
        connection crank.couplerPivot to coupler.crankPivot;
        connection coupler.rockerPivot to rocker.couplerPivot;
        connection groundFrame.groundPivot2 to rocker.groundPivot;
        connection rocker.outputPivot to outputMechanism.inputPivot;
    }
}
