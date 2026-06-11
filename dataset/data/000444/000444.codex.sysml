package DripChamberSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def VolumeFlowRate {
        unit : Unit;
        quantityKind : QuantityKind;
    }

    value def DropRate {
        unit : Unit;
        quantityKind : QuantityKind;
    }

    value def Pressure {
        unit : Unit;
        quantityKind : QuantityKind;
    }

    value def Volume {
        unit : Unit;
        quantityKind : QuantityKind;
    }

    value def Ratio {
        unit : Unit;
        quantityKind : QuantityKind;
    }

    attribute def milliliter : Unit;
    attribute def milliliterPerHour : Unit;
    attribute def dropsPerMinute : Unit;
    attribute def kilopascal : Unit;
    attribute def percent : Unit;

    item def InfusionFluid {
        attribute fluidName : String;
        attribute prescribedFlowRate : VolumeFlowRate;
        attribute viscosity : Real;
        attribute containsAir : Boolean;
    }

    item def Air {
        attribute bubbleVolume : Volume;
    }

    item def Droplet {
        attribute volume : Volume;
        attribute formedAtRate : DropRate;
    }

    item def PrimedFluidColumn {
        attribute liquidLevel : Ratio;
        attribute isBubbleFree : Boolean;
    }

    port def FluidInletPort {
        in item incomingFluid : InfusionFluid;
    }

    port def FluidOutletPort {
        out item outgoingFluid : InfusionFluid;
    }

    port def AirVentPort {
        out item separatedAir : Air;
    }

    port def VisualObservationPort {
        out attribute visibleDropRate : DropRate;
        out attribute visibleLiquidLevel : Ratio;
        out attribute bubbleDetected : Boolean;
    }

    port def FlowControlSignalPort {
        in attribute commandedFlowRate : VolumeFlowRate;
    }

    action def AdmitInfusionFluid {
        in item fluidIn : InfusionFluid;
        out item fluidOut : InfusionFluid;
    }

    action def FormMeasurableDrops {
        in item continuousFluid : InfusionFluid;
        out item droplets : Droplet;
        out attribute measuredDropRate : DropRate;
    }

    action def SeparateEntrainedAir {
        in item aeratedFluid : InfusionFluid;
        out item deaeratedFluid : InfusionFluid;
        out item removedAir : Air;
    }

    action def MaintainLiquidSeal {
        in attribute currentLevel : Ratio;
        out attribute levelWithinRange : Boolean;
    }

    action def DeliverPrimedFluid {
        in item chamberFluid : InfusionFluid;
        out item patientLineFluid : InfusionFluid;
    }

    action def IndicateObservableCondition {
        in attribute dropRate : DropRate;
        in attribute level : Ratio;
        in attribute bubblePresent : Boolean;
        out attribute observableDropRate : DropRate;
        out attribute observableLiquidLevel : Ratio;
        out attribute observableBubbleDetected : Boolean;
    }

    state def DripChamberOperatingState {
        entry action initializeChamber;
        state empty;
        state priming;
        state ready;
        state dripping;
        state airSeparation;
        state lowLevel;
        state overfilled;
        state stopped;

        transition first empty then priming
            accept primingStarted;

        transition empty_to_stopped first empty then stopped
            accept noFluidAvailable;

        transition priming_to_ready first priming then ready
            accept liquidLevelReached
            if liquidLevel >= 45[%] and liquidLevel <= 70[%];

        transition priming_to_overfilled first priming then overfilled
            accept liquidLevelReached
            if liquidLevel > 70[%];

        transition ready_to_dripping first ready then dripping
            accept flowCommanded
            if commandedFlowRate > 0[milliliterPerHour];

        transition dripping_to_airSeparation first dripping then airSeparation
            accept airBubbleDetected
            if bubbleDetected == true;

        transition airSeparation_to_dripping first airSeparation then dripping
            accept airRemoved
            if bubbleDetected == false;

        transition dripping_to_lowLevel first dripping then lowLevel
            accept liquidLevelChanged
            if liquidLevel < 35[%];

        transition lowLevel_to_dripping first lowLevel then dripping
            accept liquidLevelRestored
            if liquidLevel >= 45[%];

        transition dripping_to_overfilled first dripping then overfilled
            accept liquidLevelChanged
            if liquidLevel > 80[%];

        transition overfilled_to_ready first overfilled then ready
            accept levelCorrected
            if liquidLevel <= 70[%];

        transition dripping_to_stopped first dripping then stopped
            accept flowStopped;

        transition ready_to_stopped first ready then stopped
            accept flowStopped;
    }

    part def InletSpikeInterface {
        port inlet : FluidInletPort;
        attribute inletPressure : Pressure;
    }

    part def DropFormer {
        port fluidIn : FluidInletPort;
        port dropletOut : FluidOutletPort;
        attribute nominalDropFactor : DropRate;
        attribute dropletVolume : Volume;
        perform action formDrops : FormMeasurableDrops;
    }

    part def TransparentChamberBody {
        port chamberIn : FluidInletPort;
        port chamberOut : FluidOutletPort;
        port visual : VisualObservationPort;
        attribute chamberInternalVolume : Volume;
        attribute liquidLevel : Ratio;
        attribute minimumOperatingLevel : Ratio;
        attribute maximumOperatingLevel : Ratio;
    }

    part def AirTrapVolume {
        port aeratedFluidIn : FluidInletPort;
        port deaeratedFluidOut : FluidOutletPort;
        port vent : AirVentPort;
        attribute retainedAirVolume : Volume;
        perform action separateAir : SeparateEntrainedAir;
    }

    part def OutletFilterAndConnector {
        port inletFromChamber : FluidInletPort;
        port outletToPatientLine : FluidOutletPort;
        attribute filterPoreSizeMicrometer : Real;
        attribute outletPressure : Pressure;
    }

    part def FlowClampInterface {
        port command : FlowControlSignalPort;
        port controlledInlet : FluidInletPort;
        port controlledOutlet : FluidOutletPort;
        attribute commandedFlowRate : VolumeFlowRate;
        attribute actualFlowRate : VolumeFlowRate;
    }

    part def DripChamber {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port airVent : AirVentPort;
        port observation : VisualObservationPort;
        port flowCommand : FlowControlSignalPort;

        part inletInterface : InletSpikeInterface;
        part dropFormer : DropFormer;
        part chamberBody : TransparentChamberBody;
        part airTrap : AirTrapVolume;
        part outletConnector : OutletFilterAndConnector;
        part flowClamp : FlowClampInterface;

        attribute operatingLiquidLevel : Ratio = 55[%];
        attribute allowableMinimumLevel : Ratio = 35[%];
        attribute allowableMaximumLevel : Ratio = 80[%];
        attribute targetDropRate : DropRate;
        attribute actualDropRate : DropRate;
        attribute actualFlowRate : VolumeFlowRate;
        attribute bubbleDetected : Boolean = false;
        attribute primed : Boolean = false;

        connect inlet to inletInterface.inlet;
        connect inletInterface.inlet to dropFormer.fluidIn;
        connect dropFormer.dropletOut to chamberBody.chamberIn;
        connect chamberBody.chamberOut to airTrap.aeratedFluidIn;
        connect airTrap.deaeratedFluidOut to outletConnector.inletFromChamber;
        connect outletConnector.outletToPatientLine to flowClamp.controlledInlet;
        connect flowClamp.controlledOutlet to outlet;
        connect airTrap.vent to airVent;
        connect chamberBody.visual to observation;
        connect flowCommand to flowClamp.command;

        perform action admitFluid : AdmitInfusionFluid;
        perform action maintainSeal : MaintainLiquidSeal;
        perform action deliverFluid : DeliverPrimedFluid;
        perform action indicateCondition : IndicateObservableCondition;
        exhibit state operatingState : DripChamberOperatingState;
    }

    part def InfusionSetSegment {
        port bagSide : FluidInletPort;
        port patientSide : FluidOutletPort;
        port clinicianView : VisualObservationPort;
        port flowSetting : FlowControlSignalPort;

        part chamber : DripChamber;

        attribute prescribedFlowRate : VolumeFlowRate = 125[milliliterPerHour];
        attribute prescribedDropRate : DropRate = 42[dropsPerMinute];

        connect bagSide to chamber.inlet;
        connect chamber.outlet to patientSide;
        connect chamber.observation to clinicianView;
        connect flowSetting to chamber.flowCommand;
    }

    requirement def DripChamberPrimaryFunctionRequirement {
        subject chamber : DripChamber;
        doc /* The drip chamber shall receive infusion fluid from an upstream container, form visible drops, retain a controlled liquid column, separate entrained air, and deliver primed fluid to the downstream patient line. */
        require constraint {
            chamber.primed == true and
            chamber.operatingLiquidLevel >= chamber.allowableMinimumLevel and
            chamber.operatingLiquidLevel <= chamber.allowableMaximumLevel
        }
    }

    requirement def VisibleDropRequirement {
        subject chamber : DripChamber;
        doc /* The drip chamber shall make drop formation visually observable so that a clinician can estimate infusion flow at a high level. */
        require constraint {
            chamber.actualDropRate >= 0[dropsPerMinute]
        }
    }

    requirement def AirSeparationRequirement {
        subject chamber : DripChamber;
        doc /* The drip chamber shall reduce downstream air transfer by allowing entrained air to separate from the liquid path before fluid exits to the patient line. */
        require constraint {
            chamber.bubbleDetected == false
        }
    }

    requirement def LiquidSealRequirement {
        subject chamber : DripChamber;
        doc /* The drip chamber shall maintain enough liquid volume to preserve a continuous primed fluid path and prevent direct air passage into the outlet. */
        require constraint {
            chamber.operatingLiquidLevel >= 35[%] and
            chamber.operatingLiquidLevel <= 80[%]
        }
    }

    requirement def FlowContinuityRequirement {
        subject set : InfusionSetSegment;
        doc /* The infusion set segment shall provide a continuous fluid path from the bag-side inlet through the drip chamber to the patient-side outlet when commanded flow is greater than zero. */
        require constraint {
            set.prescribedFlowRate > 0[milliliterPerHour]
        }
    }

    satisfy DripChamberPrimaryFunctionRequirement by InfusionSetSegment::chamber;
    satisfy VisibleDropRequirement by InfusionSetSegment::chamber::dropFormer;
    satisfy AirSeparationRequirement by InfusionSetSegment::chamber::airTrap;
    satisfy LiquidSealRequirement by InfusionSetSegment::chamber::chamberBody;
    satisfy FlowContinuityRequirement by InfusionSetSegment;

    view def DripChamberHighLevelFunctionView {
        objective {
            doc /* Show the drip chamber as a passive infusion-set component whose primary high-level function is to convert incoming continuous infusion fluid into visible drops, maintain a primed liquid column, separate air, and pass fluid onward to the patient line. */
        }

        expose InfusionSetSegment;
        expose DripChamber;
        expose DripChamberPrimaryFunctionRequirement;
        expose VisibleDropRequirement;
        expose AirSeparationRequirement;
        expose LiquidSealRequirement;
    }

}