package FlowControlValveSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type PressureValue :> Real { unit "Pa"; }
    value type FlowRateValue :> Real { unit "m^3/s"; }
    value type ValvePositionValue :> Real { unit "deg"; }
    value type ControlSignalValue :> Real { unit "V"; }
    value type TemperatureValue :> Real { unit "K"; }
    value type ErrorValue :> Real { unit "m^3/s"; }

    // ---- Item types ----
    item def Fluid {
        attribute density : Real = 1000 [kg/m^3];
        attribute viscosity : Real = 0.001 [Pa*s];
    }

    // ---- Port definitions ----
    port def FluidPort {
        out item fluid : Fluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }

    port def FlowFeedbackPort {
        out attribute measuredFlow : FlowRateValue;
        out attribute sensorStatus : String;
    }

    port def ControlCommandPort {
        out attribute positionCommand : ValvePositionValue;
        out attribute commandValid : Boolean;
    }

    port def TargetSetpointPort {
        in attribute targetFlow : FlowRateValue;
        in attribute setpointValid : Boolean;
    }

    port def ActuatorFeedbackPort {
        out attribute actualPosition : ValvePositionValue;
        out attribute actuatorStatus : String;
    }

    // ---- Main system ----
    part def FlowControlValveSystem {
        // External interfaces
        port inlet : FluidPort;
        port outlet : FluidPort;
        port setpoint : TargetSetpointPort;
        port systemStatus : FlowFeedbackPort;

        // Internal components
        part valveBody : ValveBody {
            port inlet : FluidPort;
            port outlet : FluidPort;
            port positionInput : ActuatorFeedbackPort;
        }

        part actuator : Actuator {
            port command : ControlCommandPort;
            port positionOutput : ActuatorFeedbackPort;
        }

        part flowSensor : FlowSensor {
            port fluidIn : FluidPort;
            port feedback : FlowFeedbackPort;
        }

        part controller : Controller {
            port setpointIn : TargetSetpointPort;
            port flowFeedback : FlowFeedbackPort;
            port actuatorCommand : ControlCommandPort;
        }

        // Connections
        connection inletToValve : FluidPort connect self.inlet to valveBody.inlet;
        connection valveToOutlet : FluidPort connect valveBody.outlet to self.outlet;
        connection valveToSensor : FluidPort connect valveBody.outlet to flowSensor.fluidIn;
        connection sensorToController : FlowFeedbackPort connect flowSensor.feedback to controller.flowFeedback;
        connection controllerToActuator : ControlCommandPort connect controller.actuatorCommand to actuator.command;
        connection actuatorToValve : ActuatorFeedbackPort connect actuator.positionOutput to valveBody.positionInput;
        connection setpointToController : TargetSetpointPort connect self.setpoint to controller.setpointIn;
        connection sensorToStatus : FlowFeedbackPort connect flowSensor.feedback to self.systemStatus;

        // System state machine
        attribute currentFlow : FlowRateValue;
        attribute targetFlow : FlowRateValue;
        attribute valvePosition : ValvePositionValue;
        attribute systemHealth : String;

        state def SystemStates {
            entry; then closed;

            state closed {
                entry action { 
                    "System powered off. Valve in safe position." 
                }
            }

            transition from closed to initializing 
                when setpoint.setpointValid == true;

            state initializing {
                entry action { 
                    "Perform self-test. Zero flow sensor. Home actuator." 
                }
                do action {
                    "Verify sensor calibration and actuator response." 
                }
            }

            transition from initializing to regulating 
                when flowSensor.feedback.sensorStatus == "OK" 
                and actuator.positionOutput.actuatorStatus == "Ready";

            transition from initializing to fault 
                when flowSensor.feedback.sensorStatus == "Error" 
                or actuator.positionOutput.actuatorStatus == "Fault";

            state regulating {
                entry action { 
                    "Enter closed-loop control mode." 
                }
                do action {
                    "Continuously compare targetFlow to measuredFlow. "
                    "Compute error. Send corrected positionCommand to actuator." 
                }
            }

            transition regulating to regulating 
                when setpoint.targetFlow != currentFlow;

            transition regulating to fault 
                when flowSensor.feedback.sensorStatus == "Error" 
                or actuator.positionOutput.actuatorStatus == "Fault";

            state fault {
                entry action { 
                    "Close valve to safe position. Set systemHealth = 'Fault'." 
                }
                do action {
                    "Hold safe state. Await maintenance reset." 
                }
            }

            transition from fault to closed 
                when setpoint.setpointValid == false;
        }

        state machine : SystemStates;

        // Requirements satisfaction
        satisfy req FlowAccuracyRequirement by controller;
        satisfy req ResponseTimeRequirement by controller;
        satisfy req ContinuousReliabilityRequirement by valveBody;
    }

    // ---- Valve Body ----
    part def ValveBody {
        attribute maxPressure : PressureValue = 10e6 [Pa];
        attribute maxTemperature : TemperatureValue = 450 [K];
        attribute orificeDiameter : Real = 0.05 [m];
        attribute currentPosition : ValvePositionValue;
        attribute leakTightness : String = "Class VI";

        port inlet : FluidPort;
        port outlet : FluidPort;
        port positionInput : ActuatorFeedbackPort;

        action def AdjustOrifice {
            in position : ValvePositionValue;
            in fluidIn : FluidPort;
            out fluidOut : FluidPort;
            
            // Flow through orifice: Q = Cd * A * sqrt(2*dP/rho)
            attribute Cd : Real = 0.62;
            attribute area : Real = 3.14159 * (orificeDiameter/2)^2 * (position/90);
        }

        perform AdjustOrifice {
            in position = positionInput.actualPosition;
            in fluidIn = inlet;
            out fluidOut = outlet;
        }

        satisfy req PressureIntegrityRequirement by self;
    }

    // ---- Actuator ----
    part def Actuator {
        attribute maxTorque : Real = 50 [N*m];
        attribute speed : Real = 30 [deg/s];
        attribute currentPosition : ValvePositionValue;
        attribute status : String = "Ready";

        port command : ControlCommandPort;
        port positionOutput : ActuatorFeedbackPort;

        action def DriveValve {
            in commandPosition : ValvePositionValue;
            out actualPosition : ValvePositionValue;
            
            // Move toward command position at defined speed
            do action {
                "Drive motor to reach commandPosition. "
                "Update actualPosition. Report status." 
            }
        }

        perform DriveValve {
            in commandPosition = command.positionCommand;
            out actualPosition = positionOutput.actualPosition;
        }

        satisfy req ActuatorPrecisionRequirement by self;
    }

    // ---- Flow Sensor ----
    part def FlowSensor {
        attribute measurementRange : FlowRateValue = 2.0 [m^3/s];
        attribute accuracy : Real = 0.001 [m^3/s];
        attribute samplingRate : Real = 100 [Hz];
        attribute status : String = "OK";

        port fluidIn : FluidPort;
        port feedback : FlowFeedbackPort;

        action def MeasureFlow {
            in fluidIn : FluidPort;
            out measuredFlow : FlowRateValue;
            
            do action {
                "Sample flow rate. Filter noise. Output measuredFlow." 
            }
        }

        perform MeasureFlow {
            in fluidIn = fluidIn;
            out measuredFlow = feedback.measuredFlow;
        }

        satisfy req FlowMeasurementAccuracyRequirement by self;
    }

    // ---- Controller ----
    part def Controller {
        attribute proportionalGain : Real = 0.8;
        attribute integralGain : Real = 0.2;
        attribute derivativeGain : Real = 0.05;
        attribute integralError : ErrorValue = 0.0 [m^3/s];
        attribute previousError : ErrorValue = 0.0 [m^3/s];
        attribute controlOutput : ValvePositionValue;
        attribute status : String = "Active";

        port setpointIn : TargetSetpointPort;
        port flowFeedback : FlowFeedbackPort;
        port actuatorCommand : ControlCommandPort;

        action def ComputeControl {
            in target : FlowRateValue;
            in measured : FlowRateValue;
            out command : ValvePositionValue;
            
            attribute error : ErrorValue;
            attribute derivativeError : ErrorValue;
            
            do action {
                "error = target - measured; "
                "integralError += error * dt; "
                "derivativeError = (error - previousError) / dt; "
                "controlOutput = Kp*error + Ki*integralError + Kd*derivativeError; "
                "previousError = error; "
                "command = controlOutput;" 
            }
        }

        perform ComputeControl {
            in target = setpointIn.targetFlow;
            in measured = flowFeedback.measuredFlow;
            out command = actuatorCommand.positionCommand;
        }

        satisfy req ControlAlgorithmRequirement by self;
    }

    // ---- Requirements ----
    requirement def PressureIntegrityRequirement {
        doc "The valve body must safely contain fluids up to maximum rated pressure without leakage."
        attribute maxOperatingPressure : PressureValue = 10e6 [Pa];
        attribute leakClass : String = "Class VI";
    }

    requirement def FlowAccuracyRequirement {
        doc "The system shall maintain actual flow within ±1% of the target setpoint under steady-state conditions."
        attribute tolerance : Real = 0.01;
    }

    requirement def ResponseTimeRequirement {
        doc "The system shall respond to a setpoint change within 2 seconds."
        attribute maxResponseTime : Real = 2.0 [s];
    }

    requirement def ContinuousReliabilityRequirement {
        doc "The system shall operate continuously for at least 8000 hours between maintenance intervals."
        attribute minMTBF : Real = 8000 [h];
    }

    requirement def ActuatorPrecisionRequirement {
        doc "The actuator shall position the valve with ±0.5 degree accuracy."
        attribute positionTolerance : Real = 0.5 [deg];
    }

    requirement def FlowMeasurementAccuracyRequirement {
        doc "The flow sensor shall measure flow rate with accuracy of ±0.001 m³/s."
        attribute measurementAccuracy : FlowRateValue = 0.001 [m^3/s];
    }

    requirement def ControlAlgorithmRequirement {
        doc "The controller shall implement PID control to minimize flow error."
        attribute controlType : String = "PID";
    }

    requirement def SystemSafetyRequirement {
        doc "Upon fault detection, the system shall transition to a safe state with valve closed."
        attribute safeState : String = "closed";
    }

    requirement FlowControlSystemRequirements {
        doc "Top-level requirements for the automated Flow Control Valve System."
        subject system : FlowControlValveSystem;
        
        requirement pressureIntegrity : PressureIntegrityRequirement;
        requirement flowAccuracy : FlowAccuracyRequirement;
        requirement responseTime : ResponseTimeRequirement;
        requirement reliability : ContinuousReliabilityRequirement;
        requirement actuatorPrecision : ActuatorPrecisionRequirement;
        requirement measurementAccuracy : FlowMeasurementAccuracyRequirement;
        requirement controlAlgorithm : ControlAlgorithmRequirement;
        requirement safety : SystemSafetyRequirement;
    }
}
