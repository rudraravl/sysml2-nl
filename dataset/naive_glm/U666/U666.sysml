package ElectroscopeModel {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    
    value def Charge :> Real {
        doc /* Electric charge in coulombs */
        unit C;
    }
    
    value def Voltage :> Real {
        doc /* Electric potential in volts */
        unit V;
    }
    
    value def Angle :> Real {
        doc /* Divergence angle in degrees */
        unit '°';
    }
    
    value def Mass :> Real {
        doc /* Mass in kilograms */
        unit kg;
    }
    
    value def Length :> Real {
        doc /* Length in meters */
        unit m;
    }
    
    value def Force :> Real {
        doc /* Electrostatic force in newtons */
        unit N;
    }
    
    value def Conductance :> Real {
        doc /* Electrical conductance in siemens */
        unit S;
    }
    
    value def Resistance :> Real {
        doc /* Electrical resistance in ohms */
        unit 'Ω';
    }
    
    // ===== Item Types =====
    
    item def ElectricCharge {
        attribute magnitude : Charge;
        attribute polarity : ChargePolarity;
    }
    
    enum def ChargePolarity {
        neutral;
        positive;
        negative;
    }
    
    item def ChargedObject {
        attribute charge : ElectricCharge;
    }
    
    // ===== Interfaces =====
    
    interface def ChargeTransferInterface {
        end receivedCharge : ElectricCharge;
        end deliveredCharge : ElectricCharge;
    }
    
    interface def GroundingInterface {
        end chargeToGround : ElectricCharge;
        end dissipatedCharge : ElectricCharge;
    }
    
    // ===== Port Definitions =====
    
    port def ChargeInputPort {
        attribute chargeIn : ElectricCharge;
        out chargeFlow : ElectricCharge;
    }
    
    port def GroundPort {
        in chargeToDissipate : ElectricCharge;
        out dissipationStatus : Boolean;
    }
    
    port def ConductiveConnectionPort {
        in chargeIn : ElectricCharge;
        out chargeOut : ElectricCharge;
    }
    
    // ===== Component Part Definitions =====
    
    part def ConductiveCap {
        doc /* Conductive metal cap serving as primary interface for introducing electric charge */
        attribute material : String = "Brass";
        attribute diameter : Length = 0.03 [m];
        attribute thickness : Length = 0.002 [m];
        
        port chargeInput : ChargeInputPort;
        port rodConnection : ConductiveConnectionPort;
        
        attribute accumulatedCharge : ElectricCharge;
        
        action def ReceiveCharge {
            in chargedObj : ChargedObject;
            out transferredCharge : ElectricCharge;
        }
        
        action receive : ReceiveCharge;
    }
    
    part def ConductingRod {
        doc /* Conducting rod that extends downward from the cap to the leaves */
        attribute material : String = "Copper";
        attribute length : Length = 0.15 [m];
        attribute diameter : Length = 0.003 [m];
        attribute resistance : Resistance = 0.0005 ['Ω'];
        
        port capConnection : ConductiveConnectionPort;
        port leafConnection : ConductiveConnectionPort;
        
        attribute chargeThroughRod : ElectricCharge;
        
        action def ConductCharge {
            in incomingCharge : ElectricCharge;
            out distributedCharge : ElectricCharge;
        }
        
        action conduct : ConductCharge;
    }
    
    part def MetalLeaf {
        doc /* Thin lightweight metal leaf that diverges upon receiving like charge */
        attribute material : String = "Gold leaf";
        attribute length : Length = 0.08 [m];
        attribute width : Length = 0.012 [m];
        attribute mass : Mass = 0.00002 [kg];
        
        port rodAttachment : ConductiveConnectionPort;
        
        attribute leafCharge : ElectricCharge;
        attribute divergenceAngle : Angle = 0 ['°'];
        
        action def ReceiveLeafCharge {
            in charge : ElectricCharge;
            out leafChargeState : ElectricCharge;
        }
        
        action def RespondToRepulsion {
            in repulsiveForce : Force;
            out newAngle : Angle;
        }
        
        action receiveCharge : ReceiveLeafCharge;
        action respond : RespondToRepulsion;
    }
    
    part def LeafAssembly {
        doc /* Assembly of two metal leaves attached to the bottom of the rod */
        part leftLeaf : MetalLeaf;
        part rightLeaf : MetalLeaf;
        
        attribute totalDivergenceAngle : Angle;
        
        action def ComputeDivergence {
            in leftCharge : ElectricCharge;
            in rightCharge : ElectricCharge;
            out divergence : Angle;
        }
        
        action compute : ComputeDivergence;
    }
    
    part def InsulatingSupport {
        doc /* Insulating support that prevents electric charge from leaking away */
        attribute material : String = "Polyethylene";
        attribute height : Length = 0.12 [m];
        attribute resistance : Resistance = 1e14 ['Ω'];
        
        port mountPoint : ConductiveConnectionPort;
        
        attribute leakageRate : Charge = 0 [C];
    }
    
    part def ProtectiveEnclosure {
        doc /* Transparent protective enclosure surrounding the leaves */
        attribute material : String = "Glass";
        attribute height : Length = 0.20 [m];
        attribute diameter : Length = 0.08 [m];
        attribute transparent : Boolean = true;
        attribute sealed : Boolean = true;
        
        port observationPort;
    }
    
    // ===== Electroscope System =====
    
    part def Electroscope {
        doc /* Scientific instrument designed to detect the presence and relative magnitude of an electric charge */
        
        part cap : ConductiveCap;
        part rod : ConductingRod;
        part leaves : LeafAssembly;
        part support : InsulatingSupport;
        part enclosure : ProtectiveEnclosure;
        
        port externalChargePort : ChargeInputPort;
        port groundPort : GroundPort;
        
        attribute systemCharge : ElectricCharge;
        attribute systemState : ElectroscopeState;
        attribute observedDivergence : Angle;
        
        // Connections
        connection capToRod : ChargeTransferInterface connect cap.rodConnection to rod.capConnection;
        connection rodToLeaves : ChargeTransferInterface connect rod.leafConnection to leaves.leftLeaf.rodAttachment;
        connection rodToRightLeaf : ChargeTransferInterface connect rod.leafConnection to leaves.rightLeaf.rodAttachment;
        connection externalToCap : ChargeTransferInterface connect externalChargePort to cap.chargeInput;
        connection supportMount connect support.mountPoint to rod.capConnection;
        
        // State Machine
        state def ElectroscopeBehavior {
            entry action initialize {
                systemState := ElectroscopeState::uncharged;
                systemCharge.magnitude := 0 [C];
                systemCharge.polarity := ChargePolarity::neutral;
                observedDivergence := 0 ['°'];
            }
            
            state uncharged {
                doc /* Leaves hanging collapsed, no charge present */
                entry action setUncharged {
                    systemState := ElectroscopeState::uncharged;
                    leaves.leftLeaf.divergenceAngle := 0 ['°'];
                    leaves.rightLeaf.divergenceAngle := 0 ['°'];
                    observedDivergence := 0 ['°'];
                }
                
                transition to charging
                    when externalChargePort.chargeFlow.magnitude > 0 [C];
            }
            
            state charging {
                doc /* Charge is being distributed down the rod to both metal leaves */
                entry action distributeCharge {
                    systemState := ElectroscopeState::charging;
                    cap.receive(chargedObj := null);
                    rod.conduct(incomingCharge := cap.accumulatedCharge);
                    leaves.leftLeaf.receiveCharge(charge := rod.chargeThroughRod);
                    leaves.rightLeaf.receiveCharge(charge := rod.chargeThroughRod);
                    leaves.compute(leftCharge := leaves.leftLeaf.leafCharge, rightCharge := leaves.rightLeaf.leafCharge);
                }
                
                transition to charged
                    when leaves.totalDivergenceAngle > 0 ['°']
                    and systemCharge.magnitude == cap.accumulatedCharge.magnitude;
            }
            
            state charged {
                doc /* Leaves are diverged indicating presence of charge */
                entry action setCharged {
                    systemState := ElectroscopeState::charged;
                    observedDivergence := leaves.totalDivergenceAngle;
                }
                
                transition to uncharged
                    when groundPort.dissipationStatus == true
                    and systemCharge.magnitude == 0 [C];
                
                transition to charging
                    when externalChargePort.chargeFlow.magnitude > systemCharge.magnitude;
            }
            
            transition from charged to uncharged
                when groundPort.chargeToDissipate.magnitude > 0 [C]
                and groundPort.dissipationStatus == true;
        }
        
        state machine behavior : ElectroscopeBehavior;
        
        // Grounding action
        action def GroundElectroscope {
            in chargeToDissipate : ElectricCharge;
            out dissipated : Boolean;
            
            perform {
                systemCharge.magnitude := 0 [C];
                systemCharge.polarity := ChargePolarity::neutral;
                leaves.leftLeaf.leafCharge.magnitude := 0 [C];
                leaves.rightLeaf.leafCharge.magnitude := 0 [C];
                leaves.leftLeaf.divergenceAngle := 0 ['°'];
                leaves.rightLeaf.divergenceAngle := 0 ['°'];
                observedDivergence := 0 ['°'];
                dissipated := true;
            }
        }
        
        action ground : GroundElectroscope;
    }
    
    // ===== State Enumeration =====
    
    enum def ElectroscopeState {
        uncharged;
        charging;
        charged;
    }
    
    // ===== Requirements =====
    
    requirement def ElectroscopeDetectionRequirement {
        doc /* The electroscope shall detect the presence and relative magnitude of an electric charge */
        subject electroscope : Electroscope;
        
        requirement detectPresence {
            doc /* The electroscope shall indicate the presence of electric charge by divergence of leaves */
            subject e : Electroscope;
            objective {
                e.observedDivergence > 0 ['°'] implies e.systemCharge.magnitude > 0 [C];
            }
        }
        
        requirement indicateMagnitude {
            doc /* A larger charge shall result in a wider divergence angle */
            subject e : Electroscope;
            objective {
                e.systemCharge.magnitude > 1e-6 [C] implies e.observedDivergence > 5 ['°'];
                e.systemCharge.magnitude > 1e-4 [C] implies e.observedDivergence > 30 ['°'];
            }
        }
        
        requirement returnToNeutral {
            doc /* The electroscope shall return to neutral state when grounded */
            subject e : Electroscope;
            objective {
                e.ground(chargeToDissipate := e.systemCharge).dissipated == true implies
                    e.systemState == ElectroscopeState::uncharged;
            }
        }
    }
    
    requirement def ConstructionRequirement {
        doc /* The electroscope shall be constructed from specified key components */
        subject electroscope : Electroscope;
        
        requirement hasConductiveCap {
            subject e : Electroscope;
            objective { e.cap.material == "Brass"; }
        }
        
        requirement hasConductingRod {
            subject e : Electroscope;
            objective { e.rod.material == "Copper"; }
        }
        
        requirement hasTwoLeaves {
            subject e : Electroscope;
            objective { e.leaves.leftLeaf.material == "Gold leaf" and e.leaves.rightLeaf.material == "Gold leaf"; }
        }
        
        requirement hasInsulatingSupport {
            subject e : Electroscope;
            objective { e.support.resistance > 1e12 ['Ω']; }
        }
        
        requirement hasProtectiveEnclosure {
            subject e : Electroscope;
            objective { e.enclosure.transparent == true and e.enclosure.sealed == true; }
        }
    }
    
    requirement def OperationRequirement {
        doc /* The electroscope operation shall be based on electrostatic repulsion */
        subject electroscope : Electroscope;
        
        requirement samePolarityRepulsion {
            subject e : Electroscope;
            objective {
                e.leaves.leftLeaf.leafCharge.polarity == e.leaves.rightLeaf.leafCharge.polarity
                and e.leaves.leftLeaf.leafCharge.polarity != ChargePolarity::neutral
                implies e.observedDivergence > 0 ['°'];
            }
        }
        
        requirement chargeDistribution {
            subject e : Electroscope;
            objective {
                e.leaves.leftLeaf.leafCharge.magnitude == e.leaves.rightLeaf.leafCharge.magnitude;
            }
        }
    }
    
    // ===== Satisfaction =====
    
    satisfaction detectReq by Electroscope::electroscope : ElectroscopeDetectionRequirement;
    satisfaction constructReq by Electroscope::electroscope : ConstructionRequirement;
    satisfaction operationReq by Electroscope::electroscope : OperationRequirement;
}
