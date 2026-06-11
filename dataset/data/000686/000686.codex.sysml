package MedTechEuropeBasedSystem {

  import ScalarValues::*;
  import SI::*;

  item def SterileDrugSolution {
    attribute drugName : String;
    attribute concentration : Concentration;
    attribute volume : Volume;
    attribute sterilityStatus : SterilityStatus;
  }

  item def InfusionCommand {
    attribute prescribedRate : FlowRate;
    attribute prescribedVolume : Volume;
    attribute maxBolusVolume : Volume;
    attribute therapyId : String;
  }

  item def PatientPhysiology {
    attribute venousPressure : Pressure;
    attribute heartRate : Frequency;
    attribute oxygenSaturation : Percent;
  }

  item def ClinicalAlarm {
    attribute alarmCode : AlarmCode;
    attribute severity : AlarmSeverity;
    attribute message : String;
  }

  item def AuditEvent {
    attribute timestamp : Time;
    attribute actorId : String;
    attribute eventText : String;
  }

  value type Volume {
    unit = "mL";
  }

  value type FlowRate {
    unit = "mL/h";
  }

  value type Pressure {
    unit = "kPa";
  }

  value type Concentration {
    unit = "mg/mL";
  }

  value type Percent {
    unit = "%";
  }

  value type Energy {
    unit = "Wh";
  }

  enum def SterilityStatus {
    enum sterile;
    enum compromised;
    enum unknown;
  }

  enum def AlarmSeverity {
    enum advisory;
    enum medium;
    enum high;
  }

  enum def AlarmCode {
    enum occlusionDetected;
    enum airInLineDetected;
    enum doorOpen;
    enum lowBattery;
    enum infusionComplete;
    enum unauthorizedConfiguration;
    enum sensorFault;
  }

  enum def PumpOperatingState {
    enum poweredOff;
    enum selfTest;
    enum ready;
    enum configured;
    enum infusing;
    enum paused;
    enum alarmed;
    enum completed;
    enum serviceLocked;
  }

  port def FluidInletPort {
    in item solution : SterileDrugSolution;
  }

  port def FluidOutletPort {
    out item solution : SterileDrugSolution;
  }

  port def CommandPort {
    in item command : InfusionCommand;
  }

  port def PhysiologyPort {
    in item physiology : PatientPhysiology;
  }

  port def AlarmPort {
    out item alarm : ClinicalAlarm;
  }

  port def AuditPort {
    out item event : AuditEvent;
  }

  port def PowerPort {
    in attribute supplyVoltage : Real;
    in attribute availableEnergy : Energy;
  }

  part def DisposableInfusionSet {
    port reservoirInterface : FluidInletPort;
    port patientInterface : FluidOutletPort;

    attribute primed : Boolean;
    attribute tubingVolume : Volume = 3.5;
    attribute maximumPressure : Pressure = 200.0;
  }

  part def FlowSensor {
    port measuredFluid : FluidInletPort;

    attribute measuredRate : FlowRate;
    attribute accuracy : Percent = 5.0;
    attribute faultDetected : Boolean;
  }

  part def PressureSensor {
    attribute measuredPressure : Pressure;
    attribute occlusionThreshold : Pressure = 140.0;
    attribute faultDetected : Boolean;
  }

  part def AirInLineSensor {
    attribute bubbleVolumeDetected : Volume;
    attribute detectionThreshold : Volume = 0.05;
    attribute faultDetected : Boolean;
  }

  part def PumpActuator {
    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;

    attribute commandedRate : FlowRate;
    attribute deliveredVolume : Volume;
    attribute actuatorEnabled : Boolean;
  }

  part def UserInterface {
    port clinicianCommand : CommandPort;
    port alarmDisplay : AlarmPort;

    attribute authenticatedClinician : Boolean;
    attribute displayedRate : FlowRate;
    attribute displayedVolumeRemaining : Volume;
  }

  part def SafetyController {
    port commandInput : CommandPort;
    port patientInput : PhysiologyPort;
    port alarmOutput : AlarmPort;
    port auditOutput : AuditPort;

    attribute operatingState : PumpOperatingState;
    attribute activePrescription : InfusionCommand;
    attribute cumulativeDeliveredVolume : Volume;
    attribute batteryReserve : Energy;
    attribute therapyLocked : Boolean;
  }

  part def PowerSubsystem {
    port externalPower : PowerPort;

    attribute batteryCapacity : Energy = 60.0;
    attribute remainingEnergy : Energy;
    attribute charging : Boolean;
    attribute lowBatteryThreshold : Energy = 8.0;
  }

  part def SecureConnectivityModule {
    port auditStream : AuditPort;

    attribute encryptionEnabled : Boolean = true;
    attribute connectedToHospitalNetwork : Boolean;
    attribute deviceIdentifier : String;
  }

  action def ValidatePrescription {
    in item command : InfusionCommand;
    out valid : Boolean;

    constraint rateLimit {
      command.prescribedRate >= 0.1 and command.prescribedRate <= 1200.0
    }

    constraint volumeLimit {
      command.prescribedVolume > 0.0 and command.prescribedVolume <= 1000.0
    }
  }

  action def DeliverInfusion {
    in item solution : SterileDrugSolution;
    in item command : InfusionCommand;
    out deliveredVolume : Volume;

    constraint sterileFluidOnly {
      solution.sterilityStatus == SterilityStatus::sterile
    }

    constraint deliverNoMoreThanPrescribed {
      deliveredVolume <= command.prescribedVolume
    }
  }

  action def DetectHazard {
    in pressure : Pressure;
    in bubbleVolume : Volume;
    in remainingEnergy : Energy;
    out item alarm : ClinicalAlarm;
  }

  action def RecordAuditEvent {
    in text : String;
    out item event : AuditEvent;
  }

  state def InfusionPumpStateMachine {
    entry action RecordAuditEvent { text = "Device state machine entered"; }

    state poweredOff;
    state selfTest;
    state ready;
    state configured;
    state infusing;
    state paused;
    state alarmed;
    state completed;
    state serviceLocked;

    initial then poweredOff;

    transition powerApplied
      first poweredOff
      then selfTest;

    transition selfTestPassed
      first selfTest
      then ready;

    transition selfTestFailed
      first selfTest
      then serviceLocked;

    transition prescriptionAccepted
      first ready
      then configured;

    transition startInfusion
      first configured
      then infusing;

    transition pauseRequested
      first infusing
      then paused;

    transition resumeRequested
      first paused
      then infusing;

    transition hazardDetected
      first infusing
      then alarmed;

    transition alarmAcknowledged
      first alarmed
      then paused;

    transition volumeDelivered
      first infusing
      then completed;

    transition resetForNextTherapy
      first completed
      then ready;
  }

  part def SmartInfusionPumpSystem {
    doc /* Primary function: accurately and safely deliver prescribed sterile drug solutions to a patient at controlled flow rates while monitoring therapy conditions, preventing hazardous delivery, alarming clinicians, and recording traceable clinical audit data in alignment with MedTech Europe principles for patient safety, clinical value, cybersecurity, and regulatory-quality evidence. */

    port medicationIn : FluidInletPort;
    port patientLineOut : FluidOutletPort;
    port clinicianOrders : CommandPort;
    port patientMonitoring : PhysiologyPort;
    port clinicalAlarms : AlarmPort;
    port auditEvents : AuditPort;
    port mainsPower : PowerPort;

    part disposableSet : DisposableInfusionSet;
    part actuator : PumpActuator;
    part flowSensor : FlowSensor;
    part pressureSensor : PressureSensor;
    part airSensor : AirInLineSensor;
    part ui : UserInterface;
    part controller : SafetyController;
    part power : PowerSubsystem;
    part connectivity : SecureConnectivityModule;

    attribute nominalFlowAccuracy : Percent = 5.0;
    attribute maximumContinuousInfusionRate : FlowRate = 1200.0;
    attribute minimumContinuousInfusionRate : FlowRate = 0.1;
    attribute maximumReservoirVolume : Volume = 1000.0;
    attribute cybersecurityLoggingEnabled : Boolean = true;

    connect medicationIn to disposableSet.reservoirInterface;
    connect disposableSet.patientInterface to actuator.inlet;
    connect actuator.outlet to patientLineOut;
    connect clinicianOrders to ui.clinicianCommand;
    connect clinicianOrders to controller.commandInput;
    connect patientMonitoring to controller.patientInput;
    connect controller.alarmOutput to clinicalAlarms;
    connect controller.alarmOutput to ui.alarmDisplay;
    connect controller.auditOutput to auditEvents;
    connect controller.auditOutput to connectivity.auditStream;
    connect mainsPower to power.externalPower;

    perform action ValidatePrescription {
      in command = controller.activePrescription;
      out valid;
    }

    perform action DeliverInfusion {
      in solution = medicationIn.solution;
      in command = controller.activePrescription;
      out deliveredVolume = controller.cumulativeDeliveredVolume;
    }

    perform action DetectHazard {
      in pressure = pressureSensor.measuredPressure;
      in bubbleVolume = airSensor.bubbleVolumeDetected;
      in remainingEnergy = power.remainingEnergy;
      out alarm = clinicalAlarms.alarm;
    }

    exhibit state InfusionPumpStateMachine;
  }

  requirement def PrimaryClinicalFunctionRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The system shall provide controlled infusion therapy by delivering a prescribed sterile drug solution from a reservoir to the patient through a disposable infusion set at the commanded rate and volume. */

    require constraint {
      pump.controller.cumulativeDeliveredVolume <= pump.controller.activePrescription.prescribedVolume
    }
  }

  requirement def FlowAccuracyRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The delivered flow rate shall remain within plus or minus 5 percent of the prescribed flow rate during normal infusion. */

    require constraint {
      pump.nominalFlowAccuracy <= 5.0
    }
  }

  requirement def OcclusionSafetyRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The system shall stop infusion and generate a high severity alarm when line pressure exceeds the occlusion threshold. */

    require constraint {
      pump.pressureSensor.measuredPressure <= pump.pressureSensor.occlusionThreshold
      or pump.controller.operatingState == PumpOperatingState::alarmed
    }
  }

  requirement def AirInLineSafetyRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The system shall stop infusion and generate a high severity alarm when detected air volume exceeds the configured threshold. */

    require constraint {
      pump.airSensor.bubbleVolumeDetected <= pump.airSensor.detectionThreshold
      or pump.controller.operatingState == PumpOperatingState::alarmed
    }
  }

  requirement def SterilePathRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The patient fluid path shall accept only sterile solution status for active infusion. */

    require constraint {
      pump.medicationIn.solution.sterilityStatus == SterilityStatus::sterile
    }
  }

  requirement def BatteryReserveRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The system shall issue a low battery alarm before remaining battery energy falls below the minimum safe reserve. */

    require constraint {
      pump.power.remainingEnergy >= pump.power.lowBatteryThreshold
      or pump.controller.operatingState == PumpOperatingState::alarmed
    }
  }

  requirement def CybersecurityTraceabilityRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The system shall record clinician configuration, therapy start, therapy pause, alarm, and completion events with secure device identity and encrypted connectivity enabled. */

    require constraint {
      pump.connectivity.encryptionEnabled == true
      and pump.cybersecurityLoggingEnabled == true
    }
  }

  requirement def UnauthorizedUsePreventionRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The system shall reject prescription changes unless a clinician is authenticated. */

    require constraint {
      pump.ui.authenticatedClinician == true
      or pump.controller.therapyLocked == true
    }
  }

  requirement def MedTechEuropeValueRequirement {
    subject pump : SmartInfusionPumpSystem;

    doc /* The system shall support patient-centered clinical value by combining safe therapy delivery, usability for clinicians, traceable performance evidence, and protection of patient-related operational data. */

    require constraint {
      pump.nominalFlowAccuracy <= 5.0
      and pump.connectivity.encryptionEnabled == true
      and pump.cybersecurityLoggingEnabled == true
    }
  }

  satisfy PrimaryClinicalFunctionRequirement by SmartInfusionPumpSystem;
  satisfy FlowAccuracyRequirement by SmartInfusionPumpSystem;
  satisfy OcclusionSafetyRequirement by SmartInfusionPumpSystem;
  satisfy AirInLineSafetyRequirement by SmartInfusionPumpSystem;
  satisfy SterilePathRequirement by SmartInfusionPumpSystem;
  satisfy BatteryReserveRequirement by SmartInfusionPumpSystem;
  satisfy CybersecurityTraceabilityRequirement by SmartInfusionPumpSystem;
  satisfy UnauthorizedUsePreventionRequirement by SmartInfusionPumpSystem;
  satisfy MedTechEuropeValueRequirement by SmartInfusionPumpSystem;
}