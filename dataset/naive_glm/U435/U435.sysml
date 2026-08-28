package VVM {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    
    value def Temperature :> Real {
        ref unit : TemperatureUnit[1] = TemperatureUnit::degC;
    }
    
    value def HeatExposureScore :> Real {
        ref unit : HeatExposureUnit[1] = HeatExposureUnit::scoreUnit;
    }
    
    value def ColorIntensity :> Real {
        doc /* Normalized 0.0 (lightest) to 1.0 (darkest) */
        ref unit : ColorIntensityUnit[1] = ColorIntensityUnit::intensityUnit;
    }
    
    value def TimeDuration :> Real {
        ref unit : TimeUnit[1] = TimeUnit::hour;
    }
    
    item def TemperatureUnit :> Unit {
        attribute degC : TemperatureUnit;
    }
    item def HeatExposureUnit :> Unit {
        attribute scoreUnit : HeatExposureUnit;
    }
    item def ColorIntensityUnit :> Unit {
        attribute intensityUnit : ColorIntensityUnit;
    }
    item def TimeUnit :> Unit {
        attribute hour : TimeUnit;
    }
    
    // ===== Enumerations =====
    
    enum def VVMStatus {
        SAFE;
        CAUTION;
        DISCARD;
    }
    
    enum def LabelRegion {
        INNER_SQUARE;
        OUTER_RING;
    }
    
    // ===== Item Types =====
    
    item def VaccineDose {
        attribute vaccineType : String = "Measles-Rubella";
        attribute volume_mL : Real = 0.5;
    }
    
    item def TemperatureReading {
        ref value : Temperature[1];
    }
    
    item def HeatDamageUpdate {
        ref value : HeatExposureScore[1];
    }
    
    item def StatusReport {
        ref status : VVMStatus[1];
        ref innerSquareColor : ColorIntensity[1];
    }
    
    // ===== Port Definitions =====
    
    port def TemperaturePort {
        out reading : TemperatureReading;
    }
    
    port def HeatScorePort {
        out score : HeatDamageUpdate;
    }
    
    port def StatusPort {
        out report : StatusReport;
    }
    
    port def AmbientTempPort {
        out ambient : TemperatureReading;
    }
    
    // ===== Parts =====
    
    part def VaccineVial {
        port tempOut : TemperaturePort;
        
        attribute containedVaccine : VaccineDose[1];
        attribute vialVolume_mL : Real = 2.0;
        attribute currentTemperature : Temperature[1] = 8.0 [degC];
        
        part contents : VaccineDose[1..*];
        
        action def senseTemperature {
            in ambientTemp : Temperature;
            out vialTemp : Temperature;
        }
        
        action senseTemp : senseTemperature {
            in ambientTemp = currentTemperature;
            out vialTemp = currentTemperature;
        }
        
        flow from senseTemp.vialTemp to tempOut.reading.value;
        
        state vialThermalBehavior {
            entry;
            
            state Stable;
            state Warming;
            state Cooling;
            
            transition from Stable to Warming
                when currentTemperature > 8.0 [degC];
            transition from Warming to Cooling
                when currentTemperature < 8.0 [degC];
            transition from Cooling to Stable
                when currentTemperature == 8.0 [degC];
        }
    }
    
    part def ThermochromicLabel {
        port statusIn : StatusPort;
        
        attribute outerRingColor : ColorIntensity[1] = 0.85 [intensityUnit];
        attribute innerSquareColor : ColorIntensity[1] = 0.10 [intensityUnit];
        attribute isIrreversible : Boolean = true;
        attribute maxRecordedColor : ColorIntensity[1] = 0.10 [intensityUnit];
        
        part innerSquare {
            attribute color : ColorIntensity[1] = 0.10 [intensityUnit];
            attribute region : LabelRegion = LabelRegion::INNER_SQUARE;
        }
        
        part outerRing {
            attribute color : ColorIntensity[1] = 0.85 [intensityUnit];
            attribute region : LabelRegion = LabelRegion::OUTER_RING;
        }
        
        action def updateLabel {
            in report : StatusReport;
            out innerColor : ColorIntensity;
        }
        
        action update : updateLabel {
            in report = statusIn.report;
            out innerColor = innerSquareColor;
        }
        
        state labelColorState {
            entry;
            
            state Safe {
                entry : innerSquareColor = 0.10 [intensityUnit];
            }
            state Caution {
                entry : innerSquareColor = 0.55 [intensityUnit];
            }
            state Discard {
                entry : innerSquareColor = 0.90 [intensityUnit];
            }
            
            transition from Safe to Caution
                when statusIn.report.status == VVMStatus::CAUTION;
            transition from Safe to Discard
                when statusIn.report.status == VVMStatus::DISCARD;
            transition from Caution to Discard
                when statusIn.report.status == VVMStatus::DISCARD;
            
            // Irreversibility: no transitions back to Safe or Caution
        }
        
        // Enforce irreversibility by tracking max
        state irreversibilityGuard {
            entry;
            invariant maxRecordedColor >= innerSquareColor;
        }
    }
    
    part def ExposureCalculator {
        port tempIn : TemperaturePort;
        port scoreOut : HeatScorePort;
        
        attribute safeReferenceTemp : Temperature[1] = 8.0 [degC];
        attribute accumulatedHeatDamage : HeatExposureScore[1] = 0.0 [scoreUnit];
        attribute accumulationRate : Real = 1.0; // score per hour above threshold
        attribute lastUpdateTimestamp : TimeDuration[1] = 0.0 [hour];
        
        action def accumulateDamage {
            in currentTemp : Temperature;
            in threshold : Temperature;
            in rate : Real;
            out newScore : HeatExposureScore;
        }
        
        action accumulate : accumulateDamage {
            in currentTemp = tempIn.reading.value;
            in threshold = safeReferenceTemp;
            in rate = accumulationRate;
            out newScore = accumulatedHeatDamage;
        }
        
        flow from accumulate.newScore to scoreOut.score.value;
        
        state calculatorState {
            entry;
            
            state Idle {
                // Temperature at or below safe reference; no accumulation
            }
            state Accumulating {
                // Temperature exceeds safe reference; accumulate damage
            }
            
            transition from Idle to Accumulating
                when tempIn.reading.value > safeReferenceTemp;
            transition from Accumulating to Idle
                when tempIn.reading.value <= safeReferenceTemp;
        }
        
        // Continuous accumulation behavior
        action def continuousAccumulation {
            in temp : Temperature;
            in threshold : Temperature;
            in rate : Real;
            out score : HeatExposureScore;
            
            // If temp > threshold, score increases over time
            if temp > threshold {
                score = score + (rate * 1.0 [hour]);
            }
        }
    }
    
    part def StatusEvaluator {
        port scoreIn : HeatScorePort;
        port statusOut : StatusPort;
        
        attribute cautionThreshold : HeatExposureScore[1] = 30.0 [scoreUnit];
        attribute discardThreshold : HeatExposureScore[1] = 60.0 [scoreUnit];
        attribute currentStatus : VVMStatus[1] = VVMStatus::SAFE;
        attribute evaluatedInnerColor : ColorIntensity[1] = 0.10 [intensityUnit];
        
        action def evaluateStatus {
            in totalScore : HeatExposureScore;
            in caution : HeatExposureScore;
            in discard : HeatExposureScore;
            out status : VVMStatus;
            out innerColor : ColorIntensity;
        }
        
        action evaluate : evaluateStatus {
            in totalScore = scoreIn.score.value;
            in caution = cautionThreshold;
            in discard = discardThreshold;
            out status = currentStatus;
            out innerColor = evaluatedInnerColor;
        }
        
        flow from evaluate.status to statusOut.report.status;
        flow from evaluate.innerColor to statusOut.report.innerSquareColor;
        
        state evaluatorState {
            entry;
            
            state Safe {
                entry : currentStatus = VVMStatus::SAFE;
                entry : evaluatedInnerColor = 0.10 [intensityUnit];
            }
            state Caution {
                entry : currentStatus = VVMStatus::CAUTION;
                entry : evaluatedInnerColor = 0.55 [intensityUnit];
            }
            state Discard {
                entry : currentStatus = VVMStatus::DISCARD;
                entry : evaluatedInnerColor = 0.90 [intensityUnit];
            }
            
            transition from Safe to Caution
                when scoreIn.score.value >= cautionThreshold
                and scoreIn.score.value < discardThreshold;
            transition from Safe to Discard
                when scoreIn.score.value >= discardThreshold;
            transition from Caution to Discard
                when scoreIn.score.value >= discardThreshold;
            
            // Irreversibility: no transitions back to earlier states
        }
    }
    
    // ===== Top-level System =====
    
    part def VVMSystem {
        attribute systemId : String;
        attribute manufactureDate : String;
        attribute vaccineType : String = "Measles-Rubella";
        
        port ambientPort : AmbientTempPort;
        
        part vial : VaccineVial[1] {
            port redefines tempOut;
        }
        
        part label : ThermochromicLabel[1] {
            port redefines statusIn;
        }
        
        part calculator : ExposureCalculator[1] {
            port redefines tempIn;
            port redefines scoreOut;
        }
        
        part evaluator : StatusEvaluator[1] {
            port redefines scoreIn;
            port redefines statusOut;
        }
        
        // Connections
        connection vialTempToCalculator connect vial.tempOut to calculator.tempIn;
        connection calculatorScoreToEvaluator connect calculator.scoreOut to evaluator.scoreIn;
        connection evaluatorStatusToLabel connect evaluator.statusOut to label.statusIn;
        
        // Ambient temperature flows into vial
        flow from ambientPort.ambient to vial.tempOut.reading;
        
        state systemOperation {
            entry;
            
            state Monitoring {
                // System continuously monitors and updates
            }
            state Compromised {
                // Discard state reached; irreversible
            }
            
            transition from Monitoring to Compromised
                when evaluator.currentStatus == VVMStatus::DISCARD;
        }
    }
    
    // ===== Requirements =====
    
    requirement def HeatTrackingRequirement {
        doc /* The system shall continuously track cumulative heat exposure of the vaccine vial. */
        subject : VVMSystem;
        objective {
            doc /* Heat damage score accumulates only when temperature exceeds 8°C. */
            constraint { calculator.safeReferenceTemp == 8.0 [degC] }
            constraint { calculator.accumulatedHeatDamage >= 0.0 [scoreUnit] }
        }
    }
    
    requirement def IrreversibilityRequirement {
        doc /* The color change on the thermochromic label shall be permanent and irreversible. */
        subject : ThermochromicLabel;
        objective {
            doc /* Once the inner square darkens, it shall not revert to a lighter state. */
            constraint { label.isIrreversible == true }
            constraint { label.maxRecordedColor >= label.innerSquareColor }
        }
    }
    
    requirement def ThreeStateIndicatorRequirement {
        doc /* The system shall provide three distinct visual states: Safe, Caution, and Discard. */
        subject : VVMSystem;
        objective {
            doc /* The inner square color relative to the outer ring indicates status. */
            constraint { label.outerRingColor == 0.85 [intensityUnit] }
            constraint { 
                (evaluator.currentStatus == VVMStatus::SAFE 
                 and label.innerSquareColor < 0.30 [intensityUnit]) 
                or 
                (evaluator.currentStatus == VVMStatus::CAUTION 
                 and label.innerSquareColor >= 0.30 [intensityUnit] 
                 and label.innerSquareColor < 0.85 [intensityUnit]) 
                or 
                (evaluator.currentStatus == VVMStatus::DISCARD 
                 and label.innerSquareColor >= 0.85 [intensityUnit])
            }
        }
    }
    
    requirement def ThresholdRequirement {
        doc /* The status evaluator shall compare accumulated heat damage against caution and discard thresholds. */
        subject : StatusEvaluator;
        objective {
            constraint { evaluator.cautionThreshold == 30.0 [scoreUnit] }
            constraint { evaluator.discardThreshold == 60.0 [scoreUnit] }
            constraint { evaluator.cautionThreshold < evaluator.discardThreshold }
        }
    }
    
    requirement def FieldUsabilityRequirement {
        doc /* The system shall enable healthcare workers in the field to determine vaccine viability at a glance. */
        subject : VVMSystem;
        objective {
            doc /* No instruments or power required to read the status. */
            constraint { label.outerRingColor > label.innerSquareColor 
                         when evaluator.currentStatus == VVMStatus::SAFE }
        }
    }
    
    // ===== Satisfaction =====
    
    satisfaction heatTrackingSatisf : HeatTrackingRequirement {
        subject : VVMSystem;
    }
    
    satisfaction irreversibilitySatisf : IrreversibilityRequirement {
        subject : ThermochromicLabel;
    }
    
    satisfaction threeStateSatisf : ThreeStateIndicatorRequirement {
        subject : VVMSystem;
    }
    
    satisfaction thresholdSatisf : ThresholdRequirement {
        subject : StatusEvaluator;
    }
    
    satisfaction fieldUsabilitySatisf : FieldUsabilityRequirement {
        subject : VVMSystem;
    }
}
