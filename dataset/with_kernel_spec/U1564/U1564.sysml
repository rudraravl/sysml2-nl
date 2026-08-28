package 'STS-133 Mission System' {
	private import ScalarValues::*;
	private import SI::*;

	package Definitions {
		item def CrewMember;
		item def Fuel;

		item def Cargo;
		item def PMM :> Cargo {
			attribute mass : Real = 8000 [kg];
			attribute volume : Real = 70 [m^3];
		}
		item def ELC4 :> Cargo {
			attribute mass : Real = 5000 [kg];
		}
		item def Robonaut2 :> Cargo {
			attribute mass : Real = 300 [kg];
		}

		port def DockingPort {
			attribute status : String;
		}

		port def CargoPort {
			out item cargo : Cargo;
		}

		part def Spacecraft {
			attribute mass : Real;
			port dockingPort : DockingPort;
		}

		part def OMS {
			attribute thrust : Real;
		}

		part def RCS {
			attribute thrusterCount : Integer;
		}

		part def PayloadBay {
			port cargoOut : CargoPort;
			attribute capacity : Real = 25000 [kg];
		}

		part def Orbiter :> Spacecraft {
			part oms : OMS;
			part rcs : RCS;
			part payloadBay : PayloadBay;
			attribute crewSize : Integer = 6;
			part crew : CrewMember [6];
		}

		part def ISS :> Spacecraft {
			attribute altitude : Real = 400000 [m];
			port cargoIn : ~CargoPort;
		}

		action def Launch;
		action def Rendezvous;
		action def Dock;
		action def TransferCargo;
		action def EVA {
			attribute duration : Real = 21600 [s];
		}
		action def Undock;
		action def FlyAround;
		action def Deorbit;
		action def Entry;
		action def Land;

		state machine def MissionPhases {
			state launchAscent {
				entry action launch : Launch;
			}
			transition from launchAscent to rendezvous;
			state rendezvous {
				entry action rendezvousAction : Rendezvous;
			}
			transition from rendezvous to docking;
			state docking {
				entry action dock : Dock;
			}
			transition from docking to dockedOperations;
			state dockedOperations {
				entry action transferCargo : TransferCargo;
				state eva1 {
					entry action eva1Action : EVA;
				}
				state eva2 {
					entry action eva2Action : EVA;
				}
			}
			transition from dockedOperations to undocking;
			state undocking {
				entry action undock : Undock;
			}
			transition from undocking to flyAround;
			state flyAround {
				entry action flyAroundAction : FlyAround;
			}
			transition from flyAround to deorbit;
			state deorbit {
				entry action deorbitAction : Deorbit;
			}
			transition from deorbit to reentry;
			state reentry {
				entry action entryAction : Entry;
			}
			transition from reentry to landing;
			state landing {
				entry action land : Land;
			}
		}

		requirement def MissionObjective {
			text "Deliver critical hardware and supplies to the ISS.";
		}
		requirement def DeliverCargo :> MissionObjective {
			text "Deliver PMM, ELC-4, and Robonaut 2 to ISS";
		}
		requirement def PerformEVAs :> MissionObjective {
			text "Perform two spacewalks for installation and maintenance";
		}
		requirement def ReturnSafely :> MissionObjective {
			text "Return orbiter and crew safely to Earth";
		}
	}

	package Usages {
		part sts133Mission {
			part discovery : Orbiter {
				part oms : OMS;
				part rcs : RCS;
				part payloadBay : PayloadBay {
					item pmm : PMM;
					item elc4 : ELC4;
					item robonaut2 : Robonaut2;
				}
				part crew : CrewMember [6];
				port dockingPort : DockingPort;
			}

			part iss : ISS {
				port dockingPort : DockingPort;
			}

			bind discovery.dockingPort = iss.dockingPort;

			flow of cargo : Cargo from discovery.payloadBay.cargoOut.cargo to iss.cargoIn.cargo;

			perform missionPhases : MissionPhases;

			requirement deliverCargoReq : DeliverCargo;
			requirement performEVAsReq : PerformEVAs;
			requirement returnSafelyReq : ReturnSafely;

			satisfy deliverCargoReq by missionPhases.dockedOperations.transferCargo;
			satisfy performEVAsReq by missionPhases.dockedOperations.eva1, missionPhases.dockedOperations.eva2;
			satisfy returnSafelyReq by missionPhases.landing.land;
		}
	}
}
