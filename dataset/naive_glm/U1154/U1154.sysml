package SupervisoryControlSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ============== Value Types ==============

    value type EngagementLevel :> Real {
        doc /* Operator engagement level: 0 = fully disengaged, 100 = fully engaged */;
        constraint { 0 <= self and self <= 100 }
    }

    value type ReactionTime :> Time {
        doc /* Operator reaction time to stimuli */;
    }

    value type TimeDuration :> Time {
        doc /* Elapsed duration */;
    }

    value type Confidence :> Real {
        doc /* Confidence or anomaly score in range 0 to 1 */;
        constraint { 0 <= self and self <= 1 }
    }

    value type ProcessVariable :> Real {
        doc /* Generic process variable */;
    }

    value type DataRate :> Real {
        doc /* Data rate in samples per second */;
        constraint { self >= 0 }
    }

    // ============== Enumerations ==============

    enum def AlertLevel {
        none;
        informational;
        warning;
        critical;
    }

    enum def ControlMode {
        automatic;
        manual;
        shared;
    }

    enum def ProcessStatus {
        nominal;
        degraded;
        anomalous;
        failed;
    }

    enum def EngagementStateValue {
        activelyEngaged;
        passivelyMonitoring;
        disengaged;
        outOfLoop;
    }

    enum def HandoverStatus {
        notRequested;
        requested;
        inProgress;
        completed;
        aborted;
    }

    // ============== Item Definitions ==============

    item def ProcessTelemetry {
        attribute status : ProcessStatus;
        attribute primaryVariable : ProcessVariable;
        attribute secondaryVariable : ProcessVariable;
        attribute anomalyScore : Confidence;
        attribute timestamp : TimeDuration;
    }

    item def ControlCommand {
        attribute mode : ControlMode;
        attribute setpoint : ProcessVariable;
        attribute gain : Real;
        attribute derivativeGain : Real;
        attribute integralGain : Real;
    }

    item def EngagementAssessment {
        attribute state : EngagementStateValue;
        attribute level : EngagementLevel;
        attribute timeSinceLastInteraction : TimeDuration;
        attribute estimatedReactionTime : ReactionTime;
        attribute gazeOnDisplay : Boolean;
        attribute inputActivityRate : DataRate;
    }

    item def OperatorAlert {
        attribute level : AlertLevel;
        attribute message : String;
        attribute requiresAcknowledgement : Boolean;
        attribute source : String;
    }

    item def ControlHandover {
        attribute fromMode : ControlMode;
        attribute toMode : ControlMode;
        attribute reason : String;
        attribute urgency : AlertLevel;
        attribute status : HandoverStatus;
    }

    // ============== Port Definitions ==============

    port def TelemetryOutPort {
        out telemetry : ProcessTelemetry;
    }

    port def TelemetryInPort {
        in telemetry : ProcessTelemetry;
    }

    port def ControlOutPort {
        out command : ControlCommand;
    }

    port def ControlInPort {
        in command : ControlCommand;
    }

    port def AlertOutPort {
        out alert : OperatorAlert;
    }

    port def AlertInPort {
        in alert : OperatorAlert;
    }

    port def HandoverOutPort {
        out handover : ControlHandover;
    }

    port def HandoverInPort {
        in handover : ControlHandover;
    }

    port def EngagementOutPort {
        out assessment : EngagementAssessment;
    }

    port def EngagementInPort {
        in assessment : EngagementAssessment;
    }

    // ============== Requirements ==============

    requirement def EngagedReactionTimeRequirement {
        doc /* When the operator is actively engaged, reaction time must remain below a safe threshold */;
        attribute engagedThreshold : ReactionTime = 2.0;
        subject operatorReactionTime : ReactionTime;
        subject operatorEngagement : EngagementStateValue;
        constraint {
            operatorEngagement = EngagementStateValue::activelyEngaged implies
            operatorReactionTime <= engagedThreshold
        }
    }

    requirement def DisengagedReactionTimeRequirement {
        doc /* When the operator is out of the loop, reaction time is significantly degraded */;
        attribute disengagedThreshold : ReactionTime = 10.0;
        subject operatorReactionTime : ReactionTime;
        subject operatorEngagement : EngagementStateValue;
        constraint {
            operatorEngagement = EngagementStateValue::outOfLoop implies
            operatorReactionTime >= disengagedThreshold
        }
    }

    requirement def EngagementMonitoringRequirement {
        doc /* The SA Monitor must detect disengagement and issue an alert before engagement drops below the safe threshold */;
        attribute safeThreshold : EngagementLevel = 40;
        subject currentEngagement : EngagementLevel;
        subject alertIssued : Boolean;
        constraint {
            currentEngagement < safeThreshold implies alertIssued
        }
    }

    requirement def HandoverCompletionRequirement {
        doc /* Control handover from automatic to manual must complete within the maximum allowable time */;
        attribute maxHandoverTime : TimeDuration = 5.0;
        subject handoverDuration : TimeDuration;
        constraint {
            handoverDuration <= maxHandoverTime
        }
    }

    requirement def SystemSafetyRequirement {
        doc /* The system must not remain in fully automatic control with a failed process while the operator is out of the loop */;
        subject processStatus : ProcessStatus;
        subject operatorEngagement : EngagementStateValue;
        subject controlMode : ControlMode;
        constraint {
            (processStatus = ProcessStatus::failed and controlMode = ControlMode::automatic)
            implies operatorEngagement <> EngagementStateValue::outOfLoop
        }
    }

    requirement def PromptEffectivenessRequirement {
        doc /* Re-engagement prompts must restore the operator to at least passively monitoring within a bounded time */;
        attribute maxReengagementTime : TimeDuration = 8.0;
        subject reengagementDuration : TimeDuration;
        subject postPromptEngagement : EngagementStateValue;
        constraint {
            reengagementDuration <= maxReengagementTime
            and postPromptEngagement <> EngagementStateValue::outOfLoop
        }
    }

    requirement def AnomalyDetectionRequirement {
        doc /* The automation controller must detect critical anomalies and initiate handover */;
        attribute criticalThreshold : Confidence = 0.8;
        subject anomalyScore : Confidence;
        subject handoverInitiated : Boolean;
        constraint {
            anomalyScore > criticalThreshold implies handoverInitiated
        }
    }

    requirement def ContinuousMonitoringRequirement {
        doc /* The SA Monitor must continuously assess operator engagement at a minimum sampling rate */;
        attribute minSamplingRate : DataRate = 0.2;
        subject monitoringRate : DataRate;
        constraint {
            monitoringRate >= minSamplingRate
        }
    }

    // ============== Part Definitions ==============

    part def ControlledProcess {
        doc /* The physical or logical process under control (e.g., vehicle navigation, industrial plant) */;

        port telemetryOut : TelemetryOutPort;
        port controlIn : ControlInPort;

        attribute currentStatus : ProcessStatus = ProcessStatus::nominal;
        attribute primaryVariable : ProcessVariable = 0.0;
        attribute secondaryVariable : ProcessVariable = 0.0;
        attribute anomalyScore : Confidence = 0.0;
        attribute processGain : Real = 1.0;
        attribute processTimeConstant : TimeDuration = 2.0;
        attribute externalDisturbance : ProcessVariable = 0.0;
        attribute integralError : ProcessVariable = 0.0;
        attribute elapsedTime : TimeDuration = 0.0;

        state processBehavior {
            entry {
                currentStatus = ProcessStatus::nominal;
            }

            state nominal {
                entry {
                    currentStatus = ProcessStatus::nominal;
                }
                do {
                    elapsedTime' = 1.0;
                    primaryVariable' = processGain * controlIn.command.setpoint
                        - primaryVariable / processTimeConstant
                        + externalDisturbance;
                    secondaryVariable' = -secondaryVariable / processTimeConstant;
                }
            }

            state degraded {
                entry {
                    currentStatus = ProcessStatus::degraded;
                }
                do {
                    elapsedTime' = 1.0;
                    primaryVariable' = processGain * 0.7 * controlIn.command.setpoint
                        - primaryVariable / processTimeConstant
                        + externalDisturbance;
                    secondaryVariable' = -secondaryVariable / (processTimeConstant * 1.5);
                }
            }

            state anomalous {
                entry {
                    currentStatus = ProcessStatus::anomalous;
                }
                do {
                    elapsedTime' = 1.0;
                    primaryVariable' = processGain * 0.3 * controlIn.command.setpoint
                        - primaryVariable / processTimeConstant
                        + externalDisturbance * 2.0;
                    secondaryVariable' = -secondaryVariable / (processTimeConstant * 3.0);
                }
            }

            state failed {
                entry {
                    currentStatus = ProcessStatus::failed;
                }
                do {
                    elapsedTime' = 1.0;
                    primaryVariable' = externalDisturbance;
                    secondaryVariable' = 0.0;
                }
            }

            transition nominal to degraded
                when anomalyScore > 0.2;

            transition degraded to anomalous
                when anomalyScore > 0.5;

            transition anomalous to failed
                when anomalyScore > 0.9;

            transition degraded to nominal
                when anomalyScore < 0.1;

            transition anomalous to degraded
                when anomalyScore < 0.4;
        }

        action emitTelemetry {
            out telemetry : ProcessTelemetry;
            assign telemetry.status = currentStatus;
            assign telemetry.primaryVariable = primaryVariable;
            assign telemetry.secondaryVariable = secondaryVariable;
            assign telemetry.anomalyScore = anomalyScore;
            assign telemetry.timestamp = elapsedTime;
            bind telemetryOut.telemetry = telemetry;
        }
    }

    part def HumanOperator {
        doc /* Human operator subject to out-of-the-loop performance degradation during prolonged automation */;

        port alertIn : AlertInPort;
        port handoverIn : HandoverInPort;
        port engagementOut : EngagementOutPort;
        port manualControlOut : ControlOutPort;

        attribute engagementState : EngagementStateValue = EngagementStateValue::activelyEngaged;
        attribute engagementLevel : EngagementLevel = 100;
        attribute reactionTime : ReactionTime = 1.5;
        attribute timeSinceLastInteraction : TimeDuration = 0.0;
        attribute maxEngagedTime : TimeDuration = 600.0;
        attribute baseReactionTime : ReactionTime = 1.5;
        attribute disengagedMultiplier : Real = 6.0;
        attribute manualSetpoint : ProcessVariable = 100.0;
        attribute manualGain : Real = 2.0;
        attribute manualDerivativeGain : Real = 0.5;
        attribute manualIntegralGain : Real = 0.1;
        attribute hasAcknowledged : Boolean = false;
        attribute gazeOnDisplay : Boolean = true;
        attribute inputActivityRate : DataRate = 1.0;
        attribute totalAlertsReceived : Integer = 0;
        attribute totalHandoversReceived : Integer = 0;

        state operatorEngagementBehavior {

            state activelyEngaged {
                entry {
                    engagementState = EngagementStateValue::activelyEngaged;
                    engagementLevel = 100;
                    reactionTime = baseReactionTime;
                }
                do {
                    timeSinceLastInteraction' = 1.0;
                    if inputActivityRate > 0.5 {
                        gazeOnDisplay = true;
                    }
                }
            }

            state passivelyMonitoring {
                entry {
                    engagementState = EngagementStateValue::passivelyMonitoring;
                    reactionTime = baseReactionTime * 2.0;
                }
                do {
                    timeSinceLastInteraction' = 1.0;
                    engagementLevel' = -0.5;
                    gazeOnDisplay = false;
                }
            }

            state disengaged {
                entry {
                    engagementState = EngagementStateValue::disengaged;
                    reactionTime = baseReactionTime * 4.0;
                }
                do {
                    timeSinceLastInteraction' = 1.0;
                    engagementLevel' = -0.2;
                    gazeOnDisplay = false;
                    inputActivityRate = 0.0;
                }
            }

            state outOfLoop {
                entry {
                    engagementState = EngagementStateValue::outOfLoop;
                    reactionTime = baseReactionTime * disengagedMultiplier;
                }
                do {
                    timeSinceLastInteraction' = 1.0;
                    engagementLevel' = -0.1;
                    gazeOnDisplay = false;
                    inputActivityRate = 0.0;
                }
            }

            // Natural drift transitions — the out-of-the-loop problem
            transition activelyEngaged to passivelyMonitoring
                when timeSinceLastInteraction > maxEngagedTime;

            transition passivelyMonitoring to disengaged
                when engagementLevel < 40;

            transition disengaged to outOfLoop
                when engagementLevel < 10;

            // Re-engagement via informational prompts from SA Monitor
            transition passivelyMonitoring to activelyEngaged
                when alertIn.alert.level = AlertLevel::informational and hasAcknowledged
                do {
                    timeSinceLastInteraction = 0.0;
                    engagementLevel = 100;
                    hasAcknowledged = false;
                    totalAlertsReceived = totalAlertsReceived + 1;
                };

            transition disengaged to passivelyMonitoring
                when alertIn.alert.level = AlertLevel::informational and hasAcknowledged
                do {
                    timeSinceLastInteraction = 0.0;
                    engagementLevel = 60;
                    hasAcknowledged = false;
                    totalAlertsReceived = totalAlertsReceived + 1;
                };

            // Re-engagement via warning prompts from SA Monitor
            transition disengaged to passivelyMonitoring
                when alertIn.alert.level = AlertLevel::warning and hasAcknowledged
                do {
                    timeSinceLastInteraction = 0.0;
                    engagementLevel = 60;
                    hasAcknowledged = false;
                    totalAlertsReceived = totalAlertsReceived + 1;
                };

            transition outOfLoop to disengaged
                when alertIn.alert.level = AlertLevel::warning and hasAcknowledged
                do {
                    timeSinceLastInteraction = 0.0;
                    engagementLevel = 25;
                    hasAcknowledged = false;
                    totalAlertsReceived = totalAlertsReceived + 1;
                };

            // Critical alert from AutomationController forces engagement
            transition passivelyMonitoring to activelyEngaged
                when alertIn.alert.level = AlertLevel::critical and hasAcknowledged
                do {
                    timeSinceLastInteraction = 0.0;
                    engagementLevel = 100;
                    reactionTime = baseReactionTime * 2.5;
                    hasAcknowledged = false;
                    totalAlertsReceived = totalAlertsReceived + 1;
                };

            transition disengaged to activelyEngaged
                when alertIn.alert.level = AlertLevel::critical and hasAcknowledged
                do {
                    timeSinceLastInteraction = 0.0;
                    engagementLevel = 100;
                    reactionTime = baseReactionTime * 3.0;
                    hasAcknowledged = false;
                    totalAlertsReceived = totalAlertsReceived + 1;
                };

            transition outOfLoop to activelyEngaged
                when alertIn.alert.level = AlertLevel::critical and hasAcknowledged
                do {
                    timeSinceLastInteraction = 0.0;
                    engagementLevel = 100;
                    reactionTime = baseReactionTime * disengagedMultiplier;
                    hasAcknowledged = false;
                    totalAlertsReceived = totalAlertsReceived + 1;
                };
        }

        action takeManualControl {
            in handover : ControlHandover;
            out command : ControlCommand;
            assign command.mode = ControlMode::manual;
            assign command.setpoint = manualSetpoint;
            assign command.gain = manualGain;
            assign command.derivativeGain = manualDerivativeGain;
            assign command.integralGain = manualIntegralGain;
            bind manualControlOut.command = command;
        }

        action emitEngagementAssessment {
            out assessment : EngagementAssessment;
            assign assessment.state = engagementState;
            assign assessment.level = engagementLevel;
            assign assessment.timeSinceLastInteraction = timeSinceLastInteraction;
            assign assessment.estimatedReactionTime = reactionTime;
            assign assessment.gazeOnDisplay = gazeOnDisplay;
            assign assessment.inputActivityRate = inputActivityRate;
            bind engagementOut.assessment = assessment;
        }

        action acknowledgeAlert {
            in alert : OperatorAlert;
            do {
                hasAcknowledged = true;
            }
        }
    }

    part def AutomationController {
        doc /* Autonomous controller with anomaly detection, alerting, and control handover capability */;

        port telemetryIn : TelemetryInPort;
        port controlOut : ControlOutPort;
        port alertOut : AlertOutPort;
        port handoverOut : HandoverOutPort;
        port operatorControlIn : ControlInPort;

        attribute currentMode : ControlMode = ControlMode::automatic;
        attribute detectedAnomalyScore : Confidence = 0.0;
        attribute anomalyThreshold : Confidence = 0.5;
        attribute criticalThreshold : Confidence = 0.8;
        attribute controllerGain : Real = 2.0;
        attribute controllerDerivativeGain : Real = 0.5;
        attribute controllerIntegralGain : Real = 0.1;
        attribute setpoint : ProcessVariable = 100.0;
        attribute handoverInProgress : Boolean = false;
        attribute handoverDuration : TimeDuration = 0.0;
        attribute maxHandoverTime : TimeDuration = 5.0;
        attribute handoverStatus : HandoverStatus = HandoverStatus::notRequested;
        attribute integralError : ProcessVariable = 0.0;
        attribute previousError : ProcessVariable = 0.0;
        attribute elapsedTime : TimeDuration = 0.0;

        state controllerModeBehavior {

            state autonomousMode {
                entry {
                    currentMode = ControlMode::automatic;
                    handoverInProgress = false;
                    handoverStatus = HandoverStatus::notRequested;
                }
                do {
                    elapsedTime' = 1.0;
                    controlOut.command.mode = ControlMode::automatic;
                    controlOut.command.setpoint = setpoint;
                    controlOut.command.gain = controllerGain;
                    controlOut.command.derivativeGain = controllerDerivativeGain;
                    controlOut.command.integralGain = controllerIntegralGain;
                    detectedAnomalyScore = telemetryIn.telemetry.anomalyScore;
                    integralError' = setpoint - telemetryIn.telemetry.primaryVariable;
                }
            }

            state alertMode {
                entry {
                    currentMode = ControlMode::automatic;
                    alertOut.alert.level = AlertLevel::warning;
                    alertOut.alert.message = "Process anomaly detected, monitoring closely";
                    alertOut.alert.requiresAcknowledgement = true;
                    alertOut.alert.source = "AutomationController";
                }
                do {
                    elapsedTime' = 1.0;
                    controlOut.command.mode = ControlMode::automatic;
                    controlOut.command.setpoint = setpoint;
                    controlOut.command.gain = controllerGain * 0.5;
                    controlOut.command.derivativeGain = controllerDerivativeGain * 0.5;
                    controlOut.command.integralGain = controllerIntegralGain * 0.5;
                    detectedAnomalyScore = telemetryIn.telemetry.anomalyScore;
                }
            }

            state handoverMode {
                entry {
                    handoverInProgress = true;
                    handoverDuration = 0.0;
                    handoverStatus = HandoverStatus::inProgress;
                    handoverOut.handover.fromMode = ControlMode::automatic;
                    handoverOut.handover.toMode = ControlMode::manual;
                    handoverOut.handover.reason = "Critical anomaly detected, manual control required";
                    handoverOut.handover.urgency = AlertLevel::critical;
                    handoverOut.handover.status = HandoverStatus::inProgress;
                    alertOut.alert.level = AlertLevel::critical;
                    alertOut.alert.message = "CRITICAL: Manual control required immediately";
                    alertOut.alert.requiresAcknowledgement = true;
                    alertOut.alert.source = "AutomationController";
                }
                do {
                    elapsedTime' = 1.0;
                    handoverDuration' = 1.0;
                    controlOut.command.mode = ControlMode::automatic;
                    controlOut.command.setpoint = setpoint;
                    controlOut.command.gain = controllerGain * 0.3;
                    controlOut.command.derivativeGain = 0.0;
                    controlOut.command.integralGain = 0.0;
                    detectedAnomalyScore = telemetryIn.telemetry.anomalyScore;
                }
            }

            state manualMode {
                entry {
                    currentMode = ControlMode::manual;
                    handoverInProgress = false;
                    handoverStatus = HandoverStatus::completed;
                }
                do {
                    elapsedTime' = 1.0;
                    controlOut.command = operatorControlIn.command;
                    detectedAnomalyScore = telemetryIn.telemetry.anomalyScore;
                }
            }

            state sharedMode {
                entry {
                    currentMode = ControlMode::shared;
                    handoverStatus = HandoverStatus::completed;
                }
                do {
                    elapsedTime' = 1.0;
                    controlOut.command.mode = ControlMode::shared;
                    controlOut.command.setpoint = (setpoint + operatorControlIn.command.setpoint) / 2.0;
                    controlOut.command.gain = controllerGain;
                    controlOut.command.derivativeGain = controllerDerivativeGain;
                    controlOut.command.integralGain = controllerIntegralGain;
                    detectedAnomalyScore = telemetryIn.telemetry.anomalyScore;
                }
            }

            transition autonomousMode to alertMode
                when detectedAnomalyScore > anomalyThreshold;

            transition alertMode to handoverMode
                when detectedAnomalyScore > criticalThreshold;

            transition alertMode to autonomousMode
                when detectedAnomalyScore < anomalyThreshold * 0.5;

            transition handoverMode to manualMode
                when operatorControlIn.command.mode = ControlMode::manual
                and handoverDuration <= maxHandoverTime;

            transition handoverMode to manualMode
                when operatorControlIn.command.mode = ControlMode::manual
                and handoverDuration > maxHandoverTime
                do {
                    handoverStatus = HandoverStatus::aborted;
                };

            transition manualMode to sharedMode
                when operatorControlIn.command.mode = ControlMode::shared;

            transition manualMode to autonomousMode
                when operatorControlIn.command.mode = ControlMode::automatic
                and detectedAnomalyScore < anomalyThreshold * 0.5;

            transition sharedMode to autonomousMode
                when detectedAnomalyScore < anomalyThreshold * 0.5;
        }

        action detectAnomaly {
            in telemetry : ProcessTelemetry;
            out anomalyScore : Confidence;
            assign anomalyScore = telemetry.anomalyScore;
        }
    }

    part def SituationalAwarenessMonitor {
        doc /* Monitors operator engagement and proactively re-engages the operator to prevent out-of-loop degradation */;

        port engagementIn : EngagementInPort;
        port promptOut : AlertOutPort;

        attribute safeEngagementThreshold : EngagementLevel = 40;
        attribute criticalEngagementThreshold : EngagementLevel = 15;
        attribute monitoringInterval : TimeDuration = 5.0;
        attribute lastAssessment : EngagementAssessment;
        attribute promptActive : Boolean = false;
        attribute promptCount : Integer = 0;
        attribute maxPromptFrequency : TimeDuration = 30.0;
        attribute timeSinceLastPrompt : TimeDuration = 0.0;
        attribute totalMonitoringTime : TimeDuration = 0.0;
        attribute monitoringRate : DataRate = 0.2;
        attribute gazeTrackingEnabled : Boolean = true;
        attribute inputActivityThreshold : DataRate = 0.1;

        state monitoringBehavior {

            state monitoring {
                entry {
                    promptActive = false;
                }
                do {
                    timeSinceLastPrompt' = 1.0;
                    totalMonitoringTime' = 1.0;
                    lastAssessment = engagementIn.assessment;
                    if gazeTrackingEnabled and not lastAssessment.gazeOnDisplay {
                        engagementIn.assessment.level = engagementIn.assessment.level - 1.0;
                    }
                }
            }

            state alerting {
                entry {
                    promptActive = true;
                    promptCount = promptCount + 1;
                    timeSinceLastPrompt = 0.0;
                }
                do {
                    if lastAssessment.level < criticalEngagementThreshold {
                        promptOut.alert.level = AlertLevel::warning;
                        promptOut.alert.message = "URGENT: Engagement critically low. Verify system status immediately.";
                    } else {
                        promptOut.alert.level = AlertLevel::informational;
                        promptOut.alert.message = "Attention check: Please confirm you are monitoring the system.";
                    }
                    promptOut.alert.requiresAcknowledgement = true;
                    promptOut.alert.source = "SituationalAwarenessMonitor";
                    timeSinceLastPrompt' = 1.0;
                    totalMonitoringTime' = 1.0;
                    lastAssessment = engagementIn.assessment;
                }
            }

            state suppressed {
                doc /* Prompt suppression period to avoid nagging the operator */;
                do {
                    timeSinceLastPrompt' = 1.0;
                    totalMonitoringTime' = 1.0;
                    lastAssessment = engagementIn.assessment;
                }
            }

            transition monitoring to alerting
                when lastAssessment.level < safeEngagementThreshold
                and timeSinceLastPrompt >= maxPromptFrequency;

            transition alerting to suppressed
                when lastAssessment.level >= safeEngagementThreshold;

            transition suppressed to monitoring
                when timeSinceLastPrompt >= maxPromptFrequency;

            transition alerting to monitoring
                when lastAssessment.level >= safeEngagementThreshold
                and timeSinceLastPrompt >= maxPromptFrequency;
        }

        action assessEngagement {
            in assessment : EngagementAssessment;
            out isSafe : Boolean;
            assign isSafe = assessment.level >= safeEngagementThreshold;
        }
    }

    // ============== System Assembly ==============

    part def SupervisoryControlSystem {
        doc /* Complete supervisory control system addressing the out-of-the-loop problem
              by integrating an automation controller, a controlled process, a human operator,
              and a situational awareness monitor */;

        part operator : HumanOperator {
            doc /* The human operator supervising the automated system */;
        }

        part controller : AutomationController {
            doc /* The automation controller autonomously managing the process */;
        }

        part process : ControlledProcess {
            doc /* The physical or logical process under control */;
        }

        part saMonitor : SituationalAwarenessMonitor {
            doc /* The situational awareness monitor tracking operator engagement */;
        }

        // ---- Connections ----

        // Process telemetry flows to the automation controller
        connection processTelemetryToController
            from process.telemetryOut to controller.telemetryIn;

        // Controller commands flow to the controlled process
        connection controllerCommandToProcess
            from controller.controlOut to process.controlIn;

        // Controller alerts flow to the operator
        connection controllerAlertToOperator
            from controller.alertOut to operator.alertIn;

        // Controller handover requests flow to the operator
        connection controllerHandoverToOperator
            from controller.handoverOut to operator.handoverIn;

        // Operator manual control commands flow to the controller
        connection operatorControlToController
            from operator.manualControlOut to controller.operatorControlIn;

        // Operator engagement assessment flows to the SA monitor
        connection operatorEngagementToSAMonitor
            from operator.engagementOut to saMonitor.engagementIn;

        // SA monitor re-engagement prompts flow to the operator
        connection saMonitorPromptToOperator
            from saMonitor.promptOut to operator.alertIn;

        // ---- Requirement Satisfactions ----

        satisfy engagedReactionReq : EngagedReactionTimeRequirement {
            subject operatorReactionTime = operator.reactionTime;
            subject operatorEngagement = operator.engagementState;
        }

        satisfy disengagedReactionReq : DisengagedReactionTimeRequirement {
            subject operatorReactionTime = operator.reactionTime;
            subject operatorEngagement = operator.engagementState;
        }

        satisfy engagementMonitoringReq : EngagementMonitoringRequirement {
            subject currentEngagement = operator.engagementLevel;
            subject alertIssued = saMonitor.promptActive;
        }

        satisfy handoverCompletionReq : HandoverCompletionRequirement {
            subject handoverDuration = controller.handoverDuration;
        }

        satisfy systemSafetyReq : SystemSafetyRequirement {
            subject processStatus = process.currentStatus;
            subject operatorEngagement = operator.engagementState;
            subject controlMode = controller.currentMode;
        }

        satisfy promptEffectivenessReq : PromptEffectivenessRequirement {
            subject reengagementDuration = operator.timeSinceLastInteraction;
            subject postPromptEngagement = operator.engagementState;
        }

        satisfy anomalyDetectionReq : AnomalyDetectionRequirement {
            subject anomalyScore = controller.detectedAnomalyScore;
            subject handoverInitiated = controller.handoverInProgress;
        }

        satisfy continuousMonitoringReq : ContinuousMonitoringRequirement {
            subject monitoringRate = saMonitor.monitoringRate;
        }
    }
}
