package BonannoSuprapubicCatheterSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type VolumeMilliLiter > Real {
        unit 'mL';
    }

    value type VolumeLiter > Real {
        unit 'L';
    }

    value type PressureMillimeterMercury > Real {
        unit 'mmHg';
    }

    value type FlowRateMilliLiterPerMinute > Real {
        unit 'mL/min';
    }

    value type LengthMillimeter > Real {
        unit 'mm';
    }

    value type DiameterFrench > Real {
        unit 'Fr';
    }

    value type MassGram > Real {
        unit 'g';
    }

    // ===== Item Definitions =====

    item def SalineSolution {
        attribute concentration : MassGram;
        attribute volume : VolumeMilliLiter;
    }

    item def Urine {
        attribute volume : VolumeMilliLiter;
        attribute specificGravity : Real;
    }

    item def BloodClot {
        attribute size : LengthMillimeter;
    }

    item def Sediment {
        attribute density : Real;
    }

    // ===== Port Definitions =====

    port def BladderInterfacePort {
        in item urine : Urine;
        out item saline : SalineSolution;
    }

    port def DrainageOutputPort {
        out item urine : Urine;
    }

    port def IrrigationInputPort {
        in item saline : SalineSolution;
    }

    port def BalloonFillPort {
        in item saline : SalineSolution;
    }

    port def BagInputPort {
        in item urine : Urine;
    }

    port def BagOutputPort {
        out item urine : Urine;
    }

    // ===== Requirements =====

    requirement def AnchorRetentionRequirement {
        doc /* The balloon must retain the catheter in the bladder when inflated to the specified volume. */
        attribute targetVolume : VolumeMilliLiter = 10 [mL];
        subject balloon : Balloon;
        require {
            balloon.inflatedVolume == targetVolume;
        }
    }

    requirement def ContinuousDrainageRequirement {
        doc /* The drainage lumen must support continuous urine flow from bladder to collection bag. */
        attribute minFlowRate : FlowRateMilliLiterPerMinute = 5 [mL/min];
        subject drainageLumen : DrainageLumen;
        require {
            drainageLumen.flowRate >= minFlowRate;
        }
    }

    requirement def AntiRefluxRequirement {
        doc /* The collection bag must prevent backflow of urine toward the bladder. */
        subject valve : AntiRefluxValve;
        require {
            valve.allowsBackflow == false;
        }
    }

    requirement def IrrigationClearanceRequirement {
        doc /* The irrigation lumen must allow saline introduction to clear blockages in the drainage lumen. */
        subject irrigationLumen : IrrigationLumen;
        require {
            irrigationLumen.clearsBlockage == true;
        }
    }

    requirement def CollectionBagCapacityRequirement {
        doc /* The collection bag must have a capacity of at least 2 liters. */
        attribute minCapacity : VolumeLiter = 2 [L];
        subject bag : UrineCollectionBag;
        require {
            bag.capacity >= minCapacity;
        }
    }

    // ===== Component Definitions =====

    part def Balloon {
        attribute maxVolume : VolumeMilliLiter = 15 [mL];
        attribute nominalVolume : VolumeMilliLiter = 10 [mL];
        attribute inflatedVolume : VolumeMilliLiter;
        attribute inflated : Boolean = false;
        port fillPort : BalloonFillPort;
        exhibit state inflationBehavior {
            entry;
            then Deflated;
            state Deflated {
                entry { inflated = false; inflatedVolume = 0 [mL]; }
            }
            state Inflated {
                entry { inflated = true; inflatedVolume = nominalVolume; }
            }
            transition from Deflated to Inflated
                when fillPort.saline.volume > 0 [mL]
                accept SalineSolution;
            transition from Inflated to Deflated
                when inflatedVolume == 0 [mL];
        }
        satisfy AnchorRetentionRequirement;
    }

    part def Eyelet {
        attribute diameter : LengthMillimeter = 2 [mm];
        attribute open : Boolean = true;
    }

    part def CatheterTip {
        part eyelets : Eyelet[4];
        port bladderInterface : BladderInterfacePort;
        attribute tipDiameter : DiameterFrench = 16 [Fr];
    }

    part def DrainageLumen {
        attribute innerDiameter : LengthMillimeter = 4 [mm];
        attribute length : LengthMillimeter = 300 [mm];
        attribute flowRate : FlowRateMilliLiterPerMinute;
        attribute blocked : Boolean = false;
        port bladderEnd : BladderInterfacePort;
        port outputEnd : DrainageOutputPort;
        exhibit state drainageFlowBehavior {
            entry;
            then Open;
            state Open {
                entry { blocked = false; flowRate = 10 [mL/min]; }
            }
            state Blocked {
                entry { blocked = true; flowRate = 0 [mL/min]; }
            }
            transition from Open to Blocked
                when flowRate == 0 [mL/min];
            transition from Blocked to Open
                when flowRate > 0 [mL/min];
        }
        satisfy ContinuousDrainageRequirement;
    }

    part def IrrigationLumen {
        attribute innerDiameter : LengthMillimeter = 1.5 [mm];
        attribute length : LengthMillimeter = 300 [mm];
        attribute clearsBlockage : Boolean = false;
        port inputEnd : IrrigationInputPort;
        port bladderEnd : BladderInterfacePort;
        exhibit state irrigationBehavior {
            entry;
            then Idle;
            state Idle {
                entry { clearsBlockage = false; }
            }
            state Flushing {
                entry { clearsBlockage = true; }
            }
            transition from Idle to Flushing
                when inputEnd.saline.volume > 0 [mL]
                accept SalineSolution;
            transition from Flushing to Idle
                when clearsBlockage == true;
        }
        satisfy IrrigationClearanceRequirement;
    }

    part def CatheterBody {
        attribute outerDiameter : DiameterFrench = 16 [Fr];
        attribute totalLength : LengthMillimeter = 300 [mm];
        attribute material : String = "MedicalGradeSilicone";
        part drainageLumen : DrainageLumen;
        part irrigationLumen : IrrigationLumen;
        part tip : CatheterTip;
        part balloon : Balloon;
        connection drainagePath connect tip.bladderInterface to drainageLumen.bladderEnd;
        connection irrigationPath connect irrigationLumen.bladderEnd to tip.bladderInterface;
        connection balloonFillPath connect balloon.fillPort to balloon;
    }

    part def AntiRefluxValve {
        attribute allowsBackflow : Boolean = false;
        attribute sealPressure : PressureMillimeterMercury = 5 [mmHg];
        port inputPort : BagInputPort;
        port outputPort : BagOutputPort;
        exhibit state valveBehavior {
            entry;
            then Sealed;
            state Sealed {
                entry { allowsBackflow = false; }
            }
            state Open {
                entry { allowsBackflow = false; }
            }
            transition from Sealed to Open
                when inputPort.urine.volume > 0 [mL]
                accept Urine;
            transition from Open to Sealed
                when inputPort.urine.volume == 0 [mL];
        }
        satisfy AntiRefluxRequirement;
    }

    part def UrineCollectionBag {
        attribute capacity : VolumeLiter = 2 [L];
        attribute currentVolume : VolumeLiter = 0 [L];
        attribute material : String = "MedicalGradePVC";
        port inputPort : BagInputPort;
        port drainPort : BagOutputPort;
        part antiRefluxValve : AntiRefluxValve;
        exhibit state bagFillBehavior {
            entry;
            then Empty;
            state Empty {
                entry { currentVolume = 0 [L]; }
            }
            state PartiallyFilled {
                entry { currentVolume = currentVolume + inputPort.urine.volume; }
            }
            state Full {
                entry { currentVolume = capacity; }
            }
            transition from Empty to PartiallyFilled
                when inputPort.urine.volume > 0 [mL]
                accept Urine;
            transition from PartiallyFilled to Full
                when currentVolume >= capacity;
            transition from PartiallyFilled to Empty
                when drainPort.urine.volume > 0 [mL];
            transition from Full to PartiallyFilled
                when drainPort.urine.volume > 0 [mL];
        }
        satisfy CollectionBagCapacityRequirement;
    }

    // ===== Top-Level System =====

    part def BonannoSuprapubicCatheterSystem {
        part catheter : CatheterBody;
        part collectionBag : UrineCollectionBag;
        connection drainageConnection connect catheter.drainageLumen.outputEnd to collectionBag.inputPort;
        exhibit state systemLifecycle {
            entry;
            then NotInserted;
            state NotInserted {
                entry { /* Catheter not yet placed */ }
            }
            state Inserted {
                entry { /* Catheter inserted through abdominal wall */ }
            }
            state Positioned {
                entry { /* Catheter tip positioned in bladder */ }
            }
            state Secured {
                entry { /* Balloon inflated, catheter anchored */ }
            }
            state NormalDrainage {
                entry { /* Continuous urine drainage active */ }
            }
            state FlowBlocked {
                entry { /* Drainage lumen blocked */ }
            }
            state Irrigating {
                entry { /* Saline introduced to clear blockage */ }
            }
            state BalloonDeflated {
                entry { /* Balloon deflated for removal */ }
            }
            state Removed {
                entry { /* Catheter withdrawn */ }
            }
            transition from NotInserted to Inserted
                when catheter.tip.bladderInterface.urine.volume >= 0 [mL];
            transition from Inserted to Positioned
                when catheter.tip.bladderInterface.urine.volume >= 0 [mL];
            transition from Positioned to Secured
                when catheter.balloon.inflated == true;
            transition from Secured to NormalDrainage
                when catheter.drainageLumen.flowRate > 0 [mL/min];
            transition from NormalDrainage to FlowBlocked
                when catheter.drainageLumen.blocked == true;
            transition from FlowBlocked to Irrigating
                when catheter.irrigationLumen.clearsBlockage == true;
            transition from Irrigating to NormalDrainage
                when catheter.drainageLumen.flowRate > 0 [mL/min];
            transition from NormalDrainage to BalloonDeflated
                when catheter.balloon.inflated == false;
            transition from BalloonDeflated to Removed
                when catheter.balloon.inflatedVolume == 0 [mL];
        }
    }

}
