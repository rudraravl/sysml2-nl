package CoolingSystemModel {
    public import ScalarValues::*;
    public import ISQ::*;

    package Definitions {
        public import ValueDefinitions::*;
        public import ItemDefinitions::*;
        public import SignalDefinitions::*;
        public import PortDefinitions::*;
        public import PartDefinitions::*;
        public import ActionDefinitions::*;
        public import StateDefinitions::*;
        public import RequirementDefinitions::*;

        package ValueDefinitions {
            attribute def PressureValue :> ISQ::PressureValue;
            attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
            attribute def TemperatureValue :> ISQ::TemperatureValue;
            attribute def RotationalSpeedValue :> ISQ::AngularVelocityValue;
            attribute def TorqueValue :> ISQ::TorqueValue;
            attribute def ElectricalPowerValue :> ISQ::PowerValue;
            attribute def VolumeValue :> ISQ::VolumeValue;
            attribute def HeatTransferRateValue :> ISQ::PowerValue;
            attribute def LengthValue :> ISQ::LengthValue;
        }

        package ItemDefinitions {
            item def Fluid;
        }

        package SignalDefinitions {
            attribute def StartSignal;
            attribute def StopSignal;
            attribute def NormalFlowSignal;
            attribute def ReducedFlowSignal;
            attribute def EmergencyShutdownSignal;
            attribute def OverTempAlert;
            attribute def LowPressureAlert;
            attribute def FaultClearedSignal;
            attribute def StartupCompleteSignal;
            attribute def ShutdownCompleteSignal;
        }

        package PortDefinitions {
            port def FluidPort {
                out item fluid : Fluid;
            }
            port def ElectricalPort {
                out power : ElectricalPowerValue;
            }
            port def MechanicalShaftPort {
                out speed : RotationalSpeedValue;
                out torque : TorqueValue;
            }
            port def PressureSensorPort {
                out pressure : PressureValue;
            }
            port def FlowSensorPort {
                out flowRate : FlowRateValue;
            }
            port def TemperatureSensorPort {
                out temperature : TemperatureValue;
            }
            port def PumpCommandPort {
                in startCmd : StartSignal;
                in stopCmd : StopSignal;
                in normalFlowCmd : NormalFlowSignal;
                in reducedFlowCmd : ReducedFlowSignal;
                in emergencyCmd : EmergencyShutdownSignal;
                in faultClearedCmd : FaultClearedSignal;
                in speedCmd : RotationalSpeedValue;
            }
            port def PumpStatusPort {
                out startupComplete : StartupCompleteSignal;
                out shutdownComplete : ShutdownCompleteSignal;
                out overTempAlert : OverTempAlert;
                out lowPressureAlert : LowPressureAlert;
            }
        }

        package ActionDefinitions {
            action def ConvertPower {
                in electricalPower : ElectricalPowerValue;
                out rotationalSpeed : RotationalSpeedValue;
                out torque : TorqueValue;
            }
            action def PumpFluid {
                in fluidIn : Fluid;
                in rotationalSpeed : RotationalSpeedValue;
                out fluidOut : Fluid;
            }
            action def TransferHeat {
                in fluidIn : Fluid;
                out fluidOut : Fluid;
                out heatTransferRate : HeatTransferRateValue;
            }
            action def SensePressure {
                out pressure : PressureValue;
            }
            action def SenseFlow {
                out flowRate : FlowRateValue;
            }
            action def SenseTemperature {
                out temperature : TemperatureValue;
            }
            action def ControlPumpSpeed {
                in targetFlowRate : FlowRateValue;
                in actualFlowRate : FlowRateValue;
                in inletPressure : PressureValue;
                in fluidTemperature : TemperatureValue;
                out speedCommand : RotationalSpeedValue;
            }
        }

        package StateDefinitions {
            state def PumpStates;
            state def ControllerStates;
        }

        package PartDefinitions {
            part def ElectricMotor {
                port electricalInPort : ~ElectricalPort;
                port shaftOutPort : MechanicalShaftPort;
                attribute nominalSpeed : RotationalSpeedValue;
                attribute electricalPower : ElectricalPowerValue;
                perform action convertPower : ConvertPower {
                    in electricalPower = electricalInPort.power;
                    out rotationalSpeed = shaftOutPort.speed;
                    out torque = shaftOutPort.torque;
                }
            }

            part def Impeller {
                attribute numBlades : Integer;
                attribute bladeDiameter : LengthValue;
                port shaftInPort : ~MechanicalShaftPort;
            }

            part def PumpHousing {
                attribute material : String;
                port fluidInPort : ~FluidPort;
                port fluidOutPort : FluidPort;
            }

            part def CirculatorPump {
                port fluidInPort : ~FluidPort;
                port fluidOutPort : FluidPort;
                port electricalInPort : ~ElectricalPort;
                port commandPort : ~PumpCommandPort;
                port statusPort : PumpStatusPort;
                attribute targetFlowRate : FlowRateValue;
                attribute currentSpeed : RotationalSpeedValue;
                attribute inletPressure : PressureValue;
                attribute outletTemperature : TemperatureValue;
                attribute maxOperatingTemp : TemperatureValue;
                attribute minInletPressure : PressureValue;

                part motor : ElectricMotor;
                part impeller : Impeller;
                part housing : PumpHousing;

                connect motor.shaftOutPort to impeller.shaftInPort;
                connect housing.fluidInPort to fluidInPort;
                connect housing.fluidOutPort to fluidOutPort;
                connect electricalInPort to motor.electricalInPort;

                perform action pumpFluid : PumpFluid;
                exhibit state pumpStates : PumpStates;
            }

            part def Reservoir {
                attribute capacity : VolumeValue;
                attribute currentVolume : VolumeValue;
                port fluidOutPort : FluidPort;
                port fluidReturnPort : ~FluidPort;
                item storedFluid : Fluid;
            }

            part def PipeNetwork {
                attribute totalLength : LengthValue;
                port fluidInPort : ~FluidPort;
                port fluidOutPort : FluidPort;
            }

            part def HeatExchanger {
                attribute heatTransferCapacity : HeatTransferRateValue;
                port fluidInPort : ~FluidPort;
                port fluidOutPort : FluidPort;
                perform action transferHeat : TransferHeat;
            }

            part def PressureSensor {
                port fluidInPort : ~FluidPort;
                port fluidOutPort : FluidPort;
                port dataOutPort : PressureSensorPort;
                perform action sense : SensePressure;
            }

            part def FlowSensor {
                port fluidInPort : ~FluidPort;
                port fluidOutPort : FluidPort;
                port dataOutPort : FlowSensorPort;
                perform action sense : SenseFlow;
            }

            part def TemperatureSensor {
                port fluidInPort : ~FluidPort;
                port fluidOutPort : FluidPort;
                port dataOutPort : TemperatureSensorPort;
                perform action sense : SenseTemperature;
            }

            part def PumpController {
                port pressureDataPort : ~PressureSensorPort;
                port flowDataPort : ~FlowSensorPort;
                port tempDataPort : ~TemperatureSensorPort;
                port pumpCommandPort : PumpCommandPort;
                port pumpStatusPort : ~PumpStatusPort;
                attribute targetFlowRate : FlowRateValue;
                attribute maxOperatingTemp : TemperatureValue;
                attribute minInletPressure : PressureValue;
                perform action controlSpeed : ControlPumpSpeed;
                exhibit state controllerStates : ControllerStates;
            }
        }

        package RequirementDefinitions {
            requirement def FlowControlRequirement {
                text "The system shall maintain the target flow rate within +/- 5% under normal operating conditions.";
                attribute targetFlowRate : FlowRateValue;
                attribute tolerance : Real = 0.05;
            }

            requirement def DryRunProtectionRequirement {
                text "The pump shall not operate when inlet pressure falls below the minimum threshold.";
                attribute minInletPressure : PressureValue;
            }

            requirement def OverTempProtectionRequirement {
                text "The system shall trigger emergency shutdown when fluid temperature exceeds the maximum threshold.";
                attribute maxOperatingTemp : TemperatureValue;
            }

            requirement def HeatDissipationRequirement {
                text "The heat exchanger shall dissipate thermal energy at a rate sufficient to maintain outlet fluid temperature below the maximum operating threshold.";
                attribute heatTransferCapacity : HeatTransferRateValue;
            }
        }
    }

    package Usages {
        public import Definitions::*;

        part coolingSystem {
            attribute targetFlowRate : FlowRateValue = 50 [L/min];
            attribute maxOperatingTemp : TemperatureValue = 350 [K];
            attribute minInletPressure : PressureValue = 10000 [Pa];

            part reservoir : Reservoir {
                attribute capacity = 100 [L];
                attribute currentVolume = 50 [L];
            }

            part inletPipes : PipeNetwork {
                attribute totalLength = 2 [m];
            }

            part pump : CirculatorPump {
                attribute targetFlowRate = 50 [L/min];
                attribute currentSpeed = 0 [rpm];
                attribute inletPressure = 15000 [Pa];
                attribute outletTemperature = 300 [K];
                attribute maxOperatingTemp = 350 [K];
                attribute minInletPressure = 10000 [Pa];

                part motor : ElectricMotor {
                    attribute nominalSpeed = 3000 [rpm];
                    attribute electricalPower = 500 [W];
                }
                part impeller : Impeller {
                    attribute numBlades = 7;
                    attribute bladeDiameter = 0.1 [m];
                }
                part housing : PumpHousing {
                    attribute material = "Cast Iron";
                }

                exhibit state pumpStates : PumpStates {
                    entry; then idle;

                    state idle;
                    transition idle_to_starting
                        first idle
                        accept StartSignal via commandPort
                        if inletPressure >= minInletPressure
                        then starting;

                    state starting;
                    transition starting_to_running
                        first starting
                        accept NormalFlowSignal via commandPort
                        then running;
                    transition starting_to_fault
                        first starting
                        accept when inletPressure < minInletPressure
                        do send new LowPressureAlert() via statusPort
                        then fault;

                    state running {
                        do pumpFluid;
                    }
                    transition running_to_reducedFlow
                        first running
                        accept ReducedFlowSignal via commandPort
                        then reducedFlow;
                    transition running_to_shuttingDown
                        first running
                        accept StopSignal via commandPort
                        then shuttingDown;
                    transition running_to_fault_emergency
                        first running
                        accept EmergencyShutdownSignal via commandPort
                        then fault;
                    transition running_to_fault_overtemp
                        first running
                        accept when outletTemperature > maxOperatingTemp
                        do send new OverTempAlert() via statusPort
                        then fault;
                    transition running_to_fault_lowpressure
                        first running
                        accept when inletPressure < minInletPressure
                        do send new LowPressureAlert() via statusPort
                        then fault;

                    state reducedFlow {
                        do pumpFluid;
                    }
                    transition reducedFlow_to_running
                        first reducedFlow
                        accept NormalFlowSignal via commandPort
                        then running;
                    transition reducedFlow_to_shuttingDown
                        first reducedFlow
                        accept StopSignal via commandPort
                        then shuttingDown;
                    transition reducedFlow_to_fault_emergency
                        first reducedFlow
                        accept EmergencyShutdownSignal via commandPort
                        then fault;
                    transition reducedFlow_to_fault_overtemp
                        first reducedFlow
                        accept when outletTemperature > maxOperatingTemp
                        do send new OverTempAlert() via statusPort
                        then fault;
                    transition reducedFlow_to_fault_lowpressure
                        first reducedFlow
                        accept when inletPressure < minInletPressure
                        do send new LowPressureAlert() via statusPort
                        then fault;

                    state shuttingDown;
                    transition shuttingDown_to_idle
                        first shuttingDown
                        accept FaultClearedSignal via commandPort
                        then idle;

                    state fault;
                    transition fault_to_shuttingDown
                        first fault
                        accept EmergencyShutdownSignal via commandPort
                        then shuttingDown;
                    transition fault_to_idle
                        first fault
                        accept FaultClearedSignal via commandPort
                        if inletPressure >= minInletPressure
                        then idle;
                }
            }

            part pressureSensor : PressureSensor;
            part flowSensor : FlowSensor;
            part tempSensor : TemperatureSensor;

            part outletPipes : PipeNetwork {
                attribute totalLength = 1.5 [m];
            }

            part heatExchanger : HeatExchanger {
                attribute heatTransferCapacity = 1000 [W];
            }

            part returnPipes : PipeNetwork {
                attribute totalLength = 2 [m];
            }

            part controller : PumpController {
                attribute targetFlowRate = 50 [L/min];
                attribute maxOperatingTemp = 350 [K];
                attribute minInletPressure = 10000 [Pa];

                exhibit state controllerStates : ControllerStates {
                    entry; then monitoring;

                    state monitoring {
                        do controlSpeed {
                            in targetFlowRate = targetFlowRate;
                            in actualFlowRate = flowDataPort.flowRate;
                            in inletPressure = pressureDataPort.pressure;
                            in fluidTemperature = tempDataPort.temperature;
                            out speedCommand = pumpCommandPort.speedCmd;
                        }
                    }
                    transition monitoring_to_alerting_overtemp
                        first monitoring
                        accept when tempDataPort.temperature > maxOperatingTemp
                        do send new EmergencyShutdownSignal() via pumpCommandPort
                        then alerting;
                    transition monitoring_to_alerting_lowpressure
                        first monitoring
                        accept when pressureDataPort.pressure < minInletPressure
                        do send new EmergencyShutdownSignal() via pumpCommandPort
                        then alerting;
                    transition monitoring_to_alerting_overtempalert
                        first monitoring
                        accept OverTempAlert via pumpStatusPort
                        do send new EmergencyShutdownSignal() via pumpCommandPort
                        then alerting;
                    transition monitoring_to_alerting_lowpressurealert
                        first monitoring
                        accept LowPressureAlert via pumpStatusPort
                        do send new EmergencyShutdownSignal() via pumpCommandPort
                        then alerting;

                    state alerting;
                    transition alerting_to_monitoring
                        first alerting
                        accept FaultClearedSignal
                        then monitoring;
                }
            }

            flow of fluid : Fluid
                from reservoir.fluidOutPort.fluid
                to inletPipes.fluidInPort.fluid;
            flow of fluid : Fluid
                from inletPipes.fluidOutPort.fluid
                to pressureSensor.fluidInPort.fluid;
            flow of fluid : Fluid
                from pressureSensor.fluidOutPort.fluid
                to pump.fluidInPort.fluid;
            flow of fluid : Fluid
                from pump.fluidOutPort.fluid
                to flowSensor.fluidInPort.fluid;
            flow of fluid : Fluid
                from flowSensor.fluidOutPort.fluid
                to outletPipes.fluidInPort.fluid;
            flow of fluid : Fluid
                from outletPipes.fluidOutPort.fluid
                to tempSensor.fluidInPort.fluid;
            flow of fluid : Fluid
                from tempSensor.fluidOutPort.fluid
                to heatExchanger.fluidInPort.fluid;
            flow of fluid : Fluid
                from heatExchanger.fluidOutPort.fluid
                to returnPipes.fluidInPort.fluid;
            flow of fluid : Fluid
                from returnPipes.fluidOutPort.fluid
                to reservoir.fluidReturnPort.fluid;

            connect controller.pumpCommandPort to pump.commandPort;
            connect pump.statusPort to controller.pumpStatusPort;
            connect pressureSensor.dataOutPort to controller.pressureDataPort;
            connect flowSensor.dataOutPort to controller.flowDataPort;
            connect tempSensor.dataOutPort to controller.tempDataPort;
        }

        requirement flowControlReq : FlowControlRequirement {
            attribute targetFlowRate = 50 [L/min];
        }

        requirement dryRunProtectionReq : DryRunProtectionRequirement {
            attribute minInletPressure = 10000 [Pa];
        }

        requirement overTempProtectionReq : OverTempProtectionRequirement {
            attribute maxOperatingTemp = 350 [K];
        }

        requirement heatDissipationReq : HeatDissipationRequirement {
            attribute heatTransferCapacity = 1000 [W];
        }
    }
}
