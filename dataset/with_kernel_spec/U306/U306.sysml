package Meril_Myval_TAVR_System {
	doc
	/*
	 * This model describes the Meril Myval Transcatheter Aortic Valve Replacement (TAVR) System,
	 * designed for minimally invasive aortic valve replacement without open-heart surgery.
	 */

	private import ISQ::*;
	private import ScalarValues::*;

	// --- Item Definitions for Data Flows ---
	item def FluoroscopyImage;
	item def EchocardiogramImage;
	item def HemodynamicData {
		attribute pressureGradient :> pressure;
		attribute bloodFlow :> volumeFlowRate;
	}
	item def ControlCommand;
	item def CatheterStatus;

	// --- Part Definitions ---
	part def Leaflet {
		attribute material : String = "Bovine Pericardium";
	}

	part def ReleaseHandle;
	part def DisplayScreen;
	part def DiseasedAorticValve;
	part def FemoralArtery;

	part def MyvalBioprostheticValve {
		attribute crimpedDiameter :> length;
		attribute expandedDiameter :> length;
		attribute radialForce :> force;
		attribute leafletMaterial : String = "Bovine Pericardium";

		part leaflet : Leaflet[3];

		action crimpValve;
		action deployValve;

		state def ValveLifecycle {
			initial state Crimped;
			state Expanded;
			transition crimp_to_expanded first Crimped then Expanded;
		}

		state valveLifecycle : ValveLifecycle;
	}

	part def NavigatorDeliveryCatheter {
		attribute catheterLength :> length;
		attribute catheterDiameter :> length;

		part releaseHandle : ReleaseHandle;

		port valveMountPort;
		port controlPort {
			in command : ControlCommand;
			out status : CatheterStatus;
		}

		action navigateToHeart;
		action deployValveAtTarget;
		action retractCatheter;
	}

	part def FluoroscopySystem {
		port imagePort {
			out image : FluoroscopyImage;
		}
		action acquireFluoroscopy;
	}

	part def EchocardiographySystem {
		part transesophagealProbe {
			attribute probeFrequency :> frequency;
		}
		port imagePort {
			out image : EchocardiogramImage;
		}
		action performTEEImaging;
		action assessValveFunction;
	}

	part def HemodynamicMonitor {
		port dataPort {
			out data : HemodynamicData;
		}
		action monitorHemodynamics;
		action detectParavalvularLeak;
	}

	part def ControlConsole {
		port fluoroPort {
			in image : FluoroscopyImage;
		}
		port echoPort {
			in image : EchocardiogramImage;
		}
		port hemoPort {
			in data : HemodynamicData;
		}
		port controlPort {
			out command : ControlCommand;
		}
		part displayScreen : DisplayScreen;
		action integrateDataStreams;
		action displayProcedureStatus;
	}

	part def Patient {
		part diseasedAorticValve : DiseasedAorticValve;
		part femoralArtery : FemoralArtery;
	}

	// --- Composite System ---
	part def TAVRSystem {
		part valve : MyvalBioprostheticValve[1] {
			attribute :>> crimpedDiameter = 14.0;
			attribute :>> expandedDiameter = 29.0;
			attribute :>> radialForce = 15.0;
		}
		part catheter : NavigatorDeliveryCatheter[1] {
			attribute :>> catheterLength = 1000.0;
			attribute :>> catheterDiameter = 5.0;
		}
		part fluoro : FluoroscopySystem[1];
		part echo : EchocardiographySystem[1];
		part hemo : HemodynamicMonitor[1];
		part console : ControlConsole[1];
		part patient : Patient[1];

		connection def DataFlowConnection {
			end supplier;
			end consumer;
		}

		connection valveMounting connect catheter.valveMountPort to valve;
		connection fluoroToConsole : DataFlowConnection connect fluoro.imagePort to console.fluoroPort;
		connection echoToConsole : DataFlowConnection connect echo.imagePort to console.echoPort;
		connection hemoToConsole : DataFlowConnection connect hemo.dataPort to console.hemoPort;
		connection consoleToCatheter : DataFlowConnection connect console.controlPort to catheter.controlPort;

		flow fluoroImageFlow of FluoroscopyImage
			from fluoro.imagePort.image to console.fluoroPort.image;
		flow echoImageFlow of EchocardiogramImage
			from echo.imagePort.image to console.echoPort.image;
		flow hemoDataFlow of HemodynamicData
			from hemo.dataPort.data to console.hemoPort.data;
		flow commandFlow of ControlCommand
			from console.controlPort.command to catheter.controlPort.command;
	}

	// --- Procedure State Machine ---
	state def TAVRProcedure {
		initial state Preparation;
		state VascularAccess;
		state Navigation;
		state Positioning;
		state Deployment;
		state Assessment;
		state Withdrawal;
		state Completed;

		transition prep_to_access first Preparation then VascularAccess;
		transition access_to_nav first VascularAccess then Navigation;
		transition nav_to_pos first Navigation then Positioning;
		transition pos_to_deploy first Positioning then Deployment;
		transition deploy_to_assess first Deployment then Assessment;
		transition assess_to_withdraw first Assessment then Withdrawal;
		transition withdraw_to_complete first Withdrawal then Completed;
	}

	// --- Requirements ---
	requirement def ValveDeploymentRequirement {
		doc /* The valve must deploy with sufficient radial force to anchor in the native annulus. */
		subject valve : MyvalBioprostheticValve;
		constraint { valve.radialForce > 5.0 }
	}

	requirement def ImagingIntegrationRequirement {
		doc /* The console must integrate all imaging and hemodynamic data. */
		subject console : ControlConsole;
	}

	requirement def MinimallyInvasiveRequirement {
		doc /* The system must allow valve replacement without open-heart surgery. */
		subject system : TAVRSystem;
	}

	requirement valveReq : ValveDeploymentRequirement {
		subject :>> valve : TAVRSystem::valve;
	}

	requirement imagingReq : ImagingIntegrationRequirement {
		subject :>> console : TAVRSystem::console;
	}

	requirement invasiveReq : MinimallyInvasiveRequirement {
		subject :>> system : TAVRSystem;
	}
}
