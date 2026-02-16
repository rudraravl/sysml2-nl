package 'Left Atrial Appendage Occlusion System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PatientIdentifier;
	attribute def ProcedureStatus;
	
	enum def OccluderState {
		stowed;
		advancing;
		deployed;
		anchored;
		released;
		monitoring;
	}
	
	enum def BloodFlowState {
		unrestricted;
		partial;
		occluded;
	}
	
	item def Blood {
		attribute pressure : ISQ::PressureValue;
		attribute flowRate : ISQ::VolumeFlowRateValue;
	}
	
	item def Thrombus;
	
	attribute def OcclusionForce :> ISQ::ForceValue {
		doc /* Force exerted by occluder against LAA tissue to achieve seal */
	}
	
	attribute def DeviceDiameter :> ISQ::LengthValue {
		doc /* Diameter of occlusion device at deployment */
	}
	
	attribute def AnchoringForce :> ISQ::ForceValue {
		doc /* Force securing device to prevent migration */
	}
	
	attribute def ResidualLeakage :> ISQ::VolumeFlowRateValue {
		doc /* Residual blood flow past occluder */
	}
	
	port def BloodFlowPort {
		inout blood : Blood;
	}
	
	port def ImagingPort {
		out visualizationData : Real;
		out devicePosition : ISQ::LengthValue;
	}
	
	port def DeliveryControlPort {
		in deploymentCommand : Real;
		out deviceState : OccluderState;
	}
	
	port def MonitoringPort {
		out occlusionComplete : Boolean;
		out leakageRate : ResidualLeakage;
		out deviceStable : Boolean;
	}
	
	part def LeftAtrialAppendage {
		doc /* Anatomical structure prone to thrombus formation in atrial fibrillation */
		attribute ostiumDiameter : DeviceDiameter;
		attribute depth : ISQ::LengthValue;
		attribute wallThickness : ISQ::LengthValue;
		
		port bloodInlet : BloodFlowPort;
		port appendageAccess {
			in occluder;
		}
	}
	
	part def OccluderDevice {
		doc /* Implantable device that seals LAA ostium */
		attribute nominalDiameter : DeviceDiameter;
		attribute occlusionForce : OcclusionForce;
		attribute anchorForce : AnchoringForce;
		attribute currentState : OccluderState;
		
		port controlInterface : DeliveryControlPort;
		port tissueInterface {
			out contactForce : OcclusionForce;
		}
	}
	
	state def OccluderLifecycle {
		entry; then stowed;
		
		state stowed;
		accept initiateDeployment;
		then advancing;
		
		state advancing;
		accept reachTarget;
		then deployed;
		
		state deployed;
		accept confirmAnchor;
		then anchored;
		
		state anchored;
		accept verifyOcclusion;
		then released;
		
		state released;
		then monitoring;
		
		state monitoring;
	}
	
	part def DeliveryCatheter {
		doc /* Catheter system for navigating and deploying occluder */
		attribute outerDiameter : ISQ::LengthValue;
		attribute workingLength : ISQ::LengthValue;
		
		port proximalControl : DeliveryControlPort;
		port distalDelivery {
			out occluderDevice : OccluderDevice;
		}
	}
	
	part def ImagingSystem {
		doc /* Real-time imaging for procedure guidance */
		attribute spatialResolution : ISQ::LengthValue;
		attribute frameRate : ISQ::FrequencyValue;
		
		port imagingOutput : ImagingPort;
	}
	
	part def MonitoringSystem {
		doc /* Post-procedure monitoring for device stability and occlusion */
		port monitorOutput : MonitoringPort;
		
		action continuousMonitoring {
			in deviceStatus : OccluderState;
			in flowMeasurement : ResidualLeakage;
			out leakDetected : Boolean;
			out deviceMigration : Boolean;
		}
	}
	
	action def NavigateCatheter {
		in imagingGuidance : Real;
		in targetLocation : ISQ::LengthValue;
		out catheterPositioned : Boolean;
	}
	
	action def DeployOccluder {
		in deviceDiameter : DeviceDiameter;
		in laaOstiumDiameter : DeviceDiameter;
		out deviceExpanded : Boolean;
	}
	
	action def AnchorOccluder {
		in contactForce : OcclusionForce;
		in minimumForce : OcclusionForce;
		out anchorSecure : Boolean;
	}
	
	action def VerifyOcclusion {
		in imagingData : Real;
		in flowMeasurement : ResidualLeakage;
		out occlusionComplete : Boolean;
	}
	
	action def ReleaseOccluder {
		in occlusionVerified : Boolean;
		out deviceDetached : Boolean;
	}
	
	action def MonitorLongTerm {
		in deviceStatus : OccluderState;
		out monitoringActive : Boolean;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The LAAO system shall permanently occlude the left atrial appendage 
		       to prevent thrombus formation and embolization, thereby reducing 
		       stroke risk in patients with non-valvular atrial fibrillation. */
		
		require constraint completeOcclusion {
			doc /* Device must achieve complete or near-complete LAA occlusion */
		}
		
		require constraint permanentSealing {
			doc /* Occlusion must remain stable over patient lifetime */
		}
		
		require constraint thrombusReduction {
			doc /* System must prevent thrombus formation within LAA */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* System shall ensure patient safety during and after procedure */
		
		require constraint appropriateSizing {
			doc /* Device diameter must match LAA ostium within tolerance */
		}
		
		require constraint secureAnchoring {
			doc /* Anchoring force must prevent device embolization */
		}
		
		require constraint imagingGuidance {
			doc /* Procedure must use continuous imaging guidance */
		}
		
		require constraint biocompatibility {
			doc /* All materials must be biocompatible and hemocompatible */
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* System shall meet clinical performance criteria */
		
		require constraint occlusionRate {
			doc /* Complete occlusion rate shall exceed 95% at 45 days */
		}
		
		require constraint residualLeakThreshold {
			doc /* Residual peridevice leak shall be less than 5mm */
		}
		
		require constraint procedureDuration {
			doc /* Mean procedure time shall not exceed 60 minutes */
		}
		
		require constraint complicationRate {
			doc /* Major adverse events shall be below 4% at 7 days */
		}
	}
	
	part laaoSystem {
		doc /* Complete left atrial appendage occlusion system */
		
		satisfy primaryFunction : PrimaryFunctionRequirement;
		satisfy safety : SafetyRequirement;
		satisfy performance : PerformanceRequirement;
		
		part targetAnatomy : LeftAtrialAppendage {
			attribute ostiumDiameter = 20.0 [mm];
			attribute depth = 28.0 [mm];
			attribute wallThickness = 1.5 [mm];
		}
		
		part occluder : OccluderDevice {
			attribute nominalDiameter = 24.0 [mm];
			attribute occlusionForce = 2.8 [N];
			attribute anchorForce = 3.5 [N];
			attribute currentState = OccluderState::stowed;
			
			exhibit state lifecycle : OccluderLifecycle;
		}
		
		part catheter : DeliveryCatheter {
			attribute outerDiameter = 4.2 [mm];
			attribute workingLength = 1000.0 [mm];
		}
		
		part imaging : ImagingSystem {
			attribute spatialResolution = 0.3 [mm];
			attribute frameRate = 30.0 [Hz];
		}
		
		part monitoring : MonitoringSystem;
		
		connect catheter.distalDelivery.occluderDevice to occluder;
		connect imaging.imagingOutput to catheter.proximalControl;
		connect occluder.tissueInterface to targetAnatomy.appendageAccess;
		
		perform action laaoProcedure {
			doc /* Complete LAAO procedure workflow */
			
			first start;
			
			then action navigateToCatheter : NavigateCatheter {
				in imagingGuidance;
				in targetLocation = targetAnatomy.ostiumDiameter;
				out catheterPositioned;
			}
			
			then action deployDevice : DeployOccluder {
				in deviceDiameter = occluder.nominalDiameter;
				in laaOstiumDiameter = targetAnatomy.ostiumDiameter;
				out deviceExpanded;
			}
			
			then action anchorDevice : AnchorOccluder {
				in contactForce = occluder.occlusionForce;
				in minimumForce = 2.0 [N];
				out anchorSecure;
			}
			
			then action verifyOcclusionQuality : VerifyOcclusion {
				in imagingData;
				in flowMeasurement;
				out occlusionComplete;
			}
			
			then decide;
				if verifyOcclusionQuality.occlusionComplete then releaseDevice;
				if not verifyOcclusionQuality.occlusionComplete then repositionDevice;
			
			action repositionDevice {
				then merge continueDeployment;
			}
			
			merge continueDeployment;
			then deployDevice;
			
			action releaseDevice : ReleaseOccluder {
				in occlusionVerified = verifyOcclusionQuality.occlusionComplete;
				out deviceDetached;
			}
			
			then action monitorPatient : MonitorLongTerm {
				in deviceStatus = occluder.currentState;
				out monitoringActive;
			}
			
			then done;
		}
	}
	
	action def PerformLAAOProcedure {
		doc /* High-level action representing complete LAAO intervention */
		
		in patientID : PatientIdentifier;
		in laaGeometry : ISQ::LengthValue;
		out procedureSuccess : Boolean;
		out occlusionAchieved : Boolean;
		
		first start;
		
		then action assessAnatomy {
			in geometry : ISQ::LengthValue = laaGeometry;
			out suitableForDevice : Boolean;
		}
		
		then action selectDevice {
			in anatomySuitable : Boolean = assessAnatomy.suitableForDevice;
			out selectedDiameter : DeviceDiameter;
		}
		
		then action implantDevice {
			in deviceSize : DeviceDiameter = selectDevice.selectedDiameter;
			out implantComplete : Boolean;
		}
		
		then action confirmOcclusion {
			in deviceImplanted : Boolean = implantDevice.implantComplete;
			out occlusionConfirmed : Boolean;
		}
		
		then assign occlusionAchieved := confirmOcclusion.occlusionConfirmed;
		then assign procedureSuccess := confirmOcclusion.occlusionConfirmed;
		then done;
	}
}
