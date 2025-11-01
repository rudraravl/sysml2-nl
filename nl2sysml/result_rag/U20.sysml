// Create a power unit that supplies electricity to servers and prevents overload.
package 'Power Distribution System' {
	private import SI::{W, A, V, V_AC};
	private import ScalarValues::{Real, Boolean};

	attribute def Power :> Real { 
		:>> unit = W; 
	}
	attribute def Current :> Real { 
		:>> unit = A; 
	}
	attribute def Voltage :> Real { 
		:>> unit = V; 
	}

	item def AC_Power {
		attribute voltage : Voltage default 230[V_AC];
		attribute current : Current;
		attribute power : Power default voltage * current;
	}

	port def PowerPort {
		inout flow : AC_Power;
	}

	part def Server {
		port powerInput : PowerPort;
		attribute nominalConsumption : Power;
		
		bind powerInput.flow.current = 
			if powerInput.flow.voltage > 0[V] then
				nominalConsumption / powerInput.flow.voltage
			else 0[A];
	}

	part def PowerDistributionUnit {
		port powerIn : PowerPort;
		port outlets[1..*] : PowerPort;
		
		attribute maxCapacity : Power;
		attribute isTripped : Boolean default false;
		
		attribute totalLoad : Power default sum(outlets.flow.power);

		action tripBreaker {
			out isTripped = true;
		}

		action resetBreaker {
			out isTripped = false;
		}

		state machine OverloadProtection {
			initial state PowerOn {
				entry { isTripped = false; }
				transition to PowerTripped 
					when totalLoad > maxCapacity 
					do tripBreaker;
			}
			state PowerTripped {
				entry { isTripped = true; }
				transition to PowerOn on resetBreaker;
			}
		}
	}

	part def ServerRack {
		part pdu : PowerDistributionUnit {
			:>> maxCapacity = 3600[W];
		}
		part servers[1..8] : Server;

		for i in 1..size(servers) {
			connect pdu.outlets[i] to servers[i].powerInput;
		}
		
		for outlet in pdu.outlets {
			bind outlet.flow.voltage = 
				if pdu.isTripped then 0[V] 
				else pdu.powerIn.flow.voltage;
		}
	}

	requirement def OverloadProtection {
		doc "The PDU shall interrupt power to all outlets if the total power draw exceeds its maximum capacity.";
		subject pdu : PowerDistributionUnit;
		constraint { 
			if pdu.totalLoad > pdu.maxCapacity then pdu.isTripped
		}
	}

	satisfy requirement OverloadProtection by PowerDistributionUnit::OverloadProtection;

	part system 'Data Center Power System' {
		part rack : ServerRack {
			part :>> servers[1] { :>> nominalConsumption = 750[W]; }
			part :>> servers[2] { :>> nominalConsumption = 750[W]; }
			part :>> servers[3] { :>> nominalConsumption = 750[W]; }
			part :>> servers[4] { :>> nominalConsumption = 750[W]; }
			part :>> servers[5] { :>> nominalConsumption = 750[W]; }
			// The 6th server would cause an overload: 6 * 750W = 4500W > 3600W
		}
		
		part mainPowerSource;
		
		flow of AC_Power from mainPowerSource to rack.pdu.powerIn;
	}
}
