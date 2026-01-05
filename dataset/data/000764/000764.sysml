package ShuntCheckSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ResistanceValue :> ISQ::ResistanceValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialDifferenceValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def PercentValue :> Real;
    
    enum def ShuntCondition {
        normal;
        degraded;
        open;
        shorted;
    }
    
    attribute def DiagnosticResult {
        attribute condition : ShuntCondition;
        attribute measuredResistance : ResistanceValue;
        attribute deviationPercent : PercentValue;
        attribute testPassed : Boolean;
        attribute timestamp : TimeValue;
    }
    
    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def DiagnosticPort {
        out result : DiagnosticResult;
        in testTrigger : Boolean;
    }
    
    part def ShuntResistor {
        doc /* Precision current-sensing resistor element under test */
        attribute nominalResistance : ResistanceValue;
        attribute tolerancePercent : PercentValue;
        port terminalA : ElectricalPort;
        port terminalB : ElectricalPort;
    }
    
    part def PrecisionCurrentSource {
        doc /* Generates calibrated test current for shunt verification */
        attribute testCurrentLevel : CurrentValue;
        port output : ElectricalPort;
        
        action generateTestCurrent {
            in commandedCurrent : CurrentValue;
            out appliedCurrent : CurrentValue;
        }
    }
    
    part def VoltageMonitor {
        doc /* Measures voltage drop across shunt terminals */
        port positiveInput : ElectricalPort;
        port negativeInput : ElectricalPort;
        out measuredVoltage : VoltageValue;
        
        action measureVoltageDrop {
            in vPlus : VoltageValue;
            in vMinus : VoltageValue;
            out voltageDrop : VoltageValue;
        }
    }
    
    part def CurrentMonitor {
        doc /* Verifies actual test current magnitude */
        port input : ElectricalPort;
        out measuredCurrent : CurrentValue;
        
        action measureCurrent {
            out current : CurrentValue;
        }
    }
    
    part def DiagnosticProcessor {
        doc /* Analyzes measurements and determines shunt health status */
        in voltage : VoltageValue;
        in current : CurrentValue;
        in nominalResistance : ResistanceValue;
        in tolerance : PercentValue;
        out diagnosticResult : DiagnosticResult;
        
        action computeResistance {
            in v : VoltageValue;
            in i : CurrentValue;
            out r : ResistanceValue;
        }
        
        action evaluateDeviation {
            in measured : ResistanceValue;
            in nominal : ResistanceValue;
            out deviationPercent : PercentValue;
        }
        
        action classifyCondition {
            in deviation : PercentValue;
            in tolerance : PercentValue;
            out condition : ShuntCondition;
        }
    }
    
    requirement def ShuntAccuracyRequirement {
        doc /* The shunt resistor shall maintain its specified resistance within tolerance to ensure accurate current measurement in the primary circuit. */
        
        subject shunt : ShuntResistor;
        
        require constraint resistanceStability {
            doc /* Measured resistance shall remain within specified tolerance of nominal value. */
        }
    }
    
    requirement def DiagnosticCapabilityRequirement {
        doc /* The ShuntCheck system shall detect and classify shunt degradation, open circuits, and short circuits with high reliability. */
        
        require constraint detectionReliability {
            doc /* System shall correctly identify shunt condition with 99% accuracy. */
        }
    }
    
    requirement def TestSpeedRequirement {
        doc /* The ShuntCheck system shall complete a full diagnostic cycle within 1 second to minimize disruption to monitored systems. */
        
        require constraint testDuration {
            doc /* Total test time from initiation to result output shall not exceed 1.0 second. */
        }
    }
    
    action def ExecuteShuntDiagnostic {
        doc /* Primary diagnostic workflow that applies test current, measures response, and evaluates shunt condition */
        
        in testCurrent : CurrentValue;
        in expectedResistance : ResistanceValue;
        in allowedTolerance : PercentValue;
        out finalResult : DiagnosticResult;
        
        first start;
        
        then action initializeDiagnostic {
            out ready : Boolean;
        }
        
        then action applyTestCurrent {
            in current : CurrentValue = testCurrent;
            out currentApplied : Boolean;
        }
        
        then action acquireVoltage {
            out voltage : VoltageValue;
        }
        
        then action acquireCurrent {
            out current : CurrentValue;
        }
        
        then action calculateResistance {
            in v : VoltageValue = acquireVoltage.voltage;
            in i : CurrentValue = acquireCurrent.current;
            out resistance : ResistanceValue;
        }
        
        then action computeDeviation {
            in measured : ResistanceValue = calculateResistance.resistance;
            in nominal : ResistanceValue = expectedResistance;
            out deviation : PercentValue;
        }
        
        then decide;
            if computeDeviation.deviation > allowedTolerance * 2.0 then classifyAsOpen;
            if computeDeviation.deviation < -allowedTolerance * 2.0 then classifyAsShorted;
            if computeDeviation.deviation > allowedTolerance and 
               computeDeviation.deviation <= allowedTolerance * 2.0 then classifyAsDegraded;
            if computeDeviation.deviation >= -allowedTolerance and 
               computeDeviation.deviation <= allowedTolerance then classifyAsNormal;
        
        action classifyAsOpen {
            then assign finalResult := DiagnosticResult {
                condition = ShuntCondition::open;
                measuredResistance = calculateResistance.resistance;
                deviationPercent = computeDeviation.deviation;
                testPassed = false;
            }
            then reportResult;
        }
        
        action classifyAsShorted {
            then assign finalResult := DiagnosticResult {
                condition = ShuntCondition::shorted;
                measuredResistance = calculateResistance.resistance;
                deviationPercent = computeDeviation.deviation;
                testPassed = false;
            }
            then reportResult;
        }
        
        action classifyAsDegraded {
            then assign finalResult := DiagnosticResult {
                condition = ShuntCondition::degraded;
                measuredResistance = calculateResistance.resistance;
                deviationPercent = computeDeviation.deviation;
                testPassed = false;
            }
            then reportResult;
        }
        
        action classifyAsNormal {
            then assign finalResult := DiagnosticResult {
                condition = ShuntCondition::normal;
                measuredResistance = calculateResistance.resistance;
                deviationPercent = computeDeviation.deviation;
                testPassed = true;
            }
            then reportResult;
        }
        
        action reportResult;
        then done;
    }
    
    part def ShuntCheckSystem;
    
    part shuntCheckSystem : ShuntCheckSystem {
        doc /* 
            The ShuntCheck system performs automated diagnostic testing of precision 
            current-sensing shunt resistors used in power monitoring and control applications. 
            Its primary function is to verify the electrical integrity and accuracy of shunt 
            resistors by applying a calibrated test current, measuring the resulting voltage 
            drop, calculating the actual resistance, and comparing it against the expected 
            nominal value to detect degradation, open circuits, or short circuits that could 
            compromise current measurement accuracy in critical systems.
        */
        
        attribute nominalShuntResistance : ResistanceValue;
        attribute testCurrentMagnitude : CurrentValue;
        attribute tolerancePercent : PercentValue;
        
        part shuntUnderTest : ShuntResistor {
            attribute nominalResistance = shuntCheckSystem.nominalShuntResistance;
            attribute tolerancePercent = shuntCheckSystem.tolerancePercent;
        }
        
        part testCurrentSource : PrecisionCurrentSource {
            attribute testCurrentLevel = shuntCheckSystem.testCurrentMagnitude;
        }
        
        part voltmeter : VoltageMonitor;
        
        part ammeter : CurrentMonitor;
        
        part processor : DiagnosticProcessor;
        
        port diagnosticInterface : DiagnosticPort;
        
        connection currentPath 
            connect testCurrentSource.output to shuntUnderTest.terminalA;
        
        connection voltagePositive 
            connect shuntUnderTest.terminalA to voltmeter.positiveInput;
        
        connection voltageNegative 
            connect shuntUnderTest.terminalB to voltmeter.negativeInput;
        
        connection currentMonitoring 
            connect shuntUnderTest.terminalB to ammeter.input;
        
        perform action diagnosticCycle : ExecuteShuntDiagnostic {
            in testCurrent = shuntCheckSystem.testCurrentMagnitude;
            in expectedResistance = shuntCheckSystem.nominalShuntResistance;
            in allowedTolerance = shuntCheckSystem.tolerancePercent;
            out finalResult;
        }
        
        satisfy ShuntAccuracyRequirement by shuntUnderTest;
        satisfy DiagnosticCapabilityRequirement by processor;
        satisfy TestSpeedRequirement by diagnosticCycle;
    }
}
