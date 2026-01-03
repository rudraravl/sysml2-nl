package 'Hirtz Compass System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MagneticHeading :> ISQ::PlaneAngleValue {
		doc /* Angular direction relative to magnetic north */
	}
	
	attribute def MagneticFieldVector {
		attribute intensity : ISQ::MagneticFluxDensityValue;
		attribute inclination : ISQ::PlaneAngleValue;
		attribute declination : ISQ::PlaneAngleValue;
	}
	
	attribute def DampingCoefficient :> Real {
		doc /* Damping factor for needle oscillation */
	}
	
	enum def CardinalDirection {
		N; NNE; NE; ENE; E; ESE; SE; SSE; S; SSW; SW; WSW; W; WNW; NW; NNW;
	}
	
	item def MagneticField {
		attribute vector : MagneticFieldVector;
	}
	
	port def MagneticFieldPort {
		in item magneticField : MagneticField;
	}
	
	port def HeadingPort {
		out heading : MagneticHeading;
		out cardinalDir : CardinalDirection;
	}
	
	part def MagnetizedNeedle {
		doc /* Freely rotating magnetized needle that aligns with Earth's magnetic field */
		in port fieldInput : MagneticFieldPort;
		out port needlePosition {
			out angle : MagneticHeading;
		}
		attribute magneticMoment : ISQ::MagneticDipoleMomentValue;
		attribute mass : ISQ::MassValue;
		attribute length : ISQ::LengthValue;
	}
	
	part def PivotAssembly {
		doc /* Low-friction pivot mechanism allowing free needle rotation */
		attribute frictionCoefficient : DampingCoefficient;
		attribute pivotMaterial : String;
	}
	
	part def CompassCard {
		doc /* Graduated dial showing cardinal and intercardinal directions */
		in port angleInput {
			in needleAngle : MagneticHeading;
		}
		out port readingOutput {
			out heading : MagneticHeading;
			out direction : CardinalDirection;
		}
		attribute graduationInterval : ISQ::PlaneAngleValue;
		attribute diameter : ISQ::LengthValue;
	}
	
	part def LiquidDampingChamber {
		doc /* Fluid-filled chamber providing damping to reduce needle oscillation */
		attribute fluidType : String;
		attribute viscosity : ISQ::DynamicViscosityValue;
		attribute volume : ISQ::VolumeValue;
	}
	
	part def ProtectiveHousing {
		doc /* Sealed housing protecting internal components from environment */
		attribute material : String;
		attribute sealType : String;
		attribute windowMaterial : String;
	}
	
	part def LubberLine {
		doc /* Fixed reference mark indicating forward direction of platform */
		attribute alignment : ISQ::PlaneAngleValue;
	}
	
	action def SenseEarthMagneticField {
		doc /* Detect ambient Earth magnetic field vector */
		out field : MagneticFieldVector;
	}
	
	action def AlignNeedleWithField {
		doc /* Rotate needle to align with magnetic field direction */
		in field : MagneticFieldVector;
		in dampingFactor : DampingCoefficient;
		out needleAngle : MagneticHeading;
	}
	
	action def StabilizeNeedle {
		doc /* Dampen needle oscillations to achieve stable reading */
		in needleAngle : MagneticHeading;
		in dampingFactor : DampingCoefficient;
		out stabilizedAngle : MagneticHeading;
	}
	
	action def DetermineCardinalDirection {
		doc /* Convert angular heading to cardinal direction */
		in heading : MagneticHeading;
		out direction : CardinalDirection;
	}
	
	action def IndicateMagneticHeading {
		doc /* Primary function: Continuously indicate magnetic heading for navigation */
		first start;
		then merge continuousSensing;
		then action sense : SenseEarthMagneticField {
			out magneticField : MagneticFieldVector;
		}
		then action align : AlignNeedleWithField {
			in field = sense.magneticField;
			in dampingFactor;
			out rawAngle : MagneticHeading;
		}
		then action stabilize : StabilizeNeedle {
			in needleAngle = align.rawAngle;
			in dampingFactor;
			out finalAngle : MagneticHeading;
		}
		then action determine : DetermineCardinalDirection {
			in heading = stabilize.finalAngle;
			out cardinalDir : CardinalDirection;
		}
		then continuousSensing;
	}
	
	state def CompassOperationalStates {
		doc /* Operational state machine for compass system */
		entry; then initializing;
		
		state initializing {
			doc /* System startup and self-check */
		}
		
		state seeking {
			doc /* Needle actively rotating to find magnetic north */
		}
		
		state settling {
			doc /* Needle oscillating around equilibrium position */
		}
		
		state stable {
			doc /* Needle aligned and stable, providing accurate reading */
		}
		
		state disturbed {
			doc /* External magnetic interference detected */
		}
		
		transition initializing_to_seeking
			first initializing
			then seeking;
		
		transition seeking_to_settling
			first seeking
			then settling;
		
		transition settling_to_stable
			first settling
			then stable;
		
		transition stable_to_disturbed
			first stable
			then disturbed;
		
		transition disturbed_to_seeking
			first disturbed
			then seeking;
		
		transition stable_to_seeking
			first stable
			then seeking;
	}
	
	requirement def HeadingAccuracyRequirement {
		doc /* Compass shall indicate magnetic heading within specified accuracy */
		subject compass : HirtzCompass;
		require constraint {
			compass.headingError <= 2.0
		}
	}
	
	requirement def SettlingTimeRequirement {
		doc /* Compass shall stabilize to accurate reading within specified time */
		subject compass : HirtzCompass;
		require constraint {
			compass.settlingTime <= 5.0
		}
	}
	
	requirement def OperatingTemperatureRequirement {
		doc /* Compass shall operate accurately across specified temperature range */
		subject compass : HirtzCompass;
		require constraint {
			compass.minOperatingTemp >= -40.0 and
			compass.maxOperatingTemp <= 70.0
		}
	}
	
	requirement def DampingRequirement {
		doc /* Compass shall provide adequate damping to prevent excessive oscillation */
		subject compass : HirtzCompass;
		require constraint {
			compass.dampingChamber.viscosity >= 50.0 and
			compass.dampingChamber.viscosity <= 200.0
		}
	}
	
	requirement def EnvironmentalSealRequirement {
		doc /* Compass housing shall be sealed against moisture and contaminants */
		subject compass : HirtzCompass;
		require constraint {
			compass.housing.sealType == "hermetic"
		}
	}
	
	part def HirtzCompass {
		doc /* 
			Hirtz magnetic compass system for continuous indication of magnetic heading.
			
			Primary Function: Sense the Earth's magnetic field and provide a continuous,
			stable visual indication of magnetic heading relative to magnetic north,
			enabling navigation and directional orientation.
			
			The system operates by allowing a magnetized needle to freely align with
			Earth's magnetic field. The needle's angular position is read against a
			graduated compass card to determine heading. Liquid damping stabilizes
			the needle against oscillations caused by platform motion or disturbances.
		*/
		
		part needle : MagnetizedNeedle {
			attribute :>> magneticMoment = 0.05;
			attribute :>> mass = 2.0;
			attribute :>> length = 50.0;
		}
		
		part pivot : PivotAssembly {
			attribute :>> frictionCoefficient = 0.02;
			attribute :>> pivotMaterial = "sapphire";
		}
		
		part card : CompassCard {
			attribute :>> graduationInterval = 5.0;
			attribute :>> diameter = 75.0;
		}
		
		part dampingChamber : LiquidDampingChamber {
			attribute :>> fluidType = "mineral oil";
			attribute :>> viscosity = 100.0;
			attribute :>> volume = 50.0;
		}
		
		part housing : ProtectiveHousing {
			attribute :>> material = "brass";
			attribute :>> sealType = "hermetic";
			attribute :>> windowMaterial = "glass";
		}
		
		part lubberLine : LubberLine {
			attribute :>> alignment = 0.0;
		}
		
		port headingOutput : HeadingPort;
		
		connect needle.needlePosition to card.angleInput;
		connect card.readingOutput to headingOutput;
		
		attribute headingError : Real;
		attribute settlingTime : Real;
		attribute minOperatingTemp : Real;
		attribute maxOperatingTemp : Real;
	}
	
	part hirtzCompassSystem : HirtzCompass {
		doc /* Operational instance of Hirtz compass system */
		
		perform action indicateHeading[*] : IndicateMagneticHeading;
		
		exhibit state operationalStates : CompassOperationalStates;
		
		attribute :>> headingError = 1.5;
		attribute :>> settlingTime = 4.0;
		attribute :>> minOperatingTemp = -40.0;
		attribute :>> maxOperatingTemp = 70.0;
	}
	
	requirement hirtzCompassRequirements {
		doc /* Complete requirements specification for Hirtz compass system */
		
		require accuracyReq : HeadingAccuracyRequirement;
		require settlingReq : SettlingTimeRequirement;
		require tempReq : OperatingTemperatureRequirement;
		require dampingReq : DampingRequirement;
		require sealReq : EnvironmentalSealRequirement;
		
		assume constraint earthFieldPresent {
			doc /* Earth's magnetic field is present and detectable */
		}
		
		assume constraint noStrongInterference {
			doc /* No strong local magnetic interference exceeding 10x Earth field */
		}
		
		assume constraint levelMounting {
			doc /* Compass is mounted on reasonably level platform */
		}
	}
}
