package 'Wendelkolben Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
		}
		
		attribute def Pressure :> Real;
		attribute def FlowRate :> Real;
		attribute def RotationalSpeed :> Real;
		attribute def Torque :> Real;
		attribute def Power :> Real;
		attribute def Volume :> Real;
		attribute def Length :> Real;
		
		port def FluidPort {
			attribute pressure : Pressure;
			attribute flowRate : FlowRate;
			out item fluidOut : Fluid;
			in item fluidIn : Fluid;
		}
		
		port def MechanicalPort {
			attribute torque : Torque;
			attribute speed : RotationalSpeed;
		}
		
		port def PowerPort {
			attribute voltage : Real;
			attribute current : Real;
			attribute powerDraw : Power;
		}
		
		part def WendelkolbenPump {
			doc /* 
			 * Wendelkolben (helical piston) pump uses a helical rotor 
			 * rotating eccentrically within a stator to create progressive 
			 * cavities that move fluid from inlet to outlet.
			 */
			
			attribute rotorDiameter : Length;
			attribute rotorLength : Length;
			attribute helixPitch : Length;
			attribute numberOfLobes : Integer;
			attribute operatingSpeed : RotationalSpeed;
			attribute maxPressure : Pressure;
			attribute nominalFlowRate : FlowRate;
			attribute volumetricEfficiency : Real;
			
			port inletPort : FluidPort;
			port outletPort : FluidPort;
			port driveShaft : MechanicalPort;
			
			part helicalRotor {
				doc /* Eccentric helical rotor that rotates within stator */
				attribute diameter : Length = rotorDiameter;
				attribute length : Length = rotorLength;
				attribute pitch : Length = helixPitch;
			}
			
			part elastomericStator {
				doc /* Stator with internal helical cavity matching rotor profile */
				attribute numberOfCavities : Integer = numberOfLobes + 1;
			}
			
			part couplingRod {
				doc /* Connects rotor to drive shaft allowing eccentric rotation */
			}
			
			part mechanicalSeal {
				doc /* Prevents fluid leakage along shaft */
				attribute sealType : String;
			}
			
			perform action pumpFluid : PumpFluid {
				in fluidIn = inletPort.fluidIn;
				in shaftSpeed = driveShaft.speed;
				in shaftTorque = driveShaft.torque;
				out fluidOut = outletPort.fluidOut;
				out outletPressure = outletPort.pressure;
				out deliveredFlow = outletPort.flowRate;
			}
			
			exhibit state operatingState : PumpOperatingStates;
		}
		
		part def ElectricMotor {
			attribute ratedPower : Power;
			attribute ratedSpeed : RotationalSpeed;
			attribute motorEfficiency : Real;
			attribute poles : Integer;
			
			port powerInput : PowerPort;
			port mechanicalOutput : MechanicalPort;
			
			perform action driveLoad : DriveMotor {
				in electricalPower = powerInput.powerDraw;
				out outputTorque = mechanicalOutput.torque;
				out outputSpeed = mechanicalOutput.speed;
			}
		}
		
		part def SupplyTank {
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute minLevel : Volume;
			
			port outlet : FluidPort;
			
			item storedFluid : Fluid {
				attribute volume : Volume = currentLevel;
			}
		}
		
		part def ReceivingTank {
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute maxLevel : Volume;
			attribute operatingPressure : Pressure;
			
			port inlet : FluidPort;
			
			item receivedFluid : Fluid;
		}
		
		part def PressureTransducer {
			attribute measuredPressure : Pressure;
			attribute accuracy : Real;
			attribute range : Pressure;
			
			port sensingPort : FluidPort;
		}
		
		part def FlowTransducer {
			attribute measuredFlowRate : FlowRate;
			attribute accuracy : Real;
			attribute range : FlowRate;
			
			port measurementPort : FluidPort;
		}
		
		part def ReliefValve {
			attribute setPoint : Pressure;
			attribute crackingPressure : Pressure;
			attribute fullOpenPressure : Pressure;
			
			port inletPort : FluidPort;
			port outletPort : FluidPort;
			
			perform action relievePressure : RelievePressure;
		}
		
		part def IsolationValve {
			attribute position : Real;
			attribute isOpen : Boolean;
			
			port inletPort : FluidPort;
			port outletPort : FluidPort;
			
			perform action controlFlow : ControlValveFlow;
		}
		
		action def PumpFluid {
			in fluidIn : Fluid;
			in shaftSpeed : RotationalSpeed;
			in shaftTorque : Torque;
			out fluidOut : Fluid;
			out outletPressure : Pressure;
			out deliveredFlow : FlowRate;
			
			action formProgressiveCavities {
				doc /* Rotor rotation creates sealed cavities between rotor and stator */
			}
			
			action advanceFluidThroughCavities {
				doc /* Progressive cavities move fluid axially from inlet to outlet */
			}
			
			action maintainCavitySeal {
				doc /* Elastomeric stator maintains seal between adjacent cavities */
			}
			
			action calculateFlowRate {
				doc /* Flow rate proportional to rotor speed and cavity volume */
			}
			
			first formProgressiveCavities;
			then advanceFluidThroughCavities;
			then maintainCavitySeal;
			then calculateFlowRate;
		}
		
		action def DriveMotor {
			in electricalPower : Power;
			out outputTorque : Torque;
			out outputSpeed : RotationalSpeed;
			
			action convertElectricalToMechanical;
			action generateRotationalMotion;
			action deliverTorque;
			
			first convertElectricalToMechanical;
			then generateRotationalMotion;
			then deliverTorque;
		}
		
		action def RelievePressure {
			attribute pressureExceedsSetpoint : Boolean;
			attribute pressureNormalized : Boolean;
			
			action monitorInletPressure;
			action openWhenExceeded;
			action dischargeExcessFluid;
			action closeWhenNormalized;
			
			first monitorInletPressure;
			then decide;
				if pressureExceedsSetpoint then openWhenExceeded;
			then dischargeExcessFluid;
			then decide;
				if pressureNormalized then closeWhenNormalized;
		}
		
		action def ControlValveFlow {
			action receiveCommand;
			action adjustPosition;
			action modulateFlow;
			
			first receiveCommand;
			then adjustPosition;
			then modulateFlow;
		}
		
		signal StartCommand;
		signal StopCommand;
		signal FaultDetected;
		signal FaultCleared;
		
		state def PumpOperatingStates {
			attribute speedReached : Boolean;
			attribute pressureHigh : Boolean;
			attribute pressureNormal : Boolean;
			attribute flowLow : Boolean;
			attribute flowRestored : Boolean;
			attribute speedZero : Boolean;
			
			entry; then stopped;
			
			state stopped {
				doc /* Pump is not running, no fluid movement */
			}
			
			state starting {
				doc /* Pump is accelerating to operating speed */
			}
			
			state normalOperation {
				doc /* Pump operating at design conditions */
			}
			
			state highPressure {
				doc /* Outlet pressure approaching maximum limit */
			}
			
			state lowFlow {
				doc /* Flow rate below nominal due to cavitation or blockage */
			}
			
			state stopping {
				doc /* Pump is decelerating to stop */
			}
			
			state fault {
				doc /* Abnormal condition detected requiring shutdown */
			}
			
			transition stopped_to_starting
				first stopped
				accept StartCommand
				then starting;
			
			transition starting_to_normalOperation
				first starting
				if speedReached
				then normalOperation;
			
			transition normalOperation_to_highPressure
				first normalOperation
				if pressureHigh
				then highPressure;
			
			transition highPressure_to_normalOperation
				first highPressure
				if pressureNormal
				then normalOperation;
			
			transition normalOperation_to_lowFlow
				first normalOperation
				if flowLow
				then lowFlow;
			
			transition lowFlow_to_normalOperation
				first lowFlow
				if flowRestored
				then normalOperation;
			
			transition normalOperation_to_stopping
				first normalOperation
				accept StopCommand
				then stopping;
			
			transition stopping_to_stopped
				first stopping
				if speedZero
				then stopped;
			
			transition any_to_fault
				first normalOperation
				accept FaultDetected
				then fault;
			
			transition fault_to_stopped
				first fault
				accept FaultCleared
				then stopped;
		}
		
		requirement def WendelkolbenPumpRequirement {
			doc /* Performance requirements for Wendelkolben pump */
			
			subject pump : WendelkolbenPump;
			
			assert constraint flowCapability {
				doc /* Pump shall deliver specified volumetric flow rate */
				pump.nominalFlowRate >= 5.0 and pump.nominalFlowRate <= 200.0
			}
			
			assert constraint pressureCapability {
				doc /* Pump shall generate required discharge pressure */
				pump.maxPressure >= 500000.0
			}
			
			assert constraint efficiency {
				doc /* Pump shall operate at minimum volumetric efficiency */
				pump.volumetricEfficiency >= 0.85
			}
		}
		
		requirement def SubsystemReliabilityRequirement {
			doc /* Reliability and safety requirements for pumping subsystem */
			text "Subsystem shall operate continuously for 8000 hours with pressure protection and leak prevention.";
		}
	}
	
	package Usages {
		import Definitions::*;
		
		part wendelkolbenPumpingSubsystem {
			doc /* 
			 * Complete pumping subsystem using Wendelkolben pump
			 * to transfer viscous fluid from supply tank to receiving tank
			 */
			
			part supplyTank : SupplyTank {
				attribute redefines capacity = 5000.0;
				attribute redefines currentLevel = 4000.0;
				attribute redefines minLevel = 500.0;
			}
			
			part suction_isolationValve : IsolationValve {
				attribute redefines isOpen = true;
			}
			
			part inletPressureSensor : PressureTransducer {
				attribute redefines accuracy = 0.25;
				attribute redefines range = 200000.0;
			}
			
			part driveMotor : ElectricMotor {
				attribute redefines ratedPower = 22000.0;
				attribute redefines ratedSpeed = 1450.0;
				attribute redefines motorEfficiency = 0.93;
				attribute redefines poles = 4;
			}
			
			part wendelkolbenPump : WendelkolbenPump {
				attribute redefines rotorDiameter = 0.08;
				attribute redefines rotorLength = 0.5;
				attribute redefines helixPitch = 0.15;
				attribute redefines numberOfLobes = 1;
				attribute redefines operatingSpeed = 1450.0;
				attribute redefines maxPressure = 1200000.0;
				attribute redefines nominalFlowRate = 50.0;
				attribute redefines volumetricEfficiency = 0.90;
			}
			
			part dischargePressureSensor : PressureTransducer {
				attribute redefines accuracy = 0.25;
				attribute redefines range = 2000000.0;
			}
			
			part flowMeter : FlowTransducer {
				attribute redefines accuracy = 1.0;
				attribute redefines range = 100.0;
			}
			
			part reliefValve : ReliefValve {
				attribute redefines setPoint = 1000000.0;
				attribute redefines crackingPressure = 950000.0;
				attribute redefines fullOpenPressure = 1050000.0;
			}
			
			part discharge_isolationValve : IsolationValve {
				attribute redefines isOpen = true;
			}
			
			part receivingTank : ReceivingTank {
				attribute redefines capacity = 3000.0;
				attribute redefines currentLevel = 500.0;
				attribute redefines maxLevel = 2800.0;
				attribute redefines operatingPressure = 800000.0;
			}
			
			flow of fluid : Fluid
				from supplyTank.outlet.fluidOut 
				to suction_isolationValve.inletPort.fluidIn;
			
			flow of fluid : Fluid
				from suction_isolationValve.outletPort.fluidOut 
				to wendelkolbenPump.inletPort.fluidIn;
			
			flow of fluid : Fluid
				from wendelkolbenPump.outletPort.fluidOut 
				to flowMeter.measurementPort.fluidIn;
			
			flow of fluid : Fluid
				from flowMeter.measurementPort.fluidOut 
				to discharge_isolationValve.inletPort.fluidIn;
			
			flow of fluid : Fluid
				from discharge_isolationValve.outletPort.fluidOut 
				to receivingTank.inlet.fluidIn;
			
			bind inletPressureSensor.sensingPort.fluidIn = wendelkolbenPump.inletPort.fluidIn;
			bind dischargePressureSensor.sensingPort.fluidIn = wendelkolbenPump.outletPort.fluidOut;
			bind reliefValve.inletPort.fluidIn = wendelkolbenPump.outletPort.fluidOut;
			
			connection motorToPumpCoupling 
				connect driveMotor.mechanicalOutput to wendelkolbenPump.driveShaft;
			
			satisfy pumpPerformance : WendelkolbenPumpRequirement {
				subject redefines pump = wendelkolbenPump;
			}
			
			satisfy subsystemReliability : SubsystemReliabilityRequirement;
		}
	}
}
