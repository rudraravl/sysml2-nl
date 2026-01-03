package 'DegreeOfReactionTurbineSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DegreeOfReaction :> Real {
		doc /* 
		 * Degree of reaction (R) is the ratio of static enthalpy drop in the rotor 
		 * to the total static enthalpy drop across the stage.
		 * R = ΔH_rotor / (ΔH_rotor + ΔH_stator)
		 * Valid range: 0.0 to 1.0
		 */
	}
	
	attribute def EnthalpyDropValue :> Real;
	
	attribute def RotationalSpeedValue :> Real;
	
	item def WorkingFluid {
		doc /* Steam or gas flowing through the turbine stage */
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute enthalpy : Real;
		attribute velocity : SpeedValue;
		attribute massFlowRate : Real;
	}
	
	port def FluidPort {
		in item fluidIn : WorkingFluid;
		out item fluidOut : WorkingFluid;
	}
	
	port def MechanicalPort {
		attribute torque : Real;
		attribute speed : RotationalSpeedValue;
		attribute power : PowerValue;
	}
	
	part def Stator {
		doc /* 
		 * Stationary nozzle that converts pressure energy to kinetic energy.
		 * Directs flow onto rotor blades at optimal angle.
		 */
		port inlet : FluidPort;
		port outlet : FluidPort;
		
		attribute enthalpyDrop : EnthalpyDropValue;
		attribute exitAngle : Real;
		
		perform action accelerateFluid {
			in attribute inletFluid : WorkingFluid;
			out attribute outletFluid : WorkingFluid;
			
			action expandThroughNozzle {
				doc /* Isentropic expansion converts pressure to velocity */
			}
		}
	}
	
	part def Rotor {
		doc /* 
		 * Rotating blade row that extracts energy from fluid.
		 * Converts fluid kinetic and pressure energy to shaft work.
		 */
		port inlet : FluidPort;
		port outlet : FluidPort;
		port shaft : MechanicalPort;
		
		attribute enthalpyDrop : EnthalpyDropValue;
		attribute bladeSpeed : RotationalSpeedValue;
		attribute bladeAngle : Real;
		
		perform action extractWork {
			in attribute inletFluid : WorkingFluid;
			out attribute outletFluid : WorkingFluid;
			out attribute shaftPower : PowerValue;
			
			action convertFluidEnergy {
				doc /* Extract energy through momentum change across blades */
			}
		}
	}
	
	part def TurbineStage {
		doc /* 
		 * Single stage consisting of stator-rotor pair.
		 * Degree of reaction determines energy distribution between components.
		 */
		attribute degreeOfReaction : DegreeOfReaction;
		attribute totalEnthalpyDrop : EnthalpyDropValue;
		attribute operatingSpeed : RotationalSpeedValue;
		
		port stageInlet : FluidPort;
		port stageOutlet : FluidPort;
		port powerOutput : MechanicalPort;
		
		part stator : Stator {
			port :>> inlet = stageInlet;
		}
		
		part rotor : Rotor {
			port :>> outlet = stageOutlet;
			port :>> shaft = powerOutput;
		}
		
		connection statorToRotor connect stator.outlet to rotor.inlet;
		
		action computeEnergyDistribution {
			in reactionDegree : Real;
			in totalDrop : Real;
			out rotorDrop : Real;
			out statorDrop : Real;
		}
	}
	
	part def TurbineController {
		doc /* 
		 * Monitors stage performance and adjusts operating parameters
		 * to maintain optimal degree of reaction for efficiency.
		 */
		port sensorInput;
		port actuatorOutput;
		
		attribute targetReaction : DegreeOfReaction;
		attribute measuredEfficiency : Real;
		attribute measuredReaction : DegreeOfReaction;
		
		perform action controlOperation {
			first start;
			then merge controlLoop;
			
			then action monitorPerformance {
				out efficiency : Real;
				out currentReaction : Real;
			}
			
			then decide;
				if monitorPerformance.efficiency < 0.82 then optimizeReaction;
				if monitorPerformance.efficiency >= 0.82 then maintainOperation;
			
			action optimizeReaction {
				doc /* Adjust blade angles or flow conditions to improve efficiency */
				then action calculateOptimalReaction {
					in currentEff : Real;
					out newReaction : Real;
				}
			}
			then controlLoop;
			
			action maintainOperation {
				doc /* Continue steady-state operation */
			}
			then controlLoop;
		}
	}
	
	part def Generator {
		doc /* Converts mechanical shaft power to electrical power */
		port mechanicalInput : MechanicalPort;
		port electricalOutput;
		
		attribute efficiency : Real = 0.98;
		attribute outputPower : PowerValue;
		
		perform action convertPower {
			in mechanicalPower : PowerValue;
			out electricalPower : PowerValue;
		}
	}
	
	part reactionTurbineSystem : TurbineStage {
		doc /* 
		 * Primary Function: Convert thermal and pressure energy of working fluid 
		 * into mechanical shaft power through controlled expansion across stator 
		 * and rotor blade rows.
		 * 
		 * The system operates by distributing the total enthalpy drop between 
		 * the stationary stator (which accelerates the flow) and the rotating 
		 * rotor (which extracts work). The degree of reaction determines this 
		 * distribution:
		 * - R = 0.5 (50% reaction): Equal enthalpy drop in stator and rotor
		 * - R < 0.5 (impulse): More drop in stator, higher fluid velocities
		 * - R > 0.5 (reaction): More drop in rotor, lower fluid velocities
		 * 
		 * The controller continuously monitors efficiency and adjusts the degree 
		 * of reaction to maintain optimal performance across varying operating 
		 * conditions.
		 */
		
		attribute :>> degreeOfReaction = 0.50;
		attribute :>> totalEnthalpyDrop = 280.0;
		attribute :>> operatingSpeed = 3600.0;
		
		attribute inletTemperature : TemperatureValue = 823.15;
		attribute inletPressure : PressureValue = 4.0e6;
		attribute massFlow : Real = 45.0;
		
		part controller : TurbineController {
			attribute :>> targetReaction = degreeOfReaction;
		}
		
		part generator : Generator;
		
		connection shaftToGenerator connect powerOutput to generator.mechanicalInput;
		
		perform action operateTurbine {
			first start;
			
			then action initializeFlowConditions {
				doc /* Set inlet fluid properties */
			}
			
			then merge steadyOperation;
			
			then action distributeEnergy {
				in reactionDegree : Real;
				in totalDrop : Real;
			}
			
			then action processFluidThroughStator;
			then action extractWorkInRotor;
			then action generateElectricity;
			
			then action monitorAndControl;
			
			then decide;
				if controller.measuredEfficiency >= 0.80 then steadyOperation;
				if controller.measuredEfficiency < 0.80 then shutdown;
			
			action shutdown {
				doc /* Controlled shutdown sequence */
			}
			then done;
		}
	}
	
	requirement def PerformanceRequirement {
		doc /* Base requirement for turbine stage performance */
		subject stage : TurbineStage;
		require constraint { 
			stage.degreeOfReaction >= 0.0 and 
			stage.degreeOfReaction <= 1.0 
		}
	}
	
	requirement def OptimalReactionRequirement :> PerformanceRequirement {
		doc /* 
		 * Degree of reaction shall be maintained between 0.40 and 0.60 
		 * for balanced blade loading and optimal efficiency.
		 */
		subject stage = reactionTurbineSystem;
		require constraint {
			stage.degreeOfReaction >= 0.40 and 
			stage.degreeOfReaction <= 0.60
		}
	}
	
	requirement def EnergyConservationRequirement {
		doc /* 
		 * Total enthalpy drop must equal sum of stator and rotor drops
		 * to satisfy first law of thermodynamics.
		 */
		subject stage = reactionTurbineSystem;
		require constraint {
			stage.totalEnthalpyDrop == 
			(stage.stator.enthalpyDrop + stage.rotor.enthalpyDrop)
		}
	}
	
	requirement def MinimumPowerRequirement {
		doc /* Turbine must deliver minimum shaft power output */
		subject stage = reactionTurbineSystem;
		attribute minimumPower : PowerValue = 10.0e6;
		require constraint {
			stage.powerOutput.power >= minimumPower
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /* Controller must maintain stage efficiency above threshold */
		subject ctrl = reactionTurbineSystem.controller;
		attribute minimumEfficiency : Real = 0.82;
		require constraint {
			ctrl.measuredEfficiency >= minimumEfficiency
		}
	}
}
