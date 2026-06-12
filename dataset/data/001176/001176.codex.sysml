package PermanentDownholeGaugeSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Pressure;
  attribute def Temperature;
  attribute def Voltage;
  attribute def Current;
  attribute def Power;
  attribute def Frequency;
  attribute def Time;
  attribute def Length;
  attribute def Mass;
  attribute def DataRate;

  value type kPa :> Pressure;
  value type MPa :> Pressure;
  value type degC :> Temperature;
  value type V :> Voltage;
  value type mA :> Current;
  value type W :> Power;
  value type Hz :> Frequency;
  value type s :> Time;
  value type m :> Length;
  value type kg :> Mass;
  value type bit_per_s :> DataRate;

  item def ReservoirFluid {
    attribute pressure : MPa;
    attribute temperature : degC;
  }

  item def PressureSample {
    attribute measuredPressure : MPa;
    attribute sampleTime : s;
    attribute sensorHealth : HealthState;
  }

  item def TemperatureSample {
    attribute measuredTemperature : degC;
    attribute sampleTime : s;
    attribute sensorHealth : HealthState;
  }

  item def DownholeMeasurementPacket {
    attribute pressure : MPa;
    attribute temperature : degC;
    attribute downholeTimestamp : s;
    attribute gaugeDepth : m;
    attribute electronicsTemperature : degC;
    attribute diagnosticCode : Integer;
  }

  item def ElectricalPower {
    attribute supplyVoltage : V;
    attribute supplyCurrent : mA;
  }

  item def TelemetrySignal {
    attribute bitRate : bit_per_s;
    attribute carrierFrequency : Hz;
    attribute packetErrorRate : Real;
  }

  enum def HealthState {
    enum ok;
    enum degraded;
    enum failed;
    enum calibrating;
  }

  enum def GaugeOperatingState {
    enum unpowered;
    enum initialization;
    enum normalMonitoring;
    enum diagnosticMode;
    enum degradedMonitoring;
    enum safeMode;
    enum failed;
  }

  port def FluidExposurePort {
    in item fluid : ReservoirFluid;
  }

  port def PowerInputPort {
    in item power : ElectricalPower;
  }

  port def MeasurementOutputPort {
    out item packet : DownholeMeasurementPacket;
  }

  port def TelemetryPort {
    out item signal : TelemetrySignal;
    out item packet : DownholeMeasurementPacket;
  }

  port def CommandPort {
    in item command : SurfaceCommand;
  }

  item def SurfaceCommand {
    attribute commandId : Integer;
    attribute requestedSampleInterval : s;
    attribute requestDiagnostics : Boolean;
    attribute resetGauge : Boolean;
  }

  part def PermanentDownholeGaugeSystem {
    attribute designDepth : m = 4500 [m];
    attribute maximumRatedPressure : MPa = 103 [MPa];
    attribute maximumRatedTemperature : degC = 177 [degC];
    attribute nominalSampleInterval : s = 1 [s];
    attribute operatingLife : s = 315576000 [s];

    port wellboreInterface : FluidExposurePort;
    port surfacePowerInput : PowerInputPort;
    port surfaceCommandInput : CommandPort;
    port surfaceTelemetryOutput : TelemetryPort;

    part downholeGauge : DownholeGauge;
    part tubingCable : TubingEncapsulatedCable;
    part surfaceAcquisitionUnit : SurfaceAcquisitionUnit;
    part operatorDisplay : OperatorDisplay;

    connect surfacePowerInput to tubingCable.surfacePowerPort;
    connect surfaceCommandInput to surfaceAcquisitionUnit.commandInput;
    connect tubingCable.downholePowerPort to downholeGauge.powerInput;
    connect tubingCable.downholeCommandPort to downholeGauge.commandInput;
    connect wellboreInterface to downholeGauge.processInterface;
    connect downholeGauge.measurementOutput to tubingCable.downholeTelemetryPort;
    connect tubingCable.surfaceTelemetryPort to surfaceAcquisitionUnit.telemetryInput;
    connect surfaceAcquisitionUnit.processedDataOutput to operatorDisplay.dataInput;
    connect surfaceAcquisitionUnit.telemetryOutput to surfaceTelemetryOutput;

    perform action continuousReservoirSurveillance : ContinuousReservoirSurveillance;
  }

  part def DownholeGauge {
    attribute installedDepth : m = 3650 [m];
    attribute housingMass : kg = 18 [kg];
    attribute pressureAccuracy : MPa = 0.01 [MPa];
    attribute temperatureAccuracy : degC = 0.1 [degC];
    attribute sampleInterval : s = 1 [s];
    attribute electronicsHealth : HealthState = HealthState::ok;
    attribute operatingState : GaugeOperatingState = GaugeOperatingState::unpowered;

    port processInterface : FluidExposurePort;
    port powerInput : PowerInputPort;
    port commandInput : CommandPort;
    port measurementOutput : MeasurementOutputPort;

    part pressureSensor : QuartzPressureSensor;
    part temperatureSensor : PlatinumResistanceTemperatureSensor;
    part electronicsModule : DownholeElectronicsModule;
    part memoryModule : NonvolatileMemoryModule;
    part pressureHousing : PressureHousing;

    connect processInterface to pressureSensor.fluidInput;
    connect processInterface to temperatureSensor.fluidInput;
    connect pressureSensor.pressureOutput to electronicsModule.pressureInput;
    connect temperatureSensor.temperatureOutput to electronicsModule.temperatureInput;
    connect powerInput to electronicsModule.powerInput;
    connect commandInput to electronicsModule.commandInput;
    connect electronicsModule.packetOutput to memoryModule.packetInput;
    connect electronicsModule.packetOutput to measurementOutput;

    perform action acquireAndTransmitMeasurement : AcquireAndTransmitMeasurement;

    state def GaugeStateMachine {
      state unpowered;
      state initialization;
      state normalMonitoring;
      state diagnosticMode;
      state degradedMonitoring;
      state safeMode;
      state failed;

      transition initial then unpowered;

      transition powerApplied
        first unpowered
        then initialization
        accept ElectricalPower;

      transition initializationComplete
        first initialization
        then normalMonitoring
        if electronicsHealth == HealthState::ok;

      transition diagnosticRequested
        first normalMonitoring
        then diagnosticMode
        accept SurfaceCommand
        if command.requestDiagnostics == true;

      transition diagnosticsComplete
        first diagnosticMode
        then normalMonitoring
        if electronicsHealth == HealthState::ok;

      transition degradationDetected
        first normalMonitoring
        then degradedMonitoring
        if electronicsHealth == HealthState::degraded;

      transition enterSafeMode
        first degradedMonitoring
        then safeMode
        if pressureSensor.sensorHealth == HealthState::failed or temperatureSensor.sensorHealth == HealthState::failed;

      transition resetAfterSafeMode
        first safeMode
        then initialization
        accept SurfaceCommand
        if command.resetGauge == true;

      transition unrecoverableFailure
        first safeMode
        then failed
        if electronicsHealth == HealthState::failed;
    }
  }

  part def QuartzPressureSensor {
    attribute measurementRangeMin : MPa = 0 [MPa];
    attribute measurementRangeMax : MPa = 103 [MPa];
    attribute accuracy : MPa = 0.01 [MPa];
    attribute sensorHealth : HealthState = HealthState::ok;

    port fluidInput : FluidExposurePort;
    port pressureOutput {
      out item pressureSample : PressureSample;
    }

    action measurePressure {
      in item reservoirFluid : ReservoirFluid;
      out item pressureSample : PressureSample;

      bind pressureSample.measuredPressure = reservoirFluid.pressure;
      bind pressureSample.sensorHealth = sensorHealth;
    }
  }

  part def PlatinumResistanceTemperatureSensor {
    attribute measurementRangeMin : degC = -20 [degC];
    attribute measurementRangeMax : degC = 177 [degC];
    attribute accuracy : degC = 0.1 [degC];
    attribute sensorHealth : HealthState = HealthState::ok;

    port fluidInput : FluidExposurePort;
    port temperatureOutput {
      out item temperatureSample : TemperatureSample;
    }

    action measureTemperature {
      in item reservoirFluid : ReservoirFluid;
      out item temperatureSample : TemperatureSample;

      bind temperatureSample.measuredTemperature = reservoirFluid.temperature;
      bind temperatureSample.sensorHealth = sensorHealth;
    }
  }

  part def DownholeElectronicsModule {
    attribute inputVoltageMin : V = 18 [V];
    attribute inputVoltageMax : V = 48 [V];
    attribute nominalPower : W = 2.5 [W];
    attribute processorTemperature : degC;
    attribute electronicsHealth : HealthState = HealthState::ok;
    attribute packetCounter : Integer = 0;

    port powerInput : PowerInputPort;
    port commandInput : CommandPort;

    port pressureInput {
      in item pressureSample : PressureSample;
    }

    port temperatureInput {
      in item temperatureSample : TemperatureSample;
    }

    port packetOutput : MeasurementOutputPort;

    action buildMeasurementPacket {
      in item pressureSample : PressureSample;
      in item temperatureSample : TemperatureSample;
      out item packet : DownholeMeasurementPacket;

      bind packet.pressure = pressureSample.measuredPressure;
      bind packet.temperature = temperatureSample.measuredTemperature;
      bind packet.electronicsTemperature = processorTemperature;
      bind packet.diagnosticCode = packetCounter;
    }

    action validateInputs {
      in item power : ElectricalPower;
      in item pressureSample : PressureSample;
      in item temperatureSample : TemperatureSample;
      out attribute valid : Boolean;

      valid = power.supplyVoltage >= inputVoltageMin and
              power.supplyVoltage <= inputVoltageMax and
              pressureSample.sensorHealth != HealthState::failed and
              temperatureSample.sensorHealth != HealthState::failed;
    }
  }

  part def NonvolatileMemoryModule {
    attribute storageCapacityPackets : Integer = 1000000;
    attribute retainedPacketCount : Integer = 0;
    attribute memoryHealth : HealthState = HealthState::ok;

    port packetInput : MeasurementOutputPort;

    action storePacket {
      in item packet : DownholeMeasurementPacket;
      out attribute retainedPacketCountOut : Integer;

      retainedPacketCountOut = retainedPacketCount + 1;
    }
  }

  part def PressureHousing {
    attribute outsideDiameter : m = 0.032 [m];
    attribute length : m = 1.2 [m];
    attribute collapsePressureRating : MPa = 138 [MPa];
    attribute materialYieldLimitTemperature : degC = 220 [degC];
    attribute leakTight : Boolean = true;
  }

  part def TubingEncapsulatedCable {
    attribute cableLength : m = 3700 [m];
    attribute conductorResistance : Real = 28.0;
    attribute insulationTemperatureRating : degC = 200 [degC];
    attribute armorPressureRating : MPa = 103 [MPa];

    port surfacePowerPort : PowerInputPort;
    port downholePowerPort : PowerInputPort;
    port downholeCommandPort : CommandPort;
    port downholeTelemetryPort : MeasurementOutputPort;
    port surfaceTelemetryPort : TelemetryPort;
  }

  part def SurfaceAcquisitionUnit {
    attribute outputVoltage : V = 36 [V];
    attribute maximumOutputCurrent : mA = 150 [mA];
    attribute pollingInterval : s = 1 [s];
    attribute dataArchiveEnabled : Boolean = true;

    port commandInput : CommandPort;

    port telemetryInput {
      in item packet : DownholeMeasurementPacket;
      in item signal : TelemetrySignal;
    }

    port processedDataOutput {
      out item packet : DownholeMeasurementPacket;
    }

    port telemetryOutput : TelemetryPort;

    action decodeAndArchive {
      in item packet : DownholeMeasurementPacket;
      out item validatedPacket : DownholeMeasurementPacket;

      bind validatedPacket.pressure = packet.pressure;
      bind validatedPacket.temperature = packet.temperature;
      bind validatedPacket.downholeTimestamp = packet.downholeTimestamp;
      bind validatedPacket.gaugeDepth = packet.gaugeDepth;
    }
  }

  part def OperatorDisplay {
    port dataInput {
      in item packet : DownholeMeasurementPacket;
    }

    attribute latestPressure : MPa;
    attribute latestTemperature : degC;
    attribute pressureTrendIncreasing : Boolean;
    attribute alarmActive : Boolean = false;

    action updateDisplay {
      in item packet : DownholeMeasurementPacket;

      bind latestPressure = packet.pressure;
      bind latestTemperature = packet.temperature;
    }
  }

  action def ContinuousReservoirSurveillance {
    in item reservoirFluid : ReservoirFluid;
    in item suppliedPower : ElectricalPower;
    in item surfaceCommand : SurfaceCommand;
    out item displayedPacket : DownholeMeasurementPacket;

    action acquirePressure : QuartzPressureSensor::measurePressure;
    action acquireTemperature : PlatinumResistanceTemperatureSensor::measureTemperature;
    action composePacket : DownholeElectronicsModule::buildMeasurementPacket;
    action archivePacket : SurfaceAcquisitionUnit::decodeAndArchive;

    flow reservoirFluid to acquirePressure.reservoirFluid;
    flow reservoirFluid to acquireTemperature.reservoirFluid;
    flow acquirePressure.pressureSample to composePacket.pressureSample;
    flow acquireTemperature.temperatureSample to composePacket.temperatureSample;
    flow composePacket.packet to archivePacket.packet;
    flow archivePacket.validatedPacket to displayedPacket;
  }

  action def AcquireAndTransmitMeasurement {
    in item reservoirFluid : ReservoirFluid;
    in item power : ElectricalPower;
    out item packet : DownholeMeasurementPacket;

    action pressureMeasurement : QuartzPressureSensor::measurePressure;
    action temperatureMeasurement : PlatinumResistanceTemperatureSensor::measureTemperature;
    action packetBuilder : DownholeElectronicsModule::buildMeasurementPacket;

    flow reservoirFluid to pressureMeasurement.reservoirFluid;
    flow reservoirFluid to temperatureMeasurement.reservoirFluid;
    flow pressureMeasurement.pressureSample to packetBuilder.pressureSample;
    flow temperatureMeasurement.temperatureSample to packetBuilder.temperatureSample;
    flow packetBuilder.packet to packet;
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /*
     The permanent downhole gauge system shall continuously measure downhole reservoir pressure and temperature at the installed gauge depth and transmit time-correlated measurements to the surface acquisition unit for production surveillance, reservoir management, and well integrity monitoring.
    */

    subject system : PermanentDownholeGaugeSystem;

    require constraint {
      system.downholeGauge.sampleInterval <= 1 [s]
    }
  }

  requirement def PressureMeasurementRequirement {
    subject gauge : DownholeGauge;

    require constraint {
      gauge.pressureSensor.measurementRangeMax >= 100 [MPa] and
      gauge.pressureSensor.accuracy <= 0.02 [MPa]
    }
  }

  requirement def TemperatureMeasurementRequirement {
    subject gauge : DownholeGauge;

    require constraint {
      gauge.temperatureSensor.measurementRangeMax >= 175 [degC] and
      gauge.temperatureSensor.accuracy <= 0.2 [degC]
    }
  }

  requirement def DownholeSurvivabilityRequirement {
    subject gauge : DownholeGauge;

    require constraint {
      gauge.pressureHousing.collapsePressureRating >= 1.25 * gauge.pressureSensor.measurementRangeMax and
      gauge.pressureHousing.materialYieldLimitTemperature >= 200 [degC]
    }
  }

  requirement def TelemetryRequirement {
    subject system : PermanentDownholeGaugeSystem;

    require constraint {
      system.surfaceTelemetryOutput.signal.bitRate >= 1200 [bit_per_s] and
      system.surfaceTelemetryOutput.signal.packetErrorRate <= 0.001
    }
  }

  requirement def PowerRequirement {
    subject electronics : DownholeElectronicsModule;

    require constraint {
      electronics.inputVoltageMin >= 12 [V] and
      electronics.inputVoltageMax <= 60 [V] and
      electronics.nominalPower <= 5 [W]
    }
  }

  requirement def DataRetentionRequirement {
    subject memory : NonvolatileMemoryModule;

    require constraint {
      memory.storageCapacityPackets >= 500000
    }
  }

  satisfy PrimaryFunctionRequirement by PermanentDownholeGaugeSystem::continuousReservoirSurveillance;
  satisfy PressureMeasurementRequirement by QuartzPressureSensor::measurePressure;
  satisfy TemperatureMeasurementRequirement by PlatinumResistanceTemperatureSensor::measureTemperature;
  satisfy DownholeSurvivabilityRequirement by PressureHousing;
  satisfy PowerRequirement by DownholeElectronicsModule;
  satisfy DataRetentionRequirement by NonvolatileMemoryModule;
}