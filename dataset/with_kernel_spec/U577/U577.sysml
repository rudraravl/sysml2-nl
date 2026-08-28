package 'Village Infrastructure System' {
	private import ScalarValues::Real;
	private import ScalarValues::Integer;
	private import ScalarValues::Boolean;
	private import ScalarValues::String;

	item def PotableWater;
	item def Electricity;

	item def SensorData {
		attribute waterLevel : Real;
		attribute powerOutput : Real;
		attribute batteryCharge : Real;
		attribute generatorFuel : Real;
		attribute pumpOperational : Boolean;
		attribute generatorRunning : Boolean;
	}

	item def MaintenanceAlert {
		attribute severity : Integer;
		attribute description : String;
		attribute source : String;
	}

	port def WaterOutPort {
		out item water : PotableWater;
	}
	port def WaterInPort {
		in item water : PotableWater;
	}
	port def PowerOutPort {
		out item power : Electricity;
	}
	port def PowerInPort {
		in item power : Electricity;
	}
	port def SensorOutPort {
		out item data : SensorData;
	}
	port def SensorInPort {
		in item data : SensorData;
	}
	port def AlertOutPort {
		out item alert : MaintenanceAlert;
	}
	port def AlertInPort {
		in item alert : MaintenanceAlert;
	}

	action def PumpWater {
		in waterInput : PotableWater;
		out waterOutput : PotableWater;
	}
	action def GeneratePower {
		out powerGenerated : Electricity;
	}
	action def MonitorSystem {
		in sensorData : SensorData;
		out alertOutput : MaintenanceAlert;
	}
	action def PerformMaintenance {
		in alertInput : MaintenanceAlert;
		out success : Boolean;
	}

	part def Well {
		port waterOut : WaterOutPort;
		attribute rechargeRate : Real;
	}

	part def HandPump {
		port waterIn : WaterInPort;
		port waterOut : WaterOutPort;
		port telemetry : SensorOutPort;
		attribute operational : Boolean = true;
		perform action pumpWater : PumpWater {
			in waterInput = waterIn.water;
			out waterOutput = waterOut.water;
		}
	}

	part def StorageTank {
		port waterIn : WaterInPort;
		port waterOut : WaterOutPort;
		port telemetry : SensorOutPort;
		attribute capacity : Real = 50;
		attribute currentLevel : Real;
		item storedWater : PotableWater;
		flow waterIn.water to storedWater;
		flow storedWater to waterOut.water;
	}

	part def SolarPanel {
		port powerOut : PowerOutPort;
		port telemetry : SensorOutPort;
		attribute ratedPower : Real;
		perform action generatePower : GeneratePower {
			out powerGenerated = powerOut.power;
		}
	}

	part def BatteryBank {
		port powerIn : PowerInPort;
		port powerOut : PowerOutPort;
		port telemetry : SensorOutPort;
		attribute capacity : Real = 100000;
		attribute chargeLevel : Real;
		item storedEnergy : Electricity;
		flow powerIn.power to storedEnergy;
		flow storedEnergy to powerOut.power;
	}

	part def DieselGenerator {
		port powerOut : PowerOutPort;
		port telemetry : SensorOutPort;
		attribute fuelLevel : Real;
		attribute ratedPower : Real;
		attribute running : Boolean = false;
		perform action generatePower : GeneratePower {
			out powerGenerated = powerOut.power;
		}
	}

	part def WaterSupplySystem {
		port waterOut : WaterOutPort;
		part well : Well;
		part pump : HandPump;
		part tank : StorageTank;
		flow wellToPump of PotableWater from well.waterOut.water to pump.waterIn.water;
		flow pumpToTank of PotableWater from pump.waterOut.water to tank.waterIn.water;
		bind waterOut = tank.waterOut;
	}

	part def PowerGenerationSystem {
		port powerOut : PowerOutPort;
		part solar : SolarPanel;
		part battery : BatteryBank;
		part generator : DieselGenerator;
		flow solarToBattery of Electricity from solar.powerOut.power to battery.powerIn.power;
		flow generatorToBattery of Electricity from generator.powerOut.power to battery.powerIn.power;
		bind powerOut = battery.powerOut;
	}

	part def HealthClinic {
		port waterIn : WaterInPort;
		port powerIn : PowerInPort;
		part sanitationFacilities {
			port waterIn : WaterInPort;
		}
		part medicalEquipment {
			port powerIn : PowerInPort;
		}
		part lighting {
			port powerIn : PowerInPort;
		}
		flow clinicWater of PotableWater from waterIn.water to sanitationFacilities.waterIn.water;
		flow clinicMedicalPower of Electricity from powerIn.power to medicalEquipment.powerIn.power;
		flow clinicLightingPower of Electricity from powerIn.power to lighting.powerIn.power;
	}

	part def CommunityCenter {
		port waterIn : WaterInPort;
		port powerIn : PowerInPort;
		part generalWaterUse {
			port waterIn : WaterInPort;
		}
		part lights {
			port powerIn : PowerInPort;
		}
		part communicationEquipment {
			port powerIn : PowerInPort;
		}
		flow centerWater of PotableWater from waterIn.water to generalWaterUse.waterIn.water;
		flow centerLightsPower of Electricity from powerIn.power to lights.powerIn.power;
		flow centerCommsPower of Electricity from powerIn.power to communicationEquipment.powerIn.power;
	}

	state def MonitoringState {
		state Normal;
		state Anomaly;
		transition detectAnomaly from Normal to Anomaly
			when sensorIn.data.waterLevel < waterThreshold
			or sensorIn.data.powerOutput < powerThreshold
			or sensorIn.data.batteryCharge < batteryThreshold
			or sensorIn.data.generatorFuel < fuelThreshold
			or sensorIn.data.pumpOperational == false;
		transition returnToNormal from Anomaly to Normal
			when sensorIn.data.waterLevel >= waterThreshold
			and sensorIn.data.powerOutput >= powerThreshold
			and sensorIn.data.batteryCharge >= batteryThreshold
			and sensorIn.data.generatorFuel >= fuelThreshold
			and sensorIn.data.pumpOperational == true;
	}

	part def MonitoringStation {
		port sensorIn : SensorInPort;
		port alertOut : AlertOutPort;
		attribute waterThreshold : Real = 1;
		attribute powerThreshold : Real = 500;
		attribute batteryThreshold : Real = 20;
		attribute fuelThreshold : Real = 5;
		attribute maintenanceRequested : Boolean = false;
		state machine monitoringState : MonitoringState;
		perform action monitor : MonitorSystem {
			in sensorData = sensorIn.data;
			out alertOutput = alertOut.alert;
		}
	}

	part def MaintenanceTeam {
		port alertIn : AlertInPort;
		attribute availableTechnicians : Integer = 3;
		attribute responseTime : Real;
		part tools {
			attribute inventory : String;
		}
		part spareParts {
			attribute inventory : String;
		}
		perform action performMaintenance : PerformMaintenance {
			in alertInput = alertIn.alert;
		}
	}

	requirement def 'Continuous Water Supply' {
		text "The water supply system shall provide continuous potable water to the health clinic and community center.";
	}
	requirement def 'Continuous Power Supply' {
		text "The power generation system shall provide continuous electricity to the health clinic and community center.";
	}
	requirement def 'Proactive Maintenance' {
		text "The monitoring station shall detect anomalies and dispatch maintenance alerts to the maintenance team.";
	}
	requirement def 'Backup Power Availability' {
		text "The diesel generator shall provide backup power when solar generation and battery storage are insufficient.";
	}
	requirement def 'Storage Capacity' {
		text "The water storage tank shall have sufficient capacity to maintain supply during well recharge variations.";
	}

	part def VillageInfrastructure {
		part waterSystem : WaterSupplySystem;
		part powerSystem : PowerGenerationSystem;
		part clinic : HealthClinic;
		part communityCenter : CommunityCenter;
		part monitoringStation : MonitoringStation;
		part maintenanceTeam : MaintenanceTeam;
		flow waterToClinic of PotableWater from waterSystem.waterOut.water to clinic.waterIn.water;
		flow waterToCenter of PotableWater from waterSystem.waterOut.water to communityCenter.waterIn.water;
		flow powerToClinic of Electricity from powerSystem.powerOut.power to clinic.powerIn.power;
		flow powerToCenter of Electricity from powerSystem.powerOut.power to communityCenter.powerIn.power;
		flow tankTelemetry of SensorData from waterSystem.tank.telemetry.data to monitoringStation.sensorIn.data;
		flow pumpTelemetry of SensorData from waterSystem.pump.telemetry.data to monitoringStation.sensorIn.data;
		flow batteryTelemetry of SensorData from powerSystem.battery.telemetry.data to monitoringStation.sensorIn.data;
		flow solarTelemetry of SensorData from powerSystem.solar.telemetry.data to monitoringStation.sensorIn.data;
		flow generatorTelemetry of SensorData from powerSystem.generator.telemetry.data to monitoringStation.sensorIn.data;
		flow alertDispatch of MaintenanceAlert from monitoringStation.alertOut.alert to maintenanceTeam.alertIn.alert;
		requirement continuousWater : 'Continuous Water Supply';
		requirement continuousPower : 'Continuous Power Supply';
		requirement proactiveMaintenance : 'Proactive Maintenance';
		requirement backupPower : 'Backup Power Availability';
		requirement storageCapacity : 'Storage Capacity';
		satisfy continuousWater by waterSystem;
		satisfy continuousPower by powerSystem;
		satisfy proactiveMaintenance by monitoringStation, maintenanceTeam;
		satisfy backupPower by powerSystem.generator;
		satisfy storageCapacity by waterSystem.tank;
	}

	part village : VillageInfrastructure;
}
