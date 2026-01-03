package 'Surgical Mesh System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MeshMaterial;
	attribute def TissueType;
	
	attribute def PoreSize :> ISQ::LengthValue;
	attribute def TensileStrength :> ISQ::ForceValue;
	attribute def Biocompatibility :> Real;
	attribute def IntegrationLevel :> Real;
	
	enum def MeshTypeEnum {
		enum synthetic;
		enum biological;
		enum composite;
	}
	
	enum def HealingStageEnum {
		enum initial;
		enum integration;
		enum stabilized;
		enum complete;
	}
	
	port def MechanicalInterface {
		out loadDistribution : ISQ::ForceValue;
		in tissueForces : ISQ::ForceValue;
	}
	
	port def BiologicalInterface {
		out cellIngrowthSupport : IntegrationLevel;
		in tissueResponse : IntegrationLevel;
	}
	
	port def TissueLoadPort {
		out appliedForce : ISQ::ForceValue;
		in supportForce : ISQ::ForceValue;
	}
	
	port def TissueResponsePort {
		out cellActivity : IntegrationLevel;
		in meshIntegration : IntegrationLevel;
	}
	
	item def SurgicalMesh {
		attribute meshType : MeshTypeEnum;
		attribute poreSize : PoreSize;
		attribute tensileStrength : TensileStrength;
		attribute biocompatibility : Biocompatibility;
		attribute isAbsorbable : Boolean;
		
		port mechanicalInterface : MechanicalInterface;
		port biologicalInterface : BiologicalInterface;
	}
	
	item def SurroundingTissue {
		attribute tissueType : TissueType;
		attribute healingStage : HealingStageEnum;
		attribute cellDensity : Real;
		
		port mechanicalLoad : TissueLoadPort;
		port biologicalResponse : TissueResponsePort;
	}
	
	part def ImplantationSite {
		part mesh : SurgicalMesh;
		part tissue : SurroundingTissue;
		
		connection mechanicalCoupling1 
			connect mesh.mechanicalInterface.tissueForces to tissue.mechanicalLoad.appliedForce;
		connection mechanicalCoupling2
			connect tissue.mechanicalLoad.supportForce to mesh.mechanicalInterface.loadDistribution;
		connection biologicalCoupling1
			connect mesh.biologicalInterface.cellIngrowthSupport to tissue.biologicalResponse.meshIntegration;
		connection biologicalCoupling2
			connect tissue.biologicalResponse.cellActivity to mesh.biologicalInterface.tissueResponse;
	}
	
	action def DistributeLoad {
		in incomingForce : ISQ::ForceValue;
		in meshStrength : TensileStrength;
		out distributedLoad : ISQ::ForceValue;
	}
	
	action def PromoteTissueIntegration {
		in poreSize : PoreSize;
		in biocompatibility : Biocompatibility;
		out cellIngrowthRate : IntegrationLevel;
	}
	
	action def MonitorHealing {
		in currentStage : HealingStageEnum;
		out integrationLevel : IntegrationLevel;
	}
	
	action def ProvideTissueReinforcement {
		in tissueDefectSize : ISQ::LengthValue;
		in appliedTension : ISQ::ForceValue;
		out reinforcementProvided : Boolean;
		
		first start;
		then merge continuousSupport;
		
		then action distributeLoad : DistributeLoad {
			in incomingForce = appliedTension;
			in meshStrength;
			out distributedLoad;
		}
		
		then action promoteIntegration : PromoteTissueIntegration {
			in poreSize;
			in biocompatibility;
			out cellIngrowthRate;
		}
		
		then action monitorHealing : MonitorHealing {
			in currentStage;
			out integrationLevel;
		}
		
		then decide;
			if monitorHealing.integrationLevel < 100.0 then continuousSupport;
			if monitorHealing.integrationLevel >= 100.0 then completeRepair;
		
		action completeRepair {
			assign reinforcementProvided := true;
		}
		then done;
	}
	
	state def MeshLifecycle {
		entry; then implanted;
		
		state implanted {
			entry assign currentStage := HealingStageEnum::initial;
		}
		then earlyIntegration;
		
		state earlyIntegration {
			entry assign currentStage := HealingStageEnum::integration;
		}
		then tissueStabilization;
		
		state tissueStabilization {
			entry assign currentStage := HealingStageEnum::stabilized;
		}
		then fullIntegration;
		
		state fullIntegration {
			entry assign currentStage := HealingStageEnum::complete;
		}
		then done;
		
		attribute currentStage : HealingStageEnum;
	}
	
	part surgicalMeshSystem : ImplantationSite {
		perform action tissueReinforcement : ProvideTissueReinforcement {
			in tissueDefectSize;
			in appliedTension;
			out reinforcementProvided;
		}
		
		exhibit state meshLifecycle : MeshLifecycle;
		
		part mesh : SurgicalMesh {
			:>> meshType = MeshTypeEnum::composite;
			:>> poreSize = 1.5 [SI::mm];
			:>> tensileStrength = 75.0 [SI::N];
			:>> biocompatibility = 0.96;
			:>> isAbsorbable = false;
			
			perform tissueReinforcement.distributeLoad;
			perform tissueReinforcement.promoteIntegration;
		}
		
		part tissue : SurroundingTissue {
			:>> tissueType;
			:>> healingStage = HealingStageEnum::initial;
			:>> cellDensity = 1000.0;
			
			exhibit meshLifecycle;
			perform tissueReinforcement.monitorHealing;
		}
	}
	
	requirement def MechanicalStrengthRequirement {
		doc /* The surgical mesh shall provide sufficient tensile strength 
		       to support tissue loads during healing without failure. */
		
		require constraint {
			surgicalMeshSystem.mesh.tensileStrength >= 50.0 [SI::N]
		}
	}
	
	requirement def BiocompatibilityRequirement {
		doc /* The surgical mesh shall exhibit high biocompatibility 
		       to minimize adverse tissue reactions. */
		
		require constraint {
			surgicalMeshSystem.mesh.biocompatibility >= 0.90
		}
	}
	
	requirement def PoreSizeRequirement {
		doc /* The surgical mesh shall have appropriate pore size 
		       to facilitate tissue ingrowth and integration. */
		
		require constraint {
			surgicalMeshSystem.mesh.poreSize >= 0.5 [SI::mm] and 
			surgicalMeshSystem.mesh.poreSize <= 3.0 [SI::mm]
		}
	}
	
	requirement <'MESH-001'> primaryFunction {
		doc /* The surgical mesh system shall provide mechanical reinforcement 
		       to weakened or damaged tissue while promoting biological integration 
		       and healing of the surrounding tissue. */
		
		assume constraint tissueDefectExists {
			doc /* A tissue defect requiring reinforcement is present. */
		}
		
		require mechanicalStrength : MechanicalStrengthRequirement;
		require biocompatibility : BiocompatibilityRequirement;
		require poreSize : PoreSizeRequirement;
		
		require constraint successfulRepair {
			surgicalMeshSystem.tissueReinforcement.reinforcementProvided == true
		}
	}
}
