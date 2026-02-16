package KearnyAirPumpSubsystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def Fluid {
		attribute density : MassDensityValue;
		attribute volume : VolumeValue;
		attribute pressure : PressureValue;
	}
	
	item def CompressedAir {
		attribute pressure : PressureValue;
		attribute volume : VolumeValue;
		attribute temperature : TemperatureValue;
	}
	
	port def FluidPort {
		out item fluid : Fluid;
	}
	
	port def AirPort {
		out item air : CompressedAir;
	}
	
	part def CheckValve {
		port inlet : ~FluidPort;
		port outlet : FluidPort;
		attribute crackingPressure : PressureValue;
		attribute isOpen : Boolean;
	}
	
	part def SupplyTank {
		port fluidOut : FluidPort;
		attribute capacity : VolumeValue;
		item storedFluid : Fluid {
			attribute :>> volume;
			attribute :>> pressure;
		}
	}
	
	part def PressureChamber {
		port airIn : ~AirPort;
		port fluidIn : ~FluidPort;
		attribute chamberVolume : VolumeValue;
		item containedAir : CompressedAir {
			attribute :>> pressure;
			attribute :>> volume;
		}
		item containedFluid : Fluid {
			attribute :>> volume;
		}
	}
	
	part def DischargeTank {
		port fluidIn : ~FluidPort;
		attribute capacity : VolumeValue;
		item receivedFluid : Fluid {
			attribute :>> volume;
		}
	}
	
	part def ManualBellows {
		port airOut : AirPort;
		attribute maxVolume : VolumeValue;
		attribute minVolume : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute compressionRatio : Real;
	}
	
	action def IntakePhase {
		in inletValveState : Boolean;
		out fluidDrawn : VolumeValue;
	}
	
	action def CompressionPhase {
		in airPressure : PressureValue;
		in fluidVolume : VolumeValue;
		out pressurizedVolume : VolumeValue;
	}
	
	action def DischargePhase {
		in outletValveState : Boolean;
		in pressurizedVol : VolumeValue;
		out volumeTransferred : VolumeValue;
	}
	
	action def PumpingAction {
		in strokeVol : VolumeValue;
		in operatingPress : PressureValue;
		out volumeTransferred : VolumeValue;
		
		action intakePhase : IntakePhase {
			in inletValveState : Boolean;
			out fluidDrawn : VolumeValue;
		}
		
		then action compressionPhase : CompressionPhase {
			in airPressure : PressureValue;
			in fluidVolume : VolumeValue;
			out pressurizedVolume : VolumeValue;
		}
		
		then action dischargePhase : DischargePhase {
			in outletValveState : Boolean;
			in pressurizedVol : VolumeValue;
			out :>> volumeTransferred;
		}
	}
	
	state def PumpOperationStates {
		entry; then idle;
		
		state idle {
			entry assign inletValveClosed = true;
			entry assign outletValveClosed = true;
		}
		
		transition idle_to_intake
			first idle
			accept at startPump
			then intake;
		
		state intake {
			entry assign inletValveOpen = true;
			entry assign outletValveClosed = true;
			do action drawFluid;
		}
		
		transition intake_to_compression
			first intake
			accept when supplyTankFilled
			then compression;
		
		state compression {
			entry assign inletValveClosed = true;
			entry assign outletValveClosed = true;
			do action pressurizeFluid;
		}
		
		transition compression_to_discharge
			first compression
			accept when targetPressureReached
			then discharge;
		
		state discharge {
			entry assign inletValveClosed = true;
			entry assign outletValveOpen = true;
			do action expelFluid;
		}
		
		transition discharge_to_intake
			first discharge
			accept when dischargeCycleComplete
			then intake;
		
		transition any_to_idle
			first intake, compression, discharge
			accept at stopPump
			then idle;
	}
	
	part def KearnyAirPump {
		attribute strokeVolume : VolumeValue;
		attribute operatingPressure : PressureValue;
		attribute strokeFrequency : FrequencyValue;
		attribute flowRate : VolumeFlowRateValue;
		
		port fluidInlet : ~FluidPort;
		port fluidOutlet : FluidPort;
		port airSource : ~AirPort;
		
		part inletValve : CheckValve {
			attribute :>> crackingPressure = 500.0 [Pa];
		}
		
		part outletValve : CheckValve {
			attribute :>> crackingPressure = 1000.0 [Pa];
		}
		
		part supplyReservoir : SupplyTank {
			attribute :>> capacity = 0.025 [m³];
		}
		
		part pressureVessel : PressureChamber {
			attribute :>> chamberVolume = 0.020 [m³];
		}
		
		part bellowsUnit : ManualBellows {
			attribute :>> maxVolume = 0.003 [m³];
			attribute :>> minVolume = 0.0005 [m³];
			attribute :>> compressionRatio = 6.0;
		}
		
		bind fluidInlet = inletValve.inlet;
		connect inletValve.outlet to supplyReservoir.fluidOut;
		connect supplyReservoir.fluidOut to pressureVessel.fluidIn;
		connect pressureVessel.fluidIn to outletValve.inlet;
		bind outletValve.outlet = fluidOutlet;
		
		bind airSource = bellowsUnit.airOut;
		connect bellowsUnit.airOut to pressureVessel.airIn;
		
		perform action pumpingOperation : PumpingAction;
		exhibit state pumpStateMachine : PumpOperationStates;
	}
	
	calc def CalculateFlowRate {
		in strokeVolume : VolumeValue;
		in frequency : FrequencyValue;
		return flowRate : VolumeFlowRateValue;
	}
	
	calc def CalculatePressureRise {
		in airPressure : PressureValue;
		in fluidDensity : MassDensityValue;
		in chamberVolume : VolumeValue;
		return pressureIncrease : PressureValue;
	}
	
	requirement def PumpPerformanceRequirement {
		doc /* The Kearny air pump shall transfer fluid at a specified minimum flow rate. */
		
		subject pump : KearnyAirPump;
		
		require minimumFlowRate {
			attribute requiredFlow : VolumeFlowRateValue = 0.00008 [m³/s];
			assert constraint { pump.flowRate >= requiredFlow }
		}
	}
	
	requirement def PressureCapabilityRequirement {
		doc /* The pump shall generate sufficient pressure to overcome discharge head. */
		
		subject pump : KearnyAirPump;
		
		require minimumPressure {
			attribute requiredPressure : PressureValue = 3500.0 [Pa];
			assert constraint { pump.operatingPressure >= requiredPressure }
		}
	}
	
	requirement def ReliabilityRequirement {
		doc /* The pump shall operate continuously for minimum duration without failure. */
		
		subject pump : KearnyAirPump;
		
		require operatingDuration {
			attribute minimumDuration : TimeValue = 7200.0 [s];
		}
	}
	
	requirement def SystemRequirement {
		doc /* The pumping subsystem shall move fluid from source to destination using Kearny air pump. */
		
		require performanceReq : PumpPerformanceRequirement;
		require pressureReq : PressureCapabilityRequirement;
		require reliabilityReq : ReliabilityRequirement;
	}
	
	part pumpingSubsystem {
		part sourceReservoir : SupplyTank {
			attribute :>> capacity = 0.500 [m³];
			item :>> storedFluid {
				attribute :>> volume = 0.400 [m³];
				attribute :>> density = 1000.0 [kg/m³];
				attribute :>> pressure = 101325.0 [Pa];
			}
		}
		
		part kearnyPump : KearnyAirPump {
			attribute :>> strokeVolume = 0.002 [m³];
			attribute :>> operatingPressure = 4000.0 [Pa];
			attribute :>> strokeFrequency = 0.5 [Hz];
			
			calc computeFlowRate : CalculateFlowRate {
				in strokeVolume = kearnyPump.strokeVolume;
				in frequency = kearnyPump.strokeFrequency;
				return flowRate = kearnyPump.flowRate;
			}
		}
		
		part destinationTank : DischargeTank {
			attribute :>> capacity = 0.500 [m³];
			item :>> receivedFluid {
				attribute :>> volume = 0.050 [m³];
			}
		}
		
		flow of fluid : Fluid
			from sourceReservoir.fluidOut.fluid to kearnyPump.fluidInlet.fluid;
		
		flow of fluid : Fluid
			from kearnyPump.fluidOutlet.fluid to destinationTank.fluidIn.fluid;
		
		satisfy systemRequirement : SystemRequirement {
			satisfy :>> performanceReq {
				subject pump = kearnyPump;
			}
			satisfy :>> pressureReq {
				subject pump = kearnyPump;
			}
			satisfy :>> reliabilityReq {
				subject pump = kearnyPump;
			}
		}
	}
}
