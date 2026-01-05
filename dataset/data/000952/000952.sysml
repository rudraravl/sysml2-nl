package 'Variable Displacement Pumping Subsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute def PressureValue :> Real;
        attribute def VolumeFlowRateValue :> Real;
        attribute def AngularVelocityValue :> Real;
        attribute def DisplacementValue :> Real;
        attribute def VolumeValue :> Real;
        attribute def TemperatureValue :> Real;

        item def HydraulicFluid {
            attribute pressure : PressureValue;
            attribute flowRate : VolumeFlowRateValue;
            attribute temperature : TemperatureValue;
            attribute density : Real;
            attribute viscosity : Real;
        }

        port def FluidPort {
            inout item fluid : HydraulicFluid;
        }

        port def ControlSignalPort {
            in attribute commandSignal : Real;
            out attribute feedbackSignal : Real;
        }

        enum def PumpState {
            enum stopped;
            enum starting;
            enum running;
            enum stopping;
            enum faulted;
        }

        part def VariableDisplacementPump {
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port controlPort : ControlSignalPort;

            attribute maxDisplacement : DisplacementValue;
            attribute minDisplacement : DisplacementValue;
            attribute currentDisplacement : DisplacementValue;
            attribute shaftSpeed : AngularVelocityValue;
            attribute volumetricEfficiency : Real;
            attribute mechanicalEfficiency : Real;
            attribute maxPressure : PressureValue;
            attribute currentState : PumpState;

            attribute theoreticalFlowRate : VolumeFlowRateValue = 
                currentDisplacement * shaftSpeed / 60.0;
            
            attribute actualFlowRate : VolumeFlowRateValue = 
                theoreticalFlowRate * volumetricEfficiency;

            perform action pumpFluid : PumpFluidAction;
            state pumpStateMachine : PumpStateMachine;
        }

        part def FluidReservoir {
            port outletPort : FluidPort;
            port returnPort : ~FluidPort;

            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            attribute ambientPressure : PressureValue;
            attribute fluidTemperature : TemperatureValue;

            item storedFluid : HydraulicFluid {
                attribute :>> pressure = ambientPressure;
                attribute :>> temperature = fluidTemperature;
                attribute :>> density = 850.0;
                attribute :>> viscosity = 0.032;
            }
        }

        part def HydraulicActuator {
            port supplyPort : ~FluidPort;
            port returnPort : FluidPort;

            attribute requiredPressure : PressureValue;
            attribute requiredFlowRate : VolumeFlowRateValue;
            attribute strokeLength : Real;
            attribute currentPosition : Real;
            attribute pistonArea : Real;

            perform action extend : ExtendAction;
            perform action retract : RetractAction;
        }

        part def PressureSensor {
            port sensingPort : ~FluidPort;

            attribute measuredPressure : PressureValue;
            attribute accuracy : Real;
            attribute range : PressureValue;
        }

        part def FlowSensor {
            port sensingPort : ~FluidPort;

            attribute measuredFlowRate : VolumeFlowRateValue;
            attribute accuracy : Real;
            attribute range : VolumeFlowRateValue;
        }

        part def DisplacementController {
            port controlOutput : ~ControlSignalPort;
            port pressureFeedbackPort : ControlSignalPort;
            port flowFeedbackPort : ControlSignalPort;

            attribute targetPressure : PressureValue;
            attribute targetFlowRate : VolumeFlowRateValue;
            attribute pressureSetpoint : PressureValue;
            attribute flowSetpoint : VolumeFlowRateValue;
            attribute controlGain : Real;
            attribute integralTime : Real;

            perform action controlLoop : DisplacementControlLoop;
        }

        part def ReliefValve {
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;

            attribute crackingPressure : PressureValue;
            attribute maxFlowCapacity : VolumeFlowRateValue;
            attribute currentOpening : Real;

            perform action relievePressure : RelievePressureAction;
        }

        part def CheckValve {
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;

            attribute crackingPressure : PressureValue;
            attribute isOpen : Boolean;
        }

        part def Filter {
            port inletPort : ~FluidPort;
            port outletPort : FluidPort;

            attribute filtrationRating : Real;
            attribute pressureDrop : PressureValue;
            attribute currentContamination : Real;
        }

        action def PumpFluidAction {
            in inletFluid : HydraulicFluid;
            in displacementCommand : Real;
            in shaftSpeed : AngularVelocityValue;
            out outletFluid : HydraulicFluid;
            out actualDisplacement : DisplacementValue;
            out deliveredFlow : VolumeFlowRateValue;
        }

        action def ExtendAction {
            in supplyFluid : HydraulicFluid;
            out position : Real;
            out force : Real;
        }

        action def RetractAction {
            in supplyFluid : HydraulicFluid;
            out position : Real;
            out force : Real;
        }

        action def DisplacementControlLoop {
            in targetPressure : PressureValue;
            in actualPressure : PressureValue;
            in targetFlowRate : VolumeFlowRateValue;
            in actualFlowRate : VolumeFlowRateValue;
            out displacementCommand : Real;
        }

        action def RelievePressureAction {
            in systemPressure : PressureValue;
            in crackingPressure : PressureValue;
            out reliefFlow : VolumeFlowRateValue;
            out valveOpening : Real;
        }

        state def PumpStateMachine {
            entry; then stopped;

            state stopped;

            transition stopped_to_starting
                first stopped
                accept StartCommand
                then starting;

            state starting;

            transition starting_to_running
                first starting
                if outletPort.fluid.pressure > 10.0
                then running;

            state running {
                do action adjustDisplacement : AdjustDisplacementAction {
                    in command = controlPort.commandSignal;
                    out displacement = currentDisplacement;
                }
            }

            transition running_to_faulted
                first running
                if outletPort.fluid.pressure > maxPressure
                then faulted;

            transition running_to_stopping
                first running
                accept StopCommand
                then stopping;

            state stopping;

            transition stopping_to_stopped
                first stopping
                if currentDisplacement <= minDisplacement
                then stopped;

            state faulted;

            transition faulted_to_stopped
                first faulted
                accept ResetCommand
                if outletPort.fluid.pressure < maxPressure
                then stopped;
        }

        action def AdjustDisplacementAction {
            in command : Real;
            out displacement : DisplacementValue;
        }

        requirement def PumpPerformanceRequirement {
            doc /* The variable displacement pump shall provide adjustable flow rate 
                 * from minimum to maximum displacement while maintaining outlet pressure
                 * within specified operating range. */

            subject pump : VariableDisplacementPump;

            require displacementRange : DisplacementRangeConstraint {
                assume constraint {
                    pump.currentDisplacement >= pump.minDisplacement and
                    pump.currentDisplacement <= pump.maxDisplacement
                }
            }

            require efficiency : EfficiencyConstraint {
                assume constraint {
                    pump.volumetricEfficiency >= 0.85 and
                    pump.mechanicalEfficiency >= 0.90
                }
            }
        }

        requirement def SystemPressureRequirement {
            doc /* The pumping subsystem shall maintain outlet pressure within 
                 * specified operating range under all load conditions. */

            attribute minOperatingPressure : PressureValue;
            attribute maxOperatingPressure : PressureValue;
            attribute nominalOperatingPressure : PressureValue;

            require pressureRange : PressureRangeConstraint;
        }

        requirement def FlowRateRequirement {
            doc /* The pumping subsystem shall deliver variable flow rate 
                 * from zero to maximum rated flow with response time less than 2 seconds. */

            attribute maxFlowRate : VolumeFlowRateValue;
            attribute minFlowRate : VolumeFlowRateValue;
            attribute responseTime : Real;

            require flowControl : FlowControlConstraint;
        }

        requirement def SafetyRequirement {
            doc /* The pumping subsystem shall include pressure relief protection
                 * and automatic shutdown on overpressure conditions. */

            require reliefProtection : ReliefProtectionConstraint;
            require overpressureShutdown : OverpressureShutdownConstraint;
        }

        constraint def DisplacementRangeConstraint;
        constraint def EfficiencyConstraint;
        constraint def PressureRangeConstraint;
        constraint def FlowControlConstraint;
        constraint def ReliefProtectionConstraint;
        constraint def OverpressureShutdownConstraint;
    }

    package Usages {
        part pumpingSubsystem {
            part reservoir : FluidReservoir {
                attribute :>> capacity = 200.0;
                attribute :>> currentLevel = 150.0;
                attribute :>> ambientPressure = 1.0;
                attribute :>> fluidTemperature = 40.0;
            }

            part supplyFilter : Filter {
                attribute :>> filtrationRating = 10.0;
                attribute :>> pressureDrop = 0.5;
                attribute :>> currentContamination = 0.02;
            }

            part checkValve : CheckValve {
                attribute :>> crackingPressure = 0.3;
                attribute :>> isOpen = false;
            }

            part pump : VariableDisplacementPump {
                attribute :>> maxDisplacement = 100.0;
                attribute :>> minDisplacement = 10.0;
                attribute :>> currentDisplacement = 50.0;
                attribute :>> shaftSpeed = 1800.0;
                attribute :>> volumetricEfficiency = 0.92;
                attribute :>> mechanicalEfficiency = 0.95;
                attribute :>> maxPressure = 250.0;
                attribute :>> currentState = PumpState::stopped;
            }

            part reliefValve : ReliefValve {
                attribute :>> crackingPressure = 240.0;
                attribute :>> maxFlowCapacity = 120.0;
                attribute :>> currentOpening = 0.0;
            }

            part outletPressureSensor : PressureSensor {
                attribute :>> accuracy = 0.5;
                attribute :>> range = 300.0;
            }

            part outletFlowSensor : FlowSensor {
                attribute :>> accuracy = 1.0;
                attribute :>> range = 150.0;
            }

            part controller : DisplacementController {
                attribute :>> targetPressure = 200.0;
                attribute :>> targetFlowRate = 80.0;
                attribute :>> pressureSetpoint = 200.0;
                attribute :>> flowSetpoint = 80.0;
                attribute :>> controlGain = 0.5;
                attribute :>> integralTime = 2.0;
            }

            part actuator : HydraulicActuator {
                attribute :>> requiredPressure = 180.0;
                attribute :>> requiredFlowRate = 75.0;
                attribute :>> strokeLength = 500.0;
                attribute :>> currentPosition = 0.0;
                attribute :>> pistonArea = 0.01;
            }

            part returnFilter : Filter {
                attribute :>> filtrationRating = 25.0;
                attribute :>> pressureDrop = 0.3;
                attribute :>> currentContamination = 0.05;
            }

            flow of hydraulicFluid : HydraulicFluid
                from reservoir.outletPort.fluid
                to supplyFilter.inletPort.fluid;

            flow of hydraulicFluid : HydraulicFluid
                from supplyFilter.outletPort.fluid
                to checkValve.inletPort.fluid;

            flow of hydraulicFluid : HydraulicFluid
                from checkValve.outletPort.fluid
                to pump.inletPort.fluid;

            flow of hydraulicFluid : HydraulicFluid
                from pump.outletPort.fluid
                to reliefValve.inletPort.fluid;

            flow of hydraulicFluid : HydraulicFluid
                from reliefValve.inletPort.fluid
                to actuator.supplyPort.fluid;

            flow of hydraulicFluid : HydraulicFluid
                from reliefValve.outletPort.fluid
                to reservoir.returnPort.fluid;

            flow of hydraulicFluid : HydraulicFluid
                from actuator.returnPort.fluid
                to returnFilter.inletPort.fluid;

            flow of hydraulicFluid : HydraulicFluid
                from returnFilter.outletPort.fluid
                to reservoir.returnPort.fluid;

            connect pump.controlPort to controller.controlOutput;

            bind outletPressureSensor.measuredPressure = controller.pressureFeedbackPort.feedbackSignal;
            bind outletFlowSensor.measuredFlowRate = controller.flowFeedbackPort.feedbackSignal;

            perform action systemOperation : SystemOperationAction {
                first start;
                then merge controlCycle;

                action monitorPressure {
                    out pressure : PressureValue = outletPressureSensor.measuredPressure;
                }

                then action monitorFlow {
                    out flow : VolumeFlowRateValue = outletFlowSensor.measuredFlowRate;
                }

                then action computeControl : DisplacementControlLoop {
                    in targetPressure = controller.targetPressure;
                    in actualPressure = monitorPressure.pressure;
                    in targetFlowRate = controller.targetFlowRate;
                    in actualFlowRate = monitorFlow.flow;
                    out displacementCommand;
                }

                then action applyControl {
                    in command = computeControl.displacementCommand;
                }

                then action pumpOperation : PumpFluidAction {
                    in inletFluid = pump.inletPort.fluid;
                    in displacementCommand = applyControl.command;
                    in shaftSpeed = pump.shaftSpeed;
                    out outletFluid;
                    out actualDisplacement;
                    out deliveredFlow;
                }

                then action checkPressure {
                    in systemPressure = pumpOperation.outletFluid.pressure;
                }

                then decide;
                    if checkPressure.systemPressure <= pump.maxPressure then controlCycle;
                    if checkPressure.systemPressure > pump.maxPressure then emergencyShutdown;

                action emergencyShutdown {
                    doc /* Emergency shutdown procedure on overpressure */
                }

                then done;
            }

            action def SystemOperationAction;

            requirement pumpPerformance : PumpPerformanceRequirement {
                subject pump = pumpingSubsystem.pump;
            }

            requirement systemPressure : SystemPressureRequirement {
                attribute :>> minOperatingPressure = 150.0;
                attribute :>> maxOperatingPressure = 240.0;
                attribute :>> nominalOperatingPressure = 200.0;
            }

            requirement flowRate : FlowRateRequirement {
                attribute :>> maxFlowRate = 120.0;
                attribute :>> minFlowRate = 0.0;
                attribute :>> responseTime = 1.5;
            }

            requirement safety : SafetyRequirement;

            assert constraint pressureWithinLimits {
                pump.outletPort.fluid.pressure >= systemPressure.minOperatingPressure and
                pump.outletPort.fluid.pressure <= systemPressure.maxOperatingPressure
            }

            assert constraint displacementControl {
                pump.currentDisplacement >= pump.minDisplacement and
                pump.currentDisplacement <= pump.maxDisplacement
            }

            assert constraint reliefValveProtection {
                reliefValve.crackingPressure <= systemPressure.maxOperatingPressure
            }

            assert constraint flowRateControl {
                pump.actualFlowRate <= flowRate.maxFlowRate
            }
        }
    }
}
