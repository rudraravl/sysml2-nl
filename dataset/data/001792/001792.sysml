package HorsepowerPropulsionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def HorsepowerValue :> PowerValue;
	
	attribute def RotationalSpeedValue :> AngularSpeedValue;
	
	attribute def TorqueValue :> TorqueValue;
	
	item def ThrottleCommand {
		attribute position : Real;
	}
	
	item def PowerDemand {
		attribute requestedPower : HorsepowerValue;
	}
	
	item def MechanicalPower {
		attribute power : HorsepowerValue;
		attribute torque : TorqueValue;
		attribute speed : RotationalSpeedValue;
	}
	
	port def PowerOutputPort {
		out item mechanicalPower : MechanicalPower;
	}
	
	port def ThrottleInputPort {
		in item throttleCmd : ThrottleCommand;
	}
	
	port def LoadInputPort {
		in item mechanicalPower : MechanicalPower;
	}
	
	part def PowerPlant {
		attribute ratedPower : HorsepowerValue;
		attribute currentPower : HorsepowerValue;
		attribute currentTorque : TorqueValue;
		attribute currentSpeed : RotationalSpeedValue;
		attribute throttlePosition : Real;
		
		port throttleInput : ThrottleInputPort;
		port powerOutput : PowerOutputPort;
		
		part combustionChamber;
		part crankshaft;
		part pistons[8];
		part fuelInjectionSystem;
		
		perform action generatePower;
	}
	
	part def LoadDevice {
		attribute requiredPower : HorsepowerValue;
		attribute efficiency : Real;
		
		port powerInput : LoadInputPort;
		
		perform action consumePower;
	}
	
	part def PowerController {
		attribute targetPower : HorsepowerValue;
		attribute maxPower : HorsepowerValue;
		
		port throttleOutput : ~ThrottleInputPort;
		port feedbackInput;
		
		perform action regulatePower;
	}
	
	action def ComputePowerOutput {
		in throttle : Real;
		in maxPower : HorsepowerValue;
		out outputPower : HorsepowerValue;
		out outputTorque : TorqueValue;
		out outputSpeed : RotationalSpeedValue;
	}
	
	action def AdjustThrottle {
		in targetPower : HorsepowerValue;
		in currentPower : HorsepowerValue;
		in maxPower : HorsepowerValue;
		out throttlePosition : Real;
	}
	
	action def TransferPower {
		in inputPower : MechanicalPower;
		in loadEfficiency : Real;
		out deliveredPower : HorsepowerValue;
	}
	
	state def PowerPlantStates {
		in attribute throttlePosition : Real;
		in attribute currentPowerValue : Real;
		in attribute ratedPowerValue : Real;
		
		entry; then shutdown;
		
		state shutdown;
		transition shutdown_to_starting
			first shutdown
			if throttlePosition > 0.0
			then starting;
		
		state starting;
		transition starting_to_idle
			first starting
			if currentPowerValue > 0.0
			then idle;
		
		state idle {
			entry assign throttlePosition := 0.05;
		}
		transition idle_to_operating
			first idle
			if throttlePosition > 0.1
			then operating;
		
		state operating {
			state lowPower;
			transition lowPower_to_mediumPower
				first lowPower
				if currentPowerValue < ratedPowerValue * 0.5
				then mediumPower;
			
			state mediumPower;
			transition mediumPower_to_highPower
				first mediumPower
				if currentPowerValue >= ratedPowerValue * 0.5 and currentPowerValue < ratedPowerValue * 0.85
				then highPower;
			
			state highPower;
			transition highPower_to_mediumPower
				first highPower
				if currentPowerValue < ratedPowerValue * 0.5
				then mediumPower;
		}
		
		transition operating_to_idle
			first operating
			if throttlePosition <= 0.1
			then idle;
		
		transition idle_to_shutdown
			first idle
			if throttlePosition <= 0.0
			then shutdown;
	}
	
	part horsepowerSystem : PowerPlant {
		attribute :>> ratedPower = 500.0 [SI::hp];
		attribute :>> currentPower = 0.0 [SI::hp];
		attribute :>> currentTorque = 0.0 [SI::'N·m'];
		attribute :>> currentSpeed = 0.0 [SI::rpm];
		attribute :>> throttlePosition = 0.0;
		
		part controller : PowerController {
			attribute :>> targetPower = 350.0 [SI::hp];
			attribute :>> maxPower = 500.0 [SI::hp];
			
			perform action regulatePower {
				private attribute powerError : Real;
				
				first start;
				then merge controlLoop;
				then action measurePower;
				then action computeError {
					assign powerError := ScalarValues::ToReal(controller.targetPower) - ScalarValues::ToReal(horsepowerSystem.currentPower);
				}
				then decide;
					if powerError > 10.0 then increaseThrottle;
					if powerError < -10.0 then decreaseThrottle;
					if powerError >= -10.0 and powerError <= 10.0 then maintainThrottle;
				action increaseThrottle : AdjustThrottle {
					in targetPower = controller.targetPower;
					in currentPower = horsepowerSystem.currentPower;
					in maxPower = controller.maxPower;
					out throttlePosition;
				}
				then controlLoop;
				action decreaseThrottle : AdjustThrottle {
					in targetPower = controller.targetPower;
					in currentPower = horsepowerSystem.currentPower;
					in maxPower = controller.maxPower;
					out throttlePosition;
				}
				then controlLoop;
				action maintainThrottle;
				then controlLoop;
			}
		}
		
		part load : LoadDevice {
			attribute :>> requiredPower = 350.0 [SI::hp];
			attribute :>> efficiency = 0.92;
			
			perform action consumePower {
				first start;
				then action receivePower : TransferPower {
					in inputPower = horsepowerSystem.powerOutput.mechanicalPower;
					in loadEfficiency = load.efficiency;
					out deliveredPower;
				}
				then action utilizePower;
				then done;
			}
		}
		
		connect controller.throttleOutput to throttleInput;
		connect powerOutput to load.powerInput;
		
		perform action generatePower {
			first start;
			then action initialize;
			then action computeOutput : ComputePowerOutput {
				in throttle = horsepowerSystem.throttlePosition;
				in maxPower = horsepowerSystem.ratedPower;
				out outputPower;
				out outputTorque;
				out outputSpeed;
			}
			then action deliverPower {
				in power = computeOutput.outputPower;
				in torque = computeOutput.outputTorque;
				in speed = computeOutput.outputSpeed;
			}
			then done;
		}
		
		exhibit state plantStates : PowerPlantStates {
			in attribute :>> throttlePosition = horsepowerSystem.throttlePosition;
			in attribute :>> currentPowerValue = ScalarValues::ToReal(horsepowerSystem.currentPower);
			in attribute :>> ratedPowerValue = ScalarValues::ToReal(horsepowerSystem.ratedPower);
		}
	}
	
	requirement def PowerDeliveryRequirement {
		doc /* The system shall deliver rated horsepower to the load within operating specifications. */
		
		subject system : PowerPlant;
		
		require constraint {
			ScalarValues::ToReal(system.currentPower) >= ScalarValues::ToReal(system.ratedPower) * 0.90
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The system shall maintain minimum efficiency during power transfer. */
		
		subject loadDevice : LoadDevice;
		
		require constraint {
			loadDevice.efficiency >= 0.85
		}
	}
	
	requirement def OperationalRangeRequirement {
		doc /* The system shall operate safely within rated power limits. */
		
		subject system : PowerPlant;
		
		require constraint {
			ScalarValues::ToReal(system.currentPower) <= ScalarValues::ToReal(system.ratedPower) * 1.05
		}
	}
	
	requirement systemRequirements {
		doc /* The horsepower propulsion system shall convert fuel energy into mechanical power and deliver it to a load device through controlled throttle regulation, maintaining rated power output of 500 horsepower while ensuring efficient power transfer and safe operation within specified limits. */
		
		require powerDeliveryReq : PowerDeliveryRequirement;
		require efficiencyReq : EfficiencyRequirement;
		require operationalRangeReq : OperationalRangeRequirement;
	}
}
