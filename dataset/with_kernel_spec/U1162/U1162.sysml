package 'Picotechnology Assembly System' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SequenceFunctions::*;

	package Items {
		attribute def PositionVector {
			attribute x :> ISQ::length;
			attribute y :> ISQ::length;
			attribute z :> ISQ::length;
		}

		enum def Element {
			Carbon;
			Silicon;
			Oxygen;
			Hydrogen;
			Nitrogen;
		}

		item def Atom {
			attribute element : Element;
			attribute position : PositionVector;
		}

		item def AtomicMap {
			attribute atoms : Atom[*];
			attribute resolution :> ISQ::length;
		}

		item def AtomPlacement {
			attribute element : Element;
			attribute targetPosition : PositionVector;
		}

		item def AssemblyPlan {
			attribute steps : AtomPlacement[*];
		}

		item def ForceCommand {
			attribute force :> ISQ::force;
		}

		item def PositionCommand {
			attribute position : PositionVector;
		}
	}

	package Components {
		private import Items::*;

		part def VacuumChamber {
			attribute pressure :> ISQ::pressure;
			attribute temperature :> ISQ::thermodynamicTemperature;
			port environmentPort {
				out pressureReading :> ISQ::pressure;
				out temperatureReading :> ISQ::thermodynamicTemperature;
			}
			action pumpDown;
			action stabilizeTemperature;
		}

		part def ProbeTip {
			attribute radius :> ISQ::length;
		}

		part def PiezoelectricActuator {
			attribute resolution :> ISQ::length;
			port actuatorPort {
				in positionCommand : PositionCommand;
				out actualPosition : PositionVector;
			}
			action moveTo {
				in target : PositionVector;
				out achieved : PositionVector;
			}
		}

		part def ScanningProbe {
			part tip : ProbeTip;
			part actuators : PiezoelectricActuator[3];
			port probePort {
				in positionCommand : PositionCommand;
				in forceCommand : ForceCommand;
				out currentPosition : PositionVector;
				out sensedForce :> ISQ::force;
				out atomAttached : Boolean;
			}
			port atomPort {
				in atom : Atom;
			}
		}

		part def HighResolutionImager {
			port imagerPort {
				in scanRequest : Boolean;
				out atomicMap : AtomicMap;
			}
			action scanSurface {
				in area : PositionVector;
				out map : AtomicMap;
			}
		}

		part def AtomicForceController {
			attribute forceSetpoint :> ISQ::force;
			port controllerPort {
				in sensedForce :> ISQ::force;
				out forceCommand : ForceCommand;
			}
			calc def forceError {
				in measured : ISQ::force;
				in setpoint : ISQ::force;
				return : ISQ::force = measured - setpoint;
			}
			action controlForce {
				in measured : ISQ::force;
				out adjustment : ForceCommand;
			}
		}

		part def PositionFeedbackSystem {
			attribute targetPosition : PositionVector;
			port feedbackPort {
				in currentPosition : PositionVector;
				out correctedPosition : PositionCommand;
				out positionError :> ISQ::length;
			}
			calc def errorMagnitude {
				in actual : PositionVector;
				in target : PositionVector;
				return : ISQ::length;
			}
		}

		part def AtomicReservoir {
			attribute availableElements : Element[*];
			port reservoirPort {
				in requestElement : Element;
				out suppliedAtom : Atom;
			}
			action dispenseAtom {
				in element : Element;
				out atom : Atom;
			}
		}
	}

	package Behaviors {
		private import Components::*;
		private import Items::*;

		action def InitializeSystem {
			in chamber : VacuumChamber;
			in probe : ScanningProbe;
			out status : String;
			action pumpDown;
			then action stabilizeTemperature;
			then action calibrateProbe;
		}

		action def ScanArea {
			in probe : ScanningProbe;
			in imager : HighResolutionImager;
			out map : AtomicMap;
		}

		action def ManipulateAtom {
			in element : Element;
			in destination : PositionVector;
			in probe : ScanningProbe;
			in controller : AtomicForceController;
			out success : Boolean;
			action approach;
			then action attach;
			then action move;
			then action release;
		}

		action def AssembleStructure {
			in plan : AssemblyPlan;
			in probe : ScanningProbe;
			in controller : AtomicForceController;
			for i in 1..plan.steps->size() {
				perform action manipulate : ManipulateAtom {
					in element = plan.steps#(i).element;
					in destination = plan.steps#(i).targetPosition;
					in probe = probe;
					in controller = controller;
				}
			}
		}

		state machine def PicoSystemStates {
			state idle;
			state initialize;
			state ready;
			state scanning;
			state manipulating;
			state assembling;

			transition from idle to initialize;
			transition from initialize to ready;
			transition from ready to scanning;
			transition from scanning to manipulating;
			transition from manipulating to assembling;
			transition from assembling to ready;
		}
	}

	package System {
		private import Components::*;
		private import Items::*;
		private import Behaviors::*;

		part def PicoAssemblySystem {
			part chamber : VacuumChamber;
			part probe : ScanningProbe;
			part imager : HighResolutionImager;
			part forceController : AtomicForceController;
			part feedbackSystem : PositionFeedbackSystem;
			part reservoir : AtomicReservoir;

			flow positionCommandFlow of PositionCommand
				from feedbackSystem.feedbackPort.correctedPosition to probe.probePort.positionCommand;
			flow forceCommandFlow of ForceCommand
				from forceController.controllerPort.forceCommand to probe.probePort.forceCommand;
			flow probePositionFlow of PositionVector
				from probe.probePort.currentPosition to feedbackSystem.feedbackPort.currentPosition;
			flow probeForceFlow of ISQ::force
				from probe.probePort.sensedForce to forceController.controllerPort.sensedForce;
			flow atomSupplyFlow of Atom
				from reservoir.reservoirPort.suppliedAtom to probe.atomPort.atom;

			port systemPort {
				in startCommand : Boolean;
				in assemblyPlan : AssemblyPlan;
				out status : String;
				out atomicMap : AtomicMap;
			}

			bind systemPort.atomicMap = imager.imagerPort.atomicMap;
		}

		part picoSystemInstance : PicoAssemblySystem {
			exhibit systemStates : PicoSystemStates;
		}
	}

	package Requirements {
		private import System::*;
		private import Items::*;

		requirement def VacuumEnvironment {
			doc /* The system shall operate in an ultra-high vacuum with pressure below 1e-9 Pa and temperature below 4 K. */
			attribute maxPressure :> ISQ::pressure;
			attribute maxTemperature :> ISQ::thermodynamicTemperature;
			subject chamber : VacuumChamber;
			require chamber.pressure <= maxPressure and chamber.temperature <= maxTemperature;
		}

		requirement def PositioningAccuracy {
			doc /* The probe positioning error shall be less than 10 picometers. */
			attribute maxError :> ISQ::length;
			subject feedbackSystem : PositionFeedbackSystem;
			require feedbackSystem.feedbackPort.positionError <= maxError;
		}

		requirement def ForceControlResolution {
			doc /* The force controller shall resolve forces at the femtonewton scale. */
			attribute maxForceResolution :> ISQ::force;
			subject controller : AtomicForceController;
			require controller.forceSetpoint <= maxForceResolution;
		}

		requirement def AssemblyWorkflow {
			doc /* The system shall follow a precise workflow: initialize, scan, manipulate atoms, and assemble structures. */
			subject system : PicoAssemblySystem;
		}

		part picoSystemVerification : PicoAssemblySystem {
			satisfy VacuumEnvironment by chamber;
			satisfy PositioningAccuracy by feedbackSystem;
			satisfy ForceControlResolution by forceController;
			satisfy AssemblyWorkflow;
		}
	}
}
