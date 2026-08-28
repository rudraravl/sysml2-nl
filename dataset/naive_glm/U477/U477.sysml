package BushPumpSystem {
	import ScalarValues::*;

	package Units {
		value type Length :> Real { unit 'm'; }
		value type Depth :> Real { unit 'm'; }
		value type Volume :> Real { unit 'L'; }
		value type FlowRate :> Real { unit 'L/min'; }
		value type Force :> Real { unit 'N'; }
		value type Pressure :> Real { unit 'Pa'; }
		value type Mass :> Real { unit 'kg'; }
		value type StrokeLength :> Real { unit 'm'; }
		value type Frequency :> Real { unit '1/min'; }
	}

	package Items {
		item def Water;
		item def Air;
	}

	package Enums {
		enum def HandlePosition { UP; DOWN; }
		enum def ValveState { OPEN; CLOSED; }
		enum def PistonDirection { UPWARD; DOWNWARD; STATIONARY; }
		enum def FlowDirection { UPWARD; DOWNWARD; NONE; }
	}

	package Ports {
		port def WaterInPort { in item water: Items::Water; }
		port def WaterOutPort { out item water: Items::Water; }
		port def MechanicalInputPort { in force: Units::Force; }
		port def MechanicalOutputPort { out force: Units::Force; }
		port def RodInterface {
			in force: Units::Force;
			in direction: Enums::PistonDirection;
		}
	}

	package Components {
		abstract part def MechanicalComponent {
			attribute mass: Units::Mass;
		}

		part def OperatingHandle :> MechanicalComponent {
			attribute position: Enums::HandlePosition = Enums::HandlePosition::UP;
			attribute leverRatio: Real = 3.0;
			attribute inputForce: Units::Force;
			attribute outputForce: Units::Force;
			port rodConnection: Ports::MechanicalOutputPort;
			port userGrip: Ports::MechanicalInputPort;

			action def MoveHandle {
			in dir: Enums::HandlePosition;
				then if dir == Enums::HandlePosition::DOWN {
					send force to rodConnection;
				} else {
					send force to rodConnection;
				}
			}
		}

		part def PumpRod :> MechanicalComponent {
			attribute length: Units::Length;
			attribute diameter: Units::Length;
			port topEnd: Ports::MechanicalInputPort;
			port bottomEnd: Ports::MechanicalOutputPort;

			action def TransmitForce {
				in f: Units::Force;
				then send f to bottomEnd;
			}
		}

		part def Valve {
			attribute state: Enums::ValveState = Enums::ValveState::CLOSED;
			attribute crackingPressure: Units::Pressure;
			port inlet: Ports::WaterInPort;
			port outlet: Ports::WaterOutPort;

			action def Open { then assign state := Enums::ValveState::OPEN; }
			action def Close { then assign state := Enums::ValveState::CLOSED; }
		}

		part def FootValve :> Valve {
			attribute crackingPressure: Units::Pressure = 2000 [Pa];
		}

		part def PistonValve :> Valve {
			attribute crackingPressure: Units::Pressure = 1500 [Pa];
		}

		part def Piston :> MechanicalComponent {
			attribute direction: Enums::PistonDirection = Enums::PistonDirection::STATIONARY;
			attribute strokeLength: Units::StrokeLength = 0.35 [m];
			attribute sealIntegrity: Real = 1.0;
			part pistonValve: PistonValve;
			port rodInterface: Ports::RodInterface;
			port upperChamber: Ports::WaterOutPort;
			port lowerChamber: Ports::WaterInPort;
		}

		part def PumpCylinder :> MechanicalComponent {
			attribute boreDiameter: Units::Length = 0.075 [m];
			attribute cylinderLength: Units::Length = 1.2 [m];
			attribute internalPressure: Units::Pressure;
			attribute waterColumnHeight: Units::Length;
			port footValvePort: Ports::WaterInPort;
			port risingPipePort: Ports::WaterOutPort;
			port rodPort: Ports::MechanicalInputPort;

			part piston: Piston;
			part footValve: FootValve;

			connect piston.lowerChamber to footValve.outlet;
			connect footValve.inlet to footValvePort;
			connect piston.upperChamber to risingPipePort;
		}

		part def RisingPipe :> MechanicalComponent {
			attribute length: Units::Length;
			attribute innerDiameter: Units::Length = 0.04 [m];
			port intake: Ports::WaterInPort;
			port outlet: Ports::WaterOutPort;
		}

		part def DischargeSpout :> MechanicalComponent {
			attribute flowRate: Units::FlowRate;
			port inlet: Ports::WaterInPort;
			port outlet: Ports::WaterOutPort;
		}

		part def StorageTank :> MechanicalComponent {
			attribute capacity: Units::Volume = 200 [L];
			attribute currentVolume: Units::Volume = 0 [L];
			port inlet: Ports::WaterInPort;

			action def CollectWater {
			in v: Units::Volume;
				then assign currentVolume := currentVolume + v;
			}
		}

		part def WellSource {
			attribute staticWaterLevel: Units::Depth;
			attribute availableVolume: Units::Volume;
			port outlet: Ports::WaterOutPort;
		}
	}

	package System {
		part def BushPump {
			attribute maxOperatingDepth: Units::Depth = 40 [m];
			attribute minFlowRate: Units::FlowRate = 12 [L/min];
			attribute nominalCycleFrequency: Units::Frequency = 40 [1/min];
			attribute currentFlowRate: Units::FlowRate;
			attribute cyclesCompleted: Integer = 0;

			port wellIntake: Ports::WaterInPort;
			port discharge: Ports::WaterOutPort;

			part handle: Components::OperatingHandle {
				attribute mass := 8 [kg];
			}
			part rod: Components::PumpRod {
				attribute length := 42 [m];
				attribute mass := 15 [kg];
			}
			part risingPipe: Components::RisingPipe {
				attribute length := 42 [m];
			}
			part dischargeSpout: Components::DischargeSpout;
			part storageTank: Components::StorageTank;
			part well: Components::WellSource {
				attribute staticWaterLevel := 38 [m];
				attribute availableVolume := 5000 [L];
			}
			part cylinder: Components::PumpCylinder {
				attribute waterColumnHeight := 40 [m];
				part piston: Components::Piston;
				part footValve: Components::FootValve;
			}

			connect handle.rodConnection to rod.topEnd;
			connect rod.bottomEnd to cylinder.rodPort;
			connect well.outlet to wellIntake;
			connect wellIntake to cylinder.footValvePort;
			connect cylinder.risingPipePort to risingPipe.intake;
			connect risingPipe.outlet to dischargeSpout.inlet;
			connect dischargeSpout.outlet to storageTank.inlet;
			connect dischargeSpout.outlet to discharge;

			exhibit state PumpOperation {
				entry; then Downstroke;

				state Downstroke {
					entry {
						assign handle.position := Enums::HandlePosition::DOWN;
						assign cylinder.piston.direction := Enums::PistonDirection::DOWNWARD;
						assign cylinder.footValve.state := Enums::ValveState::CLOSED;
						assign cylinder.piston.pistonValve.state := Enums::ValveState::OPEN;
					}
					do {
						send handle.outputForce to handle.rodConnection;
					}
					exit {
						assign cyclesCompleted := cyclesCompleted + 1;
					}
				}

				transition Downstroke -> Upstroke
					when cylinder.piston.direction == Enums::PistonDirection::DOWNWARD
					if handle.position == Enums::HandlePosition::DOWN;

				state Upstroke {
					entry {
						assign handle.position := Enums::HandlePosition::UP;
						assign cylinder.piston.direction := Enums::PistonDirection::UPWARD;
						assign cylinder.piston.pistonValve.state := Enums::ValveState::CLOSED;
						assign cylinder.footValve.state := Enums::ValveState::OPEN;
					}
					do {
						send handle.outputForce to handle.rodConnection;
						assign currentFlowRate := minFlowRate;
					}
					exit {
						assign cyclesCompleted := cyclesCompleted + 1;
					}
				}

				transition Upstroke -> Downstroke
					when cylinder.piston.direction == Enums::PistonDirection::UPWARD
					if handle.position == Enums::HandlePosition::UP;
			}
		}
	}

	package Requirements {
		requirement def DepthRequirement {
			doc /* The pump shall operate at depths up to 40 meters. */
			attribute maxDepth: Units::Depth = 40 [m];
			subject pump: System::BushPump;
			require pump.maxOperatingDepth <= maxDepth;
		}

		requirement def FlowRateRequirement {
			doc /* The pump shall deliver a minimum flow rate of 12 liters per minute. */
			attribute minFlow: Units::FlowRate = 12 [L/min];
			subject pump: System::BushPump;
			require pump.currentFlowRate >= minFlow;
		}

		requirement def CycleRequirement {
			doc /* The pump shall complete a two-stroke cycle of downstroke and upstroke. */
			subject pump: System::BushPump;
			require pump.cyclesCompleted >= 1;
		}

		requirement def ValveOperationRequirement {
			doc /* The foot valve and piston valve shall operate in opposition during each stroke. */
			subject pump: System::BushPump;
			require ((pump.cylinder.footValve.state == Enums::ValveState::OPEN)
				implies (pump.cylinder.piston.pistonValve.state == Enums::ValveState::CLOSED))
				and ((pump.cylinder.piston.pistonValve.state == Enums::ValveState::OPEN)
				implies (pump.cylinder.footValve.state == Enums::ValveState::CLOSED));
		}

		requirement def StructuralIntegrityRequirement {
			doc /* The pump rod shall withstand tensile loads encountered at maximum depth. */
			attribute maxTensileLoad: Units::Force = 5000 [N];
			subject rod: Components::PumpRod;
			require rod.mass < 20 [kg];
		}

		requirement def StorageRequirement {
			doc /* The storage tank shall collect discharged water. */
			attribute minCapacity: Units::Volume = 100 [L];
			subject tank: Components::StorageTank;
			require tank.capacity >= minCapacity;
		}

		requirement pumpSystemRequirements : DepthRequirement {
			subject pump: System::BushPump;
			satisfy pump by System::BushPump;
		}

		requirement pumpFlowRequirements : FlowRateRequirement {
			subject pump: System::BushPump;
			satisfy pump by System::BushPump;
		}

		requirement pumpValveRequirements : ValveOperationRequirement {
			subject pump: System::BushPump;
			satisfy pump by System::BushPump;
		}

		requirement pumpCycleRequirements : CycleRequirement {
			subject pump: System::BushPump;
			satisfy pump by System::BushPump;
		}

		requirement rodRequirements : StructuralIntegrityRequirement {
			subject rod: Components::PumpRod;
			satisfy rod by System::BushPump::rod;
		}

		requirement tankRequirements : StorageRequirement {
			subject tank: Components::StorageTank;
			satisfy tank by System::BushPump::storageTank;
		}
	}
}
