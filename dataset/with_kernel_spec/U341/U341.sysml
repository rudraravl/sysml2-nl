package OstomyApplianceSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    item def Effluent;
    item def Flatus;

    port def StomaOutputPort {
        out item waste : Effluent;
        out item gas : Flatus;
    }
    port def BarrierInputPort {
        in item waste : Effluent;
        in item gas : Flatus;
    }
    port def BarrierOutputPort {
        out item waste : Effluent;
        out item gas : Flatus;
    }
    port def PouchInputPort {
        in item waste : Effluent;
        in item gas : Flatus;
    }
    port def FilterVentPort {
        in item gas : Flatus;
    }
    port def DrainPort {
        out item waste : Effluent;
    }

    part def SkinBarrier {
        attribute adhesionLevel : Real;
        attribute wearTime : TimeValue;
        attribute isWaterResistant : Boolean = true;
        port stomaPort : BarrierInputPort;
        port pouchPort : BarrierOutputPort;
    }

    part def OdorFilter {
        attribute carbonCapacity : Real;
        port ventPort : FilterVentPort;
    }

    part def CollectionPouch {
        attribute fillLevel : VolumeValue;
        attribute maxVolume : VolumeValue;
        attribute isOpaque : Boolean = true;
        port barrierPort : PouchInputPort;
        port drainPort : DrainPort;
        part odorFilter : OdorFilter;
    }

    part def OstomyAppliance {
        part skinBarrier : SkinBarrier;
        part collectionPouch : CollectionPouch;
    }

    state def ApplianceLifecycle;

    attribute def PouchEmptied;
    attribute def ApplianceReplaced;

    requirement def ContainmentRequirement {
        doc /* The system must safely contain all bodily waste. */
    }
    requirement def SkinProtectionRequirement {
        doc /* The skin barrier must protect the surrounding skin from waste contact. */
    }
    requirement def OdorControlRequirement {
        doc /* The system must neutralize odor from expelled gas. */
    }
    requirement def ComfortDiscretionRequirement {
        doc /* The appliance shall provide comfort and discretion for the user. */
    }

    part context {
        part stoma {
            port outputPort : StomaOutputPort;
        }

        part appliance : OstomyAppliance {
            part skinBarrier : SkinBarrier;
            part collectionPouch : CollectionPouch {
                flow of gas : Flatus
                    from barrierPort.gas to odorFilter.ventPort.gas;
            }

            flow of waste : Effluent
                from skinBarrier.pouchPort.waste to collectionPouch.barrierPort.waste;
            flow of gas : Flatus
                from skinBarrier.pouchPort.gas to collectionPouch.barrierPort.gas;
        }

        flow of waste : Effluent
            from stoma.outputPort.waste to appliance.skinBarrier.stomaPort.waste;
        flow of gas : Flatus
            from stoma.outputPort.gas to appliance.skinBarrier.stomaPort.gas;

        exhibit state lifecycle : ApplianceLifecycle {
            entry; then Collecting;
            state Collecting;
            accept when appliance.collectionPouch.fillLevel >= appliance.collectionPouch.maxVolume
                then Full;
            accept when appliance.skinBarrier.adhesionLevel <= 0.1
                then Degrading;
            state Full;
            accept PouchEmptied
                then Collecting;
            state Degrading;
            accept ApplianceReplaced
                then Collecting;
        }

        requirement containment : ContainmentRequirement {
            subject appliance = appliance;
        }
        requirement skinProtection : SkinProtectionRequirement {
            subject barrier = appliance.skinBarrier;
        }
        requirement odorControl : OdorControlRequirement {
            subject pouch = appliance.collectionPouch;
        }
        requirement comfort : ComfortDiscretionRequirement {
            subject appliance = appliance;
        }
    }
}
