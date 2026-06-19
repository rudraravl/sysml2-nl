package TriangulationSensingUnitModel {
  import ScalarValues::*;

  attribute def Distance {
    attribute magnitude : Real;
    attribute unitSymbol : String = "m";
  }

  attribute def TimeDuration {
    attribute magnitude : Real;
    attribute unitSymbol : String = "s";
  }

  attribute def Frequency {
    attribute magnitude : Real;
    attribute unitSymbol : String = "Hz";
  }

  attribute def Voltage {
    attribute magnitude : Real;
    attribute unitSymbol : String = "V";
  }

  attribute def ElectricCurrent {
    attribute magnitude : Real;
    attribute unitSymbol : String = "A";
  }

  attribute def ElectricPower {
    attribute magnitude : Real;
    attribute unitSymbol : String = "W";
  }

  attribute def OpticalPower {
    attribute magnitude : Real;
    attribute unitSymbol : String = "mW";
  }

  attribute def Wavelength {
    attribute magnitude : Real;
    attribute unitSymbol : String = "nm";
  }

  attribute def Angle {
    attribute magnitude : Real;
    attribute unitSymbol : String = "deg";
  }

  attribute def Temperature {
    attribute magnitude : Real;
    attribute unitSymbol : String = "degC";
  }

  attribute def Ratio {
    attribute magnitude : Real;
    attribute unitSymbol : String = "1";
  }

  attribute def PixelCoordinate {
    attribute magnitude : Real;
    attribute unitSymbol : String = "pixel";
  }

  attribute def DigitalCount {
    attribute magnitude : Real;
    attribute unitSymbol : String = "count";
  }

  attribute def DistanceRange {
    attribute minimum : Distance;
    attribute maximum : Distance;
  }

  item def ElectricalSupply {
    attribute voltage : Voltage;
    attribute currentLimit : ElectricCurrent;
    attribute availablePower : ElectricPower;
  }

  item def RegulatedElectricalPower {
    attribute voltage : Voltage;
    attribute current : ElectricCurrent;
    attribute power : ElectricPower;
    attribute regulationError : Ratio;
  }

  item def SensorCommand {
    attribute enableEmitter : Boolean;
    attribute requestSample : Boolean;
    attribute integrationTime : TimeDuration;
    attribute commandedSampleRate : Frequency;
  }

  item def SensorStatus {
    attribute powered : Boolean;
    attribute emitterEnabled : Boolean;
    attribute detectorReady : Boolean;
    attribute processorReady : Boolean;
    attribute faultPresent : Boolean;
    attribute temperature : Temperature;
  }

  item def OpticalBeam {
    attribute wavelength : Wavelength;
    attribute emittedPower : OpticalPower;
    attribute divergence : Angle;
    attribute nominalSpotDiameter : Distance;
  }

  item def ReflectedSpot {
    attribute centroidX : PixelCoordinate;
    attribute centroidY : PixelCoordinate;
    attribute peakIntensity : DigitalCount;
    attribute signalToNoiseRatio : Ratio;
    attribute receivedPower : OpticalPower;
  }

  item def TriangulationObservation {
    attribute centroidX : PixelCoordinate;
    attribute centroidY : PixelCoordinate;
    attribute baseline : Distance;
    attribute lensFocalLength : Distance;
    attribute emitterAngle : Angle;
    attribute receiverAngle : Angle;
    attribute rawDistance : Distance;
    attribute signalToNoiseRatio : Ratio;
  }

  item def DistanceMeasurement {
    attribute distance : Distance;
    attribute uncertainty : Distance;
    attribute sampleAge : TimeDuration;
    attribute valid : Boolean;
    attribute quantityName : String = "distance";
    attribute methodName : String = "optical triangulation";
  }

  item def PowerApplied;
  item def StartAcquisition;
  item def SpotCaptured;
  item def MeasurementComputed;
  item def ReportComplete;
  item def FaultDetected;
  item def ResetRequested;

  port def ElectricalPowerInputPort {
    in item supply : ElectricalSupply;
  }

  port def RegulatedPowerOutputPort {
    out item regulatedPower : RegulatedElectricalPower;
  }

  port def RegulatedPowerInputPort {
    in item regulatedPower : RegulatedElectricalPower;
  }

  port def CommandInputPort {
    in item command : SensorCommand;
  }

  port def CommandOutputPort {
    out item command : SensorCommand;
  }

  port def StatusInputPort {
    in item status : SensorStatus;
  }

  port def StatusOutputPort {
    out item status : SensorStatus;
  }

  port def OpticalTransmitPort {
    out item beam : OpticalBeam;
  }

  port def OpticalReceivePort {
    in item reflectedSpot : ReflectedSpot;
  }

  port def TargetOpticalPort {
    in item incidentBeam : OpticalBeam;
    out item reflectedSpot : ReflectedSpot;
  }

  port def ObservationInputPort {
    in item observation : TriangulationObservation;
  }

  port def ObservationOutputPort {
    out item observation : TriangulationObservation;
  }

  port def MeasurementInputPort {
    in item measurement : DistanceMeasurement;
  }

  port def MeasurementOutputPort {
    out item measurement : DistanceMeasurement;
  }

  connection def PowerDelegation {
    end externalPowerPort : ElectricalPowerInputPort;
    end internalPowerPort : ElectricalPowerInputPort;
  }

  connection def RegulatedPowerLink {
    end source : RegulatedPowerOutputPort;
    end sink : RegulatedPowerInputPort;
  }

  connection def CommandLink {
    end source : CommandOutputPort;
    end sink : CommandInputPort;
  }

  connection def StatusLink {
    end source : StatusOutputPort;
    end sink : StatusInputPort;
  }

  connection def EmittedOpticalPath {
    end source : OpticalTransmitPort;
    end target : TargetOpticalPort;
  }

  connection def ReflectedOpticalPath {
    end source : TargetOpticalPort;
    end sink : OpticalReceivePort;
  }

  connection def ObservationLink {
    end source : ObservationOutputPort;
    end sink : ObservationInputPort;
  }

  connection def MeasurementLink {
    end source : MeasurementOutputPort;
    end sink : MeasurementInputPort;
  }

  action def RegulatePower {
    in item supply : ElectricalSupply;
    out item regulatedPower : RegulatedElectricalPower;
  }

  action def EmitTriangulationBeam {
    in item command : SensorCommand;
    in item regulatedPower : RegulatedElectricalPower;
    out item beam : OpticalBeam;
  }

  action def CaptureReflectedSpot {
    in item reflectedSpot : ReflectedSpot;
    out item observation : TriangulationObservation;
  }

  action def ComputeDistanceByTriangulation {
    in item observation : TriangulationObservation;
    out item measurement : DistanceMeasurement;
    attribute computationRule : String = "target distance is derived from the detector spot centroid, emitter-receiver baseline, lens focal length, and calibrated triangulation angles";
  }

  action def ValidateAndPublishDistance {
    in item measurement : DistanceMeasurement;
    out item publishedMeasurement : DistanceMeasurement;
    attribute minimumAcceptedSnr : Ratio {
      :>> magnitude = 20.0;
    }
  }

  action def SensingMeasurementCycle {
    in item command : SensorCommand;
    in item regulatedPower : RegulatedElectricalPower;
    in item reflectedSpot : ReflectedSpot;
    out item measurement : DistanceMeasurement;

    action emit : EmitTriangulationBeam;
    action capture : CaptureReflectedSpot;
    action compute : ComputeDistanceByTriangulation;
    action publish : ValidateAndPublishDistance;

    flow command to emit.command;
    flow regulatedPower to emit.regulatedPower;
    flow reflectedSpot to capture.reflectedSpot;
    flow capture.observation to compute.observation;
    flow compute.measurement to publish.measurement;
    flow publish.publishedMeasurement to measurement;
  }

  state def SensingUnitOperatingStateMachine {
    entry; then off;

    state off;
    state initializing;
    state ready;
    state emitting;
    state imaging;
    state computing;
    state reporting;
    state fault;

    transition powerOn
      first off
      accept PowerApplied
      then initializing;

    transition initializationComplete
      first initializing
      then ready;

    transition beginAcquisition
      first ready
      accept StartAcquisition
      then emitting;

    transition beamEmitted
      first emitting
      then imaging;

    transition imageAcquired
      first imaging
      accept SpotCaptured
      then computing;

    transition distanceCalculated
      first computing
      accept MeasurementComputed
      then reporting;

    transition reportPublished
      first reporting
      accept ReportComplete
      then ready;

    transition faultFromInitializing
      first initializing
      accept FaultDetected
      then fault;

    transition faultFromReady
      first ready
      accept FaultDetected
      then fault;

    transition faultFromEmitting
      first emitting
      accept FaultDetected
      then fault;

    transition faultFromImaging
      first imaging
      accept FaultDetected
      then fault;

    transition faultFromComputing
      first computing
      accept FaultDetected
      then fault;

    transition resetFault
      first fault
      accept ResetRequested
      then initializing;
  }

  part def PowerRegulator {
    port powerInput : ElectricalPowerInputPort;
    port regulatedOutput : RegulatedPowerOutputPort;
    attribute nominalInputVoltage : Voltage {
      :>> magnitude = 24.0;
    }
    attribute nominalOutputVoltage : Voltage {
      :>> magnitude = 5.0;
    }
    attribute maximumOutputCurrent : ElectricCurrent {
      :>> magnitude = 0.8;
    }
    attribute maximumRegulationError : Ratio {
      :>> magnitude = 0.02;
    }
    action regulate : RegulatePower;
  }

  part def LaserEmitter {
    port powerInput : RegulatedPowerInputPort;
    port commandInput : CommandInputPort;
    port opticalOutput : OpticalTransmitPort;
    port statusOutput : StatusOutputPort;

    attribute nominalWavelength : Wavelength {
      :>> magnitude = 650.0;
    }
    attribute maximumEmittedPower : OpticalPower {
      :>> magnitude = 4.5;
    }
    attribute nominalDivergence : Angle {
      :>> magnitude = 0.4;
    }
    attribute nominalSpotDiameterAtStandoff : Distance {
      :>> magnitude = 0.001;
    }
    action emitBeam : EmitTriangulationBeam;
  }

  part def ImagingDetector {
    port powerInput : RegulatedPowerInputPort;
    port opticalInput : OpticalReceivePort;
    port observationOutput : ObservationOutputPort;
    port statusOutput : StatusOutputPort;

    attribute activePixelCountX : DigitalCount {
      :>> magnitude = 2048.0;
    }
    attribute activePixelCountY : DigitalCount {
      :>> magnitude = 1.0;
    }
    attribute pixelPitch : Distance {
      :>> magnitude = 0.000007;
    }
    attribute maximumIntegrationTime : TimeDuration {
      :>> magnitude = 0.002;
    }
    attribute minimumDetectableSnr : Ratio {
      :>> magnitude = 10.0;
    }
    action captureSpot : CaptureReflectedSpot;
  }

  part def TriangulationProcessor {
    port powerInput : RegulatedPowerInputPort;
    port commandInput : CommandInputPort;
    port emitterCommandOutput : CommandOutputPort;
    port observationInput : ObservationInputPort;
    port measurementOutput : MeasurementOutputPort;
    port statusOutput : StatusOutputPort;

    attribute calibrationBaseline : Distance {
      :>> magnitude = 0.035;
    }
    attribute calibrationFocalLength : Distance {
      :>> magnitude = 0.016;
    }
    attribute calibrationEmitterAngle : Angle {
      :>> magnitude = 25.0;
    }
    attribute calibrationReceiverAngle : Angle {
      :>> magnitude = 0.0;
    }
    attribute computationLatency : TimeDuration {
      :>> magnitude = 0.004;
    }

    action computeDistance : ComputeDistanceByTriangulation;
  }

  part def TriangulationSensor {
    port powerInput : RegulatedPowerInputPort;
    port commandInput : CommandInputPort;
    port opticalTransmit : OpticalTransmitPort;
    port opticalReceive : OpticalReceivePort;
    port measurementOutput : MeasurementOutputPort;
    port statusOutput : StatusOutputPort;

    attribute kind : String = "triangulation";
    attribute measuredQuantity : String = "distance";
    attribute triangulationBaseline : Distance {
      :>> magnitude = 0.035;
    }
    attribute lensFocalLength : Distance {
      :>> magnitude = 0.016;
    }
    attribute emitterAngle : Angle {
      :>> magnitude = 25.0;
    }
    attribute minimumRange : Distance {
      :>> magnitude = 0.030;
    }
    attribute maximumRange : Distance {
      :>> magnitude = 0.500;
    }
    attribute nominalStandoff : Distance {
      :>> magnitude = 0.150;
    }
    attribute maximumLinearityError : Distance {
      :>> magnitude = 0.0005;
    }

    part emitter : LaserEmitter;
    part detector : ImagingDetector;
    part processor : TriangulationProcessor;

    connection emitterPower : RegulatedPowerLink connect powerInput to emitter.powerInput;
    connection detectorPower : RegulatedPowerLink connect powerInput to detector.powerInput;
    connection processorPower : RegulatedPowerLink connect powerInput to processor.powerInput;
    connection sensorCommand : CommandLink connect commandInput to processor.commandInput;
    connection emitterCommand : CommandLink connect processor.emitterCommandOutput to emitter.commandInput;
    connection opticalEmissionDelegation connect emitter.opticalOutput to opticalTransmit;
    connection opticalReceiveDelegation connect opticalReceive to detector.opticalInput;
    connection spotObservation : ObservationLink connect detector.observationOutput to processor.observationInput;
    connection measuredDistanceDelegation : MeasurementLink connect processor.measurementOutput to measurementOutput;
    connection processorStatusDelegation connect processor.statusOutput to statusOutput;
  }

  part def MeasurementController {
    port powerInput : RegulatedPowerInputPort;
    port commandOutput : CommandOutputPort;
    port measurementInput : MeasurementInputPort;
    port measurementOutput : MeasurementOutputPort;
    port statusInput : StatusInputPort;
    port statusOutput : StatusOutputPort;

    attribute requestedSampleRate : Frequency {
      :>> magnitude = 100.0;
    }
    attribute maximumUpdatePeriod : TimeDuration {
      :>> magnitude = 0.010;
    }
    attribute maximumPermittedUncertainty : Distance {
      :>> magnitude = 0.001;
    }
    attribute integrationTimeCommand : TimeDuration {
      :>> magnitude = 0.001;
    }

    action publishDistance : ValidateAndPublishDistance;
  }

  part def SensingUnit {
    port powerInput : ElectricalPowerInputPort;
    port targetOpticalPort : TargetOpticalPort;
    port measurementOutput : MeasurementOutputPort;
    port statusOutput : StatusOutputPort;

    attribute unitName : String = "Triangulation distance sensing unit";
    attribute relevantQuantity : String = "distance";
    attribute specifiedMinimumRange : Distance {
      :>> magnitude = 0.030;
    }
    attribute specifiedMaximumRange : Distance {
      :>> magnitude = 0.500;
    }
    attribute maximumPermittedError : Distance {
      :>> magnitude = 0.001;
    }
    attribute reportedDistanceUncertainty : Distance {
      :>> magnitude = 0.0008;
    }
    attribute maximumUpdatePeriod : TimeDuration {
      :>> magnitude = 0.010;
    }
    attribute operatingTemperatureMinimum : Temperature {
      :>> magnitude = -10.0;
    }
    attribute operatingTemperatureMaximum : Temperature {
      :>> magnitude = 50.0;
    }

    part powerRegulator : PowerRegulator;
    part sensor : TriangulationSensor;
    part controller : MeasurementController;

    connection powerInDelegation : PowerDelegation connect powerInput to powerRegulator.powerInput;
    connection regulatedPowerToSensor : RegulatedPowerLink connect powerRegulator.regulatedOutput to sensor.powerInput;
    connection regulatedPowerToController : RegulatedPowerLink connect powerRegulator.regulatedOutput to controller.powerInput;
    connection controllerCommandToSensor : CommandLink connect controller.commandOutput to sensor.commandInput;
    connection sensorMeasurementToController : MeasurementLink connect sensor.measurementOutput to controller.measurementInput;
    connection controllerMeasurementDelegation : MeasurementLink connect controller.measurementOutput to measurementOutput;
    connection sensorStatusToController : StatusLink connect sensor.statusOutput to controller.statusInput;
    connection controllerStatusDelegation : StatusLink connect controller.statusOutput to statusOutput;
    connection emittedBeamPath : EmittedOpticalPath connect sensor.opticalTransmit to targetOpticalPort;
    connection reflectedSpotPath : ReflectedOpticalPath connect targetOpticalPort to sensor.opticalReceive;

    action measurementCycle : SensingMeasurementCycle;
    state operatingState : SensingUnitOperatingStateMachine;
  }

  part def MeasuredSurface {
    port opticalPort : TargetOpticalPort;

    attribute surfaceName : String = "cooperative diffuse target";
    attribute actualDistanceFromSensor : Distance {
      :>> magnitude = 0.150;
    }
    attribute reflectance : Ratio {
      :>> magnitude = 0.70;
    }
    attribute surfaceTilt : Angle {
      :>> magnitude = 0.0;
    }
  }

  part def DcPowerSupply {
    port powerOutput : ElectricalPowerInputPort;

    attribute outputVoltage : Voltage {
      :>> magnitude = 24.0;
    }
    attribute currentLimit : ElectricCurrent {
      :>> magnitude = 1.0;
    }
    attribute availablePower : ElectricPower {
      :>> magnitude = 24.0;
    }
  }

  part def HostController {
    port measurementInput : MeasurementInputPort;
    port statusInput : StatusInputPort;

    attribute acceptedQuantity : String = "distance";
    attribute requiredUpdateRate : Frequency {
      :>> magnitude = 100.0;
    }
  }

  part def MeasurementBench {
    part supply : DcPowerSupply;
    part unit : SensingUnit;
    part target : MeasuredSurface;
    part host : HostController;

    connection benchPower connect supply.powerOutput to unit.powerInput;
    connection benchOpticalPath connect unit.targetOpticalPort to target.opticalPort;
    connection benchMeasurement : MeasurementLink connect unit.measurementOutput to host.measurementInput;
    connection benchStatus : StatusLink connect unit.statusOutput to host.statusInput;
  }

  requirement def RelevantQuantityMeasuredRequirement {
    subject unit : SensingUnit;
    require constraint {
      unit.relevantQuantity == "distance"
    }
  }

  requirement def TriangulationSensorRequirement {
    subject unit : SensingUnit;
    require constraint {
      unit.sensor.kind == "triangulation"
    }
    require constraint {
      unit.sensor.triangulationBaseline.magnitude > 0.0
    }
    require constraint {
      unit.sensor.lensFocalLength.magnitude > 0.0
    }
  }

  requirement def MeasurementRangeRequirement {
    subject unit : SensingUnit;
    require constraint {
      unit.sensor.minimumRange.magnitude <= unit.specifiedMinimumRange.magnitude
    }
    require constraint {
      unit.sensor.maximumRange.magnitude >= unit.specifiedMaximumRange.magnitude
    }
  }

  requirement def MeasurementAccuracyRequirement {
    subject unit : SensingUnit;
    require constraint {
      unit.reportedDistanceUncertainty.magnitude <= unit.maximumPermittedError.magnitude
    }
  }

  requirement def UpdateRateRequirement {
    subject unit : SensingUnit;
    require constraint {
      unit.controller.maximumUpdatePeriod.magnitude <= unit.maximumUpdatePeriod.magnitude
    }
  }

  requirement def OpticalSafetyRequirement {
    subject unit : SensingUnit;
    require constraint {
      unit.sensor.emitter.maximumEmittedPower.magnitude <= 5.0
    }
  }

  requirement def SensingUnitRequirementSet {
    subject unit : SensingUnit;
    require requirement relevantQuantity : RelevantQuantityMeasuredRequirement {
      subject unit = unit;
    }
    require requirement usesTriangulation : TriangulationSensorRequirement {
      subject unit = unit;
    }
    require requirement range : MeasurementRangeRequirement {
      subject unit = unit;
    }
    require requirement accuracy : MeasurementAccuracyRequirement {
      subject unit = unit;
    }
    require requirement updateRate : UpdateRateRequirement {
      subject unit = unit;
    }
    require requirement opticalSafety : OpticalSafetyRequirement {
      subject unit = unit;
    }
  }

  part demonstrationBench : MeasurementBench;

  requirement sensingUnitRequirements : SensingUnitRequirementSet {
    subject unit = demonstrationBench.unit;
  }

  satisfy sensingUnitRequirements by demonstrationBench.unit;
}
