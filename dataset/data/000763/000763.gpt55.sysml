package ShirleyDrainModel {

    import ScalarValues::*;

    attribute def Quantity {
        attribute value : Real;
        attribute unit : String;
    }

    attribute def Length :> Quantity {
        :>> unit = "m";
    }

    attribute def Area :> Quantity {
        :>> unit = "m^2";
    }

    attribute def Volume :> Quantity {
        :>> unit = "m^3";
    }

    attribute def FlowRate :> Quantity {
        :>> unit = "m^3/s";
    }

    attribute def Velocity :> Quantity {
        :>> unit = "m/s";
    }

    attribute def Slope :> Quantity {
        :>> unit = "m/m";
    }

    attribute def Porosity :> Quantity {
        :>> unit = "1";
    }

    attribute def Diameter :> Quantity {
        :>> unit = "mm";
    }

    attribute def Mass :> Quantity {
        :>> unit = "kg";
    }

    attribute def Concentration :> Quantity {
        :>> unit = "mg/L";
    }

    attribute def TimeDuration :> Quantity {
        :>> unit = "min";
    }

    attribute def PressureHead :> Quantity {
        :>> unit = "m";
    }

    attribute def Percentage :> Quantity {
        :>> unit = "%";
    }

    item def StormWater {
        attribute flowRate : FlowRate;
        attribute suspendedSolids : Concentration;
        attribute waterTemperature : Quantity {
            :>> unit = "degC";
        }
    }

    item def GroundWater :> StormWater;

    item def SurfaceRunoff :> StormWater;

    item def FilteredDrainageWater :> StormWater {
        attribute expectedSolidsReduction : Percentage;
    }

    item def Sediment {
        attribute retainedMass : Mass;
        attribute particleDiameterD50 : Diameter;
    }

    item def Debris {
        attribute retainedMass : Mass;
    }

    item def Air {
        attribute ventFlowRate : FlowRate;
    }

    item def MaintenanceAccess {
        attribute openingDiameter : Diameter;
    }

    port def HydraulicInletPort {
        in item incomingWater : StormWater;
        in item incomingDebris : Debris;
    }

    port def HydraulicOutletPort {
        out item dischargedWater : FilteredDrainageWater;
    }

    port def BidirectionalHydraulicPort {
        inout item water : StormWater;
    }

    port def SedimentRemovalPort {
        out item removedSediment : Sediment;
    }

    port def VentPort {
        inout item air : Air;
    }

    port def InspectionPort {
        inout item access : MaintenanceAccess;
    }

    connection def HydraulicConnection {
        end upstream : BidirectionalHydraulicPort;
        end downstream : BidirectionalHydraulicPort;
    }

    connection def VentConnection {
        end lowerVent : VentPort;
        end upperVent : VentPort;
    }

    connection def MaintenanceConnection {
        end accessEnd : InspectionPort;
        end serviceEnd : InspectionPort;
    }

    part def SurfaceCollector {
        doc /* Receives surface runoff and directs it into the Shirley drain hydraulic path. */

        attribute grateOpenArea : Area {
            :>> value = 0.18;
            :>> unit = "m^2";
        }

        attribute maximumAcceptedFlow : FlowRate {
            :>> value = 0.032;
            :>> unit = "m^3/s";
        }

        attribute debrisScreenEfficiency : Percentage {
            :>> value = 65.0;
            :>> unit = "%";
        }

        port runoffIn : HydraulicInletPort;
        port collectorOut : BidirectionalHydraulicPort;
        port airVent : VentPort;
    }

    part def GeotextileFilterWrap {
        doc /* Separates surrounding soil from drainage aggregate while allowing water migration into the drain. */

        attribute wrapArea : Area {
            :>> value = 42.0;
            :>> unit = "m^2";
        }

        attribute apparentOpeningSize : Diameter {
            :>> value = 0.21;
            :>> unit = "mm";
        }

        attribute permittivity : Quantity {
            :>> value = 1.4;
            :>> unit = "1/s";
        }

        attribute soilRetentionEfficiency : Percentage {
            :>> value = 95.0;
            :>> unit = "%";
        }

        port soilSide : BidirectionalHydraulicPort;
        port aggregateSide : BidirectionalHydraulicPort;
    }

    part def GradedAggregateEnvelope {
        doc /* Provides void storage and hydraulic conductivity around the perforated collector pipe. */

        attribute trenchLength : Length {
            :>> value = 18.0;
            :>> unit = "m";
        }

        attribute trenchWidth : Length {
            :>> value = 0.60;
            :>> unit = "m";
        }

        attribute trenchDepth : Length {
            :>> value = 0.90;
            :>> unit = "m";
        }

        attribute aggregatePorosity : Porosity {
            :>> value = 0.36;
            :>> unit = "1";
        }

        attribute availableVoidVolume : Volume {
            :>> value = 3.50;
            :>> unit = "m^3";
        }

        attribute hydraulicConductivity : Velocity {
            :>> value = 0.015;
            :>> unit = "m/s";
        }

        port filterSide : BidirectionalHydraulicPort;
        port pipeSide : BidirectionalHydraulicPort;
    }

    part def PerforatedCollectorPipe {
        doc /* Collects infiltrating water from the aggregate envelope and conveys it by gravity toward the sump and outlet. */

        attribute pipeLength : Length {
            :>> value = 18.0;
            :>> unit = "m";
        }

        attribute nominalDiameter : Diameter {
            :>> value = 150.0;
            :>> unit = "mm";
        }

        attribute longitudinalSlope : Slope {
            :>> value = 0.012;
            :>> unit = "m/m";
        }

        attribute perforationArea : Area {
            :>> value = 0.045;
            :>> unit = "m^2";
        }

        attribute designPipeCapacity : FlowRate {
            :>> value = 0.040;
            :>> unit = "m^3/s";
        }

        port lateralInflow : BidirectionalHydraulicPort;
        port upstreamEnd : BidirectionalHydraulicPort;
        port downstreamEnd : BidirectionalHydraulicPort;
        port vent : VentPort;
    }

    part def SedimentSump {
        doc /* Slows incoming flow, captures coarse sediment, and provides a serviceable volume for maintenance removal. */

        attribute sumpDepth : Length {
            :>> value = 0.75;
            :>> unit = "m";
        }

        attribute sumpDiameter : Diameter {
            :>> value = 600.0;
            :>> unit = "mm";
        }

        attribute sedimentStorageVolume : Volume {
            :>> value = 0.18;
            :>> unit = "m^3";
        }

        attribute minimumSettleResidenceTime : TimeDuration {
            :>> value = 2.0;
            :>> unit = "min";
        }

        port inlet : BidirectionalHydraulicPort;
        port outlet : BidirectionalHydraulicPort;
        port cleanout : SedimentRemovalPort;
        port inspection : InspectionPort;
        port vent : VentPort;
    }

    part def OutletControl {
        doc /* Limits reverse flow, stabilizes discharge, and routes collected water to a safe outfall. */

        attribute invertLevelAboveDatum : Length {
            :>> value = 0.42;
            :>> unit = "m";
        }

        attribute maximumDischargeCapacity : FlowRate {
            :>> value = 0.035;
            :>> unit = "m^3/s";
        }

        attribute backflowPreventionHead : PressureHead {
            :>> value = 0.30;
            :>> unit = "m";
        }

        port inlet : BidirectionalHydraulicPort;
        port outlet : HydraulicOutletPort;
        port bypassInlet : BidirectionalHydraulicPort;
    }

    part def OverflowBypass {
        doc /* Provides high-flow relief when inflow exceeds the normal collector capacity. */

        attribute bypassActivationHead : PressureHead {
            :>> value = 0.20;
            :>> unit = "m";
        }

        attribute bypassCapacity : FlowRate {
            :>> value = 0.020;
            :>> unit = "m^3/s";
        }

        port inlet : BidirectionalHydraulicPort;
        port outlet : BidirectionalHydraulicPort;
    }

    part def InspectionRiser {
        doc /* Enables visual inspection, jetting, and sediment removal without excavating the drain. */

        attribute riserHeight : Length {
            :>> value = 0.85;
            :>> unit = "m";
        }

        attribute accessDiameter : Diameter {
            :>> value = 300.0;
            :>> unit = "mm";
        }

        port accessTop : InspectionPort;
        port accessBase : InspectionPort;
        port ventTop : VentPort;
        port ventBase : VentPort;
    }

    part def SafeOutfall {
        doc /* Receives discharge and conveys it away from the protected area without erosion or flooding. */

        attribute receivingChannelCapacity : FlowRate {
            :>> value = 0.060;
            :>> unit = "m^3/s";
        }

        attribute erosionProtectionLength : Length {
            :>> value = 2.5;
            :>> unit = "m";
        }

        port inflow : HydraulicInletPort;
    }

    action def InterceptRunoff {
        in item surfaceWater : SurfaceRunoff;
        out item capturedWater : StormWater;
        doc /* Collect runoff entering the Shirley drain at the surface collector and through the geotextile-wrapped aggregate trench. */
    }

    action def FilterSoilAndDebris {
        in item unfilteredWater : StormWater;
        out item filteredWater : StormWater;
        out item retainedSolids : Sediment;
        doc /* Retain soil particles, leaf debris, and coarse sediment before water reaches the collector pipe. */
    }

    action def StoreTemporaryVolume {
        in item inflow : StormWater;
        out item equalizedFlow : StormWater;
        doc /* Temporarily hold water in aggregate voids and sump volume to reduce short-duration hydraulic peaks. */
    }

    action def ConveyByGravity {
        in item collectedWater : StormWater;
        out item conveyedWater : FilteredDrainageWater;
        doc /* Convey collected water through the sloped perforated pipe and outlet control using gravity flow. */
    }

    action def DischargeToOutfall {
        in item conveyedWater : FilteredDrainageWater;
        out item outfallWater : FilteredDrainageWater;
        doc /* Deliver drained water to the safe outfall without returning water to the protected area. */
    }

    action def PerformShirleyDrainPrimaryFunction {
        in item excessWater : StormWater;
        out item drainedWater : FilteredDrainageWater;

        action intercept : InterceptRunoff;
        action filter : FilterSoilAndDebris;
        action store : StoreTemporaryVolume;
        action convey : ConveyByGravity;
        action discharge : DischargeToOutfall;

        flow intercept.capturedWater to filter.unfilteredWater;
        flow filter.filteredWater to store.inflow;
        flow store.equalizedFlow to convey.collectedWater;
        flow convey.conveyedWater to discharge.conveyedWater;
        flow discharge.outfallWater to drainedWater;

        doc /* High-level primary function: intercept excess surface and near-surface water, separate damaging solids, temporarily buffer flow, and convey the water by gravity to a safe outfall. */
    }

    state def ShirleyDrainOperatingState {
        doc /* Operational modes for a passive Shirley drain. */

        state DryStandby;
        state InterceptingRunoff;
        state FilteringAndCollecting;
        state GravityDraining;
        state HighFlowBypassActive;
        state SedimentLoadedMaintenanceRequired;
        state BlockedFault;

        transition initial then DryStandby;

        transition DryStandby_to_InterceptingRunoff
            first DryStandby
            then InterceptingRunoff
            accept SurfaceRunoff;

        transition InterceptingRunoff_to_FilteringAndCollecting
            first InterceptingRunoff
            then FilteringAndCollecting
            accept StormWater;

        transition FilteringAndCollecting_to_GravityDraining
            first FilteringAndCollecting
            then GravityDraining
            accept FilteredDrainageWater;

        transition GravityDraining_to_DryStandby
            first GravityDraining
            then DryStandby
            accept Air;

        transition FilteringAndCollecting_to_HighFlowBypassActive
            first FilteringAndCollecting
            then HighFlowBypassActive
            accept SurfaceRunoff;

        transition HighFlowBypassActive_to_GravityDraining
            first HighFlowBypassActive
            then GravityDraining
            accept FilteredDrainageWater;

        transition GravityDraining_to_SedimentLoadedMaintenanceRequired
            first GravityDraining
            then SedimentLoadedMaintenanceRequired
            accept Sediment;

        transition SedimentLoadedMaintenanceRequired_to_DryStandby
            first SedimentLoadedMaintenanceRequired
            then DryStandby
            accept MaintenanceAccess;

        transition FilteringAndCollecting_to_BlockedFault
            first FilteringAndCollecting
            then BlockedFault
            accept Debris;
    }

    constraint def CapacityAdequacy {
        in designCapacity : FlowRate;
        in requiredPeakFlow : FlowRate;
        designCapacity.value >= requiredPeakFlow.value;
    }

    constraint def OutfallAdequacy {
        in outfallCapacity : FlowRate;
        in drainDischarge : FlowRate;
        outfallCapacity.value >= drainDischarge.value;
    }

    constraint def SoilRetentionAdequacy {
        in retentionEfficiency : Percentage;
        retentionEfficiency.value >= 90.0;
    }

    constraint def GravitySlopeAdequacy {
        in providedSlope : Slope;
        providedSlope.value >= 0.005;
    }

    constraint def SedimentStorageAdequacy {
        in storageVolume : Volume;
        storageVolume.value >= 0.10;
    }

    requirement def ShirleyDrainPrimaryFunctionRequirement {
        doc /* The Shirley drain system shall provide a passive drainage function that intercepts excess surface and near-surface water, separates sediment and debris, and conveys filtered water by gravity to a safe outfall to reduce local ponding, saturation, and water damage. */

        subject drain : ShirleyDrainSystem;

        require constraint {
            drain.totalDesignCapacity.value >= drain.requiredPeakInflow.value
        }
    }

    requirement def PassiveGravityDrainageRequirement {
        doc /* The system shall operate under gravity flow during normal drainage without requiring external electrical power. */

        subject drain : ShirleyDrainSystem;

        require constraint GravitySlopeAdequacy {
            in providedSlope = drain.collectorPipe.longitudinalSlope;
        }
    }

    requirement def HydraulicCapacityRequirement {
        doc /* The normal collector pipe and outlet control shall pass the design peak inflow without causing prolonged surface ponding at the protected area. */

        subject drain : ShirleyDrainSystem;

        require constraint CapacityAdequacy {
            in designCapacity = drain.totalDesignCapacity;
            in requiredPeakFlow = drain.requiredPeakInflow;
        }
    }

    requirement def SoilAndSedimentControlRequirement {
        doc /* The drain shall limit soil migration into the collector pipe by using a geotextile-wrapped aggregate envelope and a maintainable sediment sump. */

        subject drain : ShirleyDrainSystem;

        require constraint SoilRetentionAdequacy {
            in retentionEfficiency = drain.filterWrap.soilRetentionEfficiency;
        }

        require constraint SedimentStorageAdequacy {
            in storageVolume = drain.sump.sedimentStorageVolume;
        }
    }

    requirement def OutfallProtectionRequirement {
        doc /* The safe outfall shall receive the maximum controlled discharge without backing water into the drain or eroding the discharge area. */

        subject drain : ShirleyDrainSystem;

        require constraint OutfallAdequacy {
            in outfallCapacity = drain.outfall.receivingChannelCapacity;
            in drainDischarge = drain.outletControl.maximumDischargeCapacity;
        }
    }

    requirement def MaintainabilityRequirement {
        doc /* The Shirley drain shall provide inspection and cleanout access to the sump and collector pipe without excavation. */

        subject drain : ShirleyDrainSystem;

        require constraint {
            drain.inspectionRiser.accessDiameter.value >= 300.0
        }
    }

    part def ShirleyDrainSystem {
        doc /* A Shirley drain system is modeled here as a passive, geotextile-lined, aggregate-filled drainage assembly with a perforated collector pipe, sediment sump, overflow path, inspection riser, outlet control, and safe outfall. Its primary high-level function is to collect excess surface and subsurface water and convey it away from a protected area while reducing sediment transport and blockage risk. */

        attribute protectedCatchmentArea : Area {
            :>> value = 420.0;
            :>> unit = "m^2";
        }

        attribute requiredPeakInflow : FlowRate {
            :>> value = 0.028;
            :>> unit = "m^3/s";
        }

        attribute totalDesignCapacity : FlowRate {
            :>> value = 0.035;
            :>> unit = "m^3/s";
        }

        attribute allowableSurfacePondingDuration : TimeDuration {
            :>> value = 10.0;
            :>> unit = "min";
        }

        attribute nominalDrainServiceLife : Quantity {
            :>> value = 25.0;
            :>> unit = "yr";
        }

        port runoffEntry : HydraulicInletPort;
        port groundwaterEntry : BidirectionalHydraulicPort;
        port finalDischarge : HydraulicOutletPort;
        port maintenanceAccess : InspectionPort;
        port atmosphericVent : VentPort;

        part surfaceCollector : SurfaceCollector;
        part filterWrap : GeotextileFilterWrap;
        part aggregateEnvelope : GradedAggregateEnvelope;
        part collectorPipe : PerforatedCollectorPipe;
        part sump : SedimentSump;
        part outletControl : OutletControl;
        part overflowBypass : OverflowBypass;
        part inspectionRiser : InspectionRiser;
        part outfall : SafeOutfall;

        perform action primaryFunction : PerformShirleyDrainPrimaryFunction;
        exhibit state operatingState : ShirleyDrainOperatingState;

        connection runoffToCollector connect runoffEntry to surfaceCollector.runoffIn;
        connection collectorToSump connect surfaceCollector.collectorOut to sump.inlet;
        connection sumpToPipe connect sump.outlet to collectorPipe.upstreamEnd;
        connection geotextileToAggregate connect filterWrap.aggregateSide to aggregateEnvelope.filterSide;
        connection aggregateToPipe connect aggregateEnvelope.pipeSide to collectorPipe.lateralInflow;
        connection groundwaterToGeotextile connect groundwaterEntry to filterWrap.soilSide;
        connection pipeToOutletControl connect collectorPipe.downstreamEnd to outletControl.inlet;
        connection outletControlToFinalDischarge connect outletControl.outlet to finalDischarge;
        connection outletControlToOutfall connect outletControl.outlet to outfall.inflow;
        connection sumpToInspectionRiser connect sump.inspection to inspectionRiser.accessBase;
        connection inspectionRiserToMaintenanceAccess connect inspectionRiser.accessTop to maintenanceAccess;
        connection sumpVentToRiser connect sump.vent to inspectionRiser.ventBase;
        connection pipeVentToRiser connect collectorPipe.vent to inspectionRiser.ventBase;
        connection riserVentToAtmosphere connect inspectionRiser.ventTop to atmosphericVent;
        connection overflowFromSump connect sump.outlet to overflowBypass.inlet;
        connection overflowToOutlet connect overflowBypass.outlet to outletControl.bypassInlet;

        satisfy ShirleyDrainPrimaryFunctionRequirement;
        satisfy PassiveGravityDrainageRequirement;
        satisfy HydraulicCapacityRequirement;
        satisfy SoilAndSedimentControlRequirement;
        satisfy OutfallProtectionRequirement;
        satisfy MaintainabilityRequirement;
    }

    part shirleyDrainInstallation : ShirleyDrainSystem {
        :>> protectedCatchmentArea.value = 420.0;
        :>> requiredPeakInflow.value = 0.028;
        :>> totalDesignCapacity.value = 0.035;
    }
}
