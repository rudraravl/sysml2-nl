package 'Tuohy Needle System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NeedleGauge;
	attribute def BevelAngle;
	
	item def AnestheticAgent {
		attribute concentration : Real;
		attribute volume : VolumeValue;
		attribute viscosity : Real;
	}
	
	item def EpiduralCatheter {
		attribute outerDiameter : LengthValue;
		attribute innerDiameter : LengthValue;
		attribute length : LengthValue;
		attribute material : String;
	}
	
	attribute def ResistanceLevel {
		attribute magnitude : PressureValue;
		attribute isLossDetected : Boolean;
	}
	
	attribute def InsertionDepth {
		attribute current : LengthValue;
		attribute target : LengthValue;
	}
	
	port def FluidDeliveryPort {
		in item agent : AnestheticAgent;
		attribute flowRate : VolumeFlowRateValue;
	}
	
	port def CatheterGuidancePort {
		out item catheter : EpiduralCatheter;
		attribute threadingDepth : LengthValue;
	}
	
	port def ResistanceSensingPort {
		out resistance : ResistanceLevel;
		attribute sensitivity : Real;
	}
	
	part def TuohyNeedleAssembly {
		attribute gauge : NeedleGauge;
		attribute totalLength : LengthValue;
		attribute bevelAngle : BevelAngle;
		
		part hub {
			attribute color : String;
			attribute material : String;
			port fluidIntake : FluidDeliveryPort;
			port catheterEntry : CatheterGuidancePort;
		}
		
		part shaft {
			attribute innerDiameter : LengthValue;
			attribute outerDiameter : LengthValue;
			attribute wallThickness : LengthValue;
			attribute depthMarkings : Integer;
		}
		
		part curvedBevelTip {
			attribute curvatureRadius : LengthValue;
			attribute tipAngle : BevelAngle;
			attribute bluntness : Real;
		}
		
		part stylet {
			attribute isPresent : Boolean;
			attribute length : LengthValue;
		}
	}
	
	part def LossOfResistanceSyringe {
		attribute capacity : VolumeValue;
		attribute plungerTravel : LengthValue;
		attribute currentVolume : VolumeValue;
		
		port output : FluidDeliveryPort;
		port resistanceFeedback : ResistanceSensingPort;
	}
	
	part def EpiduralSpace {
		attribute depth : LengthValue;
		attribute pressure : PressureValue;
		attribute isLocated : Boolean;
		attribute width : LengthValue;
	}
	
	part def TissueLayer {
		attribute thickness : LengthValue;
		attribute resistance : PressureValue;
		attribute name : String;
	}
	
	action def PrepareEquipment {
		in needle : TuohyNeedleAssembly;
		in syringe : LossOfResistanceSyringe;
		out readyNeedle : TuohyNeedleAssembly;
		out readySyringe : LossOfResistanceSyringe;
		
		first start;
		then action attachSyringe {
			doc /* Connect loss of resistance syringe to needle hub */
		}
		then action primeSystem {
			doc /* Fill system with saline or air to test patency */
		}
		then action verifyPatency {
			doc /* Confirm fluid flows freely through needle */
		}
		then action removeStylet {
			doc /* Extract stylet from needle shaft */
		}
		then done;
	}
	
	action def AdvanceThroughTissue {
		in needle : TuohyNeedleAssembly;
		in currentDepth : LengthValue;
		in targetLayer : TissueLayer;
		out newDepth : LengthValue;
		out resistanceEncountered : ResistanceLevel;
		
		first start;
		then action incrementalAdvance {
			doc /* Advance needle 1-2mm at a time */
		}
		then action applyPlungerPressure {
			doc /* Apply gentle continuous pressure to syringe plunger */
		}
		then action measureResistance {
			out currentResistance : ResistanceLevel;
		}
		then done;
	}
	
	action def DetectLossOfResistance {
		in resistanceReadings : ResistanceLevel[*];
		in threshold : PressureValue;
		out epiduralSpaceFound : Boolean;
		out detectionDepth : LengthValue;
		
		first start;
		then merge monitoringLoop;
		
		action sampleResistance {
			out reading : ResistanceLevel;
		}
		then decide;
			if sampleResistance.reading.magnitude > threshold then continueMonitoring;
			if sampleResistance.reading.magnitude <= threshold then confirmSpace;
		
		action continueMonitoring;
		then monitoringLoop;
		
		action confirmSpace {
			doc /* Sudden loss of resistance indicates epidural space entry */
		}
		then assign epiduralSpaceFound := true;
		then done;
	}
	
	action def ThreadCatheterThroughNeedle {
		in needle : TuohyNeedleAssembly;
		in catheter : EpiduralCatheter;
		in desiredDepth : LengthValue;
		out catheterPlaced : Boolean;
		out finalDepth : LengthValue;
		
		first start;
		then action insertCatheter {
			doc /* Thread catheter through needle lumen into epidural space */
		}
		then action advanceCatheter {
			doc /* Advance catheter to desired depth beyond needle tip */
		}
		then action stabilizeNeedle {
			doc /* Hold needle position while advancing catheter */
		}
		then action withdrawNeedleOverCatheter {
			doc /* Carefully withdraw needle while maintaining catheter position */
		}
		then action secureCatheter {
			doc /* Fix catheter at skin entry point */
		}
		then assign catheterPlaced := true;
		then done;
	}
	
	state def EpiduralAccessProcedureStates {
		entry; then preparation;
		
		state preparation {
			doc /* Equipment prepared and verified */
		}
		
		transition preparation_to_insertion
			first preparation
			then insertion;
		
		state insertion {
			doc /* Needle being advanced through tissue layers */
			entry; then performInsertion;
			
			action performInsertion : AdvanceThroughTissue;
		}
		
		transition insertion_to_detection
			first insertion
			then detection;
		
		state detection {
			doc /* Monitoring for loss of resistance */
			entry; then detectResistance;
			
			action detectResistance : DetectLossOfResistance;
		}
		
		transition detection_to_insertion_continue
			first detection
			if !detectResistance.epiduralSpaceFound
			then insertion;
		
		transition detection_to_spaceLocated
			first detection
			if detectResistance.epiduralSpaceFound
			then spaceLocated;
		
		state spaceLocated {
			doc /* Epidural space successfully identified */
		}
		
		transition spaceLocated_to_catheterPlacement
			first spaceLocated
			then catheterPlacement;
		
		state catheterPlacement {
			doc /* Catheter being threaded through needle */
			entry; then performThreading;
			
			action performThreading : ThreadCatheterThroughNeedle;
		}
		
		transition catheterPlacement_to_completed
			first catheterPlacement
			if performThreading.catheterPlaced
			then completed;
		
		state completed {
			doc /* Catheter successfully placed in epidural space */
		}
	}
	
	action def PerformEpiduralCatheterPlacement {
		doc /* 
			Primary function: Enable safe identification and access to the epidural space 
			using loss of resistance technique, followed by placement of an epidural catheter 
			for continuous delivery of anesthetic agents. The curved bevel tip design minimizes 
			risk of dural puncture and catheter shearing during the procedure.
		*/
		
		in needleAssembly : TuohyNeedleAssembly;
		in syringe : LossOfResistanceSyringe;
		in catheter : EpiduralCatheter;
		in resistanceThreshold : PressureValue;
		in catheterDepth : LengthValue;
		out procedureSuccess : Boolean;
		out finalCatheterDepth : LengthValue;
		
		private attribute currentDepth : LengthValue := 0.0[mm];
		private attribute spaceFound : Boolean := false;
		
		first start;
		then action prepare : PrepareEquipment {
			in needle = needleAssembly;
			in syringe = syringe;
		}
		then merge advancementCycle;
		
		action advance : AdvanceThroughTissue {
			in needle = prepare.readyNeedle;
			in currentDepth = currentDepth;
		}
		then assign currentDepth := advance.newDepth;
		
		then action detect : DetectLossOfResistance {
			in threshold = resistanceThreshold;
		}
		then assign spaceFound := detect.epiduralSpaceFound;
		
		then decide;
			if !spaceFound then advancementCycle;
			if spaceFound then placeCatheter;
		
		action placeCatheter : ThreadCatheterThroughNeedle {
			in needle = prepare.readyNeedle;
			in catheter = catheter;
			in desiredDepth = catheterDepth;
		}
		then assign procedureSuccess := placeCatheter.catheterPlaced;
		then assign finalCatheterDepth := placeCatheter.finalDepth;
		then done;
	}
	
	part tuohyNeedleSystem {
		doc /* 
			Complete Tuohy needle system for epidural access and catheter placement.
			The system uses a specialized curved bevel needle design to safely navigate 
			tissue planes and identify the epidural space via loss of resistance technique.
		*/
		
		part needle : TuohyNeedleAssembly {
			attribute :>> gauge = 17;
			attribute :>> totalLength = 90.0[mm];
			attribute :>> bevelAngle = 15.0;
			
			part :>> shaft {
				attribute :>> innerDiameter = 1.27[mm];
				attribute :>> outerDiameter = 1.47[mm];
				attribute :>> wallThickness = 0.10[mm];
				attribute :>> depthMarkings = 10;
			}
			
			part :>> curvedBevelTip {
				attribute :>> curvatureRadius = 1.5[mm];
				attribute :>> tipAngle = 15.0;
			}
		}
		
		part syringe : LossOfResistanceSyringe {
			attribute :>> capacity = 10.0[mL];
			attribute :>> plungerTravel = 50.0[mm];
			attribute :>> currentVolume = 5.0[mL];
		}
		
		part catheter : EpiduralCatheter {
			attribute :>> outerDiameter = 1.0[mm];
			attribute :>> innerDiameter = 0.6[mm];
			attribute :>> length = 900.0[mm];
			attribute :>> material = "polyamide";
		}
		
		part targetSpace : EpiduralSpace {
			attribute :>> depth = 45.0[mm];
			attribute :>> pressure = 5000.0[Pa];
			attribute :>> width = 5.0[mm];
		}
		
		part skin : TissueLayer {
			attribute :>> thickness = 2.0[mm];
			attribute :>> resistance = 50000.0[Pa];
			attribute :>> name = "skin";
		}
		
		part subcutaneous : TissueLayer {
			attribute :>> thickness = 15.0[mm];
			attribute :>> resistance = 30000.0[Pa];
			attribute :>> name = "subcutaneous tissue";
		}
		
		part ligamentum : TissueLayer {
			attribute :>> thickness = 5.0[mm];
			attribute :>> resistance = 150000.0[Pa];
			attribute :>> name = "ligamentum flavum";
		}
		
		connect needle.hub.fluidIntake to syringe.output;
		connect needle.hub.catheterEntry to catheter;
		
		perform action epiduralProcedure : PerformEpiduralCatheterPlacement {
			in needleAssembly = needle;
			in syringe = syringe;
			in catheter = catheter;
			in resistanceThreshold = 20000.0[Pa];
			in catheterDepth = 50.0[mm];
		}
	}
	
	requirement <'REQ-001'> primaryFunction {
		doc /* 
			The Tuohy needle system shall enable safe and controlled access to the epidural space 
			for placement of an epidural catheter to facilitate continuous regional anesthesia.
		*/
		
		subject tuohyNeedleSystem;
	}
	
	requirement <'REQ-001.1'> curvedBevelDesign :> primaryFunction {
		doc /* 
			The needle shall incorporate a curved bevel tip (Huber tip) to deflect away from 
			the dura mater and minimize risk of accidental dural puncture.
		*/
	}
	
	requirement <'REQ-001.2'> lossOfResistanceTechnique :> primaryFunction {
		doc /* 
			The system shall provide tactile feedback through loss of resistance detection 
			to confirm entry into the epidural space.
		*/
	}
	
	requirement <'REQ-001.3'> catheterGuidance :> primaryFunction {
		doc /* 
			The needle shall allow threading of an epidural catheter through its lumen 
			without shearing or damaging the catheter material.
		*/
	}
	
	requirement <'REQ-001.4'> depthControl :> primaryFunction {
		doc /* 
			The needle shall provide visible depth markings to enable precise control 
			of insertion depth during the procedure.
		*/
	}
	
	requirement <'REQ-002'> safetyRequirements {
		doc /* 
			The Tuohy needle system shall minimize procedural risks and complications 
			during epidural access.
		*/
	}
	
	requirement <'REQ-002.1'> atraumaticInsertion :> safetyRequirements {
		doc /* 
			The curved bevel shall enable tissue plane separation with minimal trauma 
			to surrounding structures.
		*/
	}
	
	requirement <'REQ-002.2'> duralProtection :> safetyRequirements {
		doc /* 
			The bevel curvature shall direct the needle tip away from the dura to 
			prevent inadvertent dural puncture and post-dural puncture headache.
		*/
	}
	
	requirement <'REQ-002.3'> catheterIntegrity :> safetyRequirements {
		doc /* 
			The needle design shall prevent catheter shearing during insertion 
			and withdrawal procedures.
		*/
	}
	
	requirement <'REQ-003'> functionalPerformance {
		doc /* 
			The Tuohy needle system shall meet specified performance criteria for 
			epidural access procedures.
		*/
	}
	
	requirement <'REQ-003.1'> resistanceDetection :> functionalPerformance {
		doc /* 
			The system shall enable detection of resistance changes with sufficient 
			sensitivity to identify epidural space entry.
		*/
	}
	
	requirement <'REQ-003.2'> catheterPlacementDepth :> functionalPerformance {
		doc /* 
			The system shall allow catheter advancement to a depth of at least 
			40-60mm beyond the needle tip into the epidural space.
		*/
	}
}
