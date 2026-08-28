package TrussSystem {

    package Definitions {

        attribute def LengthValue :> ISQ::LengthValue { unit m; }
        attribute def ForceValue :> ISQ::ForceValue { unit N; }
        attribute def AreaValue :> ISQ::AreaValue { unit m2; }
        attribute def StressValue :> ISQ::PressureValue { unit Pa; }
        attribute def MassValue :> ISQ::MassValue { unit kg; }
        attribute def DensityValue :> ISQ::DensityValue { unit kg/m3; }
        attribute def DisplacementValue :> ISQ::LengthValue { unit mm; }

        item def SteelMaterial {
            attribute yieldStrength : StressValue = 250e6 [Pa];
            attribute ultimateStrength : StressValue = 400e6 [Pa];
            attribute elasticModulus : StressValue = 200e9 [Pa];
            attribute density : DensityValue = 7850 [kg/m3];
            attribute poissonRatio : Real = 0.3;
        }

        item def MemberResult {
            attribute axialForce : ForceValue;
            attribute axialStress : StressValue;
            attribute inTension : Boolean;
        }
    }

    part def Node {
        attribute id : String;
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute isSupport : Boolean = false;
        attribute supportType : String = "none";
        attribute reactionX : ForceValue := 0 [N];
        attribute reactionY : ForceValue := 0 [N];
        attribute appliedLoadY : ForceValue := 0 [N];
    }

    part def Member {
        attribute id : String;
        attribute memberType : String;
        attribute length : LengthValue;
        attribute crossSectionArea : AreaValue;
        ref material : Definitions::SteelMaterial;
        ref endNodeA : Node;
        ref endNodeB : Node;
        attribute axialForce : ForceValue := 0 [N];
        attribute axialStress : StressValue := 0 [Pa];
        attribute inTension : Boolean := true;
        attribute allowableStress : StressValue := 0.6 * material.yieldStrength;

        action def computeStress {
            in member : Member;
            out stress : StressValue;
            out tension : Boolean;
            stress := member.axialForce / member.crossSectionArea;
            tension := member.axialForce >= 0 [N];
        }
    }

    part def TrussAnalysis {
        attribute maxDeflection : DisplacementValue := 0 [mm];
        attribute allowableDeflection : DisplacementValue := 12 [mm];
        attribute maxStress : StressValue := 0 [Pa];
        attribute allResults : Definitions::MemberResult[*];

        action def runAnalysis {
            in truss : TrussSystem::Truss;
            in appliedLoad : ForceValue;
            out deflection : DisplacementValue;
            out peakStress : StressValue;
            out overstressed : Boolean;
            // Simplified structural analysis placeholder replaced by deterministic computation
            deflection := (appliedLoad * truss.span * truss.span * truss.span) /
                          (48 * truss.members#1.material.elasticModulus * truss.members#1.crossSectionArea * truss.height * truss.height);
            peakStress := appliedLoad / truss.members#1.crossSectionArea;
            overstressed := (peakStress > truss.members#1.allowableStress) or (deflection > allowableDeflection);
        }
    }

    part def Truss {
        attribute span : LengthValue = 6 [m];
        attribute height : LengthValue = 1.5 [m];
        attribute designLoad : ForceValue = 100000 [N];
        attribute designLoadMass : MassValue = 10000 [kg];
        ref material : Definitions::SteelMaterial;

        part nodes : Node[8] {
            part n1 : Node { id = "N1"; x = 0 [m]; y = 0 [m]; isSupport = true; supportType = "pin"; }
            part n2 : Node { id = "N2"; x = 2 [m]; y = 0 [m]; }
            part n3 : Node { id = "N3"; x = 4 [m]; y = 0 [m]; }
            part n4 : Node { id = "N4"; x = 6 [m]; y = 0 [m]; isSupport = true; supportType = "roller"; }
            part n5 : Node { id = "N5"; x = 0 [m]; y = 1.5 [m]; }
            part n6 : Node { id = "N6"; x = 2 [m]; y = 1.5 [m]; }
            part n7 : Node { id = "N7"; x = 4 [m]; y = 1.5 [m]; }
            part n8 : Node { id = "N8"; x = 6 [m]; y = 1.5 [m]; }
        }

        part members : Member[13] {
            part b1 : Member { id = "B1"; memberType = "bottomChord"; length = 2 [m]; crossSectionArea = 0.002 [m2]; endNodeA = nodes.n1; endNodeB = nodes.n2; }
            part b2 : Member { id = "B2"; memberType = "bottomChord"; length = 2 [m]; crossSectionArea = 0.002 [m2]; endNodeA = nodes.n2; endNodeB = nodes.n3; }
            part b3 : Member { id = "B3"; memberType = "bottomChord"; length = 2 [m]; crossSectionArea = 0.002 [m2]; endNodeA = nodes.n3; endNodeB = nodes.n4; }
            part t1 : Member { id = "T1"; memberType = "topChord"; length = 2 [m]; crossSectionArea = 0.0025 [m2]; endNodeA = nodes.n5; endNodeB = nodes.n6; }
            part t2 : Member { id = "T2"; memberType = "topChord"; length = 2 [m]; crossSectionArea = 0.0025 [m2]; endNodeA = nodes.n6; endNodeB = nodes.n7; }
            part t3 : Member { id = "T3"; memberType = "topChord"; length = 2 [m]; crossSectionArea = 0.0025 [m2]; endNodeA = nodes.n7; endNodeB = nodes.n8; }
            part d1 : Member { id = "D1"; memberType = "diagonal"; length = 2.5 [m]; crossSectionArea = 0.0015 [m2]; endNodeA = nodes.n1; endNodeB = nodes.n5; }
            part d2 : Member { id = "D2"; memberType = "diagonal"; length = 2.5 [m]; crossSectionArea = 0.0015 [m2]; endNodeA = nodes.n5; endNodeB = nodes.n2; }
            part d3 : Member { id = "D3"; memberType = "diagonal"; length = 2.5 [m]; crossSectionArea = 0.0015 [m2]; endNodeA = nodes.n2; endNodeB = nodes.n6; }
            part d4 : Member { id = "D4"; memberType = "diagonal"; length = 2.5 [m]; crossSectionArea = 0.0015 [m2]; endNodeA = nodes.n6; endNodeB = nodes.n3; }
            part d5 : Member { id = "D5"; memberType = "diagonal"; length = 2.5 [m]; crossSectionArea = 0.0015 [m2]; endNodeA = nodes.n3; endNodeB = nodes.n7; }
            part d6 : Member { id = "D6"; memberType = "diagonal"; length = 2.5 [m]; crossSectionArea = 0.0015 [m2]; endNodeA = nodes.n7; endNodeB = nodes.n4; }
            part d7 : Member { id = "D7"; memberType = "diagonal"; length = 2.5 [m]; crossSectionArea = 0.0015 [m2]; endNodeA = nodes.n4; endNodeB = nodes.n8; }
        }

        part analysis : TrussAnalysis;

        port def LoadPort {
            attribute appliedLoad : ForceValue;
        }

        port loadPort : LoadPort;

        exhibit state trussStateMachine {
            attribute currentLoad : ForceValue := 0 [N];

            state unloaded {
                entry { currentLoad := 0 [N]; }
            }

            state loading {
                entry {
                    analysis.runAnalysis(in appliedLoad = currentLoad, out deflection = analysis.maxDeflection, out peakStress = analysis.maxStress, out overstressed = ?);
                }
                do {
                    send TrussAnalysisComplete();
                }
            }

            state operational;
            state overstressed;

            transition unloaded_to_loading
                first unloaded
                if loadPort.appliedLoad > 0 [N]
                then loading
                assign currentLoad := loadPort.appliedLoad;

            transition loading_to_operational
                from loading
                to operational
                when (analysis.maxStress <= members#1.allowableStress) and (analysis.maxDeflection <= analysis.allowableDeflection);

            transition loading_to_overstressed
                from loading
                to overstressed
                when (analysis.maxStress > members#1.allowableStress) or (analysis.maxDeflection > analysis.allowableDeflection);

            transition operational_to_unloaded
                from operational
                to unloaded
                when loadPort.appliedLoad == 0 [N];
        }
    }

    package Requirements {

        requirement def SpanRequirement {
            attribute requiredSpan : LengthValue = 6 [m];
            subject truss : TrussSystem::Truss;
            require truss.span == requiredSpan;
        }

        requirement def LoadCapacityRequirement {
            attribute requiredLoad : ForceValue = 100000 [N];
            subject truss : TrussSystem::Truss;
            require truss.designLoad >= requiredLoad;
        }

        requirement def MemberCountRequirement {
            subject truss : TrussSystem::Truss;
            require truss.members.size() == 13;
        }

        requirement def NodeCountRequirement {
            subject truss : TrussSystem::Truss;
            require truss.nodes.size() == 8;
        }

        requirement def SupportRequirement {
            subject truss : TrussSystem::Truss;
            require truss.nodes->select(isSupport)->size() == 2;
        }

        requirement def SafetyRequirement {
            subject truss : TrussSystem::Truss;
            require truss.analysis.maxStress <= truss.members#1.allowableStress;
            require truss.analysis.maxDeflection <= truss.analysis.allowableDeflection;
        }

        requirement def MaterialRequirement {
            subject truss : TrussSystem::Truss;
            require truss.material.yieldStrength >= 250e6 [Pa];
            require truss.material.elasticModulus >= 200e9 [Pa];
        }

        requirement TrussSystemRequirements {
            satisfy SpanRequirement;
            satisfy LoadCapacityRequirement;
            satisfy MemberCountRequirement;
            satisfy NodeCountRequirement;
            satisfy SupportRequirement;
            satisfy SafetyRequirement;
            satisfy MaterialRequirement;
        }
    }

    part def TrussAssembly {
        part truss : Truss {
            material = Definitions::SteelMaterial {
                yieldStrength = 250e6 [Pa];
                ultimateStrength = 400e6 [Pa];
                elasticModulus = 200e9 [Pa];
                density = 7850 [kg/m3];
                poissonRatio = 0.3;
            }
        }

        satisfy Requirements::TrussSystemRequirements by truss;
    }

}
