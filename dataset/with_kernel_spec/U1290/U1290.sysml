package 'HomeOS Model' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	package Definitions {
		value def TemperatureValue :> ScalarValues::Real;
		value def PowerValue :> ScalarValues::Real;
		value def EnergyValue :> ScalarValues::Real;
		
		item def SensorData {
			attribute temp : TemperatureValue;
			attribute humidity : ScalarValues::Real;
			attribute lightLevel : ScalarValues::Real;
			attribute isOccupied : ScalarValues::Boolean;
		}
		item def ClimateCommand {
			attribute mode : ScalarValues::String;
			attribute targetTemp : TemperatureValue;
		}
		item def LightingCommand {
			attribute isOn : ScalarValues::Boolean;
			attribute brightness : ScalarValues::Real;
		}
		item def SecurityCommand {
			attribute arm : ScalarValues::Boolean;
		}
		item def SecurityAlert {
			attribute intrusionDetected : ScalarValues::Boolean;
		}
		item def EnergyReport {
			attribute powerDraw : PowerValue;
			attribute totalEnergy : EnergyValue;
		}
		item def UserPreferences {
			attribute desiredTemp : TemperatureValue;
			attribute lightingSchedule : ScalarValues::String;
		}
		item def UserOverride {
			attribute device : ScalarValues::String;
			attribute command : ScalarValues::String;
		}
		
		attribute def NoActivityDetected;
		attribute def ActivityDetected;
		attribute def IntruderDetected;
		attribute def MaintenanceRequest;
		attribute def MaintenanceComplete;
		attribute def UserOverrideSignal;
		
		port def SensorDataOut {
			out data : SensorData;
		}
		port def SensorDataIn {
			in data : SensorData;
		}
		port def ClimateCmdPort {
			in cmd : ClimateCommand;
		}
		port def LightingCmdPort {
			in cmd : LightingCommand;
		}
		port def SecurityCmdPort {
			in cmd : SecurityCommand;
		}
		port def SecurityAlertPort {
			out alert : SecurityAlert;
		}
		port def SecurityAlertInPort {
			in alert : SecurityAlert;
		}
		port def EnergyReportOut {
			out report : EnergyReport;
		}
		port def EnergyReportIn {
			in report : EnergyReport;
		}
		port def UserPrefPort {
			in pref : UserPreferences;
		}
		port def UserOverridePort {
			in override : UserOverride;
		}
		
		part def EnvironmentalSensor {
			port dataOut : SensorDataOut;
		}
		part def ClimateController {
			port cmdIn : ClimateCmdPort;
		}
		part def LightFixture {
			port cmdIn : LightingCmdPort;
		}
		part def LightingSystem {
			port cmdIn : LightingCmdPort;
			part fixture1 : LightFixture;
			part fixture2 : LightFixture;
			part fixture3 : LightFixture;
			part fixture4 : LightFixture;
			part fixture5 : LightFixture;
			part fixture6 : LightFixture;
			connect cmdIn to fixture1.cmdIn;
			connect cmdIn to fixture2.cmdIn;
			connect cmdIn to fixture3.cmdIn;
			connect cmdIn to fixture4.cmdIn;
			connect cmdIn to fixture5.cmdIn;
			connect cmdIn to fixture6.cmdIn;
		}
		part def SecurityMonitor {
			port cmdIn : SecurityCmdPort;
			port alertOut : SecurityAlertPort;
		}
		part def EnergyManager {
			port reportOut : EnergyReportOut;
		}
		part def CentralController {
			port sensorIn : SensorDataIn;
			port climateCmdOut : ~ClimateCmdPort;
			port lightingCmdOut : ~LightingCmdPort;
			port securityCmdOut : ~SecurityCmdPort;
			port securityAlertIn : SecurityAlertInPort;
			port energyReportIn : EnergyReportIn;
			port userPrefIn : UserPrefPort;
			port userOverrideIn : UserOverridePort;
		}
		part def HomeOS {
			part controller : CentralController;
			part sensor1 : EnvironmentalSensor;
			part sensor2 : EnvironmentalSensor;
			part sensor3 : EnvironmentalSensor;
			part sensor4 : EnvironmentalSensor;
			part climate : ClimateController;
			part lighting : LightingSystem;
			part security : SecurityMonitor;
			part energy : EnergyManager;
		}
		
		action def AnalyzeData;
		action def AdjustClimate;
		action def AdjustLighting;
		action def TriggerAlarm;
		action def TrackEnergy;
		
		state def HomeOSStates {
			entry; then 'Active Monitoring';
			
			state 'Active Monitoring' {
				do AnalyzeData;
				do AdjustClimate;
				do AdjustLighting;
				do TrackEnergy;
			}
			accept NoActivityDetected then Standby;
			accept IntruderDetected then 'Security Alert';
			accept MaintenanceRequest then 'Maintenance Mode';
			accept UserOverrideSignal then 'Active Monitoring';
			
			state Standby {
				do TrackEnergy;
			}
			accept ActivityDetected then 'Active Monitoring';
			accept IntruderDetected then 'Security Alert';
			accept MaintenanceRequest then 'Maintenance Mode';
			accept UserOverrideSignal then 'Active Monitoring';
			
			state 'Security Alert' {
				do TriggerAlarm;
			}
			accept UserOverrideSignal then 'Active Monitoring';
			accept MaintenanceRequest then 'Maintenance Mode';
			
			state 'Maintenance Mode';
			accept MaintenanceComplete then 'Active Monitoring';
		}
		
		requirement def HomeOSRequirement {
			doc /* The HomeOS shall manage environment, security, and energy consumption by coordinating subsystems based on user preferences and real-time conditions. */
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part homeOS : HomeOS {
			flow sensorDataFlow1 of SensorData 
				from sensor1.dataOut.data to controller.sensorIn.data;
			flow sensorDataFlow2 of SensorData 
				from sensor2.dataOut.data to controller.sensorIn.data;
			flow sensorDataFlow3 of SensorData 
				from sensor3.dataOut.data to controller.sensorIn.data;
			flow sensorDataFlow4 of SensorData 
				from sensor4.dataOut.data to controller.sensorIn.data;
			flow climateCmdFlow of ClimateCommand 
				from controller.climateCmdOut.cmd to climate.cmdIn.cmd;
			flow lightingCmdFlow of LightingCommand 
				from controller.lightingCmdOut.cmd to lighting.cmdIn.cmd;
			flow securityCmdFlow of SecurityCommand 
				from controller.securityCmdOut.cmd to security.cmdIn.cmd;
			flow securityAlertFlow of SecurityAlert 
				from security.alertOut.alert to controller.securityAlertIn.alert;
			flow energyReportFlow of EnergyReport 
				from energy.reportOut.report to controller.energyReportIn.report;
			
			exhibit state 'homeOS states' : HomeOSStates;
			
			requirement homeOSReq : HomeOSRequirement;
		}
	}
}
