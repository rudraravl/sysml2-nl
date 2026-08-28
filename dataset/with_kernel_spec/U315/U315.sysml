package 'Miller-Abbott Tube System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def IntestinalGas {
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
	}

	item def IntestinalFluid {
		attribute volume : VolumeValue;
	}

	item def IntestinalContents {
		item gas : IntestinalGas[0..*];
		item fluid : IntestinalFluid[0..*];
	}

	port def AspirationPort {
		attribute vacuum : PressureValue;
		out item aspiratedContents : IntestinalContents;
	}

	port def SuctionInletPort {
		attribute vacuum : PressureValue;
		in item aspiratedContents : IntestinalContents;
	}

	port def InflationPort {
		attribute inflationPressure : PressureValue;
	}

	port def BowelContentPort {
		out item trappedContents : IntestinalContents;
		attribute peristalticPressure : PressureValue;
	}

	part def DistalBalloon {
		attribute inflated : Boolean = false;
		attribute inflationPressure : PressureValue = 10000 [SI::Pa];
		attribute inflatedDiameter : LengthValue = 0.0 [SI::m];
		port inflationPort : InflationPort;
	}

	part def MercuryWeightedTip {
		attribute mass : MassValue = 0.003 [SI::kg];
	}

	part def AspirationHole {
		attribute diameter : LengthValue = 0.0015 [SI::m];
	}

	part def AspirationLumen {
		attribute innerDiameter : LengthValue = 0.002 [SI::m];
		part holes : AspirationHole[4..6];
		port aspirationPort : AspirationPort;
		port intakePort : BowelContentPort;
	}

	part def InflationLumen {
		attribute innerDiameter : LengthValue = 0.001 [SI::m];
		port inflationPort : InflationPort;
	}

	part def MillerAbbottTube {
		attribute length : LengthValue = 2.5 [SI::m];
		attribute flexible : Boolean = true;
		part distalBalloon : DistalBalloon[1];
		part mercuryTip : MercuryWeightedTip[1];
		part aspirationLumen : AspirationLumen[1];
		part inflationLumen : InflationLumen[1];
		port aspirationPort : AspirationPort;
		port inflationPort : InflationPort;
		connect inflationPort to inflationLumen.inflationPort;
		connect inflationLumen.inflationPort to distalBalloon.inflationPort;
		connect aspirationPort to aspirationLumen.aspirationPort;
	}

	part def SuctionApparatus {
		attribute vacuumPressure : PressureValue = -10000 [SI::Pa];
		attribute continuousLowPressure : Boolean = true;
		port suctionInlet : SuctionInletPort;
	}

	part def SmallIntestine {
		attribute obstructed : Boolean = true;
		attribute distended : Boolean = true;
		attribute peristalticFrequency : FrequencyValue = 0.1 [SI::Hz];
		port contentPort : BowelContentPort;
	}

	part def NoseAccess {
		attribute diameter : LengthValue = 0.005 [SI::m];
	}

	part def Patient {
		part nose : NoseAccess[1];
		part smallIntestine : SmallIntestine[1];
	}

	connection def AspirationLine {
		end [1] part lumenEnd : AspirationLumen;
		end [1] part suctionEnd : SuctionApparatus;
		item gas : IntestinalGas;
		item fluid : IntestinalFluid;
	}

	part def MillerAbbottDecompressionSystem {
		part tube : MillerAbbottTube[1];
		part suctionApparatus : SuctionApparatus[1];
		part patient : Patient[1];
		connect patient.smallIntestine.contentPort to tube.aspirationLumen.intakePort;
		connect tube.aspirationPort to suctionApparatus.suctionInlet;
	}

	attribute def TubeInserted;
	attribute def BalloonInflated;
	attribute def TubePositioned;
	attribute def SuctionStarted;
	attribute def DecompressionComplete;
	attribute def BalloonDeflated;
	attribute def TubeRemoved;

	action def InsertTube {
		in patient : Patient;
		in tube : MillerAbbottTube;
		out tubePosition : LengthValue;
	}

	action def InflateDistalBalloon {
		in tube : MillerAbbottTube;
		in inflationPressure : PressureValue;
		out balloonDiameter : LengthValue;
	}

	action def AdvanceToObstruction {
		in patient : Patient;
		in tube : MillerAbbottTube;
		in startingPosition : LengthValue;
		out finalPosition : LengthValue;
		out reachedObstruction : Boolean;
	}

	action def AspirateTrappedContents {
		in suctionApparatus : SuctionApparatus;
		in tube : MillerAbbottTube;
		out aspiratedGasVolume : VolumeValue;
		out aspiratedFluidVolume : VolumeValue;
		out totalAspiratedVolume : VolumeValue;
	}

	action def MonitorDecompression {
		in patient : Patient;
		in tubePosition : LengthValue;
		in totalAspiratedVolume : VolumeValue;
		out decompressionEffective : Boolean;
	}

	action def DeflateDistalBalloon {
		in tube : MillerAbbottTube;
		out balloonDeflated : Boolean;
	}

	action def RemoveTube {
		in tube : MillerAbbottTube;
		out tubeRemoved : Boolean;
	}

	action def PerformDecompression {
		in patient : Patient;
		in tube : MillerAbbottTube;
		in suctionApparatus : SuctionApparatus;
		out decompressionEffective : Boolean;
	}

	state def ProcedureState {
		entry; then Insertion;
		state Insertion;
		accept TubeInserted then BalloonInflation;
		state BalloonInflation;
		accept BalloonInflated then PeristalticAdvance;
		state PeristalticAdvance;
		accept TubePositioned then SuctionActivation;
		state SuctionActivation;
		accept SuctionStarted then Decompression;
		state Decompression;
		accept DecompressionComplete then BalloonDeflation;
		state BalloonDeflation;
		accept BalloonDeflated then Removal;
		state Removal;
		accept TubeRemoved then Done;
		state Done;
	}

	requirement def BowelDecompressionRequirement {
		doc /* The Miller-Abbott tube system shall remove accumulated gas and fluid from the obstructed small intestine to relieve pressure and swelling. */
		subject system : MillerAbbottDecompressionSystem;
	}

	requirement def TubePlacementRequirement {
		doc /* The Miller-Abbott tube shall be positioned at or near the obstruction. */
		subject tube : MillerAbbottTube;
	}

	requirement def SuctionRequirement {
		doc /* The suction apparatus shall generate a continuous, low-pressure vacuum to draw out intestinal contents. */
		subject suctionApparatus : SuctionApparatus;
	}

	requirement def BalloonEngagementRequirement {
		doc /* The distal balloon shall be inflatable to engage intestinal peristalsis for tube advancement. */
		subject balloon : DistalBalloon;
	}

	requirement def MonitoringRequirement {
		doc /* The system shall monitor tube position and decompression effectiveness before balloon deflation and tube removal. */
		subject system : MillerAbbottDecompressionSystem;
	}

	part decompressionSystem : MillerAbbottDecompressionSystem {
		action decompressionProcedure : PerformDecompression {
			in patient : Patient = patient;
			in tube : MillerAbbottTube = tube;
			in suctionApparatus : SuctionApparatus = suctionApparatus;
			out decompressionEffective : Boolean;
		}
		state procedureStates : ProcedureState;
	}

	requirement bowelDecompressionReq : BowelDecompressionRequirement;
	requirement tubePlacementReq : TubePlacementRequirement;
	requirement suctionReq : SuctionRequirement;
	requirement balloonEngagementReq : BalloonEngagementRequirement;
	requirement monitoringReq : MonitoringRequirement;

	satisfy bowelDecompressionReq by decompressionSystem;
	satisfy tubePlacementReq by decompressionSystem::tube;
	satisfy suctionReq by decompressionSystem::suctionApparatus;
	satisfy balloonEngagementReq by decompressionSystem::tube::distalBalloon;
	satisfy monitoringReq by decompressionSystem;
}
