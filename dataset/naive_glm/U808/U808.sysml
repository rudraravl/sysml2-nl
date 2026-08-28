package PhotodetectorSystem {

  import ScalarValues::*;
  import Systems::Unit;

  package Units {
    import ScalarValues::*;
    import Systems::Unit;

    attribute volt : Unit;
    attribute ampere : Unit;
    attribute watt : Unit;
    attribute hertz : Unit;
    attribute ohm : Unit;
    attribute nanometer : Unit;
    attribute second : Unit;
    attribute squareMillimeter : Unit;

    value type Voltage :> Real { unit volt; }
    value type Current :> Real { unit ampere; }
    value type Power :> Real { unit watt; }
    value type Frequency :> Real { unit hertz; }
    value type Resistance :> Real { unit ohm; }
    value type Wavelength :> Real { unit nanometer; }
    value type TimeValue :> Real { unit second; }
    value type Area :> Real { unit squareMillimeter; }
  }

  package Items {
    import Units::*;

    item def LightSignal {
      attribute wavelength : Wavelength;
      attribute power : Power;
      attribute incident : Boolean;
    }

    item def Photocurrent {
      attribute magnitude : Current;
      attribute darkCurrent : Current;
      attribute valid : Boolean;
    }

    item def BiasVoltage {
      attribute level : Voltage;
      attribute ripple : Voltage;
      attribute stable : Boolean;
    }

    item def AmplifiedVoltage {
      attribute level : Voltage;
      attribute bandwidth : Frequency;
      attribute valid : Boolean;
    }

    item def ConditionedVoltage {
      attribute level : Voltage;
      attribute noiseFloor : Voltage;
      attribute lowCutoff : Frequency;
      attribute highCutoff : Frequency;
      attribute valid : Boolean;
    }
  }

  package PortDefinitions {
    import Items::*;

    port def OpticalIn {
      in item light : LightSignal;
    }

    port def CurrentOut {
      out item photocurrent : Photocurrent;
    }

    port def CurrentIn {
      in item photocurrent : Photocurrent;
    }

    port def VoltageOut {
      out item voltage : AmplifiedVoltage;
    }

    port def VoltageIn {
      in item voltage : AmplifiedVoltage;
    }

    port def BiasOut {
      out item bias : BiasVoltage;
    }

    port def BiasIn {
      in item bias : BiasVoltage;
    }

    port def SignalOut {
      out item signal : ConditionedVoltage;
    }
  }

  package Components {
    import PortDefinitions::*;
    import Items::*;
    import Units::*;

    part def PhotodetectorElement {
      attribute activeArea : Area;
      attribute responsivity : Real;
      attribute darkCurrent : Current;
      attribute minWavelength : Wavelength;
      attribute maxWavelength : Wavelength;
      attribute saturationPower : Power;

      port biasIn : BiasIn;
      port opticalIn : OpticalIn;
      port currentOut : CurrentOut;

      action def ConvertLightToCurrent {
        in light : LightSignal;
        in bias : BiasVoltage;
        out photocurrent : Photocurrent;
      }

      perform ConvertLightToCurrent;
    }

    part def BiasSupply {
      attribute nominalVoltage : Voltage;
      attribute ripple : Voltage;
      attribute enabled : Boolean;

      port biasOut : BiasOut;

      action def GenerateBias {
        out bias : BiasVoltage;
      }

      perform GenerateBias;
    }

    part def TransimpedanceAmplifier {
      attribute transimpedance : Resistance;
      attribute bandwidth : Frequency;
      attribute inputNoise : Current;

      port currentIn : CurrentIn;
      port voltageOut : VoltageOut;

      action def ConvertCurrentToVoltage {
        in photocurrent : Photocurrent;
        out voltage : AmplifiedVoltage;
      }

      perform ConvertCurrentToVoltage;
    }

    part def SignalConditioner {
      attribute gain : Real;
      attribute lowCutoff : Frequency;
      attribute highCutoff : Frequency;
      attribute outputNoise : Voltage;

      port voltageIn : VoltageIn;
      port signalOut : SignalOut;

      action def FilterAndAmplify {
        in voltage : AmplifiedVoltage;
        out signal : ConditionedVoltage;
      }

      perform FilterAndAmplify;
    }
  }

  package SystemModel {
    import Components::*;
    import PortDefinitions::*;
    import Items::*;
    import Units::*;

    part def PhotodetectorSystem {
      attribute saturationThreshold : Power;
      attribute standbyTimeout : TimeValue;
      attribute lightDetected : Boolean;
      attribute lightPower : Power;
      attribute currentGenerated : Boolean;
      attribute voltageAmplified : Boolean;
      attribute signalConditioned : Boolean;
      attribute isSaturated : Boolean;

      port opticalInput : OpticalIn;
      port electricalOutput : SignalOut;

      part detector : PhotodetectorElement {
        attribute activeArea = 1.0;
        attribute responsivity = 0.8;
        attribute darkCurrent = 5e-10;
        attribute minWavelength = 400;
        attribute maxWavelength = 1100;
        attribute saturationPower = 1e-3;
      }

      part bias : BiasSupply {
        attribute nominalVoltage = 5.0;
        attribute ripple = 5e-4;
        attribute enabled = true;
      }

      part tia : TransimpedanceAmplifier {
        attribute transimpedance = 10000.0;
        attribute bandwidth = 1e7;
        attribute inputNoise = 1e-12;
      }

      part conditioner : SignalConditioner {
        attribute gain = 2.0;
        attribute lowCutoff = 10.0;
        attribute highCutoff = 1e5;
        attribute outputNoise = 1e-5;
      }

      connection biasToDetector connect bias.biasOut to detector.biasIn;
      connection detectorToTIA connect detector.currentOut to tia.currentIn;
      connection tiaToConditioner connect tia.voltageOut to conditioner.voltageIn;
      connection opticalPath connect opticalInput to detector.opticalIn;
      connection outputPath connect conditioner.signalOut to electricalOutput;

      state machine def OperationStates {
        state standby;
        state detecting;
        state amplifying;
        state conditioning;
        state saturated;

        transition standby_to_detecting first standby to detecting if lightDetected;
        transition detecting_to_amplifying detecting to amplifying if currentGenerated;
        transition amplifying_to_conditioning amplifying to conditioning if voltageAmplified;
        transition conditioning_to_standby conditioning to standby if signalConditioned;
        transition standby_to_saturated standby to saturated if lightPower > saturationThreshold;
        transition detecting_to_saturated detecting to saturated if lightPower > saturationThreshold;
        transition amplifying_to_saturated amplifying to saturated if lightPower > saturationThreshold;
        transition conditioning_to_saturated conditioning to saturated if lightPower > saturationThreshold;
        transition saturated_to_detecting saturated to detecting if lightPower <= saturationThreshold and lightDetected;
        transition saturated_to_standby saturated to standby if lightPower <= saturationThreshold and not lightDetected;
      }

      exhibit OperationStates;
    }
  }

  package Requirements {
    import Units::*;
    import SystemModel::*;
    import Components::*;

    requirement def WavelengthRangeRequirement {
      subject detector : PhotodetectorElement;
      attribute minWavelength : Wavelength = 400;
      attribute maxWavelength : Wavelength = 1100;
      require detector.minWavelength <= minWavelength and detector.maxWavelength >= maxWavelength;
    }

    requirement def DarkCurrentRequirement {
      subject detector : PhotodetectorElement;
      attribute maxDarkCurrent : Current = 1e-9;
      require detector.darkCurrent <= maxDarkCurrent;
    }

    requirement def ResponsivityRequirement {
      subject detector : PhotodetectorElement;
      attribute minResponsivity : Real = 0.5;
      require detector.responsivity >= minResponsivity;
    }

    requirement def BiasStabilityRequirement {
      subject bias : BiasSupply;
      attribute maxRipple : Voltage = 1e-3;
      require bias.ripple <= maxRipple;
    }

    requirement def BiasVoltageRequirement {
      subject bias : BiasSupply;
      attribute requiredVoltage : Voltage = 5.0;
      require bias.nominalVoltage == requiredVoltage;
    }

    requirement def TIABandwidthRequirement {
      subject tia : TransimpedanceAmplifier;
      attribute minBandwidth : Frequency = 1e6;
      require tia.bandwidth >= minBandwidth;
    }

    requirement def TIATransimpedanceRequirement {
      subject tia : TransimpedanceAmplifier;
      attribute minTransimpedance : Resistance = 1000.0;
      require tia.transimpedance >= minTransimpedance;
    }

    requirement def SignalConditioningRequirement {
      subject conditioner : SignalConditioner;
      attribute maxLowCutoff : Frequency = 100.0;
      attribute minHighCutoff : Frequency = 1e4;
      require conditioner.lowCutoff <= maxLowCutoff and conditioner.highCutoff >= minHighCutoff;
    }

    requirement def SaturationProtectionRequirement {
      subject pdSystem : PhotodetectorSystem;
      require pdSystem.saturationThreshold > 0;
    }

    requirement def SystemResponseRequirement {
      subject pdSystem : PhotodetectorSystem;
      attribute maxResponseTime : TimeValue = 1e-6;
      require pdSystem.tia.bandwidth >= 1.0 / (2.0 * maxResponseTime);
    }

    requirement def PhotodetectorSystemRequirement {
      subject pdSystem : PhotodetectorSystem;
      require pdSystem.detector.darkCurrent <= 1e-9;
      require pdSystem.detector.responsivity >= 0.5;
      require pdSystem.bias.ripple <= 1e-3;
      require pdSystem.bias.nominalVoltage == 5.0;
      require pdSystem.tia.bandwidth >= 1e6;
      require pdSystem.tia.transimpedance >= 1000.0;
      require pdSystem.conditioner.lowCutoff <= 100.0 and pdSystem.conditioner.highCutoff >= 1e4;
      require pdSystem.saturationThreshold > 0;
    }
  }
}
