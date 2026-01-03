package AlgerBrushOphthalmicSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RotationalSpeed :> ISQ::AngularSpeedValue;
	attribute def StallTorque :> ISQ::TorqueValue;
	attribute def BurrDiameter :> ISQ::LengthValue;
	attribute def AppliedForce :> ISQ::ForceValue;
	
	item def ElectricalPower {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def RotationalMotion {
		attribute speed : RotationalSpeed;
		attribute torque : ISQ::TorqueValue;
	}
	
	item def ControlSignal {
		attribute activated : Boolean;
	}
	
	item def CornealDebris;
	
	port def PowerPort {
		inout power : ElectricalPower;
	}
	
	port def RotationPort {
		out rotation : RotationalMotion;
	}
	
	port def ControlPort {
		in signal : ControlSignal;
	}
	
	part def BatteryCell {
		attribute nominalVoltage : ISQ::VoltageValue;
		attribute capacity : ISQ::EnergyValue;
		port powerOutput : PowerPort;
	}
	
	part def ActivationSwitch {
		attribute switchState : Boolean;
		port powerIn : PowerPort;
		port powerOut : PowerPort;
		port control : ControlPort;
	}
	
	part def LowSpeedMotor {
		attribute noLoadSpeed : RotationalSpeed;
		attribute stallTorque : StallTorque;
		attribute operatingVoltage : ISQ::VoltageValue;
		port powerIn : PowerPort;
		port shaftOut : RotationPort;
	}
	
	part def ChuckAdapter {
		attribute grippingDiameter : ISQ::LengthValue;
		port motorShaft : RotationPort;
		port burrMount : RotationPort;
	}
	
	part def OphthalmicBurr {
		attribute diameter : BurrDiameter;
		attribute gritSize : Real;
		attribute maxSafeForce : AppliedForce;
		port shaft : RotationPort;
	}
	
	part def HandpieceHousing {
		attribute length : ISQ::LengthValue;
		attribute weight : ISQ::MassValue;
		attribute ergonomicGrip : Boolean;
	}
	
	action def SupplyPower {
		in voltage : ISQ::VoltageValue;
		in current : ISQ::ElectricCurrentValue;
		out powerDelivered : ElectricalPower;
	}
	
	action def RotateShaft {
		in power : ElectricalPower;
		in loadTorque : ISQ::TorqueValue;
		out shaftSpeed : RotationalSpeed;
		out outputTorque : ISQ::TorqueValue;
	}
	
	action def TransmitRotation {
		in inputRotation : RotationalMotion;
		out outputRotation : RotationalMotion;
	}
	
	action def AbradeCornealSurface {
		in rotation : RotationalMotion;
		in contactForce : AppliedForce;
		out debrisRemoved : CornealDebris[*];
		out tissueIntegrity : Boolean;
	}
	
	action def RemoveForeignBody {
		in activationSignal : ControlSignal;
		out removalSuccess : Boolean;
		
		first start;
		then merge continueOperation;
		
		then action checkActivation {
			in signal = activationSignal;
			out isActive : Boolean;
		}
		
		then decide;
			if checkActivation.isActive then powerMotor;
			if not checkActivation.isActive then stopOperation;
		
		action powerMotor : RotateShaft {
			in power;
			in loadTorque;
			out shaftSpeed;
			out outputTorque;
		}
		
		then action transmitToBurr : TransmitRotation {
			in inputRotation : RotationalMotion {
				attribute :>> speed = powerMotor.shaftSpeed;
				attribute :>> torque = powerMotor.outputTorque;
			}
			out outputRotation;
		}
		
		then action abradeDebris : AbradeCornealSurface {
			in rotation = transmitToBurr.outputRotation;
			in contactForce;
			out debrisRemoved;
			out tissueIntegrity;
		}
		
		then decide;
			if abradeDebris.tissueIntegrity and abradeDebris.debrisRemoved->size() > 0 
				then continueOperation;
			if not abradeDebris.tissueIntegrity then stopOperation;
		
		action stopOperation {
			assign removalSuccess := abradeDebris.debrisRemoved->size() > 0;
		}
		then done;
	}
	
	state def AlgerBrushOperationalStates {
		entry; then idle;
		
		state idle {
			entry assign motorActive := false;
		}
		
		state activated {
			entry assign motorActive := true;
		}
		
		state rotating {
			do action maintainRotation : RotateShaft;
		}
		
		state abrading {
			do action performAbrasion : AbradeCornealSurface;
		}
		
		state stalled {
			entry assign motorActive := false;
		}
		
		transition idle_to_activated
			first idle
			accept ActivationPressed
			then activated;
		
		transition activated_to_rotating
			first activated
			then rotating;
		
		transition rotating_to_abrading
			first rotating
			accept CornealContact
			then abrading;
		
		transition abrading_to_stalled
			first abrading
			accept ExcessiveResistance
			then stalled;
		
		transition abrading_to_rotating
			first abrading
			accept ContactLost
			then rotating;
		
		transition rotating_to_idle
			first rotating
			accept ActivationReleased
			then idle;
		
		transition stalled_to_idle
			first stalled
			accept ActivationReleased
			then idle;
	}
	
	part def AlgerBrushDevice;
	
	part algerBrush : AlgerBrushDevice {
		attribute operatingVoltage : ISQ::VoltageValue = 1.5[SI::V];
		attribute targetSpeed : RotationalSpeed = 1200[SI::rpm];
		attribute maxStallTorque : StallTorque = 0.0012[SI::'N·m'];
		attribute burrDiameter : BurrDiameter = 0.5[SI::mm];
		attribute deviceWeight : ISQ::MassValue = 0.15[SI::kg];
		
		part battery : BatteryCell {
			attribute :>> nominalVoltage = 1.5[SI::V];
			attribute :>> capacity = 2.0[SI::'W·h'];
		}
		
		part activationSwitch : ActivationSwitch {
			attribute :>> switchState = false;
		}
		
		part motor : LowSpeedMotor {
			attribute :>> noLoadSpeed = algerBrush.targetSpeed;
			attribute :>> stallTorque = algerBrush.maxStallTorque;
			attribute :>> operatingVoltage = algerBrush.operatingVoltage;
		}
		
		part chuck : ChuckAdapter {
			attribute :>> grippingDiameter = 2.35[SI::mm];
		}
		
		part burr : OphthalmicBurr {
			attribute :>> diameter = algerBrush.burrDiameter;
			attribute :>> gritSize = 600.0;
			attribute :>> maxSafeForce = 0.05[SI::N];
		}
		
		part housing : HandpieceHousing {
			attribute :>> length = 150[SI::mm];
			attribute :>> weight = algerBrush.deviceWeight;
			attribute :>> ergonomicGrip = true;
		}
		
		connect battery.powerOutput to activationSwitch.powerIn;
		connect activationSwitch.powerOut to motor.powerIn;
		connect motor.shaftOut to chuck.motorShaft;
		connect chuck.burrMount to burr.shaft;
		
		perform action foreignBodyRemoval : RemoveForeignBody {
			in activationSignal;
			out removalSuccess;
		}
		
		exhibit state operationalBehavior : AlgerBrushOperationalStates;
	}
	
	requirement def SafetyRequirement {
		doc /* The Alger brush shall operate safely on delicate corneal tissue 
		       without causing damage to underlying structures. */
		
		subject device : AlgerBrushDevice;
		
		require constraint motorStallProtection {
			doc /* Motor must stall when encountering resistance from Bowman's layer 
			       to prevent penetration and injury. */
			device.motor.stallTorque <= 0.0015[SI::'N·m']
		}
		
		require constraint safeOperatingSpeed {
			doc /* Operating speed must be sufficient for effective abrasion 
			       but low enough to maintain control. */
			device.motor.noLoadSpeed >= 1000[SI::rpm] and
			device.motor.noLoadSpeed <= 1500[SI::rpm]
		}
	}
	
	requirement def EffectivenessRequirement {
		doc /* The Alger brush shall effectively remove superficial corneal 
		       foreign bodies and rust rings. */
		
		subject device : AlgerBrushDevice;
		
		require constraint adequateBurrSize {
			doc /* Burr diameter must be appropriate for precision work 
			       on corneal surface. */
			device.burr.diameter >= 0.3[SI::mm] and
			device.burr.diameter <= 1.0[SI::mm]
		}
		
		require constraint sufficientRotationalSpeed {
			doc /* Rotational speed must enable effective material removal 
			       without excessive pressure. */
			device.motor.noLoadSpeed >= 1000[SI::rpm]
		}
	}
	
	requirement <'ALG-PF-001'> primaryFunctionRequirement {
		doc /* PRIMARY FUNCTION: The Alger brush is an ophthalmic surgical instrument 
		       designed to remove superficial foreign bodies, rust rings, and other 
		       debris from the corneal epithelium through controlled rotary abrasion. 
		       
		       The device employs a battery-powered low-speed motor that rotates a small 
		       diamond or metal burr at approximately 1200 RPM. When the rotating burr 
		       contacts the corneal surface, it gently abrades the superficial epithelial 
		       cells containing the foreign material without penetrating deeper corneal 
		       layers. The motor is designed with a low stall torque that causes it to 
		       stop rotating when it encounters the resistance of Bowman's layer, 
		       providing an inherent safety mechanism against excessive tissue removal. 
		       
		       This allows ophthalmologists to precisely remove embedded metallic particles 
		       and associated rust staining while preserving the structural integrity of 
		       the underlying corneal stroma. */
		
		subject algerBrush;
		
		assume constraint cornealAccessibility {
			doc /* The corneal surface must be accessible and adequately anesthetized 
			       for safe instrument application. */
		}
		
		assume constraint adequatePowerSupply {
			doc /* Battery must provide sufficient voltage and current for motor operation. */
			algerBrush.battery.nominalVoltage >= 1.5[SI::V] and
			algerBrush.battery.capacity > 0[SI::'W·h']
		}
		
		require safetyReq : SafetyRequirement;
		require effectivenessReq : EffectivenessRequirement;
		
		require constraint functionalOperation {
			doc /* The device must successfully remove foreign material while maintaining 
			       corneal tissue integrity through controlled low-speed rotation and 
			       automatic stall protection. */
			algerBrush.foreignBodyRemoval.removalSuccess = true
		}
	}
	
	requirement <'ALG-SAF-001'> motorStallSafety : SafetyRequirement {
		doc /* Motor stall torque shall prevent penetration beyond epithelial layer. */
	}
	
	requirement <'ALG-EFF-001'> debrisRemovalEffectiveness : EffectivenessRequirement {
		doc /* Device shall effectively remove corneal foreign bodies and rust rings. */
	}
}
