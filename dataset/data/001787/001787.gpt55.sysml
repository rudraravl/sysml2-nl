package GasolinePoweredEnergySystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def FuelVolume :> ISQ::volume {
    :>> unit = SI::litre;
  }

  attribute def MassFlowRate :> ISQ::massFlowRate {
    :>> unit = SI::kilogramPerSecond;
  }

  attribute def Pressure :> ISQ::pressure {
    :>> unit = SI::kilopascal;
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    :>> unit = SI::kelvin;
  }

  attribute def Energy :> ISQ::energy {
    :>> unit = SI::megajoule;
  }

  attribute def Power :> ISQ::power {
    :>> unit = SI::kilowatt;
  }

  attribute def Torque :> ISQ::torque {
    :>> unit = SI::newtonMetre;
  }

  attribute def RotationalSpeed :> ISQ::angularVelocity {
    :>> unit = SI::revolutionPerMinute;
  }

  attribute def Ratio :> ScalarValues::Real;

  attribute def Percent :> ScalarValues::Real {
    :>> unit = SI::percent;
  }

  attribute def OctaneNumber :> ScalarValues::Real;

  attribute def Distance :> ISQ::length {
    :>> unit = SI::kilometre;
  }

  attribute def TimeDuration :> ISQ::time {
    :>> unit = SI::second;
  }

  item def Gasoline {
    attribute researchOctaneNumber : OctaneNumber = 91.0;
    attribute lowerHeatingValue : Energy = 32.0 [SI::megajoule];
    attribute densityAt15C : ISQ::density = 745.0 [SI::kilogramPerCubicMetre];
    attribute vaporPressure : Pressure = 60.0 [SI::kilopascal];
    attribute sulfurContent : Percent = 0.001;
  }

  item def Air {
    attribute oxygenMoleFraction : Ratio = 0.2095;
    attribute temperature : Temperature;
    attribute pressure : Pressure;
  }

  item def FuelAirMixture {
    attribute equivalenceRatio : Ratio;
    attribute mixtureTemperature : Temperature;
    attribute mixturePressure : Pressure;
    item fuel : Gasoline;
    item air : Air;
  }

  item def CombustionProducts {
    attribute exhaustTemperature : Temperature;
    attribute exhaustPressure : Pressure;
    attribute carbonDioxideMassFlow : MassFlowRate;
    attribute waterVaporMassFlow : MassFlowRate;
    attribute nitrogenMassFlow : MassFlowRate;
    attribute carbonMonoxideMassFlow : MassFlowRate;
  }

  item def MechanicalPower {
    attribute shaftPower : Power;
    attribute shaftTorque : Torque;
    attribute shaftSpeed : RotationalSpeed;
  }

  item def ElectricalPower {
    attribute voltage : ISQ::electricPotential = 12.0 [SI::volt];
    attribute current : ISQ::electricCurrent;
    attribute power : Power;
  }

  item def Heat {
    attribute heatRate : Power;
    attribute coolantTemperature : Temperature;
  }

  item def StartCommand;
  item def StopCommand;
  item def ThrottleCommand {
    attribute requestedTorquePercent : Percent;
  }

  port def FuelOutletPort {
    out item fuel : Gasoline;
    attribute outletPressure : Pressure;
    attribute maximumFlowRate : MassFlowRate;
  }

  port def FuelInletPort {
    in item fuel : Gasoline;
    attribute requiredPressure : Pressure;
    attribute requestedFlowRate : MassFlowRate;
  }

  port def AirInletPort {
    in item air : Air;
    attribute requestedAirFlowRate : MassFlowRate;
  }

  port def MixturePort {
    out item mixture : FuelAirMixture;
  }

  port def CombustionIntakePort {
    in item mixture : FuelAirMixture;
  }

  port def ExhaustOutletPort {
    out item exhaust : CombustionProducts;
  }

  port def ExhaustInletPort {
    in item exhaust : CombustionProducts;
  }

  port def MechanicalPowerPort {
    out item mechanicalPower : MechanicalPower;
  }

  port def MechanicalLoadPort {
    in item mechanicalPower : MechanicalPower;
  }

  port def HeatOutletPort {
    out item heat : Heat;
  }

  port def HeatInletPort {
    in item heat : Heat;
  }

  port def ElectricalSupplyPort {
    out item electricalPower : ElectricalPower;
  }

  port def ElectricalLoadPort {
    in item electricalPower : ElectricalPower;
  }

  port def ControlInputPort {
    in item start : StartCommand;
    in item stop : StopCommand;
    in item throttle : ThrottleCommand;
  }

  port def ControlOutputPort {
    out item throttle : ThrottleCommand;
  }

  connection def FuelTransfer {
    end source : FuelOutletPort;
    end sink : FuelInletPort;
  }

  connection def AirTransfer {
    end source : AirInletPort;
    end sink : AirInletPort;
  }

  connection def MixtureTransfer {
    end source : MixturePort;
    end sink : CombustionIntakePort;
  }

  connection def ExhaustTransfer {
    end source : ExhaustOutletPort;
    end sink : ExhaustInletPort;
  }

  connection def ShaftPowerTransfer {
    end source : MechanicalPowerPort;
    end sink : MechanicalLoadPort;
  }

  connection def HeatTransfer {
    end source : HeatOutletPort;
    end sink : HeatInletPort;
  }

  connection def ElectricalTransfer {
    end source : ElectricalSupplyPort;
    end sink : ElectricalLoadPort;
  }

  action def StoreGasoline {
    in item incomingFuel : Gasoline;
    out item storedFuel : Gasoline;
    attribute storedVolume : FuelVolume;
    attribute maximumStoredVolume : FuelVolume;
  }

  action def PressurizeFuel {
    in item storedFuel : Gasoline;
    out item pressurizedFuel : Gasoline;
    attribute targetPressure : Pressure = 350.0 [SI::kilopascal];
    attribute pumpElectricalPower : Power;
  }

  action def MeterFuel {
    in item pressurizedFuel : Gasoline;
    in item throttle : ThrottleCommand;
    out item meteredFuel : Gasoline;
    attribute commandedFuelMassFlow : MassFlowRate;
  }

  action def DrawAir {
    out item intakeAir : Air;
    attribute intakePressure : Pressure = 101.3 [SI::kilopascal];
    attribute intakeTemperature : Temperature = 298.0 [SI::kelvin];
  }

  action def MixFuelAndAir {
    in item meteredFuel : Gasoline;
    in item intakeAir : Air;
    out item combustibleMixture : FuelAirMixture;
    attribute targetAirFuelMassRatio : Ratio = 14.7;
    attribute equivalenceRatio : Ratio = 1.0;
  }

  action def IgniteAndCombust {
    in item combustibleMixture : FuelAirMixture;
    out item combustionProducts : CombustionProducts;
    out item releasedHeat : Heat;
    attribute ignitionTimingBeforeTopDeadCenter : ScalarValues::Real = 10.0;
    attribute peakCylinderPressure : Pressure;
  }

  action def ConvertCombustionToMechanicalPower {
    in item combustionProducts : CombustionProducts;
    out item shaftPower : MechanicalPower;
    out item wasteHeat : Heat;
    attribute brakeThermalEfficiency : Percent = 28.0;
    attribute ratedPower : Power = 75.0 [SI::kilowatt];
    attribute ratedSpeed : RotationalSpeed = 5500.0 [SI::revolutionPerMinute];
  }

  action def TreatAndDischargeExhaust {
    in item rawExhaust : CombustionProducts;
    out item treatedExhaust : CombustionProducts;
    attribute catalystLightOffTemperature : Temperature = 550.0 [SI::kelvin];
    attribute carbonMonoxideConversionEfficiency : Percent = 95.0;
  }

  action def RejectHeat {
    in item wasteHeat : Heat;
    out item rejectedHeat : Heat;
    attribute coolantSetPoint : Temperature = 363.0 [SI::kelvin];
  }

  action def GenerateElectricalPower {
    in item shaftPower : MechanicalPower;
    out item electricalPower : ElectricalPower;
    attribute alternatorEfficiency : Percent = 70.0;
    attribute nominalVoltage : ISQ::electricPotential = 14.2 [SI::volt];
  }

  action def ProvideUsefulMechanicalOutput {
    in item shaftPower : MechanicalPower;
    out item usefulPower : MechanicalPower;
    attribute deliveredEfficiency : Percent = 92.0;
  }

  action def GasolineEnergyConversion {
    in item fuelSupply : Gasoline;
    in item ambientAir : Air;
    in item operatorThrottle : ThrottleCommand;
    out item usefulMechanicalPower : MechanicalPower;
    out item dischargedExhaust : CombustionProducts;
    out item rejectedHeat : Heat;

    action pressurizeFuel : PressurizeFuel;
    action meterFuel : MeterFuel;
    action drawAir : DrawAir;
    action mix : MixFuelAndAir;
    action combust : IgniteAndCombust;
    action convert : ConvertCombustionToMechanicalPower;
    action treatExhaust : TreatAndDischargeExhaust;
    action rejectHeat : RejectHeat;
    action deliverPower : ProvideUsefulMechanicalOutput;

    flow fuelSupply to pressurizeFuel.storedFuel;
    flow pressurizeFuel.pressurizedFuel to meterFuel.pressurizedFuel;
    flow operatorThrottle to meterFuel.throttle;
    flow ambientAir to drawAir.intakeAir;
    flow meterFuel.meteredFuel to mix.meteredFuel;
    flow drawAir.intakeAir to mix.intakeAir;
    flow mix.combustibleMixture to combust.combustibleMixture;
    flow combust.combustionProducts to convert.combustionProducts;
    flow convert.shaftPower to deliverPower.shaftPower;
    flow deliverPower.usefulPower to usefulMechanicalPower;
    flow convert.wasteHeat to rejectHeat.wasteHeat;
    flow rejectHeat.rejectedHeat to rejectedHeat;
    flow convert.combustionProducts to treatExhaust.rawExhaust;
    flow treatExhaust.treatedExhaust to dischargedExhaust;
  }

  state def GasolineEngineOperationalStates {
    in item start : StartCommand;
    in item stop : StopCommand;
    in item throttle : ThrottleCommand;

    attribute crankSpeedThreshold : RotationalSpeed = 250.0 [SI::revolutionPerMinute];
    attribute idleSpeed : RotationalSpeed = 750.0 [SI::revolutionPerMinute];
    attribute maximumSpeed : RotationalSpeed = 6200.0 [SI::revolutionPerMinute];

    state Off {
      entry action {
        send StopCommand;
      }
    }

    state Priming {
      entry action PressurizeFuel {
        targetPressure = 350.0 [SI::kilopascal];
      }
    }

    state Cranking {
      entry action {
        attribute commandedSpeed : RotationalSpeed = 300.0 [SI::revolutionPerMinute];
      }
    }

    state Running {
      state Idle {
        entry action {
          attribute commandedThrottle : Percent = 5.0;
        }
      }

      state PowerProducing {
        entry action GasolineEnergyConversion;
      }

      state Decelerating {
        entry action {
          attribute fuelCutEnabled : Boolean = true;
        }
      }

      transition first Idle then PowerProducing accept ThrottleCommand
        if throttle.requestedTorquePercent > 10.0;

      transition first PowerProducing then Idle accept ThrottleCommand
        if throttle.requestedTorquePercent <= 10.0;

      transition first PowerProducing then Decelerating accept ThrottleCommand
        if throttle.requestedTorquePercent == 0.0;

      transition first Decelerating then Idle accept ThrottleCommand
        if throttle.requestedTorquePercent > 0.0 and throttle.requestedTorquePercent <= 10.0;
    }

    state Shutdown {
      entry action {
        attribute fuelFlowCommand : MassFlowRate = 0.0 [SI::kilogramPerSecond];
      }
    }

    transition initial then Off;
    transition first Off then Priming accept StartCommand;
    transition first Priming then Cranking;
    transition first Cranking then Running if crankSpeedThreshold >= 250.0 [SI::revolutionPerMinute];
    transition first Running then Shutdown accept StopCommand;
    transition first Shutdown then Off;
  }

  part def GasolineTank {
    attribute capacity : FuelVolume = 55.0 [SI::litre];
    attribute usableFuelVolume : FuelVolume = 52.0 [SI::litre];
    attribute reserveFuelVolume : FuelVolume = 5.0 [SI::litre];
    attribute ventPressureLimit : Pressure = 115.0 [SI::kilopascal];

    item storedGasoline : Gasoline;

    port fuelOut : FuelOutletPort {
      outletPressure = 101.3 [SI::kilopascal];
      maximumFlowRate = 0.08 [SI::kilogramPerSecond];
    }
  }

  part def FuelPump {
    attribute nominalPressureRise : Pressure = 250.0 [SI::kilopascal];
    attribute maximumFlowRate : MassFlowRate = 0.08 [SI::kilogramPerSecond];
    attribute electricalPowerDemand : Power = 0.12 [SI::kilowatt];

    port fuelIn : FuelInletPort {
      requiredPressure = 90.0 [SI::kilopascal];
      requestedFlowRate = 0.08 [SI::kilogramPerSecond];
    }

    port fuelOut : FuelOutletPort {
      outletPressure = 350.0 [SI::kilopascal];
      maximumFlowRate = 0.08 [SI::kilogramPerSecond];
    }

    port electricalIn : ElectricalLoadPort;
  }

  part def FuelInjector {
    attribute injectorCount : ScalarValues::Integer = 4;
    attribute maximumFuelMassFlow : MassFlowRate = 0.06 [SI::kilogramPerSecond];
    attribute minimumPulseWidth : TimeDuration = 0.0015 [SI::second];

    port fuelIn : FuelInletPort {
      requiredPressure = 300.0 [SI::kilopascal];
      requestedFlowRate = 0.06 [SI::kilogramPerSecond];
    }

    port fuelOut : MixturePort;
    port controlIn : ControlInputPort;
  }

  part def AirIntake {
    attribute filterEfficiency : Percent = 98.5;
    attribute throttleAreaRatio : Ratio;
    attribute nominalAirPressure : Pressure = 101.3 [SI::kilopascal];

    port airIn : AirInletPort;
    port airOut : AirInletPort;
    port controlIn : ControlInputPort;
  }

  part def CombustionChamber {
    attribute cylinderCount : ScalarValues::Integer = 4;
    attribute compressionRatio : Ratio = 10.5;
    attribute displacement : ISQ::volume = 2.0 [SI::litre];
    attribute nominalAirFuelRatio : Ratio = 14.7;
    attribute peakTemperature : Temperature = 2400.0 [SI::kelvin];

    port mixtureIn : CombustionIntakePort;
    port exhaustOut : ExhaustOutletPort;
    port heatOut : HeatOutletPort;
    port crankshaftOut : MechanicalPowerPort;
  }

  part def IgnitionSubsystem {
    attribute sparkEnergy : Energy = 0.05 [SI::joule];
    attribute nominalSparkAdvance : ScalarValues::Real = 10.0;
    attribute coilVoltage : ISQ::electricPotential = 30000.0 [SI::volt];

    port electricalIn : ElectricalLoadPort;
    port controlIn : ControlInputPort;
  }

  part def CrankshaftAssembly {
    attribute inertia : ISQ::momentOfInertia = 0.18 [SI::kilogramMetreSquared];
    attribute maximumTorque : Torque = 180.0 [SI::newtonMetre];
    attribute idleSpeed : RotationalSpeed = 750.0 [SI::revolutionPerMinute];

    port powerIn : MechanicalLoadPort;
    port powerOut : MechanicalPowerPort;
  }

  part def ExhaustSystem {
    attribute catalystConversionEfficiency : Percent = 95.0;
    attribute mufflerPressureDrop : Pressure = 8.0 [SI::kilopascal];

    port exhaustIn : ExhaustInletPort;
    port exhaustOut : ExhaustOutletPort;
  }

  part def CoolingSystem {
    attribute coolantCapacity : FuelVolume = 6.0 [SI::litre];
    attribute thermostatOpeningTemperature : Temperature = 363.0 [SI::kelvin];
    attribute heatRejectionCapacity : Power = 45.0 [SI::kilowatt];

    port heatIn : HeatInletPort;
    port heatOut : HeatOutletPort;
  }

  part def Alternator {
    attribute nominalElectricalPower : Power = 1.2 [SI::kilowatt];
    attribute efficiency : Percent = 70.0;
    attribute regulatedVoltage : ISQ::electricPotential = 14.2 [SI::volt];

    port mechanicalIn : MechanicalLoadPort;
    port electricalOut : ElectricalSupplyPort;
  }

  part def EngineController {
    attribute commandedEquivalenceRatio : Ratio = 1.0;
    attribute idleSpeedTarget : RotationalSpeed = 750.0 [SI::revolutionPerMinute];
    attribute maximumSpeedLimit : RotationalSpeed = 6200.0 [SI::revolutionPerMinute];

    port operatorIn : ControlInputPort;
    port injectorControlOut : ControlOutputPort;
    port ignitionControlOut : ControlOutputPort;
    port throttleControlOut : ControlOutputPort;

    state controllerState : GasolineEngineOperationalStates;
  }

  part def UsefulLoad {
    attribute requiredPeakPower : Power = 60.0 [SI::kilowatt];
    attribute requiredContinuousPower : Power = 25.0 [SI::kilowatt];

    port powerIn : MechanicalLoadPort;
  }

  part def GasolinePoweredSystem {
    doc /*
      Primary high-level function: safely store gasoline and convert its chemical energy,
      with air, into controlled mechanical shaft power while managing heat, exhaust,
      electrical support loads, and operator throttle commands.
    */

    attribute maximumFuelCapacity : FuelVolume = 55.0 [SI::litre];
    attribute ratedMechanicalPower : Power = 75.0 [SI::kilowatt];
    attribute ratedTorque : Torque = 180.0 [SI::newtonMetre];
    attribute ratedSpeed : RotationalSpeed = 5500.0 [SI::revolutionPerMinute];
    attribute minimumBrakeThermalEfficiency : Percent = 25.0;
    attribute nominalStoichiometricAirFuelRatio : Ratio = 14.7;
    attribute expectedRangeAtModerateLoad : Distance = 550.0 [SI::kilometre];

    port ambientAirIn : AirInletPort;
    port operatorCommands : ControlInputPort;
    port usefulPowerOut : MechanicalPowerPort;
    port exhaustOut : ExhaustOutletPort;
    port rejectedHeatOut : HeatOutletPort;

    part tank : GasolineTank;
    part pump : FuelPump;
    part injector : FuelInjector;
    part intake : AirIntake;
    part chamber : CombustionChamber;
    part ignition : IgnitionSubsystem;
    part crankshaft : CrankshaftAssembly;
    part exhaust : ExhaustSystem;
    part cooling : CoolingSystem;
    part alternator : Alternator;
    part controller : EngineController;
    part drivenLoad : UsefulLoad;

    connection tankToPump : FuelTransfer connect tank.fuelOut to pump.fuelIn;
    connection pumpToInjector : FuelTransfer connect pump.fuelOut to injector.fuelIn;
    connection ambientToIntake connect ambientAirIn to intake.airIn;
    connection intakeToChamber connect intake.airOut to chamber.mixtureIn;
    connection chamberToCrankshaft : ShaftPowerTransfer connect chamber.crankshaftOut to crankshaft.powerIn;
    connection crankshaftToUsefulOutput : ShaftPowerTransfer connect crankshaft.powerOut to usefulPowerOut;
    connection crankshaftToLoad : ShaftPowerTransfer connect crankshaft.powerOut to drivenLoad.powerIn;
    connection crankshaftToAlternator : ShaftPowerTransfer connect crankshaft.powerOut to alternator.mechanicalIn;
    connection chamberToExhaust : ExhaustTransfer connect chamber.exhaustOut to exhaust.exhaustIn;
    connection exhaustToEnvironment : ExhaustTransfer connect exhaust.exhaustOut to exhaustOut;
    connection chamberHeatToCooling : HeatTransfer connect chamber.heatOut to cooling.heatIn;
    connection coolingToEnvironment : HeatTransfer connect cooling.heatOut to rejectedHeatOut;
    connection alternatorToPump : ElectricalTransfer connect alternator.electricalOut to pump.electricalIn;
    connection alternatorToIgnition : ElectricalTransfer connect alternator.electricalOut to ignition.electricalIn;
    connection operatorToController connect operatorCommands to controller.operatorIn;
    connection controllerToInjector connect controller.injectorControlOut to injector.controlIn;
    connection controllerToIgnition connect controller.ignitionControlOut to ignition.controlIn;
    connection controllerToThrottle connect controller.throttleControlOut to intake.controlIn;

    perform action primaryEnergyConversion : GasolineEnergyConversion;
  }

  requirement def StoreGasolineSafely {
    doc /*
      The system shall store gasoline in a sealed tank with usable capacity sufficient
      for normal operation and with pressure control to prevent unsafe vapor release.
    */
    subject system : GasolinePoweredSystem;

    require constraint {
      system.tank.capacity >= 55.0 [SI::litre] and
      system.tank.ventPressureLimit <= 115.0 [SI::kilopascal]
    }
  }

  requirement def ConvertGasolineToUsefulMechanicalPower {
    doc /*
      The system shall convert gasoline chemical energy into useful mechanical shaft
      output as its primary high-level function.
    */
    subject system : GasolinePoweredSystem;

    require constraint {
      system.ratedMechanicalPower >= 75.0 [SI::kilowatt] and
      system.minimumBrakeThermalEfficiency >= 25.0
    }
  }

  requirement def MaintainStoichiometricCombustion {
    doc /*
      During steady running operation the fuel and air metering function shall target
      a stoichiometric gasoline-air ratio for efficient combustion and catalyst operation.
    */
    subject system : GasolinePoweredSystem;

    require constraint {
      system.nominalStoichiometricAirFuelRatio >= 14.5 and
      system.nominalStoichiometricAirFuelRatio <= 14.9
    }
  }

  requirement def ProvideOperatorControlledPower {
    doc /*
      The system shall vary useful mechanical power in response to operator throttle
      commands while respecting idle and maximum rotational speed limits.
    */
    subject controller : EngineController;

    require constraint {
      controller.idleSpeedTarget >= 700.0 [SI::revolutionPerMinute] and
      controller.maximumSpeedLimit <= 6200.0 [SI::revolutionPerMinute]
    }
  }

  requirement def ManageWasteHeat {
    doc /*
      The system shall reject combustion waste heat to maintain operating temperature
      within the cooling system design range.
    */
    subject system : GasolinePoweredSystem;

    require constraint {
      system.cooling.thermostatOpeningTemperature <= 363.0 [SI::kelvin] and
      system.cooling.heatRejectionCapacity >= 45.0 [SI::kilowatt]
    }
  }

  requirement def TreatExhaustBeforeDischarge {
    doc /*
      The system shall route combustion products through an exhaust treatment path
      before discharge to the environment.
    */
    subject system : GasolinePoweredSystem;

    require constraint {
      system.exhaust.catalystConversionEfficiency >= 90.0
    }
  }

  requirement def SupportElectricalLoads {
    doc /*
      The system shall generate sufficient electrical power to operate fuel pumping,
      ignition, and control support loads while running.
    */
    subject system : GasolinePoweredSystem;

    require constraint {
      system.alternator.nominalElectricalPower >= 1.0 [SI::kilowatt] and
      system.alternator.regulatedVoltage >= 13.5 [SI::volt] and
      system.alternator.regulatedVoltage <= 14.8 [SI::volt]
    }
  }

  requirement def HighLevelGasolineSystemRequirement {
    doc /*
      A gasoline-based system shall store gasoline, mix it with air, combust the mixture,
      convert combustion energy into controlled mechanical output, reject heat, and
      discharge treated exhaust.
    */
    subject system : GasolinePoweredSystem;

    require StoreGasolineSafely {
      system = subject;
    }

    require ConvertGasolineToUsefulMechanicalPower {
      system = subject;
    }

    require MaintainStoichiometricCombustion {
      system = subject;
    }

    require ManageWasteHeat {
      system = subject;
    }

    require TreatExhaustBeforeDischarge {
      system = subject;
    }

    require SupportElectricalLoads {
      system = subject;
    }
  }

  part gasolinePoweredSystem : GasolinePoweredSystem;

  satisfy HighLevelGasolineSystemRequirement by gasolinePoweredSystem;
}
