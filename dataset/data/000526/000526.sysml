package 'Air Purifier System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AirQualityCommand;
	attribute def PowerCommand;
	attribute def FilterAlert;
	
	attribute def AirQualityIndex :> Real {
		doc /* Air Quality Index measured in micrograms per cubic meter (µg/m³) */
	}
	
	attribute def FilterLifePercentage :> Real {
		doc /* Remaining filter life as percentage from 0 to 100 */
	}
	
	attribute def FanSpeedLevel :> Integer {
		doc /* Fan speed level: 1=Low, 2=Medium, 3=High */
	}
	
	item def ContaminatedAir {
		attribute particulateMatter :> ISQ::mass;
		attribute volatileOrganicCompounds :> Real;
		attribute allergenLevel :> Real;
		attribute dustLevel :> Real;
	}
	
	item def PurifiedAir {
		attribute particulateMatter :> ISQ::mass;
		attribute volatileOrganicCompounds :> Real;
		attribute allergenLevel :> Real;
		attribute dustLevel :> Real;
	}
	
	port def AirIntakePort {
		in item contaminatedAir : ContaminatedAir;
	}
	
	port def AirOutputPort {
		out item purifiedAir : PurifiedAir;
	}
	
	port def PowerSupplyPort {
		in attribute powerInput :> ISQ::power;
	}
	
	port def UserInterfacePort {
		in attribute userCommand : PowerCommand;
		out attribute displayedQuality : AirQualityIndex;
		out attribute displayedFilterLife : FilterLifePercentage;
	}
	
	part def AirQualitySensor {
		port samplePort;
		out attribute measuredQuality : AirQualityIndex;
		
		action measureAirQuality {
			in item airSample : ContaminatedAir;
			out qualityReading : AirQualityIndex;
		}
	}
	
	part def PreFilter {
		port airIn;
		port airOut;
		attribute captureEfficiency : Real;
		
		action captureLargeParticles {
			in item inputAir : ContaminatedAir;
			out item outputAir : ContaminatedAir;
		}
	}
	
	part def HEPAFilter {
		port airIn;
		port airOut;
		attribute filtrationEfficiency : Real;
		attribute remainingLife : FilterLifePercentage;
		
		action filterFineParticles {
			in item inputAir : ContaminatedAir;
			out item outputAir : PurifiedAir;
		}
		
		action trackFilterUsage {
			in attribute operatingTime :> ISQ::time;
			out attribute lifeRemaining : FilterLifePercentage;
		}
	}
	
	part def ActivatedCarbonFilter {
		port airIn;
		port airOut;
		attribute adsorptionCapacity : Real;
		
		action removeGasesAndOdors {
			in item inputAir : PurifiedAir;
			out item outputAir : PurifiedAir;
		}
	}
	
	part def Fan {
		port powerIn : PowerSupplyPort;
		port airIn;
		port airOut;
		in attribute speedCommand : FanSpeedLevel;
		out attribute airFlowRate :> Real;
		attribute currentSpeed : FanSpeedLevel;
		
		action adjustSpeed {
			in attribute targetSpeed : FanSpeedLevel;
			out attribute actualSpeed : FanSpeedLevel;
		}
		
		action moveAir {
			in attribute speed : FanSpeedLevel;
			out attribute flowRate :> Real;
		}
	}
	
	part def ControlUnit {
		port powerIn : PowerSupplyPort;
		in attribute qualityInput : AirQualityIndex;
		in attribute filterLifeInput : FilterLifePercentage;
		in attribute userInput : PowerCommand;
		out attribute fanSpeedOutput : FanSpeedLevel;
		out attribute statusOutput : AirQualityIndex;
		
		exhibit state machine controlLogic {
			in qualityReading : AirQualityIndex;
			in filterLife : FilterLifePercentage;
			out fanSpeed : FanSpeedLevel;
			
			attribute goodAirThreshold : AirQualityIndex = 12.0;
			attribute moderateAirThreshold : AirQualityIndex = 35.5;
			attribute poorAirThreshold : AirQualityIndex = 55.5;
			
			initial state Off;
			
			state Off {
				entry assign fanSpeed := 0;
			}
			transition Off_to_Standby
				first Off
				accept powerOn
				then Standby;
			
			state Standby {
				entry assign fanSpeed := 1;
			}
			transition Standby_to_AutoMode
				first Standby
				accept autoModeSelected
				then AutoMode;
			transition Standby_to_Off
				first Standby
				accept powerOff
				then Off;
			
			state AutoMode {
				do action {
					first action checkQuality {
						in currentQuality = qualityReading;
					}
					then decide;
						if checkQuality.currentQuality > poorAirThreshold then setHighSpeed;
						if checkQuality.currentQuality > moderateAirThreshold and 
						   checkQuality.currentQuality <= poorAirThreshold then setMediumSpeed;
						if checkQuality.currentQuality > goodAirThreshold and 
						   checkQuality.currentQuality <= moderateAirThreshold then setLowSpeed;
						else setStandbySpeed;
					
					action setHighSpeed {
						then assign fanSpeed := 3;
					}
					action setMediumSpeed {
						then assign fanSpeed := 2;
					}
					action setLowSpeed {
						then assign fanSpeed := 1;
					}
					action setStandbySpeed {
						then assign fanSpeed := 1;
					}
				}
			}
			transition AutoMode_to_FilterMaintenance
				first AutoMode
				if filterLife < 10.0
				then FilterMaintenance;
			transition AutoMode_to_Standby
				first AutoMode
				accept manualModeSelected
				then Standby;
			transition AutoMode_to_Off
				first AutoMode
				accept powerOff
				then Off;
			
			state FilterMaintenance {
				entry action alertUser;
			}
			transition FilterMaintenance_to_AutoMode
				first FilterMaintenance
				accept filterReplaced
				then AutoMode;
			transition FilterMaintenance_to_Off
				first FilterMaintenance
				accept powerOff
				then Off;
		}
	}
	
	action def MeasureAirQuality {
		in item airSample : ContaminatedAir;
		out airQuality : AirQualityIndex;
	}
	
	action def DetermineFanSpeed {
		in airQuality : AirQualityIndex;
		out fanSpeed : FanSpeedLevel;
	}
	
	action def FilterAirThroughStages {
		in item contaminatedAir : ContaminatedAir;
		in fanSpeed : FanSpeedLevel;
		out item purifiedAir : PurifiedAir;
	}
	
	action def MonitorFilterLife {
		in operationTime :> ISQ::time;
		out filterLife : FilterLifePercentage;
	}
	
	action def PurifyAir {
		in item inputAir : ContaminatedAir;
		out item outputAir : PurifiedAir;
		out currentQuality : AirQualityIndex;
		out filterStatus : FilterLifePercentage;
		
		first start;
		then merge continuePurification;
		
		then action measureQuality : MeasureAirQuality {
			in item airSample = inputAir;
			out airQuality : AirQualityIndex;
		}
		
		then action determineFan : DetermineFanSpeed {
			in airQuality = measureQuality.airQuality;
			out fanSpeed : FanSpeedLevel;
		}
		
		then action filterProcess : FilterAirThroughStages {
			in item contaminatedAir = inputAir;
			in fanSpeed = determineFan.fanSpeed;
			out item purifiedAir : PurifiedAir;
		}
		
		then action monitorFilter : MonitorFilterLife {
			in operationTime :> ISQ::time;
			out filterLife : FilterLifePercentage;
		}
		
		then assign outputAir := filterProcess.purifiedAir;
		then assign currentQuality := measureQuality.airQuality;
		then assign filterStatus := monitorFilter.filterLife;
		
		then decide;
			if filterStatus >= 10.0 then continuePurification;
			else maintenanceRequired;
		
		action maintenanceRequired;
		then done;
	}
	
	part def AirPurifier {
		doc /* 
			An air purification system that continuously monitors indoor air quality,
			removes airborne contaminants including particulate matter, allergens,
			volatile organic compounds, and odors through multi-stage filtration,
			and automatically adjusts operation to maintain healthy air quality.
		*/
		
		attribute operatingMode : PowerCommand;
		attribute currentAirQuality : AirQualityIndex;
		attribute filterMaintenanceStatus : FilterLifePercentage;
		
		port intakePort : AirIntakePort;
		port outputPort : AirOutputPort;
		port powerPort : PowerSupplyPort;
		port uiPort : UserInterfacePort;
	}
	
	part airPurifier : AirPurifier {
		perform action purifyAir[*] ordered references purificationProcess;
		
		part sensor : AirQualitySensor {
			perform purifyAir.measureQuality;
		}
		
		part controller : ControlUnit {
			perform purifyAir.determineFan;
		}
		
		part preFilter : PreFilter {
			perform purifyAir.filterProcess;
		}
		
		part hepaFilter : HEPAFilter {
			perform purifyAir.filterProcess;
			perform purifyAir.monitorFilter;
		}
		
		part carbonFilter : ActivatedCarbonFilter {
			perform purifyAir.filterProcess;
		}
		
		part fan : Fan {
			perform purifyAir.filterProcess;
		}
		
		connect sensor.measuredQuality to controller.qualityInput;
		connect hepaFilter.remainingLife to controller.filterLifeInput;
		connect controller.fanSpeedOutput to fan.speedCommand;
		connect controller.statusOutput to uiPort.displayedQuality;
		connect hepaFilter.remainingLife to uiPort.displayedFilterLife;
		
		flow intakePort.contaminatedAir to sensor.samplePort;
		flow intakePort.contaminatedAir to preFilter.airIn;
		flow preFilter.airOut to hepaFilter.airIn;
		flow hepaFilter.airOut to carbonFilter.airIn;
		flow carbonFilter.airOut to fan.airIn;
		flow fan.airOut to outputPort.purifiedAir;
		
		connect powerPort to controller.powerIn;
		connect powerPort to fan.powerIn;
	}
	
	action purificationProcess : PurifyAir {
		in item ambientAir : ContaminatedAir;
		out item cleanAir : PurifiedAir;
		out qualityLevel : AirQualityIndex;
		out filterLife : FilterLifePercentage;
	}
	
	requirement def AirPurificationEfficiencyRequirement {
		doc /* The air purifier shall remove at least 99.97% of airborne particles 
		       0.3 micrometers or larger in diameter. */
		
		subject purifier : AirPurifier;
		
		require constraint {
			hepaFilter.filtrationEfficiency >= 99.97
		}
	}
	
	requirement def AirQualityMonitoringRequirement {
		doc /* The system shall continuously monitor air quality and update 
		       measurements at least every 30 seconds. */
		
		subject purifier : AirPurifier;
		
		require constraint {
			sensor.measuredQuality != null
		}
	}
	
	requirement def AutomaticOperationRequirement {
		doc /* The system shall automatically adjust fan speed based on detected 
		       air quality levels to optimize purification performance. */
		
		subject purifier : AirPurifier;
		
		require constraint {
			controller.fanSpeedOutput > 0 when controller.qualityInput > 12.0
		}
	}
	
	requirement def FilterMaintenanceRequirement {
		doc /* The system shall alert users when filter replacement is needed,
		       triggering when remaining filter life drops below 10%. */
		
		subject purifier : AirPurifier;
		
		require constraint {
			uiPort.displayedFilterLife < 10.0 implies filterAlert
		}
	}
	
	requirement def AirFlowRequirement {
		doc /* The system shall provide minimum air flow rate of 200 cubic meters 
		       per hour at maximum fan speed. */
		
		subject purifier : AirPurifier;
		
		require constraint {
			fan.airFlowRate >= 200.0 when fan.currentSpeed == 3
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for air purifier system operation and performance. */
		
		require purificationEfficiency : AirPurificationEfficiencyRequirement;
		require qualityMonitoring : AirQualityMonitoringRequirement;
		require automaticOperation : AutomaticOperationRequirement;
		require filterMaintenance : FilterMaintenanceRequirement;
		require airFlow : AirFlowRequirement;
	}
}
