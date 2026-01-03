package 'Don Pack System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PackIdentifier;
    attribute def PackSize;
    attribute def TerritoryArea;
    attribute def HuntingEfficiency;
    attribute def SocialCohesion;

    value def Position {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }

    value def PackStatus {
        attribute cohesionLevel : Real;
        attribute energyLevel : Real;
        attribute territorySecure : Boolean;
    }

    item def Prey {
        attribute mass : MassValue;
        attribute speed : SpeedValue;
        attribute position : Position;
        attribute detected : Boolean;
    }

    item def Territory {
        attribute area : AreaValue;
        attribute resourceDensity : Real;
        attribute boundaries : Position[*];
    }

    port def CommunicationPort {
        out signal : String;
        in response : String;
    }

    port def CoordinationPort {
        out command : String;
        in status : PackStatus;
    }

    part def PackMember {
        attribute memberID : PackIdentifier;
        attribute stamina : Real;
        attribute currentPosition : Position;
        attribute role : String;

        port commPort : CommunicationPort;
        port coordPort : CoordinationPort;
    }

    part def AlphaMember :> PackMember {
        attribute leadershipStrength : Real;
        attribute decisionAuthority : Boolean;
    }

    part def BetaMember :> PackMember {
        attribute supportCapability : Real;
    }

    part def ScoutMember :> PackMember {
        attribute detectionRange : LengthValue;
    }

    action def DetectPrey {
        in searchArea : Territory;
        out preyFound : Prey;
        out preyLocation : Position;
    }

    action def CommunicatePosition {
        in currentPos : Position;
        in targetPos : Position;
        out positionShared : Boolean;
    }

    action def FormHuntingFormation {
        in memberCount : PackSize;
        in preyLocation : Position;
        out formationReady : Boolean;
        out memberPositions : Position[*];
    }

    action def CoordinateApproach {
        in preyPosition : Position;
        in packPositions : Position[*];
        out approachVectors : Position[*];
    }

    action def EncirclePrey {
        in preyPosition : Position;
        in memberPositions : Position[*];
        out encirclementComplete : Boolean;
        out captureReady : Boolean;
    }

    action def ExecuteCapture {
        in targetPrey : Prey;
        in encircled : Boolean;
        out captureSuccess : Boolean;
        out acquiredFood : MassValue;
    }

    action def CooperativeHunt {
        in territory : Territory;
        in packSize : PackSize;
        out huntSuccess : Boolean;
        out foodAcquired : MassValue;

        first start;
        then action detect : DetectPrey {
            in searchArea = territory;
            out preyFound;
            out preyLocation;
        }
        then decide;
            if detect.preyFound.detected then formGroup;
            else start;
        action formGroup : FormHuntingFormation {
            in memberCount = packSize;
            in preyLocation = detect.preyLocation;
            out formationReady;
            out memberPositions;
        }
        then merge coordinateLoop;
        action coordinateLoop : CoordinateApproach {
            in preyPosition = detect.preyLocation;
            in packPositions = formGroup.memberPositions;
            out approachVectors;
        }
        then action encircle : EncirclePrey {
            in preyPosition = detect.preyLocation;
            in memberPositions = coordinateLoop.approachVectors;
            out encirclementComplete;
            out captureReady;
        }
        then decide;
            if encircle.captureReady then capture;
            else coordinateLoop;
        action capture : ExecuteCapture {
            in targetPrey = detect.preyFound;
            in encircled = encircle.encirclementComplete;
            out captureSuccess;
            out acquiredFood;
        }
        then assign huntSuccess := capture.captureSuccess;
        then assign foodAcquired := capture.acquiredFood;
        then done;
    }

    action def PatrolTerritory {
        in territoryBounds : Territory;
        in patrolRoute : Position[*];
        out patrolComplete : Boolean;
        out threatsDetected : Boolean;
    }

    action def DefendTerritory {
        in territory : Territory;
        in threatDetected : Boolean;
        out territorySecured : Boolean;

        first start;
        then decide;
            if threatDetected then mobilize;
            else patrol;
        action mobilize {
            out packMobilized : Boolean;
        }
        then action confront {
            out threatRepelled : Boolean;
        }
        then assign territorySecured := confront.threatRepelled;
        then done;
        action patrol : PatrolTerritory {
            in territoryBounds = territory;
            in patrolRoute : Position[*];
            out patrolComplete;
            out threatsDetected;
        }
        then assign territorySecured := !patrol.threatsDetected;
        then done;
    }

    action def DistributeResources {
        in foodAvailable : MassValue;
        in packSize : PackSize;
        out distributionComplete : Boolean;
        out packNourished : Boolean;
    }

    action def MaintainSocialBonds {
        in packMembers : PackSize;
        out bondStrength : Real;
        out cohesionLevel : Real;
    }

    action def NurturePack {
        in packSize : PackSize;
        in resources : MassValue;
        out packHealth : Real;

        action distribute : DistributeResources {
            in foodAvailable = resources;
            in packSize = NurturePack::packSize;
            out distributionComplete;
            out packNourished;
        }
        then action maintain : MaintainSocialBonds {
            in packMembers = NurturePack::packSize;
            out bondStrength;
            out cohesionLevel;
        }
        then assign packHealth := maintain.cohesionLevel;
    }

    state def PackBehaviorStates {
        entry; then resting;

        state resting;
        accept huntSignal : Boolean
            then hunting;

        state hunting {
            do action hunt : CooperativeHunt;
        }
        accept threatSignal : Boolean
            then defending;
        accept huntComplete : Boolean
            then resting;

        state defending {
            do action defend : DefendTerritory;
        }
        accept threatCleared : Boolean
            then resting;

        state nurturing {
            do action nurture : NurturePack;
        }
        accept careSignal : Boolean
            if resting then nurturing;
        accept careComplete : Boolean
            then resting;
    }

    connection def PackCoordination {
        end alphaPort : CoordinationPort;
        end memberPorts : CoordinationPort[*];
    }

    connection def PackCommunication {
        end senderPort : CommunicationPort;
        end receiverPorts : CommunicationPort[*];
    }

    part def DonPackSystem {
        doc /* 
            A Don Pack System represents a highly coordinated social group
            that operates through collective intelligence and cooperation.
            The primary function is to survive and thrive through coordinated
            hunting, territorial defense, and social nurturing behaviors.
        */

        attribute packID : PackIdentifier;
        attribute totalMembers : PackSize;
        attribute packTerritory : Territory;

        part alpha : AlphaMember {
            attribute memberID = "Alpha-001";
            attribute leadershipStrength = 0.95;
            attribute role = "Leader";
        }

        part beta : BetaMember[2] {
            attribute supportCapability = 0.85;
            attribute role = "Support";
        }

        part scouts : ScoutMember[2] {
            attribute detectionRange = 500.0['m'];
            attribute role = "Scout";
        }

        part hunters : PackMember[4..8] {
            attribute role = "Hunter";
        }

        perform action packOperations : CooperativeHunt[*] ordered;

        exhibit state packBehavior : PackBehaviorStates;

        connection alphaCoord : PackCoordination
            connect alpha.coordPort to beta.coordPort;
        connection alphaComm : PackCommunication
            connect alpha.commPort to scouts.commPort;
        connection scoutComm : PackCommunication
            connect scouts.commPort to hunters.commPort;
    }

    part donPackInstance : DonPackSystem {
        attribute packID = "Pack-Alpha-01";
        attribute totalMembers = 10;
        attribute packTerritory : Territory {
            attribute area = 25.0['km'^2];
            attribute resourceDensity = 0.75;
        }
    }

    requirement def PackSurvivalRequirement {
        doc /* The pack shall maintain coordinated behavior to ensure survival through hunting, defense, and nurturing. */

        require constraint huntingEfficiency {
            doc /* Hunting success rate shall exceed 60% for sustainable food acquisition. */
        }

        require constraint territorialControl {
            doc /* The pack shall maintain control over territory adequate for resource needs. */
        }

        require constraint socialCohesion {
            doc /* Pack cohesion level shall remain above 0.75 for effective coordination. */
        }
    }

    requirement <'REQ-001'> packCoordinationRequirement : PackSurvivalRequirement {
        doc /* 
            The Don Pack System shall coordinate member actions to achieve
            collective objectives including hunting, defense, and nurturing.
        */

        subject donPackSystem : DonPackSystem;

        assume constraint minimumPackSize {
            doc /* Pack shall maintain at least 5 active members. */
            donPackSystem.totalMembers >= 5
        }

        require constraint effectiveLeadership {
            doc /* Alpha member shall maintain leadership strength above 0.8. */
            donPackSystem.alpha.leadershipStrength >= 0.8
        }

        require constraint coordinatedHunting {
            doc /* Pack shall execute cooperative hunting with synchronized movements. */
        }
    }

    requirement <'REQ-002'> territoryMaintenanceRequirement {
        doc /* The pack shall defend and maintain territory for resource access. */

        subject packTerritory : Territory;

        require constraint adequateArea {
            doc /* Territory area shall support pack size and resource requirements. */
            packTerritory.area >= 20.0['km'^2]
        }

        require constraint resourceDensity {
            doc /* Territory resource density shall exceed minimum threshold. */
            packTerritory.resourceDensity >= 0.6
        }
    }

    requirement <'REQ-003'> packHealthRequirement {
        doc /* The pack shall maintain health through resource distribution and social bonding. */

        subject donPackSystem : DonPackSystem;

        require constraint resourceDistribution {
            doc /* Resources shall be distributed equitably among pack members. */
        }

        require constraint socialBonding {
            doc /* Social bonds shall be maintained through regular interaction. */
        }
    }
}
