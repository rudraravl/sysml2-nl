package PellistorBasedGasDetectionSystem {

  import ScalarValues::*;
  import SI::*;

  value type Voltage;
  value type Current;
  value type Resistance;
  value type Temperature;
  value type Power;
  value type Time;
  value type Concentration_ppm;
  value type FlowRate_L_per_minute;
  value type PercentLEL;
  value type BooleanSignal;

  item def GasMixture {
    attribute methaneConcentration : Concentration_ppm;
    attribute oxygenFraction : Real;
    attribute humidityPercent : Real;
    attribute temperature : Temperature;
    attribute flowRate : FlowRate_L_per_minute;
  }

  item def BridgeSignal {
    attribute differentialVoltage : Voltage;
    attribute commonModeVoltage : Voltage;
    attribute bridgeCurrent : Current;
  }

  item def GasReading {
    attribute combustibleGas : Concentration_ppm;
    attribute percentLowerExplosiveLimit : PercentLEL;
    attribute valid : Boolean;
    attribute timestamp : Time;
  }

  item def AlarmCommand {
    attribute alarmActive : Boolean;
    attribute alarmLevel : Integer;
    attribute reasonCode : String;
  }

  port def GasPort {
    in gas : GasMixture;
  }

  port def ElectricalPowerPort {
    in supplyVoltage : Voltage;
    in supplyCurrent : Current;
  }

  port def SignalPort {
    out signal : BridgeSignal;
  }

  port def ReadingPort {
    out reading : GasReading;
  }

  port def AlarmPort {
    out command : AlarmCommand;
  }

  part def PellistorGasDetector {
    attribute primaryFunction : String = "Detect combustible gas by measuring heat released from catalytic oxidation on a heated pellistor bead and converting the resulting Wheatstone bridge imbalance into a gas concentration and alarm decision.";

    port gasInlet : GasPort;
    port powerInput : ElectricalPowerPort;
    port readingOutput : ReadingPort;
    port alarmOutput : AlarmPort;

    part sensingHead : PellistorSensingHead;
    part bridge : WheatstoneBridge;
    part analogFrontEnd : AnalogFrontEnd;
    part controller : MeasurementController;
    part alarmManager : AlarmManager;
    part enclosure : FlameproofEnclosure;

    connect gasInlet.gas to sensingHead.chamber.sample;
    connect powerInput.supplyVoltage to bridge.excitationVoltage;
    connect powerInput.supplyCurrent to bridge.excitationCurrent;
    connect sensingHead.activeBead.resistance to bridge.activeArmResistance;
    connect sensingHead.referenceBead.resistance to bridge.referenceArmResistance;
    connect bridge.bridgeSignal to analogFrontEnd.rawBridgeSignal;
    connect analogFrontEnd.conditionedSignal to controller.measuredSignal;
    connect controller.gasReading to readingOutput.reading;
    connect controller.gasReading to alarmManager.inputReading;
    connect alarmManager.alarmCommand to alarmOutput.command;

    action operate {
      first startSystem;
      then warmPellistor;
      then balanceBridge;
      then sampleGas;
      then estimateGasConcentration;
      then evaluateAlarm;
      then publishReading;
    }

    state machine detectorLifecycle {
      state Off;
      state WarmUp;
      state NormalMonitoring;
      state AlarmActive;
      state Fault;
      state Calibration;

      transition initial then Off;
      transition Off then WarmUp accept PowerApplied;
      transition WarmUp then NormalMonitoring accept WarmupComplete;
      transition NormalMonitoring then AlarmActive accept GasAboveAlarmThreshold;
      transition AlarmActive then NormalMonitoring accept GasBelowResetThreshold;
      transition NormalMonitoring then Calibration accept CalibrationRequested;
      transition Calibration then WarmUp accept CalibrationComplete;
      transition WarmUp then Fault accept HeaterOpenCircuit;
      transition NormalMonitoring then Fault accept SensorFaultDetected;
      transition AlarmActive then Fault accept SensorFaultDetected;
      transition Fault then WarmUp accept FaultCleared;
      transition WarmUp then Off accept PowerRemoved;
      transition NormalMonitoring then Off accept PowerRemoved;
      transition AlarmActive then Off accept PowerRemoved;
      transition Fault then Off accept PowerRemoved;
    }
  }

  part def PellistorSensingHead {
    port chamber : GasPort;

    part activeBead : CatalyticPellistorBead;
    part referenceBead : CompensatingPellistorBead;
    part sinteredFlameArrestor : FlameArrestor;
    part gasDiffusionPath : DiffusionPath;

    attribute beadOperatingTemperature : Temperature = 500;
    attribute nominalFlowRate : FlowRate_L_per_minute = 0.5;

    connect chamber.gas to gasDiffusionPath.incomingGas;
    connect gasDiffusionPath.filteredGas to activeBead.localGas;
    connect gasDiffusionPath.filteredGas to referenceBead.localGas;
  }

  part def CatalyticPellistorBead {
    port localGas : GasPort;

    attribute resistance : Resistance = 2.0;
    attribute heaterPower : Power = 0.75;
    attribute beadTemperature : Temperature = 500;
    attribute catalystMaterial : String = "platinum palladium catalyst on porous ceramic bead";
    attribute combustionHeatRise : Temperature;

    action catalyzeCombustibleGas {
      in sample : GasMixture;
      out heatRise : Temperature;
      out resistanceChange : Resistance;
    }

    state machine beadThermalState {
      state Cold;
      state Heating;
      state CatalyticOxidation;
      state Poisoned;
      state OverTemperature;

      transition initial then Cold;
      transition Cold then Heating accept HeaterCurrentApplied;
      transition Heating then CatalyticOxidation accept OperatingTemperatureReached;
      transition CatalyticOxidation then OverTemperature accept ExcessiveGasConcentration;
      transition CatalyticOxidation then Poisoned accept CatalystPoisonDetected;
      transition OverTemperature then Heating accept GasCleared;
      transition Poisoned then Cold accept MaintenanceRequired;
    }
  }

  part def CompensatingPellistorBead {
    port localGas : GasPort;

    attribute resistance : Resistance = 2.0;
    attribute heaterPower : Power = 0.75;
    attribute beadTemperature : Temperature = 500;
    attribute surfaceTreatment : String = "inert glass coating preventing catalytic combustion";

    action compensateAmbientEffects {
      in sample : GasMixture;
      out ambientResistanceChange : Resistance;
    }
  }

  part def WheatstoneBridge {
    in attribute excitationVoltage : Voltage = 2.5;
    in attribute excitationCurrent : Current;
    in attribute activeArmResistance : Resistance;
    in attribute referenceArmResistance : Resistance;

    attribute fixedArmAResistance : Resistance = 2.0;
    attribute fixedArmBResistance : Resistance = 2.0;

    out item bridgeSignal : BridgeSignal;

    action convertResistanceImbalance {
      in activeResistance : Resistance;
      in referenceResistance : Resistance;
      out differentialVoltage : Voltage;
    }
  }

  part def AnalogFrontEnd {
    in item rawBridgeSignal : BridgeSignal;
    out item conditionedSignal : BridgeSignal;

    part instrumentationAmplifier : InstrumentationAmplifier;
    part lowPassFilter : LowPassFilter;
    part analogToDigitalConverter : AnalogToDigitalConverter;

    attribute gain : Real = 128.0;
    attribute cutoffFrequencyHz : Real = 5.0;
    attribute adcResolutionBits : Integer = 16;

    connect rawBridgeSignal to instrumentationAmplifier.inputSignal;
    connect instrumentationAmplifier.amplifiedSignal to lowPassFilter.inputSignal;
    connect lowPassFilter.filteredSignal to analogToDigitalConverter.inputSignal;
    connect analogToDigitalConverter.sampledSignal to conditionedSignal;
  }

  part def InstrumentationAmplifier {
    in item inputSignal : BridgeSignal;
    out item amplifiedSignal : BridgeSignal;
    attribute gain : Real = 128.0;
    attribute inputOffsetVoltage : Voltage = 0.000005;
  }

  part def LowPassFilter {
    in item inputSignal : BridgeSignal;
    out item filteredSignal : BridgeSignal;
    attribute cutoffFrequencyHz : Real = 5.0;
    attribute order : Integer = 2;
  }

  part def AnalogToDigitalConverter {
    in item inputSignal : BridgeSignal;
    out item sampledSignal : BridgeSignal;
    attribute resolutionBits : Integer = 16;
    attribute samplingPeriod : Time = 0.1;
  }

  part def MeasurementController {
    in item measuredSignal : BridgeSignal;
    out item gasReading : GasReading;

    attribute zeroOffset : Voltage = 0.0;
    attribute spanSensitivity : Voltage = 0.00002;
    attribute methaneLELppm : Concentration_ppm = 50000;
    attribute alarmThreshold : PercentLEL = 20;
    attribute resetThreshold : PercentLEL = 18;
    attribute faultLowBridgeCurrent : Current = 0.05;
    attribute faultHighBridgeCurrent : Current = 0.60;

    action initializeSensor {
      out ready : Boolean;
    }

    action performZeroBalance {
      in cleanAirSignal : BridgeSignal;
      out zeroOffset : Voltage;
    }

    action estimateConcentration {
      in conditionedSignal : BridgeSignal;
      in zeroOffset : Voltage;
      in spanSensitivity : Voltage;
      out reading : GasReading;
    }

    action diagnoseSensor {
      in signal : BridgeSignal;
      out valid : Boolean;
      out diagnosticCode : String;
    }

    state machine measurementState {
      state Initializing;
      state ZeroBalancing;
      state Measuring;
      state FaultLatched;

      transition initial then Initializing;
      transition Initializing then ZeroBalancing accept ElectronicsReady;
      transition ZeroBalancing then Measuring accept ZeroStable;
      transition Measuring then FaultLatched accept InvalidBridgeCurrent;
      transition Measuring then ZeroBalancing accept ManualZeroRequested;
      transition FaultLatched then Initializing accept ResetRequested;
    }
  }

  part def AlarmManager {
    in item inputReading : GasReading;
    out item alarmCommand : AlarmCommand;

    attribute warningThreshold : PercentLEL = 10;
    attribute alarmThreshold : PercentLEL = 20;
    attribute highAlarmThreshold : PercentLEL = 40;
    attribute hysteresis : PercentLEL = 2;
    attribute alarmLatched : Boolean = true;

    action evaluateAlarmState {
      in reading : GasReading;
      out command : AlarmCommand;
    }

    state machine alarmState {
      state Clear;
      state Warning;
      state Alarm;
      state HighAlarm;
      state SuppressedFault;

      transition initial then Clear;
      transition Clear then Warning accept ReadingAtOrAboveWarning;
      transition Warning then Alarm accept ReadingAtOrAboveAlarm;
      transition Alarm then HighAlarm accept ReadingAtOrAboveHighAlarm;
      transition HighAlarm then Alarm accept ReadingBelowHighAlarmReset;
      transition Alarm then Warning accept ReadingBelowAlarmReset;
      transition Warning then Clear accept ReadingBelowWarningReset;
      transition Clear then SuppressedFault accept InvalidReading;
      transition Warning then SuppressedFault accept InvalidReading;
      transition Alarm then SuppressedFault accept InvalidReading;
      transition HighAlarm then SuppressedFault accept InvalidReading;
      transition SuppressedFault then Clear accept ValidReadingRestored;
    }
  }

  part def FlameproofEnclosure {
    part body : MetalHousing;
    part opticalIndicatorWindow : IndicatorWindow;
    part cableGland : CableGland;

    attribute ingressProtectionRating : String = "IP66";
    attribute explosionProtectionConcept : String = "flameproof enclosure with sintered gas entry";
    attribute operatingTemperatureMin : Temperature = -40;
    attribute operatingTemperatureMax : Temperature = 75;
  }

  part def FlameArrestor {
    attribute material : String = "sintered stainless steel";
    attribute poreSizeMicrometer : Real = 40.0;
    attribute maximumSurfaceTemperature : Temperature = 85;
  }

  part def DiffusionPath {
    in item incomingGas : GasMixture;
    out item filteredGas : GasMixture;
    attribute responseTimeT90 : Time = 10.0;
  }

  part def MetalHousing {
    attribute material : String = "316 stainless steel";
    attribute wallThicknessMillimeter : Real = 3.0;
  }

  part def IndicatorWindow {
    attribute material : String = "tempered borosilicate glass";
  }

  part def CableGland {
    attribute cableDiameterMillimeter : Real = 8.0;
    attribute sealingMaterial : String = "fluoroelastomer";
  }

  requirement def PrimaryFunctionRequirement {
    subject detector : PellistorGasDetector;

    require constraint {
      detector.primaryFunction == "Detect combustible gas by measuring heat released from catalytic oxidation on a heated pellistor bead and converting the resulting Wheatstone bridge imbalance into a gas concentration and alarm decision."
    }
  }

  requirement def GasDetectionRangeRequirement {
    subject controller : MeasurementController;

    require constraint {
      controller.methaneLELppm == 50000
    }
  }

  requirement def AlarmThresholdRequirement {
    subject manager : AlarmManager;

    require constraint {
      manager.alarmThreshold <= 20
    }
  }

  requirement def WarmPellistorRequirement {
    subject bead : CatalyticPellistorBead;

    require constraint {
      bead.beadTemperature >= 450 and bead.beadTemperature <= 550
    }
  }

  requirement def ReferenceCompensationRequirement {
    subject sensingHead : PellistorSensingHead;

    require constraint {
      sensingHead.referenceBead.surfaceTreatment == "inert glass coating preventing catalytic combustion"
    }
  }

  requirement def FlameSafetyRequirement {
    subject enclosure : FlameproofEnclosure;

    require constraint {
      enclosure.explosionProtectionConcept == "flameproof enclosure with sintered gas entry"
    }
  }

  requirement def ValidReadingRequirement {
    subject reading : GasReading;

    require constraint {
      reading.percentLowerExplosiveLimit >= 0 and reading.percentLowerExplosiveLimit <= 100
    }
  }

  part pellistorBasedDetector : PellistorGasDetector;

}