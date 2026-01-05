package 'Vapor Lock System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def Fuel {
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute vaporPressure : PressureValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute liquidFraction : Real;
	}
	
	item def VaporBubble {
		attribute volume : VolumeValue;
		attribute growthRate : VolumeFlowRateValue;
	}
	
	port def FuelPort {
		out attribute fuelFlow : Fuel;
	}
	
	port def SensorPort {
		out attribute reading : Real;
	}
	
	part def FuelTank {
		port fuelOut : FuelPort;
		attribute capacity : VolumeValue;
		attribute fuelLevel : VolumeValue;
	}
	
	part def FuelPump {
		port fuelIn : FuelPort;
		port fuelOut : FuelPort;
		attribute outputPressure : PressureValue;
		attribute flowCapacity : VolumeFlowRateValue;
	}
	
	part def FuelLine {
		port inlet : FuelPort;
		port outlet : FuelPort;
		attribute length : LengthValue;
		attribute diameter : LengthValue;
		attribute ambientTemperature : TemperatureValue;
		attribute internalPressure : PressureValue;
		attribute vaporContent : Real;
	}
	
	part def Engine {
		port fuelIntake : FuelPort;
		attribute requiredFlowRate : VolumeFlowRateValue;
		attribute operatingTemperature : TemperatureValue;
		attribute powerOutput : PowerValue;
	}
	
	part def TemperatureSensor {
		port measurementPoint : FuelPort;
		port signal : SensorPort;
		attribute measuredTemperature : TemperatureValue;
	}
	
	part def PressureSensor {
		port measurementPoint : FuelPort;
		port signal : SensorPort;
		attribute measuredPressure : PressureValue;
	}
	
	part def CoolingSystem {
		port coolantIn;
		port coolantOut;
		attribute coolingCapacity : PowerValue;
		attribute targetTemperature : TemperatureValue;
	}
	
	part def VentValve {
		port fuelConnection : FuelPort;
		port ventPort;
		attribute isOpen : Boolean;
		attribute ventRate : VolumeFlowRateValue;
	}
	
	action def MonitorFuelState {
		in fuelTemp : TemperatureValue;
		in fuelPressure : PressureValue;
		in vaporPressure : PressureValue;
		out vaporLockRisk : Boolean;
		out vaporFraction : Real;
	}
	
	action def CalculateVaporPressure {
		in temperature : TemperatureValue;
		out vaporPressure : PressureValue;
	}
	
	action def ActivateCooling {
		in currentTemp : TemperatureValue;
		in targetTemp : TemperatureValue;
		out coolingActive : Boolean;
	}
	
	action def IncreasePumpPressure {
		in currentPressure : PressureValue;
		in targetPressure : PressureValue;
		out newPressure : PressureValue;
	}
	
	action def VentVapor {
		in vaporVolume : VolumeValue;
		out ventingComplete : Boolean;
	}
	
	action def VerifyFlow {
		out flowRestored : Boolean;
	}
	
	part def VaporLockPreventionSystem {
		attribute vaporPresent : Boolean;
		attribute requiredPressure : PressureValue;
		attribute estimatedVaporVolume : VolumeValue;
		
		part fuelTank : FuelTank {
			attribute :>> capacity = 60.0;
			attribute :>> fuelLevel = 45.0;
		}
		
		part fuelPump : FuelPump {
			attribute :>> outputPressure = 350.0;
			attribute :>> flowCapacity = 0.0008;
		}
		
		part fuelLine : FuelLine {
			attribute :>> length = 3.0;
			attribute :>> diameter = 0.01;
			attribute :>> ambientTemperature = 90.0;
			attribute :>> internalPressure = 300.0;
			attribute :>> vaporContent = 0.0;
		}
		
		part engine : Engine {
			attribute :>> requiredFlowRate = 0.0006;
			attribute :>> operatingTemperature = 95.0;
			attribute :>> powerOutput = 120.0;
		}
		
		part tempSensor : TemperatureSensor;
		part pressureSensor : PressureSensor;
		part coolingSystem : CoolingSystem {
			attribute :>> coolingCapacity = 5.0;
			attribute :>> targetTemperature = 70.0;
		}
		part ventValve : VentValve {
			attribute :>> isOpen = false;
			attribute :>> ventRate = 0.0001;
		}
		
		connection tankToPump connect fuelTank.fuelOut to fuelPump.fuelIn;
		connection pumpToLine connect fuelPump.fuelOut to fuelLine.inlet;
		connection lineToEngine connect fuelLine.outlet to engine.fuelIntake;
		connection tempMonitor connect tempSensor.measurementPoint to fuelLine.outlet;
		connection pressureMonitor connect pressureSensor.measurementPoint to fuelLine.outlet;
		connection ventConnection connect ventValve.fuelConnection to fuelLine.outlet;
		
		perform action preventVaporLock {
			first start;
			then merge continuousMonitor;
			
			then action monitorAction : MonitorFuelState {
				in fuelTemp = tempSensor.measuredTemperature;
				in fuelPressure = pressureSensor.measuredPressure;
				in vaporPressure = calcVP.vaporPressure;
				out vaporLockRisk;
				out vaporFraction;
			}
			
			action calcVP : CalculateVaporPressure {
				in temperature = tempSensor.measuredTemperature;
				out vaporPressure;
			}
			
			then decide riskCheck;
			
			if monitorAction.vaporLockRisk then mitigate;
			if not monitorAction.vaporLockRisk then continuousMonitor;
			
			action mitigate {
				first parallel startMitigation;
				
				action startMitigation parallel {
					action activateCool : ActivateCooling {
						in currentTemp = tempSensor.measuredTemperature;
						in targetTemp = coolingSystem.targetTemperature;
						out coolingActive;
					}
					
					action boostPressure : IncreasePumpPressure {
						in currentPressure = pressureSensor.measuredPressure;
						in targetPressure = 400.0;
						out newPressure;
					}
					
					action openVent : VentVapor {
						in vaporVolume = estimatedVaporVolume;
						out ventingComplete;
					}
				}
				
				then join checkMitigation;
				
				then action verifyMitigation {
					in coolingStatus = activateCool.coolingActive;
					in pressureStatus = boostPressure.newPressure;
					in ventStatus = openVent.ventingComplete;
					out mitigationSuccess : Boolean;
				}
				
				then decide mitigationResult;
				
				if verifyMitigation.mitigationSuccess then continuousMonitor;
				if not verifyMitigation.mitigationSuccess then mitigate;
			}
		}
	}
	
	requirement <'VL-REQ-001'> preventVaporLockFormation {
		doc /* The vapor lock prevention system shall maintain fuel in liquid state 
		        by keeping fuel line temperature below the fuel's boiling point at 
		        operating pressure throughout all normal operating conditions. */
		
		subject system : VaporLockPreventionSystem;
		
		require constraint temperatureControl {
			system.tempSensor.measuredTemperature < 80.0
		}
		
		require constraint pressureMaintenance {
			system.pressureSensor.measuredPressure > 280.0
		}
	}
	
	requirement <'VL-REQ-002'> detectVaporLockConditions {
		doc /* The system shall continuously monitor fuel temperature and pressure 
		        to detect vapor lock conditions within 200 milliseconds of onset. */
		
		subject system : VaporLockPreventionSystem;
		
		require constraint monitoringFrequency {
			monitoringCycleTime < 0.2
		}
		
		attribute monitoringCycleTime : Real;
	}
	
	requirement <'VL-REQ-003'> mitigateVaporLock {
		doc /* Upon detecting vapor lock risk, the system shall activate cooling, 
		        increase fuel pressure, and vent vapor to restore liquid fuel flow 
		        within 8 seconds. */
		
		subject system : VaporLockPreventionSystem;
		
		require constraint responseTime {
			mitigationDuration < 8.0
		}
		
		require constraint flowRestoration {
			system.engine.requiredFlowRate <= restoredFlowRate
		}
		
		attribute mitigationDuration : Real;
		attribute restoredFlowRate : Real;
	}
	
	requirement <'VL-REQ-004'> ensureContinuousOperation {
		doc /* The vapor lock prevention system shall operate reliably across 
		        ambient temperatures from -10 to 55 degrees and maintain continuous 
		        fuel delivery to the engine. */
		
		subject system : VaporLockPreventionSystem;
		
		require constraint ambientRange {
			-10.0 <= system.fuelLine.ambientTemperature and 
			system.fuelLine.ambientTemperature <= 55.0
		}
		
		require constraint availability {
			systemAvailability >= 0.995
		}
		
		attribute systemAvailability : Real;
	}
	
	part vaporLockSystem : VaporLockPreventionSystem;
}
