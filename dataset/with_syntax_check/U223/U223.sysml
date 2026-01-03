package 'FeedingTubeSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def NutritionalFormula;
    attribute def PatientIdentifier;
    attribute def AlarmCode;

    enum def SystemMode {
        enum standby;
        enum priming;
        enum delivering;
        enum paused;
        enum alarmed;
        enum completed;
    }

    enum def AlarmType {
        enum occlusion;
        enum airInLine;
        enum emptyReservoir;
        enum flowDeviation;
    }

    port def FormulaPort {
        attribute flowRate : VolumeFlowRateValue;
    }

    port def ControlPort;
    port def SensorPort;

    item def NutritionalFormulaItem :> NutritionalFormula {
        attribute caloriesPerML : Real;
        attribute proteinContent : Real;
    }

    part def FormulaReservoir {
        port outlet : FormulaPort;
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute formulaType : NutritionalFormula;
    }

    part def PumpMechanism {
        port inlet : FormulaPort;
        port outlet : FormulaPort;
        port controlInterface : ControlPort;
        attribute commandedFlowRate : VolumeFlowRateValue;
        attribute actualFlowRate : VolumeFlowRateValue;
        attribute isPumping : Boolean;
        attribute motorSpeed : Real;
    }

    part def DeliveryTubing {
        port input : FormulaPort;
        port output : FormulaPort;
        attribute length : LengthValue;
        attribute innerDiameter : LengthValue;
        attribute pressure : PressureValue;
    }

    part def FlowRateSensor {
        port sensorPort : SensorPort;
        attribute measuredFlowRate : VolumeFlowRateValue;
        attribute calibrationFactor : Real;
    }

    part def PressureSensor {
        port sensorPort : SensorPort;
        attribute measuredPressure : PressureValue;
        attribute alarmThreshold : PressureValue;
    }

    part def AirDetector {
        port sensorPort : SensorPort;
        attribute airDetected : Boolean;
    }

    part def ControlModule {
        port controlPort : ControlPort;
        attribute currentMode : SystemMode;
        attribute prescribedFlowRate : VolumeFlowRateValue;
        attribute prescribedVolume : VolumeValue;
        attribute deliveredVolume : VolumeValue;
        attribute activeAlarms : AlarmType[0..*];
    }

    part def UserInterface {
        attribute displayedMode : SystemMode;
        attribute displayedFlowRate : VolumeFlowRateValue;
        attribute displayedVolume : VolumeValue;
    }

    part def PatientConnection {
        port inlet : FormulaPort;
        attribute patientID : PatientIdentifier;
        attribute connectionSecure : Boolean;
    }

    action def MonitorFlowRate {
        in targetFlowRate : VolumeFlowRateValue;
        in measuredFlowRate : VolumeFlowRateValue;
        out withinTolerance : Boolean;
        out deviationPercent : Real;
    }

    action def DetectOcclusion {
        in measuredPressure : PressureValue;
        in pressureThreshold : PressureValue;
        out occlusionDetected : Boolean;
    }

    action def CalculateDeliveredVolume {
        in flowRate : VolumeFlowRateValue;
        in timeInterval : TimeValue;
        in previousVolume : VolumeValue;
        out newVolume : VolumeValue;
    }

    action def AdjustPumpSpeed {
        in targetFlowRate : VolumeFlowRateValue;
        in currentFlowRate : VolumeFlowRateValue;
        out newMotorSpeed : Real;
    }

    action def DeliverNutrition {
        in prescribedRate : VolumeFlowRateValue;
        in prescribedVolume : VolumeValue;
        out totalDelivered : VolumeValue;
        out deliveryComplete : Boolean;

        first start;
        then merge monitoringLoop;

        action monitoringLoop {
            action checkSensors {
                action monitorFlow : MonitorFlowRate {
                    in targetFlowRate = prescribedRate;
                    in measuredFlowRate = prescribedRate;
                    out withinTolerance;
                    out deviationPercent;
                }
                action checkPressure : DetectOcclusion {
                    in measuredPressure = 0.0 [Pa];
                    in pressureThreshold = 50000.0 [Pa];
                    out occlusionDetected;
                }
            }
            then decide;
                if checkSensors.checkPressure.occlusionDetected then handleOcclusion;
                if checkSensors.monitorFlow.withinTolerance then continueDelivery;

            action handleOcclusion {
                assign deliveryComplete := false;
            }
            then done;

            action adjustFlow : AdjustPumpSpeed {
                in targetFlowRate = prescribedRate;
                in currentFlowRate = prescribedRate;
                out newMotorSpeed;
            }
            then continueDelivery;

            action continueDelivery {
                action updateVolume : CalculateDeliveredVolume {
                    in flowRate = prescribedRate;
                    in timeInterval = 1.0 [s];
                    in previousVolume = totalDelivered;
                    out newVolume;
                }
                assign totalDelivered := updateVolume.newVolume;
            }
            then decide;
                if totalDelivered >= prescribedVolume then completeDelivery;
                if totalDelivered < prescribedVolume then monitoringLoop;

            action completeDelivery {
                assign deliveryComplete := true;
            }
            then done;
        }
    }

    part def FeedingTubeSystem {
        doc /*
         * A medical feeding tube system designed to deliver prescribed nutritional 
         * formula directly into a patient's digestive system. The system provides 
         * controlled, continuous delivery of liquid nutrition with precise flow rate 
         * control, safety monitoring, and alarm capabilities to ensure patient safety 
         * and proper nutritional support when oral intake is not possible or sufficient.
         */

        part reservoir : FormulaReservoir {
            attribute :>> capacity = 1000.0 [mL];
            attribute :>> currentLevel = 1000.0 [mL];
        }

        part pump : PumpMechanism {
            attribute :>> commandedFlowRate = 75.0 [mL/h];
            attribute :>> actualFlowRate = 0.0 [mL/h];
            attribute :>> isPumping = false;
            attribute :>> motorSpeed = 0.0;
        }

        part tubing : DeliveryTubing {
            attribute :>> length = 1500.0 [mm];
            attribute :>> innerDiameter = 3.5 [mm];
            attribute :>> pressure = 0.0 [Pa];
        }

        part flowSensor : FlowRateSensor {
            attribute :>> measuredFlowRate = 0.0 [mL/h];
            attribute :>> calibrationFactor = 1.0;
        }

        part pressureSensor : PressureSensor {
            attribute :>> measuredPressure = 0.0 [Pa];
            attribute :>> alarmThreshold = 50000.0 [Pa];
        }

        part airDetector : AirDetector {
            attribute :>> airDetected = false;
        }

        part controller : ControlModule {
            attribute :>> currentMode = SystemMode::standby;
            attribute :>> prescribedFlowRate = 75.0 [mL/h];
            attribute :>> prescribedVolume = 500.0 [mL];
            attribute :>> deliveredVolume = 0.0 [mL];
        }

        part userInterface : UserInterface {
            attribute :>> displayedMode = SystemMode::standby;
            attribute :>> displayedFlowRate = 0.0 [mL/h];
            attribute :>> displayedVolume = 0.0 [mL];
        }

        part patientConnection : PatientConnection {
            attribute :>> connectionSecure = true;
        }

        connect reservoir.outlet to pump.inlet;
        connect pump.outlet to tubing.input;
        connect tubing.output to patientConnection.inlet;

        item flow nutritionalFormula : NutritionalFormulaItem 
            from reservoir.outlet to patientConnection.inlet;

        perform action deliveryOperation : DeliverNutrition {
            in prescribedRate = controller.prescribedFlowRate;
            in prescribedVolume = controller.prescribedVolume;
            out totalDelivered;
            out deliveryComplete;
        }

        state machine SystemOperation {
            initial state standby;

            state standby {
                entry assign controller.currentMode := SystemMode::standby;
                accept startDelivery;
                transition to priming when startDelivery;
            }

            state priming {
                entry assign controller.currentMode := SystemMode::priming;
                do assign pump.isPumping := true;
                accept primingComplete;
                transition to delivering when primingComplete;
            }

            state delivering {
                entry assign controller.currentMode := SystemMode::delivering;
                do assign pump.isPumping := true;
                accept pauseCommand;
                accept alarmCondition;
                transition to paused when pauseCommand;
                transition to alarmed when alarmCondition;
                transition to completed when controller.deliveredVolume >= controller.prescribedVolume;
            }

            state paused {
                entry assign controller.currentMode := SystemMode::paused;
                entry assign pump.isPumping := false;
                accept resumeCommand;
                accept stopCommand;
                transition to delivering when resumeCommand;
                transition to standby when stopCommand;
            }

            state alarmed {
                entry assign controller.currentMode := SystemMode::alarmed;
                entry assign pump.isPumping := false;
                accept alarmReset;
                transition to standby when alarmReset;
            }

            state completed {
                entry assign controller.currentMode := SystemMode::completed;
                entry assign pump.isPumping := false;
                accept acknowledgeCompletion;
                transition to standby when acknowledgeCompletion;
            }
        }
    }

    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;

    requirement <'REQ-FT-001'> primaryFunction : FunctionalRequirement {
        doc /*
         * The feeding tube system shall deliver prescribed nutritional formula 
         * to the patient at a controlled flow rate to provide essential nutrition 
         * when oral intake is not feasible.
         */
        subject feedingSystem : FeedingTubeSystem;
    }

    requirement <'REQ-FT-002'> flowRateControl : PerformanceRequirement {
        doc /*
         * The system shall maintain the delivered flow rate within +/- 10% 
         * of the prescribed flow rate during normal operation.
         */
        subject feedingSystem : FeedingTubeSystem;
        require constraint {
            abs(feedingSystem.flowSensor.measuredFlowRate - feedingSystem.controller.prescribedFlowRate) 
                <= 0.1 * feedingSystem.controller.prescribedFlowRate
        }
    }

    requirement <'REQ-FT-003'> occlusionDetection : SafetyRequirement {
        doc /*
         * The system shall detect tube occlusion by monitoring delivery pressure 
         * and shall trigger an alarm and stop delivery when pressure exceeds 
         * the safety threshold.
         */
        subject feedingSystem : FeedingTubeSystem;
        require constraint {
            feedingSystem.tubing.pressure > feedingSystem.pressureSensor.alarmThreshold 
                implies feedingSystem.controller.currentMode == SystemMode::alarmed
        }
    }

    requirement <'REQ-FT-004'> airDetection : SafetyRequirement {
        doc /*
         * The system shall detect air in the delivery line and shall trigger 
         * an alarm and stop delivery to prevent air embolism.
         */
        subject feedingSystem : FeedingTubeSystem;
        require constraint {
            feedingSystem.airDetector.airDetected 
                implies feedingSystem.controller.currentMode == SystemMode::alarmed
        }
    }

    requirement <'REQ-FT-005'> volumeAccuracy : PerformanceRequirement {
        doc /*
         * The system shall deliver the prescribed total volume with an accuracy 
         * of +/- 5% to ensure proper nutritional intake.
         */
        subject feedingSystem : FeedingTubeSystem;
        require constraint {
            abs(feedingSystem.controller.deliveredVolume - feedingSystem.controller.prescribedVolume) 
                <= 0.05 * feedingSystem.controller.prescribedVolume
        }
    }

    part feedingTubeSystem : FeedingTubeSystem;

    satisfy primaryFunction by feedingTubeSystem;
    satisfy flowRateControl by feedingTubeSystem.deliveryOperation;
    satisfy occlusionDetection by feedingTubeSystem.SystemOperation;
    satisfy airDetection by feedingTubeSystem.airDetector;
    satisfy volumeAccuracy by feedingTubeSystem.deliveryOperation;
}
