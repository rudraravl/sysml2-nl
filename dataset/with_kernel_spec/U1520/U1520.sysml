package 'Active Vapor Lock Prevention System' {
	private import ScalarValues::*;
	
	attribute def Temperature :> Real;
	attribute def Pressure :> Real;
	
	item def LiquidFuel;
	item def FuelVapor;
	
	attribute def SensorUpdate;
	attribute def PumpBoostSignal;
	attribute def PumpNormalSignal;
	attribute def CoolingOnSignal;
	attribute def CoolingOffSignal;
	attribute def VentOpenSignal;
	attribute def VentCloseSignal;
	
	state def PumpStates;
	state def CoolingStates;
	state def VentStates;
	state def ControlLogic;
	
	port def FuelOutPort {
		out item fuel : LiquidFuel;
	}
	port def FuelInPort {
		in item fuel : LiquidFuel;
	}
	port def VaporOutPort {
		out item vapor : FuelVapor;
	}
	port def VaporInPort {
		in item vapor : FuelVapor;
	}
	port def TempSensorOutPort {
		out attribute reading : Temperature;
	}
	port def PressureSensorOutPort {
		out attribute reading : Pressure;
	}
	
	part def FuelTank {
		port fuelOut : FuelOutPort;
	}
	
	part def FuelPump {
		port fuelIn : FuelInPort;
		port fuelOut : FuelOutPort;
		attribute outputPressure : Pressure;
		
		state pumpStates : PumpStates {
			entry; then normal;
			state normal;
			accept PumpBoostSignal then boosted;
			state boosted;
			accept PumpNormalSignal then normal;
		}
	}
	
	part def FuelLine {
		port fuelIn : FuelInPort;
		port fuelOut : FuelOutPort;
		port vaporOut : VaporOutPort;
		attribute temperature : Temperature;
		attribute pressure : Pressure;
	}
	
	part def Engine {
		port fuelIn : FuelInPort;
	}
	
	part def TemperatureSensor {
		port dataOut : TempSensorOutPort;
		attribute reading : Temperature;
		bind dataOut.reading = reading;
	}
	
	part def PressureSensor {
		port dataOut : PressureSensorOutPort;
		attribute reading : Pressure;
		bind dataOut.reading = reading;
	}
	
	part def CoolingSystem {
		attribute active : Boolean = false;
		
		state coolingStates : CoolingStates {
			entry; then idle;
			state idle;
			accept CoolingOnSignal then activeState;
			state activeState;
			accept CoolingOffSignal then idle;
		}
	}
	
	part def VentValve {
		port vaporIn : VaporInPort;
		attribute open : Boolean = false;
		
		state ventStates : VentStates {
			entry; then closed;
			state closed;
			accept VentOpenSignal then openState;
			state openState;
			accept VentCloseSignal then closed;
		}
	}
	
	part def VaporLockPreventionSystem {
		attribute criticalTemp : Temperature = 80;
		attribute criticalPressure : Pressure = 30;
		attribute safeTemp : Temperature = 50;
		attribute safePressure : Pressure = 50;
		
		part tank : FuelTank;
		part pump : FuelPump;
		part line : FuelLine;
		part eng : Engine;
		part tempSensor : TemperatureSensor;
		part pressureSensor : PressureSensor;
		part cooler : CoolingSystem;
		part vent : VentValve;
		
		flow of LiquidFuel from tank.fuelOut.fuel to pump.fuelIn.fuel;
		flow of LiquidFuel from pump.fuelOut.fuel to line.fuelIn.fuel;
		flow of LiquidFuel from line.fuelOut.fuel to eng.fuelIn.fuel;
		flow of FuelVapor from line.vaporOut.vapor to vent.vaporIn.vapor;
		
		bind tempSensor.reading = line.temperature;
		bind pressureSensor.reading = line.pressure;
		
		state controlLogic : ControlLogic {
			in lineTemp : Temperature = tempSensor.reading;
			in linePressure : Pressure = pressureSensor.reading;
			in pumpPart : FuelPump = pump;
			in coolerPart : CoolingSystem = cooler;
			in ventPart : VentValve = vent;
			in critTemp : Temperature = criticalTemp;
			in critPressure : Pressure = criticalPressure;
			in sfTemp : Temperature = safeTemp;
			in sfPressure : Pressure = safePressure;
			
			entry; then monitoring;
			
			state monitoring;
			
			accept SensorUpdate
				if lineTemp > critTemp or linePressure < critPressure
				then countermeasure;
			
			state countermeasure {
				entry action activateCountermeasures {
					send new PumpBoostSignal() to pumpPart;
					send new CoolingOnSignal() to coolerPart;
					send new VentOpenSignal() to ventPart;
				}
				exit action deactivateCountermeasures {
					send new PumpNormalSignal() to pumpPart;
					send new CoolingOffSignal() to coolerPart;
					send new VentCloseSignal() to ventPart;
				}
			}
			
			accept SensorUpdate
				if lineTemp < sfTemp and linePressure > sfPressure
				then monitoring;
		}
	}
	
	requirement def PreventVaporLock {
		doc /* The system shall prevent vapor lock in the fuel line by continuously monitoring fuel temperature and pressure, and automatically initiating countermeasures when critical thresholds are reached. */
		subject system : VaporLockPreventionSystem;
	}
	
	requirement def ContinuousFuelSupply {
		doc /* The system shall ensure a continuous and reliable supply of liquid fuel to the engine under all operating conditions. */
		subject system : VaporLockPreventionSystem;
	}
	
	requirement def SensorPlacement {
		doc /* Dedicated temperature and pressure sensors shall be placed on the fuel line near the engine intake to monitor the fuel physical state. */
		subject system : VaporLockPreventionSystem;
	}
	
	requirement def CoordinatedCountermeasures {
		doc /* When vapor lock conditions are detected, the system shall simultaneously activate the cooling system to reduce fuel temperature, command the fuel pump to increase output pressure, and open the vent valve to release accumulated vapor. */
		subject system : VaporLockPreventionSystem;
	}
	
	requirement def NormalOperationRestoration {
		doc /* When fuel temperature and pressure return to safe levels, the system shall restore normal pump operation, deactivate the cooling system, and close the vent valve. */
		subject system : VaporLockPreventionSystem;
	}
}
