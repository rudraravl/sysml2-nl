package 'Dental Sinus Augmentation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		private import ScalarValues::*;
		private import ISQ::*;
		private import SI::*;

		attribute def BoneVolumeValue :> VolumeValue;
		attribute def IntegrationTimeValue :> TimeValue;
		attribute def StabilityValue :> ForceValue;
		attribute def ChewingForceValue :> ForceValue;
		attribute def OsseointegrationRatio :> Real;

		item def BoneGraft {
			attribute volume : BoneVolumeValue;
			attribute osteoconductivity : Real;
		}

		item def PlacedImplantSignal;
		item def IntegratedImplantSignal;

		port def ProstheticPort;

		part def MaxillarySinus {
			attribute airVolume : VolumeValue;
			attribute floorThickness : LengthValue;
		}
		part def ResidualBone {
			attribute height : LengthValue;
			attribute density : Real;
		}
		part def SinusMembrane {
			attribute thickness : LengthValue;
		}
		part def PatientAnatomy {
			part maxillarySinus : MaxillarySinus;
			part residualBone : ResidualBone;
			part sinusMembrane : SinusMembrane;
		}

		part def SinusImplantFixture {
			attribute material : String = "Titanium";
			attribute isBiocompatible : Boolean;
			attribute length : LengthValue;
			attribute diameter : LengthValue;
			port prostheticPort : ProstheticPort;
		}
		part def DentalCrown {
			attribute material : String;
			port crownAttachPort : ProstheticPort;
		}

		action def 'Elevate Sinus Membrane' {
			in membrane : SinusMembrane;
			out elevatedSpace : BoneVolumeValue;
		}
		action def 'Place Bone Graft' {
			in elevatedSpace : BoneVolumeValue;
			in graft : BoneGraft;
			out graftedSpace : BoneVolumeValue;
		}
		action def 'Insert Implant Fixture' {
			in graftedSpace : BoneVolumeValue;
			in bone : ResidualBone;
			in implantFixture : SinusImplantFixture;
			out placedImplant : SinusImplantFixture;
			out initialStability : StabilityValue;
		}
		action def 'Perform Osseointegration' {
			in placedImplant : SinusImplantFixture;
			in bone : ResidualBone;
			in timeDuration : IntegrationTimeValue;
			out integratedImplant : SinusImplantFixture;
			out integrationRatio : OsseointegrationRatio;
		}
		action def 'Attach Dental Crown' {
			in integratedImplant : SinusImplantFixture;
			in crown : DentalCrown;
			out restoredTooth : SinusImplantFixture;
			out chewingForce : ChewingForceValue;
		}

		state def ImplantLifecycle {
			state placed;
			state osseointegrated;
			state restored;
			transition from placed to osseointegrated;
			transition from osseointegrated to restored;
		}

		requirement def 'Biocompatibility Requirement' {
			subject implant : SinusImplantFixture;
			constraint { implant.isBiocompatible == true }
		}
		requirement def 'Initial Stability Requirement' {
			subject placedImplant : SinusImplantFixture;
			subject stability : StabilityValue;
			constraint { stability > 10.0 [N] }
		}
		requirement def 'Full Integration Requirement' {
			subject integratedImplant : SinusImplantFixture;
			subject integrationRatio : OsseointegrationRatio;
			constraint { integrationRatio >= 0.6 }
		}
		requirement def 'Restore Masticatory Function' {
			subject restoredTooth : SinusImplantFixture;
			subject chewingForce : ChewingForceValue;
			constraint { chewingForce > 100.0 [N] }
		}

		connection def ImplantCrownConnection {
			end port implantPort : ProstheticPort;
			end port crownPort : ProstheticPort;
		}
	}

	package Usages {
		private import Definitions::*;

		part dentalSystem {
			part patient : PatientAnatomy;
			part implantFixture : SinusImplantFixture {
				attribute isBiocompatible = true;
			}
			item graftMaterial : BoneGraft;
			part prostheticCrown : DentalCrown;

			perform action 'Sinus Augmentation Procedure' {
				action 'elevate sinus membrane': 'Elevate Sinus Membrane';
				bind 'elevate sinus membrane'.membrane = patient.sinusMembrane;
				flow 'elevate sinus membrane'.elevatedSpace to 'place bone graft'.elevatedSpace;
				action 'place bone graft': 'Place Bone Graft';
				bind 'place bone graft'.graft = graftMaterial;
				flow 'place bone graft'.graftedSpace to 'insert implant fixture'.graftedSpace;
				action 'insert implant fixture': 'Insert Implant Fixture';
				bind 'insert implant fixture'.bone = patient.residualBone;
				bind 'insert implant fixture'.implantFixture = implantFixture;
				flow 'insert implant fixture'.placedImplant to 'perform osseointegration'.placedImplant;
				action 'perform osseointegration': 'Perform Osseointegration';
				bind 'perform osseointegration'.bone = patient.residualBone;
				flow 'perform osseointegration'.integratedImplant to 'attach dental crown'.integratedImplant;
				action 'attach dental crown': 'Attach Dental Crown';
				bind 'attach dental crown'.crown = prostheticCrown;

				first 'elevate sinus membrane' then 'place bone graft';
				first 'place bone graft' then 'insert implant fixture';
				first 'insert implant fixture' then 'perform osseointegration';
				first 'perform osseointegration' then 'attach dental crown';
			}

			connection : ImplantCrownConnection
				from implantFixture.prostheticPort
				to prostheticCrown.crownAttachPort;

			state implantLifecycle : ImplantLifecycle;

			requirement req_biocompatibility : 'Biocompatibility Requirement' {
				:>> implant = implantFixture;
			}
			requirement req_initial_stability : 'Initial Stability Requirement' {
				:>> placedImplant = 'Sinus Augmentation Procedure'.'insert implant fixture'.placedImplant;
				:>> stability = 'Sinus Augmentation Procedure'.'insert implant fixture'.initialStability;
			}
			requirement req_full_integration : 'Full Integration Requirement' {
				:>> integratedImplant = 'Sinus Augmentation Procedure'.'perform osseointegration'.integratedImplant;
				:>> integrationRatio = 'Sinus Augmentation Procedure'.'perform osseointegration'.integrationRatio;
			}
			requirement req_restore_mastication : 'Restore Masticatory Function' {
				:>> restoredTooth = 'Sinus Augmentation Procedure'.'attach dental crown'.restoredTooth;
				:>> chewingForce = 'Sinus Augmentation Procedure'.'attach dental crown'.chewingForce;
			}
		}
	}
}
