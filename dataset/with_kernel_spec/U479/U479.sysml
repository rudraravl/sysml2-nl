package 'Industrial Fluid Pumping System' {
    private import ScalarValues::Real;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;

    item def Liquid;

    attribute def StartCommand;
    attribute def StopCommand;
    attribute def SpeedReached;
    attribute def Stopped;
    attribute def CavitationAlert;
    attribute def OverloadAlert;
    attribute def IssueCleared;

    attribute def PressureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def LengthValue :> Real;
    attribute def PowerValue :> Real;

    port def FluidPort {
        out item liquid : Liquid;
    }

    port def PressureReadout {
        out attribute pressure : PressureValue;
    }

    port def FlowReadout {
        out attribute flowRate : Real;
    }

    part def ElectricMotor {
        attribute ratedPower : PowerValue = 22;
        attribute currentPower : PowerValue;
        attribute speed : Real;
    }

    part def Impeller;

    part def VoluteCasing {
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
    }

    part def Shaft {
        attribute material : String = "Stainless Steel";
    }

    state def PumpStates {
        entry; then idle;
        state idle;
        transition idle_to_starting
            first idle
            accept StartCommand
            then starting;
        state starting;
        transition starting_to_running
            first starting
            accept SpeedReached
            then running;
        state running {
            entry; then normal;
            state normal;
            transition normal_to_cavitation
                first normal
                accept CavitationAlert
                then cavitation;
            transition normal_to_overload
                first normal
                accept OverloadAlert
                then overload;
            state cavitation;
            transition cavitation_to_normal
                first cavitation
                accept IssueCleared
                then normal;
            state overload;
            transition overload_to_normal
                first overload
                accept IssueCleared
                then normal;
        }
        transition running_to_stopping
            first running
            accept StopCommand
            then stopping;
        state stopping;
        transition stopping_to_idle
            first stopping
            accept Stopped
            then idle;
    }

    part def CentrifugalPump {
        port inletPort : ~FluidPort;
        port outletPort : FluidPort;

        part motor : ElectricMotor;
        part impeller : Impeller;
        part volute : VoluteCasing;
        part shaft : Shaft;

        bind volute.fluidIn = inletPort;
        bind volute.fluidOut = outletPort;

        state pumpState : PumpStates;
    }

    part def Reservoir {
        attribute capacity : VolumeValue = 50;
        port fluidOutPort : FluidPort;
    }

    part def Pipe {
        attribute length : LengthValue;
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
    }

    part def DischargeVessel {
        attribute pressure : PressureValue;
        port fluidIn : ~FluidPort;
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port readout : PressureReadout;
    }

    part def FlowMeter {
        attribute measuredFlowRate : Real;
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
        port readout : FlowReadout;
    }

    part def ControlValve {
        attribute opening : Real;
        port fluidIn : ~FluidPort;
        port fluidOut : FluidPort;
    }

    part def PumpController {
        port inletPressureIn : ~PressureReadout;
        port outletPressureIn : ~PressureReadout;
        port flowIn : ~FlowReadout;
        attribute cavitationThreshold : PressureValue = 80;
        attribute overloadThreshold : PowerValue = 26;
    }

    part def PumpingSystem;

    part pumpingSystem : PumpingSystem {
        part sourceReservoir : Reservoir {
            attribute capacity = 50;
        }
        part suctionPipe : Pipe {
            attribute length = 15;
        }
        part pump : CentrifugalPump;
        part dischargePipe : Pipe {
            attribute length = 100;
        }
        part flowMeter : FlowMeter;
        part controlValve : ControlValve {
            attribute opening = 0.8;
        }
        part destinationVessel : DischargeVessel;

        part inletSensor : PressureSensor;
        part outletSensor : PressureSensor;
        part controller : PumpController;

        flow of liquid : Liquid from sourceReservoir.fluidOutPort.liquid to suctionPipe.fluidIn.liquid;
        flow of liquid : Liquid from suctionPipe.fluidOut.liquid to pump.inletPort.liquid;
        flow of liquid : Liquid from pump.outletPort.liquid to flowMeter.fluidIn.liquid;
        flow of liquid : Liquid from flowMeter.fluidOut.liquid to controlValve.fluidIn.liquid;
        flow of liquid : Liquid from controlValve.fluidOut.liquid to dischargePipe.fluidIn.liquid;
        flow of liquid : Liquid from dischargePipe.fluidOut.liquid to destinationVessel.fluidIn.liquid;

        connect inletSensor.readout to controller.inletPressureIn;
        connect outletSensor.readout to controller.outletPressureIn;
        connect flowMeter.readout to controller.flowIn;
    }

    requirement def PumpSystemSpecs {
        subject pumpSystem : PumpingSystem;
        requirement TransferRequirement {
            doc /* The system shall transfer liquid from a 50 cubic meter source reservoir to a pressurized destination vessel. */
        }
        requirement MotorPowerRequirement {
            doc /* The centrifugal pump shall be driven by a 22 kW electric motor. */
        }
        requirement PipeLengthRequirement {
            doc /* The suction pipe shall be 15 meters long and the discharge pipe shall be 100 meters long. */
        }
        requirement MonitoringRequirement {
            doc /* The system shall monitor inlet and outlet pressure and control flow with a discharge control valve. */
        }
    }
}
