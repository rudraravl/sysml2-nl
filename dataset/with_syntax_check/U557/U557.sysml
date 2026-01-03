package 'Rushton Turbine Mixing System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
	attribute def FluidViscosity :> ISQ::DynamicViscosityValue;
	attribute def FluidDensity :> ISQ::DensityValue;
	attribute def MixingPower :> ISQ::PowerValue;
	attribute def FlowRate :> ISQ::VolumeFlowRateValue;
	attribute def TurbulenceLevel :> Real;
	attribute def MixingEfficiency :> Real;
	
	attribute def MotorStartCommand;
	attribute def MotorStopCommand;
	attribute def SpeedSetpoint;
	
	item def ElectricalPower;
	item def MechanicalPower;
	item def FluidMixture;
	
	port def PowerPort {
		in power : ElectricalPower;
	}
	
	port def MechanicalPort {
		out torque : ISQ::TorqueValue;
		out speed : RotationalSpeed;
	}
	
	port def FluidPort {
		inout fluid : FluidMixture;
	}
	
	part def ElectricMotor {
		attribute ratedPower : MixingPower;
		attribute currentSpeed : RotationalSpeed;
		port electricalInput : PowerPort;
		port mechanicalOutput : MechanicalPort;
	}
	
	part def DriveShaft {
		attribute diameter : ISQ::LengthValue;
		attribute length : ISQ::LengthValue;
		port motorInterface : ~MechanicalPort;
		port impellerInterface : MechanicalPort;
	}
	
	part def RushtonImpeller {
		attribute diskDiameter : ISQ::LengthValue;
		attribute bladeHeight : ISQ::LengthValue;
		attribute bladeWidth : ISQ::LengthValue;
		attribute numberOfBlades : Integer;
		port shaftInterface : ~MechanicalPort;
	}
	
	part def MixingVessel {
		attribute vesselDiameter : ISQ::LengthValue;
		attribute vesselHeight : ISQ::LengthValue;
		attribute liquidLevel : ISQ::LengthValue;
		port fluidInlet : FluidPort;
		port fluidOutlet : FluidPort;
		part baffles[4];
	}
	
	part def FluidMedium {
		attribute viscosity : FluidViscosity;
		attribute density : FluidDensity;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	action def TransmitRotationalPower {
		in inputTorque : ISQ::TorqueValue;
		in rotationSpeed : RotationalSpeed;
		out outputTorque : ISQ::TorqueValue;
	}
	
	action def GenerateRadialFlow {
		in impellerSpeed : RotationalSpeed;
		in fluidProperties : FluidMedium;
		out radialVelocity : ISQ::SpeedValue;
		out flowPattern : FlowRate;
	}
	
	action def CreateCirculation {
		in radialFlow : FlowRate;
		in vesselGeometry : ISQ::LengthValue;
		out circulationFlow : FlowRate;
		out turbulence : TurbulenceLevel;
	}
	
	action def BlendComponents {
		in circulationFlow : FlowRate;
		in turbulence : TurbulenceLevel;
		in fluidMedium : FluidMedium;
		out mixingQuality : MixingEfficiency;
		out homogeneity : Real;
	}
	
	action def PerformMixing {
		in targetSpeed : RotationalSpeed;
		in processFluid : FluidMedium;
		out mixingResult : MixingEfficiency;
		
		action transmitPower : TransmitRotationalPower {
			in inputTorque : ISQ::TorqueValue;
			in rotationSpeed = targetSpeed;
			out outputTorque : ISQ::TorqueValue;
		}
		
		flow transmitPower.outputTorque to generateFlow.impellerSpeed;
		
		action generateFlow : GenerateRadialFlow {
			in impellerSpeed : RotationalSpeed;
			in fluidProperties = processFluid;
			out radialVelocity : ISQ::SpeedValue;
			out flowPattern : FlowRate;
		}
		
		flow generateFlow.flowPattern to createCirculation.radialFlow;
		
		action createCirculation : CreateCirculation {
			in radialFlow : FlowRate;
			in vesselGeometry : ISQ::LengthValue;
			out circulationFlow : FlowRate;
			out turbulence : TurbulenceLevel;
		}
		
		flow createCirculation.circulationFlow to blendComponents.circulationFlow;
		flow createCirculation.turbulence to blendComponents.turbulence;
		
		action blendComponents : BlendComponents {
			in circulationFlow : FlowRate;
			in turbulence : TurbulenceLevel;
			in fluidMedium = processFluid;
			out mixingQuality : MixingEfficiency;
			out homogeneity : Real;
		}
	}
	
	part rushtonMixingSystem {
		attribute operatingSpeed : RotationalSpeed;
		attribute processFluid : FluidMedium;
		
		part motor : ElectricMotor {
			attribute ratedPower = 7500.0 [SI::W];
		}
		
		part shaft : DriveShaft {
			attribute diameter = 0.05 [SI::m];
			attribute length = 1.5 [SI::m];
			
			perform action transmitRotation : TransmitRotationalPower;
		}
		
		part impeller : RushtonImpeller {
			attribute diskDiameter = 0.4 [SI::m];
			attribute bladeHeight = 0.08 [SI::m];
			attribute bladeWidth = 0.1 [SI::m];
			attribute numberOfBlades = 6;
			
			perform mixingProcess.generateFlow;
		}
		
		part vessel : MixingVessel {
			attribute vesselDiameter = 1.2 [SI::m];
			attribute vesselHeight = 1.8 [SI::m];
			attribute liquidLevel = 1.5 [SI::m];
			
			perform mixingProcess.createCirculation;
		}
		
		connect motor.mechanicalOutput to shaft.motorInterface;
		connect shaft.impellerInterface to impeller.shaftInterface;
		
		perform action mixingProcess : PerformMixing {
			in targetSpeed = operatingSpeed;
			in processFluid = rushtonMixingSystem::processFluid;
			out mixingResult : MixingEfficiency;
			
			loop {
				accept startCommand : MotorStartCommand;
				then action {
					action transmitPower : TransmitRotationalPower {
						in inputTorque : ISQ::TorqueValue;
						in rotationSpeed = operatingSpeed;
						out outputTorque : ISQ::TorqueValue;
					}
					
					flow transmitPower.outputTorque to generateFlow.impellerSpeed;
					
					action generateFlow : GenerateRadialFlow {
						in impellerSpeed : RotationalSpeed;
						in fluidProperties = processFluid;
						out radialVelocity : ISQ::SpeedValue;
						out flowPattern : FlowRate;
					}
					
					flow generateFlow.flowPattern to createCirculation.radialFlow;
					
					action createCirculation : CreateCirculation {
						in radialFlow : FlowRate;
						in vesselGeometry = vessel.vesselDiameter;
						out circulationFlow : FlowRate;
						out turbulence : TurbulenceLevel;
					}
					
					flow createCirculation.circulationFlow to blendComponents.circulationFlow;
					flow createCirculation.turbulence to blendComponents.turbulence;
					
					action blendComponents : BlendComponents {
						in circulationFlow : FlowRate;
						in turbulence : TurbulenceLevel;
						in fluidMedium = processFluid;
						out mixingQuality : MixingEfficiency;
						out homogeneity : Real;
					}
				}
				then accept stopCommand : MotorStopCommand;
			}
		}
	}
	
	requirement systemObjective {
		doc /* The Rushton turbine mixing system shall effectively disperse and blend 
		       fluid components within a vessel by generating high-intensity radial flow 
		       patterns that promote turbulent mixing and achieve uniform distribution 
		       throughout the entire fluid volume. */
		
		requirement radialFlowGeneration {
			doc /* The Rushton impeller shall generate strong radial flow directed outward 
			       from the impeller disk toward the vessel walls to initiate mixing. */
		}
		
		requirement circulationEstablishment {
			doc /* The radial flow shall induce vertical circulation loops within the vessel 
			       to ensure complete fluid turnover and mixing throughout the volume. */
		}
		
		requirement homogeneityAchievement {
			doc /* The mixing operation shall achieve a minimum mixing efficiency of 90% 
			       for uniform distribution of all fluid components. */
		}
		
		require radialFlowGeneration;
		require circulationEstablishment;
		require homogeneityAchievement;
	}
	
	state def MixerOperationalStates {
		entry; then Idle;
		
		state Idle;
		state Starting;
		state Running {
			entry; do perform rushtonMixingSystem::mixingProcess;
		}
		state Stopping;
		state Fault;
		
		transition first Idle
			accept MotorStartCommand
			then Starting;
			
		transition Starting
			accept when rushtonMixingSystem::motor.currentSpeed >= rushtonMixingSystem::operatingSpeed
			then Running;
			
		transition Running
			accept MotorStopCommand
			then Stopping;
			
		transition Stopping
			accept when rushtonMixingSystem::motor.currentSpeed <= 0.0 [SI::rpm]
			then Idle;
			
		transition Running
			accept when false
			then Fault;
			
		transition Starting
			accept when false
			then Fault;
			
		transition Fault
			accept when true
			then Idle;
	}
}
