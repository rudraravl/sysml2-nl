package SinglePhotonEmissionComputedTomographySystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PhotonEnergyValue :> Real {
		doc /* Energy of gamma photons in keV */
	}
	
	attribute def RotationAngleValue :> Real {
		doc /* Detector rotation angle in degrees */
	}
	
	attribute def CountRateValue :> Real {
		doc /* Photon detection count rate in counts per second */
	}
	
	attribute def MatrixSizeValue :> Integer {
		doc /* Image matrix dimension */
	}
	
	item def RadiopharmaceuticalDose {
		attribute isotope : String;
		attribute activity : Real;
		attribute injectionTime : TimeValue;
		attribute halfLife : TimeValue;
	}
	
	item def GammaPhoton {
		attribute energy : PhotonEnergyValue;
		attribute emissionAngle : Real;
		attribute detectionTime : TimeValue;
	}
	
	item def ProjectionData {
		attribute anglePosition : RotationAngleValue;
		attribute detectorCounts : CountRateValue;
		attribute energyWindow : PhotonEnergyValue[2];
		attribute timestamp : TimeValue;
	}
	
	item def TomographicImage {
		attribute sliceThickness : LengthValue;
		attribute spatialResolution : LengthValue;
		attribute voxelIntensities : Real[*];
		attribute matrixSize : MatrixSizeValue;
	}
	
	item def CalibrationCommand;
	item def CalibrationCompleteEvent;
	item def StartScanCommand;
	item def AcquisitionCompleteEvent;
	item def ScanCompleteEvent;
	item def SystemErrorEvent;
	item def ResetCommand;
	
	port def RadiopharmaceuticalInputPort {
		in item dose : RadiopharmaceuticalDose;
	}
	
	port def GammaPhotonEmissionPort {
		out item photons : GammaPhoton[*];
	}
	
	port def GammaPhotonDetectionPort {
		in item photons : GammaPhoton[*];
	}
	
	port def ProjectionDataPort {
		out item projections : ProjectionData[*];
	}
	
	port def ImageDataPort {
		out item reconstructedImage : TomographicImage;
	}
	
	port def ControlSignalPort {
		in attribute startScanSignal : Boolean;
		in attribute stopScanSignal : Boolean;
		in attribute calibrateSignal : Boolean;
	}
	
	part def Patient {
		port gammaEmissionPort : GammaPhotonEmissionPort;
		port doseInputPort : RadiopharmaceuticalInputPort;
		
		attribute bodyRegion : String;
		attribute patientPosition : String;
		
		ref item administeredDose : RadiopharmaceuticalDose;
	}
	
	part def Collimator {
		port photonInputPort : GammaPhotonDetectionPort;
		port collimatedOutputPort : GammaPhotonEmissionPort;
		
		attribute holePattern : String;
		attribute materialType : String;
		attribute septalThickness : LengthValue;
		attribute holeLength : LengthValue;
	}
	
	part def ScintillationCrystal {
		port photonInputPort : GammaPhotonDetectionPort;
		
		attribute material : String = "Sodium Iodide (NaI)";
		attribute thickness : LengthValue;
		attribute lightOutput : Real;
		attribute decayTime : TimeValue;
	}
	
	part def PhotomultiplierTubeArray {
		attribute tubeCount : Integer;
		attribute gainFactor : Real;
		attribute quantumEfficiency : Real;
		attribute darkCurrent : Real;
	}
	
	part def PositionLogicCircuit {
		attribute spatialResolution : LengthValue;
		attribute positionAccuracy : LengthValue;
	}
	
	part def GammaCamera {
		port photonInputPort : GammaPhotonDetectionPort;
		port dataOutputPort : ProjectionDataPort;
		
		part collimator : Collimator {
			port :>> photonInputPort;
			port :>> collimatedOutputPort;
		}
		
		part scintillationCrystal : ScintillationCrystal {
			port :>> photonInputPort;
		}
		
		part pmtArray : PhotomultiplierTubeArray;
		
		part positioningCircuit : PositionLogicCircuit;
		
		connection collimatorToDetector connect 
			collimator.collimatedOutputPort to scintillationCrystal.photonInputPort;
	}
	
	part def RotationMotor {
		attribute maxSpeed : Real;
		attribute torque : Real;
		attribute positionAccuracy : Real;
	}
	
	part def AngleEncoder {
		attribute angularResolution : RotationAngleValue;
		attribute encoderType : String;
	}
	
	part def GantrySystem {
		attribute rotationSpeed : Real;
		attribute numberOfDetectorHeads : Integer;
		attribute orbitType : String;
		
		part rotationMotor : RotationMotor;
		part encoderSystem : AngleEncoder;
		
		ref part detectorHeads : GammaCamera[*];
	}
	
	part def AnalogToDigitalConverter {
		attribute samplingRate : Real;
		attribute bitDepth : Integer;
		attribute inputRange : Real;
	}
	
	part def EnergyDiscriminator {
		attribute lowerThreshold : PhotonEnergyValue;
		attribute upperThreshold : PhotonEnergyValue;
		attribute windowWidth : PhotonEnergyValue;
	}
	
	part def CoincidenceProcessor {
		attribute timeWindow : TimeValue;
		attribute coincidenceResolution : TimeValue;
	}
	
	part def DataAcquisitionSystem {
		port projectionInputPort : ProjectionDataPort;
		port digitalDataOutputPort : ProjectionDataPort;
		
		part adc : AnalogToDigitalConverter;
		part energyDiscriminator : EnergyDiscriminator;
		part coincidenceProcessor : CoincidenceProcessor;
	}
	
	part def FilteredBackprojectionProcessor {
		attribute filterType : String;
		attribute interpolationMethod : String;
		attribute cutoffFrequency : Real;
	}
	
	part def IterativeReconstructionProcessor {
		attribute algorithmType : String = "OSEM";
		attribute iterationCount : Integer;
		attribute subsetCount : Integer;
		attribute convergenceCriterion : Real;
	}
	
	part def AttenuationCorrectionModule {
		attribute correctionMethod : String;
		attribute attenuationMap : Real[*];
	}
	
	part def ScatterCorrectionModule {
		attribute scatterEstimationMethod : String;
		attribute scatterFraction : Real;
	}
	
	part def ImageReconstructionSystem {
		port projectionInputPort : ProjectionDataPort;
		port imageOutputPort : ImageDataPort;
		
		part fbpProcessor : FilteredBackprojectionProcessor;
		part iterativeProcessor : IterativeReconstructionProcessor;
		part attenuationCorrection : AttenuationCorrectionModule;
		part scatterCorrection : ScatterCorrectionModule;
	}
	
	part def AcquisitionControlInterface {
		attribute scanProtocols : String[*];
		attribute acquisitionParameters : Real[*];
	}
	
	part def ImageDisplaySystem {
		attribute displayResolution : String;
		attribute colorMaps : String[*];
		attribute windowingControls : Real[*];
	}
	
	part def OperatorConsole {
		port controlOutputPort : ControlSignalPort;
		
		part acquisitionControl : AcquisitionControlInterface;
		part imageDisplay : ImageDisplaySystem;
	}
	
	action def AdministerRadiopharmaceutical {
		in patient : Patient;
		in dose : RadiopharmaceuticalDose;
		out injectedPatient : Patient;
	}
	
	action def EmitGammaPhotons {
		in patient : Patient;
		out photonStream : GammaPhoton[*];
	}
	
	action def DetectPhotons {
		in photons : GammaPhoton[*];
		in detectorAngle : RotationAngleValue;
		out projectionData : ProjectionData;
	}
	
	action def RotateDetector {
		in currentAngle : RotationAngleValue;
		in angularStep : RotationAngleValue;
		out newAngle : RotationAngleValue;
	}
	
	action def AcquireProjections {
		in photonData : GammaPhoton[*];
		in numberOfAngles : Integer;
		out allProjections : ProjectionData[*];
	}
	
	action def ReconstructImage {
		in projections : ProjectionData[*];
		out tomographicImage : TomographicImage;
	}
	
	action def ApplyAttenuationCorrection {
		in rawImage : TomographicImage;
		out correctedImage : TomographicImage;
	}
	
	action def ApplyScatterCorrection {
		in rawImage : TomographicImage;
		out correctedImage : TomographicImage;
	}
	
	action def PerformSPECTScan {
		attribute currentAngle : RotationAngleValue = 0.0;
		attribute angleStep : RotationAngleValue = 3.0;
		attribute collectedProjections : ProjectionData[*];
		
		first start;
		then action administerDose : AdministerRadiopharmaceutical;
		then action waitForUptake {
			in uptakeTime : TimeValue;
		}
		then action positionPatient;
		then action calibrateSystem;
		then merge acquisitionLoop;
		
		action acquisitionLoop {
			then action emitPhotons : EmitGammaPhotons;
			then action detectAtAngle : DetectPhotons {
				in photons = emitPhotons.photonStream;
				in detectorAngle = currentAngle;
			}
			then action storeProjection {
				in newProjection = detectAtAngle.projectionData;
			}
			then action rotateGantry : RotateDetector {
				in currentAngle = PerformSPECTScan::currentAngle;
				in angularStep = PerformSPECTScan::angleStep;
			}
			then decide;
				if rotateGantry.newAngle < 360.0 then acquisitionLoop;
				if rotateGantry.newAngle >= 360.0 then processData;
		}
		
		action processData : AcquireProjections {
			in numberOfAngles = 120;
		}
		then action reconstruct : ReconstructImage {
			in projections = collectedProjections;
		}
		then action applyAttenuationCorrection : ApplyAttenuationCorrection {
			in rawImage = reconstruct.tomographicImage;
		}
		then action applyScatterCorrection : ApplyScatterCorrection {
			in rawImage = applyAttenuationCorrection.correctedImage;
		}
		then action displayImage;
		then done;
	}
	
	state def SPECTSystemOperationalState {
		entry; then idle;
		
		state idle {
			doc /* System is powered on but not performing any acquisition */
		}
		
		transition idle_to_calibrating
			first idle
			accept CalibrationCommand
			then calibrating;
		
		state calibrating {
			entry; then performEnergyCalibration;
			
			state performEnergyCalibration;
			then uniformityCalibration;
			
			state uniformityCalibration;
			then centerOfRotationCalibration;
			
			state centerOfRotationCalibration;
			then calibrationComplete;
			
			state calibrationComplete;
		}
		
		transition calibrating_to_ready
			first calibrating.calibrationComplete
			accept CalibrationCompleteEvent
			then ready;
		
		state ready {
			doc /* System is calibrated and ready to acquire data */
		}
		
		transition ready_to_scanning
			first ready
			accept StartScanCommand
			then scanning;
		
		state scanning {
			entry; then acquiring;
			
			state acquiring {
				entry; then rotatingAndDetecting;
				
				state rotatingAndDetecting {
					doc /* Gantry rotating and detectors acquiring projection data */
				}
			}
			
			transition acquiring_to_reconstructing
				first acquiring.rotatingAndDetecting
				accept AcquisitionCompleteEvent
				then reconstructing;
			
			state reconstructing {
				entry; then processingProjections;
				
				state processingProjections;
				then applyingCorrections;
				
				state applyingCorrections;
				then generatingImage;
				
				state generatingImage;
			}
		}
		
		transition scanning_to_ready
			first scanning.reconstructing.generatingImage
			accept ScanCompleteEvent
			then ready;
		
		state error {
			doc /* System has encountered an error condition */
		}
		
		transition anyState_to_error
			accept SystemErrorEvent
			then error;
		
		transition error_to_idle
			first error
			accept ResetCommand
			then idle;
	}
	
	part def SPECTSystem {
		attribute imagingCapability : Boolean = true;
		attribute totalAcquisitionTime : Real;
		
		port radiopharmaceuticalInput : RadiopharmaceuticalInputPort;
		port imageOutput : ImageDataPort;
		port systemControl : ControlSignalPort;
		
		part patient : Patient;
		part gammaCamera : GammaCamera;
		part gantrySystem : GantrySystem;
		part dataAcquisitionSystem : DataAcquisitionSystem;
		part imageReconstructionSystem : ImageReconstructionSystem;
		part operatorConsole : OperatorConsole;
	}
	
	requirement def SystemFunctionalRequirement {
		doc /* The SPECT system shall acquire gamma photon emission data from 
		       a patient administered with a radiopharmaceutical and reconstruct 
		       three-dimensional tomographic images of the radioisotope distribution 
		       within the body for diagnostic purposes. */
		
		subject spectSystem : SPECTSystem;
		
		require constraint {
			spectSystem.imagingCapability == true
		}
	}
	
	requirement def SpatialResolutionRequirement {
		doc /* The system shall achieve a spatial resolution of 8mm or better 
		       at 10cm from the collimator surface. */
		
		subject spectSystem : SPECTSystem;
	}
	
	requirement def EnergyResolutionRequirement {
		doc /* The gamma camera shall discriminate photon energies with a resolution 
		       of 10% or better at 140 keV. */
		
		subject spectSystem : SPECTSystem;
		
		require constraint {
			(spectSystem.dataAcquisitionSystem.energyDiscriminator.upperThreshold - 
			 spectSystem.dataAcquisitionSystem.energyDiscriminator.lowerThreshold) <= 14.0
		}
	}
	
	requirement def RotationalAccuracyRequirement {
		doc /* The gantry system shall position detectors with angular accuracy 
		       of 0.5 degrees or better. */
		
		subject spectSystem : SPECTSystem;
		
		require constraint {
			spectSystem.gantrySystem.encoderSystem.angularResolution <= 0.5
		}
	}
	
	requirement def AcquisitionTimeRequirement {
		doc /* The system shall complete a full 360-degree acquisition with 120 
		       projections in less than 20 minutes. */
		
		subject spectSystem : SPECTSystem;
		
		require constraint {
			spectSystem.totalAcquisitionTime <= 1200.0
		}
	}
	
	requirement def ImageMatrixRequirement {
		doc /* The reconstructed image shall have a minimum matrix size of 128x128 pixels. */
		
		subject spectSystem : SPECTSystem;
	}
	
	part spectSystem : SPECTSystem {
		attribute :>> imagingCapability = true;
		attribute :>> totalAcquisitionTime = 1000.0;
		
		port :>> radiopharmaceuticalInput;
		port :>> imageOutput;
		port :>> systemControl;
		
		part :>> patient {
			port :>> gammaEmissionPort;
			port :>> doseInputPort;
			attribute :>> bodyRegion = "Cardiac";
			attribute :>> patientPosition = "Supine";
		}
		
		part :>> gammaCamera {
			port :>> photonInputPort;
			port :>> dataOutputPort;
			
			part :>> collimator {
				attribute :>> holePattern = "Parallel";
				attribute :>> materialType = "Lead";
			}
			
			part :>> scintillationCrystal {
				attribute :>> material = "Sodium Iodide (NaI)";
			}
			
			part :>> pmtArray {
				attribute :>> tubeCount = 59;
				attribute :>> gainFactor = 1000000.0;
			}
		}
		
		part :>> gantrySystem {
			attribute :>> numberOfDetectorHeads = 2;
			attribute :>> rotationSpeed = 6.0;
			attribute :>> orbitType = "Circular";
			
			part :>> rotationMotor {
				attribute :>> maxSpeed = 10.0;
			}
			
			part :>> encoderSystem {
				attribute :>> angularResolution = 0.3;
			}
			
			ref part :>> detectorHeads = spectSystem.gammaCamera;
		}
		
		part :>> dataAcquisitionSystem {
			port :>> projectionInputPort;
			port :>> digitalDataOutputPort;
			
			part :>> adc {
				attribute :>> samplingRate = 100000.0;
				attribute :>> bitDepth = 16;
			}
			
			part :>> energyDiscriminator {
				attribute :>> lowerThreshold = 126.0;
				attribute :>> upperThreshold = 154.0;
				attribute :>> windowWidth = 28.0;
			}
		}
		
		part :>> imageReconstructionSystem {
			port :>> projectionInputPort;
			port :>> imageOutputPort;
			
			part :>> fbpProcessor {
				attribute :>> filterType = "Butterworth";
				attribute :>> interpolationMethod = "Linear";
			}
			
			part :>> iterativeProcessor {
				attribute :>> algorithmType = "OSEM";
				attribute :>> iterationCount = 8;
				attribute :>> subsetCount = 16;
			}
			
			part :>> attenuationCorrection {
				attribute :>> correctionMethod = "Chang";
			}
			
			part :>> scatterCorrection {
				attribute :>> scatterEstimationMethod = "Triple Energy Window";
			}
		}
		
		part :>> operatorConsole {
			port :>> controlOutputPort;
			
			part :>> imageDisplay {
				attribute :>> displayResolution = "2048x2048";
			}
		}
		
		connection photonDetection connect 
			patient.gammaEmissionPort to gammaCamera.photonInputPort;
		
		connection dataTransfer connect 
			gammaCamera.dataOutputPort to dataAcquisitionSystem.projectionInputPort;
		
		connection reconstructionDataFlow connect 
			dataAcquisitionSystem.digitalDataOutputPort to imageReconstructionSystem.projectionInputPort;
		
		connection imageDelivery connect 
			imageReconstructionSystem.imageOutputPort to imageOutput;
		
		connection systemControlConnection connect 
			operatorConsole.controlOutputPort to systemControl;
		
		perform action spectScan : PerformSPECTScan {
			in patient = spectSystem.patient;
		}
		
		exhibit state systemBehavior : SPECTSystemOperationalState;
		
		satisfy SystemFunctionalRequirement;
		satisfy SpatialResolutionRequirement;
		satisfy EnergyResolutionRequirement;
		satisfy RotationalAccuracyRequirement;
		satisfy AcquisitionTimeRequirement;
		satisfy ImageMatrixRequirement;
	}
}
