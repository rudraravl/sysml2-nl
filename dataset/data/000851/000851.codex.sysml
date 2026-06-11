package PumpingSubsystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::cubicMetrePerSecond;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def RotationalSpeed :> ISQ::angularVelocity {
        unit = SI::radianPerSecond;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Efficiency :> ScalarValues::Real {
        range = "0..1";
    }

    attribute def PercentOpen :> ScalarValues::Real {
        range = "0..100";
    }

    attribute def BooleanSignal :> ScalarValues::Boolean;
    attribute def CommandSignal :> ScalarValues::String;
    attribute def FaultCode :> ScalarValues::String;

    item def ProcessFluid {
        attribute density : Real;
        attribute viscosity : Real;
        attribute temperature : Temperature;
        attribute contaminationLevel : Real;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute frequency : Real;
    }

    item def ControlCommand {
        attribute command : CommandSignal;
        attribute requestedFlow : FlowRate;
        attribute requestedPressure : Pressure;
    }

    item def TelemetryData {
        attribute measuredFlow : FlowRate;
        attribute suctionPressure : Pressure;
        attribute dischargePressure : Pressure;
        attribute motorSpeed : RotationalSpeed;
        attribute motorPower : Power;
        attribute activeFault : FaultCode;
    }

    port def FluidInletPort {
        in item fluid : ProcessFluid;
        attribute pressure : Pressure;
        attribute flow : FlowRate;
    }

    port def FluidOutletPort {
        out item fluid : ProcessFluid;
        attribute pressure : Pressure;
        attribute flow : FlowRate;
    }

    port def ElectricalInputPort {
        in item power : ElectricalPower;
    }

    port def CommandInputPort {
        in item command : ControlCommand;
    }

    port def TelemetryOutputPort {
        out item telemetry : TelemetryData;
    }

    port def DrainPort {
        out item drainedFluid : ProcessFluid;
    }

    part def SuctionStrainer {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute meshSize : Real = 0.002;
        attribute differentialPressure : Pressure;
        attribute clogWarningLimit : Pressure = 25000 [SI::pascal];

        action cleanFluid {
            in item rawFluid : ProcessFluid;
            out item filteredFluid : ProcessFluid;
        }
    }

    part def IsolationValve {
        port upstream : FluidInletPort;
        port downstream : FluidOutletPort;

        attribute position : PercentOpen = 100;
        attribute commandedPosition : PercentOpen = 100;
        attribute failPosition : PercentOpen = 0;

        action openValve {
            out position : PercentOpen = 100;
        }

        action closeValve {
            out position : PercentOpen = 0;
        }
    }

    part def CheckValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute crackingPressure : Pressure = 10000 [SI::pascal];
        attribute reverseFlowDetected : BooleanSignal = false;
    }

    part def FlowMeter {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute measuredFlow : FlowRate;
        attribute accuracyPercent : Real = 1.0;
    }

    part def PressureSensor {
        port processPort : FluidInletPort;

        attribute measuredPressure : Pressure;
        attribute accuracy : Pressure = 5000 [SI::pascal];
        attribute healthy : BooleanSignal = true;
    }

    part def MotorDrive {
        port electricalInput : ElectricalInputPort;
        port commandInput : CommandInputPort;

        attribute outputPower : Power;
        attribute outputSpeed : RotationalSpeed;
        attribute enabled : BooleanSignal = false;
        attribute tripActive : BooleanSignal = false;
        attribute maximumPower : Power = 1500000 [SI::watt];
        attribute nominalVoltage : Voltage = 4160 [SI::volt];

        action startDrive {
            in command : ControlCommand;
            out enabled : BooleanSignal = true;
        }

        action stopDrive {
            out enabled : BooleanSignal = false;
        }

        action tripDrive {
            in reason : FaultCode;
            out tripActive : BooleanSignal = true;
        }
    }

    part def BigPump {
        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port drain : DrainPort;

        attribute ratedFlow : FlowRate = 0.42 [SI::cubicMetrePerSecond];
        attribute minimumContinuousFlow : FlowRate = 0.08 [SI::cubicMetrePerSecond];
        attribute ratedDifferentialPressure : Pressure = 850000 [SI::pascal];
        attribute maximumDischargePressure : Pressure = 1200000 [SI::pascal];
        attribute hydraulicEfficiency : Efficiency = 0.82;
        attribute casingTemperature : Temperature;
        attribute shaftSpeed : RotationalSpeed;
        attribute vibrationLevel : Real;
        attribute primed : BooleanSignal = false;
        attribute running : BooleanSignal = false;

        action primePump {
            in item incomingFluid : ProcessFluid;
            out primed : BooleanSignal = true;
        }

        action accelerateImpeller {
            in speedCommand : RotationalSpeed;
            out shaftSpeed : RotationalSpeed;
        }

        action pumpFluid {
            in item suctionFluid : ProcessFluid;
            in suctionPressure : Pressure;
            in shaftSpeed : RotationalSpeed;
            out item dischargeFluid : ProcessFluid;
            out dischargePressure : Pressure;
            out actualFlow : FlowRate;
        }

        action drainCasing {
            out item drainedFluid : ProcessFluid;
            out primed : BooleanSignal = false;
        }

        state def BigPumpOperatingStates {
            state Off;
            state Priming;
            state Ready;
            state Running;
            state MinimumFlowProtection;
            state Faulted;
            state Draining;

            entry action Off {
                running = false;
            }

            transition Off_to_Priming
                first Off
                then Priming
                accept ControlCommand
                if command == "PRIME";

            transition Priming_to_Ready
                first Priming
                then Ready
                if primed == true;

            transition Ready_to_Running
                first Ready
                then Running
                accept ControlCommand
                if command == "START";

            transition Running_to_MinimumFlowProtection
                first Running
                then MinimumFlowProtection
                if discharge.flow < minimumContinuousFlow;

            transition MinimumFlowProtection_to_Running
                first MinimumFlowProtection
                then Running
                if discharge.flow >= minimumContinuousFlow;

            transition Running_to_Faulted
                first Running
                then Faulted
                if discharge.pressure > maximumDischargePressure;

            transition Faulted_to_Draining
                first Faulted
                then Draining
                accept ControlCommand
                if command == "DRAIN";

            transition Draining_to_Off
                first Draining
                then Off
                if primed == false;
        }
    }

    part def PumpController {
        port commandInput : CommandInputPort;
        port telemetryOutput : TelemetryOutputPort;

        attribute targetFlow : FlowRate = 0.35 [SI::cubicMetrePerSecond];
        attribute targetDischargePressure : Pressure = 900000 [SI::pascal];
        attribute lowSuctionPressureTrip : Pressure = 120000 [SI::pascal];
        attribute highDischargePressureTrip : Pressure = 1150000 [SI::pascal];
        attribute minimumAllowedFlow : FlowRate = 0.08 [SI::cubicMetrePerSecond];
        attribute activeFault : FaultCode = "NONE";
        attribute pumpEnable : BooleanSignal = false;

        action evaluateInterlocks {
            in suctionPressure : Pressure;
            in dischargePressure : Pressure;
            in flow : FlowRate;
            out permitted : BooleanSignal;
            out fault : FaultCode;
        }

        action regulateFlow {
            in requestedFlow : FlowRate;
            in measuredFlow : FlowRate;
            out speedCommand : RotationalSpeed;
        }

        action publishTelemetry {
            in measuredFlow : FlowRate;
            in suctionPressure : Pressure;
            in dischargePressure : Pressure;
            in motorSpeed : RotationalSpeed;
            in motorPower : Power;
            in activeFault : FaultCode;
            out item telemetry : TelemetryData;
        }

        state def ControllerStates {
            state Standby;
            state PrimingCommanded;
            state Starting;
            state Regulating;
            state Stopping;
            state Trip;

            transition Standby_to_PrimingCommanded
                first Standby
                then PrimingCommanded
                accept ControlCommand
                if command == "PRIME";

            transition PrimingCommanded_to_Starting
                first PrimingCommanded
                then Starting
                accept ControlCommand
                if command == "START";

            transition Starting_to_Regulating
                first Starting
                then Regulating
                if pumpEnable == true;

            transition Regulating_to_Stopping
                first Regulating
                then Stopping
                accept ControlCommand
                if command == "STOP";

            transition Regulating_to_Trip
                first Regulating
                then Trip
                if activeFault != "NONE";

            transition Stopping_to_Standby
                first Stopping
                then Standby
                if pumpEnable == false;
        }
    }

    part def PumpingSubsystem {
        port systemInlet : FluidInletPort;
        port systemOutlet : FluidOutletPort;
        port electricalSupply : ElectricalInputPort;
        port operatorCommand : CommandInputPort;
        port telemetry : TelemetryOutputPort;
        port maintenanceDrain : DrainPort;

        part suctionValve : IsolationValve;
        part strainer : SuctionStrainer;
        part suctionPressureSensor : PressureSensor;
        part bigPump : BigPump;
        part dischargeCheckValve : CheckValve;
        part dischargeValve : IsolationValve;
        part flowMeter : FlowMeter;
        part dischargePressureSensor : PressureSensor;
        part motorDrive : MotorDrive;
        part controller : PumpController;

        connect systemInlet to suctionValve.upstream;
        connect suctionValve.downstream to strainer.inlet;
        connect strainer.outlet to suctionPressureSensor.processPort;
        connect suctionPressureSensor.processPort to bigPump.suction;
        connect bigPump.discharge to dischargeCheckValve.inlet;
        connect dischargeCheckValve.outlet to dischargeValve.upstream;
        connect dischargeValve.downstream to flowMeter.inlet;
        connect flowMeter.outlet to dischargePressureSensor.processPort;
        connect dischargePressureSensor.processPort to systemOutlet;
        connect bigPump.drain to maintenanceDrain;
        connect electricalSupply to motorDrive.electricalInput;
        connect operatorCommand to controller.commandInput;
        connect operatorCommand to motorDrive.commandInput;
        connect controller.telemetryOutput to telemetry;

        attribute nominalSubsystemFlow : FlowRate = 0.35 [SI::cubicMetrePerSecond];
        attribute nominalSubsystemDischargePressure : Pressure = 900000 [SI::pascal];
        attribute maximumSubsystemPressure : Pressure = 1200000 [SI::pascal];
        attribute minimumSuctionPressure : Pressure = 120000 [SI::pascal];
        attribute requiredAvailability : Real = 0.995;

        action startPumping {
            in item command : ControlCommand;
            out item telemetry : TelemetryData;

            first startDrive;
            then prime;
            then openDischarge;
            then regulate;
        }

        action startDrive {
            motorDrive.startDrive(command);
        }

        action prime {
            bigPump.primePump(systemInlet.fluid);
        }

        action openDischarge {
            dischargeValve.openValve();
        }

        action regulate {
            controller.regulateFlow(
                requestedFlow = controller.targetFlow,
                measuredFlow = flowMeter.measuredFlow
            );
        }

        action stopPumping {
            first stopDrive;
            then closeDischarge;
        }

        action stopDrive {
            motorDrive.stopDrive();
        }

        action closeDischarge {
            dischargeValve.closeValve();
        }

        action protectSubsystem {
            in suctionPressure : Pressure;
            in dischargePressure : Pressure;
            in actualFlow : FlowRate;
            out tripCommanded : BooleanSignal;

            controller.evaluateInterlocks(
                suctionPressure,
                dischargePressure,
                actualFlow
            );
        }

        constraint pressureBoost {
            dischargePressureSensor.measuredPressure - suctionPressureSensor.measuredPressure
                <= bigPump.ratedDifferentialPressure;
        }

        constraint noOverpressure {
            dischargePressureSensor.measuredPressure <= maximumSubsystemPressure;
        }

        constraint minimumFlowWhenRunning {
            if bigPump.running then flowMeter.measuredFlow >= bigPump.minimumContinuousFlow;
        }
    }

    requirement def ReqMoveFluid {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.systemOutlet.flow >= 0.35 [SI::cubicMetrePerSecond]
        }

        require constraint {
            subsystem.systemOutlet.pressure >= 850000 [SI::pascal]
        }

        doc /* The pumping subsystem shall move process fluid from the inlet boundary to the outlet boundary using the Big Pump. */
    }

    requirement def ReqBigPumpCapacity {
        subject pump : BigPump;

        require constraint {
            pump.ratedFlow >= 0.42 [SI::cubicMetrePerSecond]
        }

        require constraint {
            pump.ratedDifferentialPressure >= 850000 [SI::pascal]
        }

        doc /* The Big Pump shall provide the rated hydraulic capacity for normal subsystem operation. */
    }

    requirement def ReqLowSuctionProtection {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.controller.lowSuctionPressureTrip == 120000 [SI::pascal]
        }

        doc /* The subsystem shall prevent Big Pump operation below the minimum suction pressure limit. */
    }

    requirement def ReqOverpressureProtection {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.controller.highDischargePressureTrip <= 1150000 [SI::pascal]
        }

        require constraint {
            subsystem.bigPump.maximumDischargePressure <= 1200000 [SI::pascal]
        }

        doc /* The subsystem shall trip or stop the Big Pump before discharge pressure exceeds the equipment pressure limit. */
    }

    requirement def ReqMinimumFlowProtection {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.bigPump.minimumContinuousFlow >= 0.08 [SI::cubicMetrePerSecond]
        }

        doc /* The subsystem shall protect the Big Pump from operation below minimum continuous flow. */
    }

    requirement def ReqIsolation {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.suctionValve.failPosition == 0
        }

        require constraint {
            subsystem.dischargeValve.failPosition == 0
        }

        doc /* The subsystem shall provide upstream and downstream isolation for maintenance and fault response. */
    }

    requirement def ReqTelemetry {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.telemetry.telemetry.measuredFlow == subsystem.flowMeter.measuredFlow
        }

        require constraint {
            subsystem.telemetry.telemetry.suctionPressure == subsystem.suctionPressureSensor.measuredPressure
        }

        require constraint {
            subsystem.telemetry.telemetry.dischargePressure == subsystem.dischargePressureSensor.measuredPressure
        }

        doc /* The subsystem shall report flow, pressure, motor, and fault telemetry to the external control interface. */
    }

    requirement def ReqCheckValveBackflowPrevention {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.dischargeCheckValve.reverseFlowDetected == false
        }

        doc /* The subsystem shall prevent reverse flow from the outlet boundary into the Big Pump discharge. */
    }

    part pumpingSubsystem : PumpingSubsystem;

    satisfy ReqMoveFluid by pumpingSubsystem;
    satisfy ReqLowSuctionProtection by pumpingSubsystem;
    satisfy ReqOverpressureProtection by pumpingSubsystem;
    satisfy ReqMinimumFlowProtection by pumpingSubsystem;
    satisfy ReqIsolation by pumpingSubsystem;
    satisfy ReqTelemetry by pumpingSubsystem;
    satisfy ReqCheckValveBackflowPrevention by pumpingSubsystem;
    satisfy ReqBigPumpCapacity by pumpingSubsystem.bigPump;
}