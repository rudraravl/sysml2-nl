package 'Punctal Plug System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def PlugDimension {
        attribute diameter : LengthValue;
        attribute length : LengthValue;
    }

    attribute def TearFlowRate :> ISQ::VolumeFlowRateValue;
    attribute def TearVolume :> ISQ::VolumeValue;
    attribute def OcclusionEfficiency :> Real;

    enum def PlugMaterialType {
        silicone;
        collagen;
        acrylic;
        hydrogel;
    }

    enum def PlugPlacementStatus {
        uninserted;
        inserting;
        seated;
        displaced;
        removed;
    }

    item def TearFluid {
        attribute flowRate : TearFlowRate;
        attribute volume : TearVolume;
        attribute osmolarity : Real;
    }

    item def InsertionCommand;
    item def RemovalCommand;

    port def TearFlowPort {
        in item tearIn : TearFluid;
        out item tearOut : TearFluid;
    }

    part def Punctum {
        attribute diameter : LengthValue;
        attribute location : String;
        port tearDrainagePort : TearFlowPort;
    }

    part def LacrimalCanaliculus {
        attribute diameter : LengthValue;
        port canaliculusPort : TearFlowPort;
    }

    part def LacrimalDrainageSystem {
        part upperPunctum : Punctum {
            attribute :>> location = "upper";
            attribute :>> diameter = 0.3 [mm];
        }
        part lowerPunctum : Punctum {
            attribute :>> location = "lower";
            attribute :>> diameter = 0.3 [mm];
        }
        part canaliculus : LacrimalCanaliculus {
            attribute :>> diameter = 0.5 [mm];
        }
        attribute baselineTearDrainageRate : TearFlowRate;
        attribute currentTearDrainageRate : TearFlowRate;

        connection upperDrainage connect upperPunctum.tearDrainagePort to canaliculus.canaliculusPort;
        connection lowerDrainage connect lowerPunctum.tearDrainagePort to canaliculus.canaliculusPort;
    }

    part def PunctalPlug {
        attribute dimensions : PlugDimension;
        attribute material : PlugMaterialType;
        attribute occlusionEfficiency : OcclusionEfficiency;
        attribute placementStatus : PlugPlacementStatus;
        port plugInterface : TearFlowPort;

        ref part targetPunctum : Punctum;
    }

    part def OcularSurface {
        attribute tearFilmVolume : TearVolume;
        attribute targetTearVolume : TearVolume;
        attribute surfaceHealth : Real;
    }

    action def InsertPlugAction {
        in plug : PunctalPlug;
        in targetSite : Punctum;
        out status : PlugPlacementStatus;
        private attribute fitAcceptable : Boolean;

        first start;
        then action positionPlug;
        then action verifyFit {
            assign fitAcceptable := plug.dimensions.diameter >= targetSite.diameter * 1.1;
        }
        then decide;
            if fitAcceptable then seated;
            if not fitAcceptable then failed;
        action seated {
            assign status := PlugPlacementStatus::seated;
        }
        action failed {
            assign status := PlugPlacementStatus::displaced;
        }
        then done;
    }

    action def OccludeTearDrainage {
        in baselineFlow : TearFlowRate;
        in occlusionEfficiency : OcclusionEfficiency;
        out reducedFlow : TearFlowRate;
        out retainedVolume : TearVolume;

        first start;
        then action calculateReduction {
            assign reducedFlow := baselineFlow * (1.0 - occlusionEfficiency);
        }
        then action computeRetention {
            assign retainedVolume := (baselineFlow - reducedFlow) * 60.0 [s];
        }
        then done;
    }

    action def MonitorTearRetention {
        in currentVolume : TearVolume;
        in targetVolume : TearVolume;
        out adequateRetention : Boolean;

        first start;
        then decide;
            if currentVolume >= targetVolume then adequate;
            if currentVolume < targetVolume then inadequate;
        action adequate {
            assign adequateRetention := true;
        }
        action inadequate {
            assign adequateRetention := false;
        }
        then done;
    }

    state def PlugOperationalStateMachine {
        in attribute performInsertion : InsertPlugAction;
        in attribute monitorRetention : MonitorTearRetention;
        attribute currentStatus : PlugPlacementStatus;

        entry; then idle;

        state idle {
            entry assign currentStatus := PlugPlacementStatus::uninserted;
        }
        transition idle_to_insertion
            first idle
            accept InsertionCommand
            then insertion;

        state insertion;
        transition insertion_to_occluding
            first insertion
            if performInsertion.status == PlugPlacementStatus::seated
            then occluding;
        transition insertion_to_failed
            first insertion
            if performInsertion.status == PlugPlacementStatus::displaced
            then failed;

        state occluding {
            entry assign currentStatus := PlugPlacementStatus::seated;
        }
        transition occluding_to_monitoring
            first occluding
            then monitoring;

        state monitoring;
        transition monitoring_to_occluding
            first monitoring
            if monitorRetention.adequateRetention
            then occluding;
        transition monitoring_to_displaced
            first monitoring
            if not monitorRetention.adequateRetention
            then displaced;

        state displaced {
            entry assign currentStatus := PlugPlacementStatus::displaced;
        }
        transition displaced_to_idle
            first displaced
            accept RemovalCommand
            then idle;

        state failed;
        transition failed_to_idle
            first failed
            accept RemovalCommand
            then idle;
    }

    action def ManageDryEyeTreatment {
        in targetVolume : TearVolume;
        in baselineFlow : TearFlowRate;
        in occlusionEfficiency : OcclusionEfficiency;
        inout surfaceVolume : TearVolume;
        inout drainageRate : TearFlowRate;

        first start;
        then merge continueMonitoring;

        then action insertPlug : InsertPlugAction {
            in plug;
            in targetSite;
            out status;
        }
        then decide;
            if insertPlug.status == PlugPlacementStatus::seated then occlude;
            if insertPlug.status != PlugPlacementStatus::seated then handleFailure;

        action occlude : OccludeTearDrainage {
            in baselineFlow = baselineFlow;
            in occlusionEfficiency = occlusionEfficiency;
            out reducedFlow;
            out retainedVolume;
        }
        then assign drainageRate := occlude.reducedFlow;
        then assign surfaceVolume := surfaceVolume + occlude.retainedVolume;
        then continueMonitoring;

        then action monitor : MonitorTearRetention {
            in currentVolume = surfaceVolume;
            in targetVolume = targetVolume;
            out adequateRetention;
        }
        then decide;
            if monitor.adequateRetention then continueMonitoring;
            if not monitor.adequateRetention then adjustTreatment;

        action adjustTreatment;
        then done;

        action handleFailure;
        then done;
    }

    part punctalPlugTreatmentSystem {
        part ocularSurface : OcularSurface {
            attribute :>> tearFilmVolume = 7.0 [mm^3];
            attribute :>> targetTearVolume = 10.0 [mm^3];
            attribute :>> surfaceHealth = 0.6;
        }

        part drainageSystem : LacrimalDrainageSystem {
            attribute :>> baselineTearDrainageRate = 1.2 [mm^3/min];
            attribute :>> currentTearDrainageRate = 1.2 [mm^3/min];
        }

        part plug : PunctalPlug {
            attribute :>> dimensions {
                attribute :>> diameter = 0.4 [mm];
                attribute :>> length = 2.0 [mm];
            }
            attribute :>> material = PlugMaterialType::silicone;
            attribute :>> occlusionEfficiency = 0.90;
            attribute :>> placementStatus = PlugPlacementStatus::uninserted;

            bind targetPunctum = drainageSystem.lowerPunctum;
        }

        connection plugPlacement connect 
            plug.plugInterface to drainageSystem.lowerPunctum.tearDrainagePort;

        perform action treatmentManagement : ManageDryEyeTreatment {
            in targetVolume = ocularSurface.targetTearVolume;
            in baselineFlow = drainageSystem.baselineTearDrainageRate;
            in occlusionEfficiency = plug.occlusionEfficiency;
            inout surfaceVolume = ocularSurface.tearFilmVolume;
            inout drainageRate = drainageSystem.currentTearDrainageRate;
        }
    }

    requirement def OcclusionEfficiencyRequirement {
        doc /* The punctal plug shall occlude tear drainage with a minimum efficiency of 85 percent 
                to effectively reduce tear loss from the ocular surface. */

        subject plug : PunctalPlug;

        require constraint {
            plug.occlusionEfficiency >= 0.85
        }
    }

    requirement def BiocompatibilityRequirement {
        doc /* The punctal plug shall be manufactured from biocompatible materials 
                approved for long-term ocular contact to prevent adverse tissue reactions. */

        subject plug : PunctalPlug;
    }

    requirement def SizingRequirement {
        doc /* The punctal plug diameter shall be appropriately sized to match the target punctum 
                to ensure proper seating and retention without causing trauma. */

        subject system : PunctalPlug;
        subject site : Punctum;

        require constraint {
            system.dimensions.diameter >= site.diameter * 1.1 and
            system.dimensions.diameter <= site.diameter * 1.5
        }
    }

    requirement <'1'> primaryFunctionRequirement {
        doc /* Primary Function: The punctal plug system functions to reduce tear drainage from the eye 
                by physically occluding the punctal opening in the lacrimal drainage pathway. 
                This occlusion increases tear film retention on the ocular surface, thereby alleviating 
                symptoms of dry eye disease by maintaining adequate tear volume and improving ocular surface health. */

        subject sys : punctalPlugTreatmentSystem;

        assume constraint baselineFlowAssumption {
            sys.drainageSystem.baselineTearDrainageRate > 0.0 [mm^3/min]
        }

        require occlusionReq : OcclusionEfficiencyRequirement {
            subject plug = sys.plug;
        }
        require biocompatReq : BiocompatibilityRequirement {
            subject plug = sys.plug;
        }
        require sizingReq : SizingRequirement {
            subject system = sys.plug;
            subject site = sys.drainageSystem.lowerPunctum;
        }
    }

    requirement <'2'> tearRetentionPerformanceRequirement {
        doc /* The system shall maintain tear film volume at or above the target therapeutic level 
                during normal operation to provide clinical benefit. */

        subject sys : punctalPlugTreatmentSystem;

        require constraint {
            sys.ocularSurface.tearFilmVolume >= 
            sys.ocularSurface.targetTearVolume
        }
    }

    requirement systemRequirements {
        doc /* Complete system requirements for punctal plug dry eye treatment. */

        require primaryFunctionRequirement;
        require tearRetentionPerformanceRequirement;
    }
}
