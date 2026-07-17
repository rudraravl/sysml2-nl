package 'Peaucellier-Lipkin Linkage System' {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;
    
    attribute def AngleValue :> Real;
    attribute def AngularVelocityValue :> Real;
    
    item def Point2D {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }
    
    item def LinkageState {
        attribute crankAngle : AngleValue;
        attribute rhombusVertex1 : Point2D;
        attribute rhombusVertex2 : Point2D;
        attribute rhombusVertex3 : Point2D;
        attribute rhombusVertex4 : Point2D;
        attribute tracerPoint : Point2D;
    }
    
    port def RotaryInputPort {
        attribute angle : AngleValue;
        attribute angularVelocity : AngularVelocityValue;
        attribute torque : TorqueValue;
    }
    
    port def LinearOutputPort {
        attribute position : Point2D;
        attribute velocity : LengthValue;
        attribute force : ForceValue;
    }
    
    port def PivotJoint {
        attribute position : Point2D;
        attribute angle : AngleValue;
    }
    
    part def FixedPivot {
        attribute anchorPosition : Point2D;
        port mounting : PivotJoint {
            attribute position = anchorPosition;
        }
    }
    
    part def RigidBar {
        attribute barLength : LengthValue;
        port end1 : PivotJoint;
        port end2 : PivotJoint;
    }
    
    part def DrivingCrank {
        attribute crankLength : LengthValue;
        attribute currentAngle : AngleValue;
        port pivot : PivotJoint;
        port tip : PivotJoint;
    }
    
    part def RhombusAssembly {
        attribute sideLength : LengthValue;
        port vertex1 : PivotJoint;
        port vertex2 : PivotJoint;
        port vertex3 : PivotJoint;
        port vertex4 : PivotJoint;
        
        part side12 : RigidBar {
            attribute barLength = sideLength;
        }
        part side23 : RigidBar {
            attribute barLength = sideLength;
        }
        part side34 : RigidBar {
            attribute barLength = sideLength;
        }
        part side41 : RigidBar {
            attribute barLength = sideLength;
        }
        
        connection connect side12.end1 to vertex1;
        connection connect side12.end2 to vertex2;
        connection connect side23.end1 to vertex2;
        connection connect side23.end2 to vertex3;
        connection connect side34.end1 to vertex3;
        connection connect side34.end2 to vertex4;
        connection connect side41.end1 to vertex4;
        connection connect side41.end2 to vertex1;
    }
    
    action def ComputeLinkageKinematics {
        in crankAngle : AngleValue;
        in fixedPivotPos : Point2D;
        in drivingPivotPos : Point2D;
        in crankLength : LengthValue;
        in rhombusSide : LengthValue;
        in couplerLength : LengthValue;
        out currentState : LinkageState;
    }
    
    action def ValidateStraightLineMotion {
        in tracerPath : Point2D[*];
        in deviationTolerance : LengthValue;
        out isLinear : Boolean;
        out maxDeviation : LengthValue;
    }
    
    action def OperateLinkageSystem {
        in startAngle : AngleValue;
        in rotationSpeed : AngularVelocityValue;
        in operationDuration : TimeValue;
        in stepInterval : TimeValue;
        out tracerTrajectory : Point2D[*];
        
        private attribute angle := startAngle;
        private attribute elapsedTime : TimeValue := 0.0;
        private attribute trajectory : Point2D[*] := ();
        
        first start;
        then merge continueRotation;
        
        then decide;
            if elapsedTime < operationDuration then computePosition;
            if elapsedTime >= operationDuration then finishOperation;
        
        action computePosition : ComputeLinkageKinematics {
            in crankAngle = angle;
            out currentState;
        }
        then assign trajectory := trajectory->including(computePosition.currentState.tracerPoint);
        then assign angle := angle + (rotationSpeed * stepInterval);
        then assign elapsedTime := elapsedTime + stepInterval;
        then continueRotation;
        
        action finishOperation {
            assign tracerTrajectory := trajectory;
        }
        then done;
    }
    
    part def PeaucellierLipkinLinkage {
        doc /*
            The Peaucellier-Lipkin linkage is a planar mechanism that converts 
            circular motion into exact straight-line motion through geometric inversion.
            It consists of two fixed pivot points, a rotating crank, a rhombus-shaped 
            four-bar linkage, and two equal-length coupler bars. As the crank rotates, 
            the output tracer point follows a mathematically perfect straight line, 
            making it invaluable for precision mechanical applications.
        */
        
        attribute fixedPivotSeparation : LengthValue;
        attribute crankRadius : LengthValue;
        attribute rhombusSideLength : LengthValue;
        attribute couplerBarLength : LengthValue;
        
        port rotaryInput : RotaryInputPort;
        port linearOutput : LinearOutputPort;
        
        part fixedPivotO : FixedPivot {
            attribute anchorPosition : Point2D {
                attribute x : LengthValue = 0.0;
                attribute y : LengthValue = 0.0;
            }
        }
        
        part fixedPivotA : FixedPivot {
            attribute anchorPosition : Point2D {
                attribute x : LengthValue = fixedPivotSeparation;
                attribute y : LengthValue = 0.0;
            }
        }
        
        part crank : DrivingCrank {
            attribute crankLength = crankRadius;
        }
        
        part rhombus : RhombusAssembly {
            attribute sideLength = rhombusSideLength;
        }
        
        part couplerBar1 : RigidBar {
            attribute barLength = couplerBarLength;
        }
        
        part couplerBar2 : RigidBar {
            attribute barLength = couplerBarLength;
        }
        
        part tracerBar : RigidBar;
        
        connection crankPivotConnection connect crank.pivot to fixedPivotA.mounting;
        connection crankToRhombusConnection connect crank.tip to rhombus.vertex1;
        connection rhombusToFixedConnection connect rhombus.vertex3 to fixedPivotO.mounting;
        connection coupler1ToRhombusConnection connect couplerBar1.end1 to rhombus.vertex2;
        connection coupler2ToRhombusConnection connect couplerBar2.end1 to rhombus.vertex4;
        connection coupler1ToTracerConnection connect couplerBar1.end2 to tracerBar.end1;
        connection coupler2ToTracerConnection connect couplerBar2.end2 to tracerBar.end1;
        
        perform action operateSystem : OperateLinkageSystem {
            in startAngle : AngleValue = 0.0;
            in rotationSpeed : AngularVelocityValue = 1.0;
            in operationDuration : TimeValue;
            in stepInterval : TimeValue = 0.01;
            out tracerTrajectory : Point2D[*];
        }
        
        perform action validateMotion : ValidateStraightLineMotion {
            in tracerPath = operateSystem.tracerTrajectory;
            in deviationTolerance : LengthValue = 0.0005;
            out isLinear : Boolean;
            out maxDeviation : LengthValue;
        }
    }
    
    requirement def StraightLineMotionRequirement {
        doc /*
            The linkage system shall produce straight-line motion at the output 
            tracer point with deviation from perfect linearity not exceeding 
            0.5 mm throughout the complete range of crank rotation.
        */
        
        subject linkage : PeaucellierLipkinLinkage;
        
        require constraint {
            linkage.validateMotion.isLinear == true and
            linkage.validateMotion.maxDeviation <= 0.0005
        }
    }
    
    requirement def GeometricConstraintRequirement {
        doc /*
            The linkage dimensions shall satisfy the mathematical constraints 
            for proper geometric inversion: coupler bars must be equal in length, 
            and all four sides of the rhombus must be equal.
        */
        
        subject linkage : PeaucellierLipkinLinkage;
        
        require constraint {
            linkage.couplerBar1.barLength == linkage.couplerBar2.barLength and
            linkage.rhombus.side12.barLength == linkage.rhombus.side23.barLength and
            linkage.rhombus.side23.barLength == linkage.rhombus.side34.barLength and
            linkage.rhombus.side34.barLength == linkage.rhombus.side41.barLength
        }
    }
    
    requirement def ContinuousOperationRequirement {
        doc /*
            The linkage system shall operate continuously through full 360-degree 
            rotations of the driving crank without mechanical interference, 
            singularities, or binding.
        */
        
        subject linkage : PeaucellierLipkinLinkage;
    }
    
    requirement systemMissionRequirement {
        doc /*
            The Peaucellier-Lipkin linkage system shall convert continuous rotary 
            motion into exact rectilinear motion for precision mechanical applications 
            requiring straight-line guidance without sliding contacts.
        */
        
        subject linkage : PeaucellierLipkinLinkage;
        
        assume constraint geometricConstraints : GeometricConstraintRequirement;
        assume constraint continuousOperation : ContinuousOperationRequirement;
        require constraint straightLineMotion : StraightLineMotionRequirement;
    }
    
    part linkageSystem : PeaucellierLipkinLinkage {
        attribute fixedPivotSeparation : LengthValue = 0.100;
        attribute crankRadius : LengthValue = 0.030;
        attribute rhombusSideLength : LengthValue = 0.050;
        attribute couplerBarLength : LengthValue = 0.050;
        
        satisfy systemMissionRequirement by linkageSystem;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SequenceFunctions::*;
    private import 'Peaucellier-Lipkin Linkage System'::*;

    action orchestrator {
        attribute testCrankAngle : AngleValue = 0.0;
        action computePositionProbe : ComputeLinkageKinematics {
            in crankAngle = testCrankAngle;
        }
        first computePositionProbe;
    }
}
