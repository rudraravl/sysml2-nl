package 'BEAM Robotics System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def LightIntensity :> ISQ::LuminousIntensityValue;
	attribute def VoltageLevel :> ISQ::VoltageValue;
	attribute def ChargeLevel :> ISQ::ElectricChargeValue;
	attribute def MotorSpeed :> ISQ::AngularVelocityValue;
	attribute def TriggerThreshold :> ISQ::VoltageValue;
	
	port def LightSensorPort {
		out lightLevel : LightIntensity;
	}
	
	port def PowerPort {
		out voltage : VoltageLevel;
	}
	
	port def ChargePort {
		in inputVoltage : VoltageLevel;
		out outputVoltage : VoltageLevel;
		out currentCharge : ChargeLevel;
	}
	
	port def MotorControlPort {
		in controlVoltage : VoltageLevel;
		out speed : MotorSpeed;
	}
	
	part def Photoresistor {
		doc /* Light-sensitive resistor that detects ambient light intensity. */
		port lightOut : LightSensorPort;
	}
	
	part def SolarCell {
		doc /* Photovoltaic cell that converts light energy into electrical voltage. */
		in lightInput : LightIntensity;
		port powerOut : PowerPort;
	}
	
	part def Capacitor {
		doc /* Energy storage component that accumulates charge until threshold is reached. */
		attribute capacity : ChargeLevel;
		attribute threshold : TriggerThreshold;
		attribute storedCharge : ChargeLevel := 0.0;
		port chargePort : ChargePort;
		
		state machine def CapacitorBehavior {
			state Charging {
				doc /* Accumulating energy from solar cells. */
			}
			state Ready {
				doc /* Threshold reached, ready to discharge. */
			}
			state Discharging {
				doc /* Releasing stored energy to motors. */
			}
			
			transition chargeToReady first Charging accept at storedCharge >= threshold then Ready;
			transition readyToDischarge first Ready then Discharging;
			transition dischargeToCharge first Discharging accept at storedCharge < threshold then Charging;
		}
	}
	
	part def TriggerCircuit {
		doc /* Analog circuit that monitors capacitor voltage and triggers motor activation. */
		in voltageMonitor : VoltageLevel;
		in chargeLevel : ChargeLevel;
		in thresholdLevel : TriggerThreshold;
		out triggerSignal : Boolean;
	}
	
	part def DCMotor {
		doc /* Simple DC motor that drives mechanical locomotion. */
		attribute isActive : Boolean := false;
		port motorControl : MotorControlPort;
	}
	
	part def Wheel {
		doc /* Mechanical wheel driven by motor for locomotion. */
		in torqueInput : ISQ::TorqueValue;
		out rotationSpeed : MotorSpeed;
	}
	
	action def SenseAmbientLight {
		out detectedLight : LightIntensity;
	}
	
	action def ConvertLightToVoltage {
		in lightInput : LightIntensity;
		out generatedVoltage : VoltageLevel;
	}
	
	action def AccumulateEnergy {
		in inputVoltage : VoltageLevel;
		inout charge : ChargeLevel;
		out currentVoltage : VoltageLevel;
	}
	
	action def MonitorThreshold {
		in charge : ChargeLevel;
		in threshold : TriggerThreshold;
		out thresholdMet : Boolean;
	}
	
	action def ReleaseEnergy {
		inout charge : ChargeLevel;
		out dischargePulse : VoltageLevel;
	}
	
	action def ActivateMotor {
		in powerPulse : VoltageLevel;
		out motorTorque : ISQ::TorqueValue;
	}
	
	action def ProduceMovement {
		in torque : ISQ::TorqueValue;
		out wheelRotation : MotorSpeed;
	}
	
	action def BEAMOperationCycle {
		doc /* Primary behavior cycle: sense light, harvest energy, store charge, 
		       trigger discharge when threshold reached, drive motors for locomotion. */
		
		first start;
		then merge continuousOperation;
		
		then action detectLight : SenseAmbientLight {
			out detectedLight : LightIntensity;
		}
		
		then action harvestPower : ConvertLightToVoltage {
			in lightInput = detectLight.detectedLight;
			out generatedVoltage : VoltageLevel;
		}
		
		then action storeEnergy : AccumulateEnergy {
			in inputVoltage = harvestPower.generatedVoltage;
			inout charge : ChargeLevel;
			out currentVoltage : VoltageLevel;
		}
		
		then action checkThreshold : MonitorThreshold {
			in charge = storeEnergy.charge;
			in threshold : TriggerThreshold;
			out thresholdMet : Boolean;
		}
		
		then decide;
			if checkThreshold.thresholdMet == false then continuousOperation;
			if checkThreshold.thresholdMet == true then dischargeSequence;
		
		action dischargeSequence {
			first action releaseCharge : ReleaseEnergy {
				inout charge = storeEnergy.charge;
				out dischargePulse : VoltageLevel;
			}
			
			then action driveLeftMotor : ActivateMotor {
				in powerPulse = releaseCharge.dischargePulse;
				out motorTorque : ISQ::TorqueValue;
			}
			
			then action driveRightMotor : ActivateMotor {
				in powerPulse = releaseCharge.dischargePulse;
				out motorTorque : ISQ::TorqueValue;
			}
			
			then action moveLeftWheel : ProduceMovement {
				in torque = driveLeftMotor.motorTorque;
				out wheelRotation : MotorSpeed;
			}
			
			then action moveRightWheel : ProduceMovement {
				in torque = driveRightMotor.motorTorque;
				out wheelRotation : MotorSpeed;
			}
		}
		
		then continuousOperation;
	}
	
	part def BEAMPhotovoreRobot {
		doc /* A Biology, Electronics, Aesthetics, Mechanics (BEAM) robot that exhibits 
		       photovore behavior. Uses simple analog circuits to convert solar energy 
		       into stored electrical charge, then releases it in periodic bursts to 
		       drive motors, creating autonomous light-seeking locomotion without 
		       microprocessor control. */
		
		attribute operatingThreshold : TriggerThreshold := 2.5;
		
		part leftPhotoresistor : Photoresistor {
			port lightOut : LightSensorPort;
		}
		
		part rightPhotoresistor : Photoresistor {
			port lightOut : LightSensorPort;
		}
		
		part leftSolarCell : SolarCell {
			in lightInput : LightIntensity;
			port powerOut : PowerPort;
		}
		
		part rightSolarCell : SolarCell {
			in lightInput : LightIntensity;
			port powerOut : PowerPort;
		}
		
		part storageCapacitor : Capacitor {
			attribute capacity = 1000.0;
			attribute threshold = operatingThreshold;
			port chargePort : ChargePort;
		}
		
		part triggerCircuit : TriggerCircuit {
			in voltageMonitor : VoltageLevel;
			in chargeLevel : ChargeLevel;
			in thresholdLevel = operatingThreshold;
			out triggerSignal : Boolean;
		}
		
		part leftMotor : DCMotor {
			port motorControl : MotorControlPort;
		}
		
		part rightMotor : DCMotor {
			port motorControl : MotorControlPort;
		}
		
		part leftWheel : Wheel {
			in torqueInput : ISQ::TorqueValue;
			out rotationSpeed : MotorSpeed;
		}
		
		part rightWheel : Wheel {
			in torqueInput : ISQ::TorqueValue;
			out rotationSpeed : MotorSpeed;
		}
		
		connect leftPhotoresistor.lightOut.lightLevel to leftSolarCell.lightInput;
		connect rightPhotoresistor.lightOut.lightLevel to rightSolarCell.lightInput;
		connect leftSolarCell.powerOut.voltage to storageCapacitor.chargePort.inputVoltage;
		connect rightSolarCell.powerOut.voltage to storageCapacitor.chargePort.inputVoltage;
		connect storageCapacitor.chargePort.outputVoltage to triggerCircuit.voltageMonitor;
		connect storageCapacitor.chargePort.currentCharge to triggerCircuit.chargeLevel;
		connect storageCapacitor.chargePort.outputVoltage to leftMotor.motorControl.controlVoltage;
		connect storageCapacitor.chargePort.outputVoltage to rightMotor.motorControl.controlVoltage;
		
		perform action operationCycle[*] ordered references BEAMOperationCycle;
	}
	
	requirement def AutonomousBehavior {
		doc /* The robot shall operate autonomously using only analog electronics 
		       without digital computation or programming. */
		subject robot : BEAMPhotovoreRobot;
	}
	
	requirement def SolarEnergyHarvesting {
		doc /* The robot shall harvest energy from ambient light using photovoltaic 
		       solar cells. */
		subject robot : BEAMPhotovoreRobot;
		require constraint {
			robot.leftSolarCell.powerOut.voltage > 0.0 or 
			robot.rightSolarCell.powerOut.voltage > 0.0
		}
	}
	
	requirement def ThresholdBasedDischarge {
		doc /* The robot shall store harvested energy in a capacitor and discharge 
		       it to motors only when voltage reaches the configured threshold. */
		subject robot : BEAMPhotovoreRobot;
		require constraint {
			robot.storageCapacitor.storedCharge >= robot.storageCapacitor.threshold
		}
	}
	
	requirement def PhotovoreLocomotion {
		doc /* The robot shall exhibit photovore behavior by moving toward light 
		       sources through differential motor activation. */
		subject robot : BEAMPhotovoreRobot;
		require constraint {
			robot.leftWheel.rotationSpeed > 0.0 or 
			robot.rightWheel.rotationSpeed > 0.0
		}
	}
	
	requirement def PrimaryFunction {
		doc /* The BEAM photovore robot shall autonomously seek and move toward light 
		       sources by harvesting solar energy, storing it in a capacitor, and 
		       releasing it in periodic bursts to drive motors, demonstrating emergent 
		       life-like behavior through simple analog circuits. */
		
		require autonomousBehavior : AutonomousBehavior;
		require energyHarvesting : SolarEnergyHarvesting;
		require thresholdDischarge : ThresholdBasedDischarge;
		require photovoreMovement : PhotovoreLocomotion;
	}
	
	part photovoreRobot : BEAMPhotovoreRobot;
	
	satisfy PrimaryFunction by photovoreRobot;
}
