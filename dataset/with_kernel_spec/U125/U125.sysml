package SurgicalMeshSystem {
	private import ScalarValues::Real;
	private import ISQ::*;
	private import SI::*;
	public import Definitions::*;

	package Definitions {
		enum def MaterialType {
			synthetic;
			biological;
			composite;
		}

		enum def Absorbability {
			absorbable;
			permanent;
		}

		attribute def BiocompatibilityScoreValue :> Real;

		item def BiologicalCell;
		item def Tissue;
		item def IntegratedTissue :> Tissue;

		port def MechanicalLoadPort;
		port def BiologicalIntegrationPort;

		interface def MeshTissueMechanicalInterface {
			end meshMechPort : MechanicalLoadPort;
			end tissueMechPort : MechanicalLoadPort;
		}

		interface def MeshTissueBiologicalInterface {
			end meshBioPort : BiologicalIntegrationPort;
			end tissueBioPort : BiologicalIntegrationPort;
		}

		action def ProvideReinforcement;
		action def DistributeMechanicalLoad;
		action def PromoteTissueIntegration;

		attribute def PlacementCompleteSignal;
		attribute def CellsInvadingSignal;
		attribute def TissueMaturedSignal;
		attribute def IntegrationCompleteSignal;

		state def HealingLifecycle;

		part def SurgicalMesh {
			doc /* A specialized medical implant for reinforcing weakened or damaged biological tissue. */
			attribute materialType : MaterialType;
			attribute tensileStrength : ForceValue;
			attribute poreSize : LengthValue;
			attribute biocompatibilityScore : BiocompatibilityScoreValue;
			attribute absorbability : Absorbability;
			port mechanicalPort : MechanicalLoadPort;
			port biologicalPort : BiologicalIntegrationPort;
		}

		part def SurroundingTissue {
			doc /* The biological tissue surrounding and interacting with the implanted mesh. */
			attribute exertedForce : ForceValue;
			port mechanicalPort : MechanicalLoadPort;
			port biologicalPort : BiologicalIntegrationPort;
		}

		part def SurgicalMeshSystem {
			doc /* A system consisting of a surgical mesh implant and the surrounding biological tissue. */
			part surgicalMesh : SurgicalMesh;
			part surroundingTissue : SurroundingTissue;
			interface mechanicalInterface : MeshTissueMechanicalInterface
				connect surgicalMesh.mechanicalPort to surroundingTissue.mechanicalPort;
			interface biologicalInterface : MeshTissueBiologicalInterface
				connect surgicalMesh.biologicalPort to surroundingTissue.biologicalPort;
		}
	}

	package Usages {
		public import Definitions::*;

		action provideReinforcement : ProvideReinforcement {
			action distributeMechanicalLoad : DistributeMechanicalLoad {
				in loadFromTissue : ForceValue;
				out distributedLoad : ForceValue;
			}
			action promoteTissueIntegration : PromoteTissueIntegration {
				in item invadingCells : BiologicalCell;
				out item integratedTissue : IntegratedTissue;
			}
		}

		part surgicalMeshSystem : SurgicalMeshSystem {
			part :>> surgicalMesh : SurgicalMesh {
				attribute :>> materialType = MaterialType::composite;
				attribute :>> tensileStrength = 50 [N];
				attribute :>> poreSize = 0.8 [mm];
				attribute :>> biocompatibilityScore = 0.95;
				attribute :>> absorbability = Absorbability::permanent;
				port :>> mechanicalPort;
				port :>> biologicalPort;
				perform provideReinforcement;
			}

			part :>> surroundingTissue : SurroundingTissue {
				attribute :>> exertedForce = 10 [N];
				port :>> mechanicalPort;
				port :>> biologicalPort;
			}

			state healingLifecycle : HealingLifecycle {
				entry; then initialPlacement;
				state initialPlacement;
				accept PlacementCompleteSignal
					then earlyIntegration;
				state earlyIntegration;
				accept CellsInvadingSignal
					then tissueStabilization;
				state tissueStabilization;
				accept TissueMaturedSignal
					then fullIntegration;
				state fullIntegration;
				accept IntegrationCompleteSignal
					then healed;
				state healed;
			}
		}
	}

	package Requirements {
		public import Definitions::*;

		requirement def <'1'> StrengthRequirement {
			doc /* The surgical mesh tensile strength shall be sufficient to withstand physiological loads without failure. */
			attribute tensileStrengthActual : ForceValue;
			attribute tensileStrengthReqd : ForceValue;
			require constraint {
				tensileStrengthActual >= tensileStrengthReqd
			}
		}

		requirement def <'2'> BiocompatibilityRequirement {
			doc /* The surgical mesh shall exhibit biocompatibility to minimize adverse biological reactions. */
			attribute biocompatibilityScoreActual : BiocompatibilityScoreValue;
			attribute biocompatibilityScoreMin : BiocompatibilityScoreValue;
			require constraint {
				biocompatibilityScoreActual >= biocompatibilityScoreMin
			}
		}

		requirement def <'3'> PoreSizeRequirement {
			doc /* The surgical mesh pore size shall allow tissue ingrowth while maintaining mechanical integrity. */
			attribute poreSizeActual : LengthValue;
			attribute poreSizeMin : LengthValue;
			attribute poreSizeMax : LengthValue;
			require constraint {
				poreSizeActual >= poreSizeMin and poreSizeActual <= poreSizeMax
			}
		}

		requirement <'1.1'> meshStrength : StrengthRequirement {
			doc /* The mesh shall have a tensile strength of at least 30 N. */
			subject mesh : SurgicalMesh;
			attribute :>> tensileStrengthActual : ForceValue = mesh.tensileStrength;
			attribute :>> tensileStrengthReqd : ForceValue = 30 [N];
		}

		requirement <'2.1'> meshBiocompatibility : BiocompatibilityRequirement {
			doc /* The mesh shall have a biocompatibility score of at least 0.90. */
			subject mesh : SurgicalMesh;
			attribute :>> biocompatibilityScoreActual : BiocompatibilityScoreValue = mesh.biocompatibilityScore;
			attribute :>> biocompatibilityScoreMin : BiocompatibilityScoreValue = 0.90;
		}

		requirement <'3.1'> meshPoreSize : PoreSizeRequirement {
			doc /* The mesh pore size shall be between 0.1 mm and 2.0 mm. */
			subject mesh : SurgicalMesh;
			attribute :>> poreSizeActual : LengthValue = mesh.poreSize;
			attribute :>> poreSizeMin : LengthValue = 0.1 [mm];
			attribute :>> poreSizeMax : LengthValue = 2.0 [mm];
		}
	}
}
