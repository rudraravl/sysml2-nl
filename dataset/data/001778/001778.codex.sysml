package FirstLawThermodynamicSystem {

  import ScalarValues::*;
  import ISQ::*;

  attribute def joule :> Real;
  attribute def watt :> Real;
  attribute def kelvin :> Real;
  attribute def kilogram :> Real;
  attribute def pascal :> Real;
  attribute def second :> Real;

  item def ThermalEnergy {
    attribute amount : joule;
    attribute temperature : kelvin;
  }

  item def MechanicalWork {
    attribute amount : joule;
    attribute rate : watt;
  }

  item def HeatFlow {
    attribute rate : watt;
    attribute directionSign : Real;
  }

  item def WorkingFluid {
    attribute mass : kilogram;
    attribute temperature : kelvin;
    attribute pressure : pascal;
    attribute specificInternalEnergy : Real;
    attribute totalInternalEnergy : joule;
  }

  item def ControlSignal {
    attribute command : String;
    attribute requestedHeatRate : watt;
  }

  port def HeatPort {
    out item heat : HeatFlow;
  }

  port def WorkPort {
    out item work : MechanicalWork;
  }

  port def FluidPort {
    inout item fluid : WorkingFluid;
  }

  port def SignalPort {
    in item signal : ControlSignal;
  }

  value def EnergyBalance {
    attribute heatInput : joule;
    attribute workOutput : joule;
    attribute internalEnergyChange : joule;

    constraint firstLaw {
      internalEnergyChange == heatInput - workOutput
    }
  }

  part def HeatSource {
    attribute maximumHeatRate : watt = 5000.0;
    attribute sourceTemperature : kelvin = 600.0;

    port heatOut : HeatPort;

    action deliverHeat {
      in command : ControlSignal;
      out suppliedHeat : HeatFlow;

      first start;
      then setRate;
      then done;

      action setRate {
        suppliedHeat.rate = command.requestedHeatRate;
        suppliedHeat.directionSign = 1.0;
      }
    }
  }

  part def ExpansionChamber {
    attribute volume : Real = 0.02;
    attribute wallTemperature : kelvin = 500.0;

    port heatIn : HeatPort;
    port fluidIn : FluidPort;
    port fluidOut : FluidPort;
    port workOut : WorkPort;

    item workingFluid : WorkingFluid;

    attribute accumulatedHeatInput : joule = 0.0;
    attribute accumulatedWorkOutput : joule = 0.0;
    attribute internalEnergyChange : joule = 0.0;

    constraint chamberEnergyBalance {
      internalEnergyChange == accumulatedHeatInput - accumulatedWorkOutput
    }

    action convertHeatToWork {
      in heat : HeatFlow;
      in fluidBefore : WorkingFluid;
      out fluidAfter : WorkingFluid;
      out work : MechanicalWork;

      first receiveHeat;
      then increaseInternalEnergy;
      then expandFluid;
      then produceBoundaryWork;
      then dischargeFluid;

      action receiveHeat {
        accumulatedHeatInput = accumulatedHeatInput + heat.rate;
      }

      action increaseInternalEnergy {
        fluidAfter.mass = fluidBefore.mass;
        fluidAfter.temperature = fluidBefore.temperature + 80.0;
        fluidAfter.pressure = fluidBefore.pressure + 200000.0;
        fluidAfter.specificInternalEnergy = fluidBefore.specificInternalEnergy + 120000.0;
        fluidAfter.totalInternalEnergy = fluidBefore.totalInternalEnergy + 2400.0;
      }

      action expandFluid {
        fluidAfter.pressure = fluidAfter.pressure - 50000.0;
      }

      action produceBoundaryWork {
        work.rate = 1200.0;
        work.amount = 1200.0;
        accumulatedWorkOutput = accumulatedWorkOutput + work.amount;
      }

      action dischargeFluid {
        internalEnergyChange = accumulatedHeatInput - accumulatedWorkOutput;
      }
    }

    state def ChamberOperatingState {
      state idle;
      state heating;
      state expanding;
      state deliveringWork;
      state stabilized;

      transition idle_to_heating
        first idle
        then heating;

      transition heating_to_expanding
        first heating
        then expanding;

      transition expanding_to_deliveringWork
        first expanding
        then deliveringWork;

      transition deliveringWork_to_stabilized
        first deliveringWork
        then stabilized;

      transition stabilized_to_heating
        first stabilized
        then heating;
    }
  }

  part def WorkReceiver {
    attribute loadTorque : Real = 25.0;
    attribute deliveredPower : watt = 0.0;

    port workIn : WorkPort;

    action absorbWork {
      in work : MechanicalWork;
      out acceptedWork : MechanicalWork;

      first receive;
      then updatePower;
      then complete;

      action receive {
        acceptedWork.amount = work.amount;
        acceptedWork.rate = work.rate;
      }

      action updatePower {
        deliveredPower = work.rate;
      }
    }
  }

  part def ThermalController {
    attribute targetTemperature : kelvin = 520.0;
    attribute heatCommandRate : watt = 3000.0;

    port sensorFluid : FluidPort;
    port commandOut : SignalPort;

    action regulateHeatInput {
      in measuredFluid : WorkingFluid;
      out command : ControlSignal;

      first compareTemperature;
      then commandHeatRate;
      then issueCommand;

      action compareTemperature {
      }

      action commandHeatRate {
        command.command = "increase heat until chamber approaches target temperature";
        command.requestedHeatRate = heatCommandRate;
      }
    }

    state def ControllerState {
      state monitoring;
      state requestingHeat;
      state limitingHeat;

      transition monitoring_to_requestingHeat
        first monitoring
        then requestingHeat;

      transition requestingHeat_to_limitingHeat
        first requestingHeat
        then limitingHeat;

      transition limitingHeat_to_monitoring
        first limitingHeat
        then monitoring;
    }
  }

  part def ThermodynamicConverter {
    attribute primaryFunction : String =
      "Convert controlled heat input into useful boundary work while satisfying conservation of energy according to the First Law of Thermodynamics.";

    port externalHeatIn : HeatPort;
    port externalWorkOut : WorkPort;
    port controlIn : SignalPort;

    part heatSource : HeatSource;
    part chamber : ExpansionChamber;
    part load : WorkReceiver;
    part controller : ThermalController;

    item fluidCharge : WorkingFluid {
      attribute mass = 0.02;
      attribute temperature = 300.0;
      attribute pressure = 101325.0;
      attribute specificInternalEnergy = 215000.0;
      attribute totalInternalEnergy = 4300.0;
    }

    attribute totalHeatInput : joule = 0.0;
    attribute totalWorkOutput : joule = 0.0;
    attribute totalInternalEnergyChange : joule = 0.0;

    constraint systemFirstLaw {
      totalInternalEnergyChange == totalHeatInput - totalWorkOutput
    }

    connect heatSource.heatOut to chamber.heatIn;
    connect chamber.workOut to load.workIn;
    connect chamber.workOut to externalWorkOut;
    connect externalHeatIn to chamber.heatIn;
    connect controller.commandOut to controlIn;
    connect chamber.fluidOut to controller.sensorFluid;

    action performPrimaryFunction {
      in initialFluid : WorkingFluid;
      out usefulWork : MechanicalWork;
      out finalFluid : WorkingFluid;

      first initializeFluid;
      then regulate;
      then addHeat;
      then transformEnergy;
      then deliverUsefulWork;
      then verifyEnergyConservation;

      action initializeFluid {
        initialFluid.mass = fluidCharge.mass;
        initialFluid.temperature = fluidCharge.temperature;
        initialFluid.pressure = fluidCharge.pressure;
      }

      action regulate {
      }

      action addHeat {
        totalHeatInput = totalHeatInput + 3000.0;
      }

      action transformEnergy {
        usefulWork.rate = 1200.0;
        usefulWork.amount = 1200.0;
        finalFluid.mass = initialFluid.mass;
        finalFluid.temperature = initialFluid.temperature + 80.0;
        finalFluid.pressure = initialFluid.pressure + 150000.0;
        finalFluid.specificInternalEnergy = initialFluid.specificInternalEnergy + 90000.0;
        finalFluid.totalInternalEnergy = initialFluid.totalInternalEnergy + 1800.0;
      }

      action deliverUsefulWork {
        totalWorkOutput = totalWorkOutput + usefulWork.amount;
      }

      action verifyEnergyConservation {
        totalInternalEnergyChange = totalHeatInput - totalWorkOutput;
      }
    }

    state def ConverterLifecycle {
      state off;
      state filling;
      state heating;
      state expanding;
      state producingWork;
      state conservingEnergy;
      state shutdown;

      transition off_to_filling
        first off
        then filling;

      transition filling_to_heating
        first filling
        then heating;

      transition heating_to_expanding
        first heating
        then expanding;

      transition expanding_to_producingWork
        first expanding
        then producingWork;

      transition producingWork_to_conservingEnergy
        first producingWork
        then conservingEnergy;

      transition conservingEnergy_to_heating
        first conservingEnergy
        then heating;

      transition conservingEnergy_to_shutdown
        first conservingEnergy
        then shutdown;
    }
  }

  requirement def FirstLawCompliance {
    subject converter : ThermodynamicConverter;

    require constraint {
      converter.totalInternalEnergyChange == converter.totalHeatInput - converter.totalWorkOutput
    }

    doc /* The system shall conserve energy such that the change in internal energy of the working fluid equals heat added to the system minus work delivered by the system. */
  }

  requirement def UsefulWorkRequirement {
    subject converter : ThermodynamicConverter;

    require constraint {
      converter.totalWorkOutput >= 0.0
    }

    doc /* The system shall deliver non-negative useful mechanical work to an external load whenever heat input is commanded and working fluid is present. */
  }

  requirement def ControlledHeatInputRequirement {
    subject converter : ThermodynamicConverter;

    require constraint {
      converter.heatSource.maximumHeatRate <= 5000.0
    }

    doc /* The controller and heat source shall limit thermal input to the expansion chamber to prevent commanded heat flow from exceeding the heat source capability. */
  }

  requirement def WorkingFluidContainmentRequirement {
    subject converter : ThermodynamicConverter;

    require constraint {
      converter.fluidCharge.mass > 0.0
    }

    doc /* The expansion chamber shall contain a positive mass of working fluid before conversion of heat into work begins. */
  }

  requirement def PrimaryFunctionRequirement {
    subject converter : ThermodynamicConverter;

    doc /* The primary high-level function of the system is to accept thermal energy, raise the internal energy of a working fluid, expand the fluid, and deliver useful mechanical work while accounting for all energy by the First Law of Thermodynamics. */
  }

  part firstLawBasedEnergyConversionSystem : ThermodynamicConverter;

  satisfy FirstLawCompliance by firstLawBasedEnergyConversionSystem;
  satisfy UsefulWorkRequirement by firstLawBasedEnergyConversionSystem;
  satisfy ControlledHeatInputRequirement by firstLawBasedEnergyConversionSystem;
  satisfy WorkingFluidContainmentRequirement by firstLawBasedEnergyConversionSystem;
  satisfy PrimaryFunctionRequirement by firstLawBasedEnergyConversionSystem;
}