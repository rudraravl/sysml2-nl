package ShuntCheck {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        enum def ConditionKind {
            normal;
            degraded;
            open;
            shorted;
        }

        enum def VerdictKind {
            pass;
            fail;
        }

        item def CurrentInjection {
            attribute magnitude : ISQ::electricCurrent;
        }

        item def VoltageMeasurement {
            attribute value : ISQ::electricPotential;
        }

        item def CurrentMeasurement {
            attribute value : ISQ::electricCurrent;
        }

        item def DiagnosticReport {
            attribute measuredResistance : ISQ::resistance;
            attribute idealResistance : ISQ::resistance;
            attribute deviationPercent : Real;
            attribute condition : ConditionKind;
            attribute verdict : VerdictKind;
            attribute timestamp : ISQ::time;
        }

        attribute def ToleranceSpec {
            attribute normalTolerancePercent : Real = 1.0;
            attribute degradedThresholdPercent : Real = 5.0;
            attribute openThresholdRatio : Real = 10.0;
            attribute shortedThresholdRatio : Real = 0.1;
        }

        port def CurrentInjectionPort {
            in injection : CurrentInjection;
        }

        port def VoltageReadingPort {
            in reading : VoltageMeasurement;
        }

        port def CurrentReadingPort {
            in reading : CurrentMeasurement;
        }

        port def ReportPort {
            in report : DiagnosticReport;
        }

        part def ShuntResistor {
            attribute idealResistance : ISQ::resistance;
            attribute actualResistance : ISQ::resistance;
            attribute tolerance : ToleranceSpec;
            port currentIn : CurrentInjectionPort;
            port voltageDropOut : ~VoltageReadingPort {
                out :>> reading;
            }
        }

        part def PrecisionCurrentSource {
            attribute nominalCurrent : ISQ::electricCurrent;
            port currentOut : ~CurrentInjectionPort {
                out :>> injection;
            }
        }

        part def CurrentMonitor {
            port currentIn : CurrentInjectionPort;
            port currentOut : ~CurrentInjectionPort {
                out :>> injection;
            }
            port readingOut : ~CurrentReadingPort {
                out :>> reading;
            }
        }

        part def VoltageMonitor {
            port voltageIn : VoltageReadingPort;
            port readingOut : ~VoltageReadingPort {
                out :>> reading;
            }
        }

        state def DiagnosticProcessorStates {
            state idle;
            transition from idle to testing;
            state testing;
            transition from testing to analyzing;
            state analyzing;
            transition from analyzing to reporting;
            state reporting;
            transition from reporting to idle;
        }

        part def DiagnosticProcessor {
            port currentIn : CurrentReadingPort;
            port voltageIn : VoltageReadingPort;
            port reportOut : ~ReportPort {
                out :>> report;
            }
            attribute tolerance : ToleranceSpec;
            exhibit diagnosticStates : DiagnosticProcessorStates;
        }

        part def ShuntCheckSystem {
            port reportPort : ReportPort;
            ref part shuntUnderTest : ShuntResistor;
            part precisionCurrentSource : PrecisionCurrentSource;
            part currentMonitor : CurrentMonitor;
            part voltageMonitor : VoltageMonitor;
            part diagnosticProcessor : DiagnosticProcessor;

            interface currentSourceToCurrentMonitor
                connect precisionCurrentSource.currentOut to currentMonitor.currentIn {
                flow currentInjectionFlow of CurrentInjection
                    from precisionCurrentSource.currentOut.injection to currentMonitor.currentIn.injection;
            }
            interface currentMonitorToShunt
                connect currentMonitor.currentOut to shuntUnderTest.currentIn {
                flow currentInjectionFlow of CurrentInjection
                    from currentMonitor.currentOut.injection to shuntUnderTest.currentIn.injection;
            }
            interface shuntToVoltageMonitor
                connect shuntUnderTest.voltageDropOut to voltageMonitor.voltageIn {
                flow voltageFlow of VoltageMeasurement
                    from shuntUnderTest.voltageDropOut.reading to voltageMonitor.voltageIn.reading;
            }
            interface currentReadingToProcessor
                connect currentMonitor.readingOut to diagnosticProcessor.currentIn {
                flow currentReadingFlow of CurrentMeasurement
                    from currentMonitor.readingOut.reading to diagnosticProcessor.currentIn.reading;
            }
            interface voltageReadingToProcessor
                connect voltageMonitor.readingOut to diagnosticProcessor.voltageIn {
                flow voltageReadingFlow of VoltageMeasurement
                    from voltageMonitor.readingOut.reading to diagnosticProcessor.voltageIn.reading;
            }
            interface reportToPort
                connect diagnosticProcessor.reportOut to reportPort {
                flow reportFlow of DiagnosticReport
                    from diagnosticProcessor.reportOut.report to reportPort.report;
            }
        }

        action def DiagnosticTestSequence {
            in part shunt : ShuntResistor;
            in nominalCurrent : ISQ::electricCurrent;
            in toleranceSpec : ToleranceSpec;
            out diagnosticReport : DiagnosticReport;

            action injectCurrent {
                out injection : CurrentInjection = new CurrentInjection(magnitude = nominalCurrent);
            }
            then action measureVoltageDrop {
                in injection : CurrentInjection = injectCurrent.injection;
                out voltage : ISQ::electricPotential = injection.magnitude * shunt.actualResistance;
            }
            then action measureCurrent {
                in injection : CurrentInjection = injectCurrent.injection;
                out current : ISQ::electricCurrent = injection.magnitude;
            }
            then action calculateResistance {
                in voltage : ISQ::electricPotential = measureVoltageDrop.voltage;
                in current : ISQ::electricCurrent = measureCurrent.current;
                out resistance : ISQ::resistance = voltage / current;
            }
            then action calculateDeviation {
                in resistance : ISQ::resistance = calculateResistance.resistance;
                in ideal : ISQ::resistance = shunt.idealResistance;
                out deviationPercent : Real = (resistance - ideal) / ideal * 100.0;
                out absDeviationPercent : Real =
                    if (resistance - ideal) >= 0 then (resistance - ideal) / ideal * 100.0
                    else (ideal - resistance) / ideal * 100.0 endif;
            }
            then action classifyCondition {
                in resistance : ISQ::resistance = calculateResistance.resistance;
                in ideal : ISQ::resistance = shunt.idealResistance;
                in absDeviationPercent : Real = calculateDeviation.absDeviationPercent;
                in tolerance : ToleranceSpec = toleranceSpec;
                out condition : ConditionKind =
                    if resistance > tolerance.openThresholdRatio * ideal then ConditionKind::open
                    else if resistance < tolerance.shortedThresholdRatio * ideal then ConditionKind::shorted
                    else if absDeviationPercent <= tolerance.normalTolerancePercent then ConditionKind::normal
                    else ConditionKind::degraded endif endif endif;
            }
            then action generateReport {
                in resistance : ISQ::resistance = calculateResistance.resistance;
                in ideal : ISQ::resistance = shunt.idealResistance;
                in deviationPercent : Real = calculateDeviation.deviationPercent;
                in condition : ConditionKind = classifyCondition.condition;
                in verdict : VerdictKind =
                    if condition == ConditionKind::normal then VerdictKind::pass else VerdictKind::fail endif;
                out report : DiagnosticReport = new DiagnosticReport(
                    measuredResistance = resistance,
                    idealResistance = ideal,
                    deviationPercent = deviationPercent,
                    condition = condition,
                    verdict = verdict,
                    timestamp = 0 [SI::s]
                );
            }
            return diagnosticReport : DiagnosticReport = generateReport.report;
        }

        requirement def DiagnosticDurationRequirement {
            attribute maxDuration : Real;
            attribute actualDuration : Real;
            doc /* The complete diagnostic test cycle shall complete in under one second. */
            require constraint { actualDuration < maxDuration }
        }

        requirement def MeasurementAccuracyRequirement {
            attribute tolerancePercent : Real;
            doc /* The system shall measure shunt resistance within the specified tolerance. */
        }

        requirement def FaultDetectionRequirement {
            doc /* The system shall detect open-circuit and short-circuit fault conditions. */
        }

        requirement def DiagnosticReportRequirement {
            doc /* The system shall output a diagnostic report with measured resistance, deviation, condition, verdict, and timestamp. */
        }

        verification def ShuntDiagnosticVerificationDef {
            objective diagVerificationObjective {
                verify requirement durationVerificationReq : DiagnosticDurationRequirement;
                verify requirement accuracyVerificationReq : MeasurementAccuracyRequirement;
                verify requirement faultDetectionVerificationReq : FaultDetectionRequirement;
                verify requirement reportVerificationReq : DiagnosticReportRequirement;
            }
        }

        individual def NormalShunt :> ShuntResistor;
        individual def DegradedShunt :> ShuntResistor;
        individual def OpenShunt :> ShuntResistor;
        individual def ShortedShunt :> ShuntResistor;
        individual def TestSystem :> ShuntCheckSystem;
    }

    package Usages {
        private import Definitions::*;

        requirement <'D1'> durationReq : DiagnosticDurationRequirement {
            subject system : ShuntCheckSystem;
            doc /* The diagnostic test shall complete in under one second. */
            :>> maxDuration = 1.0;
            :>> actualDuration = 0.5;
        }

        requirement <'D2'> accuracyReq : MeasurementAccuracyRequirement {
            subject system : ShuntCheckSystem;
            doc /* Resistance measurement shall be within one percent tolerance. */
            :>> tolerancePercent = 1.0;
        }

        requirement <'D3'> faultDetectionReq : FaultDetectionRequirement {
            subject system : ShuntCheckSystem;
            doc /* The system shall detect open and shorted shunt conditions. */
        }

        requirement <'D4'> reportReq : DiagnosticReportRequirement {
            subject system : ShuntCheckSystem;
            doc /* The system shall produce a diagnostic report with all required fields. */
        }

        part shuntCheckSystem : ShuntCheckSystem {
            ref part :>> shuntUnderTest : ShuntResistor {
                :>> idealResistance = 0.1 [SI::Ohm];
                :>> actualResistance = 0.1001 [SI::Ohm];
            }
            part :>> precisionCurrentSource : PrecisionCurrentSource {
                :>> nominalCurrent = 10 [SI::A];
            }
            part :>> currentMonitor : CurrentMonitor;
            part :>> voltageMonitor : VoltageMonitor;
            part :>> diagnosticProcessor : DiagnosticProcessor {
                :>> tolerance = shuntUnderTest.tolerance;
            }

            perform diagnosticTest : DiagnosticTestSequence {
                in part :>> shunt = shuntUnderTest;
                in :>> nominalCurrent = precisionCurrentSource.nominalCurrent;
                in :>> toleranceSpec = shuntUnderTest.tolerance;
            }
        }

        part satisfactionContext {
            ref system : ShuntCheckSystem = shuntCheckSystem;
            satisfy requirement durationReq : DiagnosticDurationRequirement by system;
            satisfy requirement accuracyReq : MeasurementAccuracyRequirement by system;
            satisfy requirement faultDetectionReq : FaultDetectionRequirement by system;
            satisfy requirement reportReq : DiagnosticReportRequirement by system;
        }

        individual testSystem : TestSystem :> shuntCheckSystem {
            timeslice testNormalCase {
                ref individual :>> shuntUnderTest : NormalShunt {
                    :>> idealResistance = 0.1 [SI::Ohm];
                    :>> actualResistance = 0.1001 [SI::Ohm];
                }
            }
            then timeslice testDegradedCase {
                ref individual :>> shuntUnderTest : DegradedShunt {
                    :>> idealResistance = 0.1 [SI::Ohm];
                    :>> actualResistance = 0.103 [SI::Ohm];
                }
            }
            then timeslice testOpenCase {
                ref individual :>> shuntUnderTest : OpenShunt {
                    :>> idealResistance = 0.1 [SI::Ohm];
                    :>> actualResistance = 1000000 [SI::Ohm];
                }
            }
            then timeslice testShortedCase {
                ref individual :>> shuntUnderTest : ShortedShunt {
                    :>> idealResistance = 0.1 [SI::Ohm];
                    :>> actualResistance = 0.000001 [SI::Ohm];
                }
            }
        }

        verification diagnosticVerification : ShuntDiagnosticVerificationDef {
            subject systemUnderTest : TestSystem = testSystem;
            objective diagVerificationObjective {
                verify durationReq :>> durationVerificationReq;
                verify accuracyReq :>> accuracyVerificationReq;
                verify faultDetectionReq :>> faultDetectionVerificationReq;
                verify reportReq :>> reportVerificationReq;
            }
            action runVerification {
                in part :>> systemUnderTest;
                out verdict : VerdictKind;
            }
            return verdict : VerdictKind = runVerification.verdict;
        }
    }
}
