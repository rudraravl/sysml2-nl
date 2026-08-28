package EsophagealStentSystem {
	import ScalarValues::*;
	import ISQ::*;

	value def RadialForce :> Real { unit 'N'; }
	value def Diameter :> Real { unit 'mm'; }
	value def Length :> Real { unit 'mm'; }
	value def Pressure :> Real { unit 'kPa'; }
	value def Force :> Real { unit 'N'; }
	value def Temperature :> Real { unit 'K'; }
	value def TimeValue :> Real { unit 's'; }

	item def FoodBolus {
		attribute consistency : String;
		attribute volume : Real { unit 'mL'; }
	}
	item def TissuePressureItem {
		attribute magnitude : Pressure;
	}
	item def MigrationForceItem {
		attribute magnitude : Force;
	}
	item def OcclusionItem {
		attribute cause : String;
	}

	enum def StentOperationalState {
		compressed = 0,
		deploying = 1,
		fullyExpanded = 2,
		patent = 3,
		migrated = 4,
		occluded = 5
	}

	enum def FlangeLocation {
		proximal = 0,
		distal = 1
	}

	requirement def StentFunctionalRequirement {
		doc "The esophageal stent shall maintain esophageal patency by exerting continuous outward radial force against diseased tissue, restoring the patient's ability to swallow food and liquids."
		subject stent : EsophagealStent;
		objective {
			doc "Restore swallowing ability and maintain lumen patency."
		}
		require stent.radialForce >= 2.0 [N];
		require stent.lumenDiameter >= 16.0 [mm];
		require stent.totalLength >= 100.0 [mm];
	}

	requirement def BiocompatibilityRequirement {
		doc "The stent covering shall be biocompatible and prevent tissue ingrowth through the mesh."
		subject stent : EsophagealStent;
		require stent.covering.material == "Silicone";
		require stent.covering.coverageType == "Full";
	}

	requirement def AntiMigrationRequirement {
		doc "The proximal and distal flanges shall anchor the stent against the esophageal wall to prevent migration."
		subject stent : EsophagealStent;
		require stent.proximalFlange.flangeDiameter >= 22.0 [mm];
		require stent.distalFlange.flangeDiameter >= 22.0 [mm];
	}

	requirement def DeliverySystemRequirement {
		doc "The delivery system shall compress, transport, and release the stent at the stricture site."
		subject deliverySystem : DeliverySystem;
		require deliverySystem.catheter.compressedDiameter <= 4.0 [mm];
		require deliverySystem.catheter.catheterLength >= 600.0 [mm];
	}

	part def StentMesh {
		attribute material : String = "Nitinol";
		attribute meshLength : Length = 120.0 [mm];
		attribute expandedDiameter : Diameter = 18.0 [mm];
		attribute compressedDiameter : Diameter = 3.0 [mm];
		attribute radialForce : RadialForce = 3.5 [N];
		attribute flexibility : Real = 0.85;
		port tissueInterface : ~ * ;
		port lumenInterface : ~ * ;
	}

	part def StentCovering {
		attribute material : String = "Silicone";
		attribute coverageType : String = "Full";
		attribute thickness : Length = 0.1 [mm];
		attribute biocompatible : Boolean = true;
		port meshInterface : ~ * ;
		port lumenInterface : ~ * ;
	}

	part def StentFlange {
		attribute location : FlangeLocation;
		attribute flangeDiameter : Diameter = 24.0 [mm];
		attribute flangeLength : Length = 10.0 [mm];
		attribute anchorForce : Force = 1.2 [N];
		port wallContactPort : ~ * ;
	}

	part def LumenChannel {
		attribute nominalDiameter : Diameter = 18.0 [mm];
		attribute channelLength : Length = 120.0 [mm];
		attribute surfaceFriction : Real = 0.05;
		in item bolusIn : FoodBolus;
		out item bolusOut : FoodBolus;
		port proximalOpening : ~ * ;
		port distalOpening : ~ * ;
	}

	part def EsophagealStent {
		attribute stentState : StentOperationalState = StentOperationalState::compressed;
		attribute lumenDiameter : Diameter = 18.0 [mm];
		attribute radialForce : RadialForce = 3.5 [N];
		attribute flangeDiameter : Diameter = 24.0 [mm];
		attribute totalLength : Length = 140.0 [mm];
		attribute deployed : Boolean = false;

		part mesh : StentMesh;
		part covering : StentCovering;
		part proximalFlange : StentFlange { :>> location = FlangeLocation::proximal; }
		part distalFlange : StentFlange { :>> location = FlangeLocation::distal; }
		part lumen : LumenChannel;

		port proximalEnd : ~ * ;
		port distalEnd : ~ * ;
		port esophagealWallInterface : ~ * ;
		port deliveryInterface : ~ * ;

		flow of TissuePressureItem from esophagealWallInterface to mesh.tissueInterface;
		flow of FoodBolus from proximalEnd to lumen.proximalOpening;
		flow of FoodBolus from lumen.distalOpening to distalEnd;

		connection meshCoveringConnection connect mesh.lumenInterface to covering.meshInterface;
		connection lumenMeshConnection connect lumen to mesh.lumenInterface;

		exhibit state def StentLifecycle {
			entry action assignCompressed { stentState := StentOperationalState::compressed; }
			then compressed;

			state compressed {
				doc "Stent is loaded and constrained within the delivery catheter."
				entry action setCompressed { lumenDiameter := 3.0 [mm]; radialForce := 0.0 [N]; }
			}

			state deploying {
				doc "Stent is released from the catheter and expanding outward."
				entry action setDeploying { stentState := StentOperationalState::deploying; }
				do action expand {
					lumenDiameter := lumenDiameter + 1.5 [mm];
					radialForce := radialForce + 0.5 [N];
				}
			}

			state fullyExpanded {
				doc "Stent has reached its intended diameter and is pressing against the esophageal wall."
				entry action setExpanded {
					stentState := StentOperationalState::fullyExpanded;
					lumenDiameter := 18.0 [mm];
					radialForce := 3.5 [N];
					deployed := true;
				}
			}

			state patent {
				doc "Lumen is open and clear; food bolus can pass from throat to stomach."
				entry action setPatent { stentState := StentOperationalState::patent; }
			}

			state migrated {
				doc "Stent has moved from its original deployment position."
				entry action setMigrated { stentState := StentOperationalState::migrated; }
			}

			state occluded {
				doc "Lumen has become blocked, preventing passage of food bolus."
				entry action setOccluded { stentState := StentOperationalState::occluded; }
			}

			transition from compressed to deploying
				when deliveryInterface.releaseSignal == true
				accept ReleaseStent;

			transition from deploying to fullyExpanded
				when lumenDiameter >= 18.0 [mm] and radialForce >= 3.5 [N];

			transition from fullyExpanded to patent
				when deployed == true and lumenDiameter >= 16.0 [mm];

			transition from patent to migrated
				when esophagealWallInterface.migrationForce > proximalFlange.anchorForce + distalFlange.anchorForce;

			transition from patent to occluded
				when lumen.proximalOpening.blocked == true or lumen.distalOpening.blocked == true;
		}

		satisfy stentFunctionalReq : StentFunctionalRequirement by stent;
		satisfy antiMigrationReq : AntiMigrationRequirement by stent;
		satisfy biocompatibilityReq : BiocompatibilityRequirement by stent;
	}

	part def DeliveryCatheter {
		attribute catheterLength : Length = 800.0 [mm];
		attribute catheterDiameter : Diameter = 3.5 [mm];
		attribute compressedDiameter : Diameter = 3.0 [mm];
		attribute loaded : Boolean = true;
		attribute releaseSignal : Boolean = false;
		port distalTip : ~ * ;
		port proximalHub : ~ * ;
		port releaseControl : ~ * ;
		port stentBay : ~ * ;
		part loadedStent : EsophagealStent;
	}

	part def DeliverySystem {
		attribute deploymentForce : Force = 5.0 [N];
		attribute maxPushDistance : Length = 800.0 [mm];
		part catheter : DeliveryCatheter;
		port physicianInterface : ~ * ;
		port patientInterface : ~ * ;

		action def LoadStent {
			in stent : EsophagealStent;
			out catheter : DeliveryCatheter;
			start;
			action compressStent {
				stent.stentState := StentOperationalState::compressed;
				stent.lumenDiameter := 3.0 [mm];
			}
			then action insertIntoCatheter {
				catheter.loadedStent := stent;
				catheter.loaded := true;
			}
			done;
		}

		action def NavigateToStricture {
			inout catheter : DeliveryCatheter;
			start;
			action advanceCatheter;
			then action positionDistalTip;
			done;
		}

		action def DeployStent {
			inout catheter : DeliveryCatheter;
			out stent : EsophagealStent;
			start;
			action activateRelease {
				catheter.releaseSignal := true;
			}
			then action releaseStent {
				stent := catheter.loadedStent;
				stent.stentState := StentOperationalState::deploying;
				catheter.loaded := false;
			}
			done;
		}

		perform load : LoadStent;
		perform navigate : NavigateToStricture;
		perform deploy : DeployStent;

		satisfy deliveryReq : DeliverySystemRequirement by deliverySystem;
	}

	part def Esophagus {
		attribute strictureLocation : Length = 250.0 [mm];
		attribute strictureDiameter : Diameter = 5.0 [mm];
		attribute healthyDiameter : Diameter = 20.0 [mm];
		attribute wallElasticity : Real = 0.4;
		port throatEnd : ~ * ;
		port stomachEnd : ~ * ;
		port strictureSite : ~ * ;
		in item incomingBolus : FoodBolus;
		out item outgoingBolus : FoodBolus;
	}

	part def Patient {
		attribute bodyTemperature : Temperature = 310.15 [K];
		attribute hasStricture : Boolean = true;
		part esophagus : Esophagus;
	}

	part def EsophagealStentSystem {
		part stent : EsophagealStent;
		part deliverySystem : DeliverySystem;
		part patient : Patient;

		connection stentLoading connect stent.deliveryInterface to deliverySystem.catheter.stentBay;
		connection stentPlacement connect stent.esophagealWallInterface to patient.esophagus.strictureSite;
		connection bolusPath connect patient.esophagus.throatEnd to stent.proximalEnd;
		connection bolusExit connect stent.distalEnd to patient.esophagus.stomachEnd;

		requirement stentFunctional : StentFunctionalRequirement;
		requirement antiMigration : AntiMigrationRequirement;
		requirement biocompatibility : BiocompatibilityRequirement;
		requirement deliverySystemReq : DeliverySystemRequirement;
	}
}
