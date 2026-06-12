package SPECTSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def PhotonEnergy {
    attribute value : Real;
    attribute unit : String = "keV";
  }

  attribute def Activity {
    attribute value : Real;
    attribute unit : String = "MBq";
  }

  attribute def Dose {
    attribute value : Real;
    attribute unit : String = "mSv";
  }

  attribute def CountRate {
    attribute value : Real;
    attribute unit : String = "counts/s";
  }

  attribute def RotationAngle {
    attribute value : Real;
    attribute unit : String = "deg";
  }

  attribute def TimeDuration {
    attribute value : Real;
    attribute unit : String = "s";
  }

  attribute def SpatialResolution {
    attribute value : Real;
    attribute unit : String = "mm";
  }

  attribute def ImageVoxelSize {
    attribute value : Real;
    attribute unit : String = "mm";
  }

  item def GammaPhoton {
    attribute energy : PhotonEnergy;
    attribute originX : Real;
    attribute originY : Real;
    attribute originZ : Real;
    attribute emissionTime : TimeDuration;
  }

  item def RadiotracerDose {
    attribute isotopeName : String;
    attribute administeredActivity : Activity;
    attribute estimatedEffectiveDose : Dose;
    attribute injectionTime : TimeDuration;
  }

  item def ProjectionEvent {
    attribute detectorId : String;
    attribute angle : RotationAngle;
    attribute xChannel : Integer;
    attribute yChannel : Integer;
    attribute pulseHeight : PhotonEnergy;
    attribute timestamp : TimeDuration;
  }

  item def ProjectionFrame {
    attribute gantryAngle : RotationAngle;
    attribute acquisitionTime : TimeDuration;
    attribute eventCount : Integer;
    attribute meanCountRate : CountRate;
  }

  item def ReconstructedVolume {
    attribute voxelSize : ImageVoxelSize;
    attribute matrixX : Integer;
    attribute matrixY : Integer;
    attribute matrixZ : Integer;
    attribute correctionApplied : Boolean;
    attribute quantitativeActivityUnits : String = "Bq/ml";
  }

  item def DiagnosticImageSet {
    attribute studyUid : String;
    attribute modality : String = "SPECT";
    attribute anatomicalRegion : String;
    attribute reconstructionMethod : String;
  }

  port def PhotonInputPort {
    in item photon : GammaPhoton;
  }

  port def PhotonOutputPort {
    out item photon : GammaPhoton;
  }

  port def DosePort {
    in item dose : RadiotracerDose;
  }

  port def ProjectionDataPort {
    out item frame : ProjectionFrame;
    out item event : ProjectionEvent;
  }

  port def ImageDataPort {
    out item volume : ReconstructedVolume;
    out item imageSet : DiagnosticImageSet;
  }

  port def ControlPort {
    in attribute command : String;
    out attribute status : String;
  }

  port def PowerPort {
    in attribute voltage : Real;
    in attribute current : Real;
  }

  port def NetworkPort {
    in item inboundStudyRequest : DiagnosticImageSet;
    out item outboundImageSet : DiagnosticImageSet;
  }

  part def Patient {
    attribute patientId : String;
    attribute injectedDose : RadiotracerDose;
    port emittedPhotons : PhotonOutputPort;
  }

  part def RadiotracerAdministrationSubsystem {
    attribute supportedIsotope : String = "Tc-99m";
    attribute nominalPhotonEnergy : PhotonEnergy = (value = 140.5, unit = "keV");
    port doseOut : DosePort;
    port control : ControlPort;
  }

  part def Collimator {
    attribute type : String = "low-energy high-resolution parallel-hole";
    attribute acceptedEnergyCenter : PhotonEnergy = (value = 140.5, unit = "keV");
    attribute septalPenetrationLimit : Real = 0.05;
    port photonIn : PhotonInputPort;
    port photonOut : PhotonOutputPort;
  }

  part def ScintillationCrystal {
    attribute material : String = "NaI(Tl)";
    attribute thickness : Real = 9.5;
    attribute thicknessUnit : String = "mm";
    port photonIn : PhotonInputPort;
    port lightPulseOut : ProjectionDataPort;
  }

  part def PhotomultiplierArray {
    attribute tubeCount : Integer = 59;
    attribute gainStabilityTolerance : Real = 0.02;
    port lightPulseIn : ProjectionDataPort;
    port electricalPulseOut : ProjectionDataPort;
  }

  part def EnergyWindowAnalyzer {
    attribute lowerWindow : PhotonEnergy = (value = 126.0, unit = "keV");
    attribute upperWindow : PhotonEnergy = (value = 154.0, unit = "keV");
    port pulseIn : ProjectionDataPort;
    port acceptedEventOut : ProjectionDataPort;
  }

  part def DetectorHead {
    attribute detectorId : String;
    attribute intrinsicResolution : SpatialResolution = (value = 3.8, unit = "mm");
    part collimator : Collimator;
    part crystal : ScintillationCrystal;
    part photomultipliers : PhotomultiplierArray;
    part energyAnalyzer : EnergyWindowAnalyzer;
    port gammaIn : PhotonInputPort;
    port projectionOut : ProjectionDataPort;

    connect gammaIn to collimator.photonIn;
    connect collimator.photonOut to crystal.photonIn;
    connect crystal.lightPulseOut to photomultipliers.lightPulseIn;
    connect photomultipliers.electricalPulseOut to energyAnalyzer.pulseIn;
    connect energyAnalyzer.acceptedEventOut to projectionOut;
  }

  part def RotatingGantry {
    attribute minimumAngle : RotationAngle = (value = 0.0, unit = "deg");
    attribute maximumAngle : RotationAngle = (value = 360.0, unit = "deg");
    attribute angularStep : RotationAngle = (value = 3.0, unit = "deg");
    attribute rotationSpeed : Real = 1.0;
    attribute rotationSpeedUnit : String = "deg/s";
    port control : ControlPort;
  }

  part def PatientTable {
    attribute verticalPosition : Real;
    attribute longitudinalPosition : Real;
    attribute positionUnit : String = "mm";
    attribute maximumPatientMass : Real = 227.0;
    attribute massUnit : String = "kg";
    port control : ControlPort;
  }

  part def AcquisitionController {
    attribute targetProjectionCount : Integer = 120;
    attribute timePerProjection : TimeDuration = (value = 20.0, unit = "s");
    attribute minimumAcceptedCountRate : CountRate = (value = 5000.0, unit = "counts/s");
    port control : ControlPort;
    port projectionIn : ProjectionDataPort;
    port projectionOut : ProjectionDataPort;
  }

  part def ReconstructionProcessor {
    attribute algorithm : String = "ordered-subsets expectation maximization";
    attribute attenuationCorrection : Boolean = true;
    attribute scatterCorrection : Boolean = true;
    attribute resolutionRecovery : Boolean = true;
    attribute outputVoxelSize : ImageVoxelSize = (value = 4.0, unit = "mm");
    port projectionIn : ProjectionDataPort;
    port imageOut : ImageDataPort;
  }

  part def OperatorConsole {
    attribute operatorId : String;
    attribute selectedProtocol : String;
    port control : ControlPort;
    port imageIn : ImageDataPort;
  }

  part def SafetyController {
    attribute emergencyStopActive : Boolean = false;
    attribute doorInterlockClosed : Boolean = true;
    attribute collisionSensorClear : Boolean = true;
    attribute radiationWarningEnabled : Boolean = true;
    port control : ControlPort;
  }

  part def ArchiveInterface {
    attribute protocol : String = "DICOM";
    attribute destinationAETitle : String;
    port network : NetworkPort;
    port imageIn : ImageDataPort;
  }

  part def SPECTScanner {
    attribute systemName : String = "Single-Photon Emission Computed Tomography System";
    attribute primaryFunction : String = "Detect gamma photons emitted by an administered radiotracer from multiple projection angles and reconstruct a three-dimensional functional image of tracer distribution inside the patient.";
    attribute clinicalUse : String = "functional nuclear medicine imaging of organ perfusion, metabolism, and receptor uptake";

    part gantry : RotatingGantry;
    part table : PatientTable;
    part detectorHeadA : DetectorHead {
      :>> detectorId = "HEAD_A";
    }
    part detectorHeadB : DetectorHead {
      :>> detectorId = "HEAD_B";
    }
    part acquisitionController : AcquisitionController;
    part reconstructionProcessor : ReconstructionProcessor;
    part safetyController : SafetyController;
    part console : OperatorConsole;
    part archive : ArchiveInterface;

    port patientPhotonIn : PhotonInputPort;
    port doseIn : DosePort;
    port powerIn : PowerPort;
    port network : NetworkPort;

    connect patientPhotonIn to detectorHeadA.gammaIn;
    connect patientPhotonIn to detectorHeadB.gammaIn;
    connect detectorHeadA.projectionOut to acquisitionController.projectionIn;
    connect detectorHeadB.projectionOut to acquisitionController.projectionIn;
    connect acquisitionController.projectionOut to reconstructionProcessor.projectionIn;
    connect reconstructionProcessor.imageOut to console.imageIn;
    connect reconstructionProcessor.imageOut to archive.imageIn;
    connect console.control to acquisitionController.control;
    connect console.control to gantry.control;
    connect console.control to table.control;
    connect safetyController.control to acquisitionController.control;
    connect network to archive.network;
  }

  action def PreparePatient {
    in item dose : RadiotracerDose;
    out attribute patientReady : Boolean;
    action verifyIdentity;
    action administerRadiotracer;
    action waitForBiodistribution;
    action positionPatientOnTable;
    then verifyIdentity;
    then administerRadiotracer;
    then waitForBiodistribution;
    then positionPatientOnTable;
  }

  action def AcquireProjectionData {
    in attribute numberOfAngles : Integer;
    in attribute secondsPerAngle : TimeDuration;
    out item projectionFrame : ProjectionFrame;

    action rotateGantryToNextAngle;
    action enableDetectorAcquisition;
    action rejectOutOfWindowEvents;
    action storeProjectionFrame;

    first rotateGantryToNextAngle;
    then enableDetectorAcquisition;
    then rejectOutOfWindowEvents;
    then storeProjectionFrame;
  }

  action def ReconstructFunctionalVolume {
    in item projections : ProjectionFrame;
    out item volume : ReconstructedVolume;

    action normalizeDetectorResponse;
    action correctForAttenuation;
    action correctForScatter;
    action iterativeReconstruction;
    action generateTransaxialCoronalSagittalViews;

    first normalizeDetectorResponse;
    then correctForAttenuation;
    then correctForScatter;
    then iterativeReconstruction;
    then generateTransaxialCoronalSagittalViews;
  }

  action def PerformSPECTStudy {
    in part scanner : SPECTScanner;
    in part patient : Patient;
    out item diagnosticImages : DiagnosticImageSet;

    action prepare : PreparePatient;
    action acquire : AcquireProjectionData;
    action reconstruct : ReconstructFunctionalVolume;
    action reviewAndArchive;

    first prepare;
    then acquire;
    then reconstruct;
    then reviewAndArchive;
  }

  state def SPECTOperationalStates {
    entry action initializeElectronics;

    state Off;
    state SelfTest;
    state Ready;
    state PatientPositioning;
    state DoseUptakeWaiting;
    state AcquiringProjections;
    state Reconstructing;
    state StudyComplete;
    state Fault;

    transition powerOn first Off then SelfTest;
    transition selfTestPassed first SelfTest then Ready;
    transition selfTestFailed first SelfTest then Fault;
    transition protocolSelected first Ready then PatientPositioning;
    transition patientPositionConfirmed first PatientPositioning then DoseUptakeWaiting;
    transition uptakeTimeElapsed first DoseUptakeWaiting then AcquiringProjections;
    transition acquisitionComplete first AcquiringProjections then Reconstructing;
    transition reconstructionComplete first Reconstructing then StudyComplete;
    transition resetForNextPatient first StudyComplete then Ready;
    transition emergencyStop first Ready then Fault;
    transition acquisitionFault first AcquiringProjections then Fault;
    transition clearedByService first Fault then SelfTest;
    transition powerOff first Ready then Off;
  }

  requirement def PrimaryFunctionRequirement {
    subject scanner : SPECTScanner;
    doc /* The system shall perform single-photon emission computed tomography by collecting gamma-photon projection data from a radiotracer administered to a patient and reconstructing a three-dimensional image representing the spatial distribution of radiotracer activity. */
    require constraint {
      scanner.primaryFunction == "Detect gamma photons emitted by an administered radiotracer from multiple projection angles and reconstruct a three-dimensional functional image of tracer distribution inside the patient."
    }
  }

  requirement def GammaPhotonDetectionRequirement {
    subject detector : DetectorHead;
    doc /* Each detector head shall accept gamma photons within the configured energy window and convert accepted interactions into position-tagged projection events. */
    require constraint {
      detector.energyAnalyzer.lowerWindow.value <= 140.5 and
      detector.energyAnalyzer.upperWindow.value >= 140.5
    }
  }

  requirement def TomographicCoverageRequirement {
    subject gantry : RotatingGantry;
    doc /* The gantry shall support projection acquisition over a complete tomographic orbit. */
    require constraint {
      gantry.minimumAngle.value == 0.0 and
      gantry.maximumAngle.value >= 360.0
    }
  }

  requirement def ProjectionSamplingRequirement {
    subject controller : AcquisitionController;
    doc /* The acquisition controller shall acquire enough angular projections to support volumetric reconstruction. */
    require constraint {
      controller.targetProjectionCount >= 60 and
      controller.timePerProjection.value >= 10.0
    }
  }

  requirement def RadiationSafetyRequirement {
    subject safety : SafetyController;
    doc /* The system shall prevent acquisition motion when safety interlocks indicate unsafe operation. */
    require constraint {
      safety.doorInterlockClosed == true and
      safety.collisionSensorClear == true and
      safety.emergencyStopActive == false
    }
  }

  requirement def ImageReconstructionRequirement {
    subject processor : ReconstructionProcessor;
    doc /* The reconstruction processor shall generate a corrected three-dimensional activity volume from acquired projection frames. */
    require constraint {
      processor.attenuationCorrection == true and
      processor.scatterCorrection == true and
      processor.outputVoxelSize.value <= 6.0
    }
  }

  part spectImagingSystem {
    part patient : Patient {
      :>> patientId = "PATIENT_FOR_STUDY";
    }

    part doseSubsystem : RadiotracerAdministrationSubsystem;

    part scanner : SPECTScanner {
      :>> console.operatorId = "NUCLEAR_MEDICINE_TECHNOLOGIST";
      :>> console.selectedProtocol = "Tc-99m myocardial perfusion SPECT";
      :>> archive.destinationAETitle = "PACS_ARCHIVE";
    }

    connect doseSubsystem.doseOut to scanner.doseIn;
    connect patient.emittedPhotons to scanner.patientPhotonIn;
  }

}