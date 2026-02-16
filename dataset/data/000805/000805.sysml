package 'Truss System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def LoadCondition;
    attribute def FailureMode;
    attribute def LoadRemoved;
    
    attribute def NodePosition {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    item def StructuralMaterial {
        attribute yieldStrength : PressureValue;
        attribute elasticModulus : PressureValue;
        attribute density : DensityValue;
    }
    
    item def Steel :> StructuralMaterial {
        attribute :>> yieldStrength = 250.0e6 [Pa];
        attribute :>> elasticModulus = 200.0e9 [Pa];
        attribute :>> density = 7850.0 [kg/(m^3)];
    }
    
    port def StructuralJoint {
        in appliedForce : ForceValue;
        out reactionForce : ForceValue;
    }
    
    port def LoadPort {
        in externalLoad : ForceValue;
    }
    
    part def TrussNode {
        attribute position : NodePosition;
        attribute isSupport : Boolean;
        port joint : StructuralJoint;
        port loadApplication : LoadPort;
    }
    
    part def TrussMember {
        attribute length : LengthValue;
        attribute crossSectionalArea : AreaValue;
        attribute material : StructuralMaterial;
        attribute internalForce : ForceValue;
        attribute axialStress : PressureValue;
        
        port startConnection : StructuralJoint;
        port endConnection : StructuralJoint;
    }
    
    action def CalculateInternalForces {
        in appliedLoads : ForceValue[*];
        in memberGeometry : TrussMember[*];
        in nodePositions : NodePosition[*];
        out memberForces : ForceValue[*];
        out supportReactions : ForceValue[*];
    }
    
    action def VerifyStressLimits {
        in internalForce : ForceValue;
        in crossSection : AreaValue;
        in allowableStress : PressureValue;
        out calculatedStress : PressureValue;
        out isAcceptable : Boolean;
    }
    
    action def ComputeDeflection {
        in memberForces : ForceValue[*];
        in memberStiffness : PressureValue[*];
        in loadMagnitude : ForceValue;
        out maxDeflection : LengthValue;
    }
    
    action def AnalyzeTrussStructure {
        in trussConfiguration : TrussAssembly;
        in loadingCondition : LoadCondition;
        out structuralResponse : LengthValue;
        out memberStresses : PressureValue[*];
        out safetyStatus : Boolean;
        
        first start;
        then action calculateForces : CalculateInternalForces {
            in appliedLoads;
            in memberGeometry;
            in nodePositions;
            out memberForces;
            out supportReactions;
        }
        then action verifyStresses[*] : VerifyStressLimits;
        then action computeDeflections : ComputeDeflection {
            in memberForces = calculateForces.memberForces;
            out maxDeflection;
        }
        then decide;
            if computeDeflections.maxDeflection < trussConfiguration.deflectionLimit then acceptable;
            if computeDeflections.maxDeflection >= trussConfiguration.deflectionLimit then unacceptable;
        action acceptable {
            assign safetyStatus := true;
        }
        then done;
        action unacceptable {
            assign safetyStatus := false;
        }
        then done;
    }
    
    state def TrussLifecycle {
        entry; then unloaded;
        
        state unloaded;
        transition unloaded_to_loading
            first unloaded
            accept loadApplied : LoadCondition
            then loading;
        
        state loading {
            do action performAnalysis : AnalyzeTrussStructure;
        }
        transition loading_to_operational
            first loading
            if performAnalysis.safetyStatus
            then operational;
        transition loading_to_overstressed
            first loading
            if not performAnalysis.safetyStatus
            then overstressed;
        
        state operational {
            do action monitorStructure;
        }
        transition operational_to_unloading
            first operational
            accept loadRemoval : LoadRemoved
            then unloading;
        
        state unloading;
        transition unloading_to_unloaded
            first unloading
            then unloaded;
        
        state overstressed;
        transition overstressed_to_failure
            first overstressed
            then failure;
        
        state failure;
    }
    
    part def TrussAssembly {
        attribute spanLength : LengthValue;
        attribute height : LengthValue;
        attribute designLoad : ForceValue;
        attribute deflectionLimit : LengthValue;
        attribute safetyFactor : Real;
        
        part nodes : TrussNode[8] {
            part bottomLeft : TrussNode {
                attribute :>> position {
                    attribute :>> x = 0.0 [m];
                    attribute :>> y = 0.0 [m];
                    attribute :>> z = 0.0 [m];
                }
                attribute :>> isSupport = true;
            }
            part bottomMidLeft : TrussNode {
                attribute :>> position {
                    attribute :>> x = 2.0 [m];
                    attribute :>> y = 0.0 [m];
                    attribute :>> z = 0.0 [m];
                }
                attribute :>> isSupport = false;
            }
            part bottomMidRight : TrussNode {
                attribute :>> position {
                    attribute :>> x = 4.0 [m];
                    attribute :>> y = 0.0 [m];
                    attribute :>> z = 0.0 [m];
                }
                attribute :>> isSupport = false;
            }
            part bottomRight : TrussNode {
                attribute :>> position {
                    attribute :>> x = 6.0 [m];
                    attribute :>> y = 0.0 [m];
                    attribute :>> z = 0.0 [m];
                }
                attribute :>> isSupport = true;
            }
            part topLeft : TrussNode {
                attribute :>> position {
                    attribute :>> x = 1.0 [m];
                    attribute :>> y = 2.0 [m];
                    attribute :>> z = 0.0 [m];
                }
                attribute :>> isSupport = false;
            }
            part topMidLeft : TrussNode {
                attribute :>> position {
                    attribute :>> x = 3.0 [m];
                    attribute :>> y = 2.0 [m];
                    attribute :>> z = 0.0 [m];
                }
                attribute :>> isSupport = false;
            }
            part topMidRight : TrussNode {
                attribute :>> position {
                    attribute :>> x = 5.0 [m];
                    attribute :>> y = 2.0 [m];
                    attribute :>> z = 0.0 [m];
                }
                attribute :>> isSupport = false;
            }
            part topRight : TrussNode {
                attribute :>> position {
                    attribute :>> x = 6.0 [m];
                    attribute :>> y = 1.0 [m];
                    attribute :>> z = 0.0 [m];
                }
                attribute :>> isSupport = false;
            }
        }
        
        part members : TrussMember[13] {
            part bottomChord1 : TrussMember {
                attribute :>> length = 2.0 [m];
                attribute :>> crossSectionalArea = 0.0015 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomLeft.joint;
                connect endConnection to nodes::bottomMidLeft.joint;
            }
            part bottomChord2 : TrussMember {
                attribute :>> length = 2.0 [m];
                attribute :>> crossSectionalArea = 0.0015 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomMidLeft.joint;
                connect endConnection to nodes::bottomMidRight.joint;
            }
            part bottomChord3 : TrussMember {
                attribute :>> length = 2.0 [m];
                attribute :>> crossSectionalArea = 0.0015 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomMidRight.joint;
                connect endConnection to nodes::bottomRight.joint;
            }
            part topChord1 : TrussMember {
                attribute :>> length = 2.0 [m];
                attribute :>> crossSectionalArea = 0.0015 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::topLeft.joint;
                connect endConnection to nodes::topMidLeft.joint;
            }
            part topChord2 : TrussMember {
                attribute :>> length = 2.0 [m];
                attribute :>> crossSectionalArea = 0.0015 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::topMidLeft.joint;
                connect endConnection to nodes::topMidRight.joint;
            }
            part diagonal1 : TrussMember {
                attribute :>> length = 2.236 [m];
                attribute :>> crossSectionalArea = 0.001 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomLeft.joint;
                connect endConnection to nodes::topLeft.joint;
            }
            part diagonal2 : TrussMember {
                attribute :>> length = 2.236 [m];
                attribute :>> crossSectionalArea = 0.001 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomMidLeft.joint;
                connect endConnection to nodes::topLeft.joint;
            }
            part diagonal3 : TrussMember {
                attribute :>> length = 2.236 [m];
                attribute :>> crossSectionalArea = 0.001 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomMidLeft.joint;
                connect endConnection to nodes::topMidLeft.joint;
            }
            part diagonal4 : TrussMember {
                attribute :>> length = 2.236 [m];
                attribute :>> crossSectionalArea = 0.001 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomMidRight.joint;
                connect endConnection to nodes::topMidLeft.joint;
            }
            part diagonal5 : TrussMember {
                attribute :>> length = 2.236 [m];
                attribute :>> crossSectionalArea = 0.001 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomMidRight.joint;
                connect endConnection to nodes::topMidRight.joint;
            }
            part diagonal6 : TrussMember {
                attribute :>> length = 2.236 [m];
                attribute :>> crossSectionalArea = 0.001 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomRight.joint;
                connect endConnection to nodes::topMidRight.joint;
            }
            part diagonal7 : TrussMember {
                attribute :>> length = 1.414 [m];
                attribute :>> crossSectionalArea = 0.001 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::bottomRight.joint;
                connect endConnection to nodes::topRight.joint;
            }
            part endChord : TrussMember {
                attribute :>> length = 1.414 [m];
                attribute :>> crossSectionalArea = 0.0012 [m^2];
                attribute :>> material : Steel;
                connect startConnection to nodes::topMidRight.joint;
                connect endConnection to nodes::topRight.joint;
            }
        }
    }
    
    requirement def StructuralIntegrityRequirement {
        doc /* The truss structure shall maintain structural integrity under all design load conditions. */
        subject truss : TrussAssembly;
    }
    
    requirement def LoadCapacityRequirement :> StructuralIntegrityRequirement {
        doc /* The truss shall safely support the specified design loads without exceeding allowable member stresses. */
        
        require constraint stressConstraint {
            doc /* All member stresses shall remain below material yield strength divided by safety factor. */
        }
    }
    
    requirement def DeflectionRequirement :> StructuralIntegrityRequirement {
        doc /* The truss deflection under design load shall not exceed the specified limit. */
        
        require constraint deflectionConstraint {
            doc /* Maximum vertical deflection shall be less than span length divided by 360. */
        }
    }
    
    requirement <'TRUSS-REQ-001'> primaryStructuralRequirement : StructuralIntegrityRequirement {
        doc /*
            The truss system shall distribute applied loads through its interconnected triangulated 
            member framework to support points, transferring forces efficiently through axial tension 
            and compression in individual members while maintaining deflections within acceptable limits 
            and ensuring no member exceeds its allowable stress capacity.
        */
        
        assume constraint loadApplication {
            doc /* Loads are applied only at node locations. */
        }
        
        assume constraint supportConditions {
            doc /* Support nodes provide adequate reaction capacity and constraint. */
        }
        
        require loadCapacityReq : LoadCapacityRequirement;
        require deflectionReq : DeflectionRequirement;
    }
    
    part def TrussSystem {
        doc /*
            A structural system utilizing a triangulated framework of interconnected members to efficiently 
            transfer loads from application points to supports. The primary function is to span distances 
            while supporting applied loads through a combination of tension and compression forces in 
            individual members, providing a lightweight yet strong structural solution.
        */
        
        attribute systemSpan : LengthValue;
        attribute maximumLoad : ForceValue;
        attribute operationalSafetyFactor : Real;
        
        part structure : TrussAssembly;
        
        perform action structuralBehavior : AnalyzeTrussStructure {
            in trussConfiguration = structure;
        }
        
        exhibit state lifecycle : TrussLifecycle;
    }
    
    part trussSystem : TrussSystem {
        attribute :>> systemSpan = 6.0 [m];
        attribute :>> maximumLoad = 100000.0 [N];
        attribute :>> operationalSafetyFactor = 2.0;
        
        part :>> structure {
            attribute :>> spanLength = 6.0 [m];
            attribute :>> height = 2.0 [m];
            attribute :>> designLoad = 100000.0 [N];
            attribute :>> deflectionLimit = 0.0167 [m];
            attribute :>> safetyFactor = 2.0;
        }
        
        satisfy primaryStructuralRequirement by trussSystem;
    }
}
