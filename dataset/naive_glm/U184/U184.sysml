package CausticPencilModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // Value Types
    value type ForceValue :> Real {
        unit N;
    }
    value type DurationValue :> Real {
        unit s;
    }
    value type PercentageValue :> Real;
    value type DepthValue :> Real {
        unit mm;
    }

    // Items
    item def SilverNitrate;
    item def Tissue;
    item def CoagulatedTissue;

    // Parts
    part def PlasticHolder {
        port handlePort;
        port tipInterface;
        attribute isSingleUse : Boolean = true;
    }

    part def SilverNitrateTip {
        port internalInterface;
        port externalTipPort;
        item silverNitrate : SilverNitrate;
    }

    part def CausticPencil {
        attribute silverNitrateConcentration : PercentageValue = 95;
        port tipPort;
        
        part holder : PlasticHolder;
        part tip : SilverNitrateTip;
        
        connection tipAssembly connect holder.tipInterface to tip.internalInterface;
        
        exhibit state def PencilLifecycle {
            state Stored;
            state Idle;
            state Active;
            state Disposed;
            
            transition from Stored to Idle when readyForProcedure;
            transition from Idle to Active when appliedToTissue;
            transition from Active to Idle when contactReleased;
            transition from Idle to Disposed when procedureComplete;
        }
    }

    part def Clinician {
        port handPort;
        attribute appliedForce : ForceValue;
        attribute applicationDuration : DurationValue;
    }

    part def TargetTissue {
        port tissueSurface;
        item tissue : Tissue;
        item coagulatedTissue : CoagulatedTissue;
        attribute cauterizationDepth : DepthValue;
    }

    part def CausticPencilSystem {
        part clinician : Clinician;
        part pencil : CausticPencil;
        part target : TargetTissue;
        
        connection clinicianHold connect clinician.handPort to pencil.holder.handlePort;
        connection tissueContact connect pencil.tip.externalTipPort to target.tissueSurface;
    }

    // Requirements
    requirement def HemostasisRequirement {
        subject device : CausticPencil;
        objective {
            doc "The device shall stop minor bleeding or remove small amounts of unwanted tissue."
        }
    }
    
    requirement def ControlledApplicationRequirement {
        subject device : CausticPencil;
        attribute maxForce : ForceValue = 1.0 [N];
        attribute maxDuration : DurationValue = 10.0 [s];
        objective {
            doc "The device shall be applied with a specific gentle force and for a short duration."
        }
    }
    
    requirement def SingleUseRequirement {
        subject device : CausticPencil;
        objective {
            doc "The device shall be single-use and disposed of after the procedure."
        }
    }
    
    requirement def ChemicalCompositionRequirement {
        subject device : CausticPencil;
        attribute requiredConcentration : PercentageValue = 95;
        objective {
            doc "The tip shall be composed of 95% silver nitrate."
        }
    }
}
