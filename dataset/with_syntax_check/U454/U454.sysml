package WingedInfusionSetSystem {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	
	item def MedicalFluid {
		attribute viscosity : DynamicViscosityValue;
		attribute temperature : TemperatureValue;
		attribute volume : VolumeValue;
	}
	
	item def InfusedFluid :> MedicalFluid {
		attribute deliveredVolume : VolumeValue;
		attribute flowRate : VolumeFlowRateValue;
	}
	
	item def BloodSample {
		attribute volume : VolumeValue;
		attribute collectionTime : TimeValue;
	}
	
	port def FluidInputPort {
		in item fluid : MedicalFluid;
	}
	
	port def FluidOutputPort {
		out item fluid : InfusedFluid;
	}
	
	port def VascularAccessPort {
		inout item deliveredFluid : InfusedFluid;
		out item bloodSample : BloodSample;
	}
	
	part def NeedleAssembly {
		attribute gaugeSize : Integer;
		attribute needleLength : LengthValue;
		attribute bevelAngle : Real;
		port fluidIn : FluidInputPort;
		port vascularAccess : VascularAccessPort;
	}
	
	part def FlexibleTubing {
		attribute length : LengthValue;
		attribute innerDiameter : LengthValue;
		attribute material : String;
		port proximalEnd : FluidInputPort;
		port distalEnd : FluidOutputPort;
	}
	
	part def WingGrips {
		attribute wingSpan : LengthValue;
		attribute material : String;
		attribute flexibility : Real;
	}
	
	part def LuerConnector {
		attribute connectionType : String;
		attribute threadPitch : LengthValue;
		port fluidIn : FluidInputPort;
		port fluidOut : FluidOutputPort;
	}
	
	part def FlowRegulator {
		attribute maxFlowRate : VolumeFlowRateValue;
		attribute minFlowRate : VolumeFlowRateValue;
		attribute currentSetting : Real;
		port fluidIn : FluidInputPort;
		port fluidOut : FluidOutputPort;
	}
	
	part def SafetyClamp {
		attribute clampPosition : Real;
		attribute occlusionForce : ForceValue;
		port fluidIn : FluidInputPort;
		port fluidOut : FluidOutputPort;
	}
	
	part def Patient {
		attribute patientID : String;
		attribute veinDiameter : LengthValue;
		attribute bloodPressure : PressureValue;
		port vascularAccessPoint : VascularAccessPort;
	}
	
	part def FluidReservoir {
		attribute totalCapacity : VolumeValue;
		attribute remainingVolume : VolumeValue;
		attribute fluidType : String;
		port fluidOutput : FluidOutputPort;
	}
	
	action def PrepareInsertionSite {
		in patient : Patient;
		out sitePrepared : Boolean;
	}
	
	action def InsertNeedleIntoVein {
		in needle : NeedleAssembly;
		in patient : Patient;
		out veinAccessed : Boolean;
		out flashbackObserved : Boolean;
	}
	
	action def SecureInfusionSet {
		in wingGrips : WingGrips;
		in patient : Patient;
		out setSecured : Boolean;
	}
	
	action def AdjustFlowRate {
		in targetRate : VolumeFlowRateValue;
		in regulator : FlowRegulator;
		out actualRate : VolumeFlowRateValue;
	}
	
	action def MonitorInfusion {
		in targetVolume : VolumeValue;
		in deliveredVolume : VolumeValue;
		out completionPercentage : Real;
		out patencyStatus : Boolean;
	}
	
	action def WithdrawBloodSample {
		in needle : NeedleAssembly;
		in sampleVolume : VolumeValue;
		out sample : BloodSample;
	}
	
	action def RemoveInfusionSet {
		in needle : NeedleAssembly;
		in patient : Patient;
		out needleRemoved : Boolean;
		out hemostasisAchieved : Boolean;
	}
	
	state def InfusionLifecycle {
		entry; then Packaged;
		
		state Packaged;
		accept openPackage
		then Prepared;
		
		state Prepared;
		accept needleInserted
		then Inserted;
		
		state Inserted;
		accept flowInitiated
		then Infusing;
		
		state Infusing;
		accept pauseRequested
		then Paused;
		accept volumeDelivered
		then Completed;
		
		state Paused;
		accept resumeRequested
		then Infusing;
		accept discontinueRequested
		then Removed;
		
		state Completed;
		accept setRemoved
		then Removed;
		
		state Removed;
	}
	
	action def PerformIntravenousInfusion {
		first start;
		then action prepareSite : PrepareInsertionSite {
			in patient;
			out sitePrepared;
		}
		then action insertNeedle : InsertNeedleIntoVein {
			in needle;
			in patient;
			out veinAccessed;
			out flashbackObserved;
		}
		then action secureSet : SecureInfusionSet {
			in wingGrips;
			in patient;
			out setSecured;
		}
		then action adjustFlow : AdjustFlowRate {
			in targetRate;
			in regulator;
			out actualRate;
		}
		then merge continueInfusion;
		then action monitorInfusion : MonitorInfusion {
			in targetVolume;
			in deliveredVolume;
			out completionPercentage;
			out patencyStatus;
		}
		then decide;
			if monitorInfusion.completionPercentage < 100.0 and monitorInfusion.patencyStatus == true then maintainFlow;
			if monitorInfusion.completionPercentage >= 100.0 then removeSet;
			if monitorInfusion.patencyStatus == false then troubleshoot;
		action maintainFlow {
			in currentRate = adjustFlow.actualRate;
		}
		then continueInfusion;
		action troubleshoot {
			out issue : String;
		}
		then continueInfusion;
		action removeSet : RemoveInfusionSet {
			in needle;
			in patient;
			out needleRemoved;
			out hemostasisAchieved;
		}
		then done;
	}
	
	part def WingedInfusionSet {
		attribute setIdentifier : String;
		attribute sterile : Boolean;
		attribute expirationDate : String;
		attribute gaugeSize : Integer;
		
		part luerConnector : LuerConnector {
			attribute :>> connectionType = "standard luer lock";
			attribute :>> threadPitch = 0.8 [mm];
			port :>> fluidIn;
			port :>> fluidOut;
		}
		
		part safetyClamp : SafetyClamp {
			attribute :>> clampPosition = 0.0;
			attribute :>> occlusionForce = 5.0 [N];
			port :>> fluidIn;
			port :>> fluidOut;
		}
		
		part flexibleTubing : FlexibleTubing {
			attribute :>> length = 15.0 [cm];
			attribute :>> innerDiameter = 0.9 [mm];
			attribute :>> material = "medical grade PVC";
			port :>> proximalEnd;
			port :>> distalEnd;
		}
		
		part flowRegulator : FlowRegulator {
			attribute :>> maxFlowRate = 200.0 [mL/h];
			attribute :>> minFlowRate = 5.0 [mL/h];
			attribute :>> currentSetting = 0.5;
			port :>> fluidIn;
			port :>> fluidOut;
		}
		
		part wingGrips : WingGrips {
			attribute :>> wingSpan = 20.0 [mm];
			attribute :>> material = "flexible thermoplastic";
			attribute :>> flexibility = 0.8;
		}
		
		part needleAssembly : NeedleAssembly {
			attribute :>> gaugeSize = 23;
			attribute :>> needleLength = 19.0 [mm];
			attribute :>> bevelAngle = 12.0;
			port :>> fluidIn;
			port :>> vascularAccess;
		}
		
		connect luerConnector.fluidOut to safetyClamp.fluidIn;
		connect safetyClamp.fluidOut to flexibleTubing.proximalEnd;
		connect flexibleTubing.distalEnd to flowRegulator.fluidIn;
		connect flowRegulator.fluidOut to needleAssembly.fluidIn;
		
		exhibit state lifecycle : InfusionLifecycle;
	}
	
	part infusionSystem {
		part fluidReservoir : FluidReservoir {
			attribute :>> totalCapacity = 1000.0 [mL];
			attribute :>> remainingVolume = 1000.0 [mL];
			attribute :>> fluidType = "normal saline";
			port :>> fluidOutput;
		}
		
		part wingedSet : WingedInfusionSet {
			attribute :>> setIdentifier = "WIS-2024-001";
			attribute :>> sterile = true;
			attribute :>> expirationDate = "2025-12-31";
			attribute :>> gaugeSize = 23;
		}
		
		part patient : Patient {
			attribute :>> patientID = "PT-98765";
			attribute :>> veinDiameter = 3.5 [mm];
			attribute :>> bloodPressure = 120.0 [mmHg];
			port :>> vascularAccessPoint;
		}
		
		connect fluidReservoir.fluidOutput to wingedSet.luerConnector.fluidIn;
		connect wingedSet.needleAssembly.vascularAccess to patient.vascularAccessPoint;
		
		perform action deliverInfusion : PerformIntravenousInfusion {
			in patient = infusionSystem.patient;
			in needle = infusionSystem.wingedSet.needleAssembly;
			in wingGrips = infusionSystem.wingedSet.wingGrips;
			in regulator = infusionSystem.wingedSet.flowRegulator;
			in targetVolume = 500.0 [mL];
			in targetRate = 100.0 [mL/h];
		}
	}
	
	requirement <'WIS-REQ-001'> primaryFunction {
		doc /* The winged infusion set system shall provide safe, controlled, and reliable 
		       delivery of intravenous fluids or medications from a fluid reservoir into a 
		       patient's peripheral vein, while also enabling blood sample withdrawal when needed. 
		       The system utilizes wing grips for stable insertion, positioning, and securing 
		       during the infusion procedure. */
		
		assume constraint fluidSourceAvailable {
			doc /* A sterile fluid source with adequate volume must be available. */
			infusionSystem.fluidReservoir.remainingVolume > 0.0 [mL]
		}
		
		assume constraint patientVeinAccessible {
			doc /* Patient must have accessible peripheral vein of adequate diameter. */
			infusionSystem.patient.veinDiameter >= 2.0 [mm]
		}
		
		require safeFluidDelivery;
		require controlledFlowRate;
		require easeOfInsertion;
		require systemSterility;
	}
	
	requirement <'WIS-REQ-002'> safeFluidDelivery {
		doc /* The winged infusion set shall safely deliver fluids without causing 
		       infiltration, phlebitis, or air embolism. */
		
		require constraint flowRateLimit {
			doc /* Flow rate must remain within safe physiological limits. */
			infusionSystem.wingedSet.flowRegulator.maxFlowRate <= 250.0 [mL/h] and
			infusionSystem.wingedSet.flowRegulator.minFlowRate >= 1.0 [mL/h]
		}
		
		require constraint needleSizeAppropriate {
			doc /* Needle gauge must be appropriate for peripheral venous access. */
			infusionSystem.wingedSet.needleAssembly.gaugeSize >= 21 and
			infusionSystem.wingedSet.needleAssembly.gaugeSize <= 25
		}
		
		require constraint clampFunctionality {
			doc /* Safety clamp must be capable of complete occlusion. */
			infusionSystem.wingedSet.safetyClamp.occlusionForce >= 3.0 [N]
		}
	}
	
	requirement <'WIS-REQ-003'> controlledFlowRate {
		doc /* The system shall maintain precise control over fluid delivery rate 
		       throughout the infusion procedure. */
		
		require constraint regulatorPrecision {
			doc /* Flow regulator must provide accurate rate adjustment. */
			infusionSystem.wingedSet.flowRegulator.currentSetting >= 0.0 and
			infusionSystem.wingedSet.flowRegulator.currentSetting <= 1.0
		}
		
		require constraint tubingDimensions {
			doc /* Tubing dimensions must support consistent flow characteristics. */
			infusionSystem.wingedSet.flexibleTubing.innerDiameter >= 0.5 [mm] and
			infusionSystem.wingedSet.flexibleTubing.innerDiameter <= 1.5 [mm]
		}
	}
	
	requirement <'WIS-REQ-004'> easeOfInsertion {
		doc /* The winged infusion set shall facilitate easy insertion, positioning, 
		       and stabilization through ergonomic wing grip design. */
		
		require constraint wingGripDimensions {
			doc /* Wing grips must provide adequate surface area for manipulation. */
			infusionSystem.wingedSet.wingGrips.wingSpan >= 15.0 [mm] and
			infusionSystem.wingedSet.wingGrips.wingSpan <= 30.0 [mm]
		}
		
		require constraint wingFlexibility {
			doc /* Wing grips must be sufficiently flexible for patient comfort. */
			infusionSystem.wingedSet.wingGrips.flexibility >= 0.6 and
			infusionSystem.wingedSet.wingGrips.flexibility <= 1.0
		}
		
		require constraint needleBevelAngle {
			doc /* Needle bevel angle must facilitate smooth vein penetration. */
			infusionSystem.wingedSet.needleAssembly.bevelAngle >= 10.0 and
			infusionSystem.wingedSet.needleAssembly.bevelAngle <= 15.0
		}
	}
	
	requirement <'WIS-REQ-005'> systemSterility {
		doc /* The winged infusion set shall maintain sterility of the fluid path 
		       from reservoir to patient until use. */
		
		require constraint sterilityStatus {
			doc /* The infusion set must be sterile before use. */
			infusionSystem.wingedSet.sterile == true
		}
		
		require constraint luerConnection {
			doc /* Luer connector must provide secure, sterile connection. */
			infusionSystem.wingedSet.luerConnector.connectionType == "standard luer lock"
		}
	}
}
