package 'Cutting Balloon Catheter System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VesselDiameter :> LengthValue {
		doc /* Diameter of the target blood vessel or stenotic lesion */
	}
	
	attribute def InflationPressure :> PressureValue {
		doc /* Pressure applied to inflate the balloon membrane */
	}
	
	attribute def CuttingDepth :> LengthValue {
		doc /* Depth of incision created by atherotome blades */
	}
	
	attribute def FlowRate :> VolumeFlowRateValue {
		doc /* Rate of inflation medium delivery or removal */
	}
	
	item def ContrastMedium {
		doc /* Radiopaque fluid used to inflate the balloon and enable fluoroscopic visualization */
		attribute density : DensityValue;
		attribute viscosity : DynamicViscosityValue;
		attribute volume : VolumeValue;
	}
	
	item def VesselTissue {
		doc /* Biological tissue comprising the vessel wall and atherosclerotic plaque */
		attribute elasticity : Real;
		attribute thickness : LengthValue;
		attribute calcification : Real;
	}
	
	port def InflationPort {
		doc /* Interface for delivering inflation medium under controlled pressure */
		in item medium : ContrastMedium;
		in attribute pressure : InflationPressure;
		out attribute flowRate : FlowRate;
	}
	
	port def CatheterInterface {
		doc /* Proximal interface for catheter manipulation and guidewire passage */
		in attribute guidewirePosition : LengthValue;
		out attribute catheterPosition : LengthValue;
	}
	
	port def VesselContact {
		doc /* Interface between device and vessel wall tissue */
		in item tissue : VesselTissue;
		out attribute contactForce : ForceValue;
	}
	
	part def Atherotome {
		doc /* Microsurgical blade element bonded to balloon surface for controlled plaque scoring */
		attribute bladeHeight : LengthValue;
		attribute bladeLength : LengthValue;
		attribute sharpness : Real;
		attribute angularPosition : Real;
		
		port cuttingInterface : VesselContact {
			out attribute cuttingForce : ForceValue;
			out attribute incisionDepth : CuttingDepth;
		}
	}
	
	part def BalloonMembrane {
		doc /* Semi-compliant expandable membrane that applies radial force and supports atherotomes */
		attribute nominalDiameter : VesselDiameter;
		attribute workingLength : LengthValue;
		attribute burstPressure : InflationPressure;
		attribute compliance : Real;
		attribute wallThickness : LengthValue;
		
		port expansionInterface {
			in attribute internalPressure : InflationPressure;
			in item inflationMedium : ContrastMedium;
			out attribute currentDiameter : VesselDiameter;
			out attribute radialForce : ForceValue;
		}
		
		port bladeMount[3..4] {
			doc /* Mounting points for atherotome blades on balloon surface */
		}
	}
	
	part def CatheterShaft {
		doc /* Flexible tubular shaft for device delivery and inflation lumen */
		attribute shaftLength : LengthValue;
		attribute outerDiameter : LengthValue;
		attribute innerDiameter : LengthValue;
		attribute flexibility : Real;
		
		port proximalHub : CatheterInterface;
		port distalTip {
			out item mediumFlow : ContrastMedium;
			out attribute tipPosition : LengthValue;
		}
		
		part inflationLumen {
			doc /* Dedicated lumen for inflation medium transport */
			attribute lumenDiameter : LengthValue;
		}
		
		part guidewireLumen {
			doc /* Central lumen for over-the-wire guidewire passage */
			attribute lumenDiameter : LengthValue;
		}
	}
	
	part def InflationDevice {
		doc /* Manual or automated device for controlling balloon inflation and deflation */
		attribute maxPressure : InflationPressure;
		attribute reservoirVolume : VolumeValue;
		
		port inflationControl : InflationPort;
		
		part pressureGauge {
			attribute currentPressure : InflationPressure;
			attribute accuracy : Real;
		}
		
		part syringeAssembly {
			attribute volume : VolumeValue;
			attribute plungerPosition : LengthValue;
		}
	}
	
	action def NavigateToLesion {
		doc /* Advance catheter over guidewire to target stenotic lesion */
		in attribute targetLocation : LengthValue;
		in attribute vesselAnatomy : VesselTissue;
		out attribute positioned : Boolean;
		out attribute finalPosition : LengthValue;
	}
	
	action def InflateBalloon {
		doc /* Inflate balloon to nominal pressure for atherotome engagement */
		in attribute targetPressure : InflationPressure;
		in item medium : ContrastMedium;
		in attribute inflationRate : FlowRate;
		out attribute achievedDiameter : VesselDiameter;
		out attribute achievedPressure : InflationPressure;
		out attribute inflationComplete : Boolean;
	}
	
	action def ScorePlaque {
		doc /* Create controlled longitudinal incisions in atherosclerotic plaque */
		in attribute balloonPressure : InflationPressure;
		in item vesselWall : VesselTissue;
		in attribute dwellTime : TimeValue;
		out attribute incisionDepth : CuttingDepth;
		out attribute numberOfIncisions : Integer;
		out attribute scoringComplete : Boolean;
	}
	
	action def DeflateBalloon {
		doc /* Remove inflation medium to collapse balloon and retract atherotomes */
		in attribute deflationRate : FlowRate;
		out attribute residualPressure : InflationPressure;
		out attribute deflationComplete : Boolean;
	}
	
	action def WithdrawCatheter {
		doc /* Retract catheter system from vascular access site */
		out attribute withdrawn : Boolean;
	}
	
	action def PerformCuttingAngioplasty {
		doc /* 
			Execute complete cutting balloon angioplasty procedure to treat stenotic lesion.
			The procedure creates controlled micro-incisions in plaque while dilating the vessel,
			reducing elastic recoil and minimizing vessel trauma compared to conventional angioplasty.
		*/
		in attribute lesionLocation : LengthValue;
		in attribute nominalPressure : InflationPressure;
		in attribute targetDiameter : VesselDiameter;
		in item inflationMedium : ContrastMedium;
		in item targetVessel : VesselTissue;
		in attribute dwellDuration : TimeValue;
		out attribute procedureSuccess : Boolean;
		out attribute finalVesselDiameter : VesselDiameter;
		
		first start;
		
		then action navigate : NavigateToLesion {
			in attribute targetLocation = lesionLocation;
			in attribute vesselAnatomy = targetVessel;
			out attribute positioned;
			out attribute finalPosition;
		}
		
		then decide;
			if navigate.positioned then inflate;
			if not navigate.positioned then abort;
		
		action inflate : InflateBalloon {
			in attribute targetPressure = nominalPressure;
			in item medium = inflationMedium;
			in attribute inflationRate = 0.5 [mL/s];
			out attribute achievedDiameter;
			out attribute achievedPressure;
			out attribute inflationComplete;
		}
		
		then action score : ScorePlaque {
			in attribute balloonPressure = inflate.achievedPressure;
			in item vesselWall = targetVessel;
			in attribute dwellTime = dwellDuration;
			out attribute incisionDepth;
			out attribute numberOfIncisions;
			out attribute scoringComplete;
		}
		
		then action deflate : DeflateBalloon {
			in attribute deflationRate = 1.0 [mL/s];
			out attribute residualPressure;
			out attribute deflationComplete;
		}
		
		then action withdraw : WithdrawCatheter {
			out attribute withdrawn;
		}
		
		then assign procedureSuccess := withdraw.withdrawn and score.scoringComplete;
		then assign finalVesselDiameter := inflate.achievedDiameter;
		then done;
		
		action abort {
			doc /* Abort procedure if positioning fails */
		}
		then done;
	}
	
	state def CuttingBalloonLifecycle {
		doc /* Operational states during cutting balloon angioplasty procedure */
		
		entry; then idle;
		
		state idle {
			doc /* Catheter packaged or prepared for insertion */
		}
		
		state navigating {
			doc /* Catheter being advanced to target lesion */
		}
		
		state positioned {
			doc /* Catheter positioned at stenotic lesion */
		}
		
		state inflating {
			doc /* Balloon expanding under pressure */
		}
		
		state engaged {
			doc /* Atherotomes engaged with plaque, creating incisions */
		}
		
		state deflating {
			doc /* Balloon collapsing, atherotomes retracting */
		}
		
		state withdrawn {
			doc /* Catheter removed from patient */
		}
		
		accept insertionCommand;
		transition idle to navigating;
		
		accept positionConfirmed;
		transition navigating to positioned;
		
		accept inflationCommand;
		transition positioned to inflating;
		
		transition inflating to engaged;
		
		accept deflationCommand;
		transition engaged to deflating;
		
		transition deflating to positioned;
		
		accept withdrawalCommand;
		transition positioned to withdrawn;
		
		accept resetCommand;
		transition withdrawn to idle;
	}
	
	part def CuttingBalloonCatheter {
		doc /* 
			Integrated cutting balloon catheter system for percutaneous transluminal angioplasty.
			
			Primary Function:
			The cutting balloon catheter is a specialized interventional device designed to treat 
			stenotic (narrowed) or calcified vascular lesions through a combination of controlled 
			plaque scoring and balloon dilation. Unlike conventional angioplasty balloons, this 
			system incorporates microsurgical blades (atherotomes) mounted longitudinally on the 
			balloon surface.
			
			During inflation, the balloon expands radially to apply pressure against the vessel wall 
			while simultaneously the atherotomes create precise, controlled longitudinal micro-incisions 
			in the atherosclerotic plaque and fibrous tissue. This dual-action mechanism:
			
			1. Reduces the force required for vessel dilation
			2. Minimizes barotrauma to healthy vessel tissue
			3. Decreases elastic recoil after balloon deflation
			4. Improves acute luminal gain
			5. Enables treatment of resistant, calcified lesions
			
			The system is delivered percutaneously over a guidewire, positioned at the target lesion 
			under fluoroscopic guidance, inflated to nominal pressure for controlled scoring and dilation, 
			then deflated and withdrawn, restoring blood flow through the treated vessel segment.
		*/
		
		part balloon : BalloonMembrane {
			attribute nominalDiameter = 3.0 [mm];
			attribute workingLength = 15.0 [mm];
			attribute burstPressure = 16.0 [atm];
			attribute compliance = 0.05;
			attribute wallThickness = 0.025 [mm];
		}
		
		part atherotomes : Atherotome[3] {
			doc /* Three or four atherotomes distributed evenly around balloon circumference */
			attribute bladeHeight = 0.125 [mm];
			attribute bladeLength = 12.0 [mm];
			attribute sharpness = 0.95;
		}
		
		part shaft : CatheterShaft {
			attribute shaftLength = 1400.0 [mm];
			attribute outerDiameter = 1.02 [mm];
			attribute innerDiameter = 0.36 [mm];
			attribute flexibility = 0.75;
		}
		
		part inflationLumen {
			doc /* Dedicated lumen connecting proximal hub to balloon interior */
			connect shaft.distalTip.mediumFlow to balloon.expansionInterface;
		}
		
		connect balloon.bladeMount to atherotomes;
		
		perform action treatmentProcedure : PerformCuttingAngioplasty;
		exhibit state lifecycle : CuttingBalloonLifecycle;
	}
	
	part cuttingBalloonSystem : CuttingBalloonCatheter {
		doc /* Complete cutting balloon system configured for coronary intervention */
		
		part balloonAssembly : BalloonMembrane;
		part bladeArray : Atherotome[3];
		part deliveryShaft : CatheterShaft;
		part inflationController : InflationDevice {
			attribute maxPressure = 20.0 [atm];
			attribute reservoirVolume = 30.0 [mL];
		}
		
		connect inflationController.inflationControl to deliveryShaft.proximalHub;
		
		perform action angioplastyProcedure : PerformCuttingAngioplasty {
			in attribute lesionLocation = 250.0 [mm];
			in attribute nominalPressure = 10.0 [atm];
			in attribute targetDiameter = 3.0 [mm];
			in attribute dwellDuration = 30.0 [s];
			out attribute procedureSuccess;
			out attribute finalVesselDiameter;
		}
	}
	
	requirement def SafetyRequirement {
		doc /* Safety requirements ensuring patient protection during cutting balloon use */
		subject device : CuttingBalloonCatheter;
		
		require constraint burstPressureSafety {
			doc /* Balloon burst pressure shall exceed maximum rated pressure by safety margin */
			device.balloon.burstPressure >= 1.6 * 10.0 [atm]
		}
		
		require constraint bladePenetrationLimit {
			doc /* Atherotome height shall not exceed safe vessel wall penetration depth */
			device.atherotomes.bladeHeight <= 0.15 [mm]
		}
		
		require constraint biocompatibility {
			doc /* All patient-contacting materials shall be biocompatible per ISO 10993 */
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* Performance requirements for effective lesion treatment */
		subject device : CuttingBalloonCatheter;
		
		require constraint diameterRange {
			doc /* Balloon shall achieve nominal diameter within specified range */
			device.balloon.nominalDiameter >= 2.0 [mm] and 
			device.balloon.nominalDiameter <= 4.0 [mm]
		}
		
		require constraint bladeCount {
			doc /* System shall have three or four evenly distributed atherotomes */
			device.atherotomes->size() >= 3 and 
			device.atherotomes->size() <= 4
		}
		
		require constraint trackability {
			doc /* Catheter shall track through tortuous anatomy */
			device.shaft.flexibility >= 0.7
		}
		
		require constraint crossingProfile {
			doc /* Deflated profile shall enable lesion crossing */
			device.shaft.outerDiameter <= 1.1 [mm]
		}
	}
	
	requirement def ClinicalRequirement {
		doc /* Clinical efficacy requirements for cutting balloon therapy */
		
		require constraint acuteLuminalGain {
			doc /* Procedure shall achieve minimum acute luminal gain */
		}
		
		require constraint residualStenosis {
			doc /* Post-procedure residual stenosis shall be less than 30% */
		}
		
		require constraint proceduralSuccess {
			doc /* Procedure success rate shall exceed 95% for suitable lesions */
		}
	}
	
	requirement systemRequirements {
		doc /* Comprehensive requirements for cutting balloon catheter system */
		
		require safetyReqs : SafetyRequirement;
		require performanceReqs : PerformanceRequirement;
		require clinicalReqs : ClinicalRequirement;
		
		require constraint deliverability {
			doc /* System shall be deliverable through 6F guide catheter */
			cuttingBalloonSystem.shaft.outerDiameter <= 2.0 [mm]
		}
		
		require constraint radiopacity {
			doc /* Balloon markers shall be visible under fluoroscopy */
		}
		
		require constraint shelfLife {
			doc /* Device shall maintain sterility and performance for minimum 2 years */
		}
	}
	
	satisfy systemRequirements by cuttingBalloonSystem;
}
