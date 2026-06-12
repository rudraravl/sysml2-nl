package FiberBraggGratingSystemSpecification {

  import ScalarValues::*;
  import SI::*;

  attribute def Wavelength :> Real {
    doc /* nanometre */
  }

  attribute def OpticalPower :> Real {
    doc /* decibel-milliwatt */
  }

  attribute def Temperature :> Real {
    doc /* degree Celsius */
  }

  attribute def Strain :> Real {
    doc /* microstrain */
  }

  attribute def Frequency :> Real {
    doc /* hertz */
  }

  attribute def Length :> Real {
    doc /* metre */
  }

  attribute def Time :> Real {
    doc /* second */
  }

  attribute def Ratio :> Real {
    doc /* dimensionless */
  }

  item def OpticalSignal {
    attribute centerWavelength : Wavelength;
    attribute bandwidth : Wavelength;
    attribute power : OpticalPower;
    attribute modulationFrequency : Frequency;
  }

  item def ReflectedSpectrum {
    attribute peakWavelength : Wavelength;
    attribute peakPower : OpticalPower;
    attribute fullWidthHalfMaximum : Wavelength;
    attribute signalToNoiseRatio : Ratio;
  }

  item def SensorMeasurement {
    attribute measuredBraggWavelength : Wavelength;
    attribute wavelengthShift : Wavelength;
    attribute estimatedStrain : Strain;
    attribute estimatedTemperature : Temperature;
    attribute measurementTime : Time;
    attribute confidence : Ratio;
  }

  item def HealthStatus {
    attribute opticalLinkLoss : OpticalPower;
    attribute sourcePowerStable : Boolean;
    attribute detectorSaturated : Boolean;
    attribute calibrationValid : Boolean;
    attribute faultPresent : Boolean;
  }

  port def OpticalTransmitPort {
    out transmittedLight : OpticalSignal;
  }

  port def OpticalReceivePort {
    in receivedLight : OpticalSignal;
  }

  port def OpticalReflectPort {
    in incidentLight : OpticalSignal;
    out reflectedSpectrum : ReflectedSpectrum;
  }

  port def MeasurementOutputPort {
    out measurement : SensorMeasurement;
  }

  port def StatusOutputPort {
    out status : HealthStatus;
  }

  port def CommandPort {
    in powerOn : Boolean;
    in startMeasurement : Boolean;
    in requestCalibration : Boolean;
    in shutdown : Boolean;
  }

  part def BroadbandLightSource {
    attribute nominalPower : OpticalPower = 3.0;
    attribute minimumPower : OpticalPower = 0.0;
    attribute spectralStart : Wavelength = 1510.0;
    attribute spectralEnd : Wavelength = 1590.0;
    attribute warmupTime : Time = 5.0;

    port opticalOut : OpticalTransmitPort;
    port commandIn : CommandPort;
    port statusOut : StatusOutputPort;
  }

  part def OpticalCirculator {
    attribute insertionLoss12 : OpticalPower = 0.8;
    attribute insertionLoss23 : OpticalPower = 0.8;
    attribute isolation31 : OpticalPower = 45.0;

    port port1 : OpticalReceivePort;
    port port2Tx : OpticalTransmitPort;
    port port2Rx : OpticalReceivePort;
    port port3 : OpticalTransmitPort;
  }

  part def FiberLink {
    attribute length : Length = 15.0;
    attribute attenuation : OpticalPower = 0.3;
    attribute minimumBendRadius : Length = 0.03;

    port endAIn : OpticalReceivePort;
    port endAOut : OpticalTransmitPort;
    port endBIn : OpticalReceivePort;
    port endBOut : OpticalTransmitPort;
  }

  part def FiberBraggGratingProbe {
    attribute nominalBraggWavelength : Wavelength = 1550.0;
    attribute reflectivity : Ratio = 0.85;
    attribute gratingLength : Length = 0.01;
    attribute strainSensitivity : Wavelength = 0.0012;
    attribute temperatureSensitivity : Wavelength = 0.0100;
    attribute operatingTemperatureMin : Temperature = -40.0;
    attribute operatingTemperatureMax : Temperature = 125.0;
    attribute operatingStrainMin : Strain = -2500.0;
    attribute operatingStrainMax : Strain = 2500.0;

    port opticalPort : OpticalReflectPort;
  }

  part def PhotodetectorArray {
    attribute wavelengthResolution : Wavelength = 0.001;
    attribute minimumDetectablePower : OpticalPower = -60.0;
    attribute saturationPower : OpticalPower = 0.0;

    port opticalIn : OpticalReceivePort;
    port spectrumOut : MeasurementOutputPort;
    port statusOut : StatusOutputPort;
  }

  part def WavelengthInterrogator {
    attribute sampleRate : Frequency = 1000.0;
    attribute wavelengthAccuracy : Wavelength = 0.002;
    attribute dynamicRange : OpticalPower = 45.0;

    port reflectedLightIn : OpticalReceivePort;
    port measurementOut : MeasurementOutputPort;
    port statusOut : StatusOutputPort;

    part detector : PhotodetectorArray;
  }

  part def SignalProcessor {
    attribute averagingWindow : Time = 0.050;
    attribute calibrationReferenceWavelength : Wavelength = 1550.0;
    attribute alarmStrainLimit : Strain = 2000.0;
    attribute alarmTemperatureLimit : Temperature = 100.0;

    port measurementIn : MeasurementOutputPort;
    port processedMeasurementOut : MeasurementOutputPort;
    port statusOut : StatusOutputPort;
  }

  part def DataInterface {
    attribute updateRate : Frequency = 100.0;
    attribute latencyLimit : Time = 0.100;

    port measurementIn : MeasurementOutputPort;
    port statusIn : StatusOutputPort;
    port commandIn : CommandPort;
  }

  action def EmitBroadbandLight {
    out emittedSignal : OpticalSignal;
  }

  action def ReflectBraggWavelength {
    in incidentSignal : OpticalSignal;
    in strainAtGrating : Strain;
    in temperatureAtGrating : Temperature;
    out reflectedSpectrum : ReflectedSpectrum;
  }

  action def EstimatePhysicalQuantity {
    in reflectedSpectrum : ReflectedSpectrum;
    in referenceWavelength : Wavelength;
    out measurement : SensorMeasurement;
  }

  action def PublishMeasurement {
    in measurement : SensorMeasurement;
    in status : HealthStatus;
  }

  state def FBGSystemOperatingStates {
    state off;
    state initializing;
    state selfTesting;
    state calibrating;
    state measuring;
    state faulted;
    state shuttingDown;

    transition initialToOff first off;

    transition powerCommand
      first off
      accept powerOn
      then initializing;

    transition initializationComplete
      first initializing
      then selfTesting;

    transition selfTestPassed
      first selfTesting
      then calibrating;

    transition calibrationComplete
      first calibrating
      then measuring;

    transition recalibrate
      first measuring
      accept requestCalibration
      then calibrating;

    transition detectedFaultFromInit
      first initializing
      then faulted;

    transition detectedFaultFromSelfTest
      first selfTesting
      then faulted;

    transition detectedFaultFromMeasurement
      first measuring
      then faulted;

    transition shutdownFromMeasuring
      first measuring
      accept shutdown
      then shuttingDown;

    transition shutdownComplete
      first shuttingDown
      then off;
  }

  part def FiberBraggGratingSensingSystem {
    doc /* Primary function: illuminate a Fiber Bragg grating with broadband optical energy, detect the wavelength reflected by the grating, and convert Bragg wavelength shifts into high-level strain and temperature measurements for monitoring a physical structure. */

    attribute measurementRangeStrainMin : Strain = -2500.0;
    attribute measurementRangeStrainMax : Strain = 2500.0;
    attribute measurementRangeTemperatureMin : Temperature = -40.0;
    attribute measurementRangeTemperatureMax : Temperature = 125.0;
    attribute requiredWavelengthAccuracy : Wavelength = 0.005;
    attribute requiredMeasurementLatency : Time = 0.100;

    port commands : CommandPort;
    port measurements : MeasurementOutputPort;
    port health : StatusOutputPort;

    part lightSource : BroadbandLightSource;
    part circulator : OpticalCirculator;
    part fiber : FiberLink;
    part gratingProbe : FiberBraggGratingProbe;
    part interrogator : WavelengthInterrogator;
    part processor : SignalProcessor;
    part interface : DataInterface;

    connection sourceToCirculator {
      connect lightSource.opticalOut to circulator.port1;
    }

    connection circulatorToFiber {
      connect circulator.port2Tx to fiber.endAIn;
      connect fiber.endAOut to circulator.port2Rx;
    }

    connection fiberToGrating {
      connect fiber.endBOut to gratingProbe.opticalPort;
      connect gratingProbe.opticalPort to fiber.endBIn;
    }

    connection circulatorToInterrogator {
      connect circulator.port3 to interrogator.reflectedLightIn;
    }

    connection interrogatorToProcessor {
      connect interrogator.measurementOut to processor.measurementIn;
    }

    connection processorToInterface {
      connect processor.processedMeasurementOut to interface.measurementIn;
      connect processor.statusOut to interface.statusIn;
    }

    connection externalMeasurementOutput {
      connect processor.processedMeasurementOut to measurements;
    }

    connection externalHealthOutput {
      connect processor.statusOut to health;
    }

    connection externalCommandInput {
      connect commands to interface.commandIn;
      connect commands to lightSource.commandIn;
    }

    perform action EmitBroadbandLight;
    perform action ReflectBraggWavelength;
    perform action EstimatePhysicalQuantity;
    perform action PublishMeasurement;

    exhibit state FBGSystemOperatingStates;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : FiberBraggGratingSensingSystem;

    require constraint {
      system.requiredWavelengthAccuracy <= 0.005
    }

    doc /* The system shall provide non-electrical optical sensing by translating Fiber Bragg grating reflected wavelength shifts into strain and temperature measurements. */
  }

  requirement def OpticalIlluminationRequirement {
    subject source : BroadbandLightSource;

    require constraint {
      source.spectralStart <= 1510.0 and source.spectralEnd >= 1590.0 and source.minimumPower >= 0.0
    }
  }

  requirement def BraggReflectionRequirement {
    subject probe : FiberBraggGratingProbe;

    require constraint {
      probe.nominalBraggWavelength >= 1545.0 and
      probe.nominalBraggWavelength <= 1555.0 and
      probe.reflectivity >= 0.70
    }
  }

  requirement def MeasurementLatencyRequirement {
    subject system : FiberBraggGratingSensingSystem;

    require constraint {
      system.requiredMeasurementLatency <= 0.100
    }
  }

  requirement def EnvironmentalOperatingRequirement {
    subject probe : FiberBraggGratingProbe;

    require constraint {
      probe.operatingTemperatureMin <= -40.0 and
      probe.operatingTemperatureMax >= 125.0 and
      probe.operatingStrainMin <= -2500.0 and
      probe.operatingStrainMax >= 2500.0
    }
  }

  requirement def FaultMonitoringRequirement {
    subject system : FiberBraggGratingSensingSystem;

    require constraint {
      system.health.status.faultPresent == false
    }
  }

  part fbgStructuralMonitor : FiberBraggGratingSensingSystem;

  satisfy PrimaryFunctionRequirement by fbgStructuralMonitor;
  satisfy MeasurementLatencyRequirement by fbgStructuralMonitor;
  satisfy OpticalIlluminationRequirement by fbgStructuralMonitor.lightSource;
  satisfy BraggReflectionRequirement by fbgStructuralMonitor.gratingProbe;
  satisfy EnvironmentalOperatingRequirement by fbgStructuralMonitor.gratingProbe;

}