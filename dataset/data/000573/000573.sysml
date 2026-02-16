package 'Cooling Vest System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	doc /* 
	 * This model describes a personal cooling vest system designed to regulate 
	 * body temperature during physical activity or heat exposure. Its primary 
	 * function is to actively remove excess body heat by circulating chilled 
	 * fluid through channels embedded in a wearable garment, maintaining thermal 
	 * comfort for the wearer.
	 * 
	 * The system operates through continuous monitoring and control. A temperature 
	 * sensor measures the wearer's skin temperature, and a controller compares 
	 * this reading against a target comfort temperature. When cooling is needed, 
	 * the controller activates a thermoelectric cooling unit and fluid pump to 
	 * circulate cold fluid through the vest's thermal distribution network. 
	 * The cooled fluid absorbs heat from the body, returns to a reservoir, 
	 * passes through the cooling unit to be rechilled, and repeats the cycle 
	 * until the target temperature is achieved.
	 */
	
	attribute def ControlMode;
	attribute def SystemState;
	attribute def ActivationSignal;
	
	alias FluidTemperature for ISQ::ThermodynamicTemperatureValue;
	alias BodyTemperature for ISQ::ThermodynamicTemperatureValue;
	alias FlowRate for ISQ::VolumeFlowRateValue;
	alias CoolingPower for ISQ::PowerValue;
	alias BatteryCharge for ScalarValues::Real;
	
	item def CoolingFluid {
		attribute temperature : FluidTemperature;
		attribute flowRate : FlowRate;
	}
	
	port def FluidPort {
		out item fluidOut : CoolingFluid;
		in item fluidIn : CoolingFluid;
	}
	
	port def ThermalPort {
		out heatTransfer : ISQ::HeatFlowRateValue;
		in ambientTemp : ISQ::ThermodynamicTemperatureValue;
	}
	
	port def PowerPort {
		out powerSupply : ISQ::PowerValue;
		in powerDemand : ISQ::PowerValue;
	}
	
	port def ControlPort {
		out controlSignal : Real;
		in feedbackSignal : Real;
	}
	
	part def TemperatureSensor {
		attribute reading : BodyTemperature;
		attribute accuracy : ISQ::ThermodynamicTemperatureValue;
		port sensorPort : ThermalPort;
		port dataOut : ControlPort;
	}
	
	part def ControlUnit {
		attribute targetTemperature : BodyTemperature;
		attribute currentTemperature : BodyTemperature;
		attribute tolerance : ISQ::ThermodynamicTemperatureValue;
		attribute mode : ControlMode;
		port sensorInput : ControlPort;
		port pumpControl : ControlPort;
		port coolerControl : ControlPort;
	}
	
	part def FluidPump {
		attribute maxFlowRate : FlowRate;
		attribute commandedFlowRate : FlowRate;
		attribute powerConsumption : ISQ::PowerValue;
		port powerIn : PowerPort;
		port controlIn : ControlPort;
		port fluidInlet : FluidPort;
		port fluidOutlet : FluidPort;
	}
	
	part def ThermoelectricCooler {
		attribute coolingCapacity : CoolingPower;
		attribute operatingVoltage : ISQ::VoltageValue;
		attribute efficiency : Real;
		port powerIn : PowerPort;
		port controlIn : ControlPort;
		port warmFluidIn : FluidPort;
		port coldFluidOut : FluidPort;
		port heatRejection : ThermalPort;
	}
	
	part def FluidReservoir {
		attribute capacity : ISQ::VolumeValue;
		attribute currentVolume : ISQ::VolumeValue;
		attribute fluidTemperature : FluidTemperature;
		port warmFluidIn : FluidPort;
		port coldFluidIn : FluidPort;
		port fluidOut : FluidPort;
	}
	
	part def ThermalDistributionNetwork {
		attribute numberOfChannels : Integer;
		attribute totalLength : ISQ::LengthValue;
		attribute surfaceArea : ISQ::AreaValue;
		port fluidIn : FluidPort;
		port fluidOut : FluidPort;
		port bodyInterface : ThermalPort;
	}
	
	part def BatteryPack {
		attribute totalCapacity : ISQ::EnergyValue;
		attribute remainingCapacity : ISQ::EnergyValue;
		attribute voltage : ISQ::VoltageValue;
		attribute chargeLevel : BatteryCharge;
		port powerOutput : PowerPort;
	}
	
	part def VestGarment {
		attribute size : String;
		attribute weight : ISQ::MassValue;
		port thermalInterface : ThermalPort;
	}
	
	action def MeasureBodyTemperature {
		in sensorReading : BodyTemperature;
		out measuredTemp : BodyTemperature;
	}
	
	action def DetermineCoolingNeed {
		in currentTemp : BodyTemperature;
		in targetTemp : BodyTemperature;
		in tolerance : ISQ::ThermodynamicTemperatureValue;
		out coolingRequired : Boolean;
		out requiredPower : CoolingPower;
	}
	
	action def ActivateCoolingSystem {
		in requiredPower : CoolingPower;
		out pumpFlowRate : FlowRate;
		out coolerPowerLevel : ISQ::PowerValue;
	}
	
	action def CirculateCoolingFluid {
		in flowRate : FlowRate;
		in fluidTemp : FluidTemperature;
		out heatRemoved : ISQ::HeatFlowRateValue;
	}
	
	action def UpdateBodyTemperature {
		in heatRemoved : ISQ::HeatFlowRateValue;
		in currentTemp : BodyTemperature;
		out newTemp : BodyTemperature;
	}
	
	action def DeactivateCoolingSystem;
	
	action def RegulateBodyTemperature {
		in attribute initialBodyTemp : BodyTemperature;
		in attribute targetBodyTemp : BodyTemperature;
		in attribute tempTolerance : ISQ::ThermodynamicTemperatureValue;
		in attribute maxCoolingPower : CoolingPower;
		out attribute temperatureHistory : BodyTemperature[*] := ( );
		
		private attribute bodyTemp : BodyTemperature := initialBodyTemp;
		private attribute systemActive : Boolean := false;
		
		first start;
		then merge monitoringLoop;
		
		action monitoringLoop {
			action measure : MeasureBodyTemperature {
				in sensorReading = bodyTemp;
				out measuredTemp;
			}
			
			then action evaluateCooling : DetermineCoolingNeed {
				in currentTemp = measure.measuredTemp;
				in targetTemp = targetBodyTemp;
				in tolerance = tempTolerance;
				out coolingRequired;
				out requiredPower;
			}
			
			then decide;
				if evaluateCooling.coolingRequired then activateCooling;
				if !evaluateCooling.coolingRequired and systemActive then deactivateCooling;
				if !evaluateCooling.coolingRequired and !systemActive then recordTemperature;
			
			action activateCooling : ActivateCoolingSystem {
				in requiredPower = evaluateCooling.requiredPower;
				out pumpFlowRate;
				out coolerPowerLevel;
			}
			
			then action circulateFluid : CirculateCoolingFluid {
				in flowRate = activateCooling.pumpFlowRate;
				in fluidTemp : FluidTemperature;
				out heatRemoved;
			}
			
			then action updateTemp : UpdateBodyTemperature {
				in heatRemoved = circulateFluid.heatRemoved;
				in currentTemp = bodyTemp;
				out newTemp;
			}
			
			then assign bodyTemp := updateTemp.newTemp;
			then assign systemActive := true;
			then merge recordTemperature;
			
			action deactivateCooling : DeactivateCoolingSystem;
			then assign systemActive := false;
			then merge recordTemperature;
		}
		
		action recordTemperature {
			assign temperatureHistory := temperatureHistory->including(bodyTemp);
		}
		
		then decide;
			if bodyTemp > targetBodyTemp + tempTolerance then monitoringLoop;
			if bodyTemp <= targetBodyTemp + tempTolerance then checkContinue;
		
		action checkContinue;
		then monitoringLoop;
	}
	
	part def CoolingVest {
		attribute targetTemperature : BodyTemperature;
		attribute currentBodyTemperature : BodyTemperature;
		attribute operatingMode : SystemState;
		
		port externalThermal : ThermalPort;
		port activationInterface {
			in activationCmd : ActivationSignal;
			out statusReport : SystemState;
		}
		
		part sensor : TemperatureSensor {
			attribute reading : BodyTemperature;
			attribute accuracy = 0.5[K];
		}
		
		part controller : ControlUnit {
			attribute targetTemperature : BodyTemperature;
			attribute tolerance = 1.0[K];
		}
		
		part pump : FluidPump {
			attribute maxFlowRate = 0.8[L/s];
			attribute powerConsumption = 20.0[W];
		}
		
		part cooler : ThermoelectricCooler {
			attribute coolingCapacity = 200.0[W];
			attribute operatingVoltage = 12.0[V];
			attribute efficiency = 0.75;
		}
		
		part reservoir : FluidReservoir {
			attribute capacity = 2.5[L];
			attribute currentVolume = 2.5[L];
		}
		
		part distributionNetwork : ThermalDistributionNetwork {
			attribute numberOfChannels = 12;
			attribute totalLength = 6.0[m];
			attribute surfaceArea = 0.4[m^2];
		}
		
		part battery : BatteryPack {
			attribute totalCapacity = 600.0[W*h];
			attribute voltage = 12.0[V];
			attribute chargeLevel = 1.0;
		}
		
		part garment : VestGarment {
			attribute size = "Medium";
			attribute weight = 1.2[kg];
		}
		
		connect battery.powerOutput to pump.powerIn;
		connect battery.powerOutput to cooler.powerIn;
		connect controller.sensorInput to sensor.dataOut;
		connect controller.pumpControl to pump.controlIn;
		connect controller.coolerControl to cooler.controlIn;
		connect pump.fluidOutlet to distributionNetwork.fluidIn;
		connect distributionNetwork.fluidOut to reservoir.warmFluidIn;
		connect reservoir.fluidOut to cooler.warmFluidIn;
		connect cooler.coldFluidOut to reservoir.coldFluidIn;
		connect reservoir.fluidOut to pump.fluidInlet;
		connect distributionNetwork.bodyInterface to sensor.sensorPort;
		connect garment.thermalInterface to distributionNetwork.bodyInterface;
	}
	
	part coolingVestSystem : CoolingVest {
		attribute targetTemperature = 293.15[K];
		attribute currentBodyTemperature = 308.15[K];
		
		perform action regulateTemp[*] ordered : RegulateBodyTemperature {
			in initialBodyTemp = currentBodyTemperature;
			in targetBodyTemp = targetTemperature;
			in tempTolerance = controller.tolerance;
			in maxCoolingPower = cooler.coolingCapacity;
			out temperatureHistory;
		}
		
		part sensor : TemperatureSensor {
			perform regulateTemp.measure;
		}
		
		part controller : ControlUnit {
			perform regulateTemp.evaluateCooling;
		}
		
		part pump : FluidPump {
			perform regulateTemp.circulateFluid;
		}
		
		part cooler : ThermoelectricCooler {
			perform regulateTemp.activateCooling;
		}
	}
	
	requirement def ThermalComfortRequirement {
		doc /* The cooling vest shall maintain the wearer's body temperature 
		       within a comfortable range during operation. */
	}
	
	requirement def CoolingPerformanceRequirement {
		doc /* The cooling vest shall provide adequate cooling power to 
		       counteract metabolic heat generation. */
	}
	
	requirement def OperationalDurationRequirement {
		doc /* The cooling vest shall operate continuously for a minimum 
		       duration on a single battery charge. */
	}
	
	requirement def SafetyRequirement {
		doc /* The cooling vest shall operate safely without risk of 
		       hypothermia or electrical hazard. */
	}
	
	requirement <'R-001'> maintainComfortTemperature : ThermalComfortRequirement {
		doc /* The system shall maintain body temperature between 291K and 297K. */
		
		require constraint temperatureRange {
			291.15[K] <= coolingVestSystem.currentBodyTemperature and
			coolingVestSystem.currentBodyTemperature <= 297.15[K]
		}
	}
	
	requirement <'R-002'> provideCoolingPower : CoolingPerformanceRequirement {
		doc /* The system shall provide at least 150W of cooling power. */
		
		require constraint minimumCoolingCapacity {
			coolingVestSystem.cooler.coolingCapacity >= 150.0[W]
		}
	}
	
	requirement <'R-003'> operateForMinimumDuration : OperationalDurationRequirement {
		doc /* The system shall operate for at least 4 hours continuously. */
		
		require constraint minimumBatteryCapacity {
			coolingVestSystem.battery.totalCapacity >= 500.0[W*h]
		}
	}
	
	requirement <'R-004'> ensureSafeOperation : SafetyRequirement {
		doc /* The system shall prevent body temperature from dropping below 288K. */
		
		require constraint minimumSafeTemperature {
			coolingVestSystem.currentBodyTemperature >= 288.15[K]
		}
	}
	
	requirement <'R-SYS-001'> coolingVestSystemRequirement {
		doc /* The cooling vest system shall provide thermal comfort by actively 
		       regulating body temperature through controlled fluid circulation. */
		
		assume constraint wearerActivity {
			doc /* The wearer is engaged in moderate to high physical activity 
			       generating excess metabolic heat. */
		}
		
		require maintainComfortTemperature;
		require provideCoolingPower;
		require operateForMinimumDuration;
		require ensureSafeOperation;
	}
}
