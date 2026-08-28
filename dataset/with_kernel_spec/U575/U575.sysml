package 'Vacuum Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def Fluid;

    enum def PumpMode {
        standby;
        evacuating;
        maintaining;
    }

    enum def ValveState {
        closed;
        open;
    }

    attribute def StartCommand;
    attribute def ShutdownCommand;
    attribute def OpenValveCommand;
    attribute def CloseValveCommand;
    attribute def StartEvacuation;
    attribute def StartMaintaining;
    attribute def StopPump;
    attribute def OverPressureAlert;
    attribute def ReturnToNormal;

    port def FluidPort {
        item : Fluid;
    }

    part def SourceVessel {
        attribute pressure : PressureValue;
        port fluidPort : FluidPort;
    }

    part def ReceivingVessel {
        attribute pressure : PressureValue;
        attribute safePressureLimit : PressureValue;
        port fluidPort : FluidPort;
        port reliefPort : FluidPort;
    }

    part def IsolationValve {
        attribute valveState : ValveState;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def VacuumPump {
        attribute pumpMode : PumpMode;
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
    }

    part def PressureTransducer {
        attribute measuredPressure : PressureValue;
    }

    part def FlowTransducer {
        attribute measuredFlowRate : Real;
    }

    part def SafetyReliefValve {
        attribute safePressureLimit : PressureValue;
        attribute valveState : ValveState;
        port fluidIn : FluidPort;
        port ventPort : FluidPort;
    }

    part def VacuumController {
        attribute targetVacuum : PressureValue;
    }

    action def SenseSuctionPressure { out pressure : PressureValue; }
    action def SenseDischargePressure { out pressure : PressureValue; }
    action def SenseFlow { out flowRate : Real; }
    action def SenseReceivingPressure { out pressure : PressureValue; }

    action senseSuctionPressure : SenseSuctionPressure;
    action senseDischargePressure : SenseDischargePressure;
    action senseFlow : SenseFlow;
    action senseReceivingPressure : SenseReceivingPressure;

    state def ControllerStates;
    state def PumpStates;
    state def SafetyReliefStates;

    state controllerStates : ControllerStates {
        in controller : VacuumController;
        in pump : VacuumPump;
        in suctionValve : IsolationValve;
        in dischargeValve : IsolationValve;
        in suctionTransducer : PressureTransducer;
        in dischargeTransducer : PressureTransducer;
        in flowSensor : FlowTransducer;
        in reliefValve : SafetyReliefValve;
        in receivingVessel : ReceivingVessel;

        entry; then idle;
        do action {
            senseSuctionPressure;
            senseDischargePressure;
            senseFlow;
        }

        state idle;
        accept StartCommand
            then startup;

        state startup {
            entry action {
                send new OpenValveCommand() to suctionValve;
                send new OpenValveCommand() to dischargeValve;
                send new StartEvacuation() to pump;
            }
        }
        accept after 2 [s]
            then evacuating;

        state evacuating;
        accept when senseSuctionPressure.pressure <= controller.targetVacuum
            do send new StartMaintaining() to pump
            then maintaining;
        accept when senseFlow.flowRate <= 0
            then fault;
        accept OverPressureAlert
            then fault;

        state maintaining;
        accept when senseSuctionPressure.pressure > controller.targetVacuum
            do send new StartEvacuation() to pump
            then evacuating;
        accept when senseDischargePressure.pressure > receivingVessel.safePressureLimit
            then fault;
        accept ShutdownCommand
            then shutdown;
        accept OverPressureAlert
            then fault;

        state shutdown {
            entry action {
                send new StopPump() to pump;
                send new CloseValveCommand() to suctionValve;
                send new CloseValveCommand() to dischargeValve;
            }
        }
        accept after 2 [s]
            then idle;

        state fault {
            entry action {
                send new StopPump() to pump;
                send new CloseValveCommand() to suctionValve;
                send new CloseValveCommand() to dischargeValve;
            }
        }
        accept ReturnToNormal
            then idle;
    }

    state pumpStates : PumpStates {
        in pump : VacuumPump;
        entry; then standby;
        state standby;
        accept StartEvacuation
            then evacuating;
        state evacuating;
        accept StartMaintaining
            then maintaining;
        accept StopPump
            then standby;
        state maintaining;
        accept StartEvacuation
            then evacuating;
        accept StopPump
            then standby;
    }

    state safetyReliefStates : SafetyReliefStates {
        in reliefValve : SafetyReliefValve;
        in receivingVessel : ReceivingVessel;
        in controller : VacuumController;

        entry; then sealed;
        do senseReceivingPressure;

        state sealed;
        accept when senseReceivingPressure.pressure > reliefValve.safePressureLimit
            do send new OverPressureAlert() to controller
            then venting;

        state venting;
        accept when senseReceivingPressure.pressure <= reliefValve.safePressureLimit
            then sealed;
    }

    part def VacuumPumpingSubsystem {
        part sourceVessel : SourceVessel;
        part suctionIsolationValve : IsolationValve;
        part vacuumPump : VacuumPump;
        part dischargeIsolationValve : IsolationValve;
        part receivingVessel : ReceivingVessel;
        part suctionPressureTransducer : PressureTransducer;
        part dischargePressureTransducer : PressureTransducer;
        part flowTransducer : FlowTransducer;
        part safetyReliefValve : SafetyReliefValve;
        part vacuumController : VacuumController;

        connect sourceVessel.fluidPort to suctionIsolationValve.fluidIn;
        connect suctionIsolationValve.fluidOut to vacuumPump.suctionPort;
        connect vacuumPump.dischargePort to dischargeIsolationValve.fluidIn;
        connect dischargeIsolationValve.fluidOut to receivingVessel.fluidPort;
        connect receivingVessel.reliefPort to safetyReliefValve.fluidIn;

        exhibit controllerStates {
            in controller = vacuumController;
            in pump = vacuumPump;
            in suctionValve = suctionIsolationValve;
            in dischargeValve = dischargeIsolationValve;
            in suctionTransducer = suctionPressureTransducer;
            in dischargeTransducer = dischargePressureTransducer;
            in flowSensor = flowTransducer;
            in reliefValve = safetyReliefValve;
            in receivingVessel = receivingVessel;
        }

        exhibit pumpStates {
            in pump = vacuumPump;
        }

        exhibit safetyReliefStates {
            in reliefValve = safetyReliefValve;
            in receivingVessel = receivingVessel;
            in controller = vacuumController;
        }
    }

    requirement def VacuumEvacuationRequirement {
        doc /* The system shall evacuate fluid from the source vessel to the receiving vessel, creating a controlled vacuum environment. */
    }

    requirement def SafetyReliefRequirement {
        doc /* The safety relief valve shall automatically vent excess pressure from the receiving vessel when pressure exceeds the safe limit. */
    }

    requirement def PressureControlRequirement {
        doc /* The vacuum controller shall compare measured suction pressure to the target vacuum level and command the pump to switch between evacuating and maintaining modes. */
    }

    requirement def SystemHealthMonitoringRequirement {
        doc /* The system shall monitor pump performance via flow and discharge pressure transducers and enter a fault state upon detecting anomalies. */
    }

    requirement vacuumEvacuationReq : VacuumEvacuationRequirement;
    requirement safetyReliefReq : SafetyReliefRequirement;
    requirement pressureControlReq : PressureControlRequirement;
    requirement healthMonitoringReq : SystemHealthMonitoringRequirement;
}
