package MedicalCalculatorSystemModel {

  private import ScalarValues::*;

  enum def SexAtBirthKind {
    enum male;
    enum female;
    enum intersex;
    enum unknown;
  }

  enum def CalculationKind {
    enum bodyMassIndex;
    enum bodySurfaceArea;
    enum estimatedGlomerularFiltrationRate;
    enum creatinineClearance;
    enum weightBasedMedicationDose;
  }

  enum def ResultSeverityKind {
    enum normal;
    enum informational;
    enum caution;
    enum critical;
  }

  enum def ValidationStatusKind {
    enum accepted;
    enum corrected;
    enum rejected;
  }

  enum def CalculatorModeKind {
    enum offline;
    enum ready;
    enum collectingInputs;
    enum validatingInputs;
    enum calculating;
    enum presentingResults;
    enum logging;
    enum faulted;
  }

  attribute def KilogramValue :> Real {
    attribute unitSymbol: String = "kg";
    attribute quantityKind: String = "mass";
  }

  attribute def GramValue :> Real {
    attribute unitSymbol: String = "g";
    attribute quantityKind: String = "mass";
  }

  attribute def MeterValue :> Real {
    attribute unitSymbol: String = "m";
    attribute quantityKind: String = "length";
  }

  attribute def CentimeterValue :> Real {
    attribute unitSymbol: String = "cm";
    attribute quantityKind: String = "length";
  }

  attribute def YearValue :> Real {
    attribute unitSymbol: String = "yr";
    attribute quantityKind: String = "time";
  }

  attribute def SecondValue :> Real {
    attribute unitSymbol: String = "s";
    attribute quantityKind: String = "time";
  }

  attribute def MilligramPerDeciliterValue :> Real {
    attribute unitSymbol: String = "mg/dL";
    attribute quantityKind: String = "mass concentration";
  }

  attribute def MilliliterPerMinuteValue :> Real {
    attribute unitSymbol: String = "mL/min";
    attribute quantityKind: String = "volumetric flow rate";
  }

  attribute def MilliliterPerMinutePerSquareMeterValue :> Real {
    attribute unitSymbol: String = "mL/min/1.73m^2";
    attribute quantityKind: String = "normalized renal clearance";
  }

  attribute def SquareMeterValue :> Real {
    attribute unitSymbol: String = "m^2";
    attribute quantityKind: String = "area";
  }

  attribute def BodyMassIndexValue :> Real {
    attribute unitSymbol: String = "kg/m^2";
    attribute quantityKind: String = "body mass index";
  }

  attribute def MilligramValue :> Real {
    attribute unitSymbol: String = "mg";
    attribute quantityKind: String = "mass";
  }

  attribute def MilligramPerKilogramValue :> Real {
    attribute unitSymbol: String = "mg/kg";
    attribute quantityKind: String = "specific dose";
  }

  attribute def CountValue :> Integer {
    attribute unitSymbol: String = "count";
  }

  item def PatientIdentity {
    attribute patientIdentifier: String;
    attribute displayName: String;
    attribute sexAtBirth: SexAtBirthKind;
    attribute age: YearValue;
  }

  item def PatientAnthropometrics {
    attribute bodyMass: KilogramValue;
    attribute height: MeterValue;
  }

  item def LaboratoryValues {
    attribute serumCreatinine: MilligramPerDeciliterValue;
  }

  item def MedicationContext {
    attribute medicationName: String;
    attribute orderedDosePerKg: MilligramPerKilogramValue;
    attribute maximumSingleDose: MilligramValue;
  }

  item def PatientClinicalData {
    item identity: PatientIdentity;
    item anthropometrics: PatientAnthropometrics;
    item laboratoryValues: LaboratoryValues;
    item medicationContext: MedicationContext;
  }

  item def CalculationRequest {
    attribute requestIdentifier: String;
    attribute requestedCalculation: CalculationKind;
    attribute requestedBy: String;
    attribute clinicalPurpose: String;
    item patientData: PatientClinicalData;
  }

  item def CalculationResult {
    attribute resultIdentifier: String;
    attribute calculationPerformed: CalculationKind;
    attribute numericValue: Real;
    attribute unitSymbol: String;
    attribute interpretation: String;
    attribute severity: ResultSeverityKind;
    attribute algorithmIdentifier: String;
    attribute validForClinicalUse: Boolean;
  }

  item def ClinicalWarning {
    attribute warningIdentifier: String;
    attribute severity: ResultSeverityKind;
    attribute message: String;
    attribute recommendedAction: String;
  }

  item def ValidationReport {
    attribute status: ValidationStatusKind;
    attribute acceptedForCalculation: Boolean;
    attribute message: String;
  }

  item def AuditEvent {
    attribute eventIdentifier: String;
    attribute operatorIdentifier: String;
    attribute patientIdentifier: String;
    attribute calculationPerformed: CalculationKind;
    attribute resultUnit: String;
    attribute success: Boolean;
    attribute message: String;
  }

  item def PowerCommand {
    attribute turnOn: Boolean;
  }

  item def UserCommand {
    attribute commandName: String;
    attribute selectedCalculation: CalculationKind;
  }

  port def PowerCommandInPort {
    in item command: PowerCommand;
  }

  port def UserCommandInPort {
    in item command: UserCommand;
  }

  port def CalculationRequestInPort {
    in item request: CalculationRequest;
  }

  port def CalculationRequestOutPort {
    out item request: CalculationRequest;
  }

  port def ValidationReportOutPort {
    out item report: ValidationReport;
  }

  port def ValidationReportInPort {
    in item report: ValidationReport;
  }

  port def CalculationResultInPort {
    in item result: CalculationResult;
    in item warning: ClinicalWarning;
  }

  port def CalculationResultOutPort {
    out item result: CalculationResult;
    out item warning: ClinicalWarning;
  }

  port def AuditEventInPort {
    in item event: AuditEvent;
  }

  port def AuditEventOutPort {
    out item event: AuditEvent;
  }

  interface def CalculationRequestTransfer {
    end source: CalculationRequestOutPort;
    end target: CalculationRequestInPort;
    flow source.request to target.request;
  }

  interface def CalculationResultTransfer {
    end source: CalculationResultOutPort;
    end target: CalculationResultInPort;
    flow source.result to target.result;
    flow source.warning to target.warning;
  }

  interface def ValidationReportTransfer {
    end source: ValidationReportOutPort;
    end target: ValidationReportInPort;
    flow source.report to target.report;
  }

  interface def AuditEventTransfer {
    end source: AuditEventOutPort;
    end target: AuditEventInPort;
    flow source.event to target.event;
  }

  constraint def AdultBodyMassRange {
    in mass: KilogramValue;
    mass >= 2.0 and mass <= 350.0
  }

  constraint def AdultHeightRange {
    in height: MeterValue;
    height >= 0.30 and height <= 2.50
  }

  constraint def AdultAgeRange {
    in age: YearValue;
    age >= 0.0 and age <= 125.0
  }

  constraint def SerumCreatinineRange {
    in serumCreatinine: MilligramPerDeciliterValue;
    serumCreatinine >= 0.10 and serumCreatinine <= 20.0
  }

  constraint def BodyMassIndexFormula {
    in mass: KilogramValue;
    in height: MeterValue;
    out bodyMassIndex: BodyMassIndexValue;
    bodyMassIndex == mass / (height * height)
  }

  constraint def MostellerBodySurfaceAreaFormula {
    in mass: KilogramValue;
    in heightCm: CentimeterValue;
    out bodySurfaceArea: SquareMeterValue;
    bodySurfaceArea == sqrt((heightCm * mass) / 3600.0)
  }

  constraint def CockcroftGaultCreatinineClearanceFormula {
    in age: YearValue;
    in mass: KilogramValue;
    in serumCreatinine: MilligramPerDeciliterValue;
    in sexFactor: Real;
    out creatinineClearance: MilliliterPerMinuteValue;
    creatinineClearance == (((140.0 - age) * mass) / (72.0 * serumCreatinine)) * sexFactor
  }

  constraint def WeightBasedDoseFormula {
    in mass: KilogramValue;
    in dosePerKg: MilligramPerKilogramValue;
    in maximumSingleDose: MilligramValue;
    out recommendedDose: MilligramValue;
    recommendedDose == min(mass * dosePerKg, maximumSingleDose)
  }

  action def InitializeCalculator {
    out initialized: Boolean;
    out mode: CalculatorModeKind;
  }

  action def CaptureClinicalInputs {
    in userCommand: UserCommand;
    out request: CalculationRequest;
  }

  action def ValidateClinicalInputs {
    in request: CalculationRequest;
    out acceptedRequest: CalculationRequest;
    out validationReport: ValidationReport;

    assert constraint AdultBodyMassRange {
      mass = request.patientData.anthropometrics.bodyMass;
    }

    assert constraint AdultHeightRange {
      height = request.patientData.anthropometrics.height;
    }

    assert constraint AdultAgeRange {
      age = request.patientData.identity.age;
    }

    assert constraint SerumCreatinineRange {
      serumCreatinine = request.patientData.laboratoryValues.serumCreatinine;
    }
  }

  action def ComputeBodyMassIndex {
    in request: CalculationRequest;
    out result: CalculationResult;

    calc constraint BodyMassIndexFormula {
      mass = request.patientData.anthropometrics.bodyMass;
      height = request.patientData.anthropometrics.height;
      bodyMassIndex = result.numericValue;
    }
  }

  action def ComputeBodySurfaceArea {
    in request: CalculationRequest;
    out result: CalculationResult;

    calc constraint MostellerBodySurfaceAreaFormula {
      mass = request.patientData.anthropometrics.bodyMass;
      heightCm = request.patientData.anthropometrics.height * 100.0;
      bodySurfaceArea = result.numericValue;
    }
  }

  action def ComputeCreatinineClearance {
    in request: CalculationRequest;
    out result: CalculationResult;

    attribute sexFactor: Real =
      if request.patientData.identity.sexAtBirth == SexAtBirthKind::female then 0.85 else 1.0;

    calc constraint CockcroftGaultCreatinineClearanceFormula {
      age = request.patientData.identity.age;
      mass = request.patientData.anthropometrics.bodyMass;
      serumCreatinine = request.patientData.laboratoryValues.serumCreatinine;
      sexFactor = sexFactor;
      creatinineClearance = result.numericValue;
    }
  }

  action def ComputeEstimatedGlomerularFiltrationRate {
    in request: CalculationRequest;
    out result: CalculationResult;

    attribute algorithmIdentifier: String = "CKD-EPI-2021-creatinine";
    attribute unitSymbol: String = "mL/min/1.73m^2";
  }

  action def ComputeWeightBasedMedicationDose {
    in request: CalculationRequest;
    out result: CalculationResult;

    calc constraint WeightBasedDoseFormula {
      mass = request.patientData.anthropometrics.bodyMass;
      dosePerKg = request.patientData.medicationContext.orderedDosePerKg;
      maximumSingleDose = request.patientData.medicationContext.maximumSingleDose;
      recommendedDose = result.numericValue;
    }
  }

  action def GenerateClinicalInterpretation {
    in result: CalculationResult;
    out interpretedResult: CalculationResult;
    out warning: ClinicalWarning;
  }

  action def PresentResult {
    in result: CalculationResult;
    in warning: ClinicalWarning;
    out displayed: Boolean;
  }

  action def RecordAuditEvent {
    in request: CalculationRequest;
    in result: CalculationResult;
    out event: AuditEvent;
  }

  state def MedicalCalculatorOperatingStates {
    attribute currentMode: CalculatorModeKind;

    state Off {
      entry action {
        currentMode = CalculatorModeKind::offline;
      }
    }

    state SelfTest {
      entry action InitializeCalculator;
    }

    state Ready {
      entry action {
        currentMode = CalculatorModeKind::ready;
      }
    }

    state CollectingInputs {
      entry action {
        currentMode = CalculatorModeKind::collectingInputs;
      }
    }

    state ValidatingInputs {
      entry action ValidateClinicalInputs;
    }

    state Calculating {
      entry action {
        currentMode = CalculatorModeKind::calculating;
      }
    }

    state PresentingResults {
      entry action PresentResult;
    }

    state Logging {
      entry action RecordAuditEvent;
    }

    state Faulted {
      entry action {
        currentMode = CalculatorModeKind::faulted;
      }
    }

    transition initial then Off;
    transition powerOn first Off accept PowerCommand then SelfTest;
    transition selfTestPassed first SelfTest then Ready;
    transition calculationSelected first Ready accept UserCommand then CollectingInputs;
    transition inputsCaptured first CollectingInputs then ValidatingInputs;
    transition inputsAccepted first ValidatingInputs then Calculating;
    transition inputsRejected first ValidatingInputs then Ready;
    transition calculationComplete first Calculating then PresentingResults;
    transition resultAcknowledged first PresentingResults then Logging;
    transition auditRecorded first Logging then Ready;
    transition unrecoverableError first Ready then Faulted;
    transition resetAfterFault first Faulted accept PowerCommand then SelfTest;
    transition powerOffFromReady first Ready accept PowerCommand then Off;
  }

  part def TouchscreenUserInterface {
    port commandIn: UserCommandInPort;
    port requestOut: CalculationRequestOutPort;
    port resultIn: CalculationResultInPort;
    port validationReportIn: ValidationReportInPort;

    attribute screenDiagonal: Real = 7.0;
    attribute screenDiagonalUnit: String = "in";
    attribute minimumFontHeight: Real = 4.0;
    attribute minimumFontHeightUnit: String = "mm";
    attribute supportsMetricUnits: Boolean = true;
    attribute supportsManualEntry: Boolean = true;

    action captureInputs: CaptureClinicalInputs;
    action displayResult: PresentResult;
  }

  part def ClinicalInputValidator {
    port rawRequestIn: CalculationRequestInPort;
    port validRequestOut: CalculationRequestOutPort;
    port validationReportOut: ValidationReportOutPort;

    attribute rejectsMissingPatientIdentifier: Boolean = true;
    attribute rejectsOutOfRangeAnthropometrics: Boolean = true;
    attribute rejectsOutOfRangeSerumCreatinine: Boolean = true;

    action validate: ValidateClinicalInputs;
  }

  part def CalculationModule {
    port requestIn: CalculationRequestInPort;
    port resultOut: CalculationResultOutPort;

    attribute algorithmIdentifier: String;
    attribute calculationKind: CalculationKind;
    attribute resultUnit: String;
    attribute verified: Boolean = true;
  }

  part def BodyMassIndexModule :> CalculationModule {
    attribute algorithmIdentifier: String = "BMI-metric-mass-height-v1";
    attribute calculationKind: CalculationKind = CalculationKind::bodyMassIndex;
    attribute resultUnit: String = "kg/m^2";

    action compute: ComputeBodyMassIndex;
  }

  part def BodySurfaceAreaModule :> CalculationModule {
    attribute algorithmIdentifier: String = "Mosteller-BSA-v1";
    attribute calculationKind: CalculationKind = CalculationKind::bodySurfaceArea;
    attribute resultUnit: String = "m^2";

    action compute: ComputeBodySurfaceArea;
  }

  part def EstimatedGlomerularFiltrationRateModule :> CalculationModule {
    attribute algorithmIdentifier: String = "CKD-EPI-2021-creatinine";
    attribute calculationKind: CalculationKind = CalculationKind::estimatedGlomerularFiltrationRate;
    attribute resultUnit: String = "mL/min/1.73m^2";

    action compute: ComputeEstimatedGlomerularFiltrationRate;
  }

  part def CreatinineClearanceModule :> CalculationModule {
    attribute algorithmIdentifier: String = "Cockcroft-Gault-v1";
    attribute calculationKind: CalculationKind = CalculationKind::creatinineClearance;
    attribute resultUnit: String = "mL/min";

    action compute: ComputeCreatinineClearance;
  }

  part def WeightBasedMedicationDoseModule :> CalculationModule {
    attribute algorithmIdentifier: String = "Weight-based-dose-with-max-cap-v1";
    attribute calculationKind: CalculationKind = CalculationKind::weightBasedMedicationDose;
    attribute resultUnit: String = "mg";

    action compute: ComputeWeightBasedMedicationDose;
  }

  part def MedicalCalculationEngine {
    port requestIn: CalculationRequestInPort;
    port resultOut: CalculationResultOutPort;
    port auditEventOut: AuditEventOutPort;

    part bmiModule: BodyMassIndexModule;
    part bsaModule: BodySurfaceAreaModule;
    part egfrModule: EstimatedGlomerularFiltrationRateModule;
    part creatinineClearanceModule: CreatinineClearanceModule;
    part medicationDoseModule: WeightBasedMedicationDoseModule;

    attribute supportedCalculationCount: CountValue = 5;
    attribute maximumComputationLatency: SecondValue = 1.0;
    attribute routesByCalculationKind: Boolean = true;
    attribute producesClinicalInterpretation: Boolean = true;

    action interpret: GenerateClinicalInterpretation;
    action audit: RecordAuditEvent;
  }

  part def AuditLogger {
    port auditEventIn: AuditEventInPort;

    attribute retainsAuditTrail: Boolean = true;
    attribute retentionPeriodYears: YearValue = 7.0;
    attribute recordsOperatorIdentifier: Boolean = true;
    attribute recordsPatientIdentifier: Boolean = true;
    attribute recordsAlgorithmIdentifier: Boolean = true;
  }

  part def MedicalCalculator {
    port powerIn: PowerCommandInPort;
    port clinicianCommandIn: UserCommandInPort;

    part userInterface: TouchscreenUserInterface;
    part inputValidator: ClinicalInputValidator;
    part calculationEngine: MedicalCalculationEngine;
    part auditLogger: AuditLogger;

    attribute systemName: String = "Clinical Medical Calculator";
    attribute primaryFunctionStatement: String =
      "Accept patient-specific clinical inputs, validate them, compute common medical equations, and present traceable results for clinician decision support.";
    attribute supportedCalculationCount: CountValue = 5;
    attribute maximumClinicalResultLatency: SecondValue = 2.0;
    attribute usesMetricUnitsAsCanonicalUnits: Boolean = true;
    attribute requiresClinicianInterpretation: Boolean = true;
    attribute storesAuditRecordForEveryCompletedCalculation: Boolean = true;

    state operatingStates: MedicalCalculatorOperatingStates;

    connect clinicianCommandIn to userInterface.commandIn;
    connect userInterface.requestOut to inputValidator.rawRequestIn;
    connect inputValidator.validRequestOut to calculationEngine.requestIn;
    connect inputValidator.validationReportOut to userInterface.validationReportIn;
    connect calculationEngine.resultOut to userInterface.resultIn;
    connect calculationEngine.auditEventOut to auditLogger.auditEventIn;
  }

  requirement def PrimaryMedicalCalculatorFunctionRequirement {
    subject calculator: MedicalCalculator;

    doc
      /* The medical calculator shall provide a high-level clinical decision-support function by receiving patient-specific measurements and laboratory data, validating clinical input ranges, calculating selected medical values, presenting the numeric result with units and interpretation, and recording an audit event. */

    require constraint {
      calculator.supportedCalculationCount >= 5
    }

    require constraint {
      calculator.maximumClinicalResultLatency <= 2.0
    }

    require constraint {
      calculator.usesMetricUnitsAsCanonicalUnits == true
    }
  }

  requirement def InputValidationSafetyRequirement {
    subject validator: ClinicalInputValidator;

    doc
      /* The calculator shall reject missing identifiers and physiologically implausible values before performing a clinical calculation. */

    require constraint {
      validator.rejectsMissingPatientIdentifier == true and
      validator.rejectsOutOfRangeAnthropometrics == true and
      validator.rejectsOutOfRangeSerumCreatinine == true
    }
  }

  requirement def CalculationTraceabilityRequirement {
    subject engine: MedicalCalculationEngine;

    doc
      /* Every calculation result shall identify the calculation type, unit, and verified algorithm used to produce the result. */

    require constraint {
      engine.producesClinicalInterpretation == true and
      engine.routesByCalculationKind == true
    }
  }

  requirement def AuditRequirement {
    subject logger: AuditLogger;

    doc
      /* The calculator shall record an audit event for each completed calculation including patient, operator, algorithm, success status, and result unit. */

    require constraint {
      logger.retainsAuditTrail == true and
      logger.retentionPeriodYears >= 7.0 and
      logger.recordsOperatorIdentifier == true and
      logger.recordsPatientIdentifier == true and
      logger.recordsAlgorithmIdentifier == true
    }
  }

  requirement def HumanDisplayRequirement {
    subject ui: TouchscreenUserInterface;

    doc
      /* The calculator shall display results in metric units using legible text and shall show warnings when a result requires caution or urgent review. */

    require constraint {
      ui.supportsMetricUnits == true and
      ui.minimumFontHeight >= 4.0
    }
  }

  part medicalCalculatorSystem: MedicalCalculator {
    attribute systemName: String = "Clinical Medical Calculator";
    attribute supportedCalculationCount: CountValue = 5;
    attribute maximumClinicalResultLatency: SecondValue = 2.0;
  }

  requirement primaryFunction: PrimaryMedicalCalculatorFunctionRequirement {
    subject calculator = medicalCalculatorSystem;
  }

  requirement inputValidationSafety: InputValidationSafetyRequirement {
    subject validator = medicalCalculatorSystem.inputValidator;
  }

  requirement calculationTraceability: CalculationTraceabilityRequirement {
    subject engine = medicalCalculatorSystem.calculationEngine;
  }

  requirement auditRetention: AuditRequirement {
    subject logger = medicalCalculatorSystem.auditLogger;
  }

  requirement humanDisplay: HumanDisplayRequirement {
    subject ui = medicalCalculatorSystem.userInterface;
  }

  satisfy primaryFunction by medicalCalculatorSystem;
  satisfy inputValidationSafety by medicalCalculatorSystem.inputValidator;
  satisfy calculationTraceability by medicalCalculatorSystem.calculationEngine;
  satisfy auditRetention by medicalCalculatorSystem.auditLogger;
  satisfy humanDisplay by medicalCalculatorSystem.userInterface;
}
