package PumpingSubsystemModel {

  import ScalarValues::*;
  import SI::*;

  value def Pressure {
    unit = "Pa";
    quantityKind = "pressure";
  }

  value def FlowRate {
    unit = "m^3/s";
    quantityKind = "volumetric flow rate";
  }

  value def RotationalSpeed {
    unit = "rpm";
    quantityKind = "rotational speed";
  }

  value def Power {
    unit = "W";
    quantityKind = "power";
  }

  value def Temperature {
    unit = "degC";
    quantityKind = "temperature";
  }

  value def Efficiency {
    unit = "1";
    quantityKind = "ratio";
  }

  value def Vibration {
    unit = "mm/s";
    quantityKind = "velocity";
  }

  item def ProcessFluid {
    attribute density : Real;
    attribute dynamicViscosity : Real;
    attribute temperature : Temperature;
    attribute vaporPressure : Pressure;
  }

  item def ElectricalPower {
    attribute voltage : Real;
    attribute current : Real;
    attribute frequency : Real;
    attribute activePower : Power;
  }

  item def ControlCommand {
    attribute startRequested : Boolean;
    attribute stopRequested : Boolean;
    attribute requestedSpeed : RotationalSpeed;
  }

  item def PumpStatus {
    attribute running : Boolean;
    attribute faultActive : Boolean;
    attribute measuredSpeed : RotationalSpeed;
    attribute measuredFlow : FlowRate;
    attribute dischargePressure : Pressure;
  }

  port def FluidPort {
    inout fluid : ProcessFluid;
    attribute pressure : Pressure;
    attribute flow : FlowRate;
  }

  port def PowerPort {
    in power : ElectricalPower;
  }

  port def CommandPort {
    in command : ControlCommand;
  }

  port def StatusPort {
    out status : PumpStatus;
  }

  part def CentrifugalPump {
    port suction : FluidPort;
    port discharge : FluidPort;
    port shaftPower : PowerPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;

    attribute ratedFlow : FlowRate = 0.050;
    attribute ratedHeadPressureRise : Pressure = 450000.0;
    attribute ratedSpeed : RotationalSpeed = 3600.0;
    attribute minimumContinuousFlow : FlowRate = 0.012;
    attribute maximumAllowableWorkingPressure : Pressure = 1200000.0;
    attribute hydraulicEfficiency : Efficiency = 0.78;
    attribute measuredVibration : Vibration;
    attribute casingTemperature : Temperature;
    attribute netPositiveSuctionHeadRequired : Pressure = 65000.0;

    part casing;
    part impeller {
      attribute diameter : Real = 0.215;
      attribute bladeCount : Integer = 6;
    }
    part mechanicalSeal {
      attribute sealFlushFlow : FlowRate = 0.00015;
      attribute leakageDetected : Boolean;
    }
    part bearings {
      attribute radialVibration : Vibration;
      attribute bearingTemperature : Temperature;
    }

    action startPump {
      in cmd : ControlCommand;
      out accepted : Boolean;
      first startCheck;
      then energizeMotor;
      then accelerateImpeller;
      then confirmFlow;
    }

    action stopPump {
      first rampDown;
      then deenergizeMotor;
      then verifyNoReverseFlow;
    }

    state pumpOperatingState {
      entry; then Off;

      state Off;
      state Starting;
      state Running;
      state Stopping;
      state Faulted;

      transition Off_to_Starting
        first Off
        accept ControlCommand
        if commandIn.command.startRequested
        then Starting;

      transition Starting_to_Running
        first Starting
        if statusOut.status.measuredSpeed >= 0.95 * ratedSpeed and discharge.flow >= minimumContinuousFlow
        then Running;

      transition Running_to_Stopping
        first Running
        accept ControlCommand
        if commandIn.command.stopRequested
        then Stopping;

      transition Stopping_to_Off
        first Stopping
        if statusOut.status.measuredSpeed <= 50.0
        then Off;

      transition Any_to_Faulted
        first Off
        if mechanicalSeal.leakageDetected or measuredVibration > 7.1 or discharge.pressure > maximumAllowableWorkingPressure
        then Faulted;

      transition Faulted_to_Off
        first Faulted
        accept ControlCommand
        if not commandIn.command.startRequested and not statusOut.status.faultActive
        then Off;
    }
  }

  part def ElectricMotor {
    port electricalInput : PowerPort;
    port driveOutput : PowerPort;
    port commandIn : CommandPort;

    attribute ratedPower : Power = 45000.0;
    attribute ratedSpeed : RotationalSpeed = 3600.0;
    attribute motorEfficiency : Efficiency = 0.93;
    attribute windingTemperature : Temperature;
    attribute overloadTrip : Boolean;
  }

  part def VariableFrequencyDrive {
    port lineInput : PowerPort;
    port motorOutput : PowerPort;
    port commandIn : CommandPort;
    port statusOut : StatusPort;

    attribute inputVoltage : Real = 480.0;
    attribute outputFrequency : Real;
    attribute commandedSpeed : RotationalSpeed;
    attribute driveEfficiency : Efficiency = 0.97;
    attribute faultActive : Boolean;

    action regulateSpeed {
      in requestedSpeed : RotationalSpeed;
      out outputFrequencyCommand : Real;
    }
  }

  part def SuctionStrainer {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute cleanPressureDrop : Pressure = 8000.0;
    attribute cloggedPressureDropLimit : Pressure = 35000.0;
    attribute differentialPressure : Pressure;
  }

  part def CheckValve {
    port inlet : FluidPort;
    port outlet : FluidPort;

    attribute crackingPressure : Pressure = 5000.0;
    attribute reverseFlowDetected : Boolean;
  }

  part def IsolationValve {
    port upstream : FluidPort;
    port downstream : FluidPort;

    attribute openCommanded : Boolean;
    attribute percentOpen : Real;
  }

  part def PressureTransmitter {
    port sensedFluid : FluidPort;
    port statusOut : StatusPort;

    attribute rangeLow : Pressure = 0.0;
    attribute rangeHigh : Pressure = 1600000.0;
    attribute measuredPressure : Pressure;
  }

  part def FlowTransmitter {
    port sensedFluid : FluidPort;
    port statusOut : StatusPort;

    attribute rangeLow : FlowRate = 0.0;
    attribute rangeHigh : FlowRate = 0.080;
    attribute measuredFlow : FlowRate;
  }

  part def PumpController {
    port commandOut : CommandPort;
    port pumpStatusIn : StatusPort;
    port driveStatusIn : StatusPort;

    attribute targetFlow : FlowRate = 0.045;
    attribute lowFlowAlarmLimit : FlowRate = 0.010;
    attribute highPressureTripLimit : Pressure = 1100000.0;
    attribute automaticMode : Boolean = true;

    action computeSpeedCommand {
      in measuredFlow : FlowRate;
      in targetFlow : FlowRate;
      out requestedSpeed : RotationalSpeed;
    }

    action protectPump {
      in measuredFlow : FlowRate;
      in dischargePressure : Pressure;
      out stopRequested : Boolean;
    }
  }

  part def PumpingSubsystem {
    port suctionBoundary : FluidPort;
    port dischargeBoundary : FluidPort;
    port electricalSupply : PowerPort;
    port operatorCommand : CommandPort;
    port subsystemStatus : StatusPort;

    attribute designFlow : FlowRate = 0.050;
    attribute minimumDeliveredFlow : FlowRate = 0.040;
    attribute designDischargePressure : Pressure = 850000.0;
    attribute minimumSuctionPressure : Pressure = 120000.0;
    attribute maximumFluidTemperature : Temperature = 80.0;
    attribute requiredAvailability : Real = 0.995;

    part suctionIsolationValve : IsolationValve;
    part suctionStrainer : SuctionStrainer;
    part pump : CentrifugalPump;
    part dischargeCheckValve : CheckValve;
    part dischargeIsolationValve : IsolationValve;
    part motor : ElectricMotor;
    part drive : VariableFrequencyDrive;
    part suctionPressureSensor : PressureTransmitter;
    part dischargePressureSensor : PressureTransmitter;
    part flowSensor : FlowTransmitter;
    part controller : PumpController;

    connect suctionBoundary to suctionIsolationValve.upstream;
    connect suctionIsolationValve.downstream to suctionStrainer.inlet;
    connect suctionStrainer.outlet to pump.suction;
    connect pump.discharge to dischargeCheckValve.inlet;
    connect dischargeCheckValve.outlet to dischargeIsolationValve.upstream;
    connect dischargeIsolationValve.downstream to dischargeBoundary;

    connect electricalSupply to drive.lineInput;
    connect drive.motorOutput to motor.electricalInput;
    connect motor.driveOutput to pump.shaftPower;

    connect operatorCommand to controller.commandOut;
    connect controller.commandOut to drive.commandIn;
    connect controller.commandOut to pump.commandIn;

    connect suctionStrainer.outlet to suctionPressureSensor.sensedFluid;
    connect pump.discharge to dischargePressureSensor.sensedFluid;
    connect dischargeCheckValve.outlet to flowSensor.sensedFluid;

    connect pump.statusOut to controller.pumpStatusIn;
    connect drive.statusOut to controller.driveStatusIn;
    connect pump.statusOut to subsystemStatus;

    action normalPumpingOperation {
      first openSuctionValve;
      then openDischargeValve;
      then startDrive;
      then startCentrifugalPump;
      then regulateFlow;
      then monitorProtectionLimits;
    }

    state subsystemState {
      entry; then Secured;

      state Secured;
      state Ready;
      state Starting;
      state DeliveringFluid;
      state Shutdown;
      state ProtectiveTrip;

      transition Secured_to_Ready
        first Secured
        if suctionIsolationValve.percentOpen >= 100.0 and dischargeIsolationValve.percentOpen >= 100.0
        then Ready;

      transition Ready_to_Starting
        first Ready
        accept ControlCommand
        if operatorCommand.command.startRequested
        then Starting;

      transition Starting_to_DeliveringFluid
        first Starting
        if pump.statusOut.status.running and flowSensor.measuredFlow >= minimumDeliveredFlow
        then DeliveringFluid;

      transition DeliveringFluid_to_Shutdown
        first DeliveringFluid
        accept ControlCommand
        if operatorCommand.command.stopRequested
        then Shutdown;

      transition Shutdown_to_Secured
        first Shutdown
        if not pump.statusOut.status.running
        then Secured;

      transition DeliveringFluid_to_ProtectiveTrip
        first DeliveringFluid
        if flowSensor.measuredFlow < pump.minimumContinuousFlow or dischargePressureSensor.measuredPressure > controller.highPressureTripLimit
        then ProtectiveTrip;

      transition ProtectiveTrip_to_Secured
        first ProtectiveTrip
        if not pump.statusOut.status.running
        then Secured;
    }
  }

  requirement def PumpFluidMovementRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.flowSensor.measuredFlow >= subsystem.minimumDeliveredFlow
    }

    doc
    /*
     The pumping subsystem shall move process fluid from the suction boundary to the discharge boundary using a centrifugal pump while operating in DeliveringFluid state.
    */
  }

  requirement def DischargePressureRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.dischargePressureSensor.measuredPressure >= subsystem.designDischargePressure
    }

    doc
    /*
     The subsystem shall provide the specified discharge pressure at the discharge boundary during normal pumping operation.
    */
  }

  requirement def LowFlowProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.controller.lowFlowAlarmLimit < subsystem.pump.minimumContinuousFlow
    }

    doc
    /*
     The controller shall initiate protective shutdown when measured flow falls below the pump minimum continuous flow.
    */
  }

  requirement def OverPressureProtectionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.controller.highPressureTripLimit < subsystem.pump.maximumAllowableWorkingPressure
    }

    doc
    /*
     The subsystem shall trip before pump discharge pressure exceeds the pump maximum allowable working pressure.
    */
  }

  requirement def NPSHRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.suctionPressureSensor.measuredPressure >= subsystem.pump.netPositiveSuctionHeadRequired + subsystem.pump.suction.fluid.vaporPressure
    }

    doc
    /*
     Available suction pressure shall remain sufficient to prevent cavitation at the centrifugal pump inlet.
    */
  }

  requirement def FluidTemperatureRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.pump.suction.fluid.temperature <= subsystem.maximumFluidTemperature
    }

    doc
    /*
     The subsystem shall operate only when process fluid temperature is within the qualified pump, seal, and instrumentation limits.
    */
  }

  requirement def ReverseFlowPreventionRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      not subsystem.dischargeCheckValve.reverseFlowDetected
    }

    doc
    /*
     The discharge check valve shall prevent reverse flow through the centrifugal pump after shutdown or trip.
    */
  }

  requirement def DriveSpeedControlRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.drive.commandedSpeed <= subsystem.pump.ratedSpeed
    }

    doc
    /*
     The variable frequency drive shall regulate motor speed without commanding operation above centrifugal pump rated speed.
    */
  }

  requirement def VibrationLimitRequirement {
    subject subsystem : PumpingSubsystem;

    require constraint {
      subsystem.pump.measuredVibration <= 7.1
    }

    doc
    /*
     The centrifugal pump shall remain below the allowable vibration limit during continuous operation.
    */
  }

  satisfy PumpFluidMovementRequirement by PumpingSubsystem::pump;
  satisfy DischargePressureRequirement by PumpingSubsystem::pump;
  satisfy LowFlowProtectionRequirement by PumpingSubsystem::controller;
  satisfy OverPressureProtectionRequirement by PumpingSubsystem::controller;
  satisfy NPSHRequirement by PumpingSubsystem::suctionPressureSensor;
  satisfy FluidTemperatureRequirement by PumpingSubsystem::suctionPressureSensor;
  satisfy ReverseFlowPreventionRequirement by PumpingSubsystem::dischargeCheckValve;
  satisfy DriveSpeedControlRequirement by PumpingSubsystem::drive;
  satisfy VibrationLimitRequirement by PumpingSubsystem::pump;

}