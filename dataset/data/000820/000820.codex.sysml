package VILIMitigationSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Pressure {
    :> scalarValues::Real;
    unit = "cmH2O";
  }

  attribute def Volume {
    :> scalarValues::Real;
    unit = "mL";
  }

  attribute def FlowRate {
    :> scalarValues::Real;
    unit = "L/min";
  }

  attribute def TimeDuration {
    :> scalarValues::Real;
    unit = "s";
  }

  attribute def RespiratoryRate {
    :> scalarValues::Real;
    unit = "breaths/min";
  }

  attribute def Compliance {
    :> scalarValues::Real;
    unit = "mL/cmH2O";
  }

  attribute def Fraction {
    :> scalarValues::Real;
    unit = "1";
  }

  attribute def Mass {
    :> scalarValues::Real;
    unit = "kg";
  }

  item def AirOxygenMixture {
    attribute fio2 : Fraction;
    attribute flow : FlowRate;
    attribute pressure : Pressure;
    attribute volume : Volume;
  }

  item def LungMechanicsData {
    attribute airwayPressure : Pressure;
    attribute plateauPressure : Pressure;
    attribute peep : Pressure;
    attribute tidalVolume : Volume;
    attribute drivingPressure : Pressure;
    attribute respiratoryRate : RespiratoryRate;
    attribute dynamicCompliance : Compliance;
    attribute oxygenSaturation : Fraction;
    attribute endTidalCO2 : Pressure;
  }

  item def VentilationCommand {
    attribute targetTidalVolume : Volume;
    attribute targetPressureLimit : Pressure;
    attribute peepSetpoint : Pressure;
    attribute fio2Setpoint : Fraction;
    attribute inspiratoryTime : TimeDuration;
    attribute respiratoryRateSetpoint : RespiratoryRate;
  }

  item def InjuryRiskAssessment {
    attribute volutraumaRisk : Fraction;
    attribute barotraumaRisk : Fraction;
    attribute atelectraumaRisk : Fraction;
    attribute biotraumaRisk : Fraction;
    attribute totalRisk : Fraction;
  }

  port def GasDeliveryPort {
    out deliveredGas : AirOxygenMixture;
    in returnedGas : AirOxygenMixture;
  }

  port def SensorDataPort {
    out measuredData : LungMechanicsData;
  }

  port def CommandPort {
    in command : VentilationCommand;
  }

  port def RiskOutputPort {
    out risk : InjuryRiskAssessment;
  }

  part def PatientLung {
    attribute predictedBodyWeight : Mass;
    attribute safeTidalVolumeLow : Volume;
    attribute safeTidalVolumeHigh : Volume;
    attribute currentCompliance : Compliance;
    attribute recruitedAlveolarFraction : Fraction;

    port airway : GasDeliveryPort;
    port monitoring : SensorDataPort;

    action updateLungMechanics {
      in delivered : AirOxygenMixture;
      out mechanics : LungMechanicsData;

      first start;
      then computeAirwayPressure;
      then computeCompliance;
      then publishMeasurements;
      then done;

      action computeAirwayPressure;
      action computeCompliance;
      action publishMeasurements;
    }
  }

  part def ProtectiveVentilatorController {
    attribute maxPlateauPressure : Pressure = 30.0;
    attribute maxDrivingPressure : Pressure = 15.0;
    attribute targetVolumePerKgLow : Real = 4.0;
    attribute targetVolumePerKgHigh : Real = 6.0;
    attribute minimumPeep : Pressure = 5.0;
    attribute maximumPeep : Pressure = 18.0;
    attribute maximumFiO2 : Fraction = 1.0;

    port sensed : SensorDataPort;
    port commandOut : CommandPort;
    port riskOut : RiskOutputPort;

    action calculateProtectiveSettings {
      in data : LungMechanicsData;
      in bodyWeight : Mass;
      out command : VentilationCommand;

      first start;
      then calculateTidalVolumeRange;
      then evaluateDrivingPressure;
      then adjustPEEP;
      then limitPlateauPressure;
      then outputCommand;
      then done;

      action calculateTidalVolumeRange;
      action evaluateDrivingPressure;
      action adjustPEEP;
      action limitPlateauPressure;
      action outputCommand;
    }

    action assessVILIRisk {
      in data : LungMechanicsData;
      out risk : InjuryRiskAssessment;

      first start;
      then evaluateVolutrauma;
      then evaluateBarotrauma;
      then evaluateAtelectrauma;
      then evaluateBiotrauma;
      then aggregateRisk;
      then done;

      action evaluateVolutrauma;
      action evaluateBarotrauma;
      action evaluateAtelectrauma;
      action evaluateBiotrauma;
      action aggregateRisk;
    }

    state def ControllerStateMachine {
      state Monitoring;
      state ProtectiveAdjustment;
      state Alarm;
      state Stabilized;

      initial then Monitoring;

      transition Monitoring_to_ProtectiveAdjustment
        first Monitoring
        accept when measuredData.drivingPressure > 15.0 or measuredData.plateauPressure > 30.0
        then ProtectiveAdjustment;

      transition ProtectiveAdjustment_to_Stabilized
        first ProtectiveAdjustment
        accept when measuredData.drivingPressure <= 15.0 and measuredData.plateauPressure <= 30.0
        then Stabilized;

      transition Stabilized_to_Monitoring
        first Stabilized
        accept after 30.0
        then Monitoring;

      transition Any_to_Alarm
        first Monitoring
        accept when measuredData.oxygenSaturation < 0.88
        then Alarm;

      transition Alarm_to_ProtectiveAdjustment
        first Alarm
        accept when measuredData.oxygenSaturation >= 0.90
        then ProtectiveAdjustment;
    }
  }

  part def GasBlender {
    attribute oxygenFractionSetpoint : Fraction;
    attribute airSupplyPressure : Pressure;
    attribute oxygenSupplyPressure : Pressure;

    port commandIn : CommandPort;
    port gasOut : GasDeliveryPort;

    action blendGas {
      in command : VentilationCommand;
      out mixture : AirOxygenMixture;

      first start;
      then regulateOxygenValve;
      then regulateAirValve;
      then verifyFiO2;
      then outputMixture;
      then done;

      action regulateOxygenValve;
      action regulateAirValve;
      action verifyFiO2;
      action outputMixture;
    }
  }

  part def InspiratoryExpiratoryValveSet {
    attribute inspiratoryValveOpening : Fraction;
    attribute expiratoryValveOpening : Fraction;
    attribute peepValveSetting : Pressure;

    port commandIn : CommandPort;
    port patientGasPort : GasDeliveryPort;

    action controlBreathCycle {
      in command : VentilationCommand;
      out delivered : AirOxygenMixture;

      first start;
      then openInspiratoryValve;
      then maintainInspiratoryLimit;
      then openExpiratoryValve;
      then maintainPEEP;
      then done;

      action openInspiratoryValve;
      action maintainInspiratoryLimit;
      action openExpiratoryValve;
      action maintainPEEP;
    }
  }

  part def LungProtectionMonitor {
    attribute samplingPeriod : TimeDuration = 0.02;
    attribute plateauHoldDuration : TimeDuration = 0.5;

    port patientInput : SensorDataPort;
    port processedOutput : SensorDataPort;

    action deriveMechanics {
      in raw : LungMechanicsData;
      out derived : LungMechanicsData;

      first start;
      then filterPressureSignal;
      then estimatePlateauPressure;
      then calculateDrivingPressure;
      then calculateDynamicCompliance;
      then publishDerivedData;
      then done;

      action filterPressureSignal;
      action estimatePlateauPressure;
      action calculateDrivingPressure;
      action calculateDynamicCompliance;
      action publishDerivedData;
    }
  }

  part def AlarmManager {
    attribute highRiskThreshold : Fraction = 0.75;
    attribute urgentRiskThreshold : Fraction = 0.90;

    port riskInput : RiskOutputPort;

    action issueClinicalAlerts {
      in risk : InjuryRiskAssessment;

      first start;
      then classifyRisk;
      then displayAlert;
      then recordEvent;
      then done;

      action classifyRisk;
      action displayAlert;
      action recordEvent;
    }
  }

  part def VILIMitigationVentilationSystem {
    attribute primaryFunction : String =
      "Provide lung-protective mechanical ventilation by continuously measuring respiratory mechanics, estimating ventilator-associated lung injury risk, and adjusting breath delivery to minimize volutrauma, barotrauma, atelectrauma, and biotrauma while maintaining gas exchange.";

    part patient : PatientLung {
      predictedBodyWeight = 70.0;
      safeTidalVolumeLow = 280.0;
      safeTidalVolumeHigh = 420.0;
      currentCompliance = 35.0;
      recruitedAlveolarFraction = 0.82;
    }

    part controller : ProtectiveVentilatorController;
    part blender : GasBlender;
    part valves : InspiratoryExpiratoryValveSet;
    part monitor : LungProtectionMonitor;
    part alarmManager : AlarmManager;

    connect blender.gasOut to valves.patientGasPort;
    connect valves.patientGasPort to patient.airway;
    connect patient.monitoring to monitor.patientInput;
    connect monitor.processedOutput to controller.sensed;
    connect controller.commandOut to blender.commandIn;
    connect controller.commandOut to valves.commandIn;
    connect controller.riskOut to alarmManager.riskInput;
  }

  requirement def MaintainProtectiveTidalVolume {
    subject system : VILIMitigationVentilationSystem;
    require constraint {
      system.controller.targetVolumePerKgLow >= 4.0 and
      system.controller.targetVolumePerKgHigh <= 6.0
    }
  }

  requirement def LimitPlateauPressure {
    subject system : VILIMitigationVentilationSystem;
    require constraint {
      system.controller.maxPlateauPressure <= 30.0
    }
  }

  requirement def LimitDrivingPressure {
    subject system : VILIMitigationVentilationSystem;
    require constraint {
      system.controller.maxDrivingPressure <= 15.0
    }
  }

  requirement def MaintainMinimumPEEP {
    subject system : VILIMitigationVentilationSystem;
    require constraint {
      system.controller.minimumPeep >= 5.0
    }
  }

  requirement def BoundPEEPAdjustment {
    subject system : VILIMitigationVentilationSystem;
    require constraint {
      system.controller.maximumPeep <= 18.0
    }
  }

  requirement def MonitorVILIRiskContinuously {
    subject system : VILIMitigationVentilationSystem;
    require constraint {
      system.monitor.samplingPeriod <= 0.05
    }
  }

  requirement def SupportOxygenation {
    subject system : VILIMitigationVentilationSystem;
    require constraint {
      system.controller.maximumFiO2 <= 1.0
    }
  }

  requirement def DetectHighInjuryRisk {
    subject system : VILIMitigationVentilationSystem;
    require constraint {
      system.alarmManager.highRiskThreshold <= 0.75
    }
  }

  satisfy MaintainProtectiveTidalVolume by VILIMitigationVentilationSystem.controller;
  satisfy LimitPlateauPressure by VILIMitigationVentilationSystem.controller;
  satisfy LimitDrivingPressure by VILIMitigationVentilationSystem.controller;
  satisfy MaintainMinimumPEEP by VILIMitigationVentilationSystem.controller;
  satisfy BoundPEEPAdjustment by VILIMitigationVentilationSystem.controller;
  satisfy MonitorVILIRiskContinuously by VILIMitigationVentilationSystem.monitor;
  satisfy SupportOxygenation by VILIMitigationVentilationSystem.blender;
  satisfy DetectHighInjuryRisk by VILIMitigationVentilationSystem.alarmManager;

}