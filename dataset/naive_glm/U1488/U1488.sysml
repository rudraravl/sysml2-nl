package HydraulicRudderSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value type PressureValue :> Real { unit 'Pa'; }
    value type ForceValue :> Real { unit 'N'; }
    value type AngleValue :> Real { unit 'deg'; }
    value type AngularVelocityValue :> Real { unit 'deg/s'; }
    value type VolumeFlowRateValue :> Real { unit 'm3/s'; }
    value type TimeValue :> Real { unit 's'; }
    value type TorqueValue :> Real { unit 'N*m'; }
    value type LengthValue :> Real { unit 'm'; }
    value type AreaValue :> Real { unit 'm2'; }
    value type MassValue :> Real { unit 'kg'; }
    value type VolumeValue :> Real { unit 'm3'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type PowerValue :> Real { unit 'W'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type VelocityValue :> Real { unit 'm/s'; }

    // ===== Item Types =====
    item def HydraulicFluid;

    item def PressurizedFluid :> HydraulicFluid {
        attribute pressure : PressureValue;
        attribute flowRate : VolumeFlowRateValue;
    }

    item def RudderCommand {
        attribute commandedAngle : AngleValue;
    }

    item def AngleFeedback {
        attribute measuredAngle : AngleValue;
    }

    item def ControlSignal {
        attribute targetAngle : AngleValue;
        attribute extend : Boolean;
        attribute retract : Boolean;
        attribute hold : Boolean;
        attribute emergency : Boolean;
    }

    // ===== Port Definitions =====
    port def PressurizedFluidPort {
        out item pressurizedFluid : PressurizedFluid;
    }

    port def ReturnFluidPort {
        out item returnFluid : HydraulicFluid;
    }

    port def CommandPort {
        out item command : RudderCommand;
    }

    port def FeedbackPort {
        out item feedback : AngleFeedback;
    }

    port def ControlSignalPort {
        out item signal : ControlSignal;
    }

    port def MechanicalLinkPort {
        out attribute force : ForceValue;
        out attribute displacement : LengthValue;
    }

    // ===== Requirements =====
    requirement def SteeringForceRequirement {
        doc "The hydraulic actuator must generate sufficient steering force to position the rudder at full vessel speed."
        attribute minSteeringForce : ForceValue = 500000 [N];
        subject actuatorForce : ForceValue;
        require actuatorForce >= minSteeringForce
    }

    requirement def PositioningAccuracyRequirement {
        doc "The rudder angle must be within 0.5 degree of the commanded angle during steady-state holding."
        attribute maxError : AngleValue = 0.5 [deg];
        subject angleError : AngleValue;
        require angleError <= maxError
    }

    requirement def ResponseTimeRequirement {
        doc "The rudder must move from neutral to full deflection within the specified response time."
        attribute maxResponseTime : TimeValue = 15 [s];
        subject responseTime : TimeValue;
        require responseTime <= maxResponseTime
    }

    requirement def EmergencyResponseRequirement {
        doc "The system must enter emergency mode within 1 second of detecting a failure."
        attribute maxEmergencyActivationTime : TimeValue = 1 [s];
        subject emergencyActivationTime : TimeValue;
        require emergencyActivationTime <= maxEmergencyActivationTime
    }

    requirement def HydraulicPressureRequirement {
        doc "The hydraulic power unit must maintain operating pressure above the minimum required level."
        attribute minOperatingPressure : PressureValue = 10000000 [Pa];
        subject operatingPressure : PressureValue;
        require operatingPressure >= minOperatingPressure
    }

    // ===== Part Definitions =====

    part def RudderBlade {
        attribute bladeArea : AreaValue = 12.0 [m2];
        attribute bladeMass : MassValue = 8000 [kg];
        attribute maxDeflection : AngleValue = 35.0 [deg];
        attribute currentAngle : AngleValue = 0.0 [deg];
        attribute angularVelocity : AngularVelocityValue = 0.0 [deg/s];
        attribute generatedLateralForce : ForceValue;
        attribute generatedYawMoment : TorqueValue;
        attribute distanceToPivot : LengthValue = 2.5 [m];
        attribute waterFlowSpeed : VelocityValue = 10.0 [m/s];

        port mechanicalInterface : ~MechanicalLinkPort;
        port sensorMount : MechanicalLinkPort;

        action def GenerateLateralForce {
            in waterFlowSpeed : VelocityValue;
            in rudderAngle : AngleValue;
            in bladeArea : AreaValue;
            out lateralForce : ForceValue;
            out yawMoment : TorqueValue;
        }

        perform action generateForce : GenerateLateralForce {
            in waterFlowSpeed = waterFlowSpeed;
            in rudderAngle = currentAngle;
            in bladeArea = bladeArea;
        }
    }

    part def HydraulicActuator {
        attribute pistonArea : AreaValue = 0.02 [m2];
        attribute strokeLength : LengthValue = 1.5 [m];
        attribute maxForce : ForceValue = 600000 [N];
        attribute currentForce : ForceValue = 0 [N];
        attribute position : LengthValue = 0.0 [m];
        attribute actuatorPressure : PressureValue = 0 [Pa];
        attribute commandedPosition : LengthValue = 0.0 [m];

        port fluidSupply : ~PressurizedFluidPort;
        port fluidReturn : ReturnFluidPort;
        port mechanicalOutput : MechanicalLinkPort;
        port controlInput : ~ControlSignalPort;

        action def ExtendActuator {
            in targetAngle : AngleValue;
            in currentAngle : AngleValue;
            in supplyPressure : PressureValue;
            in pistonArea : AreaValue;
            out appliedForce : ForceValue;
            out newPosition : LengthValue;
        }

        action def RetractActuator {
            in targetAngle : AngleValue;
            in currentAngle : AngleValue;
            in supplyPressure : PressureValue;
            in pistonArea : AreaValue;
            out appliedForce : ForceValue;
            out newPosition : LengthValue;
        }

        action def HoldPosition {
            in currentPosition : LengthValue;
            in supplyPressure : PressureValue;
            in pistonArea : AreaValue;
            out holdingForce : ForceValue;
        }

        perform action extend : ExtendActuator;
        perform action retract : RetractActuator;
        perform action hold : HoldPosition;
    }

    part def HydraulicPowerUnit {
        attribute reservoirCapacity : VolumeValue = 0.5 [m3];
        attribute currentFluidLevel : VolumeValue = 0.45 [m3];
        attribute pumpFlowRate : VolumeFlowRateValue = 0.01 [m3/s];
        attribute operatingPressure : PressureValue = 15000000 [Pa];
        attribute maxPressure : PressureValue = 20000000 [Pa];
        attribute pumpPower : PowerValue = 150000 [W];
        attribute pumpActive : Boolean = true;

        port fluidOutput : PressurizedFluidPort;
        port fluidReturnInput : ~ReturnFluidPort;

        action def PressurizeFluid {
            in incomingFluid : HydraulicFluid;
            in targetPressure : PressureValue;
            in flowRate : VolumeFlowRateValue;
            out pressurizedFluid : PressurizedFluid;
        }

        action def MaintainPressure {
            in currentPressure : PressureValue;
            in targetPressure : PressureValue;
            out adjustedPressure : PressureValue;
        }

        perform action pressurize : PressurizeFluid;
        perform action maintainPressure : MaintainPressure;
    }

    part def SteeringMechanism {
        attribute helmPosition : AngleValue = 0.0 [deg];
        attribute autopilotEngaged : Boolean = false;
        attribute autopilotTargetAngle : AngleValue = 0.0 [deg];
        attribute maxHelmRate : AngularVelocityValue = 10.0 [deg/s];

        port commandOutput : CommandPort;

        action def GenerateCommand {
            in helmInput : AngleValue;
            in autopilotInput : AngleValue;
            in useAutopilot : Boolean;
            out command : RudderCommand;
        }

        perform action generateCommand : GenerateCommand {
            in helmInput = helmPosition;
            in autopilotInput = autopilotTargetAngle;
            in useAutopilot = autopilotEngaged;
        }
    }

    part def AngleSensor {
        attribute measurementRange : AngleValue = 90.0 [deg];
        attribute accuracy : AngleValue = 0.1 [deg];
        attribute updateRate : FrequencyValue = 100.0 [Hz];
        attribute measuredAngle : AngleValue = 0.0 [deg];
        attribute sensorFault : Boolean = false;

        port sensorOutput : FeedbackPort;
        port mechanicalInput : ~MechanicalLinkPort;

        action def MeasureAngle {
            in mechanicalDisplacement : LengthValue;
            in pivotDistance : LengthValue;
            out angleFeedback : AngleFeedback;
        }

        perform action measure : MeasureAngle;
    }

    part def ControlSystem {
        attribute commandedAngle : AngleValue = 0.0 [deg];
        attribute measuredAngle : AngleValue = 0.0 [deg];
        attribute angleError : AngleValue = 0.0 [deg];
        attribute controlGain : Real = 5.0;
        attribute deadband : AngleValue = 0.5 [deg];
        attribute emergencyDetected : Boolean = false;
        attribute systemActive : Boolean = true;
        attribute pressureFaultThreshold : PressureValue = 8000000 [Pa];
        attribute sensorFaultDetected : Boolean = false;

        port commandInput : ~CommandPort;
        port feedbackInput : ~FeedbackPort;
        port controlOutput : ControlSignalPort;

        action def ComputeControl {
            in command : RudderCommand;
            in feedback : AngleFeedback;
            in emergencyInput : Boolean;
            in deadband : AngleValue;
            out signal : ControlSignal;
        }

        action def DetectEmergency {
            in sensorStatus : Boolean;
            in pressureLevel : PressureValue;
            in threshold : PressureValue;
            out emergencyFlag : Boolean;
        }

        perform action compute : ComputeControl;
        perform action detectEmergency : DetectEmergency;

        satisfy PositioningAccuracyRequirement by angleError;
    }

    // ===== Top-level System =====
    part def HydraulicRudderSystem {
        attribute systemName : String = "HydraulicRudderSystem";
        attribute maxRudderAngle : AngleValue = 35.0 [deg];
        attribute systemResponseTime : TimeValue;
        attribute emergencyActivationTime : TimeValue;
        attribute currentRudderAngle : AngleValue = 0.0 [deg];
        attribute currentCommandedAngle : AngleValue = 0.0 [deg];
        attribute systemEmergencyFlag : Boolean = false;
        attribute angleErrorTolerance : AngleValue = 0.5 [deg];

        part rudderBlade : RudderBlade;
        part hydraulicActuator : HydraulicActuator;
        part hydraulicPowerUnit : HydraulicPowerUnit;
        part steeringMechanism : SteeringMechanism;
        part angleSensor : AngleSensor;
        part controlSystem : ControlSystem;

        // Connections
        connect hydraulicPowerUnit.fluidOutput to hydraulicActuator.fluidSupply;
        connect hydraulicActuator.fluidReturn to hydraulicPowerUnit.fluidReturnInput;
        connect hydraulicActuator.mechanicalOutput to rudderBlade.mechanicalInterface;
        connect rudderBlade.sensorMount to angleSensor.mechanicalInput;
        connect steeringMechanism.commandOutput to controlSystem.commandInput;
        connect angleSensor.sensorOutput to controlSystem.feedbackInput;
        connect controlSystem.controlOutput to hydraulicActuator.controlInput;

        // Requirements satisfaction
        satisfy SteeringForceRequirement by hydraulicActuator.maxForce;
        satisfy PositioningAccuracyRequirement by controlSystem.angleError;
        satisfy ResponseTimeRequirement by systemResponseTime;
        satisfy EmergencyResponseRequirement by emergencyActivationTime;
        satisfy HydraulicPressureRequirement by hydraulicPowerUnit.operatingPressure;

        // ===== State Machine =====
        state machine RudderControlStates {

            initial state Neutral {
                entry {
                    currentRudderAngle = 0.0 [deg];
                }
                do {
                    // Hold rudder centered at 0 degrees
                }
                transition to Deflecting
                    when currentCommandedAngle != currentRudderAngle
                    if !systemEmergencyFlag;
            }

            state Deflecting {
                entry {
                    // Begin actuator movement toward commanded angle
                }
                do {
                    // Actuator extends or retracts to reach commanded angle
                }
                transition to Holding
                    when (currentCommandedAngle - currentRudderAngle) <= angleErrorTolerance
                        and (currentRudderAngle - currentCommandedAngle) <= angleErrorTolerance;
                transition to Emergency
                    when systemEmergencyFlag;
            }

            state Holding {
                entry {
                    // Steady-state angle reached, maintain position
                }
                do {
                    // Actuator holds position against hydrodynamic loads
                }
                transition to Deflecting
                    when currentCommandedAngle != currentRudderAngle
                    if !systemEmergencyFlag;
                transition to Neutral
                    when currentCommandedAngle == 0.0 [deg]
                        and currentRudderAngle == 0.0 [deg];
                transition to Emergency
                    when systemEmergencyFlag;
            }

            state Emergency {
                entry {
                    // Activate emergency procedures: lock rudder or return to neutral
                }
                do {
                    // Safe mode operation with reduced functionality
                }
                transition to Neutral
                    when !systemEmergencyFlag
                        and currentCommandedAngle == 0.0 [deg];
            }
        }
    }
}
