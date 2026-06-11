package RadiologyInstrumentSystemModel {

  item def Patient;
  item def DiagnosticImageStudy;
  item def XRayPhotonBeam;
  item def MagneticField;
  item def UltrasoundWave;
  item def ImageData;
  item def ControlCommand;
  item def ElectricalPower;
  item def CoolingWater;

  attribute def Dose {
    attribute value : Real;
    attribute unit : String = "mSv";
  }

  attribute def Frequency {
    attribute value : Real;
    attribute unit : String = "MHz";
  }

  attribute def MagneticFluxDensity {
    attribute value : Real;
    attribute unit : String = "T";
  }

  attribute def Voltage {
    attribute value : Real;
    attribute unit : String = "kV";
  }

  attribute def Power {
    attribute value : Real;
    attribute unit : String = "kW";
  }

  attribute def ImageResolution {
    attribute pixelSpacing : Real;
    attribute unit : String = "mm/pixel";
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def DataPort {
    out item imageData : ImageData;
    in item command : ControlCommand;
  }

  port def PatientInterfacePort {
    in item patient : Patient;
    out item study : DiagnosticImageStudy;
  }

  port def CoolingPort {
    in item coolingWater : CoolingWater;
  }

  part def RadiologyInstrument {
    attribute operationalPower : Power;
    attribute imageResolution : ImageResolution;
    port powerPort : PowerPort;
    port dataPort : DataPort;
    port patientPort : PatientInterfacePort;
  }

  part def XRayRadiographyUnit :> RadiologyInstrument {
    attribute tubeVoltage : Voltage = (value = 120.0, unit = "kV");
    attribute entranceDose : Dose = (value = 0.2, unit = "mSv");

    part xrayTube;
    part collimator;
    part flatPanelDetector;
    part patientTable;

    port beamOutput {
      out item beam : XRayPhotonBeam;
    }
  }

  part def CTScanner :> RadiologyInstrument {
    attribute tubeVoltage : Voltage = (value = 140.0, unit = "kV");
    attribute studyDose : Dose = (value = 8.0, unit = "mSv");

    part rotatingGantry;
    part xraySource;
    part detectorArray;
    part reconstructionComputer;
    part motorizedPatientTable;

    port coolingPort : CoolingPort;
    port beamOutput {
      out item beam : XRayPhotonBeam;
    }
  }

  part def MRIScanner :> RadiologyInstrument {
    attribute fieldStrength : MagneticFluxDensity = (value = 3.0, unit = "T");
    attribute rfFrequency : Frequency = (value = 127.7, unit = "MHz");

    part superconductingMagnet;
    part gradientCoils;
    part rfTransmitCoil;
    part rfReceiveCoil;
    part cryogenicCoolingSystem;
    part patientBore;

    port magneticFieldPort {
      out item field : MagneticField;
    }
  }

  part def UltrasoundScanner :> RadiologyInstrument {
    attribute transducerFrequency : Frequency = (value = 5.0, unit = "MHz");

    part beamformer;
    part transducerProbe;
    part dopplerProcessor;
    part displayConsole;

    port acousticPort {
      out item wave : UltrasoundWave;
    }
  }

  part def RadiologyWorkstation {
    port dataIn : DataPort;
    part imageViewer;
    part measurementTools;
    part reportingConsole;
  }

  part def ImageArchive {
    port dataIn : DataPort;
    part studyDatabase;
    part dicomStorageService;
  }

  part def RadiologyInstrumentSystem {
    doc /* Primary function: acquire diagnostic medical images of a patient using radiology instruments, process them into clinical studies, display them for interpretation, and archive them for patient care. */

    part xrayUnit : XRayRadiographyUnit;
    part ctScanner : CTScanner;
    part mriScanner : MRIScanner;
    part ultrasoundScanner : UltrasoundScanner;
    part workstation : RadiologyWorkstation;
    part archive : ImageArchive;

    part powerDistribution;
    part coolingPlant;
    part operatorConsole;
    part radiationSafetyMonitor;
    part patientPositioningSystem;

    connect powerDistribution to xrayUnit.powerPort;
    connect powerDistribution to ctScanner.powerPort;
    connect powerDistribution to mriScanner.powerPort;
    connect powerDistribution to ultrasoundScanner.powerPort;

    connect coolingPlant to ctScanner.coolingPort;
    connect coolingPlant to mriScanner.cryogenicCoolingSystem;

    connect operatorConsole to xrayUnit.dataPort;
    connect operatorConsole to ctScanner.dataPort;
    connect operatorConsole to mriScanner.dataPort;
    connect operatorConsole to ultrasoundScanner.dataPort;

    connect xrayUnit.dataPort to workstation.dataIn;
    connect ctScanner.dataPort to workstation.dataIn;
    connect mriScanner.dataPort to workstation.dataIn;
    connect ultrasoundScanner.dataPort to workstation.dataIn;

    connect workstation.dataIn to archive.dataIn;
  }

  action def AcquireRadiologyStudy {
    in patient : Patient;
    in command : ControlCommand;
    out study : DiagnosticImageStudy;

    action verifyPatientIdentity;
    action selectImagingProtocol;
    action positionPatient;
    action checkSafetyInterlocks;
    action acquireRawSignals;
    action reconstructImages;
    action reviewImageQuality;
    action storeDiagnosticStudy;

    first verifyPatientIdentity;
    then selectImagingProtocol;
    then positionPatient;
    then checkSafetyInterlocks;
    then acquireRawSignals;
    then reconstructImages;
    then reviewImageQuality;
    then storeDiagnosticStudy;
  }

  state def InstrumentOperatingState {
    state Off;
    state Standby;
    state PatientSetup;
    state Ready;
    state Acquiring;
    state Processing;
    state Complete;
    state Fault;

    transition initial then Off;
    transition powerOn first Off then Standby;
    transition setupPatient first Standby then PatientSetup;
    transition confirmProtocol first PatientSetup then Ready;
    transition startAcquisition first Ready then Acquiring;
    transition acquisitionFinished first Acquiring then Processing;
    transition processingFinished first Processing then Complete;
    transition reset first Complete then Standby;
    transition faultDetected first Standby then Fault;
    transition faultDuringSetup first PatientSetup then Fault;
    transition faultDuringAcquisition first Acquiring then Fault;
    transition serviceReset first Fault then Standby;
    transition powerOff first Standby then Off;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : RadiologyInstrumentSystem;
    doc /* The system shall acquire, process, display, and archive diagnostic images from radiology instruments for clinical interpretation. */
  }

  requirement def PatientSafetyRequirement {
    subject system : RadiologyInstrumentSystem;
    doc /* The system shall verify patient identity, protocol selection, positioning, and safety interlocks before image acquisition. */
  }

  requirement def DoseManagementRequirement {
    subject xray : XRayRadiographyUnit;
    subject ct : CTScanner;
    doc /* Ionizing radiation instruments shall record estimated patient dose for each completed study. */
  }

  requirement def ImageAvailabilityRequirement {
    subject archive : ImageArchive;
    doc /* Completed diagnostic image studies shall be transferred to the archive after workstation review. */
  }

  requirement def MultiModalityRequirement {
    subject system : RadiologyInstrumentSystem;
    doc /* The system shall support radiography, computed tomography, magnetic resonance imaging, and ultrasound imaging instruments. */
  }

}