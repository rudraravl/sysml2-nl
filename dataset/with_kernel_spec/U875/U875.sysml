package 'Sextant Navigation System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	
	item def CelestialBody;
	item def Horizon;
	item def LightRay;
	item def GeographicPosition;
	item def LineOfPosition;
	
	attribute def Angle :> Real;
	attribute def Height :> Real;
	
	item def SightData {
		attribute measuredAngle : Angle;
		attribute sightTime : Real;
		attribute observerHeight : Height;
	}
	
	part def Frame;
	part def Telescope {
		port opticalIn : LightRay;
	}
	part def IndexMirror {
		port mirrorIn : LightRay;
		port mirrorOut : LightRay;
	}
	part def MicrometerDrum;
	part def ArcScale;
	part def IndexArm {
		part indexMirror : IndexMirror;
		part micrometerDrum : MicrometerDrum;
		port celestialIn : LightRay;
		port reflectedOut : LightRay;
		connect celestialIn to indexMirror.mirrorIn;
		connect indexMirror.mirrorOut to reflectedOut;
	}
	part def HorizonGlass {
		port reflectedIn : LightRay;
		port horizonIn : LightRay;
		port opticalOut : LightRay;
	}
	part def ShadingFilter {
		port filterIn : LightRay;
		port filterOut : LightRay;
	}
	
	action def AdjustArm { in body : CelestialBody; out alignedView : LightRay; }
	action def LockArm { in alignedView : LightRay; out lockedAngle : Angle; }
	action def ReadAngle { in lockedAngle : Angle; out sight : SightData; }
	
	action def TakeSight {
		in body : CelestialBody;
		in horizon : Horizon;
		out sight : SightData;
		
		first start;
		then action adjustArm : AdjustArm {
			in body;
			out alignedView;
		}
		then action lockArm : LockArm {
			in alignedView;
			out lockedAngle;
		}
		then action readAngle : ReadAngle {
			in lockedAngle;
			out sight;
		}
		then done;
	}
	
	state machine def SextantStates {
		state stowed;
		state ready;
		state sighting;
		state locked;
		transition from stowed to ready;
		transition from ready to sighting;
		transition from sighting to locked;
		transition from locked to ready;
	}
	
	part def Sextant {
		part frame : Frame;
		part telescope : Telescope;
		part indexArm : IndexArm;
		part horizonGlass : HorizonGlass;
		part shadingFilters : ShadingFilter[0..*];
		part arcScale : ArcScale;
		
		port horizonLightIn : LightRay;
		port celestialLightIn : LightRay;
		port alignedViewOut : LightRay;
		
		connect celestialLightIn to indexArm.celestialIn;
		connect indexArm.reflectedOut to horizonGlass.reflectedIn;
		connect horizonLightIn to horizonGlass.horizonIn;
		connect horizonGlass.opticalOut to telescope.opticalIn;
		
		exhibit sextantStates : SextantStates;
		
		perform action takeSight : TakeSight[*];
	}
	
	action def CorrectSight { in rawSight : SightData; in observerHeight : Height; out correctedSight : SightData; }
	action def CalculateLOP { in correctedSight : SightData; out lop : LineOfPosition; }
	action def DetermineFix { in lop1 : LineOfPosition; in lop2 : LineOfPosition; out fix : GeographicPosition; }
	
	action def Navigate {
		in body1 : CelestialBody;
		in body2 : CelestialBody;
		in horizon : Horizon;
		in observerHeight : Height;
		out fix : GeographicPosition;
		
		first start;
		then action takeSight1 : TakeSight {
			in body = body1;
			in horizon = horizon;
			out sight;
		}
		then action correctSight1 : CorrectSight {
			in rawSight = takeSight1.sight;
			in observerHeight = observerHeight;
			out correctedSight;
		}
		then action calculateLOP1 : CalculateLOP {
			in correctedSight = correctSight1.correctedSight;
			out lop;
		}
		then action takeSight2 : TakeSight {
			in body = body2;
			in horizon = horizon;
			out sight;
		}
		then action correctSight2 : CorrectSight {
			in rawSight = takeSight2.sight;
			in observerHeight = observerHeight;
			out correctedSight;
		}
		then action calculateLOP2 : CalculateLOP {
			in correctedSight = correctSight2.correctedSight;
			out lop;
		}
		then action determineFix : DetermineFix {
			in lop1 = calculateLOP1.lop;
			in lop2 = calculateLOP2.lop;
			out fix;
		}
		flow from determineFix.fix to fix;
		then done;
	}
	
	requirement def MeasureAngleRequirement {
		doc /* The sextant shall measure the angular height of a celestial body above the horizon. */
		subject sextant : Sextant;
		objective {
			doc /* The measured angle must be accurate to within 1 arcminute. */
		}
	}
	
	requirement def NavigationRequirement {
		doc /* The system shall determine the geographic position using at least two celestial sights. */
		subject navigationProcess : Navigate;
		objective {
			doc /* The calculated fix must represent the intersection of the lines of position. */
		}
	}
}
