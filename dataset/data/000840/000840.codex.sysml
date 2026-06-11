package AffinityLawPumpSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value type RotationalSpeed specializes Real { unit = "rpm"; }
  value type VolumetricFlowRate specializes Real { unit = "m^3/h"; }
  value type PressureHead specializes Real { unit = "m"; }
  value type HydraulicPower specializes Real { unit = "kW"; }
  value type Efficiency specializes Real { unit = "1"; }
  value type Percent specializes Real { unit = "%"; }
  value type Temperature specializes Real { unit = "degC"; }

  item def Water {
    attribute density : Real = 998.0;
    attribute temperature : Temperature;
  }

  item def ElectricalPower {
    attribute voltage : Real { unit = "V"; }
    attribute current : Real { unit = "A"; }
    attribute frequency : Real { unit = "Hz"; }
    attribute power : HydraulicPower;
  }

  item def PumpCommand {
    attribute requestedFlow : VolumetricFlowRate;
    attribute commandedSpeed : RotationalSpeed;
    attribute enable : Boolean;
  }

  port def FluidPort {
    inout fluid : Water;
    attribute flowRate : VolumetricFlowRate;
    attribute head : PressureHead;
  }

  port def PowerPort {
    in powerIn : ElectricalPower;
  }

  port def CommandPort {
    in command : PumpCommand;
  }

  port def TelemetryPort {
    out measuredFlow : VolumetricFlowRate;
    out measuredHead : PressureHead;
    out measuredSpeed : RotationalSpeed;
    out measuredPower : HydraulicPower;
  }

  part def VariableSpeedCentrifugalPumpSystem {
    doc /* Primary function: regulate water flow through a hydraulic network by changing centrifugal pump speed according to pump affinity laws. */

    attribute referenceSpeed : RotationalSpeed = 1800.0;
    attribute referenceFlow : VolumetricFlowRate = 120.0;
    attribute referenceHead : PressureHead = 48.0;
    attribute referencePower : HydraulicPower = 18.0;
    attribute minSpeed : RotationalSpeed = 600.0;
    attribute maxSpeed : RotationalSpeed = 3600.0;
    attribute targetFlow : VolumetricFlowRate;
    attribute deliveredFlow : VolumetricFlowRate;
    attribute deliveredHead : PressureHead;
    attribute consumedPower : HydraulicPower;

    port inlet : FluidPort;
    port outlet : FluidPort;
    port gridPower : PowerPort;
    port operatorCommand : CommandPort;
    port telemetry : TelemetryPort;

    part controller : AffinityLawController;
    part drive : VariableFrequencyDrive;
    part motor : InductionMotor;
    part pump : CentrifugalPump;
    part suctionSensor : FlowPressureSensor;
    part dischargeSensor : FlowPressureSensor;
    part pipingLoad : HydraulicLoad;

    connect operatorCommand to controller.commandIn;
    connect controller.driveCommand to drive.commandIn;
    connect gridPower to drive.powerIn;
    connect drive.motorPowerOut to motor.powerIn;
    connect motor.shaftOut to pump.shaftIn;
    connect inlet to suctionSensor.fluidIn;
    connect suctionSensor.fluidOut to pump.suction;
    connect pump.discharge to dischargeSensor.fluidIn;
    connect dischargeSensor.fluidOut to pipingLoad.inlet;
    connect pipingLoad.outlet to outlet;
    connect suctionSensor.telemetry to controller.suctionFeedback;
    connect dischargeSensor.telemetry to controller.dischargeFeedback;
    connect motor.telemetry to controller.speedFeedback;
    connect controller.telemetryOut to telemetry;

    constraint affinityFlowLaw {
      deliveredFlow == referenceFlow * pump.actualSpeed / referenceSpeed;
    }

    constraint affinityHeadLaw {
      deliveredHead == referenceHead * (pump.actualSpeed / referenceSpeed)^2;
    }

    constraint affinityPowerLaw {
      consumedPower == referencePower * (pump.actualSpeed / referenceSpeed)^3;
    }

    perform regulateFlow;
    exhibit operatingStates;
  }

  part def AffinityLawController {
    attribute requestedFlow : VolumetricFlowRate;
    attribute estimatedSpeed : RotationalSpeed;
    attribute flowError : VolumetricFlowRate;
    attribute speedLimitHigh : RotationalSpeed = 3600.0;
    attribute speedLimitLow : RotationalSpeed = 600.0;

    port commandIn : CommandPort;
    port suctionFeedback : TelemetryPort;
    port dischargeFeedback : TelemetryPort;
    port speedFeedback : TelemetryPort;
    port driveCommand : CommandPort;
    port telemetryOut : TelemetryPort;

    action computeSpeedFromAffinityLaw {
      in referenceSpeed : RotationalSpeed;
      in referenceFlow : VolumetricFlowRate;
      in targetFlow : VolumetricFlowRate;
      out speedSetpoint : RotationalSpeed;

      constraint proportionalFlow {
        speedSetpoint == referenceSpeed * targetFlow / referenceFlow;
      }
    }

    action limitSpeedCommand {
      in rawSpeed : RotationalSpeed;
      out limitedSpeed : RotationalSpeed;

      first start;
      then decide;
      if rawSpeed > speedLimitHigh then highLimit;
      if rawSpeed < speedLimitLow then lowLimit;
      else nominalLimit;

      action highLimit {
        limitedSpeed = speedLimitHigh;
      }

      action lowLimit {
        limitedSpeed = speedLimitLow;
      }

      action nominalLimit {
        limitedSpeed = rawSpeed;
      }
    }
  }

  part def VariableFrequencyDrive {
    attribute outputFrequency : Real { unit = "Hz"; }
    attribute outputVoltage : Real { unit = "V"; }
    attribute efficiency : Efficiency = 0.97;

    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port motorPowerOut : PowerPort;

    constraint frequencySpeedRelation {
      outputFrequency >= 20.0 and outputFrequency <= 120.0;
    }
  }

  part def InductionMotor {
    attribute ratedPower : HydraulicPower = 30.0;
    attribute ratedSpeed : RotationalSpeed = 3600.0;
    attribute actualSpeed : RotationalSpeed;
    attribute motorEfficiency : Efficiency = 0.94;

    port powerIn : PowerPort;
    port shaftOut : MechanicalShaftPort;
    port telemetry : TelemetryPort;
  }

  port def MechanicalShaftPort {
    out shaftSpeed : RotationalSpeed;
    out torque : Real { unit = "N*m"; }
  }

  part def CentrifugalPump {
    attribute actualSpeed : RotationalSpeed;
    attribute impellerDiameter : Real { unit = "m" } = 0.28;
    attribute hydraulicEfficiency : Efficiency = 0.82;
    attribute generatedFlow : VolumetricFlowRate;
    attribute generatedHead : PressureHead;
    attribute absorbedPower : HydraulicPower;

    port shaftIn : MechanicalShaftPort;
    port suction : FluidPort;
    port discharge : FluidPort;

    constraint pumpFlowAffinity {
      generatedFlow == 120.0 * actualSpeed / 1800.0;
    }

    constraint pumpHeadAffinity {
      generatedHead == 48.0 * (actualSpeed / 1800.0)^2;
    }

    constraint pumpPowerAffinity {
      absorbedPower == 18.0 * (actualSpeed / 1800.0)^3;
    }
  }

  part def FlowPressureSensor {
    attribute flowAccuracy : Percent = 1.0;
    attribute pressureAccuracy : Percent = 0.5;
    attribute measuredFlow : VolumetricFlowRate;
    attribute measuredHead : PressureHead;

    port fluidIn : FluidPort;
    port fluidOut : FluidPort;
    port telemetry : TelemetryPort;
  }

  part def HydraulicLoad {
    attribute staticHead : PressureHead = 15.0;
    attribute resistanceCoefficient : Real = 0.0023;
    attribute requiredHead : PressureHead;

    port inlet : FluidPort;
    port outlet : FluidPort;

    constraint systemCurve {
      requiredHead == staticHead + resistanceCoefficient * inlet.flowRate^2;
    }
  }

  action def regulateFlow {
    in targetFlow : VolumetricFlowRate;
    out deliveredFlow : VolumetricFlowRate;

    first receiveCommand;
    then calculateAffinitySpeed;
    then applySpeedLimit;
    then energizeDrive;
    then acceleratePump;
    then measureDischarge;
    then compareFlow;
    then adjustSpeed;

    action receiveCommand {
      targetFlow = 100.0;
    }

    action calculateAffinitySpeed {
      estimatedSpeed = 1800.0 * targetFlow / 120.0;
    }

    action applySpeedLimit {
      if estimatedSpeed > 3600.0 then estimatedSpeed = 3600.0;
      if estimatedSpeed < 600.0 then estimatedSpeed = 600.0;
    }

    action energizeDrive;
    action acceleratePump;
    action measureDischarge;
    action compareFlow;
    action adjustSpeed;
  }

  state def PumpOperatingStates {
    state Off;
    state Standby;
    state Starting;
    state Regulating;
    state HighDemand;
    state Fault;
    state Shutdown;

    initial then Off;

    transition Off_to_Standby
      first Off
      accept PowerAvailable
      then Standby;

    transition Standby_to_Starting
      first Standby
      accept EnableCommand
      then Starting;

    transition Starting_to_Regulating
      first Starting
      if speedFeedbackValid
      then Regulating;

    transition Regulating_to_HighDemand
      first Regulating
      if targetFlow > 0.85 * 240.0
      then HighDemand;

    transition HighDemand_to_Regulating
      first HighDemand
      if targetFlow <= 0.85 * 240.0
      then Regulating;

    transition Regulating_to_Fault
      first Regulating
      if measuredHead < 0.8 * requiredHead or measuredSpeed > 3600.0
      then Fault;

    transition HighDemand_to_Fault
      first HighDemand
      if consumedPower > 30.0
      then Fault;

    transition Fault_to_Shutdown
      first Fault
      accept ResetRejected
      then Shutdown;

    transition Shutdown_to_Off
      first Shutdown
      accept PumpStopped
      then Off;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : VariableSpeedCentrifugalPumpSystem;

    require constraint {
      system.deliveredFlow == system.targetFlow
    }

    doc /* The system shall provide commanded water flow by varying centrifugal pump speed using affinity-law relationships. */
  }

  requirement def FlowAffinityRequirement {
    subject system : VariableSpeedCentrifugalPumpSystem;

    require constraint {
      system.deliveredFlow / system.referenceFlow ==
      system.pump.actualSpeed / system.referenceSpeed
    }
  }

  requirement def HeadAffinityRequirement {
    subject system : VariableSpeedCentrifugalPumpSystem;

    require constraint {
      system.deliveredHead / system.referenceHead ==
      (system.pump.actualSpeed / system.referenceSpeed)^2
    }
  }

  requirement def PowerAffinityRequirement {
    subject system : VariableSpeedCentrifugalPumpSystem;

    require constraint {
      system.consumedPower / system.referencePower ==
      (system.pump.actualSpeed / system.referenceSpeed)^3
    }
  }

  requirement def SpeedLimitRequirement {
    subject system : VariableSpeedCentrifugalPumpSystem;

    require constraint {
      system.pump.actualSpeed >= system.minSpeed and
      system.pump.actualSpeed <= system.maxSpeed
    }
  }

  requirement def HydraulicDemandRequirement {
    subject system : VariableSpeedCentrifugalPumpSystem;

    require constraint {
      system.deliveredHead >= system.pipingLoad.requiredHead
    }
  }

  requirement def EfficiencyRequirement {
    subject system : VariableSpeedCentrifugalPumpSystem;

    require constraint {
      system.drive.efficiency >= 0.95 and
      system.motor.motorEfficiency >= 0.90 and
      system.pump.hydraulicEfficiency >= 0.75
    }
  }

  part affinityControlledPumpSystem : VariableSpeedCentrifugalPumpSystem {
    attribute targetFlow = 100.0;
    attribute deliveredFlow = 100.0;
    attribute deliveredHead = 33.33;
    attribute consumedPower = 10.42;

    ref requirement primaryFunction : PrimaryFunctionRequirement;
    ref requirement flowAffinity : FlowAffinityRequirement;
    ref requirement headAffinity : HeadAffinityRequirement;
    ref requirement powerAffinity : PowerAffinityRequirement;
    ref requirement speedLimit : SpeedLimitRequirement;
    ref requirement hydraulicDemand : HydraulicDemandRequirement;
    ref requirement efficiency : EfficiencyRequirement;

    satisfy primaryFunction by affinityControlledPumpSystem;
    satisfy flowAffinity by affinityControlledPumpSystem;
    satisfy headAffinity by affinityControlledPumpSystem;
    satisfy powerAffinity by affinityControlledPumpSystem;
    satisfy speedLimit by affinityControlledPumpSystem;
    satisfy hydraulicDemand by affinityControlledPumpSystem;
    satisfy efficiency by affinityControlledPumpSystem;
  }

}