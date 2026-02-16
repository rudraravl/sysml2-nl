package 'Float Switch System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def LiquidLevelValue :> LengthValue;
	attribute def ActivationLevelValue :> LengthValue;
	attribute def DeactivationLevelValue :> LengthValue;
	
	enum def SwitchState {
		enum open;
		enum closed;
	}
	
	enum def PumpState {
		enum off;
		enum on;
	}
	
	port def LiquidPort {
		inout liquidFlow : VolumeFlowRateValue;
	}
	
	port def LevelSensorPort {
		out measuredLevel : LiquidLevelValue;
	}
	
	port def SwitchOutputPort {
		out switchState : SwitchState;
	}
	
	port def PumpControlPort {
		in controlSignal : SwitchState;
	}
	
	part def FloatMechanism {
		attribute buoyantForce : ForceValue;
		attribute verticalPosition : LengthValue;
		attribute currentLiquidLevel : LiquidLevelValue;
		
		action def DetectLevel {
			in liquidLevel : LiquidLevelValue;
			out position : LengthValue;
		}
	}
	
	part def SwitchContact {
		attribute contactState : SwitchState;
		port output : SwitchOutputPort;
		
		action def ToggleContact {
			in floatPosition : LengthValue;
			in activationThreshold : LengthValue;
			in deactivationThreshold : LengthValue;
			out newState : SwitchState;
		}
	}
	
	part def FloatSwitch {
		attribute activationLevel : ActivationLevelValue;
		attribute deactivationLevel : DeactivationLevelValue;
		attribute hysteresisGap : LengthValue;
		
		part floatMechanism : FloatMechanism;
		part switchContact : SwitchContact;
		
		port levelSensor : LevelSensorPort;
		port switchOutput : SwitchOutputPort;
		
		connection floatToContact connect floatMechanism to switchContact;
		
		perform action operateSwitch : FloatSwitchOperation {
			in liquidLevel = levelSensor.measuredLevel;
			in activationThreshold = activationLevel;
			in deactivationThreshold = deactivationLevel;
			out outputState = switchOutput.switchState;
		}
	}
	
	part def LiquidTank {
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute currentLevel : LiquidLevelValue;
		attribute crossSectionalArea : AreaValue;
		
		port inlet : LiquidPort;
		port outlet : LiquidPort;
		port levelOutput : LevelSensorPort;
	}
	
	part def Pump {
		attribute ratedFlowRate : VolumeFlowRateValue;
		attribute powerRating : PowerValue;
		attribute operatingState : PumpState;
		
		port control : PumpControlPort;
		port discharge : LiquidPort;
		
		action def StartPump;
		action def StopPump;
	}
	
	part def LiquidSource {
		attribute supplyPressure : PressureValue;
		port supply : LiquidPort;
	}
	
	action def FloatSwitchOperation {
		in liquidLevel : LiquidLevelValue;
		in activationThreshold : ActivationLevelValue;
		in deactivationThreshold : DeactivationLevelValue;
		out outputState : SwitchState;
		
		private attribute currentState : SwitchState := SwitchState::open;
		
		first start;
		then merge continuousMonitoring;
		
		then action measureLevel {
			in level = liquidLevel;
			out measuredValue : LiquidLevelValue;
		}
		
		then decide;
			if measureLevel.measuredValue >= activationThreshold and currentState == SwitchState::open 
				then closeSwitch;
			if measureLevel.measuredValue <= deactivationThreshold and currentState == SwitchState::closed 
				then openSwitch;
			else maintainState;
		
		action closeSwitch {
			then assign currentState := SwitchState::closed;
			then assign outputState := SwitchState::closed;
		}
		
		action openSwitch {
			then assign currentState := SwitchState::open;
			then assign outputState := SwitchState::open;
		}
		
		action maintainState {
			then assign outputState := currentState;
		}
		
		then continuousMonitoring;
	}
	
	action def PumpControlLogic {
		in switchSignal : SwitchState;
		out pumpCommand : PumpState;
		
		first start;
		then decide;
			if switchSignal == SwitchState::closed then activatePump;
			if switchSignal == SwitchState::open then deactivatePump;
		
		action activatePump {
			then assign pumpCommand := PumpState::on;
		}
		
		action deactivatePump {
			then assign pumpCommand := PumpState::off;
		}
		
		then done;
	}
	
	part floatSwitchControlSystem {
		part tank : LiquidTank {
			attribute capacity = 5000.0 [SI::L];
			attribute currentVolume = 1500.0 [SI::L];
			attribute currentLevel = 0.75 [SI::m];
			attribute crossSectionalArea = 2.0 [SI::m^2];
		}
		
		part floatSwitch : FloatSwitch {
			attribute activationLevel = 1.8 [SI::m];
			attribute deactivationLevel = 0.5 [SI::m];
			attribute hysteresisGap = 0.1 [SI::m];
		}
		
		part pump : Pump {
			attribute ratedFlowRate = 50.0 [SI::L / SI::s];
			attribute powerRating = 2.5 [SI::kW];
			attribute operatingState = PumpState::off;
		}
		
		part source : LiquidSource {
			attribute supplyPressure = 300.0 [SI::kPa];
		}
		
		connection tankLevelToSwitch connect tank.levelOutput to floatSwitch.levelSensor;
		connection switchToPump connect floatSwitch.switchOutput to pump.control;
		connection pumpToTank connect pump.discharge to tank.inlet;
		connection sourceToTank connect source.supply to tank.inlet;
		
		perform action controlCycle : PumpControlLogic {
			in switchSignal = floatSwitch.switchOutput.switchState;
			out pumpCommand;
		}
	}
	
	requirement <'FS-REQ-001'> primaryFunctionRequirement {
		doc /* The float switch system shall automatically control liquid level 
		       in a tank by activating a pump when the liquid rises above a 
		       specified activation level and deactivating the pump when the 
		       liquid falls below a specified deactivation level. */
		
		subject floatSwitchControlSystem;
		
		require constraint activationCondition {
			floatSwitchControlSystem.tank.currentLevel >= floatSwitchControlSystem.floatSwitch.activationLevel
			implies
			floatSwitchControlSystem.floatSwitch.switchContact.contactState == SwitchState::closed
		}
		
		require constraint deactivationCondition {
			floatSwitchControlSystem.tank.currentLevel <= floatSwitchControlSystem.floatSwitch.deactivationLevel
			implies
			floatSwitchControlSystem.floatSwitch.switchContact.contactState == SwitchState::open
		}
	}
	
	requirement <'FS-REQ-002'> hysteresisRequirement {
		doc /* The float switch shall maintain a hysteresis gap between 
		       activation and deactivation levels to prevent rapid cycling 
		       of the pump. */
		
		require constraint minimumHysteresis {
			floatSwitchControlSystem.floatSwitch.activationLevel - 
			floatSwitchControlSystem.floatSwitch.deactivationLevel >= 
			floatSwitchControlSystem.floatSwitch.hysteresisGap
		}
	}
	
	requirement <'FS-REQ-003'> pumpControlRequirement {
		doc /* The pump shall be energized when the float switch is in the 
		       closed state and de-energized when the float switch is in 
		       the open state. */
		
		require constraint pumpActivation {
			floatSwitchControlSystem.floatSwitch.switchContact.contactState == SwitchState::closed
			implies
			floatSwitchControlSystem.pump.operatingState == PumpState::on
		}
		
		require constraint pumpDeactivation {
			floatSwitchControlSystem.floatSwitch.switchContact.contactState == SwitchState::open
			implies
			floatSwitchControlSystem.pump.operatingState == PumpState::off
		}
	}
	
	requirement <'FS-REQ-004'> reliabilityRequirement {
		doc /* The float switch mechanism shall operate reliably through 
		       continuous monitoring of liquid level and accurate actuation 
		       of electrical contacts. */
		
		assume constraint continuousLevelMonitoring {
			floatSwitchControlSystem.floatSwitch.floatMechanism.currentLiquidLevel != null
		}
		
		require constraint accurateContactActuation {
			floatSwitchControlSystem.floatSwitch.switchContact.contactState != null
		}
	}
	
	requirement <'FS-REQ-005'> systemIntegrationRequirement {
		doc /* The float switch system shall integrate the tank, float switch, 
		       and pump into a cohesive automatic liquid level control system. */
		
		satisfy primaryFunctionRequirement;
		satisfy hysteresisRequirement;
		satisfy pumpControlRequirement;
		satisfy reliabilityRequirement;
	}
}
