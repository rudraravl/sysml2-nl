package DegreeOfReactionSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Ratio {
    value : Real;
    constraint validRange { value >= 0.0 and value <= 1.0 }
  }

  attribute def PressureRatio {
    value : Real;
    constraint positive { value > 0.0 }
  }

  attribute def Efficiency {
    value : Real;
    constraint validRange { value >= 0.0 and value <= 1.0 }
  }

  attribute def AngularSpeed {
    value : Real;
    unit = "rad/s";
  }

  attribute def SpecificEnthalpy {
    value : Real;
    unit = "J/kg";
  }

  attribute def MassFlowRate {
    value : Real;
    unit = "kg/s";
  }

  attribute def Torque {
    value : Real;
    unit = "N*m";
  }

  attribute def Power {
    value : Real;
    unit = "W";
  }

  attribute def Temperature {
    value : Real;
    unit = "K";
  }

  attribute def Pressure {
    value : Real;
    unit = "Pa";
  }

  attribute def FlowAngle {
    value : Real;
    unit = "deg";
  }

  item def WorkingFluid {
    attribute staticPressure : Pressure;
    attribute staticTemperature : Temperature;
    attribute stagnationPressure : Pressure;
    attribute stagnationTemperature : Temperature;
    attribute specificEnthalpy : SpecificEnthalpy;
    attribute massFlow : MassFlowRate;
  }

  item def ShaftPower {
    attribute transmittedPower : Power;
    attribute shaftTorque : Torque;
    attribute shaftSpeed : AngularSpeed;
  }

  port def FluidPort {
    inout fluid : WorkingFluid;
  }

  port def MechanicalShaftPort {
    inout power : ShaftPower;
  }

  port def ControlPort {
    in commandedReaction : Ratio;
    in commandedSpeed : AngularSpeed;
    out measuredReaction : Ratio;
    out operatingEfficiency : Efficiency;
  }

  part def ReactionStage {
    attribute degreeOfReaction : Ratio;
    attribute stagePressureRatio : PressureRatio;
    attribute stageEfficiency : Efficiency;
    attribute rotorSpeed : AngularSpeed;
    attribute stagePower : Power;

    port inlet : FluidPort;
    port outlet : FluidPort;
    port shaft : MechanicalShaftPort;

    requirement reactionDefinition {
      doc /* Degree of reaction shall be the ratio of static enthalpy change in the rotor to total static enthalpy change across the complete stage. */
      attribute rotorStaticEnthalpyChange : SpecificEnthalpy;
      attribute stageStaticEnthalpyChange : SpecificEnthalpy;
      require constraint {
        degreeOfReaction.value == rotorStaticEnthalpyChange.value / stageStaticEnthalpyChange.value
      }
    }

    requirement balancedReaction {
      doc /* The stage shall maintain degree of reaction near 0.5 during nominal operation to distribute aerodynamic loading between stator and rotor. */
      require constraint {
        degreeOfReaction.value >= 0.45 and degreeOfReaction.value <= 0.55
      }
    }
  }

  part def Stator {
    attribute inletFlowAngle : FlowAngle;
    attribute exitFlowAngle : FlowAngle;
    attribute staticPressureDrop : Pressure;
    attribute staticEnthalpyChange : SpecificEnthalpy;

    port inlet : FluidPort;
    port outlet : FluidPort;

    action redirectAndAccelerateFlow {
      in incomingFluid : WorkingFluid;
      out conditionedFluid : WorkingFluid;
      objective {
        doc /* Convert pressure potential into directed kinetic energy and establish rotor inlet swirl. */
      }
    }
  }

  part def Rotor {
    attribute bladeSpeed : AngularSpeed;
    attribute torqueProduced : Torque;
    attribute staticEnthalpyChange : SpecificEnthalpy;
    attribute relativeInletAngle : FlowAngle;
    attribute relativeExitAngle : FlowAngle;

    port inlet : FluidPort;
    port outlet : FluidPort;
    port shaft : MechanicalShaftPort;

    action exchangeEnergyWithFluid {
      in rotorInletFluid : WorkingFluid;
      out rotorOutletFluid : WorkingFluid;
      out mechanicalPower : ShaftPower;
      objective {
        doc /* Exchange energy between the working fluid and shaft while producing the rotor portion of the stage static enthalpy change. */
      }
    }
  }

  part def ReactionController {
    attribute targetReaction : Ratio;
    attribute targetSpeed : AngularSpeed;
    attribute reactionTolerance : Ratio;
    attribute measuredReaction : Ratio;

    port control : ControlPort;

    action computeReactionCorrection {
      in target : Ratio;
      in measured : Ratio;
      out vaneScheduleCommand : FlowAngle;
      out speedCommand : AngularSpeed;
    }

    state def ControlStateMachine {
      state initializing;
      state monitoring;
      state correcting;
      state faulted;

      transition first initializing;
      transition initializing_to_monitoring
        first initializing then monitoring;

      transition monitoring_to_correcting
        first monitoring then correcting
        if abs(targetReaction.value - measuredReaction.value) > reactionTolerance.value;

      transition correcting_to_monitoring
        first correcting then monitoring
        if abs(targetReaction.value - measuredReaction.value) <= reactionTolerance.value;

      transition any_to_faulted
        first monitoring then faulted
        if measuredReaction.value < 0.0 or measuredReaction.value > 1.0;
    }
  }

  part def DegreeOfReactionTurbomachinerySystem {
    doc /* Primary function: manage the distribution of thermodynamic energy conversion between stationary and rotating blade rows by controlling the degree of reaction of a turbomachinery stage. */

    attribute nominalDegreeOfReaction : Ratio = (value = 0.5);
    attribute nominalMassFlow : MassFlowRate = (value = 24.0);
    attribute nominalRotorSpeed : AngularSpeed = (value = 1250.0);
    attribute nominalPressureRatio : PressureRatio = (value = 1.32);
    attribute nominalEfficiency : Efficiency = (value = 0.88);

    port fluidInlet : FluidPort;
    port fluidOutlet : FluidPort;
    port shaftInterface : MechanicalShaftPort;
    port supervisoryControl : ControlPort;

    part stator : Stator;
    part rotor : Rotor;
    part stage : ReactionStage;
    part controller : ReactionController;

    connect fluidInlet to stator.inlet;
    connect stator.outlet to rotor.inlet;
    connect rotor.outlet to fluidOutlet;
    connect rotor.shaft to shaftInterface;
    connect supervisoryControl to controller.control;

    bind stage.inlet = stator.inlet;
    bind stage.outlet = rotor.outlet;
    bind stage.shaft = rotor.shaft;
    bind stage.degreeOfReaction = controller.measuredReaction;
    bind controller.targetReaction = nominalDegreeOfReaction;
    bind controller.targetSpeed = nominalRotorSpeed;

    action performPrimaryFunction {
      in inletFluid : WorkingFluid;
      in requestedReaction : Ratio;
      out outletFluid : WorkingFluid;
      out shaftPower : ShaftPower;

      first stator.redirectAndAccelerateFlow(
        incomingFluid = inletFluid,
        conditionedFluid = rotor.inlet.fluid
      );

      then rotor.exchangeEnergyWithFluid(
        rotorInletFluid = rotor.inlet.fluid,
        rotorOutletFluid = outletFluid,
        mechanicalPower = shaftPower
      );

      then controller.computeReactionCorrection(
        target = requestedReaction,
        measured = stage.degreeOfReaction
      );
    }

    requirement primaryFunctionRequirement {
      doc /* The system shall control a turbomachinery stage so that the degree of reaction defines how total static enthalpy change is shared between rotor and stator. */
    }

    requirement nominalOperationRequirement {
      doc /* During nominal operation the system shall maintain mass flow, pressure ratio, speed, and degree of reaction within controlled operating limits. */
      require constraint {
        stage.degreeOfReaction.value >= 0.45 and
        stage.degreeOfReaction.value <= 0.55 and
        stage.stagePressureRatio.value >= 1.20 and
        stage.stagePressureRatio.value <= 1.45 and
        stage.stageEfficiency.value >= 0.82
      }
    }

    requirement safetyRequirement {
      doc /* The controller shall enter a faulted state if computed degree of reaction is outside the physically meaningful range from zero to one. */
      require constraint {
        controller.measuredReaction.value >= 0.0 and controller.measuredReaction.value <= 1.0
      }
    }
  }

}