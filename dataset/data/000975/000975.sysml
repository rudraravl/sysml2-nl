package AngleSensitivePixelSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AngleDegrees :> Real;
	attribute def NormalizedIntensity :> Real;
	attribute def PixelResponseLevel :> Real;
	
	item def IncomingLight {
		attribute incidenceAngle : AngleDegrees;
		attribute intensity : NormalizedIntensity;
		attribute wavelength : LengthValue;
	}
	
	item def AngleData {
		attribute measuredAngle : AngleDegrees;
		attribute confidence : NormalizedIntensity;
		attribute timestamp : TimeValue;
	}
	
	item def PixelSignal {
		attribute responseA : PixelResponseLevel;
		attribute responseB : PixelResponseLevel;
		attribute combinedResponse : PixelResponseLevel;
	}
	
	port def OpticalPort {
		in item lightIn : IncomingLight;
	}
	
	port def SignalPort {
		out item signalOut : PixelSignal;
	}
	
	port def DataPort {
		out item dataOut : AngleData;
	}
	
	part def Microlens {
		attribute focalLength : LengthValue;
		attribute aperture : LengthValue;
		
		port opticalInput : OpticalPort;
		port opticalOutput : OpticalPort;
		
		action focusLight {
			in light : IncomingLight;
			out focusedLight : IncomingLight;
		}
	}
	
	part def DiffractionGrating {
		attribute gratingPitch : LengthValue;
		attribute diffractionOrder : Integer;
		
		port opticalInput : OpticalPort;
		port opticalOutput : OpticalPort;
		
		action diffractLight {
			in light : IncomingLight;
			out diffractedLight : IncomingLight;
		}
	}
	
	part def Photodetector {
		attribute quantumEfficiency : Real;
		attribute responsivity : Real;
		
		port opticalInput : OpticalPort;
		port signalOutput : SignalPort;
		
		action convertLightToSignal {
			in light : IncomingLight;
			out electricalSignal : PixelResponseLevel;
		}
	}
	
	part def AngleComputationUnit {
		attribute calibrationMatrix : Real[*];
		attribute angularRange : AngleDegrees;
		
		port signalInput : SignalPort;
		port dataOutput : DataPort;
		
		action computeAngle {
			in signalA : PixelResponseLevel;
			in signalB : PixelResponseLevel;
			out angleResult : AngleDegrees;
		}
	}
	
	part def AngleSensitivePixel {
		doc /* 
			An angle-sensitive pixel that determines the direction of incoming light
			by using dual photodetectors with different diffraction gratings to 
			measure angular information encoded in the light field.
		*/
		
		attribute pixelIdentifier : String;
		attribute sensitiveArea : AreaValue;
		attribute angularResolution : AngleDegrees;
		attribute operatingWavelength : LengthValue;
		
		port opticalInterface : OpticalPort;
		port angleDataOutput : DataPort;
		
		part lens : Microlens {
			attribute :>> focalLength = 5.0e-6 [m];
			attribute :>> aperture = 2.0e-6 [m];
		}
		
		part gratingChannelA : DiffractionGrating {
			attribute :>> gratingPitch = 400.0e-9 [m];
			attribute :>> diffractionOrder = 1;
		}
		
		part gratingChannelB : DiffractionGrating {
			attribute :>> gratingPitch = 450.0e-9 [m];
			attribute :>> diffractionOrder = 1;
		}
		
		part photodetectorA : Photodetector {
			attribute :>> quantumEfficiency = 0.85;
			attribute :>> responsivity = 0.6;
		}
		
		part photodetectorB : Photodetector {
			attribute :>> quantumEfficiency = 0.85;
			attribute :>> responsivity = 0.6;
		}
		
		part angleProcessor : AngleComputationUnit {
			attribute :>> angularRange = 90.0;
		}
		
		connect opticalInterface to lens.opticalInput;
		connect lens.opticalOutput to gratingChannelA.opticalInput;
		connect lens.opticalOutput to gratingChannelB.opticalInput;
		connect gratingChannelA.opticalOutput to photodetectorA.opticalInput;
		connect gratingChannelB.opticalOutput to photodetectorB.opticalInput;
		connect photodetectorA.signalOutput to angleProcessor.signalInput;
		connect photodetectorB.signalOutput to angleProcessor.signalInput;
		connect angleProcessor.dataOutput to angleDataOutput;
		
		perform action measureLightAngle;
	}
	
	action def CaptureLight {
		in incomingLight : IncomingLight;
		out capturedLight : IncomingLight;
	}
	
	action def SplitLightPath {
		in light : IncomingLight;
		out pathA : IncomingLight;
		out pathB : IncomingLight;
	}
	
	action def DetectDifferentialResponse {
		in responseA : PixelResponseLevel;
		in responseB : PixelResponseLevel;
		out differentialSignal : PixelSignal;
	}
	
	action def DeriveAngleFromSignal {
		in signal : PixelSignal;
		out angleData : AngleData;
	}
	
	action measureLightAngle {
		doc /* 
			Primary function: Measure the angle of incidence of incoming light
			by analyzing differential responses from two photodetectors with 
			distinct diffraction gratings, enabling directional light sensing.
		*/
		
		first start;
		
		then action captureIncomingLight : CaptureLight {
			out capturedLight;
		}
		
		then action focusWithLens {
			in light : IncomingLight = captureIncomingLight.capturedLight;
			out focusedLight : IncomingLight;
		}
		
		then action splitToChannels : SplitLightPath {
			in light = focusWithLens.focusedLight;
			out pathA;
			out pathB;
		}
		
		then action diffractChannelA {
			in lightA : IncomingLight = splitToChannels.pathA;
			out diffractedA : IncomingLight;
		}
		
		then action diffractChannelB {
			in lightB : IncomingLight = splitToChannels.pathB;
			out diffractedB : IncomingLight;
		}
		
		then action detectChannelA {
			in lightA : IncomingLight = diffractChannelA.diffractedA;
			out signalA : PixelResponseLevel;
		}
		
		then action detectChannelB {
			in lightB : IncomingLight = diffractChannelB.diffractedB;
			out signalB : PixelResponseLevel;
		}
		
		then action analyzeDifferential : DetectDifferentialResponse {
			in responseA = detectChannelA.signalA;
			in responseB = detectChannelB.signalB;
			out differentialSignal;
		}
		
		then action calculateAngle : DeriveAngleFromSignal {
			in signal = analyzeDifferential.differentialSignal;
			out angleData;
		}
		
		then action outputAngleData {
			in finalData : AngleData = calculateAngle.angleData;
		}
		
		then done;
	}
	
	state def PixelOperationalStates {
		attribute powerLevel : Real;
		
		entry; then idle;
		
		state idle {
			entry action setPowerLevelIdle {
				do assign powerLevel = 0.05;
			}
		}
		
		transition idleToReady
			first idle
			accept lightDetected
			then ready;
		
		state ready {
			entry action setPowerLevelReady {
				do assign powerLevel = 0.5;
			}
		}
		
		transition readyToMeasuring
			first ready
			accept startMeasurement
			then measuring;
		
		state measuring {
			entry action setPowerLevelMeasuring {
				do assign powerLevel = 1.0;
			}
			
			state capturingLight;
			
			transition capturingToProcessing
				first capturingLight
				accept captureComplete
				then processingSignal;
			
			state processingSignal;
			
			transition processingToComputing
				first processingSignal
				accept signalReady
				then computingAngle;
			
			state computingAngle;
		}
		
		transition measuringToReady
			first measuring
			accept measurementComplete
			then ready;
		
		transition readyToIdle
			first ready
			accept timeout
			then idle;
	}
	
	part angleSensitivePixelInstance : AngleSensitivePixel {
		attribute :>> pixelIdentifier = "ASP-PROTO-001";
		attribute :>> sensitiveArea = 16.0e-12 [m^2];
		attribute :>> angularResolution = 1.5;
		attribute :>> operatingWavelength = 550.0e-9 [m];
		
		perform action continuousAngleSensing {
			first start;
			then merge measurementLoop;
			
			then action singleMeasurement : measureLightAngle;
			
			then decide;
				if continueMeasuring then measurementLoop;
				if stopRequested then shutdown;
			
			action shutdown;
			then done;
			
			attribute continueMeasuring : Boolean;
			attribute stopRequested : Boolean;
		}
		
		exhibit state operationalBehavior : PixelOperationalStates;
	}
	
	requirement def AngularPrecisionRequirement {
		doc /* The pixel shall measure incident light angle with specified precision */
		
		subject pixel : AngleSensitivePixel;
		
		require constraint {
			doc /* Angular measurement precision shall be better than 2 degrees */
			pixel.angularResolution <= 2.0
		}
	}
	
	requirement def WavelengthRangeRequirement {
		doc /* The pixel shall operate across visible spectrum */
		
		subject pixel : AngleSensitivePixel;
		
		require constraint {
			doc /* Operating wavelength shall be in visible range 400-700 nm */
			pixel.operatingWavelength >= 400.0e-9 [m] and 
			pixel.operatingWavelength <= 700.0e-9 [m]
		}
	}
	
	requirement def DetectionEfficiencyRequirement {
		doc /* The pixel shall maintain high quantum efficiency */
		
		subject pixel : AngleSensitivePixel;
		
		require constraint {
			doc /* Quantum efficiency shall exceed 80% */
			pixel.photodetectorA.quantumEfficiency >= 0.80 and
			pixel.photodetectorB.quantumEfficiency >= 0.80
		}
	}
	
	requirement def AngularCoverageRequirement {
		doc /* The pixel shall cover wide angular range */
		
		subject pixel : AngleSensitivePixel;
		
		require constraint {
			doc /* Angular coverage shall be at least 80 degrees */
			pixel.angleProcessor.angularRange >= 80.0
		}
	}
	
	requirement primarySystemRequirements {
		doc /* 
			Top-level requirements for the angle-sensitive pixel system
			ensuring accurate directional light sensing capability
		*/
		
		require angularPrecision : AngularPrecisionRequirement;
		require wavelengthRange : WavelengthRangeRequirement;
		require detectionEfficiency : DetectionEfficiencyRequirement;
		require angularCoverage : AngularCoverageRequirement;
	}
}
