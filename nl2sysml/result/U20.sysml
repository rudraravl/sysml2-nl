// Create a power unit that supplies electricity to servers and prevents overload.
package 'ElectricalSystem' {
	private import ScalarValues::*;
	private import ScalarFunctions::*;

	item def Electricity;

	port def PowerOutPort {
		out electricity : Electricity;
	}

	port def PowerInPort {
		in electricity : Electricity;
	}

	part def Server {
		port powerInput : PowerInPort;
		attribute powerConsumption : Real;
	}

	part def PowerUnit {
		port powerOutput : PowerOutPort;
		attribute maxCapacity : Real;
		attribute currentLoad : Real;
		constraint overloadPrevention { currentLoad <= maxCapacity; }
	}

	part def ElectricalSystemAssembly {
		part powerSource : PowerUnit;
		part connectedServers : Server[*];
		attribute :>> powerSource.currentLoad = sum(connectedServers.powerConsumption);
	}
}
