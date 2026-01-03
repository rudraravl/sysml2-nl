package ClimberSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ClimbingState;
    attribute def SafetyAlert;
    attribute def HoldQuality;
    
    attribute def GripForce :> ISQ::ForceValue {
        doc /* Force exerted by climber's grip on hold */
    }
    
    attribute def StaminaLevel :> ScalarValues::Real {
        doc /* Remaining energy as percentage of maximum capacity */
    }
    
    attribute def WallAngle :> ISQ::AngleValue {
        doc /* Inclination angle of climbing surface from vertical */
    }
    
    attribute def AnchorTension :> ISQ::ForceValue {
        doc /* Tension force in safety rope at anchor point */
    }
    
    attribute def ReachDistance :> ISQ::LengthValue {
        doc /* Distance climber can extend to next hold */
    }
    
    item def HoldPosition {
        attribute height : LengthValue;
        attribute lateralOffset : LengthValue;
        attribute quality : HoldQuality;
        attribute maxLoad : ForceValue;
    }
    
    item def RouteSegment {
        attribute startHeight : LengthValue;
        attribute endHeight : LengthValue;
        attribute difficulty : Real;
        attribute holds : HoldPosition[*];
    }
    
    part def Climber {
        doc /* Human climber ascending vertical or near-vertical surfaces */
        
        attribute bodyMass : MassValue;
        attribute maxGripForce : GripForce;
        attribute currentStamina : StaminaLevel;
        attribute currentHeight : LengthValue;
        attribute reachRange : ReachDistance;
        
        port physicalContact {
            out gripForce : ForceValue;
            in supportReaction : ForceValue;
        }
        
        port safetyLink {
            out bodyWeight : ForceValue;
            in ropeTension : AnchorTension;
            out emergencySignal : SafetyAlert;
        }
    }
    
    part def ClimbingWall {
        doc /* Vertical surface with holds for climbing */
        
        attribute wallHeight : LengthValue;
        attribute wallAngle : WallAngle;
        attribute surfaceFriction : Real;
        attribute numberOfRoutes : Integer;
        
        port surfaceContact {
            in appliedForce : ForceValue;
            out normalForce : ForceValue;
        }
    }
    
    part def SafetyRope {
        doc /* Dynamic rope providing fall protection */
        
        attribute ropeLength : LengthValue;
        attribute ropeDiameter : LengthValue;
        attribute maxTensileLoad : ForceValue;
        attribute currentTension : AnchorTension;
        attribute elongation : LengthValue;
        
        port climberEnd {
            in climberLoad : ForceValue;
            out tensionFeedback : AnchorTension;
        }
        
        port belayEnd {
            out transmittedLoad : ForceValue;
        }
    }
    
    part def BelaySystem {
        doc /* Friction device controlling rope for climber protection */
        
        attribute frictionCoefficient : Real;
        attribute lockingEngaged : Boolean;
        attribute slackManaged : LengthValue;
        
        port ropeInput {
            in incomingTension : ForceValue;
        }
        
        port ropeOutput {
            out controlledTension : ForceValue;
        }
    }
    
    part def Harness {
        doc /* Wearable equipment connecting climber to rope */
        
        attribute loadCapacity : ForceValue;
        attribute attachmentPoints : Integer;
        
        port climberAttachment {
            in distributedLoad : ForceValue;
        }
        
        port ropeAttachment {
            out transferredLoad : ForceValue;
        }
    }
    
    action def EvaluateNextHold {
        in currentPosition : LengthValue;
        in availableHolds : HoldPosition[*];
        in reachCapability : ReachDistance;
        in currentStamina : StaminaLevel;
        out selectedHold : HoldPosition;
        out moveViable : Boolean;
    }
    
    action def ExecuteMove {
        in targetHold : HoldPosition;
        in requiredGrip : GripForce;
        in climberMass : MassValue;
        out moveCompleted : Boolean;
        out staminaConsumed : StaminaLevel;
        out newHeight : LengthValue;
    }
    
    action def SecureGrip {
        in holdCapacity : ForceValue;
        in appliedGripForce : GripForce;
        in surfaceFriction : Real;
        out gripStable : Boolean;
        out slipRisk : Real;
    }
    
    action def ManageRope {
        in climberHeight : LengthValue;
        in climbingVelocity : SpeedValue;
        out slackAdjusted : LengthValue;
        out tensionControlled : AnchorTension;
    }
    
    action def MonitorSafety {
        in ropeTension : AnchorTension;
        in maxRopeLoad : ForceValue;
        in climberStamina : StaminaLevel;
        in gripStability : Boolean;
        out safetyStatus : SafetyAlert;
        out continueClimb : Boolean;
    }
    
    action def AscendRoute {
        doc /* Primary climbing action: ascend from base to top of route */
        
        in route : RouteSegment;
        in climberMass : MassValue;
        in initialStamina : StaminaLevel;
        in maxGripCapability : GripForce;
        out finalHeight : LengthValue;
        out ascentSuccessful : Boolean;
        out remainingStamina : StaminaLevel;
        
        private attribute currentHeight := route.startHeight;
        private attribute stamina := initialStamina;
        private attribute safetyOK : Boolean := true;
        
        first start;
        then merge climbingLoop;
        
        then action checkSafety : MonitorSafety {
            in ropeTension;
            in maxRopeLoad;
            in climberStamina = stamina;
            in gripStability;
            out safetyStatus;
            out continueClimb;
        }
        
        then decide;
            if checkSafety.continueClimb and currentHeight < route.endHeight and stamina > 15.0 
                then progressUpward;
            if not checkSafety.continueClimb or stamina <= 15.0 
                then abortAscent;
            if currentHeight >= route.endHeight 
                then reachTop;
        
        action progressUpward {
            action evaluateHold : EvaluateNextHold {
                in currentPosition = currentHeight;
                in availableHolds = route.holds;
                in reachCapability;
                in currentStamina = stamina;
                out selectedHold;
                out moveViable;
            }
            
            then decide;
                if evaluateHold.moveViable then attemptMove;
                if not evaluateHold.moveViable then searchAlternative;
            
            action attemptMove {
                action secureGrip : SecureGrip {
                    in holdCapacity = evaluateHold.selectedHold.maxLoad;
                    in appliedGripForce = maxGripCapability;
                    in surfaceFriction;
                    out gripStable;
                    out slipRisk;
                }
                
                then action manageRope : ManageRope {
                    in climberHeight = currentHeight;
                    in climbingVelocity;
                    out slackAdjusted;
                    out tensionControlled;
                }
                
                then action executeMove : ExecuteMove {
                    in targetHold = evaluateHold.selectedHold;
                    in requiredGrip = maxGripCapability;
                    in climberMass;
                    out moveCompleted;
                    out staminaConsumed;
                    out newHeight;
                }
                
                then assign currentHeight := executeMove.newHeight;
                then assign stamina := stamina - executeMove.staminaConsumed;
            }
            then climbingLoop;
            
            action searchAlternative;
            then climbingLoop;
        }
        
        action abortAscent;
        then assign ascentSuccessful := false;
        then assign finalHeight := currentHeight;
        then assign remainingStamina := stamina;
        then complete;
        
        action reachTop;
        then assign ascentSuccessful := true;
        then assign finalHeight := currentHeight;
        then assign remainingStamina := stamina;
        then complete;
        
        action complete;
        then done;
    }
    
    state machine ClimberStateMachine {
        entry; then Preparation;
        
        state Preparation;
        transition Preparation to ActiveClimbing;
        
        state ActiveClimbing;
        transition ActiveClimbing to Resting;
        transition ActiveClimbing to Descending;
        transition ActiveClimbing to Emergency;
        
        state Resting;
        transition Resting to ActiveClimbing;
        
        state Emergency;
        transition Emergency to Descending;
        
        state Descending;
        transition Descending to done;
    }
    
    part climbingSystem {
        doc /* Integrated climbing system for vertical ascent */
        
        part athlete : Climber {
            attribute :>> bodyMass = 72.0 [SI::kg];
            attribute :>> maxGripForce = 450.0 [SI::N];
            attribute :>> currentStamina = 100.0;
            attribute :>> currentHeight = 0.0 [SI::m];
            attribute :>> reachRange = 0.65 [SI::m];
        }
        
        part wall : ClimbingWall {
            attribute :>> wallHeight = 15.0 [SI::m];
            attribute :>> wallAngle = 95.0 [SI::deg];
            attribute :>> surfaceFriction = 0.55;
            attribute :>> numberOfRoutes = 8;
        }
        
        part rope : SafetyRope {
            attribute :>> ropeLength = 50.0 [SI::m];
            attribute :>> ropeDiameter = 0.0098 [SI::m];
            attribute :>> maxTensileLoad = 2400.0 [SI::N];
            attribute :>> currentTension = 0.0 [SI::N];
            attribute :>> elongation = 0.0 [SI::m];
        }
        
        part belay : BelaySystem {
            attribute :>> frictionCoefficient = 0.85;
            attribute :>> lockingEngaged = false;
            attribute :>> slackManaged = 0.5 [SI::m];
        }
        
        part harness : Harness {
            attribute :>> loadCapacity = 1500.0 [SI::N];
            attribute :>> attachmentPoints = 2;
        }
        
        connect athlete.physicalContact.gripForce to wall.surfaceContact.appliedForce;
        connect wall.surfaceContact.normalForce to athlete.physicalContact.supportReaction;
        connect athlete.safetyLink.bodyWeight to harness.climberAttachment.distributedLoad;
        connect harness.ropeAttachment.transferredLoad to rope.climberEnd.climberLoad;
        connect rope.climberEnd.tensionFeedback to athlete.safetyLink.ropeTension;
        connect rope.belayEnd.transmittedLoad to belay.ropeInput.incomingTension;
        
        perform action climbingMission : AscendRoute {
            in route : RouteSegment {
                attribute :>> startHeight = 0.0 [SI::m];
                attribute :>> endHeight = wall.wallHeight;
                attribute :>> difficulty = 5.8;
            }
            in climberMass = athlete.bodyMass;
            in initialStamina = athlete.currentStamina;
            in maxGripCapability = athlete.maxGripForce;
            out finalHeight;
            out ascentSuccessful;
            out remainingStamina;
        }
        
        perform action stateBehavior : ClimberStateMachine;
    }
    
    requirement def SafetyLoadRequirement {
        doc /* Rope system must withstand maximum expected loads with safety margin */
        
        subject safetyRope : SafetyRope;
        
        require constraint {
            safetyRope.currentTension < safetyRope.maxTensileLoad * 0.7
        }
    }
    
    requirement def StaminaManagementRequirement {
        doc /* Climber must maintain minimum stamina reserve for safe descent */
        
        subject climber : Climber;
        
        require constraint {
            climber.currentStamina >= 20.0
        }
    }
    
    requirement def GripSecurityRequirement {
        doc /* Applied grip force must exceed minimum threshold for hold stability */
        
        subject climber : Climber;
        
        require constraint {
            climber.maxGripForce >= 300.0 [SI::N]
        }
    }
    
    requirement <'CLM-SYS-001'> primaryAscentMission {
        doc /* The climber system shall enable safe vertical ascent of climbing routes through coordinated physical effort and safety equipment */
        
        subject system : climbingSystem;
        
        assume constraint validRoute {
            system.wall.wallHeight >= 5.0 [SI::m] and
            system.wall.wallHeight <= 30.0 [SI::m] and
            system.wall.wallAngle >= 75.0 [SI::deg] and
            system.wall.wallAngle <= 105.0 [SI::deg]
        }
        
        assume constraint climberCapability {
            system.athlete.bodyMass >= 50.0 [SI::kg] and
            system.athlete.bodyMass <= 100.0 [SI::kg] and
            system.athlete.currentStamina >= 60.0
        }
        
        require constraint safetyEquipmentRated {
            system.rope.maxTensileLoad >= 2000.0 [SI::N] and
            system.harness.loadCapacity >= 1200.0 [SI::N]
        }
        
        require constraint performanceCapability {
            system.athlete.maxGripForce >= 350.0 [SI::N] and
            system.athlete.reachRange >= 0.5 [SI::m]
        }
        
        require safetyLoad : SafetyLoadRequirement {
            subject safetyRope = system.rope;
        }
        
        require staminaReserve : StaminaManagementRequirement {
            subject climber = system.athlete;
        }
        
        require gripSecurity : GripSecurityRequirement {
            subject climber = system.athlete;
        }
    }
}
