package 'Nail Brace System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	doc /* 
	This model describes a Nail Brace System, an orthopedic medical device designed 
	to correct nail deformities such as ingrown toenails or curved nails. The system 
	applies controlled mechanical force to gradually reshape the nail plate over time, 
	reducing curvature and relieving pressure on surrounding tissue.
	*/
	
	attribute def CurvatureValue :> Real {
		doc /* Represents nail curvature as inverse radius (1/m). Higher values indicate more severe deformity. */
	}
	
	attribute def TreatmentDuration :> TimeValue;
	attribute def CorrectionRate :> Real;
	
	item def CorrectionForce {
		attribute magnitude : ForceValue;
		attribute direction : String;
		attribute applicationPoint : String;
	}
	
	attribute def NailGeometry {
		attribute width : LengthValue;
		attribute thickness : LengthValue;
		attribute initialCurvature : CurvatureValue;
		attribute currentCurvature : CurvatureValue;
	}
	
	attribute def BraceTension {
		attribute appliedForce : ForceValue;
		attribute tensionLevel : Real;
	}
	
	port def MechanicalCouplingPort {
		inout force : CorrectionForce;
		out deformation : LengthValue;
	}
	
	port def MonitoringPort {
		out curvatureMeasurement : CurvatureValue;
		out pressureFeedback : PressureValue;
	}
	
	part def NailPlate {
		doc /* The patient's nail being treated for deformity. */
		
		attribute geometry : NailGeometry;
		attribute elasticModulus : PressureValue;
		attribute painThreshold : PressureValue;
		
		port mechanicalInterface : MechanicalCouplingPort;
		port sensorInterface : MonitoringPort;
	}
	
	part def BraceWire {
		doc /* Flexible wire component that applies corrective force across the nail surface. */
		
		attribute wireDiameter : LengthValue;
		attribute material : String;
		attribute springConstant : Real;
		attribute maxTension : ForceValue;
		
		port nailContact : MechanicalCouplingPort;
	}
	
	part def AnchorHook {
		doc /* Attachment points that secure the brace wire to the nail edges. */
		
		attribute hookSize : LengthValue;
		attribute attachmentStrength : ForceValue;
		attribute position : String;
	}
	
	part def TensionAdjuster {
		doc /* Mechanism for controlling and adjusting the corrective force applied by the wire. */
		
		attribute adjustmentRange : ForceValue[2];
		attribute currentSetting : ForceValue;
		attribute incrementSize : ForceValue;
	}
	
	part def NailBraceSystem {
		doc /* 
		Complete nail brace assembly that corrects nail deformities by applying 
		controlled, gradual mechanical force to reshape the nail plate over time.
		*/
		
		attribute targetCurvature : CurvatureValue;
		attribute maxTreatmentCycles : Integer;
		attribute treatmentOutcome : Boolean;
		
		part nail : NailPlate;
		part wire : BraceWire;
		part leftHook : AnchorHook;
		part rightHook : AnchorHook;
		part adjuster : TensionAdjuster;
	}
	
	requirement def CorrectionEfficacyRequirement {
		doc /* The system shall reduce nail curvature to clinically acceptable levels. */
		
		subject system : NailBraceSystem;
		
		require constraint {
			system.nail.geometry.currentCurvature <= 0.05
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall not exceed safe force limits that could damage the nail or cause excessive pain. */
		
		attribute maxSafeForce : ForceValue = 3.0 [N];
		
		subject system : NailBraceSystem;
		
		require constraint {
			system.wire.nailContact.force.magnitude <= maxSafeForce
		}
	}
	
	requirement def ComfortRequirement {
		doc /* The system shall maintain patient comfort during treatment. */
		
		subject system : NailBraceSystem;
		
		require constraint {
			system.nail.sensorInterface.pressureFeedback <= system.nail.painThreshold
		}
	}
	
	requirement def TreatmentDurationRequirement {
		doc /* The system shall achieve correction within a clinically reasonable timeframe. */
		
		attribute maxTreatmentTime : TreatmentDuration = 90.0 [day];
		
		subject system : NailBraceSystem;
	}
	
	state def BraceOperationalState {
		doc /* Lifecycle states of the nail brace during treatment. */
		
		entry; then Installed;
		
		state Installed {
			doc /* Brace has been fitted to the nail. */
		}
		
		state ActiveCorrection {
			doc /* Brace is actively applying corrective force. */
		}
		
		state Monitoring {
			doc /* Periodic assessment of correction progress. */
		}
		
		state Adjusting {
			doc /* Tension is being modified based on progress. */
		}
		
		state TreatmentComplete {
			doc /* Target curvature achieved. */
		}
		
		state Removed {
			doc /* Brace has been removed from the nail. */
		}
		
		accept InitialTensionApplied;
		transition first Installed then ActiveCorrection;
		
		accept MonitoringInterval;
		transition first ActiveCorrection then Monitoring;
		
		transition first Monitoring then if CurvatureAboveTarget Adjusting;
		transition first Monitoring then if CurvatureAtTarget TreatmentComplete;
		
		accept TensionAdjusted;
		transition first Adjusting then ActiveCorrection;
		
		accept RemovalAuthorized;
		transition first TreatmentComplete then Removed;
	}
	
	action def MeasureCurvature {
		doc /* Assess current nail curvature to track correction progress. */
		
		in nail : NailPlate;
		out measuredCurvature : CurvatureValue;
	}
	
	action def CalculateRequiredForce {
		doc /* Determine optimal corrective force based on current curvature and nail properties. */
		
		in currentCurvature : CurvatureValue;
		in targetCurvature : CurvatureValue;
		in nailStiffness : PressureValue;
		out requiredForce : ForceValue;
	}
	
	action def ApplyCorrectionForce {
		doc /* Apply calculated force through the brace wire to deform the nail. */
		
		in force : ForceValue;
		in wire : BraceWire;
		inout nail : NailPlate;
		out appliedDeformation : LengthValue;
	}
	
	action def AdjustTension {
		doc /* Modify brace tension to maintain optimal correction rate. */
		
		in adjuster : TensionAdjuster;
		in targetForce : ForceValue;
		out newTension : BraceTension;
	}
	
	action def PerformCorrectionCycle {
		doc /* Execute one complete cycle of measurement, calculation, and force application. */
		
		inout nail : NailPlate;
		in wire : BraceWire;
		in adjuster : TensionAdjuster;
		in targetCurvature : CurvatureValue;
		out cycleComplete : Boolean;
		
		first start;
		
		then action measure : MeasureCurvature {
			in nail = PerformCorrectionCycle::nail;
			out measuredCurvature;
		}
		
		then decide;
			if measure.measuredCurvature > targetCurvature then continueCorrection;
			if measure.measuredCurvature <= targetCurvature then targetAchieved;
		
		action continueCorrection {
			action calculate : CalculateRequiredForce {
				in currentCurvature = measure.measuredCurvature;
				in targetCurvature = PerformCorrectionCycle::targetCurvature;
				in nailStiffness = PerformCorrectionCycle::nail.elasticModulus;
				out requiredForce;
			}
			then action adjust : AdjustTension {
				in adjuster = PerformCorrectionCycle::adjuster;
				in targetForce = calculate.requiredForce;
				out newTension;
			}
			then action apply : ApplyCorrectionForce {
				in force = adjust.newTension.appliedForce;
				in wire = PerformCorrectionCycle::wire;
				inout nail = PerformCorrectionCycle::nail;
				out appliedDeformation;
			}
			then assign cycleComplete := false;
		}
		
		action targetAchieved {
			assign cycleComplete := true;
		}
		
		then done;
	}
	
	action def ProvideCorrectionTherapy {
		doc /* Primary system function: Gradually correct nail deformity through controlled mechanical force application. */
		
		inout nail : NailPlate;
		in wire : BraceWire;
		in adjuster : TensionAdjuster;
		in targetCurvature : CurvatureValue;
		in maxCycles : Integer;
		out treatmentSuccess : Boolean;
		
		private attribute cycleCount : Integer := 0;
		private attribute correctionComplete : Boolean := false;
		
		first start;
		
		then merge treatmentLoop;
		
		then action checkProgress {
			in currentCycle : Integer = cycleCount;
			in maxAllowed : Integer = maxCycles;
			in complete : Boolean = correctionComplete;
			out continueTherapy : Boolean;
		}
		
		then decide;
			if checkProgress.continueTherapy and not correctionComplete then performCycle;
			if correctionComplete then success;
			if cycleCount >= maxCycles and not correctionComplete then failure;
		
		action performCycle {
			perform cycle : PerformCorrectionCycle {
				inout nail = ProvideCorrectionTherapy::nail;
				in wire = ProvideCorrectionTherapy::wire;
				in adjuster = ProvideCorrectionTherapy::adjuster;
				in targetCurvature = ProvideCorrectionTherapy::targetCurvature;
				out cycleComplete;
			}
			then assign cycleCount := cycleCount + 1;
			then assign correctionComplete := cycle.cycleComplete;
		}
		then treatmentLoop;
		
		action success {
			assign treatmentSuccess := true;
		}
		then done;
		
		action failure {
			assign treatmentSuccess := false;
		}
		then done;
	}
	
	part nailBraceInstance : NailBraceSystem {
		:>> targetCurvature = 0.05;
		:>> maxTreatmentCycles = 180;
		
		part :>> nail {
			attribute :>> geometry {
				:>> width = 12.0 [mm];
				:>> thickness = 0.5 [mm];
				:>> initialCurvature = 0.25;
				:>> currentCurvature = 0.25;
			}
			:>> elasticModulus = 2.5 [GPa];
			:>> painThreshold = 50.0 [kPa];
		}
		
		part :>> wire {
			:>> wireDiameter = 0.3 [mm];
			:>> material = "Nickel-Titanium Alloy";
			:>> springConstant = 0.8;
			:>> maxTension = 3.0 [N];
		}
		
		part :>> leftHook {
			:>> hookSize = 1.5 [mm];
			:>> attachmentStrength = 5.0 [N];
			:>> position = "Left Edge";
		}
		
		part :>> rightHook {
			:>> hookSize = 1.5 [mm];
			:>> attachmentStrength = 5.0 [N];
			:>> position = "Right Edge";
		}
		
		part :>> adjuster {
			:>> adjustmentRange = (0.5 [N], 3.0 [N]);
			:>> currentSetting = 1.5 [N];
			:>> incrementSize = 0.1 [N];
		}
		
		connect wire.nailContact to nail.mechanicalInterface;
		
		perform therapy : ProvideCorrectionTherapy {
			inout nail = nailBraceInstance::nail;
			in wire = nailBraceInstance::wire;
			in adjuster = nailBraceInstance::adjuster;
			in targetCurvature = nailBraceInstance::targetCurvature;
			in maxCycles = nailBraceInstance::maxTreatmentCycles;
			out treatmentSuccess;
		}
		
		state machine lifecycle : BraceOperationalState;
		
		satisfy correctionEfficacy : CorrectionEfficacyRequirement {
			subject system = nailBraceInstance;
		}
		
		satisfy safety : SafetyRequirement {
			subject system = nailBraceInstance;
		}
		
		satisfy comfort : ComfortRequirement {
			subject system = nailBraceInstance;
		}
		
		satisfy treatmentDuration : TreatmentDurationRequirement {
			subject system = nailBraceInstance;
		}
	}
}
