package SurgiboxSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PressureValue :> ISQ::PressureValue;
	attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
	attribute def PowerValue :> ISQ::PowerValue;
	attribute def ParticleConcentrationValue :> Real;
	attribute def EfficiencyValue :> Real;
	
	item def FilteredAir {
		attribute particleConcentration : ParticleConcentrationValue;
		attribute flowRate : FlowRateValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def AirFlowPort {
		in item airIn : FilteredAir;
		out item airOut : FilteredAir;
	}
	
	port def PowerSupplyPort {
		in item power : ElectricalPower;
	}
	
	port def PressureSensingPort {
		out attribute pressureReading : PressureValue;
	}
	
	part def HEPAFilterUnit {
		attribute filterEfficiency : EfficiencyValue = 0.9997;
		port airIntake : AirFlowPort;
		port airDischarge : AirFlowPort;
		
		action filterAirstream {
			in rawAir : FilteredAir;
			out cleanAir : FilteredAir;
		}
	}
	
	part def FanAssembly {
		attribute nominalFlowRate : FlowRateValue;
		attribute operatingSpeed : Real;
		port powerInput : PowerSupplyPort;
		port airInput : AirFlowPort;
		port airOutput : AirFlowPort;
		
		action circulateAir {
			in powerLevel : PowerValue;
			out airflow : FlowRateValue;
		}
	}
	
	part def PressureRegulationSystem {
		attribute targetPressure : PressureValue;
		port airInlet : AirFlowPort;
		port airOutlet : AirFlowPort;
		port pressureSensor : PressureSensingPort;
		
		action regulatePressure {
			in measuredPressure : PressureValue;
			in setpoint : PressureValue;
			out flowAdjustment : FlowRateValue;
		}
	}
	
	part def EnvironmentMonitor {
		attribute currentPressure : PressureValue;
		attribute currentParticleLevel : ParticleConcentrationValue;
		port sensing : PressureSensingPort;
		
		action measureConditions {
			out pressure : PressureValue;
			out particleCount : ParticleConcentrationValue;
		}
	}
	
	part def SystemController {
		attribute operationalState : String;
		port powerSupply : PowerSupplyPort;
		
		action manageOperation {
			in environmentData : PressureValue;
			out fanControl : PowerValue;
			out regulatorSetpoint : PressureValue;
		}
	}
	
	part def BatteryPack {
		attribute capacity : ISQ::EnergyValue;
		attribute remainingCharge : ISQ::EnergyValue;
		port powerOutput : PowerSupplyPort;
		
		action supplyPower {
			out deliveredPower : ElectricalPower;
		}
	}
	
	part def SterileWorkspace {
		attribute internalVolume : ISQ::VolumeValue;
		attribute pressureDifferential : PressureValue;
		port airSupply : AirFlowPort;
		port instrumentAccess[2];
		port patientInterface;
	}
	
	part def Surgibox {
		doc /* 
			A portable sterile field generation system that creates and maintains 
			a controlled positive-pressure environment using HEPA-filtered air circulation 
			to enable safe surgical procedures in resource-limited or field settings.
		*/
		
		part workspace : SterileWorkspace {
			attribute internalVolume = 0.6 [SI::m^3];
			attribute pressureDifferential = 5.0 [SI::Pa];
		}
		
		part hepaFilter : HEPAFilterUnit {
			attribute filterEfficiency = 0.99975;
		}
		
		part fan : FanAssembly {
			attribute nominalFlowRate = 180.0 [SI::L/SI::min];
			attribute operatingSpeed = 1.0;
		}
		
		part regulator : PressureRegulationSystem {
			attribute targetPressure = 5.0 [SI::Pa];
		}
		
		part monitor : EnvironmentMonitor;
		
		part controller : SystemController {
			attribute operationalState = "standby";
		}
		
		part battery : BatteryPack {
			attribute capacity = 500.0 [SI::W * SI::h];
			attribute remainingCharge = 500.0 [SI::W * SI::h];
		}
		
		connection airPath1 connect fan.airOutput to hepaFilter.airIntake;
		connection airPath2 connect hepaFilter.airDischarge to regulator.airInlet;
		connection airPath3 connect regulator.airOutlet to workspace.airSupply;
		
		connection powerLine1 connect battery.powerOutput to controller.powerSupply;
		connection powerLine2 connect battery.powerOutput to fan.powerInput;
		
		connection sensorLink connect monitor.sensing to regulator.pressureSensor;
	}
	
	action def SenseEnvironment {
		in workspaceState : PressureValue;
		out pressureMeasurement : PressureValue;
		out particleMeasurement : ParticleConcentrationValue;
	}
	
	action def ControlAirflow {
		in targetPressure : PressureValue;
		in actualPressure : PressureValue;
		out fanPowerSetting : PowerValue;
	}
	
	action def FilterAir {
		in ambientAir : FilteredAir;
		out sterileAir : FilteredAir;
	}
	
	action def MaintainSterileEnvironment {
		first start;
		then merge operationLoop;
		
		then action sense : SenseEnvironment {
			in workspaceState;
			out currentPressure : PressureValue;
			out currentParticles : ParticleConcentrationValue;
		}
		
		then decide;
			if sense.currentPressure < 4.5 then boostPressure;
			if sense.currentPressure >= 4.5 and sense.currentPressure <= 5.5 then holdSteady;
			if sense.currentPressure > 5.5 then reducePressure;
		
		action boostPressure : ControlAirflow {
			in targetPressure = 5.0 [SI::Pa];
			in actualPressure = sense.currentPressure;
			out fanPowerSetting;
		}
		then operationLoop;
		
		action holdSteady {
			doc /* Maintain current operational parameters */
		}
		then operationLoop;
		
		action reducePressure : ControlAirflow {
			in targetPressure = 5.0 [SI::Pa];
			in actualPressure = sense.currentPressure;
			out fanPowerSetting;
		}
		then operationLoop;
	}
	
	state def SurgiboxOperationalStates {
		entry; then poweredOff;
		
		state poweredOff;
		transition powerOn first poweredOff then initializing;
		
		state initializing;
		transition systemCheck first initializing then pressurizing;
		
		state pressurizing;
		transition pressureAchieved first pressurizing then sterileReady;
		
		state sterileReady;
		transition beginProcedure first sterileReady then activeOperation;
		
		state activeOperation;
		transition batteryDepleted first activeOperation then lowBattery;
		transition completeProcedure first activeOperation then shutdown;
		
		state lowBattery;
		transition emergencyStop first lowBattery then shutdown;
		
		state shutdown;
		transition powerOff first shutdown then poweredOff;
	}
	
	requirement def SterilityRequirement {
		doc /* The system shall maintain ISO Class 5 sterile conditions within the workspace. */
		require constraint particleLimit {
			doc /* Particle concentration shall not exceed 3520 particles/m³ at 0.5 micrometers. */
		}
	}
	
	requirement def PressureMaintenanceRequirement {
		doc /* The system shall maintain positive pressure differential relative to ambient. */
		require constraint pressureRange {
			doc /* Internal pressure shall be maintained between 4.5 and 5.5 Pa above ambient. */
		}
	}
	
	requirement def FiltrationPerformanceRequirement {
		doc /* The system shall employ HEPA filtration meeting medical standards. */
		require constraint hepaStandard {
			doc /* Filter efficiency shall be minimum 99.97% at 0.3 micrometers. */
		}
	}
	
	requirement def OperationalEnduranceRequirement {
		doc /* The system shall operate continuously on battery power for minimum duration. */
		require constraint batteryLife {
			doc /* System shall operate for at least 4 hours on full battery charge. */
		}
	}
	
	requirement <'SRG-SYS-001'> surgiboxSystemRequirements {
		doc /* 
			The Surgibox shall create and maintain a portable, sterile surgical environment 
			through controlled positive-pressure HEPA-filtered air circulation, enabling 
			safe surgical procedures in non-traditional clinical settings.
		*/
		
		subject system : Surgibox;
		
		require sterilityReq : SterilityRequirement;
		require pressureReq : PressureMaintenanceRequirement;
		require filtrationReq : FiltrationPerformanceRequirement;
		require enduranceReq : OperationalEnduranceRequirement;
	}
	
	part deployedSurgibox : Surgibox {
		perform action sterileOperation : MaintainSterileEnvironment;
		exhibit state operationalBehavior : SurgiboxOperationalStates;
	}
}
