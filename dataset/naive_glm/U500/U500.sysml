package FoamPumpingSubsystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;

    // ---- Item and Value Types ----

    item def Foam {
        attribute concentration : Real = 0.03; // 3% foam concentrate
        attribute density : MassDensity = 1.0 [kg/L];
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
        attribute frequency : Frequency = 60 [Hz];
    }

    value def PressureValue :> Real { unit 'Pa'; }
    value def FlowRateValue :> Real { unit 'L/min'; }
    value def VoltageValue :> Real { unit 'V'; }
    value def SpeedValue :> Real { unit 'rpm'; }
    value def TemperatureValue :> Real { unit 'K'; }

    // ---- Port Definitions ----

    port def FoamPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        out item foam : Foam;
    }

    port def PowerPort {
        out item power : ElectricalPower;
    }

    port def SignalPort {
        attribute value : Real;
    }

    // ---- Requirements ----

    requirement def PressureControlRequirement {
        attribute targetPressure : PressureValue = 700000 [Pa];
        attribute tolerance : PressureValue = 20000 [Pa];
        subject : FoamPump;
        require {
            subject.outletPressure >= targetPressure - tolerance and
            subject.outletPressure <= targetPressure + tolerance
        }
    }

    requirement def FlowControlRequirement {
        attribute targetFlowRate : FlowRateValue = 2000 [L/min];
        attribute tolerance : FlowRateValue = 100 [L/min];
        subject : FoamPump;
        require {
            subject.outletFlowRate >= targetFlowRate - tolerance and
            subject.outletFlowRate <= targetFlowRate + tolerance
        }
    }

    requirement def SafetyRequirement {
        attribute maxPressure : PressureValue = 1200000 [Pa];
        subject : FoamPumpingSubsystem;
        require {
            subject.reliefValve.open == true when subject.foamPump.outletPressure > maxPressure
        }
    }

    requirement def StartupRequirement {
        subject : FoamPump;
        require {
            subject.stateMachine.currentState == 'Priming' and
            subject.stateMachine.currentState == 'Accelerating' and
            subject.stateMachine.currentState == 'Running'
        }
    }

    // ---- Part Definitions ----

    part def FoamReservoir {
        attribute capacity : Volume = 10000 [L];
        attribute currentLevel : Volume = 10000 [L];
        attribute minLevel : Volume = 500 [L];
        port outlet : FoamPort;
    }

    part def FoamPump {
        attribute targetSpeed : SpeedValue = 1800 [rpm];
        attribute currentSpeed : SpeedValue = 0 [rpm];
        attribute outletPressure : PressureValue = 0 [Pa];
        attribute outletFlowRate : FlowRateValue = 0 [L/min];
        attribute inletPressure : PressureValue = 0 [Pa];
        attribute cavitationDetected : Boolean = false;
        attribute overPressureDetected : Boolean = false;

        port inlet : FoamPort;
        port outlet : FoamPort;
        port powerIn : PowerPort;
        port speedCommand : SignalPort;
        port pressureFeedback : SignalPort;
        port flowFeedback : SignalPort;

        state machine stateMachine {
            entry; then Off;

            state Off;
            transition off_to_priming
                first Off
                accept Activate
                then Priming;

            state Priming {
                entry action {
                    currentSpeed := 200 [rpm];
                    inletPressure := 100000 [Pa];
                }
            }
            transition priming_to_accelerating
                first Priming
                accept PrimingComplete
                then Accelerating;

            state Accelerating {
                entry action {
                    currentSpeed := targetSpeed;
                }
            }
            transition accelerating_to_running
                first Accelerating
                accept TargetSpeedReached
                then Running;

            state Running;
            transition running_to_overpressure
                first Running
                accept OverPressure
                then OverPressureMode;

            state OverPressureMode {
                entry action {
                    currentSpeed := currentSpeed * 0.5;
                    overPressureDetected := true;
                }
            }
            transition overpressure_to_running
                first OverPressureMode
                accept PressureNormalized
                then Running;

            transition running_to_cavitation
                first Running
                accept Cavitation
                then CavitationMode;

            state CavitationMode {
                entry action {
                    currentSpeed := currentSpeed * 0.3;
                    cavitationDetected := true;
                }
            }
            transition cavitation_to_running
                first CavitationMode
                accept InletRecovered
                then Running;

            transition running_to_shutdown
                first Running
                accept Deactivate
                then Shutdown;

            transition overpressure_to_shutdown
                first OverPressureMode
                accept Deactivate
                then Shutdown;

            transition cavitation_to_shutdown
                first CavitationMode
                accept Deactivate
                then Shutdown;

            state Shutdown {
                entry action {
                    currentSpeed := 0 [rpm];
                    outletPressure := 0 [Pa];
                    outletFlowRate := 0 [L/min];
                }
            }
            transition shutdown_to_off
                first Shutdown
                accept ShutdownComplete
                then Off;
        }
    }

    part def DischargeManifold {
        attribute numOutlets : Integer = 4;
        attribute outletPressure : PressureValue;
        port inlet : FoamPort;
        port outlets : FoamPort[4];
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute samplingRate : Frequency = 100 [Hz];
        port sensePort : FoamPort;
        port outputPort : SignalPort;
    }

    part def FlowSensor {
        attribute measuredFlowRate : FlowRateValue;
        attribute samplingRate : Frequency = 100 [Hz];
        port sensePort : FoamPort;
        port outputPort : SignalPort;
    }

    part def PumpController {
        attribute targetPressure : PressureValue = 700000 [Pa];
        attribute targetFlowRate : FlowRateValue = 2000 [L/min];
        attribute maxPressure : PressureValue = 1200000 [Pa];
        attribute kp : Real = 0.5;
        attribute ki : Real = 0.1;
        attribute integralError : Real = 0.0;
        attribute controlOutput : SpeedValue = 0 [rpm];
        attribute overPressureAlarm : Boolean = false;

        port pressureInput : SignalPort;
        port flowInput : SignalPort;
        port speedOutput : SignalPort;
        port powerIn : PowerPort;
        port activatePump : SignalPort;
        port deactivatePump : SignalPort;

        action def ControlLoop {
            in pressureReading : PressureValue;
            in flowReading : FlowRateValue;
            out speedCommand : SpeedValue;
            local pressureError : Real;
            local flowError : Real;
            local totalError : Real;
            action computePressureError {
                pressureError := targetPressure - pressureReading;
            }
            action computeFlowError {
                flowError := targetFlowRate - flowReading;
            }
            action updateIntegral {
                integralError := integralError + (pressureError + flowError) * 0.01;
            }
            action computeOutput {
                totalError := kp * (pressureError + flowError) + ki * integralError;
                speedCommand := 1800 [rpm] + totalError;
                if speedCommand > 2400 [rpm] then speedCommand := 2400 [rpm]; endif
                if speedCommand < 0 [rpm] then speedCommand := 0 [rpm]; endif
            }
            then computePressureError;
            then computeFlowError;
            then updateIntegral;
            then computeOutput;
        }

        state machine controllerState {
            entry; then Standby;

            state Standby;
            transition standby_to_active
                first Standby
                accept Engage
                then Active;

            state Active {
                do action {
                    if pressureInput.value > maxPressure then
                        overPressureAlarm := true;
                        deactivatePump.value := 1.0;
                    else
                        overPressureAlarm := false;
                    endif
                }
            }
            transition active_to_standby
                first Active
                accept Disengage
                then Standby;
        }
    }

    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 480 [V];
        attribute maxPower : Power = 100000 [W];
        attribute status : String = "Operational";
        port controllerOutput : PowerPort;
        port pumpOutput : PowerPort;
    }

    part def ReliefValve {
        attribute setPressure : PressureValue = 1200000 [Pa];
        attribute open : Boolean = false;
        attribute crackPressure : PressureValue = 1100000 [Pa];
        port inlet : FoamPort;
        port vent : FoamPort;

        action def CheckPressure {
            in pressure : PressureValue;
            if pressure >= setPressure then
                open := true;
            elseif pressure < crackPressure then
                open := false;
            endif
        }
    }

    // ---- Top-level System ----

    part def FoamPumpingSubsystem {
        attribute systemStatus : String = "Idle";

        part foamReservoir : FoamReservoir;
        part foamPump : FoamPump;
        part dischargeManifold : DischargeManifold;
        part pumpController : PumpController;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part powerSupply : PowerSupply;
        part reliefValve : ReliefValve;

        // Connections
        connection foamReservoir_to_pump connect foamReservoir.outlet to foamPump.inlet;
        connection pump_to_manifold connect foamPump.outlet to dischargeManifold.inlet;
        connection pump_to_pressureSensor connect foamPump.outlet to pressureSensor.sensePort;
        connection pump_to_flowSensor connect foamPump.outlet to flowSensor.sensePort;
        connection pressureSensor_to_controller connect pressureSensor.outputPort to pumpController.pressureInput;
        connection flowSensor_to_controller connect flowSensor.outputPort to pumpController.flowInput;
        connection controller_to_pump_speed connect pumpController.speedOutput to foamPump.speedCommand;
        connection controller_to_pump_activate connect pumpController.activatePump to foamPump.pressureFeedback;
        connection power_to_controller connect powerSupply.controllerOutput to pumpController.powerIn;
        connection power_to_pump connect powerSupply.pumpOutput to foamPump.powerIn;
        connection pump_to_reliefValve connect foamPump.outlet to reliefValve.inlet;

        // Requirements satisfaction
        satisfy PressureControlRequirement by foamPump;
        satisfy FlowControlRequirement by foamPump;
        satisfy SafetyRequirement by self;
        satisfy StartupRequirement by foamPump;
    }
}
