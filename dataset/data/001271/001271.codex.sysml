package SNSPD_System_Model {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def CountRate :> ISQ::frequency;
  attribute def Wavelength :> ISQ::length;
  attribute def QuantumEfficiency :> ScalarValues::Real;
  attribute def DarkCountRate :> ISQ::frequency;
  attribute def TimingJitter :> ISQ::time;
  attribute def Temperature :> ISQ::thermodynamicTemperature;
  attribute def BiasCurrent :> ISQ::electricCurrent;
  attribute def VoltagePulseAmplitude :> ISQ::electricPotential;
  attribute def OpticalPower :> ISQ::power;

  item def Photon {
    attribute wavelength : Wavelength;
    attribute arrivalTime : ISQ::time;
    attribute energy : ISQ::energy;
  }

  item def DetectionPulse {
    attribute amplitude : VoltagePulseAmplitude;
    attribute riseTime : ISQ::time;
    attribute timestamp : ISQ::time;
    attribute confidence : QuantumEfficiency;
  }

  item def BiasSupply {
    attribute current : BiasCurrent;
    attribute complianceVoltage : ISQ::electricPotential;
    attribute noiseCurrentRms : BiasCurrent;
  }

  item def ThermalLoad {
    attribute heatFlow : ISQ::power;
    attribute sourceTemperature : Temperature;
  }

  item def DigitalDetectionEvent {
    attribute eventTime : ISQ::time;
    attribute channelId : ScalarValues::Integer;
    attribute pulseHeight : VoltagePulseAmplitude;
  }

  port def OpticalInputPort {
    in item photons : Photon;
  }

  port def ElectricalBiasPort {
    in item bias : BiasSupply;
  }

  port def PulseOutputPort {
    out item pulse : DetectionPulse;
  }

  port def ThermalPort {
    inout item load : ThermalLoad;
  }

  port def DigitalOutputPort {
    out item event : DigitalDetectionEvent;
  }

  part def SuperconductingNanowireSinglePhotonDetector {
    attribute operatingTemperature : Temperature = 2.5 [K];
    attribute criticalCurrent : BiasCurrent = 22 [uA];
    attribute nominalBiasCurrent : BiasCurrent = 19 [uA];
    attribute systemDetectionEfficiency : QuantumEfficiency = 0.85;
    attribute darkCountRate : DarkCountRate = 25 [Hz];
    attribute timingJitter : TimingJitter = 35 [ps];
    attribute recoveryTime : ISQ::time = 45 [ns];
    attribute activeWavelength : Wavelength = 1550 [nm];

    port opticalIn : OpticalInputPort;
    port biasIn : ElectricalBiasPort;
    port pulseOut : PulseOutputPort;
    port thermal : ThermalPort;

    part opticalCoupler {
      attribute insertionLoss : ScalarValues::Real = 0.35;
      attribute alignmentTolerance : ISQ::length = 1.0 [um];
      port input : OpticalInputPort;
      port output : OpticalInputPort;
    }

    part nanowireMeander {
      attribute material = "NbTiN";
      attribute wireWidth : ISQ::length = 80 [nm];
      attribute filmThickness : ISQ::length = 7 [nm];
      attribute fillFactor : ScalarValues::Real = 0.55;
      attribute activeAreaDiameter : ISQ::length = 16 [um];
      attribute kineticInductance : ISQ::inductance = 650 [nH];
      attribute localTemperature : Temperature = 2.5 [K];

      port photonAbsorption : OpticalInputPort;
      port bias : ElectricalBiasPort;
      port pulse : PulseOutputPort;
      port heat : ThermalPort;
    }

    part shuntAndReadoutInterface {
      attribute shuntResistance : ISQ::resistance = 50 [Ohm];
      attribute couplingCapacitance : ISQ::capacitance = 100 [nF];
      port nanowirePulseIn : PulseOutputPort;
      port conditionedPulseOut : PulseOutputPort;
    }

    connection opticalCoupling connect opticalIn to opticalCoupler.input;
    connection guidedPhotonPath connect opticalCoupler.output to nanowireMeander.photonAbsorption;
    connection biasPath connect biasIn to nanowireMeander.bias;
    connection rawPulsePath connect nanowireMeander.pulse to shuntAndReadoutInterface.nanowirePulseIn;
    connection detectorPulsePath connect shuntAndReadoutInterface.conditionedPulseOut to pulseOut;
    connection thermalPath connect nanowireMeander.heat to thermal;

    state def DetectorOperationalState {
      state initializing;
      state superconductingReady;
      state photonAbsorbed;
      state resistiveHotspot;
      state pulseEmitted;
      state recovering;
      state latchedFault;

      initial then initializing;

      transition initializing_to_ready
        first initializing
        then superconductingReady
        guard operatingTemperature <= 3.0 [K] and nominalBiasCurrent < criticalCurrent;

      transition ready_to_absorbed
        first superconductingReady
        then photonAbsorbed
        accept Photon
        guard nominalBiasCurrent >= 0.75 * criticalCurrent;

      transition absorbed_to_hotspot
        first photonAbsorbed
        then resistiveHotspot;

      transition hotspot_to_pulse
        first resistiveHotspot
        then pulseEmitted;

      transition pulse_to_recovery
        first pulseEmitted
        then recovering;

      transition recovery_to_ready
        first recovering
        then superconductingReady
        after recoveryTime;

      transition overbias_to_fault
        first superconductingReady
        then latchedFault
        guard nominalBiasCurrent >= criticalCurrent;

      transition reset_fault
        first latchedFault
        then initializing
        accept ResetCommand;
    }

    action detectSinglePhoton {
      in item incidentPhoton : Photon;
      out item detectionPulse : DetectionPulse;

      first start;
      then absorbPhoton;
      then formHotspot;
      then divertBiasCurrent;
      then generateVoltagePulse;
      then resetNanowire;
      then done;

      action absorbPhoton {
        in item p : Photon = incidentPhoton;
      }

      action formHotspot {
        in item p : Photon = incidentPhoton;
      }

      action divertBiasCurrent {
        in item bias : BiasSupply;
      }

      action generateVoltagePulse {
        out item pulse : DetectionPulse = detectionPulse;
      }

      action resetNanowire;
    }
  }

  item def ResetCommand;

  part def CryogenicPhotonCountingInstrument {
    attribute targetWavelength : Wavelength = 1550 [nm];
    attribute maximumInputCountRate : CountRate = 20 [MHz];
    attribute measuredDarkCountRate : DarkCountRate;
    attribute measuredTimingJitter : TimingJitter;

    port opticalInput : OpticalInputPort;
    port detectionEvents : DigitalOutputPort;

    part cryostat {
      attribute baseTemperature : Temperature = 2.2 [K];
      attribute coolingPowerAtBase : ISQ::power = 120 [uW];
      attribute temperatureStability : Temperature = 0.005 [K];
      port coldStage : ThermalPort;
    }

    part biasController {
      attribute setCurrent : BiasCurrent = 19 [uA];
      attribute currentResolution : BiasCurrent = 10 [nA];
      attribute currentNoiseRms : BiasCurrent = 25 [nA];
      port biasOut : ElectricalBiasPort;
    }

    part detector : SuperconductingNanowireSinglePhotonDetector {
      attribute operatingTemperature = cryostat.baseTemperature;
      attribute nominalBiasCurrent = biasController.setCurrent;
    }

    part lowNoiseAmplifier {
      attribute gain : ScalarValues::Real = 40.0;
      attribute bandwidth : ISQ::frequency = 3 [GHz];
      attribute inputImpedance : ISQ::resistance = 50 [Ohm];
      attribute outputPulseAmplitude : VoltagePulseAmplitude = 350 [mV];
      port pulseIn : PulseOutputPort;
      port pulseOut : PulseOutputPort;
    }

    part discriminator {
      attribute threshold : VoltagePulseAmplitude = 70 [mV];
      attribute deadTime : ISQ::time = 10 [ns];
      port analogPulseIn : PulseOutputPort;
      port eventOut : DigitalOutputPort;
    }

    connection inputFiberToDetector connect opticalInput to detector.opticalIn;
    connection coldStageThermalCoupling connect cryostat.coldStage to detector.thermal;
    connection biasToDetector connect biasController.biasOut to detector.biasIn;
    connection detectorToAmplifier connect detector.pulseOut to lowNoiseAmplifier.pulseIn;
    connection amplifierToDiscriminator connect lowNoiseAmplifier.pulseOut to discriminator.analogPulseIn;
    connection digitalEventOutput connect discriminator.eventOut to detectionEvents;

    action countPhotons {
      in item incomingPhoton : Photon;
      out item event : DigitalDetectionEvent;

      first receivePhoton;
      then detector.detectSinglePhoton;
      then amplifyPulse;
      then thresholdPulse;
      then emitDetectionEvent;
      then done;

      action receivePhoton {
        in item p : Photon = incomingPhoton;
      }

      action amplifyPulse {
        in item pulse : DetectionPulse;
        out item amplifiedPulse : DetectionPulse;
      }

      action thresholdPulse {
        in item pulse : DetectionPulse;
        out item acceptedEvent : DigitalDetectionEvent;
      }

      action emitDetectionEvent {
        out item e : DigitalDetectionEvent = event;
      }
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject instrument : CryogenicPhotonCountingInstrument;

    require constraint {
      instrument shall convert an absorbed single optical photon at the target wavelength into one time-stamped digital detection event.
    }
  }

  requirement def HighDetectionEfficiencyRequirement {
    subject detector : SuperconductingNanowireSinglePhotonDetector;

    require constraint {
      detector.systemDetectionEfficiency >= 0.80;
    }
  }

  requirement def LowDarkCountRequirement {
    subject detector : SuperconductingNanowireSinglePhotonDetector;

    require constraint {
      detector.darkCountRate <= 100 [Hz];
    }
  }

  requirement def TimingResolutionRequirement {
    subject detector : SuperconductingNanowireSinglePhotonDetector;

    require constraint {
      detector.timingJitter <= 50 [ps];
    }
  }

  requirement def CryogenicOperationRequirement {
    subject detector : SuperconductingNanowireSinglePhotonDetector;

    require constraint {
      detector.operatingTemperature < 4.0 [K];
    }
  }

  requirement def BiasSafetyRequirement {
    subject detector : SuperconductingNanowireSinglePhotonDetector;

    require constraint {
      detector.nominalBiasCurrent < detector.criticalCurrent;
    }
  }

  part snspdInstrument : CryogenicPhotonCountingInstrument;

  satisfy PrimaryFunctionRequirement by snspdInstrument;
  satisfy HighDetectionEfficiencyRequirement by snspdInstrument.detector;
  satisfy LowDarkCountRequirement by snspdInstrument.detector;
  satisfy TimingResolutionRequirement by snspdInstrument.detector;
  satisfy CryogenicOperationRequirement by snspdInstrument.detector;
  satisfy BiasSafetyRequirement by snspdInstrument.detector;
}