package RoundaboutPlayPumpSubsystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VolumeFlowRate :> Real;
	attribute def PressureValue :> Real;
	attribute def AngularVelocityValue :> Real;
	attribute def TorqueValue :> Real;
	attribute def PowerValue :> Real;
	attribute def EfficiencyValue :> Real;
	
	item def Water {
		attribute temperature : TemperatureValue;
		attribute quality : String;
	}
	
	port def FluidPort {
		out item water : Water;
		attribute pressure : PressureValue;
		attribute flowRate : VolumeFlowRate;
	}
	
	port def MechanicalPort {
		attribute angularVelocity : AngularVelocityValue;
		attribute torque : TorqueValue;
		attribute power : PowerValue;
	}
	
	part def WaterSource {
		attribute depth : LengthValue;
		attribute staticPressure : PressureValue;
		port outlet : FluidPort;
	}
	
	part def StorageTank {
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute height : LengthValue;
		port inlet : FluidPort;
		port dispensingOutlet : FluidPort;
		
		state tankStates {
			entry; then empty;
			
			state empty;
			state filling;
			state full;
			state dispensing;
			
			transition empty_to_filling
				first empty
				if inlet.flowRate > 0.0
				then filling;
			
			transition filling_to_full
				first filling
				if currentVolume >= capacity
				then full;
			
			transition filling_to_empty
				first filling
				if currentVolume <= 0.0
				then empty;
			
			transition full_to_dispensing
				first full
				if dispensingOutlet.flowRate > 0.0
				then dispensing;
			
			transition dispensing_to_filling
				first dispensing
				if currentVolume < capacity
				then filling;
			
			transition dispensing_to_empty
				first dispensing
				if currentVolume <= 0.0
				then empty;
		}
	}
	
	part def Roundabout {
		attribute diameter : LengthValue;
		attribute mass : MassValue;
		attribute momentOfInertia : Real;
		attribute numberOfSeats : Integer;
		port rotationOutput : MechanicalPort;
		
		action def GenerateRotation {
			in childrenCount : Integer;
			in pushForce : ForceValue;
			out rotationalSpeed : AngularVelocityValue;
			out outputTorque : TorqueValue;
			
			first start;
			then action calculateInertia {
				in count : Integer = childrenCount;
				out inertia : Real;
			}
			then action computeAngularAcceleration {
				in force : ForceValue = pushForce;
				in inertiaValue : Real = calculateInertia.inertia;
				out acceleration : Real;
			}
			then action determineSpeed {
				in accel : Real = computeAngularAcceleration.acceleration;
				out speed : AngularVelocityValue;
			}
			then action calculateTorque {
				in omega : AngularVelocityValue = determineSpeed.speed;
				out torque : TorqueValue;
			}
			then done;
		}
	}
	
	part def PumpMechanism {
		attribute pumpType : String;
		attribute efficiency : EfficiencyValue;
		attribute maxFlowRate : VolumeFlowRate;
		attribute maxPressure : PressureValue;
		attribute maxLiftHeight : LengthValue;
		
		port mechanicalInput : MechanicalPort;
		port fluidInlet : FluidPort;
		port fluidOutlet : FluidPort;
		
		action def PumpOperation {
			in inputTorque : TorqueValue;
			in inputSpeed : AngularVelocityValue;
			in inletPressure : PressureValue;
			out outletPressure : PressureValue;
			out deliveryFlowRate : VolumeFlowRate;
			
			first start;
			then action calculateHydraulicPower {
				in torque : TorqueValue = inputTorque;
				in speed : AngularVelocityValue = inputSpeed;
				out hydraulicPower : PowerValue;
			}
			then action determineFlowRate {
				in power : PowerValue = calculateHydraulicPower.hydraulicPower;
				in eff : EfficiencyValue = efficiency;
				out flow : VolumeFlowRate;
			}
			then action computeOutletPressure {
				in flow : VolumeFlowRate = determineFlowRate.flow;
				in inPressure : PressureValue = inletPressure;
				out outPressure : PressureValue;
			}
			then done;
		}
		
		state pumpStates {
			entry; then idle;
			
			state idle;
			state priming;
			state pumping;
			
			transition idle_to_priming
				first idle
				if mechanicalInput.angularVelocity > 0.1
				then priming;
			
			transition priming_to_pumping
				first priming
				if fluidInlet.pressure > 0.0
				then pumping;
			
			transition priming_to_idle
				first priming
				if mechanicalInput.angularVelocity <= 0.1
				then idle;
			
			transition pumping_to_idle
				first pumping
				if mechanicalInput.angularVelocity <= 0.1
				then idle;
		}
	}
	
	part def RisingMainPipe {
		attribute length : LengthValue;
		attribute diameter : LengthValue;
		attribute material : String;
		attribute roughness : Real;
		port inlet : FluidPort;
		port outlet : FluidPort;
		
		flow pipeFlow of water : Water from inlet.water to outlet.water;
	}
	
	part def DeliveryPipe {
		attribute length : LengthValue;
		attribute diameter : LengthValue;
		port inlet : FluidPort;
		port outlet : FluidPort;
		
		flow deliveryFlow of water : Water from inlet.water to outlet.water;
	}
	
	part def RoundaboutPlayPump {
		part roundabout : Roundabout {
			attribute :>> diameter = 3.5[m];
			attribute :>> mass = 250.0[kg];
			attribute :>> momentOfInertia = 150.0;
			attribute :>> numberOfSeats = 8;
		}
		
		part pump : PumpMechanism {
			attribute :>> pumpType = "Positive Displacement";
			attribute :>> efficiency = 0.70;
			attribute :>> maxFlowRate = 1500.0;
			attribute :>> maxPressure = 450000.0;
			attribute :>> maxLiftHeight = 45.0[m];
		}
		
		port mechanicalCoupling : MechanicalPort;
		port waterInlet : FluidPort;
		port waterOutlet : FluidPort;
		
		connection mechanicalDrive connect roundabout.rotationOutput to pump.mechanicalInput;
		
		flow inletFlow of water : Water from waterInlet.water to pump.fluidInlet.water;
		flow outletFlow of water : Water from pump.fluidOutlet.water to waterOutlet.water;
	}
	
	part def PumpingSubsystem {
		part borehole : WaterSource {
			attribute :>> depth = 40.0[m];
			attribute :>> staticPressure = 101325.0;
		}
		
		part playPump : RoundaboutPlayPump;
		
		part risingMain : RisingMainPipe {
			attribute :>> length = 40.0[m];
			attribute :>> diameter = 0.05[m];
			attribute :>> material = "PVC";
			attribute :>> roughness = 0.0015;
		}
		
		part deliveryMain : DeliveryPipe {
			attribute :>> length = 15.0[m];
			attribute :>> diameter = 0.05[m];
		}
		
		part storage : StorageTank {
			attribute :>> capacity = 2500.0[L];
			attribute :>> currentVolume = 0.0[L];
			attribute :>> height = 7.0[m];
		}
		
		flow sourceToPlayPump of water : Water 
			from borehole.outlet.water to playPump.waterInlet.water;
		
		flow playPumpToRisingMain of water : Water 
			from playPump.waterOutlet.water to risingMain.inlet.water;
		
		flow risingMainToDelivery of water : Water 
			from risingMain.outlet.water to deliveryMain.inlet.water;
		
		flow deliveryToStorage of water : Water 
			from deliveryMain.outlet.water to storage.inlet.water;
	}
	
	action def SystemOperation {
		first start;
		then merge monitorActivity;
		
		action monitorActivity {
			out childrenPresent : Boolean;
			out playIntensity : Real;
		}
		
		then decide;
			if monitorActivity.childrenPresent then activePumping;
			if not monitorActivity.childrenPresent then standby;
		
		action activePumping {
			action rotateRoundabout {
				out rotationSpeed : AngularVelocityValue;
			}
			then action drivePump {
				in speed : AngularVelocityValue = rotateRoundabout.rotationSpeed;
				out flowRate : VolumeFlowRate;
			}
			then action liftWater {
				in flow : VolumeFlowRate = drivePump.flowRate;
				out liftedVolume : VolumeValue;
			}
			then action fillTank {
				in volume : VolumeValue = liftWater.liftedVolume;
			}
		}
		then monitorActivity;
		
		action standby;
		then monitorActivity;
	}
	
	requirement def FlowRateRequirement {
		doc /* The pumping subsystem shall deliver a minimum flow rate of 
		       1400 liters per hour when operated at nominal play speed. */
		
		subject subsystem : PumpingSubsystem;
		
		require constraint {
			subsystem.playPump.pump.maxFlowRate >= 1400.0
		}
	}
	
	requirement def LiftCapabilityRequirement {
		doc /* The pump mechanism shall be capable of lifting water from 
		       a depth of at least 40 meters. */
		
		subject pumpUnit : PumpMechanism;
		
		require constraint {
			pumpUnit.maxLiftHeight >= 40.0[m]
		}
	}
	
	requirement def StorageRequirement {
		doc /* The storage tank shall have a minimum capacity of 2500 liters 
		       to ensure adequate water supply for community needs. */
		
		subject tank : StorageTank;
		
		require constraint {
			tank.capacity >= 2500.0[L]
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* The pump mechanism shall operate at a minimum efficiency of 
		       65% to ensure effective energy conversion. */
		
		subject pumpUnit : PumpMechanism;
		
		require constraint {
			pumpUnit.efficiency >= 0.65
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The roundabout shall be designed for safe operation by children 
		       with appropriate diameter and seating capacity. */
		
		subject roundaboutUnit : Roundabout;
		
		require constraint {
			roundaboutUnit.diameter >= 3.0[m] and 
			roundaboutUnit.diameter <= 4.0[m] and
			roundaboutUnit.numberOfSeats >= 6
		}
	}
	
	requirement def SystemRequirement {
		doc /* The Roundabout PlayPump subsystem shall convert kinetic energy 
		       from children playing into mechanical pumping action to lift 
		       groundwater to an elevated storage tank for community use. */
		
		subject system : PumpingSubsystem;
		
		require flowRate : FlowRateRequirement {
			subject subsystem = system;
		}
		
		require liftCapability : LiftCapabilityRequirement {
			subject pumpUnit = system.playPump.pump;
		}
		
		require storage : StorageRequirement {
			subject tank = system.storage;
		}
		
		require efficiency : EfficiencyRequirement {
			subject pumpUnit = system.playPump.pump;
		}
		
		require safety : SafetyRequirement {
			subject roundaboutUnit = system.playPump.roundabout;
		}
	}
	
	part pumpingSystem : PumpingSubsystem;
	
	requirement systemRequirement : SystemRequirement {
		subject system = pumpingSystem;
	}
}
