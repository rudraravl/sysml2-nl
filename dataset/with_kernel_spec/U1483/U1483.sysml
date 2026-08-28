package 'Resistor Circuit Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		item def Charge;
		
		port def ElectricalPort {
			item charge : Charge;
			attribute voltage : ElectricPotentialDifference;
			attribute current : ElectricCurrent;
		}
		
		part def VoltageSource {
			port positive : ElectricalPort;
			port negative : ElectricalPort;
			attribute outputVoltage : ElectricPotentialDifference;
		}
		
		part def Resistor {
			port terminal1 : ElectricalPort;
			port terminal2 : ElectricalPort;
			attribute resistance : Resistance;
			attribute maxPower : Power;
			attribute maxTemp : ThermodynamicTemperature;
			attribute warningTemp : ThermodynamicTemperature;
			attribute currentTemp : ThermodynamicTemperature;
			attribute dissipatedPower : Power;
			exhibit state 'resistor states' : 'Resistor States';
		}
		
		part def Ground {
			port terminal : ElectricalPort;
		}
		
		action def 'Apply Ohms Law' {
			in voltage : ElectricPotentialDifference;
			in resistance : Resistance;
			out current : ElectricCurrent;
		}
		
		action def 'Calculate Dissipated Power' {
			in voltage : ElectricPotentialDifference;
			in current : ElectricCurrent;
			out power : Power;
		}
		
		action def 'Estimate Temperature Rise' {
			in power : Power;
			out temp : ThermodynamicTemperature;
		}
		
		state def 'Resistor States';
		
		requirement def 'Ohm Law Requirement' {
			doc /* The current through the resistor shall equal the voltage across it divided by its resistance. */
		}
		
		requirement def 'Safe Operation Requirement' {
			doc /* The resistor shall not exceed its maximum power dissipation or maximum temperature ratings. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part circuit {
			part voltageSource : VoltageSource {
				attribute outputVoltage = 12 [V];
			}
			
			part resistor : Resistor {
				attribute resistance = 100 [ohm];
				attribute maxPower = 0.5 [W];
				attribute maxTemp = 350 [K];
				attribute warningTemp = 280 [K];
				attribute currentTemp = 300 [K];
				
				state 'resistor states' : 'Resistor States' {
					entry; then idle;
					
					state idle;
					
					accept when voltageSource.outputVoltage > 0 [V]
						then conducting;
					
					state conducting {
						entry action 'apply ohms law' : 'Apply Ohms Law' {
							in voltage = voltageSource.outputVoltage;
							in resistance = resistor.resistance;
							out current = resistor.terminal1.current;
						}
						entry action 'calculate power' : 'Calculate Dissipated Power' {
							in voltage = voltageSource.outputVoltage;
							in current = resistor.terminal1.current;
							out power = resistor.dissipatedPower;
						}
						do action 'estimate temp' : 'Estimate Temperature Rise' {
							in power = resistor.dissipatedPower;
							out temp = resistor.currentTemp;
						}
					}
					
					accept when voltageSource.outputVoltage == 0 [V]
						then idle;
					
					accept when resistor.currentTemp > resistor.warningTemp
						then heating;
					
					state heating {
						do action 'estimate temp' : 'Estimate Temperature Rise' {
							in power = resistor.dissipatedPower;
							out temp = resistor.currentTemp;
						}
					}
					
					accept when voltageSource.outputVoltage == 0 [V]
						then idle;
					
					accept when resistor.currentTemp > resistor.maxTemp
						then overheated;
					
					state overheated;
					
					accept when voltageSource.outputVoltage == 0 [V]
						then idle;
				}
			}
			
			part ground : Ground;
			
			connect voltageSource.positive to resistor.terminal1;
			connect resistor.terminal2 to ground.terminal;
			connect ground.terminal to voltageSource.negative;
			
			flow of charge : Charge
				from voltageSource.positive.charge to resistor.terminal1.charge;
			flow of charge : Charge
				from resistor.terminal2.charge to ground.terminal.charge;
			flow of charge : Charge
				from ground.terminal.charge to voltageSource.negative.charge;
			
			satisfy 'Ohm Law Requirement' by resistor;
			satisfy 'Safe Operation Requirement' by resistor;
		}
	}
}
