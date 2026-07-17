package PressureRegulationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;

    attribute def PressureValue :> ISQ::pressure;
    attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
    attribute def FlowRateValue :> ISQ::volumeFlowRate;
    attribute def VolumeValue :> ISQ::volume;

    enum def SystemState {
        initializing;
        monitoring;
        regulating;
        emergency;
        shutdown;
    }

    enum def ValveState {
        closed;
        opening;
        open;
        closing;
        partiallyOpen;
    }

    item def ProcessFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
    }

    port def FluidPort {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        out flow : ProcessFluid;
    }

    port def SensorPort {
        out measuredPressure : PressureValue;
        out measuredTemperature : TemperatureValue;
    }

    port def ControlPort {
        in command : ValveState;
        out status : ValveState;
    }

    part def PressureSensor {
        port sensePort : FluidPort;
        port dataPort : SensorPort;
        attribute accuracy : Real = 0.01;
        attribute responseTime : Time::TimeValue = 50.0 [SI::ms];

        action measurePressure {
            in fluidPressure : PressureValue;
            out reading : PressureValue;
            first start;
            then action samplePressure {
                in inputPressure = fluidPressure;
                out sampleValue : PressureValue = inputPressure;
            }
            then action filterReading {
                in rawValue = samplePressure.sampleValue;
                out filteredValue : PressureValue = rawValue;
            }
            then action outputReading {
                in finalValue = filterReading.filteredValue;
                out reading = finalValue;
            }
            then done;
        }
    }

    part def ControlValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port control : ControlPort;
        
        attribute currentState : ValveState = ValveState::closed;
        attribute maxFlowCapacity : FlowRateValue = 100.0 [SI::L/SI::s];
        attribute actuationTime : Time::TimeValue = 200.0 [SI::ms];

        state valveStateMachine {
            entry; then closed;

            state closed {
                entry assign currentState := ValveState::closed;
            }
            transition closed_to_opening
                first closed
                accept OpenCommand
                then opening;

            state opening {
                entry assign currentState := ValveState::opening;
            }
            transition opening_to_open
                first opening
                accept FullyOpenReached
                then open;

            state open {
                entry assign currentState := ValveState::open;
            }
            transition open_to_closing
                first open
                accept CloseCommand
                then closing;

            state closing {
                entry assign currentState := ValveState::closing;
            }
            transition closing_to_closed
                first closing
                accept FullyClosedReached
                then closed;

            state partiallyOpen {
                entry assign currentState := ValveState::partiallyOpen;
            }
            transition open_to_partial
                first open
                accept PartialCommand
                then partiallyOpen;
            transition partial_to_closing
                first partiallyOpen
                accept CloseCommand
                then closing;
        }

        action actuate {
            in targetState : ValveState;
            out actualState : ValveState;
        }
    }

    part def PressureVessel {
        port vesselPort : FluidPort;
        
        attribute maxPressure : PressureValue = 1000.0 [SI::kPa];
        attribute volume : VolumeValue = 500.0 [SI::L];
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute safetyMargin : PressureValue = 50.0 [SI::kPa];

        item containedFluid : ProcessFluid {
            attribute :>> pressure = currentPressure;
            attribute :>> temperature = currentTemperature;
        }

        assert constraint safetyConstraint {
            currentPressure <= maxPressure - safetyMargin
        }
    }

    part def PressureController {
        port sensorInput : SensorPort;
        port valveOutput : ControlPort;
        
        attribute targetPressure : PressureValue = 500.0 [SI::kPa];
        attribute tolerance : PressureValue = 5.0 [SI::kPa];
        attribute criticalThreshold : PressureValue = 900.0 [SI::kPa];
        attribute currentSystemState : SystemState = SystemState::initializing;

        action def EvaluatePressure {
            in measured : PressureValue;
            in target : PressureValue;
            in tol : PressureValue;
            in critical : PressureValue;
            out decision : SystemState;
        }

        action def ComputeValveCommand {
            in systemState : SystemState;
            in pressureError : Real;
            out command : ValveState;
        }

        action controlCycle {
            first start;
            then merge continuousControl;

            then action readSensor {
                in sensorData : PressureValue;
                out currentReading : PressureValue = sensorData;
            }

            then action evaluate : EvaluatePressure {
                in measured = readSensor.currentReading;
                in target = targetPressure;
                in tol = tolerance;
                in critical = criticalThreshold;
                out stateDecision : SystemState;
            }

            then decide controlDecision;
                if evaluate.stateDecision == SystemState::emergency then emergencyStop;
                if evaluate.stateDecision == SystemState::regulating then regulate;
                if evaluate.stateDecision == SystemState::monitoring then monitor;
                else normalOperation;

            action emergencyStop {
                out valveCommand = ValveState::closed;
            }
            then done;

            action regulate : ComputeValveCommand {
                in systemState = SystemState::regulating;
                in pressureError = 0.0;
                out valveCommand : ValveState;
            }
            then continuousControl;

            action monitor {
                out valveCommand = ValveState::partiallyOpen;
            }
            then continuousControl;

            action normalOperation {
                out valveCommand = ValveState::partiallyOpen;
            }
            then continuousControl;
        }

        state controllerStateMachine {
            entry; then initializing;

            state initializing {
                entry assign currentSystemState := SystemState::initializing;
            }
            transition init_to_monitoring
                first initializing
                accept SystemReady
                then monitoring;

            state monitoring {
                entry assign currentSystemState := SystemState::monitoring;
                
                state idle;
                state checking;
                
                transition idle_to_checking
                    first idle
                    then checking;
                transition checking_to_idle
                    first checking
                    then idle;
            }
            transition monitoring_to_regulating
                first monitoring
                accept PressureDeviation
                then regulating;

            state regulating {
                entry assign currentSystemState := SystemState::regulating;
                
                state adjusting;
                state stabilizing;
                
                transition adjusting_to_stabilizing
                    first adjusting
                    accept PressureStable
                    then stabilizing;
            }
            transition regulating_to_monitoring
                first regulating
                accept TargetReached
                then monitoring;

            state emergency {
                entry assign currentSystemState := SystemState::emergency;
            }
            transition any_to_emergency
                first monitoring
                accept CriticalPressure
                then emergency;
            transition emergency_to_shutdown
                first emergency
                accept SafetyProtocol
                then shutdown;

            state shutdown {
                entry assign currentSystemState := SystemState::shutdown;
            }
        }
    }

    part def ReliefValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        
        attribute setPoint : PressureValue = 950.0 [SI::kPa];
        attribute isOpen : Boolean = false;

        action reliefAction {
            in inletPressure : PressureValue;
            out relieving : Boolean;
            first start;
            then decide;
                if inletPressure >= setPoint then openRelief;
                else closeRelief;
            action openRelief {
                out relieving = true;
            }
            then done;
            action closeRelief {
                out relieving = false;
            }
            then done;
        }
    }

    part pressureRegulationSystem {
        doc /* 
         * Primary Function: Automatically regulate and maintain process fluid pressure
         * within a vessel at a specified target value by continuously monitoring pressure
         * conditions and dynamically adjusting inlet valve position to control fluid flow,
         * while providing emergency pressure relief to ensure safe operation.
         */

        attribute systemTargetPressure : PressureValue = 500.0 [SI::kPa];
        attribute systemTolerance : PressureValue = 5.0 [SI::kPa];
        attribute maxOperatingPressure : PressureValue = 1000.0 [SI::kPa];
        attribute criticalPressure : PressureValue = 900.0 [SI::kPa];

        part sensor : PressureSensor {
            port :>> sensePort;
            port :>> dataPort;
        }

        part controller : PressureController {
            attribute :>> targetPressure = systemTargetPressure;
            attribute :>> tolerance = systemTolerance;
            attribute :>> criticalThreshold = criticalPressure;
            port :>> sensorInput;
            port :>> valveOutput;
        }

        part inletValve : ControlValve {
            attribute :>> maxFlowCapacity = 80.0 [SI::L/SI::s];
            port :>> inlet;
            port :>> outlet;
            port :>> control;
        }

        part vessel : PressureVessel {
            attribute :>> maxPressure = maxOperatingPressure;
            attribute :>> volume = 500.0 [SI::L];
            port :>> vesselPort;
        }

        part safetyRelief : ReliefValve {
            attribute :>> setPoint = criticalPressure + 50.0 [SI::kPa];
            port :>> inlet;
            port :>> outlet;
        }

        connection sensorToVessel
            connect sensor.sensePort to vessel.vesselPort;

        connection sensorToController
            connect sensor.dataPort to controller.sensorInput;

        connection controllerToValve
            connect controller.valveOutput to inletValve.control;

        connection valveToVessel
            connect inletValve.outlet to vessel.vesselPort;

        connection vesselToRelief
            connect vessel.vesselPort to safetyRelief.inlet;

        perform action regulateSystemPressure {
            first start;
            then merge continuousRegulation;

            then action monitorVesselPressure {
                in vesselPressure : PressureValue;
                out pressureReading : PressureValue = vesselPressure;
            }

            then action executeControlLogic references controller.controlCycle;

            then action actuateValvePosition references inletValve.actuate;

            then action checkSafetyRelief references safetyRelief.reliefAction;

            then continuousRegulation;
        }
    }

    requirement def SystemRequirement {
        doc /* Base requirement for pressure regulation system. */
        subject system : pressureRegulationSystem;
    }

    requirement <'REQ-PR-001'> maintainTargetPressure : SystemRequirement {
        doc /* The system shall maintain vessel pressure at the target value within specified tolerance. */
        subject sys :> pressureRegulationSystem;
        
        require constraint {
            sys.vessel.currentPressure >= (sys.systemTargetPressure - sys.systemTolerance) and
            sys.vessel.currentPressure <= (sys.systemTargetPressure + sys.systemTolerance)
        }
    }

    requirement <'REQ-PR-002'> preventOverpressure : SystemRequirement {
        doc /* The system shall prevent vessel pressure from exceeding maximum rated pressure. */
        subject sys :> pressureRegulationSystem;
        
        require constraint {
            sys.vessel.currentPressure <= sys.vessel.maxPressure
        }
    }

    requirement <'REQ-PR-003'> emergencyResponse : SystemRequirement {
        doc /* The system shall close inlet valve and activate relief when critical pressure is detected. */
        subject sys :> pressureRegulationSystem;
        
        require constraint {
            sys.controller.currentSystemState == SystemState::emergency implies
            sys.inletValve.currentState == ValveState::closed
        }
    }

    requirement <'REQ-PR-004'> sensorAccuracy : SystemRequirement {
        doc /* Pressure sensor shall provide measurements with accuracy better than 1% of reading. */
        subject sensor :> pressureRegulationSystem.sensor;
        
        require constraint {
            sensor.accuracy <= 0.01
        }
    }

    requirement <'REQ-PR-005'> responseTime : SystemRequirement {
        doc /* The controller shall respond to pressure deviations within 500 milliseconds. */
        subject controller :> pressureRegulationSystem.controller;
    }

    satisfy maintainTargetPressure by pressureRegulationSystem;
    satisfy preventOverpressure by pressureRegulationSystem;
    satisfy emergencyResponse by pressureRegulationSystem;
    satisfy sensorAccuracy by pressureRegulationSystem.sensor;
    satisfy responseTime by pressureRegulationSystem.controller;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import NumericalFunctions::*;
    private import PressureRegulationSystem::*;

    part testSubject : PressureController {
    :>> systemState = SystemState::initializing;
    :>> pressureError = 0.0;
    }
}
