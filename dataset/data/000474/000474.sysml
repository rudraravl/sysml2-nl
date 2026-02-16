package MitraClipSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RegurgitantFraction :> Real {
		doc /* Fraction of blood flowing backward through mitral valve during systole. */
	}
	
	attribute def CoaptationLength :> LengthValue {
		doc /* Length of leaflet tissue contact achieved by clip. */
	}
	
	attribute def DeflectionAngle :> Real {
		doc /* Angular deflection of steerable catheter in degrees. */
	}
	
	attribute def GraspingForce :> ForceValue {
		doc /* Force applied by clip arms to grasp leaflets. */
	}
	
	item def MitralLeaflet {
		attribute thickness : LengthValue;
		attribute mobility : String;
		attribute position : String;
	}
	
	item def MitralValve {
		attribute regurgitantOrificeArea : AreaValue;
		attribute severityGrade : String;
		part anteriorLeaflet : MitralLeaflet;
		part posteriorLeaflet : MitralLeaflet;
	}
	
	item def BloodFlow {
		attribute volumeRate : VolumeFlowRateValue;
		attribute direction : String;
		attribute regurgitantFraction : RegurgitantFraction;
	}
	
	item def EchocardiographicImage {
		attribute viewType : String;
		attribute quality : String;
	}
	
	port def VascularAccessPort {
		in item catheterEntry;
		out item catheterPosition;
	}
	
	port def ImagingPort {
		in item echoImage : EchocardiographicImage;
	}
	
	port def ControlPort {
		in attribute steeringCommand : DeflectionAngle;
		in attribute graspCommand : Boolean;
		in attribute releaseCommand : Boolean;
	}
	
	part def ClipImplant {
		attribute clipWidth : LengthValue;
		attribute numberOfArms : Integer;
		attribute armMaterial : String;
		attribute graspingForce : GraspingForce;
		
		state clipDeployment {
			entry; then retracted;
			
			state retracted;
			accept graspCommand
			then opened;
			
			state opened;
			accept leafletsAligned
			then grasping;
			
			state grasping;
			accept closureCommand
			then closed;
			accept repositionCommand
			then opened;
			
			state closed;
			accept lockCommand
			then locked;
			accept adjustCommand
			then grasping;
			
			state locked;
			accept releaseCommand
			then deployed;
			
			state deployed;
		}
	}
	
	part def SteerableDeliveryCatheter {
		attribute outerDiameter : LengthValue;
		attribute workingLength : LengthValue;
		attribute deflectionRange : DeflectionAngle;
		
		port controlInput : ControlPort;
		port imagingInput : ImagingPort;
		port clipInterface;
	}
	
	part def GuideSheath {
		attribute innerDiameter : LengthValue;
		attribute sheathLength : LengthValue;
		
		port vascularAccess : VascularAccessPort;
	}
	
	part def SteeringControl {
		attribute deflectionKnob : String;
		attribute rotationKnob : String;
		
		port controlOutput : ControlPort;
	}
	
	action def EstablishVascularAccess {
		in accessSite : String;
		out sheathPlaced : Boolean;
	}
	
	action def PerformTransseptalPuncture {
		in sheathPlaced : Boolean;
		out leftAtriumAccessed : Boolean;
	}
	
	action def NavigateToMitralValve {
		in leftAtriumAccessed : Boolean;
		in imagingGuidance : EchocardiographicImage;
		out catheterAtValve : Boolean;
	}
	
	action def AlignClipWithLeaflets {
		in catheterAtValve : Boolean;
		in valveGeometry : MitralValve;
		in imagingGuidance : EchocardiographicImage;
		out clipAligned : Boolean;
		out coaptationPoint : String;
	}
	
	action def GraspMitralLeaflets {
		in clipAligned : Boolean;
		in anteriorLeaflet : MitralLeaflet;
		in posteriorLeaflet : MitralLeaflet;
		in graspingForce : GraspingForce;
		out leafletsCaptured : Boolean;
		out coaptationLength : CoaptationLength;
	}
	
	action def CloseAndLockClip {
		in leafletsCaptured : Boolean;
		in coaptationLength : CoaptationLength;
		out clipLocked : Boolean;
	}
	
	action def AssessRegurgitationReduction {
		in clipLocked : Boolean;
		in preRegurgitantFraction : RegurgitantFraction;
		in imagingGuidance : EchocardiographicImage;
		out postRegurgitantFraction : RegurgitantFraction;
		out reductionAdequate : Boolean;
	}
	
	action def ReleaseClipFromDeliverySystem {
		in reductionAdequate : Boolean;
		in clipLocked : Boolean;
		out clipDeployed : Boolean;
	}
	
	action def WithdrawCatheterSystem {
		in clipDeployed : Boolean;
		out systemRemoved : Boolean;
	}
	
	action def PerformMitraClipProcedure {
		in targetValve : MitralValve;
		in femoralAccessSite : String;
		out mitralRegurgitationReduced : Boolean;
		out procedureSuccessful : Boolean;
		
		first start;
		
		then action establishAccess : EstablishVascularAccess {
			in accessSite = femoralAccessSite;
			out sheathPlaced;
		}
		
		then action transseptalPuncture : PerformTransseptalPuncture {
			in sheathPlaced = establishAccess.sheathPlaced;
			out leftAtriumAccessed;
		}
		
		then action navigateToValve : NavigateToMitralValve {
			in leftAtriumAccessed = transseptalPuncture.leftAtriumAccessed;
			in imagingGuidance;
			out catheterAtValve;
		}
		
		then merge alignmentLoop;
		
		action alignClip : AlignClipWithLeaflets {
			in catheterAtValve = navigateToValve.catheterAtValve;
			in valveGeometry = targetValve;
			in imagingGuidance;
			out clipAligned;
			out coaptationPoint;
		}
		
		then action graspLeaflets : GraspMitralLeaflets {
			in clipAligned = alignClip.clipAligned;
			in anteriorLeaflet = targetValve.anteriorLeaflet;
			in posteriorLeaflet = targetValve.posteriorLeaflet;
			in graspingForce = 6.0 [SI::N];
			out leafletsCaptured;
			out coaptationLength;
		}
		
		then decide;
			if graspLeaflets.leafletsCaptured and graspLeaflets.coaptationLength >= 5.0 [SI::mm] then closeClip;
			else alignmentLoop;
		
		action closeClip : CloseAndLockClip {
			in leafletsCaptured = graspLeaflets.leafletsCaptured;
			in coaptationLength = graspLeaflets.coaptationLength;
			out clipLocked;
		}
		
		then action assessReduction : AssessRegurgitationReduction {
			in clipLocked = closeClip.clipLocked;
			in preRegurgitantFraction = 0.6;
			in imagingGuidance;
			out postRegurgitantFraction;
			out reductionAdequate;
		}
		
		then decide;
			if assessReduction.reductionAdequate then releaseClip;
			else alignmentLoop;
		
		action releaseClip : ReleaseClipFromDeliverySystem {
			in reductionAdequate = assessReduction.reductionAdequate;
			in clipLocked = closeClip.clipLocked;
			out clipDeployed;
		}
		
		then action withdrawSystem : WithdrawCatheterSystem {
			in clipDeployed = releaseClip.clipDeployed;
			out systemRemoved;
		}
		
		then assign mitralRegurgitationReduced := assessReduction.reductionAdequate;
		then assign procedureSuccessful := withdrawSystem.systemRemoved;
		then done;
	}
	
	requirement def ClinicalEffectivenessRequirement;
	requirement def SafetyRequirement;
	requirement def DeliverabilityRequirement;
	
	part def MitraClipTherapeuticSystem;
	
	requirement <'REQ-001'> reduceRegurgitation : ClinicalEffectivenessRequirement {
		doc /* The MitraClip system shall reduce mitral regurgitation from severe 
		       (regurgitant fraction > 0.5) to moderate or less (regurgitant fraction <= 0.3) 
		       in at least 70% of treated patients. */
		
		subject system : MitraClipTherapeuticSystem;
	}
	
	requirement <'REQ-002'> achieveLeafletCoaptation : ClinicalEffectivenessRequirement {
		doc /* The clip shall achieve a minimum coaptation length of 5 mm between 
		       anterior and posterior mitral leaflets to ensure durable repair. */
		
		subject clip : ClipImplant;
	}
	
	requirement <'REQ-003'> preventTissueDamage : SafetyRequirement {
		doc /* The grasping force applied to mitral leaflets shall not exceed 8 N 
		       to prevent tissue laceration or perforation. */
		
		subject clip : ClipImplant;
	}
	
	requirement <'REQ-004'> enableTransseptalDelivery : DeliverabilityRequirement {
		doc /* The delivery catheter system shall be navigable through femoral venous access 
		       and transseptal puncture with outer diameter not exceeding 24 French. */
		
		subject catheter : SteerableDeliveryCatheter;
	}
	
	requirement <'REQ-005'> provideSteering : DeliverabilityRequirement {
		doc /* The steerable catheter shall provide at least 180 degrees of deflection 
		       to enable positioning across the mitral valve from left atrial approach. */
		
		subject catheter : SteerableDeliveryCatheter;
	}
	
	part mitraClipTherapeuticSystem : MitraClipTherapeuticSystem {
		doc /* 
		The MitraClip Transcatheter Mitral Valve Repair System is a minimally invasive 
		medical device designed to treat mitral regurgitation by approximating the mitral 
		valve leaflets.
		
		Its primary function is to reduce or eliminate abnormal backward blood flow through 
		the mitral valve by creating a tissue bridge between the anterior and posterior 
		leaflets. This is achieved by delivering a small clip device through the venous 
		system to the heart, where it grasps and holds together portions of the valve 
		leaflets, effectively reducing the regurgitant orifice area.
		
		The system mimics the surgical Alfieri edge-to-edge repair technique but is performed 
		percutaneously, avoiding the need for open-heart surgery. By restoring more effective 
		valve closure, the MitraClip reduces the volume of blood flowing backward into the 
		left atrium during ventricular contraction, thereby improving cardiac output and 
		reducing symptoms of heart failure in patients with significant mitral regurgitation.
		*/
		
		part clip : ClipImplant {
			attribute clipWidth = 4.0 [SI::mm];
			attribute numberOfArms = 2;
			attribute armMaterial = "Cobalt-Chromium Alloy";
			attribute graspingForce = 6.5 [SI::N];
		}
		
		part deliveryCatheter : SteerableDeliveryCatheter {
			attribute outerDiameter = 7.5 [SI::mm];
			attribute workingLength = 100.0 [SI::cm];
			attribute deflectionRange = 180.0;
		}
		
		part guideSheath : GuideSheath {
			attribute innerDiameter = 8.0 [SI::mm];
			attribute sheathLength = 65.0 [SI::cm];
		}
		
		part steeringControl : SteeringControl {
			attribute deflectionKnob = "Proximal Handle";
			attribute rotationKnob = "Distal Handle";
		}
		
		connect steeringControl.controlOutput to deliveryCatheter.controlInput;
		connect deliveryCatheter.clipInterface to clip;
		
		perform action treatMitralRegurgitation : PerformMitraClipProcedure {
			in targetValve;
			in femoralAccessSite = "Right Femoral Vein";
			out mitralRegurgitationReduced;
			out procedureSuccessful;
		}
		
		satisfy reduceRegurgitation;
		satisfy achieveLeafletCoaptation;
		satisfy preventTissueDamage;
		satisfy enableTransseptalDelivery;
		satisfy provideSteering;
	}
}
