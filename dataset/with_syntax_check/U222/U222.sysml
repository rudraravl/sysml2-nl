package EyepatchSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def LightBlockagePercentage :> Real {
        assert constraint { LightBlockagePercentage >= 0.0 & LightBlockagePercentage <= 100.0 }
    }
    
    attribute def ComfortRating :> Real {
        assert constraint { ComfortRating >= 0.0 & ComfortRating <= 10.0 }
    }
    
    attribute def SecurementLevel :> Real {
        assert constraint { SecurementLevel >= 0.0 & SecurementLevel <= 100.0 }
    }
    
    attribute def ApplicationEvent;
    attribute def RemovalEvent;
    attribute def AdjustmentCompleteEvent;
    attribute def RemovalSignal;
    
    item def PaddingMaterial {
        attribute softness : Real;
        attribute thickness : LengthValue;
        attribute breathability : Real;
    }
    
    item def StrapMaterial {
        attribute elasticity : Real;
        attribute durability : Real;
    }
    
    port def LightProtectionPort {
        in ambientLight : Real;
        out blockedLight : LightBlockagePercentage;
    }
    
    port def ComfortPort {
        in contactPressure : PressureValue;
        out comfortLevel : ComfortRating;
    }
    
    port def SecurementPort {
        in headCircumference : LengthValue;
        out retentionForce : ForceValue;
    }
    
    part def OcclusivePad {
        attribute material : PaddingMaterial;
        attribute coverageArea : AreaValue;
        attribute lightBlockage : LightBlockagePercentage;
        
        port lightProtection : LightProtectionPort;
        port comfort : ComfortPort;
    }
    
    part def AdjustableStrap {
        attribute material : StrapMaterial;
        attribute currentLength : LengthValue;
        attribute minLength : LengthValue;
        attribute maxLength : LengthValue;
        attribute tension : ForceValue;
        
        port securement : SecurementPort;
    }
    
    part def CushionLayer {
        attribute material : PaddingMaterial;
        attribute contactArea : AreaValue;
        
        port comfort : ComfortPort;
    }
    
    requirement def ProtectionRequirement {
        doc /* The eyepatch shall block at least 98% of ambient light from reaching the covered eye. */
    }
    
    requirement def ComfortRequirement {
        doc /* The eyepatch shall maintain contact pressure below 5 kPa to ensure wearer comfort. */
    }
    
    requirement def SecurementRequirement {
        doc /* The eyepatch shall remain securely positioned during normal head movements. */
    }
    
    requirement <'EP-REQ-001'> eyepatchPrimaryRequirement {
        doc /* The eyepatch system shall protect and shield an injured or recovering eye from light and external contact while maintaining secure, comfortable positioning. */
        
        require constraint protectionReq : ProtectionRequirement;
        require constraint comfortReq : ComfortRequirement;
        require constraint securementReq : SecurementRequirement;
    }
    
    action def BlockAmbientLight {
        in incomingLight : Real;
        in blockageCapability : LightBlockagePercentage;
        out transmittedLight : Real;
    }
    
    action def DistributePressure {
        in appliedForce : ForceValue;
        in contactArea : AreaValue;
        out resultingPressure : PressureValue;
    }
    
    action def MaintainPosition {
        in headMovement : Real;
        in strapTension : ForceValue;
        out positionStability : SecurementLevel;
    }
    
    action def AdjustFit {
        in currentComfort : ComfortRating;
        in targetComfort : ComfortRating;
        out newStrapLength : LengthValue;
    }
    
    action def ProvideEyeProtection {
        in ambientLight : Real;
        in headCircumference : LengthValue;
        out eyeProtected : Boolean;
        out wearerComfort : ComfortRating;
        
        first start;
        then merge continuousProtection;
        
        then action positionEyepatch {
            in headSize : LengthValue;
            out positioned : Boolean;
        }
        
        then action blockLight : BlockAmbientLight {
            in incomingLight = ambientLight;
            in blockageCapability;
            out transmittedLight;
        }
        
        flow blockLight.transmittedLight to evaluateProtection.lightLevel;
        
        then action distributePressure : DistributePressure {
            in appliedForce;
            in contactArea;
            out resultingPressure;
        }
        
        flow distributePressure.resultingPressure to evaluateProtection.pressure;
        
        then action maintainPosition : MaintainPosition {
            in headMovement;
            in strapTension;
            out positionStability;
        }
        
        flow maintainPosition.positionStability to evaluateProtection.stability;
        
        then action evaluateProtection {
            in lightLevel : Real;
            in pressure : PressureValue;
            in stability : SecurementLevel;
            out protectionQuality : Real;
            out comfortQuality : ComfortRating;
        }
        
        then decide;
            if evaluateProtection.protectionQuality >= 98.0 & evaluateProtection.comfortQuality >= 7.0
                then continuousProtection;
            if evaluateProtection.protectionQuality < 98.0 | evaluateProtection.comfortQuality < 7.0
                then adjustFit;
        
        action adjustFit : AdjustFit {
            in currentComfort = evaluateProtection.comfortQuality;
            in targetComfort = 8.0;
            out newStrapLength;
        }
        then continuousProtection;
        
        accept removalSignal : RemovalSignal;
        then action removeEyepatch;
        then done;
    }
    
    state def EyepatchOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* Eyepatch is not in use. */
        }
        
        transition idle_to_fitting
            first idle
            accept appEvent : ApplicationEvent
            then fitting;
        
        state fitting {
            doc /* Eyepatch is being positioned and adjusted on the wearer. */
            
            attribute padPositioned : Boolean;
            attribute strapAdjusted : Boolean;
            attribute fitConfirmed : Boolean;
            
            state positioning {
                entry assign padPositioned := false;
                do action positionPad;
                exit assign padPositioned := true;
            }
            
            transition positioning_to_adjusting
                first positioning
                if padPositioned
                then adjusting;
            
            state adjusting {
                entry assign strapAdjusted := false;
                do action adjustStrap;
                exit assign strapAdjusted := true;
            }
            
            transition adjusting_to_secured
                first adjusting
                if strapAdjusted
                then secured;
            
            state secured {
                entry assign fitConfirmed := true;
            }
        }
        
        transition fitting_to_active
            first fitting.secured
            if fitting.fitConfirmed
            then active;
        
        state active {
            doc /* Eyepatch is actively protecting the eye. */
            
            attribute protectionActive : Boolean;
            attribute protectionEstablished : Boolean;
            attribute comfortAcceptable : Boolean;
            attribute comfortUnacceptable : Boolean;
            
            entry assign protectionActive := true;
            
            state protecting {
                do action blockLight : BlockAmbientLight;
                do action maintainPosition : MaintainPosition;
                exit assign protectionEstablished := true;
            }
            
            state monitoring {
                do action evaluateComfort {
                    in currentPressure : PressureValue;
                    out comfortStatus : ComfortRating;
                }
            }
            
            transition protecting_to_monitoring
                first protecting
                if protectionEstablished
                then monitoring;
            
            transition monitoring_to_protecting
                first monitoring
                if comfortAcceptable
                then protecting;
            
            transition monitoring_to_readjusting
                first monitoring
                if comfortUnacceptable
                then readjusting;
            
            state readjusting;
            
            transition readjusting_to_protecting
                first readjusting
                accept adjComplete : AdjustmentCompleteEvent
                then protecting;
        }
        
        transition active_to_removing
            first active
            accept remEvent : RemovalEvent
            then removing;
        
        state removing {
            doc /* Eyepatch is being removed from the wearer. */
            attribute protectionActive : Boolean;
            exit assign protectionActive := false;
        }
        
        transition removing_to_idle
            first removing
            then idle;
    }
    
    part eyepatch : Eyepatch {
        doc /* 
            An eyepatch is a protective medical device designed to shield an injured, 
            post-operative, or recovering eye from ambient light and physical contact. 
            Its primary function is to provide complete light occlusion while maintaining 
            comfortable, secure positioning on the wearer's face to facilitate optimal 
            healing conditions and prevent further injury.
        */
        
        attribute totalMass : MassValue = 
            occlusivePad.material.thickness * 0.5[g] + 
            adjustableStrap.currentLength * 0.1[g] + 
            cushionLayer.material.thickness * 0.3[g];
        
        attribute operationalDuration : TimeValue;
        attribute protectionEffectiveness : LightBlockagePercentage;
        
        part occlusivePad : OcclusivePad {
            attribute :>> material {
                attribute :>> softness = 0.85;
                attribute :>> thickness = 4.0[mm];
                attribute :>> breathability = 0.75;
            }
            attribute :>> coverageArea = 25.0[cm^2];
            attribute :>> lightBlockage = 99.5;
        }
        
        part adjustableStrap : AdjustableStrap {
            attribute :>> material {
                attribute :>> elasticity = 0.80;
                attribute :>> durability = 0.90;
            }
            attribute :>> currentLength = 300.0[mm];
            attribute :>> minLength = 250.0[mm];
            attribute :>> maxLength = 400.0[mm];
            attribute :>> tension = 2.0[N];
        }
        
        part cushionLayer : CushionLayer {
            attribute :>> material {
                attribute :>> softness = 0.90;
                attribute :>> thickness = 2.0[mm];
                attribute :>> breathability = 0.85;
            }
            attribute :>> contactArea = 20.0[cm^2];
        }
        
        connection padToCushion connect occlusivePad.comfort to cushionLayer.comfort;
        connection strapToPad connect adjustableStrap.securement to occlusivePad.lightProtection;
        
        perform action provideProtection : ProvideEyeProtection {
            in ambientLight;
            in headCircumference;
            out eyeProtected;
            out wearerComfort;
        }
        
        exhibit state operationalStates : EyepatchOperationalStates;
    }
    
    part def Eyepatch {
        doc /* 
            The Eyepatch is a wearable medical device consisting of an occlusive pad, 
            adjustable retention strap, and cushioning layer that work together to 
            protect an eye from light exposure and physical contact during recovery.
        */
        
        part occlusivePad : OcclusivePad;
        part adjustableStrap : AdjustableStrap;
        part cushionLayer : CushionLayer;
        
        attribute totalMass : MassValue;
        attribute operationalDuration : TimeValue;
        attribute protectionEffectiveness : LightBlockagePercentage;
    }
}
