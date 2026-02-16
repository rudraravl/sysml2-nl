package 'Hydraulic Accumulator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SystemStart;
	attribute def SystemStop;
	attribute def ChargeCommand;
	attribute def DischargeCommand;
	attribute def EmergencyShutdown;
	
	item def HydraulicFluid {
		attribute density : DensityValue;
		attribute viscosity : Real;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute contamination : Real;
	}
	
	item def CompressedGas {
		attribute gasType : String;
		attribute prechargePress : PressureValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	port def HydraulicPort {
		attribute pressure : PressureValue;
		attribute flowRate : VolumeFlowRateValue;
		inout item fluid : HydraulicFluid;
	}
	
	port def SensorPort {
		out attribute pressureReading : PressureValue;
		out attribute volumeReading : VolumeValue;
	}
	
	part def PressureSensor {
		port sense : HydraulicPort;
		port output : SensorPort;
		attribute accuracy : PressureValue;
		attribute range : PressureValue;
	}
	
	part def GasBladder {
		attribute prechargePress : PressureValue;
		attribute maxVolume : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute gasConstant : Real;
		part gas : CompressedGas;
	}
	
	part def FluidChamber {
		attribute maxVolume : VolumeValue;
		attribute currentVolume : VolumeValue;
		part fluid : HydraulicFluid;
	}
	
	part def AccumulatorShell {
		attribute maxPressure : PressureValue;
		attribute nominalVolume : VolumeValue;
		attribute wallThickness : LengthValue;
		attribute material : String;
	}
	
	part def ControlValve {
		port inlet : HydraulicPort;
		port outlet : HydraulicPort;
		attribute position : Real;
		attribute maxFlowRate : VolumeFlowRateValue;
		attribute crackingPressure : PressureValue;
	}
	
	part def HydraulicPump {
		port suction : HydraulicPort;
		port discharge : HydraulicPort;
		attribute maxFlowRate : VolumeFlowRateValue;
		attribute maxPressure : PressureValue;
		attribute efficiency : Real;
	}
	
	part def HydraulicActuator {
		port inlet : HydraulicPort;
		attribute requiredPressure : PressureValue;
		attribute requiredFlowRate : VolumeFlowRateValue;
		attribute strokeLength : LengthValue;
	}
	
	part def Reservoir {
		port outlet : HydraulicPort;
		attribute capacity : VolumeValue;
		attribute currentLevel : VolumeValue;
		part fluid : HydraulicFluid;
	}
	
	action def MonitorPressure {
		in targetPressure : PressureValue;
		in tolerance : PressureValue;
		out currentPressure : PressureValue;
		out pressureDeviation : PressureValue;
	}
	
	action def ChargeAccumulator {
		in inletFlowRate : VolumeFlowRateValue;
		in currentFluidVolume : VolumeValue;
		in maxFluidVolume : VolumeValue;
		out newFluidVolume : VolumeValue;
		out newPressure : PressureValue;
	}
	
	action def DischargeAccumulator {
		in demandFlowRate : VolumeFlowRateValue;
		in currentFluidVolume : VolumeValue;
		in minFluidVolume : VolumeValue;
		out newFluidVolume : VolumeValue;
		out newPressure : PressureValue;
	}
	
	action def CompressGasCharge {
		in fluidVolume : VolumeValue;
		in prechargePress : PressureValue;
		in totalVolume : VolumeValue;
		out gasPressure : PressureValue;
		out gasVolume : VolumeValue;
	}
	
	action def SupplyPeakDemand {
		in systemDemand : VolumeFlowRateValue;
		in pumpCapacity : VolumeFlowRateValue;
		in storedPressure : PressureValue;
		out supplementalFlow : VolumeFlowRateValue;
		out deliveredPressure : PressureValue;
	}
	
	part def HydraulicAccumulator {
		doc /* A pressure vessel that stores hydraulic energy by compressing gas 
		       with hydraulic fluid, enabling energy storage and release on demand. */
		
		attribute maxOperatingPressure : PressureValue;
		attribute minOperatingPressure : PressureValue;
		attribute nominalVolume : VolumeValue;
		attribute currentFluidVolume : VolumeValue;
		attribute currentSystemPressure : PressureValue;
		
		part shell : AccumulatorShell {
			attribute maxPressure = HydraulicAccumulator::maxOperatingPressure;
			attribute nominalVolume = HydraulicAccumulator::nominalVolume;
			attribute wallThickness = 12.0[SI::mm];
			attribute material = "High-strength steel";
		}
		
		part gasBladder : GasBladder {
			attribute prechargePress = 0.6 * HydraulicAccumulator::maxOperatingPressure;
			attribute maxVolume = shell.nominalVolume * 0.85;
			attribute currentVolume : VolumeValue;
			attribute gasConstant = 1.4;
			part gas {
				attribute gasType = "Nitrogen";
				attribute prechargePress = gasBladder.prechargePress;
				attribute temperature = 293.15[SI::K];
			}
		}
		
		part fluidChamber : FluidChamber {
			attribute maxVolume = shell.nominalVolume * 0.85;
			attribute currentVolume = HydraulicAccumulator::currentFluidVolume;
			part fluid {
				attribute density = 870.0[SI::kg/SI::m^3];
				attribute viscosity = 46.0;
				attribute temperature = 313.15[SI::K];
				attribute contamination = 0.02;
			}
		}
		
		part pressureSensor : PressureSensor {
			attribute accuracy = 0.5[SI::bar];
			attribute range = 350.0[SI::bar];
		}
		
		part inletValve : ControlValve {
			attribute maxFlowRate = 80.0[SI::L/SI::min];
			attribute crackingPressure = 5.0[SI::bar];
		}
		
		part outletValve : ControlValve {
			attribute maxFlowRate = 100.0[SI::L/SI::min];
			attribute crackingPressure = 10.0[SI::bar];
		}
		
		port inletPort : HydraulicPort;
		port outletPort : HydraulicPort;
		port sensorPort : SensorPort;
		
		connection inletConnection connect inletPort to inletValve.inlet;
		connection outletConnection connect outletPort to outletValve.outlet;
		connection sensorConnection connect pressureSensor.sense to fluidChamber;
	}
	
	part def AccumulatorSystem {
		doc /* A hydraulic system that stores pressurized fluid energy in an accumulator
		       to supplement pump flow during peak demands, absorb pressure shocks, 
		       maintain system pressure during pump failure, and compensate for leakage. */
		
		attribute systemPressureSetpoint : PressureValue;
		attribute systemPressureTolerance : PressureValue;
		attribute pumpFlowCapacity : VolumeFlowRateValue;
		attribute peakDemandFlow : VolumeFlowRateValue;
		
		part reservoir : Reservoir {
			attribute capacity = 150.0[SI::L];
			attribute currentLevel = 120.0[SI::L];
			part fluid {
				attribute density = 870.0[SI::kg/SI::m^3];
				attribute viscosity = 46.0;
				attribute temperature = 313.15[SI::K];
				attribute contamination = 0.01;
			}
		}
		
		part pump : HydraulicPump {
			attribute maxFlowRate = 60.0[SI::L/SI::min];
			attribute maxPressure = 280.0[SI::bar];
			attribute efficiency = 0.88;
		}
		
		part accumulator : HydraulicAccumulator {
			attribute maxOperatingPressure = 300.0[SI::bar];
			attribute minOperatingPressure = 120.0[SI::bar];
			attribute nominalVolume = 20.0[SI::L];
			attribute currentFluidVolume = 10.0[SI::L];
			attribute currentSystemPressure = 200.0[SI::bar];
			
			perform action energyManagement[*] ordered references manageEnergy;
		}
		
		part actuator : HydraulicActuator {
			attribute requiredPressure = 180.0[SI::bar];
			attribute requiredFlowRate = 45.0[SI::L/SI::min];
			attribute strokeLength = 500.0[SI::mm];
		}
		
		part reliefValve : ControlValve {
			attribute maxFlowRate = 100.0[SI::L/SI::min];
			attribute crackingPressure = 310.0[SI::bar];
		}
		
		connection pumpToAccumulator connect pump.discharge to accumulator.inletPort;
		connection accumulatorToActuator connect accumulator.outletPort to actuator.inlet;
		connection reservoirToPump connect reservoir.outlet to pump.suction;
		connection reliefToReservoir connect reliefValve.outlet to reservoir.outlet;
		connection systemRelief connect accumulator.outletPort to reliefValve.inlet;
	}
	
	action def ManageHydraulicEnergy {
		doc /* Manages the charging and discharging cycles of the hydraulic accumulator
		       to maintain system pressure and provide supplemental flow during peak demands. */
		
		in systemPressureSetpoint : PressureValue;
		in pressureTolerance : PressureValue;
		in pumpFlow : VolumeFlowRateValue;
		in systemDemand : VolumeFlowRateValue;
		out accumulatorPressure : PressureValue;
		out accumulatorFluidVolume : VolumeValue;
		
		private attribute currentPressure : PressureValue;
		private attribute currentVolume : VolumeValue;
		private attribute pressureDelta : PressureValue;
		
		loop {
			accept start : SystemStart;
			then action operationalCycle {
				first start;
				then merge continueOperation;
				
				then action monitor : MonitorPressure {
					in targetPressure = systemPressureSetpoint;
					in tolerance = pressureTolerance;
					out currentPressure : PressureValue;
					out pressureDeviation : PressureValue;
				}
				
				then assign currentPressure := monitor.currentPressure;
				then assign pressureDelta := monitor.pressureDeviation;
				
				then decide;
					if pressureDelta < -10.0[SI::bar] and pumpFlow > systemDemand then chargeMode;
					if pressureDelta > 10.0[SI::bar] and systemDemand > pumpFlow then dischargeMode;
					if pressureDelta >= -10.0[SI::bar] and pressureDelta <= 10.0[SI::bar] then maintainMode;
				
				action chargeMode {
					doc /* Accumulator is charged when pump capacity exceeds demand
					       and pressure is below setpoint. */
					
					action charge : ChargeAccumulator {
						in inletFlowRate = pumpFlow - systemDemand;
						in currentFluidVolume = currentVolume;
						in maxFluidVolume = 17.0[SI::L];
						out newFluidVolume : VolumeValue;
						out newPressure : PressureValue;
					}
					
					then action compress : CompressGasCharge {
						in fluidVolume = charge.newFluidVolume;
						in prechargePress = 180.0[SI::bar];
						in totalVolume = 20.0[SI::L];
						out gasPressure : PressureValue;
						out gasVolume : VolumeValue;
					}
					
					then assign currentVolume := charge.newFluidVolume;
					then assign currentPressure := compress.gasPressure;
					then assign accumulatorFluidVolume := currentVolume;
					then assign accumulatorPressure := currentPressure;
				}
				then continueOperation;
				
				action dischargeMode {
					doc /* Accumulator discharges to supplement pump flow when 
					       demand exceeds pump capacity. */
					
					action discharge : DischargeAccumulator {
						in demandFlowRate = systemDemand - pumpFlow;
						in currentFluidVolume = currentVolume;
						in minFluidVolume = 3.0[SI::L];
						out newFluidVolume : VolumeValue;
						out newPressure : PressureValue;
					}
					
					then action supply : SupplyPeakDemand {
						in systemDemand = systemDemand;
						in pumpCapacity = pumpFlow;
						in storedPressure = discharge.newPressure;
						out supplementalFlow : VolumeFlowRateValue;
						out deliveredPressure : PressureValue;
					}
					
					then assign currentVolume := discharge.newFluidVolume;
					then assign currentPressure := supply.deliveredPressure;
					then assign accumulatorFluidVolume := currentVolume;
					then assign accumulatorPressure := currentPressure;
				}
				then continueOperation;
				
				action maintainMode {
					doc /* Accumulator maintains pressure when system is in equilibrium. */
					
					assign accumulatorPressure := currentPressure;
					assign accumulatorFluidVolume := currentVolume;
				}
				then continueOperation;
			}
			then accept stop : SystemStop;
		}
	}
	
	action manageEnergy : ManageHydraulicEnergy {
		in systemPressureSetpoint : PressureValue;
		in pressureTolerance : PressureValue;
		in pumpFlow : VolumeFlowRateValue;
		in systemDemand : VolumeFlowRateValue;
		out accumulatorPressure : PressureValue;
		out accumulatorFluidVolume : VolumeValue;
	}
	
	requirement def EnergyStorageRequirement {
		doc /* The hydraulic accumulator shall store sufficient pressurized fluid 
		       to supplement pump flow during transient peak demands. */
		
		subject acc : HydraulicAccumulator;
		
		require constraint {
			acc.currentSystemPressure >= acc.minOperatingPressure and
			acc.currentSystemPressure <= acc.maxOperatingPressure
		}
	}
	
	requirement def PressureRegulationRequirement {
		doc /* The system shall maintain hydraulic pressure within specified limits
		       during all operating modes. */
		
		subject acc : HydraulicAccumulator;
		
		require constraint {
			acc.gasBladder.prechargePress >= 0.5 * acc.maxOperatingPressure and
			acc.gasBladder.prechargePress <= 0.9 * acc.maxOperatingPressure
		}
	}
	
	requirement def FlowSupplementRequirement {
		doc /* The accumulator shall provide supplemental flow to meet peak demands
		       exceeding pump capacity. */
		
		attribute minSupplementalFlow : VolumeFlowRateValue = 40.0[SI::L/SI::min];
		attribute responseTime : DurationValue = 0.1[SI::s];
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall include pressure relief protection to prevent
		       overpressure conditions. */
		
		subject acc : HydraulicAccumulator;
		
		require constraint {
			acc.currentSystemPressure <= 1.1 * acc.maxOperatingPressure
		}
	}
	
	requirement <'ACC-SYS-001'> hydraulicAccumulatorSystemRequirement {
		doc /* The hydraulic accumulator system shall store pressurized hydraulic energy
		       and release it on demand to: (1) supplement pump flow during peak demands,
		       (2) maintain system pressure during pump failure or fluctuations,
		       (3) absorb pressure shocks and pulsations, and (4) compensate for
		       minor leakage in the hydraulic circuit. */
		
		subject system : AccumulatorSystem;
		
		assume constraint validOperatingConditions {
			system.pump.maxPressure > 0.0[SI::bar] and
			system.accumulator.gasBladder.prechargePress > 0.0[SI::bar] and
			system.reservoir.currentLevel > 0.0[SI::L]
		}
		
		require energyStorage : EnergyStorageRequirement {
			subject acc = system.accumulator;
		}
		require pressureRegulation : PressureRegulationRequirement {
			subject acc = system.accumulator;
		}
		require flowSupplement : FlowSupplementRequirement;
		require safety : SafetyRequirement {
			subject acc = system.accumulator;
		}
	}
	
	part accumulatorSystem : AccumulatorSystem;
}
