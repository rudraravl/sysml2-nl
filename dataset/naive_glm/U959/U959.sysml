package DynamicPerformanceOptimization {
    public import ScalarValues::*;
    public import ISQ::*;

    attribute def ThroughputValue :> Real {
        doc "Throughput measured in operations per second."
        unit "ops/s"
    }

    attribute def EfficiencyValue :> Real {
        doc "Efficiency expressed as a dimensionless ratio in [0,1]."
        unit "ratio"
    }

    attribute def RateOfImprovement :> Real {
        doc "First derivative of performance with respect to time."
        unit "1/s"
    }

    attribute def AccelerationValue :> Real {
        doc "Second derivative of performance with respect to time."
        unit "1/s^2"
    }

    attribute def AmplificationFactor :> Real {
        doc "Dimensionless multiplier applied to the current rate of improvement."
    }

    attribute def TimeStamp :> Real {
        unit "s"
    }

    attribute def GainParameter :> Real {
        doc "Controller gain used to compute the amplification factor."
    }

    item def PerformanceSample {
        attribute throughput : ThroughputValue;
        attribute efficiency : EfficiencyValue;
        attribute timestamp : TimeStamp;
    }

    item def PerformanceHistory {
        attribute samples : PerformanceSample[0..*] ordered;
    }

    item def AccelerationReport {
        attribute currentRate : RateOfImprovement;
        attribute acceleration : AccelerationValue;
        attribute positiveAcceleration : Boolean;
        attribute confidence : Real;
    }

    item def OptimizationCommand {
        attribute targetFactor : AmplificationFactor;
        attribute priority : Integer;
        attribute justification : String;
    }

    item def AmplifiedRate {
        attribute amplifiedRate : RateOfImprovement;
        attribute appliedFactor : AmplificationFactor;
    }

    item def RegulatedFeedback {
        attribute regulatedRate : RateOfImprovement;
        attribute stabilityMargin : Real;
        attribute stable : Boolean;
    }

    port def PerformanceDataOutPort {
        out item sample : PerformanceSample;
    }

    port def PerformanceDataInPort {
        in item sample : PerformanceSample;
    }

    port def AccelerationReportOutPort {
        out item report : AccelerationReport;
    }

    port def AccelerationReportInPort {
        in item report : AccelerationReport;
    }

    port def OptimizationCommandOutPort {
        out item command : OptimizationCommand;
    }

    port def OptimizationCommandInPort {
        in item command : OptimizationCommand;
    }

    port def AmplifiedRateOutPort {
        out item amplified : AmplifiedRate;
    }

    port def AmplifiedRateInPort {
        in item amplified : AmplifiedRate;
    }

    port def RegulatedFeedbackOutPort {
        out item feedback : RegulatedFeedback;
    }

    port def RegulatedFeedbackInPort {
        in item feedback : RegulatedFeedback;
    }

    part def TargetSystem {
        port feedbackIn : RegulatedFeedbackInPort;
        port dataOut : PerformanceDataOutPort;

        attribute currentThroughput : ThroughputValue = 100.0;
        attribute currentEfficiency : EfficiencyValue = 0.5;
        attribute baselineRate : RateOfImprovement = 0.0;
        attribute internalTime : TimeStamp = 0.0;

        action def evolveState :> Action {
            in feedback : RegulatedFeedback;
            out sample : PerformanceSample;
        }

        action evolveState : evolveState {
            in feedback = feedbackIn.feedback;
            out sample = dataOut.sample;
        }

        state targetSystemBehavior {
            entry; then Operating;
            state Operating {
                entry action {
                    currentThroughput := currentThroughput + feedback.regulatedRate * 0.1;
                    if (currentThroughput < 0.0) { currentThroughput := 0.0; }
                    currentEfficiency := currentEfficiency + 0.01 * feedback.regulatedRate;
                    if (currentEfficiency > 1.0) { currentEfficiency := 1.0; }
                    if (currentEfficiency < 0.0) { currentEfficiency := 0.0; }
                    internalTime := internalTime + 0.1;
                }
                do action send sample : PerformanceSample {
                    sample.throughput := currentThroughput;
                    sample.efficiency := currentEfficiency;
                    sample.timestamp := internalTime;
                    send sample to dataOut.sample;
                }
            }
        }
    }

    part def PerformanceMonitor {
        port dataOut : PerformanceDataOutPort;
        port feedbackIn : RegulatedFeedbackInPort;

        attribute samplingInterval : TimeStamp = 0.1;
        attribute latestSample : PerformanceSample;
        attribute observedFeedback : RegulatedFeedback;

        action def gatherSample :> Action {
            in feedback : RegulatedFeedback;
            out sample : PerformanceSample;
        }

        action gatherSample : gatherSample {
            in feedback = feedbackIn.feedback;
            out sample = dataOut.sample;
        }

        state monitorStates {
            entry; then Idle;
            state Idle {
                do action wait {
                    // await feedback or timer
                }
                transition then Sampling;
            }
            state Sampling {
                entry action {
                    observedFeedback := feedbackIn.feedback;
                    latestSample.throughput := 0.0;
                    latestSample.efficiency := 0.0;
                    latestSample.timestamp := 0.0;
                }
                do action emit : PerformanceSample {
                    latestSample.throughput := latestSample.throughput + observedFeedback.regulatedRate;
                    latestSample.efficiency := observedFeedback.stabilityMargin;
                    send latestSample to dataOut.sample;
                }
                transition then Idle;
            }
        }
    }

    part def ChangeAnalyzer {
        port dataIn : PerformanceDataInPort;
        port reportOut : AccelerationReportOutPort;

        attribute history : PerformanceHistory;
        attribute previousRate : RateOfImprovement = 0.0;
        attribute currentRate : RateOfImprovement = 0.0;
        attribute acceleration : AccelerationValue = 0.0;
        attribute windowSize : Integer = 10;
        attribute accelerationThreshold : AccelerationValue = 0.001;

        action def analyze :> Action {
            in sample : PerformanceSample;
            out report : AccelerationReport;
        }

        action analyze : analyze {
            in sample = dataIn.sample;
            out report = reportOut.report;
        }

        state analyzerStates {
            entry; then Accumulating;
            state Accumulating {
                do action ingest {
                    append dataIn.sample to history.samples;
                    if (size(history.samples) > windowSize) {
                        history.samples := history.samples[1..windowSize];
                    }
                }
                transition if size(history.samples) >= 2 then Evaluating;
            }
            state Evaluating {
                entry action {
                    attribute t1 : TimeStamp := history.samples[size(history.samples)-1].timestamp;
                    attribute t2 : TimeStamp := history.samples[size(history.samples)].timestamp;
                    attribute p1 : ThroughputValue := history.samples[size(history.samples)-1].throughput;
                    attribute p2 : ThroughputValue := history.samples[size(history.samples)].throughput;
                    attribute dt : TimeStamp := t2 - t1;
                    if (dt > 0.0) {
                        previousRate := currentRate;
                        currentRate := (p2 - p1) / dt;
                        if (previousRate != 0.0) {
                            acceleration := (currentRate - previousRate) / dt;
                        } else {
                            acceleration := 0.0;
                        }
                    }
                }
                do action emit : AccelerationReport {
                    attribute rep : AccelerationReport;
                    rep.currentRate := currentRate;
                    rep.acceleration := acceleration;
                    rep.positiveAcceleration := acceleration > accelerationThreshold;
                    rep.confidence := if size(history.samples) >= windowSize then 1.0 else size(history.samples) / windowSize;
                    send rep to reportOut.report;
                }
                transition then Accumulating;
            }
        }
    }

    part def AmplificationController {
        port reportIn : AccelerationReportInPort;
        port commandOut : OptimizationCommandOutPort;

        attribute proportionalGain : GainParameter = 2.0;
        attribute integralGain : GainParameter = 0.5;
        attribute integralAccumulator : Real = 0.0;
        attribute maxFactor : AmplificationFactor = 5.0;
        attribute minFactor : AmplificationFactor = 1.0;
        attribute targetAcceleration : AccelerationValue = 0.01;

        action def formulateStrategy :> Action {
            in report : AccelerationReport;
            out command : OptimizationCommand;
        }

        action formulateStrategy : formulateStrategy {
            in report = reportIn.report;
            out command = commandOut.command;
        }

        state controllerStates {
            entry; then Listening;
            state Listening {
                do action wait {
                    // await acceleration report
                }
                transition then Strategizing;
            }
            state Strategizing {
                entry action {
                    attribute rep : AccelerationReport := reportIn.report;
                    attribute error : AccelerationValue := targetAcceleration - rep.acceleration;
                    integralAccumulator := integralAccumulator + error;
                    attribute rawFactor : AmplificationFactor := proportionalGain * rep.acceleration + integralGain * integralAccumulator;
                    attribute factor : AmplificationFactor;
                    if (rawFactor > maxFactor) { factor := maxFactor; }
                    else if (rawFactor < minFactor) { factor := minFactor; }
                    else { factor := rawFactor; }
                    if (factor < 1.0) { factor := 1.0; }
                    attribute cmd : OptimizationCommand;
                    cmd.targetFactor := factor;
                    cmd.priority := if rep.positiveAcceleration then 1 else 5;
                    cmd.justification := if rep.positiveAcceleration then "Positive acceleration detected; amplifying." else "No positive acceleration; holding.";
                    send cmd to commandOut.command;
                }
                transition then Listening;
            }
        }
    }

    part def RateAmplifier {
        port commandIn : OptimizationCommandInPort;
        port rateIn : AccelerationReportInPort;
        port amplifiedOut : AmplifiedRateOutPort;

        attribute currentRate : RateOfImprovement = 0.0;
        attribute appliedFactor : AmplificationFactor = 1.0;
        attribute smoothing : Real = 0.8;

        action def amplify :> Action {
            in command : OptimizationCommand;
            in report : AccelerationReport;
            out amplified : AmplifiedRate;
        }

        action amplify : amplify {
            in command = commandIn.command;
            in report = rateIn.report;
            out amplified = amplifiedOut.amplified;
        }

        state amplifierStates {
            entry; then Idle;
            state Idle {
                do action wait {
                    // await command and report
                }
                transition then Boosting;
            }
            state Boosting {
                entry action {
                    currentRate := rateIn.report.currentRate;
                    attribute target : AmplificationFactor := commandIn.command.targetFactor;
                    appliedFactor := smoothing * appliedFactor + (1.0 - smoothing) * target;
                    attribute boosted : RateOfImprovement := currentRate * appliedFactor;
                    attribute out : AmplifiedRate;
                    out.amplifiedRate := boosted;
                    out.appliedFactor := appliedFactor;
                    send out to amplifiedOut.amplified;
                }
                transition then Idle;
            }
        }
    }

    part def FeedbackRegulator {
        port amplifiedIn : AmplifiedRateInPort;
        port feedbackOut : RegulatedFeedbackOutPort;

        attribute stabilityThreshold : Real = 0.1;
        attribute maxRate : RateOfImprovement = 50.0;
        attribute damping : Real = 0.9;
        attribute regulatedRate : RateOfImprovement = 0.0;
        attribute stabilityMargin : Real = 1.0;

        action def regulate :> Action {
            in amplified : AmplifiedRate;
            out feedback : RegulatedFeedback;
        }

        action regulate : regulate {
            in amplified = amplifiedIn.amplified;
            out feedback = feedbackOut.feedback;
        }

        state regulatorStates {
            entry; then Governing;
            state Governing {
                entry action {
                    attribute raw : RateOfImprovement := amplifiedIn.amplified.amplifiedRate;
                    attribute candidate : RateOfImprovement := damping * regulatedRate + (1.0 - damping) * raw;
                    if (candidate > maxRate) { candidate := maxRate; }
                    if (candidate < -maxRate) { candidate := -maxRate; }
                    regulatedRate := candidate;
                    stabilityMargin := 1.0 - abs(regulatedRate) / maxRate;
                    attribute fb : RegulatedFeedback;
                    fb.regulatedRate := regulatedRate;
                    fb.stabilityMargin := stabilityMargin;
                    fb.stable := stabilityMargin >= stabilityThreshold;
                    send fb to feedbackOut.feedback;
                }
                do action wait {
                    // await next amplified input
                }
                transition then Governing;
            }
        }
    }

    part def DynamicPerformanceOptimizationSystem {
        part targetSystem : TargetSystem {
            port feedbackIn : RegulatedFeedbackInPort;
            port dataOut : PerformanceDataOutPort;
        }
        part monitor : PerformanceMonitor {
            port dataOut : PerformanceDataOutPort;
            port feedbackIn : RegulatedFeedbackInPort;
        }
        part analyzer : ChangeAnalyzer {
            port dataIn : PerformanceDataInPort;
            port reportOut : AccelerationReportOutPort;
        }
        part controller : AmplificationController {
            port reportIn : AccelerationReportInPort;
            port commandOut : OptimizationCommandOutPort;
        }
        part amplifier : RateAmplifier {
            port commandIn : OptimizationCommandInPort;
            port rateIn : AccelerationReportInPort;
            port amplifiedOut : AmplifiedRateOutPort;
        }
        part regulator : FeedbackRegulator {
            port amplifiedIn : AmplifiedRateInPort;
            port feedbackOut : RegulatedFeedbackOutPort;
        }

        connection targetSystem.dataOut flow to monitor.feedbackIn;
        connection monitor.dataOut flow to analyzer.dataIn;
        connection analyzer.reportOut flow to controller.reportIn;
        connection analyzer.reportOut flow to amplifier.rateIn;
        connection controller.commandOut flow to amplifier.commandIn;
        connection amplifier.amplifiedOut flow to regulator.amplifiedIn;
        connection regulator.feedbackOut flow to targetSystem.feedbackIn;
        connection regulator.feedbackOut flow to monitor.feedbackIn;
    }

    requirement def PerformanceOptimizationRequirement {
        doc "The dynamic performance optimization system shall autonomously create and manage self-reinforcing cycles of improvement."
    }

    requirement def MonitoringRequirement :> PerformanceOptimizationRequirement {
        doc "The Performance Monitor shall continuously gather real-time throughput and efficiency data from the target system."
        subject monitor : PerformanceMonitor;
        objective {
            doc "Throughput and efficiency are sampled at a configurable interval."
        }
    }

    requirement def AnalysisRequirement :> PerformanceOptimizationRequirement {
        doc "The Change Analyzer shall compute the current rate of improvement and detect whether that rate is accelerating."
        subject analyzer : ChangeAnalyzer;
        attribute minWindow : Integer = 2;
        constraint { size(analyzer.history.samples) >= minWindow }
    }

    requirement def AmplificationTriggerRequirement :> PerformanceOptimizationRequirement {
        doc "When positive acceleration is detected, the Amplification Controller shall issue an optimization command to the Rate Amplifier."
        subject controller : AmplificationController;
        constraint {
            controller.reportIn.report.positiveAcceleration implies
            controller.commandOut.command.targetFactor > 1.0
        }
    }

    requirement def RateBoostRequirement :> PerformanceOptimizationRequirement {
        doc "The Rate Amplifier shall multiply the current rate of improvement by the commanded amplification factor."
        subject amplifier : RateAmplifier;
        constraint {
            amplifier.amplifiedOut.amplified.amplifiedRate ==
            amplifier.rateIn.report.currentRate * amplifier.appliedFactor
        }
    }

    requirement def StabilityRequirement :> PerformanceOptimizationRequirement {
        doc "The Feedback Regulator shall moderate the amplified rate so that the feedback loop remains stable and productive."
        subject regulator : FeedbackRegulator;
        constraint { regulator.feedbackOut.feedback.stable == true }
        constraint { abs(regulator.feedbackOut.feedback.regulatedRate) <= regulator.maxRate }
    }

    requirement def TargetAccelerationRequirement :> PerformanceOptimizationRequirement {
        doc "The system shall achieve and maintain a target rate of acceleration, compounding small positive changes into significant performance growth."
        subject system : DynamicPerformanceOptimizationSystem;
        attribute targetAcceleration : AccelerationValue = 0.01;
        constraint {
            system.analyzer.reportOut.report.acceleration >= targetAcceleration
        }
    }

    requirement DynamicPerformanceOptimizationRequirements {
        satisfy MonitoringRequirement by monitor;
        satisfy AnalysisRequirement by analyzer;
        satisfy AmplificationTriggerRequirement by controller;
        satisfy RateBoostRequirement by amplifier;
        satisfy StabilityRequirement by regulator;
        satisfy TargetAccelerationRequirement by DynamicPerformanceOptimizationSystem;
    }
}
