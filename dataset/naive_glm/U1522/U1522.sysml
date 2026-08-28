package PrecisionFluidTransferSystem {
    import ScalarValues::*;

    // ==================== Units ====================
    unit cubicMetre;
    unit cubicMetrePerSecond;
    unit pascal;
    unit second;
    unit metre;
    unit percent;
    unit one;

    // ==================== Value Types ====================
    value type Volume :> Real { unit cubicMetre; }
    value type VolumetricFlowRate :> Real { unit cubicMetrePerSecond; }
    value type Pressure :> Real { unit pascal; }
    value type Duration :> Real { unit second; }
    value type Length :> Real { unit metre; }
    value type Diameter :> Real { unit metre; }
    value type ValveOpeningPct :> Real { unit percent; }
    value type TolerancePct :> Real { unit percent; }
    value type Gain :> Real { unit one; }
    value type Ratio :> Real { unit one; }

    // ==================== Items ====================
    item def Fluid;

    // ==================== Signal / Data Attribute Definitions ====================
    attribute def TargetFlowCommand {
        attribute targetRate : VolumetricFlowRate;
        attribute issuedAt : Duration;
    }

    attribute def FlowReading {
        attribute measuredRate : VolumetricFlowRate;
        attribute measuredAt : Duration;
    }

    attribute def ValveActuation {
        attribute opening : ValveOpeningPct;
        attribute actuatedAt : Duration;
    }

    // ==================== Enumerations ====================
    enum def ControllerStatus {
        idle;
        settling;
        stable;
        fault;
    }

    // ==================== Ports ====================
    port def FluidOutPort {
        out item fluid : Fluid;
        out attribute pressure : Pressure;
    }

    port def FluidInPort {
        in item fluid : Fluid;
        in attribute pressure : Pressure;
    }

    port def TargetCommandInPort {
        in attribute command : TargetFlowCommand;
    }

    port def FlowReadingInPort {
        in attribute reading : FlowReading;
    }

    port def FlowReadingOutPort {
        out attribute reading : FlowReading;
    }

    port def ValveCommandInPort {
        in attribute actuation : ValveActuation;
    }

    port def ValveCommandOutPort {
        out attribute actuation : ValveActuation;
    }

    // ==================== Part Definitions ====================

    part def SourceReservoir {
        attribute initialVolume : Volume;
        attribute currentVolume : Volume;
        attribute ambientPressure : Pressure;
        attribute outFlowRate : VolumetricFlowRate;
        port fluidOutlet : FluidOutPort;
    }

    part def Pump {
        attribute nominalPressureRise : Pressure;
        attribute maxFlowRate : VolumetricFlowRate;
        attribute currentFlowRate : VolumetricFlowRate;
        port pumpInlet : FluidInPort;
        port pumpOutlet : FluidOutPort;
    }

    part def Pipe {
        attribute length : Length;
        attribute innerDiameter : Diameter;
        attribute roughness : Length;
        attribute flowResistance : Ratio;
        port pipeInlet : FluidInPort;
        port pipeOutlet : FluidOutPort;
    }

    part def ControllableFlowValve {
        attribute maxFlowRate : VolumetricFlowRate;
        attribute currentOpening : ValveOpeningPct;
        attribute effectiveFlowRate : VolumetricFlowRate;
        port valveInlet : FluidInPort;
        port valveOutlet : FluidOutPort;
        port command : ValveCommandInPort;
    }

    part def FlowSensor {
        attribute samplingPeriod : Duration;
        attribute measurementRangeMax : VolumetricFlowRate;
        attribute accuracy : TolerancePct;
        attribute instantaneousFlow : VolumetricFlowRate;
        port sensorInlet : FluidInPort;
        port sensorOutlet : FluidOutPort;
        port reading : FlowReadingOutPort;
    }

    part def ReceivingTank {
        attribute capacity : Volume;
        attribute currentVolume : Volume;
        attribute fillLevel : Ratio;
        port tankInlet : FluidInPort;
    }

    part def FlowController {
        attribute tolerance : TolerancePct = 5.0;
        attribute settlingTimeLimit : Duration = 30.0;
        attribute proportionalGain : Gain;
        attribute integralGain : Gain;
        attribute derivativeGain : Gain;
        attribute currentTarget : VolumetricFlowRate;
        attribute currentMeasured : VolumetricFlowRate;
        attribute lastError : VolumetricFlowRate;
        attribute integralError : Real;
        attribute lastCommandTime : Duration;
        attribute currentTime : Duration;
        attribute status : ControllerStatus;

        port targetCommand : TargetCommandInPort;
        port sensorFeedback : FlowReadingInPort;
        port valveCommand : ValveCommandOutPort;

        action def ComputeControl {
            in targetRate : VolumetricFlowRate;
            in measuredRate : VolumetricFlowRate;
            in dt : Duration;
            out opening : ValveOpeningPct;
        }

        state ControllerStates {
            state idle {
                entry {
                    status := ControllerStatus::idle;
                    currentTarget := 0.0 [cubicMetrePerSecond];
                    integralError := 0.0;
                    lastError := 0.0 [cubicMetrePerSecond];
                }
            }

            state settling {
                entry {
                    status := ControllerStatus::settling;
                    lastCommandTime := currentTime;
                }
                do {
                    /* continuously compute PID valve command and emit valveCommand.actuation */
                }
            }

            state stable {
                entry {
                    status := ControllerStatus::stable;
                }
                do {
                    /* maintain valveCommand.actuation with fine PID corrections */
                }
            }

            state fault {
                entry {
                    status := ControllerStatus::fault;
                    valveCommand.actuation.opening := 0.0 [percent];
                }
            }

            transition initial to idle;

            transition from idle to settling
                when targetCommand.command.targetRate > 0.0 [cubicMetrePerSecond];

            transition from settling to stable
                when (currentTarget > 0.0 [cubicMetrePerSecond]) and
                     (abs(currentMeasured - currentTarget) <= (tolerance / 100.0) * currentTarget);

            transition from settling to fault
                when (currentTime - lastCommandTime) > settlingTimeLimit;

            transition from stable to settling
                when targetCommand.command.targetRate != currentTarget;

            transition from stable to fault
                when (abs(currentMeasured - currentTarget) > (tolerance / 100.0) * currentTarget);
        }
    }

    // ==================== System Assembly ====================
    part def PrecisionFluidTransferSystem {
        attribute systemTargetFlow : VolumetricFlowRate = 5.0e-4 [cubicMetrePerSecond];
        attribute systemTolerance : TolerancePct = 5.0;
        attribute systemSettlingTime : Duration = 30.0;

        part reservoir : SourceReservoir {
            attribute initialVolume = 0.5 [cubicMetre];
            attribute currentVolume = 0.5 [cubicMetre];
            attribute ambientPressure = 101325 [pascal];
        }

        part pump : Pump {
            attribute nominalPressureRise = 2.0e5 [pascal];
            attribute maxFlowRate = 1.0e-3 [cubicMetrePerSecond];
        }

        part pipe1 : Pipe {
            attribute length = 0.5 [metre];
            attribute innerDiameter = 0.02 [metre];
        }

        part valve : ControllableFlowValve {
            attribute maxFlowRate = 1.0e-3 [cubicMetrePerSecond];
            attribute currentOpening = 50.0 [percent];
        }

        part sensor : FlowSensor {
            attribute samplingPeriod = 0.1 [second];
            attribute measurementRangeMax = 2.0e-3 [cubicMetrePerSecond];
            attribute accuracy = 1.0 [percent];
        }

        part pipe2 : Pipe {
            attribute length = 0.8 [metre];
            attribute innerDiameter = 0.02 [metre];
        }

        part receiver : ReceivingTank {
            attribute capacity = 1.0 [cubicMetre];
            attribute currentVolume = 0.0 [cubicMetre];
        }

        part controller : FlowController {
            attribute tolerance = 5.0 [percent];
            attribute settlingTimeLimit = 30.0 [second];
            attribute proportionalGain = 50.0;
            attribute integralGain = 5.0;
            attribute derivativeGain = 2.0;
        }

        // Fluid pathway connections
        connect reservoir.fluidOutlet to pump.pumpInlet;
        connect pump.pumpOutlet to pipe1.pipeInlet;
        connect pipe1.pipeOutlet to valve.valveInlet;
        connect valve.valveOutlet to sensor.sensorInlet;
        connect sensor.sensorOutlet to pipe2.pipeInlet;
        connect pipe2.pipeOutlet to receiver.tankInlet;

        // Signal connections (feedback control loop)
        connect sensor.reading to controller.sensorFeedback;
        connect controller.valveCommand to valve.command;
    }

    // ==================== Requirement Definitions ====================
    requirement def TransferFluidRequirement {
        doc /* The system shall transfer fluid from the source reservoir to the receiving tank through a continuous fluid pathway. */;
    }

    requirement def TargetFlowRateRequirement {
        doc /* The system shall move fluid at a user-specified volumetric flow rate provided via a target command. */;
        attribute targetRate : VolumetricFlowRate;
    }

    requirement def FlowToleranceRequirement {
        doc /* The measured volumetric flow rate shall remain within +/- 5 percent of the target flow rate during steady-state operation. */;
        attribute tolerance : TolerancePct = 5.0;
    }

    requirement def SettlingTimeRequirement {
        doc /* The system shall achieve stable flow within 30 seconds of receiving a new target flow command. */;
        attribute maxSettlingTime : Duration = 30.0;
    }

    requirement def FeedbackControlRequirement {
        doc /* The flow controller shall continuously compare the measured flow rate from the flow sensor to the target and adjust the controllable valve opening to correct deviations. */;
    }

    requirement def ValveResponseRequirement {
        doc /* The controllable flow valve shall modulate its opening in response to actuation commands issued by the flow controller. */;
    }

    // ==================== Requirement Usages ====================
    requirement transferFluidReq : TransferFluidRequirement;

    requirement targetFlowReq : TargetFlowRateRequirement {
        attribute targetRate = 5.0e-4 [cubicMetrePerSecond];
    }

    requirement flowToleranceReq : FlowToleranceRequirement {
        attribute tolerance = 5.0 [percent];
    }

    requirement settlingTimeReq : SettlingTimeRequirement {
        attribute maxSettlingTime = 30.0 [second];
    }

    requirement feedbackControlReq : FeedbackControlRequirement;

    requirement valveResponseReq : ValveResponseRequirement;

    // ==================== System Usage and Satisfaction ====================
    part precisionSystem : PrecisionFluidTransferSystem;

    satisfy transferFluidReq by precisionSystem;
    satisfy targetFlowReq by precisionSystem;
    satisfy flowToleranceReq by precisionSystem;
    satisfy settlingTimeReq by precisionSystem;
    satisfy feedbackControlReq by precisionSystem;
    satisfy valveResponseReq by precisionSystem;
}
