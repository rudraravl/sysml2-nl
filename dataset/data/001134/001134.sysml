package 'Magnetic Compass System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MagneticHeading :> ISQ::PlaneAngleValue {
		doc /* Directional heading measured in degrees from magnetic north (0-360 degrees) */
	}
	
	attribute def MagneticFluxDensity :> Real {
		doc /* Strength of the magnetic field in microtesla */
	}
	
	attribute def Declination :> ISQ::PlaneAngleValue {
		doc /* Angular difference between magnetic north and true north */
	}
	
	attribute def DampingCoefficient :> Real {
		doc /* Coefficient describing resistance to needle motion */
	}
	
	item def EarthMagneticField {
		attribute fieldStrength : MagneticFluxDensity;
		attribute fieldDirection : MagneticHeading;
		attribute localDeclination : Declination;
	}
	
	part def MagnetizedNeedle {
		attribute magneticMoment : Real;
		attribute currentOrientation : MagneticHeading;
		attribute mass : ISQ::MassValue;
		
		port magneticInterface {
			in item ambientField : EarthMagneticField;
			out attribute needleDirection : MagneticHeading;
		}
	}
	
	part def PivotAssembly {
		attribute frictionCoefficient : Real;
		attribute bearingType : String;
		doc /* Low-friction pivot allowing free needle rotation */
	}
	
	part def CompassRose {
		attribute numberOfGraduations : Integer;
		attribute cardinalDirections : String[4] := ("N", "E", "S", "W");
		attribute intercardinalDirections : String[4] := ("NE", "SE", "SW", "NW");
		doc /* Graduated circular dial with directional markings */
	}
	
	part def ProtectiveHousing {
		attribute housingMaterial : String;
		attribute isWaterproof : Boolean;
		attribute hasViewingWindow : Boolean;
		doc /* Sealed enclosure protecting internal mechanism */
	}
	
	part def DampingMedium {
		attribute fluidViscosity : Real;
		attribute mediumType : String;
		doc /* Damping fluid reducing needle oscillation */
	}
	
	part def LubberLine {
		attribute lineWidth : ISQ::LengthValue;
		attribute alignment : String;
		doc /* Reference mark indicating forward direction of compass */
	}
	
	action def SenseEarthField {
		in environmentalField : EarthMagneticField;
		out detectedField : EarthMagneticField;
		doc /* Detect the ambient Earth magnetic field */
	}
	
	action def AlignToField {
		in magneticField : EarthMagneticField;
		in needleOrientation : MagneticHeading;
		out alignedOrientation : MagneticHeading;
		doc /* Align magnetized needle with magnetic field lines */
	}
	
	action def StabilizeNeedle {
		in needleVelocity : Real;
		in dampingFactor : DampingCoefficient;
		out stabilizedVelocity : Real;
		doc /* Apply damping to reduce needle oscillation */
	}
	
	action def CorrectForDeclination {
		in magneticHeading : MagneticHeading;
		in declination : Declination;
		out trueHeading : MagneticHeading;
		doc /* Apply declination correction to obtain true heading */
	}
	
	action def IndicateDirection {
		in heading : MagneticHeading;
		out displayedHeading : MagneticHeading;
		doc /* Display the current heading on compass rose */
	}
	
	action def DetermineDirectionalHeading {
		doc /* Primary system function: continuously determine and indicate magnetic heading */
		
		in attribute earthField : EarthMagneticField;
		in attribute dampingCoeff : DampingCoefficient;
		out attribute indicatedHeading : MagneticHeading;
		
		private attribute needlePosition : MagneticHeading := 0.0;
		private attribute needleVelocity : Real := 0.0;
		
		first start;
		then merge continuousOperation;
		
		action sense : SenseEarthField {
			in environmentalField = earthField;
			out detectedField : EarthMagneticField;
		}
		
		then action align : AlignToField {
			in magneticField = sense.detectedField;
			in needleOrientation = needlePosition;
			out alignedOrientation : MagneticHeading;
		}
		
		then action stabilize : StabilizeNeedle {
			in needleVelocity = needleVelocity;
			in dampingFactor = dampingCoeff;
			out stabilizedVelocity : Real;
		}
		
		then action correct : CorrectForDeclination {
			in magneticHeading = align.alignedOrientation;
			in declination = earthField.localDeclination;
			out trueHeading : MagneticHeading;
		}
		
		then action indicate : IndicateDirection {
			in heading = correct.trueHeading;
			out displayedHeading : MagneticHeading;
		}
		
		then assign needlePosition := align.alignedOrientation;
		then assign needleVelocity := stabilize.stabilizedVelocity;
		then assign indicatedHeading := indicate.displayedHeading;
		then continuousOperation;
	}
	
	attribute def SystemReadySignal;
	attribute def FieldDisturbanceSignal;
	attribute def MinorDisturbanceSignal;
	
	state def CompassOperationalStates {
		entry; then initializing;
		
		state initializing {
			doc /* System startup, needle seeking magnetic north */
		}
		
		transition initializing_to_seeking
			first initializing
			accept SystemReadySignal
			then seeking;
		
		state seeking {
			doc /* Needle actively rotating to align with magnetic field */
		}
		
		transition seeking_to_stabilizing
			first seeking
			then stabilizing;
		
		state stabilizing {
			doc /* Damping oscillations to achieve steady reading */
		}
		
		transition stabilizing_to_steady
			first stabilizing
			then steady;
		
		state steady {
			doc /* Needle stable, accurate heading indicated */
		}
		
		transition steady_to_seeking
			first steady
			accept FieldDisturbanceSignal
			then seeking;
		
		transition steady_to_stabilizing
			first steady
			accept MinorDisturbanceSignal
			then stabilizing;
	}
	
	part def MagneticCompass {
		doc /* A magnetic compass system that determines and indicates directional heading 
		       by sensing the Earth's magnetic field and aligning a freely-rotating 
		       magnetized needle to magnetic north. The system provides continuous 
		       directional reference for navigation and orientation. */
		
		attribute headingAccuracy : ISQ::PlaneAngleValue;
		attribute stabilizationTime : ISQ::TimeValue;
		attribute stabilizationTolerance : ISQ::PlaneAngleValue;
		attribute minimumFieldStrength : Real;
		attribute maximumFieldStrength : Real;
		attribute operationalMode : String;
		attribute hasDampingMechanism : Boolean;
		attribute currentHeading : MagneticHeading;
		
		port environmentPort {
			in item earthField : EarthMagneticField;
		}
		
		port headingOutput {
			out attribute heading : MagneticHeading;
		}
		
		part needle : MagnetizedNeedle {
			perform determineHeading.align;
		}
		
		part pivot : PivotAssembly {
			doc /* Supports needle with minimal friction */
		}
		
		part rose : CompassRose {
			perform determineHeading.indicate;
		}
		
		part housing : ProtectiveHousing {
			doc /* Protects mechanism from environmental factors */
		}
		
		part dampingFluid : DampingMedium {
			perform determineHeading.stabilize;
		}
		
		part lubberLine : LubberLine {
			doc /* Provides reference alignment mark */
		}
		
		perform action determineHeading : DetermineDirectionalHeading {
			in earthField = environmentPort.earthField;
			in dampingCoeff = dampingFluid.fluidViscosity;
			out indicatedHeading : MagneticHeading;
		}
		
		exhibit state operationalStates : CompassOperationalStates;
		
		connection needleToPivot connect needle to pivot;
		connection needleToRose connect needle to rose;
		connection fluidToNeedle connect dampingFluid to needle;
		connection roseToLubberLine connect rose to lubberLine;
		connection housingContainment connect housing to needle;
		connection housingContainment2 connect housing to rose;
		
		flow environmentPort.earthField to needle.magneticInterface.ambientField;
		flow needle.magneticInterface.needleDirection to headingOutput.heading;
	}
	
	requirement def <'REQ-COMP-001'> PrimaryFunctionRequirement {
		doc /* The magnetic compass system shall continuously sense the Earth's magnetic 
		       field and align a magnetized needle to indicate the direction of magnetic 
		       north, thereby providing directional heading information to the user. */
		
		subject compassSystem : MagneticCompass;
		
		require constraint {
			doc /* System shall provide continuous heading indication */
			compassSystem.operationalMode == "continuous"
		}
	}
	
	requirement def <'REQ-COMP-002'> AccuracyRequirement {
		doc /* The compass shall indicate magnetic heading with an accuracy of ±2 degrees 
		       under normal operating conditions. */
		
		subject compassSystem : MagneticCompass;
		
		require constraint {
			compassSystem.headingAccuracy <= 2.0
		}
	}
	
	requirement def <'REQ-COMP-003'> StabilizationRequirement {
		doc /* The compass needle shall stabilize to within ±1 degree of final reading 
		       within 6 seconds following disturbance. */
		
		subject compassSystem : MagneticCompass;
		
		require constraint {
			compassSystem.stabilizationTime <= 6.0 and
			compassSystem.stabilizationTolerance <= 1.0
		}
	}
	
	requirement def <'REQ-COMP-004'> OperatingEnvironmentRequirement {
		doc /* The compass shall operate accurately in magnetic field strengths ranging 
		       from 22 to 67 microtesla, corresponding to Earth's magnetic field at 
		       various latitudes. */
		
		subject compassSystem : MagneticCompass;
		
		require constraint {
			compassSystem.minimumFieldStrength >= 22.0 and
			compassSystem.maximumFieldStrength <= 67.0
		}
	}
	
	requirement def <'REQ-COMP-005'> DampingRequirement {
		doc /* The compass shall incorporate damping mechanism to prevent excessive 
		       needle oscillation and ensure readable indication. */
		
		subject compassSystem : MagneticCompass;
		
		require constraint {
			compassSystem.hasDampingMechanism == true
		}
	}
	
	part magneticCompassInstance : MagneticCompass {
		doc /* Operational instance of magnetic compass system for navigation */
		
		:>> headingAccuracy = 1.5;
		:>> stabilizationTime = 5.0;
		:>> stabilizationTolerance = 0.8;
		:>> minimumFieldStrength = 22.0;
		:>> maximumFieldStrength = 67.0;
		:>> operationalMode = "continuous";
		:>> hasDampingMechanism = true;
	}
	
	satisfy PrimaryFunctionRequirement by magneticCompassInstance;
	satisfy AccuracyRequirement by magneticCompassInstance;
	satisfy StabilizationRequirement by magneticCompassInstance;
	satisfy OperatingEnvironmentRequirement by magneticCompassInstance;
	satisfy DampingRequirement by magneticCompassInstance;
}
