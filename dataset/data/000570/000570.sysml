package 'Compression Garment System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CompressionLevel {
        attribute magnitude : Real;
        attribute unit : String;
    }
    
    attribute def GarmentDimensions {
        attribute circumference : LengthValue;
        attribute length : LengthValue;
        attribute thickness : LengthValue;
    }
    
    attribute def MaterialProperties {
        attribute elasticModulus : Real;
        attribute compressionRetention : Real;
        attribute breathability : Real;
        attribute durability : Real;
    }
    
    item def CompressiveFabric {
        attribute properties : MaterialProperties;
        attribute compressionGrade : CompressionLevel;
        attribute layerCount : Integer;
    }
    
    item def ElasticYarn;
    item def ReinforcementPanel;
    item def MoistureWickingLiner;
    
    port def CompressionApplicationPort {
        attribute appliedPressure : PressureValue;
        attribute distributionArea : AreaValue;
        attribute gradientProfile : Real[*];
    }
    
    port def LimbInterfacePort {
        attribute surfaceTemperature : TemperatureValue;
        attribute limbDiameter : LengthValue;
        attribute skinCondition : Real;
    }
    
    part def CompressionGarment {
        doc /* A therapeutic compression garment that applies graduated external pressure 
               to improve venous circulation and reduce edema in limbs. */
        
        attribute targetPressure : CompressionLevel;
        attribute dimensions : GarmentDimensions;
        attribute fitTolerance : LengthValue;
        
        part fabricLayers : CompressiveFabric[2..4] {
            attribute layerIndex : Integer;
            attribute compressionContribution : Real;
        }
        
        part elasticComponents : ElasticYarn[*] {
            attribute tensionForce : ForceValue;
            attribute stretchRatio : Real;
        }
        
        part reinforcementZones : ReinforcementPanel[1..3] {
            attribute supportLevel : Real;
            attribute location : String;
        }
        
        part innerLiner : MoistureWickingLiner {
            attribute absorptionRate : Real;
            attribute comfortRating : Real;
        }
        
        port compressionPort : CompressionApplicationPort[*];
        port limbInterface : LimbInterfacePort[*];
        
        perform action deliverCompression;
    }
    
    part def AffectedLimb {
        doc /* The limb receiving compression therapy. */
        
        attribute baselineCircumference : LengthValue;
        attribute currentCircumference : LengthValue;
        attribute swellingMagnitude : LengthValue;
        attribute venousFlowRate : VolumeFlowRateValue;
        
        port contactSurface : LimbInterfacePort;
        
        part venousSystem {
            attribute returnFlow : VolumeFlowRateValue;
            attribute valveFunction : Real;
        }
        
        part lymphaticSystem {
            attribute drainageRate : VolumeFlowRateValue;
            attribute fluidAccumulation : VolumeValue;
        }
    }
    
    action def AssessLimbCondition {
        in limb : AffectedLimb;
        out baselineMeasurement : LengthValue;
        out swellingLevel : LengthValue;
        out circulationStatus : Real;
    }
    
    action def DetermineCompressionLevel {
        in limbMeasurements : LengthValue;
        in swellingDegree : LengthValue;
        out recommendedPressure : CompressionLevel;
        out garmentSize : GarmentDimensions;
    }
    
    action def FitGarment {
        in garment : CompressionGarment;
        in limb : AffectedLimb;
        out properFit : Boolean;
        out achievedPressure : PressureValue;
    }
    
    action def ApplyGraduatedPressure {
        in targetCompression : CompressionLevel;
        in limbGeometry : GarmentDimensions;
        out pressureGradient : PressureValue[*];
        out distalPressure : PressureValue;
        out proximalPressure : PressureValue;
    }
    
    action def EnhanceVenousReturn {
        in externalPressure : PressureValue;
        inout venousFlow : VolumeFlowRateValue;
        out flowImprovement : Real;
    }
    
    action def ReduceEdema {
        in sustainedCompression : PressureValue;
        in treatmentDuration : DurationValue;
        inout edemaVolume : VolumeValue;
        out reductionRate : Real;
    }
    
    action def MonitorTherapyProgress {
        in currentLimbSize : LengthValue;
        in venousFlowRate : VolumeFlowRateValue;
        in treatmentTime : DurationValue;
        out therapeuticEffectiveness : Real;
        out continueTreatment : Boolean;
    }
    
    action def DeliverCompressionTherapy {
        doc /* Primary action that coordinates the delivery of therapeutic compression 
               to improve circulation and reduce swelling. */
        
        in targetLimb : AffectedLimb;
        in therapeuticGarment : CompressionGarment;
        out circulationImproved : Boolean;
        out edemaReduced : Boolean;
        out treatmentSuccessful : Boolean;
        
        first start;
        then action assess : AssessLimbCondition {
            in limb = targetLimb;
            out baselineMeasurement;
            out swellingLevel;
            out circulationStatus;
        }
        then action determine : DetermineCompressionLevel {
            in limbMeasurements = assess.baselineMeasurement;
            in swellingDegree = assess.swellingLevel;
            out recommendedPressure;
            out garmentSize;
        }
        then action fit : FitGarment {
            in garment = therapeuticGarment;
            in limb = targetLimb;
            out properFit;
            out achievedPressure;
        }
        then decide;
            if fit.properFit then proceedWithTherapy;
            if not fit.properFit then refitRequired;
        
        action refitRequired;
        then done;
        
        action proceedWithTherapy {
            first action applyPressure : ApplyGraduatedPressure {
                in targetCompression = determine.recommendedPressure;
                in limbGeometry = determine.garmentSize;
                out pressureGradient;
                out distalPressure;
                out proximalPressure;
            }
            then merge therapyCycle;
            then action enhanceFlow : EnhanceVenousReturn {
                in externalPressure = applyPressure.distalPressure;
                inout venousFlow;
                out flowImprovement;
            }
            then action reduceSwelling : ReduceEdema {
                in sustainedCompression = applyPressure.distalPressure;
                in treatmentDuration;
                inout edemaVolume;
                out reductionRate;
            }
            then action monitor : MonitorTherapyProgress {
                in currentLimbSize = targetLimb.currentCircumference;
                in venousFlowRate = enhanceFlow.venousFlow;
                in treatmentTime;
                out therapeuticEffectiveness;
                out continueTreatment;
            }
            then decide;
                if monitor.continueTreatment and monitor.therapeuticEffectiveness >= 0.6 then therapyCycle;
                if monitor.therapeuticEffectiveness >= 0.8 then treatmentComplete;
                if not monitor.continueTreatment then adjustmentNeeded;
            
            action adjustmentNeeded {
                action modifyCompression;
            }
            then therapyCycle;
            
            action treatmentComplete;
            then assign circulationImproved := true;
            then assign edemaReduced := true;
            then assign treatmentSuccessful := true;
        }
        then done;
    }
    
    state def CompressionGarmentState {
        entry; then idle;
        
        state idle {
            doc /* Garment is not being worn or is not applying therapeutic pressure. */
        }
        
        state fitting {
            doc /* Garment is being positioned and adjusted on the limb. */
        }
        
        state activeCompression {
            doc /* Garment is applying therapeutic graduated pressure. */
            
            state initialCompression;
            state sustainedTherapy;
            state pressureAdjustment;
            
            transition first initialCompression;
            transition initialCompression to sustainedTherapy;
            transition sustainedTherapy to pressureAdjustment;
            transition pressureAdjustment to sustainedTherapy;
        }
        
        state monitoring {
            doc /* Therapeutic effectiveness is being evaluated. */
        }
        
        state removal {
            doc /* Garment is being removed from the limb. */
        }
        
        transition idle to fitting;
        transition fitting to activeCompression;
        transition activeCompression to monitoring;
        transition monitoring to activeCompression;
        transition monitoring to removal;
        transition removal to idle;
    }
    
    requirement def TherapeuticCompressionRequirement {
        doc /* The compression garment shall deliver graduated compression pressure 
               to enhance venous return and reduce edema. */
        
        subject garment : CompressionGarment;
        
        require constraint pressureRange {
            garment.targetPressure.magnitude >= 15.0 and
            garment.targetPressure.magnitude <= 50.0
        }
    }
    
    requirement def PressureGradientRequirement {
        doc /* The garment shall apply maximum pressure distally and gradually 
               decrease pressure proximally to promote venous flow. */
        
        subject garment : CompressionGarment;
        
        require constraint gradientRatio {
            doc /* Proximal pressure should be 50-70% of distal pressure. */
        }
    }
    
    requirement def ComfortAndComplianceRequirement {
        doc /* The garment shall maintain patient comfort and breathability 
               to ensure treatment compliance. */
        
        subject garment : CompressionGarment;
        
        require constraint breathabilityMinimum {
            garment.fabricLayers->forAll(layer | 
                layer.properties.breathability >= 0.65)
        }
    }
    
    requirement def DurabilityAndRetentionRequirement {
        doc /* The garment shall maintain compression effectiveness through 
               repeated use and laundering cycles. */
        
        subject garment : CompressionGarment;
        
        require constraint retentionStandard {
            garment.fabricLayers->forAll(layer | 
                layer.properties.compressionRetention >= 0.75)
        }
    }
    
    requirement <'CG-SYS-001'> primaryTherapeuticFunction {
        doc /* The compression garment system shall provide graduated external pressure 
               to affected limbs to enhance venous and lymphatic circulation, reduce edema, 
               prevent venous pooling, and support treatment of venous insufficiency and 
               lymphedema through sustained, comfortable compression therapy. */
        
        subject system : CompressionGarment;
        
        assume constraint patientCondition {
            doc /* The patient has diagnosed venous insufficiency, lymphedema, 
                   or post-surgical swelling requiring compression therapy. */
        }
        
        require therapeuticCompression : TherapeuticCompressionRequirement;
        require pressureGradient : PressureGradientRequirement;
        require comfortCompliance : ComfortAndComplianceRequirement;
        require durabilityRetention : DurabilityAndRetentionRequirement;
    }
    
    part compressionTherapySystem {
        doc /* Complete system demonstrating compression garment therapy application. */
        
        part patient {
            part lowerLimb : AffectedLimb {
                attribute baselineCircumference = 38.0 [SI::cm];
                attribute currentCircumference = 42.0 [SI::cm];
                attribute swellingMagnitude = 4.0 [SI::cm];
                attribute venousFlowRate = 180.0 [SI::ml/SI::min];
                
                part venousSystem {
                    attribute returnFlow = 180.0 [SI::ml/SI::min];
                    attribute valveFunction = 0.6;
                }
                
                part lymphaticSystem {
                    attribute drainageRate = 15.0 [SI::ml/SI::min];
                    attribute fluidAccumulation = 250.0 [SI::ml];
                }
            }
        }
        
        part medicalGarment : CompressionGarment {
            attribute targetPressure {
                attribute magnitude = 25.0;
                attribute unit = "mmHg";
            }
            attribute dimensions {
                attribute circumference = 36.0 [SI::cm];
                attribute length = 45.0 [SI::cm];
                attribute thickness = 2.5 [SI::mm];
            }
            attribute fitTolerance = 1.5 [SI::cm];
            
            part fabricLayers : CompressiveFabric[3] {
                attribute :>> layerIndex;
                attribute :>> compressionContribution;
            }
            
            state behavior : CompressionGarmentState;
        }
        
        connection garmentToLimb connect 
            medicalGarment.limbInterface to patient.lowerLimb.contactSurface;
        
        perform action therapy : DeliverCompressionTherapy {
            in targetLimb = patient.lowerLimb;
            in therapeuticGarment = medicalGarment;
            out circulationImproved;
            out edemaReduced;
            out treatmentSuccessful;
        }
        
        assert constraint therapySuccess {
            therapy.circulationImproved and 
            therapy.edemaReduced and 
            therapy.treatmentSuccessful
        }
        
        assert constraint pressureWithinRange {
            medicalGarment.targetPressure.magnitude >= 15.0 and
            medicalGarment.targetPressure.magnitude <= 50.0
        }
    }
    
    satisfy primaryTherapeuticFunction by compressionTherapySystem.medicalGarment;
}
