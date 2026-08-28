package BionicProsthesis {
    import ScalarValues::*;

    // ===== Units =====
    unit V;
    unit A;
    unit W;
    unit N_m;
    unit N;
    unit deg;
    unit rad_s;
    unit uV;
    unit Hz;
    unit degC;
    unit pct;
    unit s;
    unit W_h;

    // ===== Value Types =====
    value def Voltage :> Real;
    value def Current :> Real;
    value def Power :> Real;
    value def Torque :> Real;
    value def Force :> Real;
    value def Angle :> Real;
    value def AngularVelocity :> Real;
    value def BioelectricPotential :> Real;
    value def Frequency :> Real;
    value def Temperature :> Real;
    value def BatteryLevel :> Real;
    value def TimeDuration :> Real;
    value def Confidence :> Real;

    // ===== Enumerations =====
    enum def MotorIntent {
        none;
        grasp;
        release;
        flexJoint;
        extendJoint;
        rotate;
        holdPosition;
    }

    enum def OperationalState {
        startup;
        standby;
        active;
        failSafe;
    }

    enum def SafetyStatus {
        nominal;
        warning;
        critical;
    }

    // ===== Item Definitions =====
    item def BioelectricSignal {
        attribute amplitude : BioelectricPotential;
        attribute frequency : Frequency;
        attribute source : String;
        attribute timestamp : TimeDuration;
    }

    item def ProcessedSignal {
        attribute intent : MotorIntent;
        attribute confidence : Confidence;
        attribute decodedTorque : Torque;
        attribute targetJoint : String;
        attribute timestamp : TimeDuration;
    }

    item def MotorCommand {
        attribute targetActuatorId : Integer;
        attribute commandedTorque : Torque;
        attribute commandedVelocity : AngularVelocity;
        attribute targetPosition : Angle;
        attribute duration : TimeDuration;
    }

    item def ProprioceptiveFeedback {
        attribute actuatorId : Integer;
        attribute jointAngle : Angle;
        attribute angularVelocity : AngularVelocity;
        attribute appliedForce : Force;
        attribute appliedTorque : Torque;
        attribute temperature : Temperature;
        attribute timestamp : TimeDuration;
    }

    item def SafetyAlert {
        attribute status : SafetyStatus;
        attribute message : String;
        attribute actuatorId : Integer;
        attribute measuredValue : Real;
        attribute limitValue : Real;
        attribute timestamp : TimeDuration;
    }

    item def PowerStatus {
        attribute batteryLevel : BatteryLevel;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute estimatedRuntime : TimeDuration;
    }

    // ===== Port Definitions =====
    port def BioelectricOut {
        out signal : BioelectricSignal;
    }

    port def BioelectricIn {
        in signal : BioelectricSignal;
    }

    port def IntentOut {
        out intent : ProcessedSignal;
    }

    port def IntentIn {
        in intent : ProcessedSignal;
    }

    port def CommandOut {
        out command : MotorCommand;
    }

    port def CommandIn {
        in command : MotorCommand;
    }

    port def FeedbackOut {
        out feedback : ProprioceptiveFeedback;
    }

    port def FeedbackIn {
        in feedback : ProprioceptiveFeedback;
    }

    port def SafetyAlertOut {
        out alert : SafetyAlert;
    }

    port def SafetyAlertIn {
        in alert : SafetyAlert;
    }

    port def PowerOut {
        out status : PowerStatus;
    }

    port def PowerIn {
        in status : PowerStatus;
    }

    // ===== Neural Sensor =====
    part def NeuralSensor {
        port bodyIn : BioelectricIn;
        port bioOut : BioelectricOut;
        port powerIn : PowerIn;

        attribute samplingRate : Frequency = 1000 [Hz];
        attribute electrodeCount : Integer = 16;
        attribute sensitivity : BioelectricPotential = 5 [uV];
        attribute signalDetected : Boolean = false;

        action def detectSignals {
            in raw : BioelectricSignal;
            out detected : BioelectricSignal;

            action amplify {
                in input : BioelectricSignal;
                out amplified : BioelectricSignal;
            }
            action digitize {
                in analog : BioelectricSignal;
                out digital : BioelectricSignal;
            }
            action encode {
                in digital : BioelectricSignal;
                out encoded : BioelectricSignal;
            }

            flow raw to amplify.input;
            flow amplify.amplified to digitize.analog;
            flow digitize.digital to encode.digital;
            flow encode.encoded to detected;
        }

        exhibit {
            entry; then sensing;

            state sensing {
                entry;
                do detectSignals;
                transition sensing to sensing
                    when bodyIn.signal.amplitude > 0 [uV];
            }
        }
    }

    // ===== Signal Processor =====
    part def SignalProcessor {
        port bioIn : BioelectricIn;
        port intentOut : IntentOut;
        port powerIn : PowerIn;

        attribute filterCutoff : Frequency = 500 [Hz];
        attribute noiseFloor : BioelectricPotential = 2 [uV];
        attribute decodeLatency : TimeDuration = 0.05 [s];
        attribute signalReceived : Boolean = false;

        action def processSignals {
            in raw : BioelectricSignal;
            out decoded : ProcessedSignal;

            action filterNoise {
                in input : BioelectricSignal;
                out filtered : BioelectricSignal;
            }
            action extractFeatures {
                in filtered : BioelectricSignal;
                out features : BioelectricSignal;
            }
            action decodeIntent {
                in features : BioelectricSignal;
                out intent : ProcessedSignal;
            }

            flow raw to filterNoise.input;
            flow filterNoise.filtered to extractFeatures.filtered;
            flow extractFeatures.features to decodeIntent.features;
            flow decodeIntent.intent to decoded;
        }

        exhibit {
            entry; then idle;

            state idle {
                entry;
                transition idle to decoding
                    when bioIn.signal.amplitude > 0 [uV];
            }

            state decoding {
                entry;
                do processSignals;
                transition decoding to idle
                    when intentOut.intent.confidence > 0.0;
            }
        }
    }

    // ===== Control Unit =====
    part def ControlUnit {
        port intentIn : IntentIn;
        port commandOut : CommandOut[5];
        port feedbackIn : FeedbackIn[5];
        port safetyIn : SafetyAlertIn;
        port powerIn : PowerIn;

        attribute controlLoopRate : Frequency = 200 [Hz];
        attribute maxTorque : Torque = 50 [N_m];
        attribute currentState : OperationalState = OperationalState::startup;

        action def computeCommands {
            in intent : ProcessedSignal;
            in feedback : ProprioceptiveFeedback[5];
            in safety : SafetyAlert;
            out commands : MotorCommand[5];

            action evaluateIntent {
                in input : ProcessedSignal;
                out target : ProcessedSignal;
            }
            action incorporateFeedback {
                in target : ProcessedSignal;
                in feedback : ProprioceptiveFeedback[5];
                out adjusted : ProcessedSignal;
            }
            action checkSafety {
                in adjusted : ProcessedSignal;
                in safety : SafetyAlert;
                out safe : ProcessedSignal;
            }
            action generateCommands {
                in safe : ProcessedSignal;
                out commands : MotorCommand[5];
            }

            flow intent to evaluateIntent.input;
            flow feedback to incorporateFeedback.feedback;
            flow safety to checkSafety.safety;
            flow evaluateIntent.target to incorporateFeedback.target;
            flow incorporateFeedback.adjusted to checkSafety.adjusted;
            flow checkSafety.safe to generateCommands.safe;
            flow generateCommands.commands to commands;
        }

        action def performInitialization {
            out initialized : Boolean;
        }

        action def sendNullCommands {
            out commands : MotorCommand[5];
        }

        action def emergencyStop {
            out commands : MotorCommand[5];
        }

        exhibit {
            entry; then startup;

            state startup {
                entry;
                do performInitialization;
                transition startup to standby
                    when powerIn.status.batteryLevel > 10 [pct];
            }

            state standby {
                entry;
                do sendNullCommands;
                transition standby to active
                    when intentIn.intent.confidence > 0.7;
                transition standby to failSafe
                    when safetyIn.alert.status == SafetyStatus::critical;
            }

            state active {
                entry;
                do computeCommands;
                transition active to standby
                    when intentIn.intent.intent == MotorIntent::none;
                transition active to failSafe
                    when safetyIn.alert.status == SafetyStatus::critical;
            }

            state failSafe {
                entry;
                do emergencyStop;
                transition failSafe to startup
                    when safetyIn.alert.status == SafetyStatus::nominal;
            }
        }
    }

    // ===== Bionic Actuator =====
    part def BionicActuator {
        port commandIn : CommandIn;
        port feedbackOut : FeedbackOut;
        port powerIn : PowerIn;

        attribute actuatorId : Integer;
        attribute maxTorque : Torque = 10 [N_m];
        attribute maxVelocity : AngularVelocity = 5 [rad_s];
        attribute maxForce : Force = 200 [N];
        attribute operatingTemp : Temperature = 25 [degC];

        action def executeMovement {
            in command : MotorCommand;
            out feedback : ProprioceptiveFeedback;

            action applyTorque {
                in cmd : MotorCommand;
                out applied : Torque;
            }
            action measurePosition {
                out angle : Angle;
                out velocity : AngularVelocity;
            }
            action measureForce {
                out force : Force;
                out torque : Torque;
            }
            action transmitFeedback {
                in angle : Angle;
                in velocity : AngularVelocity;
                in force : Force;
                in torque : Torque;
                out fb : ProprioceptiveFeedback;
            }

            flow command to applyTorque.cmd;
            flow applyTorque.applied to measureForce.torque;
            flow measurePosition.angle to transmitFeedback.angle;
            flow measurePosition.velocity to transmitFeedback.velocity;
            flow measureForce.force to transmitFeedback.force;
            flow measureForce.torque to transmitFeedback.torque;
            flow transmitFeedback.fb to feedback;
        }

        exhibit {
            entry; then idle;

            state idle {
                entry;
                transition idle to moving
                    when commandIn.command.commandedTorque != 0 [N_m];
            }

            state moving {
                entry;
                do executeMovement;
                transition moving to idle
                    when feedbackOut.feedback.appliedTorque >= 0 [N_m];
            }
        }
    }

    // ===== Safety Monitor =====
    part def SafetyMonitor {
        port feedbackIn : FeedbackIn[5];
        port alertOut : SafetyAlertOut;
        port powerIn : PowerIn;

        attribute maxSafeTorque : Torque = 8 [N_m];
        attribute maxSafeForce : Force = 150 [N];
        attribute maxSafeTemp : Temperature = 60 [degC];
        attribute maxSafeVelocity : AngularVelocity = 4 [rad_s];
        attribute checkRate : Frequency = 500 [Hz];

        action def monitorSafety {
            in feedback : ProprioceptiveFeedback[5];
            out alert : SafetyAlert;

            action checkTorque {
                in fb : ProprioceptiveFeedback[5];
                out violation : Boolean;
            }
            action checkForce {
                in fb : ProprioceptiveFeedback[5];
                out violation : Boolean;
            }
            action checkTemperature {
                in fb : ProprioceptiveFeedback[5];
                out violation : Boolean;
            }
            action checkVelocity {
                in fb : ProprioceptiveFeedback[5];
                out violation : Boolean;
            }
            action evaluateStatus {
                in torqueViolation : Boolean;
                in forceViolation : Boolean;
                in tempViolation : Boolean;
                in velocityViolation : Boolean;
                out alert : SafetyAlert;
            }

            flow feedback to checkTorque.fb;
            flow feedback to checkForce.fb;
            flow feedback to checkTemperature.fb;
            flow feedback to checkVelocity.fb;
            flow checkTorque.violation to evaluateStatus.torqueViolation;
            flow checkForce.violation to evaluateStatus.forceViolation;
            flow checkTemperature.violation to evaluateStatus.tempViolation;
            flow checkVelocity.violation to evaluateStatus.velocityViolation;
            flow evaluateStatus.alert to alert;
        }

        exhibit {
            entry; then monitoring;

            state monitoring {
                entry;
                do monitorSafety;
                transition monitoring to monitoring
                    when feedbackIn.feedback.appliedTorque >= 0 [N_m];
            }
        }
    }

    // ===== Power Management =====
    part def PowerManagement {
        port powerOut : PowerOut;

        attribute batteryCapacity : Power = 50 [W_h];
        attribute batteryLevel : BatteryLevel = 100 [pct];
        attribute outputVoltage : Voltage = 12 [V];
        attribute maxOutputCurrent : Current = 10 [A];
        attribute chargeCycles : Integer = 0;

        action def distributePower {
            out status : PowerStatus;

            action measureBattery {
                out level : BatteryLevel;
            }
            action regulateVoltage {
                out voltage : Voltage;
            }
            action distributeCurrent {
                out current : Current;
            }
            action reportStatus {
                in level : BatteryLevel;
                in voltage : Voltage;
                in current : Current;
                out status : PowerStatus;
            }

            flow measureBattery.level to reportStatus.level;
            flow regulateVoltage.voltage to reportStatus.voltage;
            flow distributeCurrent.current to reportStatus.current;
            flow reportStatus.status to status;
        }

        action def reduceOutput {
            out status : PowerStatus;
        }

        exhibit {
            entry; then discharging;

            state discharging {
                entry;
                do distributePower;
                transition discharging to lowBattery
                    when batteryLevel < 20 [pct];
            }

            state lowBattery {
                entry;
                do reduceOutput;
                transition lowBattery to discharging
                    when batteryLevel > 50 [pct];
            }
        }
    }

    // ===== Requirements =====
    requirement def BioelectricDetectionRequirement {
        subject sensor : NeuralSensor;
        doc 'The neural sensor shall detect bioelectric signals with amplitude as low as 5 uV from residual nerves or muscles.';
        require sensor.samplingRate >= 1000 [Hz];
        require sensor.sensitivity <= 5 [uV];
    }

    requirement def SignalDecodingRequirement {
        subject processor : SignalProcessor;
        doc 'The signal processor shall decode motor intent from bioelectric signals within 50 ms.';
        require processor.decodeLatency <= 0.05 [s];
        require processor.noiseFloor <= 2 [uV];
    }

    requirement def ControlResponsivenessRequirement {
        subject controller : ControlUnit;
        doc 'The control unit shall compute motor commands at a rate of at least 200 Hz.';
        require controller.controlLoopRate >= 200 [Hz];
        require controller.maxTorque <= 50 [N_m];
    }

    requirement def ActuatorPerformanceRequirement {
        subject actuator : BionicActuator;
        doc 'Each bionic actuator shall generate torque up to 10 N*m and provide proprioceptive feedback.';
        require actuator.maxTorque >= 10 [N_m];
        require actuator.maxForce >= 200 [N];
    }

    requirement def SafetyMonitoringRequirement {
        subject monitor : SafetyMonitor;
        doc 'The safety monitor shall detect and report any feedback exceeding safe limits within 2 ms.';
        require monitor.checkRate >= 500 [Hz];
        require monitor.maxSafeTorque <= 8 [N_m];
        require monitor.maxSafeForce <= 150 [N];
        require monitor.maxSafeTemp <= 60 [degC];
    }

    requirement def PowerEnduranceRequirement {
        subject power : PowerManagement;
        doc 'The power management unit shall provide at least 8 hours of continuous operation on a full charge.';
        require power.batteryCapacity >= 50 [W_h];
        require power.outputVoltage >= 12 [V];
    }

    requirement def SystemIntegrationRequirement {
        subject prosthesis : BionicProsthesisSystem;
        doc 'The complete bionic prosthesis shall form a continuous feedback loop from neural sensing to actuation within 100 ms total latency.';
        require prosthesis.totalLatency <= 0.1 [s];
    }

    // ===== Requirement Usages =====
    requirement bioReq : BioelectricDetectionRequirement;
    requirement decodeReq : SignalDecodingRequirement;
    requirement controlReq : ControlResponsivenessRequirement;
    requirement actuatorReq : ActuatorPerformanceRequirement;
    requirement safetyReq : SafetyMonitoringRequirement;
    requirement powerReq : PowerEnduranceRequirement;
    requirement integrationReq : SystemIntegrationRequirement;

    // ===== Top-level System =====
    part def BionicProsthesisSystem {
        attribute totalLatency : TimeDuration = 0.08 [s];
        attribute numActuators : Integer = 5;

        port bodySignalIn : BioelectricIn;
        port externalSafetyAlert : SafetyAlertOut;

        part neuralSensor : NeuralSensor;
        part signalProcessor : SignalProcessor;
        part controlUnit : ControlUnit;
        part actuators : BionicActuator[5];
        part safetyMonitor : SafetyMonitor;
        part powerManagement : PowerManagement;

        // Signal flow: sensor to processor
        connection neuralToProcessor connect neuralSensor.bioOut to signalProcessor.bioIn;

        // Signal flow: processor to controller
        connection processorToController connect signalProcessor.intentOut to controlUnit.intentIn;

        // Controller commands to actuators
        connection cmdToAct1 connect controlUnit.commandOut[1] to actuators[1].commandIn;
        connection cmdToAct2 connect controlUnit.commandOut[2] to actuators[2].commandIn;
        connection cmdToAct3 connect controlUnit.commandOut[3] to actuators[3].commandIn;
        connection cmdToAct4 connect controlUnit.commandOut[4] to actuators[4].commandIn;
        connection cmdToAct5 connect controlUnit.commandOut[5] to actuators[5].commandIn;

        // Actuator feedback to controller
        connection fbToCtrl1 connect actuators[1].feedbackOut to controlUnit.feedbackIn[1];
        connection fbToCtrl2 connect actuators[2].feedbackOut to controlUnit.feedbackIn[2];
        connection fbToCtrl3 connect actuators[3].feedbackOut to controlUnit.feedbackIn[3];
        connection fbToCtrl4 connect actuators[4].feedbackOut to controlUnit.feedbackIn[4];
        connection fbToCtrl5 connect actuators[5].feedbackOut to controlUnit.feedbackIn[5];

        // Actuator feedback to safety monitor
        connection fbToSafety1 connect actuators[1].feedbackOut to safetyMonitor.feedbackIn[1];
        connection fbToSafety2 connect actuators[2].feedbackOut to safetyMonitor.feedbackIn[2];
        connection fbToSafety3 connect actuators[3].feedbackOut to safetyMonitor.feedbackIn[3];
        connection fbToSafety4 connect actuators[4].feedbackOut to safetyMonitor.feedbackIn[4];
        connection fbToSafety5 connect actuators[5].feedbackOut to safetyMonitor.feedbackIn[5];

        // Safety monitor to controller
        connection safetyToCtrl connect safetyMonitor.alertOut to controlUnit.safetyIn;

        // Safety monitor to external alert (delegation)
        connection safetyToExternal connect safetyMonitor.alertOut to externalSafetyAlert;

        // Power distribution to all components
        connection powerToSensor connect powerManagement.powerOut to neuralSensor.powerIn;
        connection powerToProcessor connect powerManagement.powerOut to signalProcessor.powerIn;
        connection powerToController connect powerManagement.powerOut to controlUnit.powerIn;
        connection powerToAct1 connect powerManagement.powerOut to actuators[1].powerIn;
        connection powerToAct2 connect powerManagement.powerOut to actuators[2].powerIn;
        connection powerToAct3 connect powerManagement.powerOut to actuators[3].powerIn;
        connection powerToAct4 connect powerManagement.powerOut to actuators[4].powerIn;
        connection powerToAct5 connect powerManagement.powerOut to actuators[5].powerIn;
        connection powerToSafety connect powerManagement.powerOut to safetyMonitor.powerIn;

        // Body signal delegation to neural sensor
        connection bodyToSensor connect bodySignalIn to neuralSensor.bodyIn;

        // Requirement satisfaction
        satisfy bioReq by neuralSensor;
        satisfy decodeReq by signalProcessor;
        satisfy controlReq by controlUnit;
        satisfy actuatorReq by actuators;
        satisfy safetyReq by safetyMonitor;
        satisfy powerReq by powerManagement;
        satisfy integrationReq by self;
    }
}
