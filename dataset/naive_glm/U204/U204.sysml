package PackSystem {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    package ValueTypes {
        value type Distance :> Length;
        value type Area :> Real;
        value type Speed :> Real;
        value type DetectionRange :> Distance;
        value type CohesionLevel :> Real {
            constraint { 0.0 <= self and self <= 1.0; }
        }
        value type EnergyLevel :> Real {
            constraint { 0.0 <= self and self <= 100.0; }
        }
        value type PackSize :> Integer {
            constraint { 2 <= self; }
        }
        value type ThreatLevel :> Integer {
            constraint { 1 <= self and self <= 10; }
        }
        value type FoodMass :> Mass;
    }

    package ItemDefs {
        import ValueTypes::*;

        item def Prey {
            attribute species : String;
            attribute estimatedMass : FoodMass;
            attribute positionX : Distance;
            attribute positionY : Distance;
            attribute isMobile : Boolean;
        }

        item def Threat {
            attribute threatType : String;
            attribute threatLevel : ThreatLevel;
            attribute positionX : Distance;
            attribute positionY : Distance;
        }

        item def FoodResource {
            attribute mass : FoodMass;
            attribute portions : Integer;
        }

        item def Territory {
            attribute area : Area := 300000;
            attribute perimeter : Distance := 2400 [m];
            attribute centerX : Distance := 0 [m];
            attribute centerY : Distance := 0 [m];
        }

        item def IntrusionAlert {
            attribute alertType : String;
            attribute severity : ThreatLevel;
            attribute positionX : Distance;
            attribute positionY : Distance;
        }

        enum BehavioralMode {
            resting;
            hunting;
            defending;
            nurturing;
        }

        enum Role {
            alpha;
            beta;
            scout;
            hunter;
        }
    }

    package PortDefs {
        import ItemDefs::*;

        port def SensorPort {
            in detectedPrey : Prey;
            in detectedThreat : Threat;
        }

        port def CommunicationPort {
            in incoming : String;
            out outgoing : String;
        }

        port def CommandPort {
            in receivedDirective : String;
            out issuedDirective : String;
        }
    }

    package MemberDefs {
        import PortDefs::*;
        import ItemDefs::*;
        import ValueTypes::*;

        part def PackMember {
            attribute role : Role;
            attribute energy : EnergyLevel := 75.0;
            attribute cohesion : CohesionLevel := 0.8;
            attribute detectionRange : DetectionRange;
            attribute maxSpeed : Speed;
            attribute isAlive : Boolean := true;

            port sensor : SensorPort;
            port comm : CommunicationPort;
            port cmd : CommandPort;

            action def senseEnvironment {
                out prey : Prey;
                out threat : Threat;
            }

            action def communicate {
                in message : String;
                out response : String;
            }

            action def moveTo {
                in targetX : Distance;
                in targetY : Distance;
            }

            action def rest;

            action def eat {
                in food : FoodResource;
                out newEnergy : EnergyLevel;
            }
        }

        part def Alpha :> PackMember {
            attribute role : Role := Role::alpha;
            attribute detectionRange : DetectionRange := 1500 [m];
            attribute maxSpeed : Speed := 8;

            action def issueDirective {
                in objective : String;
                out directive : String;
            }

            action def coordinateHunt {
                in prey : Prey;
                out formation : String;
                out directive : String;
            }

            action def distributeFood {
                in food : FoodResource;
                out portionsPerMember : Integer;
            }
        }

        part def Beta :> PackMember {
            attribute role : Role := Role::beta;
            attribute detectionRange : DetectionRange := 1200 [m];
            attribute maxSpeed : Speed := 9;

            action def supportAlpha {
                in directive : String;
                out coordination : String;
            }

            action def mediateConflict;
        }

        part def Scout :> PackMember {
            attribute role : Role := Role::scout;
            attribute detectionRange : DetectionRange := 3000 [m];
            attribute maxSpeed : Speed := 10;

            action def reconnoiter {
                out preySighted : Prey;
                out threatSighted : Threat;
            }

            action def reportFindings {
                in prey : Prey;
                in threat : Threat;
                out report : String;
            }
        }

        part def Hunter :> PackMember {
            attribute role : Role := Role::hunter;
            attribute detectionRange : DetectionRange := 800 [m];
            attribute maxSpeed : Speed := 9;

            action def approachPrey {
                in prey : Prey;
                in formation : String;
            }

            action def encircle {
                in prey : Prey;
                in formation : String;
            }

            action def capture {
                in prey : Prey;
                out capturedFood : FoodResource;
            }
        }
    }

    package PackDef {
        import MemberDefs::*;
        import ItemDefs::*;
        import ValueTypes::*;
        import PortDefs::*;

        part def Pack {
            attribute mode : BehavioralMode := BehavioralMode::resting;
            attribute cohesion : CohesionLevel := 0.8;
            attribute packSize : PackSize;
            attribute territory : Territory;
            attribute preyDetected : Boolean := false;
            attribute threatDetected : Boolean := false;
            attribute formationReady : Boolean := false;
            attribute approachComplete : Boolean := false;
            attribute encirclementComplete : Boolean := false;
            attribute captureComplete : Boolean := false;
            attribute huntSuccess : Boolean := false;
            attribute intrusionRepelled : Boolean := false;

            part alpha : Alpha;
            part betas : Beta[2];
            part scouts : Scout[3];
            part hunters : Hunter[*];

            port territorySensor : SensorPort;
            port packComm : CommunicationPort;

            connection alphaToBetas connect alpha.cmd to betas.cmd;
            connection alphaToScouts connect alpha.cmd to scouts.cmd;
            connection alphaToHunters connect alpha.cmd to hunters.cmd;
            connection scoutsToAlpha connect scouts.comm to alpha.comm;
            connection betasToAlpha connect betas.comm to alpha.comm;
            connection huntersToAlpha connect hunters.comm to alpha.comm;
            connection territorySensorToAlpha connect territorySensor to alpha.sensor;
            connection territorySensorToScouts connect territorySensor to scouts.sensor;
            connection territorySensorToHunters connect territorySensor to hunters.sensor;

            action recoverEnergy;
            action dispatchScouts;
            action coordinateFormation;
            action beginApproach;
            action executeEncirclement;
            action executeCapture;
            action distributeFoodResources;
            action patrolTerritory;
            action mobilizeDefense;
            action repelIntruder;
            action beginSocialBonding;
            action maintainCohesion;

            state machine PackBehavior {
                state resting {
                    entry recoverEnergy;
                }

                state hunting {
                    state detection {
                        entry dispatchScouts;
                    }
                    state coordination {
                        entry coordinateFormation;
                    }
                    state approach {
                        entry beginApproach;
                    }
                    state encirclement {
                        entry executeEncirclement;
                    }
                    state capture {
                        entry executeCapture;
                        exit distributeFoodResources;
                    }
                    transition from detection to coordination when preyDetected;
                    transition from coordination to approach when formationReady;
                    transition from approach to encirclement when approachComplete;
                    transition from encirclement to capture when encirclementComplete;
                }

                state defending {
                    entry patrolTerritory;
                    do mobilizeDefense;
                    exit repelIntruder;
                }

                state nurturing {
                    entry beginSocialBonding;
                    do maintainCohesion;
                }

                transition from resting to hunting when preyDetected;
                transition from resting to defending when threatDetected;
                transition from hunting to defending when threatDetected;
                transition from capture to resting when captureComplete and cohesion >= 0.7;
                transition from capture to nurturing when captureComplete and cohesion < 0.7;
                transition from defending to resting when !threatDetected;
                transition from defending to hunting when preyDetected and !threatDetected;
                transition from resting to nurturing when !preyDetected and !threatDetected and cohesion < 0.7;
                transition from nurturing to resting when cohesion >= 0.9;
            }
        }

        part wolfPack : Pack {
            attribute packSize := 12;
            attribute cohesion := 0.85;

            part alpha;
            part betas[2];
            part scouts[3];
            part hunters[6];
        }
    }

    package Requirements {
        import ItemDefs::*;
        import ValueTypes::*;
        import PackDef::*;
        import MemberDefs::*;

        requirement def PackSurvivalRequirement {
            doc "The pack shall survive and thrive through collective intelligence and clear social hierarchy.";
        }

        requirement def HuntingCooperationRequirement {
            doc "The pack shall perform a multi-stage cooperative hunt: detection, coordination, approach, encirclement, and capture.";
            subject pack : Pack;
            objective {
                pack.huntSuccess == true;
            }
        }

        requirement def ScoutDetectionRequirement {
            doc "Scouts shall detect prey within their detection range.";
            subject scout : Scout;
            attribute minDetectionRange : DetectionRange := 2000 [m];
            constraint { scout.detectionRange >= minDetectionRange; }
        }

        requirement def TerritoryDefenseRequirement {
            doc "The pack shall patrol its territory and repel intruders when threats are detected.";
            subject pack : Pack;
            objective {
                pack.intrusionRepelled == true;
            }
        }

        requirement def CohesionRequirement {
            doc "The pack shall maintain social cohesion above a minimum threshold.";
            subject pack : Pack;
            attribute minCohesion : CohesionLevel := 0.7;
            constraint { pack.cohesion >= minCohesion; }
        }

        requirement def FoodDistributionRequirement {
            doc "After a successful hunt, food shall be distributed among all members.";
            subject pack : Pack;
            objective {
                pack.huntSuccess == true;
            }
        }

        requirement BehavioralModeRequirement {
            doc "The pack shall operate in resting, hunting, defending, or nurturing modes, transitioning based on external cues.";
            subject pack : Pack;
        }

        requirement AlphaLeadershipRequirement {
            doc "The Alpha shall lead and issue directives to all members.";
            subject alpha : Alpha;
        }
    }

    package Verifications {
        import Requirements::*;
        import PackDef::*;
        import MemberDefs::*;

        verification def VerifyHunt {
            subject pack : Pack;
            objective { HuntingCooperationRequirement.satisfied; }
        }

        verification def VerifyScouts {
            subject scout : Scout;
            objective { ScoutDetectionRequirement.satisfied; }
        }

        verification def VerifyDefense {
            subject pack : Pack;
            objective { TerritoryDefenseRequirement.satisfied; }
        }

        verification def VerifyCohesion {
            subject pack : Pack;
            objective { CohesionRequirement.satisfied; }
        }

        verification def VerifyFoodDistribution {
            subject pack : Pack;
            objective { FoodDistributionRequirement.satisfied; }
        }

        verification def VerifyBehavioralModes {
            subject pack : Pack;
            objective { BehavioralModeRequirement.satisfied; }
        }
    }
}
