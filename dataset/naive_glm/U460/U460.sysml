package HighPrecisionPumpingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQMechanics::*;

    item def Liquid;

    value def FlowRateValue :> Real {
        private unit L_per_min = 1.0 'L/min';
        unit :>> L_per_min;
    }

    value def PressureValue :> Real {
        private unit bar = 100000.0 'Pa';
        unit :>> bar;
    }

    value def VolumeValue :> Real {
        private unit liter = 1.0 'L';
        unit :>> liter;
    }

    value def StrokeRateValue :> Real {
        private unit spm = 1.0 '1/min';
        unit :>> spm;
    }

    value def MotorSpeedValue :> Real {
        private unit rpm = 1.0 '1/min';
        unit :>> rpm;
    }

    value def TemperatureValue :> Real {
        private unit degC = 1.0 'degC';
        unit :>> degC;
    }

    value def DurationValue :> Real {
        private unit sec = 1.0 's';
        unit :>> sec;
    }

    port def LiquidOutPort {
        out item liquid : Liquid;
        out attr pressure : PressureValue;
    }

    port def LiquidInPort {
        in item liquid : Liquid;
        in attr pressure : PressureValue;
    }

    port def FlowFeedbackPort {
        out attr measuredFlow : FlowRateValue;
    }

    port def MotorCommandPort {
        out attr speedCommand : MotorSpeedValue;
        in attr speedActual : MotorSpeedValue;
    }

    port def ControlPort {
        in attr flowFeedback : FlowRateValue;
        out attr motorCommand : MotorSpeedValue;
        in attr dischargePressure : PressureValue;
        in attr suctionPressure : PressureValue;
        out attr alarmActive : Boolean;
    }

    port def TargetPort {
        in attr targetFlow : FlowRateValue;
    }

    part def SupplyTank {
        port liquidOut : LiquidOutPort;
        attr capacity : VolumeValue = 100.0 'L';
        attr currentVolume : VolumeValue;
        attr minLevel : VolumeValue = 5.0 'L';
        attr temperature : TemperatureValue;
    }

    part def PumpHead {
        port inlet : LiquidInPort;
        port outlet : LiquidOutPort;
        attr pistonDisplacement : VolumeValue = 0.5 'L';
        attr cylinderBore : Real;
        attr strokeLength : Real;
        attr valveCount : Integer = 2;
    }

    part def Motor {
        port command : MotorCommandPort;
        attr nominalSpeed : MotorSpeedValue = 1750.0 '1/min';
        attr currentSpeed : MotorSpeedValue;
        attr power : Real;
    }

    part def Controller {
        port control : ControlPort;
        port target : TargetPort;
        attr targetFlow : FlowRateValue;
        attr actualFlow : FlowRateValue;
        attr measuredDischargePressure : PressureValue;
        attr measuredSuctionPressure : PressureValue;
        attr maxDischargePressure : PressureValue = 10.0 'bar';
        attr minSuctionPressure : PressureValue = 0.2 'bar';
        attr proportionalGain : Real = 0.8;
        attr integralGain : Real = 0.05;
        attr integralError : Real = 0.0;
        attr alarmActive : Boolean = false;
        attr strokeRate : StrokeRateValue;

        private compute strokeRateFromSpeed(speed : MotorSpeedValue) : StrokeRateValue {
            return speed * 1.0;
        }

        private compute errorSignal() : Real {
            return (targetFlow - actualFlow) / 1.0 'L/min';
        }

        private compute controlOutput() : MotorSpeedValue {
            attr err : Real = errorSignal();
            integralError = integralError + err * 0.1;
            return (proportionalGain * err + integralGain * integralError) * 100.0 '1/min';
        }

        state machine ControllerStateMachine {
            entry;
            then idle;
            state idle {
                entry action { alarmActive = false; }
                transition idle_to_priming
                    first idle
                    accept TargetReceived
                    then priming;
            }
            state priming {
                entry action { /* run pump at low speed to purge air */ }
                do action { send PrimeComplete; }
                transition priming_to_running
                    first priming
                    accept PrimeComplete
                    then running;
                transition priming_to_fault
                    first priming
                    accept FaultDetected
                    then fault;
            }
            state running {
                entry action { /* begin closed-loop control */ }
                do action {
                    actualFlow = control.flowFeedback;
                    measuredDischargePressure = control.dischargePressure;
                    measuredSuctionPressure = control.suctionPressure;
                    if (measuredDischargePressure > maxDischargePressure) {
                        send FaultDetected;
                    }
                    if (measuredSuctionPressure < minSuctionPressure) {
                        send FaultDetected;
                    }
                    control.motorCommand = controlOutput();
                }
                transition running_to_shutdown
                    first running
                    accept ShutdownCommand
                    then shutdown;
                transition running_to_fault
                    first running
                    accept FaultDetected
                    then fault;
            }
            state fault {
                entry action {
                    alarmActive = true;
                    control.alarmActive = true;
                    control.motorCommand = 0.0 '1/min';
                }
                transition fault_to_shutdown
                    first fault
                    accept Acknowledge
                    then shutdown;
            }
            state shutdown {
                entry action { control.motorCommand = 0.0 '1/min'; }
                transition shutdown_to_idle
                    first shutdown
                    accept Reset
                    then idle;
            }
        }
    }

    part def MeteringPump {
        port suctionPort : LiquidInPort;
        port dischargePort : LiquidOutPort;
        port controlPort : ControlPort;
        port targetPort : TargetPort;

        part motor : Motor {
            port command : MotorCommandPort;
        }
        part head : PumpHead {
            port inlet : LiquidInPort;
            port outlet : LiquidOutPort;
        }
        part controller : Controller {
            port control : ControlPort;
            port target : TargetPort;
        }

        connect suctionPort to head.inlet;
        connect head.outlet to dischargePort;
        connect controller.control to controlPort;
        connect controller.target to targetPort;
        connect controller.control.motorCommand to motor.command.speedCommand;
        connect motor.command.speedActual to controller.control;
    }

    part def FlowSensor {
        port liquidIn : LiquidInPort;
        port liquidOut : LiquidOutPort;
        port feedback : FlowFeedbackPort;
        attr measuredFlow : FlowRateValue;
        attr accuracyPercent : Real = 0.1;
        attr responseTime : DurationValue = 0.05 's';

        private compute measureFlow() : FlowRateValue {
            return measuredFlow;
        }
    }

    part def ReceivingVessel {
        port liquidIn : LiquidInPort;
        attr capacity : VolumeValue = 200.0 'L';
        attr currentVolume : VolumeValue;
        attr maxPressure : PressureValue = 8.0 'bar';
    }

    part def PumpingSystem {
        part supplyTank : SupplyTank;
        part pump : MeteringPump;
        part sensor : FlowSensor;
        part vessel : ReceivingVessel;

        connect supplyTank.liquidOut to pump.suctionPort;
        connect pump.dischargePort to sensor.liquidIn;
        connect sensor.liquidOut to vessel.liquidIn;
        connect sensor.feedback to pump.controlPort.flowFeedback;
        connect pump.controlPort.dischargePressure to pump.dischargePort.pressure;
        connect pump.controlPort.suctionPressure to pump.suctionPort.pressure;
    }

    requirement def AccuracyRequirement {
        subject : PumpingSystem;
        objective {
            doc /* The system shall deliver fluid at a flow rate within +/- 0.5% of the target flow rate under steady-state conditions. */
        }
        assume { targetFlow > 0.0 'L/min'; }
    }

    requirement def RepeatabilityRequirement {
        subject : PumpingSystem;
        objective {
            doc /* The system shall repeat a given dosing volume within +/- 0.2% across consecutive cycles. */
        }
    }

    requirement def ResponsivenessRequirement {
        subject : PumpingSystem;
        objective {
            doc /* The system shall adjust the actual flow rate to within 1% of a new target within 2 seconds of a setpoint change. */
        }
    }

    requirement def SafetyRequirement {
        subject : PumpingSystem;
        objective {
            doc /* The system shall detect excessive discharge pressure or cavitation and automatically shut down within 0.5 seconds, triggering an alarm. */
        }
    }

    requirement def StateRequirement {
        subject : PumpingSystem;
        objective {
            doc /* The system shall support idle, priming, running, fault, and shutdown operational states. */
        }
    }

    requirement PumpingSystemRequirements {
        subject : PumpingSystem;
        satisfy AccuracyRequirement;
        satisfy RepeatabilityRequirement;
        satisfy ResponsivenessRequirement;
        satisfy SafetyRequirement;
        satisfy StateRequirement;
    }
}
