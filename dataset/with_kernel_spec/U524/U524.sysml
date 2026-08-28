package InductivePumpingSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        public import ItemDefinitions::*;
        public import SignalDefinitions::*;
        public import PortDefinitions::*;
        public import ActionDefinitions::*;
        public import PartDefinitions::*;
        public import RequirementDefinitions::*;

        package ItemDefinitions {
            item def ConductiveFluid {
                attribute electricalConductivity : Real;
                attribute density : Real;
                attribute viscosity : Real;
            }
        }

        package SignalDefinitions {
            attribute def StartPumpSignal;
            attribute def StopPumpSignal;
            attribute def PumpReadySignal;
            attribute def FaultAcknowledgedSignal;
        }

        package PortDefinitions {
            port def FluidPort {
                attribute flowRate : Real;
                attribute pressure : Real;
                attribute temperature : Real;
            }
            port def ThreePhasePowerPort {
                attribute phaseAVoltage : Real;
                attribute phaseBVoltage : Real;
                attribute phaseCVoltage : Real;
                attribute frequency : Real;
                attribute current : Real;
            }
            port def FlowSensorDataPort {
                attribute flowRate : Real;
                attribute pressure : Real;
            }
            port def PowerCmdPort {
                attribute commandedFrequency : Real;
                attribute commandedVoltage : Real;
                attribute enable : Boolean;
            }
            port def TemperatureDataPort {
                attribute temperature : Real;
            }
            port def CoolantPort {
                attribute flowRate : Real;
                attribute temperature : Real;
                attribute pressure : Real;
            }
            port def CoolingCmdPort {
                attribute enable : Boolean;
                attribute targetFlowRate : Real;
            }
            port def MainsPowerPort {
                attribute voltage : Real;
                attribute frequency : Real;
            }
        }

        package ActionDefinitions {
            action def GenerateTravelingField {
                in frequency : Real;
                in coilCurrent : Real[3];
            }
            action def InduceEddyCurrents {
                in magneticFieldStrength : Real;
                in fluidConductivity : Real;
                out eddyCurrentDensity : Real;
            }
            action def GenerateLorentzForce {
                in currentDensity : Real;
                in magneticFieldStrength : Real;
                out forceDensity : Real;
            }
            action def TransferFluid;
            action def ExecutePIDControl {
                in setpoint : Real;
                in measuredValue : Real;
                in kp : Real;
                in ki : Real;
                in kd : Real;
                out controlOutput : Real;
            }
            action def MonitorTemperature {
                in currentTemp : Real;
                in maxTemp : Real;
                out overTemp : Boolean;
            }
            action def ActivateCooling;
            action def CirculateCoolant;
            action def EmergencyShutdown;
            action def RampUpField;
            action def RampDownField;
        }

        package PartDefinitions {
            part def InductivePump {
                attribute coilTemperature : Real;
                attribute maxCoilTemperature : Real = 423.15;
                attribute safeRestartTemperature : Real = 323.15;
                attribute ductInnerDiameter : Real;
                attribute ductLength : Real;

                port powerSupplyPort : ThreePhasePowerPort;
                port fluidInletPort : FluidPort;
                port fluidOutletPort : FluidPort;
                port coolingInletPort : CoolantPort;
                port coolingOutletPort : CoolantPort;

                part statorCore : LaminatedSteelCore {
                    part coils : ThreePhaseCoil[3];
                }
                part duct : StainlessSteelDuct;
                part coolingJacket : CoolingJacket;
                part tempSensor : TemperatureSensor;

                perform action generateTravelingField : GenerateTravelingField;
                perform action induceEddyCurrents : InduceEddyCurrents;
                perform action generateLorentzForce : GenerateLorentzForce;
                perform action transferFluid : TransferFluid;
                perform action monitorTemperature : MonitorTemperature;
                perform action rampUpField : RampUpField;
                perform action rampDownField : RampDownField;
                perform action emergencyShutdown : EmergencyShutdown;

                exhibit state pumpStates {
                    entry; then idle;

                    state idle;
                    accept StartPumpSignal
                        if coilTemperature <= safeRestartTemperature
                        then starting;

                    state starting {
                        do rampUpField;
                        do generateTravelingField;
                    }
                    accept PumpReadySignal
                        then running;

                    state running {
                        do generateTravelingField;
                        do induceEddyCurrents;
                        do generateLorentzForce;
                        do transferFluid;
                        do monitorTemperature;
                    }
                    accept StopPumpSignal
                        then stopping;
                    accept when coilTemperature > maxCoilTemperature
                        then faulted;

                    state stopping {
                        entry rampDownField;
                    }
                    accept when coilTemperature <= maxCoilTemperature
                        then idle;

                    state faulted {
                        entry emergencyShutdown;
                        do monitorTemperature;
                    }
                    accept FaultAcknowledgedSignal
                        if coilTemperature <= safeRestartTemperature
                        then idle;
                }
            }

            part def LaminatedSteelCore;

            part def ThreePhaseCoil {
                attribute inductance : Real;
                attribute resistance : Real;
            }

            part def StainlessSteelDuct {
                attribute wallThickness : Real;
            }

            part def CoolingJacket {
                port coolantInlet : CoolantPort;
                port coolantOutlet : CoolantPort;
            }

            part def TemperatureSensor {
                attribute sensedTemperature : Real;
                port tempDataPort : TemperatureDataPort;
            }

            part def SourceReservoir {
                attribute fluidLevel : Real;
                attribute capacity : Real;
                port outletPort : FluidPort;
            }

            part def DestinationTank {
                attribute fluidLevel : Real;
                attribute capacity : Real;
                port inletPort : FluidPort;
            }

            part def PumpController {
                attribute commandedFlowRate : Real;
                attribute proportionalGain : Real;
                attribute integralGain : Real;
                attribute derivativeGain : Real;
                attribute controlLoopFrequency : Real;
                attribute maxOperatingTemperature : Real = 423.15;

                port flowSensorInletPort : FlowSensorDataPort;
                port flowSensorOutletPort : FlowSensorDataPort;
                port powerCmdPort : PowerCmdPort;
                port tempSensorPort : TemperatureDataPort;
                port coolingCmdPort : CoolingCmdPort;

                perform action executePIDControl : ExecutePIDControl;
                perform action monitorTemperature : MonitorTemperature;
                perform action activateCooling : ActivateCooling;
                perform action emergencyShutdown : EmergencyShutdown;

                exhibit state controllerStates {
                    entry; then standby;

                    state standby;
                    accept StartPumpSignal
                        then starting;

                    state starting {
                        do executePIDControl;
                    }
                    accept PumpReadySignal
                        then regulating;

                    state regulating {
                        do executePIDControl;
                        do monitorTemperature;
                    }
                    accept StopPumpSignal
                        then stopping;
                    accept when tempSensorPort.temperature > maxOperatingTemperature
                        then faultHandling;

                    state stopping {
                        entry emergencyShutdown;
                    }
                    accept when tempSensorPort.temperature <= maxOperatingTemperature
                        then standby;

                    state faultHandling {
                        entry emergencyShutdown;
                        do activateCooling;
                    }
                    accept FaultAcknowledgedSignal
                        if tempSensorPort.temperature <= maxOperatingTemperature
                        then standby;
                }
            }

            part def FlowSensor {
                attribute measuredFlowRate : Real;
                attribute measuredPressure : Real;
                port sensorDataPort : FlowSensorDataPort;
                port fluidInPort : FluidPort;
                port fluidOutPort : FluidPort;
            }

            part def ThreePhasePowerSupply {
                attribute outputFrequency : Real;
                attribute outputVoltage : Real;
                attribute outputCurrent : Real;
                attribute maxPower : Real;

                port inputCmdPort : PowerCmdPort;
                port outputPowerPort : ThreePhasePowerPort;
                port mainsInputPort : MainsPowerPort;
            }

            part def CoolingSystem {
                attribute coolantFlowRate : Real;
                attribute coolantTemperature : Real;

                port cmdPort : CoolingCmdPort;
                port supplyPort : CoolantPort;
                port returnPort : CoolantPort;

                perform action circulateCoolant : CirculateCoolant;
            }

            part def MainsPower {
                port powerOutPort : MainsPowerPort;
            }
        }

        package RequirementDefinitions {
            requirement def FlowRateAccuracy {
                doc /* The system shall maintain the commanded flow rate within ±2% of setpoint during steady-state operation. */
                attribute targetAccuracy : Real = 0.02;
            }
            requirement def OverTemperatureProtection {
                doc /* The pump shall automatically shut down and enter a faulted state if coil temperature exceeds 150°C (423.15 K). */
                attribute maxOperatingTemperature : Real = 423.15;
            }
            requirement def NoMovingParts {
                doc /* The pumping mechanism shall contain no moving mechanical parts in contact with the process fluid. */
            }
            requirement def CoolDownRestart {
                doc /* The pump shall only allow restart after a fault when coil temperature has dropped below 50°C (323.15 K). */
                attribute safeRestartTemp : Real = 323.15;
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part pumpSystem {
            part pump : InductivePump;
            part sourceTank : SourceReservoir;
            part destinationTank : DestinationTank;
            part inletFlowSensor : FlowSensor;
            part outletFlowSensor : FlowSensor;
            part powerSupply : ThreePhasePowerSupply {
                attribute redefines maxPower = 50;
            }
            part coolingSystem : CoolingSystem;
            part pumpController : PumpController {
                attribute redefines proportionalGain = 1.5;
                attribute redefines integralGain = 0.8;
                attribute redefines derivativeGain = 0.1;
                attribute redefines controlLoopFrequency = 100;
            }
            part mainsPower : MainsPower;

            connect sourceTank.outletPort to inletFlowSensor.fluidInPort;
            connect inletFlowSensor.fluidOutPort to pump.fluidInletPort;
            connect pump.fluidOutletPort to outletFlowSensor.fluidInPort;
            connect outletFlowSensor.fluidOutPort to destinationTank.inletPort;

            connect mainsPower.powerOutPort to powerSupply.mainsInputPort;
            connect powerSupply.outputPowerPort to pump.powerSupplyPort;
            connect pumpController.powerCmdPort to powerSupply.inputCmdPort;

            connect inletFlowSensor.sensorDataPort to pumpController.flowSensorInletPort;
            connect outletFlowSensor.sensorDataPort to pumpController.flowSensorOutletPort;
            connect pump.tempSensor.tempDataPort to pumpController.tempSensorPort;

            connect coolingSystem.supplyPort to pump.coolingInletPort;
            connect pump.coolingOutletPort to coolingSystem.returnPort;
            connect pumpController.coolingCmdPort to coolingSystem.cmdPort;

            satisfy FlowRateAccuracy by pumpController;
            satisfy OverTemperatureProtection by pump;
            satisfy NoMovingParts by pump;
            satisfy CoolDownRestart by pump;
        }
    }
}
