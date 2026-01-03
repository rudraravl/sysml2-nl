package 'Microneedle Drug Delivery System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ActivationCommand;
	attribute def DeliveryComplete;
	attribute def PenetrationDepth :> LengthValue;
	attribute def DoseVolume :> VolumeValue;
	
	item def DrugFormulation {
		attribute concentration : Real;
		attribute viscosity : Real;
		attribute volume : VolumeValue;
	}
	
	item def BiologicalFluid;
	
	port def DrugOutPort {
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
		out item drugFlow : DrugFormulation;
	}
	
	port def DrugInPort {
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
		in item drugFlow : DrugFormulation;
	}
	
	port def SkinInterfacePort {
		attribute penetrationDepth : PenetrationDepth;
		attribute temperature : ThermodynamicTemperatureValue;
		in item drugFlow : DrugFormulation;
		out item tissueResponse : BiologicalFluid;
	}
	
	part def DrugReservoir {
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		port outlet : DrugOutPort;
	}
	
	part def MicroPump {
		attribute maxFlowRate : VolumeFlowRateValue;
		attribute operatingPressure : PressureValue;
		port inlet : DrugInPort;
		port outlet : DrugOutPort;
	}
	
	part def MicroneedleArray {
		attribute needleCount : Integer;
		attribute needleLength : LengthValue;
		attribute needleDiameter : LengthValue;
		port drugInlet : DrugInPort;
		port skinInterface : SkinInterfacePort;
	}
	
	part def ControlModule {
		attribute targetDose : DoseVolume;
		attribute deliveryRate : VolumeFlowRateValue;
		attribute deliveredVolume : VolumeValue;
	}
	
	part def FlowSensor {
		attribute measuredFlow : VolumeFlowRateValue;
	}
	
	part def PressureSensor {
		attribute measuredPressure : PressureValue;
	}
	
	action def ApplyPatch {
		in applicationForce : ForceValue;
		out penetrationDepth : PenetrationDepth;
	}
	
	action def PrimePump {
		in primeVolume : VolumeValue;
		out pumpReady : Boolean;
	}
	
	action def ActivatePump {
		in targetPressure : PressureValue;
		out flowRate : VolumeFlowRateValue;
	}
	
	action def TransferDrug {
		in drugInput : DrugFormulation;
		in flowRate : VolumeFlowRateValue;
		out drugOutput : DrugFormulation;
	}
	
	action def MonitorDelivery {
		in currentFlow : VolumeFlowRateValue;
		in currentPressure : PressureValue;
		out deliveredVolume : VolumeValue;
	}
	
	action def AdjustFlow {
		in targetFlow : VolumeFlowRateValue;
		in measuredFlow : VolumeFlowRateValue;
		out adjustedPressure : PressureValue;
	}
	
	action def StopDelivery {
		out shutdownComplete : Boolean;
	}
	
	action def DeliverDrugDose {
		in activationCmd : ActivationCommand;
		in prescribedDose : DoseVolume;
		out totalDelivered : VolumeValue;
		out completionSignal : DeliveryComplete;
		
		first start;
		
		then action applyPatch : ApplyPatch {
			in applicationForce : ForceValue;
			out penetrationDepth : PenetrationDepth;
		}
		
		then action primePump : PrimePump {
			in primeVolume : VolumeValue;
			out pumpReady : Boolean;
		}
		
		then merge deliveryCycle;
		
		action activatePump : ActivatePump {
			in targetPressure : PressureValue;
			out flowRate : VolumeFlowRateValue;
		}
		
		flow activatePump.flowRate to transferDrug.flowRate;
		
		action transferDrug : TransferDrug {
			in drugInput : DrugFormulation;
			in flowRate : VolumeFlowRateValue;
			out drugOutput : DrugFormulation;
		}
		
		flow transferDrug.drugOutput to monitorDelivery.currentFlow;
		
		action monitorDelivery : MonitorDelivery {
			in currentFlow : VolumeFlowRateValue;
			in currentPressure : PressureValue;
			out deliveredVolume : VolumeValue;
		}
		
		then decide;
			if monitorDelivery.deliveredVolume < prescribedDose then adjustFlow;
			if monitorDelivery.deliveredVolume >= prescribedDose then stopDelivery;
		
		action adjustFlow : AdjustFlow {
			in targetFlow : VolumeFlowRateValue;
			in measuredFlow = monitorDelivery.currentFlow;
			out adjustedPressure : PressureValue;
		}
		
		then deliveryCycle;
		
		action stopDelivery : StopDelivery {
			out shutdownComplete : Boolean;
		}
		
		flow monitorDelivery.deliveredVolume to totalDelivered;
		
		then done;
	}
	
	state def DeliverySystemStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_preparing
			first idle
			accept activationCmd : ActivationCommand
			then preparing;
		
		state preparing {
			entry; then applyingPatch;
			
			state applyingPatch;
			
			transition applyingPatch_to_priming
				first applyingPatch
				then priming;
			
			state priming;
		}
		
		transition preparing_to_delivering
			first preparing
			then delivering;
		
		state delivering {
			entry; then pumping;
			
			state pumping;
			
			transition pumping_to_monitoring
				first pumping
				then monitoring;
			
			state monitoring;
			
			transition monitoring_to_adjusting
				first monitoring
				if "deliveredVolume < targetDose"
				then adjusting;
			
			state adjusting;
			
			transition adjusting_to_pumping
				first adjusting
				then pumping;
			
			transition monitoring_to_completing
				first monitoring
				if "deliveredVolume >= targetDose"
				then completing;
			
			state completing;
		}
		
		transition delivering_to_idle
			first delivering
			accept completionSignal : DeliveryComplete
			then idle;
	}
	
	part def MicroneedleDeliverySystem {
		part reservoir : DrugReservoir {
			attribute :>> capacity = 5.0;
			attribute :>> currentLevel = 5.0;
		}
		
		part pump : MicroPump {
			attribute :>> maxFlowRate;
			attribute :>> operatingPressure = 150000.0;
		}
		
		part needleArray : MicroneedleArray {
			attribute :>> needleCount = 100;
			attribute :>> needleLength = 0.0008;
			attribute :>> needleDiameter = 0.00005;
		}
		
		part controller : ControlModule {
			attribute :>> targetDose;
			attribute :>> deliveryRate;
			attribute :>> deliveredVolume;
		}
		
		part flowSensor : FlowSensor;
		
		part pressureSensor : PressureSensor;
		
		connect reservoir.outlet to pump.inlet;
		connect pump.outlet to needleArray.drugInlet;
		
		perform action deliverDose[*] ordered references DeliverDrugDose;
		
		exhibit state operationalStates : DeliverySystemStates;
	}
	
	requirement def SafetyRequirement {
		doc /* The microneedle array shall penetrate skin to a depth not exceeding 
		       1.0 mm to ensure patient safety and minimize pain. */
		
		subject needles : MicroneedleArray;
		
		require constraint {
			needles.needleLength <= 0.001
		}
	}
	
	requirement def DoseAccuracyRequirement {
		doc /* The system shall deliver the prescribed drug dose with an accuracy 
		       of ±3% to ensure therapeutic efficacy. */
		
		subject ctrl : ControlModule;
		
		require constraint {
			ctrl.deliveredVolume >= ctrl.targetDose * 0.97 and
			ctrl.deliveredVolume <= ctrl.targetDose * 1.03
		}
	}
	
	requirement def FlowRateRequirement {
		doc /* The micropump shall maintain a stable flow rate within ±10% of the 
		       target rate throughout the delivery process. */
		
		subject pump : MicroPump;
		
		require constraint {
			pump.maxFlowRate > 0.0
		}
	}
	
	requirement def PenetrationConsistencyRequirement {
		doc /* All microneedles in the array shall penetrate to a uniform depth 
		       with variation not exceeding ±50 micrometers. */
		
		subject needles : MicroneedleArray;
		
		require constraint {
			needles.needleCount > 0
		}
	}
	
	part microneedleSystem : MicroneedleDeliverySystem {
		satisfy SafetyRequirement by needleArray;
		satisfy DoseAccuracyRequirement by controller;
		satisfy FlowRateRequirement by pump;
		satisfy PenetrationConsistencyRequirement by needleArray;
	}
}
