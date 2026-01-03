package 'Nasal Cannula Oxygen Delivery System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
	attribute def OxygenConcentrationValue :> Real;
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def TemperatureValue :> ISQ::TemperatureValue;
	attribute def LengthValue :> ISQ::LengthValue;
	
	attribute def StartTherapyCommand;
	attribute def StopTherapyCommand;
	attribute def AdjustFlowCommand;
	attribute def ResetCommand;
	
	item def OxygenGas {
		attribute flowRate : FlowRateValue;
		attribute concentration : OxygenConcentrationValue;
		attribute pressure : PressureValue;
		attribute temperature : TemperatureValue;
	}
	
	item def EnrichedAir {
		attribute oxygenLevel : OxygenConcentrationValue;
	}
	
	port def OxygenSupplyPort {
		out item oxygenFlow : OxygenGas;
	}
	
	port def OxygenDeliveryPort {
		in item oxygenFlow : OxygenGas;
	}
	
	port def PatientInterfacePort {
		out item enrichedAir : EnrichedAir;
	}
	
	port def PatientNasalPort {
		in item enrichedAir : EnrichedAir;
	}
	
	part def OxygenSource {
		doc /* Medical oxygen supply providing high-purity oxygen at regulated pressure. */
		
		attribute sourcePressure : PressureValue;
		attribute sourceConcentration : OxygenConcentrationValue;
		attribute maxFlowCapacity : FlowRateValue;
		
		port supplyPort : OxygenSupplyPort;
	}
	
	part def FlowMeter {
		doc /* Precision flow control device regulating oxygen delivery rate. */
		
		attribute targetFlowRate : FlowRateValue;
		attribute actualFlowRate : FlowRateValue;
		attribute calibrationAccuracy : Real;
		
		port inletPort : OxygenDeliveryPort;
		port outletPort : OxygenSupplyPort;
		
		action def RegulateFlow {
			in sourceFlow : OxygenGas;
			in desiredRate : FlowRateValue;
			out regulatedFlow : OxygenGas;
		}
	}
	
	part def OxygenTubing {
		doc /* Flexible medical-grade tubing transporting oxygen from source to patient. */
		
		attribute tubingLength : LengthValue;
		attribute innerDiameter : LengthValue;
		attribute material : String;
		
		port tubingInlet : OxygenDeliveryPort;
		port tubingOutlet : OxygenSupplyPort;
		
		action def TransportOxygen {
			in inputFlow : OxygenGas;
			out outputFlow : OxygenGas;
		}
	}
	
	part def NasalProng {
		doc /* Soft nasal prong for comfortable oxygen delivery into nostril. */
		
		attribute prongDiameter : LengthValue;
		attribute insertionDepth : LengthValue;
		attribute softness : String;
		
		port prongInlet : OxygenDeliveryPort;
		port nasalOutlet : PatientInterfacePort;
		
		action def DeliverToNostril {
			in oxygenInput : OxygenGas;
			out nasalOutput : EnrichedAir;
		}
	}
	
	part def Patient {
		doc /* Patient receiving supplemental oxygen therapy. */
		
		attribute bloodOxygenSaturation : Real;
		attribute respiratoryRate : ISQ::FrequencyValue;
		attribute nasalCavityVolume : ISQ::VolumeValue;
		
		port leftNostril : PatientNasalPort;
		port rightNostril : PatientNasalPort;
	}
	
	action def MonitorOxygenDelivery {
		in currentFlowRate : FlowRateValue;
		in patientSaturation : Real;
		out deliveryEffectiveness : Real;
	}
	
	action def ProvideOxygenTherapy {
		in prescribedFlowRate : FlowRateValue;
		in targetSaturation : Real;
		out actualSaturation : Real;
		
		first start;
		then accept therapyStart : StartTherapyCommand;
		then merge continuousDelivery;
		
		then action supplyOxygen {
			out sourceGas : OxygenGas;
		}
		
		flow supplyOxygen.sourceGas to regulateFlow.sourceFlow;
		
		then action regulateFlow : FlowMeter::RegulateFlow {
			in sourceFlow : OxygenGas;
			in desiredRate = prescribedFlowRate;
			out regulatedFlow : OxygenGas;
		}
		
		flow regulateFlow.regulatedFlow to transportOxygen.inputFlow;
		
		then action transportOxygen : OxygenTubing::TransportOxygen {
			in inputFlow : OxygenGas;
			out outputFlow : OxygenGas;
		}
		
		flow transportOxygen.outputFlow to deliverLeft.oxygenInput;
		flow transportOxygen.outputFlow to deliverRight.oxygenInput;
		
		then action deliverLeft : NasalProng::DeliverToNostril {
			in oxygenInput : OxygenGas;
			out nasalOutput : EnrichedAir;
		}
		
		then action deliverRight : NasalProng::DeliverToNostril {
			in oxygenInput : OxygenGas;
			out nasalOutput : EnrichedAir;
		}
		
		then action monitorDelivery : MonitorOxygenDelivery {
			in currentFlowRate = regulateFlow.regulatedFlow.flowRate;
			out deliveryEffectiveness : Real;
		}
		
		then decide;
			if monitorDelivery.deliveryEffectiveness >= 0.90 then continuousDelivery;
			if monitorDelivery.deliveryEffectiveness < 0.90 then adjustTherapy;
		
		action adjustTherapy {
			then accept adjustCmd : AdjustFlowCommand;
		}
		then continuousDelivery;
		
		accept therapyStop : StopTherapyCommand;
		then done;
	}
	
	state def TherapyState {
		entry; then idle;
		
		state idle {
			doc /* System ready but not delivering oxygen. */
		}
		
		transition idle_to_active
			first idle
			accept startCommand : StartTherapyCommand
			then active;
		
		state active {
			doc /* Actively delivering oxygen to patient. */
			
			entry; then regulating;
			
			state regulating {
				doc /* Flow rate being controlled. */
			}
			
			transition regulating_to_monitoring
				first regulating
				then monitoring;
			
			state monitoring {
				doc /* Patient response being monitored. */
			}
			
			transition monitoring_to_regulating
				first monitoring
				then regulating;
		}
		
		transition active_to_idle
			first active
			accept stopCommand : StopTherapyCommand
			then idle;
		
		state alarm {
			doc /* System fault detected. */
		}
		
		transition active_to_alarm
			first active
			then alarm;
		
		transition alarm_to_idle
			first alarm
			accept resetCommand : ResetCommand
			then idle;
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The nasal cannula system shall deliver supplemental oxygen to a patient 
		       to increase blood oxygen saturation levels. */
		
		subject nasalCannulaSystem : NasalCannulaSystem;
	}
	
	requirement def FlowRateRequirement {
		doc /* The system shall deliver oxygen at adjustable flow rates 
		       between 0.5 and 6.0 liters per minute. */
		
		require constraint {
			0.5 <= flowRate.value and flowRate.value <= 6.0
		}
	}
	
	requirement def OxygenPurityRequirement {
		doc /* Delivered oxygen shall maintain concentration of at least 90 percent. */
		
		require constraint {
			oxygenConcentration >= 0.90
		}
	}
	
	requirement def PatientComfortRequirement {
		doc /* Nasal prongs shall be designed for patient comfort during extended use. */
		
		subject prongs : NasalProng[2];
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall operate without causing patient harm or discomfort. */
		
		require constraint pressureSafety {
			doc /* Delivery pressure shall not exceed safe nasal cavity limits. */
		}
		
		require constraint flowStability {
			doc /* Flow rate shall remain stable within 10 percent of set value. */
		}
	}
	
	part nasalCannulaSystem : NasalCannulaSystem {
		doc /* Complete nasal cannula oxygen delivery system providing non-invasive 
		       supplemental oxygen therapy to patients with respiratory insufficiency. 
		       The system delivers controlled oxygen flow through soft nasal prongs 
		       inserted into the patient's nostrils, enriching inspired air to 
		       improve blood oxygen saturation. */
		
		satisfy primaryFunction : PrimaryFunctionRequirement;
		satisfy flowRateReq : FlowRateRequirement;
		satisfy purityReq : OxygenPurityRequirement;
		satisfy comfortReq : PatientComfortRequirement;
		satisfy safetyReq : SafetyRequirement;
		
		attribute prescribedFlow : FlowRateValue {
			attribute :>> value = 2.0;
		}
		
		part oxygenSource : OxygenSource {
			attribute :>> sourcePressure {
				attribute :>> value = 345000.0;
			}
			attribute :>> sourceConcentration {
				attribute :>> value = 0.99;
			}
			attribute :>> maxFlowCapacity {
				attribute :>> value = 15.0;
			}
		}
		
		part flowMeter : FlowMeter {
			attribute :>> targetFlowRate {
				attribute :>> value = prescribedFlow.value;
			}
			attribute :>> calibrationAccuracy {
				attribute :>> value = 0.95;
			}
		}
		
		part deliveryTubing : OxygenTubing {
			attribute :>> tubingLength {
				attribute :>> value = 2.1;
			}
			attribute :>> innerDiameter {
				attribute :>> value = 0.004;
			}
			attribute :>> material = "medical-grade PVC";
		}
		
		part leftProng : NasalProng {
			attribute :>> prongDiameter {
				attribute :>> value = 0.003;
			}
			attribute :>> insertionDepth {
				attribute :>> value = 0.006;
			}
			attribute :>> softness = "soft silicone";
		}
		
		part rightProng : NasalProng {
			attribute :>> prongDiameter {
				attribute :>> value = 0.003;
			}
			attribute :>> insertionDepth {
				attribute :>> value = 0.006;
			}
			attribute :>> softness = "soft silicone";
		}
		
		part patient : Patient {
			attribute :>> bloodOxygenSaturation = 92.0;
			attribute :>> respiratoryRate {
				attribute :>> value = 16.0;
			}
		}
		
		connect oxygenSource.supplyPort to flowMeter.inletPort;
		connect flowMeter.outletPort to deliveryTubing.tubingInlet;
		connect deliveryTubing.tubingOutlet to leftProng.prongInlet;
		connect deliveryTubing.tubingOutlet to rightProng.prongInlet;
		connect leftProng.nasalOutlet to patient.leftNostril;
		connect rightProng.nasalOutlet to patient.rightNostril;
		
		perform action therapyDelivery : ProvideOxygenTherapy {
			in prescribedFlowRate = prescribedFlow;
			in targetSaturation = 95.0;
			out actualSaturation => patient.bloodOxygenSaturation;
		}
		
		exhibit state therapyStateMachine : TherapyState;
	}
	
	part def NasalCannulaSystem {
		doc /* Integrated nasal cannula oxygen delivery system. */
	}
}
