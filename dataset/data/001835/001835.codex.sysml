package PotentialEnergyStorageSystem {

  import ScalarValues::*;
  import SI::*;

  value type MassValue :> Real { unit = "kg"; }
  value type LengthValue :> Real { unit = "m"; }
  value type VelocityValue :> Real { unit = "m/s"; }
  value type AccelerationValue :> Real { unit = "m/s^2"; }
  value type EnergyValue :> Real { unit = "J"; }
  value type PowerValue :> Real { unit = "W"; }
  value type EfficiencyValue :> Real { unit = "1"; }
  value type TimeValue :> Real { unit = "s"; }
  value type FlowRateValue :> Real { unit = "kg/s"; }
  value type VoltageValue :> Real { unit = "V"; }
  value type CurrentValue :> Real { unit = "A"; }

  item def WaterMass {
    attribute mass : MassValue;
    attribute elevation : LengthValue;
    attribute temperature : Real;
  }

  item def ElectricalEnergy {
    attribute power : PowerValue;
    attribute voltage : VoltageValue;
    attribute current : CurrentValue;
    attribute duration : TimeValue;
  }

  item def MechanicalEnergy {
    attribute torque : Real;
    attribute angularSpeed : Real;
    attribute power : PowerValue;
  }

  item def ControlSignal {
    attribute command : String;
    attribute setPointPower : PowerValue;
    attribute requestedMode : String;
  }

  port def WaterPort {
    inout item water : WaterMass;
  }

  port def ElectricalPort {
    inout item electricity : ElectricalEnergy;
  }

  port def MechanicalPort {
    inout item shaftEnergy : MechanicalEnergy;
  }

  port def ControlPort {
    in item signal : ControlSignal;
  }

  port def StatusPort {
    out item status : ControlSignal;
  }

  part def UpperReservoir {
    attribute storedWaterMass : MassValue;
    attribute waterElevation : LengthValue;
    attribute maximumWaterMass : MassValue;
    attribute minimumOperatingMass : MassValue;

    port outlet : WaterPort;
    port inlet : WaterPort;
  }

  part def LowerReservoir {
    attribute storedWaterMass : MassValue;
    attribute waterElevation : LengthValue;
    attribute maximumWaterMass : MassValue;

    port inlet : WaterPort;
    port outlet : WaterPort;
  }

  part def Penstock {
    attribute length : LengthValue;
    attribute internalDiameter : LengthValue;
    attribute maximumFlowRate : FlowRateValue;
    attribute hydraulicLossCoefficient : Real;

    port upperEnd : WaterPort;
    port lowerEnd : WaterPort;
  }

  part def ReversiblePumpTurbine {
    attribute turbineEfficiency : EfficiencyValue;
    attribute pumpEfficiency : EfficiencyValue;
    attribute maximumHydraulicPower : PowerValue;
    attribute minimumHydraulicPower : PowerValue;
    attribute nominalFlowRate : FlowRateValue;

    port highPressurePort : WaterPort;
    port lowPressurePort : WaterPort;
    port shaftPort : MechanicalPort;
    port control : ControlPort;
  }

  part def MotorGenerator {
    attribute generatorEfficiency : EfficiencyValue;
    attribute motorEfficiency : EfficiencyValue;
    attribute ratedElectricalPower : PowerValue;
    attribute ratedVoltage : VoltageValue;

    port shaftPort : MechanicalPort;
    port gridPort : ElectricalPort;
    port control : ControlPort;
  }

  part def PowerConverter {
    attribute conversionEfficiency : EfficiencyValue;
    attribute maximumOutputPower : PowerValue;
    attribute dcLinkVoltage : VoltageValue;

    port machinePort : ElectricalPort;
    port gridPort : ElectricalPort;
    port control : ControlPort;
  }

  part def GridInterface {
    attribute gridVoltage : VoltageValue;
    attribute gridFrequency : Real;
    attribute maximumImportPower : PowerValue;
    attribute maximumExportPower : PowerValue;

    port electricalConnection : ElectricalPort;
    port dispatchCommand : ControlPort;
    port operatingStatus : StatusPort;
  }

  part def EnergyManagementController {
    attribute requestedPower : PowerValue;
    attribute measuredStoredEnergy : EnergyValue;
    attribute reserveEnergyLimit : EnergyValue;
    attribute maximumChargePower : PowerValue;
    attribute maximumDischargePower : PowerValue;

    port gridCommand : ControlPort;
    port turbineCommand : ControlPort;
    port generatorCommand : ControlPort;
    port converterCommand : ControlPort;
    port status : StatusPort;
  }

  constraint def GravitationalPotentialEnergy {
    in mass : MassValue;
    in gravity : AccelerationValue;
    in heightDifference : LengthValue;
    out potentialEnergy : EnergyValue;

    potentialEnergy == mass * gravity * heightDifference;
  }

  constraint def DischargePower {
    in flowRate : FlowRateValue;
    in gravity : AccelerationValue;
    in heightDifference : LengthValue;
    in efficiency : EfficiencyValue;
    out outputPower : PowerValue;

    outputPower == flowRate * gravity * heightDifference * efficiency;
  }

  action def StorePotentialEnergy {
    in electricalInput : ElectricalEnergy;
    in lowerWater : WaterMass;
    out elevatedWater : WaterMass;
    out storedEnergyIncrease : EnergyValue;

    first startPump;
    then liftWater;
    then updateStoredEnergy;

    action startPump;
    action liftWater;
    action updateStoredEnergy;
  }

  action def ReleasePotentialEnergy {
    in elevatedWater : WaterMass;
    out electricalOutput : ElectricalEnergy;
    out storedEnergyDecrease : EnergyValue;

    first openFlowPath;
    then driveTurbine;
    then generateElectricity;
    then deliverPowerToGrid;

    action openFlowPath;
    action driveTurbine;
    action generateElectricity;
    action deliverPowerToGrid;
  }

  state def StorageOperatingState {
    state Idle;
    state Charging;
    state EnergyStored;
    state Discharging;
    state ReserveProtected;
    state FaultIsolated;

    transition IdleToCharging
      first Idle
      then Charging;

    transition ChargingToStored
      first Charging
      then EnergyStored;

    transition StoredToDischarging
      first EnergyStored
      then Discharging;

    transition DischargingToReserveProtected
      first Discharging
      then ReserveProtected;

    transition AnyToFault
      first Idle
      then FaultIsolated;
  }

  part def GravitationalPotentialEnergyStoragePlant {
    attribute gravitationalAcceleration : AccelerationValue = 9.80665;
    attribute designHead : LengthValue;
    attribute maximumStoredEnergy : EnergyValue;
    attribute minimumReserveEnergy : EnergyValue;
    attribute roundTripEfficiency : EfficiencyValue;
    attribute ratedChargePower : PowerValue;
    attribute ratedDischargePower : PowerValue;

    part upperReservoir : UpperReservoir;
    part lowerReservoir : LowerReservoir;
    part penstock : Penstock;
    part pumpTurbine : ReversiblePumpTurbine;
    part motorGenerator : MotorGenerator;
    part converter : PowerConverter;
    part gridInterface : GridInterface;
    part controller : EnergyManagementController;

    port gridElectricalPort : ElectricalPort;
    port dispatchPort : ControlPort;
    port statusPort : StatusPort;

    connect upperReservoir.outlet to penstock.upperEnd;
    connect penstock.lowerEnd to pumpTurbine.highPressurePort;
    connect pumpTurbine.lowPressurePort to lowerReservoir.inlet;
    connect lowerReservoir.outlet to pumpTurbine.lowPressurePort;
    connect pumpTurbine.shaftPort to motorGenerator.shaftPort;
    connect motorGenerator.gridPort to converter.machinePort;
    connect converter.gridPort to gridInterface.electricalConnection;
    connect gridInterface.electricalConnection to gridElectricalPort;

    connect dispatchPort to controller.gridCommand;
    connect gridInterface.dispatchCommand to controller.gridCommand;
    connect controller.turbineCommand to pumpTurbine.control;
    connect controller.generatorCommand to motorGenerator.control;
    connect controller.converterCommand to converter.control;
    connect controller.status to statusPort;

    constraint storedEnergyModel : GravitationalPotentialEnergy {
      mass = upperReservoir.storedWaterMass;
      gravity = gravitationalAcceleration;
      heightDifference = designHead;
      potentialEnergy = controller.measuredStoredEnergy;
    }

    constraint dischargePowerModel : DischargePower {
      flowRate = penstock.maximumFlowRate;
      gravity = gravitationalAcceleration;
      heightDifference = designHead;
      efficiency = roundTripEfficiency;
      outputPower = ratedDischargePower;
    }

    perform action chargeCycle : StorePotentialEnergy;
    perform action dischargeCycle : ReleasePotentialEnergy;

    exhibit state operatingState : StorageOperatingState;
  }

  requirement def PrimaryFunctionRequirement {
    subject plant : GravitationalPotentialEnergyStoragePlant;

    doc
      /* The system shall store electrical energy as gravitational potential energy by lifting water to a higher elevation and shall later convert that stored potential energy back into electrical power for delivery to the grid. */

    require constraint {
      plant.maximumStoredEnergy >= plant.minimumReserveEnergy;
      plant.ratedChargePower > 0;
      plant.ratedDischargePower > 0;
      plant.designHead > 0;
    }
  }

  requirement def EnergyCapacityRequirement {
    subject plant : GravitationalPotentialEnergyStoragePlant;

    doc
      /* The plant shall maintain enough elevated water mass to provide a useful grid-scale reserve of gravitational potential energy. */

    require constraint {
      plant.maximumStoredEnergy >= 360000000000;
      plant.minimumReserveEnergy >= 36000000000;
    }
  }

  requirement def PowerDeliveryRequirement {
    subject plant : GravitationalPotentialEnergyStoragePlant;

    doc
      /* The plant shall provide controlled discharge power through the turbine, generator, converter, and grid interface. */

    require constraint {
      plant.ratedDischargePower >= 100000000;
      plant.roundTripEfficiency >= 0.70;
    }
  }

  requirement def ReserveProtectionRequirement {
    subject plant : GravitationalPotentialEnergyStoragePlant;

    doc
      /* The controller shall prevent discharge below the minimum reserve energy limit. */

    require constraint {
      plant.controller.measuredStoredEnergy >= plant.minimumReserveEnergy;
    }
  }

  part plant : GravitationalPotentialEnergyStoragePlant {
    attribute designHead = 500;
    attribute maximumStoredEnergy = 490332500000;
    attribute minimumReserveEnergy = 49033250000;
    attribute roundTripEfficiency = 0.78;
    attribute ratedChargePower = 120000000;
    attribute ratedDischargePower = 100000000;

    part upperReservoir {
      attribute storedWaterMass = 100000000;
      attribute waterElevation = 650;
      attribute maximumWaterMass = 120000000;
      attribute minimumOperatingMass = 10000000;
    }

    part lowerReservoir {
      attribute storedWaterMass = 100000000;
      attribute waterElevation = 150;
      attribute maximumWaterMass = 130000000;
    }

    part penstock {
      attribute length = 900;
      attribute internalDiameter = 6;
      attribute maximumFlowRate = 26000;
      attribute hydraulicLossCoefficient = 0.04;
    }

    part pumpTurbine {
      attribute turbineEfficiency = 0.91;
      attribute pumpEfficiency = 0.89;
      attribute maximumHydraulicPower = 130000000;
      attribute minimumHydraulicPower = 10000000;
      attribute nominalFlowRate = 22000;
    }

    part motorGenerator {
      attribute generatorEfficiency = 0.97;
      attribute motorEfficiency = 0.96;
      attribute ratedElectricalPower = 120000000;
      attribute ratedVoltage = 13800;
    }

    part converter {
      attribute conversionEfficiency = 0.98;
      attribute maximumOutputPower = 120000000;
      attribute dcLinkVoltage = 24000;
    }

    part gridInterface {
      attribute gridVoltage = 230000;
      attribute gridFrequency = 60;
      attribute maximumImportPower = 120000000;
      attribute maximumExportPower = 100000000;
    }

    part controller {
      attribute requestedPower = 0;
      attribute measuredStoredEnergy = 490332500000;
      attribute reserveEnergyLimit = 49033250000;
      attribute maximumChargePower = 120000000;
      attribute maximumDischargePower = 100000000;
    }
  }

  satisfy PrimaryFunctionRequirement by plant;
  satisfy EnergyCapacityRequirement by plant;
  satisfy PowerDeliveryRequirement by plant;
  satisfy ReserveProtectionRequirement by plant;
}