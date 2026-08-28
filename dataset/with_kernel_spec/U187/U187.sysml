package 'Medical Compression Therapy System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package 'Value Definitions' {
        attribute def AssessmentComplete;
        attribute def FitComplete;
        attribute def MonitoringComplete;
        attribute def AdjustTreatment;
        attribute def TherapyGoalsMet;
    }

    package 'Garment Definitions' {
        private import 'Value Definitions'::*;
        
        part def PatientLimb {
            attribute distalCircumference : LengthValue;
            attribute proximalCircumference : LengthValue;
            attribute currentCircumference : LengthValue;
            attribute circulationStatus : Real;
            port limbPort : LimbInterfacePort;
        }
        
        part def CompressiveFabricLayer {
            attribute tension : PressureValue;
        }
        
        part def ElasticYarn {
            attribute elasticity : Real;
        }
        
        part def ReinforcementZone {
            attribute supportLevel : Real;
            attribute location : String;
        }
        
        part def MoistureWickingLiner {
            attribute breathability : Real;
        }
        
        port def LimbInterfacePort {
            attribute circumference : LengthValue;
            attribute appliedPressure : PressureValue;
        }
        
        part def TherapeuticCompressionGarment {
            part compressiveLayers : CompressiveFabricLayer[1..*];
            part elasticYarns : ElasticYarn[1..*];
            part reinforcementZones : ReinforcementZone[1..*];
            part innerLiner : MoistureWickingLiner;
            
            attribute durability : Real;
            attribute distalPressure : PressureValue;
            attribute proximalPressure : PressureValue;
            
            port limbInterface : LimbInterfacePort;
        }
    }

    package 'Therapy Behaviors' {
        private import 'Garment Definitions'::*;
        private import 'Value Definitions'::*;
        
        action def AssessLimb {
            in limb : PatientLimb;
            out swelling : LengthValue;
            out size : String;
            out compressionLevel : PressureValue;
        }
        
        action def FitGarment {
            in limb : PatientLimb;
            in garment : TherapeuticCompressionGarment;
        }
        
        action def ApplyGraduatedPressure {
            in garment : TherapeuticCompressionGarment;
        }
        
        action def MonitorProgress {
            in limb : PatientLimb;
            out circumferenceChange : LengthValue;
            out circulationStatus : Real;
        }
        
        action def AdjustTreatment {
            in limb : PatientLimb;
            in garment : TherapeuticCompressionGarment;
        }
        
        action assessLimb : AssessLimb;
        action fitGarment : FitGarment;
        action applyGraduatedPressure : ApplyGraduatedPressure;
        action monitorProgress : MonitorProgress;
        action adjustTreatment : AdjustTreatment;
        
        state def TherapyProcess {
            entry; then assessing;
            state assessing {
                do assessLimb;
            }
            accept AssessmentComplete then fitting;
            state fitting {
                do fitGarment;
            }
            accept FitComplete then activeCompression;
            state activeCompression {
                do applyGraduatedPressure;
            }
            accept MonitoringComplete then monitoring;
            state monitoring {
                do monitorProgress;
            }
            accept AdjustTreatment then adjusting;
            accept TherapyGoalsMet then complete;
            state adjusting {
                do adjustTreatment;
            }
            accept FitComplete then activeCompression;
            state complete;
        }
    }

    package 'System Context' {
        private import 'Therapy Behaviors'::*;
        private import 'Garment Definitions'::*;
        private import 'Value Definitions'::*;
        
        part def CompressionTherapySystem {
            part garment : TherapeuticCompressionGarment;
            part affectedLimb : PatientLimb;
            
            action assess : AssessLimb {
                in limb = affectedLimb;
            }
            action fit : FitGarment {
                in limb = affectedLimb;
                in garment = garment;
            }
            action apply : ApplyGraduatedPressure {
                in garment = garment;
            }
            action monitor : MonitorProgress {
                in limb = affectedLimb;
            }
            action adjust : AdjustTreatment {
                in limb = affectedLimb;
                in garment = garment;
            }
            
            exhibit state currentTherapy : TherapyProcess;
            
            connect garment.limbInterface to affectedLimb.limbPort;
        }
        
        part therapySystem : CompressionTherapySystem {
            part :>> garment {
                attribute :>> distalPressure = 5.3[kPa];
                attribute :>> proximalPressure = 2.7[kPa];
                part :>> innerLiner {
                    attribute :>> breathability = 0.8;
                }
                part :>> compressiveLayers {
                    attribute :>> tension = 30[kPa];
                }
            }
            part :>> affectedLimb {
                attribute :>> distalCircumference = 25[cm];
                attribute :>> proximalCircumference = 40[cm];
                attribute :>> currentCircumference = 25[cm];
                attribute :>> circulationStatus = 0.6;
            }
        }
    }
    
    package 'Requirements' {
        private import 'System Context'::*;
        
        requirement def GraduatedPressureRequirement {
            subject s : CompressionTherapySystem;
            doc /* The garment shall apply graduated pressure with distal pressure greater than proximal pressure. */
        }
        
        requirement def SwellingReductionRequirement {
            subject s : CompressionTherapySystem;
            doc /* The limb circumference shall decrease over the course of therapy. */
        }
        
        requirement def DurabilityRequirement {
            subject s : CompressionTherapySystem;
            doc /* The garment shall retain its compressive properties through repeated use. */
        }
        
        requirement def BreathabilityRequirement {
            subject s : CompressionTherapySystem;
            doc /* The garment inner liner shall provide moisture wicking for patient comfort. */
        }
    }
}
