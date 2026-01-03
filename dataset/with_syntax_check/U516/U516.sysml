package 'Humphrey Pump Subsystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute density : Real;
			attribute viscosity : Real;
			attribute temperature : Real;
		}
		
		item def FuelAirMixture {
			attribute fuelRatio : Real;
			attribute temperature : Real;
		}
		
		item def ExhaustGas {
			attribute temperature : Real;
			attribute pressure : Real;
		}
		
		attribute def PressureValue :> Real;
		
		attribute def VolumeValue :> Real;
		
		attribute def FlowRateValue :> Real;
		
		attribute def FrequencyValue :> Real;
		
		port def FluidPort {
			attribute pressure : PressureValue;
			attribute flowRate : FlowRateValue;
			inout item fluid : Fluid;
		}
		
		port def FuelPort {
			in item fuelMixture : FuelAirMixture;
		}
		
		port def ExhaustPort {
			out item exhaust : ExhaustGas;
		}
		
		port def IgnitionPort {
			attribute sparkCommand : Boolean;
		}
		
		part def CheckValve {
			port inletPort : ~FluidPort;
			port outletPort : FluidPort;
			attribute crackingPressure : PressureValue;
			attribute isOpen : Boolean;
		}
		
		part def CombustionChamber {
			port fluidInletPort : ~FluidPort;
			port fluidOutletPort : FluidPort;
			port fuelInletPort : ~FuelPort;
			port exhaustOutletPort : ExhaustPort;
			port ignitionPort : ~IgnitionPort;
			
			attribute volume : VolumeValue;
			attribute currentPressure : PressureValue;
			attribute maxPressure : PressureValue;
			attribute temperature : Real;
			attribute fluidColumnHeight : Real;
		}
		
		part def IgnitionSystem {
			port ignitionTrigger : IgnitionPort;
			attribute sparkEnergy : Real;
			attribute firingFrequency : FrequencyValue;
		}
		
		part def FluidReservoir {
			port outletPort : FluidPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			item storedFluid : Fluid;
		}
		
		part def DischargeTank {
			port inletPort : ~FluidPort;
			attribute capacity : VolumeValue;
			attribute currentLevel : VolumeValue;
			attribute elevation : Real;
			item receivedFluid : Fluid;
		}
		
		part def FuelSupplySystem {
			port fuelOutletPort : FuelPort;
			attribute fuelPressure : PressureValue;
			attribute airFuelRatio : Real;
		}
		
		part def HumphreyPump {
			doc /*
			 * A Humphrey pump uses intermittent combustion to create pressure pulses
			 * that drive a column of fluid. The pump operates without pistons or
			 * moving parts in the pumping chamber, using the inertia of the fluid
			 * column and check valves to achieve pumping action.
			 */
			
			port fluidInletPort : ~FluidPort;
			port fluidOutletPort : FluidPort;
			port fuelSupplyPort : ~FuelPort;
			
			attribute pumpingFrequency : FrequencyValue;
			attribute maxFlowRate : FlowRateValue;
			attribute maxDischargePressure : PressureValue;
			attribute efficiency : Real;
			
			part combustionChamber : CombustionChamber;
			part inletCheckValve : CheckValve;
			part outletCheckValve : CheckValve;
			part ignitionSystem : IgnitionSystem;
			
			binding combustionChamber.fluidInletPort = inletCheckValve.outletPort;
			binding combustionChamber.fluidOutletPort = outletCheckValve.inletPort;
			binding combustionChamber.ignitionPort = ignitionSystem.ignitionTrigger;
			
			state machine PumpCycleStateMachine {
				doc /*
				 * The Humphrey pump operates in a repeating cycle of intake, compression,
				 * combustion, discharge, and exhaust phases.
				 */
				
				entry; then idle;
				
				state idle {
					entry action setIdlePressure {
						combustionChamber.currentPressure := 101325.0;
					}
				}
				
				accept StartPumping;
				transition idle_to_intake
					first idle
					accept StartPumping
					then intake;
				
				state intake {
					doc /*
					 * Fluid enters the combustion chamber through the inlet check valve
					 * as the fluid column momentum creates a partial vacuum.
					 */
					entry action openInlet {
						inletCheckValve.isOpen := true;
						outletCheckValve.isOpen := false;
					}
				}
				
				transition intake_to_fuelAdmission
					first intake
					then fuelAdmission;
				
				state fuelAdmission {
					doc /*
					 * Fuel-air mixture is admitted into the combustion chamber
					 * above the fluid column.
					 */
					entry action admitFuel {
						inletCheckValve.isOpen := false;
					}
				}
				
				transition fuelAdmission_to_ignition
					first fuelAdmission
					then ignition;
				
				state ignition {
					doc /*
					 * The fuel-air mixture is ignited, creating a rapid pressure rise.
					 */
					entry action fireIgnition {
						ignitionSystem.ignitionTrigger.sparkCommand := true;
					}
				}
				
				transition ignition_to_combustion
					first ignition
					then combustion;
				
				state combustion {
					doc /*
					 * Combustion creates high pressure that accelerates the fluid column
					 * downward and opens the outlet check valve.
					 */
					entry action generatePressure {
						combustionChamber.currentPressure := combustionChamber.maxPressure;
						outletCheckValve.isOpen := true;
					}
				}
				
				transition combustion_to_discharge
					first combustion
					then discharge;
				
				state discharge {
					doc /*
					 * High-pressure fluid is discharged through the outlet check valve
					 * to the discharge tank.
					 */
					entry action dischargeFluid {
						inletCheckValve.isOpen := false;
						outletCheckValve.isOpen := true;
					}
				}
				
				transition discharge_to_exhaust
					first discharge
					then exhaust;
				
				state exhaust {
					doc /*
					 * Combustion gases are exhausted as the fluid column reverses
					 * direction due to inertia and gravity.
					 */
					entry action exhaustGases {
						combustionChamber.currentPressure := 101325.0;
					}
				}
				
				transition exhaust_to_intake
					first exhaust
					then intake;
				
				accept StopPumping;
				transition exhaust_to_idle
					first exhaust
					accept StopPumping
					then idle;
			}
		}
		
		part def PumpingSubsystem {
			port systemInletPort : ~FluidPort;
			port systemOutletPort : FluidPort;
			port fuelSupplyPort : ~FuelPort;
			
			part sourceReservoir : FluidReservoir;
			part humphreyPump : HumphreyPump;
			part dischargeTank : DischargeTank;
			part fuelSupply : FuelSupplySystem;
			
			attribute operatingPressure : PressureValue;
			attribute targetFlowRate : FlowRateValue;
			attribute systemEfficiency : Real;
		}
		
		action def PumpFluid {
			in fluidInput : Fluid;
			in sourcePressure : PressureValue;
			in targetPressure : PressureValue;
			out fluidOutput : Fluid;
			out actualFlowRate : FlowRateValue;
		}
		
		action def ControlPumpOperation {
			in currentPressure : PressureValue;
			in targetPressure : PressureValue;
			in currentFlowRate : FlowRateValue;
			in targetFlowRate : FlowRateValue;
			out ignitionTiming : Real;
			out fuelFlowRate : FlowRateValue;
		}
		
		requirement def FlowRateRequirement {
			doc /*
			 * The pumping subsystem shall deliver fluid at the specified flow rate.
			 */
			subject pump : HumphreyPump;
			attribute requiredFlowRate : FlowRateValue;
			
			assert constraint {
				pump.maxFlowRate >= requiredFlowRate
			}
		}
		
		requirement def PressureRequirement {
			doc /*
			 * The pumping subsystem shall achieve the specified discharge pressure.
			 */
			subject pump : HumphreyPump;
			attribute requiredPressure : PressureValue;
			
			assert constraint {
				pump.maxDischargePressure >= requiredPressure
			}
		}
		
		requirement def EfficiencyRequirement {
			doc /*
			 * The pumping subsystem shall operate at or above the minimum efficiency.
			 */
			subject pump : HumphreyPump;
			attribute minimumEfficiency : Real;
			
			assert constraint {
				pump.efficiency >= minimumEfficiency
			}
		}
		
		requirement def SafetyRequirement {
			doc /*
			 * The combustion chamber pressure shall not exceed the maximum design pressure.
			 */
			subject chamber : CombustionChamber;
			
			assert constraint {
				chamber.currentPressure <= chamber.maxPressure
			}
		}
		
		requirement def ValveIntegrityRequirement {
			doc /*
			 * Inlet and outlet check valves shall not be open simultaneously.
			 */
			subject pump : HumphreyPump;
			
			assert constraint {
				not (pump.inletCheckValve.isOpen and pump.outletCheckValve.isOpen)
			}
		}
	}
	
	package Usages {
		part pumpingSystem : Definitions::PumpingSubsystem {
			part :>> sourceReservoir {
				attribute :>> capacity = 5000.0;
				attribute :>> currentLevel = 4200.0;
			}
			
			part :>> humphreyPump {
				attribute :>> pumpingFrequency = 3.0;
				attribute :>> maxFlowRate = 75.0;
				attribute :>> maxDischargePressure = 600000.0;
				attribute :>> efficiency = 0.68;
				
				part :>> combustionChamber {
					attribute :>> volume = 0.08;
					attribute :>> currentPressure = 101325.0;
					attribute :>> maxPressure = 900000.0;
					attribute :>> temperature = 298.15;
					attribute :>> fluidColumnHeight = 0.0;
				}
				
				part :>> inletCheckValve {
					attribute :>> crackingPressure = 3000.0;
					attribute :>> isOpen = false;
				}
				
				part :>> outletCheckValve {
					attribute :>> crackingPressure = 8000.0;
					attribute :>> isOpen = false;
				}
				
				part :>> ignitionSystem {
					attribute :>> sparkEnergy = 0.15;
					attribute :>> firingFrequency = 3.0;
				}
				
				perform action pumpingAction : Definitions::PumpFluid {
					in fluidInput = fluidInletPort.fluid;
					in sourcePressure = fluidInletPort.pressure;
					in targetPressure = fluidOutletPort.pressure;
					out fluidOutput = fluidOutletPort.fluid;
				}
				
				exhibit state pumpOperation : PumpCycleStateMachine;
			}
			
			part :>> dischargeTank {
				attribute :>> capacity = 3000.0;
				attribute :>> currentLevel = 1500.0;
				attribute :>> elevation = 25.0;
			}
			
			part :>> fuelSupply {
				attribute :>> fuelPressure = 250000.0;
				attribute :>> airFuelRatio = 14.7;
			}
			
			attribute :>> operatingPressure = 550000.0;
			attribute :>> targetFlowRate = 70.0;
			attribute :>> systemEfficiency = 0.65;
			
			flow fluidFromReservoir : Definitions::Fluid
				from sourceReservoir.outletPort.fluid
				to humphreyPump.fluidInletPort.fluid;
			
			flow fluidToTank : Definitions::Fluid
				from humphreyPump.fluidOutletPort.fluid
				to dischargeTank.inletPort.fluid;
			
			flow fuelMixtureFlow : Definitions::FuelAirMixture
				from fuelSupply.fuelOutletPort.fuelMixture
				to humphreyPump.fuelSupplyPort.fuelMixture;
			
			binding humphreyPump.fluidInletPort = systemInletPort;
			binding humphreyPump.fluidOutletPort = systemOutletPort;
			binding fuelSupply.fuelOutletPort = fuelSupplyPort;
			
			perform action controlAction : Definitions::ControlPumpOperation {
				in currentPressure = dischargeTank.inletPort.pressure;
				in targetPressure = operatingPressure;
				in currentFlowRate = humphreyPump.fluidOutletPort.flowRate;
				in targetFlowRate = pumpingSystem.targetFlowRate;
			}
		}
		
		item water : Definitions::Fluid {
			attribute :>> density = 1000.0;
			attribute :>> viscosity = 0.001;
			attribute :>> temperature = 293.15;
		}
		
		satisfy flowReq : Definitions::FlowRateRequirement {
			subject pump = pumpingSystem.humphreyPump;
			attribute :>> requiredFlowRate = 65.0;
		}
		
		satisfy pressureReq : Definitions::PressureRequirement {
			subject pump = pumpingSystem.humphreyPump;
			attribute :>> requiredPressure = 500000.0;
		}
		
		satisfy efficiencyReq : Definitions::EfficiencyRequirement {
			subject pump = pumpingSystem.humphreyPump;
			attribute :>> minimumEfficiency = 0.60;
		}
		
		satisfy safetyReq : Definitions::SafetyRequirement {
			subject chamber = pumpingSystem.humphreyPump.combustionChamber;
		}
		
		satisfy valveReq : Definitions::ValveIntegrityRequirement {
			subject pump = pumpingSystem.humphreyPump;
		}
	}
}
