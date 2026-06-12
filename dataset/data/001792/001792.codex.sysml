package HorsepowerBasedSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Horsepower :> ISQ::power {
    unit = "hp";
  }

  attribute def RevolutionsPerMinute {
    unit = "rpm";
  }

  attribute def NewtonMeter :> ISQ::torque {
    unit = "N*m";
  }

  attribute def Percent {
    unit = "%";
  }

  attribute def Celsius :> ISQ::temperature {
    unit = "degC";
  }

  item def Fuel;
  item def Air;
  item def ExhaustGas;
  item def MechanicalRotation;
  item def ControlSignal;
  item def ThermalEnergy;
  item def DiagnosticMessage;

  port def FuelInlet {
    in item fuel : Fuel;
  }

  port def AirInlet {
    in item air : Air;
  }

  port def ExhaustOutlet {
    out item exhaust : ExhaustGas;
  }

  port def RotationOutlet {
    out item shaftPower : MechanicalRotation;
  }

  port def ControlPort {
    in item command : ControlSignal;
    out item status : DiagnosticMessage;
  }

  port def CoolingPort {
    out item wasteHeat : ThermalEnergy;
  }

  part def HorsepowerSystem {
    attribute ratedPower : Horsepower = 150 [hp];
    attribute maximumPower : Horsepower = 185 [hp];
    attribute idleSpeed : RevolutionsPerMinute = 750 [rpm];
    attribute ratedSpeed : RevolutionsPerMinute = 5200 [rpm];
    attribute peakTorque : NewtonMeter = 280 [N*m];
    attribute efficiency : Percent = 34 [%];
    attribute coolantTemperature : Celsius;

    port fuelInput : FuelInlet;
    port airInput : AirInlet;
    port exhaustOutput : ExhaustOutlet;
    port powerOutput : RotationOutlet;
    port controls : ControlPort;
    port cooling : CoolingPort;

    part fuelSubsystem : FuelDeliverySubsystem;
    part airSubsystem : AirInductionSubsystem;
    part combustionAssembly : CombustionPowerAssembly;
    part crankshaftAssembly : RotatingPowerOutputAssembly;
    part controller : PowerController;
    part coolingSubsystem : CoolingSubsystem;
    part diagnostics : DiagnosticSubsystem;

    connect fuelInput to fuelSubsystem.fuelInput;
    connect airInput to airSubsystem.airInput;
    connect fuelSubsystem.meteredFuelOutput to combustionAssembly.fuelInput;
    connect airSubsystem.meteredAirOutput to combustionAssembly.airInput;
    connect combustionAssembly.exhaustOutput to exhaustOutput;
    connect combustionAssembly.pistonForceOutput to crankshaftAssembly.forceInput;
    connect crankshaftAssembly.rotationOutput to powerOutput;
    connect controls to controller.externalControl;
    connect controller.fuelCommand to fuelSubsystem.controlInput;
    connect controller.airCommand to airSubsystem.controlInput;
    connect controller.sparkCommand to combustionAssembly.controlInput;
    connect combustionAssembly.heatOutput to coolingSubsystem.heatInput;
    connect coolingSubsystem.coolingOutput to cooling;
    connect diagnostics.systemStatus to controls.status;

    perform action produceRegulatedHorsepower;
    exhibit state horsepowerSystemOperatingState;
  }

  part def FuelDeliverySubsystem {
    attribute fuelPressure : ISQ::pressure = 350 [kPa];
    attribute fuelFlowRate : ISQ::massFlowRate;
    attribute injectorDutyCycle : Percent;

    port fuelInput : FuelInlet;
    port meteredFuelOutput {
      out item meteredFuel : Fuel;
    }
    port controlInput {
      in item fuelCommand : ControlSignal;
    }
  }

  part def AirInductionSubsystem {
    attribute manifoldPressure : ISQ::pressure;
    attribute airMassFlowRate : ISQ::massFlowRate;
    attribute throttlePosition : Percent;

    port airInput : AirInlet;
    port meteredAirOutput {
      out item meteredAir : Air;
    }
    port controlInput {
      in item airCommand : ControlSignal;
    }
  }

  part def CombustionPowerAssembly {
    attribute cylinderCount : Integer = 4;
    attribute compressionRatio : Real = 10.5;
    attribute combustionTemperature : Celsius;
    attribute indicatedPower : Horsepower;

    port fuelInput {
      in item fuel : Fuel;
    }
    port airInput {
      in item air : Air;
    }
    port controlInput {
      in item sparkCommand : ControlSignal;
    }
    port pistonForceOutput {
      out item reciprocatingForce : MechanicalRotation;
    }
    port exhaustOutput : ExhaustOutlet;
    port heatOutput {
      out item rejectedHeat : ThermalEnergy;
    }
  }

  part def RotatingPowerOutputAssembly {
    attribute shaftSpeed : RevolutionsPerMinute;
    attribute shaftTorque : NewtonMeter;
    attribute deliveredPower : Horsepower;

    port forceInput {
      in item reciprocatingForce : MechanicalRotation;
    }
    port rotationOutput : RotationOutlet;
  }

  part def PowerController {
    attribute requestedPower : Horsepower;
    attribute commandedThrottle : Percent;
    attribute commandedFuelRate : ISQ::massFlowRate;
    attribute overspeedLimit : RevolutionsPerMinute = 6000 [rpm];

    port externalControl : ControlPort;
    port fuelCommand {
      out item fuelCommand : ControlSignal;
    }
    port airCommand {
      out item airCommand : ControlSignal;
    }
    port sparkCommand {
      out item sparkCommand : ControlSignal;
    }
  }

  part def CoolingSubsystem {
    attribute coolantTemperature : Celsius;
    attribute heatRejectionRate : ISQ::power;

    port heatInput {
      in item wasteHeat : ThermalEnergy;
    }
    port coolingOutput : CoolingPort;
  }

  part def DiagnosticSubsystem {
    attribute faultActive : Boolean;
    attribute measuredPower : Horsepower;
    attribute measuredSpeed : RevolutionsPerMinute;
    attribute measuredTemperature : Celsius;

    port systemStatus {
      out item status : DiagnosticMessage;
    }
  }

  action def ProduceRegulatedHorsepower {
    in item fuel : Fuel;
    in item air : Air;
    in item command : ControlSignal;
    out item rotation : MechanicalRotation;
    out item exhaust : ExhaustGas;
    out item heat : ThermalEnergy;

    attribute targetPower : Horsepower;
    attribute actualPower : Horsepower;
    attribute shaftSpeed : RevolutionsPerMinute;
    attribute shaftTorque : NewtonMeter;

    first start;
    then meterAirFuel;
    then combustMixture;
    then convertLinearForceToTorque;
    then regulateOutput;
    then deliverHorsepower;

    action start;
    action meterAirFuel;
    action combustMixture;
    action convertLinearForceToTorque;
    action regulateOutput;
    action deliverHorsepower;
  }

  state def HorsepowerSystemOperatingState {
    entry action initializeController;

    state Off;
    state Starting;
    state Idle;
    state PowerProducing;
    state OverloadProtected;
    state CoolingDown;
    state Faulted;

    initial then Off;

    transition Off_to_Starting
      first Off
      accept StartCommand
      then Starting;

    transition Starting_to_Idle
      first Starting
      accept StableCombustionDetected
      then Idle;

    transition Idle_to_PowerProducing
      first Idle
      accept PowerRequest
      then PowerProducing;

    transition PowerProducing_to_Idle
      first PowerProducing
      accept ZeroPowerRequest
      then Idle;

    transition PowerProducing_to_OverloadProtected
      first PowerProducing
      accept ExcessPowerDemand
      then OverloadProtected;

    transition OverloadProtected_to_PowerProducing
      first OverloadProtected
      accept DemandWithinRating
      then PowerProducing;

    transition PowerProducing_to_CoolingDown
      first PowerProducing
      accept StopCommand
      then CoolingDown;

    transition Idle_to_CoolingDown
      first Idle
      accept StopCommand
      then CoolingDown;

    transition CoolingDown_to_Off
      first CoolingDown
      accept SafeTemperatureReached
      then Off;

    transition Any_to_Faulted
      first Off
      accept CriticalFault
      then Faulted;

    transition Faulted_to_Off
      first Faulted
      accept FaultReset
      then Off;

    action initializeController;
  }

  requirement def PrimaryFunctionRequirement {
    subject horsepowerSystem : HorsepowerSystem;

    doc /* The system shall convert input fuel and air into regulated rotational mechanical power expressed in horsepower for use by an external mechanical load. */

    require constraint {
      horsepowerSystem.ratedPower >= 150 [hp]
    }
  }

  requirement def RatedOutputRequirement {
    subject horsepowerSystem : HorsepowerSystem;

    doc /* The system shall continuously deliver at least 150 horsepower at rated speed without exceeding thermal limits. */

    require constraint {
      horsepowerSystem.ratedPower == 150 [hp] and
      horsepowerSystem.ratedSpeed == 5200 [rpm]
    }
  }

  requirement def PeakOutputRequirement {
    subject horsepowerSystem : HorsepowerSystem;

    doc /* The system shall provide short-duration peak output of 185 horsepower for acceleration or transient load response. */

    require constraint {
      horsepowerSystem.maximumPower >= 185 [hp]
    }
  }

  requirement def TorqueRequirement {
    subject horsepowerSystem : HorsepowerSystem;

    doc /* The system shall provide sufficient shaft torque to support high-load operation below rated speed. */

    require constraint {
      horsepowerSystem.peakTorque >= 280 [N*m]
    }
  }

  requirement def EfficiencyRequirement {
    subject horsepowerSystem : HorsepowerSystem;

    doc /* The system shall convert chemical energy to useful shaft power with a minimum peak efficiency of 34 percent. */

    require constraint {
      horsepowerSystem.efficiency >= 34 [%]
    }
  }

  requirement def ProtectionRequirement {
    subject horsepowerSystem : HorsepowerSystem;

    doc /* The system shall reduce commanded output when demanded power exceeds the rated continuous horsepower envelope. */
  }

  requirement def DiagnosticRequirement {
    subject horsepowerSystem : HorsepowerSystem;

    doc /* The system shall report operating power, shaft speed, temperature, and active fault status through its control port. */
  }

  part horsepowerPlant : HorsepowerSystem {
    attribute ratedPower = 150 [hp];
    attribute maximumPower = 185 [hp];
    attribute idleSpeed = 750 [rpm];
    attribute ratedSpeed = 5200 [rpm];
    attribute peakTorque = 280 [N*m];
    attribute efficiency = 34 [%];

    satisfy PrimaryFunctionRequirement by horsepowerPlant;
    satisfy RatedOutputRequirement by horsepowerPlant;
    satisfy PeakOutputRequirement by horsepowerPlant;
    satisfy TorqueRequirement by horsepowerPlant;
    satisfy EfficiencyRequirement by horsepowerPlant;
    satisfy ProtectionRequirement by horsepowerPlant;
    satisfy DiagnosticRequirement by horsepowerPlant;
  }

}