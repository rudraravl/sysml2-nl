package RefrigerationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureSetpoint :> ISQ::TemperatureValue;
	attribute def CoolingCapacity :> ISQ::PowerValue;
	attribute def RefrigerantPressure :> ISQ::PressureValue;
	attribute def MassFlowRate :> ISQ::MassValue;
	attribute def CompressorSpeed :> Real;
	
	enum def RefrigerantPhase {
		subcooledLiquid;
		saturatedLiquid;
		liquidVaporMixture;
		saturatedVapor;
		superheatedVapor;
	}
	
	enum def SystemMode {
		off;
		idle;
		cooling;
		defrost;
	}
	
	item def Refrigerant {
		attribute temperature :> ISQ::TemperatureValue;
		attribute pressure :> ISQ::PressureValue;
		attribute massFlow :> MassFlowRate;
		attribute enthalpy :> ISQ::EnergyValue;
		attribute phase : RefrigerantPhase;
	}
	
	port def RefrigerantPort {
		out item refrigerantOut : Refrigerant;
		in item refrigerantIn : Refrigerant;
	}
	
	port def ThermalPort {
		in attribute heatLoad :> ISQ::PowerValue;
		out attribute coolingProvided :> ISQ::PowerValue;
		attribute temperature :> ISQ::TemperatureValue;
	}
	
	port def PowerPort {
		in attribute electricalPower :> ISQ::PowerValue;
		attribute voltage :> Real;
		attribute current :> Real;
	}
	
	port def ControlPort {
		in attribute targetTemperature :> TemperatureSetpoint;
		out attribute actualTemperature :> ISQ::TemperatureValue;
		out attribute compressorCommand : CompressorSpeed;
		in attribute systemMode : SystemMode;
	}
	
	part def Compressor {
		port refrigerantIn : RefrigerantPort;
		port refrigerantOut : RefrigerantPort;
		port electrical : PowerPort;
		attribute speed : CompressorSpeed;
		attribute powerConsumption :> ISQ::PowerValue;
		
		perform action compress {
			in lowPressureVapor : Refrigerant;
			out highPressureVapor : Refrigerant;
			
			action increasePressure {
				in inputPressure : ISQ::PressureValue;
				out outputPressure : ISQ::PressureValue;
			}
			then action increaseTemperature {
				in inputTemp : ISQ::TemperatureValue;
				in compressionRatio : Real;
				out outputTemp : ISQ::TemperatureValue;
			}
			then action increaseEnthalpy {
				in inputEnthalpy : ISQ::EnergyValue;
				in workInput : ISQ::PowerValue;
				out outputEnthalpy : ISQ::EnergyValue;
			}
			then action buildOutput {
				out result : Refrigerant;
			}
		}
	}
	
	part def Condenser {
		port refrigerantIn : RefrigerantPort;
		port refrigerantOut : RefrigerantPort;
		port heatRejection : ThermalPort;
		attribute ambientTemperature :> ISQ::TemperatureValue;
		
		perform action condense {
			in hotVapor : Refrigerant;
			out cooledLiquid : Refrigerant;
			
			action desuperheat {
				in inputTemp : ISQ::TemperatureValue;
				out saturationTemp : ISQ::TemperatureValue;
			}
			then action condenseToSaturated {
				in vaporEnthalpy : ISQ::EnergyValue;
				out liquidEnthalpy : ISQ::EnergyValue;
				out heatRejected : ISQ::PowerValue;
			}
			then action subcool {
				in satTemp : ISQ::TemperatureValue;
				out subcooledTemp : ISQ::TemperatureValue;
			}
			then action buildOutput {
				out result : Refrigerant;
			}
		}
	}
	
	part def ExpansionValve {
		port refrigerantIn : RefrigerantPort;
		port refrigerantOut : RefrigerantPort;
		attribute openingPercentage : Real;
		
		perform action expand {
			in highPressureLiquid : Refrigerant;
			out lowPressureMixture : Refrigerant;
			
			action throttle {
				in inputPressure : ISQ::PressureValue;
				out outputPressure : ISQ::PressureValue;
			}
			then action flashEvaporation {
				in inputEnthalpy : ISQ::EnergyValue;
				out outputTemp : ISQ::TemperatureValue;
				out vaporQuality : Real;
			}
			then action buildOutput {
				out result : Refrigerant;
			}
		}
	}
	
	part def Evaporator {
		port refrigerantIn : RefrigerantPort;
		port refrigerantOut : RefrigerantPort;
		port coolingLoad : ThermalPort;
		attribute internalTemperature :> ISQ::TemperatureValue;
		attribute surfaceArea :> Real;
		
		perform action evaporate {
			in coldMixture : Refrigerant;
			out warmVapor : Refrigerant;
			
			action absorbHeat {
				in heatLoad : ISQ::PowerValue;
				in inletEnthalpy : ISQ::EnergyValue;
				out outletEnthalpy : ISQ::EnergyValue;
				out coolingProvided : ISQ::PowerValue;
			}
			then action evaporateToSaturated {
				in mixturePressure : ISQ::PressureValue;
				out saturationTemp : ISQ::TemperatureValue;
			}
			then action superheat {
				in satTemp : ISQ::TemperatureValue;
				out superheatedTemp : ISQ::TemperatureValue;
			}
			then action buildOutput {
				out result : Refrigerant;
			}
		}
	}
	
	part def TemperatureSensor {
		port sensing : ThermalPort;
		attribute measuredTemperature :> ISQ::TemperatureValue;
		attribute accuracy :> ISQ::TemperatureValue;
		
		perform action measureTemperature {
			in actualTemp : ISQ::TemperatureValue;
			out sensedTemp : ISQ::TemperatureValue;
		}
	}
	
	part def Controller {
		port control : ControlPort;
		attribute setpoint :> TemperatureSetpoint;
		attribute hysteresis :> ISQ::TemperatureValue;
		attribute proportionalGain : Real;
		attribute integralGain : Real;
		
		state machine controlLogic {
			initial state SystemOff;
			
			state SystemIdle;
			
			state ActiveCooling;
			
			state DefrostMode;
			
			transition powerOn first SystemOff then SystemIdle;
			
			transition startCooling first SystemIdle then ActiveCooling;
			
			transition stopCooling first ActiveCooling then SystemIdle;
			
			transition enterDefrost first ActiveCooling then DefrostMode;
			
			transition exitDefrost first DefrostMode then SystemIdle;
			
			transition shutdown first SystemIdle then SystemOff;
		}
		
		perform action regulateTemperature {
			in targetTemp : TemperatureSetpoint;
			in actualTemp : ISQ::TemperatureValue;
			out commandSpeed : CompressorSpeed;
			
			first start;
			then merge controlLoop;
			then action computeError {
				in target : TemperatureSetpoint;
				in actual : ISQ::TemperatureValue;
				out error : Real;
			}
			then decide;
				if computeError.error > 5.0 then maxCooling;
				if computeError.error > 2.0 then moderateCooling;
				if computeError.error >= -2.0 then minimalCooling;
			
			action maxCooling {
				out speed : CompressorSpeed;
			}
			then controlLoop;
			
			action moderateCooling {
				out speed : CompressorSpeed;
			}
			then controlLoop;
			
			action minimalCooling {
				out speed : CompressorSpeed;
			}
			then controlLoop;
		}
	}
	
	part refrigerationSystem {
		part compressor : Compressor;
		part condenser : Condenser;
		part expansionValve : ExpansionValve;
		part evaporator : Evaporator;
		part temperatureSensor : TemperatureSensor;
		part controller : Controller;
		
		port externalPower : PowerPort;
		port compartmentLoad : ThermalPort;
		port ambientEnvironment : ThermalPort;
		
		connection powerSupply connect externalPower to compressor.electrical;
		
		connection refrigerantCycle1 connect 
			compressor.refrigerantOut.refrigerantOut to condenser.refrigerantIn.refrigerantIn;
		connection refrigerantCycle2 connect 
			condenser.refrigerantOut.refrigerantOut to expansionValve.refrigerantIn.refrigerantIn;
		connection refrigerantCycle3 connect 
			expansionValve.refrigerantOut.refrigerantOut to evaporator.refrigerantIn.refrigerantIn;
		connection refrigerantCycle4 connect 
			evaporator.refrigerantOut.refrigerantOut to compressor.refrigerantIn.refrigerantIn;
		
		connection thermalLoad connect compartmentLoad to evaporator.coolingLoad;
		connection heatRejection connect ambientEnvironment to condenser.heatRejection;
		connection temperatureMonitoring connect evaporator.coolingLoad to temperatureSensor.sensing;
		connection controlFeedback connect temperatureSensor.sensing to controller.control;
		
		perform action provideCooling {
			in targetTemperature : TemperatureSetpoint;
			in initialCompartmentTemp : ISQ::TemperatureValue;
			in ambientTemp : ISQ::TemperatureValue;
			in heatLoad : ISQ::PowerValue;
			out finalCompartmentTemp : ISQ::TemperatureValue;
			out totalCoolingDelivered : ISQ::PowerValue;
			
			private attribute compartmentTemp : ISQ::TemperatureValue := initialCompartmentTemp;
			private attribute cycleCount : Integer := 0;
			
			first start;
			then merge continueCooling;
			then action controlCycle : Controller::regulateTemperature {
				in targetTemp = targetTemperature;
				in actualTemp = compartmentTemp;
				out commandSpeed;
			}
			then decide;
				if controlCycle.commandSpeed > 0.0 then runCycle;
			
			action runCycle {
				action compressCycle : Compressor::compress;
				flow compressCycle.highPressureVapor to condenseCycle.hotVapor;
				
				then action condenseCycle : Condenser::condense;
				flow condenseCycle.cooledLiquid to expandCycle.highPressureLiquid;
				
				then action expandCycle : ExpansionValve::expand;
				flow expandCycle.lowPressureMixture to evaporateCycle.coldMixture;
				
				then action evaporateCycle : Evaporator::evaporate;
				
				then action updateTemperature {
					in cooling : ISQ::PowerValue;
					out newTemp : ISQ::TemperatureValue;
				}
				
				then assign compartmentTemp := updateTemperature.newTemp;
				then assign cycleCount := cycleCount + 1;
			}
			then continueCooling;
		}
	}
	
	requirement def CoolingCapacityRequirement {
		doc /* The refrigeration system shall provide sufficient cooling capacity 
		       to maintain the target temperature under maximum heat load conditions. */
		attribute minimumCoolingCapacity :> ISQ::PowerValue;
		attribute maximumHeatLoad :> ISQ::PowerValue;
		require constraint { minimumCoolingCapacity >= maximumHeatLoad }
	}
	
	requirement def TemperatureControlRequirement {
		doc /* The refrigeration system shall maintain the internal temperature 
		       within specified tolerance of the setpoint temperature. */
		attribute temperatureTolerance :> ISQ::TemperatureValue;
		attribute maximumTolerance :> ISQ::TemperatureValue;
		require constraint { temperatureTolerance <= maximumTolerance }
	}
	
	requirement def EnergyEfficiencyRequirement {
		doc /* The refrigeration system shall operate with a coefficient of performance (COP) 
		       meeting or exceeding the minimum specified value under rated conditions. */
		attribute minimumCOP : Real;
		attribute ratedCOP : Real;
		require constraint { ratedCOP >= minimumCOP }
	}
	
	requirement def SafetyRequirement {
		doc /* The refrigeration system shall operate within safe pressure and temperature limits 
		       to prevent component failure and ensure user safety. */
		attribute maximumPressure :> ISQ::PressureValue;
		attribute maximumTemperature :> ISQ::TemperatureValue;
	}
	
	requirement systemRequirements {
		subject refrigerationSystem;
		
		require coolingCapacity : CoolingCapacityRequirement;
		
		require temperatureControl : TemperatureControlRequirement;
		
		require energyEfficiency : EnergyEfficiencyRequirement;
		
		require safety : SafetyRequirement;
	}
}
