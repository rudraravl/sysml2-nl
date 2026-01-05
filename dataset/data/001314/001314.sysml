package 'Wavefront Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	comment about WavefrontSensingUnit
	/* This model describes a wavefront sensing unit that measures optical 
	 * wavefront aberrations using a Shack-Hartmann sensor configuration.
	 * The system captures incoming light through a lenslet array, analyzes
	 * the focal spot pattern to determine local wavefront slopes, and
	 * reconstructs the complete wavefront profile with Zernike decomposition. */
	
	attribute def WavefrontErrorUnit :> LengthUnit;
	
	attribute def WavefrontErrorValue :> LengthValue {
		attribute :>> num : Real;
		attribute :>> mRef : WavefrontErrorUnit;
	}
	
	attribute def WavelengthValue :> LengthValue;
	
	attribute def IntensityUnit :> MeasurementUnit {
		private attribute powerPF : UnitPowerFactor[1] {
			attribute :>> unit = PowerUnit;
			attribute :>> exponent = 1;
		}
		private attribute areaPF : UnitPowerFactor[2] {
			attribute :>> unit = AreaUnit;
			attribute :>> exponent = -1;
		}
		attribute :>> unitPowerFactor = (powerPF, areaPF);
	}
	
	attribute def IntensityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : IntensityUnit;
	}
	
	attribute def ZernikeMode {
		attribute modeIndex : Integer;
		attribute coefficient : WavefrontErrorValue;
		attribute modeName : String;
	}
	
	item def OpticalWavefront {
		attribute wavelength : WavelengthValue;
		attribute rmsError : WavefrontErrorValue;
		attribute peakToPeakError : WavefrontErrorValue;
		attribute intensity : IntensityValue;
	}
	
	item def SpotPattern {
		attribute spotPositionsX : Real[*];
		attribute spotPositionsY : Real[*];
		attribute spotIntensities : IntensityValue[*];
		attribute referencePositionsX : Real[*];
		attribute referencePositionsY : Real[*];
	}
	
	item def SlopeData {
		attribute xSlopesFlat : Real[*];
		attribute ySlopesFlat : Real[*];
		attribute validSubapertures : Integer;
	}
	
	item def WavefrontMeasurement {
		attribute timestamp : TimeValue;
		attribute wavefrontMapFlat : WavefrontErrorValue[*];
		attribute rmsError : WavefrontErrorValue;
		attribute zernikeModes : ZernikeMode[*];
		attribute strehlRatio : Real;
	}
	
	port def OpticalInputPort {
		in item incomingWavefront : OpticalWavefront;
	}
	
	port def MeasurementOutputPort {
		out item measurement : WavefrontMeasurement;
	}
	
	port def ControlPort {
		in attribute calibrate : Boolean;
		in attribute exposureTime : TimeValue;
		out attribute status : String;
	}
	
	action def CaptureSpotPattern {
		in item wavefront : OpticalWavefront;
		in attribute exposure : TimeValue;
		out item spotPattern : SpotPattern;
	}
	
	action def ComputeSlopes {
		in item spotPattern : SpotPattern;
		out item slopes : SlopeData;
	}
	
	action def ReconstructWavefront {
		in item slopes : SlopeData;
		in attribute wavelength : WavelengthValue;
		out item wavefrontMapFlat : WavefrontErrorValue[*];
		out attribute rmsError : WavefrontErrorValue;
	}
	
	action def DecomposeZernike {
		in item wavefrontMapFlat : WavefrontErrorValue[*];
		in attribute numModes : Integer;
		out item zernikeModes : ZernikeMode[*];
	}
	
	action def CalculateMetrics {
		in item wavefrontMapFlat : WavefrontErrorValue[*];
		in attribute wavelength : WavelengthValue;
		out attribute strehlRatio : Real;
		out attribute peakToPeak : WavefrontErrorValue;
	}
	
	action def MeasureWavefront {
		in item inputWavefront : OpticalWavefront;
		in attribute exposureTime : TimeValue;
		out item measurement : WavefrontMeasurement;
		
		bind capture.wavefront = inputWavefront;
		bind capture.exposure = exposureTime;
		
		action capture : CaptureSpotPattern {
			in item wavefront;
			in attribute exposure;
			out item spotPattern;
		}
		
		flow from capture.spotPattern to computeSlopes.spotPattern;
		
		action computeSlopes : ComputeSlopes {
			in item spotPattern;
			out item slopes;
		}
		
		flow from computeSlopes.slopes to reconstruct.slopes;
		
		action reconstruct : ReconstructWavefront {
			in item slopes;
			in attribute wavelength;
			out item wavefrontMapFlat;
			out attribute rmsError;
		}
		
		flow from reconstruct.wavefrontMapFlat to decompose.wavefrontMapFlat;
		flow from reconstruct.wavefrontMapFlat to calculateMetrics.wavefrontMapFlat;
		
		action decompose : DecomposeZernike {
			in item wavefrontMapFlat;
			in attribute numModes;
			out item zernikeModes;
		}
		
		action calculateMetrics : CalculateMetrics {
			in item wavefrontMapFlat;
			in attribute wavelength;
			out attribute strehlRatio;
			out attribute peakToPeak;
		}
		
		bind measurement.wavefrontMapFlat = reconstruct.wavefrontMapFlat;
		bind measurement.rmsError = reconstruct.rmsError;
		bind measurement.zernikeModes = decompose.zernikeModes;
		bind measurement.strehlRatio = calculateMetrics.strehlRatio;
	}
	
	state def SensorOperationalState {
		entry; then idle;
		
		state idle;
		
		accept at when calibrate
			then calibrating;
		
		state calibrating;
		then idle;
		
		accept at when incomingWavefront
			then measuring;
		
		state measuring;
		then idle;
		
		state error;
	}
	
	part def LensletArray {
		attribute pitch : LengthValue;
		attribute focalLength : LengthValue;
		attribute subapertureCountX : Integer;
		attribute subapertureCountY : Integer;
		attribute fillFactor : Real;
	}
	
	part def DetectorArray {
		attribute pixelSize : LengthValue;
		attribute resolutionX : Integer;
		attribute resolutionY : Integer;
		attribute quantumEfficiency : Real;
		attribute readoutNoise : Real;
		attribute darkCurrent : Real;
	}
	
	part def SignalProcessor {
		attribute processingRate : FrequencyValue;
		attribute centroidAlgorithm : String;
		attribute reconstructionMethod : String;
	}
	
	part def CalibrationModule {
		attribute referenceWavelength : WavelengthValue;
		attribute calibrationAccuracy : WavefrontErrorValue;
	}
	
	part def WavefrontSensingUnit {
		port opticalInput : OpticalInputPort;
		port measurementOutput : MeasurementOutputPort;
		port control : ControlPort;
		
		part lensletArray : LensletArray[1] {
			attribute :>> pitch = 200.0[um];
			attribute :>> focalLength = 6.0[mm];
			attribute :>> subapertureCountX = 20;
			attribute :>> subapertureCountY = 20;
			attribute :>> fillFactor = 0.95;
		}
		
		part detector : DetectorArray[1] {
			attribute :>> pixelSize = 6.5[um];
			attribute :>> resolutionX = 1024;
			attribute :>> resolutionY = 1024;
			attribute :>> quantumEfficiency = 0.80;
			attribute :>> readoutNoise = 3.5;
			attribute :>> darkCurrent = 0.01;
		}
		
		part processor : SignalProcessor[1] {
			attribute :>> processingRate = 200.0[Hz];
			attribute :>> centroidAlgorithm = "Center of Mass";
			attribute :>> reconstructionMethod = "Least Squares";
		}
		
		part calibration : CalibrationModule[1] {
			attribute :>> referenceWavelength = 633.0[nm];
			attribute :>> calibrationAccuracy = 0.02[um];
		}
		
		connection opticalPath connect opticalInput to lensletArray;
		connection imagingPath connect lensletArray to detector;
		connection dataPath connect detector to processor;
		connection outputPath connect processor to measurementOutput;
		connection controlPath connect control to calibration;
		
		perform action measurementSequence : MeasureWavefront {
			in item inputWavefront = opticalInput.incomingWavefront;
			in attribute exposureTime = control.exposureTime;
			out item measurement = measurementOutput.measurement;
		}
		
		exhibit state operationalBehavior : SensorOperationalState;
	}
	
	requirement def AccuracyRequirement {
		doc /* The wavefront sensing unit shall measure wavefront aberrations
		     * with RMS accuracy better than lambda/20 at the reference wavelength. */
		
		subject sensor : WavefrontSensingUnit;
		
		require constraint {
			sensor.calibration.calibrationAccuracy.num < 
				(sensor.calibration.referenceWavelength.num / 20.0)
		}
	}
	
	requirement def SpatialResolutionRequirement {
		doc /* The wavefront sensing unit shall provide spatial sampling
		     * with at least 400 subapertures across the aperture. */
		
		subject sensor : WavefrontSensingUnit;
		
		require constraint {
			sensor.lensletArray.subapertureCountX * 
			sensor.lensletArray.subapertureCountY >= 400
		}
	}
	
	requirement def TemporalResolutionRequirement {
		doc /* The wavefront sensing unit shall acquire and process measurements
		     * at a minimum rate of 100 Hz for closed-loop applications. */
		
		subject sensor : WavefrontSensingUnit;
		
		require constraint {
			sensor.processor.processingRate.num >= 100.0
		}
	}
	
	requirement def DynamicRangeRequirement {
		doc /* The wavefront sensing unit shall measure wavefront errors
		     * up to 10 micrometers peak-to-peak. */
		
		subject sensor : WavefrontSensingUnit;
		
		attribute maxError : WavefrontErrorValue = 10.0[um];
	}
	
	requirement def SystemRequirements {
		doc /* Top-level requirements for the wavefront sensing unit system. */
		
		requirement accuracyReq : AccuracyRequirement;
		requirement spatialReq : SpatialResolutionRequirement;
		requirement temporalReq : TemporalResolutionRequirement;
		requirement dynamicReq : DynamicRangeRequirement;
	}
	
	part wavefrontSensor : WavefrontSensingUnit {
		satisfy SystemRequirements by wavefrontSensor;
	}
}
