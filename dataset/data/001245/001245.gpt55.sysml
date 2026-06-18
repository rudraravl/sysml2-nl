package SextantNavigationSystem {

	import ScalarValues::*;

	attribute def Angle_deg :> Real {
		doc /* Plane angle measured in degrees. */
		attribute unitSymbol : String = "deg";
	}

	attribute def Angle_arcmin :> Real {
		doc /* Plane angle measured in arc minutes. */
		attribute unitSymbol : String = "arcmin";
	}

	attribute def Angle_arcsec :> Real {
		doc /* Plane angle measured in arc seconds. */
		attribute unitSymbol : String = "arcsec";
	}

	attribute def Length_mm :> Real {
		doc /* Linear dimension measured in millimeters. */
		attribute unitSymbol : String = "mm";
	}

	attribute def Time_s :> Real {
		doc /* Time duration measured in seconds. */
		attribute unitSymbol : String = "s";
	}

	attribute def Temperature_C :> Real {
		doc /* Temperature measured in degrees Celsius. */
		attribute unitSymbol : String = "degC";
	}

	attribute def Latitude_deg :> Real {
		doc /* Geodetic latitude measured in degrees north positive. */
		attribute unitSymbol : String = "deg";
	}

	attribute def Longitude_deg :> Real {
		doc /* Geodetic longitude measured in degrees east positive. */
		attribute unitSymbol : String = "deg";
	}

	attribute def DimensionlessRatio :> Real {
		doc /* Dimensionless ratio. */
		attribute unitSymbol : String = "1";
	}

	attribute def BooleanStatus :> Boolean;

	item def CelestialLight {
		attribute apparentAltitude : Angle_deg;
		attribute apparentDiameter : Angle_arcmin;
		attribute brightnessMagnitude : Real;
	}

	item def HorizonLight {
		attribute horizonDip : Angle_arcmin;
		attribute contrastRatio : DimensionlessRatio;
	}

	item def CombinedOpticalImage {
		attribute indexArmAngle : Angle_deg;
		attribute horizonReferenceVisible : BooleanStatus;
		attribute celestialBodyCentered : BooleanStatus;
	}

	item def ObserverCommand {
		attribute requestedObservation : String;
		attribute shadeSelectionCommanded : BooleanStatus;
		attribute clampReleased : BooleanStatus;
	}

	item def MicrometerSetting {
		attribute coarseArcReading : Angle_deg;
		attribute micrometerReading : Angle_arcmin;
		attribute vernierReading : Angle_arcsec;
	}

	item def CalibrationCorrection {
		attribute indexError : Angle_arcmin;
		attribute mirrorPerpendicularityError : Angle_arcmin;
		attribute shadeTransmissionRatio : DimensionlessRatio;
	}

	item def EnvironmentalCondition {
		attribute temperature : Temperature_C;
		attribute pressureEquivalentCorrection : Angle_arcmin;
		attribute horizonDipCorrection : Angle_arcmin;
	}

	item def ObservationTimeMark {
		attribute universalTimeSecondsOfDay : Time_s;
		attribute dateText : String;
		attribute chronometerUncertainty : Time_s;
	}

	item def SextantObservation {
		attribute observedAltitude : Angle_deg;
		attribute correctedAltitude : Angle_deg;
		attribute totalCorrection : Angle_arcmin;
		attribute measurementUncertainty : Angle_arcmin;
		attribute valid : BooleanStatus;
	}

	item def NauticalAlmanacData {
		attribute declination : Latitude_deg;
		attribute greenwichHourAngle : Longitude_deg;
		attribute semiDiameterCorrection : Angle_arcmin;
		attribute refractionCorrection : Angle_arcmin;
	}

	item def EstimatedPosition {
		attribute deadReckonedLatitude : Latitude_deg;
		attribute deadReckonedLongitude : Longitude_deg;
	}

	item def LineOfPosition {
		attribute interceptDistanceNauticalMiles : Real;
		attribute azimuth : Angle_deg;
		attribute tangentLatitude : Latitude_deg;
		attribute tangentLongitude : Longitude_deg;
		attribute confidenceArcMinutes : Angle_arcmin;
	}

	port def OpticalInputPort {
		in item light : CelestialLight;
	}

	port def HorizonInputPort {
		in item light : HorizonLight;
	}

	port def CombinedImagePort {
		out item image : CombinedOpticalImage;
	}

	port def CommandPort {
		in item command : ObserverCommand;
	}

	port def SettingPort {
		out item setting : MicrometerSetting;
	}

	port def CorrectionPort {
		out item correction : CalibrationCorrection;
	}

	port def EnvironmentPort {
		in item environment : EnvironmentalCondition;
	}

	port def TimePort {
		in item timeMark : ObservationTimeMark;
	}

	port def AlmanacPort {
		in item almanac : NauticalAlmanacData;
	}

	port def PositionEstimatePort {
		in item estimatedPosition : EstimatedPosition;
	}

	port def ObservationPort {
		out item observation : SextantObservation;
	}

	port def NavigationResultPort {
		out item lineOfPosition : LineOfPosition;
	}

	port def MechanicalAdjustmentPort {
		in item command : ObserverCommand;
		out item setting : MicrometerSetting;
	}

	part def IndexMirror {
		attribute flatnessError : Angle_arcsec = 5.0;
		attribute perpendicularityError : Angle_arcmin = 0.2;
		port celestialInput : OpticalInputPort;
		port reflectedOutput : CombinedImagePort;
	}

	part def HorizonMirror {
		attribute silveredFraction : DimensionlessRatio = 0.5;
		attribute transparencyFraction : DimensionlessRatio = 0.5;
		attribute perpendicularityError : Angle_arcmin = 0.2;
		port horizonInput : HorizonInputPort;
		port celestialReflectionInput : CombinedImagePort;
		port combinedImageOutput : CombinedImagePort;
	}

	part def Telescope {
		attribute magnification : DimensionlessRatio = 3.5;
		attribute objectiveDiameter : Length_mm = 40.0;
		attribute fieldOfView : Angle_deg = 5.0;
		port imageInput : CombinedImagePort;
		port eyepieceOutput : CombinedImagePort;
	}

	part def IndexArm {
		attribute currentAngle : Angle_deg = 0.0;
		attribute minimumAngle : Angle_deg = -5.0;
		attribute maximumAngle : Angle_deg = 130.0;
		attribute clampEngaged : BooleanStatus = true;
		port adjustment : MechanicalAdjustmentPort;
	}

	part def GraduatedArc {
		attribute radius : Length_mm = 162.0;
		attribute minimumGraduation : Angle_arcmin = 10.0;
		attribute arcRange : Angle_deg = 130.0;
		port settingOutput : SettingPort;
	}

	part def MicrometerDrum {
		attribute resolution : Angle_arcsec = 10.0;
		attribute backlash : Angle_arcsec = 5.0;
		port adjustment : MechanicalAdjustmentPort;
		port settingOutput : SettingPort;
	}

	part def ShadeSet {
		attribute solarShadeCount : Integer = 4;
		attribute horizonShadeCount : Integer = 3;
		attribute selectedTransmissionRatio : DimensionlessRatio = 1.0;
		port commandInput : CommandPort;
	}

	part def CalibrationSubsystem {
		attribute storedIndexError : Angle_arcmin = 0.0;
		attribute lastCalibrationAge : Time_s = 0.0;
		port correctionOutput : CorrectionPort;
	}

	part def ObserverInterface {
		port commandInput : CommandPort;
		port observedSettingInput : SettingPort;
		port imageInput : CombinedImagePort;
		port timeInput : TimePort;
		port observationOutput : ObservationPort;
	}

	part def NavigationReductionComputer {
		port observationInput : ObservationPort;
		port correctionInput : CorrectionPort;
		port environmentInput : EnvironmentPort;
		port timeInput : TimePort;
		port almanacInput : AlmanacPort;
		port estimatedPositionInput : PositionEstimatePort;
		port resultOutput : NavigationResultPort;
	}

	part def SextantSystem {
		doc /* A sextant-based navigation system whose primary high-level function is to measure the vertical angle between a celestial body and the visible horizon, correct that observation, and provide a celestial navigation line of position. */

		attribute instrumentMass_kg : Real = 1.45;
		attribute angularRange : Angle_deg = 130.0;
		attribute nominalResolution : Angle_arcsec = 10.0;
		attribute requiredObservationAccuracy : Angle_arcmin = 1.0;

		port skyLightIn : OpticalInputPort;
		port horizonLightIn : HorizonInputPort;
		port observerCommandIn : CommandPort;
		port environmentIn : EnvironmentPort;
		port observationTimeIn : TimePort;
		port almanacIn : AlmanacPort;
		port estimatedPositionIn : PositionEstimatePort;
		port observationOut : ObservationPort;
		port lineOfPositionOut : NavigationResultPort;

		part indexMirror : IndexMirror;
		part horizonMirror : HorizonMirror;
		part telescope : Telescope;
		part indexArm : IndexArm;
		part graduatedArc : GraduatedArc;
		part micrometerDrum : MicrometerDrum;
		part shadeSet : ShadeSet;
		part calibrationSubsystem : CalibrationSubsystem;
		part observerInterface : ObserverInterface;
		part navigationReductionComputer : NavigationReductionComputer;

		connect skyLightIn to indexMirror.celestialInput;
		connect horizonLightIn to horizonMirror.horizonInput;
		connect indexMirror.reflectedOutput to horizonMirror.celestialReflectionInput;
		connect horizonMirror.combinedImageOutput to telescope.imageInput;
		connect telescope.eyepieceOutput to observerInterface.imageInput;
		connect observerCommandIn to shadeSet.commandInput;
		connect observerCommandIn to observerInterface.commandInput;
		connect observerCommandIn to indexArm.adjustment;
		connect indexArm.adjustment to micrometerDrum.adjustment;
		connect micrometerDrum.settingOutput to observerInterface.observedSettingInput;
		connect graduatedArc.settingOutput to observerInterface.observedSettingInput;
		connect calibrationSubsystem.correctionOutput to navigationReductionComputer.correctionInput;
		connect environmentIn to navigationReductionComputer.environmentInput;
		connect observationTimeIn to observerInterface.timeInput;
		connect observationTimeIn to navigationReductionComputer.timeInput;
		connect almanacIn to navigationReductionComputer.almanacInput;
		connect estimatedPositionIn to navigationReductionComputer.estimatedPositionInput;
		connect observerInterface.observationOutput to navigationReductionComputer.observationInput;
		connect observerInterface.observationOutput to observationOut;
		connect navigationReductionComputer.resultOutput to lineOfPositionOut;
	}

	action def AcquireHorizon {
		in item horizonLight : HorizonLight;
		out item stabilizedHorizon : HorizonLight;
		attribute acquisitionTime : Time_s = 3.0;
	}

	action def AcquireCelestialBody {
		in item celestialLight : CelestialLight;
		out item selectedBodyLight : CelestialLight;
		attribute acquisitionTime : Time_s = 5.0;
	}

	action def SelectOpticalShades {
		in item command : ObserverCommand;
		out item attenuatedCelestialLight : CelestialLight;
		attribute selectedTransmissionRatio : DimensionlessRatio;
	}

	action def AlignImages {
		in item horizon : HorizonLight;
		in item celestialBody : CelestialLight;
		in item command : ObserverCommand;
		out item combinedImage : CombinedOpticalImage;
		attribute alignmentTolerance : Angle_arcmin = 0.5;
	}

	action def ReadArcAndMicrometer {
		in item image : CombinedOpticalImage;
		out item setting : MicrometerSetting;
		attribute readingResolution : Angle_arcsec = 10.0;
	}

	action def ApplyInstrumentCorrections {
		in item setting : MicrometerSetting;
		in item correction : CalibrationCorrection;
		out item correctedObservation : SextantObservation;
		attribute maximumAllowedIndexError : Angle_arcmin = 3.0;
	}

	action def ApplyEnvironmentalCorrections {
		in item uncorrectedObservation : SextantObservation;
		in item environment : EnvironmentalCondition;
		in item almanac : NauticalAlmanacData;
		out item correctedObservation : SextantObservation;
	}

	action def ComputeLineOfPosition {
		in item correctedObservation : SextantObservation;
		in item observationTime : ObservationTimeMark;
		in item almanac : NauticalAlmanacData;
		in item estimatedPosition : EstimatedPosition;
		out item lineOfPosition : LineOfPosition;
		attribute sphericalReductionMethod : String = "intercept";
	}

	action def PerformSextantSight {
		in item celestialLight : CelestialLight;
		in item horizonLight : HorizonLight;
		in item command : ObserverCommand;
		in item correction : CalibrationCorrection;
		in item environment : EnvironmentalCondition;
		in item timeMark : ObservationTimeMark;
		in item almanac : NauticalAlmanacData;
		in item estimatedPosition : EstimatedPosition;
		out item observation : SextantObservation;
		out item lineOfPosition : LineOfPosition;

		action acquireHorizon : AcquireHorizon {
			in horizonLight = PerformSextantSight::horizonLight;
		}

		action acquireBody : AcquireCelestialBody {
			in celestialLight = PerformSextantSight::celestialLight;
		}

		action selectShades : SelectOpticalShades {
			in command = PerformSextantSight::command;
		}

		action alignImages : AlignImages {
			in horizon = acquireHorizon.stabilizedHorizon;
			in celestialBody = acquireBody.selectedBodyLight;
			in command = PerformSextantSight::command;
		}

		action readSetting : ReadArcAndMicrometer {
			in image = alignImages.combinedImage;
		}

		action instrumentCorrection : ApplyInstrumentCorrections {
			in setting = readSetting.setting;
			in correction = PerformSextantSight::correction;
		}

		action environmentalCorrection : ApplyEnvironmentalCorrections {
			in uncorrectedObservation = instrumentCorrection.correctedObservation;
			in environment = PerformSextantSight::environment;
			in almanac = PerformSextantSight::almanac;
		}

		action reduceSight : ComputeLineOfPosition {
			in correctedObservation = environmentalCorrection.correctedObservation;
			in observationTime = PerformSextantSight::timeMark;
			in almanac = PerformSextantSight::almanac;
			in estimatedPosition = PerformSextantSight::estimatedPosition;
		}

		bind observation = environmentalCorrection.correctedObservation;
		bind lineOfPosition = reduceSight.lineOfPosition;
	}

	state def SextantOperationalState {
		doc /* Operational state behavior for observing and reducing a sextant sight. */

		state stowed;
		state deployed;
		state calibrated;
		state sighting;
		state reading;
		state reducing;
		state resultAvailable;
		state faulted;

		transition initial then stowed;
		transition deploy from stowed to deployed;
		transition calibrate from deployed to calibrated;
		transition beginSight from calibrated to sighting;
		transition imageAligned from sighting to reading;
		transition settingRead from reading to reducing;
		transition reductionComplete from reducing to resultAvailable;
		transition repeatSight from resultAvailable to sighting;
		transition stow from deployed to stowed;
		transition calibrationFault from calibrated to faulted;
		transition opticalFault from sighting to faulted;
		transition recover from faulted to deployed;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The sextant system shall measure the angular separation between a selected celestial body and the visible horizon and shall provide a corrected celestial navigation observation suitable for deriving a line of position. */
		subject sextant : SextantSystem;
		require constraint {
			sextant.angularRange >= 120.0
		}
	}

	requirement def AngularResolutionRequirement {
		doc /* The sextant system shall resolve angular settings to 10 arc seconds or finer. */
		subject sextant : SextantSystem;
		require constraint {
			sextant.nominalResolution <= 10.0
		}
	}

	requirement def ObservationAccuracyRequirement {
		doc /* After calibration and environmental correction, the sextant system shall support a corrected altitude uncertainty not greater than one arc minute under normal visible-horizon observing conditions. */
		subject sextant : SextantSystem;
		require constraint {
			sextant.requiredObservationAccuracy <= 1.0
		}
	}

	requirement def OpticalCombinationRequirement {
		doc /* The optical assembly shall superimpose reflected celestial light from the index mirror with direct horizon light at the horizon mirror so that the observer can align the celestial body with the horizon reference. */
		subject sextant : SextantSystem;
	}

	requirement def NavigationOutputRequirement {
		doc /* The navigation reduction function shall output a line of position containing intercept distance, azimuth, tangent latitude, tangent longitude, and confidence. */
		subject sextant : SextantSystem;
	}

	requirement def CalibrationRequirement {
		doc /* The sextant system shall provide an index-error correction and use it when converting micrometer and arc readings into corrected observed altitude. */
		subject sextant : SextantSystem;
		require constraint {
			sextant.calibrationSubsystem.storedIndexError >= -5.0 and sextant.calibrationSubsystem.storedIndexError <= 5.0
		}
	}

	part sextantNavigationSystem : SextantSystem;

	satisfy PrimaryFunctionRequirement by sextantNavigationSystem;
	satisfy AngularResolutionRequirement by sextantNavigationSystem;
	satisfy ObservationAccuracyRequirement by sextantNavigationSystem;
	satisfy OpticalCombinationRequirement by sextantNavigationSystem;
	satisfy NavigationOutputRequirement by sextantNavigationSystem;
	satisfy CalibrationRequirement by sextantNavigationSystem;
}
