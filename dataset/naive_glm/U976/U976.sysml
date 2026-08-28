package ArtificialMuscleActuatorSystem {

    import ScalarValues::*;

    // ===== Value Types =====
    value def Voltage :> Real;
    value def Current :> Real;
    value def ForceValue :> Real;
    value def LengthValue :> Real;
    value def MassValue :> Real;
    value def TimeValue :> Real;
    value def Percentage :> Real;
    value def TemperatureValue :> Real;

    // ===== Item Definitions =====
    item def ElectricalEnergy;
    item def ControlSignal {
        attribute command : String;
        attribute targetVoltage : Voltage;
    }
    item def ForceMeasurement {
        attribute measuredForce : ForceValue;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }
    item def SystemCommand {
        attribute command : String;
        attribute targetForce : ForceValue;
    }
    item def StatusReport {
        attribute status : String;
        attribute cycleCount : Integer;
        attribute currentForce : ForceValue;
        attribute currentLength : LengthValue;
    }

    // ===== Port Definitions =====
    port def HVOutputPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def HVControlPort {
        in signal : ControlSignal;
    }

    port def FiberElectricalPort {
        in voltage : Voltage;
        in current : Current;
    }

    port def FiberMechanicalPort {
        out force : ForceValue;
        out length : LengthValue;
    }

    port def LoadMechanicalPort {
        in force : ForceValue;
        in displacement : LengthValue;
    }

    port def SensorMechanicalInPort {
        in force : ForceValue;
    }

    port def SensorMechanicalOutPort {
        out force : ForceValue;
    }

    port def SensorDataPort {
        out measurement : ForceMeasurement;
    }

    port def MCUControlOutPort {
        out signal : ControlSignal;
    }

    port def MCUFeedbackPort {
        in measurement : ForceMeasurement;
    }

    port def MCUCommandPort {
        in command : SystemCommand;
    }

    port def MCUStatusPort {
        out report : StatusReport;
    }

    // ===== Calculation Definitions =====
    calc def RequiredVoltage {
        in targetForce : ForceValue;
        in fiberMaxForce : ForceValue;
        in nominalVoltage : Voltage;
        out result : Voltage;
    }

    calc def ContractionRatio {
        in appliedVoltage : Voltage;
        in thresholdVoltage : Voltage;
        out ratio : Percentage;
    }

    // ===== Part Definitions =====

    part def ElectroactivePolymerFiber {
        attribute restingLength : LengthValue = 100;
        attribute maxContractionPercent : Percentage = 30;
        attribute maxForce : ForceValue = 50;
        attribute stiffness : Real = 0.5;
        attribute operatingTemp : TemperatureValue = 25;
        attribute currentLength : LengthValue;
        attribute generatedForce : ForceValue;
        attribute appliedVoltage : Voltage;
        attribute contractedLength : LengthValue = restingLength * (1.0 - maxContractionPercent / 100.0);
        attribute contractionState : String;

        port electrical : FiberElectricalPort;
        port mechanical : FiberMechanicalPort;

        action def ContractAction {
            in voltage : Voltage;
            in restLength : LengthValue;
            in contractLength : LengthValue;
            out length : LengthValue;
            out force : ForceValue;
        }

        action def RelaxAction {
            in restLength : LengthValue;
            out length : LengthValue;
            out force : ForceValue;
        }

        action def HoldAction {
            in targetForce : ForceValue;
            in currentForce : ForceValue;
            out adjustedForce : ForceValue;
        }

        state def FiberStateBehavior {
            entry; then Resting;

            state Resting {
                entry {
                    currentLength = restingLength;
                    generatedForce = 0;
                    contractionState = "resting";
                }
            }

            state Contracting {
                entry {
                    currentLength = contractedLength;
                    generatedForce = maxForce;
                    contractionState = "contracting";
                }
            }

            state Holding {
                entry {
                    contractionState = "holding";
                }
            }

            state Relaxing {
                entry {
                    currentLength = restingLength;
                    generatedForce = 0;
                    contractionState = "relaxing";
                }
            }

            transition Resting to Contracting when electrical.voltage > 0;
            transition Contracting to Holding when generatedForce >= maxForce;
            transition Holding to Relaxing when electrical.voltage == 0;
            transition Contracting to Relaxing when electrical.voltage == 0;
            transition Relaxing to Resting when currentLength >= restingLength;
        }

        exhibit FiberStateBehavior;
    }

    part def HighVoltagePowerSupply {
        attribute nominalVoltage : Voltage = 2000;
        attribute maxCurrent : Current = 0.01;
        attribute outputVoltage : Voltage = 0;
        attribute outputCurrent : Current = 0;
        attribute enabled : Boolean = false;
        attribute efficiency : Real = 0.85;
        attribute rampTime : TimeValue = 0.05;

        port control : HVControlPort;
        port output : HVOutputPort;

        action def EnableAction {
            in targetVoltage : Voltage;
            in ramp : TimeValue;
            out voltage : Voltage;
        }

        action def DisableAction {
            out voltage : Voltage;
        }

        action def RegulateAction {
            in targetVoltage : Voltage;
            in loadCurrent : Current;
            out voltage : Voltage;
            out current : Current;
        }

        state def SupplyStateBehavior {
            entry; then Off;

            state Off {
                entry {
                    outputVoltage = 0;
                    outputCurrent = 0;
                    enabled = false;
                }
            }

            state Ramping {
                entry {
                    enabled = true;
                }
            }

            state On {
                entry {
                    outputVoltage = nominalVoltage;
                    enabled = true;
                }
            }

            transition Off to Ramping when control.signal.command == "activate";
            transition Ramping to On when outputVoltage >= nominalVoltage;
            transition On to Off when control.signal.command == "deactivate";
            transition Ramping to Off when control.signal.command == "deactivate";
        }

        exhibit SupplyStateBehavior;
    }

    part def MicrocontrollerUnit {
        attribute targetForce : ForceValue = 30;
        attribute samplePeriod : TimeValue = 0.01;
        attribute active : Boolean = false;
        attribute measuredForce : ForceValue;
        attribute outputCommand : String;
        attribute pidProportional : Real = 1.2;
        attribute pidIntegral : Real = 0.4;
        attribute pidDerivative : Real = 0.08;
        attribute integralError : Real = 0;
        attribute previousError : Real = 0;
        attribute cycleCount : Integer = 0;

        port commandIn : MCUCommandPort;
        port feedback : MCUFeedbackPort;
        port controlOut : MCUControlOutPort;
        port statusOut : MCUStatusPort;

        action def ProcessCommandAction {
            in cmd : SystemCommand;
            out signal : ControlSignal;
        }

        action def RegulateForceAction {
            in measured : ForceMeasurement;
            in target : ForceValue;
            out signal : ControlSignal;
        }

        action def GenerateStatusAction {
            in force : ForceValue;
            in cycles : Integer;
            out report : StatusReport;
        }

        state def MCUStateBehavior {
            entry; then Idle;

            state Idle {
                entry {
                    active = false;
                    outputCommand = "none";
                }
            }

            state Activating {
                entry {
                    active = true;
                    outputCommand = "activate";
                    cycleCount = cycleCount + 1;
                }
            }

            state Regulating {
                entry {
                    active = true;
                    outputCommand = "hold";
                }
            }

            state Deactivating {
                entry {
                    active = false;
                    outputCommand = "deactivate";
                }
            }

            transition Idle to Activating when commandIn.command.command == "activate";
            transition Activating to Regulating when feedback.measurement.measuredForce > 0;
            transition Regulating to Deactivating when commandIn.command.command == "deactivate";
            transition Activating to Deactivating when commandIn.command.command == "deactivate";
            transition Deactivating to Idle when feedback.measurement.measuredForce == 0;
        }

        exhibit MCUStateBehavior;
    }

    part def ForceSensor {
        attribute sensitivity : Real = 0.1;
        attribute range : ForceValue = 100;
        attribute measuredForce : ForceValue;
        attribute calibrated : Boolean = true;
        attribute noiseFloor : ForceValue = 0.05;
        attribute sampleRate : TimeValue = 0.005;

        port mechanicalIn : SensorMechanicalInPort;
        port mechanicalOut : SensorMechanicalOutPort;
        port dataOut : SensorDataPort;

        action def MeasureAction {
            in force : ForceValue;
            in sensitivityVal : Real;
            out measurement : ForceMeasurement;
        }

        action def CalibrateAction {
            out calStatus : Boolean;
        }

        state def SensorStateBehavior {
            entry; then Ready;

            state Ready {
                entry {
                    measuredForce = mechanicalIn.force;
                }
            }

            state Measuring {
                entry {
                    measuredForce = mechanicalIn.force;
                }
            }

            state Fault {
                entry {
                    measuredForce = 0;
                }
            }

            transition Ready to Measuring when mechanicalIn.force > 0;
            transition Measuring to Ready when mechanicalIn.force == 0;
            transition Measuring to Fault when measuredForce > range;
            transition Fault to Ready when calibrated == true;
        }

        exhibit SensorStateBehavior;
    }

    part def MechanicalLoad {
        attribute mass : MassValue = 2;
        attribute position : LengthValue = 0;
        attribute maxDisplacement : LengthValue = 30;
        attribute currentForce : ForceValue;
        attribute damping : Real = 0.3;
        attribute friction : ForceValue = 0.5;

        port mechanical : LoadMechanicalPort;

        action def MoveAction {
            in force : ForceValue;
            in loadMass : MassValue;
            in dampingCoeff : Real;
            out displacement : LengthValue;
        }

        action def HoldPositionAction {
            in force : ForceValue;
            in frictionForce : ForceValue;
            out displacement : LengthValue;
        }

        state def LoadStateBehavior {
            entry; then Static;

            state Static {
                entry {
                    currentForce = 0;
                    position = 0;
                }
            }

            state Moving {
                entry {
                    currentForce = mechanical.force;
                }
            }

            state Held {
                entry {
                    currentForce = mechanical.force;
                }
            }

            transition Static to Moving when mechanical.force > friction;
            transition Moving to Held when position >= maxDisplacement;
            transition Held to Static when mechanical.force == 0;
            transition Moving to Static when mechanical.force <= friction;
        }

        exhibit LoadStateBehavior;
    }

    // ===== System Definition =====
    part def ArtificialMuscleActuator {
        attribute systemName : String = "ArtificialMuscleActuator";
        attribute designForce : ForceValue = 30;
        attribute designVoltage : Voltage = 2000;
        attribute cycleCount : Integer = 0;
        attribute systemActive : Boolean = false;
        attribute ambientTemp : TemperatureValue = 25;

        port externalCommand : MCUCommandPort;
        port systemStatus : MCUStatusPort;

        part microcontroller : MicrocontrollerUnit;
        part powerSupply : HighVoltagePowerSupply;
        part fiber : ElectroactivePolymerFiber;
        part sensor : ForceSensor;
        part load : MechanicalLoad;

        // Control signal from MCU to power supply
        connection microcontroller.controlOut to powerSupply.control;
        flow of ControlSignal from microcontroller.controlOut to powerSupply.control;

        // Electrical energy from power supply to fiber
        connection powerSupply.output to fiber.electrical;
        flow of ElectricalEnergy from powerSupply.output to fiber.electrical;

        // Mechanical force path: fiber -> sensor -> load
        connection fiber.mechanical to sensor.mechanicalIn;
        connection sensor.mechanicalOut to load.mechanical;

        // Force feedback from sensor to MCU
        connection sensor.dataOut to microcontroller.feedback;
        flow of ForceMeasurement from sensor.dataOut to microcontroller.feedback;

        // External command to MCU
        connection externalCommand to microcontroller.commandIn;
        flow of SystemCommand from externalCommand to microcontroller.commandIn;

        // Status output
        connection microcontroller.statusOut to systemStatus;
        flow of StatusReport from microcontroller.statusOut to systemStatus;

        state def SystemOperationBehavior {
            entry; then Standby;

            state Standby {
                entry {
                    systemActive = false;
                }
            }

            state Activating {
                entry {
                    systemActive = true;
                }
            }

            state Holding {
                entry {
                    systemActive = true;
                }
            }

            state Deactivating {
                entry {
                    systemActive = false;
                }
            }

            transition Standby to Activating when externalCommand.command.command == "activate";
            transition Activating to Holding when sensor.dataOut.measurement.measuredForce >= microcontroller.targetForce;
            transition Holding to Deactivating when externalCommand.command.command == "deactivate";
            transition Activating to Deactivating when externalCommand.command.command == "deactivate";
            transition Deactivating to Standby when fiber.mechanical.length >= fiber.restingLength;
        }

        exhibit SystemOperationBehavior;
    }

    // ===== Requirements =====
    requirement def ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* Base requirement for the artificial muscle actuator system. */
    }

    requirement ContractionCapability : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The electroactive polymer fiber shall contract by at least 30 percent of its resting length when the design voltage is applied. */
        require actuator.fiber.maxContractionPercent >= 30;
    }

    requirement ForceGeneration : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The system shall generate at least 30 N of mechanical force against the load when activated. */
        require actuator.designForce >= 30;
    }

    requirement VoltageProvision : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The high-voltage power supply shall provide up to 2000 V to stimulate the polymer fiber. */
        require actuator.powerSupply.nominalVoltage >= 2000;
    }

    requirement FeedbackAccuracy : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The force sensor shall measure mechanical force with sensitivity of at least 0.1 N. */
        require actuator.sensor.sensitivity <= 0.1;
    }

    requirement ActivationResponse : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The microcontroller shall process commands and adjust output within a 0.01 s sample period. */
        require actuator.microcontroller.samplePeriod <= 0.01;
    }

    requirement RelaxationReturn : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* Upon deactivation, the polymer fiber shall return to its resting length of 100 mm. */
        require actuator.fiber.restingLength == 100;
    }

    requirement SilentOperation : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The actuator shall operate silently without acoustic emissions above ambient noise level. */
    }

    requirement CycleEndurance : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The actuator shall support at least 100000 activation and deactivation cycles without degradation. */
    }

    requirement LoadCompatibility : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The actuator shall be compatible with mechanical loads up to 2 kg and displacements up to 30 mm. */
        require actuator.load.mass <= 2;
        require actuator.load.maxDisplacement >= 30;
    }

    requirement PowerEfficiency : ActuationRequirement {
        subject actuator : ArtificialMuscleActuator;
        doc /* The high-voltage power supply shall operate at an efficiency of at least 85 percent. */
        require actuator.powerSupply.efficiency >= 0.85;
    }

    // ===== Satisfaction =====
    satisfy ContractionCapability by ArtificialMuscleActuator;
    satisfy ForceGeneration by ArtificialMuscleActuator;
    satisfy VoltageProvision by ArtificialMuscleActuator;
    satisfy FeedbackAccuracy by ArtificialMuscleActuator;
    satisfy ActivationResponse by ArtificialMuscleActuator;
    satisfy RelaxationReturn by ArtificialMuscleActuator;
    satisfy SilentOperation by ArtificialMuscleActuator;
    satisfy CycleEndurance by ArtificialMuscleActuator;
    satisfy LoadCompatibility by ArtificialMuscleActuator;
    satisfy PowerEfficiency by ArtificialMuscleActuator;
}
