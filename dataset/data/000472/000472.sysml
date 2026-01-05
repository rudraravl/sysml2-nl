package 'MERCI Retriever System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def ClotLocation {
        attribute vesselSegment : String;
        attribute distanceFromAccess : LengthValue;
    }

    attribute def TICIScore {
        attribute grade : Integer;
        attribute description : String;
    }

    attribute def NavigationCommand {
        attribute direction : String;
        attribute magnitude : Real;
    }

    attribute def DeploymentStatus {
        attribute deployed : Boolean;
        attribute expansionDiameter : LengthValue;
    }

    item def Thrombus {
        attribute mass : MassValue;
        attribute composition : String;
        attribute adherence : ForceValue;
    }

    port def VascularAccessPort {
        in attribute guidewirePosition : LengthValue;
        out attribute catheterPosition : LengthValue;
        in attribute bloodFlow : ISQ::VolumeFlowValue;
    }

    port def ImagingPort {
        out attribute fluoroscopyImage : String;
        out attribute vesselDiameter : LengthValue;
        out attribute flowVisualization : Boolean;
    }

    port def RetrievalPort {
        in attribute deployCommand : DeploymentStatus;
        out attribute clotCaptured : Boolean;
        out attribute retrievedMaterial : Thrombus;
    }

    part def GuideCatheter {
        attribute innerDiameter : LengthValue;
        attribute length : LengthValue;
        attribute tipShape : String;
        port proximalEnd : VascularAccessPort;
        port distalEnd : VascularAccessPort;
    }

    part def Microcatheter {
        attribute outerDiameter : LengthValue;
        attribute length : LengthValue;
        attribute trackability : ForceValue;
        port proximalEnd : VascularAccessPort;
        port distalEnd : VascularAccessPort;
    }

    part def MERCIRetrieverDevice {
        attribute helicalLoops : Integer;
        attribute filamentDiameter : LengthValue;
        attribute expansionDiameter : LengthValue;
        attribute radialForce : ForceValue;
        attribute deployed : Boolean;
        port shaft : VascularAccessPort;
        port retrieval : RetrievalPort;
    }

    part def AspirationPump {
        attribute maxSuction : PressureValue;
        attribute flowRate : ISQ::VolumeFlowValue;
        attribute active : Boolean;
    }

    part def FluoroscopySystem {
        attribute frameRate : Real;
        attribute resolution : LengthValue;
        port imaging : ImagingPort;
    }

    action def NavigateToOcclusion {
        in targetLocation : ClotLocation;
        in vesselDiameter : LengthValue;
        out navigationCommands : NavigationCommand[*];
        out positionReached : Boolean;
        out finalPosition : LengthValue;
    }

    action def DeployRetriever {
        in occlusionLocation : ClotLocation;
        in vesselDiameter : LengthValue;
        out deploymentStatus : DeploymentStatus;
        out retrieverExpanded : Boolean;
    }

    action def EngageThrombus {
        in retrieverDeployed : Boolean;
        in dwellTime : TimeValue;
        out clotEngaged : Boolean;
        out engagementForce : ForceValue;
    }

    action def WithdrawRetriever {
        in clotEngaged : Boolean;
        in aspirationActive : Boolean;
        out clotExtracted : Boolean;
        out retrievedClot : Thrombus;
    }

    action def AssessReperfusion {
        in postRetrievalFlow : ISQ::VolumeFlowValue;
        in baselineFlow : ISQ::VolumeFlowValue;
        out reperfusionScore : TICIScore;
        out reperfusionAchieved : Boolean;
    }

    action def PerformMechanicalThrombectomy {
        in targetOcclusion : ClotLocation;
        in baselineFlowRate : ISQ::VolumeFlowValue;
        in maxAttempts : Integer;
        out procedureSuccess : Boolean;
        out finalReperfusion : TICIScore;
        out retrievedClots : Thrombus[*];

        private attribute attemptCount : Integer := 0;
        private attribute reperfusionAchieved : Boolean := false;
        private attribute clotCollection : Thrombus[*] := ();

        first start;

        then action navigateToTarget : NavigateToOcclusion {
            in targetLocation = targetOcclusion;
            in vesselDiameter;
            out navigationCommands;
            out positionReached;
            out finalPosition;
        }

        then decide;
            if navigateToTarget.positionReached == true then initiateRetrieval;
            if navigateToTarget.positionReached == false then abortProcedure;

        action initiateRetrieval;
        then merge retrievalLoop;

        action retrievalLoop {
            first loopStart;
            then assign attemptCount := attemptCount + 1;

            then action deployDevice : DeployRetriever {
                in occlusionLocation = targetOcclusion;
                in vesselDiameter;
                out deploymentStatus;
                out retrieverExpanded;
            }

            then decide;
                if deployDevice.retrieverExpanded == true then engageClot;
                if deployDevice.retrieverExpanded == false then checkAttempts;

            action engageClot : EngageThrombus {
                in retrieverDeployed = deployDevice.retrieverExpanded;
                in dwellTime = 180.0 [SI::s];
                out clotEngaged;
                out engagementForce;
            }

            then action withdrawDevice : WithdrawRetriever {
                in clotEngaged = engageClot.clotEngaged;
                in aspirationActive = true;
                out clotExtracted;
                out retrievedClot;
            }

            then decide;
                if withdrawDevice.clotExtracted == true then storeClot;
                if withdrawDevice.clotExtracted == false then checkAttempts;

            action storeClot {
                then assign clotCollection := clotCollection->including(withdrawDevice.retrievedClot);
            }

            then action assessOutcome : AssessReperfusion {
                in postRetrievalFlow;
                in baselineFlow = baselineFlowRate;
                out reperfusionScore;
                out reperfusionAchieved;
            }

            then assign reperfusionAchieved := assessOutcome.reperfusionAchieved;
            then assign finalReperfusion := assessOutcome.reperfusionScore;

            then decide;
                if reperfusionAchieved == true then completeProcedure;
                if reperfusionAchieved == false then checkAttempts;

            action checkAttempts;
            then decide;
                if attemptCount < maxAttempts then retrievalLoop;
                if attemptCount >= maxAttempts then completeProcedure;

            action loopStart;
        }

        action completeProcedure {
            then assign procedureSuccess := reperfusionAchieved;
            then assign retrievedClots := clotCollection;
            then done;
        }

        action abortProcedure {
            then assign procedureSuccess := false;
            then done;
        }
    }

    part def MERCIThrombectomySystem;

    part merciThrombectomySystem : MERCIThrombectomySystem {
        doc /*
        The MERCI Retriever System is a mechanical thrombectomy device designed to 
        restore cerebral blood flow in patients experiencing acute ischemic stroke 
        caused by large vessel occlusion. Its primary function is to navigate through 
        the cerebrovascular system to the site of a thrombus, mechanically engage and 
        capture the clot using a helical retriever device, and extract it from the 
        vessel to achieve reperfusion of the affected brain tissue.
        
        The system operates through a coordinated sequence: vascular access is 
        established, a guide catheter and microcatheter are navigated to the occlusion 
        site under fluoroscopic guidance, the MERCI retriever is deployed beyond the 
        clot and expanded to engage it, and the device is withdrawn while aspiration 
        is applied to prevent distal embolization. The procedure may be repeated 
        multiple times until adequate reperfusion is achieved or the maximum number 
        of attempts is reached.
        */

        attribute systemIdentifier : String;
        attribute maxRetrievalAttempts : Integer;

        part guideCatheter : GuideCatheter {
            attribute innerDiameter = 2.4 [SI::mm];
            attribute length = 950.0 [SI::mm];
            attribute tipShape = "Angled";
        }

        part microcatheter : Microcatheter {
            attribute outerDiameter = 0.56 [SI::mm];
            attribute length = 1500.0 [SI::mm];
            attribute trackability = 0.15 [SI::N];
        }

        part retrieverDevice : MERCIRetrieverDevice {
            attribute helicalLoops = 5;
            attribute filamentDiameter = 0.15 [SI::mm];
            attribute expansionDiameter = 4.5 [SI::mm];
            attribute radialForce = 0.25 [SI::N];
            attribute deployed = false;
        }

        part aspirationSystem : AspirationPump {
            attribute maxSuction = -950.0 [SI::mbar];
            attribute flowRate = 60.0 [SI::ml/SI::s];
            attribute active = false;
        }

        part imagingSystem : FluoroscopySystem {
            attribute frameRate = 15.0;
            attribute resolution = 0.2 [SI::mm];
        }

        connection guideToMicro connect 
            guideCatheter.distalEnd to microcatheter.proximalEnd;

        connection microToRetriever connect 
            microcatheter.distalEnd to retrieverDevice.shaft;

        perform action thrombectomyProcedure : PerformMechanicalThrombectomy {
            in targetOcclusion;
            in baselineFlowRate;
            in maxAttempts = maxRetrievalAttempts;
            out procedureSuccess;
            out finalReperfusion;
            out retrievedClots;
        }
    }

    requirement def ReperfusionRequirement {
        doc /* The system shall achieve TICI 2b or greater reperfusion in target vessels. */
        
        require constraint {
            merciThrombectomySystem.thrombectomyProcedure.finalReperfusion.grade >= 2
        }
    }

    requirement def SafetyRequirement {
        doc /* The system shall minimize risk of vessel perforation during retrieval. */
        
        require constraint {
            merciThrombectomySystem.retrieverDevice.radialForce <= 0.3 [SI::N]
        }
    }

    requirement def NavigationRequirement {
        doc /* The system shall successfully navigate to occlusions in M1 and M2 segments. */
        
        require constraint {
            merciThrombectomySystem.microcatheter.trackability <= 0.2 [SI::N]
        }
    }

    requirement def TimeRequirement {
        doc /* The system shall complete each retrieval attempt within 10 minutes. */
    }

    requirement systemRequirements {
        doc /* Top-level requirements for the MERCI Retriever Thrombectomy System. */
        
        require reperfusion : ReperfusionRequirement;
        require safety : SafetyRequirement;
        require navigation : NavigationRequirement;
        require timing : TimeRequirement;
    }
}
