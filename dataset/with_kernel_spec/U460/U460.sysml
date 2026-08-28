package 'HighPrecisionPumpingSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def FlowRate :> ISQ::volumeFlowRate;
    attribute def Pressure :> ISQ::pressure;
    attribute def Volume :> ISQ::volume;
    attribute def RotationalSpeed :> ISQ::frequency;

    item def Fluid;
    item def StartCommand;
    item def StopCommand;
    item def AlarmSignal;
    item def FaultEvent;

    action def PrimePumpAct;
    action def ReadyForRunningAct;
    action def SetMotorSpeedToZeroAct {
        out speed : RotationalSpeed;
    }
    action def ControlFlowAct {
        in tgtFlow : FlowRate;
        in actFlow : FlowRate;
        in strVol : Volume;
        out mtrSpeed : RotationalSpeed;
    }
    action def MonitorFaultsAct {
        in dischPress : Pressure;
        in inPress : Pressure;
        in maxPress : Pressure;
        in minPress : Pressure;
        out fault : Boolean;
    }

    port def FluidPort {
        out item fluid : Fluid;
    }
    port def FlowRatePort {
        out flowRate : FlowRate;
    }
    port def PressurePort {
        out pressure : Pressure;
    }
    port def RotationalSpeedPort {
        out speed : RotationalSpeed;
    }
    port def AlarmPort {
        out alarm : AlarmSignal;
    }
    port def StartCmdPort {
        in item cmd : StartCommand;
    }
    port def StopCmdPort {
        in item cmd : StopCommand;
    }

    part def SupplyTank {
        port fluidOut : FluidPort;
        attribute capacity : Volume = 100 [L];
        attribute currentLevel : Volume = 50 [L];
    }

    part def ReceivingVessel {
        port fluidIn : ~FluidPort;
        attribute capacity : Volume = 100 [L];
        attribute currentLevel : Volume = 0 [L];
    }

    part def FlowSensor {
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
        port sensedFlowRate : FlowRatePort;
    }

    part def Motor {
        port speedCmd : ~RotationalSpeedPort;
        attribute currentSpeed : RotationalSpeed = 0 [Hz];
    }

    part def PumpHead {
        attribute strokeVolume : Volume = 0.01 [L];
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
        port dischargePressurePort : PressurePort;
        port inletPressurePort : PressurePort;
    }

    part def PressureSensor {
        port pressureOut : PressurePort;
        attribute measuredPressure : Pressure;
    }

    part def Operator {
        port startCmd : ~StartCmdPort;
        port stopCmd : ~StopCmdPort;
    }

    part def TargetSource {
        port targetOut : FlowRatePort;
        attribute targetFlowRate : FlowRate = 0.0001667 [m^3/s];
        bind targetOut.flowRate = targetFlowRate;
    }

    part def PumpController {
        attribute strokeVolume : Volume = 0.01 [L];
        attribute maxPressure : Pressure = 5000000 [Pa];
        attribute minInletPressure : Pressure = 50000 [Pa];
        attribute faultDetected : Boolean = false;

        port targetFlowRatePort : ~FlowRatePort;
        port actualFlowRatePort : ~FlowRatePort;
        port dischargePressurePort : ~PressurePort;
        port inletPressurePort : ~PressurePort;
        port motorSpeedCmdPort : RotationalSpeedPort;
        port alarmPort : AlarmPort;
        port startCmdPort : StartCmdPort;
        port stopCmdPort : StopCmdPort;

        exhibit state pumpStates {
            entry; then idle;
            state idle;
            transition idle_to_priming
                first idle
                accept startCmd : StartCommand via startCmdPort
                then priming;
            state priming {
                entry PrimePumpAct;
                exit ReadyForRunningAct;
            }
            transition priming_to_running
                first priming
                after 5 [s]
                then running;
            state running {
                do ControlFlowAct {
                    in tgtFlow = targetFlowRatePort.flowRate;
                    in actFlow = actualFlowRatePort.flowRate;
                    in strVol = strokeVolume;
                    out mtrSpeed = motorSpeedCmdPort.speed;
                }
                do MonitorFaultsAct {
                    in dischPress = dischargePressurePort.pressure;
                    in inPress = inletPressurePort.pressure;
                    in maxPress = maxPressure;
                    in minPress = minInletPressure;
                    out fault = faultDetected;
                }
            }
            transition running_to_shutdown_on_fault
                first running
                accept faultEvt : FaultEvent
                then shutdown;
            transition running_to_shutdown_on_stop
                first running
                accept stopCmd : StopCommand via stopCmdPort
                then shutdown;
            state shutdown {
                entry send new AlarmSignal() via alarmPort;
                do SetMotorSpeedToZeroAct {
                    out speed = motorSpeedCmdPort.speed;
                }
            }
            transition shutdown_to_idle
                first shutdown
                after 10 [s]
                then idle;
        }
    }

    part def MeteringPump {
        part motor : Motor;
        part pumpHead : PumpHead;
        part controller : PumpController;

        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
        port targetFlowRatePort : ~FlowRatePort;
        port actualFlowRatePort : ~FlowRatePort;
        port dischargePressurePort : ~PressurePort;
        port inletPressurePort : ~PressurePort;
        port alarmPort : AlarmPort;
        port startCmdPort : StartCmdPort;
        port stopCmdPort : StopCmdPort;

        flow of fluid : Fluid from fluidIn.fluid to pumpHead.fluidIn.fluid;
        flow of fluid : Fluid from pumpHead.fluidOut.fluid to fluidOut.fluid;
        flow of speed : RotationalSpeed from controller.motorSpeedCmdPort.speed to motor.speedCmd.speed;

        bind controller.strokeVolume = pumpHead.strokeVolume;

        bind targetFlowRatePort = controller.targetFlowRatePort;
        bind actualFlowRatePort = controller.actualFlowRatePort;
        bind dischargePressurePort = controller.dischargePressurePort;
        bind inletPressurePort = controller.inletPressurePort;
        bind alarmPort = controller.alarmPort;
        bind startCmdPort = controller.startCmdPort;
        bind stopCmdPort = controller.stopCmdPort;
    }

    requirement def AccuracyRequirement {
        doc /* The delivered flow rate shall be within 0.5% of the target flow rate under steady state conditions. */
    }
    requirement def RepeatabilityRequirement {
        doc /* The pump shall deliver consistent volume per stroke within 0.2% of the nominal stroke volume. */
    }
    requirement def ResponsivenessRequirement {
        doc /* The system shall reach the target flow rate within 2 seconds after a change in the desired flow rate. */
    }
    requirement def OverpressureProtection {
        doc /* The system shall shut down and trigger an alarm if the discharge pressure exceeds the maximum allowable pressure. */
    }
    requirement def CavitationProtection {
        doc /* The system shall shut down and trigger an alarm if the inlet pressure drops below the minimum allowable pressure. */
    }

    part context {
        part supplyTank : SupplyTank;
        part meteringPump : MeteringPump;
        part flowSensor : FlowSensor;
        part receivingVessel : ReceivingVessel;
        part dischargePressureSensor : PressureSensor;
        part inletPressureSensor : PressureSensor;
        part operator : Operator;
        part targetSource : TargetSource;

        flow of fluid : Fluid from supplyTank.fluidOut.fluid to meteringPump.fluidIn.fluid;
        flow of fluid : Fluid from meteringPump.fluidOut.fluid to flowSensor.fluidIn.fluid;
        flow of fluid : Fluid from flowSensor.fluidOut.fluid to receivingVessel.fluidIn.fluid;

        flow of flowRate : FlowRate from flowSensor.sensedFlowRate.flowRate to meteringPump.actualFlowRatePort.flowRate;
        flow of targetFlow : FlowRate from targetSource.targetOut.flowRate to meteringPump.targetFlowRatePort.flowRate;

        flow of pressure : Pressure from dischargePressureSensor.pressureOut.pressure to meteringPump.dischargePressurePort.pressure;
        flow of pressure : Pressure from inletPressureSensor.pressureOut.pressure to meteringPump.inletPressurePort.pressure;

        flow of cmd : StartCommand from operator.startCmd.cmd to meteringPump.startCmdPort.cmd;
        flow of cmd : StopCommand from operator.stopCmd.cmd to meteringPump.stopCmdPort.cmd;
    }
}
