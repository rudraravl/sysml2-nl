package 'Bubble Chamber System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	private import Time::*;

	item def ChargedParticle {
		attribute charge : ElectricChargeValue;
		attribute momentum : MomentumValue;
	}
	item def SuperheatedLiquid;
	item def BubbleTrack {
		attribute path : LengthValue[3];
	}
	item def Photograph;
	item def LightFlash;

	attribute def ParticleDetected;
	attribute def ExpansionComplete;
	attribute def TrackFormed;
	attribute def ImageCaptured;

	action def DropPressure {
		in currentPressure : PressureValue;
		out newPressure : PressureValue;
	}
	action def Recompress {
		in currentPressure : PressureValue;
		out newPressure : PressureValue;
	}
	action def Flash {
		in duration : TimeValue;
	}
	action def TakePhoto {
		in exposure : TimeValue;
		out photo : Photograph;
	}
	action def FormTrack {
		in particle : ChargedParticle;
		in fieldStrength : MagneticFluxDensityValue;
		out track : BubbleTrack;
	}
	action def MaintainConditions {
		in targetTemp : TemperatureValue;
		in targetPressure : PressureValue;
	}
	action def ApplyField {
		in fieldStrength : MagneticFluxDensityValue;
	}

	part def ChamberVessel {
		attribute liquidTemperature : TemperatureValue;
		attribute internalPressure : PressureValue;
		attribute totalVolume : VolumeValue;
		in port liquidIn : SuperheatedLiquid;
		in port particleIn : ChargedParticle;
		in port lightIn : LightFlash;
	}

	part def LiquidSupplySystem {
		attribute targetTemp : TemperatureValue := 423 [K];
		attribute targetPressure : PressureValue := 500000 [Pa];
		out port liquidOut : SuperheatedLiquid;
	}

	part def ExpansionMechanism {
		attribute pistonPosition : LengthValue;
		attribute pistonVelocity : SpeedValue;
	}

	part def MagneticFieldSystem {
		attribute fieldStrength : MagneticFluxDensityValue := 1.5 [T];
		attribute uniformity : Real;
	}

	part def IlluminationSystem {
		attribute flashDuration : TimeValue := 0.001 [s];
		attribute peakIlluminance : Real := 1000;
		out port lightOut : LightFlash;
	}

	part def ImagingSystem {
		attribute resolution : Real := 10;
		attribute exposureTime : TimeValue := 0.001 [s];
		attribute numberOfCameras : Integer := 2;
		out port imageOut : Photograph;
	}

	part def BubbleChamber {
		part vessel : ChamberVessel;
		part supply : LiquidSupplySystem;
		part piston : ExpansionMechanism;
		part magnet : MagneticFieldSystem;
		part illuminator : IlluminationSystem;
		part camera : ImagingSystem;

		flow from supply.liquidOut to vessel.liquidIn;
		flow from illuminator.lightOut to vessel.lightIn;

		state operationStates {
			in chamber : BubbleChamber;
			entry; then stable;
			state stable {
				do action : MaintainConditions;
				do action : ApplyField;
			}
			accept ParticleDetected then expanding;
			state expanding {
				do action : DropPressure;
			}
			accept ExpansionComplete then tracking;
			state tracking {
				do action : FormTrack;
			}
			accept TrackFormed then imaging;
			state imaging {
				do action : Flash;
				do action : TakePhoto;
			}
			accept ImageCaptured then recompressing;
			state recompressing {
				do action : Recompress;
			}
			transition first recompressing then stable;
			constraint { DurationOf(expanding) <= 0.01 [s] }
			constraint { DurationOf(tracking) <= 0.02 [s] }
			constraint { DurationOf(recompressing) <= 0.01 [s] }
		}
	}

	requirement def SuperheatedLiquidCondition {
		doc "The liquid must be maintained in a superheated state just below its boiling point at high temperature and pressure.";
		subject chamber : BubbleChamber;
		require constraint { chamber.vessel.liquidTemperature >= 423 [K] };
		require constraint { chamber.vessel.internalPressure >= 500000 [Pa] };
	}

	requirement def MagneticFieldUniformity {
		doc "The magnetic field must be uniform to ensure particle trajectory curvature accurately reflects momentum and charge.";
		subject chamber : BubbleChamber;
		require constraint { chamber.magnet.fieldStrength >= 1.0 [T] };
		require constraint { chamber.magnet.uniformity <= 1.0 };
	}

	requirement def RapidCycleTiming {
		doc "The expansion, tracking, imaging, and recompression cycle must complete within 100 milliseconds.";
		subject chamber : BubbleChamber;
		require constraint { chamber.illuminator.flashDuration <= 0.001 [s] };
		require constraint { chamber.camera.exposureTime <= 0.001 [s] };
	}

	requirement def StereoscopicImaging {
		doc "The imaging system must use at least two cameras to capture stereoscopic photographs of bubble tracks.";
		subject chamber : BubbleChamber;
		require constraint { chamber.camera.numberOfCameras >= 2 };
		require constraint { chamber.camera.resolution >= 10 };
	}

	requirement def IlluminationRequirement {
		doc "The illumination system must provide a bright flash of at least 1000 lux for at least 1 millisecond.";
		subject chamber : BubbleChamber;
		require constraint { chamber.illuminator.peakIlluminance >= 1000 };
		require constraint { chamber.illuminator.flashDuration >= 0.001 [s] };
	}
}
