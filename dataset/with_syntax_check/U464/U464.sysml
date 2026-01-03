package 'Airlift Pumping Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute volume : Real;
		}
		
		item def CompressedAir {
			attribute pressure : Real;
			attribute flowRate : Real;
		}
		
		item def AirFluidMixture {
			attribute mixtureDensity : Real;
			attribute voidFraction : Real;
		}
		
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;
		attribute def LengthValue :> Real;
		attribute def VolumeValue :> Real;
		
		port def FluidPort {
			out item fluidOut : Fluid;
		}
		
		port def AirPort {
			out item airOut : CompressedAir;
		}
		
		port def MixturePort {
			out item mixtureOut : AirFluidMixture;
		}
		
		part def SourceReservoir {
			port fluidOutPort : FluidPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : LengthValue;
			item storedFluid : Fluid {
				attribute :>> density = 1000.0;
				attribute :>> volume;
			}
			attribute fillLevel : Real = storedFluid.volume / capacity;
		}
		
		part def AirCompressor {
			port airOutPort : AirPort;
			attribute operatingPressure : PressureValue;
			attribute maxFlowRate : FlowRateValue;
			
			perform action compressAir : CompressAir;
		}
		
		part def PressureRegulator {
			port airInPort : ~AirPort;
			port airOutPort : AirPort;
			attribute setPointPressure : PressureValue;
			
			perform action regulatePressure : RegulatePressure;
		}
		
		part def AirliftPump {
			doc /*
			 * An airlift pump uses compressed air injected at the bottom of a riser pipe
			 * to create a buoyant air-fluid mixture that rises due to density difference,
			 * lifting fluid to a higher elevation without mechanical moving parts.
			 */
			
			port fluidInPort : ~FluidPort;
			port airInPort : ~AirPort;
			port mixtureOutPort : MixturePort;
			
			attribute riserDiameter : LengthValue;
			attribute riserLength : LengthValue;
			attribute submergenceDepth : LengthValue;
			attribute liftHeight : LengthValue;
			attribute efficiency : Real;
			
			part riserPipe {
				attribute diameter : LengthValue = riserDiameter;
				attribute length : LengthValue = riserLength;
			}
			
			part airInjectionPoint {
				attribute depth : LengthValue = submergenceDepth;
			}
			
			perform action pumpFluid : AirliftPumping;
			
			assert constraint submergenceRatio {
				doc /*
				 * Airlift pumps require submergence ratio (submergence/total lift)
				 * typically between 0.4 and 0.7 for efficient operation.
				 */
				submergenceDepth / (submergenceDepth + liftHeight) >= 0.4 and
				submergenceDepth / (submergenceDepth + liftHeight) <= 0.7
			}
		}
		
		part def AirFluidSeparator {
			port mixtureInPort : ~MixturePort;
			port fluidOutPort : FluidPort;
			port airVentPort : AirPort;
			
			perform action separateMixture : SeparateMixture;
		}
		
		part def DestinationTank {
			port fluidInPort : ~FluidPort;
			attribute capacity : VolumeValue;
			attribute currentVolume : VolumeValue;
			attribute fillLevel : Real = currentVolume / capacity;
			item receivedFluid : Fluid;
		}
		
		part def FlowMeter {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute measuredFlowRate : FlowRateValue;
			
			perform action measureFlow : MeasureFlow;
		}
		
		action def CompressAir {
			out compressedAir : CompressedAir;
		}
		
		action def RegulatePressure {
			in airIn : CompressedAir;
			out airOut : CompressedAir;
		}
		
		action def AirliftPumping {
			in fluidIn : Fluid;
			in airIn : CompressedAir;
			out mixtureOut : AirFluidMixture;
			
			first start;
			then action injectAir {
				doc /* Inject compressed air at bottom of riser pipe */
				in air = airIn;
			}
			then action mixAirFluid {
				doc /* Create air-fluid mixture in riser */
				in fluid = fluidIn;
				in air = injectAir.air;
				out mixture;
			}
			then action liftMixture {
				doc /* Buoyancy forces lift less dense mixture upward */
				in mixture = mixAirFluid.mixture;
				out risingMixture = mixtureOut;
			}
			then done;
		}
		
		action def SeparateMixture {
			in mixtureIn : AirFluidMixture;
			out fluidOut : Fluid;
			out airOut : CompressedAir;
		}
		
		action def MeasureFlow {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
			out flowRate : FlowRateValue;
		}
		
		state def AirliftPumpStates {
			entry; then idle;
			
			state idle {
				doc /* Pump is not operating */
			}
			
			transition idle_to_starting
				first idle
				accept StartSignal
				then starting;
			
			state starting {
				doc /* Air compressor starting, building pressure */
				entry action buildPressure;
			}
			
			transition starting_to_operating
				first starting
				accept PressureReachedSignal
				then operating;
			
			state operating {
				doc /* Pump actively lifting fluid */
				entry action beginPumping;
				do action continuousPumping;
			}
			
			transition operating_to_stopping
				first operating
				accept StopSignal
				then stopping;
			
			transition operating_to_fault
				first operating
				accept FaultSignal
				then fault;
			
			state stopping {
				doc /* Shutting down air supply */
				entry action shutdownAir;
			}
			
			transition stopping_to_idle
				first stopping
				accept AirPressureZeroSignal
				then idle;
			
			state fault {
				doc /* System fault detected */
				entry action emergencyShutdown;
			}
			
			transition fault_to_idle
				first fault
				accept ResetSignal
				then idle;
		}
		
		requirement def AirliftPumpingRequirement {
			doc /*
			 * The airlift pumping subsystem shall move fluid from a source reservoir
			 * to a destination tank at a higher elevation using compressed air injection.
			 */
			
			subject pump : AirliftPump;
			
			require constraint liftCapability {
				doc /* Pump shall lift fluid to specified height */
				pump.liftHeight > 0.0
			}
			
			require constraint airSupply {
				doc /* Adequate air supply pressure shall be maintained */
				pump.airInPort.airOut.pressure >= 
					1.5 * pump.submergenceDepth * 9.81 * 1000.0
			}
		}
		
		requirement def SystemEfficiencyRequirement {
			doc /*
			 * The airlift pump shall operate with minimum efficiency of 30%.
			 */
			
			subject pump : AirliftPump;
			
			require constraint minEfficiency {
				pump.efficiency >= 0.30
			}
		}
		
		requirement def FlowRateRequirement {
			doc /*
			 * The pumping subsystem shall deliver minimum flow rate.
			 */
			
			attribute minFlowRate : FlowRateValue;
			
			require constraint flowRateMin {
				doc /* Measured flow rate shall meet minimum requirement */
			}
		}
	}
	
	package Usages {
		import Definitions::*;
		
		part airliftPumpingSystem {
			doc /*
			 * Complete airlift pumping subsystem with air compressor, pressure regulation,
			 * airlift pump, separation, and monitoring instrumentation.
			 */
			
			part sourceReservoir : SourceReservoir {
				attribute :>> capacity = 50.0;
				attribute :>> currentLevel = 8.0;
				item :>> storedFluid : Fluid {
					attribute :>> density = 1000.0;
					attribute :>> volume = 40.0;
				}
			}
			
			flow of fluid : Fluid
				from sourceReservoir.fluidOutPort.fluidOut 
				to airliftPump.fluidInPort.fluidOut;
			
			part airCompressor : AirCompressor {
				attribute :>> operatingPressure = 500000.0;
				attribute :>> maxFlowRate = 0.05;
				
				perform action :>> compressAir : CompressAir {
					out :>> compressedAir = airOutPort.airOut;
				}
			}
			
			flow of compressedAir : CompressedAir
				from airCompressor.airOutPort.airOut
				to pressureRegulator.airInPort.airOut;
			
			part pressureRegulator : PressureRegulator {
				attribute :>> setPointPressure = 350000.0;
				
				perform action :>> regulatePressure : RegulatePressure {
					in :>> airIn = airInPort.airOut;
					out :>> airOut = airOutPort.airOut;
				}
			}
			
			flow of regulatedAir : CompressedAir
				from pressureRegulator.airOutPort.airOut
				to airliftPump.airInPort.airOut;
			
			part airliftPump : AirliftPump {
				attribute :>> riserDiameter = 0.15;
				attribute :>> riserLength = 12.0;
				attribute :>> submergenceDepth = 8.0;
				attribute :>> liftHeight = 4.0;
				attribute :>> efficiency = 0.35;
				
				perform action :>> pumpFluid : AirliftPumping {
					in :>> fluidIn = fluidInPort.fluidOut;
					in :>> airIn = airInPort.airOut;
					out :>> mixtureOut = mixtureOutPort.mixtureOut;
				}
				
				exhibit state pumpStateMachine : AirliftPumpStates;
			}
			
			flow of mixture : AirFluidMixture
				from airliftPump.mixtureOutPort.mixtureOut
				to separator.mixtureInPort.mixtureOut;
			
			part separator : AirFluidSeparator {
				perform action :>> separateMixture : SeparateMixture {
					in :>> mixtureIn = mixtureInPort.mixtureOut;
					out :>> fluidOut = fluidOutPort.fluidOut;
					out :>> airOut = airVentPort.airOut;
				}
			}
			
			flow of separatedFluid : Fluid
				from separator.fluidOutPort.fluidOut
				to dischargeMeter.fluidInPort.fluidOut;
			
			part dischargeMeter : FlowMeter {
				attribute :>> measuredFlowRate = 0.02;
				
				perform action :>> measureFlow : MeasureFlow {
					in :>> fluidIn = fluidInPort.fluidOut;
					out :>> fluidOut = fluidOutPort.fluidOut;
					out :>> flowRate = measuredFlowRate;
				}
			}
			
			flow of measuredFluid : Fluid
				from dischargeMeter.fluidOutPort.fluidOut
				to destinationTank.fluidInPort.fluidOut;
			
			part destinationTank : DestinationTank {
				attribute :>> capacity = 30.0;
				attribute :>> currentVolume = 5.0;
				
				flow fluidInPort.fluidOut to receivedFluid;
			}
			
			satisfy pumpingReq : AirliftPumpingRequirement {
				subject pump = airliftPump;
			}
			
			satisfy efficiencyReq : SystemEfficiencyRequirement {
				subject pump = airliftPump;
			}
			
			satisfy flowReq : FlowRateRequirement {
				attribute :>> minFlowRate = 0.015;
				
				assert constraint :>> flowRateMin {
					dischargeMeter.measuredFlowRate >= minFlowRate
				}
			}
			
			assert constraint tankNotOverfilled {
				doc /* Destination tank shall not exceed capacity */
				destinationTank.currentVolume <= destinationTank.capacity
			}
			
			assert constraint adequateSource {
				doc /* Source reservoir shall maintain sufficient level */
				sourceReservoir.currentLevel >= airliftPump.submergenceDepth
			}
		}
	}
}
