package VaginalSyringeSystemModel {

  value type Volume_mL :> Real { unit = "mL"; }
  value type Pressure_kPa :> Real { unit = "kPa"; }
  value type FlowRate_mL_per_s :> Real { unit = "mL/s"; }
  value type Length_mm :> Real { unit = "mm"; }
  value type Temperature_C :> Real { unit = "degC"; }
  value type Force_N :> Real { unit = "N"; }
  value type Time_s :> Real { unit = "s"; }

  item def IrrigationFluid {
    attribute volume : Volume_mL;
    attribute temperature : Temperature_C;
    attribute isSterile : Boolean;
  }

  item def UsedFluid {
    attribute volume : Volume_mL;
    attribute containsDischarge : Boolean;
  }

  item def ManualForce {
    attribute magnitude : Force_N;
  }

  item def UserCommand {
    attribute requestedDelivery : Boolean;
    attribute requestedStop : Boolean;
  }

  port def FillPort {
    in item fluidIn : IrrigationFluid;
  }

  port def DeliveryPort {
    out item fluidOut : IrrigationFluid;
  }

  port def DrainPort {
    in item returnFluid : UsedFluid;
  }

  port def ActuationPort {
    in item forceIn : ManualForce;
  }

  port def ControlPort {
    in item command : UserCommand;
  }

  part def FluidReservoir {
    attribute capacity : Volume_mL = 250.0;
    attribute currentVolume : Volume_mL;
    attribute maxFillTemperature : Temperature_C = 40.0;
    port fill : FillPort;
    port outlet : DeliveryPort;
  }

  part def PlungerAssembly {
    attribute strokeLength : Length_mm = 95.0;
    attribute appliedForce : Force_N;
    attribute sealIntegrity : Boolean;
    port actuation : ActuationPort;
    port displacedFluid : DeliveryPort;
  }

  part def OneWayValve {
    attribute crackingPressure : Pressure_kPa = 2.0;
    attribute backflowBlocked : Boolean = true;
    port inlet : DrainPort;
    port outlet : DeliveryPort;
  }

  part def DeliveryNozzle {
    attribute insertionLength : Length_mm = 75.0;
    attribute outerDiameter : Length_mm = 8.0;
    attribute tipRadius : Length_mm = 3.0;
    attribute outletPressure : Pressure_kPa;
    attribute outletFlowRate : FlowRate_mL_per_s;
    port inlet : DrainPort;
    port outlet : DeliveryPort;
  }

  part def ErgonomicHandle {
    attribute gripWidth : Length_mm = 42.0;
    attribute texturedSurface : Boolean = true;
    port manualInput : ActuationPort;
  }

  part def VaginalCanalInterface {
    attribute acceptedNozzleDiameter : Length_mm;
    attribute receivedVolume : Volume_mL;
    port fluidEntry : DrainPort;
    port fluidReturn : DeliveryPort;
  }

  part def VaginalSyringe {
    attribute nominalDoseVolume : Volume_mL = 150.0;
    attribute maximumReservoirVolume : Volume_mL = 250.0;
    attribute maximumOutletPressure : Pressure_kPa = 20.0;
    attribute maximumFlowRate : FlowRate_mL_per_s = 12.0;
    attribute reusableBody : Boolean = true;
    attribute intendedPrimaryFunction : String = "Provide controlled intravaginal irrigation by manually delivering a measured volume of fluid through a rounded nozzle.";

    part reservoir : FluidReservoir;
    part plunger : PlungerAssembly;
    part valve : OneWayValve;
    part nozzle : DeliveryNozzle;
    part handle : ErgonomicHandle;

    port fillAccess : FillPort;
    port userActuation : ActuationPort;
    port delivery : DeliveryPort;
    port control : ControlPort;

    connection fillToReservoir connect fillAccess to reservoir.fill;
    connection handleToPlunger connect userActuation to handle.manualInput;
    connection gripForceToPlunger connect handle.manualInput to plunger.actuation;
    connection reservoirToValve connect reservoir.outlet to valve.inlet;
    connection plungerToReservoirFlow connect plunger.displacedFluid to reservoir.outlet;
    connection valveToNozzle connect valve.outlet to nozzle.inlet;
    connection nozzleToDelivery connect nozzle.outlet to delivery;
  }

  part def UseEnvironment {
    part device : VaginalSyringe;
    part anatomicalInterface : VaginalCanalInterface;

    connection deliveredFluidPath connect device.delivery to anatomicalInterface.fluidEntry;
  }

  action def FillReservoir {
    in item inputFluid : IrrigationFluid;
    inout part reservoir : FluidReservoir;
    out item acceptedFluid : IrrigationFluid;

    first start;
    then verifyTemperature;
    then transferFluid;
    then filled;

    action verifyTemperature {
      assert constraint { inputFluid.temperature <= reservoir.maxFillTemperature; }
      assert constraint { inputFluid.isSterile == true; }
    }

    action transferFluid {
      bind acceptedFluid = inputFluid;
      bind reservoir.currentVolume = inputFluid.volume;
      assert constraint { reservoir.currentVolume <= reservoir.capacity; }
    }
  }

  action def DeliverIrrigationFluid {
    in item actuationForce : ManualForce;
    inout part syringe : VaginalSyringe;
    out item deliveredFluid : IrrigationFluid;

    first ready;
    then applyManualForce;
    then displaceReservoirFluid;
    then regulateFlow;
    then exitNozzle;
    then completeDelivery;

    action applyManualForce {
      bind syringe.plunger.appliedForce = actuationForce.magnitude;
      assert constraint { syringe.plunger.sealIntegrity == true; }
    }

    action displaceReservoirFluid {
      assert constraint { syringe.reservoir.currentVolume > 0.0; }
    }

    action regulateFlow {
      assert constraint { syringe.valve.backflowBlocked == true; }
      assert constraint { syringe.nozzle.outletPressure <= syringe.maximumOutletPressure; }
      assert constraint { syringe.nozzle.outletFlowRate <= syringe.maximumFlowRate; }
    }

    action exitNozzle {
      bind deliveredFluid.volume = syringe.nominalDoseVolume;
      assert constraint { deliveredFluid.volume <= syringe.reservoir.currentVolume; }
    }

    action completeDelivery {
      bind syringe.reservoir.currentVolume = syringe.reservoir.currentVolume - deliveredFluid.volume;
    }
  }

  state def SyringeUseStateMachine {
    state Empty;
    state Filled;
    state Positioned;
    state Delivering;
    state Complete;
    state Cleaning;
    state Fault;

    transition initial then Empty;

    transition Empty_to_Filled
      first Empty
      accept UserCommand
      if command.requestedDelivery == false
      then Filled;

    transition Filled_to_Positioned
      first Filled
      accept UserCommand
      if command.requestedDelivery == false
      then Positioned;

    transition Positioned_to_Delivering
      first Positioned
      accept ManualForce
      if forceIn.magnitude > 0.0
      then Delivering;

    transition Delivering_to_Complete
      first Delivering
      if deliveredFluid.volume >= nominalDoseVolume
      then Complete;

    transition Delivering_to_Fault
      first Delivering
      if nozzle.outletPressure > maximumOutletPressure
      then Fault;

    transition Complete_to_Cleaning
      first Complete
      accept UserCommand
      if command.requestedStop == true
      then Cleaning;

    transition Cleaning_to_Empty
      first Cleaning
      then Empty;
  }

  requirement def PrimaryFunctionRequirement {
    subject syringe : VaginalSyringe;

    require constraint {
      syringe.intendedPrimaryFunction == "Provide controlled intravaginal irrigation by manually delivering a measured volume of fluid through a rounded nozzle.";
    }
  }

  requirement def ReservoirCapacityRequirement {
    subject syringe : VaginalSyringe;

    require constraint {
      syringe.reservoir.capacity >= 150.0 and syringe.reservoir.capacity <= 250.0;
    }
  }

  requirement def ControlledFlowRequirement {
    subject syringe : VaginalSyringe;

    require constraint {
      syringe.nozzle.outletFlowRate <= syringe.maximumFlowRate;
    }
  }

  requirement def PressureSafetyRequirement {
    subject syringe : VaginalSyringe;

    require constraint {
      syringe.nozzle.outletPressure <= syringe.maximumOutletPressure;
    }
  }

  requirement def BackflowPreventionRequirement {
    subject syringe : VaginalSyringe;

    require constraint {
      syringe.valve.backflowBlocked == true;
    }
  }

  requirement def NozzleComfortRequirement {
    subject syringe : VaginalSyringe;

    require constraint {
      syringe.nozzle.tipRadius >= 2.5 and syringe.nozzle.outerDiameter <= 10.0;
    }
  }

  requirement def SterileFluidRequirement {
    subject fluid : IrrigationFluid;

    require constraint {
      fluid.isSterile == true and fluid.temperature <= 40.0;
    }
  }

  requirement def ManualOperationRequirement {
    subject syringe : VaginalSyringe;

    require constraint {
      syringe.plunger.appliedForce <= 35.0;
    }
  }

  satisfy PrimaryFunctionSatisfaction by VaginalSyringe;
  satisfy ReservoirCapacitySatisfaction by FluidReservoir;
  satisfy ControlledFlowSatisfaction by DeliveryNozzle;
  satisfy PressureSafetySatisfaction by DeliveryNozzle;
  satisfy BackflowPreventionSatisfaction by OneWayValve;
  satisfy NozzleComfortSatisfaction by DeliveryNozzle;
  satisfy ManualOperationSatisfaction by PlungerAssembly;

}