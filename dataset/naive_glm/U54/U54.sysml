package DBS_Therapy_System {

  import ScalarValues::*;

  // ===== Value Types with Units =====
  value type Voltage :> Real { unit 'V' }
  value type Current :> Real { unit 'A' }
  value type Impedance :> Real { unit 'ohm' }
  value type Frequency :> Real { unit 'Hz' }
  value type PulseWidth :> Real {> 'us' }
  value type Charge :> Real { unit 'C' }
  value type BatteryLevel :> Real { unit '%' }
  value type Power :> Real { unit 'W' }
  value type Length :> Real { unit 'mm' }

  // ===== Items =====
  item def NeuralSignal {
    attribute amplitude : Voltage;
    attribute frequency : Frequency;
  }
  item def StimulationPulse {
    attribute amplitude : Current;
    attribute frequency : Frequency;
    attribute pulseWidth : PulseWidth;
    attribute electrodeIndex : Integer;
  }
  item def TelemetryData {
    attribute batteryLevel : BatteryLevel;
    attribute impedance : Impedance;
    attribute deliveredCharge : Charge;
    attribute systemStatus : String;
  }
  item def ProgrammingCommand {
    attribute commandType : String;
    attribute amplitude : Current;
    attribute frequency : Frequency;
    attribute pulseWidth : PulseWidth;
  }
  item def ImpedanceMeasurement {
    attribute value : Impedance;
    attribute electrodeIndex : Integer;
  }
  item def AlertMessage {
    attribute alertType : String;
    attribute severity : String;
  }

  // ===== Port Definitions =====
  port def NeuralPort {
    in neuralSignal : NeuralSignal;
    out stimulationPulse : StimulationPulse;
    out impedance : ImpedanceMeasurement;
  }
  port def TelemetryPort {
    out data : TelemetryData;
    in command : ProgrammingCommand;
  }
  port def LeadConnectionPort {
    in stimulationPulse : StimulationPulse;
    out neuralSignal : NeuralSignal;
    out impedance : ImpedanceMeasurement;
  }

  // ===== Requirements =====
  requirement def TherapyDeliveryRequirement {
    doc "The system shall deliver controlled electrical pulses to targeted brain areas to modulate abnormal neural activity."
    subject dbsSystem : DBS_Therapy_System
    attribute deliversTherapy : Boolean;
    objective { dbsSystem.deliversTherapy == true }
  }

  requirement def ClosedLoopControlRequirement {
    doc "The system shall continuously sense neural activity, analyze pathological patterns, and deliver adaptive stimulation in a closed loop."
    subject dbsSystem : DBS_Therapy_System
    attribute closedLoopActive : Boolean;
    objective { dbsSystem.closedLoopActive == true }
  }

  requirement def SafetyMonitoringRequirement {
    doc "The system shall continuously monitor lead impedance and delivered charge to ensure patient safety."
    subject dbsSystem : DBS_Therapy_System
    attribute safetyMonitoringActive : Boolean;
    objective { dbsSystem.safetyMonitoringActive == true }
  }

  requirement def BatteryLifeRequirement {
    doc "The IPG shall generate a low battery alert when battery level falls below a defined threshold."
    subject ipg : IPG
    attribute batteryAlertEnabled : Boolean;
    objective { ipg.batteryAlertEnabled == true }
  }

  requirement def WirelessCommunicationRequirement {
    doc "The clinician programmer shall communicate wirelessly with the IPG for programming and monitoring."
    subject programmer : ClinicianProgrammer
    attribute wirelessLinkEstablished : Boolean;
    objective { programmer.wirelessLinkEstablished == true }
  }

  requirement def ImpedanceSafetyRequirement {
    doc "The system shall detect lead impedance outside the safe range and suspend stimulation."
    subject ipg : IPG
    attribute impedanceSafeRangeMin : Impedance = 200;
    attribute impedanceSafeRangeMax : Impedance = 2000;
    objective { ipg.impedanceWithinSafeRange == true }
  }

  // ===== IPG (Implantable Pulse Generator) =====
  part def IPG {
    attribute batteryLevel : BatteryLevel = 100;
    attribute pulseAmplitude : Current = 0.001;
    attribute pulseFrequency : Frequency = 130;
    attribute pulseWidth : PulseWidth = 60;
    attribute impedanceThreshold : Impedance = 1000;
    attribute chargeLimit : Charge = 0.00001;
    attribute deliveredCharge : Charge = 0;
    attribute deliversTherapy : Boolean = false;
    attribute closedLoopActive : Boolean = false;
    attribute safetyMonitoringActive : Boolean = false;
    attribute batteryAlertEnabled : Boolean = true;
    attribute wirelessLinkEstablished : Boolean = false;
    attribute impedanceWithinSafeRange : Boolean = true;
    attribute lowBatteryThreshold : BatteryLevel = 10;

    port telemetryPort : TelemetryPort;
    port leadPort : LeadConnectionPort;

    part battery {
      attribute capacity : Charge = 1.0;
      attribute remaining : BatteryLevel = 100;
      attribute voltage : Voltage = 3.2;
    }

    part processingCircuit {
      attribute clockFrequency : Frequency = 1000000;
      action analyzeSignal {
        in neuralSignal : NeuralSignal;
        out pathologicalDetected : Boolean;
      }
      action calculateStimulation {
        in pathologicalDetected : Boolean;
        out stimulationPulse : StimulationPulse;
      }
      action generatePulse {
        in stimulationPulse : StimulationPulse;
        out electricalPulse : StimulationPulse;
      }
    }

    part telemetryUnit {
      attribute carrierFrequency : Frequency = 403000000;
      action transmitData {
        in data : TelemetryData;
      }
      action receiveCommand {
        out command : ProgrammingCommand;
      }
      action establishLink {
        out linkEstablished : Boolean;
      }
    }

    part safetyMonitor {
      attribute maxChargePerPhase : Charge = 0.00003;
      action checkImpedance {
        in impedance : ImpedanceMeasurement;
        out safe : Boolean;
      }
      action checkCharge {
        in deliveredCharge : Charge;
        out safe : Boolean;
      }
      action generateAlert {
        in alertType : String;
        out alert : AlertMessage;
      }
    }

    part pulseGenerator {
      attribute outputVoltage : Voltage = 10;
      action deliverPulse {
        in stimulationPulse : StimulationPulse;
        out electricalPulse : StimulationPulse;
      }
    }

    // State Machine
    state def IPGStateMachine {
      entry; then off;

      state off {
        entry { deliversTherapy = false; closedLoopActive = false; safetyMonitoringActive = false; }
      }

      transition off_to_standby
        first off
        if telemetryPort.command.commandType == "powerOn"
        then standby;

      state standby {
        entry { wirelessLinkEstablished = true; safetyMonitoringActive = true; }
        do action monitorLink {
          // listen for programming commands
        }
      }

      transition standby_to_active
        first standby
        if telemetryPort.command.commandType == "startTherapy"
        then active;

      state active {
        entry { deliversTherapy = true; closedLoopActive = true; }
        do action closedLoopTherapy {
          // continuous sensing, analyzing, stimulating
          first sense;
          then analyze;
          then stimulate;
          then sense;

          action sense {
            in neuralSignal : NeuralSignal;
            out sensedSignal : NeuralSignal;
          }
          action analyze {
            in sensedSignal : NeuralSignal;
            out pathologicalDetected : Boolean;
          }
          action stimulate {
            in pathologicalDetected : Boolean;
            out stimulationPulse : StimulationPulse;
          }
        }
      }

      transition active_to_standby
        first active
        if telemetryPort.command.commandType == "stopTherapy"
        then standby;

      transition active_to_off
        first active
        if batteryLevel < lowBatteryThreshold
        then off;

      transition standby_to_off
        first standby
        if telemetryPort.command.commandType == "powerOff"
        then off;
    }

    exhibit state IPGStateMachine;
  }

  // ===== Lead Assembly =====
  part def LeadAssembly {
    attribute leadLength : Length = 400;
    attribute insulationType : String = "Polyurethane";
    attribute electrodeCount : Integer = 4;
    port neuralPort : NeuralPort;

    part def Electrode {
      attribute position : Integer;
      attribute active : Boolean = false;
      attribute surfaceArea : Real = 1.5;
      port electrodePort : NeuralPort;
    }

    part electrodes : Electrode[4] {
      attribute positions : Integer[4] = (0, 1, 2, 3);
    }

    action senseNeuralActivity {
      out neuralSignal : NeuralSignal;
    }
    action deliverStimulation {
      in stimulationPulse : StimulationPulse;
    }
    action measureImpedance {
      out impedance : ImpedanceMeasurement;
    }
  }

  // ===== Clinician Programmer =====
  part def ClinicianProgrammer {
    attribute wirelessLinkEstablished : Boolean = false;
    attribute displayType : String = "Touchscreen LCD";
    attribute batteryLevel : BatteryLevel = 100;
    port telemetryPort : TelemetryPort;

    part display {
      attribute resolution : String = "1024x768";
    }

    part wirelessModule {
      attribute carrierFrequency : Frequency = 403000000;
      action establishLink {
        out linkEstablished : Boolean;
      }
      action transmitCommand {
        in command : ProgrammingCommand;
      }
      action receiveTelemetry {
        out data : TelemetryData;
      }
    }

    action setStimulationParameters {
      out amplitude : Current;
      out frequency : Frequency;
      out pulseWidth : PulseWidth;
    }
    action monitorBattery {
      in batteryLevel : BatteryLevel;
      out alert : AlertMessage;
    }
    action checkSystemIntegrity {
      in data : TelemetryData;
      out integrityOK : Boolean;
    }
    action sendCommand {
      out command : ProgrammingCommand;
    }
    action displayAlert {
      in alert : AlertMessage;
    }
  }

  // ===== Patient =====
  part def Patient {
    attribute patientID : String;
    attribute condition : String = "Parkinson's Disease";
    part brain {
      part targetRegion {
        attribute name : String = "Subthalamic Nucleus";
        attribute depth : Length = 12;
      }
    }
  }

  // ===== Top-Level DBS Therapy System =====
  part def DBS_Therapy_System {
    attribute deliversTherapy : Boolean = false;
    attribute closedLoopActive : Boolean = false;
    attribute safetyMonitoringActive : Boolean = false;
    attribute systemID : String;

    part ipg : IPG;
    part leads : LeadAssembly[1..4];
    part programmer : ClinicianProgrammer;
    part patient : Patient;

    connection leadConnection connect ipg.leadPort to leads.neuralPort;
    connection telemetryConnection connect ipg.telemetryPort to programmer.telemetryPort;

    // Closed-loop flow
    flow neuralFlow from leads.neuralPort.neuralSignal to ipg.leadPort.neuralSignal;
    flow stimulationFlow from ipg.leadPort.stimulationPulse to leads.neuralPort.stimulationPulse;
    flow impedanceFlow from leads.neuralPort.impedance to ipg.leadPort.impedance;
    flow telemetryFlow from ipg.telemetryPort.data to programmer.telemetryPort.data;
    flow commandFlow from programmer.telemetryPort.command to ipg.telemetryPort.command;

    satisfy TherapyDeliveryRequirement by ipg;
    satisfy ClosedLoopControlRequirement by ipg;
    satisfy SafetyMonitoringRequirement by ipg.safetyMonitor;
    satisfy BatteryLifeRequirement by ipg;
    satisfy WirelessCommunicationRequirement by programmer;
    satisfy ImpedanceSafetyRequirement by ipg.safetyMonitor;
  }

  // ===== System Instance =====
  part dbsSystemInstance : DBS_Therapy_System {
    attribute systemID = "DBS-001";
    part ipg {
      attribute batteryLevel = 95;
    }
    part leads[2];
    part programmer;
    part patient {
      attribute patientID = "PT-2024-001";
    }
  }
}
