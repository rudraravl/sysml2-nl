package SyringeFilterSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MicroliterVolume :> VolumeValue {
        :>> unit = SI::microlitre;
    }

    attribute def MilliliterVolume :> VolumeValue {
        :>> unit = SI::millilitre;
    }

    attribute def MicrometreLength :> LengthValue {
        :>> unit = SI::micrometre;
    }

    attribute def KilopascalPressure :> PressureValue {
        :>> unit = SI::kilopascal;
    }

    attribute def MilliliterPerMinuteFlowRate :> VolumeFlowRateValue {
        :>> unit = SI::millilitre / SI::minute;
    }

    attribute def PercentEfficiency :> Real {
        range = "0..100";
    }

    item def LiquidSample {
        attribute volume : MilliliterVolume;
        attribute viscosity : DynamicViscosityValue;
        attribute particleLoad : Real;
        attribute biocompatible : Boolean;
    }

    item def SuspendedParticle {
        attribute diameter : MicrometreLength;
        attribute material : String;
        attribute deformable : Boolean;
    }

    item def FilteredLiquid {
        attribute volume : MilliliterVolume;
        attribute maximumParticleDiameter : MicrometreLength;
        attribute clarityIndex : PercentEfficiency;
    }

    item def RetainedContaminant {
        attribute capturedVolume : MicroliterVolume;
        attribute capturedParticleCount : Integer;
    }

    port def SampleInletPort {
        in item sample : LiquidSample;
        attribute appliedPressure : KilopascalPressure;
    }

    port def FiltrateOutletPort {
        out item filtrate : FilteredLiquid;
        attribute outletPressure : KilopascalPressure;
    }

    port def RetentatePort {
        out item retainedMatter : RetainedContaminant;
    }

    port def MechanicalInterfacePort {
        attribute luerCompatible : Boolean;
        attribute sealed : Boolean;
    }

    port def PressureReliefPort {
        out item bypassedSample : LiquidSample;
        attribute reliefPressure : KilopascalPressure;
    }

    part def LuerLockInlet {
        port syringeInterface : MechanicalInterfacePort;
        port sampleReceiver : SampleInletPort;

        attribute innerDiameter : MicrometreLength;
        attribute maxOperatingPressure : KilopascalPressure;
        attribute connectionSealed : Boolean;
    }

    part def FlowDistributor {
        port distributedInlet : SampleInletPort;
        port membraneFace : SampleInletPort;

        attribute activeDistributionArea : AreaValue;
        attribute channelDepth : MicrometreLength;
        attribute deadVolume : MicroliterVolume;
    }

    part def FilterMembrane {
        port feedSide : SampleInletPort;
        port filtrateSide : FiltrateOutletPort;
        port retentionSide : RetentatePort;

        attribute poreSize : MicrometreLength;
        attribute membraneDiameter : MicrometreLength;
        attribute effectiveFiltrationArea : AreaValue;
        attribute particleRetentionEfficiency : PercentEfficiency;
        attribute wetted : Boolean;
        attribute clogged : Boolean;
        attribute capturedParticleCount : Integer;
    }

    part def SupportMesh {
        port membraneContact : MechanicalInterfacePort;
        port downstreamFlow : FiltrateOutletPort;

        attribute openAreaRatio : PercentEfficiency;
        attribute compressionSet : PercentEfficiency;
    }

    part def FilterHousing {
        port upstreamSeal : MechanicalInterfacePort;
        port downstreamSeal : MechanicalInterfacePort;
        port relief : PressureReliefPort;

        attribute material : String;
        attribute transparent : Boolean;
        attribute burstPressure : KilopascalPressure;
        attribute internalHoldUpVolume : MicroliterVolume;
    }

    part def OutletNozzle {
        port filtrateReceiver : FiltrateOutletPort;
        port externalOutlet : FiltrateOutletPort;

        attribute tipOuterDiameter : MicrometreLength;
        attribute dripFreeGeometry : Boolean;
    }

    part def SyringeFilter {
        part inlet : LuerLockInlet;
        part distributor : FlowDistributor;
        part membrane : FilterMembrane;
        part support : SupportMesh;
        part housing : FilterHousing;
        part outlet : OutletNozzle;

        port syringeSide : SampleInletPort;
        port filteredSide : FiltrateOutletPort;
        port retainedContaminants : RetentatePort;
        port syringeMechanicalCoupling : MechanicalInterfacePort;
        port pressureRelief : PressureReliefPort;

        attribute nominalPoreSize : MicrometreLength = 0.22 [SI::micrometre];
        attribute ratedSampleVolume : MilliliterVolume = 100 [SI::millilitre];
        attribute maximumInletPressure : KilopascalPressure = 520 [SI::kilopascal];
        attribute nominalFlowRate : MilliliterPerMinuteFlowRate = 25 [SI::millilitre / SI::minute];
        attribute sterileConfiguration : Boolean = true;

        connect syringeSide to inlet.sampleReceiver;
        connect syringeMechanicalCoupling to inlet.syringeInterface;
        connect inlet.sampleReceiver to distributor.distributedInlet;
        connect distributor.membraneFace to membrane.feedSide;
        connect membrane.filtrateSide to support.downstreamFlow;
        connect support.downstreamFlow to outlet.filtrateReceiver;
        connect outlet.externalOutlet to filteredSide;
        connect membrane.retentionSide to retainedContaminants;
        connect housing.relief to pressureRelief;
        connect housing.upstreamSeal to inlet.syringeInterface;
        connect housing.downstreamSeal to support.membraneContact;
    }

    action def ReceiveSample {
        in item incomingSample : LiquidSample;
        out item pressurizedSample : LiquidSample;
    }

    action def DistributeFlow {
        in item pressurizedSample : LiquidSample;
        out item uniformMembraneFeed : LiquidSample;
    }

    action def SeparateParticles {
        in item uniformMembraneFeed : LiquidSample;
        out item clarifiedLiquid : FilteredLiquid;
        out item capturedMatter : RetainedContaminant;
    }

    action def DeliverFiltrate {
        in item clarifiedLiquid : FilteredLiquid;
        out item dispensedFiltrate : FilteredLiquid;
    }

    action def ProtectAgainstOverpressure {
        in item overpressurizedSample : LiquidSample;
        out item bypassedSample : LiquidSample;
    }

    action def HighLevelFiltrationFunction {
        in item rawSample : LiquidSample;
        out item cleanSample : FilteredLiquid;
        out item removedContaminants : RetainedContaminant;

        action receive : ReceiveSample {
            in item incomingSample = rawSample;
        }

        action distribute : DistributeFlow {
            in item pressurizedSample = receive.pressurizedSample;
        }

        action separate : SeparateParticles {
            in item uniformMembraneFeed = distribute.uniformMembraneFeed;
        }

        action deliver : DeliverFiltrate {
            in item clarifiedLiquid = separate.clarifiedLiquid;
        }

        bind cleanSample = deliver.dispensedFiltrate;
        bind removedContaminants = separate.capturedMatter;
    }

    state def SyringeFilterLifecycle {
        state Unused;
        state ConnectedToSyringe;
        state Primed;
        state Filtering;
        state Clogged;
        state Completed;
        state OverpressureRelief;
        state Disposed;

        transition initial then Unused;
        transition Unused_to_Connected first Unused then ConnectedToSyringe;
        transition Connected_to_Primed first ConnectedToSyringe then Primed;
        transition Primed_to_Filtering first Primed then Filtering;
        transition Filtering_to_Completed first Filtering then Completed;
        transition Filtering_to_Clogged first Filtering then Clogged;
        transition Filtering_to_Relief first Filtering then OverpressureRelief;
        transition Relief_to_Disposed first OverpressureRelief then Disposed;
        transition Clogged_to_Disposed first Clogged then Disposed;
        transition Completed_to_Disposed first Completed then Disposed;
    }

    requirement def PrimaryFiltrationRequirement {
        subject filter : SyringeFilter;

        doc
        /*
         The syringe filter shall accept a liquid sample from a syringe,
         force the sample through a porous membrane, retain particles larger
         than the rated pore size, and deliver clarified filtrate through the outlet.
        */

        require constraint {
            filter.nominalPoreSize <= 0.22 [SI::micrometre]
        }

        require constraint {
            filter.maximumInletPressure >= 500 [SI::kilopascal]
        }

        require constraint {
            filter.membrane.particleRetentionEfficiency >= 99.0
        }
    }

    requirement def PressureSafetyRequirement {
        subject filter : SyringeFilter;

        require constraint {
            filter.housing.burstPressure > filter.maximumInletPressure
        }

        require constraint {
            filter.pressureRelief.reliefPressure <= filter.housing.burstPressure
        }
    }

    requirement def LowHoldUpVolumeRequirement {
        subject filter : SyringeFilter;

        require constraint {
            filter.housing.internalHoldUpVolume <= 100 [SI::microlitre]
        }
    }

    part syringeFilterSystem : SyringeFilter {
        attribute nominalPoreSize = 0.22 [SI::micrometre];
        attribute ratedSampleVolume = 100 [SI::millilitre];
        attribute maximumInletPressure = 520 [SI::kilopascal];
        attribute nominalFlowRate = 25 [SI::millilitre / SI::minute];

        part membrane {
            attribute poreSize = 0.22 [SI::micrometre];
            attribute particleRetentionEfficiency = 99.9;
            attribute wetted = false;
            attribute clogged = false;
            attribute capturedParticleCount = 0;
        }

        part housing {
            attribute material = "medical-grade polypropylene";
            attribute transparent = true;
            attribute burstPressure = 700 [SI::kilopascal];
            attribute internalHoldUpVolume = 80 [SI::microlitre];
        }

        part inlet {
            attribute maxOperatingPressure = 520 [SI::kilopascal];
            attribute connectionSealed = true;
        }

        part outlet {
            attribute dripFreeGeometry = true;
        }
    }
}