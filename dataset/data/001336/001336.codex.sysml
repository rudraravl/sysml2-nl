package AirPollutionModel {

  value def Concentration {
    unit = "ug/m^3";
  }

  value def GasConcentration {
    unit = "ppm";
  }

  value def FlowRate {
    unit = "m^3/s";
  }

  value def Temperature {
    unit = "degC";
  }

  value def Humidity {
    unit = "%";
  }

  value def Percent {
    unit = "%";
  }

  value def TimeDuration {
    unit = "s";
  }

  item def AmbientAir {
    attribute pm25 : Concentration;
    attribute pm10 : Concentration;
    attribute nitrogenDioxide : GasConcentration;
    attribute sulfurDioxide : GasConcentration;
    attribute carbonMonoxide : GasConcentration;
    attribute ozone : GasConcentration;
    attribute temperature : Temperature;
    attribute relativeHumidity : Humidity;
  }

  item def CleanedAir {
    attribute pm25 : Concentration;
    attribute pm10 : Concentration;
    attribute nitrogenDioxide : GasConcentration;
    attribute ozone : GasConcentration;
  }

  item def AirQualityIndex {
    attribute value : Integer;
    attribute category : String;
  }

  item def PollutionAlert {
    attribute severity : String;
    attribute pollutant : String;
    attribute message : String;
  }

  item def MitigationCommand {
    attribute fanSpeed : Percent;
    attribute filtrationEnabled : Boolean;
    attribute notifyPublic : Boolean;
  }

  port def AirIntakePort {
    in item incomingAir : AmbientAir;
  }

  port def AirOutletPort {
    out item outgoingAir : CleanedAir;
  }

  port def AirSamplePort {
    in item airSample : AmbientAir;
  }

  port def MeasurementPort {
    out item measuredAir : AmbientAir;
    out item airQuality : AirQualityIndex;
  }

  port def CommandPort {
    in item command : MitigationCommand;
  }

  port def AlertPort {
    out item alert : PollutionAlert;
  }

  port def DataPort {
    out item airQuality : AirQualityIndex;
    out item measuredAir : AmbientAir;
  }

  part def ParticulateSensor {
    port sample : AirSamplePort;
    port measurement : MeasurementPort;

    attribute samplePeriod : TimeDuration = 5;
    attribute pm25Accuracy : Concentration = 2;
    attribute pm10Accuracy : Concentration = 5;

    action measureParticulates {
      in item sampledAir : AmbientAir;
      out item measuredAir : AmbientAir;
    }
  }

  part def GasSensor {
    port sample : AirSamplePort;
    port measurement : MeasurementPort;

    attribute no2Accuracy : GasConcentration = 0.02;
    attribute so2Accuracy : GasConcentration = 0.01;
    attribute coAccuracy : GasConcentration = 0.1;
    attribute ozoneAccuracy : GasConcentration = 0.01;

    action measureGases {
      in item sampledAir : AmbientAir;
      out item measuredAir : AmbientAir;
    }
  }

  part def AirQualityProcessor {
    port particulateInput : MeasurementPort;
    port gasInput : MeasurementPort;
    port commandOutput : CommandPort;
    port alertOutput : AlertPort;
    port dataOutput : DataPort;

    attribute hazardousAqiThreshold : Integer = 150;
    attribute unhealthyAqiThreshold : Integer = 100;

    action computeAirQuality {
      in item particulateData : AmbientAir;
      in item gasData : AmbientAir;
      out item aqi : AirQualityIndex;
    }

    action selectMitigation {
      in item aqi : AirQualityIndex;
      out item command : MitigationCommand;
    }

    action publishAlert {
      in item aqi : AirQualityIndex;
      out item alert : PollutionAlert;
    }
  }

  part def FiltrationUnit {
    port intake : AirIntakePort;
    port commandInput : CommandPort;
    port outlet : AirOutletPort;

    attribute ratedFlowRate : FlowRate = 12.0;
    attribute pm25RemovalEfficiency : Percent = 85;
    attribute pm10RemovalEfficiency : Percent = 90;
    attribute activatedCarbonEfficiency : Percent = 60;

    action filterAir {
      in item incomingAir : AmbientAir;
      in item command : MitigationCommand;
      out item cleanedAir : CleanedAir;
    }
  }

  part def VentilationFan {
    port commandInput : CommandPort;

    attribute minimumSpeed : Percent = 20;
    attribute maximumSpeed : Percent = 100;
    attribute currentSpeed : Percent;

    action adjustFlow {
      in item command : MitigationCommand;
      out attribute currentSpeed : Percent;
    }
  }

  part def PublicNotificationGateway {
    port alertInput : AlertPort;

    action notifyPopulation {
      in item alert : PollutionAlert;
    }
  }

  state def PollutionControlStates {
    entry action initializeMonitoring;

    state Off;
    state Monitoring;
    state Assessing;
    state Mitigating;
    state Alerting;
    state Fault;

    first Off;

    transition Off_to_Monitoring
      first Off
      then Monitoring;

    transition Monitoring_to_Assessing
      first Monitoring
      then Assessing;

    transition Assessing_to_Mitigating
      first Assessing
      then Mitigating
      if aqi.value >= 100;

    transition Assessing_to_Monitoring
      first Assessing
      then Monitoring
      if aqi.value < 100;

    transition Mitigating_to_Alerting
      first Mitigating
      then Alerting
      if aqi.value >= 150;

    transition Alerting_to_Monitoring
      first Alerting
      then Monitoring
      if aqi.value < 100;

    transition Monitoring_to_Fault
      first Monitoring
      then Fault
      if sensorHealth == false;
  }

  part def AirPollutionMonitoringAndMitigationSystem {
    port ambientAirIn : AirIntakePort;
    port cleanedAirOut : AirOutletPort;
    port publicAlertOut : AlertPort;
    port publicDataOut : DataPort;

    part particulateSensor : ParticulateSensor;
    part gasSensor : GasSensor;
    part processor : AirQualityProcessor;
    part filtrationUnit : FiltrationUnit;
    part ventilationFan : VentilationFan;
    part notificationGateway : PublicNotificationGateway;

    attribute primaryFunction : String =
      "Monitor polluted ambient air, assess pollution severity, reduce pollutant concentration when needed, and issue public health alerts.";

    attribute targetPm25Limit : Concentration = 35;
    attribute targetPm10Limit : Concentration = 150;
    attribute targetNo2Limit : GasConcentration = 0.10;
    attribute requiredAvailability : Percent = 99;

    state operatingState : PollutionControlStates;

    connect ambientAirIn to particulateSensor.sample;
    connect ambientAirIn to gasSensor.sample;
    connect particulateSensor.measurement to processor.particulateInput;
    connect gasSensor.measurement to processor.gasInput;
    connect processor.commandOutput to filtrationUnit.commandInput;
    connect processor.commandOutput to ventilationFan.commandInput;
    connect ambientAirIn to filtrationUnit.intake;
    connect filtrationUnit.outlet to cleanedAirOut;
    connect processor.alertOutput to notificationGateway.alertInput;
    connect processor.alertOutput to publicAlertOut;
    connect processor.dataOutput to publicDataOut;
  }

  requirement def DetectPollutionRequirement {
    subject system : AirPollutionMonitoringAndMitigationSystem;

    require constraint {
      system.particulateSensor.samplePeriod <= 10
    }
  }

  requirement def MitigateParticulateMatterRequirement {
    subject system : AirPollutionMonitoringAndMitigationSystem;

    require constraint {
      system.filtrationUnit.pm25RemovalEfficiency >= 80 and
      system.filtrationUnit.pm10RemovalEfficiency >= 85
    }
  }

  requirement def AlertPublicRequirement {
    subject system : AirPollutionMonitoringAndMitigationSystem;

    require constraint {
      system.processor.hazardousAqiThreshold == 150
    }
  }

  requirement def MaintainAirQualityRequirement {
    subject cleanedAir : CleanedAir;

    require constraint {
      cleanedAir.pm25 <= 35 and
      cleanedAir.pm10 <= 150 and
      cleanedAir.nitrogenDioxide <= 0.10
    }
  }

  requirement def SystemAvailabilityRequirement {
    subject system : AirPollutionMonitoringAndMitigationSystem;

    require constraint {
      system.requiredAvailability >= 99
    }
  }

  part airPollutionSystem : AirPollutionMonitoringAndMitigationSystem;

}