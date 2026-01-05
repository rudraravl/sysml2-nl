package 'Urine Collection Device System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceStatus {
		attribute isCollecting : Boolean;
		attribute isSealed : Boolean;
		attribute currentVolume : ISQ::VolumeValue;
		attribute isFull : Boolean;
	}
	
	attribute def SensorData {
		attribute measuredVolume : ISQ::VolumeValue;
		attribute measuredPressure : ISQ::PressureValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def UrineFluid {
		attribute volume : ISQ::VolumeValue;
		attribute flowRate : Real;
	}
	
	port def FluidInputPort {
		in item urineFlow : UrineFluid;
	}
	
	port def FluidStoragePort {
		out attribute storedVolume : ISQ::VolumeValue;
		out attribute storagePressure : ISQ::PressureValue;
	}
	
	port def SensorDataPort {
		out attribute sensorReading : SensorData;
	}
	
	port def ControlSignalPort {
		in attribute sealCommand : Boolean;
		out attribute deviceStatus : DeviceStatus;
	}
	
	part def CollectionReservoir {
		attribute maxCapacity : ISQ::VolumeValue;
		attribute currentVolume : ISQ::VolumeValue;
		attribute material : String;
		
		port fluidInput : FluidInputPort;
		port storageStatus : FluidStoragePort;
	}
	
	part def VolumeMonitor {
		attribute measurementAccuracy : Real;
		attribute calibrationDate : ISQ::TimeValue;
		
		port dataOutput : SensorDataPort;
	}
	
	part def PressureMonitor {
		attribute measurementRange : ISQ::PressureValue;
		attribute alarmThreshold : ISQ::PressureValue;
		
		port dataOutput : SensorDataPort;
	}
	
	part def SealingAssembly {
		attribute isEngaged : Boolean;
		attribute sealStrength : Real;
		
		port controlInterface : ControlSignalPort;
	}
	
	part def ControlModule {
		attribute operatingMode : String;
		
		port sensorInput : SensorDataPort;
		port controlOutput : ControlSignalPort;
	}
	
	part def OverflowProtection {
		attribute maxPressureLimit : ISQ::PressureValue;
		attribute isActive : Boolean;
		
		port pressureInput : SensorDataPort;
	}
	
	action def MonitorFluidLevel {
		in sensorData : SensorData;
		in maxCapacity : ISQ::VolumeValue;
		out currentLevel : ISQ::VolumeValue;
		out capacityReached : Boolean;
	}
	
	action def CheckPressureSafety {
		in pressureReading : ISQ::PressureValue;
		in safetyLimit : ISQ::PressureValue;
		out pressureNormal : Boolean;
	}
	
	action def ActivateSeal {
		in sealTrigger : Boolean;
		out sealEngaged : Boolean;
	}
	
	action def UpdateDeviceStatus {
		in volumeLevel : ISQ::VolumeValue;
		in sealState : Boolean;
		in fullIndicator : Boolean;
		out status : DeviceStatus;
	}
	
	action def HandleOverflow {
		in pressureLevel : ISQ::PressureValue;
		in threshold : ISQ::PressureValue;
		out protectionActive : Boolean;
	}
	
	attribute def BeginCollection;
	attribute def ManualSealRequest;
	attribute def RemoveDevice;
	attribute def ResetDevice;
	
	state def CollectionSystemStates {
		in deviceRef : UrineCollectionDevice;
		
		entry; then standby;
		
		state standby;
		
		transition standby_to_active
			first standby
			accept BeginCollection
			then active;
		
		state active;
		
		transition active_to_nearfull
			first active
			then nearfull;
		
		state nearfull;
		
		transition nearfull_to_full
			first nearfull
			then full;
		
		transition nearfull_to_sealing
			first nearfull
			accept ManualSealRequest
			then sealing;
		
		state full;
		
		transition full_to_sealing
			first full
			then sealing;
		
		state sealing;
		
		transition sealing_to_sealed
			first sealing
			then sealed;
		
		state sealed;
		
		transition sealed_to_removal
			first sealed
			accept RemoveDevice
			then removal;
		
		state removal;
		
		transition removal_to_standby
			first removal
			accept ResetDevice
			then standby;
	}
	
	action def CollectAndContainUrine {
		in maxStorageCapacity : ISQ::VolumeValue;
		in pressureSafetyLimit : ISQ::PressureValue;
		out finalDeviceStatus : DeviceStatus;
		
		first start;
		then merge continuousMonitoring;
		
		then action monitorVolume : MonitorFluidLevel {
			in sensorData : SensorData;
			in maxCapacity = maxStorageCapacity;
			out currentLevel : ISQ::VolumeValue;
			out capacityReached : Boolean;
		}
		
		then action checkPressure : CheckPressureSafety {
			in pressureReading : ISQ::PressureValue;
			in safetyLimit = pressureSafetyLimit;
			out pressureNormal : Boolean;
		}
		
		then decide;
			if checkPressure.pressureNormal then continueCollection;
			if monitorVolume.capacityReached then initiateSealing;
		
		action continueCollection;
		then continuousMonitoring;
		
		action initiateSealing : ActivateSeal {
			in sealTrigger = true;
			out sealEngaged : Boolean;
		}
		
		then action updateStatus : UpdateDeviceStatus {
			in volumeLevel = monitorVolume.currentLevel;
			in sealState = initiateSealing.sealEngaged;
			in fullIndicator = monitorVolume.capacityReached;
			out status : DeviceStatus;
		}
		
		then assign finalDeviceStatus := updateStatus.status;
		then done;
	}
	
	part def UrineCollectionDevice {
		attribute maxCapacity : ISQ::VolumeValue;
		attribute pressureLimit : ISQ::PressureValue;
		attribute status : DeviceStatus;
		
		part reservoir : CollectionReservoir;
		part volumeSensor : VolumeMonitor;
		part pressureSensor : PressureMonitor;
		part sealingUnit : SealingAssembly;
		part controller : ControlModule;
		part overflowProtector : OverflowProtection;
	}
	
	part system : UrineCollectionDevice {
		attribute :>> maxCapacity = 500.0[mL];
		attribute :>> pressureLimit = 100.0[kPa];
		
		part :>> reservoir {
			attribute :>> maxCapacity = system.maxCapacity;
			attribute :>> currentVolume = 0.0[mL];
			attribute :>> material = "Medical Grade Polymer";
		}
		
		part :>> volumeSensor {
			attribute :>> measurementAccuracy = 0.98;
		}
		
		part :>> pressureSensor {
			attribute :>> measurementRange = system.pressureLimit;
			attribute :>> alarmThreshold = 90.0[kPa];
		}
		
		part :>> sealingUnit {
			attribute :>> isEngaged = false;
			attribute :>> sealStrength = 0.95;
		}
		
		part :>> controller {
			attribute :>> operatingMode = "Automatic";
		}
		
		part :>> overflowProtector {
			attribute :>> maxPressureLimit = system.pressureLimit;
			attribute :>> isActive = false;
		}
		
		connection volumeMonitoring connect 
			reservoir.storageStatus to volumeSensor.dataOutput;
		
		connection pressureMonitoring connect 
			reservoir.storageStatus to pressureSensor.dataOutput;
		
		connection volumeControl connect 
			volumeSensor.dataOutput to controller.sensorInput;
		
		connection pressureControl connect 
			pressureSensor.dataOutput to controller.sensorInput;
		
		connection sealingControl connect 
			controller.controlOutput to sealingUnit.controlInterface;
		
		connection overflowMonitoring connect 
			pressureSensor.dataOutput to overflowProtector.pressureInput;
		
		perform action collectUrine : CollectAndContainUrine {
			in maxStorageCapacity = system.maxCapacity;
			in pressureSafetyLimit = system.pressureLimit;
			out finalDeviceStatus : DeviceStatus;
		}
		
		exhibit state operationalStates : CollectionSystemStates {
			in deviceRef = system;
		}
	}
	
	requirement def ContainmentRequirement {
		doc /* The device shall safely contain collected urine without leakage under normal operating conditions. */
		
		subject device : UrineCollectionDevice;
		
		require constraint sealIntegrity {
			device.sealingUnit.sealStrength >= 0.90
		}
	}
	
	requirement def CapacityMonitoringRequirement {
		doc /* The device shall continuously monitor fluid volume and prevent overflow conditions. */
		
		subject device : UrineCollectionDevice;
	}
	
	requirement def PressureSafetyRequirement {
		doc /* The device shall maintain internal pressure within safe limits to prevent structural failure. */
		
		subject device : UrineCollectionDevice;
	}
	
	requirement def HygienicSealingRequirement {
		doc /* The device shall provide a hygienic seal upon completion of collection to prevent contamination. */
		
		subject device : UrineCollectionDevice;
	}
	
	requirement <'UCR-001'> primaryFunctionRequirement {
		doc /* The urine collection device shall safely collect, monitor, contain, and seal biological fluid 
		       for hygienic handling and disposal through automated volume monitoring, pressure control, 
		       and sealing mechanisms. */
		
		subject device : UrineCollectionDevice;
		
		require ContainmentRequirement;
		require CapacityMonitoringRequirement;
		require PressureSafetyRequirement;
		require HygienicSealingRequirement;
	}
}
