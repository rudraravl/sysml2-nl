package 'Vacuum Insulated Evaporator System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VacuumPressure :> ISQ::pressure;
	attribute def EvaporationRate :> ISQ::volumeFlowRate;
	attribute def HeatLeakRate :> ISQ::heatFlowRate;
	attribute def ThermalConductivity :> ISQ::thermalConductivity;
	attribute def InsulationEfficiency :> ScalarValues::Real;
	
	item def CryogenicLiquid {
		attribute temperature :> ISQ::thermodynamicTemperature;
		attribute pressure :> ISQ::pressure;
		attribute density :> ISQ::density;
		attribute latentHeat :> ISQ::specificEnergy;
	}
	
	item def CryogenicVapor {
		attribute temperature :> ISQ::thermodynamicTemperature;
		attribute pressure :> ISQ::pressure;
		attribute flowRate :> ISQ::volumeFlowRate;
	}
	
	port def LiquidInletPort {
		in item liquid : CryogenicLiquid;
		attribute inletFlowRate :> ISQ::volumeFlowRate;
	}
	
	port def VaporOutletPort {
		out item vapor : CryogenicVapor;
		attribute outletFlowRate :> ISQ::volumeFlowRate;
		attribute outletPressure :> ISQ::pressure;
	}
	
	port def VacuumMaintenancePort {
		attribute vacuumPressure : VacuumPressure;
		attribute heatLeak : HeatLeakRate;
	}
	
	port def ThermalLoadPort {
		in attribute externalHeatLoad :> ISQ::heatFlowRate;
	}
	
	part def InnerVessel {
		attribute storageCapacity :> ISQ::volume;
		attribute wallTemperature :> ISQ::thermodynamicTemperature;
		attribute liquidLevel :> ISQ::length;
		attribute operatingPressure :> ISQ::pressure;
		
		port liquidInlet : LiquidInletPort;
		port vaporOutlet : VaporOutletPort;
		port thermalInterface : ThermalLoadPort;
	}
	
	part def OuterShell {
		attribute ambientTemperature :> ISQ::thermodynamicTemperature;
		attribute shellThickness :> ISQ::length;
		attribute surfaceArea :> ISQ::area;
	}
	
	part def VacuumJacket {
		attribute vacuumGapWidth :> ISQ::length;
		attribute vacuumLevel : VacuumPressure;
		attribute effectiveConductivity : ThermalConductivity;
		attribute insulationEfficiency : InsulationEfficiency;
		
		port vacuumPort : VacuumMaintenancePort;
	}
	
	part def VacuumPumpSystem {
		attribute pumpingSpeed :> ISQ::volumeFlowRate;
		attribute ultimatePressure : VacuumPressure;
		attribute currentPressure : VacuumPressure;
		attribute pumpActive : Boolean;
	}
	
	part def EvaporatorCoil {
		attribute heatTransferArea :> ISQ::area;
		attribute heatTransferCoefficient :> ISQ::heatTransferCoefficient;
		attribute evaporationCapacity : EvaporationRate;
	}
	
	part def PressureRegulationValve {
		attribute setPointPressure :> ISQ::pressure;
		attribute flowCapacity :> ISQ::volumeFlowRate;
		attribute valvePosition : ScalarValues::Real;
	}
	
	part def SafetyReliefValve {
		attribute reliefPressure :> ISQ::pressure;
		attribute reliefCapacity :> ISQ::volumeFlowRate;
		attribute valveState : Boolean;
	}
	
	part def LevelSensor {
		attribute measuredLevel :> ISQ::length;
		attribute sensorAccuracy :> ISQ::length;
		attribute lowLevelAlarm : Boolean;
	}
	
	part def PressureSensor {
		attribute measuredPressure :> ISQ::pressure;
		attribute sensorAccuracy :> ISQ::pressure;
	}
	
	part def TemperatureSensor {
		attribute measuredTemperature :> ISQ::thermodynamicTemperature;
		attribute sensorAccuracy :> ISQ::thermodynamicTemperature;
	}
	
	part def VacuumGauge {
		attribute measuredVacuum : VacuumPressure;
		attribute gaugeAccuracy : VacuumPressure;
	}
	
	action def MonitorLiquidLevel {
		in currentLevel : ISQ::length;
		in minimumLevel : ISQ::length;
		in maximumLevel : ISQ::length;
		out levelOK : Boolean;
		out refillNeeded : Boolean;
	}
	
	action def MonitorVacuumQuality {
		in currentVacuum : VacuumPressure;
		in targetVacuum : VacuumPressure;
		in maximumVacuum : VacuumPressure;
		out vacuumOK : Boolean;
		out pumpRequired : Boolean;
	}
	
	action def CalculateHeatIntrusion {
		in vacuumConductivity : ThermalConductivity;
		in temperatureDelta : ISQ::thermodynamicTemperature;
		in surfaceArea : ISQ::area;
		in gapWidth : ISQ::length;
		out heatLeak : HeatLeakRate;
	}
	
	action def CalculateEvaporationRate {
		in totalHeatLoad : ISQ::heatFlowRate;
		in latentHeatVaporization : ISQ::specificEnergy;
		in liquidDensity : ISQ::density;
		out evaporationRate : EvaporationRate;
	}
	
	action def ControlVacuumPump {
		in vacuumPressure : VacuumPressure;
		in targetPressure : VacuumPressure;
		out activatePump : Boolean;
	}
	
	action def RegulateOutputPressure {
		in currentPressure : ISQ::pressure;
		in targetPressure : ISQ::pressure;
		in tolerance : ISQ::pressure;
		out valveAdjustment : ScalarValues::Real;
	}
	
	action def ManageCryogenSupply {
		in liquidLevel : ISQ::length;
		in minLevel : ISQ::length;
		in maxLevel : ISQ::length;
		out refillCommand : Boolean;
		out shutoffCommand : Boolean;
	}
	
	action def EvaporateCryogen {
		in attribute appliedHeat :> ISQ::heatFlowRate;
		in attribute cryogenProperties : CryogenicLiquid;
		in attribute vesselLevel :> ISQ::length;
		out attribute vaporProduced : EvaporationRate;
		out attribute coolingProvided :> ISQ::power;
		
		first start;
		then action computeEvaporation : CalculateEvaporationRate {
			in totalHeatLoad = appliedHeat;
			in latentHeatVaporization = cryogenProperties.latentHeat;
			in liquidDensity = cryogenProperties.density;
			out evaporationRate;
		}
		then assign vaporProduced := computeEvaporation.evaporationRate;
		then assign coolingProvided := appliedHeat;
		then done;
	}
	
	action def MaintainVacuumInsulation {
		in attribute currentVacuum : VacuumPressure;
		in attribute targetVacuum : VacuumPressure;
		in attribute maxVacuum : VacuumPressure;
		out attribute pumpStatus : Boolean;
		
		first start;
		then merge checkVacuum;
		then action monitorVacuum : MonitorVacuumQuality {
			in currentVacuum = MaintainVacuumInsulation::currentVacuum;
			in targetVacuum = MaintainVacuumInsulation::targetVacuum;
			in maximumVacuum = maxVacuum;
			out vacuumOK;
			out pumpRequired;
		}
		then decide;
			if monitorVacuum.pumpRequired then activatePump;
			if not monitorVacuum.pumpRequired then deactivatePump;
		action activatePump : ControlVacuumPump {
			in vacuumPressure = currentVacuum;
			in targetPressure = targetVacuum;
			out activatePump;
		}
		then assign pumpStatus := true;
		then checkVacuum;
		action deactivatePump {
			then assign pumpStatus := false;
		}
		then checkVacuum;
	}
	
	action def ProvideRegulatedVapor {
		in attribute heatLoad :> ISQ::heatFlowRate;
		in attribute cryogenSupply : CryogenicLiquid;
		in attribute vacuumQuality : VacuumPressure;
		in attribute targetOutputPressure :> ISQ::pressure;
		out attribute vaporOutput : EvaporationRate;
		out attribute outputPressure :> ISQ::pressure;
		
		first start;
		then action calculateHeatLeak : CalculateHeatIntrusion {
			in vacuumConductivity;
			in temperatureDelta;
			in surfaceArea;
			in gapWidth;
			out heatLeak;
		}
		then action evaporate : EvaporateCryogen {
			in appliedHeat = heatLoad + calculateHeatLeak.heatLeak;
			in cryogenProperties = cryogenSupply;
			in vesselLevel;
			out vaporProduced;
			out coolingProvided;
		}
		then action regulatePressure : RegulateOutputPressure {
			in currentPressure;
			in targetPressure = targetOutputPressure;
			in tolerance;
			out valveAdjustment;
		}
		then assign vaporOutput := evaporate.vaporProduced;
		then assign outputPressure := targetOutputPressure;
		then done;
	}
	
	part def VacuumInsulatedEvaporator;
	
	part vacuumInsulatedEvaporator : VacuumInsulatedEvaporator {
		doc /*
		A vacuum insulated evaporator system designed to store cryogenic liquids
		at extremely low temperatures and convert them to regulated vapor on demand.
		The system minimizes heat intrusion through high-performance vacuum insulation,
		enabling efficient long-term storage and controlled evaporation for applications
		requiring continuous supply of cryogenic gases such as liquid nitrogen, oxygen,
		or argon. The primary function is to maintain cryogenic liquid storage while
		providing regulated gaseous output with minimal boil-off losses.
		*/
		
		attribute nominalCapacity :> ISQ::volume;
		attribute operatingTemperature :> ISQ::thermodynamicTemperature;
		attribute ambientTemperature :> ISQ::thermodynamicTemperature;
		attribute targetVacuumLevel : VacuumPressure;
		attribute outputPressureSetpoint :> ISQ::pressure;
		attribute maxEvaporationRate : EvaporationRate;
		
		part innerVessel : InnerVessel {
			attribute storageCapacity = 500.0 [SI::L];
			attribute wallTemperature = 77.3 [SI::K];
			attribute liquidLevel = 0.75 [SI::m];
			attribute operatingPressure = 1.5e5 [SI::Pa];
		}
		
		part outerShell : OuterShell {
			attribute ambientTemperature = 293.15 [SI::K];
			attribute shellThickness = 0.008 [SI::m];
			attribute surfaceArea = 4.5 [SI::'m^2'];
		}
		
		part vacuumJacket : VacuumJacket {
			attribute vacuumGapWidth = 0.025 [SI::m];
			attribute vacuumLevel = 5.0e-6 [SI::Pa];
			attribute effectiveConductivity = 5.0e-5;
			attribute insulationEfficiency = 0.998;
		}
		
		part vacuumPump : VacuumPumpSystem {
			attribute pumpingSpeed = 75.0;
			attribute ultimatePressure = 1.0e-6 [SI::Pa];
			attribute currentPressure = vacuumJacket.vacuumLevel;
			attribute pumpActive = false;
		}
		
		part evaporatorCoil : EvaporatorCoil {
			attribute heatTransferArea = 1.2 [SI::'m^2'];
			attribute heatTransferCoefficient = 500.0;
			attribute evaporationCapacity = 25.0;
		}
		
		part pressureRegulator : PressureRegulationValve {
			attribute setPointPressure = 2.0e5 [SI::Pa];
			attribute flowCapacity = 30.0;
			attribute valvePosition = 0.5;
		}
		
		part safetyValve : SafetyReliefValve {
			attribute reliefPressure = 2.5e5 [SI::Pa];
			attribute reliefCapacity = 50.0;
			attribute valveState = false;
		}
		
		part levelSensor : LevelSensor {
			attribute measuredLevel = innerVessel.liquidLevel;
			attribute sensorAccuracy = 0.005 [SI::m];
			attribute lowLevelAlarm = false;
		}
		
		part vesselPressureSensor : PressureSensor {
			attribute measuredPressure = innerVessel.operatingPressure;
			attribute sensorAccuracy = 500.0 [SI::Pa];
		}
		
		part vesselTemperatureSensor : TemperatureSensor {
			attribute measuredTemperature = innerVessel.wallTemperature;
			attribute sensorAccuracy = 0.2 [SI::K];
		}
		
		part vacuumGauge : VacuumGauge {
			attribute measuredVacuum = vacuumJacket.vacuumLevel;
			attribute gaugeAccuracy = 1.0e-7 [SI::Pa];
		}
		
		connection vacuumMaintenance connect 
			vacuumJacket.vacuumPort to vacuumPump;
		
		connection thermalLoad connect 
			innerVessel.thermalInterface to vacuumJacket.vacuumPort;
		
		connection liquidSupply connect 
			innerVessel.liquidInlet to evaporatorCoil;
		
		connection vaporDelivery connect 
			evaporatorCoil to innerVessel.vaporOutlet;
		
		connection pressureControl connect 
			innerVessel.vaporOutlet to pressureRegulator;
		
		connection safetyProtection connect 
			innerVessel.vaporOutlet to safetyValve;
		
		perform action provideVapor : ProvideRegulatedVapor {
			in heatLoad;
			in cryogenSupply;
			in vacuumQuality = vacuumJacket.vacuumLevel;
			in targetOutputPressure = pressureRegulator.setPointPressure;
			out vaporOutput;
			out outputPressure;
		}
		
		perform action maintainVacuum : MaintainVacuumInsulation {
			in currentVacuum = vacuumGauge.measuredVacuum;
			in targetVacuum = targetVacuumLevel;
			in maxVacuum = 1.0e-4 [SI::Pa];
			out pumpStatus;
		}
		
		perform action manageLiquid : ManageCryogenSupply {
			in liquidLevel = levelSensor.measuredLevel;
			in minLevel = 0.15 [SI::m];
			in maxLevel = 0.95 [SI::m];
			out refillCommand;
			out shutoffCommand;
		}
	}
	
	requirement def StorageRequirement {
		doc /*
		The vacuum insulated evaporator shall maintain cryogenic liquid storage
		with minimal boil-off losses through effective vacuum insulation.
		*/
		
		require constraint vacuumQualityConstraint {
			vacuumInsulatedEvaporator.vacuumJacket.vacuumLevel <= 1.0e-4 [SI::Pa]
		}
		
		require constraint temperatureStabilityConstraint {
			vacuumInsulatedEvaporator.innerVessel.wallTemperature <= 85.0 [SI::K]
		}
		
		require constraint heatLeakConstraint {
			vacuumInsulatedEvaporator.vacuumJacket.effectiveConductivity <= 1.0e-4
		}
	}
	
	requirement def VaporizationRequirement {
		doc /*
		The evaporator shall convert stored cryogenic liquid to regulated vapor
		at specified pressure and flow rate on demand.
		*/
		
		require constraint evaporationCapacityConstraint {
			vacuumInsulatedEvaporator.evaporatorCoil.evaporationCapacity >= 20.0
		}
		
		require constraint pressureRegulationConstraint {
			vacuumInsulatedEvaporator.pressureRegulator.setPointPressure >= 1.0e5 [SI::Pa] and
			vacuumInsulatedEvaporator.pressureRegulator.setPointPressure <= 3.0e5 [SI::Pa]
		}
	}
	
	requirement def SafetyRequirement {
		doc /*
		The evaporator system shall operate safely with proper overpressure protection,
		level monitoring, and vacuum integrity maintenance.
		*/
		
		require constraint overpressureProtectionConstraint {
			vacuumInsulatedEvaporator.safetyValve.reliefPressure <= 3.0e5 [SI::Pa]
		}
		
		require constraint levelMonitoringConstraint {
			vacuumInsulatedEvaporator.levelSensor.sensorAccuracy <= 0.01 [SI::m]
		}
		
		require constraint vacuumMonitoringConstraint {
			vacuumInsulatedEvaporator.vacuumGauge.gaugeAccuracy <= 1.0e-6 [SI::Pa]
		}
	}
	
	requirement def EfficiencyRequirement {
		doc /*
		The system shall maintain high thermal efficiency through effective
		vacuum insulation and minimal parasitic heat loads.
		*/
		
		require constraint insulationEfficiencyConstraint {
			vacuumInsulatedEvaporator.vacuumJacket.insulationEfficiency >= 0.995
		}
	}
	
	requirement systemRequirements {
		subject vacuumInsulatedEvaporator;
		
		doc /*
		The vacuum insulated evaporator system shall provide reliable long-term
		storage of cryogenic liquids with minimal losses while delivering regulated
		vapor output on demand. The system maintains thermal efficiency through
		high-performance vacuum insulation and operates safely under all conditions.
		*/
		
		require requirement storageReq : StorageRequirement;
		require requirement vaporizationReq : VaporizationRequirement;
		require requirement safetyReq : SafetyRequirement;
		require requirement efficiencyReq : EfficiencyRequirement;
	}
}
