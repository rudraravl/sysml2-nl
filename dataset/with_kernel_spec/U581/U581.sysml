package WaterladderPumpingSubsystem {
    public import Definitions::*;
    public import Usages::*;
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        alias Torque for ISQ::TorqueValue;
        alias RotationalSpeed for ISQ::AngularVelocityValue;
        alias Pressure for ISQ::PressureValue;
        alias VolumeFlowRate for ISQ::VolumeFlowRateValue;
        alias Volume for ISQ::VolumeValue;
        alias Length for ISQ::LengthValue;
        alias Power for ISQ::PowerValue;

        item def Water;

        attribute def StartCmd;
        attribute def StopCmd;
        attribute def ResetCmd;
        attribute def ExcessiveTorqueFault;

        port def ElectricalPowerPort {
            in power : Power;
        }
        port def MechanicalPowerPort {
            out torque : Torque;
            out speed : RotationalSpeed;
        }
        port def WaterFlowInPort {
            in water : Water;
            in flowRate : VolumeFlowRate;
            in pressure : Pressure;
        }
        port def WaterFlowOutPort {
            out water : Water;
            out flowRate : VolumeFlowRate;
            out pressure : Pressure;
        }
        port def ControlOutPort {
            out start : StartCmd;
            out stop : StopCmd;
            out reset : ResetCmd;
        }
        port def ControlInPort {
            in start : StartCmd;
            in stop : StopCmd;
            in reset : ResetCmd;
        }
        port def InstrumentOutPort {
            out pressure : Pressure;
            out flowRate : VolumeFlowRate;
        }
        port def InstrumentInPort {
            in pressure : Pressure;
            in flowRate : VolumeFlowRate;
        }

        action def ConvertPower {
            in electricalPower : Power;
            out torque : Torque;
            out speed : RotationalSpeed;
        }
        action def AccelerateDrum {
            in targetSpeed : RotationalSpeed;
            out currentSpeed : RotationalSpeed;
        }
        action def DecelerateDrum {
            out currentSpeed : RotationalSpeed;
        }
        action def PumpWater {
            in electricalPower : Power;
            in inletWater : Water;
            out dischargeWater : Water;
            out liftedVolume : Volume;
        }
        action def MonitorTorque {
            in motorTorque : Torque;
            in limit : Torque;
            out isFault : Boolean;
        }
        action def SensePressure {
            out pressure : Pressure;
        }
        action def SenseFlowRate {
            out flowRate : VolumeFlowRate;
        }
        action def EmergencyShutdown;
        action def Idle;

        part def SupplyReservoir {
            attribute waterLevel : Length;
            port waterOut : WaterFlowOutPort;
        }
        part def DischargeReservoir {
            attribute waterLevel : Length;
            attribute capacity : Volume;
            port waterIn : WaterFlowInPort;
        }
        part def InletControlValve {
            attribute position : Real;
            port waterIn : WaterFlowInPort;
            port waterOut : WaterFlowOutPort;
            port controlIn : ControlInPort;
        }
        part def Bucket {
            attribute capacity : Volume;
        }
        part def LiftingChain {
            attribute bucketCount : Integer = 12;
            part buckets : Bucket[12];
        }
        part def RotatingDrum {
            attribute diameter : Length;
            port mechIn : ~MechanicalPowerPort;
        }
        part def WaterladderPump {
            attribute liftHeight : Length;
            part drum : RotatingDrum;
            part chain : LiftingChain;
            port mechIn : ~MechanicalPowerPort;
            port waterIn : WaterFlowInPort;
            port waterOut : WaterFlowOutPort;
            perform action pumpWater : PumpWater;
        }
        part def DriveMotor {
            attribute ratedPower : Power;
            attribute maxTorque : Torque;
            port powerIn : ElectricalPowerPort;
            port mechOut : MechanicalPowerPort;
            port controlIn : ControlInPort;
            perform action generateTorque : ConvertPower;
        }
        part def PressureGauge {
            attribute location : String;
            port sensed : WaterFlowInPort;
            port reading : InstrumentOutPort;
            perform action sensePressure : SensePressure;
        }
        part def FlowMeter {
            port sensed : WaterFlowInPort;
            port reading : InstrumentOutPort;
            perform action senseFlowRate : SenseFlowRate;
        }

        state def PumpingStates;
        state def ControllerStates;

        part def PumpController {
            port controlOut : ControlOutPort;
            port motorFeedback : ~MechanicalPowerPort;
            port inletPressureInput : InstrumentInPort;
            port outletPressureInput : InstrumentInPort;
            port flowInput : InstrumentInPort;
            exhibit state controllerStates : ControllerStates {
                entry; then stopped;
                state stopped;
                accept StartCmd then starting;
                state starting;
                accept when motorFeedback.speed >= 8.4 [rad/s] then running;
                state running;
                accept StopCmd then stopping;
                state stopping;
                accept when motorFeedback.speed <= 0 [rad/s] then stopped;
                accept ExcessiveTorqueFault then fault;
                state fault;
                accept ResetCmd then stopped;
            }
        }

        part def WaterladderSubsystem {
            part supplyReservoir : SupplyReservoir;
            part inletValve : InletControlValve;
            part pump : WaterladderPump;
            part motor : DriveMotor;
            part dischargeReservoir : DischargeReservoir;
            part inletPressureGauge : PressureGauge;
            part outletPressureGauge : PressureGauge;
            part flowMeter : FlowMeter;
            part controller : PumpController;
        }

        requirement def PumpingRequirement {
            subject subsystem : WaterladderSubsystem;
            requirement continuousOperation {
                doc /* The subsystem shall continuously lift water from the supply reservoir to the discharge reservoir when in the running state. */
            }
            requirement efficientLifting {
                doc /* The subsystem shall use a 12-bucket waterladder mechanism to lift water efficiently along the chain loop. */
            }
            requirement faultProtection {
                doc /* The subsystem shall enter a fault state upon detecting motor torque exceeding the maximum allowable limit. */
            }
            requirement manualReset {
                doc /* A manual reset shall be required to clear a fault and return the subsystem to the stopped state. */
            }
            requirement instrumentMonitoring {
                doc /* The subsystem shall provide pressure gauges at the pump inlet and outlet and a flow meter on the discharge line for monitoring. */
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part waterladderSubsystem : WaterladderSubsystem {
            part supplyReservoir : SupplyReservoir {
                attribute waterLevel = 2.0 [m];
            }
            part inletValve : InletControlValve {
                attribute position = 1.0;
            }
            part pump : WaterladderPump {
                attribute liftHeight = 8.0 [m];
                part drum : RotatingDrum {
                    attribute diameter = 1.5 [m];
                }
                part chain : LiftingChain {
                    attribute bucketCount = 12;
                    part buckets : Bucket[12] {
                        attribute capacity = 0.05 [m^3];
                    }
                }
            }
            part motor : DriveMotor {
                attribute ratedPower = 15000 [W];
                attribute maxTorque = 500 [N*m];
            }
            part dischargeReservoir : DischargeReservoir {
                attribute waterLevel = 0.0 [m];
                attribute capacity = 500 [m^3];
            }
            part inletPressureGauge : PressureGauge {
                attribute location = "pump inlet";
            }
            part outletPressureGauge : PressureGauge {
                attribute location = "pump outlet";
            }
            part flowMeter : FlowMeter;
            part controller : PumpController;

            flow supplyReservoir.waterOut to inletValve.waterIn;
            flow inletValve.waterOut to pump.waterIn;
            flow pump.waterOut to dischargeReservoir.waterIn;
            flow inletValve.waterOut to inletPressureGauge.sensed;
            flow pump.waterOut to outletPressureGauge.sensed;
            flow pump.waterOut to flowMeter.sensed;
            connect motor.mechOut to pump.mechIn;
            connect motor.mechOut to controller.motorFeedback;
            connect inletPressureGauge.reading to controller.inletPressureInput;
            connect outletPressureGauge.reading to controller.outletPressureInput;
            connect flowMeter.reading to controller.flowInput;
            connect controller.controlOut to motor.controlIn;
            connect controller.controlOut to inletValve.controlIn;

            exhibit state subsystemStates : PumpingStates {
                ref ctrl : PumpController := controller;
                ref drvMotor : DriveMotor := motor;

                entry; then stopped;

                state stopped {
                    do action idle : Idle;
                }

                accept StartCmd
                    do send new StartCmd() to ctrl
                    then starting;

                state starting {
                    entry action accelerate : AccelerateDrum {
                        in targetSpeed = 8.4 [rad/s];
                        out currentSpeed : RotationalSpeed;
                    }
                    do action monitorTorque : MonitorTorque {
                        in motorTorque = drvMotor.mechOut.torque;
                        in limit = drvMotor.maxTorque;
                        out isFault : Boolean;
                    }
                }

                accept when drvMotor.mechOut.torque > drvMotor.maxTorque
                    do send new ExcessiveTorqueFault() to ctrl
                    then fault;

                accept when drvMotor.mechOut.speed >= 8.4 [rad/s]
                    then running;

                state running {
                    do action liftAndDischarge : PumpWater {
                        in electricalPower = 15000 [W];
                        in inletWater : Water;
                        out dischargeWater : Water;
                        out liftedVolume : Volume;
                    }
                    do action monitorTorque : MonitorTorque {
                        in motorTorque = drvMotor.mechOut.torque;
                        in limit = drvMotor.maxTorque;
                        out isFault : Boolean;
                    }
                }

                accept when drvMotor.mechOut.torque > drvMotor.maxTorque
                    do send new ExcessiveTorqueFault() to ctrl
                    then fault;

                accept StopCmd
                    do send new StopCmd() to ctrl
                    then stopping;

                state stopping {
                    entry action decelerate : DecelerateDrum {
                        out currentSpeed : RotationalSpeed;
                    }
                }

                accept when drvMotor.mechOut.speed <= 0 [rad/s]
                    then stopped;

                state fault {
                    entry action emergencyShutdown : EmergencyShutdown;
                }

                accept ResetCmd
                    do send new ResetCmd() to ctrl
                    then stopped;
            }
        }

        requirement pumpingReq : PumpingRequirement {
            subject subsystem = waterladderSubsystem;
        }
    }
}
