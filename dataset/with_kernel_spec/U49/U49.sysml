package 'Drug Eluting Coronary Stent System' {
	private import ScalarValues::*;
	private import SI::*;
	private import ISQ::*;

	package Definitions {
		item def InflationFluid;
		item def ExpansionForceItem;
		item def Blood;
		item def Plaque;

		port def InflationSourcePort {
			out item inflationFluid : InflationFluid;
		}
		port def InflationInPort {
			in item inflationFluid : InflationFluid;
		}
		port def ExpansionForceSourcePort {
			out item expansionForce : ExpansionForceItem;
		}
		port def ExpansionForceInPort {
			in item expansionForce : ExpansionForceItem;
		}
		port def BloodOutPort {
			out item blood : Blood;
		}
		port def BloodInPort {
			in item blood : Blood;
		}

		item def AntiproliferativeDrug {
			attribute name : String;
			attribute elutionRate : Real;
		}

		item def DrugCoating {
			item drug : AntiproliferativeDrug;
			attribute releaseDuration : Real;
			attribute coatingThickness : Real;
		}

		part def Stent {
			attribute material : String;
			attribute strutThickness : Real;
			attribute collapsedDiameter : Real;
			attribute expandedDiameter : Real;
			attribute radialStrength : Real;
			item coating : DrugCoating;
			port forceInPort : ExpansionForceInPort;
			port proximalBloodPort : BloodInPort;
			port distalBloodPort : BloodOutPort;
		}

		part def Balloon {
			attribute nominalPressure : Real;
			attribute ratedBurstPressure : Real;
			attribute expandedDiameter : Real;
			port inflationPort : InflationInPort;
			port forceOutPort : ExpansionForceSourcePort;
		}

		part def CatheterShaft {
			attribute workingLength : Real;
			attribute outerDiameter : Real;
		}

		part def BalloonCatheter {
			attribute workingLength : Real;
			part balloon : Balloon;
			part shaft : CatheterShaft;
			port proximalHubPort : InflationInPort;
		}

		part def Indeflator {
			attribute maxPressure : Real;
			port fluidOutPort : InflationSourcePort;
		}

		part def CoronaryArterySegment {
			attribute lumenDiameter : Real;
			attribute stenosisPercent : Real;
			item plaque : Plaque;
			port proximalEnd : BloodOutPort;
			port distalEnd : BloodInPort;
		}

		part def DrugElutingStentSystem {
			part stent : Stent;
			part balloonCatheter : BalloonCatheter;
			part indeflator : Indeflator;
			part coronaryArtery : CoronaryArterySegment;

			flow of InflationFluid
				from indeflator.fluidOutPort.inflationFluid
				to balloonCatheter.proximalHubPort.inflationFluid;

			flow of ExpansionForceItem
				from balloonCatheter.balloon.forceOutPort.expansionForce
				to stent.forceInPort.expansionForce;

			flow of Blood
				from coronaryArtery.proximalEnd.blood
				to stent.proximalBloodPort.blood;

			flow of Blood
				from stent.distalBloodPort.blood
				to coronaryArtery.distalEnd.blood;
		}

		action def GuideToLesion {
			in catheter : BalloonCatheter;
			in artery : CoronaryArterySegment;
		}

		action def InflateBalloon {
			in catheter : BalloonCatheter;
			in targetPressure : Real;
			out inflatedDiameter : Real;
		}

		action def DeployStent {
			in stent : Stent;
			in balloon : Balloon;
		}

		action def DeflateBalloon {
			in catheter : BalloonCatheter;
		}

		action def RemoveCatheter {
			in catheter : BalloonCatheter;
		}

		requirement def DrugReleaseDurationRequirement {
			subject stent : Stent;
			require stent.coating.releaseDuration >= 180.0;
		}

		requirement def RadialStrengthRequirement {
			subject stent : Stent;
			require stent.radialStrength >= 8.0;
		}

		requirement def InflationPressureRequirement {
			subject catheter : BalloonCatheter;
			require catheter.balloon.nominalPressure >= 900000.0;
		}

		requirement def BloodFlowRestorationRequirement {
			subject artery : CoronaryArterySegment;
			require artery.lumenDiameter >= 3.0;
		}
	}

	package Usages {
		private import Definitions::*;

		part deploymentSystem : DrugElutingStentSystem {
			part stent : Stent {
				:>> material = 'Cobalt-Chromium Alloy L-605';
				:>> strutThickness = 0.08;
				:>> collapsedDiameter = 1.0;
				:>> expandedDiameter = 3.0;
				:>> radialStrength = 8.0;
				item coating : DrugCoating {
					:>> releaseDuration = 180.0;
					:>> coatingThickness = 0.005;
					item drug : AntiproliferativeDrug {
						:>> name = 'Sirolimus';
						:>> elutionRate = 0.001;
					}
				}
			}

			part balloonCatheter : BalloonCatheter {
				:>> workingLength = 1400.0;
				part balloon : Balloon {
					:>> nominalPressure = 900000.0;
					:>> ratedBurstPressure = 1400000.0;
					:>> expandedDiameter = 3.0;
				}
				part shaft : CatheterShaft {
					:>> workingLength = 1450.0;
					:>> outerDiameter = 0.9;
				}
			}

			part indeflator : Indeflator {
				:>> maxPressure = 2000000.0;
			}

			part coronaryArtery : CoronaryArterySegment {
				:>> lumenDiameter = 3.0;
				:>> stenosisPercent = 70.0;
			}

			satisfy drugReleaseReq : DrugReleaseDurationRequirement by stent;
			satisfy radialStrengthReq : RadialStrengthRequirement by stent;
			satisfy inflationPressureReq : InflationPressureRequirement by balloonCatheter;
			satisfy bloodFlowReq : BloodFlowRestorationRequirement by coronaryArtery;

			perform action guide : GuideToLesion {
				in catheter = balloonCatheter;
				in artery = coronaryArtery;
			}
			then perform action inflate : InflateBalloon {
				in catheter = balloonCatheter;
				in targetPressure = balloonCatheter.balloon.nominalPressure;
				out inflatedDiameter = balloonCatheter.balloon.expandedDiameter;
			}
			then perform action deploy : DeployStent {
				in stent = stent;
				in balloon = balloonCatheter.balloon;
			}
			then perform action deflate : DeflateBalloon {
				in catheter = balloonCatheter;
			}
			then perform action removeCatheter : RemoveCatheter {
				in catheter = balloonCatheter;
			}
		}
	}
}
