package 'Precision Fluid Pumping Subsystem' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ISQ::VolumeFlowRate;
    private import ISQ::Pressure;
    private import ISQ::ElectricPotential;
    private import ISQ::Frequency;

    item def Fluid;

    attribute def ControlSignal {
        attribute voltage : ElectricPotential;
        attribute frequency : Frequency;
    }

    attribute def TargetFlow {
        attribute value : VolumeFlowRate;
    }

    attribute def FlowReading {
        attribute flowRate : VolumeFlowRate;
    }

    attribute def PressureReading {
        attribute pressure : Pressure;
    }

    attribute def StartCommand;
    attribute def StopCommand;
    attribute def EmergencyStopCommand;
    attribute def ResetCommand;
    attribute def PrimingComplete;
    attribute def FlowDeviation;
    attribute def FlowCorrected;

    port def FluidOutPort {
        out item fluid : Fluid;
    }

    port def FluidInPort {
        in item fluid : Fluid;
    }

    port def ControlOutPort {
        out signal : ControlSignal;
    }

    port def ControlInPort {
        in signal : ControlSignal;
    }

    port def FlowDataOutPort {
        out data : FlowReading;
    }

    port def FlowDataInPort {
        in data : FlowReading;
    }

    port def PressureDataOutPort {
        out data : PressureReading;
    }

    port def PressureDataInPort {
        in data : PressureReading;
    }

    port def TargetInPort {
        in target : TargetFlow;
    }

    port def DrivePort;

    part def SourceReservoir {
        port fluidOutPort : FluidOutPort;
    }

    part def DestinationReceiver {
        port fluidInPort : FluidInPort;
    }

    part def PiezoelectricActuator {
        port controlInPort : ControlInPort;
        port driveOut : DrivePort;
    }

    part def Membrane {
        port driveIn : DrivePort;
        port chamberDrive : DrivePort;
    }

    part def PumpChamber {
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        port membraneDrive : DrivePort;
    }

    part def CheckValve {
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
    }

    part def ImpedancePump {
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        port controlInPort : ControlInPort;

        part actuator : PiezoelectricActuator;
        part membrane : Membrane;
        part chamber : PumpChamber;
        part inletValve : CheckValve;
        part outletValve : CheckValve;

        bind controlInPort = actuator.controlInPort;
        bind actuator.driveOut = membrane.driveIn;
        bind membrane.chamberDrive = chamber.membraneDrive;

        flow of fluid : Fluid from fluidInPort.fluid to inletValve.fluidInPort.fluid;
        flow of fluid : Fluid from inletValve.fluidOutPort.fluid to chamber.fluidInPort.fluid;
        flow of fluid : Fluid from chamber.fluidOutPort.fluid to outletValve.fluidInPort.fluid;
        flow of fluid : Fluid from outletValve.fluidOutPort.fluid to fluidOutPort.fluid;
    }

    part def PressureSensor {
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        port dataOutPort : PressureDataOutPort;
    }

    part def FlowSensor {
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        port dataOutPort : FlowDataOutPort;
    }

    action def ControlLoop {
        in target : VolumeFlowRate;
        in actualFlow : VolumeFlowRate;
        in actualPressure : Pressure;
        out controlSignal : ControlSignal;

        first start;
        then decide;
        if actualFlow < target then increaseFlow;
        if actualFlow > target then decreaseFlow;
        if actualFlow == target then maintainFlow;

        action increaseFlow {
            out controlSignal : ControlSignal;
        }
        then done;
        action decreaseFlow {
            out controlSignal : ControlSignal;
        }
        then done;
        action maintainFlow {
            out controlSignal : ControlSignal;
        }
        then done;
    }

    state def PumpingSystemStates {
        entry; then idle;
        state idle;
        accept StartCommand then priming;
        state priming;
        accept PrimingComplete then running;
        state running {
            entry; then normal;
            state normal;
            state adjusting;
            transition first normal accept FlowDeviation then adjusting;
            transition first adjusting accept FlowCorrected then normal;
        }
        accept StopCommand then shutdown;
        accept EmergencyStopCommand then emergencyStop;
        state shutdown;
        accept ResetCommand then idle;
        state emergencyStop;
        accept ResetCommand then reset;
        state reset;
        transition first reset then idle;
    }

    part def Controller {
        port targetInPort : TargetInPort;
        port flowDataInPort : FlowDataInPort;
        port pressureDataInPort : PressureDataInPort;
        port controlOutPort : ControlOutPort;

        attribute targetFlowRate : VolumeFlowRate;
        attribute currentFlowRate : VolumeFlowRate;
        attribute currentPressure : Pressure;

        perform action controlLoop : ControlLoop {
            in target = targetFlowRate;
            in actualFlow = currentFlowRate;
            in actualPressure = currentPressure;
            out controlSignal = controlOutPort.signal;
        }

        state controllerState : PumpingSystemStates;
    }

    requirement def PrecisionFlowControl {
        doc /* The system shall transfer liquid from a source to a destination at a controlled rate using an impedance pump with piezoelectric actuation. */
        attribute targetFlowRate : VolumeFlowRate;
        attribute tolerance : Real = 0.05;
    }

    requirement def ClosedLoopControl {
        doc /* The controller shall continuously compare actual flow rate with target flow rate and adjust voltage and frequency to the piezoelectric actuator to correct deviations. */
    }

    requirement def OperationalStates {
        doc /* The system shall transition through idle, priming, running (normal/adjusting), shutdown, emergency stop, and reset states based on sensor feedback and operator commands. */
    }

    part systemContext {
        part source : SourceReservoir;
        part pump : ImpedancePump;
        part destination : DestinationReceiver;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : Controller;

        flow of fluid : Fluid from source.fluidOutPort.fluid to pump.fluidInPort.fluid;
        flow of fluid : Fluid from pump.fluidOutPort.fluid to pressureSensor.fluidInPort.fluid;
        flow of fluid : Fluid from pressureSensor.fluidOutPort.fluid to flowSensor.fluidInPort.fluid;
        flow of fluid : Fluid from flowSensor.fluidOutPort.fluid to destination.fluidInPort.fluid;

        flow of data : PressureReading from pressureSensor.dataOutPort.data to controller.pressureDataInPort.data;
        flow of data : FlowReading from flowSensor.dataOutPort.data to controller.flowDataInPort.data;

        flow of signal : ControlSignal from controller.controlOutPort.signal to pump.controlInPort.signal;

        state systemState : PumpingSystemStates;

        satisfy precisionFlowControl : PrecisionFlowControl;
        satisfy closedLoopControl : ClosedLoopControl;
        satisfy operationalStates : OperationalStates;
    }
}
