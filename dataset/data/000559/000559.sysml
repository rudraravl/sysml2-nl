package BubbleOxygenatorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def OxygenSaturation :> Real;
	attribute def CarbonDioxidePartialPressure :> PressureValue;
	attribute def HemoglobinConcentration :> Real;
	
	item def VenousBlood {
		attribute oxygenSaturation : OxygenSaturation;
		attribute co2PartialPressure : CarbonDioxidePartialPressure;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute hemoglobin : HemoglobinConcentration;
	}
	
	item def ArterialBlood :> VenousBlood {
		attribute :>> oxygenSaturation;
		attribute :>> co2PartialPressure;
	}
	
	item def MedicalOxygen {
		attribute flowRate : VolumeFlowRateValue;
		attribute purity : Real;
		attribute pressure : PressureValue;
	}
	
	item def ExhaustGas {
		attribute co2Concentration : Real;
		attribute flowRate : VolumeFlowRateValue;
	}
	
	port def VenousBloodPort {
		in item venousBlood : VenousBlood;
	}
	
	port def ArterialBloodPort {
		out item arterialBlood : ArterialBlood;
	}
	
	port def OxygenSupplyPort {
		in item oxygen : MedicalOxygen;
	}
	
	port def ExhaustPort {
		out item exhaust : ExhaustGas;
	}
	
	part def BubbleGenerationModule {
		port oxygenIn : OxygenSupplyPort;
		
		attribute bubbleDiameter : LengthValue;
		attribute bubbleFrequency : FrequencyValue;
		attribute surfaceAreaPerVolume : Real;
		
		perform action generateBubbles {
			in oxygenSupply : MedicalOxygen;
			out oxygenBubbles[*];
			
			attribute generationRate : Real;
		}
	}
	
	part def OxygenationColumn {
		port bloodIn : VenousBloodPort;
		port bloodOut : ArterialBloodPort;
		
		attribute columnHeight : LengthValue;
		attribute columnDiameter : LengthValue;
		attribute bloodVolume : VolumeValue;
		attribute residenceTime : DurationValue;
		
		part bloodReservoir {
			attribute level : LengthValue;
			attribute capacity : VolumeValue;
		}
		
		perform action facilitateGasExchange {
			in venousBlood : VenousBlood;
			in oxygenBubbles[*];
			out partiallyOxygenatedBlood : ArterialBlood;
			
			attribute contactTime : DurationValue;
			attribute exchangeEfficiency : Real;
		}
	}
	
	part def GasExchangeMembrane {
		attribute surfaceArea : AreaValue;
		attribute permeability : Real;
		
		perform action transferOxygen {
			in bloodSide : VenousBlood;
			in gasSide : MedicalOxygen;
			out oxygenatedBlood : ArterialBlood;
			out depletedGas : ExhaustGas;
			
			attribute oxygenTransferRate : Real;
			attribute co2RemovalRate : Real;
		}
	}
	
	part def DefoamingUnit {
		port bloodIn : VenousBloodPort;
		port bloodOut : ArterialBloodPort;
		port gasOut : ExhaustPort;
		
		attribute defoamingEfficiency : Real;
		
		perform action removeBubbles {
			in oxygenatedBloodWithBubbles : ArterialBlood;
			out bubbleFreeBlood : ArterialBlood;
			out separatedGas : ExhaustGas;
		}
		
		state defoamingStates {
			entry; then idle;
			
			state idle;
			
			state separating {
				entry; then perform removeBubbles;
			}
			
			state venting;
			
			transition first idle to separating;
			transition separating to venting;
			transition venting to separating;
		}
	}
	
	part def TemperatureControlUnit {
		attribute targetTemperature : ThermodynamicTemperatureValue;
		attribute heatingPower : PowerValue;
		attribute coolingPower : PowerValue;
		
		perform action maintainTemperature {
			in bloodFlow : ArterialBlood;
			out temperatureControlledBlood : ArterialBlood;
			
			attribute temperatureDeviation : ThermodynamicTemperatureValue;
		}
	}
	
	part def FlowRegulator {
		attribute setpointFlowRate : VolumeFlowRateValue;
		attribute actualFlowRate : VolumeFlowRateValue;
		
		perform action regulateFlow {
			in measuredFlow : VolumeFlowRateValue;
			out controlSignal : Real;
			
			attribute proportionalGain : Real;
			attribute integralGain : Real;
		}
	}
	
	part def OxygenationMonitor {
		perform action measureOxygenation {
			in bloodSample : ArterialBlood;
			out saturation : OxygenSaturation;
			out co2Level : CarbonDioxidePartialPressure;
		}
		
		perform action assessPerformance {
			in saturation : OxygenSaturation;
			in co2Level : CarbonDioxidePartialPressure;
			out performanceStatus : Real;
		}
	}
	
	part def BubbleOxygenator {
		port venousInlet : VenousBloodPort;
		port arterialOutlet : ArterialBloodPort;
		port oxygenSupply : OxygenSupplyPort;
		port exhaustGasOutlet : ExhaustPort;
		
		part bubbleGenerator : BubbleGenerationModule;
		part oxygenationColumn : OxygenationColumn;
		part gasExchanger : GasExchangeMembrane;
		part defoamer : DefoamingUnit;
		part temperatureControl : TemperatureControlUnit;
		part flowRegulator : FlowRegulator;
		part monitor : OxygenationMonitor;
		
		connection oxygenFeed connect oxygenSupply to bubbleGenerator.oxygenIn;
		connection venousInput connect venousInlet to oxygenationColumn.bloodIn;
		connection oxygenatedFlow connect oxygenationColumn.bloodOut to defoamer.bloodIn;
		connection cleanBloodOutput connect defoamer.bloodOut to arterialOutlet;
		connection exhaustOutput connect defoamer.gasOut to exhaustGasOutlet;
		
		perform action oxygenateBlood {
			first start;
			
			then action admitVenousBlood {
				in venousBlood : VenousBlood;
			}
			
			then action supplyOxygen {
				in oxygenSource : MedicalOxygen;
			}
			
			then merge oxygenationCycle;
			
			then action createBubbles : BubbleGenerationModule::generateBubbles {
				in oxygenSupply = supplyOxygen.oxygenSource;
				out oxygenBubbles[*];
			}
			
			then action introduceBloodToColumn {
				in blood = admitVenousBlood.venousBlood;
			}
			
			then action mixBloodWithBubbles {
				in blood = introduceBloodToColumn.blood;
				in bubbles[*] = createBubbles.oxygenBubbles;
			}
			
			then action exchangeGases : GasExchangeMembrane::transferOxygen {
				in bloodSide = mixBloodWithBubbles.blood;
				in gasSide = supplyOxygen.oxygenSource;
				out oxygenatedBlood : ArterialBlood;
				out depletedGas : ExhaustGas;
			}
			
			then action controlTemperature : TemperatureControlUnit::maintainTemperature {
				in bloodFlow = exchangeGases.oxygenatedBlood;
				out temperatureControlledBlood : ArterialBlood;
			}
			
			then action removeResidualBubbles : DefoamingUnit::removeBubbles {
				in oxygenatedBloodWithBubbles = controlTemperature.temperatureControlledBlood;
				out bubbleFreeBlood : ArterialBlood;
				out separatedGas : ExhaustGas;
			}
			
			then action monitorBloodQuality : OxygenationMonitor::measureOxygenation {
				in bloodSample = removeResidualBubbles.bubbleFreeBlood;
				out saturation : OxygenSaturation;
				out co2Level : CarbonDioxidePartialPressure;
			}
			
			then action evaluatePerformance : OxygenationMonitor::assessPerformance {
				in saturation = monitorBloodQuality.saturation;
				in co2Level = monitorBloodQuality.co2Level;
				out performanceStatus : Real;
			}
			
			then decide;
				if evaluatePerformance.performanceStatus >= 0.95 then deliverArterialBlood;
				if evaluatePerformance.performanceStatus < 0.95 then adjustOxygenation;
			
			action adjustOxygenation : FlowRegulator::regulateFlow {
				in measuredFlow : VolumeFlowRateValue;
				out controlSignal : Real;
			}
			then oxygenationCycle;
			
			action deliverArterialBlood {
				out finalBlood : ArterialBlood = removeResidualBubbles.bubbleFreeBlood;
			}
			
			then done;
		}
	}
	
	requirement def FunctionalRequirement;
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	
	requirement <'REQ-OXY-001'> primaryOxygenationFunction : FunctionalRequirement {
		doc /* 
		The bubble oxygenator shall oxygenate venous blood by introducing fine oxygen bubbles 
		into the blood stream, facilitating gas exchange to achieve arterial-level oxygen saturation 
		while simultaneously removing carbon dioxide.
		*/
		subject oxygenator : BubbleOxygenator;
		
		require constraint {
			oxygenator.monitor.measureOxygenation.saturation >= 95.0
		}
	}
	
	requirement <'REQ-OXY-002'> bubbleEliminationSafety : SafetyRequirement {
		doc /* 
		The defoaming unit shall remove all gas bubbles exceeding 40 micrometers in diameter 
		from the oxygenated blood to prevent gas embolism and ensure patient safety.
		*/
		subject defoamer : DefoamingUnit;
		
		require constraint {
			defoamer.defoamingEfficiency >= 0.999
		}
	}
	
	requirement <'REQ-OXY-003'> temperatureMaintenance : SafetyRequirement {
		doc /* 
		The temperature control unit shall maintain blood temperature within the physiological 
		range of 36.0°C to 37.5°C throughout the oxygenation process to prevent thermal injury.
		*/
		subject tempControl : TemperatureControlUnit;
		
		require constraint {
			tempControl.targetTemperature >= 36.0 and
			tempControl.targetTemperature <= 37.5
		}
	}
	
	requirement <'REQ-OXY-004'> flowRateCapacity : PerformanceRequirement {
		doc /* 
		The bubble oxygenator shall support blood flow rates ranging from 0.5 to 7.0 liters 
		per minute to accommodate pediatric through adult patient requirements.
		*/
		subject flowControl : FlowRegulator;
	}
	
	requirement <'REQ-OXY-005'> gasExchangeEfficiency : PerformanceRequirement {
		doc /* 
		The gas exchange process shall achieve a minimum oxygen transfer efficiency of 90% 
		and carbon dioxide removal efficiency of 85% under normal operating conditions.
		*/
		subject exchanger : GasExchangeMembrane;
	}
	
	requirement systemMission {
		doc /* 
		The bubble oxygenator system shall provide extracorporeal blood oxygenation by 
		generating fine oxygen bubbles that mix with venous blood in a column, enabling 
		efficient gas exchange to produce oxygenated arterial blood while removing all 
		residual bubbles and maintaining physiological temperature.
		*/
		
		assume constraint {
			doc /* Continuous supply of venous blood is available at the inlet. */
		}
		
		assume constraint {
			doc /* Medical-grade oxygen is supplied at regulated pressure and flow. */
		}
		
		require primaryOxygenationFunction;
		require bubbleEliminationSafety;
		require temperatureMaintenance;
		require flowRateCapacity;
		require gasExchangeEfficiency;
	}
}
