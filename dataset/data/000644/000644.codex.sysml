package CardiologyInstrumentsModel {

  import ScalarValues::*;

  attribute def Voltage_mV :> Real {
    doc /* Electric potential measured in millivolts. */
  }

  attribute def Pressure_mmHg :> Real {
    doc /* Blood pressure measured in millimeters of mercury. */
  }

  attribute def Frequency_Hz :> Real {
    doc /* Frequency measured in hertz. */
  }

  attribute def HeartRate_bpm :> Real {
    doc /* Heart rate measured in beats per minute. */
  }

  attribute def OxygenSaturation_percent :> Real {
    doc /* Arterial oxygen saturation measured as percent. */
  }

  attribute def Energy_J :> Real {
    doc /* Electrical therapy energy measured in joules. */
  }

  attribute def Time_s :> Real {
    doc /* Time measured in seconds. */
  }

  attribute def Temperature_C :> Real {
    doc /* Temperature measured in degrees Celsius. */
  }

  item def PatientPhysiology {
    attribute ecgLeadI : Voltage_mV;
    attribute ecgLeadII : Voltage_mV;
    attribute ecgLeadIII : Voltage_mV;
    attribute arterialPressure : Pressure_mmHg;
    attribute oxygenSaturation : OxygenSaturation_percent;
    attribute cardiacMotionSignal : Real;
    attribute skinTemperature : Temperature_C;
  }

  item def ECGWaveform {
    attribute sampleRate : Frequency_Hz = 500.0;
    attribute leadI : Voltage_mV;
    attribute leadII : Voltage_mV;
    attribute leadIII : Voltage_mV;
    attribute qrsDetected : Boolean;
    attribute calculatedHeartRate : HeartRate_bpm;
  }

  item def BloodPressureReading {
    attribute systolic : Pressure_mmHg;
    attribute diastolic : Pressure_mmHg;
    attribute meanArterialPressure : Pressure_mmHg;
    attribute valid : Boolean;
  }

  item def PulseOximetryReading {
    attribute spo2 : OxygenSaturation_percent;
    attribute pulseRate : HeartRate_bpm;
    attribute perfusionIndex : Real;
    attribute valid : Boolean;
  }

  item def UltrasoundImageFrame {
    attribute frameRate : Frequency_Hz = 60.0;
    attribute leftVentricleArea : Real;
    attribute wallMotionIndex : Real;
    attribute imageQuality : Real;
  }

  item def TherapyCommand {
    attribute selectedEnergy : Energy_J;
    attribute synchronized : Boolean;
    attribute authorized : Boolean;
  }

  item def DefibrillationPulse {
    attribute deliveredEnergy : Energy_J;
    attribute biphasic : Boolean = true;
    attribute pulseDuration : Time_s;
  }

  item def ClinicalAssessment {
    attribute heartRate : HeartRate_bpm;
    attribute systolicPressure : Pressure_mmHg;
    attribute diastolicPressure : Pressure_mmHg;
    attribute spo2 : OxygenSaturation_percent;
    attribute rhythmNormal : Boolean;
    attribute shockRecommended : Boolean;
    attribute summaryText : String;
  }

  port def PhysiologyAcquisitionPort {
    in patientSignal : PatientPhysiology;
  }

  port def ECGDataPort {
    out waveform : ECGWaveform;
  }

  port def PressureDataPort {
    out reading : BloodPressureReading;
  }

  port def OximetryDataPort {
    out reading : PulseOximetryReading;
  }

  port def ImagingDataPort {
    out frame : UltrasoundImageFrame;
  }

  port def AssessmentPort {
    in assessment : ClinicalAssessment;
    out assessment : ClinicalAssessment;
  }

  port def TherapyControlPort {
    in command : TherapyCommand;
    out pulse : DefibrillationPulse;
  }

  port def DisplayPort {
    in displayedAssessment : ClinicalAssessment;
    in displayedWaveform : ECGWaveform;
    in displayedPressure : BloodPressureReading;
    in displayedOximetry : PulseOximetryReading;
    in displayedImage : UltrasoundImageFrame;
  }

  port def AlarmPort {
    out audibleAlarm : Boolean;
    out visualAlarm : Boolean;
  }

  action def AcquireECG {
    in physiology : PatientPhysiology;
    out waveform : ECGWaveform;
  }

  action def MeasureBloodPressure {
    in physiology : PatientPhysiology;
    out pressure : BloodPressureReading;
  }

  action def MeasureOxygenSaturation {
    in physiology : PatientPhysiology;
    out oximetry : PulseOximetryReading;
  }

  action def AcquireCardiacImage {
    in physiology : PatientPhysiology;
    out image : UltrasoundImageFrame;
  }

  action def AnalyzeCardiacStatus {
    in waveform : ECGWaveform;
    in pressure : BloodPressureReading;
    in oximetry : PulseOximetryReading;
    in image : UltrasoundImageFrame;
    out assessment : ClinicalAssessment;
  }

  action def DeliverDefibrillation {
    in command : TherapyCommand;
    out pulse : DefibrillationPulse;
  }

  state def InstrumentOperatingState {
    entry action InitializeElectronics;
    state Off;
    state SelfTest;
    state Ready;
    state Monitoring;
    state Imaging;
    state AlarmActive;
    state TherapyArmed;
    state TherapyDelivered;
    state Fault;

    transition first Off;
    transition Off_to_SelfTest
      first Off then SelfTest;

    transition SelfTest_to_Ready
      first SelfTest then Ready
      if selfTestPassed;

    transition SelfTest_to_Fault
      first SelfTest then Fault
      if not selfTestPassed;

    transition Ready_to_Monitoring
      first Ready then Monitoring
      if patientConnected;

    transition Monitoring_to_Imaging
      first Monitoring then Imaging
      if imagingRequested;

    transition Imaging_to_Monitoring
      first Imaging then Monitoring
      if imagingComplete;

    transition Monitoring_to_AlarmActive
      first Monitoring then AlarmActive
      if shockRecommended or vitalLimitExceeded;

    transition AlarmActive_to_TherapyArmed
      first AlarmActive then TherapyArmed
      if clinicianArmsDefibrillator;

    transition TherapyArmed_to_TherapyDelivered
      first TherapyArmed then TherapyDelivered
      if clinicianConfirmsShock;

    transition TherapyDelivered_to_Monitoring
      first TherapyDelivered then Monitoring;

    transition Any_to_Fault
      first Monitoring then Fault
      if sensorFailure or batteryCritical;
  }

  part def ECGMonitor {
    port physiologyIn : PhysiologyAcquisitionPort;
    port ecgOut : ECGDataPort;

    attribute inputImpedanceMegaOhm : Real = 10.0;
    attribute bandwidthLowHz : Frequency_Hz = 0.05;
    attribute bandwidthHighHz : Frequency_Hz = 150.0;
    attribute samplingRate : Frequency_Hz = 500.0;

    action acquire : AcquireECG;
  }

  part def NonInvasiveBloodPressureMonitor {
    port physiologyIn : PhysiologyAcquisitionPort;
    port pressureOut : PressureDataPort;

    attribute cuffInflationPressure : Pressure_mmHg = 170.0;
    attribute measurementInterval : Time_s = 300.0;
    attribute overPressureLimit : Pressure_mmHg = 300.0;

    action measure : MeasureBloodPressure;
  }

  part def PulseOximeter {
    port physiologyIn : PhysiologyAcquisitionPort;
    port oximetryOut : OximetryDataPort;

    attribute redLedWavelengthNm : Real = 660.0;
    attribute infraredLedWavelengthNm : Real = 940.0;
    attribute averagingTime : Time_s = 8.0;

    action measure : MeasureOxygenSaturation;
  }

  part def EchocardiographyProbe {
    port physiologyIn : PhysiologyAcquisitionPort;
    port imageOut : ImagingDataPort;

    attribute centerFrequency : Frequency_Hz = 2500000.0;
    attribute frameRate : Frequency_Hz = 60.0;
    attribute acousticOutputIndex : Real = 0.7;

    action image : AcquireCardiacImage;
  }

  part def CardiacStatusAnalyzer {
    port ecgIn : ECGDataPort;
    port pressureIn : PressureDataPort;
    port oximetryIn : OximetryDataPort;
    port imageIn : ImagingDataPort;
    port assessmentOut : AssessmentPort;

    attribute bradycardiaLimit : HeartRate_bpm = 40.0;
    attribute tachycardiaLimit : HeartRate_bpm = 150.0;
    attribute lowSpo2Limit : OxygenSaturation_percent = 90.0;
    attribute hypotensionSystolicLimit : Pressure_mmHg = 90.0;

    action analyze : AnalyzeCardiacStatus;
  }

  part def Defibrillator {
    port therapy : TherapyControlPort;

    attribute minimumEnergy : Energy_J = 2.0;
    attribute maximumEnergy : Energy_J = 200.0;
    attribute defaultAdultEnergy : Energy_J = 150.0;
    attribute chargeTimeLimit : Time_s = 10.0;

    action deliver : DeliverDefibrillation;
  }

  part def ClinicianInterface {
    port assessmentIn : AssessmentPort;
    port display : DisplayPort;
    port alarms : AlarmPort;
    port therapyControl : TherapyControlPort;

    attribute screenDiagonalInch : Real = 15.0;
    attribute alarmSoundPressureDbA : Real = 75.0;
    attribute batteryRuntime : Time_s = 14400.0;
  }

  part def CardiologyInstrumentSystem {
    doc /* Primary function: acquire, analyze, display, and, when authorized by a clinician, treat cardiac conditions using integrated cardiology instruments. */

    port patientInput : PhysiologyAcquisitionPort;

    part ecgMonitor : ECGMonitor;
    part bloodPressureMonitor : NonInvasiveBloodPressureMonitor;
    part pulseOximeter : PulseOximeter;
    part echoProbe : EchocardiographyProbe;
    part analyzer : CardiacStatusAnalyzer;
    part defibrillator : Defibrillator;
    part userInterface : ClinicianInterface;

    attribute operatingState : InstrumentOperatingState;
    attribute patientConnected : Boolean;
    attribute selfTestPassed : Boolean;
    attribute shockRecommended : Boolean;
    attribute vitalLimitExceeded : Boolean;
    attribute clinicianArmsDefibrillator : Boolean;
    attribute clinicianConfirmsShock : Boolean;
    attribute imagingRequested : Boolean;
    attribute imagingComplete : Boolean;
    attribute sensorFailure : Boolean;
    attribute batteryCritical : Boolean;

    connection patient_to_ecg
      connect patientInput to ecgMonitor.physiologyIn;

    connection patient_to_pressure
      connect patientInput to bloodPressureMonitor.physiologyIn;

    connection patient_to_oximeter
      connect patientInput to pulseOximeter.physiologyIn;

    connection patient_to_echo
      connect patientInput to echoProbe.physiologyIn;

    connection ecg_to_analyzer
      connect ecgMonitor.ecgOut to analyzer.ecgIn;

    connection pressure_to_analyzer
      connect bloodPressureMonitor.pressureOut to analyzer.pressureIn;

    connection oximetry_to_analyzer
      connect pulseOximeter.oximetryOut to analyzer.oximetryIn;

    connection image_to_analyzer
      connect echoProbe.imageOut to analyzer.imageIn;

    connection analyzer_to_interface
      connect analyzer.assessmentOut to userInterface.assessmentIn;

    connection interface_to_defibrillator
      connect userInterface.therapyControl to defibrillator.therapy;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : CardiologyInstrumentSystem;

    require constraint {
      system.patientConnected implies
      not system.sensorFailure
    }

    doc /* The cardiology instrument system shall support high-level cardiac care by continuously acquiring cardiac physiology, presenting clinically meaningful measurements, detecting abnormal status, and enabling clinician-authorized therapy. */
  }

  requirement def ECGMonitoringRequirement {
    subject monitor : ECGMonitor;

    require constraint {
      monitor.samplingRate >= 500.0
    }

    doc /* The ECG monitor shall acquire electrical cardiac activity with sufficient sample rate for rhythm analysis. */
  }

  requirement def BloodPressureRequirement {
    subject monitor : NonInvasiveBloodPressureMonitor;

    require constraint {
      monitor.overPressureLimit <= 300.0
    }

    doc /* The blood pressure monitor shall limit cuff pressure while producing systolic, diastolic, and mean arterial pressure values. */
  }

  requirement def OximetryRequirement {
    subject oximeter : PulseOximeter;

    require constraint {
      oximeter.averagingTime <= 10.0
    }

    doc /* The pulse oximeter shall provide oxygen saturation and pulse rate suitable for bedside cardiac monitoring. */
  }

  requirement def DefibrillationSafetyRequirement {
    subject defibrillator : Defibrillator;

    require constraint {
      defibrillator.maximumEnergy <= 200.0 and
      defibrillator.chargeTimeLimit <= 10.0
    }

    doc /* The defibrillator shall constrain delivered energy and charge time to support controlled clinician-authorized cardiac therapy. */
  }

  requirement def IntegratedAssessmentRequirement {
    subject analyzer : CardiacStatusAnalyzer;

    require constraint {
      analyzer.bradycardiaLimit < analyzer.tachycardiaLimit and
      analyzer.lowSpo2Limit <= 90.0
    }

    doc /* The analyzer shall combine ECG, pressure, oxygenation, and imaging information into a single clinical assessment. */
  }

  satisfy PrimaryFunctionRequirement by CardiologyInstrumentSystem;
  satisfy ECGMonitoringRequirement by ECGMonitor;
  satisfy BloodPressureRequirement by NonInvasiveBloodPressureMonitor;
  satisfy OximetryRequirement by PulseOximeter;
  satisfy DefibrillationSafetyRequirement by Defibrillator;
  satisfy IntegratedAssessmentRequirement by CardiacStatusAnalyzer;
}