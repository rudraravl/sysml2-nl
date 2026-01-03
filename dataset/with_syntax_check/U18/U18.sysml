package CableRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CoordinateVector {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def VelocityVector {
        attribute vx : SpeedValue;
        attribute vy : SpeedValue;
        attribute vz : SpeedValue;
    }
    
    attribute def CableIdentifier :> String;
    
    attribute def CableTension :> ForceValue;
    attribute def CableLength :> LengthValue;
    attribute def WinchSpeed :> AngularVelocityValue;
    
    item def Payload {
        attribute mass : MassValue;
        attribute position : CoordinateVector;
        attribute velocity : VelocityVector;
        attribute targetPosition : CoordinateVector;
    }
    
    item def Cable {
        attribute id : CableIdentifier;
        attribute length : CableLength;
        attribute tension : CableTension;
        attribute maxTension : CableTension;
        attribute anchorPoint : CoordinateVector;
    }
    
    item def Winch {
        attribute id : CableIdentifier;
        attribute motorPower : PowerValue;
        attribute currentSpeed : WinchSpeed;
        attribute targetSpeed : WinchSpeed;
        attribute spoolRadius : LengthValue;
    }
    
    item def Controller {
        attribute controlFrequency : FrequencyValue;
        attribute positionTolerance : LengthValue;
    }
    
    attribute def MoveCommand;
    attribute def TargetReached;
    attribute def SafetyViolation;
    attribute def ReleasePayload;
    attribute def SystemReset;
    
    part def CableRobot {
        attribute numberOfCables : Integer;
        attribute workspaceVolume : VolumeValue;
        attribute maxPayload : MassValue;
        attribute positionAccuracy : LengthValue;
        attribute systemStatus : String;
        
        part payload : Payload;
        part cables : Cable[6];
        part winches : Winch[6];
        part controller : Controller;
        
        port commandInterface {
            in targetPos : CoordinateVector;
            out currentPos : CoordinateVector;
            out status : String;
        }
        
        port sensorInterface {
            out tensions : CableTension[6];
            out lengths : CableLength[6];
            out payloadPos : CoordinateVector;
        }
        
        connect cables to winches;
        connect cables to payload;
        connect controller to winches;
    }
    
    action def ComputeInverseKinematics {
        in desiredPosition : CoordinateVector;
        in anchorPoints : CoordinateVector[6];
        out targetLengths : CableLength[6];
    }
    
    action def ComputeTensionDistribution {
        in payloadMass : MassValue;
        in cableGeometry : CoordinateVector[6];
        in payloadAcceleration : AccelerationValue;
        out tensions : CableTension[6];
    }
    
    action def ControlWinch {
        in currentLength : CableLength;
        in targetLength : CableLength;
        in maxSpeed : WinchSpeed;
        out commandSpeed : WinchSpeed;
    }
    
    action def CheckTensionLimits {
        in currentTension : CableTension;
        in maxTension : CableTension;
        out withinLimits : Boolean;
    }
    
    action def MovePayloadToTarget {
        in targetPosition : CoordinateVector;
        in currentPosition : CoordinateVector;
        in payloadMass : MassValue;
        in anchorPoints : CoordinateVector[6];
        out finalPosition : CoordinateVector;
        
        first start;
        then merge controlLoop;
        
        then action kinematics : ComputeInverseKinematics {
            in desiredPosition = targetPosition;
            in anchorPoints = MovePayloadToTarget::anchorPoints;
            out targetLengths;
        }
        
        then action tensionCalc : ComputeTensionDistribution {
            in payloadMass = MovePayloadToTarget::payloadMass;
            in cableGeometry = MovePayloadToTarget::anchorPoints;
            in payloadAcceleration;
            out tensions;
        }
        
        then action checkTensions : CheckTensionLimits[6] {
            in currentTension;
            in maxTension;
            out withinLimits;
        }
        
        then decide;
            if checkTensions.withinLimits[0] == true and checkTensions.withinLimits[1] == true then adjustWinches;
            if checkTensions.withinLimits[0] == false or checkTensions.withinLimits[1] == false then emergencyStop;
        
        action adjustWinches {
            action controlWinches : ControlWinch[6] {
                in currentLength;
                in targetLength = kinematics.targetLengths;
                in maxSpeed;
                out commandSpeed;
            }
        }
        then verifyPosition;
        
        action verifyPosition {
            attribute positionReached : Boolean;
        }
        
        then decide;
            if verifyPosition.positionReached then completeMove;
            if not verifyPosition.positionReached then controlLoop;
        
        action emergencyStop;
        then done;
        
        action completeMove {
            assign finalPosition := targetPosition;
        }
        then done;
    }
    
    state def CableRobotOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign CableRobot::systemStatus := "Idle";
        }
        accept moveCmd : MoveCommand then positioning;
        
        state positioning {
            entry assign CableRobot::systemStatus := "Positioning";
            do action moveAction : MovePayloadToTarget;
        }
        accept targetReached : TargetReached then holding;
        accept safetyViolation : SafetyViolation then emergency;
        
        state holding {
            entry assign CableRobot::systemStatus := "Holding Position";
        }
        accept moveCmd2 : MoveCommand then positioning;
        accept releasePayload : ReleasePayload then idle;
        
        state emergency {
            entry assign CableRobot::systemStatus := "Emergency Stop";
        }
        accept systemReset : SystemReset then idle;
    }
    
    part cableRobotInstance : CableRobot {
        attribute :>> numberOfCables = 6;
        attribute :>> maxPayload = 100.0 [SI::kg];
        attribute :>> positionAccuracy = 0.002 [SI::m];
        attribute :>> workspaceVolume = 30.0 [SI::m^3];
        
        part :>> controller {
            attribute :>> controlFrequency = 100.0 [SI::Hz];
            attribute :>> positionTolerance = 0.002 [SI::m];
        }
        
        perform action primaryOperation : MovePayloadToTarget {
            in targetPosition;
            in currentPosition = cableRobotInstance.payload.position;
            in payloadMass = cableRobotInstance.payload.mass;
            in anchorPoints = cableRobotInstance.cables.anchorPoint;
            out finalPosition;
        }
        
        exhibit state operationalBehavior : CableRobotOperationalStates;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The cable robot shall position a payload at commanded 3D coordinates 
             within its workspace by coordinating multiple cables and winches. */
        
        subject robot : CableRobot;
    }
    
    requirement def PositioningAccuracyRequirement {
        doc /* The cable robot shall position the payload within the specified 
             accuracy tolerance of the target position. */
        
        subject robot : CableRobot;
        
        require constraint {
            robot.positionAccuracy <= 0.005 [SI::m]
        }
    }
    
    requirement def PayloadCapacityRequirement {
        doc /* The cable robot shall support and maneuver payloads up to the 
             maximum specified mass. */
        
        subject robot : CableRobot;
        
        require constraint {
            robot.payload.mass <= robot.maxPayload
        }
    }
    
    requirement def CableTensionSafetyRequirement {
        doc /* All cables shall operate within their maximum tension limits 
             during all operations. */
        
        subject robot : CableRobot;
        
        require constraint {
            robot.cables[0].tension <= robot.cables[0].maxTension and
            robot.cables[1].tension <= robot.cables[1].maxTension and
            robot.cables[2].tension <= robot.cables[2].maxTension and
            robot.cables[3].tension <= robot.cables[3].maxTension and
            robot.cables[4].tension <= robot.cables[4].maxTension and
            robot.cables[5].tension <= robot.cables[5].maxTension
        }
    }
    
    requirement def WorkspaceVolumeRequirement {
        doc /* The cable robot shall provide a minimum workspace volume for 
             payload positioning operations. */
        
        subject robot : CableRobot;
        
        require constraint {
            robot.workspaceVolume >= 25.0 [SI::m^3]
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for the cable robot system to precisely 
             position payloads in three-dimensional space using coordinated 
             cable-driven actuation. */
        
        subject sut : CableRobot = cableRobotInstance;
        
        require primaryFunction : PrimaryFunctionRequirement {
            subject robot = sut;
        }
        
        require positioningAccuracy : PositioningAccuracyRequirement {
            subject robot = sut;
        }
        
        require payloadCapacity : PayloadCapacityRequirement {
            subject robot = sut;
        }
        
        require cableSafety : CableTensionSafetyRequirement {
            subject robot = sut;
        }
        
        require workspace : WorkspaceVolumeRequirement {
            subject robot = sut;
        }
    }
}
