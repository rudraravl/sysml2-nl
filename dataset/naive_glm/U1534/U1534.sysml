package WheelAxleLiftingSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def InputForce :> Real { unit = "N"; }
    value def OutputForce :> Real { unit = "N"; }
    value def LoadMass :> Real { unit = "kg"; }
    value def Radius :> Real { unit = "m"; }
    value def Diameter :> Real { unit = "m"; }
    value def TorqueValue :> Real { unit = "N*m"; }
    value def LinearVelocity :> Real { unit = "m/s"; }
    value def AngularVelocity :> Real { unit = "rad/s"; }
    value def Height :> Real { unit = "m"; }
    value def MechanicalAdvantage :> Real { unit = "1"; }
    value def EfficiencyValue :> Real { unit = "1"; }

    // ---- Item definitions ----
    item def ForceFlow {
        attribute magnitude : InputForce;
    }
    item def LiftFlow {
        attribute magnitude : OutputForce;
    }

    // ---- Requirements ----
    requirement def ForceMultiplicationRequirement {
        attribute minAdvantage : MechanicalAdvantage = 5.0;
        requirement {
            subject system : WheelAxleSystem;
            doc /* The system shall magnify the input force by at least five times. */
        }
    }

    requirement def LoadCapacityRequirement {
        attribute maxLoad : LoadMass = 100.0;
        requirement {
            subject system : WheelAxleSystem;
            doc /* The system shall be capable of lifting loads up to 100 kilograms. */
        }
    }

    requirement def EfficiencyRequirement {
        attribute minEfficiency : EfficiencyValue = 0.85;
        requirement {
            subject system : WheelAxleSystem;
            doc /* The system shall operate with at least 85% efficiency. */
        }
    }

    requirement def LiftingSystemRequirements {
        requirement forceMultiplication : ForceMultiplicationRequirement;
        requirement loadCapacity : LoadCapacityRequirement;
        requirement efficiency : EfficiencyRequirement;
    }

    // ---- Port definitions ----
    port def ForceInputPort {
        in item force : ForceFlow;
    }
    port def ForceOutputPort {
        out item lift : LiftFlow;
    }
    port def RotationalPort {
        attribute torque : TorqueValue;
        attribute omega : AngularVelocity;
    }

    // ---- Part definitions ----
    part def Wheel {
        attribute wheelRadius : Radius = 0.50;
        attribute wheelDiameter : Diameter = 1.00;
        port in inputPort : ForceInputPort;
        port out shaftPort : RotationalPort;

        action applyInputForce {
            in force : InputForce;
            out torque : TorqueValue;
        }
    }

    part def Axle {
        attribute axleRadius : Radius = 0.10;
        attribute axleDiameter : Diameter = 0.20;
        port in shaftPort : RotationalPort;
        port out liftPort : ForceOutputPort;

        action transmitTorque {
            in torque : TorqueValue;
            out liftForce : OutputForce;
        }
    }

    part def Cable {
        attribute length : Height = 2.00;
        attribute tensileStrength : OutputForce = 1500.0;
        attribute currentHeight : Height = 0.0;
    }

    part def Load {
        attribute mass : LoadMass = 75.0;
        attribute weight : OutputForce = 735.5;
        attribute currentHeight : Height = 0.0;
        port in liftPort : ForceOutputPort;
    }

    part def Operator {
        attribute appliedForce : InputForce = 150.0;
        action applyForce {
            out force : ForceFlow;
        }
    }

    // ---- System ----
    part def WheelAxleSystem {
        attribute mechanicalAdvantage : MechanicalAdvantage = 5.0;
        attribute efficiency : EfficiencyValue = 0.90;
        attribute maxLoad : LoadMass = 100.0;

        port in operatorPort : ForceInputPort;
        port out loadPort : ForceOutputPort;

        part wheel : Wheel {
            attribute wheelRadius = 0.50;
        }
        part axle : Axle {
            attribute axleRadius = 0.10;
        }
        part cable : Cable;
        part load : Load {
            attribute mass = 75.0;
        }
        part operator : Operator;

        connection operatorToWheel connect operator.applyForce.force to wheel.inputPort.force;
        connection wheelToAxle connect wheel.shaftPort to axle.shaftPort;
        connection axleToCable connect axle.liftPort.lift to load.liftPort.lift;

        // ---- Behavior: state machine ----
        state def LiftingStateMachine {
            entry action initialize { /* reset system to idle */ }

            state idle {
                entry { /* system at rest, no force applied */ }
            }
            state engaged {
                entry { /* operator begins applying force */ }
            }
            state lifting {
                entry { /* cable winding, load rising */ }
                do action raiseLoad {
                    in load : Load;
                    in cable : Cable;
                    out height : Height;
                }
            }
            state holding {
                entry { /* load held stationary at height */ }
            }

            transition idle_to_engaged
                first idle
                then engaged
                when operator.appliedForce > 0.0;

            transition engaged_to_lifting
                first engaged
                then lifting
                when axle.liftPort.lift.magnitude >= load.weight;

            transition lifting_to_holding
                first lifting
                then holding
                when operator.appliedForce == 0.0;

            transition holding_to_lifting
                first holding
                then lifting
                when operator.appliedForce > 0.0;

            transition holding_to_idle
                first holding
                then idle
                when load.currentHeight == 0.0;
        }

        // ---- Actions ----
        action computeTorque {
            in inputForce : InputForce;
            in wheelRadius : Radius;
            out torque : TorqueValue;
        }
        action computeLiftForce {
            in torque : TorqueValue;
            in axleRadius : Radius;
            in efficiency : EfficiencyValue;
            out liftForce : OutputForce;
        }
        action computeAdvantage {
            in wheelRadius : Radius;
            in axleRadius : Radius;
            out advantage : MechanicalAdvantage;
        }

        // ---- Requirements satisfaction ----
        satisfy forceMultiplicationRequirement by system;
        satisfy loadCapacityRequirement by system;
        satisfy efficiencyRequirement by system;
    }

    part system : WheelAxleSystem {
        part redef wheel;
        part redef axle;
        part redef cable;
        part redef load;
        part redef operator;
    }

    // ---- Example usage binding ----
    part def LiftingScenario {
        part subjectSystem : WheelAxleSystem;
        assert requirement liftingRequirements : LiftingSystemRequirements {
            subject = subjectSystem;
        }
    }
}
