package InclinedPlaneSystem {
    import ISQ::*;
    import ScalarValues::*;

    item def MassValue :> Real { unit = 'kg'; }
    item def ForceValue :> Real { unit = 'N'; }
    item def LengthValue :> Real { unit = 'm'; }
    item def AngleValue :> Real { unit = 'rad'; }
    item def VelocityValue :> Real { unit = 'm/s'; }
    item def CoefficientValue :> Real { unit = '1'; }
    item def EnergyValue :> Real { unit = 'J'; }

    enum def LoadStatus { AtRestBottom, MovingUp, AtRestTop; }

    requirement def MechanicalAdvantage {
        doc /* The system must provide a mechanical advantage, reducing the required effort force compared to vertical lift. */
        attribute requiredEffortForce : ForceValue;
        attribute verticalLiftForce : ForceValue;
        require constraint { requiredEffortForce < verticalLiftForce }
    }

    requirement def EfficiencyGoal {
        doc /* The system must minimize energy loss due to friction. */
        attribute frictionLoss : EnergyValue;
        attribute inputEnergy : EnergyValue;
        require constraint { frictionLoss / inputEnergy < 0.2 }
    }

    requirement def SafetyConstraints {
        doc /* The operator must not apply an unsafe amount of force, and the ramp angle must prevent uncontrolled sliding. */
        attribute operatorMaxForce : ForceValue;
        attribute appliedForce : ForceValue;
        attribute rampAngle : AngleValue;
        attribute staticFrictionCoefficient : CoefficientValue;
        require constraint { appliedForce <= operatorMaxForce }
        require constraint { rampAngle <= atan(staticFrictionCoefficient) }
    }

    part def Load {
        attribute mass : MassValue;
        attribute weight : ForceValue;
        attribute position : LengthValue = 0.0; 
        attribute velocity : VelocityValue = 0.0;
        attribute status : LoadStatus = LoadStatus::AtRestBottom;
        
        attribute rampAngle : AngleValue;
        attribute rampLength : LengthValue;
        attribute frictionForce : ForceValue;
        
        port inputPort {
            attribute appliedForce : ForceValue;
        }
        
        exhibit state LoadBehavior {
            entry; then AtRestBottom;
            
            state AtRestBottom {
                entry { status = LoadStatus::AtRestBottom; }
                transition if (inputPort.appliedForce > weight * sin(rampAngle) + frictionForce) to MovingUp;
            }
            
            state MovingUp {
                entry { status = LoadStatus::MovingUp; }
                do {
                    velocity = velocity + (inputPort.appliedForce - weight * sin(rampAngle) - frictionForce) / mass * 0.1;
                    position = position + velocity * 0.1;
                }
                transition if (position >= rampLength) to AtRestTop;
            }
            
            state AtRestTop {
                entry { status = LoadStatus::AtRestTop; velocity = 0.0; }
            }
        }
    }

    part def InclinedPlane {
        attribute length : LengthValue;
        attribute height : LengthValue;
        attribute angle : AngleValue;
        attribute frictionCoefficient : CoefficientValue;
        
        attribute normalForce : ForceValue;
        attribute frictionForce : ForceValue;
        
        action computeFriction {
            frictionForce = frictionCoefficient * normalForce;
        }
    }

    part def Operator {
        attribute maxForce : ForceValue;
        attribute appliedForce : ForceValue;
        
        port outputPort {
            attribute appliedForce : ForceValue;
        }
        
        action applyForce {
            outputPort.appliedForce = appliedForce;
        }
    }

    part def InclinedPlaneSystem {
        part load : Load {
            attribute mass : MassValue = 100;
            attribute weight : ForceValue = mass * 9.81;
            attribute rampAngle : AngleValue = ramp.angle;
            attribute rampLength : LengthValue = ramp.length;
            attribute frictionForce : ForceValue = ramp.frictionForce;
        }
        
        part ramp : InclinedPlane {
            attribute length : LengthValue = 5.0;
            attribute height : LengthValue = 1.0;
            attribute angle : AngleValue = asin(height / length);
            attribute frictionCoefficient : CoefficientValue = 0.1;
            attribute normalForce : ForceValue = load.weight * cos(angle);
            attribute frictionForce : ForceValue = frictionCoefficient * normalForce;
        }
        
        part operator : Operator {
            attribute maxForce : ForceValue = 500.0;
            attribute appliedForce : ForceValue = 300.0;
        }
        
        connection operatorToLoad {
            operator.outputPort.appliedForce = load.inputPort.appliedForce;
        }
        
        satisfy MechanicalAdvantage {
            requiredEffortForce = operator.appliedForce;
            verticalLiftForce = load.weight;
        }
        
        satisfy SafetyConstraints {
            operatorMaxForce = operator.maxForce;
            appliedForce = operator.appliedForce;
            rampAngle = ramp.angle;
            staticFrictionCoefficient = ramp.frictionCoefficient;
        }
    }
}
