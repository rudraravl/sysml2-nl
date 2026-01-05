package ElectroscopeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    enum def ChargePolarity {
        positive;
        negative;
        neutral;
    }
    
    enum def LeafState {
        collapsed;
        diverged;
    }
    
    item def ChargeCarrier {
        attribute magnitude : ISQ::ElectricChargeValue;
        attribute polarity : ChargePolarity;
    }
    
    port def ChargePort {
        in item charge : ChargeCarrier;
    }
    
    port def VisualPort {
        out attribute leafAngle : ISQ::PlaneAngleValue;
    }
    
    part def MetalCap {
        attribute conductivity : Real;
        port chargeInput : ChargePort;
    }
    
    part def ConductingRod {
        attribute length : ISQ::LengthValue;
        attribute resistance : Real;
        port topEnd;
        port bottomEnd;
    }
    
    part def MetalLeaf {
        attribute mass : ISQ::MassValue;
        attribute chargeLevel : ISQ::ElectricChargeValue;
        attribute divergenceAngle : ISQ::PlaneAngleValue;
        attribute leafState : LeafState;
    }
    
    part def InsulatingSupport {
        attribute material : String;
        attribute dielectricStrength : Real;
    }
    
    part def ProtectiveEnclosure {
        attribute transparency : Real;
        attribute shielding : Boolean;
    }
    
    action def AcceptCharge {
        in chargeSource : ChargeCarrier;
        out acceptedCharge : ISQ::ElectricChargeValue;
    }
    
    action def ConductCharge {
        in inputCharge : ISQ::ElectricChargeValue;
        out distributedCharge : ISQ::ElectricChargeValue;
    }
    
    action def CalculateRepulsion {
        in leaf1Charge : ISQ::ElectricChargeValue;
        in leaf2Charge : ISQ::ElectricChargeValue;
        out repulsionForce : ISQ::ForceValue;
    }
    
    action def ComputeDivergence {
        in repulsionForce : ISQ::ForceValue;
        in leafMass : ISQ::MassValue;
        out divergenceAngle : ISQ::PlaneAngleValue;
    }
    
    action def IndicateCharge {
        in divergenceAngle : ISQ::PlaneAngleValue;
        out indication : LeafState;
    }
    
    state def ElectroscopeStateMachine {
        entry action initialize;
        
        state Uncharged {
            entry action setUnchargedState;
        }
        
        transition chargeReceived
            first Uncharged
            accept chargeApplied : ChargeCarrier
            then Charging;
        
        state Charging {
            do action distributeCharge;
        }
        
        transition chargeDistributed
            first Charging
            then Charged;
        
        state Charged {
            state LowCharge;
            state HighCharge;
            
            transition increaseDivergence
                first LowCharge
                then HighCharge;
        }
        
        transition discharge
            first Charged
            accept groundedEvent
            then Uncharged;
    }
    
    action def OperateElectroscope {
        first start;
        
        then action acceptCharge : AcceptCharge {
            in chargeSource;
            out acceptedCharge;
        }
        
        then action conductCharge : ConductCharge {
            in inputCharge = acceptCharge.acceptedCharge;
            out distributedCharge;
        }
        
        then action calculateRepulsion : CalculateRepulsion {
            in leaf1Charge = conductCharge.distributedCharge;
            in leaf2Charge = conductCharge.distributedCharge;
            out repulsionForce;
        }
        
        then action computeDivergence : ComputeDivergence {
            in repulsionForce = calculateRepulsion.repulsionForce;
            in leafMass;
            out divergenceAngle;
        }
        
        then action indicateCharge : IndicateCharge {
            in divergenceAngle = computeDivergence.divergenceAngle;
            out indication;
        }
        
        then done;
    }
    
    part def Electroscope {
        doc /* An electroscope detects the presence and relative magnitude of electric charge 
               by transferring charge to thin metal leaves that diverge due to electrostatic repulsion. */
        
        attribute systemCharge : ISQ::ElectricChargeValue;
        attribute currentLeafState : LeafState;
        attribute currentDivergenceAngle : ISQ::PlaneAngleValue;
        
        port chargeInterface : ChargePort;
        port visualIndicator : VisualPort;
        
        part cap : MetalCap {
            attribute :>> conductivity = 5.96e7;
        }
        
        part rod : ConductingRod {
            attribute :>> length = 20.0 [SI::cm];
            attribute :>> resistance = 0.001;
        }
        
        part leaf1 : MetalLeaf {
            attribute :>> mass = 0.05 [SI::g];
            attribute :>> chargeLevel = 0.0 [SI::C];
            attribute :>> divergenceAngle = 0.0 [SI::'°'];
            attribute :>> leafState = LeafState::collapsed;
        }
        
        part leaf2 : MetalLeaf {
            attribute :>> mass = 0.05 [SI::g];
            attribute :>> chargeLevel = 0.0 [SI::C];
            attribute :>> divergenceAngle = 0.0 [SI::'°'];
            attribute :>> leafState = LeafState::collapsed;
        }
        
        part support : InsulatingSupport {
            attribute :>> material = "amber";
            attribute :>> dielectricStrength = 90.0;
        }
        
        part enclosure : ProtectiveEnclosure {
            attribute :>> transparency = 0.92;
            attribute :>> shielding = false;
        }
        
        connection capToRod connect cap.chargeInput to rod.topEnd;
        connection rodToLeaf1 connect rod.bottomEnd to leaf1;
        connection rodToLeaf2 connect rod.bottomEnd to leaf2;
        
        bind chargeInterface = cap.chargeInput;
        bind visualIndicator.leafAngle = currentDivergenceAngle;
        
        perform action operation : OperateElectroscope {
            in chargeSource;
            in leafMass = 0.05 [SI::g];
            out indication;
        }
        
        exhibit state behavior : ElectroscopeStateMachine;
    }
    
    requirement def <'REQ-001'> ChargeDetectionRequirement {
        doc /* The electroscope shall detect the presence of electric charge when a charged object 
               contacts or approaches the metal cap. */
        
        subject device : Electroscope;
        
        require constraint {
            device.chargeInterface.charge.magnitude > 0.0 [SI::C] implies
            device.systemCharge > 0.0 [SI::C]
        }
    }
    
    requirement def <'REQ-002'> LeafDivergenceRequirement {
        doc /* The metal leaves shall diverge proportionally to the magnitude of charge present, 
               providing a visual indication of charge level. */
        
        subject device : Electroscope;
        
        require constraint {
            device.systemCharge > 0.0 [SI::C] implies
            device.currentLeafState == LeafState::diverged and
            device.currentDivergenceAngle > 0.0 [SI::'°']
        }
    }
    
    requirement def <'REQ-003'> ChargeDistributionRequirement {
        doc /* Charge shall be uniformly distributed from the cap through the rod to both leaves 
               to ensure symmetric divergence. */
        
        subject device : Electroscope;
        
        require constraint {
            device.leaf1.chargeLevel == device.leaf2.chargeLevel
        }
    }
    
    requirement def <'REQ-004'> ElectricalIsolationRequirement {
        doc /* The insulating support shall prevent charge leakage to maintain measurement accuracy 
               and allow sustained observation. */
        
        subject device : Electroscope;
        
        require constraint {
            device.support.dielectricStrength > 50.0
        }
    }
    
    requirement electroscopeRequirements {
        doc /* Complete requirements specification for electroscope charge detection system. */
        
        require req1 : ChargeDetectionRequirement;
        require req2 : LeafDivergenceRequirement;
        require req3 : ChargeDistributionRequirement;
        require req4 : ElectricalIsolationRequirement;
    }
    
    part chargeDetectionInstrument : Electroscope {
        attribute :>> systemCharge = 0.0 [SI::C];
        attribute :>> currentLeafState = LeafState::collapsed;
        attribute :>> currentDivergenceAngle = 0.0 [SI::'°'];
        
        satisfy electroscopeRequirements;
    }
}
