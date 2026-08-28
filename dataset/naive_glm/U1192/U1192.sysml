package RoboticTechVest {

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====

    value type TorqueValue :> Real {
        :>> unit = 'N·m';
    }

    value type ForceValue :> Real {
        :>> unit = 'N';
    }

    value type AngleValue :> Real {
        :>> unit = 'deg';
    }

    value type PowerValue :> Real {
        :>> unit = 'W';
    }

    value type VoltageValue :> Real {
        :>> unit = 'V';
    }

    value type CurrentValue :> Real {
        :>> unit = 'A';
    }

    value type TimeValue :> Real {
        :>> unit = 'ms';
    }

    value type BatteryCapacityValue :> Real {
        :>> unit = 'Ah';
    }

    value type PercentageValue :> Real {
        :>> unit = '%';
    }

    value type FrequencyValue :> Real {
        :>> unit = 'Hz';
    }

    // ===== Item Types =====

    item def PostureData {
        attribute spinalAngles : AngleValue[5];
        attribute shoulderAngles : AngleValue[2];
        attribute timestamp : TimeValue;
    }

    item def PostureDeviation {
        attribute deviationMagnitude : AngleValue;
        attribute affectedJoint : String;
        attribute severity : PercentageValue;
    }

    item def ActuatorCommand {
        attribute targetActuatorId : String;
        attribute commandedTorque : TorqueValue;
        attribute duration : TimeValue;
    }

    item def HapticSignal {
        attribute moduleId : Integer;
        attribute intensity : PercentageValue;
        attribute pattern : String;
    }

    item def BatteryStatus {
        attribute chargeLevel : PercentageValue;
        attribute voltage : VoltageValue;
        attribute currentDraw : CurrentValue;
        attribute estimatedRemainingTime : TimeValue;
    }

    item def SafetyAlert {
        attribute alertType : String;
        attribute severity : String;
        attribute timestamp : TimeValue;
    }

    // ===== Port Definitions =====

    port def SensorDataOut {
        out postureData : PostureData;
    }

    port def SensorDataIn {
        in postureData : PostureData;
    }

    port def ActuatorCommandOut {
        out command : ActuatorCommand;
    }

    port def ActuatorCommandIn {
        in command : ActuatorCommand;
    }

    port def HapticCommandOut {
        out signal : HapticSignal;
    }

    port def HapticCommandIn {
        in signal : HapticSignal;
    }

    port def PowerOut {
        out voltage : VoltageValue;
        out current : CurrentValue;
    }

    port def PowerIn {
        in voltage : VoltageValue;
        in current : CurrentValue;
    }

    port def BatteryStatusOut {
        out status : BatteryStatus;
    }

    port def BatteryStatusIn {
        in status : BatteryStatus;
    }

    port def SafetyAlertOut {
        out alert : SafetyAlert;
    }

    port def SafetyAlertIn {
        in alert : SafetyAlert;
    }

    // ===== Sensor Definitions =====

    part def PostureSensor {
        attribute sensorId : String;
        attribute location : String;
        attribute samplingRate : FrequencyValue;
        port sensorOut : SensorDataOut;
        attribute measuredAngle : AngleValue;

        private action sensePosture {
            in sensorLocation : String;
            out angle : AngleValue;
        }
    }

    part def SpinalSensor :> PostureSensor {
        attribute spinalSegment : String;
    }

    part def ShoulderSensor :> PostureSensor {
        attribute shoulderSide : String;
    }

    // ===== Actuator Definitions =====

    part def ExoskeletonActuator {
        attribute actuatorId : String;
        attribute location : String;
        attribute maxTorque : TorqueValue;
        attribute maxForce : ForceValue;
        attribute currentTorque : TorqueValue;
        port commandIn : ActuatorCommandIn;
        port safetyAlertOut : SafetyAlertOut;

        private action applyTorque {
            in commandedTorque : TorqueValue;
            in maxAllowedTorque : TorqueValue;
            out appliedTorque : TorqueValue;
        }

        assert constraint maxTorqueLimit {
            currentTorque <= maxTorque
        }
    }

    part def SpinalActuator :> ExoskeletonActuator {
        attribute spinalSegment : String;
    }

    part def ShoulderActuator :> ExoskeletonActuator {
        attribute shoulderSide : String;
    }

    part def HipActuator :> ExoskeletonActuator {
        attribute hipSide : String;
    }

    // ===== Haptic Feedback Module =====

    part def HapticFeedbackModule {
        attribute moduleId : Integer;
        attribute location : String;
        attribute maxIntensity : PercentageValue;
        port commandIn : HapticCommandIn;

        private action generateVibration {
            in intensity : PercentageValue;
            in pattern : String;
        }
    }

    // ===== Battery Module =====

    part def BatteryModule {
        attribute capacity : BatteryCapacityValue;
        attribute nominalVoltage : VoltageValue;
        attribute chargeLevel : PercentageValue;
        attribute minOperatingTime : TimeValue;
        port powerOut : PowerOut;
        port statusOut : BatteryStatusOut;

        private action discharge {
            in currentDraw : CurrentValue;
            out remainingCharge : PercentageValue;
        }

        private action recharge {
            in chargeVoltage : VoltageValue;
            in chargeCurrent : CurrentValue;
            out chargeLevel : PercentageValue;
        }

        assert constraint minimumOperatingTime {
            minOperatingTime >= 48000
        }
    }

    // ===== Central Control Unit =====

    part def CentralControlUnit {
        attribute processingFrequency : FrequencyValue;
        attribute maxResponseTime : TimeValue;
        port sensorDataIn : SensorDataIn;
        port actuatorCommandOut : ActuatorCommandOut;
        port hapticCommandOut : HapticCommandOut;
        port batteryStatusIn : BatteryStatusIn;
        port safetyAlertIn : SafetyAlertIn;

        attribute currentPostureData : PostureData;
        attribute detectedDeviations : PostureDeviation[*];
        attribute safetyLimitTorque : TorqueValue;

        private action analyzePosture {
            in data : PostureData;
            out deviations : PostureDeviation[*];
        }

        private action generateActuatorCommands {
            in deviations : PostureDeviation[*];
            in safetyLimit : TorqueValue;
            out commands : ActuatorCommand[*];
        }

        private action generateHapticSignals {
            in deviations : PostureDeviation[*];
            out signals : HapticSignal[*];
        }

        assert constraint responseTimeLimit {
            maxResponseTime <= 100
        }
    }

    // ===== Sensor Array =====

    part def SensorArray {
        part spinalSensors : SpinalSensor[5] {
            :>> spinalSegment = {"Cervical", "UpperThoracic", "MidThoracic", "LowerThoracic", "Lumbar"};
            :>> samplingRate = 100;
        }
        part shoulderSensors : ShoulderSensor[2] {
            :>> shoulderSide = {"Left", "Right"};
            :>> samplingRate = 100;
        }
        port dataOut : SensorDataOut;
    }

    // ===== Actuator Array =====

    part def ActuatorArray {
        part spinalActuators : SpinalActuator[5] {
            :>> spinalSegment = {"Cervical", "UpperThoracic", "MidThoracic", "LowerThoracic", "Lumbar"};
            :>> maxTorque = 15;
            :>> maxForce = 50;
        }
        part shoulderActuators : ShoulderActuator[2] {
            :>> shoulderSide = {"Left", "Right"};
            :>> maxTorque = 10;
            :>> maxForce = 35;
        }
        part hipActuators : HipActuator[2] {
            :>> hipSide = {"Left", "Right"};
            :>> maxTorque = 20;
            :>> maxForce = 70;
        }
        port commandIn : ActuatorCommandIn;
        port safetyAlertOut : SafetyAlertOut;
    }

    // ===== Haptic Feedback Array =====

    part def HapticFeedbackArray {
        part modules : HapticFeedbackModule[6] {
            :>> location = {"UpperSpine", "LowerSpine", "LeftShoulder", "RightShoulder", "LeftHip", "RightHip"};
            :>> maxIntensity = 100;
        }
        port commandIn : HapticCommandIn;
    }

    // ===== Vest System =====

    part def RoboticTechVestSystem {
        attribute systemId : String;
        attribute firmwareVersion : String;

        part sensorArray : SensorArray;
        part controlUnit : CentralControlUnit {
            :>> processingFrequency = 200;
            :>> maxResponseTime = 100;
            :>> safetyLimitTorque = 15;
        }
        part actuatorArray : ActuatorArray;
        part hapticArray : HapticFeedbackArray;
        part battery : BatteryModule {
            :>> capacity = 10;
            :>> nominalVoltage = 12;
            :>> minOperatingTime = 48000;
        }

        // Connections
        connection sensorDataFlow connect sensorArray.dataOut to controlUnit.sensorDataIn;
        connection actuatorCommandFlow connect controlUnit.actuatorCommandOut to actuatorArray.commandIn;
        connection hapticCommandFlow connect controlUnit.hapticCommandOut to hapticArray.commandIn;
        connection batteryStatusFlow connect battery.statusOut to controlUnit.batteryStatusIn;
        connection safetyAlertFlow connect actuatorArray.safetyAlertOut to controlUnit.safetyAlertIn;

        // Power distribution
        connection powerToControlUnit connect battery.powerOut to controlUnit.powerIn;
        connection powerToActuators connect battery.powerOut to actuatorArray.powerIn;
        connection powerToSensors connect battery.powerOut to sensorArray.powerIn;
        connection powerToHaptics connect battery.powerOut to hapticArray.powerIn;

        // State Machine
        state def VestStateMachine {
            entry action {
                log("Vest system initialized.");
            }

            state standby {
                entry action {
                    log("Entering standby mode.");
                }
                do action {
                    send batteryStatusRequest();
                }
                transition standby_to_active
                    when battery.chargeLevel > 20
                    to activeMonitoring;
            }

            state activeMonitoring {
                entry action {
                    log("Entering active monitoring and analysis mode.");
                }
                do action {
                    sensorArray.collectPostureData();
                    controlUnit.analyzePosture(currentPostureData);
                }
                transition active_to_support
                    when controlUnit.detectedDeviations->size() > 0
                    to supportMode;
                transition active_to_lowPower
                    when battery.chargeLevel <= 20
                    to lowPowerMode;
                transition active_to_standby
                    when userDeactivation == true
                    to standby;
            }

            state supportMode {
                entry action {
                    log("Entering support/assisting mode.");
                }
                do action {
                    controlUnit.generateActuatorCommands(detectedDeviations, safetyLimitTorque);
                    controlUnit.generateHapticSignals(detectedDeviations);
                    actuatorArray.applyTorque();
                    hapticArray.generateVibration();
                }
                transition support_to_active
                    when controlUnit.detectedDeviations->size() == 0
                    to activeMonitoring;
                transition support_to_lowPower
                    when battery.chargeLevel <= 20
                    to lowPowerMode;
            }

            state lowPowerMode {
                entry action {
                    log("Entering low-power mode to conserve energy.");
                }
                do action {
                    reduceSamplingRate();
                    disableNonCriticalModules();
                }
                transition lowPower_to_standby
                    when battery.chargeLevel > 80
                    to standby;
            }
        }

        // Main behavior
        action def VestOperation {
            in vestSystem : RoboticTechVestSystem;
            out operationalStatus : String;

            // Initialize
            action initialize {
                out status : String = "Initialized";
            }

            // Monitor loop
            action monitorPosture {
                in sensorData : PostureData;
                out deviations : PostureDeviation[*];
            }

            // Decision
            action evaluateDeviations {
                in deviations : PostureDeviation[*];
                out requiresSupport : Boolean;
            }

            // Support
            action provideSupport {
                in deviations : PostureDeviation[*];
                in safetyLimit : TorqueValue;
                out actuatorCommands : ActuatorCommand[*];
                out hapticSignals : HapticSignal[*];
            }

            // Safety check
            action safetyCheck {
                in commandedTorque : TorqueValue;
                in maxTorque : TorqueValue;
                out safe : Boolean;
            }

            flow initialize.status -> monitorPosture.sensorData;
            flow monitorPosture.deviations -> evaluateDeviations.deviations;
            flow evaluateDeviations.requiresSupport -> provideSupport.deviations;
            flow provideSupport.actuatorCommands -> safetyCheck.commandedTorque;
        }
    }

    // ===== Requirements =====

    requirement def PosturalSupportRequirement {
        subject vest : RoboticTechVestSystem;
        objective {
            doc /* The vest shall provide real-time postural support to reduce physical strain on the user. */
        }
    }

    requirement def SensorArrayRequirement {
        subject sensorArray : SensorArray;
        objective {
            doc /* The sensor array shall include five spinal sensors and two shoulder sensors to continuously monitor posture. */
        }
        assume {
            sensorArray.spinalSensors->size() == 5;
            sensorArray.shoulderSensors->size() == 2;
        }
    }

    requirement def ActuatorArrayRequirement {
        subject actuatorArray : ActuatorArray;
        objective {
            doc /* The actuator array shall include five spinal actuators, two shoulder actuators, and two hip actuators. */
        }
        assume {
            actuatorArray.spinalActuators->size() == 5;
            actuatorArray.shoulderActuators->size() == 2;
            actuatorArray.hipActuators->size() == 2;
        }
    }

    requirement def HapticFeedbackRequirement {
        subject hapticArray : HapticFeedbackArray;
        objective {
            doc /* The vest shall include six haptic feedback modules to alert the user of postural changes. */
        }
        assume {
            hapticArray.modules->size() == 6;
        }
    }

    requirement def BatteryLifeRequirement {
        subject battery : BatteryModule;
        objective {
            doc /* The battery shall support at least 8 hours of continuous operation. */
        }
        assume {
            battery.minOperatingTime >= 48000;
        }
    }

    requirement def ResponseTimeRequirement {
        subject controlUnit : CentralControlUnit;
        objective {
            doc /* The system shall respond to postural deviation within 100 milliseconds from detection to support. */
        }
        assume {
            controlUnit.maxResponseTime <= 100;
        }
    }

    requirement def SafetyLimitRequirement {
        subject actuatorArray : ActuatorArray;
        objective {
            doc /* The system shall enforce safety limits on actuator force to prevent injury to the user. */
        }
        assume {
            actuatorArray.spinalActuators.maxTorque <= 15;
            actuatorArray.shoulderActuators.maxTorque <= 10;
            actuatorArray.hipActuators.maxTorque <= 20;
        }
    }

    requirement def OperatingStatesRequirement {
        subject vest : RoboticTechVestSystem;
        objective {
            doc /* The vest shall operate through standby, active monitoring, support, and low-power modes. */
        }
    }

    requirement def AdaptiveControlRequirement {
        subject controlUnit : CentralControlUnit;
        objective {
            doc /* The central control unit shall run an adaptive posture control algorithm to process sensor data and generate actuator commands. */
        }
    }

    // ===== Requirement Satisfaction =====

    requirement posturalSupport : PosturalSupportRequirement {
        subject vest : RoboticTechVestSystem;
    }

    requirement sensorArrayReq : SensorArrayRequirement {
        subject sensorArray : SensorArray;
    }

    requirement actuatorArrayReq : ActuatorArrayRequirement {
        subject actuatorArray : ActuatorArray;
    }

    requirement hapticFeedbackReq : HapticFeedbackRequirement {
        subject hapticArray : HapticFeedbackArray;
    }

    requirement batteryLifeReq : BatteryLifeRequirement {
        subject battery : BatteryModule;
    }

    requirement responseTimeReq : ResponseTimeRequirement {
        subject controlUnit : CentralControlUnit;
    }

    requirement safetyLimitReq : SafetyLimitRequirement {
        subject actuatorArray : ActuatorArray;
    }

    requirement operatingStatesReq : OperatingStatesRequirement {
        subject vest : RoboticTechVestSystem;
    }

    requirement adaptiveControlReq : AdaptiveControlRequirement {
        subject controlUnit : CentralControlUnit;
    }

    // ===== Verification =====

    verification def VerifySensorCount {
        subject sensorArray : SensorArray;
        objective {
            doc /* Verify that the sensor array contains exactly 5 spinal and 2 shoulder sensors. */
        }
        return sensorArray.spinalSensors->size() == 5 and sensorArray.shoulderSensors->size() == 2;
    }

    verification def VerifyActuatorCount {
        subject actuatorArray : ActuatorArray;
        objective {
            doc /* Verify that the actuator array contains exactly 5 spinal, 2 shoulder, and 2 hip actuators. */
        }
        return actuatorArray.spinalActuators->size() == 5 and
               actuatorArray.shoulderActuators->size() == 2 and
               actuatorArray.hipActuators->size() == 2;
    }

    verification def VerifyHapticCount {
        subject hapticArray : HapticFeedbackArray;
        objective {
            doc /* Verify that the haptic feedback array contains exactly 6 modules. */
        }
        return hapticArray.modules->size() == 6;
    }

    verification def VerifyBatteryLife {
        subject battery : BatteryModule;
        objective {
            doc /* Verify that the battery supports at least 8 hours of operation. */
        }
        return battery.minOperatingTime >= 48000;
    }

    verification def VerifyResponseTime {
        subject controlUnit : CentralControlUnit;
        objective {
            doc /* Verify that the response time is under 100 milliseconds. */
        }
        return controlUnit.maxResponseTime <= 100;
    }

    verification def VerifySafetyLimits {
        subject actuatorArray : ActuatorArray;
        objective {
            doc /* Verify that all actuators enforce safety torque limits. */
        }
        return actuatorArray.spinalActuators.maxTorque <= 15 and
               actuatorArray.shoulderActuators.maxTorque <= 10 and
               actuatorArray.hipActuators.maxTorque <= 20;
    }

    // ===== Package-level configuration =====

    part vestSystemInstance : RoboticTechVestSystem {
        :>> systemId = "RTV-001";
        :>> firmwareVersion = "2.1.0";

        :>> sensorArray.spinalSensors.samplingRate = 100;
        :>> sensorArray.shoulderSensors.samplingRate = 100;
        :>> controlUnit.processingFrequency = 200;
        :>> controlUnit.maxResponseTime = 80;
        :>> controlUnit.safetyLimitTorque = 12;
        :>> battery.capacity = 10;
        :>> battery.nominalVoltage = 12;
        :>> battery.minOperatingTime = 50000;
    }

    satisfy posturalSupport by vestSystemInstance;
    satisfy sensorArrayReq by vestSystemInstance.sensorArray;
    satisfy actuatorArrayReq by vestSystemInstance.actuatorArray;
    satisfy hapticFeedbackReq by vestSystemInstance.hapticArray;
    satisfy batteryLifeReq by vestSystemInstance.battery;
    satisfy responseTimeReq by vestSystemInstance.controlUnit;
    satisfy safetyLimitReq by vestSystemInstance.actuatorArray;
    satisfy operatingStatesReq by vestSystemInstance;
    satisfy adaptiveControlReq by vestSystemInstance.controlUnit;

}
