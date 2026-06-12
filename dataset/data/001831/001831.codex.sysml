package PistonSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Pressure :> Real {
    unit = "Pa";
  }

  attribute def Force :> Real {
    unit = "N";
  }

  attribute def Length :> Real {
    unit = "m";
  }

  attribute def Area :> Real {
    unit = "m^2";
  }

  attribute def Volume :> Real {
    unit = "m^3";
  }

  attribute def Temperature :> Real {
    unit = "K";
  }

  attribute def Frequency :> Real {
    unit = "Hz";
  }

  attribute def Efficiency :> Real {
    unit = "1";
  }

  attribute def Mass :> Real {
    unit = "kg";
  }

  item def WorkingFluid {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute volumeFlowRate : Real {
      unit = "m^3/s";
    }
  }

  item def MechanicalPower {
    attribute force : Force;
    attribute velocity : Real {
      unit = "m/s";
    }
    attribute power : Real {
      unit = "W";
    }
  }

  item def ThermalEnergy {
    attribute heatRate : Real {
      unit = "W";
    }
    attribute temperature : Temperature;
  }

  port def FluidPort {
    inout item fluid : WorkingFluid;
  }

  port def TranslationalMechanicalPort {
    inout item mechanicalPower : MechanicalPower;
  }

  port def ThermalPort {
    inout item heat : ThermalEnergy;
  }

  port def ControlPort {
    in item command : ControlCommand;
    out item status : PistonStatus;
  }

  item def ControlCommand {
    attribute enable : Boolean;
    attribute targetStrokeFrequency : Frequency;
    attribute requestedMode : PistonMode;
  }

  item def PistonStatus {
    attribute currentPosition : Length;
    attribute currentForce : Force;
    attribute chamberPressure : Pressure;
    attribute mode : PistonMode;
    attribute faultActive : Boolean;
  }

  enum def PistonMode {
    enum idle;
    enum intake;
    enum compression;
    enum expansion;
    enum exhaust;
    enum fault;
  }

  part def Cylinder {
    attribute boreDiameter : Length;
    attribute strokeLength : Length;
    attribute chamberVolume : Volume;
    attribute maximumPressure : Pressure;
    attribute wallMass : Mass;

    port inlet : FluidPort;
    port outlet : FluidPort;
    port chamber : FluidPort;
    port thermalBoundary : ThermalPort;
  }

  part def PistonHead {
    attribute crownArea : Area;
    attribute skirtLength : Length;
    attribute mass : Mass;
    attribute position : Length;
    attribute velocity : Real {
      unit = "m/s";
    }

    port fluidFace : FluidPort;
    port rodInterface : TranslationalMechanicalPort;
    port thermalPath : ThermalPort;
  }

  part def PistonRings {
    attribute radialSealForce : Force;
    attribute leakageRate : Real {
      unit = "m^3/s";
    }
    attribute frictionForce : Force;

    port upperSeal : FluidPort;
    port lowerSeal : FluidPort;
    port heatPath : ThermalPort;
  }

  part def ConnectingRod {
    attribute length : Length;
    attribute mass : Mass;
    attribute compressiveLoadLimit : Force;

    port pistonEnd : TranslationalMechanicalPort;
    port crankEnd : TranslationalMechanicalPort;
  }

  part def Crankshaft {
    attribute crankRadius : Length;
    attribute rotationalSpeed : Frequency;
    attribute outputTorque : Real {
      unit = "N*m";
    }

    port rodJournal : TranslationalMechanicalPort;
    port outputShaft : TranslationalMechanicalPort;
  }

  part def ValveAssembly {
    attribute intakeOpeningPressure : Pressure;
    attribute exhaustOpeningPressure : Pressure;
    attribute responseTime : Real {
      unit = "s";
    }

    port intakePort : FluidPort;
    port exhaustPort : FluidPort;
    port chamberPort : FluidPort;
    port control : ControlPort;
  }

  part def Controller {
    attribute commandedFrequency : Frequency;
    attribute measuredPressure : Pressure;
    attribute measuredPosition : Length;
    attribute enabled : Boolean;

    port operatorCommand : ControlPort;
    port valveCommand : ControlPort;
    port pistonFeedback : ControlPort;
  }

  part def PistonActuatorSystem {
    attribute nominalBoreDiameter : Length = 0.085;
    attribute nominalStrokeLength : Length = 0.095;
    attribute nominalCrownArea : Area = 0.00567;
    attribute maximumChamberPressure : Pressure = 6500000.0;
    attribute nominalOutputForce : Force = 18000.0;
    attribute nominalStrokeFrequency : Frequency = 25.0;
    attribute mechanicalEfficiency : Efficiency = 0.86;

    port fluidSupply : FluidPort;
    port fluidReturn : FluidPort;
    port mechanicalOutput : TranslationalMechanicalPort;
    port heatRejection : ThermalPort;
    port supervisoryControl : ControlPort;

    part cylinder : Cylinder {
      attribute boreDiameter = nominalBoreDiameter;
      attribute strokeLength = nominalStrokeLength;
      attribute maximumPressure = maximumChamberPressure;
    }

    part pistonHead : PistonHead {
      attribute crownArea = nominalCrownArea;
    }

    part ringPack : PistonRings;
    part connectingRod : ConnectingRod;
    part crankshaft : Crankshaft;
    part valves : ValveAssembly;
    part controller : Controller;

    connect fluidSupply to valves.intakePort;
    connect fluidReturn to valves.exhaustPort;
    connect valves.chamberPort to cylinder.chamber;
    connect cylinder.chamber to pistonHead.fluidFace;
    connect pistonHead.fluidFace to ringPack.upperSeal;
    connect ringPack.lowerSeal to cylinder.chamber;
    connect pistonHead.rodInterface to connectingRod.pistonEnd;
    connect connectingRod.crankEnd to crankshaft.rodJournal;
    connect crankshaft.outputShaft to mechanicalOutput;
    connect cylinder.thermalBoundary to heatRejection;
    connect pistonHead.thermalPath to heatRejection;
    connect ringPack.heatPath to heatRejection;
    connect supervisoryControl to controller.operatorCommand;
    connect controller.valveCommand to valves.control;
    connect controller.pistonFeedback to supervisoryControl;
  }

  action def AdmitWorkingFluid {
    in item suppliedFluid : WorkingFluid;
    out item chamberFluid : WorkingFluid;
  }

  action def CompressWorkingFluid {
    in item initialFluid : WorkingFluid;
    in attribute pistonDisplacement : Length;
    out item compressedFluid : WorkingFluid;
  }

  action def ConvertPressureToLinearForce {
    in attribute chamberPressure : Pressure;
    in attribute pistonArea : Area;
    out attribute generatedForce : Force;
  }

  action def TransferForceToOutputShaft {
    in item pistonPower : MechanicalPower;
    out item shaftPower : MechanicalPower;
  }

  action def ExhaustWorkingFluid {
    in item expandedFluid : WorkingFluid;
    out item returnedFluid : WorkingFluid;
  }

  action def RegulateStrokeCycle {
    in item command : ControlCommand;
    in item status : PistonStatus;
    out item valveCommand : ControlCommand;
  }

  state def PistonOperatingStateMachine {
    state idle;
    state intake;
    state compression;
    state expansion;
    state exhaust;
    state fault;

    transition initial then idle;

    transition idle_to_intake
      first idle
      accept ControlCommand
      if command.enable == true
      then intake;

    transition intake_to_compression
      first intake
      if status.currentPosition >= 0.095
      then compression;

    transition compression_to_expansion
      first compression
      if status.chamberPressure >= 5000000.0
      then expansion;

    transition expansion_to_exhaust
      first expansion
      if status.currentPosition <= 0.005
      then exhaust;

    transition exhaust_to_intake
      first exhaust
      if command.enable == true
      then intake;

    transition any_to_fault
      first idle
      accept PistonStatus
      if status.faultActive == true
      then fault;

    transition fault_to_idle
      first fault
      accept ControlCommand
      if command.enable == false
      then idle;
  }

  action def PistonPrimaryFunction {
    objective {
      doc
      /* Convert pressure energy in a controlled working fluid into reciprocating mechanical motion and deliver that motion as useful mechanical output force. */
    }

    in item incomingFluid : WorkingFluid;
    in item command : ControlCommand;
    out item outgoingFluid : WorkingFluid;
    out item outputPower : MechanicalPower;

    action admit : AdmitWorkingFluid {
      in suppliedFluid = incomingFluid;
    }

    action compress : CompressWorkingFluid {
      in initialFluid = admit.chamberFluid;
    }

    action forceGeneration : ConvertPressureToLinearForce {
      in chamberPressure = compress.compressedFluid.pressure;
      in pistonArea = 0.00567;
    }

    action powerTransfer : TransferForceToOutputShaft;

    action exhaust : ExhaustWorkingFluid {
      in expandedFluid = compress.compressedFluid;
      out returnedFluid = outgoingFluid;
    }

    flow forceGeneration.generatedForce to powerTransfer.pistonPower.force;
    flow powerTransfer.shaftPower to outputPower;
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /* The piston system shall convert controlled working-fluid pressure into reciprocating mechanical force at the mechanical output interface. */

    subject system : PistonActuatorSystem;

    require constraint {
      system.nominalOutputForce >= 18000.0
    }
  }

  requirement def PressureContainmentRequirement {
    doc
    /* The cylinder, piston head, and ring pack shall contain the maximum operating chamber pressure without functional leakage or structural failure. */

    subject system : PistonActuatorSystem;

    require constraint {
      system.maximumChamberPressure >= 6500000.0
    }
  }

  requirement def StrokeRequirement {
    doc
    /* The piston shall provide a defined linear stroke sufficient to displace the working fluid volume needed for the operating cycle. */

    subject system : PistonActuatorSystem;

    require constraint {
      system.nominalStrokeLength >= 0.095
    }
  }

  requirement def EfficiencyRequirement {
    doc
    /* The piston system shall preserve useful mechanical output by limiting sealing, sliding, and linkage losses. */

    subject system : PistonActuatorSystem;

    require constraint {
      system.mechanicalEfficiency >= 0.85
    }
  }

  requirement def ControlRequirement {
    doc
    /* The controller shall coordinate valve timing and piston feedback so that the piston cycles through intake, compression, expansion, and exhaust while enabled. */

    subject system : PistonActuatorSystem;

    require constraint {
      system.nominalStrokeFrequency >= 20.0 and system.nominalStrokeFrequency <= 30.0
    }
  }

  requirement def ThermalManagementRequirement {
    doc
    /* The piston system shall reject heat from the cylinder wall, piston head, and ring pack through the heat rejection interface during sustained operation. */

    subject system : PistonActuatorSystem;
  }

  satisfy PrimaryFunctionRequirement by PistonActuatorSystem;
  satisfy PressureContainmentRequirement by PistonActuatorSystem;
  satisfy StrokeRequirement by PistonActuatorSystem;
  satisfy EfficiencyRequirement by PistonActuatorSystem;
  satisfy ControlRequirement by PistonActuatorSystem;
  satisfy ThermalManagementRequirement by PistonActuatorSystem;

}