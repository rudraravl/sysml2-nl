package NasalCannulaOxygenDeliverySystem {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def FlowRateValue :> Real;
	attribute def ConcentrationValue :> Real;
	attribute def SaturationValue :> Real;

	item def Oxygen {
		attribute concentration : ConcentrationValue;
		attribute pressure : Real;
		attribute flowRate : FlowRateValue;
	}

	port def OxygenOutPort {
		out item oxygenSupply : Oxygen;
	}

	port def OxygenInPort {
		in item oxygenIn : Oxygen;
	}

	interface def OxygenDeliveryInterface {
		end supplierPort : OxygenOutPort;
		end consumerPort : OxygenInPort;
	}

	part def OxygenSource {
		port oxygenOutput : OxygenOutPort;
		attribute sourcePressure : Real = 345000.0;
		attribute sourceConcentration : ConcentrationValue = 0.995;
	}

	part def FlowMeter {
		port oxygenInput : OxygenInPort;
		port oxygenOutput : OxygenOutPort;
		attribute setFlowRate : FlowRateValue = 2.0;
		attribute actualFlowRate : FlowRateValue = setFlowRate;
		flow from oxygenInput.oxygenIn to oxygenOutput.oxygenSupply;
	}

	part def OxygenTubing {
		port oxygenInput : OxygenInPort;
		port oxygenOutput : OxygenOutPort;
		attribute length : Real = 2.0;
		attribute innerDiameter : Real = 0.005;
		flow from oxygenInput.oxygenIn to oxygenOutput.oxygenSupply;
	}

	part def NasalCannula {
		port oxygenInput : OxygenInPort;
		port prongOutput : OxygenOutPort;
		attribute prongDiameter : Real = 0.003;
		attribute prongCount : Integer = 2;
		flow from oxygenInput.oxygenIn to prongOutput.oxygenSupply;
	}

	part def Patient {
		port nasalPort : OxygenInPort;
		attribute bloodOxygenSaturation : SaturationValue;
		attribute targetSaturation : SaturationValue = 0.95;
	}

	part def OxygenDeliverySystem {
		part oxygenSource : OxygenSource;
		part flowMeter : FlowMeter;
		part tubing : OxygenTubing;
		part cannula : NasalCannula;
		ref patient : Patient;

		interface : OxygenDeliveryInterface connect
			supplierPort ::> oxygenSource.oxygenOutput to
			consumerPort ::> flowMeter.oxygenInput;

		interface : OxygenDeliveryInterface connect
			supplierPort ::> flowMeter.oxygenOutput to
			consumerPort ::> tubing.oxygenInput;

		interface : OxygenDeliveryInterface connect
			supplierPort ::> tubing.oxygenOutput to
			consumerPort ::> cannula.oxygenInput;

		interface : OxygenDeliveryInterface connect
			supplierPort ::> cannula.prongOutput to
			consumerPort ::> patient.nasalPort;

		state systemState : SystemOperation;
	}

	state def SystemOperation {
		entry;
			then idle;

		state idle;
		transition idle_to_active
			first idle
			accept StartCommand
			then active;

		state active;
		transition active_to_idle
			first active
			accept StopCommand
			then idle;
		transition active_to_alarm
			first active
			accept FaultDetected
			then alarm;

		state alarm;
		transition alarm_to_idle
			first alarm
			accept ResetCommand
			then idle;
	}

	requirement def OxygenTherapyRequirement {
		subject deliverySystem : OxygenDeliverySystem;
		subject pat : Patient;

		require deliverySystem.flowMeter.actualFlowRate >= 0.5;
		require deliverySystem.flowMeter.actualFlowRate <= 5.0;
		require deliverySystem.oxygenSource.sourceConcentration >= 0.90;
		require pat.bloodOxygenSaturation >= pat.targetSaturation;
		require deliverySystem.oxygenSource.sourcePressure <= 500000.0;
	}
}
