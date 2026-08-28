package ShuntCheck {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value types with units ----
    value def Voltage :> Real { 
        attribute unit : String = "V"; 
    }
    value def Current :> Real { 
        attribute unit : String = "A"; 
    }
    value def Resistance :> Real { 
        attribute unit : String = "Ω"; 
    }
    value def Percent :> Real { 
        attribute unit : String = "%"; 
    }
    value def TimeDuration :> Real { 
        attribute unit : String = "s"; 
    }
    value def DateTime :> String;

    // ---- Enumerations ----
    enum def ShuntCondition {
        normal;
        degraded;
        open;
        shorted;
    }
    enum def PassFail {
        pass;
        fail;
    }

    // ---- Item definitions ----
    item def VoltageReading {
        attribute voltage : Voltage;
        attribute timestamp : DateTime;
    }
    item def CurrentReading {
        attribute current : Current;
        attribute timestamp : DateTime;
    }
    item def DiagnosticReport {
        attribute measuredResistance : Resistance;
        attribute idealResistance : Resistance;
        attribute deviationPercent : Percent;
        attribute condition : ShuntCondition;
        attribute result : PassFail;
        attribute timestamp : DateTime;
    }

    // ---- Port definitions ----
    port def ElectricalPort {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    port def MeasurementPort {
        in voltageReading : VoltageReading;
        in currentReading : CurrentReading;
    }
    port def ReportPort {
        out report : DiagnosticReport;
    }
    port def CommandPort {
        in startTest : Boolean;
    }

    // ---- Shunt resistor under test ----
    part def ShuntResistor {
        attribute idealResistance : Resistance = 0.001 [Ω];
        attribute tolerancePercent : Percent = 1.0 [%];
        attribute degradedThresholdPercent : Percent = 2.0 [%];
        attribute openThresholdResistance : Resistance = 1000.0 [Ω];
        attribute shortedThresholdResistance : Resistance = 0.0001 [Ω];

        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;

        attribute actualResistance : Resistance;

        compute calcActual {
            in v : Voltage;
            in i : Current;
            out r : Resistance = v / i;
        }
    }

    // ---- Precision current source ----
    part def PrecisionCurrentSource {
        attribute calibratedCurrent : Current = 10.0 [A];
        attribute currentAccuracyPercent : Percent = 0.05 [%];
        attribute outputEnabled : Boolean = false;

        port positiveOutput : ElectricalPort;
        port negativeOutput : ElectricalPort;
        port commandIn : CommandPort;

        action def generateCurrent {
            in target : Current;
            out delivered : Current;
        }

        perform generateCurrent {
            in target = calibratedCurrent;
            out delivered = positiveOutput.current;
        }

        state def SourceStates {
            entry; then Off;
            state Off;
            transition off_to_on 
                from Off to On 
                when commandIn.startTest;
            state On {
                entry { positiveOutput.current = calibratedCurrent; }
            }
            transition on_to_off 
                from On to Off 
                when !commandIn.startTest;
        }
    }

    // ---- Voltage monitor ----
    part def VoltageMonitor {
        attribute inputRange : Voltage = 1.0 [V];
        attribute resolution : Voltage = 0.000001 [V];
        attribute sampleInterval : TimeDuration = 0.01 [s];

        port positiveProbe : ElectricalPort;
        port negativeProbe : ElectricalPort;
        port voltageOut : >> MeasurementPort;

        action def measureVoltage {
            in vA : Voltage;
            in vB : Voltage;
            out reading : VoltageReading;
        }

        perform measureVoltage {
            in vA = positiveProbe.voltage;
            in vB = negativeProbe.voltage;
            out reading = voltageOut.voltageReading;
        }
    }

    // ---- Current monitor ----
    part def CurrentMonitor {
        attribute inputRange : Current = 20.0 [A];
        attribute resolution : Current = 0.0001 [A];
        attribute sampleInterval : TimeDuration = 0.01 [s];

        port senseInput : ElectricalPort;
        port currentOut : >> MeasurementPort;

        action def measureCurrent {
            in i : Current;
            out reading : CurrentReading;
        }

        perform measureCurrent {
            in i = senseInput.current;
            out reading = currentOut.currentReading;
        }
    }

    // ---- Diagnostic processor ----
    part def DiagnosticProcessor {
        attribute idealResistance : Resistance = 0.001 [Ω];
        attribute tolerancePercent : Percent = 1.0 [%];
        attribute degradedThresholdPercent : Percent = 2.0 [%];
        attribute openThresholdResistance : Resistance = 1000.0 [Ω];
        attribute shortedThresholdResistance : Resistance = 0.0001 [Ω];
        attribute maxTestCycleTime : TimeDuration = 1.0 [s];

        port measurementIn : MeasurementPort;
        port reportOut : ReportPort;
        port commandOut : CommandPort;

        attribute measuredVoltage : Voltage;
        attribute measuredCurrent : Current;
        attribute measuredResistance : Resistance;
        attribute deviationPercent : Percent;
        attribute condition : ShuntCondition;
        attribute result : PassFail;
        attribute testStartTime : DateTime;
        attribute testEndTime : DateTime;

        action def calculateResistance {
            in v : Voltage;
            in i : Current;
            out r : Resistance;
        }
        action def calculateDeviation {
            in measured : Resistance;
            in ideal : Resistance;
            out deviation : Percent;
        }
        action def classifyCondition {
            in measured : Resistance;
            in ideal : Resistance;
            in deviation : Percent;
            in tol : Percent;
            in degradedThresh : Percent;
            in openThresh : Resistance;
            in shortedThresh : Resistance;
            out condition : ShuntCondition;
            out result : PassFail;
        }
        action def generateReport {
            in measured : Resistance;
            in ideal : Resistance;
            in deviation : Percent;
            in condition : ShuntCondition;
            in result : PassFail;
            in timestamp : DateTime;
            out report : DiagnosticReport;
        }

        state def DiagnosticStates {
            entry; then Idle;
            state Idle {
                entry { commandOut.startTest = false; }
            }
            transition idle_to_testing 
                from Idle to Testing 
                when measurementIn.voltageReading.timestamp != null 
                or measurementIn.currentReading.timestamp != null;

            state Testing {
                entry { 
                    commandOut.startTest = true; 
                    testStartTime = now(); 
                }
                do {
                    measuredVoltage = measurementIn.voltageReading.voltage;
                    measuredCurrent = measurementIn.currentReading.current;
                }
            }
            transition testing_to_calculating 
                from Testing to Calculating 
                when measuredVoltage != null and measuredCurrent != null;

            state Calculating {
                do {
                    measuredResistance = measuredVoltage / measuredCurrent;
                    deviationPercent = ((measuredResistance - idealResistance) / idealResistance) * 100.0;
                }
            }
            transition calculating_to_classifying 
                from Calculating to Classifying 
                when measuredResistance != null;

            state Classifying {
                do {
                    if measuredResistance >= openThresholdResistance {
                        condition = ShuntCondition::open;
                        result = PassFail::fail;
                    } else if measuredResistance <= shortedThresholdResistance {
                        condition = ShuntCondition::shorted;
                        result = PassFail::fail;
                    } else if abs(deviationPercent) <= tolerancePercent {
                        condition = ShuntCondition::normal;
                        result = PassFail::pass;
                    } else if abs(deviationPercent) <= degradedThresholdPercent {
                        condition = ShuntCondition::degraded;
                        result = PassFail::fail;
                    } else {
                        condition = ShuntCondition::degraded;
                        result = PassFail::fail;
                    }
                }
            }
            transition classifying_to_reporting 
                from Classifying to Reporting 
                when condition != null;

            state Reporting {
                entry { testEndTime = now(); }
                do {
                    reportOut.report = DiagnosticReport {
                        measuredResistance = measuredResistance;
                        idealResistance = idealResistance;
                        deviationPercent = deviationPercent;
                        condition = condition;
                        result = result;
                        timestamp = testEndTime;
                    };
                }
            }
            transition reporting_to_idle 
                from Reporting to Idle 
                when reportOut.report != null;
        }

        perform DiagnosticStates;
    }

    // ---- Top-level ShuntCheck system ----
    part def ShuntCheckSystem {
        part shuntUnderTest : ShuntResistor {
            attribute idealResistance = 0.001 [Ω];
        }
        part currentSource : PrecisionCurrentSource {
            attribute calibratedCurrent = 10.0 [A];
        }
        part voltageMonitor : VoltageMonitor;
        part currentMonitor : CurrentMonitor;
        part diagnosticProcessor : DiagnosticProcessor {
            attribute idealResistance = shuntUnderTest.idealResistance;
        }

        // Electrical connections forming the test circuit
        connection connectSourcePositiveToShuntA 
            from currentSource.positiveOutput 
            to shuntUnderTest.terminalA;
        connection connectShuntBToCurrentMonitor 
            from shuntUnderTest.terminalB 
            to currentMonitor.senseInput;
        connection connectCurrentMonitorToSourceNegative 
            from currentMonitor.senseInput 
            to currentSource.negativeOutput;

        // Voltage monitor probes across shunt terminals
        connection connectVoltageProbeA 
            from shuntUnderTest.terminalA 
            to voltageMonitor.positiveProbe;
        connection connectVoltageProbeB 
            from shuntUnderTest.terminalB 
            to voltageMonitor.negativeProbe;

        // Measurement data flows to processor
        connection flow voltageDataFlow 
            from voltageMonitor.voltageOut 
            to diagnosticProcessor.measurementIn;
        connection flow currentDataFlow 
            from currentMonitor.currentOut 
            to diagnosticProcessor.measurementIn;

        // Command flow from processor to current source
        connection flow commandFlow 
            from diagnosticProcessor.commandOut 
            to currentSource.commandIn;

        // Report output port
        port systemReportOut : ReportPort;
        connection flow reportFlow 
            from diagnosticProcessor.reportOut 
            to systemReportOut;
    }

    // ---- Requirements ----
    requirement def TestCycleTimeRequirement {
        attribute maxCycleTime : TimeDuration = 1.0 [s];
        subject : ShuntCheckSystem;
        objective {
            doc "The complete diagnostic test cycle shall complete in under one second.";
            check subject.diagnosticProcessor.testEndTime - subject.diagnosticProcessor.testStartTime <= maxCycleTime;
        }
    }

    requirement def ResistanceAccuracyRequirement {
        attribute tolerance : Percent = 1.0 [%];
        subject : ShuntCheckSystem;
        objective {
            doc "The system shall classify a shunt as normal when measured resistance is within tolerance of the ideal value.";
            check subject.diagnosticProcessor.deviationPercent <= tolerance;
        }
    }

    requirement def ConditionClassificationRequirement {
        subject : ShuntCheckSystem;
        objective {
            doc "The system shall classify the shunt condition as one of: normal, degraded, open, or shorted.";
            check subject.diagnosticProcessor.condition in ShuntCondition;
        }
    }

    requirement def DiagnosticReportRequirement {
        subject : ShuntCheckSystem;
        objective {
            doc "The system shall output a diagnostic report containing measured resistance, deviation percentage, pass/fail result, condition, and timestamp.";
            check subject.systemReportOut.report != null 
                and subject.systemReportOut.report.measuredResistance != null
                and subject.systemReportOut.report.deviationPercent != null
                and subject.systemReportOut.report.result != null
                and subject.systemReportOut.report.condition != null
                and subject.systemReportOut.report.timestamp != null;
        }
    }

    requirement def CurrentSourceCalibrationRequirement {
        attribute accuracy : Percent = 0.05 [%];
        subject : ShuntCheckSystem;
        objective {
            doc "The precision current source shall deliver current accurate to within 0.05% of the calibrated value.";
            check abs(subject.currentSource.positiveOutput.current - subject.currentSource.calibratedCurrent) 
                / subject.currentSource.calibratedCurrent * 100.0 <= accuracy;
        }
    }

    requirement def VoltageMeasurementResolutionRequirement {
        attribute minResolution : Voltage = 0.000001 [V];
        subject : ShuntCheckSystem;
        objective {
            doc "The voltage monitor shall resolve voltage drops of at least 1 microvolt.";
            check subject.voltageMonitor.resolution <= minResolution;
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfyTestCycleTime by ShuntCheckSystem satisfy TestCycleTimeRequirement;
    satisfaction satisfyResistanceAccuracy by ShuntCheckSystem satisfy ResistanceAccuracyRequirement;
    satisfaction satisfyConditionClassification by ShuntCheckSystem satisfy ConditionClassificationRequirement;
    satisfaction satisfyDiagnosticReport by ShuntCheckSystem satisfy DiagnosticReportRequirement;
    satisfaction satisfyCurrentCalibration by ShuntCheckSystem satisfy CurrentSourceCalibrationRequirement;
    satisfaction satisfyVoltageResolution by ShuntCheckSystem satisfy VoltageMeasurementResolutionRequirement;
}
