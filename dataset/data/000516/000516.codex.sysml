package TrigeminalNerveStimulationModel {

  import ScalarValues::*;

  attribute def ElectricCurrent_mA :> Real;
  attribute def ElectricPotential_V :> Real;
  attribute def Frequency_Hz :> Real;
  attribute def Duration_us :> Real;
  attribute def Duration_s :> Real;
  attribute def Energy_mWh :> Real;
  attribute def Impedance_ohm :> Real;
  attribute def Temperature_C :> Real;
  attribute def Percentage :> Real;

  enum def TherapyMode {
    enum idle;
    enum acuteTherapy;
    enum scheduledTherapy;
    enum diagnosticTest;
  }

  enum def FaultKind {
    enum none;
    enum lowBattery;
    enum highElectrodeImpedance;
    enum overCurrent;
    enum overTemperature;
    enum controllerFailure;
    enum disconnectedElectrode;
  }

  item def ElectricalEnergy {
    attribute storedEnergy : Energy_mWh;
    attribute sourceVoltage : ElectricPotential_V;
  }

  item def TherapyPrescription {
    attribute mode : TherapyMode;
    attribute targetAmplitude : ElectricCurrent_mA;
    attribute targetFrequency : Frequency_Hz;
    attribute pulseWidth : Duration_us;
    attribute sessionDuration : Duration_s;
    attribute rampUpTime : Duration_s;
  }

  item def StimulationPulse {
    attribute amplitude : ElectricCurrent_mA;
    attribute pulseWidth : Duration_us;
    attribute repetitionRate : Frequency_Hz;
    attribute chargeBalanced : Boolean;
  }

  item def ElectrodeMeasurement {
    attribute contactImpedance : Impedance_ohm;
    attribute skinTemperature : Temperature_C;
    attribute deliveredCurrent : ElectricCurrent_mA;
  }

  item def NeuralActivation {
    attribute trigeminalBranchActivated : Boolean;
    attribute activationLevel : Percentage;
  }

  item def UserCommand {
    attribute startRequested : Boolean;
    attribute stopRequested : Boolean;
    attribute pauseRequested : Boolean;
    attribute requestedMode : TherapyMode;
  }

  item def TherapyStatus {
    attribute active : Boolean;
    attribute elapsedTime : Duration_s;
    attribute batteryLevel : Percentage;
    attribute fault : FaultKind;
  }

  port def EnergyPort {
    in item energy : ElectricalEnergy;
  }

  port def CommandPort {
    in item command : UserCommand;
  }

  port def PrescriptionPort {
    in item prescription : TherapyPrescription;
  }

  port def PulsePort {
    out item pulse : StimulationPulse;
  }

  port def MeasurementPort {
    out item measurement : ElectrodeMeasurement;
  }

  port def NeuralInterfacePort {
    in item pulse : StimulationPulse;
    out item activation : NeuralActivation;
  }

  port def StatusPort {
    out item status : TherapyStatus;
  }

  part def RechargeableBattery {
    attribute capacity : Energy_mWh = 1200.0;
    attribute stateOfCharge : Percentage;
    attribute nominalVoltage : ElectricPotential_V = 3.7;

    port powerOut : EnergyPort;
  }

  part def TherapyController {
    attribute enabled : Boolean;
    attribute selectedMode : TherapyMode;
    attribute currentFault : FaultKind;

    port userCommandIn : CommandPort;
    port prescriptionIn : PrescriptionPort;
    port measurementIn : MeasurementPort;
    port pulseCommandOut : PrescriptionPort;
    port statusOut : StatusPort;
  }

  part def PulseGenerator {
    attribute maxCurrent : ElectricCurrent_mA = 10.0;
    attribute maxVoltage : ElectricPotential_V = 60.0;
    attribute minimumPulseWidth : Duration_us = 50.0;
    attribute maximumPulseWidth : Duration_us = 500.0;

    port powerIn : EnergyPort;
    port prescriptionIn : PrescriptionPort;
    port pulseOut : PulsePort;
  }

  part def SurfaceElectrodeArray {
    attribute electrodeCount : Integer = 2;
    attribute maximumContactImpedance : Impedance_ohm = 5000.0;
    attribute placementRegion : String = "forehead over supraorbital and supratrochlear branches";

    port pulseIn : NeuralInterfacePort;
    port measurementOut : MeasurementPort;
  }

  part def TrigeminalNerveTarget {
    attribute anatomicalTarget : String = "ophthalmic branch of trigeminal nerve";
    attribute stimulationThreshold : ElectricCurrent_mA = 1.5;
    attribute comfortableLimit : ElectricCurrent_mA = 8.0;

    port neuralInterface : NeuralInterfacePort;
  }

  part def UserInterface {
    port commandOut : CommandPort;
    port prescriptionOut : PrescriptionPort;
    port statusIn : StatusPort;
  }

  part def SafetyMonitor {
    attribute highImpedanceLimit : Impedance_ohm = 5000.0;
    attribute temperatureLimit : Temperature_C = 41.0;
    attribute batteryReserveLimit : Percentage = 10.0;
    attribute detectedFault : FaultKind;

    port measurementIn : MeasurementPort;
    port statusOut : StatusPort;
  }

  action def DeliverTherapy {
    in prescription : TherapyPrescription;
    in measurement : ElectrodeMeasurement;
    out pulse : StimulationPulse;
    out activation : NeuralActivation;

    action validatePrescription;
    action rampCurrent;
    action generateChargeBalancedPulseTrain;
    action monitorElectrodeContact;
    action stopAtSessionLimit;

    first start;
    then validatePrescription;
    then rampCurrent;
    then generateChargeBalancedPulseTrain;
    then monitorElectrodeContact;
    then stopAtSessionLimit;
  }

  action def PrimaryFunction_TrigeminalNerveStimulation {
    in prescription : TherapyPrescription;
    out activation : NeuralActivation;
    out status : TherapyStatus;

    action acceptUserTherapyRequest;
    action applyControlledElectricalPulsesToTrigeminalNerve;
    action modulateSensoryNerveActivity;
    action reportTherapyState;

    first acceptUserTherapyRequest;
    then applyControlledElectricalPulsesToTrigeminalNerve;
    then modulateSensoryNerveActivity;
    then reportTherapyState;
  }

  state def TNSOperationalStateMachine {
    state off;
    state selfTest;
    state standby;
    state therapyActive;
    state paused;
    state charging;
    state faulted;

    transition initial then off;
    transition off_to_selfTest
      first off
      accept UserCommand
      if command.startRequested
      then selfTest;

    transition selfTest_to_standby
      first selfTest
      if detectedFault == FaultKind::none
      then standby;

    transition selfTest_to_faulted
      first selfTest
      if detectedFault != FaultKind::none
      then faulted;

    transition standby_to_therapyActive
      first standby
      accept TherapyPrescription
      if prescription.mode != TherapyMode::idle
      then therapyActive;

    transition therapyActive_to_paused
      first therapyActive
      accept UserCommand
      if command.pauseRequested
      then paused;

    transition paused_to_therapyActive
      first paused
      accept UserCommand
      if command.startRequested
      then therapyActive;

    transition therapyActive_to_standby
      first therapyActive
      accept UserCommand
      if command.stopRequested
      then standby;

    transition any_to_faulted
      first therapyActive
      if detectedFault != FaultKind::none
      then faulted;

    transition faulted_to_standby
      first faulted
      accept UserCommand
      if command.stopRequested
      then standby;
  }

  part def TrigeminalNerveStimulator {
    attribute primaryFunction : String =
      "Deliver controlled, charge-balanced electrical stimulation through surface electrodes to activate selected trigeminal nerve branches and modulate sensory neural activity.";

    part battery : RechargeableBattery;
    part controller : TherapyController;
    part pulseGenerator : PulseGenerator;
    part electrodes : SurfaceElectrodeArray;
    part trigeminalTarget : TrigeminalNerveTarget;
    part userInterface : UserInterface;
    part safetyMonitor : SafetyMonitor;

    port statusOut : StatusPort;

    connect battery.powerOut to pulseGenerator.powerIn;
    connect userInterface.commandOut to controller.userCommandIn;
    connect userInterface.prescriptionOut to controller.prescriptionIn;
    connect controller.pulseCommandOut to pulseGenerator.prescriptionIn;
    connect pulseGenerator.pulseOut to electrodes.pulseIn;
    connect electrodes.pulseIn to trigeminalTarget.neuralInterface;
    connect electrodes.measurementOut to controller.measurementIn;
    connect electrodes.measurementOut to safetyMonitor.measurementIn;
    connect controller.statusOut to userInterface.statusIn;
    connect controller.statusOut to statusOut;

    exhibit state TNSOperationalStateMachine;
    perform action PrimaryFunction_TrigeminalNerveStimulation;
    perform action DeliverTherapy;
  }

  requirement def PrimaryFunctionRequirement {
    subject stimulator : TrigeminalNerveStimulator;

    require constraint {
      stimulator.primaryFunction ==
      "Deliver controlled, charge-balanced electrical stimulation through surface electrodes to activate selected trigeminal nerve branches and modulate sensory neural activity."
    }
  }

  requirement def ChargeBalancedPulseRequirement {
    subject pulse : StimulationPulse;

    require constraint {
      pulse.chargeBalanced == true
    }
  }

  requirement def CurrentLimitRequirement {
    subject pulse : StimulationPulse;

    require constraint {
      pulse.amplitude <= 10.0
    }
  }

  requirement def PulseWidthRequirement {
    subject pulse : StimulationPulse;

    require constraint {
      pulse.pulseWidth >= 50.0 and pulse.pulseWidth <= 500.0
    }
  }

  requirement def ElectrodeContactRequirement {
    subject measurement : ElectrodeMeasurement;

    require constraint {
      measurement.contactImpedance <= 5000.0
    }
  }

  requirement def ThermalSafetyRequirement {
    subject measurement : ElectrodeMeasurement;

    require constraint {
      measurement.skinTemperature <= 41.0
    }
  }

  requirement def BatteryReserveRequirement {
    subject battery : RechargeableBattery;

    require constraint {
      battery.stateOfCharge >= 10.0
    }
  }

  requirement def TherapySessionRequirement {
    subject prescription : TherapyPrescription;

    require constraint {
      prescription.sessionDuration <= 3600.0 and
      prescription.targetFrequency >= 1.0 and
      prescription.targetFrequency <= 150.0
    }
  }

  part trigeminalNerveStimulationSystem : TrigeminalNerveStimulator;

}