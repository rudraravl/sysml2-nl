package OpticalCoherenceTomographyModel {
	import ScalarValues::*;
	import ISQ::*;
	import SI::*;

	attribute def OpticalWavelength :> ISQ::LengthValue;
	attribute def OpticalBandwidth :> ISQ::LengthValue;
	attribute def AxialResolution :> ISQ::LengthValue;
	attribute def LateralResolution :> ISQ::LengthValue;
	attribute def OpticalPower :> ISQ::PowerValue;
	attribute def SweepRate :> ISQ::FrequencyValue;
	attribute def FrameRate :> ISQ::FrequencyValue;
	attribute def IntegrationTime :> ISQ::TimeValue;
	attribute def AcquisitionTime :> ISQ::TimeValue;
	attribute def ElectricalVoltage :> ISQ::ElectricPotentialValue;
	attribute def ElectricalPower :> ISQ::PowerValue;

	item def SweptOpticalBeam {
		attribute centerWavelength : OpticalWavelength = 0.000000840 [SI::m];
		attribute sweepBandwidth : OpticalBandwidth = 0.000000100 [SI::m];
		attribute opticalPower : OpticalPower = 0.000010 [SI::W];
		attribute polarizationMaintained : Boolean = true;
	}

	item def SampleIlluminationBeam :> SweptOpticalBeam {
		attribute maximumCornealPower : OpticalPower = 0.000020 [SI::W];
	}

	item def BackscatteredOpticalBeam :> SweptOpticalBeam {
		attribute returnPower : OpticalPower = 0.000000002 [SI::W];
	}

	item def ReferenceOpticalBeam :> SweptOpticalBeam {
		attribute referencePower : OpticalPower = 0.000005 [SI::W];
	}

	item def InterferenceOpticalBeam :> SweptOpticalBeam {
		attribute fringeVisibility : Real = 0.85;
	}

	item def ScanCommand {
		attribute requestedVolumeWidth : ISQ::LengthValue = 0.006 [SI::m];
		attribute requestedVolumeHeight : ISQ::LengthValue = 0.006 [SI::m];
		attribute aScansPerBScan : Integer = 1024;
		attribute bScansPerVolume : Integer = 512;
		attribute requestedFrameRate : FrameRate = 60 [SI::Hz];
	}

	item def ClockSignal {
		attribute frequency : SweepRate = 100000 [SI::Hz];
		attribute synchronizedToLaserSweep : Boolean = true;
	}

	item def AnalogInterferogramSignal {
		attribute peakVoltage : ElectricalVoltage = 1.2 [SI::V];
		attribute bandwidth : SweepRate = 100000000 [SI::Hz];
	}

	item def DigitalFringeData {
		attribute sampleCountPerAScan : Integer = 2048;
		attribute bitDepth : Integer = 14;
		attribute clockFrequency : SweepRate = 200000000 [SI::Hz];
	}

	item def OCTVolumeData {
		attribute axialResolution : AxialResolution = 0.000005 [SI::m];
		attribute lateralResolution : LateralResolution = 0.000015 [SI::m];
		attribute depthRange : ISQ::LengthValue = 0.003 [SI::m];
		attribute aScanCount : Integer = 524288;
		attribute generatedWithin : AcquisitionTime = 0.006 [SI::s];
	}

	item def DisplayImage {
		attribute pixelColumns : Integer = 1024;
		attribute pixelRows : Integer = 1024;
		attribute grayscaleDepthBits : Integer = 12;
		attribute annotatedForClinician : Boolean = true;
	}

	item def ElectricalPowerFlow {
		attribute voltage : ElectricalVoltage = 24 [SI::V];
		attribute availablePower : ElectricalPower = 120 [SI::W];
	}

	port def OpticalBeamOutPort {
		out item beam : SweptOpticalBeam;
	}

	port def OpticalBeamInPort {
		in item beam : SweptOpticalBeam;
	}

	port def SampleOpticalOutPort {
		out item beam : SampleIlluminationBeam;
	}

	port def BackscatterOpticalInPort {
		in item beam : BackscatteredOpticalBeam;
	}

	port def ReferenceOpticalOutPort {
		out item beam : ReferenceOpticalBeam;
	}

	port def ReferenceOpticalInPort {
		in item beam : ReferenceOpticalBeam;
	}

	port def InterferenceOpticalOutPort {
		out item beam : InterferenceOpticalBeam;
	}

	port def InterferenceOpticalInPort {
		in item beam : InterferenceOpticalBeam;
	}

	port def EyeOpticalPort {
		in item illumination : SampleIlluminationBeam;
		out item backscatter : BackscatteredOpticalBeam;
	}

	port def ScanCommandInPort {
		in item command : ScanCommand;
	}

	port def ScanCommandOutPort {
		out item command : ScanCommand;
	}

	port def ClockOutPort {
		out item clock : ClockSignal;
	}

	port def ClockInPort {
		in item clock : ClockSignal;
	}

	port def AnalogSignalOutPort {
		out item signal : AnalogInterferogramSignal;
	}

	port def AnalogSignalInPort {
		in item signal : AnalogInterferogramSignal;
	}

	port def DigitalDataOutPort {
		out item data : DigitalFringeData;
	}

	port def DigitalDataInPort {
		in item data : DigitalFringeData;
	}

	port def VolumeDataOutPort {
		out item volume : OCTVolumeData;
	}

	port def VolumeDataInPort {
		in item volume : OCTVolumeData;
	}

	port def DisplayImageOutPort {
		out item image : DisplayImage;
	}

	port def DisplayImageInPort {
		in item image : DisplayImage;
	}

	port def ElectricalPowerOutPort {
		out item power : ElectricalPowerFlow;
	}

	port def ElectricalPowerInPort {
		in item power : ElectricalPowerFlow;
	}

	action def GenerateSweptLowCoherenceLight {
		out item beam : SweptOpticalBeam;
	}

	action def SplitLightIntoSampleAndReferenceArms {
		in item sourceBeam : SweptOpticalBeam;
		out item sampleBeam : SampleIlluminationBeam;
		out item referenceBeam : ReferenceOpticalBeam;
	}

	action def RasterScanSample {
		in item command : ScanCommand;
		in item illumination : SampleIlluminationBeam;
		out item returnedLight : BackscatteredOpticalBeam;
	}

	action def CombineReferenceAndReturnedLight {
		in item returnedLight : BackscatteredOpticalBeam;
		in item referenceLight : ReferenceOpticalBeam;
		out item interferenceLight : InterferenceOpticalBeam;
	}

	action def DetectInterferogram {
		in item interferenceLight : InterferenceOpticalBeam;
		out item interferogram : AnalogInterferogramSignal;
	}

	action def DigitizeInterferogram {
		in item analogInterferogram : AnalogInterferogramSignal;
		in item samplingClock : ClockSignal;
		out item fringeData : DigitalFringeData;
	}

	action def ReconstructDepthResolvedVolume {
		in item fringeData : DigitalFringeData;
		out item octVolume : OCTVolumeData;
	}

	action def RenderClinicalImage {
		in item octVolume : OCTVolumeData;
		out item image : DisplayImage;
	}

	action def PerformOCTImaging {
		in item scanRequest : ScanCommand;
		out item clinicalImage : DisplayImage;

		action generateLight : GenerateSweptLowCoherenceLight;
		action splitLight : SplitLightIntoSampleAndReferenceArms;
		action scanSample : RasterScanSample;
		action combineLight : CombineReferenceAndReturnedLight;
		action detectFringes : DetectInterferogram;
		action digitizeFringes : DigitizeInterferogram;
		action reconstructVolume : ReconstructDepthResolvedVolume;
		action renderImage : RenderClinicalImage;

		flow generateLight.beam to splitLight.sourceBeam;
		flow splitLight.sampleBeam to scanSample.illumination;
		flow scanRequest to scanSample.command;
		flow scanSample.returnedLight to combineLight.returnedLight;
		flow splitLight.referenceBeam to combineLight.referenceLight;
		flow combineLight.interferenceLight to detectFringes.interferenceLight;
		flow detectFringes.interferogram to digitizeFringes.analogInterferogram;
		flow digitizeFringes.fringeData to reconstructVolume.fringeData;
		flow reconstructVolume.octVolume to renderImage.octVolume;
		flow renderImage.image to clinicalImage;
	}

	state def OCTOperatingLifecycle {
		state off;
		state selfTest;
		state standby;
		state aligningOptics;
		state ready;
		state acquiringVolume;
		state reconstructingVolume;
		state displayingImage;
		state faultSafe;

		transition powerApplied first off then selfTest;
		transition selfTestPassed first selfTest then standby;
		transition alignmentRequested first standby then aligningOptics;
		transition alignmentComplete first aligningOptics then ready;
		transition scanRequested first ready then acquiringVolume;
		transition acquisitionComplete first acquiringVolume then reconstructingVolume;
		transition reconstructionComplete first reconstructingVolume then displayingImage;
		transition clinicianAcceptsImage first displayingImage then ready;
		transition faultDetectedDuringSelfTest first selfTest then faultSafe;
		transition faultDetectedDuringScan first acquiringVolume then faultSafe;
		transition resetAfterFault first faultSafe then selfTest;
		transition shutdownFromStandby first standby then off;
		transition shutdownFromReady first ready then off;
	}

	part def SweptLaserSource {
		attribute centerWavelength : OpticalWavelength = 0.000000840 [SI::m];
		attribute sweepBandwidth : OpticalBandwidth = 0.000000100 [SI::m];
		attribute sweepRate : SweepRate = 100000 [SI::Hz];
		attribute outputPower : OpticalPower = 0.000010 [SI::W];

		port commandIn : ScanCommandInPort;
		port clockOut : ClockOutPort;
		port opticalOut : OpticalBeamOutPort;
		port powerIn : ElectricalPowerInPort;

		action generateLight : GenerateSweptLowCoherenceLight;
	}

	part def FiberInterferometer {
		attribute sampleSplitRatio : Real = 0.50;
		attribute referenceSplitRatio : Real = 0.50;
		attribute insertionLoss : Real = 0.08;

		port sourceInput : OpticalBeamInPort;
		port sampleOutput : SampleOpticalOutPort;
		port sampleReturnInput : BackscatterOpticalInPort;
		port referenceOutput : ReferenceOpticalOutPort;
		port referenceReturnInput : ReferenceOpticalInPort;
		port interferenceOutput : InterferenceOpticalOutPort;
		port powerIn : ElectricalPowerInPort;

		action splitLight : SplitLightIntoSampleAndReferenceArms;
		action combineLight : CombineReferenceAndReturnedLight;
	}

	part def GalvanometerSampleScanner {
		attribute lateralResolution : LateralResolution = 0.000015 [SI::m];
		attribute maximumScanWidth : ISQ::LengthValue = 0.012 [SI::m];
		attribute maximumScanHeight : ISQ::LengthValue = 0.012 [SI::m];
		attribute dwellTimePerAScan : IntegrationTime = 0.000010 [SI::s];

		port commandIn : ScanCommandInPort;
		port opticalIn : SampleOpticalOutPort;
		port patientPort : EyeOpticalPort;
		port backscatterOut : BackscatterOpticalInPort;
		port powerIn : ElectricalPowerInPort;

		action rasterScan : RasterScanSample;
	}

	part def ReferenceDelayArm {
		attribute opticalPathLength : ISQ::LengthValue = 0.030 [SI::m];
		attribute adjustableDelayRange : ISQ::LengthValue = 0.006 [SI::m];
		attribute dispersionCompensationEnabled : Boolean = true;

		port referenceIn : ReferenceOpticalInPort;
		port referenceOut : ReferenceOpticalOutPort;
		port powerIn : ElectricalPowerInPort;
	}

	part def BalancedPhotodetector {
		attribute analogBandwidth : SweepRate = 100000000 [SI::Hz];
		attribute noiseEquivalentPower : OpticalPower = 0.000000000002 [SI::W];
		attribute balancedDetectionEnabled : Boolean = true;

		port opticalIn : InterferenceOpticalInPort;
		port analogOut : AnalogSignalOutPort;
		port powerIn : ElectricalPowerInPort;

		action detectInterferogram : DetectInterferogram;
	}

	part def HighSpeedDigitizer {
		attribute sampleRate : SweepRate = 200000000 [SI::Hz];
		attribute resolutionBits : Integer = 14;
		attribute inputRange : ElectricalVoltage = 2 [SI::V];

		port commandIn : ScanCommandInPort;
		port clockIn : ClockInPort;
		port analogIn : AnalogSignalInPort;
		port digitalOut : DigitalDataOutPort;
		port powerIn : ElectricalPowerInPort;

		action digitizeInterferogram : DigitizeInterferogram;
	}

	part def ReconstructionProcessor {
		attribute axialResolution : AxialResolution = 0.000005 [SI::m];
		attribute maximumProcessingLatency : AcquisitionTime = 0.100 [SI::s];
		attribute performsDispersionCorrection : Boolean = true;
		attribute performsFourierTransform : Boolean = true;

		port commandIn : ScanCommandInPort;
		port fringeDataIn : DigitalDataInPort;
		port volumeOut : VolumeDataOutPort;
		port powerIn : ElectricalPowerInPort;

		action reconstructVolume : ReconstructDepthResolvedVolume;
	}

	part def ClinicalDisplay {
		attribute diagonalSize : ISQ::LengthValue = 0.6858 [SI::m];
		attribute refreshRate : FrameRate = 60 [SI::Hz];
		attribute displaysDepthScale : Boolean = true;

		port imageIn : DisplayImageInPort;
		port powerIn : ElectricalPowerInPort;

		action renderImage : RenderClinicalImage;
	}

	part def OperatorConsole {
		attribute supportsRetinaScanProtocol : Boolean = true;
		attribute supportsCorneaScanProtocol : Boolean = true;

		port scanCommandOut : ScanCommandOutPort;
		port imageIn : DisplayImageInPort;
		port powerIn : ElectricalPowerInPort;
	}

	part def SystemController {
		attribute interlockClosed : Boolean = true;
		attribute eyeSafetyMonitoringEnabled : Boolean = true;
		attribute primaryFunctionDescription : String = "Acquire low-coherence optical interference from ocular tissue and reconstruct depth-resolved cross-sectional and volumetric images without contact.";

		port operatorCommandIn : ScanCommandInPort;
		port laserCommandOut : ScanCommandOutPort;
		port scannerCommandOut : ScanCommandOutPort;
		port digitizerCommandOut : ScanCommandOutPort;
		port processorCommandOut : ScanCommandOutPort;
		port powerIn : ElectricalPowerInPort;
	}

	part def MedicalPowerSupply {
		attribute inputVoltage : ElectricalVoltage = 120 [SI::V];
		attribute outputVoltage : ElectricalVoltage = 24 [SI::V];
		attribute ratedOutputPower : ElectricalPower = 120 [SI::W];
		attribute leakageCurrentControlled : Boolean = true;

		port electricalOut : ElectricalPowerOutPort;
	}

	part def PatientEye {
		attribute corneaToRetinaDepth : ISQ::LengthValue = 0.024 [SI::m];
		attribute maximumSafeIncidentPower : OpticalPower = 0.000020 [SI::W];

		port eyeOptics : EyeOpticalPort;
	}

	part def OpticalCoherenceTomographySystem {
		doc /* The primary high-level function of this optical coherence tomography system is to illuminate tissue with low-coherence swept light, collect backscattered reflections, interfere them with a reference path, digitize the resulting fringes, and reconstruct depth-resolved images for clinical interpretation. */

		attribute primaryFunctionDescription : String = "Non-contact depth-resolved imaging using low-coherence interferometry.";
		attribute systemAxialResolution : AxialResolution = 0.000005 [SI::m];
		attribute systemLateralResolution : LateralResolution = 0.000015 [SI::m];
		attribute maximumPatientOpticalPower : OpticalPower = 0.000020 [SI::W];
		attribute maximumVolumeAcquisitionTime : AcquisitionTime = 0.006 [SI::s];
		attribute operatingFrameRate : FrameRate = 60 [SI::Hz];

		port operatorCommandIn : ScanCommandInPort;
		port patientOpticalInterface : EyeOpticalPort;
		port imageOutput : DisplayImageOutPort;
		port mainsPowerOutput : ElectricalPowerOutPort;

		part powerSupply : MedicalPowerSupply;
		part controller : SystemController;
		part sweptLaser : SweptLaserSource;
		part interferometer : FiberInterferometer;
		part sampleScanner : GalvanometerSampleScanner;
		part referenceArm : ReferenceDelayArm;
		part detector : BalancedPhotodetector;
		part digitizer : HighSpeedDigitizer;
		part processor : ReconstructionProcessor;
		part display : ClinicalDisplay;
		part console : OperatorConsole;

		state lifecycle : OCTOperatingLifecycle;
		action primaryImagingFunction : PerformOCTImaging;

		connection externalCommandToConsole connect operatorCommandIn to console.scanCommandOut;
		connection consoleToController connect console.scanCommandOut to controller.operatorCommandIn;
		connection controllerToLaser connect controller.laserCommandOut to sweptLaser.commandIn;
		connection controllerToScanner connect controller.scannerCommandOut to sampleScanner.commandIn;
		connection controllerToDigitizer connect controller.digitizerCommandOut to digitizer.commandIn;
		connection controllerToProcessor connect controller.processorCommandOut to processor.commandIn;

		connection laserClockToDigitizer connect sweptLaser.clockOut to digitizer.clockIn;
		connection laserToInterferometer connect sweptLaser.opticalOut to interferometer.sourceInput;
		connection interferometerToScanner connect interferometer.sampleOutput to sampleScanner.opticalIn;
		connection scannerToPatient connect sampleScanner.patientPort to patientOpticalInterface;
		connection patientBackscatterToScanner connect patientOpticalInterface to sampleScanner.patientPort;
		connection scannerReturnToInterferometer connect sampleScanner.backscatterOut to interferometer.sampleReturnInput;
		connection interferometerToReferenceArm connect interferometer.referenceOutput to referenceArm.referenceIn;
		connection referenceArmToInterferometer connect referenceArm.referenceOut to interferometer.referenceReturnInput;
		connection interferometerToDetector connect interferometer.interferenceOutput to detector.opticalIn;
		connection detectorToDigitizer connect detector.analogOut to digitizer.analogIn;
		connection digitizerToProcessor connect digitizer.digitalOut to processor.fringeDataIn;
		connection processorToDisplay connect processor.volumeOut to display.imageIn;
		connection displayToConsole connect display.imageIn to console.imageIn;
		connection displayToExternalImage connect display.imageIn to imageOutput;

		connection powerToController connect powerSupply.electricalOut to controller.powerIn;
		connection powerToLaser connect powerSupply.electricalOut to sweptLaser.powerIn;
		connection powerToInterferometer connect powerSupply.electricalOut to interferometer.powerIn;
		connection powerToScanner connect powerSupply.electricalOut to sampleScanner.powerIn;
		connection powerToReferenceArm connect powerSupply.electricalOut to referenceArm.powerIn;
		connection powerToDetector connect powerSupply.electricalOut to detector.powerIn;
		connection powerToDigitizer connect powerSupply.electricalOut to digitizer.powerIn;
		connection powerToProcessor connect powerSupply.electricalOut to processor.powerIn;
		connection powerToDisplay connect powerSupply.electricalOut to display.powerIn;
		connection powerToConsole connect powerSupply.electricalOut to console.powerIn;
		connection systemPowerExport connect powerSupply.electricalOut to mainsPowerOutput;
	}

	requirement def PrimaryFunctionRequirement {
		doc /* The OCT system shall provide non-contact, depth-resolved optical imaging by producing low-coherence interference measurements and reconstructing cross-sectional or volumetric tissue images. */
		subject oct : OpticalCoherenceTomographySystem;
		require constraint { oct.systemAxialResolution <= 0.000007 [SI::m] }
		require constraint { oct.maximumVolumeAcquisitionTime <= 0.010 [SI::s] }
	}

	requirement def EyeSafetyRequirement {
		doc /* The OCT system shall limit patient incident optical power to a clinically safe value during scanning. */
		subject oct : OpticalCoherenceTomographySystem;
		require constraint { oct.maximumPatientOpticalPower <= 0.000020 [SI::W] }
	}

	requirement def ResolutionRequirement {
		doc /* The OCT system shall resolve fine retinal or corneal structures in depth and laterally. */
		subject oct : OpticalCoherenceTomographySystem;
		require constraint { oct.systemAxialResolution <= 0.000005 [SI::m] }
		require constraint { oct.systemLateralResolution <= 0.000020 [SI::m] }
	}

	requirement def RealTimeDisplayRequirement {
		doc /* The OCT system shall produce a clinically viewable image stream at video frame rate. */
		subject oct : OpticalCoherenceTomographySystem;
		require constraint { oct.operatingFrameRate >= 30 [SI::Hz] }
	}

	part octSystem : OpticalCoherenceTomographySystem;
	part patient : PatientEye;

	connection patientToOCT connect patient.eyeOptics to octSystem.patientOpticalInterface;

	requirement primaryFunction : PrimaryFunctionRequirement {
		subject oct = octSystem;
	}

	requirement eyeSafety : EyeSafetyRequirement {
		subject oct = octSystem;
	}

	requirement resolution : ResolutionRequirement {
		subject oct = octSystem;
	}

	requirement realTimeDisplay : RealTimeDisplayRequirement {
		subject oct = octSystem;
	}
}
