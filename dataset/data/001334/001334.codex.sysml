package AerogelThermalProtectionModel {

  import ScalarValues::*;
  import SI::*;

  value type Temperature :> Real {
    unit = "K";
  }

  value type TemperatureDifference :> Real {
    unit = "K";
  }

  value type Length :> Real {
    unit = "m";
  }

  value type Area :> Real {
    unit = "m^2";
  }

  value type Mass :> Real {
    unit = "kg";
  }

  value type Density :> Real {
    unit = "kg/m^3";
  }

  value type HeatRate :> Real {
    unit = "W";
  }

  value type HeatFlux :> Real {
    unit = "W/m^2";
  }

  value type ThermalConductivity :> Real {
    unit = "W/(m*K)";
  }

  value type SpecificHeat :> Real {
    unit = "J/(kg*K)";
  }

  value type Pressure :> Real {
    unit = "Pa";
  }

  value type Time :> Real {
    unit = "s";
  }

  value type Percent :> Real {
    unit = "%";
  }

  item def ThermalEnergy {
    attribute heatRate : HeatRate;
    attribute heatFlux : HeatFlux;
    attribute sourceTemperature : Temperature;
    attribute sinkTemperature : Temperature;
  }

  item def TemperatureSignal {
    attribute measuredTemperature : Temperature;
    attribute sampleTime : Time;
    attribute sensorHealth : Percent;
  }

  item def HealthStatus {
    attribute panelIntegrity : Percent;
    attribute moistureContent : Percent;
    attribute compressionLoad : Pressure;
    attribute safeToOperate : Boolean;
  }

  item def VentGas {
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute relativeHumidity : Percent;
  }

  port def ThermalSurfacePort {
    in item incidentHeat : ThermalEnergy;
    out item rejectedHeat : ThermalEnergy;
    attribute surfaceTemperature : Temperature;
  }

  port def PayloadThermalPort {
    out item leakageHeat : ThermalEnergy;
    attribute payloadInterfaceTemperature : Temperature;
  }

  port def DataPort {
    out item temperatureTelemetry : TemperatureSignal;
    out item healthTelemetry : HealthStatus;
  }

  port def VentPort {
    inout item purgeGas : VentGas;
  }

  constraint def ConductiveHeatTransfer {
    in k : ThermalConductivity;
    in a : Area;
    in deltaT : TemperatureDifference;
    in thickness : Length;
    out q : HeatRate;

    require q == k * a * deltaT / thickness;
  }

  constraint def ArealMass {
    in density : Density;
    in area : Area;
    in thickness : Length;
    out mass : Mass;

    require mass == density * area * thickness;
  }

  part def AerogelBlanket {
    attribute thickness : Length = 0.025;
    attribute exposedArea : Area = 2.4;
    attribute density : Density = 145.0;
    attribute thermalConductivityAt300K : ThermalConductivity = 0.014;
    attribute specificHeat : SpecificHeat = 1000.0;
    attribute hydrophobicity : Percent = 98.0;
    attribute maxServiceTemperature : Temperature = 923.0;
    attribute minimumCompressionIntegrity : Percent = 85.0;

    port hotFace : ThermalSurfacePort;
    port coldFace : PayloadThermalPort;

    constraint conductiveLimit : ConductiveHeatTransfer {
      in k = thermalConductivityAt300K;
      in a = exposedArea;
      in thickness = thickness;
    }

    constraint blanketMass : ArealMass {
      in density = density;
      in area = exposedArea;
      in thickness = thickness;
    }
  }

  part def MicroporousBarrierFilm {
    attribute thickness : Length = 0.00008;
    attribute vaporTransmissionRate : Real = 0.04;
    attribute emissivity : Percent = 82.0;
    attribute punctureIntegrity : Percent = 100.0;

    port outerSurface : ThermalSurfacePort;
    port innerSurface : ThermalSurfacePort;
  }

  part def CompositeFaceSheet {
    attribute thickness : Length = 0.0012;
    attribute exposedArea : Area = 2.4;
    attribute density : Density = 1600.0;
    attribute thermalConductivity : ThermalConductivity = 0.32;
    attribute allowableTemperature : Temperature = 473.0;

    port environmentSide : ThermalSurfacePort;
    port aerogelSide : ThermalSurfacePort;
  }

  part def EdgeSeal {
    attribute sealLength : Length = 6.4;
    attribute leakageRate : Real = 0.0002;
    attribute maxSealTemperature : Temperature = 423.0;
    attribute moistureIngressResistance : Percent = 99.5;

    port sealVent : VentPort;
  }

  part def TemperatureSensor {
    attribute accuracy : TemperatureDifference = 0.5;
    attribute samplePeriod : Time = 1.0;
    attribute measuredTemperature : Temperature;
    attribute operational : Boolean = true;

    port sensedSurface : ThermalSurfacePort;
    port telemetry : DataPort;
  }

  part def HealthMonitor {
    attribute minimumPanelIntegrity : Percent = 90.0;
    attribute maximumMoistureContent : Percent = 5.0;
    attribute maximumCompressionLoad : Pressure = 35000.0;
    attribute safeToOperate : Boolean;

    port inputData : DataPort;
    port outputData : DataPort;
  }

  part def ThermalControlController {
    attribute highTemperatureLimit : Temperature = 333.0;
    attribute warningTemperatureLimit : Temperature = 323.0;
    attribute shutdownTemperatureLimit : Temperature = 343.0;
    attribute commandedSafeMode : Boolean = false;

    port telemetryInput : DataPort;
    port statusOutput : DataPort;

    action evaluateThermalCondition {
      in currentTemperature : Temperature;
      in panelIntegrity : Percent;
      out safeModeCommand : Boolean;

      if currentTemperature >= shutdownTemperatureLimit then
        safeModeCommand = true;
      else if panelIntegrity < 90.0 then
        safeModeCommand = true;
      else
        safeModeCommand = false;
      end;
    }

    state def ControllerStateMachine {
      state Initializing;
      state Monitoring;
      state Warning;
      state SafeMode;
      state Fault;

      transition first Initializing;
      transition Initializing_to_Monitoring
        first Initializing then Monitoring;

      transition Monitoring_to_Warning
        first Monitoring then Warning
        if telemetryInput.temperatureTelemetry.measuredTemperature >= warningTemperatureLimit;

      transition Warning_to_Monitoring
        first Warning then Monitoring
        if telemetryInput.temperatureTelemetry.measuredTemperature < warningTemperatureLimit;

      transition Warning_to_SafeMode
        first Warning then SafeMode
        if telemetryInput.temperatureTelemetry.measuredTemperature >= shutdownTemperatureLimit;

      transition Monitoring_to_Fault
        first Monitoring then Fault
        if telemetryInput.healthTelemetry.safeToOperate == false;

      transition Fault_to_SafeMode
        first Fault then SafeMode;

      entry action Initializing {
        commandedSafeMode = false;
      }

      entry action SafeMode {
        commandedSafeMode = true;
      }
    }
  }

  part def AerogelThermalProtectionPanel {
    attribute panelArea : Area = 2.4;
    attribute totalThickness : Length = 0.029;
    attribute maximumAllowedHeatLeak : HeatRate = 8.0;
    attribute nominalHotSideTemperature : Temperature = 393.0;
    attribute nominalColdSideTemperature : Temperature = 298.0;
    attribute designPressureLoad : Pressure = 25000.0;
    attribute primaryFunction : String =
      "Limit heat transfer from a hot external environment to a protected payload using a lightweight silica aerogel insulation core.";

    port externalThermalInterface : ThermalSurfacePort;
    port payloadThermalInterface : PayloadThermalPort;
    port purgeInterface : VentPort;
    port diagnosticInterface : DataPort;

    part outerFaceSheet : CompositeFaceSheet;
    part outerBarrier : MicroporousBarrierFilm;
    part aerogelCore : AerogelBlanket;
    part innerBarrier : MicroporousBarrierFilm;
    part edgeSeal : EdgeSeal;
    part hotSideSensor : TemperatureSensor;
    part coldSideSensor : TemperatureSensor;
    part monitor : HealthMonitor;
    part controller : ThermalControlController;

    connect externalThermalInterface to outerFaceSheet.environmentSide;
    connect outerFaceSheet.aerogelSide to outerBarrier.outerSurface;
    connect outerBarrier.innerSurface to aerogelCore.hotFace;
    connect aerogelCore.coldFace to innerBarrier.innerSurface;
    connect innerBarrier.outerSurface to payloadThermalInterface;
    connect purgeInterface to edgeSeal.sealVent;

    connect hotSideSensor.sensedSurface to outerFaceSheet.environmentSide;
    connect coldSideSensor.sensedSurface to innerBarrier.outerSurface;
    connect hotSideSensor.telemetry to monitor.inputData;
    connect coldSideSensor.telemetry to monitor.inputData;
    connect monitor.outputData to controller.telemetryInput;
    connect controller.statusOutput to diagnosticInterface;

    constraint heatLeakRequirement : ConductiveHeatTransfer {
      in k = aerogelCore.thermalConductivityAt300K;
      in a = aerogelCore.exposedArea;
      in deltaT = nominalHotSideTemperature - nominalColdSideTemperature;
      in thickness = aerogelCore.thickness;
    }

    state def PanelLifecycle {
      state Stored;
      state Installed;
      state Conditioning;
      state Operating;
      state Degraded;
      state SafeShutdown;
      state Removed;

      transition first Stored;
      transition Stored_to_Installed first Stored then Installed;
      transition Installed_to_Conditioning first Installed then Conditioning;
      transition Conditioning_to_Operating first Conditioning then Operating;

      transition Operating_to_Degraded
        first Operating then Degraded
        if monitor.outputData.healthTelemetry.panelIntegrity < 90.0;

      transition Operating_to_SafeShutdown
        first Operating then SafeShutdown
        if controller.commandedSafeMode == true;

      transition Degraded_to_SafeShutdown
        first Degraded then SafeShutdown
        if monitor.outputData.healthTelemetry.safeToOperate == false;

      transition SafeShutdown_to_Removed first SafeShutdown then Removed;

      entry action Conditioning {
        purgeInterface.purgeGas.pressure = 101325.0;
        purgeInterface.purgeGas.relativeHumidity = 2.0;
      }

      entry action Operating {
        controller.commandedSafeMode = false;
      }

      entry action SafeShutdown {
        controller.commandedSafeMode = true;
      }
    }
  }

  part def ProtectedPayloadCompartment {
    attribute allowableTemperatureMin : Temperature = 293.0;
    attribute allowableTemperatureMax : Temperature = 333.0;
    attribute protectedVolume : Real = 0.85;
    attribute internalHeatDissipation : HeatRate = 25.0;

    port thermalBoundary : PayloadThermalPort;
    port healthData : DataPort;
  }

  part def HotExternalEnvironment {
    attribute peakAmbientTemperature : Temperature = 393.0;
    attribute nominalAmbientTemperature : Temperature = 363.0;
    attribute externalConvectiveHeatFlux : HeatFlux = 850.0;
    attribute solarEquivalentHeatFlux : HeatFlux = 500.0;

    port thermalExposure : ThermalSurfacePort;
  }

  part def AerogelInsulatedPayloadSystem {
    attribute missionDuration : Time = 28800.0;
    attribute permittedPayloadTemperature : Temperature = 333.0;
    attribute requiredHeatLeakLimit : HeatRate = 8.0;

    part environment : HotExternalEnvironment;
    part thermalProtectionPanel : AerogelThermalProtectionPanel;
    part payloadCompartment : ProtectedPayloadCompartment;

    port systemDiagnosticPort : DataPort;

    connect environment.thermalExposure to thermalProtectionPanel.externalThermalInterface;
    connect thermalProtectionPanel.payloadThermalInterface to payloadCompartment.thermalBoundary;
    connect thermalProtectionPanel.diagnosticInterface to payloadCompartment.healthData;
    connect thermalProtectionPanel.diagnosticInterface to systemDiagnosticPort;

    action protectPayloadFromHeat {
      in externalTemperature : Temperature;
      in payloadTemperature : Temperature;
      out heatLeak : HeatRate;
      out safeMode : Boolean;

      heatLeak =
        thermalProtectionPanel.aerogelCore.thermalConductivityAt300K *
        thermalProtectionPanel.aerogelCore.exposedArea *
        (externalTemperature - payloadTemperature) /
        thermalProtectionPanel.aerogelCore.thickness;

      safeMode = payloadTemperature >= permittedPayloadTemperature;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : AerogelInsulatedPayloadSystem;

    doc
      /* The system shall use an aerogel-based thermal protection panel as its primary means of reducing heat transfer from a hot external environment into a protected payload compartment. */

    require constraint {
      system.thermalProtectionPanel.primaryFunction ==
      "Limit heat transfer from a hot external environment to a protected payload using a lightweight silica aerogel insulation core.";
    }
  }

  requirement def HeatLeakRequirement {
    subject system : AerogelInsulatedPayloadSystem;

    require constraint {
      system.thermalProtectionPanel.heatLeakRequirement.q <= system.requiredHeatLeakLimit;
    }
  }

  requirement def PayloadTemperatureRequirement {
    subject system : AerogelInsulatedPayloadSystem;

    require constraint {
      system.payloadCompartment.thermalBoundary.payloadInterfaceTemperature
        <= system.payloadCompartment.allowableTemperatureMax;
    }
  }

  requirement def LightweightInsulationRequirement {
    subject panel : AerogelThermalProtectionPanel;

    require constraint {
      panel.aerogelCore.blanketMass.mass <= 9.0;
    }
  }

  requirement def MoistureProtectionRequirement {
    subject panel : AerogelThermalProtectionPanel;

    require constraint {
      panel.edgeSeal.moistureIngressResistance >= 99.0 and
      panel.aerogelCore.hydrophobicity >= 95.0;
    }
  }

  requirement def HealthMonitoringRequirement {
    subject panel : AerogelThermalProtectionPanel;

    require constraint {
      panel.monitor.outputData.healthTelemetry.safeToOperate == true
      implies panel.controller.commandedSafeMode == false;
    }
  }

  satisfy PrimaryFunctionRequirement by AerogelInsulatedPayloadSystem;
  satisfy HeatLeakRequirement by AerogelThermalProtectionPanel;
  satisfy PayloadTemperatureRequirement by ProtectedPayloadCompartment;
  satisfy LightweightInsulationRequirement by AerogelBlanket;
  satisfy MoistureProtectionRequirement by EdgeSeal;
  satisfy HealthMonitoringRequirement by ThermalControlController;
}