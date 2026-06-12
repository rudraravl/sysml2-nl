package FluorescentChlorideSensorSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def ChlorideConcentration :> ISQ::amountOfSubstanceConcentration {
    :>> unit = SI::molePerCubicMetre;
  }

  attribute def FluorescenceIntensity {
    attribute value : Real;
    attribute unitSymbol : String = "counts/s";
  }

  attribute def ExcitationWavelength :> ISQ::length {
    :>> unit = SI::nanometre;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    :>> unit = SI::kelvin;
  }

  attribute def Voltage :> ISQ::electricPotential {
    :>> unit = SI::volt;
  }

  attribute def Current :> ISQ::electricCurrent {
    :>> unit = SI::milliampere;
  }

  attribute def TimeDuration :> ISQ::time {
    :>> unit = SI::second;
  }

  item def BiologicalSample {
    attribute chlorideLevel : ChlorideConcentration;
    attribute sampleTemperature : Temperature;
    attribute volume_uL : Real;
  }

  item def ExcitationLight {
    attribute wavelength : ExcitationWavelength;
    attribute opticalPower_mW : Real;
  }

  item def EmissionLight {
    attribute peakWavelength : ExcitationWavelength;
    attribute intensity : FluorescenceIntensity;
  }

  item def ChlorideReading {
    attribute chlorideConcentration : ChlorideConcentration;
    attribute confidence : Real;
    attribute timestamp_s : Real;
  }

  item def SensorCommand {
    attribute requestedMode : String;
    attribute integrationTime : TimeDuration;
  }

  port def SamplePort {
    in item sample : BiologicalSample;
  }

  port def OpticalExcitationPort {
    out item excitation : ExcitationLight;
  }

  port def OpticalEmissionPort {
    in item emission : EmissionLight;
  }

  port def ReadingPort {
    out item reading : ChlorideReading;
  }

  port def CommandPort {
    in item command : SensorCommand;
  }

  port def ElectricalPowerPort {
    in attribute supplyVoltage : Voltage;
    in attribute supplyCurrent : Current;
  }

  action def AcquireFluorescence {
    in item sample : BiologicalSample;
    in item excitation : ExcitationLight;
    out item emission : EmissionLight;
  }

  action def ConvertFluorescenceToChloride {
    in item emission : EmissionLight;
    in attribute temperature : Temperature;
    out item reading : ChlorideReading;
  }

  action def RunCalibration {
    in attribute blankIntensity : Real;
    in attribute standardLow_mol_per_m3 : Real;
    in attribute standardHigh_mol_per_m3 : Real;
    out attribute calibrationSlope : Real;
    out attribute calibrationOffset : Real;
  }

  action def PublishReading {
    in item reading : ChlorideReading;
  }

  part def FluorescentChlorideSensor {
    port sampleIn : SamplePort;
    port commandIn : CommandPort;
    port readingOut : ReadingPort;
    port powerIn : ElectricalPowerPort;

    part opticalModule : OpticalModule;
    part sensingElement : ChlorideSensitiveFluorophoreLayer;
    part detectorModule : PhotodetectorModule;
    part processor : SignalProcessor;
    part housing : SensorHousing;

    attribute measurementRangeMin : ChlorideConcentration = 0.1 [SI::molePerCubicMetre];
    attribute measurementRangeMax : ChlorideConcentration = 200.0 [SI::molePerCubicMetre];
    attribute responseTime : TimeDuration = 5.0 [SI::second];
    attribute excitationWavelength : ExcitationWavelength = 470.0 [SI::nanometre];
    attribute emissionPeakWavelength : ExcitationWavelength = 520.0 [SI::nanometre];
    attribute operatingTemperatureMin : Temperature = 278.15 [SI::kelvin];
    attribute operatingTemperatureMax : Temperature = 318.15 [SI::kelvin];

    connect sampleIn.sample to sensingElement.sampleInterface.sample;
    connect opticalModule.excitationOut.excitation to sensingElement.excitationIn.excitation;
    connect sensingElement.emissionOut.emission to detectorModule.emissionIn.emission;
    connect detectorModule.signalOut.emission to processor.fluorescenceIn.emission;
    connect commandIn.command to processor.commandIn.command;
    connect processor.readingOut.reading to readingOut.reading;

    perform action measureChloride {
      first start;
      then illuminateSample;
      then collectEmission;
      then calculateChloride;
      then outputReading;
      then done;

      action start;
      action illuminateSample : AcquireFluorescence {
        in sample = sampleIn.sample;
        in excitation = opticalModule.excitationOut.excitation;
      }
      action collectEmission;
      action calculateChloride : ConvertFluorescenceToChloride {
        in emission = detectorModule.signalOut.emission;
        in temperature = sensingElement.localTemperature;
      }
      action outputReading : PublishReading {
        in reading = processor.readingOut.reading;
      }
      action done;
    }

    state def SensorOperatingState {
      state off;
      state initializing;
      state idle;
      state measuring;
      state calibrating;
      state fault;

      entry; then off;

      transition powerApplied
        first off
        then initializing;

      transition initializationComplete
        first initializing
        then idle;

      transition measurementCommanded
        first idle
        then measuring;

      transition measurementComplete
        first measuring
        then idle;

      transition calibrationCommanded
        first idle
        then calibrating;

      transition calibrationComplete
        first calibrating
        then idle;

      transition diagnosticFailure
        first initializing
        then fault;

      transition opticalSignalLost
        first measuring
        then fault;

      transition resetCommanded
        first fault
        then initializing;
    }
  }

  part def OpticalModule {
    port excitationOut : OpticalExcitationPort;
    port powerIn : ElectricalPowerPort;

    part led : BlueLED;
    part driveCircuit : LEDDriver;

    attribute nominalWavelength : ExcitationWavelength = 470.0 [SI::nanometre];
    attribute nominalOpticalPower_mW : Real = 2.5;
    attribute modulationFrequency_Hz : Real = 250.0;

    connect driveCircuit.outputCurrent to led.inputCurrent;
    connect led.generatedLight to excitationOut.excitation;
  }

  part def BlueLED {
    out item generatedLight : ExcitationLight;
    in attribute inputCurrent : Current;

    attribute centerWavelength : ExcitationWavelength = 470.0 [SI::nanometre];
    attribute spectralWidth_nm : Real = 25.0;
    attribute maximumCurrent : Current = 20.0 [SI::milliampere];
  }

  part def LEDDriver {
    in attribute supplyVoltage : Voltage;
    out attribute outputCurrent : Current;

    attribute currentSetpoint : Current = 10.0 [SI::milliampere];
    attribute currentStability_percent : Real = 1.0;
  }

  part def ChlorideSensitiveFluorophoreLayer {
    port sampleInterface : SamplePort;
    port excitationIn : OpticalExcitationPort;
    port emissionOut : OpticalEmissionPort;

    attribute localTemperature : Temperature = 298.15 [SI::kelvin];
    attribute SternVolmerConstant_m3_per_mol : Real = 0.018;
    attribute baselineIntensity_counts_per_s : Real = 100000.0;
    attribute photobleachRate_per_hour : Real = 0.02;
    attribute membraneThickness_um : Real = 15.0;

    perform action fluorescenceResponse : AcquireFluorescence {
      in sample = sampleInterface.sample;
      in excitation = excitationIn.excitation;
      out emission = emissionOut.emission;
    }
  }

  part def PhotodetectorModule {
    port emissionIn : OpticalEmissionPort;
    port signalOut : OpticalEmissionPort;
    port powerIn : ElectricalPowerPort;

    part opticalFilter : EmissionFilter;
    part photodiode : Photodiode;
    part amplifier : TransimpedanceAmplifier;

    attribute darkCurrent : Current = 2.0 [SI::nanoampere];
    attribute integrationTime : TimeDuration = 0.25 [SI::second];

    connect emissionIn.emission to opticalFilter.rawEmission;
    connect opticalFilter.filteredEmission to photodiode.receivedEmission;
    connect photodiode.photocurrent to amplifier.inputCurrent;
    connect amplifier.digitizedEmission to signalOut.emission;
  }

  part def EmissionFilter {
    in item rawEmission : EmissionLight;
    out item filteredEmission : EmissionLight;

    attribute passbandCenter : ExcitationWavelength = 520.0 [SI::nanometre];
    attribute passbandWidth_nm : Real = 40.0;
    attribute excitationRejectionRatio : Real = 100000.0;
  }

  part def Photodiode {
    in item receivedEmission : EmissionLight;
    out attribute photocurrent : Current;

    attribute responsivity_A_per_W : Real = 0.31;
    attribute activeArea_mm2 : Real = 7.0;
  }

  part def TransimpedanceAmplifier {
    in attribute inputCurrent : Current;
    out item digitizedEmission : EmissionLight;

    attribute gain_ohm : Real = 1000000.0;
    attribute adcResolution_bits : Integer = 16;
    attribute noise_counts_rms : Real = 12.0;
  }

  part def SignalProcessor {
    port fluorescenceIn : OpticalEmissionPort;
    port commandIn : CommandPort;
    port readingOut : ReadingPort;

    attribute calibrationSlope : Real = -0.018;
    attribute calibrationOffset : Real = 1.0;
    attribute temperatureCompensationCoefficient_per_K : Real = 0.012;
    attribute lastMeasuredIntensity_counts_per_s : Real;
    attribute lastChlorideConcentration : ChlorideConcentration;

    perform action convertSignal : ConvertFluorescenceToChloride {
      in emission = fluorescenceIn.emission;
      out reading = readingOut.reading;
    }

    perform action calibrate : RunCalibration {
      in blankIntensity = 100000.0;
      in standardLow_mol_per_m3 = 10.0;
      in standardHigh_mol_per_m3 = 100.0;
      out calibrationSlope = calibrationSlope;
      out calibrationOffset = calibrationOffset;
    }
  }

  part def SensorHousing {
    attribute material : String = "black anodized aluminum";
    attribute ingressProtection : String = "IP54";
    attribute opticalPathLength_mm : Real = 8.0;
    attribute sampleWellVolume_uL : Real = 100.0;
  }

  part fluorescentChlorideSensorSystem {
    part sensor : FluorescentChlorideSensor;
    part hostController : HostController;
    part sampleSource : SampleSource;
    part powerSupply : RegulatedPowerSupply;

    connect sampleSource.sampleOut.sample to sensor.sampleIn.sample;
    connect hostController.commandOut.command to sensor.commandIn.command;
    connect sensor.readingOut.reading to hostController.readingIn.reading;
    connect powerSupply.powerOut.supplyVoltage to sensor.powerIn.supplyVoltage;
    connect powerSupply.powerOut.supplyCurrent to sensor.powerIn.supplyCurrent;
  }

  part def HostController {
    port commandOut : CommandPort;
    port readingIn : ReadingPort;

    attribute displayRefreshRate_Hz : Real = 2.0;
    attribute dataLoggingEnabled : Boolean = true;
  }

  part def SampleSource {
    port sampleOut : SamplePort;

    attribute nominalChlorideConcentration : ChlorideConcentration = 100.0 [SI::molePerCubicMetre];
    attribute nominalTemperature : Temperature = 298.15 [SI::kelvin];
  }

  part def RegulatedPowerSupply {
    port powerOut : ElectricalPowerPort;

    attribute outputVoltage : Voltage = 5.0 [SI::volt];
    attribute maximumOutputCurrent : Current = 500.0 [SI::milliampere];
    attribute ripple_mV : Real = 5.0;
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /* The system shall determine chloride ion concentration in a sample by exciting a chloride-sensitive fluorescent layer, measuring chloride-dependent fluorescence emission, converting the optical response into a compensated chloride reading, and reporting the result to a host controller. */

    subject sensor : FluorescentChlorideSensor;

    require constraint {
      sensor.measurementRangeMin <= 0.1 [SI::molePerCubicMetre] and
      sensor.measurementRangeMax >= 200.0 [SI::molePerCubicMetre]
    }
  }

  requirement def ResponseTimeRequirement {
    subject sensor : FluorescentChlorideSensor;

    require constraint {
      sensor.responseTime <= 5.0 [SI::second]
    }
  }

  requirement def OpticalExcitationRequirement {
    subject sensor : FluorescentChlorideSensor;

    require constraint {
      sensor.excitationWavelength >= 450.0 [SI::nanometre] and
      sensor.excitationWavelength <= 490.0 [SI::nanometre]
    }
  }

  requirement def EmissionDetectionRequirement {
    subject sensor : FluorescentChlorideSensor;

    require constraint {
      sensor.emissionPeakWavelength >= 500.0 [SI::nanometre] and
      sensor.emissionPeakWavelength <= 550.0 [SI::nanometre]
    }
  }

  requirement def OperatingTemperatureRequirement {
    subject sensor : FluorescentChlorideSensor;

    require constraint {
      sensor.operatingTemperatureMin <= 278.15 [SI::kelvin] and
      sensor.operatingTemperatureMax >= 318.15 [SI::kelvin]
    }
  }

  satisfy PrimaryFunctionRequirement by fluorescentChlorideSensorSystem.sensor;
  satisfy ResponseTimeRequirement by fluorescentChlorideSensorSystem.sensor;
  satisfy OpticalExcitationRequirement by fluorescentChlorideSensorSystem.sensor;
  satisfy EmissionDetectionRequirement by fluorescentChlorideSensorSystem.sensor;
  satisfy OperatingTemperatureRequirement by fluorescentChlorideSensorSystem.sensor;

}