package HeatingPadSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
	attribute def PowerSetting :> ISQ::PowerValue;
	
	enum def HeatLevel {
		enum off;
		enum low;
		enum medium;
		enum high;
	}
	
	item def ElectricalPowerFlow {
		attribute voltage : ISQ::ElectricPotentialDifferenceValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute power : ISQ::PowerValue;
	}
	
	item def ThermalOutput {
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute heatFlowRate : ISQ::HeatFlowRateValue;
	}
	
	item def ControlSignal {
		attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute heatLevel : HeatLevel;
	}
	
	item def SensorReading {
		attribute measuredTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	port def PowerInputPort {
		in item electricalPower : ElectricalPowerFlow;
	}
	
	port def ThermalOutputPort {
		out item thermalEnergy : ThermalOutput;
	}
	
	port def ControlInputPort {
		in item controlCmd : ControlSignal;
	}
	
	port def SensorOutputPort {
		out item sensorData : SensorReading;
	}
	
	port def PowerControlPort {
		out item powerCommand : PowerSetting;
	}
	
	part def TemperatureSensor {
		out port sensorPort : SensorOutputPort;
		attribute accuracy : ISQ::ThermodynamicTemperatureValue := 0.5[SI::K];
		attribute responseTime : ISQ::TimeValue := 2.0[SI::s];
		
		action def MeasureTemperature {
			out reading : SensorReading;
		}
		
		perform action sensing : MeasureTemperature[*] ordered;
	}
	
	part def HeatingElement {
		in port powerPort : PowerInputPort;
		out port thermalPort : ThermalOutputPort;
		attribute resistance : Real := 100.0;
		attribute maxPower : ISQ::PowerValue := 60.0[SI::W];
		attribute efficiency : Real := 0.95;
		
		action def ConvertElectricalToThermal {
			in electricalInput : PowerValue;
			out thermalOutput : HeatFlowRateValue;
		}
		
		perform action heating : ConvertElectricalToThermal[*] ordered;
	}
	
	part def ControllerUnit {
		in port controlIn : ControlInputPort;
		in port feedbackIn : SensorOutputPort;
		out port powerOut : PowerControlPort;
		
		attribute targetTemp : ISQ::ThermodynamicTemperatureValue;
		attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
		attribute temperatureTolerance : ISQ::ThermodynamicTemperatureValue := 1.0[SI::K];
		attribute hysteresis : ISQ::ThermodynamicTemperatureValue := 2.0[SI::K];
		
		state def TemperatureControlStateMachine {
			entry; then off;
			
			state off {
				entry assign powerOut.powerCommand := 0.0[SI::W];
			}
			
			state heating {
				entry assign powerOut.powerCommand := 60.0[SI::W];
			}
			
			state maintaining {
				entry assign powerOut.powerCommand := 25.0[SI::W];
			}
			
			state cooling {
				entry assign powerOut.powerCommand := 0.0[SI::W];
			}
			
			transition off_to_heating
				first off
				accept at controlIn.controlCmd
				if controlIn.controlCmd.heatLevel != HeatLevel::off
				then heating;
			
			transition heating_to_maintaining
				first heating
				if feedbackIn.sensorData.measuredTemperature >= targetTemp - temperatureTolerance
				then maintaining;
			
			transition maintaining_to_heating
				first maintaining
				if feedbackIn.sensorData.measuredTemperature < targetTemp - hysteresis
				then heating;
			
			transition maintaining_to_cooling
				first maintaining
				if feedbackIn.sensorData.measuredTemperature > targetTemp + temperatureTolerance
				then cooling;
			
			transition cooling_to_maintaining
				first cooling
				if feedbackIn.sensorData.measuredTemperature <= targetTemp + temperatureTolerance
				then maintaining;
			
			transition heating_to_off
				first heating
				accept at controlIn.controlCmd
				if controlIn.controlCmd.heatLevel == HeatLevel::off
				then off;
			
			transition maintaining_to_off
				first maintaining
				accept at controlIn.controlCmd
				if controlIn.controlCmd.heatLevel == HeatLevel::off
				then off;
			
			transition cooling_to_off
				first cooling
				accept at controlIn.controlCmd
				if controlIn.controlCmd.heatLevel == HeatLevel::off
				then off;
		}
		
		perform state controlBehavior : TemperatureControlStateMachine;
	}
	
	part def FabricCover {
		in port heatIn : ThermalOutputPort;
		attribute material : String := "Cotton blend";
		attribute thermalConductivity : Real := 0.06;
		attribute surfaceArea : ISQ::AreaValue := 0.15[SI::'m^2'];
		out attribute surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	part def UserInterface {
		out port userControlPort : ControlInputPort;
		in port displayPort : SensorOutputPort;
		
		attribute selectedLevel : HeatLevel := HeatLevel::off;
		attribute displayedTemperature : ISQ::ThermodynamicTemperatureValue;
		
		action def ProcessUserInput {
			in userSelection : HeatLevel;
			out controlSignal : ControlSignal;
		}
		
		perform action userInteraction : ProcessUserInput[*] ordered;
	}
	
	part def PowerSupply {
		out port powerOutput : PowerInputPort;
		attribute inputVoltage : ISQ::ElectricPotentialDifferenceValue := 120.0[SI::V];
		attribute outputVoltage : ISQ::ElectricPotentialDifferenceValue := 24.0[SI::V];
		attribute maxCurrent : ISQ::ElectricCurrentValue := 2.5[SI::A];
		attribute efficiency : Real := 0.88;
	}
	
	part def SafetyCircuit {
		in port tempMonitor : SensorOutputPort;
		out port shutdownSignal : ControlInputPort;
		attribute maxSafeTemperature : ISQ::ThermodynamicTemperatureValue := 333.15[SI::K];
		attribute autoShutoffTime : ISQ::TimeValue := 3600.0[SI::s];
		
		action def MonitorSafety {
			in temperature : ISQ::ThermodynamicTemperatureValue;
			in operationTime : ISQ::TimeValue;
			out safetyCommand : ControlSignal;
		}
		
		perform action safetyMonitoring : MonitorSafety[*] ordered;
	}
	
	part def HeatingPad {
		attribute ratedPower : ISQ::PowerValue := 60.0[SI::W];
		attribute ratedVoltage : ISQ::ElectricPotentialDifferenceValue := 24.0[SI::V];
		attribute maxSurfaceTemperature : ISQ::ThermodynamicTemperatureValue := 333.15[SI::K];
		attribute minOperatingTemperature : ISQ::ThermodynamicTemperatureValue := 293.15[SI::K];
		attribute targetLowTemp : ISQ::ThermodynamicTemperatureValue := 313.15[SI::K];
		attribute targetMediumTemp : ISQ::ThermodynamicTemperatureValue := 318.15[SI::K];
		attribute targetHighTemp : ISQ::ThermodynamicTemperatureValue := 323.15[SI::K];
		
		part powerSupply : PowerSupply;
		part userInterface : UserInterface;
		part controller : ControllerUnit;
		part heatingElement : HeatingElement;
		part temperatureSensor : TemperatureSensor;
		part fabricCover : FabricCover;
		part safetyCircuit : SafetyCircuit;
		
		connect powerSupply.powerOutput to heatingElement.powerPort;
		connect userInterface.userControlPort to controller.controlIn;
		connect temperatureSensor.sensorPort to controller.feedbackIn;
		connect controller.powerOut to heatingElement.powerPort;
		connect heatingElement.thermalPort to fabricCover.heatIn;
		connect temperatureSensor.sensorPort to userInterface.displayPort;
		connect temperatureSensor.sensorPort to safetyCircuit.tempMonitor;
		connect safetyCircuit.shutdownSignal to controller.controlIn;
		
		perform action deliverTherapeuticHeat;
	}
	
	action def DeliverTherapeuticHeat {
		first start;
		then action receiveUserCommand {
			out selectedLevel : HeatLevel;
			out targetTemp : ISQ::ThermodynamicTemperatureValue;
		}
		then merge regulationLoop;
		then action measureCurrentTemperature {
			out currentTemp : ISQ::ThermodynamicTemperatureValue;
		}
		then decide;
			if measureCurrentTemperature.currentTemp < receiveUserCommand.targetTemp - 2.0[SI::K] then applyFullPower;
			if measureCurrentTemperature.currentTemp >= receiveUserCommand.targetTemp - 2.0[SI::K] and 
			   measureCurrentTemperature.currentTemp <= receiveUserCommand.targetTemp + 1.0[SI::K] then applyMaintainingPower;
			if measureCurrentTemperature.currentTemp > receiveUserCommand.targetTemp + 1.0[SI::K] then stopHeating;
		action applyFullPower {
			in powerLevel : ISQ::PowerValue := 60.0[SI::W];
		}
		then regulationLoop;
		action applyMaintainingPower {
			in powerLevel : ISQ::PowerValue := 25.0[SI::W];
		}
		then regulationLoop;
		action stopHeating {
			in powerLevel : ISQ::PowerValue := 0.0[SI::W];
		}
		then regulationLoop;
	}
	
	part heatingPadSystem : HeatingPad {
		perform action deliverTherapeuticHeat references DeliverTherapeuticHeat;
	}
	
	requirement def SafetyRequirement;
	requirement def PerformanceRequirement;
	requirement def UsabilityRequirement;
	
	requirement <'HP-REQ-001'> maxTemperatureSafety : SafetyRequirement {
		doc /* The heating pad surface temperature shall not exceed 60 degrees Celsius (333.15 K) 
		        to prevent burns and ensure user safety during therapeutic use. */
		subject pad : HeatingPad;
		require constraint {
			pad.fabricCover.surfaceTemperature <= pad.maxSurfaceTemperature
		}
	}
	
	requirement <'HP-REQ-002'> autoShutoffSafety : SafetyRequirement {
		doc /* The heating pad shall automatically shut off after 60 minutes of continuous operation 
		        to prevent overheating and reduce fire risk. */
		subject pad : HeatingPad;
		require constraint {
			pad.safetyCircuit.autoShutoffTime == 3600.0[SI::s]
		}
	}
	
	requirement <'HP-REQ-003'> temperatureAccuracy : PerformanceRequirement {
		doc /* The heating pad shall maintain the selected temperature within +/- 1 degree Celsius 
		        of the target temperature during steady-state operation. */
		subject pad : HeatingPad;
		require constraint {
			pad.controller.temperatureTolerance <= 1.0[SI::K]
		}
	}
	
	requirement <'HP-REQ-004'> heatingResponse : PerformanceRequirement {
		doc /* The heating pad shall reach the target temperature within 10 minutes of activation 
		        from room temperature (20 degrees Celsius). */
		subject pad : HeatingPad;
	}
	
	requirement <'HP-REQ-005'> multiLevelControl : UsabilityRequirement {
		doc /* The heating pad shall provide at least three distinct heat level settings 
		        (low, medium, high) plus an off state for user comfort customization. */
		subject pad : HeatingPad;
	}
	
	requirement <'HP-REQ-006'> powerConsumption : PerformanceRequirement {
		doc /* The heating pad shall not exceed 60 watts of power consumption during maximum heat operation. */
		subject pad : HeatingPad;
		require constraint {
			pad.heatingElement.maxPower <= pad.ratedPower
		}
	}
	
	requirement heatingPadMissionRequirement {
		doc /* The heating pad system shall provide controlled, safe therapeutic heat to users 
		        for pain relief, muscle relaxation, and comfort enhancement through precise 
		        temperature regulation and multiple user-selectable heat levels. */
		assume constraint operationalContext {
			doc /* The heating pad is used on appropriate body areas according to manufacturer instructions, 
			        with adequate electrical power supply and in normal indoor environmental conditions. */
		}
		require maxTemperatureSafety;
		require autoShutoffSafety;
		require temperatureAccuracy;
		require heatingResponse;
		require multiLevelControl;
		require powerConsumption;
	}
}
