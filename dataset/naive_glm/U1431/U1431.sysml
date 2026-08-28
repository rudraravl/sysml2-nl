package WarehouseRampSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;
    import ISQSpace::*;
    import ISQMass::*;
    import ISQForce::*;
    import ISQEnergy::*;
    import ISQAngle::*;
    import ISQAcceleration::*;

    // ===== Value Types =====
    attribute def Length :> Real {
        unit :>> metre;
    }
    attribute def Height :> Real {
        unit :>> metre;
    }
    attribute def MassValue :> Real {
        unit :>> kilogram;
    }
    attribute def ForceValue :> Real {
        unit :>> newton;
    }
    attribute def AngleValue :> Real {
        unit :>> degree;
    }
    attribute def FrictionCoefficient :> Real {
        unit :>> One;
    }
    attribute def AccelerationValue :> Real {
        unit :>> 'm/s2';
    }
    attribute def SpeedValue :> Real {
        unit :>> 'm/s';
    }
    attribute def PowerValue :> Real {
        unit :>> watt;
    }
    attribute def TorqueValue :> Real {
        unit :>> 'N*m';
    }

    item def Load {
        attribute mass : MassValue;
        attribute position : Length;
        attribute velocity : SpeedValue;
    }

    // ===== Requirements =====
    requirement def StructuralStability {
        doc /* The support frame must provide vertical height and structural stability. */
        subject frame : SupportFrame;
        require frame.height >= 2.0 [m];
        require frame.maxLoadCapacity >= 750.0 [kg];
    }

    requirement def SafeInclineLimit {
        doc /* The ramp incline angle must be within safe limits. */
        subject ramp : RampSurface;
        require ramp.inclineAngle <= 20.0 [deg];
        require ramp.inclineAngle >= 5.0 [deg];
    }

    requirement def FrictionControl {
        doc /* Surface friction must balance ease of movement with control. */
        subject ramp : RampSurface;
        require ramp.frictionCoefficient >= 0.15 [One];
        require ramp.frictionCoefficient <= 0.35 [One];
    }

    requirement def BrakeHolding {
        doc /* The brake must hold the load securely at any point on the ramp. */
        subject brake : BrakeSystem;
        require brake.holdingForce >= 5000.0 [N];
        require brake.engagementTime <= 0.5 [s];
    }

    requirement def LoadCapacity {
        doc /* The system must handle loads up to the maximum capacity. */
        subject system : WarehouseRamp;
        require system.maxLoadMass >= 750.0 [kg];
    }

    requirement def OperationalSequence {
        doc /* Operation follows: base, ascending, top, secured. */
        subject system : WarehouseRamp;
        require system.controller.currentState in {'Base', 'Ascending', 'Top', 'Secured'};
    }

    // ===== Parts =====
    part def SupportFrame {
        attribute height : Height = 2.0 [m];
        attribute maxLoadCapacity : MassValue = 750.0 [kg];
        attribute materialStrength : ForceValue = 20000.0 [N];
        port baseMount : ~Any;
        port topMount : ~Any;
        port rampMount : ~Any;
    }

    part def RampSurface {
        attribute length : Length = 8.0 [m];
        attribute width : Length = 2.0 [m];
        attribute inclineAngle : AngleValue = 14.48 [deg];
        attribute frictionCoefficient : FrictionCoefficient = 0.25 [One];
        attribute surfaceMaterial : String = "textured steel";
        port baseEnd : ~Any;
        port topEnd : ~Any;
        port loadInterface : ~Any;
    }

    part def Winch {
        attribute maxPullForce : ForceValue = 6000.0 [N];
        attribute maxSpeed : SpeedValue = 0.3 [m/s];
        attribute motorPower : PowerValue = 2000.0 [W];
        attribute cableLength : Length = 10.0 [m];
        port cablePort : ~Any;
        port controlPort : ~Any;
        attribute engaged : Boolean;
    }

    part def BrakeSystem {
        attribute holdingForce : ForceValue = 6000.0 [N];
        attribute engagementTime : Real = 0.3 [s];
        attribute engaged : Boolean;
        port actuationPort : ~Any;
    }

    part def Controller {
        attribute currentState : String;
        attribute maxLoadMass : MassValue = 750.0 [kg];
        port sensorPort : ~Any;
        port winchControl : ~Any;
        port brakeControl : ~Any;
        exhibit state behavior {
            state def RampOperation {
                entry; then state Base;
                state Base {
                    entry { controller.currentState := "Base"; }
                    transition Base -> Ascending when loadDetected;
                }
                state Ascending {
                    entry { controller.currentState := "Ascending"; }
                    do { winch.engaged := true; brake.engaged := false; }
                    transition Ascending -> Top when topReached;
                }
                state Top {
                    entry { controller.currentState := "Top"; }
                    do { winch.engaged := false; brake.engaged := true; }
                    transition Top -> Secured when secureConfirmed;
                }
                state Secured {
                    entry { controller.currentState := "Secured"; }
                    do { brake.engaged := true; winch.engaged := false; }
                }
            }
        }
        attribute loadDetected : Boolean;
        attribute topReached : Boolean;
        attribute secureConfirmed : Boolean;
    }

    part def WarehouseRamp {
        attribute rampLength : Length = 8.0 [m];
        attribute rampHeight : Height = 2.0 [m];
        attribute maxLoadMass : MassValue = 750.0 [kg];
        attribute inclineAngle : AngleValue = 14.48 [deg];
        attribute gravitationalAcceleration : AccelerationValue = 9.81 ['m/s2'];

        part frame : SupportFrame {
            attribute height redefines SupportFrame::height = 2.0 [m];
            attribute maxLoadCapacity redefines SupportFrame::maxLoadCapacity = 750.0 [kg];
        }

        part ramp : RampSurface {
            attribute length redefines RampSurface::length = 8.0 [m];
            attribute inclineAngle redefines RampSurface::inclineAngle = 14.48 [deg];
            attribute frictionCoefficient redefines RampSurface::frictionCoefficient = 0.25 [One];
        }

        part winch : Winch {
            attribute maxPullForce redefines Winch::maxPullForce = 6000.0 [N];
        }

        part brake : BrakeSystem {
            attribute holdingForce redefines BrakeSystem::holdingForce = 6000.0 [N];
        }

        part controller : Controller {
            attribute maxLoadMass redefines Controller::maxLoadMass = 750.0 [kg];
        }

        item currentLoad : Load;

        // Required force to move load up the incline
        // F = m*g*(sin(theta) + mu*cos(theta))
        attribute requiredForce : ForceValue = currentLoad.mass * gravitationalAcceleration * (inclineAngle.sin() + ramp.frictionCoefficient * inclineAngle.cos());

        // Mechanical advantage of inclined plane
        attribute mechanicalAdvantage : Real = ramp.length / frame.height;

        satisfy StructuralStability by frame;
        satisfy SafeInclineLimit by ramp;
        satisfy FrictionControl by ramp;
        satisfy BrakeHolding by brake;
        satisfy LoadCapacity by self;
        satisfy OperationalSequence by self;

        connection frame.rampMount to ramp.baseEnd;
        connection winch.cablePort to ramp.loadInterface;
        connection controller.winchControl to winch.controlPort;
        connection controller.brakeControl to brake.actuationPort;
        connection controller.sensorPort to ramp.loadInterface;

        action def MoveLoad {
            in load : Load;
            out success : Boolean;
            attribute appliedForce : ForceValue;
            attribute workDone : Real;
            do {
                appliedForce := load.mass * gravitationalAcceleration * (inclineAngle.sin() + ramp.frictionCoefficient * inclineAngle.cos());
                workDone := appliedForce * ramp.length;
                success := appliedForce <= winch.maxPullForce and load.mass <= maxLoadMass;
            }
        }

        action def EngageBrake {
            in position : Length;
            do {
                brake.engaged := true;
                winch.engaged := false;
            }
        }

        action def DisengageBrake {
            do {
                brake.engaged := false;
            }
        }
    }

    part warehouseRampInstance : WarehouseRamp {
        part frame redefines WarehouseRamp::frame;
        part ramp redefines WarehouseRamp::ramp;
        part winch redefines WarehouseRamp::winch;
        part brake redefines WarehouseRamp::brake;
        part controller redefines WarehouseRamp::controller;
        item currentLoad redefines WarehouseRamp::currentLoad {
            attribute mass = 500.0 [kg];
            attribute position = 0.0 [m];
            attribute velocity = 0.0 [m/s];
        }
    }
}
