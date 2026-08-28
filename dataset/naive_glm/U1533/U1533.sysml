package WedgeSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;
    import Quantities::*;
    
    // ===== Value Types =====
    
    value def AngleValue :> Real {
        unit unit angle = 1 [NonSI::degree];
    }
    
    value def LengthValue :> Real {
        unit unit length = 1 [SI::mm];
    }
    
    value def ForceValue :> Real {
        unit unit force = 1 [SI::N];
    }
    
    value def HardnessValue :> Real {
        unit unit hardness = 1 [SI::unitless];
    }
    
    value def StressValue :> Real {
        unit unit stress = 1 [SI::Pa];
    }
    
    value def AreaValue :> Real {
        unit unit area = 1 [SI::m2];
    }
    
    value def MassValue :> Real {
        unit unit mass = 1 [SI::kg];
    }
    
    value def VelocityValue :> Real {
        unit unit velocity = 1 [SI::m/s];
    }
    
    value def MechanicalAdvantage :> Real {
        unit unit dimensionless = 1 [SI::unitless];
    }
    
    // ===== Item Types =====
    
    item def MaterialProperties {
        attribute hardness : HardnessValue;
        attribute tensileStrength : StressValue;
        attribute compressiveStrength : StressValue;
    }
    
    item def WedgeMaterial :> MaterialProperties {
        attribute yieldStrength : StressValue;
        attribute impactResistance : StressValue;
    }
    
    item def TargetMaterialProperties :> MaterialProperties {
        attribute fractureToughness : StressValue;
        attribute grainOrientation : AngleValue;
    }
    
    // ===== Requirements =====
    
    requirement def WedgeGeometryRequirements {
        doc {/*
            The system is designed to operate with a wedge angle 
            between 5 and 40 degrees for optimal performance and 
            structural integrity.
        */}
        attribute wedgeAngle : AngleValue;
        require { wedgeAngle >= 5 [angle] }
        require { wedgeAngle <= 40 [angle] }
    }
    
    requirement def WedgeMaterialRequirements {
        doc {/*
            The wedge must be made of a durable material characterized 
            by its hardness and strength, which must be sufficient to 
            withstand the operational forces without breaking.
        */}
        attribute materialHardness : HardnessValue;
        attribute materialStrength : StressValue;
        require { materialHardness > 50 [hardness] }
        require { materialStrength > 500 [stress] }
    }
    
    requirement def ForceAmplificationRequirement {
        doc {/*
            The wedge's angled surfaces amplify the input force, 
            generating powerful lateral splitting forces.
        */}
        attribute inputForce : ForceValue;
        attribute outputForce : ForceValue;
        attribute amplification : MechanicalAdvantage;
        require { outputForce > inputForce }
        require { amplification > 1.0 [dimensionless] }
    }
    
    requirement def TargetMaterialRequirement {
        doc {/*
            Target material properties determine how much force 
            is required to split it.
        */}
        attribute materialHardness : HardnessValue;
        attribute fractureToughness : StressValue;
        require { materialHardness > 10 [hardness] }
        require { fractureToughness > 1 [stress] }
    }
    
    // ===== Parts =====
    
    part def Wedge {
        attribute angle : AngleValue = 20 [angle];
        attribute length : LengthValue = 150 [length];
        attribute thickness : LengthValue = 52.4 [length];
        attribute mass : MassValue = 2.5 [mass];
        
        attribute material : WedgeMaterial {
            hardness = 65 [hardness];
            tensileStrength = 800 [stress];
            compressiveStrength = 1200 [stress];
            yieldStrength = 750 [stress];
            impactResistance = 900 [stress];
        }
        
        attribute mechanicalAdvantage : MechanicalAdvantage = 1.0 [dimensionless];
        
        port def BluntEndPort {
            attribute appliedForce : ForceValue;
            in inputForce : ForceValue;
        }
        
        port def InclinedSurfacePort {
            attribute lateralForce : ForceValue;
            out splittingForce : ForceValue;
        }
        
        port bluntEnd : BluntEndPort;
        port leftInclinedSurface : InclinedSurfacePort;
        port rightInclinedSurface : InclinedSurfacePort;
        
        satisfy WedgeGeometryRequirements by wedgeGeometryReq {
            wedgeAngle = angle;
        }
        
        satisfy WedgeMaterialRequirements by wedgeMaterialReq {
            materialHardness = material.hardness;
            materialStrength = material.yieldStrength;
        }
        
        exhibit WedgeOperationalStates {
            attribute operationalState : String;
            
            entry action initializeWedge {
                operationalState = "Ready";
            }
            
            state Ready {
                entry { operationalState = "Ready"; }
                transition Ready -> Engaging 
                    on bluntEnd.inputForce 
                    when { bluntEnd.inputForce > 0 [force] };
            }
            
            state Engaging {
                entry { operationalState = "Engaging"; }
                do action engageMaterial {
                    mechanicalAdvantage := 1.0 / (2.0 * (angle / 2.0) * 3.14159 / 180.0);
                    leftInclinedSurface.splittingForce := bluntEnd.inputForce * mechanicalAdvantage / 2.0;
                    rightInclinedSurface.splittingForce := bluntEnd.inputForce * mechanicalAdvantage / 2.0;
                }
                transition Engaging -> Splitting 
                    when { leftInclinedSurface.splittingForce > 1000 [force] };
            }
            
            state Splitting {
                entry { operationalState = "Splitting"; }
                do action splitMaterial {
                    leftInclinedSurface.splittingForce := bluntEnd.inputForce * mechanicalAdvantage;
                    rightInclinedSurface.splittingForce := bluntEnd.inputForce * mechanicalAdvantage;
                }
                transition Splitting -> Ready 
                    when { bluntEnd.inputForce == 0 [force] };
            }
        }
    }
    
    part def AppliedLoad {
        attribute loadType : String;
        attribute magnitude : ForceValue;
        attribute duration : Real;
        attribute impactVelocity : VelocityValue;
        
        port def LoadOutputPort {
            out outputForce : ForceValue;
        }
        
        port loadOutput : LoadOutputPort;
        
        exhibit LoadApplicationStates {
            attribute loadState : String;
            
            entry action initializeLoad {
                loadState = "Idle";
            }
            
            state Idle {
                entry { loadState = "Idle"; }
                transition Idle -> Applying 
                    when { magnitude > 0 [force] };
            }
            
            state Applying {
                entry { loadState = "Applying"; }
                do action applyForce {
                    loadOutput.outputForce := magnitude;
                }
                transition Applying -> Idle 
                    when { magnitude == 0 [force] };
            }
        }
    }
    
    part def TargetMaterial {
        attribute materialType : String;
        attribute dimensions : LengthValue;
        attribute crossSectionalArea : AreaValue;
        
        attribute properties : TargetMaterialProperties {
            hardness = 15 [hardness];
            tensileStrength = 50 [stress];
            compressiveStrength = 40 [stress];
            fractureToughness = 5 [stress];
            grainOrientation = 90 [angle];
        }
        
        attribute requiredSplitForce : ForceValue;
        
        port def MaterialInputPort {
            in appliedForce : ForceValue;
            attribute resistanceForce : ForceValue;
        }
        
        port leftSplitSurface : MaterialInputPort;
        port rightSplitSurface : MaterialInputPort;
        
        satisfy TargetMaterialRequirement by targetMaterialReq {
            materialHardness = properties.hardness;
            fractureToughness = properties.fractureToughness;
        }
        
        exhibit MaterialResponseStates {
            attribute materialState : String;
            
            entry action initializeMaterial {
                materialState = "Intact";
                requiredSplitForce := properties.fractureToughness * crossSectionalArea;
            }
            
            state Intact {
                entry { materialState = "Intact"; }
                transition Intact -> Resisting 
                    on leftSplitSurface.appliedForce 
                    when { leftSplitSurface.appliedForce > 0 [force] };
            }
            
            state Resisting {
                entry { materialState = "Resisting"; }
                do action resistForce {
                    leftSplitSurface.resistanceForce := properties.fractureToughness * crossSectionalArea;
                    rightSplitSurface.resistanceForce := properties.fractureToughness * crossSectionalArea;
                }
                transition Resisting -> Split 
                    when { leftSplitSurface.appliedForce > requiredSplitForce };
            }
            
            state Split {
                entry { materialState = "Split"; }
                do action completeSplit {
                    leftSplitSurface.resistanceForce := 0 [force];
                    rightSplitSurface.resistanceForce := 0 [force];
                }
            }
        }
    }
    
    // ===== System Assembly =====
    
    part WedgeSystemAssembly {
        part wedge : Wedge {
            attribute angle = 20 [angle];
            attribute length = 150 [length];
            attribute thickness = 52.4 [length];
        }
        
        part appliedLoad : AppliedLoad {
            attribute loadType = "Impact";
            attribute magnitude = 5000 [force];
            attribute duration = 0.01;
            attribute impactVelocity = 5.0 [velocity];
        }
        
        part targetMaterial : TargetMaterial {
            attribute materialType = "Oak Wood";
            attribute dimensions = 300 [length];
            attribute crossSectionalArea = 0.01 [area];
        }
        
        satisfy ForceAmplificationRequirement by forceAmpReq {
            inputForce = appliedLoad.magnitude;
            outputForce = wedge.leftInclinedSurface.splittingForce + wedge.rightInclinedSurface.splittingForce;
            amplification = wedge.mechanicalAdvantage;
        }
        
        connection def ForceTransmission {
            end sourceForce : ForceValue;
            end targetForce : ForceValue;
            attribute transmissionEfficiency : Real = 0.95;
        }
        
        connection loadToWedge : ForceTransmission 
            connect appliedLoad.loadOutput.outputForce to wedge.bluntEnd.inputForce;
        
        connection wedgeToTargetLeft : ForceTransmission 
            connect wedge.leftInclinedSurface.splittingForce to targetMaterial.leftSplitSurface.appliedForce;
        
        connection wedgeToTargetRight : ForceTransmission 
            connect wedge.rightInclinedSurface.splittingForce to targetMaterial.rightSplitSurface.appliedForce;
        
        action def WedgeOperationSequence {
            input initialForce : ForceValue;
            output splitResult : Boolean;
            
            action applyLoad {
                output loadForce : ForceValue;
            }
            
            action driveWedge {
                in inputForce : ForceValue;
                output lateralForce : ForceValue;
            }
            
            action splitMaterial {
                in splittingForce : ForceValue;
                output materialSplit : Boolean;
            }
            
            flow applyLoad.loadForce to driveWedge.inputForce;
            flow driveWedge.lateralForce to splitMaterial.splittingForce;
        }
    }
}
