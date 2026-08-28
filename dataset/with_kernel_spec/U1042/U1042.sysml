package EnergyManagementSystem {
	private import ScalarValues::*;

	attribute def PowerValue :> Real;
	attribute def EnergyValue :> Real;
	attribute def VoltageValue :> Real;
	attribute def CurrentValue :> Real;
	attribute def TimeValue :> Real;
	attribute def PercentageValue :> Real;
	attribute def StateOfChargeValue :> PercentageValue;
	attribute def CostValue :> Real;

	item def Electricity;
	item def SolarPower :> Electricity;
	item def WindPower :> Electricity;
	item def GridPower :> Electricity;
	item def BatteryPower :> Electricity;

	enum def OperationalMode {
		peak;
		normal;
		economy;
		standby;
	}

	enum def LoadPriority {
		critical;
		deferrable;
	}

	attribute def GenerationData {
		attribute solarOutput : PowerValue;
		attribute windOutput : PowerValue;
		attribute totalRenewable : PowerValue;
	}

	attribute def StorageData {
		attribute stateOfCharge : StateOfChargeValue;
		attribute capacity : EnergyValue;
		attribute chargeRate : PowerValue;
		attribute dischargeRate : PowerValue;
	}

	attribute def LoadData {
		attribute criticalLoad : PowerValue;
		attribute deferrableLoad : PowerValue;
		attribute totalLoad : PowerValue;
	}

	attribute def GridData {
		attribute gridPrice : CostValue;
		attribute gridAvailable : Boolean;
		attribute exportAllowed : Boolean;
		attribute importPower : PowerValue;
		attribute exportPower : PowerValue;
	}

	attribute def SystemData {
		attribute generation : GenerationData;
		attribute storage : StorageData;
		attribute load : LoadData;
		attribute grid : GridData;
	}

	attribute def OptimizationCommand {
		attribute solarAllocation : PowerValue;
		attribute windAllocation : PowerValue;
		attribute batteryAllocation : PowerValue;
		attribute gridAllocation : PowerValue;
		attribute chargeBattery : Boolean;
		attribute exportToGrid : Boolean;
		attribute shedDeferrable : Boolean;
		attribute mode : OperationalMode;
	}

	attribute def EnterStandbyMode;
	attribute def EnterEconomyMode;
	attribute def EnterNormalMode;
	attribute def EnterPeakMode;
	attribute def StartCharging;
	attribute def StopCharging;
	attribute def StartDischarging;
	attribute def StopDischarging;
	attribute def ShedDeferrableLoads;
	attribute def RestoreDeferrableLoads;

	port def PowerPort {
		attribute power : PowerValue;
		inout item electricity : Electricity;
	}

	port def DataPort {
		inout attribute data : SystemData;
	}

	port def CommandPort {
		inout attribute command : OptimizationCommand;
	}

	action def MonitorPowerFlows {
		out generationData : GenerationData;
		out storageData : StorageData;
		out loadData : LoadData;
		out gridData : GridData;
	}

	action def DetermineMode {
		in totalLoad : PowerValue;
		in totalGeneration : PowerValue;
		in batterySOC : StateOfChargeValue;
		out mode : OperationalMode;
	}

	action def AllocatePower {
		in generationData : GenerationData;
		in storageData : StorageData;
		in loadData : LoadData;
		in gridData : GridData;
		in mode : OperationalMode;
		out command : OptimizationCommand;
	}

	action def DistributePower {
		in command : OptimizationCommand;
		out loadPower : PowerValue;
	}

	action def SystemOptimization {
		first start;
		then action monitor : MonitorPowerFlows;
		then action determineMode : DetermineMode {
			in totalLoad = monitor.loadData.totalLoad;
			in totalGeneration = monitor.generationData.totalRenewable;
			in batterySOC = monitor.storageData.stateOfCharge;
		}
		then action allocatePower : AllocatePower {
			in generationData = monitor.generationData;
			in storageData = monitor.storageData;
			in loadData = monitor.loadData;
			in gridData = monitor.gridData;
			in mode = determineMode.mode;
		}
		then action distributePower : DistributePower {
			in command = allocatePower.command;
		}
		then done;
	}

	part def SolarArray {
		attribute maxOutput : PowerValue = 10000;
		attribute currentOutput : PowerValue;
		attribute panelCount : Integer;
		attribute efficiency : PercentageValue;
		port powerOut : PowerPort;
		port dataOut : DataPort;
		port cmdIn : CommandPort;
		perform action generatePower {
			out generatedPower : PowerValue;
		}
	}

	part def WindTurbine {
		attribute maxOutput : PowerValue = 15000;
		attribute currentOutput : PowerValue;
		attribute rotorDiameter : Real;
		attribute cutInSpeed : Real;
		attribute cutOutSpeed : Real;
		port powerOut : PowerPort;
		port dataOut : DataPort;
		port cmdIn : CommandPort;
		perform action generatePower {
			out generatedPower : PowerValue;
		}
	}

	part def GridConnection {
		attribute maxImportPower : PowerValue = 50000;
		attribute maxExportPower : PowerValue = 30000;
		attribute currentPrice : CostValue;
		attribute isAvailable : Boolean;
		attribute exportEnabled : Boolean;
		port gridPort : PowerPort;
		port dataOut : DataPort;
		port cmdIn : CommandPort;
		perform action manageGridFlow {
			in importPower : PowerValue;
			in exportPower : PowerValue;
			out actualFlow : PowerValue;
		}
	}

	part def BatteryStorage {
		attribute capacity : EnergyValue = 50000;
		attribute stateOfCharge : StateOfChargeValue;
		attribute maxChargeRate : PowerValue = 20000;
		attribute maxDischargeRate : PowerValue = 20000;
		attribute cycleCount : Integer;
		attribute healthPercentage : PercentageValue;
		port powerPort : PowerPort;
		port dataOut : DataPort;
		port cmdIn : CommandPort;
		perform action charge {
			in chargePower : PowerValue;
			out newSOC : StateOfChargeValue;
		}
		perform action discharge {
			in dischargePower : PowerValue;
			out newSOC : StateOfChargeValue;
		}
		exhibit state batteryStates {
			entry; then idle;
			state idle;
			transition idle_to_charging
				first idle
				accept StartCharging
				then charging;
			state charging {
				do charge;
			}
			transition charging_to_idle
				first charging
				accept StopCharging
				then idle;
			transition idle_to_discharging
				first idle
				accept StartDischarging
				then discharging;
			state discharging {
				do discharge;
			}
			transition discharging_to_idle
				first discharging
				accept StopDischarging
				then idle;
		}
	}

	part def LoadController {
		attribute criticalLoadDemand : PowerValue;
		attribute deferrableLoadDemand : PowerValue;
		attribute totalDemand : PowerValue;
		attribute availablePower : PowerValue;
		attribute shedActive : Boolean;
		port powerIn : PowerPort;
		port dataOut : DataPort;
		port cmdIn : CommandPort;
		perform action manageLoads {
			in availablePower : PowerValue;
			out criticalPower : PowerValue;
			out deferrablePower : PowerValue;
			out shedStatus : Boolean;
		}
		exhibit state loadStates {
			entry; then fullyPowered;
			state fullyPowered {
				constraint { totalDemand <= availablePower }
			}
			transition fully_to_shedding
				first fullyPowered
				accept ShedDeferrableLoads
				then loadShedding;
			state loadShedding {
				do manageLoads;
				constraint { criticalLoadDemand <= availablePower }
			}
			transition shedding_to_fully
				first loadShedding
				accept RestoreDeferrableLoads
				then fullyPowered;
		}
	}

	part def PowerDistributionUnit {
		attribute totalInputPower : PowerValue;
		attribute totalOutputPower : PowerValue;
		attribute conversionEfficiency : PercentageValue;
		port solarInput : PowerPort;
		port windInput : PowerPort;
		port batteryPort : PowerPort;
		port gridPort : PowerPort;
		port loadOutput : PowerPort;
		perform action distributePower {
			in solarPower : PowerValue;
			in windPower : PowerValue;
			in batteryPower : PowerValue;
			in gridPower : PowerValue;
			out loadPower : PowerValue;
		}
	}

	part def EnergyMonitor {
		attribute solarGeneration : PowerValue;
		attribute windGeneration : PowerValue;
		attribute batteryFlow : PowerValue;
		attribute gridFlow : PowerValue;
		attribute totalConsumption : PowerValue;
		attribute totalGeneration : PowerValue;
		attribute measurementInterval : TimeValue;
		port solarDataIn : DataPort;
		port windDataIn : DataPort;
		port batteryDataIn : DataPort;
		port gridDataIn : DataPort;
		port loadDataIn : DataPort;
		port monitorDataOut : DataPort;
		perform action monitorPowerFlows {
			in solar : PowerValue;
			in wind : PowerValue;
			in battery : PowerValue;
			in grid : PowerValue;
			in load : PowerValue;
			out generationData : GenerationData;
			out storageData : StorageData;
			out loadData : LoadData;
			out gridData : GridData;
		}
	}

	part def EnergyOptimizer {
		attribute currentMode : OperationalMode;
		attribute optimizationInterval : TimeValue;
		attribute renewablePriority : Integer = 1;
		attribute batteryPriority : Integer = 2;
		attribute gridPriority : Integer = 3;
		attribute peakThreshold : PowerValue = 20000;
		attribute normalThreshold : PowerValue = 10000;
		attribute economyThreshold : PowerValue = 3000;
		port monitorDataIn : DataPort;
		port solarCmdOut : CommandPort;
		port windCmdOut : CommandPort;
		port batteryCmdOut : CommandPort;
		port gridCmdOut : CommandPort;
		port loadCmdOut : CommandPort;
		perform action optimize {
			in generationData : GenerationData;
			in storageData : StorageData;
			in loadData : LoadData;
			in gridData : GridData;
			out command : OptimizationCommand;
		}
		exhibit state optimizerStates {
			entry; then standbyMode;
			state standbyMode {
				constraint { currentMode == OperationalMode::standby }
			}
			transition standby_to_economy
				first standbyMode
				accept EnterEconomyMode
				then economyMode;
			transition standby_to_normal
				first standbyMode
				accept EnterNormalMode
				then normalMode;
			transition standby_to_peak
				first standbyMode
				accept EnterPeakMode
				then peakMode;
			state economyMode {
				do optimize;
				constraint { currentMode == OperationalMode::economy }
			}
			transition economy_to_normal
				first economyMode
				accept EnterNormalMode
				then normalMode;
			transition economy_to_peak
				first economyMode
				accept EnterPeakMode
				then peakMode;
			transition economy_to_standby
				first economyMode
				accept EnterStandbyMode
				then standbyMode;
			state normalMode {
				do optimize;
				constraint { currentMode == OperationalMode::normal }
			}
			transition normal_to_peak
				first normalMode
				accept EnterPeakMode
				then peakMode;
			transition normal_to_economy
				first normalMode
				accept EnterEconomyMode
				then economyMode;
			transition normal_to_standby
				first normalMode
				accept EnterStandbyMode
				then standbyMode;
			state peakMode {
				do optimize;
				constraint { currentMode == OperationalMode::peak }
			}
			transition peak_to_normal
				first peakMode
				accept EnterNormalMode
				then normalMode;
			transition peak_to_economy
				first peakMode
				accept EnterEconomyMode
				then economyMode;
			transition peak_to_standby
				first peakMode
				accept EnterStandbyMode
				then standbyMode;
		}
	}

	part def EnergyManagementSystem {
		attribute systemRating : PowerValue;
		attribute systemAvailability : PercentageValue;
		part solarArray : SolarArray;
		part windTurbine : WindTurbine;
		part gridConnection : GridConnection;
		part batteryStorage : BatteryStorage;
		part loadController : LoadController;
		part pdu : PowerDistributionUnit;
		part energyMonitor : EnergyMonitor;
		part energyOptimizer : EnergyOptimizer;

		connect solarArray.powerOut to pdu.solarInput;
		connect windTurbine.powerOut to pdu.windInput;
		connect batteryStorage.powerPort to pdu.batteryPort;
		connect gridConnection.gridPort to pdu.gridPort;
		connect pdu.loadOutput to loadController.powerIn;

		connect solarArray.dataOut to energyMonitor.solarDataIn;
		connect windTurbine.dataOut to energyMonitor.windDataIn;
		connect batteryStorage.dataOut to energyMonitor.batteryDataIn;
		connect gridConnection.dataOut to energyMonitor.gridDataIn;
		connect loadController.dataOut to energyMonitor.loadDataIn;

		connect energyMonitor.monitorDataOut to energyOptimizer.monitorDataIn;

		connect energyOptimizer.solarCmdOut to solarArray.cmdIn;
		connect energyOptimizer.windCmdOut to windTurbine.cmdIn;
		connect energyOptimizer.batteryCmdOut to batteryStorage.cmdIn;
		connect energyOptimizer.gridCmdOut to gridConnection.cmdIn;
		connect energyOptimizer.loadCmdOut to loadController.cmdIn;

		perform action systemOptimization : SystemOptimization;
	}

	part ems : EnergyManagementSystem;

	requirement def ReliabilityReqDef {
		doc /* The system shall ensure continuous power to critical loads with at least 99.9 percent uptime. */
		attribute uptime : PercentageValue;
		attribute minUptime : PercentageValue = 99.9;
		require constraint { uptime >= minUptime }
	}

	requirement def EfficiencyReqDef {
		doc /* The system shall maximize renewable energy utilization, prioritizing renewables over grid power. */
		attribute renewableFraction : PercentageValue;
		attribute minRenewableFraction : PercentageValue = 70;
		require constraint { renewableFraction >= minRenewableFraction }
	}

	requirement def CostOptimizationReqDef {
		doc /* The system shall minimize energy procurement costs by optimizing source allocation. */
		attribute actualCost : CostValue;
		attribute maxCost : CostValue;
		require constraint { actualCost <= maxCost }
	}

	requirement def BatteryProtectionReqDef {
		doc /* The system shall prevent battery overcharge and deep discharge to preserve battery health. */
		attribute minSOC : StateOfChargeValue = 20;
		attribute maxSOC : StateOfChargeValue = 100;
		attribute currentSOC : StateOfChargeValue;
		require constraint { currentSOC >= minSOC and currentSOC <= maxSOC }
	}

	requirement def LoadSheddingReqDef {
		doc /* The system shall shed deferrable loads before interrupting critical loads. */
		attribute criticalLoadStatus : Boolean;
		require constraint { criticalLoadStatus == true }
	}

	requirement def GridExportReqDef {
		doc /* The system shall export surplus renewable energy to the grid when export is allowed and economical. */
		attribute surplusPower : PowerValue;
		attribute exportThreshold : PowerValue;
		attribute exportAllowed : Boolean;
		require constraint { surplusPower >= exportThreshold and exportAllowed == true }
	}

	requirement def ResponseTimeReqDef {
		doc /* The energy optimizer shall respond to load changes within 2 seconds. */
		attribute responseTime : TimeValue;
		attribute maxResponseTime : TimeValue = 2;
		require constraint { responseTime <= maxResponseTime }
	}

	requirement def ModeTransitionReqDef {
		doc /* The system shall transition between operational modes based on load thresholds. */
		attribute peakThreshold : PowerValue = 20000;
		attribute normalThreshold : PowerValue = 10000;
		attribute economyThreshold : PowerValue = 3000;
		attribute currentLoad : PowerValue;
		attribute currentMode : OperationalMode;
		require constraint {
			(currentLoad >= peakThreshold and currentMode == OperationalMode::peak) or
			(currentLoad >= normalThreshold and currentLoad < peakThreshold and currentMode == OperationalMode::normal) or
			(currentLoad >= economyThreshold and currentLoad < normalThreshold and currentMode == OperationalMode::economy) or
			(currentLoad < economyThreshold and currentMode == OperationalMode::standby)
		}
	}

	requirement def EmissionReductionReqDef {
		doc /* The system shall reduce grid-based emissions by maximizing renewable and storage usage. */
		attribute gridImportReduction : PercentageValue;
		attribute minReduction : PercentageValue = 50;
		require constraint { gridImportReduction >= minReduction }
	}

	requirement def SourcePriorityReqDef {
		doc /* Power allocation shall follow the priority: renewables first, then battery, then grid. */
		attribute renewableAllocated : PowerValue;
		attribute batteryAllocated : PowerValue;
		attribute gridAllocated : PowerValue;
		attribute totalLoad : PowerValue;
		require constraint {
			renewableAllocated + batteryAllocated + gridAllocated >= totalLoad
		}
	}

	requirement energySystemRequirements {
		requirement reliabilityReq : ReliabilityReqDef;
		requirement efficiencyReq : EfficiencyReqDef;
		requirement costOptReq : CostOptimizationReqDef;
		requirement batteryProtReq : BatteryProtectionReqDef;
		requirement loadShedReq : LoadSheddingReqDef;
		requirement gridExportReq : GridExportReqDef;
		requirement responseTimeReq : ResponseTimeReqDef;
		requirement modeTransitionReq : ModeTransitionReqDef;
		requirement emissionReductionReq : EmissionReductionReqDef;
		requirement sourcePriorityReq : SourcePriorityReqDef;
	}
}
