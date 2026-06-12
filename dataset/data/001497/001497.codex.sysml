package MetamaterialCloakingSystem {

  import ScalarValues::*;
  import ISQ::*;

  value def Hertz :> frequencyUnit;
  value def Meter :> lengthUnit;
  value def WattPerSquareMeter;
  value def Decibel;
  value def Celsius :> temperatureUnit;
  value def Volt :> electricPotentialUnit;
  value def Ampere :> electricCurrentUnit;
  value def Percent;

  value def Frequency {
    unit : Hertz;
  }

  value def Wavelength {
    unit : Meter;
  }

  value def PowerDensity {
    unit : WattPerSquareMeter;
  }

  value def Attenuation {
    unit : Decibel;
  }

  value def Temperature {
    unit : Celsius;
  }

  value def Voltage {
    unit : Volt;
  }

  value def Current {
    unit : Ampere;
  }

  value def Efficiency {
    unit : Percent;
  }

  item def IncidentElectromagneticWave {
    attribute frequency : Frequency;
    attribute wavelength : Wavelength;
    attribute powerDensity : PowerDensity;
    attribute polarizationAngle : Real;
    attribute incidenceAngle : Real;
  }

  item def GuidedElectromagneticWave {
    attribute phaseDelay : Real;
    attribute localImpedance : Real;
    attribute powerDensity : PowerDensity;
    attribute scatteringLoss : Attenuation;
  }

  item def ReconstructedElectromagneticWave {
    attribute wavefrontError : Real;
    attribute insertionLoss : Attenuation;
    attribute phaseContinuity : Efficiency;
  }

  item def ThermalLoad {
    attribute temperature : Temperature;
    attribute heatFlux : Real;
  }

  item def ControlCommand {
    attribute targetFrequency : Frequency;
    attribute steeringAngle : Real;
    attribute cloakEnabled : Boolean;
  }

  port def WaveInputPort {
    in item incidentWave : IncidentElectromagneticWave;
  }

  port def WaveGuidancePort {
    in item guidedIn : GuidedElectromagneticWave;
    out item guidedOut : GuidedElectromagneticWave;
  }

  port def WaveOutputPort {
    out item reconstructedWave : ReconstructedElectromagneticWave;
  }

  port def PowerPort {
    in attribute supplyVoltage : Voltage;
    in attribute supplyCurrent : Current;
  }

  port def ThermalPort {
    out item heat : ThermalLoad;
  }

  port def ControlPort {
    in item command : ControlCommand;
    out attribute healthStatus : String;
  }

  part def GradientIndexMetamaterialLayer {
    attribute relativePermittivity : Real;
    attribute relativePermeability : Real;
    attribute refractiveIndexGradient : Real;
    attribute unitCellPitch : Wavelength;
    attribute operatingBandwidth : Frequency;

    port input : WaveGuidancePort;
    port output : WaveGuidancePort;

    action transformWave {
      in item incoming : GuidedElectromagneticWave;
      out item outgoing : GuidedElectromagneticWave;

      first start;
      then calculateLocalIndex;
      then imposePhaseDelay;
      then matchImpedance;
      then emitGuidedWave;
    }
  }

  part def SplitRingResonatorArray {
    attribute resonatorCount : Integer;
    attribute resonanceFrequency : Frequency;
    attribute qualityFactor : Real;
    attribute tunableCapacitance : Real;

    port wavePort : WaveGuidancePort;
    port power : PowerPort;

    action tuneResonance {
      in item command : ControlCommand;
      out attribute tunedFrequency : Frequency;

      first receiveCommand;
      then adjustCapacitance;
      then verifyResonance;
    }
  }

  part def CloakShell {
    attribute shellInnerRadius : Wavelength;
    attribute shellOuterRadius : Wavelength;
    attribute targetScatteringReduction : Attenuation;
    attribute angularCoverage : Real;

    port exteriorInput : WaveInputPort;
    port exteriorOutput : WaveOutputPort;
    port thermal : ThermalPort;

    part outerLayer : GradientIndexMetamaterialLayer;
    part middleLayer : GradientIndexMetamaterialLayer;
    part innerLayer : GradientIndexMetamaterialLayer;
    part resonators : SplitRingResonatorArray;

    connection exteriorInputToOuter connect exteriorInput.incidentWave to outerLayer.input.guidedIn;
    connection outerToMiddle connect outerLayer.output.guidedOut to middleLayer.input.guidedIn;
    connection middleToInner connect middleLayer.output.guidedOut to innerLayer.input.guidedIn;
    connection innerToResonators connect innerLayer.output.guidedOut to resonators.wavePort.guidedIn;
    connection resonatorsToOutput connect resonators.wavePort.guidedOut to exteriorOutput.reconstructedWave;
  }

  part def HiddenPayloadVolume {
    attribute maximumPayloadDiameter : Wavelength;
    attribute electromagneticIsolation : Attenuation;
    attribute payloadTemperatureLimit : Temperature;

    port thermal : ThermalPort;
  }

  part def WavefrontSensor {
    attribute phaseResolution : Real;
    attribute samplingRate : Frequency;
    attribute detectionThreshold : PowerDensity;

    port sensingInput : WaveInputPort;
    port control : ControlPort;

    action estimateIncidentField {
      in item wave : IncidentElectromagneticWave;
      out item command : ControlCommand;

      first sampleWavefront;
      then estimateFrequency;
      then estimateIncidenceAngle;
      then generateRetuningCommand;
    }
  }

  part def AdaptiveController {
    attribute controlLoopRate : Frequency;
    attribute phaseErrorLimit : Real;
    attribute scatteringSetpoint : Attenuation;

    port sensorBus : ControlPort;
    port resonatorBus : ControlPort;
    port power : PowerPort;

    state def ControllerState {
      entry action initializeController;

      state Off;
      state Standby;
      state Calibrating;
      state Cloaking;
      state Fault;

      transition Off_to_Standby
        first Off
        accept enable
        then Standby;

      transition Standby_to_Calibrating
        first Standby
        accept calibrationRequested
        then Calibrating;

      transition Calibrating_to_Cloaking
        first Calibrating
        accept calibrationComplete
        then Cloaking;

      transition Cloaking_to_Calibrating
        first Cloaking
        accept wavefrontErrorHigh
        then Calibrating;

      transition Any_to_Fault
        first Off
        accept faultDetected
        then Fault;

      transition Fault_to_Standby
        first Fault
        accept faultCleared
        then Standby;
    }

    action computeMetamaterialTuning {
      in item sensedCommand : ControlCommand;
      out item tuningCommand : ControlCommand;

      first validateCommand;
      then computeGradientIndexProfile;
      then computeResonatorBias;
      then publishTuningCommand;
    }
  }

  part def PowerConditioningUnit {
    attribute inputVoltage : Voltage;
    attribute regulatedVoltage : Voltage;
    attribute maximumCurrent : Current;
    attribute conversionEfficiency : Efficiency;

    port inputPower : PowerPort;
    port cloakPower : PowerPort;
    port controllerPower : PowerPort;
  }

  part def ThermalManagementAssembly {
    attribute heatRejectionCapacity : Real;
    attribute maximumShellTemperature : Temperature;
    attribute thermalControlEfficiency : Efficiency;

    port shellThermalInput : ThermalPort;
    port payloadThermalInput : ThermalPort;
  }

  part def MetamaterialCloakingDevice {
    attribute nominalCenterFrequency : Frequency = 10.0 [Hertz];
    attribute minimumScatteringReduction : Attenuation = 20.0 [Decibel];
    attribute operationalTemperatureMin : Temperature = -20.0 [Celsius];
    attribute operationalTemperatureMax : Temperature = 70.0 [Celsius];

    port incidentWavePort : WaveInputPort;
    port exitWavePort : WaveOutputPort;
    port commandPort : ControlPort;
    port electricalPower : PowerPort;

    part cloakShell : CloakShell;
    part hiddenVolume : HiddenPayloadVolume;
    part wavefrontSensor : WavefrontSensor;
    part adaptiveController : AdaptiveController;
    part powerConditioning : PowerConditioningUnit;
    part thermalManagement : ThermalManagementAssembly;

    connection incidentToSensor connect incidentWavePort.incidentWave to wavefrontSensor.sensingInput.incidentWave;
    connection incidentToShell connect incidentWavePort.incidentWave to cloakShell.exteriorInput.incidentWave;
    connection shellToExit connect cloakShell.exteriorOutput.reconstructedWave to exitWavePort.reconstructedWave;
    connection sensorToController connect wavefrontSensor.control.command to adaptiveController.sensorBus.command;
    connection controllerToCommandPort connect adaptiveController.sensorBus.healthStatus to commandPort.healthStatus;
    connection externalPowerToConditioner connect electricalPower.supplyVoltage to powerConditioning.inputPower.supplyVoltage;
    connection conditionerToController connect powerConditioning.controllerPower.supplyVoltage to adaptiveController.power.supplyVoltage;
    connection conditionerToResonators connect powerConditioning.cloakPower.supplyVoltage to cloakShell.resonators.power.supplyVoltage;
    connection shellThermalToManagement connect cloakShell.thermal.heat to thermalManagement.shellThermalInput.heat;
    connection payloadThermalToManagement connect hiddenVolume.thermal.heat to thermalManagement.payloadThermalInput.heat;

    action cloakIncidentWave {
      in item incident : IncidentElectromagneticWave;
      out item reconstructed : ReconstructedElectromagneticWave;

      first senseIncomingWave;
      then computeAdaptiveMaterialProfile;
      then routeWaveAroundHiddenVolume;
      then suppressBackscatter;
      then reconstructOutgoingWavefront;
    }

    state def CloakOperationalState {
      state Deenergized;
      state Powered;
      state AdaptiveTuning;
      state CloakActive;
      state ThermalLimit;
      state MaintenanceRequired;

      transition powerOn
        first Deenergized
        accept electricalPowerAvailable
        then Powered;

      transition beginTuning
        first Powered
        accept validIncidentWaveDetected
        then AdaptiveTuning;

      transition activateCloak
        first AdaptiveTuning
        accept tuningStable
        then CloakActive;

      transition retune
        first CloakActive
        accept frequencyShiftDetected
        then AdaptiveTuning;

      transition thermalLimitReached
        first CloakActive
        accept shellTemperatureHigh
        then ThermalLimit;

      transition cooled
        first ThermalLimit
        accept shellTemperatureNormal
        then AdaptiveTuning;

      transition maintenance
        first Powered
        accept diagnosticFailure
        then MaintenanceRequired;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /* The system shall reduce electromagnetic observability of a protected payload by guiding incident electromagnetic waves around the payload volume and reconstructing the outgoing wavefront so that scattering, shadowing, and phase disturbance are minimized at the specified operating frequency band. */

    subject device : MetamaterialCloakingDevice;

    require constraint {
      device.minimumScatteringReduction >= 20.0 [Decibel]
    }
  }

  requirement def WavefrontContinuityRequirement {
    subject device : MetamaterialCloakingDevice;

    require constraint {
      device.cloakShell.targetScatteringReduction >= device.minimumScatteringReduction
    }
  }

  requirement def PayloadIsolationRequirement {
    subject device : MetamaterialCloakingDevice;

    require constraint {
      device.hiddenVolume.electromagneticIsolation >= 30.0 [Decibel]
    }
  }

  requirement def ThermalOperationRequirement {
    subject device : MetamaterialCloakingDevice;

    require constraint {
      device.operationalTemperatureMin <= 0.0 [Celsius] and
      device.operationalTemperatureMax >= 50.0 [Celsius]
    }
  }

  requirement def AdaptiveRetuningRequirement {
    subject device : MetamaterialCloakingDevice;

    require constraint {
      device.adaptiveController.controlLoopRate >= 1000.0 [Hertz]
    }
  }

  part metamaterialCloakingSystem : MetamaterialCloakingDevice {
    attribute nominalCenterFrequency = 10.0 [Hertz];
    attribute minimumScatteringReduction = 25.0 [Decibel];

    part cloakShell {
      attribute shellInnerRadius = 0.50 [Meter];
      attribute shellOuterRadius = 0.75 [Meter];
      attribute targetScatteringReduction = 25.0 [Decibel];
      attribute angularCoverage = 360.0;

      part outerLayer {
        attribute relativePermittivity = 2.4;
        attribute relativePermeability = 1.8;
        attribute refractiveIndexGradient = 0.35;
      }

      part middleLayer {
        attribute relativePermittivity = 1.7;
        attribute relativePermeability = 1.3;
        attribute refractiveIndexGradient = 0.22;
      }

      part innerLayer {
        attribute relativePermittivity = 1.1;
        attribute relativePermeability = 0.9;
        attribute refractiveIndexGradient = 0.14;
      }

      part resonators {
        attribute resonatorCount = 4096;
        attribute resonanceFrequency = 10.0 [Hertz];
        attribute qualityFactor = 120.0;
      }
    }

    part hiddenVolume {
      attribute maximumPayloadDiameter = 0.90 [Meter];
      attribute electromagneticIsolation = 35.0 [Decibel];
      attribute payloadTemperatureLimit = 60.0 [Celsius];
    }

    part adaptiveController {
      attribute controlLoopRate = 5000.0 [Hertz];
      attribute phaseErrorLimit = 0.05;
      attribute scatteringSetpoint = 25.0 [Decibel];
    }

    part powerConditioning {
      attribute inputVoltage = 28.0 [Volt];
      attribute regulatedVoltage = 12.0 [Volt];
      attribute maximumCurrent = 8.0 [Ampere];
      attribute conversionEfficiency = 92.0 [Percent];
    }
  }

}