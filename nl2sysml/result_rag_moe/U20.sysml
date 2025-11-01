// Create a power unit that supplies electricity to servers and prevents overload.
package 'PowerDistributionSystem' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	// --- Value Types and Items ---
	attribute def Power :> ISQ::PowerValue;
	attribute def Current :> ISQ::ElectricCurrentValue;
	attribute def Voltage :> ISQ::ElectricPotentialValue;

	item def Electricity {
		attribute voltage : Voltage;
		attribute current : Current;
	}

	// --- Ports and Interfaces ---
	port def PowerInPort;
	port def PowerOutPort;

	interface def PowerInterface {
		end supplier : PowerOutPort;
		end consumer : PowerInPort;
	}

	// --- Component Definitions ---
	part def Server {
		port powerIn : PowerInPort;
		attribute powerConsumption : Power default 250[W];
	}

	part def PowerDistributionUnit {
		attribute maxCurrent : Current = 16[A];
		attribute nominalVoltage : Voltage = 230[V];
		attribute readonly totalCurrentDraw : Current;
		port mainPowerIn : PowerInPort;
		port serverOutlets : PowerOutPort[8];

		action def TripBreaker {
			doc "Opens the main circuit, interrupting power flow to all server outlets.";
		}
		action def ResetBreaker {
			doc "Closes the main circuit, restoring power flow to server outlets.";
		}

		event def Reset;

		state machine OverloadProtection {
			initial state Operating;

			state Operating {
				doc "The PDU is supplying power normally to all outlets.";
				transition to Tripped
					when self.owner.totalCurrentDraw > self.owner.maxCurrent {
					perform TripBreaker;
				}
			}

			state Tripped {
				doc "The PDU has detected an overload and has cut power to all outlets.";
				entry { doc "All outlets are disabled."; }
				transition to Operating on accept Reset {
					perform ResetBreaker;
				}
				exit { doc "All outlets are re-enabled."; }
			}
		}
	}

	// --- System Assembly Definition ---
	part def ServerRack {
		part pdu : PowerDistributionUnit;
		part servers : Server[8];

		for (i in 1..8) {
			interface powerConnection : PowerInterface connect
				supplier ::> pdu.serverOutlets[i] to
				consumer ::> servers[i].powerIn;
		}

		flow of Electricity from pdu.serverOutlets to servers.powerIn;

		bind pdu.totalCurrentDraw = sum(servers.powerConsumption) / pdu.nominalVoltage;
	}

	// --- Requirement Definition ---
	requirement def OverloadProtectionRequirement {
		subject pdu : PowerDistributionUnit;
		subject servers : Server[*];

		doc "The Power Distribution Unit shall enter the Tripped state if the total
		     current draw from connected servers exceeds its maximum rated current.";

		require constraint checkOverload {
			(sum(servers.powerConsumption) / pdu.nominalVoltage) > pdu.maxCurrent implies
				pdu.OverloadProtection.state == PowerDistributionUnit::OverloadProtection::Tripped
		}
	}

	// --- Example System Instance ---
	part dataCenterRack : ServerRack {
		// Override default power consumption for some servers to create a specific scenario
		// Total power = 7 * 500W + 1 * 250W = 3750W
		// Total current = 3750W / 230V = 16.3A, which exceeds the 16A limit.
		part :>> servers[0] { attribute :>> powerConsumption = 500[W]; }
		part :>> servers[1] { attribute :>> powerConsumption = 500[W]; }
		part :>> servers[2] { attribute :>> powerConsumption = 500[W]; }
		part :>> servers[3] { attribute :>> powerConsumption = 500[W]; }
		part :>> servers[4] { attribute :>> powerConsumption = 500[W]; }
		part :>> servers[5] { attribute :>> powerConsumption = 500[W]; }
		part :>> servers[6] { attribute :>> powerConsumption = 500[W]; }
		// Server 7 uses the default 250[W]
	}

	// Instantiate the requirement for the specific system instance
	requirement overloadReq on dataCenterRack {
		satisfy overloadProtection : OverloadProtectionRequirement {
			subject pdu = dataCenterRack.pdu;
			subject servers = dataCenterRack.servers;
		}
	}
}
