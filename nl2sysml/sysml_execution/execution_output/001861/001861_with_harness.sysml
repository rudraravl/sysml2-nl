package 'Simple Machine - Inclined Plane System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def LoadMass :> ISQ::mass;
    attribute def AppliedForce :> ISQ::force;
    attribute def NormalForce :> ISQ::force;
    attribute def FrictionForce :> ISQ::force;
    attribute def Distance :> ISQ::length;
    attribute def Angle :> ISQ::planeAngle;
    attribute def Velocity :> ISQ::speed;
    attribute def Coefficient :> Real;
    
    item def Load {
        attribute mass : LoadMass;
        attribute weight : AppliedForce;
        attribute position : Distance;
        attribute velocity : Velocity;
    }
    
    item def ForceVector {
        attribute magnitude : AppliedForce;
        attribute direction : Angle;
    }
    
    port def LoadPort {
        in item appliedEffort : ForceVector;
        out item loadMovement : Load;
        attribute normalReaction : NormalForce;
        attribute frictionResistance : FrictionForce;
    }
    
    port def EffortPort {
        out item appliedEffort : ForceVector;
        in item loadMovement : Load;
    }
    
    port def SurfacePort {
        attribute inclineAngle : Angle;
        attribute frictionCoefficient : Coefficient;
        out normalReaction : NormalForce;
        out frictionResistance : FrictionForce;
    }
    
    part def Operator {
        attribute maxEffort : AppliedForce;
        attribute currentEffort : AppliedForce;
        port effortApplication : EffortPort;
    }
    
    part def LoadObject {
        attribute mass : LoadMass;
        attribute weight : AppliedForce;
        attribute currentPosition : Distance;
        attribute currentVelocity : Velocity;
        port loadInterface : LoadPort;
    }
    
    part def InclinedPlane {
        attribute planeLength : Distance;
        attribute planeHeight : Distance;
        attribute inclineAngle : Angle;
        attribute surfaceFriction : Coefficient;
        
        port loadSupport : SurfacePort;
        port effortInput : EffortPort;
        
        calc calculateMechanicalAdvantage {
            in length : Distance = planeLength;
            in height : Distance = planeHeight;
            return : Real = length / height;
        }
        
        calc calculateRequiredForce {
            in loadWeight : AppliedForce;
            in angle : Angle = inclineAngle;
            in friction : Coefficient = surfaceFriction;
            return : AppliedForce = loadWeight * (angle + friction);
        }
    }
    
    action def ApplyEffortForce {
        in effortMagnitude : AppliedForce;
        in effortDirection : Angle;
        out effortVector : ForceVector;
    }
    
    action def MoveLoad {
        in appliedForce : AppliedForce;
        in loadWeight : AppliedForce;
        in planeAngle : Angle;
        in frictionCoeff : Coefficient;
        in planeLength : Distance;
        out displacement : Distance;
        out finalVelocity : Velocity;
        out workDone : Real;
    }
    
    state def InclinedPlaneState {
        entry; then idle;
        
        state idle {
            entry assign loadAtRest = true;
            entry assign effortApplied = false;
        }
        
        accept at idle
            then checkingEffort
            when effortApplied;
        
        state checkingEffort {
            do action evaluateForce;
        }
        
        accept at checkingEffort
            then movingLoad
            when sufficientForce;
        accept at checkingEffort
            then idle
            when insufficientForce;
        
        state movingLoad {
            do action translateLoad : MoveLoad;
        }
        
        accept at movingLoad
            then checkingPosition
            when loadInMotion;
        
        state checkingPosition;
        
        accept at checkingPosition
            then reachedTop
            when atTopOfPlane;
        accept at checkingPosition
            then movingLoad
            when continueMoving;
        
        state reachedTop {
            entry assign loadAtRest = true;
        }
        then idle;
    }
    
    requirement def MechanicalAdvantageRequirement {
        doc /* The inclined plane shall provide mechanical advantage by reducing 
                the force required to raise a load compared to lifting it vertically. */
        
        subject plane : InclinedPlane;
        
        require constraint {
            plane.calculateMechanicalAdvantage() > 1.0
        }
        
        require constraint {
            plane.calculateRequiredForce() < plane.loadSupport.normalReaction
        }
    }
    
    requirement def EfficiencyRequirement {
        doc /* The inclined plane system shall minimize energy loss due to friction
                while maintaining safe operation. */
        
        attribute maxFrictionCoefficient : Coefficient = 0.3;
        attribute minEfficiency : Real = 0.70;
        attribute surfaceFriction : Coefficient;
        attribute systemEfficiency : Real;
        
        require constraint {
            surfaceFriction <= maxFrictionCoefficient
        }
        
        require constraint {
            systemEfficiency >= minEfficiency
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall prevent uncontrolled descent of the load and
                ensure operator effort remains within safe limits. */
        
        attribute maxOperatorForce : AppliedForce;
        attribute minStabilityAngle : Angle;
        attribute appliedEffort : AppliedForce;
        attribute planeAngle : Angle;
        
        require constraint {
            appliedEffort <= maxOperatorForce
        }
        
        require constraint {
            planeAngle >= minStabilityAngle
        }
    }
    
    part inclinedPlaneSystem {
        attribute gravity : ISQ::acceleration = 9.81;
        attribute systemEfficiency : Real;
        
        part plane : InclinedPlane {
            attribute :>> planeLength = 5.0;
            attribute :>> planeHeight = 1.0;
            attribute :>> inclineAngle = 11.5;
            attribute :>> surfaceFriction = 0.2;
        }
        
        part operator : Operator {
            attribute :>> maxEffort = 300.0;
            attribute :>> currentEffort = 150.0;
        }
        
        part load : LoadObject {
            attribute :>> mass = 60.0;
            attribute :>> weight = mass * gravity;
            attribute :>> currentPosition = 0.0;
            attribute :>> currentVelocity = 0.0;
        }
        
        action systemOperation : MoveLoad {
            in :>> appliedForce = operator.currentEffort;
            in :>> loadWeight = load.weight;
            in :>> planeAngle = plane.inclineAngle;
            in :>> frictionCoeff = plane.surfaceFriction;
            in :>> planeLength = plane.planeLength;
        }
        
        state planeBehavior : InclinedPlaneState;
        
        flow operator.effortApplication to plane.effortInput;
        flow plane.loadSupport to load.loadInterface;
        
        satisfy mechanicalAdvantageReq : MechanicalAdvantageRequirement by plane;
        
        satisfy efficiencyReq : EfficiencyRequirement by inclinedPlaneSystem {
            attribute :>> surfaceFriction = plane.surfaceFriction;
            attribute :>> systemEfficiency = 
                (plane.planeHeight / plane.planeLength) / 
                (1.0 + plane.surfaceFriction);
        }
        
        satisfy safetyReq : SafetyRequirement by inclinedPlaneSystem {
            attribute :>> maxOperatorForce = operator.maxEffort;
            attribute :>> appliedEffort = operator.currentEffort;
            attribute :>> planeAngle = plane.inclineAngle;
            attribute :>> minStabilityAngle = 5.0;
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import 'Simple Machine - Inclined Plane System'::*;

    part testSubject = inclinedPlaneSystem;

    part testSubject : Operator {
        exhibit state sm : InclinedPlaneState;
    }
}
