package 'Low Dead Space Syringe System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidType;
    attribute def MaterialType;
    
    item def Medication {
        attribute medicationType : FluidType;
        attribute concentration : Real;
        attribute volume : ISQ::VolumeValue;
    }
    
    port def FluidPort {
        in attribute fluidIn : Medication;
        out attribute fluidOut : Medication;
        attribute flowRate : ISQ::VolumeValue;
        attribute pressure : ISQ::PressureValue;
    }
    
    port def MechanicalPort {
        in attribute appliedForce : ISQ::ForceValue;
        out attribute displacement : ISQ::LengthValue;
    }
    
    part def Barrel {
        doc /* Cylindrical chamber that holds the medication. */
        attribute innerDiameter : ISQ::LengthValue;
        attribute length : ISQ::LengthValue;
        attribute capacity : ISQ::VolumeValue;
        attribute material : MaterialType;
        port fluidChamber : FluidPort;
    }
    
    part def Plunger {
        doc /* Movable component that creates pressure to expel fluid. */
        attribute position : ISQ::LengthValue;
        attribute sealDiameter : ISQ::LengthValue;
        attribute sealMaterial : MaterialType;
        port mechanicalInterface : MechanicalPort;
    }
    
    part def Needle {
        doc /* Hollow tube for fluid delivery. */
        attribute gaugeSize : Real;
        attribute length : ISQ::LengthValue;
        attribute innerDiameter : ISQ::LengthValue;
        attribute bevelAngle : Real;
        port fluidOutput : FluidPort;
    }
    
    part def LowDeadSpaceTip {
        doc /* Specialized tip design minimizing void space between plunger seal and needle hub. */
        attribute residualVolume : ISQ::VolumeValue;
        attribute tipGeometry : String;
        attribute hubDeadSpace : ISQ::VolumeValue;
    }
    
    connection def PlungerBarrelConnection {
        end plungerEnd : Plunger;
        end barrelEnd : Barrel;
    }
    
    connection def TipNeedleConnection {
        end tipEnd : LowDeadSpaceTip;
        end needleEnd : Needle;
    }
    
    connection def BarrelTipConnection {
        end barrelEnd : Barrel;
        end tipEnd : LowDeadSpaceTip;
    }
    
    part def LowDeadSpaceSyringe {
        doc /* A syringe designed to minimize residual fluid volume after injection,
               reducing medication waste and improving dosing accuracy. */
        
        attribute nominalCapacity : ISQ::VolumeValue;
        attribute deadSpaceVolume : ISQ::VolumeValue;
        attribute currentVolume : ISQ::VolumeValue;
        attribute sterile : Boolean;
        
        port fluidInterface : FluidPort;
        port plungerInterface : MechanicalPort;
        
        part barrel : Barrel;
        part plunger : Plunger;
        part needle : Needle;
        part tip : LowDeadSpaceTip;
        
        connection plungerToBarrel : PlungerBarrelConnection 
            connect plunger to barrel;
        connection tipToNeedle : TipNeedleConnection 
            connect tip to needle;
        connection barrelToTip : BarrelTipConnection 
            connect barrel to tip;
    }
    
    action def DrawMedication {
        doc /* Draw medication from vial into syringe barrel. */
        in targetVolume : ISQ::VolumeValue;
        in sourceMedication : Medication;
        in vialPressure : ISQ::PressureValue;
        out drawnVolume : ISQ::VolumeValue;
        out chamberPressure : ISQ::PressureValue;
    }
    
    action def ExpelAir {
        doc /* Remove air bubbles from syringe to ensure accurate dosing. */
        in currentVolume : ISQ::VolumeValue;
        out airVolume : ISQ::VolumeValue;
        out adjustedVolume : ISQ::VolumeValue;
    }
    
    action def InjectMedication {
        doc /* Deliver medication through needle into patient. */
        in volumeToInject : ISQ::VolumeValue;
        in injectionForce : ISQ::ForceValue;
        in injectionSite : String;
        out deliveredVolume : ISQ::VolumeValue;
        out residualVolume : ISQ::VolumeValue;
        out injectionPressure : ISQ::PressureValue;
    }
    
    action def MinimizeWaste {
        doc /* Optimize plunger position to minimize dead space volume. */
        in plungerPosition : ISQ::LengthValue;
        in tipGeometry : String;
        out achievedDeadSpace : ISQ::VolumeValue;
    }
    
    action def AdministerDose {
        doc /* Primary function: Deliver precise medication dose with minimal waste. */
        
        in prescribedDose : ISQ::VolumeValue;
        in medication : Medication;
        in patientSite : String;
        out actualDeliveredDose : ISQ::VolumeValue;
        out wastedMedication : ISQ::VolumeValue;
        out dosageAccuracy : Real;
        
        first start;
        
        then action prepareSyringe {
            action inspectIntegrity;
            then action attachNeedle;
            then action ensureSterility;
        }
        
        then action drawDose : DrawMedication {
            in targetVolume = prescribedDose;
            in sourceMedication = medication;
            in vialPressure;
            out drawnVolume;
            out chamberPressure;
        }
        
        then action removeAir : ExpelAir {
            in currentVolume = drawDose.drawnVolume;
            out airVolume;
            out adjustedVolume;
        }
        
        then action positionForInjection {
            in site = patientSite;
        }
        
        then action inject : InjectMedication {
            in volumeToInject = removeAir.adjustedVolume;
            in injectionForce;
            in injectionSite = patientSite;
            out deliveredVolume;
            out residualVolume;
            out injectionPressure;
        }
        
        then action optimizeDeadSpace : MinimizeWaste {
            in plungerPosition;
            in tipGeometry;
            out achievedDeadSpace;
        }
        
        then assign actualDeliveredDose := inject.deliveredVolume;
        then assign wastedMedication := inject.residualVolume;
        then assign dosageAccuracy := (actualDeliveredDose / prescribedDose) * 100.0;
        
        then done;
    }
    
    state def SyringeOperationStates {
        doc /* State machine governing syringe operation lifecycle. */
        
        entry; then idle;
        
        state idle {
            doc /* Syringe is ready for use but not actively engaged. */
        }
        
        transition idle_to_drawing
            first idle
            accept DrawCommand
            then drawing;
        
        state drawing {
            doc /* Medication is being drawn into the barrel. */
            do action drawingAction : DrawMedication;
        }
        
        transition drawing_to_primed
            first drawing
            if drawingAction.drawnVolume > 0.0 [mL]
            then primed;
        
        state primed {
            doc /* Syringe contains medication and is ready for injection. */
        }
        
        transition primed_to_deairing
            first primed
            accept DeairCommand
            then deairing;
        
        state deairing {
            doc /* Air bubbles are being expelled from the syringe. */
            do action deairingAction : ExpelAir;
        }
        
        transition deairing_to_ready
            first deairing
            if deairingAction.airVolume >= 0.0 [mL]
            then ready;
        
        state ready {
            doc /* Syringe is prepared and positioned for injection. */
        }
        
        transition ready_to_injecting
            first ready
            accept InjectCommand
            then injecting;
        
        state injecting {
            doc /* Medication is being delivered to patient. */
            do action injectingAction : InjectMedication;
        }
        
        transition injecting_to_complete
            first injecting
            if injectingAction.residualVolume <= maxAllowedDeadSpace
            then complete;
        
        state complete {
            doc /* Injection is complete with minimal waste. */
        }
        
        transition complete_to_disposed
            first complete
            accept DisposeCommand
            then disposed;
        
        state disposed {
            doc /* Syringe has been safely disposed. */
        }
        
        attribute maxAllowedDeadSpace : ISQ::VolumeValue;
    }
    
    requirement def MinimizeDeadSpaceRequirement {
        doc /* The syringe shall minimize dead space volume to reduce medication waste. */
        
        subject syringe : LowDeadSpaceSyringe;
        
        require constraint deadSpaceLimit {
            syringe.deadSpaceVolume <= 0.002 [mL]
        }
    }
    
    requirement def DoseAccuracyRequirement {
        doc /* The syringe shall deliver medication doses with high accuracy. */
        
        subject syringe : LowDeadSpaceSyringe;
        
        attribute deliveredVolume : ISQ::VolumeValue;
        attribute prescribedVolume : ISQ::VolumeValue;
        
        require constraint accuracyTolerance {
            (deliveredVolume - prescribedVolume) / prescribedVolume <= 0.02 and
            (prescribedVolume - deliveredVolume) / prescribedVolume <= 0.02
        }
    }
    
    requirement def WasteReductionRequirement {
        doc /* The syringe shall reduce medication waste compared to standard syringes. */
        
        subject syringe : LowDeadSpaceSyringe;
        
        attribute standardDeadSpace : ISQ::VolumeValue = 0.010 [mL];
        
        require constraint wasteReduction {
            (standardDeadSpace - syringe.deadSpaceVolume) / standardDeadSpace >= 0.80
        }
    }
    
    requirement def SterilityRequirement {
        doc /* The syringe shall maintain sterility until use. */
        
        subject syringe : LowDeadSpaceSyringe;
        
        require constraint maintainSterility {
            syringe.sterile == true
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for low dead space syringe system. */
        
        require req1 : MinimizeDeadSpaceRequirement;
        require req2 : DoseAccuracyRequirement;
        require req3 : WasteReductionRequirement;
        require req4 : SterilityRequirement;
    }
    
    part lowDeadSpaceSyringeSystem : LowDeadSpaceSyringe {
        doc /* Complete low dead space syringe system instance. */
        
        attribute :>> nominalCapacity = 1.0 [mL];
        attribute :>> deadSpaceVolume = 0.0015 [mL];
        attribute :>> currentVolume = 0.0 [mL];
        attribute :>> sterile = true;
        
        part :>> barrel {
            attribute :>> innerDiameter = 4.7 [mm];
            attribute :>> length = 60.0 [mm];
            attribute :>> capacity = 1.0 [mL];
            attribute :>> material = "Medical Grade Polypropylene";
        }
        
        part :>> plunger {
            attribute :>> position = 0.0 [mm];
            attribute :>> sealDiameter = 4.65 [mm];
            attribute :>> sealMaterial = "Synthetic Rubber";
        }
        
        part :>> needle {
            attribute :>> gaugeSize = 25.0;
            attribute :>> length = 16.0 [mm];
            attribute :>> innerDiameter = 0.25 [mm];
            attribute :>> bevelAngle = 12.0;
        }
        
        part :>> tip {
            attribute :>> residualVolume = 0.0007 [mL];
            attribute :>> tipGeometry = "Conical Low Dead Space";
            attribute :>> hubDeadSpace = 0.0008 [mL];
        }
        
        perform action primaryFunction : AdministerDose {
            in prescribedDose = 0.5 [mL];
            in medication;
            in patientSite = "Deltoid Muscle";
            out actualDeliveredDose;
            out wastedMedication;
            out dosageAccuracy;
        }
        
        exhibit state operationStateMachine : SyringeOperationStates {
            attribute :>> maxAllowedDeadSpace = 0.002 [mL];
        }
    }
    
    attribute def DrawCommand;
    attribute def DeairCommand;
    attribute def InjectCommand;
    attribute def DisposeCommand;
}
