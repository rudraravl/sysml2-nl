package DrugDeliverySystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Milliliter :> Real;
  attribute def Milligram :> Real;
  attribute def Minute :> Real;
  attribute def Hour :> Real;
  attribute def MilliliterPerHour :> Real;
  attribute def MilligramPerMilliliter :> Real;
  attribute def Kilopascal :> Real;
  attribute def Percent :> Real;
  attribute def Celsius :> Real;
  attribute def Volt :> Real;
  attribute def MilliampereHour :> Real;

  enum def DeliveryMode {
    enum continuous;
    enum bolus;
    enum patientControlled;
    enum keepVeinOpen;
  }

  enum def AlarmSeverity {
    enum advisory;
    enum warning;
    enum critical;
  }

  enum def DeliveryStatus {
    enum configured;
    enum priming;
    enum ready;
    enum delivering;
    enum paused;
    enum completed;
    enum faulted;
  }

  item def Medication {
    attribute name : String;
    attribute concentration : MilligramPerMilliliter;
    attribute temperatureLimitLow : Celsius;
    attribute temperatureLimitHigh : Celsius;
  }

  item def Prescription {
    attribute patientId : String;
    attribute medicationName : String;
    attribute prescribedDose : Milligram;
    attribute concentration : MilligramPerMilliliter;
    attribute deliveryMode : DeliveryMode;
    attribute basalRate : MilliliterPerHour;
    attribute bolusVolume : Milliliter;
    attribute lockoutInterval : Minute;
    attribute maxVolumePerHour : Milliliter;
  }

  item def MedicationFlow {
    attribute medicationName : String;
    attribute concentration : MilligramPerMilliliter;
    attribute volumetricRate : MilliliterPerHour;
    attribute cumulativeVolume : Milliliter;
    attribute deliveredDose : Milligram;
    attribute linePressure : Kilopascal;
  }

  item def DeliveryCommand {
    attribute commandId : String;
    attribute requestedMode : DeliveryMode;
    attribute requestedRate : MilliliterPerHour;
    attribute requestedBolusVolume : Milliliter;
  }

  item def DeliveryReport {
    attribute patientId : String;
    attribute status : DeliveryStatus;
    attribute deliveredVolume : Milliliter;
    attribute deliveredDose : Milligram;
    attribute elapsedTime : Minute;
    attribute activeAlarmCount : Integer;
  }

  item def AlarmSignal {
    attribute code : String;
    attribute severity : AlarmSeverity;
    attribute message : String;
  }

  port def FluidInPort {
    in flow : MedicationFlow;
  }

  port def FluidOutPort {
    out flow : MedicationFlow;
  }

  port def PrescriptionPort {
    in prescription : Prescription;
  }

  port def CommandPort {
    in command : DeliveryCommand;
  }

  port def ReportPort {
    out report : DeliveryReport;
  }

  port def AlarmPort {
    out alarm : AlarmSignal;
  }

  port def PowerPort {
    in voltage : Volt;
  }

  part def MedicationReservoir {
    attribute nominalCapacity : Milliliter = 250.0;
    attribute currentVolume : Milliliter;
    attribute medication : Medication;
    port outlet : FluidOutPort;
  }

  part def AirInLineSensor {
    attribute detectedBubbleVolume : Milliliter;
    attribute detectionThreshold : Milliliter = 0.02;
    port sampledFlow : FluidInPort;
    port alarmOut : AlarmPort;
  }

  part def PressureSensor {
    attribute measuredPressure : Kilopascal;
    attribute occlusionThreshold : Kilopascal = 120.0;
    port sampledFlow : FluidInPort;
    port alarmOut : AlarmPort;
  }

  part def FlowSensor {
    attribute measuredRate : MilliliterPerHour;
    attribute measuredVolume : Milliliter;
    attribute accuracy : Percent = 5.0;
    port sampledFlow : FluidInPort;
  }

  part def InfusionPump {
    attribute commandedRate : MilliliterPerHour;
    attribute minimumRate : MilliliterPerHour = 0.1;
    attribute maximumRate : MilliliterPerHour = 1200.0;
    attribute deliveredVolume : Milliliter;
    port inlet : FluidInPort;
    port outlet : FluidOutPort;
    port commandIn : CommandPort;
  }

  part def CheckValve {
    attribute crackingPressure : Kilopascal = 2.0;
    port inlet : FluidInPort;
    port outlet : FluidOutPort;
  }

  part def PatientLine {
    attribute primingVolume : Milliliter = 1.8;
    attribute innerVolume : Milliliter = 2.5;
    port inlet : FluidInPort;
    port outlet : FluidOutPort;
  }

  part def PatientInterface {
    attribute catheterGauge : Integer = 22;
    attribute maximumSafePressure : Kilopascal = 100.0;
    port inlet : FluidInPort;
  }

  part def Battery {
    attribute capacity : MilliampereHour = 4200.0;
    attribute stateOfCharge : Percent;
    attribute lowBatteryThreshold : Percent = 15.0;
    port powerOut : PowerPort;
    port alarmOut : AlarmPort;
  }

  part def UserInterface {
    attribute displayStatus : DeliveryStatus;
    attribute clinicianAuthenticated : Boolean;
    port prescriptionIn : PrescriptionPort;
    port commandOut : CommandPort;
    port reportIn : ReportPort;
    port alarmIn : AlarmPort;
  }

  part def DeliveryController {
    attribute activeStatus : DeliveryStatus;
    attribute targetVolume : Milliliter;
    attribute targetDose : Milligram;
    attribute cumulativeDeliveredVolume : Milliliter;
    attribute cumulativeDeliveredDose : Milligram;
    attribute activePrescription : Prescription;
    port prescriptionIn : PrescriptionPort;
    port commandOut : CommandPort;
    port reportOut : ReportPort;
    port alarmOut : AlarmPort;

    state def ControllerStateMachine {
      state idle;
      state validatingPrescription;
      state primingLine;
      state ready;
      state delivering;
      state paused;
      state completed;
      state alarmed;

      transition initial then idle;
      transition idle to validatingPrescription accept Prescription;
      transition validatingPrescription to primingLine if activePrescription.prescribedDose > 0.0;
      transition validatingPrescription to alarmed if activePrescription.maxVolumePerHour <= 0.0;
      transition primingLine to ready if cumulativeDeliveredVolume >= 1.8;
      transition ready to delivering accept DeliveryCommand;
      transition delivering to paused accept DeliveryCommand if activeStatus == DeliveryStatus::paused;
      transition paused to delivering accept DeliveryCommand if activeStatus == DeliveryStatus::delivering;
      transition delivering to completed if cumulativeDeliveredDose >= targetDose;
      transition delivering to alarmed if cumulativeDeliveredVolume > activePrescription.maxVolumePerHour;
      transition delivering to alarmed accept AlarmSignal;
      transition alarmed to idle accept DeliveryCommand;
      transition completed to idle accept Prescription;
    }
  }

  action def ValidatePrescription {
    in prescription : Prescription;
    out accepted : Boolean;
    out targetVolume : Milliliter;
    out targetDose : Milligram;

    calc targetVolume = prescription.prescribedDose / prescription.concentration;
    calc targetDose = prescription.prescribedDose;
    calc accepted =
      prescription.prescribedDose > 0.0 and
      prescription.concentration > 0.0 and
      prescription.maxVolumePerHour > 0.0 and
      targetVolume <= prescription.maxVolumePerHour;
  }

  action def PrimeFluidPath {
    in lineVolume : Milliliter;
    out primedVolume : Milliliter;
    out complete : Boolean;

    calc primedVolume = lineVolume;
    calc complete = primedVolume >= lineVolume;
  }

  action def DeliverMedication {
    in prescription : Prescription;
    in commandedRate : MilliliterPerHour;
    out report : DeliveryReport;

    calc report.status = DeliveryStatus::delivering;
    calc report.deliveredVolume = prescription.prescribedDose / prescription.concentration;
    calc report.deliveredDose = prescription.prescribedDose;
  }

  action def DetectUnsafeCondition {
    in pressure : Kilopascal;
    in bubbleVolume : Milliliter;
    in batteryPercent : Percent;
    out alarm : AlarmSignal;

    calc alarm.severity =
      if pressure >= 120.0 or bubbleVolume >= 0.02 then AlarmSeverity::critical
      else if batteryPercent <= 15.0 then AlarmSeverity::warning
      else AlarmSeverity::advisory;
  }

  part def DrugDeliverySystem {
    attribute systemStatus : DeliveryStatus;
    attribute supportedMode : DeliveryMode = DeliveryMode::continuous;

    part reservoir : MedicationReservoir {
      attribute currentVolume = 250.0;
    }

    part pump : InfusionPump;
    part checkValve : CheckValve;
    part line : PatientLine;
    part patientInterface : PatientInterface;
    part pressureSensor : PressureSensor;
    part airSensor : AirInLineSensor;
    part flowSensor : FlowSensor;
    part controller : DeliveryController;
    part userInterface : UserInterface;
    part battery : Battery;

    port prescriptionInput : PrescriptionPort;
    port patientOutlet : FluidOutPort;
    port alarmOutput : AlarmPort;
    port statusOutput : ReportPort;
    port powerInput : PowerPort;

    connect prescriptionInput to controller.prescriptionIn;
    connect controller.commandOut to pump.commandIn;
    connect controller.reportOut to statusOutput;
    connect controller.alarmOut to alarmOutput;

    connect reservoir.outlet to pump.inlet;
    connect pump.outlet to checkValve.inlet;
    connect checkValve.outlet to line.inlet;
    connect line.outlet to patientInterface.inlet;
    connect line.outlet to patientOutlet;

    connect pump.outlet to flowSensor.sampledFlow;
    connect line.outlet to pressureSensor.sampledFlow;
    connect line.outlet to airSensor.sampledFlow;

    connect pressureSensor.alarmOut to alarmOutput;
    connect airSensor.alarmOut to alarmOutput;
    connect battery.alarmOut to alarmOutput;

    connect powerInput to battery.powerOut;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : DrugDeliverySystem;

    require constraint {
      system shall deliver prescribed medication from reservoir to patient interface
      at the commanded delivery mode and rate while measuring delivered volume,
      detecting unsafe conditions, and reporting delivery status.
    }
  }

  requirement def DoseAccuracyRequirement {
    subject system : DrugDeliverySystem;

    attribute maximumDoseError : Percent = 5.0;

    require constraint {
      abs(system.flowSensor.measuredVolume - system.controller.targetVolume)
      <= system.controller.targetVolume * maximumDoseError / 100.0
    }
  }

  requirement def OcclusionProtectionRequirement {
    subject system : DrugDeliverySystem;

    attribute maximumLinePressure : Kilopascal = 120.0;

    require constraint {
      system.pressureSensor.measuredPressure < maximumLinePressure
      or system.systemStatus == DeliveryStatus::faulted
    }
  }

  requirement def AirInLineProtectionRequirement {
    subject system : DrugDeliverySystem;

    attribute maximumBubbleVolume : Milliliter = 0.02;

    require constraint {
      system.airSensor.detectedBubbleVolume < maximumBubbleVolume
      or system.systemStatus == DeliveryStatus::faulted
    }
  }

  requirement def ReservoirCapacityRequirement {
    subject system : DrugDeliverySystem;

    require constraint {
      system.reservoir.nominalCapacity >=
      system.controller.activePrescription.prescribedDose /
      system.controller.activePrescription.concentration
    }
  }

  requirement def BatteryRuntimeRequirement {
    subject system : DrugDeliverySystem;

    attribute minimumStateOfChargeBeforeDelivery : Percent = 15.0;

    require constraint {
      system.battery.stateOfCharge >= minimumStateOfChargeBeforeDelivery
      or system.systemStatus == DeliveryStatus::faulted
    }
  }

  requirement def PatientSafetyStopRequirement {
    subject system : DrugDeliverySystem;

    require constraint {
      system.systemStatus == DeliveryStatus::delivering implies
      system.pressureSensor.measuredPressure < system.patientInterface.maximumSafePressure
    }
  }

}