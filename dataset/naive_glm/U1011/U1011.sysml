package RockClimbingSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    value def Mass :> Real { unit 'kg'; }
    value def Force :> Real { unit 'N'; }
    value def Length :> Real { unit 'm'; }
    value def Angle :> Real { unit 'deg'; }
    value def Friction :> Real { unit '1'; }
    value def Energy :> Real { unit 'J'; }
    value def Tension :> Real { unit 'N'; }
    value def StaminaLevel :> Real { unit '1'; }
    value def Quality :> Real { unit '1'; }

    item def GripForce {
        attribute magnitude : Force;
    }
    item def RopeTension {
        attribute magnitude : Tension;
    }
    
    part def Climber {
        attribute mass : Mass;
        attribute maxGripStrength : Force;
        attribute reach : Length;
        attribute stamina : StaminaLevel;
        attribute currentHeight : Length;
        
        port def GripPort {
            out gripForce : GripForce;
        }
        port def SafetyPort {
            out climberWeight : Mass;
        }
        
        port gripPort : GripPort;
        port safetyPort : SafetyPort;
        
        state machine ClimberBehavior {
            state Preparation;
            state ActiveClimbing;
            state Resting;
            state Descending;
            state Emergency;
            
            transition prep_to_active
                from Preparation to ActiveClimbing
                when startClimb;
                
            transition active_to_rest
                from ActiveClimbing to Resting
                when stamina < 0.3;
                
            transition rest_to_active
                from Resting to ActiveClimbing
                when stamina > 0.7;
                
            transition active_to_emergency
                from ActiveClimbing to Emergency
                when stamina < 0.1 or gripStability == false;
                
            transition active_to_descending
                from ActiveClimbing to Descending
                when reachedTop;
        }
        
        action EvaluateNextHold {
            in wall : ClimbingWall;
            in currentStamina : StaminaLevel;
            out targetHold : Hold;
        }
        
        action ExecuteMove {
            in targetHold : Hold;
            in out stamina : StaminaLevel;
            out heightGained : Length;
        }
    }

    part def Hold {
        attribute location : Length[2];
        attribute quality : Quality;
        attribute maxLoadCapacity : Force;
    }

    part def Route {
        attribute name : String;
        part holds : Hold[*];
    }

    part def ClimbingWall {
        attribute height : Length;
        attribute angle : Angle;
        attribute surfaceFriction : Friction;
        part routes : Route[*];
        
        port def HoldInterface {
            in appliedForce : GripForce;
        }
        
        port holdInterface : HoldInterface;
    }

    part def Harness {
        attribute weightCapacity : Mass;
        
        port def AttachmentPort {
            in climberWeight : Mass;
            out ropeAttachment : Force;
        }
        
        port attachmentPort : AttachmentPort;
    }

    part def SafetyRope {
        attribute length : Length;
        attribute diameter : Length;
        attribute maxTensileStrength : Force;
        attribute stretchCoefficient : Real;
        
        port def ClimberEnd {
            in harnessForce : Force;
        }
        port def BelayEnd {
            out ropeTension : RopeTension;
        }
        
        port climberEnd : ClimberEnd;
        port belayEnd : BelayEnd;
    }

    part def BelaySystem {
        attribute frictionCoefficient : Real;
        
        port def BelayPort {
            in ropeTension : RopeTension;
            out lockOff : Boolean;
        }
        
        port belayPort : BelayPort;
    }

    part def SafetySystem {
        part harness : Harness;
        part rope : SafetyRope;
        part belay : BelaySystem;
        
        connect harness.attachmentPort.ropeAttachment to rope.climberEnd.harnessForce;
        connect rope.belayEnd.ropeTension to belay.belayPort.ropeTension;
    }

    part def RockClimbingSystem {
        part climber : Climber;
        part wall : ClimbingWall;
        part safetySystem : SafetySystem;
        
        connect climber.gripPort.gripForce to wall.holdInterface.appliedForce;
        connect climber.safetyPort.climberWeight to safetySystem.harness.attachmentPort.climberWeight;
        
        action ClimbSequence {
            action evaluateHold : Climber.EvaluateNextHold {
                in wall = wall;
                in currentStamina = climber.stamina;
            }
            action executeMove : Climber.ExecuteMove {
                in targetHold = evaluateHold.targetHold;
                in out stamina = climber.stamina;
            }
        }
        
        action SafetyMonitoring {
            in ropeTension : Tension;
            in climberStamina : StaminaLevel;
            in gripStability : Boolean;
            out abortClimb : Boolean;
        }
    }

    requirement def SafetyRequirement {
        subject sys : RockClimbingSystem;
        objective {
            doc "The safety system must arrest a fall before the climber hits the ground."
            require sys.safetySystem.rope.maxTensileStrength > sys.climber.mass * 9.81 * 10;
        }
    }
    
    requirement def StaminaRequirement {
        subject c : Climber;
        objective {
            doc "The climber must maintain stamina above critical levels during active climbing."
            require c.stamina > 0.1;
        }
    }
}
