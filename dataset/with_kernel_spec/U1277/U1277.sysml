package 'IoT Environmental Monitoring System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def SensorData {
			attribute temperature : ISQ::TemperatureValue;
			attribute humidity : ScalarValues::Real;
			attribute pressure : ISQ::PressureValue;
			attribute sensorId : String;
			attribute timestamp : String;
		}

		item def ControlCommand {
			attribute deviceId : String;
			attribute actionType : String;
			attribute parameter : ScalarValues::Real;
		}

		item def StatusReport {
			attribute deviceId : String;
			attribute status : String;
		}

		port def DataOutPort {
			out data : SensorData;
		}
		port def CommandOutPort {
			out command : ControlCommand;
		}
		port def StatusOutPort {
			out status : StatusReport;
		}

		action def 'Measure Environment' {
			out data : SensorData;
		}

		action def 'Authenticate and Encrypt' {
			in data : SensorData;
			out securedData : SensorData;
			language "Alf"
			/*
			 * securedData = encryptAES256(data, encryptionKey);
			 */
		}

		action def 'Analyze Data' {
			in data : SensorData;
			out command : ControlCommand;
			language "Alf"
			/*
			 * if (data.temperature > 25.0) {
			 *   command = new ControlCommand(deviceId="HVAC1", actionType="cool", parameter=22.0);
			 * } else if (data.humidity < 30.0) {
			 *   command = new ControlCommand(deviceId="Humidifier1", actionType="humidify", parameter=45.0);
			 * } else {
			 *   command = null;
			 * }
			 */
		}

		action def 'Execute Command' {
			in command : ControlCommand;
			out status : StatusReport;
			language "Alf"
			/*
			 * status = new StatusReport(deviceId=command.deviceId, status="completed");
			 */
		}

		action def 'Store Data' {
			in data : SensorData;
		}

		part def IoTSensor {
			attribute batteryLevel : ScalarValues::Real;
			port sensorDataOut : DataOutPort;

			perform action 'measure environment' : 'Measure Environment';

			exhibit state sensorStates {
				entry; then sleeping;
				state sleeping;
				transition sleeping_to_waking
					first sleeping
					accept after 60 [s]
					then waking;
				state waking {
					do 'measure environment';
				}
				transition waking_to_transmitting
					first waking
					then transmitting;
				state transmitting {
					entry send new SensorData() via sensorDataOut;
				}
				transition transmitting_to_sleeping
					first transmitting
					then sleeping;
			}
		}

		part def NetworkGateway {
			attribute maxDevices : ScalarValues::Integer = 100;
			port sensorDataIn : ~DataOutPort;
			port cloudDataOut : DataOutPort;
			port controlCommandIn : ~CommandOutPort;
			port controlCommandOut : CommandOutPort;
			port statusReportIn : ~StatusOutPort;
			port statusReportOut : StatusOutPort;

			exhibit state gatewayStates {
				entry; then idle;
				state idle;
				transition onSensorData
					first idle
					accept SensorData via sensorDataIn
					do send new SensorData() via cloudDataOut
					then idle;
				transition onControlCommand
					first idle
					accept ControlCommand via controlCommandIn
					do send new ControlCommand() via controlCommandOut
					then idle;
				transition onStatusReport
					first idle
					accept StatusReport via statusReportIn
					do send new StatusReport() via statusReportOut
					then idle;
			}
		}

		part def SecurityModule {
			attribute encryptionAlgorithm : String = "AES-256";
			port dataIn : ~DataOutPort;
			port dataOut : DataOutPort;
			port controlIn : ~CommandOutPort;
			port controlOut : CommandOutPort;
			port statusIn : ~StatusOutPort;
			port statusOut : StatusOutPort;

			perform action 'authenticate and encrypt' : 'Authenticate and Encrypt';

			exhibit state securityStates {
				entry; then idle;
				state idle;
				transition onSensorData
					first idle
					accept SensorData via dataIn
					do 'authenticate and encrypt'
					then forwarding;
				state forwarding {
					entry send new SensorData() via dataOut;
				}
				transition forwarding_to_idle
					first forwarding
					then idle;
				transition onControlCommand
					first idle
					accept ControlCommand via controlIn
					do send new ControlCommand() via controlOut
					then idle;
				transition onStatusReport
					first idle
					accept StatusReport via statusIn
					do send new StatusReport() via statusOut
					then idle;
			}
		}

		part def Database {
			perform action 'store data' : 'Store Data';
		}

		part def CloudPlatform {
			port dataIn : ~DataOutPort;
			port controlOut : CommandOutPort;
			port statusIn : ~StatusOutPort;

			part database : Database;

			perform action 'analyze data' : 'Analyze Data';

			exhibit state cloudStates {
				entry; then idle;
				state idle;
				transition onSensorData
					first idle
					accept SensorData via dataIn
					do 'analyze data'
					then evaluating;
				state evaluating {
					entry send new ControlCommand() via controlOut;
				}
				transition evaluating_to_idle
					first evaluating
					then idle;
				transition onStatusReport
					first idle
					accept StatusReport via statusIn
					then idle;
			}
		}

		abstract part def ActuatorDevice {
			port commandIn : ~CommandOutPort;
			port statusOut : StatusOutPort;

			perform action 'execute command' : 'Execute Command';

			exhibit state actuatorStates {
				entry; then idle;
				state idle;
				transition onCommand
					first idle
					accept ControlCommand via commandIn
					do 'execute command'
					then executing;
				state executing {
					entry send new StatusReport() via statusOut;
				}
				transition executing_to_idle
					first executing
					then idle;
			}
		}

		part def HVACUnit :> ActuatorDevice {
			attribute coolingEnabled : Boolean;
		}

		part def SmartLighting :> ActuatorDevice {
			attribute brightnessLevel : ScalarValues::Real;
		}

		requirement def 'Data Collection Requirement' {
			doc /* The system shall collect environmental data from IoT sensors deployed at various physical locations. */
		}

		requirement def 'Security Requirement' {
			doc /* The system shall authenticate data sources and encrypt all communications using AES-256 encryption. */
		}

		requirement def 'Scalability Requirement' {
			doc /* The network gateway shall manage communications for up to 100 connected devices. */
		}

		requirement def 'Automated Control Requirement' {
			doc /* The system shall automatically generate and send control commands to actuator devices based on analyzed sensor data. */
		}

		verification def GatewayScalabilityTest {
			private import VerificationCases::*;
			subject gw : NetworkGateway;
			objective scalabilityObjective {
				verify 'Scalability Requirement';
			}
			action simulateDevices {
				in part gw : NetworkGateway = GatewayScalabilityTest::gw;
				out deviceCount : ScalarValues::Integer;
			}
			action evaluate {
				in deviceCount : ScalarValues::Integer = simulateDevices.deviceCount;
				out verdict : VerdictKind = PassIf(deviceCount >= 100);
			}
			return verdict : VerdictKind = evaluate.verdict;
		}

		part def IoTEnvironmentSystem {
			part sensor1 : IoTSensor;
			part sensor2 : IoTSensor;
			part gateway : NetworkGateway;
			part security : SecurityModule;
			part cloud : CloudPlatform;
			part hvac : HVACUnit;
			part lighting : SmartLighting;

			connect sensor1.sensorDataOut to gateway.sensorDataIn;
			connect sensor2.sensorDataOut to gateway.sensorDataIn;
			connect gateway.cloudDataOut to security.dataIn;
			connect security.dataOut to cloud.dataIn;
			connect cloud.controlOut to security.controlIn;
			connect security.controlOut to gateway.controlCommandIn;
			connect gateway.controlCommandOut to hvac.commandIn;
			connect gateway.controlCommandOut to lighting.commandIn;
			connect hvac.statusOut to gateway.statusReportIn;
			connect lighting.statusOut to gateway.statusReportIn;
			connect gateway.statusReportOut to security.statusIn;
			connect security.statusOut to cloud.statusIn;

			flow sensorDataFlow1 of SensorData
				from sensor1.sensorDataOut.data to gateway.sensorDataIn.data;
			flow sensorDataFlow2 of SensorData
				from sensor2.sensorDataOut.data to gateway.sensorDataIn.data;
			flow gatewayToSecurityFlow of SensorData
				from gateway.cloudDataOut.data to security.dataIn.data;
			flow securityToCloudFlow of SensorData
				from security.dataOut.data to cloud.dataIn.data;
			flow cloudToSecurityCmdFlow of ControlCommand
				from cloud.controlOut.command to security.controlIn.command;
			flow securityToGatewayCmdFlow of ControlCommand
				from security.controlOut.command to gateway.controlCommandIn.command;
			flow gatewayToHvacCmdFlow of ControlCommand
				from gateway.controlCommandOut.command to hvac.commandIn.command;
			flow gatewayToLightingCmdFlow of ControlCommand
				from gateway.controlCommandOut.command to lighting.commandIn.command;
			flow hvacToGatewayStatusFlow of StatusReport
				from hvac.statusOut.status to gateway.statusReportIn.status;
			flow lightingToGatewayStatusFlow of StatusReport
				from lighting.statusOut.status to gateway.statusReportIn.status;
			flow gatewayToSecurityStatusFlow of StatusReport
				from gateway.statusReportOut.status to security.statusIn.status;
			flow securityToCloudStatusFlow of StatusReport
				from security.statusOut.status to cloud.statusIn.status;

			requirement 'data collection req' : 'Data Collection Requirement' {
				subject :>> sensor1;
				subject :>> sensor2;
			}
			requirement 'security req' : 'Security Requirement' {
				subject :>> security;
			}
			requirement 'scalability req' : 'Scalability Requirement' {
				subject :>> gateway;
			}
			requirement 'automated control req' : 'Automated Control Requirement' {
				subject :>> cloud;
				subject :>> hvac;
				subject :>> lighting;
			}
		}
	}

	package Usages {
		private import Definitions::*;
		part iotSystem : IoTEnvironmentSystem;

		verification gatewayTest : GatewayScalabilityTest {
			subject :>> gw = iotSystem.gateway;
		}
	}
}
