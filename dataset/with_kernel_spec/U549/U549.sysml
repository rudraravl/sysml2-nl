package 'Pumpjack System Model' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def ElectricalEnergy;
		item def RotationalPower {
			attribute torque : TorqueValue;
			attribute angularSpeed : RotationalSpeedValue;
		}
		item def ReciprocatingMotion {
			attribute strokePosition : LengthValue;
			attribute strokeRate : FrequencyValue;
		}
		item def WellFluid;
		item def ControlSignal {
			attribute strokeRateSetpoint : FrequencyValue;
		}

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def EmergencySignal;
		attribute def ResetCommand;

		port def ElectricalPort { out item energy : ElectricalEnergy; }
		port def RotationalPort { out item power : RotationalPower; }
		port def ReciprocatingPort { out item motion : ReciprocatingMotion; }
		port def FluidPort { out item fluid : WellFluid; }
		port def ControlPort { out item signal : ControlSignal; }

		part def PumpjackSystem {
			attribute maxStrokeRate : FrequencyValue;
		}

		part def ElectricMotor {
			port electricalInPort : ~ElectricalPort;
			port controlInPort : ~ControlPort;
			port rotationalOutPort : RotationalPort;
			attribute ratedPower : PowerValue;
		}
		part def SpeedReducer {
			port rotationalInPort : ~RotationalPort;
			port rotationalOutPort : RotationalPort;
			attribute gearRatio : Real;
		}
		part def CrankAssembly {
			port rotationalInPort : ~RotationalPort;
			port reciprocatingOutPort : ReciprocatingPort;
			attribute counterweightMass : MassValue;
		}
		part def WalkingBeam {
			port reciprocatingInPort : ~ReciprocatingPort;
			port reciprocatingOutPort : ReciprocatingPort;
			attribute beamLength : LengthValue;
		}
		part def PolishedRodString {
			port reciprocatingInPort : ~ReciprocatingPort;
			port reciprocatingOutPort : ReciprocatingPort;
			attribute rodLength : LengthValue;
		}
		part def SubsurfacePump {
			port reciprocatingInPort : ~ReciprocatingPort;
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute pumpEfficiency : Real;
		}
		part def ProductionTubing {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute innerDiameter : LengthValue;
		}
		part def WellheadAssembly {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute maxPressure : PressureValue;
		}
		part def FlowlinePipeline {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute flowCapacity : VolumeFlowRateValue;
		}
		part def StorageFacility {
			port fluidInPort : ~FluidPort;
			attribute capacity : VolumeValue;
		}
		part def ControlSystem {
			port reciprocatingInPort : ~ReciprocatingPort;
			port controlOutPort : ControlPort;
			attribute targetStrokeRate : FrequencyValue;
		}

		action def GenerateRotationalPower {
			in energy : ElectricalEnergy;
			in controlSignal : ControlSignal;
			out power : RotationalPower;
		}
		action def ReduceSpeedIncreaseTorque {
			in powerIn : RotationalPower;
			out powerOut : RotationalPower;
		}
		action def ConvertRotaryToReciprocating {
			in power : RotationalPower;
			out motion : ReciprocatingMotion;
		}
		action def TransmitReciprocatingMotion {
			in motionIn : ReciprocatingMotion;
			out motionOut : ReciprocatingMotion;
		}
		action def LiftWellFluid {
			in motion : ReciprocatingMotion;
			in fluidIn : WellFluid;
			out fluidOut : WellFluid;
		}
		action def TransportWellFluid {
			in fluidIn : WellFluid;
			out fluidOut : WellFluid;
		}
		action def ManageStrokeRate {
			in motion : ReciprocatingMotion;
			out controlSignal : ControlSignal;
		}

		state def PumpjackOperation {
			state idle;
			state pumping {
				state upstroke;
				state downstroke;
				transition from upstroke to downstroke;
				transition from downstroke to upstroke;
			}
			state emergencyShutdown;
			transition from idle to pumping accept start : StartCommand;
			transition from pumping to idle accept stop : StopCommand;
			transition from pumping to emergencyShutdown accept emergency : EmergencySignal;
			transition from emergencyShutdown to idle accept reset : ResetCommand;
		}

		requirement def PumpjackSystemRequirement {
			subject pumpjack : PumpjackSystem;
			text "This model represents a complete pumpjack system, a type of artificial lift system commonly used in onshore oil fields to extract crude oil from underground reservoirs. Its primary function is to convert electrical energy into a powerful, reciprocating motion that drives a pump located deep within an oil well, lifting fluids to the surface. The system's operation begins with a large electric motor that provides the initial rotational power. This high-speed, low-torque output is fed into a speed reducer, essentially a gearbox, which converts it into low-speed, high-torque rotation. This powerful rotation drives a crank assembly equipped with large counterweights to balance the load. The crank's motion is transferred to a large, pivoting walking beam, the iconic 'nodding' component of the pumpjack. The walking beam converts the rotary motion into a steady, vertical up-and-down stroke at the surface. This surface motion is transmitted deep into the well via a long, connected series of steel rods known as a polished rod string. At the bottom of the well, this rod string is connected to a subsurface pump. As the rod string moves up, it lifts a column of fluid (a mixture of crude oil, water, and gas) from the reservoir. This fluid travels up through production tubing to the wellhead assembly at the surface, which manages the pressure and directs the output. From the wellhead, the extracted fluid is then transported through a flowline pipeline to a storage or processing facility. A dedicated control system manages the pumpjack's operational speed, or stroke rate, to optimize production. The entire system operates through distinct states, including an idle standby mode, an active pumping state which cycles continuously between upstroke and downstroke, and an emergency shutdown state for safety.";
		}
	}

	package Usages {
		private import Definitions::*;

		part pumpjackContext : PumpjackSystem {
			part gridSource {
				port electricalOutPort : ElectricalPort;
			}
			part reservoir {
				port fluidOutPort : FluidPort;
			}
			part storageFacility {
				port fluidInPort : ~FluidPort;
			}

			part electricMotor : ElectricMotor {
				perform action generatePower : GenerateRotationalPower {
					in energy = electricalInPort.energy;
					in controlSignal = controlInPort.signal;
					out power = rotationalOutPort.power;
				}
			}
			part speedReducer : SpeedReducer {
				perform action reduceSpeed : ReduceSpeedIncreaseTorque {
					in powerIn = rotationalInPort.power;
					out powerOut = rotationalOutPort.power;
				}
			}
			part crankAssembly : CrankAssembly {
				perform action convertMotion : ConvertRotaryToReciprocating {
					in power = rotationalInPort.power;
					out motion = reciprocatingOutPort.motion;
				}
			}
			part walkingBeam : WalkingBeam {
				perform action transmitMotion1 : TransmitReciprocatingMotion {
					in motionIn = reciprocatingInPort.motion;
					out motionOut = reciprocatingOutPort.motion;
				}
			}
			part polishedRodString : PolishedRodString {
				perform action transmitMotion2 : TransmitReciprocatingMotion {
					in motionIn = reciprocatingInPort.motion;
					out motionOut = reciprocatingOutPort.motion;
				}
			}
			part subsurfacePump : SubsurfacePump {
				perform action liftFluid : LiftWellFluid {
					in motion = reciprocatingInPort.motion;
					in fluidIn = fluidInPort.fluid;
					out fluidOut = fluidOutPort.fluid;
				}
			}
			part productionTubing : ProductionTubing {
				perform action transportFluid1 : TransportWellFluid {
					in fluidIn = fluidInPort.fluid;
					out fluidOut = fluidOutPort.fluid;
				}
			}
			part wellheadAssembly : WellheadAssembly {
				perform action transportFluid2 : TransportWellFluid {
					in fluidIn = fluidInPort.fluid;
					out fluidOut = fluidOutPort.fluid;
				}
			}
			part flowlinePipeline : FlowlinePipeline {
				perform action transportFluid3 : TransportWellFluid {
					in fluidIn = fluidInPort.fluid;
					out fluidOut = fluidOutPort.fluid;
				}
			}
			part controlSystem : ControlSystem {
				perform action manageRate : ManageStrokeRate {
					in motion = reciprocatingInPort.motion;
					out controlSignal = controlOutPort.signal;
				}
			}

			flow of energy : ElectricalEnergy
				from gridSource.electricalOutPort.energy to electricMotor.electricalInPort.energy;
			flow of signal : ControlSignal
				from controlSystem.controlOutPort.signal to electricMotor.controlInPort.signal;
			flow of power : RotationalPower
				from electricMotor.rotationalOutPort.power to speedReducer.rotationalInPort.power;
			flow of power : RotationalPower
				from speedReducer.rotationalOutPort.power to crankAssembly.rotationalInPort.power;
			flow of motion : ReciprocatingMotion
				from crankAssembly.reciprocatingOutPort.motion to walkingBeam.reciprocatingInPort.motion;
			flow of motion : ReciprocatingMotion
				from walkingBeam.reciprocatingOutPort.motion to polishedRodString.reciprocatingInPort.motion;
			flow of motion : ReciprocatingMotion
				from polishedRodString.reciprocatingOutPort.motion to subsurfacePump.reciprocatingInPort.motion;
			flow of motion : ReciprocatingMotion
				from polishedRodString.reciprocatingOutPort.motion to controlSystem.reciprocatingInPort.motion;
			flow of fluid : WellFluid
				from reservoir.fluidOutPort.fluid to subsurfacePump.fluidInPort.fluid;
			flow of fluid : WellFluid
				from subsurfacePump.fluidOutPort.fluid to productionTubing.fluidInPort.fluid;
			flow of fluid : WellFluid
				from productionTubing.fluidOutPort.fluid to wellheadAssembly.fluidInPort.fluid;
			flow of fluid : WellFluid
				from wellheadAssembly.fluidOutPort.fluid to flowlinePipeline.fluidInPort.fluid;
			flow of fluid : WellFluid
				from flowlinePipeline.fluidOutPort.fluid to storageFacility.fluidInPort.fluid;

			state operation : PumpjackOperation;
		}

		requirement pumpjackReq : PumpjackSystemRequirement;
		satisfy pumpjackReq by pumpjackContext;
	}
}
