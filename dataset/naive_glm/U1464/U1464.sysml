package PeaucellierLipkinLinkage {

    import ISQ::*;
    import ScalarValues::*;

    value def LengthValue :> Real { unit 'm'; }
    value def AngleValue :> Real { unit 'rad'; }
    value def AngularVelocityValue :> Real { unit 'rad/s'; }
    value def LinearVelocityValue :> Real { unit 'm/s'; }
    value def ForceValue :> Real { unit 'N'; }

    item def Point2D {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }

    port def PivotPort {
        attribute position : Point2D;
        attribute reactionForce : ForceValue;
    }

    part def RigidBar {
        port endA : PivotPort;
        port endB : PivotPort;
        attribute length : LengthValue;
        attribute orientation : AngleValue;
        attribute mass : Real { unit 'kg'; }
    }

    part def FixedPivot {
        port pivot : PivotPort;
        attribute anchorPosition : Point2D;
        attribute isGrounded : Boolean = true;
    }

    part def InputCrank :> RigidBar {
        attribute angularVelocity : AngularVelocityValue;
        attribute crankRadius : LengthValue;
        attribute inputTorque : Real { unit 'N*m'; }
    }

    part def RhombusBar :> RigidBar {
        attribute sideLength : LengthValue;
    }

    part def CouplerBar :> RigidBar {
        attribute couplerLength : LengthValue;
    }

    part def TracerPoint {
        port tracer : PivotPort;
        attribute pathDeviation : LengthValue;
        attribute instantaneousVelocity : LinearVelocityValue;
        attribute pathIsStraight : Boolean;
    }

    part def Base {
        attribute material : String;
        attribute mountingSurface : String;
        port anchor1 : PivotPort;
        port anchor2 : PivotPort;
        attribute pivotSeparation : LengthValue;
    }

    part def RhombusAssembly {
        port vertexCrank : PivotPort;
        port vertexFixed : PivotPort;
        port vertexCoupler1 : PivotPort;
        port vertexCoupler2 : PivotPort;
        attribute sideLength : LengthValue;
        attribute diagonalLong : LengthValue;
        attribute diagonalShort : LengthValue;

        part barA : RhombusBar {
            sideLength = RhombusAssembly::sideLength;
            length = sideLength;
        }
        part barB : RhombusBar {
            sideLength = RhombusAssembly::sideLength;
            length = sideLength;
        }
        part barC : RhombusBar {
            sideLength = RhombusAssembly::sideLength;
            length = sideLength;
        }
        part barD : RhombusBar {
            sideLength = RhombusAssembly::sideLength;
            length = sideLength;
        }

        connection pivot_V1_barA connect vertexCrank to barA.endA;
        connection pivot_barA_V3 connect barA.endB to vertexCoupler1;
        connection pivot_V3_barB connect vertexCoupler1 to barB.endA;
        connection pivot_barB_V2 connect barB.endB to vertexFixed;
        connection pivot_V2_barC connect vertexFixed to barC.endA;
        connection pivot_barC_V4 connect barC.endB to vertexCoupler2;
        connection pivot_V4_barD connect vertexCoupler2 to barD.endA;
        connection pivot_barD_V1 connect barD.endB to vertexCrank;

        assert constraint { barA.length == barB.length and barB.length == barC.length and barC.length == barD.length }
        assert constraint { diagonalLong == diagonalShort + 0.0 [m] implies vertexCoupler1.position.x == vertexCoupler2.position.x }
    }

    part def PeaucellierLipkinMechanism {
        attribute crankLength : LengthValue;
        attribute couplerLength : LengthValue;
        attribute rhombusSide : LengthValue;
        attribute pivotSeparation : LengthValue;
        attribute designDeviation : LengthValue = 0.0 [m];

        part base : Base {
            material = "cast iron";
            mountingSurface = "planar";
            pivotSeparation = PeaucellierLipkinMechanism::pivotSeparation;
        }
        part fixedPivot1 : FixedPivot {
            anchorPosition = base.anchor1.position;
            pivot.position = base.anchor1.position;
        }
        part fixedPivot2 : FixedPivot {
            anchorPosition = base.anchor2.position;
            pivot.position = base.anchor2.position;
        }
        part crank : InputCrank {
            length = crankLength;
            crankRadius = crankLength;
            endA.position = fixedPivot1.pivot.position;
        }
        part rhombus : RhombusAssembly {
            sideLength = rhombusSide;
            vertexFixed.position = fixedPivot2.pivot.position;
        }
        part coupler1 : CouplerBar {
            length = couplerLength;
            couplerLength = couplerLength;
        }
        part coupler2 : CouplerBar {
            length = couplerLength;
            couplerLength = couplerLength;
        }
        part tracer : TracerPoint {
            pathDeviation = designDeviation;
            pathIsStraight = true;
        }

        connection bind_base_anchor1 connect base.anchor1 to fixedPivot1.pivot;
        connection bind_base_anchor2 connect base.anchor2 to fixedPivot2.pivot;
        connection connect_crank_to_pivot1 connect crank.endA to fixedPivot1.pivot;
        connection connect_crank_to_rhombus connect crank.endB to rhombus.vertexCrank;
        connection connect_rhombus_to_pivot2 connect rhombus.vertexFixed to fixedPivot2.pivot;
        connection connect_rhombusV3_to_coupler1 connect rhombus.vertexCoupler1 to coupler1.endA;
        connection connect_rhombusV4_to_coupler2 connect rhombus.vertexCoupler2 to coupler2.endA;
        connection connect_coupler1_to_tracer connect coupler1.endB to tracer.tracer;
        connection connect_coupler2_to_tracer connect coupler2.endB to tracer.tracer;

        assert constraint { coupler1.length == coupler2.length }
        assert constraint { rhombus.sideLength == rhombusSide }
        assert constraint { crank.length == crankLength }

        state machine def OperationStateMachine {
            state Idle {
            }
            state Rotating {
            }
            state TracingStraightLine {
            }
            transition init_Idle from Idle to Rotating when crank.angularVelocity > 0.0 [rad/s];
            transition start_Tracing from Rotating to TracingStraightLine when tracer.pathIsStraight == true;
            transition continue_Tracing from TracingStraightLine to TracingStraightLine when crank.angularVelocity > 0.0 [rad/s];
            transition stop_to_Idle from TracingStraightLine to Idle when crank.angularVelocity == 0.0 [rad/s];
        }

        action def ComputeTracerPosition {
            in crankAngle : AngleValue;
            in pivotSeparation : LengthValue;
            in crankLength : LengthValue;
            in rhombusSide : LengthValue;
            in couplerLength : LengthValue;
            out tracerPosition : Point2D;
            out pathDeviation : LengthValue;

            attribute crankEndX : LengthValue;
            attribute crankEndY : LengthValue;
            attribute distCrankToFixed : LengthValue;
            attribute rhombusDiagonal : LengthValue;

            perform {
                crankEndX := crankLength * cos(crankAngle);
                crankEndY := crankLength * sin(crankAngle);
                distCrankToFixed := sqrt((crankEndX - pivotSeparation)**2 + crankEndY**2);
                rhombusDiagonal := sqrt(4.0 * rhombusSide**2 - distCrankToFixed**2);
                tracerPosition.x := (pivotSeparation * rhombusSide**2 - crankEndX * (rhombusSide**2 - rhombusDiagonal**2 / 4.0)) / (rhombusSide**2);
                tracerPosition.y := 0.0 [m];
                pathDeviation := 0.0 [m];
            }
        }

        action def DriveMechanism {
            in inputAngularVelocity : AngularVelocityValue;
            out tracerPath : Point2D[0..*];

            perform {
                while inputAngularVelocity > 0.0 [rad/s] {
                    ComputeTracerPosition();
                }
            }
        }
    }

    requirement def StraightLineMotionRequirement {
        subject mechanism : PeaucellierLipkinMechanism;
        attribute maxPermissibleDeviation : LengthValue = 0.0 [m];

        requirement id SR-01 {
            subject mechanism;
            doc /* The tracer point shall trace a mathematically perfect straight line as the input crank undergoes continuous rotary motion. */
            require constraint { mechanism.tracer.pathDeviation <= maxPermissibleDeviation }
        }

        requirement id SR-02 {
            subject mechanism;
            doc /* The straight-line path shall be produced solely through rigid-bar kinematic constraints, without sliding contact. */
            require constraint { mechanism.tracer.pathIsStraight == true }
        }
    }

    requirement def RotaryInputRequirement {
        subject mechanism : PeaucellierLipkinMechanism;
        requirement id RR-01 {
            subject mechanism;
            doc /* The input crank shall accept continuous rotary motion about fixedPivot1. */
            require constraint { mechanism.crank.angularVelocity > 0.0 [rad/s] }
        }
    }

    requirement def NoSlidingContactRequirement {
        subject mechanism : PeaucellierLipkinMechanism;
        requirement id NSC-01 {
            subject mechanism;
            doc /* All kinematic pairs shall be pivoting joints; no prismatic or sliding pairs shall be used. */
        }
    }

    requirement def RhombusEqualLengthRequirement {
        subject mechanism : PeaucellierLipkinMechanism;
        requirement id REL-01 {
            subject mechanism;
            doc /* The four bars forming the rhombus assembly shall be of equal length. */
            require constraint {
                mechanism.rhombus.barA.length == mechanism.rhombus.barB.length and
                mechanism.rhombus.barB.length == mechanism.rhombus.barC.length and
                mechanism.rhombus.barC.length == mechanism.rhombus.barD.length
            }
        }
    }

    requirement def CouplerEqualLengthRequirement {
        subject mechanism : PeaucellierLipkinMechanism;
        requirement id CEL-01 {
            subject mechanism;
            doc /* The two coupler bars shall be of equal length to each other. */
            require constraint { mechanism.coupler1.length == mechanism.coupler2.length }
        }
    }

    part def PeaucellierLipkinSystem :> PeaucellierLipkinMechanism {
        satisfy StraightLineMotionRequirement by mechanism;
        satisfy RotaryInputRequirement by mechanism;
        satisfy NoSlidingContactRequirement by mechanism;
        satisfy RhombusEqualLengthRequirement by mechanism;
        satisfy CouplerEqualLengthRequirement by mechanism;
    }

}
