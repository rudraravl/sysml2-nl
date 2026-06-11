package GeneralMedicineInstrumentSystem {

  enum def TemperatureUnit { C; }
  enum def PressureUnit { mmHg; }
  enum def FrequencyUnit { bpm; breathsPerMinute; }
  enum def SaturationUnit { percent; }
  enum def TimeUnit { s; min; }
  enum def LengthUnit { cm; }
  enum def MassUnit { kg; }

  value def TemperatureValue {
    attribute magnitude : Real;
    attribute unit : TemperatureUnit = TemperatureUnit::C;
  }

  value def PressureValue {
    attribute magnitude : Real;
    attribute unit : PressureUnit = PressureUnit::mmHg;
  }

  value def FrequencyValue {
    attribute magnitude : Real;
    attribute unit : FrequencyUnit;
  }

  value def SaturationValue {
    attribute magnitude : Real;
    attribute unit : SaturationUnit = SaturationUnit::percent;
  }

  value def DurationValue {
    attribute magnitude : Real;
    attribute unit : TimeUnit;
  }

  value def LengthValue {
    attribute magnitude : Real;
    attribute unit : LengthUnit = LengthUnit::cm;
  }

  value def MassValue {
    attribute magnitude : Real;
    attribute unit : MassUnit = MassUnit::kg;
  }

  item def PatientInterface {
    attribute patientId : String;
    attribute contactSite : String;
  }

  item def AcousticSignal {
    attribute source : String;
    attribute intensity : Real;
    attribute frequencyHz : Real;
  }

  item def OpticalSignal {
    attribute wavelengthNm : Real;
    attribute reflectedIntensity : Real;
  }

  item def PressureSignal {
    attribute cuffPressure : PressureValue;
    attribute pulseOscillation : Real;
  }

  item def ThermalSignal {
    attribute sensedTemperature : TemperatureValue;
  }

  item def VitalSigns {
    attribute bodyTemperature : TemperatureValue;
    attribute systolicPressure : PressureValue;
    attribute diastolicPressure : PressureValue;
    attribute heartRate : FrequencyValue;
    attribute respiratoryRate : FrequencyValue;
    attribute oxygenSaturation : SaturationValue;
  }

  item def PhysicalExamObservation {
    attribute findingName : String;
    attribute findingValue : String;
    attribute bodySite : String;
    attribute confidence : Real;
  }

  item def ClinicalAssessmentRecord {
    attribute encounterId : String;
    attribute patientId : String;
    attribute measurementTime : String;
    attribute vitalSigns : VitalSigns;
    attribute observations : PhysicalExamObservation[0..*];
    attribute clinicianSummary : String;
  }

  port def PatientContactPort {
    in patientInterface : PatientInterface;
    out acousticSignal : AcousticSignal;
    out opticalSignal : OpticalSignal;
    out pressureSignal : PressureSignal;
    out thermalSignal : ThermalSignal;
  }

  port def MeasurementPort {
    in acousticSignal : AcousticSignal;
    in opticalSignal : OpticalSignal;
    in pressureSignal : PressureSignal;
    in thermalSignal : ThermalSignal;
    out vitalSigns : VitalSigns;
    out observation : PhysicalExamObservation;
  }

  port def ClinicalDataPort {
    in vitalSigns : VitalSigns;
    in observation : PhysicalExamObservation;
    out assessmentRecord : ClinicalAssessmentRecord;
  }

  port def UserInterfacePort {
    in clinicianCommand : String;
    out displayedVitalSigns : VitalSigns;
    out displayedObservation : PhysicalExamObservation;
    out alarmMessage : String;
  }

  part def Patient {
    attribute patientId : String;
    attribute bodyMass : MassValue;
    attribute height : LengthValue;

    port contact : PatientContactPort;
  }

  part def Stethoscope {
    attribute diaphragmDiameter : LengthValue;
    attribute acousticGain : Real;

    port patientSide : PatientContactPort;
    port measurementSide : MeasurementPort;

    action auscultateHeartAndLungs {
      in acousticSignal : AcousticSignal;
      out observation : PhysicalExamObservation;
    }
  }

  part def Sphygmomanometer {
    attribute cuffWidth : LengthValue;
    attribute cuffInflationLimit : PressureValue;
    attribute measurementDuration : DurationValue;

    port patientSide : PatientContactPort;
    port measurementSide : MeasurementPort;

    action measureBloodPressure {
      in pressureSignal : PressureSignal;
      out systolicPressure : PressureValue;
      out diastolicPressure : PressureValue;
    }
  }

  part def DigitalThermometer {
    attribute responseTime : DurationValue;
    attribute measurementRangeLow : TemperatureValue;
    attribute measurementRangeHigh : TemperatureValue;

    port patientSide : PatientContactPort;
    port measurementSide : MeasurementPort;

    action measureBodyTemperature {
      in thermalSignal : ThermalSignal;
      out bodyTemperature : TemperatureValue;
    }
  }

  part def PulseOximeter {
    attribute redWavelengthNm : Real;
    attribute infraredWavelengthNm : Real;
    attribute averagingTime : DurationValue;

    port patientSide : PatientContactPort;
    port measurementSide : MeasurementPort;

    action measurePulseAndOxygenSaturation {
      in opticalSignal : OpticalSignal;
      out heartRate : FrequencyValue;
      out oxygenSaturation : SaturationValue;
    }
  }

  part def Otoscope {
    attribute illuminationLevelLux : Real;
    attribute speculumDiameter : LengthValue;

    port patientSide : PatientContactPort;
    port measurementSide : MeasurementPort;

    action inspectEarCanal {
      in opticalSignal : OpticalSignal;
      out observation : PhysicalExamObservation;
    }
  }

  part def VitalSignsProcessor {
    port sensorInput : MeasurementPort;
    port dataOutput : ClinicalDataPort;

    action validateMeasurements {
      in vitalSigns : VitalSigns;
      out validVitalSigns : VitalSigns;
      out alarmMessage : String;
    }

    action assembleAssessmentRecord {
      in vitalSigns : VitalSigns;
      in observation : PhysicalExamObservation;
      out assessmentRecord : ClinicalAssessmentRecord;
    }
  }

  part def ClinicianDisplay {
    port dataInput : ClinicalDataPort;
    port userInterface : UserInterfacePort;

    action presentClinicalData {
      in assessmentRecord : ClinicalAssessmentRecord;
      out displayedVitalSigns : VitalSigns;
      out displayedObservation : PhysicalExamObservation;
    }
  }

  state def InstrumentUseStateMachine {
    entry action initializeInstrumentSet;

    state Ready;
    state PatientPrepared;
    state MeasuringTemperature;
    state MeasuringBloodPressure;
    state MeasuringPulseOximetry;
    state Auscultating;
    state Inspecting;
    state ReviewingResults;
    state Complete;

    transition first Ready;
    transition Ready_to_PatientPrepared
      first Ready then PatientPrepared
      accept clinicianCommand;

    transition PatientPrepared_to_MeasuringTemperature
      first PatientPrepared then MeasuringTemperature
      accept startTemperatureMeasurement;

    transition MeasuringTemperature_to_MeasuringBloodPressure
      first MeasuringTemperature then MeasuringBloodPressure
      accept temperatureCaptured;

    transition MeasuringBloodPressure_to_MeasuringPulseOximetry
      first MeasuringBloodPressure then MeasuringPulseOximetry
      accept bloodPressureCaptured;

    transition MeasuringPulseOximetry_to_Auscultating
      first MeasuringPulseOximetry then Auscultating
      accept oxygenSaturationCaptured;

    transition Auscultating_to_Inspecting
      first Auscultating then Inspecting
      accept auscultationComplete;

    transition Inspecting_to_ReviewingResults
      first Inspecting then ReviewingResults
      accept inspectionComplete;

    transition ReviewingResults_to_Complete
      first ReviewingResults then Complete
      accept clinicianApprovesRecord;
  }

  action def ConductGeneralMedicalAssessment {
    in patient : Patient;
    out assessmentRecord : ClinicalAssessmentRecord;

    action preparePatient;
    action captureTemperature;
    action captureBloodPressure;
    action capturePulseOximetry;
    action captureAuscultationFindings;
    action captureOtoscopeFindings;
    action validateAndDisplayResults;
    action finalizeRecord;

    first start then preparePatient;
    then captureTemperature;
    then captureBloodPressure;
    then capturePulseOximetry;
    then captureAuscultationFindings;
    then captureOtoscopeFindings;
    then validateAndDisplayResults;
    then finalizeRecord;
    then done;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : GeneralMedicineInstrumentSet;

    require constraint {
      system.primaryFunction == "Support high-level general medical assessment by collecting vital signs and physical examination observations from a patient for clinician review."
    }
  }

  requirement def VitalSignsRequirement {
    subject record : ClinicalAssessmentRecord;

    require constraint {
      record.vitalSigns.bodyTemperature.magnitude >= 25.0 and
      record.vitalSigns.bodyTemperature.magnitude <= 45.0 and
      record.vitalSigns.systolicPressure.magnitude >= 40.0 and
      record.vitalSigns.systolicPressure.magnitude <= 260.0 and
      record.vitalSigns.diastolicPressure.magnitude >= 20.0 and
      record.vitalSigns.diastolicPressure.magnitude <= 160.0 and
      record.vitalSigns.heartRate.magnitude >= 20.0 and
      record.vitalSigns.heartRate.magnitude <= 240.0 and
      record.vitalSigns.oxygenSaturation.magnitude >= 50.0 and
      record.vitalSigns.oxygenSaturation.magnitude <= 100.0
    }
  }

  requirement def ClinicianReviewRequirement {
    subject display : ClinicianDisplay;

    require constraint {
      display.userInterface.displayedVitalSigns != null
    }
  }

  requirement def NonInvasiveUseRequirement {
    subject system : GeneralMedicineInstrumentSet;

    require constraint {
      system.invasiveContact == false
    }
  }

  part def GeneralMedicineInstrumentSet {
    attribute primaryFunction : String = "Support high-level general medical assessment by collecting vital signs and physical examination observations from a patient for clinician review.";
    attribute invasiveContact : Boolean = false;

    part patient : Patient;
    part stethoscope : Stethoscope;
    part sphygmomanometer : Sphygmomanometer;
    part thermometer : DigitalThermometer;
    part pulseOximeter : PulseOximeter;
    part otoscope : Otoscope;
    part processor : VitalSignsProcessor;
    part display : ClinicianDisplay;

    port patientInterface : PatientContactPort;
    port clinicalData : ClinicalDataPort;
    port userInterface : UserInterfacePort;

    connect patient.contact to patientInterface;

    connect patientInterface to stethoscope.patientSide;
    connect patientInterface to sphygmomanometer.patientSide;
    connect patientInterface to thermometer.patientSide;
    connect patientInterface to pulseOximeter.patientSide;
    connect patientInterface to otoscope.patientSide;

    connect stethoscope.measurementSide to processor.sensorInput;
    connect sphygmomanometer.measurementSide to processor.sensorInput;
    connect thermometer.measurementSide to processor.sensorInput;
    connect pulseOximeter.measurementSide to processor.sensorInput;
    connect otoscope.measurementSide to processor.sensorInput;

    connect processor.dataOutput to clinicalData;
    connect clinicalData to display.dataInput;
    connect display.userInterface to userInterface;

    perform assessment : ConductGeneralMedicalAssessment {
      in patient = patient;
      out assessmentRecord = clinicalData.assessmentRecord;
    }

    exhibit stateMachine : InstrumentUseStateMachine;
  }

  satisfy PrimaryFunctionRequirement by GeneralMedicineInstrumentSet;
  satisfy NonInvasiveUseRequirement by GeneralMedicineInstrumentSet;
  satisfy ClinicianReviewRequirement by ClinicianDisplay;
}