package DiversPumpSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def Fluid;

        attribute def StartCommand;
        attribute def StopCommand;
        attribute def ResetCommand;
        attribute def FaultAlert;

        port def FluidPort {
            item fluid : Fluid;
            attribute pressure :> ISQ::pressure;
            attribute flowRate :> ISQ::volumeFlowRate;
        }

        port def CommandPort;
        port def AlertPort;

        port def SensorPort {
            attribute pressure :> ISQ::pressure;
            attribute flowRate :> ISQ::volumeFlowRate;
        }

        part def SourceReservoir {
            attribute volume :> ISQ::volume;
            port outlet : FluidPort;
        }

        part def DestinationVessel {
            attribute volume :> ISQ::volume;
            attribute capacity :> ISQ::volume;
            port inlet : FluidPort;
        }

        part def Cylinder {
            attribute bore :> ISQ::length;
            attribute stroke :> ISQ::length;
            attribute chamberPressure :> ISQ::pressure;
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
        }

        part def PistonAssembly {
            attribute position :> ISQ::length;
        }

        part def DriveMechanism {
            attribute power :> ISQ::power;
            attribute running : Boolean;
            port commandIn : CommandPort;
        }

        part def Valve {
            attribute openThreshold :> ISQ::pressure;
            attribute isOpen : Boolean;
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
        }

        part def InletValve :> Valve {
            attribute redefines openThreshold;
        }

        part def OutletValve :> Valve {
            attribute redefines openThreshold;
        }

        part def PressureSensor {
            attribute reading :> ISQ::pressure;
            attribute maxSafePressure :> ISQ::pressure;
            port sensorOut : SensorPort;
        }

        part def FlowSensor {
            attribute reading :> ISQ::volumeFlowRate;
            attribute minFlowRate :> ISQ::volumeFlowRate;
            attribute maxFlowRate :> ISQ::volumeFlowRate;
            port sensorOut : SensorPort;
        }

        action def IntakeStroke;
        action def DischargeStroke;
        action def PrimeCylinder;

        state def PumpStates;
        state def ControllerStates;

        part def DiversPump {
            part cylinder : Cylinder;
            part piston : PistonAssembly;
            part drive : DriveMechanism;
            part inletValve : InletValve;
            part outletValve : OutletValve;
            port sourcePort : FluidPort;
            port destPort : FluidPort;
            port commandIn : CommandPort;
            port alertOut : AlertPort;
            port inletSensorIn : SensorPort;
            port outletSensorIn : SensorPort;
            port flowSensorIn : SensorPort;

            connect sourcePort to inletValve.fluidIn;
            connect inletValve.fluidOut to cylinder.fluidIn;
            connect cylinder.fluidOut to outletValve.fluidIn;
            connect outletValve.fluidOut to destPort;

            perform action intakeStroke : IntakeStroke;
            perform action dischargeStroke : DischargeStroke;
            perform action primeCylinder : PrimeCylinder;
            exhibit state pumpStates : PumpStates;
        }

        part def PumpController {
            port externalCommand : CommandPort;
            port pumpCommand : CommandPort;
            port alertIn : AlertPort;
            port inletSensor : SensorPort;
            port outletSensor : SensorPort;
            port flowSensor : SensorPort;
            exhibit state controllerStates : ControllerStates;
        }

        requirement def MaxPressureRequirement {
            doc /* The pump shall not exceed its maximum rated pressure during operation. */
            attribute maxPressure :> ISQ::pressure;
        }

        requirement def FlowRateRequirement {
            doc /* The flow rate shall be within specified limits. */
            attribute minFlow :> ISQ::volumeFlowRate;
            attribute maxFlow :> ISQ::volumeFlowRate;
        }

        requirement def PrimingRequirement {
            doc /* The pump shall complete a priming cycle before entering the pumping state. */
        }

        requirement def OneWayFlowRequirement {
            doc /* The inlet and outlet valves shall ensure unidirectional fluid flow. */
        }
    }

    package Usages {
        private import Definitions::*;

        action intakeStroke : IntakeStroke;
        action dischargeStroke : DischargeStroke;
        action primeCylinder : PrimeCylinder;

        part reservoir : SourceReservoir {
            attribute redefines volume = 0.1 [m^3];
        }
        part vessel : DestinationVessel {
            attribute redefines capacity = 0.2 [m^3];
            attribute redefines volume = 0 [m^3];
        }
        part pump : DiversPump {
            part redefines cylinder {
                attribute redefines bore = 0.1 [m];
                attribute redefines stroke = 0.15 [m];
            }
            part redefines drive {
                attribute redefines power = 500 [W];
                attribute redefines running = false;
            }
            part redefines inletValve {
                attribute redefines openThreshold = 5000 [Pa];
            }
            part redefines outletValve {
                attribute redefines openThreshold = 10000 [Pa];
            }
        }
        part controller : PumpController;
        part inletPressureSensor : PressureSensor {
            attribute redefines maxSafePressure = 200000 [Pa];
        }
        part outletPressureSensor : PressureSensor {
            attribute redefines maxSafePressure = 300000 [Pa];
        }
        part flowSensor : FlowSensor {
            attribute redefines minFlowRate = 0.001 [m^3/s];
            attribute redefines maxFlowRate = 0.01 [m^3/s];
        }

        connect reservoir.outlet to pump.sourcePort;
        connect pump.destPort to vessel.inlet;
        connect controller.pumpCommand to pump.commandIn;
        connect pump.alertOut to controller.alertIn;
        connect inletPressureSensor.sensorOut to pump.inletSensorIn;
        connect outletPressureSensor.sensorOut to pump.outletSensorIn;
        connect flowSensor.sensorOut to pump.flowSensorIn;
        connect pump.inletSensorIn to controller.inletSensor;
        connect pump.outletSensorIn to controller.outletSensor;
        connect pump.flowSensorIn to controller.flowSensor;

        state pumpStates : PumpStates {
            entry; then idle;
            state idle;
            accept StartCommand
                then priming;
            state priming {
                do primeCylinder;
            }
            accept after 10 [SI::s]
                then pumping;
            accept after 30 [SI::s]
                do send new FaultAlert() to controller
                then fault;
            state pumping {
                entry; then intakePhase;
                state intakePhase {
                    do intakeStroke;
                }
                accept after 2 [SI::s]
                    then dischargePhase;
                state dischargePhase {
                    do dischargeStroke;
                }
                accept after 2 [SI::s]
                    then intakePhase;
            }
            accept StopCommand
                then stopping;
            accept when outletPressureSensor.reading > outletPressureSensor.maxSafePressure
                do send new FaultAlert() to controller
                then fault;
            accept when flowSensor.reading < flowSensor.minFlowRate
                do send new FaultAlert() to controller
                then fault;
            state stopping {
                do action stopDrive {
                    send new StopCommand() to pump.drive;
                }
            }
            accept after 3 [SI::s]
                then idle;
            state fault {
                do action emergencyShutdown {
                    send new StopCommand() to pump.drive;
                }
            }
            accept ResetCommand
                then idle;
        }

        state controllerStates : ControllerStates {
            entry; then monitoring;
            state monitoring;
            accept StartCommand
                do send new StartCommand() to pump
                then active;
            state active;
            accept StopCommand
                do send new StopCommand() to pump
                then monitoring;
            accept FaultAlert
                then faulted;
            state faulted;
            accept ResetCommand
                do send new ResetCommand() to pump
                then monitoring;
        }

        requirement maxPressureReq : MaxPressureRequirement {
            attribute redefines maxPressure = 300000 [Pa];
        }
        requirement flowRateReq : FlowRateRequirement {
            attribute redefines minFlow = 0.001 [m^3/s];
            attribute redefines maxFlow = 0.01 [m^3/s];
        }
        requirement primingReq : PrimingRequirement;
        requirement oneWayFlowReq : OneWayFlowRequirement;
    }
}
