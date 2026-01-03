package EsophagealStentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StentDiameter :> LengthValue {
        doc /* Internal diameter of the stent lumen in millimeters */
    }
    
    attribute def StentLength :> LengthValue {
        doc /* Axial length of the stent body in millimeters */
    }
    
    attribute def RadialForce :> ForceValue {
        doc /* Chronic outward radial force exerted by the stent against tissue */
    }
    
    attribute def FlowRate :> VolumeFlowRateValue {
        doc /* Rate of bolus passage through the esophageal lumen */
    }
    
    enum def StentMaterial {
        nitinol;
        stainless_steel;
        silicone_covered;
        biodegradable_polymer;
    }
    
    enum def StentStatus {
        compressed;
        deploying;
        fully_expanded;
        patent;
        migrated;
        occluded;
    }
    
    item def FoodBolus {
        attribute volume : VolumeValue;
        attribute consistency : String;
    }
    
    item def EsophagealTissue {
        attribute nativeDiameter : StentDiameter;
        attribute strictureLocation : LengthValue;
        attribute strictureSeverity : Real;
        attribute compressionForce : ForceValue;
    }
    
    port def LumenPort {
        in foodBolus : FoodBolus;
        out foodBolus : FoodBolus;
        in flowRate : FlowRate;
    }
    
    port def TissueInterfacePort {
        in tissueCompression : ForceValue;
        out radialExpansion : RadialForce;
    }
    
    port def DeploymentPort {
        in deploymentCommand : Boolean;
        out expansionStatus : Real;
    }
    
    part def StentMesh {
        attribute material : StentMaterial;
        attribute wireThickness : LengthValue;
        attribute meshDensity : Real;
        attribute radialForce : RadialForce;
        attribute elasticModulus : PressureValue;
    }
    
    part def StentCovering {
        attribute coverageType : String;
        attribute permeability : Real;
        attribute biocompatibility : Real;
    }
    
    part def ProximalFlange {
        attribute flareDiameter : StentDiameter;
        attribute flareAngle : AngleValue;
        
        port migrationResistance : TissueInterfacePort;
    }
    
    part def DistalFlange {
        attribute flareDiameter : StentDiameter;
        attribute flareAngle : AngleValue;
        
        port anchoringInterface : TissueInterfacePort;
    }
    
    part def LumenChannel {
        attribute innerDiameter : StentDiameter;
        attribute effectiveLength : StentLength;
        
        port proximalOpening : LumenPort;
        port distalOpening : LumenPort;
    }
    
    part def DeliverySystem {
        attribute catheterDiameter : LengthValue;
        attribute workingLength : LengthValue;
        
        port deliveryControl : DeploymentPort;
    }
    
    part def EsophagealStent {
        doc /* 
            Self-expanding metallic stent designed to maintain esophageal patency.
            Provides radial support to counteract stricture forces and enable swallowing.
        */
        
        attribute nominalDiameter : StentDiameter;
        attribute nominalLength : StentLength;
        attribute currentStatus : StentStatus;
        attribute deploymentProgress : Real;
        
        part mesh : StentMesh {
            attribute :>> material = StentMaterial::nitinol;
            attribute :>> wireThickness = 0.35 [mm];
            attribute :>> meshDensity = 0.65;
            attribute :>> radialForce = 9.0 [N];
        }
        
        part covering : StentCovering {
            attribute :>> coverageType = "partial silicone";
            attribute :>> permeability = 0.15;
            attribute :>> biocompatibility = 0.97;
        }
        
        part proximalFlange : ProximalFlange {
            attribute :>> flareDiameter = 24.0 [mm];
            attribute :>> flareAngle = 18.0 [deg];
        }
        
        part distalFlange : DistalFlange {
            attribute :>> flareDiameter = 24.0 [mm];
            attribute :>> flareAngle = 18.0 [deg];
        }
        
        part lumen : LumenChannel {
            attribute :>> innerDiameter = 18.0 [mm];
            attribute :>> effectiveLength = 95.0 [mm];
        }
        
        port tissueContact : TissueInterfacePort;
        port foodPassage : LumenPort;
        port deploymentInterface : DeploymentPort;
        
        connect proximalFlange.migrationResistance to tissueContact;
        connect distalFlange.anchoringInterface to tissueContact;
        bind foodPassage = lumen.proximalOpening;
    }
    
    part def Esophagus {
        attribute normalDiameter : StentDiameter;
        attribute peristalticForce : ForceValue;
        
        part tissue : EsophagealTissue {
            attribute :>> nativeDiameter = 20.0 [mm];
            attribute :>> strictureLocation = 280.0 [mm];
            attribute :>> strictureSeverity = 0.80;
            attribute :>> compressionForce = 12.0 [N];
        }
        
        port lumenInterface : LumenPort;
        port wallInterface : TissueInterfacePort;
    }
    
    action def DeployStent {
        in deliverySystem : DeliverySystem;
        in targetLocation : LengthValue;
        in targetDiameter : StentDiameter;
        out deployedStent : EsophagealStent;
        out deploymentSuccess : Boolean;
        
        first start;
        then action positionCatheter {
            in location = targetLocation;
            out positioned : Boolean;
        }
        then action releaseConstraint {
            out stentReleased : Boolean;
        }
        then action expandStent {
            in targetDiam = targetDiameter;
            out currentDiameter : StentDiameter;
            out expansionComplete : Boolean;
        }
        then action verifyPlacement {
            in diameter = expandStent.currentDiameter;
            out verified : Boolean;
        }
        then assign deploymentSuccess := verifyPlacement.verified;
        then done;
    }
    
    action def MaintainPatency {
        in stent : EsophagealStent;
        in esophagus : Esophagus;
        out lumenOpen : Boolean;
        out currentDiameter : StentDiameter;
        
        first start;
        then merge monitoringLoop;
        then action assessLumen {
            in stentDiameter : StentDiameter;
            in tissueForce : ForceValue;
            out isPatent : Boolean;
            out effectiveDiameter : StentDiameter;
        }
        then decide;
            if assessLumen.isPatent then sustainExpansion;
            if not assessLumen.isPatent then handleOcclusion;
        
        action sustainExpansion {
            in radialForce : RadialForce;
            out stabilizedDiameter : StentDiameter;
        }
        then assign currentDiameter := sustainExpansion.stabilizedDiameter;
        then monitoringLoop;
        
        action handleOcclusion {
            in occlusionType : String;
            out interventionNeeded : Boolean;
        }
        then assign lumenOpen := false;
        then done;
    }
    
    action def FacilitateSwallowing {
        in foodBolus : FoodBolus;
        in stentLumen : LumenChannel;
        out passageComplete : Boolean;
        out transitTime : TimeValue;
        
        first start;
        then action receiveBolus {
            in bolus = foodBolus;
            out bolusEntered : Boolean;
        }
        then action conductBolus {
            in lumenDiameter : StentDiameter;
            in bolusVolume : VolumeValue;
            out flowRate : FlowRate;
        }
        then action exitBolus {
            in flow = conductBolus.flowRate;
            out bolusExited : Boolean;
        }
        then assign passageComplete := exitBolus.bolusExited;
        then done;
    }
    
    attribute def DeploymentInitiated;
    attribute def MigrationDetected;
    attribute def OcclusionDetected;
    
    state def StentLifecycle {
        in stent : EsophagealStent;
        
        entry; then compressed;
        
        state compressed {
            entry assign stent.currentStatus := StentStatus::compressed;
        }
        
        transition compressed_to_deploying
            first compressed
            accept DeploymentInitiated
            then deploying;
        
        state deploying {
            entry assign stent.currentStatus := StentStatus::deploying;
            do action expandMesh {
                in radialForce : RadialForce;
                out expansionProgress : Real;
            }
        }
        
        transition deploying_to_expanded
            first deploying
            if stent.deploymentProgress >= 0.95
            then fully_expanded;
        
        state fully_expanded {
            entry assign stent.currentStatus := StentStatus::fully_expanded;
        }
        
        transition expanded_to_patent
            first fully_expanded
            if stent.lumen.innerDiameter >= 15.0 [mm]
            then patent;
        
        state patent {
            entry assign stent.currentStatus := StentStatus::patent;
        }
        
        transition patent_to_migrated
            first patent
            accept MigrationDetected
            then migrated;
        
        transition patent_to_occluded
            first patent
            accept OcclusionDetected
            then occluded;
        
        state migrated {
            entry assign stent.currentStatus := StentStatus::migrated;
        }
        
        state occluded {
            entry assign stent.currentStatus := StentStatus::occluded;
        }
    }
    
    requirement def FunctionalRequirements {
        doc /* Core functional requirements for esophageal stent system */
        subject stent : EsophagealStent;
        
        requirement <'FR-1'> maintainLumenPatency {
            doc /* The stent shall maintain minimum esophageal lumen diameter to enable swallowing */
            
            require constraint {
                stent.lumen.innerDiameter >= 15.0 [mm]
            }
        }
        
        requirement <'FR-2'> provideRadialForce {
            doc /* The stent shall provide sufficient radial force to resist stricture compression */
            
            require constraint {
                stent.mesh.radialForce >= 6.0 [N] and stent.mesh.radialForce <= 12.0 [N]
            }
        }
        
        requirement <'FR-3'> preventMigration {
            doc /* The stent shall resist axial migration through flange anchoring */
            
            require constraint {
                stent.proximalFlange.flareDiameter >= stent.nominalDiameter * 1.15 and
                stent.distalFlange.flareDiameter >= stent.nominalDiameter * 1.15
            }
        }
        
        requirement <'FR-4'> allowBolusPas {
            doc /* The stent shall permit passage of food bolus with minimal resistance */
            
            require constraint {
                stent.lumen.effectiveLength >= 60.0 [mm] and
                stent.lumen.effectiveLength <= 150.0 [mm]
            }
        }
    }
    
    requirement def SafetyRequirements {
        doc /* Safety and biocompatibility requirements */
        subject stent : EsophagealStent;
        
        requirement <'SR-1'> biocompatibility {
            doc /* Stent materials shall be biocompatible to minimize adverse tissue reaction */
            
            require constraint {
                stent.covering.biocompatibility >= 0.95
            }
        }
        
        requirement <'SR-2'> preventPerforation {
            doc /* The stent shall not perforate esophageal tissue during deployment or use */
            
            require constraint {
                stent.mesh.radialForce <= 12.0 [N] and
                stent.mesh.wireThickness <= 0.40 [mm]
            }
        }
        
        requirement <'SR-3'> limitMigration {
            doc /* Axial migration shall be limited to prevent displacement from target site */
            
            require constraint {
                stent.proximalFlange.flareAngle >= 15.0 [deg] and
                stent.distalFlange.flareAngle >= 15.0 [deg]
            }
        }
    }
    
    requirement systemMission {
        doc /* 
            Primary mission: Restore and maintain esophageal patency in patients with 
            malignant or benign strictures by providing continuous radial support.
        */
        
        subject stentSystem : EsophagealStent;
        subject targetEsophagus : Esophagus;
        
        assume constraint patientHasStricture {
            doc /* Patient presents with esophageal stricture causing dysphagia */
            targetEsophagus.tissue.strictureSeverity >= 0.50
        }
        
        require functionalReqs : FunctionalRequirements {
            subject stent = stentSystem;
        }
        require safetyReqs : SafetyRequirements {
            subject stent = stentSystem;
        }
    }
    
    part esophagealStentSystem {
        doc /* 
            Complete esophageal stent system for treating esophageal strictures and obstructions.
            
            Primary Function: Maintain esophageal patency by providing continuous radial support
            to the esophageal wall, creating and sustaining an open lumen that enables passage
            of food and liquids from the pharynx to the stomach. The stent counteracts stricture
            forces through chronic outward radial expansion while resisting migration through
            proximal and distal flange anchoring mechanisms.
        */
        
        part stent : EsophagealStent {
            attribute :>> nominalDiameter = 20.0 [mm];
            attribute :>> nominalLength = 100.0 [mm];
            attribute :>> currentStatus = StentStatus::compressed;
            attribute :>> deploymentProgress = 0.0;
            
            exhibit state lifecycle : StentLifecycle {
                in stent = esophagealStentSystem.stent;
            }
        }
        
        part targetEsophagus : Esophagus {
            attribute :>> normalDiameter = 22.0 [mm];
            attribute :>> peristalticForce = 3.5 [N];
        }
        
        part delivery : DeliverySystem {
            attribute :>> catheterDiameter = 7.5 [mm];
            attribute :>> workingLength = 850.0 [mm];
        }
        
        perform action operateStent {
            first start;
            then action deployment : DeployStent {
                in deliverySystem = delivery;
                in targetLocation = targetEsophagus.tissue.strictureLocation;
                in targetDiameter = stent.nominalDiameter;
                out deployedStent;
                out deploymentSuccess;
            }
            then action maintainFunction : MaintainPatency {
                in stent = stent;
                in esophagus = targetEsophagus;
                out lumenOpen;
                out currentDiameter;
            }
            then action facilitatePassage : FacilitateSwallowing[*] {
                in stentLumen = stent.lumen;
                out passageComplete;
                out transitTime;
            }
        }
        
        connection stentToTissue connect stent.tissueContact to targetEsophagus.wallInterface;
        connection foodPathway connect targetEsophagus.lumenInterface to stent.foodPassage;
        connection deploymentControl connect delivery.deliveryControl to stent.deploymentInterface;
        
        satisfy systemMission {
            subject stentSystem = stent;
            subject targetEsophagus = targetEsophagus;
        }
    }
}
