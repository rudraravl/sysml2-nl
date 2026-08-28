package SerbianBarrel {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceAndTime::*;
    import ISQVolume::*;

    // ===== Value Types =====
    value type StaveHeight :> Length;
    value type BarrelRadius :> Length;
    value type WaterLevel :> Length;
    value type WaterVolume :> Volume;
    value type FlowRate :> VolumeFlowRate;
    value type HoopTension :> Real { unit "N"; }
    value type StaveIntegrity :> Real { unit "1"; } // 0..1 health fraction

    attribute def StaveProfile {
        attribute id : Integer;
        attribute height : StaveHeight;
        attribute integrity : StaveIntegrity;
        attribute thickness : Length;
        attribute width : Length;
    }

    // ===== Item Definitions =====
    item def Water;
    item def ExcessWater :> Water;
    item def Wood;
    item def Metal;

    // ===== Port Definitions =====
    port def InletPort {
        out item water : Water;
        attribute flowRate : FlowRate;
    }
    port def OutletPort {
        in item water : Water;
        attribute flowRate : FlowRate;
    }
    port def OverflowPort {
        out item overflow : ExcessWater;
        attribute flowRate : FlowRate;
    }

    // ===== Requirements =====
    requirement def CapacityRequirement {
        subject barrel : SerbianBarrelSystem;
        objective {
            doc /* The effective capacity shall be determined solely by the shortest stave. */
            assert barrel.effectiveCapacity == barrel.computeShortestStaveCapacity();
        }
    }

    requirement def StructuralIntegrityRequirement {
        subject barrel : SerbianBarrelSystem;
        objective {
            doc /* All staves shall maintain integrity above a minimum threshold. */
            assert barrel.minStaveIntegrity >= 0.5;
        }
    }

    requirement def ContainmentRequirement {
        subject barrel : SerbianBarrelSystem;
        objective {
            doc /* The barrel shall contain water up to the shortest stave height without leakage. */
            assert barrel.currentWaterLevel <= barrel.shortestStaveHeight;
        }
    }

    // ===== Parts =====
    part def Stave {
        attribute profile : StaveProfile;
        port def StaveTopPort {
            attribute exposed : Boolean;
        }
        port topPort : StaveTopPort;
        item material : Wood;
        
        action def Degrade {
            in delta : Real;
            out newIntegrity : StaveIntegrity;
        }
    }

    part def Hoop {
        attribute id : Integer;
        attribute diameter : Length;
        attribute tension : HoopTension;
        item material : Metal;
    }

    part def BarrelBase {
        attribute radius : BarrelRadius;
        attribute thickness : Length;
        item material : Wood;
        port def BaseSealPort {
            attribute sealed : Boolean = true;
        }
        port sealPort : BaseSealPort;
    }

    // ===== Main System =====
    part def SerbianBarrelSystem {
        attribute id : String = "SB-001";
        attribute radius : BarrelRadius = 0.5 [m];
        attribute staveCount : Integer = 24;
        attribute hoopCount : Integer = 4;
        
        attribute staveProfiles : StaveProfile[24] = (
            StaveProfile{id=1, height=1.0[m], integrity=0.95, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=2, height=1.0[m], integrity=0.92, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=3, height=0.98[m], integrity=0.88, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=4, height=1.0[m], integrity=0.94, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=5, height=1.02[m], integrity=0.91, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=6, height=1.0[m], integrity=0.93, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=7, height=0.99[m], integrity=0.90, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=8, height=1.01[m], integrity=0.96, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=9, height=1.0[m], integrity=0.89, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=10, height=0.97[m], integrity=0.85, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=11, height=1.0[m], integrity=0.92, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=12, height=1.03[m], integrity=0.94, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=13, height=1.0[m], integrity=0.91, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=14, height=0.95[m], integrity=0.87, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=15, height=1.0[m], integrity=0.93, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=16, height=1.01[m], integrity=0.95, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=17, height=0.99[m], integrity=0.90, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=18, height=1.0[m], integrity=0.92, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=19, height=1.02[m], integrity=0.94, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=20, height=1.0[m], integrity=0.91, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=21, height=0.98[m], integrity=0.88, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=22, height=1.0[m], integrity=0.93, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=23, height=1.01[m], integrity=0.95, thickness=0.03[m], width=0.13[m]},
            StaveProfile{id=24, height=1.0[m], integrity=0.92, thickness=0.03[m], width=0.13[m]}
        );
        
        // Derived attributes
        attribute shortestStaveHeight : StaveHeight = staveProfiles->minBy(p | p.height).height;
        attribute tallestStaveHeight : StaveHeight = staveProfiles->maxBy(p | p.height).height;
        attribute averageStaveHeight : StaveHeight = staveProfiles->collect(p | p.height)->sum() / staveCount;
        attribute effectiveCapacity : WaterVolume = 3.14159 * radius * radius * shortestStaveHeight;
        attribute minStaveIntegrity : StaveIntegrity = staveProfiles->minBy(p | p.integrity).integrity;
        
        attribute currentWaterLevel : WaterLevel = 0 [m];
        attribute currentWaterVolume : WaterVolume = 0 [L];
        attribute inletFlowRate : FlowRate = 5 [L/min];
        attribute outletFlowRate : FlowRate = 8 [L/min];
        
        // Parts
        part staves : Stave[24] {
            each stave[i] : Stave {
                attribute profile = staveProfiles[i];
            }
        }
        
        part hoops : Hoop[4] {
            each hoop[i] : Hoop {
                attribute id = i;
                attribute diameter = 2 * radius;
                attribute tension = 500 [N];
            }
        }
        
        part base : BarrelBase {
            attribute radius = SerbianBarrelSystem::radius;
            attribute thickness = 0.04 [m];
        }
        
        // Ports
        port inlet : InletPort {
            attribute flowRate = inletFlowRate;
        }
        port outlet : OutletPort {
            attribute flowRate = outletFlowRate;
        }
        port overflow : OverflowPort {
            attribute flowRate = 0 [L/min];
        }
        
        // Connections
        connection inletFlow : Water = inlet.water to staves;
        connection outletFlow : Water = staves to outlet.water;
        connection overflowFlow : ExcessWater = staves to overflow.overflow;
        
        // ===== Behaviors =====
        action def ComputeShortestStaveCapacity :> Action {
            out capacity : WaterVolume;
            out shortestHeight : StaveHeight;
            perform {
                shortestHeight = staveProfiles->minBy(p | p.height).height;
                capacity = 3.14159 * radius * radius * shortestHeight;
            }
        }
        
        action def AnalyzeStaveHeights :> Action {
            out heights : StaveHeight[24];
            out shortest : StaveHeight;
            out tallest : StaveHeight;
            out average : StaveHeight;
            perform {
                heights = staveProfiles->collect(p | p.height);
                shortest = staveProfiles->minBy(p | p.height).height;
                tallest = staveProfiles->maxBy(p | p.height).height;
                average = staveProfiles->collect(p | p.height)->sum() / staveCount;
            }
        }
        
        action def InspectStructuralIntegrity :> Action {
            out integrities : StaveIntegrity[24];
            out minIntegrity : StaveIntegrity;
            out passed : Boolean;
            perform {
                integrities = staveProfiles->collect(p | p.integrity);
                minIntegrity = staveProfiles->minBy(p | p.integrity).integrity;
                passed = minIntegrity >= 0.5;
            }
        }
        
        action def FillBarrel :> Action {
            in duration : TimeValue;
            in flow : FlowRate;
            out newVolume : WaterVolume;
            out overflowVolume : WaterVolume;
            perform {
                newVolume = currentWaterVolume + flow * duration;
                if (newVolume > effectiveCapacity) {
                    overflowVolume = newVolume - effectiveCapacity;
                    newVolume = effectiveCapacity;
                    currentWaterLevel = shortestStaveHeight;
                } else {
                    overflowVolume = 0 [L];
                    currentWaterLevel = newVolume / (3.14159 * radius * radius);
                }
                currentWaterVolume = newVolume;
            }
        }
        
        action def DrainBarrel :> Action {
            in duration : TimeValue;
            in flow : FlowRate;
            out newVolume : WaterVolume;
            perform {
                newVolume = currentWaterVolume - flow * duration;
                if (newVolume < 0 [L]) {
                    newVolume = 0 [L];
                }
                currentWaterVolume = newVolume;
                currentWaterLevel = currentWaterVolume / (3.14159 * radius * radius);
            }
        }
        
        // ===== State Machine =====
        state def BarrelStateMachine {
            state empty {
                entry {
                    currentWaterVolume = 0 [L];
                    currentWaterLevel = 0 [m];
                }
                transition to filling {
                    when inlet.water->notEmpty();
                }
            }
            
            state filling {
                entry {
                    inletFlowRate = 5 [L/min];
                }
                do action FillBarrel {
                    in duration = 1 [min];
                    in flow = inletFlowRate;
                }
                transition to partiallyFull {
                    when currentWaterVolume > 0 [L] && currentWaterLevel < shortestStaveHeight;
                }
                transition to full {
                    when currentWaterLevel >= shortestStaveHeight;
                }
                transition to draining {
                    when outlet.water->notEmpty();
                }
            }
            
            state partiallyFull {
                do action FillBarrel {
                    in duration = 1 [min];
                    in flow = inletFlowRate;
                }
                transition to filling {
                    when inlet.water->notEmpty() && currentWaterLevel < shortestStaveHeight;
                }
                transition to full {
                    when currentWaterLevel >= shortestStaveHeight;
                }
                transition to draining {
                    when outlet.water->notEmpty();
                }
                transition to empty {
                    when currentWaterVolume == 0 [L];
                }
            }
            
            state full {
                entry {
                    currentWaterLevel = shortestStaveHeight;
                    currentWaterVolume = effectiveCapacity;
                    overflow.flowRate = inletFlowRate;
                }
                do action FillBarrel {
                    in duration = 1 [min];
                    in flow = inletFlowRate;
                }
                transition to draining {
                    when outlet.water->notEmpty();
                }
                transition to partiallyFull {
                    when currentWaterVolume < effectiveCapacity;
                }
            }
            
            state draining {
                entry {
                    overflow.flowRate = 0 [L/min];
                }
                do action DrainBarrel {
                    in duration = 1 [min];
                    in flow = outletFlowRate;
                }
                transition to empty {
                    when currentWaterVolume == 0 [L];
                }
                transition to partiallyFull {
                    when currentWaterVolume > 0 [L] && currentWaterLevel < shortestStaveHeight;
                }
                transition to filling {
                    when inlet.water->notEmpty() && currentWaterVolume > 0 [L];
                }
            }
        }
        
        // Requirements satisfaction
        satisfy capacityReq : CapacityRequirement {
            subject = Self;
        }
        satisfy structuralReq : StructuralIntegrityRequirement {
            subject = Self;
        }
        satisfy containmentReq : ContainmentRequirement {
            subject = Self;
        }
        
        // State machine instance
        state machine barrelStates : BarrelStateMachine;
        
        // Action instances available for invocation
        action analyzeHeights : AnalyzeStaveHeights;
        action inspectIntegrity : InspectStructuralIntegrity;
        action computeCapacity : ComputeShortestStaveCapacity;
    }
    
    // ===== Verification =====
    verification VerifyCapacity {
        subject barrel : SerbianBarrelSystem;
        objective {
            doc /* Verify that effective capacity equals volume at shortest stave height. */
            assert barrel.effectiveCapacity == 3.14159 * barrel.radius * barrel.radius * barrel.shortestStaveHeight;
        }
    }
    
    verification VerifyOverflow {
        subject barrel : SerbianBarrelSystem;
        objective {
            doc /* Verify that water above shortest stave overflows. */
            assert barrel.currentWaterLevel <= barrel.shortestStaveHeight;
        }
    }
}
