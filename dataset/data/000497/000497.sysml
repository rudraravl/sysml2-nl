package RightspotpHIndicatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def pHValue :> Real {
        doc /* pH measurement value ranging from 0 to 14 */
    }
    
    attribute def AccuracyValue :> Real {
        doc /* Measurement accuracy in pH units */
    }
    
    enum def PlacementStatus {
        gastric;
        nonGastric;
        indeterminate;
    }
    
    enum def SystemState {
        idle;
        ready;
        measuring;
        analyzing;
        displaying;
        error;
    }
    
    item def AspirateSample {
        attribute volume : ISQ::VolumeValue;
        attribute pH : pHValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
    }
    
    item def MeasurementResult {
        attribute measuredpH : pHValue;
        attribute placement : PlacementStatus;
        attribute confidence : Real;
        attribute timestamp : ISQ::TimeValue;
    }
    
    port def SampleInputPort {
        in aspirate : AspirateSample;
    }
    
    port def ResultOutputPort {
        out result : MeasurementResult;
    }
    
    port def SensorDataPort {
        out rawpH : pHValue;
        out sampleTemp : ISQ::ThermodynamicTemperatureValue;
    }
    
    port def ProcessedDataPort {
        in sensorpH : pHValue;
        in sensorTemp : ISQ::ThermodynamicTemperatureValue;
        out calibratedpH : pHValue;
    }
    
    part def pHSensorProbe {
        doc /* Electrochemical sensor probe for pH measurement of gastric aspirate */
        
        port sampleInput : SampleInputPort;
        port dataOutput : SensorDataPort;
        
        attribute responseTime : ISQ::TimeValue;
        attribute measurementRange : pHValue[2];
        
        perform action sensepH {
            in sample : AspirateSample;
            out rawReading : pHValue;
            out tempReading : ISQ::ThermodynamicTemperatureValue;
            
            assign rawReading := sample.pH;
            assign tempReading := sample.temperature;
        }
    }
    
    part def SignalProcessor {
        doc /* Processes raw sensor signals and applies calibration */
        
        port sensorInput : ~SensorDataPort;
        port processedOutput : ProcessedDataPort;
        
        attribute calibrationCoefficients : Real[3];
        attribute temperatureCompensation : Boolean;
        
        action def CalibrateReading {
            in rawpH : pHValue;
            in temperature : ISQ::ThermodynamicTemperatureValue;
            out calibratedpH : pHValue;
            
            private attribute tempCompensationFactor : Real;
            
            assign tempCompensationFactor := 1.0 + 0.003 * (temperature.num - 298.15);
            assign calibratedpH := rawpH * tempCompensationFactor;
        }
    }
    
    part def PlacementAnalyzer {
        doc /* Analyzes pH reading to determine tube placement status */
        
        port dataInput : ~ProcessedDataPort;
        
        attribute gastricThreshold : pHValue;
        attribute confidenceThreshold : Real;
        
        action def DeterminePlacement {
            in measuredpH : pHValue;
            out placementStatus : PlacementStatus;
            out confidenceLevel : Real;
            
            first start;
            then decide;
                if measuredpH <= 5.5 then assignGastric;
                if measuredpH > 5.5 and measuredpH <= 6.5 then assignIndeterminate;
                if measuredpH > 6.5 then assignNonGastric;
            
            action assignGastric {
                assign placementStatus := PlacementStatus::gastric;
                assign confidenceLevel := 0.95;
            }
            then done;
            
            action assignIndeterminate {
                assign placementStatus := PlacementStatus::indeterminate;
                assign confidenceLevel := 0.60;
            }
            then done;
            
            action assignNonGastric {
                assign placementStatus := PlacementStatus::nonGastric;
                assign confidenceLevel := 0.90;
            }
            then done;
        }
    }
    
    part def VisualDisplay {
        doc /* Visual display unit showing pH value and placement status */
        
        port resultInput : ~ResultOutputPort;
        
        attribute displayResolution : Real;
        attribute updateRate : ISQ::FrequencyValue;
        
        perform action showResult {
            in result : MeasurementResult;
            
            action displaypH {
                in pHValue : pHValue;
            }
            then action displayStatus {
                in status : PlacementStatus;
            }
            then action displayConfidence {
                in confidence : Real;
            }
        }
    }
    
    part def ControlUnit {
        doc /* Central control unit managing system operation and workflow */
        
        attribute currentState : SystemState;
        attribute measurementCount : Integer;
        
        state machine def ControlStateMachine {
            initial state systemIdle;
            
            state systemIdle {
                entry action {
                    assign currentState := SystemState::idle;
                }
            }
            
            transition idleToReady
                first systemIdle
                accept sampleInserted
                then systemReady;
            
            state systemReady {
                entry action {
                    assign currentState := SystemState::ready;
                }
            }
            
            transition readyToMeasuring
                first systemReady
                accept startMeasurement
                then systemMeasuring;
            
            state systemMeasuring {
                entry action {
                    assign currentState := SystemState::measuring;
                }
                do action performMeasurement;
            }
            
            transition measuringToAnalyzing
                first systemMeasuring
                accept measurementComplete
                then systemAnalyzing;
            
            state systemAnalyzing {
                entry action {
                    assign currentState := SystemState::analyzing;
                }
                do action analyzeData;
            }
            
            transition analyzingToDisplaying
                first systemAnalyzing
                accept analysisComplete
                then systemDisplaying;
            
            state systemDisplaying {
                entry action {
                    assign currentState := SystemState::displaying;
                }
                do action displayResults;
            }
            
            transition displayingToIdle
                first systemDisplaying
                accept resultAcknowledged
                then systemIdle;
            
            transition anyToError
                first systemIdle or systemReady or systemMeasuring or systemAnalyzing or systemDisplaying
                accept errorDetected
                then systemError;
            
            state systemError {
                entry action {
                    assign currentState := SystemState::error;
                }
            }
            
            transition errorToIdle
                first systemError
                accept errorCleared
                then systemIdle;
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'REQ-001'> tubePlacementVerification : FunctionalRequirement {
        doc /* The system shall verify nasogastric tube placement by measuring gastric aspirate pH */
        subject system : RightspotpHIndicator;
    }
    
    requirement <'REQ-002'> gastricDetectionAccuracy : PerformanceRequirement {
        doc /* The system shall identify gastric placement when pH is 5.5 or lower with 95% confidence */
        subject system : RightspotpHIndicator;
        require constraint {
            system.analyzer.gastricThreshold == 5.5
        }
    }
    
    requirement <'REQ-003'> measurementResponseTime : PerformanceRequirement {
        doc /* The system shall provide placement confirmation within 10 seconds of sample introduction */
        subject system : RightspotpHIndicator;
        require constraint {
            system.sensor.responseTime <= 10.0 [SI::s]
        }
    }
    
    requirement <'REQ-004'> measurementAccuracy : PerformanceRequirement {
        doc /* The system shall measure pH with accuracy of ±0.1 pH units */
        subject system : RightspotpHIndicator;
    }
    
    requirement <'REQ-005'> safeOperation : SafetyRequirement {
        doc /* The system shall operate safely in contact with bodily fluids */
        subject system : RightspotpHIndicator;
    }
    
    part def RightspotpHIndicator {
        doc /* 
            RightspotpH Indicator system for verifying nasogastric feeding tube placement.
            
            Primary Function: The system measures the pH level of gastric aspirate to confirm 
            correct placement of nasogastric feeding tubes. By detecting acidic gastric contents 
            (pH ≤ 5.5), the system provides rapid, reliable confirmation that the tube tip is 
            positioned in the stomach rather than the respiratory tract, thereby preventing 
            potentially fatal feeding misadministration.
        */
        
        port sampleInterface : SampleInputPort;
        port resultInterface : ResultOutputPort;
        
        part sensor : pHSensorProbe {
            :>> responseTime = 8.0 [SI::s];
            :>> measurementRange = (0.0, 14.0);
        }
        
        part processor : SignalProcessor {
            :>> calibrationCoefficients = (1.0, 0.0, 0.0);
            :>> temperatureCompensation = true;
        }
        
        part analyzer : PlacementAnalyzer {
            :>> gastricThreshold = 5.5;
            :>> confidenceThreshold = 0.85;
        }
        
        part display : VisualDisplay {
            :>> displayResolution = 0.1;
            :>> updateRate = 2.0 [SI::Hz];
        }
        
        part controller : ControlUnit {
            :>> currentState = SystemState::idle;
            :>> measurementCount = 0;
        }
        
        connection sensorToProcessor connect sensor.dataOutput to processor.sensorInput;
        connection processorToAnalyzer connect processor.processedOutput to analyzer.dataInput;
        connection analyzerToDisplay connect resultInterface to display.resultInput;
        
        perform action verifyTubePlacement {
            doc /* Complete workflow for tube placement verification */
            
            first start;
            
            then action acceptSample {
                in sample : AspirateSample;
            }
            
            then action measurepH : pHSensorProbe::sensepH {
                in sample = acceptSample.sample;
                out rawReading : pHValue;
                out tempReading : ISQ::ThermodynamicTemperatureValue;
            }
            
            then action calibrate : SignalProcessor::CalibrateReading {
                in rawpH = measurepH.rawReading;
                in temperature = measurepH.tempReading;
                out calibratedpH : pHValue;
            }
            
            then action analyze : PlacementAnalyzer::DeterminePlacement {
                in measuredpH = calibrate.calibratedpH;
                out placementStatus : PlacementStatus;
                out confidenceLevel : Real;
            }
            
            then action generateResult {
                in pHValue : pHValue = calibrate.calibratedpH;
                in placement : PlacementStatus = analyze.placementStatus;
                in confidence : Real = analyze.confidenceLevel;
                out finalResult : MeasurementResult;
                
                assign finalResult.measuredpH := pHValue;
                assign finalResult.placement := placement;
                assign finalResult.confidence := confidence;
            }
            
            then action presentResult : VisualDisplay::showResult {
                in result = generateResult.finalResult;
            }
            
            then done;
        }
        
        satisfy tubePlacementVerification;
        satisfy gastricDetectionAccuracy;
        satisfy measurementResponseTime;
        satisfy measurementAccuracy;
        satisfy safeOperation;
    }
    
    part rightspotSystem : RightspotpHIndicator;
}
