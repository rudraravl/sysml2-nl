package DenisBrowneBarSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RotationAngle :> ISQ::PlaneAngleValue;
	attribute def BarLength :> ISQ::LengthValue;
	attribute def CorrectionForce :> ISQ::ForceValue;
	attribute def WearTime :> ISQ::TimeValue;
	attribute def PatientAge :> ISQ::TimeValue;
	
	enum def FootPositionState {
		neutral;
		externally_rotated;
		abducted;
		corrected;
	}
	
	enum def TreatmentStage {
		initial_fitting;
		active_correction;
		maintenance_phase;
		weaning;
	}
	
	port def MechanicalConnection {
		attribute torque :> ISQ::TorqueValue;
		attribute angle :> ISQ::PlaneAngleValue;
	}
	
	item def Foot {
		attribute position : FootPositionState;
		attribute currentRotation : RotationAngle;
		attribute flexibility : Real;
	}
	
	part def Shoe {
		doc /* Specialized orthopedic shoe that secures the infant's foot. */
		attribute size : BarLength;
		port footInterface : MechanicalConnection;
	}
	
	part def FootPlate {
		doc /* Adjustable plate that attaches to shoe and connects to bar. */
		attribute rotationAngle : RotationAngle;
		attribute lockPosition : Boolean;
		port shoeConnection : MechanicalConnection;
		port barConnection : MechanicalConnection;
	}
	
	part def CentralBar {
		doc /* Rigid bar connecting the two foot plates at shoulder width. */
		attribute length : BarLength;
		attribute material : String;
		port leftAttachment : MechanicalConnection;
		port rightAttachment : MechanicalConnection;
	}
	
	part def DenisBrowneBar {
		doc /* 
		Complete Denis Browne bar assembly consisting of a central bar 
		with adjustable foot plates and shoes for bilateral foot correction.
		*/
		
		part bar : CentralBar {
			attribute length = 0.20[SI::m];
			attribute material = "aluminum";
		}
		
		part leftPlate : FootPlate {
			attribute rotationAngle = 70.0[SI::'°'];
			attribute lockPosition = true;
		}
		
		part rightPlate : FootPlate {
			attribute rotationAngle = 70.0[SI::'°'];
			attribute lockPosition = true;
		}
		
		part leftShoe : Shoe {
			attribute size = 0.10[SI::m];
		}
		
		part rightShoe : Shoe {
			attribute size = 0.10[SI::m];
		}
		
		connect bar.leftAttachment to leftPlate.barConnection;
		connect bar.rightAttachment to rightPlate.barConnection;
		connect leftPlate.shoeConnection to leftShoe.footInterface;
		connect rightPlate.shoeConnection to rightShoe.footInterface;
	}
	
	part def Infant {
		doc /* Infant patient receiving clubfoot correction treatment. */
		attribute age : PatientAge;
		attribute shoulderWidth : BarLength;
		
		part leftFoot : Foot {
			attribute position = FootPositionState::externally_rotated;
			attribute currentRotation = 65.0[SI::'°'];
			attribute flexibility = 0.8;
		}
		
		part rightFoot : Foot {
			attribute position = FootPositionState::externally_rotated;
			attribute currentRotation = 65.0[SI::'°'];
			attribute flexibility = 0.8;
		}
	}
	
	action def AssessFootPosition {
		in foot : Foot;
		out measuredAngle : RotationAngle;
		out positionState : FootPositionState;
	}
	
	action def ApplyCorrectionForce {
		in targetAngle : RotationAngle;
		in footPlate : FootPlate;
		in foot : Foot;
		out appliedForce : CorrectionForce;
	}
	
	action def AdjustPlateAngle {
		in currentAngle : RotationAngle;
		in targetAngle : RotationAngle;
		in plate : FootPlate;
		out newAngle : RotationAngle;
	}
	
	action def MaintainFootAbduction {
		doc /* 
		Primary function: Continuously maintain both feet in abducted 
		and externally rotated positions to prevent clubfoot relapse.
		*/
		
		in leftFoot : Foot;
		in rightFoot : Foot;
		in leftPlate : FootPlate;
		in rightPlate : FootPlate;
		in targetRotation : RotationAngle;
		out correctionAchieved : Boolean;
		
		first start;
		then merge monitoringLoop;
		
		then action assessLeftFoot : AssessFootPosition {
			in foot = leftFoot;
			out measuredAngle;
			out positionState;
		}
		
		then action assessRightFoot : AssessFootPosition {
			in foot = rightFoot;
			out measuredAngle;
			out positionState;
		}
		
		then decide;
			if assessLeftFoot.positionState == FootPositionState::corrected then checkRight;
		
		action checkRight {
			decide;
				if assessRightFoot.positionState == FootPositionState::corrected then holdPosition;
				if assessRightFoot.positionState != FootPositionState::corrected then applyCorrection;
		}
		then done;
		
		action applyCorrection {
			action adjustLeft : AdjustPlateAngle {
				in currentAngle = assessLeftFoot.measuredAngle;
				in targetAngle = targetRotation;
				in plate = leftPlate;
				out newAngle;
			}
			
			then action adjustRight : AdjustPlateAngle {
				in currentAngle = assessRightFoot.measuredAngle;
				in targetAngle = targetRotation;
				in plate = rightPlate;
				out newAngle;
			}
			
			then action applyLeftForce : ApplyCorrectionForce {
				in targetAngle = targetRotation;
				in footPlate = leftPlate;
				in foot = leftFoot;
				out appliedForce;
			}
			
			then action applyRightForce : ApplyCorrectionForce {
				in targetAngle = targetRotation;
				in footPlate = rightPlate;
				in foot = rightFoot;
				out appliedForce;
			}
		}
		then monitoringLoop;
		
		action holdPosition {
			assign correctionAchieved := true;
		}
	}
	
	state def TreatmentLifecycle {
		entry; then initialFitting;
		
		state initialFitting : TreatmentStage {
			entry assign stage = TreatmentStage::initial_fitting;
		}
		
		transition fitToActive
			first initialFitting
			accept at deviceFitted
			then activeCorrection;
		
		state activeCorrection : TreatmentStage {
			entry assign stage = TreatmentStage::active_correction;
			do MaintainFootAbduction;
		}
		
		transition activeToMaintenance
			first activeCorrection
			accept at correctionStabilized
			then maintenancePhase;
		
		state maintenancePhase : TreatmentStage {
			entry assign stage = TreatmentStage::maintenance_phase;
			do MaintainFootAbduction;
		}
		
		transition maintenanceToWeaning
			first maintenancePhase
			accept at weaningStarted
			then weaning;
		
		state weaning : TreatmentStage {
			entry assign stage = TreatmentStage::weaning;
		}
		
		transition weaningComplete
			first weaning
			accept at treatmentComplete
			then done;
		
		attribute stage : TreatmentStage;
		attribute deviceFitted : Boolean;
		attribute correctionStabilized : Boolean;
		attribute weaningStarted : Boolean;
		attribute treatmentComplete : Boolean;
	}
	
	part clubfootCorrectionSystem {
		doc /* 
		Complete Denis Browne bar orthopedic system for maintaining 
		clubfoot correction in infants following serial casting treatment.
		*/
		
		part device : DenisBrowneBar;
		part patient : Infant {
			attribute age = 3.0[SI::mo];
			attribute shoulderWidth = 0.18[SI::m];
		}
		
		connect device.leftShoe.footInterface to patient.leftFoot via leftFootConnection;
		connect device.rightShoe.footInterface to patient.rightFoot via rightFootConnection;
		
		perform action correctiveTreatment : MaintainFootAbduction {
			in leftFoot = patient.leftFoot;
			in rightFoot = patient.rightFoot;
			in leftPlate = device.leftPlate;
			in rightPlate = device.rightPlate;
			in targetRotation = 70.0[SI::'°'];
			out correctionAchieved;
		}
		
		exhibit state treatmentCycle : TreatmentLifecycle;
	}
	
	requirement def PositionMaintenanceRequirement {
		doc /* 
		The Denis Browne bar shall maintain both feet in external rotation 
		and abduction to prevent relapse of clubfoot deformity.
		*/
		
		subject device : DenisBrowneBar;
		
		require constraint rotationAngleConstraint {
			doc /* Foot plates shall maintain rotation between 60 and 70 degrees. */
			device.leftPlate.rotationAngle >= 60.0[SI::'°'] and
			device.leftPlate.rotationAngle <= 70.0[SI::'°'] and
			device.rightPlate.rotationAngle >= 60.0[SI::'°'] and
			device.rightPlate.rotationAngle <= 70.0[SI::'°']
		}
		
		require constraint barLengthConstraint {
			doc /* Bar length shall match patient shoulder width. */
			device.bar.length >= 0.15[SI::m] and
			device.bar.length <= 0.25[SI::m]
		}
	}
	
	requirement def WearComplianceRequirement {
		doc /* 
		The device shall be worn for prescribed duration to ensure 
		effective correction maintenance.
		*/
		
		require constraint dailyWearTime {
			doc /* Device shall be worn minimum 23 hours per day during active treatment. */
			true
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The device shall be safe for continuous infant use. */
		
		require constraint materialSafety {
			doc /* All materials shall be non-toxic and hypoallergenic. */
			true
		}
		
		require constraint forceLimit {
			doc /* Applied corrective forces shall not exceed safe limits for infant bones. */
			true
		}
	}
	
	requirement <'DBB-SYS-001'> primarySystemRequirement {
		doc /* 
		The Denis Browne bar system shall maintain corrected foot position 
		following clubfoot treatment by holding both feet in external rotation 
		and abduction through a rigid bar connecting adjustable foot plates, 
		thereby preventing relapse of the deformity during the critical 
		post-casting phase of treatment.
		*/
		
		subject system : DenisBrowneBar;
		
		assume constraint postCastingCorrection {
			doc /* Patient has completed serial casting with successful initial correction. */
			true
		}
		
		require PositionMaintenanceRequirement;
		require WearComplianceRequirement;
		require SafetyRequirement;
	}
}
