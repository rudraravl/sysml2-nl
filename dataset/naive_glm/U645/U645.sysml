package DalyDetectorSystem {

  import ScalarValues::*;

  // ===== Value Types =====
  value type Voltage :> Real { unit 'V'; }
  value type Current :> Real { unit 'A'; }
  value type Energy :> Real { unit 'eV'; }
  value type Pressure :> Real { unit 'Pa'; }
  value type TimeValue :> Real { unit 's'; }
  value type Gain :> Real { unit '1'; }
  value type Count :> Integer;
  value type PulseAmplitude :> Real { unit 'V'; }
  value type Frequency :> Real { unit 'Hz'; }
  value type Temperature :> Real { unit 'K'; }
  value type Mass :> Real { unit 'u'; }
  value type Length :> Real { unit 'm'; }
  value type Percent :> Real { unit '%'; }
  value type Wavelength :> Real { unit 'nm'; }
  value type LeakRate :> Real { unit 'Pa*m^3/s'; }
  value type Volume :> Real { unit 'm^3'; }

  // ===== Item Types =====
  item def Ion {
    doc /* A charged particle to be detected. */
    attribute mass : Mass;
    attribute charge : Integer;
    attribute kineticEnergy : Energy;
  }

  item def Electron {
    doc /* Secondary electron emitted from the conversion dynode. */
    attribute kineticEnergy : Energy;
    attribute charge : Integer := -1;
  }

  item def Photon {
    doc /* Scintillation photon produced by the scintillator. */
    attribute wavelength : Wavelength;
    attribute energy : Energy;
  }

  item def ElectricalPulse {
    doc /* Electrical pulse representing a detection event. */
    attribute amplitude : PulseAmplitude;
    attribute duration : TimeValue;
    attribute timestamp : TimeValue;
    attribute valid : Boolean;
  }

  // ===== Port Definitions =====
  port def IonPort {
    inout item ions : Ion[0..*];
  }

  port def ElectronPort {
    inout item electrons : Electron[0..*];
  }

  port def PhotonPort {
    inout item photons : Photon[0..*];
  }

  port def SignalPort {
    inout item pulses : ElectricalPulse[0..*];
  }

  port def HVPort {
    out attribute voltage : Voltage;
    out attribute maxCurrent : Current;
  }

  // ===== Requirements =====
  requirement def DetectionRequirement {
    doc /* The Daly detector shall detect individual low-energy ions and produce a countable electrical pulse. */
    subject detector : DalyDetector;
    require detector.conversionEfficiency >= 0.5;
    require detector.overallGain >= 1.0e6;
    require detector.noiseThreshold == 0.05 [V];
    require detector.maxDeadTime <= 1.0e-6 [s];
  }

  requirement def VacuumRequirement {
    doc /* The vacuum chamber shall maintain pressure below 1e-5 Pa to prevent ion interference from air molecules. */
    subject chamber : VacuumChamber;
    require chamber.pressure <= 1.0e-5 [Pa];
    require chamber.leakRate <= 1.0e-9 [Pa*m^3/s];
  }

  requirement def HVStabilityRequirement {
    doc /* The high-voltage supply shall provide stable potentials for the conversion dynode and PMT. */
    subject hvSupply : HighVoltageSupply;
    require hvSupply.dynodeVoltage == -20000 [V];
    require hvSupply.pmtVoltage >= 800 [V];
    require hvSupply.voltageStability <= 0.01 [%];
    require hvSupply.ripple <= 0.1 [V];
  }

  requirement def SignalProcessingRequirement {
    doc /* The signal processor shall reject pulses below threshold and count valid ion detection events. */
    subject processor : SignalProcessor;
    require processor.noiseThreshold == 0.05 [V];
    require processor.countingEfficiency >= 0.99;
  }

  // ===== Part Definitions =====

  part def VacuumChamber {
    doc /* Enclosure maintaining vacuum to allow particles to travel without interference from air molecules. */
    port ionInput : IonPort;
    port pressureSensor : SignalPort;

    attribute pressure : Pressure;
    attribute temperature : Temperature := 293.0 [K];
    attribute volume : Volume := 0.01 [m^3];
    attribute leakRate : LeakRate;

    action def Evacuate {
      doc /* Pump down the chamber to operating vacuum. */
      out pressure : Pressure;
    }

    action def MonitorPressure {
      doc /* Continuously monitor chamber pressure and raise alarm if threshold exceeded. */
      in currentPressure : Pressure;
      out alarm : Boolean;
    }

    satisfy VacuumRequirement;
  }

  part def ConversionDynode {
    doc /* Metal plate held at high negative voltage; ion impact releases secondary electrons. */
    port ionIn : IonPort;
    port electronOut : ElectronPort;
    port hvInput : HVPort;

    attribute dynodeVoltage : Voltage := -20000 [V];
    attribute conversionEfficiency : Real := 0.6;
    attribute secondaryElectronYield : Real := 5.0;

    action def ConvertIonToElectrons {
      doc /* Ion strikes the dynode surface, knocking out a shower of secondary electrons. */
      in ion : Ion;
      out electrons : Electron[0..*];
    }
  }

  part def Scintillator {
    doc /* Phosphor-coated screen that converts electron impacts into flashes of light (photons). */
    port electronIn : ElectronPort;
    port photonOut : PhotonPort;

    attribute phosphorType : String := "P47";
    attribute photonYield : Real := 40.0;
    attribute decayTime : TimeValue := 60.0e-9 [s];

    action def ConvertElectronToPhotons {
      doc /* Accelerated electrons strike the scintillator, causing emission of scintillation photons. */
      in electrons : Electron[0..*];
      out photons : Photon[0..*];
    }
  }

  part def PhotomultiplierTube {
    doc /* Extremely sensitive light detector that amplifies weak optical signals into electrical pulses. */
    port photonIn : PhotonPort;
    port signalOut : SignalPort;
    port hvInput : HVPort;

    attribute gain : Gain := 1.0e6;
    attribute darkCountRate : Frequency := 100 [Hz];
    attribute quantumEfficiency : Real := 0.25;
    attribute dynodeStages : Integer := 10;

    action def AmplifyPhoton {
      doc /* Photons strike the photocathode; resulting electrons cascade through dynode stages, producing an electrical pulse. */
      in photons : Photon[0..*];
      out pulse : ElectricalPulse;
    }
  }

  part def SignalProcessor {
    doc /* Electronic unit that cleans the raw pulse, filters noise, and counts valid ion detection events. */
    port signalIn : SignalPort;
    port signalOut : SignalPort;

    attribute noiseThreshold : PulseAmplitude := 0.05 [V];
    attribute count : Count := 0;
    attribute countingEfficiency : Real := 0.99;
    attribute bandwidth : Frequency := 50.0e6 [Hz];

    action def ProcessPulse {
      doc /* Filter noise by rejecting pulses below threshold; accept and count valid pulses. */
      in rawPulse : ElectricalPulse;
      out conditionedPulse : ElectricalPulse;
    }

    action def ResetCounter {
      doc /* Reset the event counter to zero. */
      out count : Count := 0;
    }

    satisfy SignalProcessingRequirement;
  }

  part def HighVoltageSupply {
    doc /* Dedicated supply providing stable high-potential fields for the conversion dynode and PMT. */
    port dynodeHVOut : HVPort;
    port pmtHVOut : HVPort;

    attribute dynodeVoltage : Voltage := -20000 [V];
    attribute pmtVoltage : Voltage := 1000 [V];
    attribute voltageStability : Percent;
    attribute ripple : Voltage;
    attribute maxOutputCurrent : Current := 1.0e-3 [A];

    action def Regulate {
      doc /* Maintain stable output voltage under varying load conditions. */
      out voltage : Voltage;
    }

    satisfy HVStabilityRequirement;
  }

  // ===== Top-level System =====
  part def DalyDetector {
    doc /* A Daly Detector System: converts a single low-energy ion into a large, countable electrical pulse via a multi-stage cascade. */
    port ionInput : IonPort;
    port output : SignalPort;

    part chamber : VacuumChamber;
    part dynode : ConversionDynode;
    part scintillator : Scintillator;
    part pmt : PhotomultiplierTube;
    part processor : SignalProcessor;
    part hvSupply : HighVoltageSupply;

    attribute conversionEfficiency : Real;
    attribute overallGain : Gain;
    attribute noiseThreshold : PulseAmplitude;
    attribute maxDeadTime : TimeValue;
    attribute command : String;
    attribute calibrationComplete : Boolean;
    attribute faultCleared : Boolean;

    // --- Item flow connections (cascade path) ---
    flow ionFlow1 of Ion from ionInput to chamber.ionInput;
    flow ionFlow2 of Ion from chamber.ionInput to dynode.ionIn;
    flow electronFlow of Electron from dynode.electronOut to scintillator.electronIn;
    flow photonFlow of Photon from scintillator.photonOut to pmt.photonIn;
    flow signalFlow of ElectricalPulse from pmt.signalOut to processor.signalIn;
    flow outputFlow of ElectricalPulse from processor.signalOut to output;

    // --- High-voltage connections ---
    connection hvDynode connect hvSupply.dynodeHVOut to dynode.hvInput;
    connection hvPMT connect hvSupply.pmtHVOut to pmt.hvInput;

    // --- State machine ---
    state machine DetectorStates {
      initial;

      state idle {
        doc /* System is not in use; HV is off; vacuum is monitored. */
        entry action enterIdle { /* Power down HV, enable vacuum monitoring */ }
        do action standby { /* Continuously monitor chamber pressure */ }
        transition idle_to_active
          first idle
          if hvSupply.dynodeVoltage == -20000 [V] and chamber.pressure <= 1.0e-5 [Pa]
          then active;
      }

      state active {
        doc /* Detection mode; HV is on; ions are processed through the cascade. */
        entry action enterActive { /* Ramp up HV to operating levels */ }
        do action detect { /* Process incoming ions through the full cascade */ }
        transition active_to_calibration
          first active
          if command == "calibrate"
          then calibration;
        transition active_to_fault
          first active
          if chamber.pressure > 1.0e-5 [Pa] or hvSupply.ripple > 0.1 [V]
          then fault;
      }

      state calibration {
        doc /* Setup and tuning mode; thresholds and gains are adjusted. */
        entry action enterCalibration { /* Enable calibration signal source */ }
        do action calibrate { /* Tune noise threshold and PMT gain */ }
        transition calibration_to_active
          first calibration
          if calibrationComplete
          then active;
      }

      state fault {
        doc /* A problem has been detected; HV is disabled for safety. */
        entry action enterFault { /* Disable HV immediately, log fault */ }
        do action diagnose { /* Run diagnostics on all subsystems */ }
        transition fault_to_idle
          first fault
          if faultCleared
          then idle;
      }

      transition init_to_idle first initial then idle;
    }

    satisfy DetectionRequirement;
  }

  // ===== Instance =====
  part dalyDetectorInstance : DalyDetector {
    doc /* A configured instance of the Daly Detector System. */
    attribute conversionEfficiency := 0.6;
    attribute overallGain := 1.2e6;
    attribute noiseThreshold := 0.05 [V];
    attribute maxDeadTime := 0.5e-6 [s];
  }
}
