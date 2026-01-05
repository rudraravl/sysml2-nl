package 'Flexible Impeller Pump System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def RotationalSpeed :> ISQ::AngularVelocityValue;
	attribute def FlowRate :> ISQ::VolumeFlowRateValue;
	attribute def Pressure :> ISQ::PressureValue;
	attribute def Viscosity :> ISQ::DynamicViscosityValue;
	attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
	attribute def Torque :> ISQ::TorqueValue;
	
	item def Fluid {
		attribute viscosity : Viscosity;
		attribute temperature : Temperature;
		attribute density : ISQ::DensityValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	item def MechanicalPower {
		attribute torque : Torque;
		attribute speed : RotationalSpeed;
	}
	
	attribute def StartCommand;
	attribute def StopCommand;
	attribute def EmergencyStop;
	
	port def FluidPort {
		attribute pressure : Pressure;
		attribute flowRate : FlowRate;
	}
	
	port def MechanicalPort {
		attribute torque : Torque;
		attribute speed : RotationalSpeed;
	}
	
	part def ElectricMotor {
		in port powerInput;
		out port shaftOutput : MechanicalPort;
		attribute ratedPower : ISQ::PowerValue;
		attribute ratedSpeed : RotationalSpeed;
		attribute efficiency : Real;
	}
	
	part def DriveShaft {
		in port motorConnection : MechanicalPort;
		out port impellerConnection : MechanicalPort;
		attribute diameter : ISQ::LengthValue;
		attribute length : ISQ::LengthValue;
		attribute material : String;
	}
	
	part def FlexibleImpeller {
		in port driveConnection : MechanicalPort;
		attribute numberOfBlades : Integer;
		attribute bladeThickness : ISQ::LengthValue;
		attribute outerDiameter : ISQ::LengthValue;
		attribute innerDiameter : ISQ::LengthValue;
		attribute material : String;
		attribute flexibilityModulus : ISQ::PressureValue;
	}
	
	part def PumpCasing {
		in port fluidInlet : FluidPort;
		out port fluidOutlet : FluidPort;
		attribute inletDiameter : ISQ::LengthValue;
		attribute outletDiameter : ISQ::LengthValue;
		attribute casingMaterial : String;
		attribute internalClearance : ISQ::LengthValue;
	}
	
	part def SuctionCheckValve {
		in port inlet : FluidPort;
		out port outlet : FluidPort;
		attribute crackingPressure : Pressure;
	}
	
	part def DischargeCheckValve {
		in port inlet : FluidPort;
		out port outlet : FluidPort;
		attribute crackingPressure : Pressure;
	}
	
	action def CompressBlade {
		in rotationSpeed : RotationalSpeed;
		in casingClearance : ISQ::LengthValue;
		in bladeFlexibility : ISQ::PressureValue;
		out bladeDeformation : ISQ::LengthValue;
		out compressionForce : ISQ::ForceValue;
	}
	
	action def CreateVacuum {
		in bladeDeformation : ISQ::LengthValue;
		in rotationSpeed : RotationalSpeed;
		out suctionPressure : Pressure;
	}
	
	action def DrawFluidIn {
		in suctionPressure : Pressure;
		in inletPressure : Pressure;
		in fluidProperties : Fluid;
		out inletFlowRate : FlowRate;
		out volumeDrawn : ISQ::VolumeValue;
	}
	
	action def TransportFluid {
		in volumeDrawn : ISQ::VolumeValue;
		in numberOfBlades : Integer;
		in rotationSpeed : RotationalSpeed;
		out transportedVolume : ISQ::VolumeValue;
	}
	
	action def CompressFluid {
		in transportedVolume : ISQ::VolumeValue;
		in bladeCompression : ISQ::ForceValue;
		out dischargePressure : Pressure;
	}
	
	action def DischargeFluid {
		in dischargePressure : Pressure;
		in transportedVolume : ISQ::VolumeValue;
		in outletPressure : Pressure;
		out outletFlowRate : FlowRate;
	}
	
	action def PumpFluidContinuously {
		in motorSpeed : RotationalSpeed;
		in inletPressure : Pressure;
		in outletPressure : Pressure;
		in fluidProperties : Fluid;
		in impellerBlades : Integer;
		in casingClearance : ISQ::LengthValue;
		in bladeFlexibility : ISQ::PressureValue;
		out deliveredFlowRate : FlowRate;
		out deliveredPressure : Pressure;
		
		first start;
		then action compress : CompressBlade {
			in rotationSpeed = motorSpeed;
			in casingClearance = PumpFluidContinuously::casingClearance;
			in bladeFlexibility = PumpFluidContinuously::bladeFlexibility;
			out bladeDeformation;
			out compressionForce;
		}
		then action createVacuum : CreateVacuum {
			in bladeDeformation = compress.bladeDeformation;
			in rotationSpeed = motorSpeed;
			out suctionPressure;
		}
		then action drawIn : DrawFluidIn {
			in suctionPressure = createVacuum.suctionPressure;
			in inletPressure = PumpFluidContinuously::inletPressure;
			in fluidProperties = PumpFluidContinuously::fluidProperties;
			out inletFlowRate;
			out volumeDrawn;
		}
		then action transport : TransportFluid {
			in volumeDrawn = drawIn.volumeDrawn;
			in numberOfBlades = impellerBlades;
			in rotationSpeed = motorSpeed;
			out transportedVolume;
		}
		then action compressFluid : CompressFluid {
			in transportedVolume = transport.transportedVolume;
			in bladeCompression = compress.compressionForce;
			out dischargePressure;
		}
		then action discharge : DischargeFluid {
			in dischargePressure = compressFluid.dischargePressure;
			in transportedVolume = transport.transportedVolume;
			in outletPressure = PumpFluidContinuously::outletPressure;
			out outletFlowRate;
		}
		then assign deliveredFlowRate := discharge.outletFlowRate;
		then assign deliveredPressure := compressFluid.dischargePressure;
		then done;
	}
	
	state def PumpOperationalStates {
		entry; then off;
		
		state off {
			doc /* Pump is not operating, motor is stopped. */
		}
		
		transition off_to_starting
			first off
			accept StartCommand
			then starting;
		
		state starting {
			doc /* Motor is accelerating to operational speed. */
			entry assign currentSpeed := 0.0;
		}
		
		transition starting_to_running
			first starting
			if currentSpeed >= operationalSpeed
			then running;
		
		state running {
			doc /* Pump is operating at steady state, continuously moving fluid. */
			do action pumpOperation : PumpFluidContinuously;
		}
		
		transition running_to_stopping_normal
			first running
			accept StopCommand
			then stopping;
		
		transition running_to_stopping_emergency
			first running
			accept EmergencyStop
			then stopping;
		
		state stopping {
			doc /* Motor is decelerating, pump is shutting down. */
		}
		
		transition stopping_to_off
			first stopping
			if currentSpeed <= 0.0
			then off;
	}
	
	attribute def operationalSpeed : RotationalSpeed;
	attribute def currentSpeed : RotationalSpeed;
	
	part flexibleImpellerPumpSystem {
		doc /* A flexible impeller pump system that transfers fluid by using a rotating flexible impeller 
		       whose blades compress against the pump casing, creating suction at the inlet and discharge 
		       at the outlet. The system is self-priming and capable of handling viscous fluids and 
		       entrained air. */
		
		attribute systemFlowRate : FlowRate;
		attribute systemInletPressure : Pressure;
		attribute systemOutletPressure : Pressure;
		
		in port electricalSupply;
		in port fluidSource : FluidPort;
		out port fluidDestination : FluidPort;
		in port controlInterface;
		
		part motor : ElectricMotor {
			attribute ratedPower = 1500.0;
			attribute ratedSpeed = 1450.0;
			attribute efficiency = 0.85;
		}
		
		part shaft : DriveShaft {
			attribute diameter = 0.020;
			attribute length = 0.12;
			attribute material = "stainless steel 316";
		}
		
		part impeller : FlexibleImpeller {
			attribute numberOfBlades = 6;
			attribute bladeThickness = 0.004;
			attribute outerDiameter = 0.075;
			attribute innerDiameter = 0.020;
			attribute material = "nitrile rubber";
			attribute flexibilityModulus = 5.0e6;
			
			perform action pumpAction : PumpFluidContinuously {
				in motorSpeed = shaft.motorConnection.speed;
				in inletPressure = flexibleImpellerPumpSystem::systemInletPressure;
				in outletPressure = flexibleImpellerPumpSystem::systemOutletPressure;
				in fluidProperties;
				in impellerBlades = impeller.numberOfBlades;
				in casingClearance = casing.internalClearance;
				in bladeFlexibility = impeller.flexibilityModulus;
				out deliveredFlowRate;
				out deliveredPressure;
			}
		}
		
		part casing : PumpCasing {
			attribute inletDiameter = 0.050;
			attribute outletDiameter = 0.050;
			attribute casingMaterial = "bronze";
			attribute internalClearance = 0.001;
		}
		
		part suctionValve : SuctionCheckValve {
			attribute crackingPressure = 500.0;
		}
		
		part dischargeValve : DischargeCheckValve {
			attribute crackingPressure = 2000.0;
		}
		
		part processFluid : Fluid {
			attribute viscosity = 0.050;
			attribute temperature = 298.15;
			attribute density = 1050.0;
		}
		
		connect electricalSupply to motor.powerInput;
		connect motor.shaftOutput to shaft.motorConnection;
		connect shaft.impellerConnection to impeller.driveConnection;
		connect fluidSource to suctionValve.inlet;
		connect suctionValve.outlet to casing.fluidInlet;
		connect casing.fluidOutlet to dischargeValve.inlet;
		connect dischargeValve.outlet to fluidDestination;
		
		binding systemFlowBinding bind systemFlowRate = impeller.pumpAction.deliveredFlowRate;
		
		exhibit state pumpStateMachine : PumpOperationalStates;
	}
	
	requirement def FlowPerformanceRequirement {
		doc /* The flexible impeller pump shall deliver specified minimum flow rate under defined operating conditions. */
		
		subject pump;
		
		require constraint minimumFlowRate {
			pump.systemFlowRate >= 120.0
		}
		
		require constraint flowRateStability {
			doc /* Flow rate variation shall not exceed 5% during continuous operation. */
		}
	}
	
	requirement def PressureCapabilityRequirement {
		doc /* The pump shall operate within specified pressure ranges without damage or performance degradation. */
		
		subject pump;
		
		require constraint maximumDischargePressure {
			pump.systemOutletPressure <= 600000.0
		}
		
		require constraint minimumSuctionPressure {
			pump.systemInletPressure >= -50000.0
		}
	}
	
	requirement def ImpellerDurabilityRequirement {
		doc /* The flexible impeller shall maintain structural integrity and flexibility throughout its service life. */
		
		subject impeller;
		
		require constraint bladeFlexibilityRetention {
			impeller.flexibilityModulus >= 4.0e6
		}
		
		require constraint operatingTemperatureLimit {
			doc /* Impeller material shall withstand continuous operation at temperatures up to 80°C. */
		}
		
		require constraint dryRunProtection {
			doc /* Impeller shall survive brief dry-run conditions without catastrophic failure. */
		}
	}
	
	requirement def SelfPrimingRequirement {
		doc /* The pump shall be capable of self-priming from a dry start condition. */
		
		subject pump;
		
		require constraint primingTime {
			doc /* Pump shall achieve full prime within 60 seconds from dry start with 3 meter suction lift. */
		}
		
		require constraint airHandlingCapability {
			doc /* Pump shall handle entrained air up to 20% by volume without loss of prime. */
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the flexible impeller pump system. */
		
		subject flexibleImpellerPumpSystem;
		
		require req1 : FlowPerformanceRequirement;
		require req2 : PressureCapabilityRequirement;
		require req3 : ImpellerDurabilityRequirement;
		require req4 : SelfPrimingRequirement;
	}
}
