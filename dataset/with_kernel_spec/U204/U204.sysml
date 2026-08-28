package 'Social Animal Pack' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	value type DetectionRange :> Real;
	value type PackCohesion :> Real;
	value type PackSize :> Integer;

	item def Prey;
	item def Threat;
	item def Food;
	item def CoordinationCommand;
	item def BondingSignal;

	port def PreyDetectionPort {
		out preyDetected : Prey;
	}
	port def ThreatDetectionPort {
		out threatDetected : Threat;
	}
	port def CommandReceivePort {
		in command : CoordinationCommand;
	}
	port def CommandSendPort {
		out command : CoordinationCommand;
	}
	port def FoodReceivePort {
		in food : Food;
	}
	port def FoodSendPort {
		out food : Food;
	}
	port def BondingSendPort {
		out bondingSignal : BondingSignal;
	}
	port def BondingReceivePort {
		in bondingSignal : BondingSignal;
	}

	part def PackMember {
		attribute name : String;
		attribute role : String;
		attribute healthStatus : String;
		attribute energyLevel : Real;
		port commandPort : CommandReceivePort;
		port foodPort : FoodReceivePort;
		port bondingSendPort : BondingSendPort;
	}

	part def Alpha :> PackMember {
		attribute leadershipAuthority : Real;
		attribute decisionMakingCapability : Real;
		port commandSendPort : CommandSendPort;
		port preyInfoPort {
			in preyInfo : Prey;
		}
		port threatInfoPort {
			in threatInfo : Threat;
		}
		port foodSendPort : FoodSendPort;
		port bondingReceivePort : BondingReceivePort;
	}

	part def Beta :> PackMember {
		attribute supportCapability : Real;
	}

	part def Scout :> PackMember {
		attribute detectionRange : DetectionRange;
		port preyDetectionPort : PreyDetectionPort;
		port threatDetectionPort : ThreatDetectionPort;
	}

	part def Hunter :> PackMember {
		attribute huntingSkill : Real;
	}

	part def Territory {
		attribute area : Real;
		attribute boundaryStatus : String;
		item preyPopulation : Prey [0..*];
		item intruders : Threat [0..*];
	}

	action def CooperativeHunt {
		out food : Food;

		action detectPrey {
			out prey : Prey;
		}
		action coordinateFormation {
			in prey : Prey;
			out command : CoordinationCommand;
		}
		action coordinatedApproach {
			in command : CoordinationCommand;
		}
		action encirclePrey;
		action capturePrey {
			out food : Food;
		}

		flow detectPrey.prey to coordinateFormation.prey;
		flow coordinateFormation.command to coordinatedApproach.command;
	}

	action def DefendTerritory {
		out repelled : Boolean;

		action patrolTerritory {
			out threat : Threat;
		}
		action mobilizePack {
			in threat : Threat;
			out command : CoordinationCommand;
		}
		action confrontIntruder {
			in command : CoordinationCommand;
			out repelled : Boolean;
		}

		flow patrolTerritory.threat to mobilizePack.threat;
		flow mobilizePack.command to confrontIntruder.command;
	}

	action def MaintainSocialHealth {
		out cohesionLevel : PackCohesion;

		action distributeFood {
			out distributed : Boolean;
		}
		action socialBonding {
			out cohesionLevel : PackCohesion;
		}
	}

	part def Pack {
		attribute packSize : PackSize;
		attribute cohesion : PackCohesion;
		attribute preyDetected : Boolean;
		attribute threatDetected : Boolean;
		attribute huntComplete : Boolean;
		attribute threatRepelled : Boolean;

		part alpha : Alpha [1];
		part betas : Beta [1..*];
		part scouts : Scout [1..*];
		part hunters : Hunter [2..*];
		part territory : Territory [1];

		connection alphaToBetasCommand connect alpha.commandSendPort to betas.commandPort;
		connection alphaToScoutsCommand connect alpha.commandSendPort to scouts.commandPort;
		connection alphaToHuntersCommand connect alpha.commandSendPort to hunters.commandPort;

		flow preyDetectionFlow of Prey from scouts.preyDetectionPort.preyDetected to alpha.preyInfoPort.preyInfo;
		flow threatDetectionFlow of Threat from scouts.threatDetectionPort.threatDetected to alpha.threatInfoPort.threatInfo;

		flow foodDistributionFlowBetas of Food from alpha.foodSendPort.food to betas.foodPort.food;
		flow foodDistributionFlowHunters of Food from alpha.foodSendPort.food to hunters.foodPort.food;
		flow foodDistributionFlowScouts of Food from alpha.foodSendPort.food to scouts.foodPort.food;

		flow bondingFlowBetas of BondingSignal from betas.bondingSendPort.bondingSignal to alpha.bondingReceivePort.bondingSignal;
		flow bondingFlowHunters of BondingSignal from hunters.bondingSendPort.bondingSignal to alpha.bondingReceivePort.bondingSignal;
		flow bondingFlowScouts of BondingSignal from scouts.bondingSendPort.bondingSignal to alpha.bondingReceivePort.bondingSignal;

		exhibit packStates {
			state Resting;
			state Hunting;
			state Defending;
			state Nurturing;

			transition from Resting to Hunting when preyDetected;
			transition from Resting to Defending when threatDetected;
			transition from Resting to Nurturing when cohesion < 50;

			transition from Hunting to Nurturing when huntComplete;
			transition from Hunting to Defending when threatDetected;
			transition from Hunting to Resting when not preyDetected;

			transition from Defending to Resting when threatRepelled;
			transition from Defending to Hunting when preyDetected and threatRepelled;

			transition from Nurturing to Resting when cohesion >= 80;
			transition from Nurturing to Hunting when preyDetected;
			transition from Nurturing to Defending when threatDetected;
		}
	}

	requirement def PackSurvivalRequirement {
		doc /* The pack must survive and thrive through collective intelligence. */
		subject packSystem : Pack;

		requirement packCohesionRequirement {
			doc /* Pack cohesion must remain above 60 percent for effective cooperation. */
			assert constraint { packSystem.cohesion >= 60 }
		}
		requirement huntSuccessRequirement {
			doc /* The cooperative hunt must result in food capture when prey is detected. */
		}
		requirement territoryDefenseRequirement {
			doc /* The pack must repel detected threats to defend its territory. */
		}
		requirement socialHierarchyRequirement {
			doc /* The pack must maintain a clear social hierarchy with one Alpha leader. */
		}
	}

	requirement packOperationalRequirement : PackSurvivalRequirement;

	part socialAnimalPack : Pack {
		part :>> alpha : Alpha {
			attribute :>> name = "AlphaOne";
			attribute :>> role = "Leader";
			attribute :>> leadershipAuthority = 95;
			attribute :>> decisionMakingCapability = 90;
		}
		part :>> betas : Beta [2] {
			attribute :>> role = "Support";
		}
		part :>> scouts : Scout [3] {
			attribute :>> detectionRange = 1500;
			attribute :>> role = "Reconnaissance";
		}
		part :>> hunters : Hunter [6] {
			attribute :>> huntingSkill = 85;
			attribute :>> role = "Hunter";
		}
		part :>> territory : Territory {
			attribute :>> area = 500;
		}
	}
}
