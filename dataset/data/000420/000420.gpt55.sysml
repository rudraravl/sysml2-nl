package AlternatingElectricFieldTherapyModel {
  import ScalarValues::*;

  attribute def Frequency_kHz :> Real {
    attribute unit : String = "kHz";
  }

  attribute def Voltage_V :> Real {
    attribute unit : String = "V";
  }

  attribute def Current_mA :> Real {
    attribute unit : String = "mA";
  }

  attribute def ElectricFieldStrength_V_per_cm :> Real {
    attribute unit : String = "V/cm";
  }

  attribute def Impedance_ohm :> Real {
    attribute unit : String = "ohm";
  }

  attribute def Temperature_degC :> Real {
    attribute unit : String = "degC";
  }

  attribute def Duration_min :> Real {
    attribute unit : String = "min";
  }

  attribute def Duration_s :> Real {
    attribute unit : String = "s";
  }

  attribute def DutyCycle_percent :> Real {
    attribute unit : "%";
  }

  attribute def Energy_Wh :> Real {
    attribute unit : "Wh";
  }

  enum def WaveformKind {
    enum Sinusoidal;
    enum BiphasicSquare;
    enum AmplitudeModulatedSinusoidal;
  }

  enum def TherapyMode {
    enum Standby;
    enum SelfTest;
    enum PrescriptionLoaded;
    enum ArrayPlacementCheck;
    enum RampUp;
    enum ActiveTherapy;
    enum Paused;
    enum Fault;
    enum Completed;
  }

  enum def AlarmSeverity {
    enum Advisory;
    enum Caution;
    enum Critical;
  }

  enum def ArrayPosition {
    enum Anterior;
    enum Posterior;
    enum LeftLateral;
    enum RightLateral;
  }

  enum def TreatmentRegion {
    enum Cranial;
    enum Thoracic;
    enum Abdominal;
    enum Pelvic;
    enum Limb;
  }

  item def DCPower {
    attribute voltage : Voltage_V = 24.0;
    attribute currentLimit : Current_mA = 5000.0;
    attribute storedEnergy : Energy_Wh = 160.0;
  }

  item def TherapyPrescription {
    attribute region : TreatmentRegion = TreatmentRegion::Cranial;
    attribute targetFrequency : Frequency_kHz = 200.0;
    attribute targetFieldStrength : ElectricFieldStrength_V_per_cm = 1.5;
    attribute sessionDuration : Duration_min = 60.0;
    attribute dutyCycle : DutyCycle_percent = 75.0;
    attribute maxSkinTemperature : Temperature_degC = 41.0;
    attribute minAcceptedImpedance : Impedance_ohm = 50.0;
    attribute maxAcceptedImpedance : Impedance_ohm = 2000.0;
    attribute alternationPeriod : Duration_s = 1.0;
  }

  item def AlternatingFieldDrive {
    attribute waveform : WaveformKind = WaveformKind::Sinusoidal;
    attribute frequency : Frequency_kHz = 200.0;
    attribute peakVoltage : Voltage_V = 48.0;
    attribute rmsCurrentLimit : Current_mA = 900.0;
    attribute fieldStrengthCommand : ElectricFieldStrength_V_per_cm = 1.5;
    attribute dutyCycle : DutyCycle_percent = 75.0;
    attribute phaseOffset_deg : Real = 0.0;
  }

  item def ElectrodeTelemetry {
    attribute arrayPosition : ArrayPosition;
    attribute measuredVoltage : Voltage_V;
    attribute measuredCurrent : Current_mA;
    attribute measuredImpedance : Impedance_ohm;
    attribute measuredSkinTemperature : Temperature_degC;
    attribute contactQuality_percent : DutyCycle_percent;
  }

  item def PatientStatus {
    attribute therapyRegion : TreatmentRegion;
    attribute patientConnected : Boolean;
    attribute motionDetected : Boolean;
    attribute requestedPause : Boolean;
    attribute skinComfortRating_0_to_10 : Integer;
  }

  item def AlarmMessage {
    attribute severity : AlarmSeverity;
    attribute alarmCode : String;
    attribute alarmText : String;
    attribute latched : Boolean;
  }

  item def TreatmentLogEntry {
    attribute deliveredDuration : Duration_min;
    attribute meanFrequency : Frequency_kHz;
    attribute meanFieldStrength : ElectricFieldStrength_V_per_cm;
    attribute maximumSkinTemperature : Temperature_degC;
    attribute minimumImpedance : Impedance_ohm;
    attribute interruptions : Integer;
    attribute completedAsPrescribed : Boolean;
  }

  port def PowerInputPort {
    in item power : DCPower;
  }

  port def PowerOutputPort {
    out item power : DCPower;
  }

  port def PrescriptionInputPort {
    in item prescription : TherapyPrescription;
  }

  port def UserStatusPort {
    out item status : PatientStatus;
    out item alarm : AlarmMessage;
  }

  port def WaveformCommandPort {
    out item command : AlternatingFieldDrive;
  }

  port def WaveformInputPort {
    in item command : AlternatingFieldDrive;
  }

  port def FieldDriveOutputPort {
    out item drive : AlternatingFieldDrive;
    in item telemetry : ElectrodeTelemetry;
  }

  port def FieldDriveInputPort {
    in item drive : AlternatingFieldDrive;
    out item telemetry : ElectrodeTelemetry;
  }

  port def TelemetryOutputPort {
    out item telemetry : ElectrodeTelemetry;
  }

  port def TelemetryInputPort {
    in item telemetry : ElectrodeTelemetry;
  }

  port def PatientContactPort {
    out item fieldDrive : AlternatingFieldDrive;
    in item patientStatus : PatientStatus;
  }

  part def RechargeablePowerPack {
    attribute nominalVoltage : Voltage_V = 24.0;
    attribute capacity : Energy_Wh = 160.0;
    attribute lowEnergyThreshold : Energy_Wh = 20.0;
    port dcOut : PowerOutputPort;
  }

  part def TherapyController {
    attribute currentMode : TherapyMode = TherapyMode::Standby;
    attribute prescribedFrequency : Frequency_kHz = 200.0;
    attribute prescribedFieldStrength : ElectricFieldStrength_V_per_cm = 1.5;
    attribute prescribedDuration : Duration_min = 60.0;
    attribute accumulatedDeliveredTime : Duration_min = 0.0;
    attribute safetyInterlockEngaged : Boolean = true;
    port powerIn : PowerInputPort;
    port prescriptionIn : PrescriptionInputPort;
    port waveformCommandOut : WaveformCommandPort;
    port telemetryIn : TelemetryInputPort;
    port userStatusOut : UserStatusPort;

    action loadPrescription : LoadTherapyPrescription;
    action superviseTherapy : SuperviseAlternatingFieldTherapy;
    exhibit state operatingState : TherapyOperatingState;
  }

  part def AlternatingFieldGenerator {
    attribute supportedMinFrequency : Frequency_kHz = 100.0;
    attribute supportedMaxFrequency : Frequency_kHz = 300.0;
    attribute maximumOutputVoltage : Voltage_V = 80.0;
    attribute maximumRmsCurrent : Current_mA = 1000.0;
    attribute channelCount : Integer = 4;
    port powerIn : PowerInputPort;
    port commandIn : WaveformInputPort;
    port anteriorOutput : FieldDriveOutputPort;
    port posteriorOutput : FieldDriveOutputPort;
    port leftOutput : FieldDriveOutputPort;
    port rightOutput : FieldDriveOutputPort;

    action synthesizeField : SynthesizeAlternatingField;
  }

  part def TransducerArray {
    attribute position : ArrayPosition;
    attribute electrodeCount : Integer = 9;
    attribute hydrogelTemperatureLimit : Temperature_degC = 41.0;
    attribute nominalContactImpedance : Impedance_ohm = 400.0;
    attribute activeArea_cm2 : Real = 180.0;
    port driveIn : FieldDriveInputPort;
    port patientContact : PatientContactPort;
  }

  part def ImpedanceMonitor {
    attribute samplingPeriod : Duration_s = 0.5;
    attribute lowImpedanceLimit : Impedance_ohm = 50.0;
    attribute highImpedanceLimit : Impedance_ohm = 2000.0;
    port telemetryIn : TelemetryInputPort;
    port alarmOut : UserStatusPort;
  }

  part def SkinTemperatureMonitor {
    attribute samplingPeriod : Duration_s = 0.5;
    attribute cautionThreshold : Temperature_degC = 39.5;
    attribute criticalThreshold : Temperature_degC = 41.0;
    port telemetryIn : TelemetryInputPort;
    port alarmOut : UserStatusPort;
  }

  part def PatientUserInterface {
    attribute displayedMode : TherapyMode = TherapyMode::Standby;
    attribute remainingSessionTime : Duration_min = 60.0;
    attribute audibleAlarmEnabled : Boolean = true;
    port prescriptionIn : PrescriptionInputPort;
    port statusOut : UserStatusPort;
  }

  part def TreatmentLogger {
    attribute retainedSessions : Integer = 365;
    attribute lastCompletedDuration : Duration_min = 0.0;
    port telemetryIn : TelemetryInputPort;
    port statusOut : UserStatusPort;

    action recordSession : RecordTreatmentLog;
  }

  part def PatientInterfaceAssembly {
    part anteriorArray : TransducerArray {
      :>> position = ArrayPosition::Anterior;
    }
    part posteriorArray : TransducerArray {
      :>> position = ArrayPosition::Posterior;
    }
    part leftLateralArray : TransducerArray {
      :>> position = ArrayPosition::LeftLateral;
    }
    part rightLateralArray : TransducerArray {
      :>> position = ArrayPosition::RightLateral;
    }
  }

  part def AlternatingElectricFieldTherapySystem {
    attribute primaryFunction : String =
      "Non-invasively deliver low-intensity intermediate-frequency alternating electric fields through skin-applied transducer arrays to interfere with mitotic cell division in a prescribed treatment region while maintaining patient safety and treatment traceability.";
    attribute providesAlternatingElectricFieldTherapy : Boolean = true;
    attribute nominalTherapyFrequency : Frequency_kHz = 200.0;
    attribute nominalFieldStrength : ElectricFieldStrength_V_per_cm = 1.5;
    attribute nominalSessionDuration : Duration_min = 60.0;

    port prescriptionIn : PrescriptionInputPort;
    port patientStatusOut : UserStatusPort;

    part powerPack : RechargeablePowerPack;
    part controller : TherapyController;
    part generator : AlternatingFieldGenerator;
    part patientInterface : PatientInterfaceAssembly;
    part impedanceMonitor : ImpedanceMonitor;
    part temperatureMonitor : SkinTemperatureMonitor;
    part userInterface : PatientUserInterface;
    part logger : TreatmentLogger;

    connect powerPack.dcOut to controller.powerIn;
    connect powerPack.dcOut to generator.powerIn;

    connect prescriptionIn to controller.prescriptionIn;
    connect prescriptionIn to userInterface.prescriptionIn;

    connect controller.waveformCommandOut to generator.commandIn;

    connect generator.anteriorOutput to patientInterface.anteriorArray.driveIn;
    connect generator.posteriorOutput to patientInterface.posteriorArray.driveIn;
    connect generator.leftOutput to patientInterface.leftLateralArray.driveIn;
    connect generator.rightOutput to patientInterface.rightLateralArray.driveIn;

    connect patientInterface.anteriorArray.driveIn to impedanceMonitor.telemetryIn;
    connect patientInterface.posteriorArray.driveIn to impedanceMonitor.telemetryIn;
    connect patientInterface.leftLateralArray.driveIn to impedanceMonitor.telemetryIn;
    connect patientInterface.rightLateralArray.driveIn to impedanceMonitor.telemetryIn;

    connect patientInterface.anteriorArray.driveIn to temperatureMonitor.telemetryIn;
    connect patientInterface.posteriorArray.driveIn to temperatureMonitor.telemetryIn;
    connect patientInterface.leftLateralArray.driveIn to temperatureMonitor.telemetryIn;
    connect patientInterface.rightLateralArray.driveIn to temperatureMonitor.telemetryIn;

    connect impedanceMonitor.alarmOut to controller.userStatusOut;
    connect temperatureMonitor.alarmOut to controller.userStatusOut;
    connect controller.userStatusOut to userInterface.statusOut;
    connect controller.userStatusOut to patientStatusOut;

    connect impedanceMonitor.telemetryIn to logger.telemetryIn;
    connect temperatureMonitor.telemetryIn to logger.telemetryIn;

    action deliverTherapy : DeliverAlternatingElectricFieldTherapy;
    exhibit state therapyState : TherapyOperatingState;
  }

  event def StartTherapy;
  event def PauseTherapy;
  event def ResumeTherapy;
  event def StopTherapy;
  event def PrescriptionAccepted;
  event def ArraysVerified;
  event def RampComplete;
  event def SessionTimeComplete;
  event def FaultDetected;
  event def FaultCleared;

  action def LoadTherapyPrescription {
    in item prescription : TherapyPrescription;
    out item acceptedPrescription : TherapyPrescription;
  }

  action def ValidatePrescription {
    in item prescription : TherapyPrescription;
    out attribute valid : Boolean;
  }

  action def SynthesizeAlternatingField {
    in item command : AlternatingFieldDrive;
    out item anteriorDrive : AlternatingFieldDrive;
    out item posteriorDrive : AlternatingFieldDrive;
    out item leftDrive : AlternatingFieldDrive;
    out item rightDrive : AlternatingFieldDrive;
  }

  action def ApplyAlternatingFields {
    in item anteriorDrive : AlternatingFieldDrive;
    in item posteriorDrive : AlternatingFieldDrive;
    in item leftDrive : AlternatingFieldDrive;
    in item rightDrive : AlternatingFieldDrive;
    out item anteriorTelemetry : ElectrodeTelemetry;
    out item posteriorTelemetry : ElectrodeTelemetry;
    out item leftTelemetry : ElectrodeTelemetry;
    out item rightTelemetry : ElectrodeTelemetry;
  }

  action def MonitorTherapySafety {
    in item telemetry : ElectrodeTelemetry;
    in item prescription : TherapyPrescription;
    out item alarm : AlarmMessage;
    out attribute therapyPermitted : Boolean;
  }

  action def SuperviseAlternatingFieldTherapy {
    in item prescription : TherapyPrescription;
    in item telemetry : ElectrodeTelemetry;
    out item command : AlternatingFieldDrive;
    out item alarm : AlarmMessage;

    first validate : ValidatePrescription;
    then synthesize : SynthesizeAlternatingField;
    then monitor : MonitorTherapySafety;
    then done;
  }

  action def RecordTreatmentLog {
    in item prescription : TherapyPrescription;
    in item telemetry : ElectrodeTelemetry;
    out item logEntry : TreatmentLogEntry;
  }

  action def DeliverAlternatingElectricFieldTherapy {
    in item prescription : TherapyPrescription;
    out item treatmentSummary : TreatmentLogEntry;

    first loadPrescription : LoadTherapyPrescription;
    then validatePrescription : ValidatePrescription;
    then synthesizeWaveforms : SynthesizeAlternatingField;
    then applyFields : ApplyAlternatingFields;
    then monitorSafety : MonitorTherapySafety;
    then recordTreatment : RecordTreatmentLog;
    then done;
  }

  state def TherapyOperatingState {
    entry; then standby;

    state standby {
      entry action standbyEntry;
    }

    state selfTest {
      entry action selfTestEntry;
    }

    state prescriptionLoaded {
      entry action prescriptionLoadedEntry;
    }

    state arrayPlacementCheck {
      entry action arrayPlacementCheckEntry;
    }

    state rampUp {
      entry action rampUpEntry;
    }

    state activeTherapy {
      entry action activeTherapyEntry;
      do action DeliverAlternatingElectricFieldTherapy;
    }

    state paused {
      entry action pausedEntry;
    }

    state fault {
      entry action faultEntry;
    }

    state completed {
      entry action completedEntry;
    }

    transition startFromStandby first standby accept StartTherapy then selfTest;
    transition selfTestPassed first selfTest accept PrescriptionAccepted then prescriptionLoaded;
    transition prescriptionLoadedToArrayCheck first prescriptionLoaded accept PrescriptionAccepted then arrayPlacementCheck;
    transition arraysReady first arrayPlacementCheck accept ArraysVerified then rampUp;
    transition rampFinished first rampUp accept RampComplete then activeTherapy;
    transition pauseRequested first activeTherapy accept PauseTherapy then paused;
    transition resumeRequested first paused accept ResumeTherapy then rampUp;
    transition normalCompletion first activeTherapy accept SessionTimeComplete then completed;
    transition stopFromActive first activeTherapy accept StopTherapy then completed;
    transition stopFromPaused first paused accept StopTherapy then completed;
    transition faultDuringSelfTest first selfTest accept FaultDetected then fault;
    transition faultDuringArrayCheck first arrayPlacementCheck accept FaultDetected then fault;
    transition faultDuringRamp first rampUp accept FaultDetected then fault;
    transition faultDuringTherapy first activeTherapy accept FaultDetected then fault;
    transition faultDuringPause first paused accept FaultDetected then fault;
    transition faultReset first fault accept FaultCleared then standby;
  }

  constraint def PrescribedFrequencyWithinTherapeuticBand {
    in attribute f : Frequency_kHz;
    f >= 100.0 and f <= 300.0
  }

  constraint def PrescribedFieldStrengthWithinLowIntensityLimit {
    in attribute e : ElectricFieldStrength_V_per_cm;
    e >= 1.0 and e <= 3.0
  }

  constraint def SkinTemperatureSafe {
    in attribute t : Temperature_degC;
    t <= 41.0
  }

  constraint def ElectrodeImpedanceAcceptable {
    in attribute z : Impedance_ohm;
    z >= 50.0 and z <= 2000.0
  }

  requirement def PrimaryFunctionRequirement {
    subject system : AlternatingElectricFieldTherapySystem;
    require constraint {
      system.providesAlternatingElectricFieldTherapy == true
    }
  }

  requirement def TherapeuticFrequencyRequirement {
    subject prescription : TherapyPrescription;
    require constraint PrescribedFrequencyWithinTherapeuticBand {
      f = prescription.targetFrequency
    }
  }

  requirement def LowIntensityFieldRequirement {
    subject prescription : TherapyPrescription;
    require constraint PrescribedFieldStrengthWithinLowIntensityLimit {
      e = prescription.targetFieldStrength
    }
  }

  requirement def SkinTemperatureSafetyRequirement {
    subject telemetry : ElectrodeTelemetry;
    require constraint SkinTemperatureSafe {
      t = telemetry.measuredSkinTemperature
    }
  }

  requirement def ElectrodeContactMonitoringRequirement {
    subject telemetry : ElectrodeTelemetry;
    require constraint ElectrodeImpedanceAcceptable {
      z = telemetry.measuredImpedance
    }
  }

  requirement def TreatmentSessionTraceabilityRequirement {
    subject logEntry : TreatmentLogEntry;
    require constraint {
      logEntry.deliveredDuration >= 0.0 and
      logEntry.meanFrequency >= 100.0 and
      logEntry.meanFrequency <= 300.0 and
      logEntry.maximumSkinTemperature <= 41.0
    }
  }

  part therapySystem : AlternatingElectricFieldTherapySystem;

  requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
    subject system = therapySystem;
  }
}
