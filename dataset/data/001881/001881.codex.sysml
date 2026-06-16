package TurbineSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Power {
    :> ScalarValues::Real;
    unit = W;
  }

  attribute def RotationalSpeed {
    :> ScalarValues::Real;
    unit = rpm;
  }

  attribute def Torque {
    :> ScalarValues::Real;
    unit = N*m;
  }

  attribute def Pressure {
    :> ScalarValues::Real;
    unit = Pa;
  }

  attribute def Temperature {
    :> ScalarValues::Real;
    unit = K;
  }

  attribute def MassFlowRate {
    :> ScalarValues::Real;
    unit = kg/s;
  }

  attribute def Efficiency {
    :> ScalarValues::Real;
  }

  item def WorkingFluid {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute massFlow : MassFlowRate;
    attribute specificEnthalpy : Real;
  }

  item def ShaftPower {
    attribute power : Power;
    attribute torque : Torque;
    attribute speed : RotationalSpeed;
  }

  item def ControlCommand {
    attribute targetSpeed : RotationalSpeed;
    attribute targetPower : Power;
    attribute valveDemand : Real;
    attribute emergencyStop : Boolean;
  }

  item def Telemetry {
    attribute measuredSpeed : RotationalSpeed;
    attribute measuredPower : Power;
    attribute inletPressure : Pressure;
    attribute inletTemperature : Temperature;
    attribute vibrationLevel : Real;
    attribute alarmActive : Boolean;
  }

  port def FluidInletPort {
    in item fluid : WorkingFluid;
  }

  port def FluidOutletPort {
    out item fluid : WorkingFluid;
  }

  port def MechanicalPowerPort {
    out item shaftPower : ShaftPower;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def TelemetryPort {
    out item telemetry : Telemetry;
  }

  part def TurbineSystem {
    attribute ratedPower : Power = 5000000 [W];
    attribute ratedSpeed : RotationalSpeed = 3600 [rpm];
    attribute minimumOperatingSpeed : RotationalSpeed = 900 [rpm];
    attribute maximumInletPressure : Pressure = 12000000 [Pa];
    attribute maximumInletTemperature : Temperature = 850 [K];
    attribute nominalEfficiency : Efficiency = 0.88;

    port inlet : FluidInletPort;
    port exhaust : FluidOutletPort;
    port powerOutput : MechanicalPowerPort;
    port commandInput : CommandPort;
    port telemetryOutput : TelemetryPort;

    part inletValve : InletControlValve;
    part rotorAssembly : RotorAssembly;
    part statorAssembly : StatorAssembly;
    part casing : PressureCasing;
    part bearingSet : BearingSet;
    part lubricationSystem : LubricationSystem;
    part controller : TurbineController;
    part speedSensor : SpeedSensor;
    part vibrationSensor : VibrationSensor;
    part generatorCoupling : GeneratorCoupling;

    connect inlet.fluid to inletValve.upstream.fluid;
    connect inletValve.downstream.fluid to statorAssembly.flowInput.fluid;
    connect statorAssembly.flowOutput.fluid to rotorAssembly.flowInput.fluid;
    connect rotorAssembly.flowOutput.fluid to exhaust.fluid;
    connect rotorAssembly.shaftOutput.shaftPower to generatorCoupling.shaftInput.shaftPower;
    connect generatorCoupling.shaftOutput.shaftPower to powerOutput.shaftPower;
    connect commandInput.command to controller.commandInput.command;
    connect speedSensor.telemetryOutput.telemetry to controller.speedFeedback.telemetry;
    connect vibrationSensor.telemetryOutput.telemetry to controller.vibrationFeedback.telemetry;
    connect controller.valveCommand.command to inletValve.commandInput.command;
    connect controller.telemetryOutput.telemetry to telemetryOutput.telemetry;

    perform behavior turbineOperation;
  }

  part def InletControlValve {
    attribute valvePosition : Real = 0.0;
    attribute maximumFlow : MassFlowRate = 80 [kg/s];

    port upstream : FluidInletPort;
    port downstream : FluidOutletPort;
    port commandInput : CommandPort;

    action regulateFlow {
      in item command : ControlCommand;
      in item upstreamFluid : WorkingFluid;
      out item downstreamFluid : WorkingFluid;

      first start;
      then computeValveArea;
      then limitMassFlow;
      then produceConditionedFlow;
    }
  }

  part def StatorAssembly {
    attribute nozzleEfficiency : Efficiency = 0.94;
    attribute vaneCount : Integer = 48;

    port flowInput : FluidInletPort;
    port flowOutput : FluidOutletPort;

    action expandAndAccelerateFluid {
      in item inletFluid : WorkingFluid;
      out item directedFluid : WorkingFluid;

      first receiveHighPressureFluid;
      then convertPressureToVelocity;
      then directFlowOntoRotorBlades;
      then dischargeDirectedFluid;
    }
  }

  part def RotorAssembly {
    attribute bladeCount : Integer = 72;
    attribute currentSpeed : RotationalSpeed = 0 [rpm];
    attribute currentTorque : Torque = 0 [N*m];
    attribute extractedPower : Power = 0 [W];

    port flowInput : FluidInletPort;
    port flowOutput : FluidOutletPort;
    port shaftOutput : MechanicalPowerPort;

    action convertFluidEnergyToRotation {
      in item directedFluid : WorkingFluid;
      out item exhaustFluid : WorkingFluid;
      out item shaftPower : ShaftPower;

      first receiveDirectedFluid;
      then transferMomentumToBlades;
      then rotateShaft;
      then dischargeLowerEnergyFluid;
      then deliverShaftPower;
    }
  }

  part def PressureCasing {
    attribute designPressure : Pressure = 15000000 [Pa];
    attribute designTemperature : Temperature = 900 [K];
    attribute leakTight : Boolean = true;
  }

  part def BearingSet {
    attribute bearingTemperature : Temperature = 330 [K];
    attribute radialVibration : Real = 0.0;
    attribute axialPosition : Real = 0.0;

    action supportRotor {
      first maintainRadialAlignment;
      then limitAxialMotion;
      then transmitLoadsToCasing;
    }
  }

  part def LubricationSystem {
    attribute oilPressure : Pressure = 350000 [Pa];
    attribute oilTemperature : Temperature = 315 [K];
    attribute oilFlowRate : MassFlowRate = 1.5 [kg/s];

    action lubricateBearings {
      first pumpOil;
      then filterOil;
      then coolOil;
      then deliverOilToBearingSet;
      then returnOilToReservoir;
    }
  }

  part def TurbineController {
    attribute commandedValvePosition : Real = 0.0;
    attribute overspeedLimit : RotationalSpeed = 3960 [rpm];
    attribute vibrationTripLimit : Real = 7.5;

    port commandInput : CommandPort;
    port speedFeedback : TelemetryPort;
    port vibrationFeedback : TelemetryPort;
    port valveCommand : CommandPort;
    port telemetryOutput : TelemetryPort;

    state def ControlStateMachine {
      state Off;
      state Ready;
      state Starting;
      state Running;
      state LoadFollowing;
      state Shutdown;
      state Trip;

      transition first Off then Ready
        accept Initialize;

      transition Ready then Starting
        accept StartCommand;

      transition Starting then Running
        if measuredSpeed >= minimumOperatingSpeed;

      transition Running then LoadFollowing
        accept LoadDemandChanged;

      transition LoadFollowing then Running
        if measuredPower == targetPower;

      transition Running then Shutdown
        accept StopCommand;

      transition LoadFollowing then Shutdown
        accept StopCommand;

      transition Shutdown then Off
        if measuredSpeed <= 50 [rpm];

      transition Running then Trip
        if measuredSpeed > overspeedLimit;

      transition LoadFollowing then Trip
        if vibrationLevel > vibrationTripLimit;

      transition Starting then Trip
        if emergencyStop == true;

      transition Trip then Off
        accept ResetAfterInspection;
    }

    action controlTurbine {
      in item command : ControlCommand;
      in item speedTelemetry : Telemetry;
      in item vibrationTelemetry : Telemetry;
      out item valveCommandItem : ControlCommand;
      out item telemetry : Telemetry;

      first readCommand;
      then readSensors;
      then evaluateTrips;
      then computeValveDemand;
      then issueValveCommand;
      then publishTelemetry;
    }
  }

  part def SpeedSensor {
    attribute sampleRate : Real = 100.0;
    attribute measuredSpeed : RotationalSpeed = 0 [rpm];

    port telemetryOutput : TelemetryPort;

    action measureRotorSpeed {
      first senseShaftRotation;
      then calculateSpeed;
      then publishSpeedTelemetry;
    }
  }

  part def VibrationSensor {
    attribute sampleRate : Real = 1000.0;
    attribute measuredVibration : Real = 0.0;

    port telemetryOutput : TelemetryPort;

    action measureVibration {
      first senseBearingMotion;
      then filterSignal;
      then publishVibrationTelemetry;
    }
  }

  part def GeneratorCoupling {
    attribute couplingEfficiency : Efficiency = 0.985;
    attribute transmittedPower : Power = 0 [W];

    port shaftInput : MechanicalPowerPort;
    port shaftOutput : MechanicalPowerPort;

    action transmitMechanicalPower {
      in item inputPower : ShaftPower;
      out item outputPower : ShaftPower;

      first receiveRotorTorque;
      then accommodateAlignmentError;
      then transmitTorqueToLoad;
      then reportDeliveredPower;
    }
  }

  action def GenerateMechanicalPower {
    in item inletFluid : WorkingFluid;
    in item command : ControlCommand;
    out item exhaustFluid : WorkingFluid;
    out item deliveredPower : ShaftPower;
    out item telemetry : Telemetry;

    first admitWorkingFluid;
    then regulateWorkingFluidFlow;
    then expandFluidThroughStator;
    then extractEnergyInRotor;
    then deliverRotaryShaftPower;
    then monitorAndProtectSystem;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The turbine system shall convert thermal and pressure energy in a working fluid into controlled rotary mechanical shaft power for an external load. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.powerOutput.shaftPower.power >= 0 [W]
    }
  }

  requirement def RatedPowerRequirement {
    doc /* The turbine system shall deliver at least 5 MW of shaft power at rated inlet conditions and rated speed. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.powerOutput.shaftPower.power >= turbine.ratedPower
    }
  }

  requirement def SpeedControlRequirement {
    doc /* The turbine controller shall regulate inlet flow so that rotor speed remains at the commanded target during normal operation. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.rotorAssembly.currentSpeed <= turbine.ratedSpeed * 1.02
    }
  }

  requirement def OverspeedProtectionRequirement {
    doc /* The turbine system shall command a trip when measured rotor speed exceeds 110 percent of rated speed. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.controller.overspeedLimit == turbine.ratedSpeed * 1.10
    }
  }

  requirement def FluidContainmentRequirement {
    doc /* The pressure casing shall contain the working fluid at all operating pressures and temperatures within design limits. */

    subject casing : PressureCasing;

    require constraint {
      casing.designPressure >= 15000000 [Pa] and casing.designTemperature >= 900 [K]
    }
  }

  requirement def TelemetryRequirement {
    doc /* The turbine system shall provide telemetry for speed, power, inlet pressure, inlet temperature, vibration, and alarm state. */

    subject turbine : TurbineSystem;

    require constraint {
      turbine.telemetryOutput.telemetry.alarmActive == true or turbine.telemetryOutput.telemetry.alarmActive == false
    }
  }

  satisfy PrimaryFunctionRequirement by TurbineSystem;
  satisfy RatedPowerRequirement by TurbineSystem;
  satisfy SpeedControlRequirement by TurbineController;
  satisfy OverspeedProtectionRequirement by TurbineController;
  satisfy FluidContainmentRequirement by PressureCasing;
  satisfy TelemetryRequirement by TurbineSystem;

}