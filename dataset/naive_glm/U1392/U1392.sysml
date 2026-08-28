package CentrifugalFanSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ---- Value types ----
    value type AngularVelocityValue > Real { unit "rev/min"; }
    value type VolumetricFlowRateValue > Real { unit "m3/s"; }
    value type PressureValue > Real { unit "Pa"; }
    value type VibrationValue > Real { unit "mm/s"; }
    value type TorqueValue > Real { unit "N.m"; }
    value type PowerValue > Real { unit "W"; }
    value type FrequencyValue > Real { unit "Hz"; }
    value type VoltageValue > Real { unit "V"; }
    value type CurrentValue > Real { unit "A"; }
    value type LengthValue > Real { unit "m"; }
    value type AreaValue > Real { unit "m2"; }
    value type ForceValue > Real { unit "N"; }
    value type TemperatureValue > Real { unit "degC"; }

    // ---- Items ----
    item def Air;
    item def ElectricalPower;
    item def CommandSignal {
        attribute value : String;
    }
    item def FeedbackSignal {
        attribute speed : AngularVelocityValue;
        attribute vibration : VibrationValue;
        attribute status : String;
    }

    // ---- Ports ----
    port def AirInletPort {
        in item airIn : Air;
    }
    port def AirOutletPort {
        out item airOut : Air;
    }
    port def ElectricalPowerPort {
        in item power : ElectricalPower;
    }
    port def CommandPort {
        in attribute command : String;
    }
    port def FeedbackPort {
        out attribute speed : AngularVelocityValue;
        out attribute vibration : VibrationValue;
        out attribute status : String;
    }
    port def MechanicalPowerPort {
        out attribute torque : TorqueValue;
        out attribute speed : AngularVelocityValue;
    }

    // ---- Parts ----
    part def ElectricMotor {
        port in powerIn : ElectricalPowerPort;
        port out mechanicalOut : MechanicalPowerPort;
        port out speedFeedback : FeedbackPort;
        attribute ratedPower : PowerValue = 15000.0;
        attribute ratedSpeed : AngularVelocityValue = 1800.0;
        attribute inputFrequency : FrequencyValue;
        attribute inputVoltage : VoltageValue = 400.0;
        attribute outputTorque : TorqueValue;
        attribute outputSpeed : AngularVelocityValue;

        action def generateTorque {
            in power : ElectricalPower;
            in frequency : FrequencyValue;
            out torque : TorqueValue;
            out speed : AngularVelocityValue;
        }
    }

    part def DriveShaft {
        port in inputMechanical : MechanicalPowerPort;
        port out outputMechanical : MechanicalPowerPort;
        attribute length : LengthValue = 0.5;
        attribute diameter : LengthValue = 0.04;
        attribute material : String = "Steel";
        attribute transmittedTorque : TorqueValue;
        attribute rotationalSpeed : AngularVelocityValue;
    }

    part def BearingAssembly {
        port in shaftInterface : MechanicalPowerPort;
        port out vibrationFeedback : FeedbackPort;
        attribute bearingType : String = "Roller";
        attribute maxLoad : ForceValue = 5000.0;
        attribute vibrationLevel : VibrationValue;
        attribute temperature : TemperatureValue;
    }

    part def Impeller {
        port in driveInput : MechanicalPowerPort;
        attribute bladeCount : Integer = 8;
        attribute diameter : LengthValue = 0.6;
        attribute rotationalSpeed : AngularVelocityValue;
        attribute airflowRate : VolumetricFlowRateValue;

        action def accelerateAir {
            in air : Air;
            in speed : AngularVelocityValue;
            out acceleratedAir : Air;
        }
    }

    part def ScrollHousing {
        port in inlet : AirInletPort;
        port out outlet : AirOutletPort;
        attribute inletDiameter : LengthValue = 0.3;
        attribute outletArea : AreaValue = 0.05;
        attribute staticPressure : PressureValue;
        attribute outletFlow : VolumetricFlowRateValue;

        action def convertKineticToPressure {
            in highSpeedAir : Air;
            out pressurizedAir : Air;
        }
    }

    part def ControlModule {
        port in commandIn : CommandPort;
        port in powerIn : ElectricalPowerPort;
        port out powerOut : ElectricalPowerPort;
        port in feedbackIn : FeedbackPort;
        port out feedbackOut : FeedbackPort;
        attribute speedCommandRangeMin : AngularVelocityValue = 0.0;
        attribute speedCommandRangeMax : AngularVelocityValue = 1800.0;
        attribute speedCommand : AngularVelocityValue;
        attribute currentSpeed : AngularVelocityValue;
        attribute vibrationLevel : VibrationValue;
        attribute vibrationThreshold : VibrationValue = 7.1;
        attribute outputFrequency : FrequencyValue;
        attribute status : String;

        action def regulateSpeed {
            in command : String;
            in currentSpeed : AngularVelocityValue;
            out frequency : FrequencyValue;
            out speedCommand : AngularVelocityValue;
        }

        action def monitorPerformance {
            in speed : AngularVelocityValue;
            in vibration : VibrationValue;
            out feedback : FeedbackSignal;
        }

        state machine controlStates {
            attribute activeState : String;

            state idle {
                entry { activeState = "idle"; status = "idle"; }
                transition to startup
                    when commandIn.command == "start";
            }

            state startup {
                entry { activeState = "startup"; status = "starting"; }
                do action regulateAction : regulateSpeed;
                transition to normalOperation
                    when currentSpeed >= speedCommandRangeMax * 0.95;
                transition to faultMode
                    when vibrationLevel > vibrationThreshold;
            }

            state normalOperation {
                entry { activeState = "normalOperation"; status = "running"; }
                do action monitorAction : monitorPerformance;
                transition to shutdown
                    when commandIn.command == "stop";
                transition to faultMode
                    when vibrationLevel > vibrationThreshold;
            }

            state shutdown {
                entry { activeState = "shutdown"; status = "stopping"; }
                do action regulateAction : regulateSpeed;
                transition to idle
                    when currentSpeed <= 0.0;
            }

            state faultMode {
                entry { activeState = "faultMode"; status = "fault"; }
                do action monitorAction : monitorPerformance;
                transition to shutdown;
            }
        }
    }

    part def CentrifugalFanSystem {
        port in airIntake : AirInletPort;
        port out airDischarge : AirOutletPort;
        port in externalPower : ElectricalPowerPort;
        port in commandPort : CommandPort;
        port out systemFeedback : FeedbackPort;

        part controlModule : ControlModule {
            port in commandIn : CommandPort;
            port in powerIn : ElectricalPowerPort;
            port out powerOut : ElectricalPowerPort;
            port in feedbackIn : FeedbackPort;
            port out feedbackOut : FeedbackPort;
        }
        part motor : ElectricMotor {
            port in powerIn : ElectricalPowerPort;
            port out mechanicalOut : MechanicalPowerPort;
            port out speedFeedback : FeedbackPort;
        }
        part driveShaft : DriveShaft {
            port in inputMechanical : MechanicalPowerPort;
            port out outputMechanical : MechanicalPowerPort;
        }
        part bearingAssembly : BearingAssembly {
            port in shaftInterface : MechanicalPowerPort;
            port out vibrationFeedback : FeedbackPort;
        }
        part impeller : Impeller {
            port in driveInput : MechanicalPowerPort;
        }
        part scrollHousing : ScrollHousing {
            port in inlet : AirInletPort;
            port out outlet : AirOutletPort;
        }

        attribute outletFlow : VolumetricFlowRateValue;
        attribute outletPressure : PressureValue;
        attribute vibrationLevel : VibrationValue;
        attribute speedCommand : AngularVelocityValue;

        // Power distribution
        connection externalPowerToControl connect externalPower to controlModule.powerIn;
        connection controlToMotor connect controlModule.powerOut to motor.powerIn;

        // Mechanical power transmission
        connection motorToShaft connect motor.mechanicalOut to driveShaft.inputMechanical;
        connection shaftToBearing connect driveShaft.outputMechanical to bearingAssembly.shaftInterface;
        connection shaftToImpeller connect driveShaft.outputMechanical to impeller.driveInput;

        // Air flow path
        connection intakeToHousing connect airIntake to scrollHousing.inlet;
        connection dischargeFromHousing connect scrollHousing.outlet to airDischarge;

        // Feedback signals
        connection motorSpeedFeedback connect motor.speedFeedback to controlModule.feedbackIn;
        connection bearingVibrationFeedback connect bearingAssembly.vibrationFeedback to controlModule.feedbackIn;
        connection controlFeedbackOut connect controlModule.feedbackOut to systemFeedback;

        // Command
        connection commandToControl connect commandPort to controlModule.commandIn;

        // Bindings for monitoring and control
        binding controlModule.currentSpeed = motor.outputSpeed;
        binding controlModule.vibrationLevel = bearingAssembly.vibrationLevel;
        binding outletFlow = scrollHousing.outletFlow;
        binding outletPressure = scrollHousing.staticPressure;
        binding vibrationLevel = bearingAssembly.vibrationLevel;
        binding speedCommand = controlModule.speedCommand;

        // Requirement satisfaction
        satisfy fanPerformanceReq by self;
        satisfy safetyReq by self;
        satisfy controllabilityReq by self;
    }

    // ---- Requirements ----
    requirement def FanPerformanceRequirement {
        subject fan : CentrifugalFanSystem;
        doc /* The fan shall deliver air at specified flow and pressure. */
        attribute minFlow : VolumetricFlowRateValue = 10.0;
        attribute minPressure : PressureValue = 1500.0;
        require fan.outletFlow >= minFlow;
        require fan.outletPressure >= minPressure;
    }

    requirement def SafetyRequirement {
        subject fan : CentrifugalFanSystem;
        doc /* The fan shall shut down safely under fault conditions. */
        attribute maxVibration : VibrationValue = 7.1;
        require fan.vibrationLevel <= maxVibration;
    }

    requirement def ControllabilityRequirement {
        subject fan : CentrifugalFanSystem;
        doc /* The fan speed shall be adjustable via external command. */
        attribute minSpeed : AngularVelocityValue = 0.0;
        attribute maxSpeed : AngularVelocityValue = 1800.0;
        require fan.speedCommand >= minSpeed;
        require fan.speedCommand <= maxSpeed;
    }

    requirement fanPerformanceReq : FanPerformanceRequirement {
        subject fan : CentrifugalFanSystem;
    }

    requirement safetyReq : SafetyRequirement {
        subject fan : CentrifugalFanSystem;
    }

    requirement controllabilityReq : ControllabilityRequirement {
        subject fan : CentrifugalFanSystem;
    }
}
