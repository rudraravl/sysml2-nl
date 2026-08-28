package AirDrivenPumpingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import MeasurementReferences::*;
    public import Definitions::*;

    package Definitions {
        item def Fluid;
        item def Air;

        attribute def StartCommand;
        attribute def StopCommand;
        attribute def OverPressureAlert;
        attribute def ResetCommand;

        port def AirPort {
            out item air : Air;
        }
        port def FluidPort {
            out item fluid : Fluid;
        }
        port def PressureSignalPort {
            out pressure : PressureValue;
        }
        port def ControlSignalPort {
            out startCmd : StartCommand;
            out stopCmd : StopCommand;
        }

        part def AirCompressor {
            port airOutPort : AirPort;
            attribute outputPressure : PressureValue = 700 [kPa];
            perform action 'compress air' : 'Compress Air';
        }

        part def PressureRegulator {
            port airInPort : ~AirPort;
            port airOutPort : AirPort;
            attribute regulatedPressure : PressureValue = 600 [kPa];
        }

        part def FluidReservoir {
            port fluidOutPort : FluidPort;
            attribute capacity : VolumeValue = 100 [L];
            item storedFluid : Fluid;
        }

        part def FluidReceiver {
            port fluidInPort : ~FluidPort;
            port pressurePort : FluidPort;
            attribute capacity : VolumeValue = 80 [L];
            attribute currentPressure : PressureValue;
            item storedFluid : Fluid;
        }

        part def AirDrivenPump {
            port airInPort : ~AirPort;
            port airExhaustPort : AirPort;
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port controlPort : ~ControlSignalPort;

            attribute maxFlowRate : VolumeFlowRateValue = 80 [L/min];
            attribute maxDischargePressure : PressureValue = 500 [kPa];
            attribute dischargePressure : PressureValue;

            perform action 'pump fluid' : 'Pump Fluid';
            exhibit state 'pump states' : 'Pump States';
        }

        part def CheckValve {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute crackingPressure : PressureValue = 10 [kPa];
        }

        part def SystemController {
            port sensorPort : ~PressureSignalPort;
            port pumpControlPort : ControlSignalPort;

            attribute targetPressure : PressureValue = 400 [kPa];
            attribute minPressure : PressureValue = 350 [kPa];
            attribute maxPressure : PressureValue = 450 [kPa];

            exhibit state 'controller states' : 'Controller States';
        }

        part def PressureSensor {
            port fluidPort : ~FluidPort;
            port signalPort : PressureSignalPort;
            perform action 'sense pressure' : 'Sense Pressure';
        }

        part def Atmosphere {
            port airInPort : ~AirPort;
        }

        state def 'Pump States';
        state def 'Controller States';

        action def 'Compress Air' {
            out airOut : Air;
        }

        action def 'Pump Fluid' {
            in airIn : Air;
            in fluidIn : Fluid;
            out fluidOut : Fluid;
            out exhaustAir : Air;
        }

        action def 'Sense Pressure' {
            in fluidIn : Fluid;
            out pressure : PressureValue;
        }

        action def 'Prime Pump';
        action def 'Stop Pumping';
        action def 'Shutdown Safely';

        requirement def 'Pressure Maintenance Requirement' {
            subject receiver : FluidReceiver;
            requirement receiver.currentPressure >= 350 [kPa] and receiver.currentPressure <= 450 [kPa];
        }

        requirement def 'Flow Rate Requirement' {
            subject pump : AirDrivenPump;
            requirement pump.maxFlowRate <= 80 [L/min];
        }

        requirement def 'Safety Requirement' {
            subject pump : AirDrivenPump;
            requirement pump.dischargePressure <= pump.maxDischargePressure;
        }
    }

    package Usages {
        private import Definitions::*;

        part context {
            part airCompressor : AirCompressor;
            part pressureRegulator : PressureRegulator;
            part fluidReservoir : FluidReservoir;
            part airDrivenPump : AirDrivenPump;
            part checkValve : CheckValve;
            part fluidReceiver : FluidReceiver;
            part systemController : SystemController;
            part pressureSensor : PressureSensor;
            part atmosphere : Atmosphere;

            flow of air : Air
                from airCompressor.airOutPort.air to pressureRegulator.airInPort.air;
            flow of air : Air
                from pressureRegulator.airOutPort.air to airDrivenPump.airInPort.air;
            flow of air : Air
                from airDrivenPump.airExhaustPort.air to atmosphere.airInPort.air;
            flow of fluid : Fluid
                from fluidReservoir.fluidOutPort.fluid to airDrivenPump.fluidInPort.fluid;
            flow of fluid : Fluid
                from airDrivenPump.fluidOutPort.fluid to checkValve.fluidInPort.fluid;
            flow of fluid : Fluid
                from checkValve.fluidOutPort.fluid to fluidReceiver.fluidInPort.fluid;
            flow of fluid : Fluid
                from fluidReceiver.pressurePort.fluid to pressureSensor.fluidPort.fluid;
            flow of pressure : PressureValue
                from pressureSensor.signalPort.pressure to systemController.sensorPort.pressure;
            flow of startCmd : StartCommand
                from systemController.pumpControlPort.startCmd to airDrivenPump.controlPort.startCmd;
            flow of stopCmd : StopCommand
                from systemController.pumpControlPort.stopCmd to airDrivenPump.controlPort.stopCmd;

            action 'compress air' : 'Compress Air';
            action 'pump fluid' : 'Pump Fluid';
            action 'sense pressure' : 'Sense Pressure';
            action 'prime pump' : 'Prime Pump';
            action 'stop pumping' : 'Stop Pumping';
            action 'shutdown safely' : 'Shutdown Safely';

            state 'pump states' : 'Pump States' {
                entry; then idle;
                state idle;
                accept StartCommand
                    then priming;
                state priming {
                    entry 'prime pump';
                }
                then active;
                state active {
                    do 'pump fluid';
                }
                accept StopCommand
                    then stopping;
                accept when airDrivenPump.dischargePressure > airDrivenPump.maxDischargePressure
                    do send new OverPressureAlert() to systemController
                    then fault;
                state stopping {
                    entry 'stop pumping';
                }
                then idle;
                state fault {
                    entry 'shutdown safely';
                }
                accept ResetCommand
                    then idle;
            }

            state 'controller states' : 'Controller States' {
                entry; then pumpStopped;
                state pumpStopped;
                accept when systemController.sensorPort.pressure < systemController.minPressure
                    do send new StartCommand() to airDrivenPump
                    then pumpRunning;
                state pumpRunning;
                accept when systemController.sensorPort.pressure > systemController.maxPressure
                    do send new StopCommand() to airDrivenPump
                    then pumpStopped;
            }

            requirement pressureMaintenance : 'Pressure Maintenance Requirement';
            requirement flowRate : 'Flow Rate Requirement';
            requirement safety : 'Safety Requirement';

            satisfy pressureMaintenance by systemController;
            satisfy flowRate by airDrivenPump;
            satisfy safety by airDrivenPump;
        }
    }
}
