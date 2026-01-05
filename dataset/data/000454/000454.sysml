package HeatPenSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
	attribute def PowerLevel :> ISQ::PowerValue;
	attribute def ControlMode;
	attribute def TipPressureLevel :> ISQ::PressureValue;
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def ThermalEnergy {
		attribute heatFlow : ISQ::PowerValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	item def ControlSignal {
		attribute commandValue : Real;
	}
	
	port def PowerPort {
		out item electricalPower : ElectricalPower;
	}
	
	port def ThermalPort {
		out item thermalOutput : ThermalEnergy;
	}
	
	port def ControlPort {
		in item controlInput : ControlSignal;
	}
	
	port def SensorPort {
		out item sensorData : ThermalEnergy;
	}
	
	part def PowerSupplyUnit {
		attribute inputVoltage : ISQ::ElectricPotentialValue;
		attribute outputVoltage : ISQ::ElectricPotentialValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		port powerInput : PowerPort;
		port powerOutput : PowerPort;
	}
	
	part def ControllerModule {
		attribute setpoint : TemperatureSetpoint;
		attribute currentMode : ControlMode;
		attribute pidGain : Real;
		port powerIn : PowerPort;
		port controlOut : ControlPort;
		port sensorIn : SensorPort;
		port powerControl : PowerPort;
		perform action regulateTemperature[*] ordered;
	}
	
	part def HeatingElementAssembly {
		attribute resistance : ISQ::ElectricResistanceValue;
		attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute thermalMass : ISQ::HeatCapacityValue;
		port electricalIn : PowerPort;
		port thermalOut : ThermalPort;
		port sensorOut : SensorPort;
	}
	
	part def TipModule {
		attribute tipMaterial : String;
		attribute tipGeometry : String;
		attribute thermalConductivity : ISQ::ThermalConductivityValue;
		attribute workingTemperature : ISQ::ThermodynamicTemperatureValue;
		port thermalIn : ThermalPort;
		port applicationSurface : ThermalPort;
	}
	
	part def PressureSensorAssembly {
		attribute activationThreshold : ISQ::PressureValue;
		attribute sensitivity : Real;
		port pressureInput;
		port sensorOutput : SensorPort;
	}
	
	part def UserInterfacePanel {
		attribute displayType : String;
		attribute numberOfModes : Integer;
		port modeSelection : ControlPort;
		port temperatureAdjust : ControlPort;
		port statusDisplay;
	}
	
	part def HeatPen {
		doc /* A precision thermal tool for applying controlled heat to materials for soldering, crafting, or thermal bonding applications. */
		
		attribute operatingVoltage : ISQ::ElectricPotentialValue = 12.0[SI::V];
		attribute maxOperatingTemp : ISQ::ThermodynamicTemperatureValue = 723.15[SI::K];
		attribute ambientTemp : ISQ::ThermodynamicTemperatureValue = 298.15[SI::K];
		attribute heatingPower : ISQ::PowerValue = 60.0[SI::W];
		
		port externalPowerConnection : PowerPort;
		port workSurfaceInterface : ThermalPort;
		
		part powerSupply : PowerSupplyUnit {
			attribute inputVoltage = 120.0[SI::V];
			attribute outputVoltage = 12.0[SI::V];
			attribute maxCurrent = 5.0[SI::A];
		}
		
		part controller : ControllerModule {
			attribute setpoint : TemperatureSetpoint = 623.15[SI::K];
			attribute pidGain = 0.8;
		}
		
		part heatingElement : HeatingElementAssembly {
			attribute resistance = 2.4[SI::Ω];
			attribute maxTemperature = 773.15[SI::K];
			attribute thermalMass = 15.0[SI::'J/K'];
		}
		
		part tip : TipModule {
			attribute tipMaterial = "Copper-Iron Alloy";
			attribute tipGeometry = "Conical";
			attribute thermalConductivity = 50.0[SI::'W/(m·K)'];
			attribute workingTemperature = 623.15[SI::K];
		}
		
		part pressureSensor : PressureSensorAssembly {
			attribute activationThreshold = 30000.0[SI::Pa];
			attribute sensitivity = 0.95;
		}
		
		part userInterface : UserInterfacePanel {
			attribute displayType = "LED";
			attribute numberOfModes = 5;
		}
		
		connect externalPowerConnection to powerSupply.powerInput;
		connect powerSupply.powerOutput to controller.powerIn;
		connect controller.powerControl to heatingElement.electricalIn;
		connect heatingElement.thermalOut to tip.thermalIn;
		connect tip.applicationSurface to workSurfaceInterface;
		connect heatingElement.sensorOut to controller.sensorIn;
		connect pressureSensor.sensorOutput to controller.sensorIn;
		connect userInterface.modeSelection to controller.controlOut;
		connect userInterface.temperatureAdjust to controller.controlOut;
		
		exhibit state operationStateMachine;
	}
	
	state def operationStateMachine {
		entry; then idle;
		
		state idle {
			doc /* System is powered but not heating. */
		}
		
		state standby {
			doc /* System is ready and monitoring for activation. */
		}
		
		state preheating {
			doc /* System is actively heating to reach target temperature. */
		}
		
		state operational {
			doc /* System maintains target temperature during use. */
		}
		
		state cooldown {
			doc /* System is cooling after use. */
		}
		
		state fault {
			doc /* System has detected an error condition. */
		}
		
		transition idle_to_standby
			first idle
			accept powerOn
			then standby;
		
		transition standby_to_preheating
			first standby
			accept tipPressureDetected
			then preheating;
		
		transition preheating_to_operational
			first preheating
			accept targetTempReached
			then operational;
		
		transition operational_to_cooldown
			first operational
			accept tipPressureReleased
			then cooldown;
		
		transition operational_to_fault
			first operational
			accept overtemperatureDetected
			then fault;
		
		transition cooldown_to_standby
			first cooldown
			accept cooledToSafe
			then standby;
		
		transition fault_to_idle
			first fault
			accept faultCleared
			then idle;
		
		transition standby_to_idle
			first standby
			accept powerOff
			then idle;
	}
	
	action def TemperatureRegulation {
		in targetTemperature : ISQ::ThermodynamicTemperatureValue;
		in measuredTemperature : ISQ::ThermodynamicTemperatureValue;
		in pressureApplied : Boolean;
		out heatingPower : ISQ::PowerValue;
		
		first start;
		then merge controlLoop;
		
		action controlLoop {
			action checkPressure {
				in pressure : Boolean;
				out active : Boolean;
			}
			
			then decide;
				if checkPressure.active then calculatePower;
				if !checkPressure.active then shutdownPower;
			
			action calculatePower {
				action computeError {
					in target : ISQ::ThermodynamicTemperatureValue;
					in current : ISQ::ThermodynamicTemperatureValue;
					out error : ISQ::ThermodynamicTemperatureValue;
				}
				
				then action determinePower {
					in tempError : ISQ::ThermodynamicTemperatureValue;
					out power : ISQ::PowerValue;
				}
			}
			then controlLoop;
			
			action shutdownPower;
			then controlLoop;
		}
	}
	
	action def ApplyHeat {
		in desiredTemperature : ISQ::ThermodynamicTemperatureValue;
		in applicationDuration : ISQ::TimeValue;
		in workpieceMaterial : String;
		out energyDelivered : ISQ::EnergyValue;
		
		private attribute elapsedTime : ISQ::TimeValue := 0.0[SI::s];
		private attribute currentTemp : ISQ::ThermodynamicTemperatureValue := 298.15[SI::K];
		private attribute totalEnergy : ISQ::EnergyValue := 0.0[SI::J];
		
		first start;
		then action initializeHeating;
		
		then merge heatingCycle;
		
		action heatingCycle {
			action measureTemperature {
				out temp : ISQ::ThermodynamicTemperatureValue;
			}
			
			then decide;
				if measureTemperature.temp < desiredTemperature then increaseHeat;
				if measureTemperature.temp >= desiredTemperature then maintainHeat;
			
			action increaseHeat {
				action applyFullPower {
					in power : ISQ::PowerValue := 60.0[SI::W];
					in deltaTime : ISQ::TimeValue := 0.1[SI::s];
					out tempIncrease : ISQ::ThermodynamicTemperatureValue;
					out energyUsed : ISQ::EnergyValue;
				}
			}
			then checkDuration;
			
			action maintainHeat {
				action applyRegulatedPower {
					in power : ISQ::PowerValue := 35.0[SI::W];
					in deltaTime : ISQ::TimeValue := 0.1[SI::s];
					out energyUsed : ISQ::EnergyValue;
				}
			}
			then checkDuration;
			
			action checkDuration {
				decide;
					if elapsedTime < applicationDuration then heatingCycle;
					if elapsedTime >= applicationDuration then complete;
			}
		}
		
		action complete;
		then done;
	}
	
	requirement def <'REQ-HP-001'> PrimaryFunctionRequirement {
		doc /* The heat pen shall deliver controlled thermal energy to a work surface for precision heating applications. */
		subject heatPen : HeatPen;
		require constraint {
			heatPen.heatingPower >= 40.0[SI::W] && heatPen.heatingPower <= 80.0[SI::W]
		}
	}
	
	requirement def <'REQ-HP-002'> TemperatureControlRequirement {
		doc /* The heat pen shall maintain tip temperature within 5K of the setpoint during operation. */
		subject heatPen : HeatPen;
		require constraint {
			heatPen.tip.workingTemperature >= heatPen.controller.setpoint - 5.0[SI::K] &&
			heatPen.tip.workingTemperature <= heatPen.controller.setpoint + 5.0[SI::K]
		}
	}
	
	requirement def <'REQ-HP-003'> SafetyRequirement {
		doc /* The heat pen shall not exceed maximum safe operating temperature under any condition. */
		subject heatPen : HeatPen;
		require constraint {
			heatPen.heatingElement.maxTemperature <= 773.15[SI::K]
		}
	}
	
	requirement def <'REQ-HP-004'> ActivationRequirement {
		doc /* The heat pen shall activate heating only when tip pressure is detected. */
		subject heatPen : HeatPen;
	}
	
	requirement def <'REQ-HP-005'> ResponseTimeRequirement {
		doc /* The heat pen shall reach operating temperature within 30 seconds from activation. */
		subject heatPen : HeatPen;
	}
	
	requirement def <'REQ-HP-006'> PowerEfficiencyRequirement {
		doc /* The heat pen shall operate with electrical efficiency greater than 85 percent. */
		subject heatPen : HeatPen;
		require constraint {
			heatPen.heatingPower / (heatPen.operatingVoltage * heatPen.powerSupply.maxCurrent) >= 0.85
		}
	}
	
	part heatPenInstance : HeatPen {
		satisfy <'REQ-HP-001'> by heatPenInstance;
		satisfy <'REQ-HP-002'> by heatPenInstance.controller;
		satisfy <'REQ-HP-003'> by heatPenInstance.heatingElement;
		satisfy <'REQ-HP-004'> by heatPenInstance.pressureSensor;
		satisfy <'REQ-HP-005'> by heatPenInstance.controller;
		satisfy <'REQ-HP-006'> by heatPenInstance.powerSupply;
	}
}
