package HighTemperatureSuperconductivitySystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CriticalTemperature :> ISQ::TemperatureValue;
	attribute def MagneticFluxDensity :> ISQ::MagneticFluxDensityValue;
	attribute def CurrentDensity :> ISQ::ElectricCurrentDensityValue;
	attribute def ElectricalResistance :> ISQ::ResistanceValue;
	attribute def CoolingPower :> ISQ::PowerValue;
	
	item def LiquidNitrogen;
	item def ElectricalCurrent;
	item def MagneticField;
	item def ThermalEnergy;
	
	port def CryogenicPort {
		attribute temperature : CriticalTemperature;
		in item coolantIn : LiquidNitrogen;
		out item coolantOut : LiquidNitrogen;
		attribute flowRate : ISQ::VolumeFlowRateValue;
	}
	
	port def PowerPort {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute resistance : ElectricalResistance;
		in item powerIn : ElectricalCurrent;
		out item powerOut : ElectricalCurrent;
	}
	
	port def MagneticPort {
		attribute fieldStrength : MagneticFluxDensity;
		out item field : MagneticField;
	}
	
	port def ThermalPort {
		attribute temperature : ISQ::TemperatureValue;
		in item heatIn : ThermalEnergy;
		out item heatOut : ThermalEnergy;
	}
	
	part def HTSCMaterial {
		attribute criticalTemperature : CriticalTemperature;
		attribute operatingTemperature : ISQ::TemperatureValue;
		attribute maxCurrentDensity : CurrentDensity;
		attribute zeroResistance : ElectricalResistance;
		attribute materialType : String;
	}
	
	part def CryogenicCoolingSystem {
		port coolingPort : CryogenicPort;
		port thermalPort : ThermalPort;
		attribute targetTemperature : CriticalTemperature;
		attribute coolingCapacity : CoolingPower;
		
		part liquidNitrogenReservoir {
			attribute capacity : ISQ::VolumeValue;
			attribute currentLevel : ISQ::VolumeValue;
			attribute refillThreshold : ISQ::VolumeValue;
		}
		
		part cryocooler {
			attribute coolingRate : CoolingPower;
			attribute efficiency : Real;
			attribute operatingPower : ISQ::PowerValue;
		}
		
		part temperatureSensor {
			attribute measuredTemperature : ISQ::TemperatureValue;
			attribute accuracy : ISQ::TemperatureValue;
			attribute sampleRate : ISQ::FrequencyValue;
		}
		
		part flowController {
			attribute setpointFlow : ISQ::VolumeFlowRateValue;
			attribute actualFlow : ISQ::VolumeFlowRateValue;
		}
	}
	
	part def SuperconductingCoil {
		port powerInput : PowerPort;
		port magneticOutput : MagneticPort;
		port thermalInterface : ThermalPort;
		
		attribute windingCount : Integer;
		attribute coilDiameter : ISQ::LengthValue;
		attribute wireLength : ISQ::LengthValue;
		attribute inductance : ISQ::InductanceValue;
		
		part htsMaterial : HTSCMaterial {
			attribute criticalTemperature := 92.0[SI::K];
			attribute materialType := "YBCO";
			attribute maxCurrentDensity := 1.0e8[SI::A/SI::m^2];
		}
	}
	
	part def PowerSupplySystem {
		port powerOutput : PowerPort;
		port gridInput : PowerPort;
		
		attribute outputVoltage : ISQ::VoltageValue;
		attribute outputCurrent : ISQ::ElectricCurrentValue;
		attribute maxPower : ISQ::PowerValue;
		attribute efficiency : Real;
		
		part rectifier {
			attribute conversionEfficiency : Real;
		}
		
		part currentRegulator {
			attribute setpointCurrent : ISQ::ElectricCurrentValue;
			attribute actualCurrent : ISQ::ElectricCurrentValue;
			attribute responseTime : ISQ::DurationValue;
		}
	}
	
	part def MagneticShieldingSystem {
		attribute shieldingEffectiveness : Real;
		attribute maxExternalField : MagneticFluxDensity;
		attribute shieldThickness : ISQ::LengthValue;
	}
	
	part def MonitoringAndControlSystem {
		attribute systemState : String;
		
		part temperatureMonitor {
			attribute criticalTempThreshold : CriticalTemperature;
			attribute warningTempThreshold : ISQ::TemperatureValue;
		}
		
		part currentMonitor {
			attribute maxCurrentThreshold : ISQ::ElectricCurrentValue;
			attribute quenchDetectionTime : ISQ::DurationValue;
		}
		
		part safetyInterlock {
			attribute emergencyShutdownEnabled : Boolean;
		}
	}
	
	action def PerformCooldown {
		in targetTemp : CriticalTemperature;
		in currentTemp : ISQ::TemperatureValue;
		out coolingPower : CoolingPower;
	}
	
	action def MaintainSuperconductivity {
		in operatingTemp : ISQ::TemperatureValue;
		in criticalTemp : CriticalTemperature;
		in appliedCurrent : ISQ::ElectricCurrentValue;
		out magneticField : MagneticFluxDensity;
	}
	
	action def HandleQuench {
		in excessEnergy : ISQ::EnergyValue;
		out dissipationRate : ISQ::PowerValue;
	}
	
	state def HTSCOperationalStates {
		entry; then initialization;
		
		state initialization;
		
		transition initialization to coolingDown
			when systemChecksPassed;
		
		state coolingDown {
			do action performCooldown : PerformCooldown;
		}
		
		transition coolingDown to superconducting
			when temperatureBelowCritical;
		
		state superconducting {
			do action maintainSuperconductivity : MaintainSuperconductivity;
		}
		
		transition superconducting to quench
			when temperatureExceedsCritical;
		
		transition superconducting to quench
			when currentExceedsLimit;
		
		state quench {
			do action handleQuench : HandleQuench;
		}
		
		transition quench to shutdown
			when quenchHandled;
		
		transition superconducting to shutdown
			when shutdownRequested;
		
		state shutdown;
		
		state systemChecksPassed;
		state temperatureBelowCritical;
		state temperatureExceedsCritical;
		state currentExceedsLimit;
		state quenchHandled;
		state shutdownRequested;
	}
	
	action def MonitorTemperature {
		in currentTemp : ISQ::TemperatureValue;
		in criticalTemp : CriticalTemperature;
		in safetyMargin : ISQ::TemperatureValue;
		out tempStatus : Boolean;
		out tempDelta : ISQ::TemperatureValue;
	}
	
	action def RegulateCurrentFlow {
		in requestedCurrent : ISQ::ElectricCurrentValue;
		in maxCurrentDensity : CurrentDensity;
		in coilCrossSection : ISQ::AreaValue;
		in operatingTemp : ISQ::TemperatureValue;
		out actualCurrent : ISQ::ElectricCurrentValue;
		out powerDissipation : ISQ::PowerValue;
	}
	
	action def GenerateMagneticField {
		in superconductingCurrent : ISQ::ElectricCurrentValue;
		in coilRadius : ISQ::LengthValue;
		in windingCount : Integer;
		in coilLength : ISQ::LengthValue;
		out fieldStrength : MagneticFluxDensity;
		out storedEnergy : ISQ::EnergyValue;
	}
	
	action def MaintainCryogenicConditions {
		first start;
		then merge monitorLoop;
		
		then action monitor : MonitorTemperature {
			in currentTemp;
			in criticalTemp;
			in safetyMargin := 5.0[SI::K];
			out tempStatus;
			out tempDelta;
		}
		
		then decide;
			if monitor.tempStatus == false then increaseCooling;
			if monitor.tempStatus == true then maintainCooling;
		
		action increaseCooling {
			in tempDelta : ISQ::TemperatureValue;
			in currentCoolingPower : CoolingPower;
			out adjustedCoolingPower : CoolingPower;
		}
		then monitorLoop;
		
		action maintainCooling {
			in steadyStatePower : CoolingPower;
			out actualPower : CoolingPower;
		}
		then monitorLoop;
	}
	
	action def OperateHTSCSystem {
		in targetFieldStrength : MagneticFluxDensity;
		in operatingCurrent : ISQ::ElectricCurrentValue;
		
		first start;
		
		then action initializeCooling : MaintainCryogenicConditions;
		
		then action regulateCurrent : RegulateCurrentFlow {
			in requestedCurrent := operatingCurrent;
			in maxCurrentDensity;
			in coilCrossSection;
			in operatingTemp;
			out actualCurrent;
			out powerDissipation;
		}
		
		then action generateField : GenerateMagneticField {
			in superconductingCurrent := regulateCurrent.actualCurrent;
			in coilRadius;
			in windingCount;
			in coilLength;
			out fieldStrength;
			out storedEnergy;
		}
		
		then done;
	}
	
	requirement def HTSCPerformanceRequirements {
		doc /* High-temperature superconducting system shall operate with zero electrical resistance 
		       when maintained below critical temperature to enable lossless power transmission. */
		
		require constraint operatingTemperatureConstraint {
			doc /* Operating temperature shall be maintained at least 5K below critical temperature. */
		}
		
		require constraint zeroResistanceConstraint {
			doc /* Electrical resistance shall be effectively zero in superconducting state. */
		}
		
		require constraint currentDensityConstraint {
			doc /* Current density shall not exceed 80% of material critical current density. */
		}
	}
	
	requirement def MagneticFieldRequirement {
		doc /* System shall generate stable high-strength magnetic field for energy storage and transmission. */
		
		require constraint fieldStrengthConstraint {
			doc /* Magnetic field strength shall exceed 5 Tesla for effective operation. */
		}
		
		require constraint fieldStabilityConstraint {
			doc /* Magnetic field variation shall remain within 0.1% over operating period. */
		}
		
		require constraint fieldHomogeneityConstraint {
			doc /* Field homogeneity shall be better than 1% over useful volume. */
		}
	}
	
	requirement def CryogenicSystemRequirement {
		doc /* Cryogenic cooling system shall maintain temperature below critical threshold continuously. */
		
		require constraint coolingCapacityConstraint {
			doc /* Cooling system capacity shall exceed thermal load by at least 20%. */
		}
		
		require constraint temperatureStabilityConstraint {
			doc /* Temperature fluctuations shall not exceed ±0.5K during operation. */
		}
		
		require constraint coolantSupplyConstraint {
			doc /* Coolant supply shall be sufficient for 24 hours continuous operation. */
		}
	}
	
	requirement def SafetyRequirement {
		doc /* System shall safely handle quench events and prevent damage to components. */
		
		require constraint quenchDetectionConstraint {
			doc /* Quench detection shall occur within 100 milliseconds of onset. */
		}
		
		require constraint energyDissipationConstraint {
			doc /* Stored magnetic energy shall be safely dissipated during quench. */
		}
		
		require constraint emergencyShutdownConstraint {
			doc /* Emergency shutdown shall complete within 5 seconds. */
		}
	}
	
	requirement <'HTSC-SYS-001'> systemLevelRequirement {
		doc /* High-temperature superconducting system shall provide lossless electrical power transmission 
		       and storage through generation of stable, high-strength magnetic fields at temperatures 
		       achievable with liquid nitrogen cooling (77K), enabling efficient energy distribution 
		       and magnetic levitation applications. */
		
		assume constraint materialAvailability {
			doc /* HTSC material (YBCO or BSCCO) with critical temperature above 77K is available. */
		}
		
		assume constraint cryogenAvailability {
			doc /* Liquid nitrogen supply is continuously available for cooling. */
		}
		
		require htscPerformance : HTSCPerformanceRequirements;
		require magneticField : MagneticFieldRequirement;
		require cryogenicSystem : CryogenicSystemRequirement;
		require safety : SafetyRequirement;
	}
	
	part htscSystem {
		doc /* Complete high-temperature superconductivity system for lossless power transmission,
		       energy storage, and high-field magnet applications. The system operates by maintaining
		       superconducting coils below their critical temperature using liquid nitrogen cooling,
		       enabling zero-resistance current flow and generation of strong magnetic fields without
		       energy dissipation. */
		
		attribute systemTargetField : MagneticFluxDensity := 8.0[SI::T];
		attribute systemOperatingCurrent : ISQ::ElectricCurrentValue := 500.0[SI::A];
		
		perform action operateSystem[*] ordered references OperateHTSCSystem;
		
		part coolingSystem : CryogenicCoolingSystem {
			attribute targetTemperature := 77.0[SI::K];
			attribute coolingCapacity := 2000.0[SI::W];
			perform operateSystem.initializeCooling;
		}
		
		part scCoil : SuperconductingCoil {
			attribute windingCount := 1000;
			attribute coilDiameter := 0.5[SI::m];
			attribute wireLength := 1570.8[SI::m];
			attribute inductance := 2.5[SI::H];
			perform operateSystem.regulateCurrent;
			perform operateSystem.generateField;
		}
		
		part powerSupply : PowerSupplySystem {
			attribute outputVoltage := 100.0[SI::V];
			attribute outputCurrent := 500.0[SI::A];
			attribute maxPower := 50000.0[SI::W];
			attribute efficiency := 0.95;
		}
		
		part shielding : MagneticShieldingSystem {
			attribute shieldingEffectiveness := 0.99;
			attribute maxExternalField := 0.1[SI::T];
			attribute shieldThickness := 0.05[SI::m];
		}
		
		part controlSystem : MonitoringAndControlSystem {
			attribute systemState := "Offline";
		}
		
		connect coolingSystem.coolingPort to scCoil.thermalInterface;
		connect powerSupply.powerOutput to scCoil.powerInput;
	}
}
