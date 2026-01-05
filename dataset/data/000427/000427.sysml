package AuricularSplintSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeformityType;
    attribute def CorrectionStage;
    
    attribute def MoldingPressure :> ISQ::PressureValue;
    
    attribute def SplintThickness :> ISQ::LengthValue;
    
    attribute def TreatmentTime :> ISQ::TimeValue;
    
    attribute def CartilageFlexibility :> Real;
    
    item def SiliconeMaterial {
        attribute thickness: SplintThickness;
        attribute flexibility: CartilageFlexibility;
        attribute biocompatible: Boolean;
    }
    
    item def AdhesiveLayer {
        attribute bondStrength: ISQ::ForceValue;
        attribute skinSafe: Boolean;
    }
    
    item def MoldingForce {
        attribute pressure: MoldingPressure;
        attribute distributionUniformity: Real;
    }
    
    port def MoldingContactPort {
        in appliedPressure: MoldingPressure;
        out cartilageResponse: CartilageFlexibility;
    }
    
    port def MoldingSurfacePort {
        out appliedPressure: MoldingPressure;
        in requiredPressure: MoldingPressure;
    }
    
    port def SecurementPort {
        out retentionForce: ISQ::ForceValue;
    }
    
    port def TherapeuticInterfacePort {
        out correctionPressure: MoldingPressure;
        in targetPressure: MoldingPressure;
    }
    
    part def NeonatalEar {
        attribute deformityType: DeformityType;
        attribute cartilageFlexibility: CartilageFlexibility;
        attribute ageInDays: Real;
        
        port moldingContact: MoldingContactPort;
    }
    
    part def SplintShell {
        attribute material: SiliconeMaterial;
        attribute contourShape: String;
        
        port moldingSurface: MoldingSurfacePort;
    }
    
    part def RetentionBand {
        attribute adhesive: AdhesiveLayer;
        attribute tensionLevel: ISQ::ForceValue;
        
        port securement: SecurementPort;
    }
    
    part def AuricularSplintDevice {
        attribute deviceID: String;
        attribute patientAge: Real;
        attribute treatmentDuration: TreatmentTime;
        
        part shell: SplintShell {
            attribute material: SiliconeMaterial {
                attribute thickness = 1.5 [SI::mm];
                attribute flexibility = 0.75;
                attribute biocompatible = true;
            }
            attribute contourShape = "anatomical";
        }
        
        part anteriorBand: RetentionBand {
            attribute adhesive: AdhesiveLayer {
                attribute bondStrength = 8.0 [SI::N];
                attribute skinSafe = true;
            }
            attribute tensionLevel = 3.5 [SI::N];
        }
        
        part posteriorBand: RetentionBand {
            attribute adhesive: AdhesiveLayer {
                attribute bondStrength = 8.0 [SI::N];
                attribute skinSafe = true;
            }
            attribute tensionLevel = 3.5 [SI::N];
        }
        
        port therapeuticInterface: TherapeuticInterfacePort;
    }
    
    action def AssessDeformity {
        in ear: NeonatalEar;
        out deformitySeverity: Real;
        out recommendedPressure: MoldingPressure;
        out estimatedDuration: TreatmentTime;
    }
    
    action def CustomizeSplint {
        in earMeasurements: String;
        in targetPressure: MoldingPressure;
        out customizedDevice: AuricularSplintDevice;
    }
    
    action def ApplySplint {
        in device: AuricularSplintDevice;
        in targetEar: NeonatalEar;
        out applicationSuccess: Boolean;
        out initialPressure: MoldingPressure;
    }
    
    action def MonitorCorrection {
        in ear: NeonatalEar;
        in currentPressure: MoldingPressure;
        in elapsedTime: TreatmentTime;
        out correctionProgress: Real;
        out cartilageAdaptation: CartilageFlexibility;
    }
    
    action def AdjustPressure {
        in currentProgress: Real;
        in currentPressure: MoldingPressure;
        out adjustedPressure: MoldingPressure;
        out continueRequired: Boolean;
    }
    
    action def RemoveDevice {
        in device: AuricularSplintDevice;
        in correctionComplete: Boolean;
        out removalSuccess: Boolean;
        out finalEarShape: String;
    }
    
    action def PerformCorrection {
        in affectedEar: NeonatalEar;
        in maxTreatmentDuration: TreatmentTime;
        out correctionAchieved: Boolean;
        
        first start;
        
        then action assess: AssessDeformity {
            in ear = affectedEar;
            out deformitySeverity;
            out recommendedPressure;
            out estimatedDuration;
        }
        
        then action customize: CustomizeSplint {
            in earMeasurements = "patient-specific";
            in targetPressure = assess.recommendedPressure;
            out customizedDevice;
        }
        
        then action apply: ApplySplint {
            in device = customize.customizedDevice;
            in targetEar = affectedEar;
            out applicationSuccess;
            out initialPressure;
        }
        
        then merge correctionCycle;
        
        then action monitor: MonitorCorrection {
            in ear = affectedEar;
            in currentPressure = apply.initialPressure;
            in elapsedTime: TreatmentTime;
            out correctionProgress;
            out cartilageAdaptation;
        }
        
        then decide;
            if monitor.correctionProgress < 0.90 then adjust;
            if monitor.correctionProgress >= 0.90 then remove;
        
        action adjust: AdjustPressure {
            in currentProgress = monitor.correctionProgress;
            in currentPressure = apply.initialPressure;
            out adjustedPressure;
            out continueRequired;
        }
        then correctionCycle;
        
        action remove: RemoveDevice {
            in device = customize.customizedDevice;
            in correctionComplete = true;
            out removalSuccess;
            out finalEarShape;
        }
        then assign correctionAchieved := remove.removalSuccess;
        then done;
    }
    
    state def CorrectionLifecycle {
        entry; then Idle;
        
        state Idle;
        state Assessment;
        state Application;
        state ActiveCorrection;
        state Monitoring;
        state Adjustment;
        state Completion;
        
        transition from Idle to Assessment
            accept patientIntake;
        
        transition from Assessment to Application;
        
        transition from Application to ActiveCorrection;
        
        transition from ActiveCorrection to Monitoring;
        
        transition from Monitoring to Adjustment;
        
        transition from Adjustment to ActiveCorrection;
        
        transition from Monitoring to Completion;
        
        transition from Completion to TreatmentComplete;
        
        state TreatmentComplete;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The Auricular Splint System shall non-surgically correct congenital 
               ear deformities in neonates by applying controlled, continuous molding 
               pressure to reshape flexible auricular cartilage during the critical 
               early postnatal period. */
        
        require constraint {
            doc /* The system shall apply molding pressure between 2000 Pa and 5000 Pa. */
        }
        
        require constraint {
            doc /* Treatment shall be initiated within the first 6 weeks of life. */
        }
        
        require constraint {
            doc /* The device shall maintain continuous contact for 4 to 6 weeks. */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The Auricular Splint System shall ensure patient safety through 
               biocompatible materials and controlled pressure application. */
        
        require constraint {
            doc /* All materials in contact with skin shall be medical-grade and hypoallergenic. */
        }
        
        require constraint {
            doc /* Applied pressure shall not exceed capillary occlusion threshold. */
        }
        
        require constraint {
            doc /* The device shall allow for daily skin inspection. */
        }
    }
    
    requirement def EffectivenessRequirement {
        doc /* The Auricular Splint System shall achieve clinically significant 
               correction of auricular deformities. */
        
        require constraint {
            doc /* The system shall achieve at least 90 percent correction for eligible deformities. */
        }
        
        require constraint {
            doc /* Correction shall be maintained after device removal. */
        }
    }
    
    requirement <'ASR-100'> systemPrimaryFunction {
        doc /* The Auricular Splint System shall provide non-invasive correction of 
               neonatal auricular deformities by leveraging the natural plasticity of 
               infant ear cartilage through controlled, sustained molding pressure, 
               eliminating the need for surgical intervention. */
        
        require primaryFunction: PrimaryFunctionRequirement;
        require safety: SafetyRequirement;
        require effectiveness: EffectivenessRequirement;
    }
    
    part auricularCorrectionSystem {
        part splintDevice: AuricularSplintDevice {
            attribute deviceID = "ACS-2024-001";
            attribute patientAge = 14.0;
            attribute treatmentDuration = 42.0 [SI::day];
            
            perform action correctionAction: PerformCorrection {
                in affectedEar;
                in maxTreatmentDuration = 42.0 [SI::day];
                out correctionAchieved;
            }
        }
        
        part patientEar: NeonatalEar {
            attribute deformityType = "prominent ear";
            attribute cartilageFlexibility = 0.85;
            attribute ageInDays = 14.0;
        }
        
        connection connect splintDevice.shell.moldingSurface to patientEar.moldingContact;
        
        satisfy systemPrimaryFunction;
    }
}
