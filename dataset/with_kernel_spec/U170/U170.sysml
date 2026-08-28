package 'Bodok Seal Gas Connection System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;
	
	item def MedicalGas;
	
	attribute def LeakRate :> Real;
	
	part def BodokSealAssembly {
		part nylonWasher {
			attribute material : String = "Nylon";
			attribute thickness : Real;
		}
		part brassRetainingRing {
			attribute material : String = "Brass";
		}
		attribute deformationLevel : Real;
	}
	
	port def GasOutPort {
		out item gas : MedicalGas;
	}
	
	port def GasInPort {
		in item gas : MedicalGas;
	}
	
	part def CylinderValveOutlet {
		port gasOutPort : GasOutPort;
		attribute sealingFaceFlatness : Real;
	}
	
	part def RegulatorInlet {
		port gasInPort : GasInPort;
		attribute sealingFaceFlatness : Real;
	}
	
	part def ConnectionNut {
		attribute appliedTorque :> torque;
		action tighten;
	}
	
	flow def GasFlow {
		ref :>> payload : MedicalGas;
		end port supplierPort : GasOutPort;
		end port consumerPort : GasInPort;
	}
	
	connection def SealingInterface {
		end cylinderFace : CylinderValveOutlet;
		end regulatorFace : RegulatorInlet;
	}
	
	part def BodokGasConnectionSystem {
		attribute maxServicePressure :> pressure = 200e5 [Pa];
		attribute maxLeakRate : LeakRate = 1e-9;
		attribute maxCycles : Integer = 50;
		attribute currentCycles : Integer = 0;
		attribute currentLeakRate : LeakRate = 0;
		attribute currentPressure :> pressure = 0 [Pa];
		
		part cylinderValve : CylinderValveOutlet;
		part regulator : RegulatorInlet;
		part seal : BodokSealAssembly;
		part nut : ConnectionNut;
		
		connection : SealingInterface connect 
			cylinderFace ::> cylinderValve to 
			regulatorFace ::> regulator;
		
		flow : GasFlow of MedicalGas
			from cylinderValve.gasOutPort.gas
			to regulator.gasInPort.gas;
		
		state machine SealLifecycle {
			state Positioning;
			state Compressing;
			state Operating;
			state Degrading;
			state SealFailed;
			
			transition from Positioning to Compressing when nut.appliedTorque > 0 [N*m];
			transition from Compressing to Operating when seal.deformationLevel >= 1.0;
			transition from Operating to Degrading when currentCycles > maxCycles / 2;
			transition from Degrading to SealFailed when currentLeakRate > maxLeakRate;
		}
		
		satisfy reqPressure : SealPerformanceRequirement;
		satisfy reqLeak : LeakRateRequirement;
		satisfy reqReusability : ReusabilityRequirement;
	}
	
	requirement def SealPerformanceRequirement {
		doc /* The system must withstand service pressures up to 200 bar. */
		subject system : BodokGasConnectionSystem;
		assert system.currentPressure <= system.maxServicePressure;
	}
	
	requirement def LeakRateRequirement {
		doc /* The system must maintain an extremely low leak rate. */
		subject system : BodokGasConnectionSystem;
		assert system.currentLeakRate <= system.maxLeakRate;
	}
	
	requirement def ReusabilityRequirement {
		doc /* The seal must be reusable for multiple cycles. */
		subject system : BodokGasConnectionSystem;
		assert system.currentCycles <= system.maxCycles;
	}
}
