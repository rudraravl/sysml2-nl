package PeristalticPumpSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Time::*;

    package Definitions {
        item def Fluid;
        item def ElectricPower;

        attribute def PrimeCommand;
        attribute def StartCommand;
        attribute def StopCommand;
        attribute def ResetCommand;
        attribute def FaultSignal;

        port def FluidPort {
            out item fluid : Fluid;
        }

        port def PowerPort {
            out item power : ElectricPower;
        }

        port def ControlPort {
            in attribute command;
            out attribute status;
        }

        part def FluidReservoir {
            port fluidOutPort : FluidPort;
            attribute volume : VolumeValue;
        }

        part def ReceivingTank {
            port fluidInPort : ~FluidPort;
            attribute volumeMax : VolumeValue;
            attribute currentVolume : VolumeValue;
        }

        part def PowerSupply {
            port powerOutPort : PowerPort;
        }

        part def DriveMotor {
            port powerInPort : ~PowerPort;
            port controlInPort : ~ControlPort;
            attribute speed : AngularVelocityValue;
        }

        part def Roller;
        part def OcclusionBed;

        part def FlexibleTubing {
            attribute maxCompressions : Integer;
            attribute currentCompressions : Integer;
            attribute innerDiameter : LengthValue;
        }

        part def PumpHousing {
            part occlusionBed : OcclusionBed;
            part tubing : FlexibleTubing;
        }

        part def RotorAssembly {
            attribute rollerCount : Integer = 3;
            part rollers : Roller[3];
        }

        part def PressureSensor {
            attribute measuredPressure : PressureValue;
        }

        part def PeristalticPump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port powerInPort : ~PowerPort;
            port controlInPort : ~ControlPort;

            part motor : DriveMotor;
            part rotor : RotorAssembly;
            part housing : PumpHousing;
            part pressureSensor : PressureSensor;

            attribute actualFlowRate : VolumeFlowRateValue;
            attribute maxSafePressure : PressureValue;

            perform action pumpFluid : PumpFluid;
            exhibit state pumpStates : PumpStates;
        }

        part def PumpController {
            port controlOutPort : ControlPort;
            port statusInPort : ~ControlPort;
            attribute desiredFlowRate : VolumeFlowRateValue;
            attribute maxPressure : PressureValue;
            exhibit state controllerStates : ControllerStates;
        }

        action def PumpFluid {
            in fluidIn : Fluid;
            out fluidOut : Fluid;
        }

        action def SensePressure {
            out pressure : PressureValue;
        }

        state def PumpStates {
            in pump : PeristalticPump;
            in controller : PumpController;
            entry; then idle;
            state idle;
            accept PrimeCommand then priming;
            state priming;
            accept after 5 [s] then running;
            state running;
            accept StopCommand then idle;
            accept when pump.pressureSensor.measuredPressure > pump.maxSafePressure
                do send new FaultSignal() to controller.statusInPort
                then faulted;
            state faulted;
            accept ResetCommand then idle;
        }

        state def ControllerStates {
            in controller : PumpController;
            in pump : PeristalticPump;
            entry; then monitoring;
            do sensePressure : SensePressure;
            state monitoring;
            accept PrimeCommand do send new PrimeCommand() to pump.controlInPort then priming;
            state priming;
            accept after 5 [s] do send new StartCommand() to pump.controlInPort then running;
            state running;
            accept StopCommand do send new StopCommand() to pump.controlInPort then monitoring;
            accept FaultSignal do send new StopCommand() to pump.controlInPort then faulted;
            state faulted;
            accept ResetCommand do send new ResetCommand() to pump.controlInPort then monitoring;
        }

        requirement def FlowRateAccuracy {
            attribute setpoint : VolumeFlowRateValue;
            attribute actual : VolumeFlowRateValue;
            require constraint { actual >= 0.95 * setpoint and actual <= 1.05 * setpoint }
        }

        requirement def PressureLimit {
            attribute maxPressure : PressureValue;
            attribute outletPressure : PressureValue;
            require constraint { outletPressure <= maxPressure }
        }

        requirement def TubingLifespan {
            attribute cycles : Integer;
            attribute maxCycles : Integer;
            require constraint { cycles <= maxCycles }
        }
    }

    package Usages {
        private import Definitions::*;
        private import SI::*;

        part context {
            part reservoir : FluidReservoir;
            part pump : PeristalticPump;
            part tank : ReceivingTank;
            part powerSupply : PowerSupply;
            part controller : PumpController {
                attribute maxPressure = 300 [kPa];
            }

            flow of fluid : Fluid from reservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;
            flow of fluid : Fluid from pump.fluidOutPort.fluid to tank.fluidInPort.fluid;
            connect powerSupply.powerOutPort to pump.powerInPort;
            connect controller.controlOutPort to pump.controlInPort;
            connect pump.controlInPort to controller.statusInPort;

            exhibit state pumpStates : PumpStates {
                in pump = pump;
                in controller = controller;
            }

            exhibit state controllerStates : ControllerStates {
                in controller = controller;
                in pump = pump;
            }

            satisfy requirement flowRateReq : FlowRateAccuracy {
                setpoint = controller.desiredFlowRate;
                actual = pump.actualFlowRate;
            }

            satisfy requirement pressureReq : PressureLimit {
                maxPressure = pump.maxSafePressure;
                outletPressure = pump.pressureSensor.measuredPressure;
            }

            satisfy requirement tubingReq : TubingLifespan {
                cycles = pump.housing.tubing.currentCompressions;
                maxCycles = pump.housing.tubing.maxCompressions;
            }
        }
    }
}
