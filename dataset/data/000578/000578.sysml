package CrutchMobilitySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def LoadCapacity :> ISQ::MassValue;
    attribute def HeightAdjustment :> ISQ::LengthValue;
    attribute def StabilityRating :> Real;
    
    value def CrutchHeight :> ISQ::LengthValue;
    value def UserHeight :> ISQ::LengthValue;
    value def BodyWeight :> ISQ::MassValue;
    value def GripPressure :> ISQ::PressureValue;
    
    item def StructuralMaterial {
        attribute tensileStrength : ISQ::PressureValue;
        attribute density : ISQ::DensityValue;
        attribute fatigueResistance : Real;
    }
    
    port def LoadTransferPort {
        in appliedForce : ISQ::ForceValue;
        out reactionForce : ISQ::ForceValue;
        attribute contactArea : ISQ::AreaValue;
    }
    
    port def HeightAdjustmentPort {
        in requestedHeight : ISQ::LengthValue;
        out actualHeight : ISQ::LengthValue;
        attribute isLocked : Boolean;
    }
    
    port def StabilityPort {
        in groundContact : Boolean;
        out stabilityFactor : Real;
        attribute frictionCoefficient : Real;
    }
    
    part def UnderarmCuff {
        attribute paddingThickness : ISQ::LengthValue;
        attribute cuffWidth : ISQ::LengthValue;
        attribute material : StructuralMaterial;
        port loadInterface : LoadTransferPort;
        
        assert constraint comfortConstraint {
            loadInterface.contactArea >= 40.0 * (SI::cm^2)
        }
    }
    
    part def HandGrip {
        attribute gripDiameter : ISQ::LengthValue;
        attribute gripAngle : ISQ::AngleValue;
        attribute surfaceTexture : Real;
        port gripInterface : LoadTransferPort;
        
        assert constraint ergonomicConstraint {
            gripDiameter >= 2.5 * SI::cm and gripDiameter <= 3.5 * SI::cm
        }
    }
    
    part def TelescopicShaft {
        attribute minHeight : ISQ::LengthValue;
        attribute maxHeight : ISQ::LengthValue;
        attribute wallThickness : ISQ::LengthValue;
        attribute shaftMaterial : StructuralMaterial;
        port heightControl : HeightAdjustmentPort;
        
        assert constraint rangeConstraint {
            heightControl.actualHeight >= minHeight and 
            heightControl.actualHeight <= maxHeight
        }
    }
    
    part def HeightLockMechanism {
        attribute numberOfPositions : Integer;
        attribute lockingStrength : ISQ::ForceValue;
        attribute engaged : Boolean;
        
        assert constraint lockStrengthConstraint {
            lockingStrength >= 600.0 * SI::N
        }
    }
    
    part def RubberFootTip {
        attribute tipDiameter : ISQ::LengthValue;
        attribute treadPattern : String;
        attribute frictionCoeff : Real;
        port groundInterface : StabilityPort;
        
        assert constraint tractionConstraint {
            frictionCoeff >= 0.75
        }
    }
    
    part def Crutch {
        attribute overallWeight : ISQ::MassValue;
        attribute maxUserWeight : LoadCapacity;
        attribute heightIncrements : ISQ::LengthValue;
        
        part cuff : UnderarmCuff {
            attribute :>> paddingThickness = 1.5 * SI::cm;
            attribute :>> cuffWidth = 9.0 * SI::cm;
        }
        
        part grip : HandGrip {
            attribute :>> gripDiameter = 3.0 * SI::cm;
            attribute :>> gripAngle = 12.0 * SI::'°';
        }
        
        part shaft : TelescopicShaft {
            attribute :>> minHeight = 105.0 * SI::cm;
            attribute :>> maxHeight = 150.0 * SI::cm;
            attribute :>> wallThickness = 2.0 * SI::mm;
        }
        
        part lockingPin : HeightLockMechanism {
            attribute :>> numberOfPositions = 10;
            attribute :>> engaged = true;
        }
        
        part footTip : RubberFootTip {
            attribute :>> tipDiameter = 3.0 * SI::cm;
            attribute :>> frictionCoeff = 0.85;
        }
        
        connection upperLoad connect cuff.loadInterface to shaft.heightControl;
        connection midLoad connect grip.gripInterface to shaft.heightControl;
        connection lowerStability connect shaft.heightControl to footTip.groundInterface;
        
        assert constraint totalWeightConstraint {
            overallWeight <= 0.8 * SI::kg
        }
        
        assert constraint loadCapacityConstraint {
            maxUserWeight >= 140.0 * SI::kg
        }
    }
    
    action def ConfigureHeight {
        in targetUserHeight : UserHeight;
        in currentHeight : CrutchHeight;
        out finalHeight : CrutchHeight;
        
        first start;
        then action calculateOptimalHeight {
            doc /* Determine optimal crutch height based on user anthropometry */
        }
        then action releaseHeightLock;
        then action adjustShaftLength;
        then action engageHeightLock;
        then action verifyLockEngagement;
        then done;
    }
    
    action def DistributeBodyWeight {
        in totalWeight : BodyWeight;
        in supportAngle : ISQ::AngleValue;
        in terrainCondition : Real;
        out effectiveLoad : ISQ::ForceValue;
        out stabilityIndex : Real;
        
        assert constraint optimalAngleConstraint {
            supportAngle >= 10.0 * SI::'°' and supportAngle <= 30.0 * SI::'°'
        }
    }
    
    action def ProvideMobilityAssistance {
        in userBodyWeight : BodyWeight;
        in surfaceType : String;
        in walkingSpeed : ISQ::SpeedValue;
        out supportQuality : Real;
        out energyEfficiency : Real;
        
        first start;
        then action establishGroundContact;
        then action applyHandGrip;
        then merge assistanceCycle;
        
        action distributeLoad : DistributeBodyWeight {
            in totalWeight = userBodyWeight;
            in supportAngle;
            in terrainCondition;
            out effectiveLoad;
            out stabilityIndex;
        }
        
        then decide;
            if distributeLoad.stabilityIndex >= 0.85 then continueSupport;
            if distributeLoad.stabilityIndex < 0.85 then repositionCrutch;
        
        action continueSupport {
            doc /* Maintain stable weight-bearing support during gait cycle */
        }
        then assistanceCycle;
        
        action repositionCrutch {
            doc /* Adjust crutch position to improve stability */
        }
        then assistanceCycle;
        
        accept when done;
    }
    
    action def HeightAdjustmentRequest;
    action def WeightApplication;
    action def WeightRelease;
    action def StorageCommand;
    action def MaintenanceRequired;
    action def MaintenanceComplete;
    
    state def CrutchLifecycle {
        entry; then stored;
        
        state stored {
            doc /* Crutch is not in active use and stored safely */
        }
        
        transition stored_to_configuring
            first stored
            accept HeightAdjustmentRequest
            then configuring;
        
        state configuring {
            entry; do action heightConfig : ConfigureHeight;
            doc /* Height adjustment and fitting in progress */
        }
        
        transition configuring_to_ready
            first configuring
            if heightConfig.finalHeight != null
            then ready;
        
        state ready {
            doc /* Crutch is properly configured and ready for weight bearing */
        }
        
        transition ready_to_activeSupport
            first ready
            accept WeightApplication
            then activeSupport;
        
        state activeSupport {
            entry; do action mobilityAssist : ProvideMobilityAssistance;
            doc /* Actively supporting user during ambulation */
        }
        
        transition activeSupport_to_ready
            first activeSupport
            accept WeightRelease
            then ready;
        
        transition ready_to_stored
            first ready
            accept StorageCommand
            then stored;
        
        transition activeSupport_to_maintenance
            first activeSupport
            accept MaintenanceRequired
            then maintenance;
        
        state maintenance {
            doc /* Crutch requires inspection or component replacement */
        }
        
        transition maintenance_to_stored
            first maintenance
            accept MaintenanceComplete
            then stored;
    }
    
    part crutchAssembly : Crutch {
        perform action assistMobility : ProvideMobilityAssistance;
        exhibit state lifecycle : CrutchLifecycle;
    }
    
    requirement def <'REQ-001'> MobilityEnablementRequirement {
        doc /* The crutch system shall enable safe and stable ambulation 
               for users with lower extremity impairment or injury. */
        
        subject crutchAssembly : Crutch;
        
        require constraint {
            crutchAssembly.maxUserWeight >= 140.0 * SI::kg
        }
        
        require constraint {
            crutchAssembly.shaft.maxHeight - crutchAssembly.shaft.minHeight >= 40.0 * SI::cm
        }
    }
    
    requirement def <'REQ-002'> StructuralIntegrityRequirement {
        doc /* The crutch shall maintain structural integrity under 
               maximum rated load without failure or permanent deformation. */
        
        subject crutchAssembly : Crutch;
        
        require constraint {
            crutchAssembly.lockingPin.lockingStrength >= 600.0 * SI::N
        }
        
        require constraint {
            crutchAssembly.footTip.frictionCoeff >= 0.75
        }
    }
    
    requirement def <'REQ-003'> UserComfortRequirement {
        doc /* The crutch shall provide ergonomic support minimizing 
               user discomfort during extended use periods. */
        
        subject crutchAssembly : Crutch;
        
        require constraint {
            crutchAssembly.cuff.cuffWidth >= 8.0 * SI::cm
        }
        
        require constraint {
            crutchAssembly.grip.gripAngle >= 10.0 * SI::'°' and
            crutchAssembly.grip.gripAngle <= 15.0 * SI::'°'
        }
    }
    
    requirement def <'REQ-004'> AdjustabilityRequirement {
        doc /* The crutch shall accommodate users of varying heights 
               through secure, repeatable height adjustment. */
        
        subject crutchAssembly : Crutch;
        
        require constraint {
            crutchAssembly.lockingPin.numberOfPositions >= 8
        }
        
        require constraint {
            crutchAssembly.heightIncrements <= 2.5 * SI::cm
        }
    }
    
    requirement systemRequirements {
        doc /* Comprehensive requirements for the crutch mobility assistance system 
               ensuring safe, comfortable, and effective user support. */
        
        require req1 : MobilityEnablementRequirement;
        require req2 : StructuralIntegrityRequirement;
        require req3 : UserComfortRequirement;
        require req4 : AdjustabilityRequirement;
    }
}
