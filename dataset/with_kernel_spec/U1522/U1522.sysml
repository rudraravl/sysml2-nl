package 'Precision Fluid Transfer System' {
    private import ScalarValues::Real;
    private import ScalarFunctions::*;
    private import ISQ::Volume;
    private import ISQ::VolumeFlowRate;
    private import ISQ::Time;
    private import SI::s;

    item def Fluid;
    item def TargetFlowCommand {
        attribute targetRate : VolumeFlowRate;
    }
    item def ValveCommand {
        attribute opening : Real;
    }
    item def FlowRateReading {
        attribute rate : VolumeFlowRate;
    }

    port def FluidPort {
        out item fluid : Fluid;
    }
    port def TargetFlowPort {
        out item targetCommand : TargetFlowCommand;
    }
    port def FlowRatePort {
        out item reading : FlowRateReading;
    }
    port def ValveControlPort {
        out item command : ValveCommand;
    }

    part def SourceReservoir {
        port fluidOut : FluidPort;
        attribute volume : Volume;
    }

    part def Pump {
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
    }

    part def Pipe {
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
    }

    action def ValveOperation {
        in command : ValveCommand;
        out opening : Real;
    }

    part def FlowValve {
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
        port controlIn : ~ValveControlPort;
        attribute opening : Real = 0.5;

        perform action valveOperation : ValveOperation {
            in command = controlIn.command;
            out opening = opening;
        }
    }

    action def MeasureFlow {
        in fluidIn : Fluid;
        out reading : FlowRateReading;
    }

    part def FlowSensor {
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
        port flowRateOut : FlowRatePort;

        perform action measureFlow : MeasureFlow {
            out reading = flowRateOut.reading;
        }
    }

    action def ComputeError {
        in target : VolumeFlowRate;
        in measured : VolumeFlowRate;
        out errorValue : Real;
    }

    action def ComputeValveOpening {
        in errorValue : Real;
        out opening : Real;
    }

    part def FlowController {
        port targetIn : ~TargetFlowPort;
        port flowRateIn : ~FlowRatePort;
        port valveControlOut : ValveControlPort;

        attribute targetFlowRate : VolumeFlowRate;
        attribute gain : Real = 0.1;

        action controlLoop {
            action receiveTarget accept targetCommand : TargetFlowCommand via targetIn;
            then action receiveReading accept reading : FlowRateReading via flowRateIn;
            then action computeError : ComputeError {
                in target = receiveTarget.targetCommand.targetRate;
                in measured = receiveReading.reading.rate;
            }
            then action computeValveOpening : ComputeValveOpening {
                in errorValue = computeError.errorValue;
            }
            then action sendValveCommand send new ValveCommand(opening = computeValveOpening.opening) via valveControlOut;
        }
    }

    part def ReceivingTank {
        port fluidIn : ~FluidPort;
        attribute volume : Volume;
    }

    part def UserInterface {
        port targetOut : TargetFlowPort;
    }

    part def FluidTransferSystem {
        part userInterface : UserInterface;
        part sourceReservoir : SourceReservoir;
        part pump : Pump;
        part pipe1 : Pipe;
        part flowValve : FlowValve;
        part flowSensor : FlowSensor;
        part pipe2 : Pipe;
        part receivingTank : ReceivingTank;
        part flowController : FlowController;

        flow of Fluid from sourceReservoir.fluidOut.fluid to pump.fluidIn.fluid;
        flow of Fluid from pump.fluidOut.fluid to pipe1.fluidIn.fluid;
        flow of Fluid from pipe1.fluidOut.fluid to flowValve.fluidIn.fluid;
        flow of Fluid from flowValve.fluidOut.fluid to flowSensor.fluidIn.fluid;
        flow of Fluid from flowSensor.fluidOut.fluid to pipe2.fluidIn.fluid;
        flow of Fluid from pipe2.fluidOut.fluid to receivingTank.fluidIn.fluid;

        interface controllerToValveInterface connect flowController.valveControlOut to flowValve.controlIn {
            flow of ValveCommand from flowController.valveControlOut.command to flowValve.controlIn.command;
        }
        interface sensorToControllerInterface connect flowSensor.flowRateOut to flowController.flowRateIn {
            flow of FlowRateReading from flowSensor.flowRateOut.reading to flowController.flowRateIn.reading;
        }
        interface uiToControllerInterface connect userInterface.targetOut to flowController.targetIn {
            flow of TargetFlowCommand from userInterface.targetOut.targetCommand to flowController.targetIn.targetCommand;
        }
    }

    requirement def StableFlowRequirement {
        doc /* The system shall maintain the actual flow rate within plus or minus 5 percent of the target flow rate under steady-state conditions. */
        attribute targetFlowRate : VolumeFlowRate;
        attribute measuredFlowRate : VolumeFlowRate;
        constraint { measuredFlowRate >= targetFlowRate * 0.95 and measuredFlowRate <= targetFlowRate * 1.05 }
    }

    requirement def ResponseTimeRequirement {
        doc /* The system shall achieve a stable flow within 30 seconds of receiving a new target command. */
        attribute responseTime : Time;
        constraint { responseTime <= 30 [s] }
    }

    requirement def PrecisionFluidTransferRequirements {
        requirement stableFlow : StableFlowRequirement;
        requirement responseTime : ResponseTimeRequirement;
    }

    part systemInstance : FluidTransferSystem {
        satisfy StableFlowRequirement;
        satisfy ResponseTimeRequirement;
    }
}
