package 'Wavefront Sensing Unit' {
	doc
	/*
	 * High-precision optical instrument using a Shack-Hartmann sensor configuration
	 * to measure wavefront aberrations. Suitable for telescopes, microscopes,
	 * and high-power lasers with real-time adaptive optics feedback.
	 */

	private import ISQ::*;
	private import ScalarValues::*;

	attribute def WavelengthValue :> ISQ::length;
	attribute def FocalLengthValue :> ISQ::length;
	attribute def PixelPitchValue :> ISQ::length;
	attribute def DisplacementValue :> ISQ::length;
	attribute def WavefrontHeightValue :> ISQ::length;
	attribute def RMSValue :> ISQ::length;
	attribute def PeakToValleyValue :> ISQ::length;
	attribute def SlopeValue :> Real;
	attribute def StrehlValue :> Real;
	attribute def ZernikeCoefficientValue :> Real;
	attribute def FrameRateValue :> Real;
	attribute def IntensityValue :> Real;

	item def LightBeam {
		attribute wavelength : WavelengthValue;
		attribute intensity : IntensityValue;
	}

	item def SpotPosition {
		attribute x : DisplacementValue;
		attribute y : DisplacementValue;
	}

	item def SpotPattern {
		attribute measuredSpots : SpotPosition[*];
		attribute referenceSpots : SpotPosition[*];
	}

	item def DetectorImage {
		attribute pixelData : IntensityValue[*];
		attribute rows : Natural;
		attribute cols : Natural;
	}

	item def Slopes {
		attribute slopeX : SlopeValue[*];
		attribute slopeY : SlopeValue[*];
	}

	item def Wavefront {
		attribute heightMap : WavefrontHeightValue[*];
	}

	item def AberrationMetrics {
		attribute rmsError : RMSValue;
		attribute peakToValley : PeakToValleyValue;
		attribute strehlRatio : StrehlValue;
		attribute zernikeModes : ZernikeCoefficientValue[*];
	}

	port def OpticalInPort {
		in beam : LightBeam;
	}

	port def OpticalOutPort {
		out beam : LightBeam;
	}

	port def ImageOutPort {
		out image : DetectorImage;
	}

	port def ImageInPort {
		in image : DetectorImage;
	}

	port def WavefrontOutPort {
		out wavefront : Wavefront;
	}

	port def WavefrontInPort {
		in wavefront : Wavefront;
	}

	port def MetricsOutPort {
		out metrics : AberrationMetrics;
	}

	calc def FindSpotCentroids {
		in image : DetectorImage;
		return : SpotPosition[*];
	}

	calc def ComputeSlopes {
		in measuredSpots : SpotPosition[*];
		in referenceSpots : SpotPosition[*];
		in pixelPitch : PixelPitchValue;
		in focalLength : FocalLengthValue;
		return : Slopes;
	}

	calc def ReconstructWavefront {
		in slopes : Slopes;
		return : Wavefront;
	}

	calc def ComputeRMS {
		in wf : Wavefront;
		return : RMSValue;
	}

	calc def ComputePeakToValley {
		in wf : Wavefront;
		return : PeakToValleyValue;
	}

	calc def ComputeStrehl {
		in wf : Wavefront;
		in wavelength : WavelengthValue;
		return : StrehlValue;
	}

	calc def DecomposeZernike {
		in wf : Wavefront;
		return : ZernikeCoefficientValue[*];
	}

	action def AcquireImage {
		in item beam : LightBeam;
		out item image : DetectorImage;
	}

	action def ProcessImage {
		in item image : DetectorImage;
		out item wavefront : Wavefront;
	}

	action def CharacterizeAberrations {
		in item wavefront : Wavefront;
		out item metrics : AberrationMetrics;
	}

	action def CalibrateReference {
		in item image : DetectorImage;
		out item referenceSpots : SpotPosition[*];
	}

	action def PerformMeasurement {
		in item beam : LightBeam;
		out item metrics : AberrationMetrics;
		bind acquire.beam = beam;
		action acquire : AcquireImage { in beam; out image; }
		succession flow from acquire.image to process.image;
		action process : ProcessImage { in image; out wavefront; }
		succession flow from process.wavefront to characterize.wavefront;
		action characterize : CharacterizeAberrations { in wavefront; out metrics; }
		bind characterize.metrics = metrics;
	}

	part def LensletArray {
		doc
		/*
		 * Grid of tiny lenses that breaks the incoming beam into many smaller beams,
		 * each focusing onto a specific spot on the detector array.
		 */
		attribute numLensletsX : Natural;
		attribute numLensletsY : Natural;
		attribute lensletFocalLength : FocalLengthValue;
		port opticalIn : OpticalInPort;
		port opticalOut : OpticalOutPort;
	}

	part def DetectorArray {
		doc
		/*
		 * High-resolution digital camera sensor that captures the focused spot
		 * pattern produced by the lenslet array.
		 */
		attribute numRows : Natural;
		attribute numCols : Natural;
		attribute pixelPitch : PixelPitchValue;
		port opticalIn : OpticalInPort;
		port imageOut : ImageOutPort;
	}

	part def SignalProcessor {
		doc
		/*
		 * Analyzes the detector image to find spot centroids, compares them to a
		 * calibrated reference grid, computes local wavefront slopes, and
		 * reconstructs the full two-dimensional wavefront.
		 */
		attribute processingRate : FrameRateValue;
		ref item referenceGrid : SpotPosition[*];
		port imageIn : ImageInPort;
		port wavefrontOut : WavefrontOutPort;
	}

	part def WavefrontAnalyzer {
		doc
		/*
		 * Characterizes the reconstructed wavefront by computing RMS error,
		 * peak-to-valley error, Strehl ratio, and Zernike mode coefficients.
		 */
		port wavefrontIn : WavefrontInPort;
		port metricsOut : MetricsOutPort;
	}

	state machine def OperatingState {
		doc
		/*
		 * Operating modes: standby (idle), calibration (establish reference grid
		 * for a perfect wavefront), and activeMeasurement (continuous sensing).
		 */
		initial state standby;
		state calibration;
		state activeMeasurement;

		transition from standby to calibration;
		transition from calibration to standby;
		transition from standby to activeMeasurement;
		transition from activeMeasurement to standby;
	}

	part def WavefrontSensingUnit {
		doc
		/*
		 * Shack-Hartmann wavefront sensor: incoming light passes through a lenslet
		 * array onto a detector array; a signal processor reconstructs the
		 * wavefront from spot displacements; a wavefront analyzer computes
		 * aberration metrics. Designed for over 100 measurements per second.
		 */
		attribute operatingRate : FrameRateValue;
		attribute operatingWavelength : WavelengthValue;

		port lightInput : OpticalInPort;
		port metricsOutput : MetricsOutPort;

		part lensletArray : LensletArray;
		part detectorArray : DetectorArray;
		part signalProcessor : SignalProcessor;
		part wavefrontAnalyzer : WavefrontAnalyzer;

		flow lightToLenslet : LightBeam
			from lightInput.beam to lensletArray.opticalIn.beam;
		flow lensletToDetector : LightBeam
			from lensletArray.opticalOut.beam to detectorArray.opticalIn.beam;
		flow detectorToProcessor : DetectorImage
			from detectorArray.imageOut.image to signalProcessor.imageIn.image;
		flow processorToAnalyzer : Wavefront
			from signalProcessor.wavefrontOut.wavefront to wavefrontAnalyzer.wavefrontIn.wavefront;
		flow analyzerToOutput : AberrationMetrics
			from wavefrontAnalyzer.metricsOut.metrics to metricsOutput.metrics;

		exhibit state operatingMode : OperatingState;
	}

	requirement def HighSpeedOperationRequirement {
		doc
		/*
		 * The unit shall acquire and process measurements at over 100 times per second.
		 */
		subject unit : WavefrontSensingUnit;
		assert constraint rateConstraint { unit.operatingRate >= 100.0 }
	}

	requirement def RealTimeFeedbackRequirement {
		doc
		/*
		 * The unit shall be suitable for real-time adaptive optics feedback
		 * and correction systems.
		 */
		subject unit : WavefrontSensingUnit;
		assert constraint feedbackRate { unit.operatingRate > 100.0 }
	}

	requirement def CalibrationModeRequirement {
		doc
		/*
		 * The unit shall support a calibration mode to establish a reference
		 * grid corresponding to a perfect, undistorted wavefront.
		 */
		subject unit : WavefrontSensingUnit;
	}

	requirement def WavefrontReconstructionRequirement {
		doc
		/*
		 * The signal processor shall reconstruct the complete two-dimensional
		 * wavefront from local slope measurements derived from spot displacements.
		 */
		subject processor : SignalProcessor;
	}

	requirement def AberrationMetricsRequirement {
		doc
		/*
		 * The system shall compute RMS wavefront error, peak-to-valley error,
		 * Strehl ratio, and Zernike mode coefficients including defocus,
		 * astigmatism, and coma.
		 */
		subject analyzer : WavefrontAnalyzer;
	}

	part wavefrontSensor : WavefrontSensingUnit {
		attribute operatingRate = 120.0;
		part redefines lensletArray {
			attribute numLensletsX = 20;
			attribute numLensletsY = 20;
		}
		part redefines detectorArray {
			attribute numRows = 2048;
			attribute numCols = 2048;
		}
		part redefines signalProcessor {
			attribute processingRate = 120.0;
		}
	}

	requirement highSpeedReq : HighSpeedOperationRequirement {
		subject unit = wavefrontSensor;
	}

	requirement realTimeReq : RealTimeFeedbackRequirement {
		subject unit = wavefrontSensor;
	}

	requirement calibReq : CalibrationModeRequirement {
		subject unit = wavefrontSensor;
	}

	requirement reconstructionReq : WavefrontReconstructionRequirement {
		subject processor = wavefrontSensor.signalProcessor;
	}

	requirement metricsReq : AberrationMetricsRequirement {
		subject analyzer = wavefrontSensor.wavefrontAnalyzer;
	}
}
