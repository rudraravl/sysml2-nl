package 'MillerAbbottTubeSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def IntestinalFluid {
		attribute volume : VolumeValue;
		attribute flowRate : VolumeFlowRateValue;
	}
	
	item def IntestinalGas {
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
	}
	
	item def MercuryWeight {
		attribute mass : MassValue;
	}
	
	port def SuctionPort {
		out item aspiratedFluid : IntestinalFluid;
		out item aspiratedGas : IntestinalGas;
	}
	
	port def IntestinalLumenPort {
		in item luminalFluid : IntestinalFluid;
		in item luminalGas : IntestinalGas;
	}
	
	port def BalloonInflationPort {
		in item inflationMedium : IntestinalFluid;
		out attribute balloonPressure : PressureValue;
	}
	
	part def DistalBalloon {
		port inflationPort : BalloonInflationPort;
		attribute balloonVolume : VolumeValue;
		attribute inflationPressure : PressureValue;
		attribute isInflated : Boolean;
	}
	
	part def AspiratingLumen {
		port intestinalInterface : IntestinalLumenPort;
		port suctionInterface : SuctionPort;
		attribute lumenDiameter : LengthValue;
		attribute numberOfHoles : Integer;
	}
	
	part def MillerAbbottTube {
		attribute tubeLength : LengthValue;
		attribute currentPosition : LengthValue;
		attribute insertionDepth : LengthValue;
		
		part distalBalloon : DistalBalloon {
			attribute :>> balloonVolume = 2.0 [SI::mL];
		}
		
		part aspirationLumen : AspiratingLumen {
			attribute :>> lumenDiameter = 3.0 [SI::mm];
			attribute :>> numberOfHoles = 4;
		}
		
		part mercuryTip : MercuryWeight {
			attribute :>> mass = 5.0 [SI::g];
		}
		
		connection balloonToLumen 
			connect distalBalloon.inflationPort to aspirationLumen.intestinalInterface;
	}
	
	part def SuctionApparatus {
		port suctionInput : SuctionPort;
		attribute suctionPressure : PressureValue;
		attribute continuousSuction : Boolean;
		attribute collectedVolume : VolumeValue;
	}
	
	part def SmallIntestine {
		port lumenInterface : IntestinalLumenPort;
		attribute peristalticActivity : Boolean;
		attribute obstructionPresent : Boolean;
		attribute distensionLevel : Real;
		attribute luminalPressure : PressureValue;
	}
	
	action def IntestinalDecompression;
	
	part millerAbbottSystem {
		part tube : MillerAbbottTube {
			attribute :>> tubeLength = 3.0 [SI::m];
			attribute :>> currentPosition = 0.0 [SI::m];
			attribute :>> insertionDepth = 0.0 [SI::m];
		}
		
		part suctionDevice : SuctionApparatus {
			attribute :>> suctionPressure = -80.0 [SI::kPa];
			attribute :>> continuousSuction = true;
			attribute :>> collectedVolume = 0.0 [SI::mL];
		}
		
		part intestinalTract : SmallIntestine {
			attribute :>> peristalticActivity = true;
			attribute :>> obstructionPresent = true;
			attribute :>> distensionLevel = 0.8;
			attribute :>> luminalPressure = 15.0 [SI::kPa];
		}
		
		connection aspirationConnection 
			connect tube.aspirationLumen.suctionInterface to suctionDevice.suctionInput;
		
		connection intestinalConnection 
			connect tube.aspirationLumen.intestinalInterface to intestinalTract.lumenInterface;
		
		perform action decompressIntestine[*] ordered references intestinalDecompression;
	}
	
	action def InflateBalloon {
		in targetVolume : VolumeValue;
		out achievedPressure : PressureValue;
		out inflationSuccess : Boolean;
	}
	
	action def ApplySuction {
		in suctionLevel : PressureValue;
		in duration : DurationValue;
		out aspiratedVolume : VolumeValue;
	}
	
	action def MonitorTubePosition {
		in currentDepth : LengthValue;
		in targetDepth : LengthValue;
		out positionReached : Boolean;
	}
	
	action def AssessDecompression {
		in distensionLevel : Real;
		in aspiratedVolume : VolumeValue;
		out decompressionComplete : Boolean;
	}
	
	state def TubeOperationStates {
		entry; then insertion;
		
		state insertion;
		then balloonInflation;
		
		state balloonInflation;
		then peristalticAdvancement;
		
		state peristalticAdvancement;
		then activeDecompression;
		
		state activeDecompression;
		then balloonDeflation;
		
		state balloonDeflation;
		then removal;
		
		state removal;
		then done;
	}
	
	action intestinalDecompression : IntestinalDecompression {
		first start;
		
		then action insertTube {
			doc /* Insert the Miller-Abbott tube through the nose, advancing it through the stomach into the duodenum. */
		}
		
		then action inflateBalloon : InflateBalloon {
			in targetVolume = 2.0 [SI::mL];
			out achievedPressure;
			out inflationSuccess;
		}
		
		then merge advancementCycle;
		
		then action waitForPeristalsis {
			doc /* Allow intestinal peristalsis to propel the weighted, inflated balloon distally through the small intestine. */
		}
		
		then action monitorPosition : MonitorTubePosition {
			in currentDepth = millerAbbottSystem.tube.currentPosition;
			in targetDepth = 2.5 [SI::m];
			out positionReached;
		}
		
		then decide positionCheck;
			if monitorPosition.positionReached == false then advancementCycle;
			if monitorPosition.positionReached == true then beginSuction;
		
		action beginSuction {
			then action activateSuction : ApplySuction {
				in suctionLevel = -80.0 [SI::kPa];
				in duration = 24.0 [SI::h];
				out aspiratedVolume;
			}
			
			then merge decompressionCycle;
			
			then action assessDecompression : AssessDecompression {
				in distensionLevel = millerAbbottSystem.intestinalTract.distensionLevel;
				in aspiratedVolume = activateSuction.aspiratedVolume;
				out decompressionComplete;
			}
			
			then decide decompressionCheck;
				if assessDecompression.decompressionComplete == false then decompressionCycle;
				if assessDecompression.decompressionComplete == true then deflateBalloon;
		}
		
		action deflateBalloon {
			doc /* Deflate the distal balloon to facilitate tube removal. */
		}
		
		then action removeTube {
			doc /* Withdraw the Miller-Abbott tube after successful intestinal decompression. */
		}
		
		then done;
	}
	
	requirement <'MAT-REQ-001'> primaryFunctionRequirement {
		doc /* The Miller-Abbott tube system shall decompress the obstructed or distended small intestine 
		       by continuous aspiration of accumulated gas and fluid through a long intestinal tube that 
		       is advanced distally via peristaltic propulsion of a mercury-weighted, inflatable distal balloon. */
		
		subject millerAbbottSystem;
		
		require constraint {
			millerAbbottSystem.tube.distalBalloon.isInflated == true
		}
		
		require constraint {
			millerAbbottSystem.suctionDevice.continuousSuction == true
		}
		
		require constraint {
			millerAbbottSystem.suctionDevice.suctionPressure < 0.0 [SI::kPa]
		}
	}
	
	requirement <'MAT-REQ-002'> decompressionEffectivenessRequirement {
		doc /* The system shall effectively reduce intestinal distension by removing accumulated 
		       intraluminal gas and fluid through continuous low-pressure suction applied to the 
		       aspiration lumen positioned at the site of obstruction. */
		
		assume constraint {
			millerAbbottSystem.intestinalTract.obstructionPresent == true or 
			millerAbbottSystem.intestinalTract.distensionLevel > 0.5
		}
		
		require primaryFunctionRequirement;
	}
	
	requirement <'MAT-REQ-003'> balloonAdvancementRequirement {
		doc /* The mercury-weighted, inflated distal balloon shall be propelled distally through 
		       the small intestine by normal peristaltic activity to position the aspiration ports 
		       at or beyond the site of obstruction. */
		
		assume constraint {
			millerAbbottSystem.intestinalTract.peristalticActivity == true
		}
		
		require constraint {
			millerAbbottSystem.tube.distalBalloon.balloonVolume >= 1.0 [SI::mL] and
			millerAbbottSystem.tube.distalBalloon.balloonVolume <= 3.0 [SI::mL]
		}
		
		require constraint {
			millerAbbottSystem.tube.mercuryTip.mass >= 4.0 [SI::g] and
			millerAbbottSystem.tube.mercuryTip.mass <= 6.0 [SI::g]
		}
	}
	
	requirement <'MAT-REQ-004'> suctionSafetyRequirement {
		doc /* The suction pressure applied to the aspiration lumen shall not exceed safe limits 
		       to prevent mucosal injury while maintaining effective decompression. */
		
		require constraint {
			millerAbbottSystem.suctionDevice.suctionPressure >= -120.0 [SI::kPa] and
			millerAbbottSystem.suctionDevice.suctionPressure <= -60.0 [SI::kPa]
		}
	}
}
