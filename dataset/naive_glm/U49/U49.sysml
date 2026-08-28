package CoronaryStentSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQForce::*;
    import ISQPressure::*;
    import ISQTime::*;
    import ISQMass::*;

    attribute def LengthUnit :> Real {
        unit mm;
    }
    attribute def DiameterUnit :> Real {
        unit mm;
    }
    attribute def PressureUnit :> Real {
        unit atm;
    }
    attribute def TimeUnit :> Real {
        unit day;
    }
    attribute def ForceUnit :> Real {
        unit N;
    }
    attribute def MassUnit :> Real {
        unit ug;
    }

    item def StentMaterial {
        attribute name : String;
        attribute yieldStrength : ForceUnit;
    }
    item def CobaltChromium :> StentMaterial {
        restructure name = "CoCr";
        attribute yieldStrength := 600 [N];
    }
    item def PlatinumChromium :> StentMaterial {
        restructure name = "PtCr";
        attribute yieldStrength := 650 [N];
    }

    item def Drug {
        attribute name : String;
        attribute releaseDuration : TimeUnit;
        attribute totalDose : MassUnit;
    }
    item def Everolimus :> Drug {
        restructure name = "Everolimus";
        attribute releaseDuration := 180 [day];
        attribute totalDose := 100 [ug];
    }

    item def Blood {
        attribute viscosity : Real;
        attribute flowRate : Real;
    }

    item def Plaque {
        attribute composition : String;
        attribute occlusionPercentage : Real;
    }

    port def BloodFlowPort {
        out blood : Blood;
    }

    port def PressurePort {
        in pressure : PressureUnit;
    }

    port def MechanicalInterfacePort {
        in radialForce : ForceUnit;
    }

    attribute def StentGeometry {
        attribute collapsedDiameter : DiameterUnit;
        attribute expandedDiameter : DiameterUnit;
        attribute length : LengthUnit;
        attribute strutThickness : LengthUnit;
    }

    part def DrugElutingStent {
        attribute material : StentMaterial;
        attribute geometry : StentGeometry;
        attribute drugCoating : Drug;
        attribute radialStrength : ForceUnit;
        attribute isExpanded : Boolean := false;
        attribute isDeployed : Boolean := false;

        port mechanicalInterface : MechanicalInterfacePort;
        port bloodFlow : BloodFlowPort;

        exhibit state def DeploymentLifecycle {
            entry action init { 
                send isExpanded = false; 
                send isDeployed = false; 
            }
            state Collapsed;
            state Expanding;
            state Deployed;
            state DrugReleasing;
            state FullyReleased;

            transition from Collapsed to Expanding 
                when mechanicalInterface.radialForce > 0 [N];
            transition from Expanding to Deployed 
                when geometry.expandedDiameter >= 3.0 [mm];
            transition from Deployed to DrugReleasing 
                when isDeployed == true;
            transition from DrugReleasing to FullyReleased 
                when drugCoating.releaseDuration >= 180 [day];
        }

        action def ExpandStent {
            in pressure : PressureUnit;
            out expandedDiameter : DiameterUnit;
            
            perform action applyForce {
                in p = pressure;
            }
            perform action deformMesh {
                in p = pressure;
                out d : DiameterUnit = 3.0 [mm];
            }
            then assign isExpanded = true;
            then assign geometry.expandedDiameter = deformMesh.d;
        }

        action def ReleaseDrug {
            in duration : TimeUnit;
            out releasedDose : MassUnit;
            
            perform action elute {
                in d = duration;
                out dose : MassUnit = drugCoating.totalDose;
            }
        }
    }

    part def BalloonCatheter {
        attribute catheterLength : LengthUnit;
        attribute balloonDiameter : DiameterUnit;
        attribute balloonPressure : PressureUnit := 0 [atm];
        attribute isBalloonInflated : Boolean := false;
        attribute stentMounted : Boolean := false;

        port pressurePort : PressurePort;
        port distalEnd : MechanicalInterfacePort;

        exhibit state def CatheterOperation {
            entry action init { 
                send isBalloonInflated = false; 
            }
            state Ready;
            state Navigating;
            state Positioned;
            state Inflating;
            state Deflating;
            state Withdrawn;

            transition from Ready to Navigating 
                when stentMounted == true;
            transition from Navigating to Positioned 
                when catheterLength <= 1400 [mm];
            transition from Positioned to Inflating 
                when balloonPressure >= 8 [atm];
            transition from Inflating to Deflating 
                when balloonPressure <= 14 [atm] & balloonPressure >= 12 [atm];
            transition from Deflating to Withdrawn 
                when balloonPressure == 0 [atm];
        }

        action def InflateBalloon {
            in targetPressure : PressureUnit;
            out achievedPressure : PressureUnit;
            
            perform action pressurize {
                in tp = targetPressure;
                out ap : PressureUnit = tp;
            }
            then assign balloonPressure = pressurize.ap;
            then assign isBalloonInflated = true;
        }

        action def DeflateBalloon {
            out finalPressure : PressureUnit;
            
            perform action depressurize {
                out fp : PressureUnit = 0 [atm];
            }
            then assign balloonPressure = depressurize.fp;
            then assign isBalloonInflated = false;
        }

        action def NavigateToLesion {
            in pathLength : LengthUnit;
            out positionReached : Boolean;
            
            perform action advance {
                in pl = pathLength;
                out pr : Boolean = true;
            }
        }
    }

    part def CoronaryArtery {
        attribute vesselDiameter : DiameterUnit;
        attribute vesselLength : LengthUnit;
        attribute plaque : Plaque;
        attribute bloodFlowRestored : Boolean := false;

        port proximalFlow : BloodFlowPort;
        port distalFlow : BloodFlowPort;
        port lesionSite : MechanicalInterfacePort;

        exhibit state def ArteryState {
            state Occluded;
            state Stented;
            state Patent;
            transition from Occluded to Stented 
                when lesionSite.radialForce > 0 [N];
            transition from Stented to Patent 
                when bloodFlowRestored == true;
        }
    }

    part def Patient {
        attribute patientId : String;
        part coronaryArtery : CoronaryArtery {
            restructure vesselDiameter := 3.0 [mm];
            restructure vesselLength := 20 [mm];
            restructure plaque.composition := "Atheromatous";
            restructure plaque.occlusionPercentage := 75;
        }
    }

    part def DrugElutingCoronaryStentSystem {
        part stent : DrugElutingStent {
            restructure material := CobaltChromium{};
            restructure geometry.collapsedDiameter := 1.5 [mm];
            restructure geometry.expandedDiameter := 3.0 [mm];
            restructure geometry.length := 18 [mm];
            restructure geometry.strutThickness := 0.08 [mm];
            restructure drugCoating := Everolimus{};
            restructure radialStrength := 1.2 [N];
        }

        part catheter : BalloonCatheter {
            restructure catheterLength := 1400 [mm];
            restructure balloonDiameter := 3.0 [mm];
        }

        part patient : Patient;

        connection def PressureConnection {
            end source : PressurePort;
            end target : PressurePort;
        }

        connection def MechanicalConnection {
            end source : MechanicalInterfacePort;
            end target : MechanicalInterfacePort;
        }

        connection def BloodFlowConnection {
            end source : BloodFlowPort;
            end target : BloodFlowPort;
        }

        connection pressureLink : PressureConnection 
            connect catheter.pressurePort to stent.mechanicalInterface;
        connection stentArteryInterface : MechanicalConnection 
            connect stent.mechanicalInterface to patient.coronaryArtery.lesionSite;
        connection catheterStentMount : MechanicalConnection 
            connect catheter.distalEnd to stent.mechanicalInterface;
        connection proximalBloodFlow : BloodFlowConnection 
            connect patient.coronaryArtery.proximalFlow to stent.bloodFlow;
        connection distalBloodFlow : BloodFlowConnection 
            connect stent.bloodFlow to patient.coronaryArtery.distalFlow;

        action def StentImplantationProcedure {
            in patientRef : Patient;
            in stentRef : DrugElutingStent;
            in catheterRef : BalloonCatheter;

            perform action mountStent {
                in s = stentRef;
                in c = catheterRef;
                then assign c.stentMounted = true;
            }
            perform action navigate {
                in c = catheterRef;
                in p = patientRef;
                then perform c.NavigateToLesion(pathLength = 1400 [mm]);
            }
            perform action inflate {
                in c = catheterRef;
                then perform c.InflateBalloon(targetPressure = 12 [atm]);
            }
            perform action expandStent {
                in s = stentRef;
                in pressure : PressureUnit = 12 [atm];
                then perform s.ExpandStent(pressure = pressure);
                then assign s.isDeployed = true;
            }
            perform action compressPlaque {
                in artery = patientRef.coronaryArtery;
                then assign artery.plaque.occlusionPercentage = 10;
            }
            perform action deflate {
                in c = catheterRef;
                then perform c.DeflateBalloon();
            }
            perform action withdraw {
                in c = catheterRef;
                then assign c.stentMounted = false;
            }
            perform action restoreFlow {
                in artery = patientRef.coronaryArtery;
                then assign artery.bloodFlowRestored = true;
            }

            flow from mountStent to navigate;
            flow from navigate to inflate;
            flow from inflate to expandStent;
            flow from expandStent to compressPlaque;
            flow from compressPlaque to deflate;
            flow from deflate to withdraw;
            flow from withdraw to restoreFlow;
        }

        requirement def RestoresBloodFlow {
            subject system : DrugElutingCoronaryStentSystem;
            objective {
                doc "The system shall restore and maintain blood flow to the heart muscle."
            }
            require system.patient.coronaryArtery.bloodFlowRestored == true;
        }

        requirement def DrugReleaseDuration {
            subject stentPart : DrugElutingStent;
            objective {
                doc "The stent drug coating shall release medication over at least 180 days."
            }
            require stentPart.drugCoating.releaseDuration >= 180 [day];
        }

        requirement def RadialStrengthRequirement {
            subject stentPart : DrugElutingStent;
            objective {
                doc "The stent shall exert sufficient radial force to hold the artery open."
            }
            require stentPart.radialStrength >= 1.0 [N];
        }

        requirement def BalloonInflationPressure {
            subject catheterPart : BalloonCatheter;
            objective {
                doc "The balloon shall inflate to a precise pressure between 8 and 14 atm."
            }
            require catheterPart.balloonPressure >= 8 [atm] & catheterPart.balloonPressure <= 14 [atm];
        }

        requirement def BiocompatibleMaterial {
            subject stentPart : DrugElutingStent;
            objective {
                doc "The stent shall be constructed from Cobalt-Chromium or Platinum-Chromium."
            }
            require stentPart.material == CobaltChromium{} | stentPart.material == PlatinumChromium{};
        }

        requirement def StentDeployment {
            subject system : DrugElutingCoronaryStentSystem;
            objective {
                doc "After deployment, the stent shall remain as a permanent scaffold."
            }
            require system.stent.isDeployed == true;
            require system.catheter.stentMounted == false;
        }

        requirement def StentImplantationSatisfiesFlow :> RestoresBloodFlow {
            subject system : DrugElutingCoronaryStentSystem;
            require system.patient.coronaryArtery.plaque.occlusionPercentage <= 20;
        }

        satisfy restoresBloodFlowReq : RestoresBloodFlow by system;
        satisfy drugReleaseReq : DrugReleaseDuration by stent;
        satisfy radialStrengthReq : RadialStrengthRequirement by stent;
        satisfy balloonPressureReq : BalloonInflationPressure by catheter;
        satisfy materialReq : BiocompatibleMaterial by stent;
        satisfy deploymentReq : StentDeployment by system;
    }
}
