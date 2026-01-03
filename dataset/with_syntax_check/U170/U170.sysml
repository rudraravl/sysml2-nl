package 'Bodok Seal Gas Connection System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SealingForce :> ISQ::ForceValue;
	attribute def CompressionDepth :> ISQ::LengthValue;
	attribute def LeakRate :> ISQ::VolumeFlowRateValue;
	attribute def SurfaceRoughness :> ISQ::LengthValue;
	
	item def MedicalGas {
		attribute pressure : ISQ::PressureValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute flowRate : ISQ::VolumeFlowRateValue;
		attribute gasType : String;
	}
	
	attribute def SealCondition {
		attribute isCompressed : Boolean;
		attribute isSealing : Boolean;
		attribute compressionDepth : CompressionDepth;
		attribute contactForce : SealingForce;
	}
	
	part def NylonWasher {
		doc /* Resilient seating element that deforms under compression to create gas-tight seal. */
		attribute thickness : ISQ::LengthValue;
		attribute outerDiameter : ISQ::LengthValue;
		attribute innerDiameter : ISQ::LengthValue;
		attribute maxCompression : ISQ::LengthValue;
		attribute elasticModulus : ISQ::PressureValue;
	}
	
	part def MetalRetainingRing {
		doc /* Metal component that holds nylon washer and provides structural support. */
		attribute material : String;
		attribute hardness : Real;
		attribute outerDiameter : ISQ::LengthValue;
	}
	
	part def BodokSealAssembly {
		doc /* Complete Bodok seal assembly consisting of nylon washer and metal retaining ring. */
		
		part washer : NylonWasher {
			attribute :>> thickness = 2.0[SI::mm];
			attribute :>> outerDiameter = 18.0[SI::mm];
			attribute :>> innerDiameter = 10.0[SI::mm];
			attribute :>> maxCompression = 0.6[SI::mm];
			attribute :>> elasticModulus = 2.8e9[SI::Pa];
		}
		
		part retainingRing : MetalRetainingRing {
			attribute :>> material = "Brass";
			attribute :>> hardness = 80.0;
			attribute :>> outerDiameter = 18.0[SI::mm];
		}
		
		port cylinderInterface {
			attribute sealingSurface : SurfaceRoughness;
			attribute contactArea : ISQ::AreaValue;
		}
		
		port regulatorInterface {
			attribute sealingSurface : SurfaceRoughness;
			attribute contactArea : ISQ::AreaValue;
		}
		
		port gasPassage {
			in item highPressureGas : MedicalGas;
			out item regulatedGas : MedicalGas;
		}
	}
	
	part def CylinderValveOutlet {
		doc /* High-pressure gas cylinder valve outlet with sealing surface. */
		attribute threadType : String;
		attribute sealingSurfaceFinish : SurfaceRoughness;
		attribute nominalPressure : ISQ::PressureValue;
		
		port sealingFace {
			attribute flatness : ISQ::LengthValue;
			attribute surfaceFinish : SurfaceRoughness;
		}
		
		port gasOutput {
			out item gas : MedicalGas;
		}
	}
	
	part def RegulatorInlet {
		doc /* Pressure regulator inlet connection with mating sealing surface. */
		attribute threadType : String;
		attribute sealingSurfaceFinish : SurfaceRoughness;
		attribute maxInputPressure : ISQ::PressureValue;
		
		port sealingFace {
			attribute flatness : ISQ::LengthValue;
			attribute surfaceFinish : SurfaceRoughness;
		}
		
		port gasInput {
			in item gas : MedicalGas;
		}
	}
	
	part def ConnectionNut {
		doc /* Threaded nut that applies compression force to create seal. */
		attribute threadType : String;
		attribute torqueSpecification : ISQ::TorqueValue;
		attribute appliedTorque : ISQ::TorqueValue;
	}
	
	requirement def <'REQ-SEAL-001'> LeakTightnessRequirement {
		doc /* The Bodok seal shall maintain leak-tight seal with leakage rate not exceeding 
		       1.0e-6 standard liters per minute at maximum service pressure. */
		
		subject seal : BodokSealAssembly;
		
		require constraint maxLeakageRate {
			doc /* Maximum allowable leakage rate constraint. */
		}
	}
	
	requirement def <'REQ-SEAL-002'> PressureRatingRequirement {
		doc /* The Bodok seal assembly shall withstand service pressure up to 200 bar 
		       without loss of sealing integrity or structural failure. */
		
		subject seal : BodokSealAssembly;
		
		require constraint {
			seal.gasPassage.highPressureGas.pressure <= 2.0e7[SI::Pa]
		}
	}
	
	requirement def <'REQ-SEAL-003'> ReusabilityRequirement {
		doc /* The Bodok seal shall be reusable for minimum 10 connection cycles 
		       while maintaining sealing performance. */
		
		subject seal : BodokSealAssembly;
	}
	
	requirement def <'REQ-SEAL-004'> MaterialCompatibilityRequirement {
		doc /* All seal materials shall be compatible with medical oxygen and other 
		       medical gases without degradation or contamination. */
		
		subject seal : BodokSealAssembly;
	}
	
	action def PositionSeal {
		in sealAssembly : BodokSealAssembly;
		in cylinderFace : CylinderValveOutlet;
		in regulatorFace : RegulatorInlet;
		out positioned : Boolean;
		out alignment : Real;
	}
	
	action def ApplyCompression {
		in appliedTorque : ISQ::TorqueValue;
		in targetTorque : ISQ::TorqueValue;
		out compressionForce : SealingForce;
		out compressionDepth : CompressionDepth;
		out sealAchieved : Boolean;
	}
	
	action def VerifyLeakTightness {
		in testPressure : ISQ::PressureValue;
		in sealCondition : SealCondition;
		out leakDetected : Boolean;
		out measuredLeakRate : LeakRate;
		out sealIntegrity : Real;
	}
	
	action def MonitorSealPerformance {
		in operatingPressure : ISQ::PressureValue;
		in gasFlow : MedicalGas;
		out currentCondition : SealCondition;
		out degradationLevel : Real;
	}
	
	state def BodokSealLifecycle {
		doc /* State machine representing lifecycle of Bodok seal from installation to removal. */
		
		entry; then Uninstalled;
		
		state Uninstalled;
		
		state Positioned {
			doc /* Seal positioned between mating surfaces but not compressed. */
		}
		
		state Compressing {
			doc /* Compression force being applied to seal. */
		}
		
		state Sealed {
			doc /* Seal fully compressed and leak-tight. */
		}
		
		state Operating {
			doc /* Seal maintaining integrity under gas flow. */
		}
		
		state Degraded {
			doc /* Seal showing signs of wear or reduced performance. */
		}
		
		state Failed {
			doc /* Seal has lost integrity and requires replacement. */
		}
		
		state Removed;
		
		transition first Uninstalled then Positioned;
		transition Positioned then Compressing;
		transition Compressing then Sealed;
		transition Sealed then Operating;
		transition Operating then Sealed;
		transition Operating then Degraded;
		transition Degraded then Operating;
		transition Degraded then Failed;
		transition Sealed then Positioned;
		transition Positioned then Removed;
		transition Failed then Removed;
	}
	
	action def EstablishBodokSeal {
		doc /* Primary action to establish gas-tight seal using Bodok seal assembly. */
		
		in initialPressure : ISQ::PressureValue;
		in targetTorque : ISQ::TorqueValue;
		out finalSealCondition : SealCondition;
		out sealEstablished : Boolean;
		
		first start;
		
		then action positionSeal : PositionSeal {
			out positioned;
			out alignment;
		}
		
		then decide;
			if positionSeal.alignment >= 0.95 then applyCompression;
			if positionSeal.alignment < 0.95 then repositionSeal;
		
		action repositionSeal : PositionSeal {
			out positioned;
			out alignment;
		}
		then applyCompression;
		
		action applyCompression : ApplyCompression {
			in appliedTorque;
			in targetTorque = targetTorque;
			out compressionForce;
			out compressionDepth;
			out sealAchieved;
		}
		
		flow applyCompression.compressionForce to verifySeal.sealCondition.contactForce;
		flow applyCompression.compressionDepth to verifySeal.sealCondition.compressionDepth;
		
		then action verifySeal : VerifyLeakTightness {
			in testPressure = initialPressure;
			in sealCondition;
			out leakDetected;
			out measuredLeakRate;
			out sealIntegrity;
		}
		
		then decide;
			if verifySeal.sealIntegrity >= 0.98 then sealComplete;
			if verifySeal.sealIntegrity < 0.98 and verifySeal.sealIntegrity >= 0.90 then increaseTorque;
			if verifySeal.sealIntegrity < 0.90 then replaceSeal;
		
		action increaseTorque : ApplyCompression {
			in appliedTorque;
			in targetTorque;
			out compressionForce;
			out compressionDepth;
			out sealAchieved;
		}
		then verifySeal;
		
		action replaceSeal {
			doc /* Remove and replace seal assembly. */
		}
		then positionSeal;
		
		action sealComplete {
			doc /* Seal successfully established and verified. */
		}
		then done;
	}
	
	action def MaintainSealIntegrity {
		doc /* Continuous monitoring and maintenance of seal integrity during operation. */
		
		in operatingPressure : ISQ::PressureValue;
		in gasFlow : MedicalGas;
		out sealStatus : SealCondition;
		
		loop {
			action monitorSeal : MonitorSealPerformance {
				in operatingPressure = operatingPressure;
				in gasFlow = gasFlow;
				out currentCondition;
				out degradationLevel;
			}
			
			then action evaluateCondition {
				in condition = monitorSeal.currentCondition;
				in degradation = monitorSeal.degradationLevel;
				out acceptable : Boolean;
			}
			
			then decide;
				if evaluateCondition.acceptable then continueMaintaining;
				if !evaluateCondition.acceptable then alertMaintenance;
			
			action continueMaintaining {
				doc /* Seal condition acceptable, continue monitoring. */
			}
			then monitorSeal;
			
			action alertMaintenance {
				doc /* Seal requires maintenance or replacement. */
			}
			then done;
		}
	}
	
	part bodokSealConnectionSystem {
		doc /* Complete gas connection system utilizing Bodok seal for high-pressure medical gas applications. 
		       Primary function: Create and maintain a reliable, reusable, gas-tight metal-to-metal seal 
		       between a high-pressure gas cylinder valve and a pressure regulator inlet by controlled 
		       compression of a resilient nylon seating element, enabling safe delivery of medical gases 
		       at pressures up to 200 bar while preventing leakage and allowing for repeated 
		       connection/disconnection cycles. */
		
		part cylinderValve : CylinderValveOutlet {
			attribute :>> threadType = "CGA-580";
			attribute :>> sealingSurfaceFinish = 8.0e-7[SI::m];
			attribute :>> nominalPressure = 2.0e7[SI::Pa];
			
			part sealingFace {
				attribute :>> flatness = 1.0e-5[SI::m];
				attribute :>> surfaceFinish = 8.0e-7[SI::m];
			}
		}
		
		part bodokSeal : BodokSealAssembly {
			part :>> washer;
			part :>> retainingRing;
			
			port :>> cylinderInterface {
				attribute :>> sealingSurface = 8.0e-7[SI::m];
				attribute :>> contactArea = 5.0e-5[SI::m^2];
			}
			
			port :>> regulatorInterface {
				attribute :>> sealingSurface = 8.0e-7[SI::m];
				attribute :>> contactArea = 5.0e-5[SI::m^2];
			}
		}
		
		part regulatorInlet : RegulatorInlet {
			attribute :>> threadType = "CGA-580";
			attribute :>> sealingSurfaceFinish = 8.0e-7[SI::m];
			attribute :>> maxInputPressure = 2.0e7[SI::Pa];
			
			part sealingFace {
				attribute :>> flatness = 1.0e-5[SI::m];
				attribute :>> surfaceFinish = 8.0e-7[SI::m];
			}
		}
		
		part connectionNut : ConnectionNut {
			attribute :>> threadType = "CGA-580";
			attribute :>> torqueSpecification = 40.0[SI::N*SI::m];
			attribute :>> appliedTorque = 0.0[SI::N*SI::m];
		}
		
		connection cylinderToSeal connect cylinderValve.sealingFace to bodokSeal.cylinderInterface;
		
		connection sealToRegulator connect bodokSeal.regulatorInterface to regulatorInlet.sealingFace;
		
		connection gasFlow connect cylinderValve.gasOutput to bodokSeal.gasPassage.highPressureGas;
		
		connection regulatedGasFlow connect bodokSeal.gasPassage.regulatedGas to regulatorInlet.gasInput;
		
		perform action establishSeal : EstablishBodokSeal {
			in initialPressure = 2.0e7[SI::Pa];
			in targetTorque = 40.0[SI::N*SI::m];
			out finalSealCondition;
			out sealEstablished;
		}
		
		perform action maintainSeal : MaintainSealIntegrity {
			in operatingPressure = 2.0e7[SI::Pa];
			in gasFlow;
			out sealStatus;
		}
		
		perform state lifecycle : BodokSealLifecycle;
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for Bodok seal connection system. */
		
		require leakTightness : LeakTightnessRequirement {
			subject seal = bodokSealConnectionSystem.bodokSeal;
		}
		
		require pressureRating : PressureRatingRequirement {
			subject seal = bodokSealConnectionSystem.bodokSeal;
		}
		
		require reusability : ReusabilityRequirement {
			subject seal = bodokSealConnectionSystem.bodokSeal;
		}
		
		require materialCompatibility : MaterialCompatibilityRequirement {
			subject seal = bodokSealConnectionSystem.bodokSeal;
		}
	}
	
	action operateBodokSealSystem {
		doc /* High-level operation of complete Bodok seal connection system from installation 
		       through operation to disconnection, demonstrating primary function of creating 
		       reliable gas-tight seal for high-pressure medical gas delivery. */
		
		first start;
		
		then action installSealAssembly {
			doc /* Install Bodok seal assembly onto cylinder valve outlet. */
		}
		
		then action positionRegulator {
			doc /* Position regulator inlet against Bodok seal. */
		}
		
		then action threadConnectionNut {
			doc /* Thread connection nut onto cylinder valve. */
		}
		
		then action applyTorque {
			doc /* Apply specified torque to compress seal and establish metal-to-metal contact. */
			out torque : ISQ::TorqueValue = 40.0[SI::N*SI::m];
		}
		
		flow applyTorque.torque to establishSeal.targetTorque;
		
		then action establishSeal : EstablishBodokSeal {
			in initialPressure = 2.0e7[SI::Pa];
			in targetTorque;
			out finalSealCondition;
			out sealEstablished;
		}
		
		then decide;
			if establishSeal.sealEstablished then openCylinderValve;
			if !establishSeal.sealEstablished then troubleshoot;
		
		action troubleshoot {
			doc /* Diagnose and correct sealing issues. */
		}
		then establishSeal;
		
		action openCylinderValve {
			doc /* Open cylinder valve to allow high-pressure gas flow. */
		}
		
		then action maintainSeal : MaintainSealIntegrity {
			in operatingPressure = 2.0e7[SI::Pa];
			in gasFlow;
			out sealStatus;
		}
		
		then action closeCylinderValve {
			doc /* Close cylinder valve when operation complete. */
		}
		
		then action releaseConnectionTorque {
			doc /* Release connection nut torque to decompress seal. */
		}
		
		then action removeRegulator {
			doc /* Remove regulator from cylinder valve. */
		}
		
		then action inspectSeal {
			doc /* Inspect Bodok seal for wear or damage before reuse. */
			out sealCondition : String;
		}
		
		then done;
	}
}
