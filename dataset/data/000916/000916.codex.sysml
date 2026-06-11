package PeristalticPumpingSubsystemModel {

  import ScalarValues::*;
  import SI::*;

  item def Fluid {
    attribute density : Real;
    attribute dynamicViscosity : Real;
    attribute temperature : Real;
  }

  item def ElectricalPower {
    attribute voltage : Real;
    attribute current : Real;
  }

  item def ControlSignal {
    attribute commandCode : String;
    attribute setpoint : Real;
  }

  item def StatusSignal {
    attribute state : String;
    attribute alarmCode : String;
  }

  attribute def FlowRate {
    attribute value : Real;
    attribute unit : String = "mL/min";
  }

  attribute def Pressure {
    attribute value : Real;
    attribute unit : String = "kPa";
  }

  attribute def Volume {
    attribute value : Real;
    attribute unit : String = "mL";
  }

  attribute def Speed {
    attribute value : Real;
    attribute unit : String = "rpm";
  }

  attribute def TimeDuration {
    attribute value : Real;
    attribute unit : String = "s";
  }

  port def FluidPort {
    inout item fluid : Fluid;
    attribute pressure : Pressure;
    attribute flowRate : FlowRate;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def CommandPort {
    in item command : ControlSignal;
  }

  port def StatusPort {
    out item status : StatusSignal;
  }

  interface def FluidInterface {
    end inlet : FluidPort;
    end outlet : FluidPort;
    flow inlet.fluid to outlet.fluid;
  }

  interface def PowerInterface {
    end supply : PowerPort;
    end load : PowerPort;
    flow supply.power to load.power;
  }

  part def FluidReservoir {
    port outlet : FluidPort;
    attribute capacity : Volume;
    attribute remainingVolume : Volume;
    attribute lowLevelThreshold : Volume;
  }

  part def PumpTubing {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute innerDiameter : Real;
    attribute wallThickness : Real;
    attribute material : String;
    attribute maximumPressure : Pressure;
    attribute displacementPerRevolution : Volume;
  }

  part def PeristalticRoller {
    attribute contactForce : Real;
    attribute diameter : Real;
  }

  part def RotorAssembly {
    port mechanicalDrive;
    part roller[3] : PeristalticRoller;
    attribute rotationalSpeed : Speed;
    attribute occlusionAngle : Real;
  }

  part def Motor {
    port powerIn : PowerPort;
    port controlIn : CommandPort;
    port shaftOut;
    attribute ratedVoltage : Real;
    attribute maximumSpeed : Speed;
    attribute commandedSpeed : Speed;
    attribute actualSpeed : Speed;
  }

  part def PumpController {
    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;
    port motorCommandOut : CommandPort;
    port sensorStatusIn;
    attribute targetFlowRate : FlowRate;
    attribute deliveredVolume : Volume;
    attribute primeDuration : TimeDuration;
  }

  part def FlowSensor {
    port fluidIn : FluidPort;
    port fluidOut : FluidPort;
    port statusOut;
    attribute measuredFlowRate : FlowRate;
    attribute accuracyPercent : Real;
  }

  part def PressureSensor {
    port fluidPort : FluidPort;
    port statusOut;
    attribute measuredPressure : Pressure;
    attribute highPressureLimit : Pressure;
  }

  part def CheckValve {
    port inlet : FluidPort;
    port outlet : FluidPort;
    attribute crackingPressure : Pressure;
    attribute preventsBackflow : Boolean = true;
  }

  part def PeristalticPump {
    port fluidIn : FluidPort;
    port fluidOut : FluidPort;
    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;

    part motor : Motor;
    part rotor : RotorAssembly;
    part tubing : PumpTubing;
    part controller : PumpController;
    part flowSensor : FlowSensor;
    part pressureSensor : PressureSensor;
    part outletValve : CheckValve;

    attribute nominalFlowRate : FlowRate;
    attribute maximumFlowRate : FlowRate;
    attribute minimumFlowRate : FlowRate;
    attribute maximumOutletPressure : Pressure;
    attribute tubingServiceLifeHours : Real;

    connect powerIn to motor.powerIn;
    connect commandIn to controller.commandIn;
    connect controller.motorCommandOut to motor.controlIn;
    connect motor.shaftOut to rotor.mechanicalDrive;

    connect fluidIn to tubing.inlet;
    connect tubing.outlet to flowSensor.fluidIn;
    connect flowSensor.fluidOut to outletValve.inlet;
    connect outletValve.outlet to fluidOut;
    connect pressureSensor.fluidPort to tubing.outlet;
    connect controller.statusOut to statusOut;
  }

  part def PumpingSubsystem {
    port fluidSourcePort : FluidPort;
    port fluidDeliveryPort : FluidPort;
    port powerInput : PowerPort;
    port commandInput : CommandPort;
    port statusOutput : StatusPort;

    part reservoir : FluidReservoir;
    part pump : PeristalticPump;

    attribute requestedFlowRate : FlowRate;
    attribute deliveredVolume : Volume;
    attribute operatingPressure : Pressure;

    connect reservoir.outlet to pump.fluidIn;
    connect pump.fluidOut to fluidDeliveryPort;
    connect powerInput to pump.powerIn;
    connect commandInput to pump.commandIn;
    connect pump.statusOut to statusOutput;
    connect reservoir.outlet to fluidSourcePort;
  }

  action def PrimePump {
    in part pump : PeristalticPump;
    in duration : TimeDuration;
    out primed : Boolean;

    first startMotor;
    then displaceAir;
    then verifyContinuousFlow;

    action startMotor;
    action displaceAir;
    action verifyContinuousFlow;
  }

  action def DeliverFluid {
    in part pump : PeristalticPump;
    in targetFlowRate : FlowRate;
    in targetVolume : Volume;
    out deliveredVolume : Volume;

    first calculateMotorSpeed;
    then regulateRotorSpeed;
    then monitorFlowAndPressure;
    then stopAtTargetVolume;

    action calculateMotorSpeed;
    action regulateRotorSpeed;
    action monitorFlowAndPressure;
    action stopAtTargetVolume;
  }

  action def DetectOcclusion {
    in pressure : Pressure;
    in highPressureLimit : Pressure;
    out occlusionDetected : Boolean;
  }

  state def PumpOperatingState {
    entry action initializeStatus;

    state Off;
    state Priming;
    state Ready;
    state Pumping;
    state OcclusionDetected;
    state LowReservoir;
    state Fault;
    state Shutdown;

    transition initial then Off;

    transition Off_to_Priming
      first Off
      accept command == "PRIME"
      then Priming;

    transition Priming_to_Ready
      first Priming
      accept primed == true
      then Ready;

    transition Ready_to_Pumping
      first Ready
      accept command == "START"
      then Pumping;

    transition Pumping_to_Ready
      first Pumping
      accept command == "STOP"
      then Ready;

    transition Pumping_to_OcclusionDetected
      first Pumping
      accept measuredPressure.value > highPressureLimit.value
      then OcclusionDetected;

    transition Pumping_to_LowReservoir
      first Pumping
      accept remainingVolume.value <= lowLevelThreshold.value
      then LowReservoir;

    transition OcclusionDetected_to_Fault
      first OcclusionDetected
      accept alarmAcknowledged == false
      then Fault;

    transition LowReservoir_to_Ready
      first LowReservoir
      accept reservoirRefilled == true
      then Ready;

    transition Ready_to_Shutdown
      first Ready
      accept command == "SHUTDOWN"
      then Shutdown;

    transition Fault_to_Off
      first Fault
      accept resetCommand == true
      then Off;
  }

  requirement def FlowControlRequirement {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.requestedFlowRate.value >= subsystem.pump.minimumFlowRate.value and
      subsystem.requestedFlowRate.value <= subsystem.pump.maximumFlowRate.value
    }
  }

  requirement def OutletPressureRequirement {
    subject pump : PeristalticPump;
    require constraint {
      pump.pressureSensor.measuredPressure.value <= pump.maximumOutletPressure.value
    }
  }

  requirement def BackflowPreventionRequirement {
    subject valve : CheckValve;
    require constraint {
      valve.preventsBackflow == true
    }
  }

  requirement def DryRunProtectionRequirement {
    subject subsystem : PumpingSubsystem;
    require constraint {
      subsystem.reservoir.remainingVolume.value > subsystem.reservoir.lowLevelThreshold.value
    }
  }

  requirement def TubingPressureRatingRequirement {
    subject pump : PeristalticPump;
    require constraint {
      pump.tubing.maximumPressure.value >= pump.maximumOutletPressure.value
    }
  }

  requirement def DeliveredVolumeRequirement {
    subject subsystem : PumpingSubsystem;
    attribute commandedVolume : Volume;
    attribute tolerancePercent : Real = 5.0;
    require constraint {
      abs(subsystem.deliveredVolume.value - commandedVolume.value) <= commandedVolume.value * tolerancePercent / 100.0
    }
  }

  part pumpingSubsystem : PumpingSubsystem {
    attribute requestedFlowRate : FlowRate {
      value = 120.0;
      unit = "mL/min";
    }

    part reservoir {
      attribute capacity : Volume {
        value = 1000.0;
        unit = "mL";
      }
      attribute remainingVolume : Volume {
        value = 850.0;
        unit = "mL";
      }
      attribute lowLevelThreshold : Volume {
        value = 50.0;
        unit = "mL";
      }
    }

    part pump {
      attribute nominalFlowRate : FlowRate {
        value = 120.0;
        unit = "mL/min";
      }
      attribute maximumFlowRate : FlowRate {
        value = 300.0;
        unit = "mL/min";
      }
      attribute minimumFlowRate : FlowRate {
        value = 5.0;
        unit = "mL/min";
      }
      attribute maximumOutletPressure : Pressure {
        value = 250.0;
        unit = "kPa";
      }
      attribute tubingServiceLifeHours = 500.0;

      part tubing {
        attribute innerDiameter = 3.2;
        attribute wallThickness = 1.6;
        attribute material = "platinum-cured silicone";
        attribute displacementPerRevolution : Volume {
          value = 1.2;
          unit = "mL";
        }
        attribute maximumPressure : Pressure {
          value = 300.0;
          unit = "kPa";
        }
      }

      part motor {
        attribute ratedVoltage = 24.0;
        attribute maximumSpeed : Speed {
          value = 250.0;
          unit = "rpm";
        }
      }

      part controller {
        attribute targetFlowRate : FlowRate {
          value = 120.0;
          unit = "mL/min";
        }
        attribute deliveredVolume : Volume {
          value = 0.0;
          unit = "mL";
        }
        attribute primeDuration : TimeDuration {
          value = 15.0;
          unit = "s";
        }
      }

      part flowSensor {
        attribute accuracyPercent = 2.0;
      }

      part pressureSensor {
        attribute highPressureLimit : Pressure {
          value = 225.0;
          unit = "kPa";
        }
      }

      part outletValve {
        attribute crackingPressure : Pressure {
          value = 5.0;
          unit = "kPa";
        }
      }
    }
  }

}