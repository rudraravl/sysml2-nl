package StrainRateImagingSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def StrainRateValue :> Real;
	attribute def FrameRateValue :> FrequencyValue;
	attribute def DisplacementValue :> LengthValue;
	
	item def UltrasoundPulse {
		attribute frequency : FrequencyValue;
		attribute amplitude : PressureValue;
		attribute duration : TimeValue;
		attribute beamAngle : Real;
	}
	
	item def EchoData {
		attribute samples : Real;
		attribute samplingRate : FrequencyValue;
		attribute timestamp : TimeValue;
		attribute scanLineIndex : Integer;
	}
	
	item def TissueDisplacementField {
		attribute displacements : DisplacementValue;
		attribute spatialResolution : LengthValue;
		attribute temporalResolution : TimeValue;
	}
	
	item def VelocityField {
		attribute velocities : SpeedValue;
		attribute depths : LengthValue;
		attribute lateralPositions : LengthValue;
	}
	
	item def StrainRateMap {
		attribute strainRates : StrainRateValue;
		attribute imageWidth : LengthValue;
		attribute imageHeight : LengthValue;
		attribute acquisitionTime : TimeValue;
	}
	
	port def TransmitPort {
		out pulse : UltrasoundPulse;
	}
	
	port def ReceivePort {
		in echo : EchoData;
	}
	
	port def TissuePort {
		in incident : UltrasoundPulse;
		out reflected : EchoData;
	}
	
	port def DataOutputPort {
		out data : EchoData;
	}
	
	port def DataInputPort {
		in data : EchoData;
	}
	
	port def DisplacementOutputPort {
		out displacement : TissueDisplacementField;
	}
	
	port def DisplacementInputPort {
		in displacement : TissueDisplacementField;
	}
	
	port def VelocityOutputPort {
		out velocity : VelocityField;
	}
	
	port def VelocityInputPort {
		in velocity : VelocityField;
	}
	
	port def StrainOutputPort {
		out strain : StrainRateMap;
	}
	
	port def StrainInputPort {
		in strain : StrainRateMap;
	}
	
	action def TransmitReceiveCycle {
		in beamAngle : Real;
		in focusDepth : LengthValue;
		out pulse : UltrasoundPulse;
		out echo : EchoData;
		
		first action transmit {
			out emittedPulse : UltrasoundPulse;
		}
		then assign pulse := transmit.emittedPulse;
		then action receive {
			out receivedEcho : EchoData;
		}
		then assign echo := receive.receivedEcho;
	}
	
	action def BeamformEchoes {
		in rawEcho : EchoData;
		out beamformedData : EchoData;
		
		action applyDelays {
			in echo : EchoData;
			out delayedSignals : EchoData;
		}
		then action sumChannels {
			in signals : EchoData;
			out coherentSum : EchoData;
		}
		then assign beamformedData := sumChannels.coherentSum;
	}
	
	action def EstimateTissueDisplacement {
		in echoSequence : EchoData;
		out displacementField : TissueDisplacementField;
		
		action selectReferenceFrame {
			in echoes : EchoData;
			out reference : EchoData;
		}
		then action performSpeckleTracking {
			in reference : EchoData;
			in current : EchoData;
			out displacement : TissueDisplacementField;
		}
		then assign displacementField := performSpeckleTracking.displacement;
	}
	
	action def CalculateVelocityField {
		in displacement : TissueDisplacementField;
		in timeInterval : TimeValue;
		out velocity : VelocityField;
		
		action computeTemporalDerivative {
			in displacementData : TissueDisplacementField;
			in deltaTime : TimeValue;
			out velocityData : VelocityField;
		}
		then assign velocity := computeTemporalDerivative.velocityData;
	}
	
	action def ComputeStrainRate {
		in velocity : VelocityField;
		in spatialStep : LengthValue;
		out strainRate : StrainRateMap;
		
		action computeSpatialGradient {
			in velocityField : VelocityField;
			in dx : LengthValue;
			out gradientField : StrainRateValue;
		}
		then action applyTemporalFiltering {
			in rawStrainRate : StrainRateValue;
			out filteredStrainRate : StrainRateValue;
		}
		then action packageResult {
			in strainData : StrainRateValue;
			out strainMap : StrainRateMap;
		}
		then assign strainRate := packageResult.strainMap;
	}
	
	action def GenerateStrainRateImage {
		in strainData : StrainRateMap;
		
		action applyColorMapping {
			in strain : StrainRateMap;
		}
		then action renderToDisplay {
			in colorMappedData : StrainRateMap;
		}
	}
	
	action def ReflectUltrasound {
		in incident : UltrasoundPulse;
		out reflected : EchoData;
		
		action scatterFromTissue {
			in wave : UltrasoundPulse;
			out scatteredWave : EchoData;
		}
		then assign reflected := scatterFromTissue.scatteredWave;
	}
	
	action def ManageImagingSequence {
		in scanLines : Integer;
		in frameRate : FrameRateValue;
	}
	
	action def StrainRateImagingSequence {
		in attribute beamAngles : Real;
		in attribute imagingDepth :> ISQ::length;
		in attribute prf :> ISQ::frequency;
		in attribute frameInterval :> ISQ::time;
		out attribute strainRateFrames : StrainRateMap;
		
		perform action acquire : TransmitReceiveCycle {
			in beamAngle = beamAngles;
			in focusDepth = imagingDepth;
			out pulse;
			out echo;
		}
		then perform action beamform : BeamformEchoes {
			in rawEcho = acquire.echo;
			out beamformedData;
		}
		then perform action track : EstimateTissueDisplacement {
			in echoSequence = beamform.beamformedData;
			out displacementField;
		}
		then perform action estimateVelocity : CalculateVelocityField {
			in displacement = track.displacementField;
			in timeInterval = frameInterval;
			out velocity;
		}
		then perform action computeStrain : ComputeStrainRate {
			in velocity = estimateVelocity.velocity;
			in spatialStep = 1.0 [mm];
			out strainRate;
		}
		then perform action render : GenerateStrainRateImage {
			in strainData = computeStrain.strainRate;
		}
		then assign strainRateFrames := computeStrain.strainRate;
	}
	
	part def UltrasoundTransducer {
		port transmit : TransmitPort;
		port receive : ReceivePort;
		
		attribute centerFrequency : FrequencyValue;
		attribute elementCount : Integer;
		attribute aperture : LengthValue;
		
		perform action transmitReceiveCycle : TransmitReceiveCycle;
	}
	
	part def Beamformer {
		port dataIn : DataInputPort;
		port dataOut : DataOutputPort;
		
		attribute focusDepth : LengthValue;
		attribute beamSpacing : LengthValue;
		
		perform action formBeam : BeamformEchoes;
	}
	
	part def MotionTracker {
		port echoIn : DataInputPort;
		port displacementOut : DisplacementOutputPort;
		
		attribute trackingKernelSize : LengthValue;
		attribute searchRegionSize : LengthValue;
		attribute correlationThreshold : Real;
		
		perform action trackTissueMotion : EstimateTissueDisplacement;
	}
	
	part def VelocityEstimator {
		port displacementIn : DisplacementInputPort;
		port velocityOut : VelocityOutputPort;
		
		attribute frameInterval : TimeValue;
		
		perform action computeVelocity : CalculateVelocityField;
	}
	
	part def StrainRateProcessor {
		port velocityIn : VelocityInputPort;
		port strainOut : StrainOutputPort;
		
		attribute spatialFilterSize : LengthValue;
		attribute derivativeMethod : String;
		
		perform action calculateStrainRate : ComputeStrainRate;
	}
	
	part def ImageRenderer {
		port strainIn : StrainInputPort;
		
		attribute colorMap : String;
		attribute dynamicRange : Real;
		attribute displayFrameRate : FrameRateValue;
		
		perform action renderImage : GenerateStrainRateImage;
	}
	
	part def MyocardialTissue {
		port tissueInterface : TissuePort;
		
		attribute elasticModulus : PressureValue;
		attribute density : DensityValue;
		attribute thickness : LengthValue;
		
		perform action respondToUltrasound : ReflectUltrasound;
	}
	
	part def SystemController {
		attribute imagingMode : String;
		attribute frameRate : FrameRateValue;
		attribute sectorAngle : Real;
		
		perform action controlImaging : ManageImagingSequence;
	}
	
	part strainRateImager {
		part transducer : UltrasoundTransducer {
			attribute :>> centerFrequency = 3500000.0 [Hz];
			attribute :>> elementCount = 128;
			attribute :>> aperture = 0.038 [m];
		}
		
		part beamformer : Beamformer {
			attribute :>> focusDepth = 0.08 [m];
			attribute :>> beamSpacing = 0.0005 [m];
		}
		
		part motionTracker : MotionTracker {
			attribute :>> trackingKernelSize = 0.002 [m];
			attribute :>> searchRegionSize = 0.004 [m];
			attribute :>> correlationThreshold = 0.85;
		}
		
		part velocityEstimator : VelocityEstimator {
			attribute :>> frameInterval = 0.02 [s];
		}
		
		part strainProcessor : StrainRateProcessor {
			attribute :>> spatialFilterSize = 0.003 [m];
			attribute :>> derivativeMethod = "least_squares_gradient";
		}
		
		part renderer : ImageRenderer {
			attribute :>> colorMap = "velocity_colormap";
			attribute :>> dynamicRange = 40.0;
			attribute :>> displayFrameRate = 50.0 [Hz];
		}
		
		part tissue : MyocardialTissue {
			attribute :>> elasticModulus = 15000.0 [Pa];
			attribute :>> density = 1055.0 [kg/(m^3)];
			attribute :>> thickness = 0.012 [m];
		}
		
		part controller : SystemController {
			attribute :>> imagingMode = "strain_rate";
			attribute :>> frameRate = 50.0 [Hz];
			attribute :>> sectorAngle = 90.0;
		}
		
		connect transducer.transmit to tissue.tissueInterface;
		connect tissue.tissueInterface to transducer.receive;
		connect transducer.receive to beamformer.dataIn;
		connect beamformer.dataOut to motionTracker.echoIn;
		connect motionTracker.displacementOut to velocityEstimator.displacementIn;
		connect velocityEstimator.velocityOut to strainProcessor.velocityIn;
		connect strainProcessor.strainOut to renderer.strainIn;
		
		perform action imagingSequence : StrainRateImagingSequence;
	}
	
	state def ImagingSystemState {
		entry action initialize;
		
		state Idle {
			entry action powerOn;
		}
		
		state Calibrating {
			entry action runCalibration;
		}
		
		state Imaging {
			entry action startAcquisition;
			do action continuousImaging;
			exit action stopAcquisition;
		}
		
		state Processing {
			do action processData;
		}
		
		state Displaying {
			do action updateDisplay;
		}
		
		state Fault {
			entry action logError;
		}
		
		transition idleToCalibrating
			first Idle
			accept at 0 [s]
			then Calibrating;
			
		transition calibratingToImaging
			first Calibrating
			accept at 0 [s]
			then Imaging;
			
		transition imagingToProcessing
			first Imaging
			accept at 0 [s]
			then Processing;
			
		transition processingToDisplaying
			first Processing
			accept at 0 [s]
			then Displaying;
			
		transition displayingToImaging
			first Displaying
			accept at 0 [s]
			then Imaging;
			
		transition anyToFault
			first Imaging
			accept at 0 [s]
			then Fault;
	}
	
	requirement def FunctionalRequirement;
	requirement def PerformanceRequirement;
	requirement def SafetyRequirement;
	
	requirement <'SRI-F-001'> primaryFunction : FunctionalRequirement {
		doc /* The strain rate imaging system shall acquire sequential ultrasound echo data from myocardial tissue,
		     track tissue displacement over time using speckle tracking algorithms, compute tissue velocity fields
		     from temporal displacement gradients, calculate myocardial strain rate as the spatial gradient of
		     tissue velocity, and display real-time color-coded strain rate maps to enable clinical assessment
		     of regional myocardial contractile function and mechanical properties. */
		
		subject system : strainRateImager;
	}
	
	requirement <'SRI-P-001'> temporalResolution : PerformanceRequirement {
		doc /* The system shall achieve a frame rate of at least 50 frames per second to capture rapid cardiac motion. */
		
		subject system : strainRateImager;
		
		require constraint {
			system.controller.frameRate >= 50.0 [Hz]
		}
	}
	
	requirement <'SRI-P-002'> spatialResolution : PerformanceRequirement {
		doc /* The system shall provide spatial resolution better than 2 mm for accurate strain rate localization. */
		
		subject tracker : strainRateImager.motionTracker;
		
		require constraint {
			tracker.trackingKernelSize <= 0.002 [m]
		}
	}
	
	requirement <'SRI-P-003'> strainRateAccuracy : PerformanceRequirement {
		doc /* The system shall measure strain rate with accuracy within 15% of reference values over the physiological range. */
		
		subject processor : strainRateImager.strainProcessor;
	}
	
	requirement <'SRI-S-001'> acousticSafety : SafetyRequirement {
		doc /* The system shall maintain acoustic output levels within FDA regulatory limits for diagnostic ultrasound. */
		
		subject transducer : strainRateImager.transducer;
	}
	
	requirement <'SRI-MISSION'> strainRateImagingMission {
		doc /* The strain rate imaging system shall provide real-time quantitative assessment of myocardial
		     deformation to support clinical diagnosis of cardiac dysfunction. */
		
		subject system : strainRateImager;
		
		assume constraint {
			system.tissue.elasticModulus > 0.0 [Pa]
		}
		
		require primaryFunction;
		require temporalResolution;
		require spatialResolution;
		require strainRateAccuracy;
		require acousticSafety;
	}
}
