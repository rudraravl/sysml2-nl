package RockClimbingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    /* Value Type Definitions */
    attribute def GripStrengthValue :> ForceValue;
    attribute def StaminaValue :> Real;
    attribute def ReachValue :> LengthValue;
    attribute def HoldQualityValue :> Real;
    attribute def LoadCapacityValue :> ForceValue;
    attribute def RopeTensionValue :> ForceValue;
    attribute def FrictionCoefficientValue :> Real;
    attribute def StretchCoefficientValue :> Real;
    
    /* Item Definitions for Signals */
    item def StartClimbSignal;
    item def HoldSelectedSignal {
        attribute selectedHoldIndex : Integer;
    }
    item def GripSecuredSignal {
        attribute isStable : Boolean;
    }
    item def MoveCompleteSignal {
        attribute heightGained : LengthValue;
    }
    item def RestSignal;
    item def ResumeClimbSignal;
    item def CompleteClimbSignal;
    item def EmergencySignal;
    item def AbortClimbSignal;
    item def GroundReachedSignal;
    item def LockSignal;
    item def UnlockSignal;
    
    /* Port Definitions */
    port def ForcePort {
        in appliedForce : ForceValue;
        out reactionForce : ForceValue;
    }
    
    port def HarnessPort {
        in bodyWeight : ForceValue;
        out ropeTension : ForceValue;
    }
    
    port def RopePort {
        in tension : ForceValue;
        out extension : LengthValue;
    }
    
    port def ControlPort {
        in lockCommand : Boolean;
        out status : String;
    }
    
    /* Part Definitions */
    part def Hold {
        attribute position : LengthValue[2];
        attribute quality : HoldQualityValue;
        attribute maxLoadCapacity : LoadCapacityValue;
        
        port contactPort : ForcePort;
    }
    
    part def Route {
        part holds : Hold[*];
    }
    
    part def ClimbingWall {
        attribute height : LengthValue;
        attribute angle : PlaneAngleValue;
        attribute surfaceFriction : FrictionCoefficientValue;
        
        part route : Route;
        
        port climberContactPort : ForcePort;
    }
    
    part def Climber {
        attribute bodyMass : MassValue;
        attribute maxGripStrength : GripStrengthValue;
        attribute reach : ReachValue;
        attribute currentStamina : StaminaValue;
        attribute currentPosition : LengthValue;
        
        port wallContactPort : ForcePort;
        port safetyAttachmentPort : HarnessPort;
        
        action evaluateNextHold {
            in availableHolds : Hold[*];
            in currentStamina : StaminaValue;
            in reach : ReachValue;
            in currentPosition : LengthValue;
            out selectedHold : Hold;
            out isFeasible : Boolean;
            
            language "Alf"
            /*
             * selectedHold = null;
             * isFeasible = false;
             * for (hold in availableHolds) {
             *     if (hold.position[1] <= currentPosition + reach && currentStamina > 0.1) {
             *         selectedHold = hold;
             *         isFeasible = true;
             *         break;
             *     }
             * }
             */
        }
        
        action secureGrip {
            in targetHold : Hold;
            in maxGrip : GripStrengthValue;
            out gripStability : Real;
            out energyCost : EnergyValue;
            
            language "Alf"
            /*
             * gripStability = targetHold.quality * (maxGrip / targetHold.maxLoadCapacity);
             * energyCost = 50.0 * (1.0 - gripStability);
             */
        }
        
        action executeMove {
            in targetHold : Hold;
            in energyCost : EnergyValue;
            in currentPosition : LengthValue;
            out heightGained : LengthValue;
            out newStamina : StaminaValue;
            
            language "Alf"
            /*
             * heightGained = targetHold.position[1] - currentPosition;
             * newStamina = currentStamina - (energyCost / 1000.0);
             */
        }
        
        exhibit state climberStates {
            entry; then preparation;
            
            state preparation;
            transition prep_to_active
                first preparation
                accept StartClimbSignal
                then activeClimbing;
            
            state activeClimbing {
                entry; then evaluating;
                
                state evaluating;
                transition eval_to_grip
                    first evaluating
                    accept HoldSelectedSignal
                    then gripping;
                
                state gripping;
                transition grip_to_move
                    first gripping
                    accept GripSecuredSignal
                    then moving;
                
                state moving;
                transition move_to_eval
                    first moving
                    accept MoveCompleteSignal
                    then evaluating;
            }
            
            transition active_to_rest
                first activeClimbing
                accept RestSignal
                then resting;
            
            state resting;
            transition rest_to_active
                first resting
                accept ResumeClimbSignal
                then activeClimbing;
            
            transition active_to_descend
                first activeClimbing
                accept CompleteClimbSignal
                then descending;
            
            state descending;
            transition descend_to_prep
                first descending
                accept GroundReachedSignal
                then preparation;
            
            transition active_to_emergency
                first activeClimbing
                accept EmergencySignal
                then emergency;
            
            transition rest_to_emergency
                first resting
                accept EmergencySignal
                then emergency;
            
            state emergency;
            transition emergency_to_descend
                first emergency
                accept AbortClimbSignal
                then descending;
        }
    }
    
    part def Harness {
        attribute maxLoadCapacity : LoadCapacityValue;
        attribute weightDistributionFactor : Real;
        
        port climberAttachmentPort : HarnessPort;
        port ropeAttachmentPort : RopePort;
        
        action distributeLoad {
            in climberForce : ForceValue;
            in distributionFactor : Real;
            out ropeForce : ForceValue;
            
            language "Alf"
            /*
             * ropeForce = climberForce * distributionFactor;
             */
        }
    }
    
    part def SafetyRope {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        attribute maxTensileStrength : ForceValue;
        attribute stretchCoefficient : StretchCoefficientValue;
        attribute currentTension : RopeTensionValue;
        
        port harnessEndPort : RopePort;
        port belayEndPort : RopePort;
        
        action absorbFallEnergy {
            in fallForce : ForceValue;
            in ropeLength : LengthValue;
            in stretchCoeff : StretchCoefficientValue;
            out absorbedEnergy : EnergyValue;
            out peakTension : RopeTensionValue;
            
            language "Alf"
            /*
             * peakTension = fallForce;
             * absorbedEnergy = 0.5 * stretchCoeff * ropeLength * fallForce;
             */
        }
    }
    
    part def BelaySystem {
        attribute frictionCoefficient : FrictionCoefficientValue;
        attribute maxHoldingForce : ForceValue;
        attribute isLocked : Boolean;
        
        port ropePort : RopePort;
        port controlPort : ControlPort;
        
        exhibit state belayStates {
            entry; then unlocked;
            
            state unlocked;
            transition unlock_to_lock
                first unlocked
                accept LockSignal
                then locked;
            
            state locked;
            transition lock_to_unlock
                first locked
                accept UnlockSignal
                then unlocked;
        }
        
        action controlRope {
            in inputForce : ForceValue;
            in isLocked : Boolean;
            in frictionCoeff : FrictionCoefficientValue;
            in maxHoldForce : ForceValue;
            out outputForce : ForceValue;
            
            language "Alf"
            /*
             * if (isLocked) {
             *     outputForce = Math.min(inputForce, maxHoldForce);
             * } else {
             *     outputForce = inputForce * (1.0 - frictionCoeff);
             * }
             */
        }
    }
    
    part def SafetySystem {
        part harness : Harness;
        part rope : SafetyRope;
        part belay : BelaySystem;
        
        port climberConnectionPort : HarnessPort;
        
        connection harnessToRope connect harness.ropeAttachmentPort to rope.harnessEndPort;
        connection ropeToBelay connect rope.belayEndPort to belay.ropePort;
    }
    
    /* System Assembly */
    part def ClimbingContext {
        part climber : Climber;
        part wall : ClimbingWall;
        part safetySystem : SafetySystem;
        
        connection climberToWall connect climber.wallContactPort to wall.climberContactPort;
        connection climberToSafety connect climber.safetyAttachmentPort to safetySystem.climberConnectionPort;
        
        action monitorSafety {
            in ropeTension : RopeTensionValue;
            in climberStamina : StaminaValue;
            in gripStability : Real;
            in maxTensile : ForceValue;
            out isSafe : Boolean;
            out abortSignal : Boolean;
            
            language "Alf"
            /*
             * isSafe = (ropeTension < maxTensile * 0.5) && (climberStamina > 0.1) && (gripStability > 0.3);
             * abortSignal = !isSafe;
             */
        }
        
        action performClimbSequence {
            in route : Route;
            inout climber : Climber;
            inout safetySystem : SafetySystem;
            out climbResult : String;
            
            language "Alf"
            /*
             * climbResult = "SUCCESS";
             * for (hold in route.holds) {
             *     // Evaluate and select hold
             *     // Secure grip
             *     // Execute move
             *     // Monitor safety
             *     if (abortSignal) {
             *         climbResult = "ABORTED";
             *         break;
             *     }
             * }
             */
        }
    }
    
    /* Requirement Definitions */
    requirement def SafetyRequirement {
        doc /* The safety system must prevent rope failure during a fall. */
        subject safetySystem : SafetySystem;
        attribute maxFallForce : ForceValue;
        require constraint {
            safetySystem.rope.maxTensileStrength > maxFallForce
        }
    }
    
    requirement def StaminaRequirement {
        doc /* The climber must maintain sufficient stamina to complete the route. */
        subject climber : Climber;
        attribute minStamina : StaminaValue = 0.1;
        require constraint {
            climber.currentStamina >= minStamina
        }
    }
    
    requirement def HoldStrengthRequirement {
        doc /* Each hold must support at least 1.5 times the climber's body weight. */
        subject climbingContext : ClimbingContext;
        attribute minRequiredHoldCapacity : ForceValue;
        require constraint {
            minRequiredHoldCapacity >= 1.5 * climbingContext.climber.bodyMass * 9.81 [m/s^2]
        }
    }
    
    requirement def RopeLengthRequirement {
        doc /* The rope must be at least as long as the wall height. */
        subject climbingContext : ClimbingContext;
        require constraint {
            climbingContext.safetySystem.rope.length >= climbingContext.wall.height
        }
    }
    
    /* Analysis Definition */
    analysis def ClimbingAnalysis {
        subject climbingContext : ClimbingContext;
        
        requirement safetyReq : SafetyRequirement;
        requirement staminaReq : StaminaRequirement;
        requirement holdStrengthReq : HoldStrengthRequirement;
        requirement ropeLengthReq : RopeLengthRequirement;
        
        objective climbingAnalysisObjective {
            doc /* Verify that the climbing system meets all safety and performance requirements. */
            
            assume constraint {
                climbingContext.climber.bodyMass == 70 [kg] &
                climbingContext.climber.maxGripStrength == 500 [N] &
                climbingContext.climber.reach == 2.0 [m] &
                climbingContext.wall.height == 15 [m] &
                climbingContext.safetySystem.rope.maxTensileStrength == 22000 [N]
            }
            
            require constraint {
                climbingContext.safetySystem.rope.maxTensileStrength > 
                    10 * climbingContext.climber.bodyMass * 9.81 [m/s^2] &
                climbingContext.climber.currentStamina >= 0.1
            }
        }
        
        action simulateClimb {
            in route : Route = climbingContext.wall.route;
            out finalPosition : LengthValue;
            out staminaRemaining : StaminaValue;
            out climbSuccessful : Boolean;
            
            language "Alf"
            /*
             * finalPosition = 0.0;
             * staminaRemaining = 1.0;
             * climbSuccessful = true;
             * for (hold in route.holds) {
             *     if (staminaRemaining < 0.1) {
             *         climbSuccessful = false;
             *         break;
             *     }
             *     finalPosition = hold.position[1];
             *     staminaRemaining = staminaRemaining - 0.05;
             * }
             */
        }
        
        return analysisResult : Boolean = simulateClimb.climbSuccessful;
    }
    
    /* Instance */
    part climbingContext_Instance : ClimbingContext {
        part :>> climber {
            attribute :>> bodyMass = 70 [kg];
            attribute :>> maxGripStrength = 500 [N];
            attribute :>> reach = 2.0 [m];
            attribute :>> currentStamina = 1.0;
            attribute :>> currentPosition = 0 [m];
        }
        
        part :>> wall {
            attribute :>> height = 15 [m];
            attribute :>> angle = 5 [deg];
            attribute :>> surfaceFriction = 0.7;
            
            part :>> route {
                part hold1 : holds {
                    attribute :>> position = (0 [m], 1.5 [m]);
                    attribute :>> quality = 0.9;
                    attribute :>> maxLoadCapacity = 2000 [N];
                }
                part hold2 : holds {
                    attribute :>> position = (0.3 [m], 3.0 [m]);
                    attribute :>> quality = 0.8;
                    attribute :>> maxLoadCapacity = 1500 [N];
                }
                part hold3 : holds {
                    attribute :>> position = (-0.2 [m], 4.5 [m]);
                    attribute :>> quality = 0.7;
                    attribute :>> maxLoadCapacity = 1800 [N];
                }
                part hold4 : holds {
                    attribute :>> position = (0.1 [m], 6.0 [m]);
                    attribute :>> quality = 0.85;
                    attribute :>> maxLoadCapacity = 2000 [N];
                }
                part hold5 : holds {
                    attribute :>> position = (0.4 [m], 7.5 [m]);
                    attribute :>> quality = 0.75;
                    attribute :>> maxLoadCapacity = 1600 [N];
                }
            }
        }
        
        part :>> safetySystem {
            part :>> harness {
                attribute :>> maxLoadCapacity = 2500 [N];
                attribute :>> weightDistributionFactor = 1.0;
            }
            part :>> rope {
                attribute :>> length = 50 [m];
                attribute :>> diameter = 0.01 [m];
                attribute :>> maxTensileStrength = 22000 [N];
                attribute :>> stretchCoefficient = 0.01;
                attribute :>> currentTension = 0 [N];
            }
            part :>> belay {
                attribute :>> frictionCoefficient = 0.3;
                attribute :>> maxHoldingForce = 10000 [N];
                attribute :>> isLocked = false;
            }
        }
    }
}
