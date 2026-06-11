package FirePumpPumpingSubsystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> scalar;
    attribute def FlowRate :> scalar;
    attribute def Volume :> scalar;
    attribute def Speed :> scalar;
    attribute def Power :> scalar;
    attribute def Temperature :> scalar;
    attribute def Efficiency :> scalar;
    attribute def TimeDuration :> scalar;

    enum def FluidKind {
        enum water;
        enum foamSolution;
        enum glycolWater;
    }

    enum def PumpMode {
        enum off;
        enum standby;
        enum priming;
        enum running;
        enum shutdown;
        enum faulted;
    }

    enum def ValvePosition {
        enum closed;
        enum opening;
        enum open;
        enum closing;
    }

    item def FireSuppressionFluid {
        attribute kind : FluidKind = FluidKind::water;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
        attribute volume : Volume;
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
        attribute availablePower : Power;
    }

    item def ControlSignal {
        attribute commandStart : Boolean;
        attribute commandStop : Boolean;
        attribute resetFault : Boolean;
        attribute requestedOutletPressure : Pressure;
        attribute requestedFlowRate : FlowRate;
    }

    item def StatusSignal {
        attribute pumpMode : PumpMode;
        attribute actualOutletPressure : Pressure;
        attribute actualFlowRate : FlowRate;
        attribute motorSpeed : Speed;
        attribute faultActive : Boolean;
        attribute lowSuctionPressureAlarm : Boolean;
        attribute highDischargePressureAlarm : Boolean;
        attribute overTemperatureAlarm : Boolean;
    }

    port def FluidInletPort {
        in item fluidIn : FireSuppressionFluid;
    }

    port def FluidOutletPort {
        out item fluidOut : FireSuppressionFluid;
    }

    port def FluidPassThroughPort {
        in item fluidIn : FireSuppressionFluid;
        out item fluidOut : FireSuppressionFluid;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def ControlInputPort {
        in item controlIn : ControlSignal;
    }

    port def StatusOutputPort {
        out item statusOut : StatusSignal;
    }

    part def IsolationValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute position : ValvePosition = ValvePosition::closed;
        attribute nominalDiameter : Length;
        attribute maximumWorkingPressure : Pressure;
        attribute pressureDropAtRatedFlow : Pressure;

        action openValve {
            first start;
            then setOpening;
            then setOpen;
            then done;

            action setOpening {
                assign position := ValvePosition::opening;
            }

            action setOpen {
                assign position := ValvePosition::open;
            }
        }

        action closeValve {
            first start;
            then setClosing;
            then setClosed;
            then done;

            action setClosing {
                assign position := ValvePosition::closing;
            }

            action setClosed {
                assign position := ValvePosition::closed;
            }
        }
    }

    part def CheckValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute crackingPressure : Pressure;
        attribute maximumReverseLeakage : FlowRate;
        attribute open : Boolean = false;

        action allowForwardFlow {
            if inlet.fluidIn.inletPressure > crackingPressure then
                assign open := true;
            else
                assign open := false;
            end;
        }
    }

    part def Strainer {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute meshSize : Length;
        attribute cleanPressureDrop : Pressure;
        attribute cloggedPressureDropLimit : Pressure;
        attribute accumulatedDebrisVolume : Volume;

        action filterFluid {
            assign outlet.fluidOut.kind := inlet.fluidIn.kind;
            assign outlet.fluidOut.temperature := inlet.fluidIn.temperature;
            assign outlet.fluidOut.flowRate := inlet.fluidIn.flowRate;
            assign outlet.fluidOut.outletPressure := inlet.fluidIn.inletPressure - cleanPressureDrop;
        }
    }

    part def ElectricMotor {
        port power : PowerInputPort;

        attribute ratedPower : Power;
        attribute ratedSpeed : Speed;
        attribute actualSpeed : Speed = 0.0;
        attribute windingTemperature : Temperature;
        attribute efficiency : Efficiency;
        attribute energized : Boolean = false;

        action startMotor {
            assign energized := true;
            assign actualSpeed := ratedSpeed;
        }

        action stopMotor {
            assign actualSpeed := 0.0;
            assign energized := false;
        }

        action tripOnOverTemperature {
            if windingTemperature > 155.0 then
                assign actualSpeed := 0.0;
                assign energized := false;
            end;
        }
    }

    part def FirePump {
        port suction : FluidInletPort;
        port discharge : FluidOutletPort;
        port drivePower : PowerInputPort;

        part motor : ElectricMotor;

        attribute ratedFlow : FlowRate;
        attribute ratedDischargePressure : Pressure;
        attribute ratedSuctionPressureMinimum : Pressure;
        attribute shutoffPressureMaximum : Pressure;
        attribute pumpEfficiency : Efficiency;
        attribute impellerDiameter : Length;
        attribute casingTemperature : Temperature;
        attribute running : Boolean = false;

        connect drivePower.powerIn to motor.power.powerIn;

        action primePump {
            if suction.fluidIn.inletPressure >= ratedSuctionPressureMinimum then
                assign running := false;
            end;
        }

        action startPump {
            first start;
            then energizeMotor;
            then produceFlow;
            then done;

            action energizeMotor {
                perform motor.startMotor;
            }

            action produceFlow {
                if motor.energized and suction.fluidIn.inletPressure >= ratedSuctionPressureMinimum then
                    assign running := true;
                    assign discharge.fluidOut.kind := suction.fluidIn.kind;
                    assign discharge.fluidOut.temperature := suction.fluidIn.temperature;
                    assign discharge.fluidOut.flowRate := ratedFlow;
                    assign discharge.fluidOut.outletPressure := ratedDischargePressure;
                else
                    assign running := false;
                    assign discharge.fluidOut.flowRate := 0.0;
                end;
            }
        }

        action stopPump {
            perform motor.stopMotor;
            assign running := false;
            assign discharge.fluidOut.flowRate := 0.0;
        }
    }

    part def PressureReliefValve {
        port inlet : FluidInletPort;
        port returnOutlet : FluidOutletPort;

        attribute setPressure : Pressure;
        attribute reseatPressure : Pressure;
        attribute bypassFlowCapacity : FlowRate;
        attribute open : Boolean = false;

        action regulatePressure {
            if inlet.fluidIn.inletPressure > setPressure then
                assign open := true;
                assign returnOutlet.fluidOut.flowRate := bypassFlowCapacity;
            else if inlet.fluidIn.inletPressure < reseatPressure then
                assign open := false;
                assign returnOutlet.fluidOut.flowRate := 0.0;
            end;
        }
    }

    part def PressureSensor {
        port sensedFluid : FluidInletPort;

        attribute measuredPressure : Pressure;
        attribute measurementRangeMaximum : Pressure;
        attribute accuracyPercentFullScale : Real;

        action samplePressure {
            assign measuredPressure := sensedFluid.fluidIn.inletPressure;
        }
    }

    part def FlowSensor {
        port sensedFluid : FluidInletPort;

        attribute measuredFlowRate : FlowRate;
        attribute measurementRangeMaximum : FlowRate;
        attribute accuracyPercentReading : Real;

        action sampleFlow {
            assign measuredFlowRate := sensedFluid.fluidIn.flowRate;
        }
    }

    part def PumpController {
        port command : ControlInputPort;
        port status : StatusOutputPort;

        attribute mode : PumpMode = PumpMode::off;
        attribute commandedOutletPressure : Pressure;
        attribute commandedFlowRate : FlowRate;
        attribute lowSuctionTripPressure : Pressure;
        attribute highDischargeTripPressure : Pressure;
        attribute motorOverTemperatureTrip : Temperature;
        attribute faultLatched : Boolean = false;

        action evaluateCommands {
            if command.controlIn.resetFault then
                assign faultLatched := false;
                assign mode := PumpMode::standby;
            end;

            if command.controlIn.commandStart and not faultLatched then
                assign mode := PumpMode::priming;
                assign commandedOutletPressure := command.controlIn.requestedOutletPressure;
                assign commandedFlowRate := command.controlIn.requestedFlowRate;
            end;

            if command.controlIn.commandStop then
                assign mode := PumpMode::shutdown;
            end;
        }

        action publishStatus {
            assign status.statusOut.pumpMode := mode;
            assign status.statusOut.faultActive := faultLatched;
        }

        state def ControllerStateMachine {
            entry action initialize {
                assign mode := PumpMode::off;
            }

            state Off;
            state Standby;
            state Priming;
            state Running;
            state Shutdown;
            state Faulted;

            transition first Off;

            transition Off_to_Standby
                first Off
                accept command.controlIn.resetFault
                then Standby;

            transition Standby_to_Priming
                first Standby
                accept command.controlIn.commandStart
                then Priming;

            transition Priming_to_Running
                first Priming
                if not faultLatched
                then Running;

            transition Running_to_Shutdown
                first Running
                accept command.controlIn.commandStop
                then Shutdown;

            transition Shutdown_to_Standby
                first Shutdown
                then Standby;

            transition Any_to_Faulted
                first Standby
                if faultLatched
                then Faulted;

            transition Faulted_to_Standby
                first Faulted
                accept command.controlIn.resetFault
                then Standby;
        }
    }

    part def FirePumpPumpingSubsystem {
        port waterSupplyInlet : FluidInletPort;
        port pressurizedDischargeOutlet : FluidOutletPort;
        port electricalSupply : PowerInputPort;
        port controlInput : ControlInputPort;
        port statusOutput : StatusOutputPort;

        part suctionIsolationValve : IsolationValve {
            attribute nominalDiameter = 0.1524;
            attribute maximumWorkingPressure = 1200000.0;
            attribute pressureDropAtRatedFlow = 12000.0;
        }

        part suctionStrainer : Strainer {
            attribute meshSize = 0.003;
            attribute cleanPressureDrop = 8000.0;
            attribute cloggedPressureDropLimit = 35000.0;
            attribute accumulatedDebrisVolume = 0.0;
        }

        part pump : FirePump {
            attribute ratedFlow = 0.063;
            attribute ratedDischargePressure = 1034000.0;
            attribute ratedSuctionPressureMinimum = 70000.0;
            attribute shutoffPressureMaximum = 1240000.0;
            attribute pumpEfficiency = 0.74;
            attribute impellerDiameter = 0.32;
            attribute casingTemperature = 25.0;
        }

        part dischargeCheckValve : CheckValve {
            attribute crackingPressure = 15000.0;
            attribute maximumReverseLeakage = 0.0001;
        }

        part dischargeIsolationValve : IsolationValve {
            attribute nominalDiameter = 0.1524;
            attribute maximumWorkingPressure = 1400000.0;
            attribute pressureDropAtRatedFlow = 10000.0;
        }

        part reliefValve : PressureReliefValve {
            attribute setPressure = 1160000.0;
            attribute reseatPressure = 1080000.0;
            attribute bypassFlowCapacity = 0.015;
        }

        part suctionPressureSensor : PressureSensor {
            attribute measurementRangeMaximum = 700000.0;
            attribute accuracyPercentFullScale = 0.5;
        }

        part dischargePressureSensor : PressureSensor {
            attribute measurementRangeMaximum = 1600000.0;
            attribute accuracyPercentFullScale = 0.5;
        }

        part dischargeFlowSensor : FlowSensor {
            attribute measurementRangeMaximum = 0.1;
            attribute accuracyPercentReading = 1.0;
        }

        part controller : PumpController {
            attribute lowSuctionTripPressure = 50000.0;
            attribute highDischargeTripPressure = 1250000.0;
            attribute motorOverTemperatureTrip = 155.0;
        }

        connect waterSupplyInlet.fluidIn to suctionIsolationValve.inlet.fluidIn;
        connect suctionIsolationValve.outlet.fluidOut to suctionStrainer.inlet.fluidIn;
        connect suctionStrainer.outlet.fluidOut to pump.suction.fluidIn;
        connect pump.discharge.fluidOut to dischargeCheckValve.inlet.fluidIn;
        connect dischargeCheckValve.outlet.fluidOut to dischargeIsolationValve.inlet.fluidIn;
        connect dischargeIsolationValve.outlet.fluidOut to pressurizedDischargeOutlet.fluidOut;

        connect electricalSupply.powerIn to pump.drivePower.powerIn;
        connect controlInput.controlIn to controller.command.controlIn;
        connect controller.status.statusOut to statusOutput.statusOut;

        connect pump.suction.fluidIn to suctionPressureSensor.sensedFluid.fluidIn;
        connect pump.discharge.fluidOut to dischargePressureSensor.sensedFluid.fluidIn;
        connect pump.discharge.fluidOut to dischargeFlowSensor.sensedFluid.fluidIn;
        connect pump.discharge.fluidOut to reliefValve.inlet.fluidIn;
        connect reliefValve.returnOutlet.fluidOut to suctionStrainer.inlet.fluidIn;

        action startSubsystem {
            first receiveCommand;
            then openSuctionValve;
            then openDischargeValve;
            then prime;
            then startPumpAction;
            then monitor;
            then done;

            action receiveCommand {
                perform controller.evaluateCommands;
            }

            action openSuctionValve {
                perform suctionIsolationValve.openValve;
            }

            action openDischargeValve {
                perform dischargeIsolationValve.openValve;
            }

            action prime {
                perform pump.primePump;
            }

            action startPumpAction {
                perform pump.startPump;
            }

            action monitor {
                perform suctionPressureSensor.samplePressure;
                perform dischargePressureSensor.samplePressure;
                perform dischargeFlowSensor.sampleFlow;
                perform reliefValve.regulatePressure;

                assign controller.status.statusOut.actualOutletPressure := dischargePressureSensor.measuredPressure;
                assign controller.status.statusOut.actualFlowRate := dischargeFlowSensor.measuredFlowRate;
                assign controller.status.statusOut.motorSpeed := pump.motor.actualSpeed;

                if suctionPressureSensor.measuredPressure < controller.lowSuctionTripPressure then
                    assign controller.status.statusOut.lowSuctionPressureAlarm := true;
                    assign controller.faultLatched := true;
                    assign controller.mode := PumpMode::faulted;
                end;

                if dischargePressureSensor.measuredPressure > controller.highDischargeTripPressure then
                    assign controller.status.statusOut.highDischargePressureAlarm := true;
                    assign controller.faultLatched := true;
                    assign controller.mode := PumpMode::faulted;
                end;

                if pump.motor.windingTemperature > controller.motorOverTemperatureTrip then
                    assign controller.status.statusOut.overTemperatureAlarm := true;
                    assign controller.faultLatched := true;
                    assign controller.mode := PumpMode::faulted;
                    perform pump.stopPump;
                end;

                perform controller.publishStatus;
            }
        }

        action stopSubsystem {
            first stopPumpAction;
            then closeDischargeValve;
            then closeSuctionValve;
            then publishStopped;
            then done;

            action stopPumpAction {
                perform pump.stopPump;
            }

            action closeDischargeValve {
                perform dischargeIsolationValve.closeValve;
            }

            action closeSuctionValve {
                perform suctionIsolationValve.closeValve;
            }

            action publishStopped {
                assign controller.mode := PumpMode::standby;
                perform controller.publishStatus;
            }
        }
    }

    requirement def PumpFluidMovementRequirement {
        subject subsystem : FirePumpPumpingSubsystem;

        require constraint {
            subsystem.pump.ratedFlow >= 0.05 and
            subsystem.pump.ratedDischargePressure >= 900000.0 and
            subsystem.pump.ratedSuctionPressureMinimum <= 100000.0
        }

        doc
        /* The pumping subsystem shall move fire suppression fluid from the water supply inlet to the pressurized discharge outlet using a fire pump. */
    }

    requirement def AutomaticStartRequirement {
        subject subsystem : FirePumpPumpingSubsystem;

        require constraint {
            subsystem.controller.mode == PumpMode::running implies
            subsystem.pump.running == true and
            subsystem.suctionIsolationValve.position == ValvePosition::open and
            subsystem.dischargeIsolationValve.position == ValvePosition::open
        }

        doc
        /* The subsystem shall automatically open the suction and discharge isolation valves and start the fire pump when a valid start command is received. */
    }

    requirement def MinimumSuctionProtectionRequirement {
        subject subsystem : FirePumpPumpingSubsystem;

        require constraint {
            subsystem.suctionPressureSensor.measuredPressure < subsystem.controller.lowSuctionTripPressure implies
            subsystem.controller.faultLatched == true
        }

        doc
        /* The subsystem shall latch a fault when suction pressure falls below the configured low suction trip pressure. */
    }

    requirement def OverPressureProtectionRequirement {
        subject subsystem : FirePumpPumpingSubsystem;

        require constraint {
            subsystem.dischargePressureSensor.measuredPressure > subsystem.controller.highDischargeTripPressure implies
            subsystem.reliefValve.open == true or subsystem.controller.faultLatched == true
        }

        doc
        /* The subsystem shall protect the discharge line from overpressure using a relief valve and controller fault logic. */
    }

    requirement def BackflowPreventionRequirement {
        subject subsystem : FirePumpPumpingSubsystem;

        require constraint {
            subsystem.dischargeCheckValve.maximumReverseLeakage <= 0.0001
        }

        doc
        /* The subsystem shall prevent reverse flow from the pressurized discharge outlet back through the fire pump. */
    }

    requirement def StatusReportingRequirement {
        subject subsystem : FirePumpPumpingSubsystem;

        require constraint {
            subsystem.statusOutput.statusOut.actualOutletPressure == subsystem.dischargePressureSensor.measuredPressure and
            subsystem.statusOutput.statusOut.actualFlowRate == subsystem.dischargeFlowSensor.measuredFlowRate
        }

        doc
        /* The subsystem shall report pump mode, outlet pressure, discharge flow rate, motor speed, and active alarms through its status output port. */
    }

    part firePumpPumpingSubsystem : FirePumpPumpingSubsystem;

    satisfy PumpFluidMovementRequirement by firePumpPumpingSubsystem;
    satisfy AutomaticStartRequirement by firePumpPumpingSubsystem;
    satisfy MinimumSuctionProtectionRequirement by firePumpPumpingSubsystem;
    satisfy OverPressureProtectionRequirement by firePumpPumpingSubsystem;
    satisfy BackflowPreventionRequirement by firePumpPumpingSubsystem;
    satisfy StatusReportingRequirement by firePumpPumpingSubsystem;
}