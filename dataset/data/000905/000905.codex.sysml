package PumpingSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ScalarValues::Real {
        unit = "Pa";
    }

    attribute def FlowRate :> ScalarValues::Real {
        unit = "m^3/s";
    }

    attribute def Temperature :> ScalarValues::Real {
        unit = "K";
    }

    attribute def RotationalSpeed :> ScalarValues::Real {
        unit = "rpm";
    }

    attribute def ElectricPower :> ScalarValues::Real {
        unit = "W";
    }

    attribute def Voltage :> ScalarValues::Real {
        unit = "V";
    }

    attribute def Current :> ScalarValues::Real {
        unit = "A";
    }

    attribute def TimeDuration :> ScalarValues::Real {
        unit = "s";
    }

    item def Fluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : ElectricPower;
    }

    item def ControlCommand {
        attribute requestedFlowRate : FlowRate;
        attribute requestedPressure : Pressure;
        attribute startRequested : Boolean;
        attribute stopRequested : Boolean;
        attribute resetRequested : Boolean;
    }

    item def PumpTelemetry {
        attribute measuredFlowRate : FlowRate;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute motorSpeed : RotationalSpeed;
        attribute motorPower : ElectricPower;
        attribute vibrationAlarm : Boolean;
        attribute cavitationDetected : Boolean;
        attribute faultActive : Boolean;
    }

    port def FluidInletPort {
        in item incomingFluid : Fluid;
    }

    port def FluidOutletPort {
        out item outgoingFluid : Fluid;
    }

    port def ElectricalPowerPort {
        in item suppliedPower : ElectricalEnergy;
    }

    port def ControlInputPort {
        in item command : ControlCommand;
    }

    port def TelemetryOutputPort {
        out item telemetry : PumpTelemetry;
    }

    part def InletManifold {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute designPressureLimit : Pressure = 600000.0;
        attribute minimumNetPositiveSuctionPressure : Pressure = 120000.0;
    }

    part def OutletManifold {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute designPressureLimit : Pressure = 1200000.0;
        attribute checkValveCrackingPressure : Pressure = 15000.0;
    }

    part def ElectricMotor {
        port powerInput : ElectricalPowerPort;

        attribute ratedPower : ElectricPower = 7500.0;
        attribute ratedVoltage : Voltage = 480.0;
        attribute ratedCurrent : Current = 16.0;
        attribute commandedSpeed : RotationalSpeed;
        attribute actualSpeed : RotationalSpeed;
        attribute windingTemperature : Temperature;
        attribute enabled : Boolean;
    }

    part def VariableFrequencyDrive {
        port powerInput : ElectricalPowerPort;
        port commandInput : ControlInputPort;
        port telemetryOutput : TelemetryOutputPort;

        attribute dcBusVoltage : Voltage;
        attribute outputFrequency : ScalarValues::Real;
        attribute outputCurrent : Current;
        attribute driveEnabled : Boolean;
        attribute overCurrentTrip : Boolean;
    }

    part def PumpHydraulicStage {
        port suction : FluidInletPort;
        port discharge : FluidOutletPort;

        attribute impellerSpeed : RotationalSpeed;
        attribute differentialPressure : Pressure;
        attribute hydraulicEfficiency : ScalarValues::Real = 0.72;
        attribute maximumFlowRate : FlowRate = 0.035;
        attribute minimumContinuousFlowRate : FlowRate = 0.004;
    }

    part def FlowSensor {
        port sensedFluid : FluidInletPort;
        port telemetryOutput : TelemetryOutputPort;

        attribute measuredFlowRate : FlowRate;
        attribute accuracyPercentFullScale : ScalarValues::Real = 1.0;
        attribute samplePeriod : TimeDuration = 0.1;
    }

    part def PressureSensor {
        port sensedFluid : FluidInletPort;
        port telemetryOutput : TelemetryOutputPort;

        attribute measuredPressure : Pressure;
        attribute accuracyPercentFullScale : ScalarValues::Real = 0.5;
        attribute samplePeriod : TimeDuration = 0.05;
    }

    part def IntelligentPumpController {
        port commandInput : ControlInputPort;
        port telemetryOutput : TelemetryOutputPort;

        attribute targetFlowRate : FlowRate;
        attribute targetPressure : Pressure;
        attribute measuredFlowRate : FlowRate;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute motorSpeedCommand : RotationalSpeed;
        attribute faultLatched : Boolean;
        attribute cavitationMargin : Pressure;
        attribute controlPeriod : TimeDuration = 0.05;

        action computeSpeedCommand {
            in requestedFlow : FlowRate;
            in actualFlow : FlowRate;
            in requestedPressure : Pressure;
            in actualOutletPressure : Pressure;
            out speedCommand : RotationalSpeed;
        }

        action detectCavitation {
            in suctionPressure : Pressure;
            in flow : FlowRate;
            out cavitationDetected : Boolean;
        }

        action latchFault {
            in cavitationDetected : Boolean;
            in overPressure : Boolean;
            in motorTrip : Boolean;
            out faultActive : Boolean;
        }

        state controllerState {
            entry; then Idle;

            state Idle;
            state Starting;
            state Regulating;
            state Faulted;
            state Stopping;

            transition Idle_to_Starting
                first Idle
                accept ControlCommand
                if command.startRequested and not faultLatched
                then Starting;

            transition Starting_to_Regulating
                first Starting
                if motorSpeedCommand > 300.0
                then Regulating;

            transition Regulating_to_Stopping
                first Regulating
                accept ControlCommand
                if command.stopRequested
                then Stopping;

            transition Regulating_to_Faulted
                first Regulating
                if faultLatched
                then Faulted;

            transition Starting_to_Faulted
                first Starting
                if faultLatched
                then Faulted;

            transition Stopping_to_Idle
                first Stopping
                if motorSpeedCommand <= 0.0
                then Idle;

            transition Faulted_to_Idle
                first Faulted
                accept ControlCommand
                if command.resetRequested
                then Idle;
        }
    }

    part def IntelligentPump {
        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port powerInput : ElectricalPowerPort;
        port commandInput : ControlInputPort;
        port telemetryOutput : TelemetryOutputPort;

        part drive : VariableFrequencyDrive;
        part motor : ElectricMotor;
        part hydraulicStage : PumpHydraulicStage;
        part controller : IntelligentPumpController;
        part suctionPressureSensor : PressureSensor;
        part dischargePressureSensor : PressureSensor;
        part dischargeFlowSensor : FlowSensor;

        attribute ratedFlowRate : FlowRate = 0.025;
        attribute ratedDifferentialPressure : Pressure = 450000.0;
        attribute maximumOutletPressure : Pressure = 1000000.0;
        attribute minimumInletPressure : Pressure = 100000.0;
        attribute ratedSpeed : RotationalSpeed = 3600.0;
        attribute intelligentModeEnabled : Boolean = true;

        connect suction to hydraulicStage.suction;
        connect hydraulicStage.discharge to discharge;

        connect powerInput to drive.powerInput;
        connect drive.powerInput to motor.powerInput;

        connect commandInput to controller.commandInput;
        connect commandInput to drive.commandInput;

        connect controller.telemetryOutput to telemetryOutput;
        connect drive.telemetryOutput to telemetryOutput;
        connect dischargeFlowSensor.telemetryOutput to telemetryOutput;
        connect suctionPressureSensor.telemetryOutput to telemetryOutput;
        connect dischargePressureSensor.telemetryOutput to telemetryOutput;

        connect suction to suctionPressureSensor.sensedFluid;
        connect discharge to dischargePressureSensor.sensedFluid;
        connect discharge to dischargeFlowSensor.sensedFluid;

        action pumpFluid {
            in fluidAtSuction : Fluid;
            in electricalEnergy : ElectricalEnergy;
            in command : ControlCommand;
            out pressurizedFluid : Fluid;
            out telemetry : PumpTelemetry;
        }

        state pumpOperatingState {
            entry; then Off;

            state Off;
            state Priming;
            state Running;
            state Degraded;
            state Shutdown;
            state LockedOut;

            transition Off_to_Priming
                first Off
                accept ControlCommand
                if command.startRequested
                then Priming;

            transition Priming_to_Running
                first Priming
                if suctionPressureSensor.measuredPressure >= minimumInletPressure
                then Running;

            transition Running_to_Degraded
                first Running
                if controller.cavitationMargin < 20000.0
                then Degraded;

            transition Degraded_to_Running
                first Degraded
                if controller.cavitationMargin >= 40000.0
                then Running;

            transition Running_to_Shutdown
                first Running
                accept ControlCommand
                if command.stopRequested
                then Shutdown;

            transition Degraded_to_Shutdown
                first Degraded
                accept ControlCommand
                if command.stopRequested
                then Shutdown;

            transition Running_to_LockedOut
                first Running
                if controller.faultLatched
                then LockedOut;

            transition Degraded_to_LockedOut
                first Degraded
                if controller.faultLatched
                then LockedOut;

            transition Shutdown_to_Off
                first Shutdown
                if motor.actualSpeed <= 0.0
                then Off;

            transition LockedOut_to_Off
                first LockedOut
                accept ControlCommand
                if command.resetRequested
                then Off;
        }
    }

    part def PumpingSubsystem {
        port systemInlet : FluidInletPort;
        port systemOutlet : FluidOutletPort;
        port electricalSupply : ElectricalPowerPort;
        port controlInput : ControlInputPort;
        port telemetryOutput : TelemetryOutputPort;

        part inletManifold : InletManifold;
        part intelligentPump : IntelligentPump;
        part outletManifold : OutletManifold;

        attribute requiredFlowRate : FlowRate = 0.02;
        attribute normalInletPressure : Pressure = 180000.0;
        attribute normalOutletPressure : Pressure = 620000.0;
        attribute maximumStartupTime : TimeDuration = 8.0;
        attribute maximumShutdownTime : TimeDuration = 5.0;

        connect systemInlet to inletManifold.inlet;
        connect inletManifold.outlet to intelligentPump.suction;
        connect intelligentPump.discharge to outletManifold.inlet;
        connect outletManifold.outlet to systemOutlet;

        connect electricalSupply to intelligentPump.powerInput;
        connect controlInput to intelligentPump.commandInput;
        connect intelligentPump.telemetryOutput to telemetryOutput;

        action transferFluid {
            in sourceFluid : Fluid;
            in command : ControlCommand;
            in suppliedEnergy : ElectricalEnergy;
            out deliveredFluid : Fluid;
            out subsystemTelemetry : PumpTelemetry;
        }
    }

    requirement def PumpingSubsystemRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.requiredFlowRate >= 0.02
        }

        require constraint {
            subsystem.normalOutletPressure - subsystem.normalInletPressure >= 400000.0
        }
    }

    requirement def IntelligentPumpFlowControlRequirement {
        subject pump : IntelligentPump;

        require constraint {
            pump.discharge.outgoingFluid.flowRate >= 0.018 and
            pump.discharge.outgoingFluid.flowRate <= 0.022
        }
    }

    requirement def IntelligentPumpProtectionRequirement {
        subject pump : IntelligentPump;

        require constraint {
            pump.suctionPressureSensor.measuredPressure >= pump.minimumInletPressure
        }

        require constraint {
            pump.dischargePressureSensor.measuredPressure <= pump.maximumOutletPressure
        }
    }

    requirement def TelemetryRequirement {
        subject pump : IntelligentPump;

        require constraint {
            pump.controller.controlPeriod <= 0.05
        }

        require constraint {
            pump.dischargeFlowSensor.samplePeriod <= 0.1
        }
    }

    requirement def ShutdownRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.maximumShutdownTime <= 5.0
        }
    }

    part pumpingSubsystem : PumpingSubsystem;

    satisfy PumpingSubsystemRequirement by pumpingSubsystem;
    satisfy IntelligentPumpFlowControlRequirement by pumpingSubsystem.intelligentPump;
    satisfy IntelligentPumpProtectionRequirement by pumpingSubsystem.intelligentPump;
    satisfy TelemetryRequirement by pumpingSubsystem.intelligentPump;
    satisfy ShutdownRequirement by pumpingSubsystem;
}