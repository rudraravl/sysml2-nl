package VaccineVialMonitorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CumulativeHeatExposure :> Real;
    
    enum def VVMIndicatorState {
        enum safe;
        enum caution;
        enum discard;
    }
    
    item def TemperatureMeasurement {
        attribute temperature : TemperatureValue;
        attribute timestamp : TimeValue;
    }
    
    item def ColorChangeData {
        attribute innerSquareDarkness : Real;
        attribute outerRingDarkness : Real;
    }
    
    attribute def ExposureThresholds {
        attribute cautionThreshold : CumulativeHeatExposure;
        attribute discardThreshold : CumulativeHeatExposure;
    }
    
    port def TemperatureMonitorPort {
        out item tempData : TemperatureMeasurement;
    }
    
    port def IndicatorPort {
        in item colorData : ColorChangeData;
        out item indicatorState : VVMIndicatorState;
    }
    
    part def VaccineVial {
        attribute vaccineType : String;
        attribute volumeCapacity : VolumeValue;
        port thermalInterface : TemperatureMonitorPort;
    }
    
    part def ThermochromicLabel {
        attribute innerSquareDarkness : Real;
        attribute outerRingDarkness : Real;
        attribute baselineInnerDarkness : Real;
        attribute baselineOuterDarkness : Real;
        
        port colorOutput : IndicatorPort;
        
        state thermochromicBehavior {
            entry; then activeMonitoring;
            
            state activeMonitoring {
                entry assign innerSquareDarkness := baselineInnerDarkness;
            }
            
            accept HeatExposureEvent
            if innerSquareDarkness >= outerRingDarkness * 0.9
            then cautionLevel;
            
            state cautionLevel {
                doc /* Inner square approaches outer ring darkness */
            }
            
            accept HeatExposureEvent
            if innerSquareDarkness >= outerRingDarkness
            then discardLevel;
            
            state discardLevel {
                doc /* Inner square matches or exceeds outer ring darkness */
            }
        }
    }
    
    part def ExposureCalculator {
        attribute cumulativeExposure : CumulativeHeatExposure;
        attribute referenceTemperature : TemperatureValue;
        
        action calculateExposure : ComputeHeatExposure {
            in currentTemp : TemperatureMeasurement;
            in refTemp : TemperatureValue;
            inout totalExposure : CumulativeHeatExposure;
            out exposureIncrement : Real;
        }
    }
    
    part def StatusEvaluator {
        attribute thresholds : ExposureThresholds;
        
        action evaluateStatus : DetermineVVMStatus {
            in exposure : CumulativeHeatExposure;
            in thresholds : ExposureThresholds;
            out status : VVMIndicatorState;
        }
    }
    
    action def ComputeHeatExposure {
        in currentTemp : TemperatureMeasurement;
        in refTemp : TemperatureValue;
        inout totalExposure : CumulativeHeatExposure;
        out exposureIncrement : Real;
        
        first start;
        then decide;
            if currentTemp.temperature > refTemp then accumulateExposure;
            if currentTemp.temperature <= refTemp then noExposure;
        
        action accumulateExposure {
            out exposureIncrement;
        }
        then done;
        
        action noExposure {
            assign exposureIncrement := 0.0;
        }
        then done;
    }
    
    action def DetermineVVMStatus {
        in exposure : CumulativeHeatExposure;
        in thresholds : ExposureThresholds;
        out status : VVMIndicatorState;
        
        first start;
        then decide;
            if exposure < thresholds.cautionThreshold then setSafe;
            if exposure >= thresholds.cautionThreshold and exposure < thresholds.discardThreshold then setCaution;
            if exposure >= thresholds.discardThreshold then setDiscard;
        
        action setSafe {
            assign status := VVMIndicatorState::safe;
        }
        then done;
        
        action setCaution {
            assign status := VVMIndicatorState::caution;
        }
        then done;
        
        action setDiscard {
            assign status := VVMIndicatorState::discard;
        }
        then done;
    }
    
    action def MonitorVaccineVial {
        in attribute temperatureReadings : TemperatureMeasurement[*];
        in attribute referenceTemp : TemperatureValue;
        in attribute thresholds : ExposureThresholds;
        out attribute finalStatus : VVMIndicatorState;
        
        private attribute cumulativeExposure : CumulativeHeatExposure := 0.0;
        
        for reading in temperatureReadings {
            perform action computeExposure : ComputeHeatExposure {
                in currentTemp = reading;
                in refTemp = referenceTemp;
                inout totalExposure = cumulativeExposure;
                out exposureIncrement;
            }
            then assign cumulativeExposure := cumulativeExposure + computeExposure.exposureIncrement;
        }
        
        perform action determineStatus : DetermineVVMStatus {
            in exposure = cumulativeExposure;
            in thresholds = thresholds;
            out status;
        }
        then assign finalStatus := determineStatus.status;
    }
    
    occurrence def HeatExposureEvent;
    
    part def VaccineVialMonitor;
    
    part vaccineVialMonitor : VaccineVialMonitor {
        part vial : VaccineVial {
            attribute :>> vaccineType = "Measles-Rubella";
            attribute :>> volumeCapacity = 10.0 [SI::mL];
        }
        
        part label : ThermochromicLabel {
            attribute :>> baselineInnerDarkness = 0.2;
            attribute :>> baselineOuterDarkness = 0.8;
            attribute :>> innerSquareDarkness = 0.2;
            attribute :>> outerRingDarkness = 0.8;
        }
        
        part calculator : ExposureCalculator {
            attribute :>> cumulativeExposure = 0.0;
            attribute :>> referenceTemperature = 281.15 [SI::K];
        }
        
        part evaluator : StatusEvaluator {
            attribute :>> thresholds = ExposureThresholds {
                cautionThreshold = 50.0;
                discardThreshold = 100.0;
            };
        }
        
        connection vialToCalculator connect vial.thermalInterface to calculator;
        connection calculatorToEvaluator connect calculator to evaluator;
        connection evaluatorToLabel connect evaluator to label.colorOutput;
        
        perform action monitorOperation : MonitorVaccineVial;
    }
    
    requirement def VVMFunctionalRequirement;
    
    requirement <'VVM-REQ-001'> primaryFunction : VVMFunctionalRequirement {
        doc /* The Vaccine Vial Monitor shall provide a continuous, irreversible visual indication 
               of cumulative heat exposure to enable healthcare workers to determine vaccine viability 
               at the point of administration. */
        
        subject vaccineVialMonitor;
    }
    
    requirement <'VVM-REQ-002'> heatExposureTracking : VVMFunctionalRequirement {
        doc /* The system shall track cumulative heat exposure above the reference storage temperature 
               and update the thermochromic indicator accordingly. */
        
        subject vaccineVialMonitor.calculator;
        
        require constraint {
            vaccineVialMonitor.calculator.referenceTemperature == 281.15 [SI::K]
        }
    }
    
    requirement <'VVM-REQ-003'> visualIndicatorStates : VVMFunctionalRequirement {
        doc /* The thermochromic label shall display three distinct states: safe (inner square lighter 
               than outer ring), caution (inner square approaching outer ring), and discard (inner square 
               matches or exceeds outer ring darkness). */
        
        subject vaccineVialMonitor.label;
        
        require constraint {
            vaccineVialMonitor.label.baselineInnerDarkness < vaccineVialMonitor.label.baselineOuterDarkness
        }
    }
    
    requirement <'VVM-REQ-004'> statusEvaluation : VVMFunctionalRequirement {
        doc /* The system shall evaluate vaccine status based on cumulative heat exposure thresholds 
               and provide clear guidance for vaccine use or disposal. */
        
        subject vaccineVialMonitor.evaluator;
        
        require constraint {
            vaccineVialMonitor.evaluator.thresholds.cautionThreshold < 
            vaccineVialMonitor.evaluator.thresholds.discardThreshold
        }
    }
    
    requirement <'VVM-REQ-005'> irreversibleIndication : VVMFunctionalRequirement {
        doc /* The color change in the thermochromic label shall be irreversible to prevent 
               false indication of vaccine viability after temperature excursions. */
        
        subject vaccineVialMonitor.label;
    }
    
    requirement vvmSystemMission {
        doc /* The Vaccine Vial Monitor system shall protect public health by preventing administration 
               of heat-damaged vaccines through continuous monitoring and clear visual indication of 
               cumulative heat exposure throughout the vaccine cold chain. */
        
        assume constraint coldChainEnvironment {
            doc /* Vaccines are transported and stored in environments where temperature may fluctuate 
                   but monitoring is essential for maintaining vaccine potency. */
        }
        
        require primaryFunction;
        require heatExposureTracking;
        require visualIndicatorStates;
        require statusEvaluation;
        require irreversibleIndication;
    }
}
