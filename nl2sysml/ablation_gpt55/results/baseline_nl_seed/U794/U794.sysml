package OpticalFiberPrimaryFunctionModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def FiberLength :> ISQ::length;
	attribute def OpticalWavelength :> ISQ::length;
	attribute def OpticalPower :> ISQ::power;
	attribute def TimeDuration :> ISQ::time;
	attribute def OperatingTemperature :> ISQ::thermodynamicTemperature;
	attribute def OpticalLoss_dB :> Real;
	attribute def OpticalAttenuation_dBPerKm :> Real;
	attribute def OpticalPowerLevel_dBm :> Real;
	attribute def DataRate_Hz :> ISQ::frequency;
	attribute def BitCount :> Integer;

	item def ElectricalData {
		attribute bitRate : DataRate_Hz = 10000000000.0 [Hz];
		attribute frameLength : BitCount = 12000;
		attribute isEncoded : Boolean = true;
	}

	item def OpticalSignal {
		attribute centerWavelength : OpticalWavelength = 0.000001550 [m];
		attribute spectralWidth : OpticalWavelength = 0.00000000010 [m];
		attribute averagePower : OpticalPower = 0.001 [W];
		attribute powerLevel_dBm : OpticalPowerLevel_dBm = 0.0;
		attribute bitRate : DataRate_Hz = 10000000000.0 [Hz];
	}

	item def ControlCommand {
		attribute enableTransmission : Boolean = true;
		attribute requestLoopbackTest : Boolean = false;
		attribute resetFault : Boolean = false;
	}

	item def LinkStatus {
		attribute linkAvailable : Boolean = true;
		attribute receivedPower_dBm : OpticalPowerLevel_dBm = -12.0;
		attribute measuredLoss_dB : OpticalLoss_dB = 2.8;
		attribute bitErrorAlarm : Boolean = false;
		attribute faultPresent : Boolean = false;
	}

	port def ElectricalDataInPort {
		in item data : ElectricalData;
	}

	port def ElectricalDataOutPort {
		out item data : ElectricalData;
	}

	port def OpticalInPort {
		in item signal : OpticalSignal;
	}

	port def OpticalOutPort {
		out item signal : OpticalSignal;
	}

	port def OperatorInterfacePort {
		in item command : ControlCommand;
		out item status : LinkStatus;
	}

	port def ControllerToDeviceManagementPort {
		out item command : ControlCommand;
		in item status : LinkStatus;
	}

	port def DeviceManagementPort {
		in item command : ControlCommand;
		out item status : LinkStatus;
	}

	action def ConvertElectricalToOptical {
		in item electricalDataIn : ElectricalData;
		out item opticalSignalOut : OpticalSignal;
		in wavelength : OpticalWavelength;
		in launchPower : OpticalPower;
	}

	action def GuideOpticalSignal {
		in item inputSignal : OpticalSignal;
		out item outputSignal : OpticalSignal;
		in length : FiberLength;
		in attenuationCoefficient_dBPerKm : OpticalAttenuation_dBPerKm;
		out totalLoss_dB : OpticalLoss_dB;
	}

	action def ConvertOpticalToElectrical {
		in item opticalSignalIn : OpticalSignal;
		out item electricalDataOut : ElectricalData;
		in receiverSensitivity_dBm : OpticalPowerLevel_dBm;
	}

	action def MonitorOpticalLink {
		in item monitoredSignal : OpticalSignal;
		out item status : LinkStatus;
		in minimumReceivedPower_dBm : OpticalPowerLevel_dBm;
	}

	action def TransmitDataOverOpticalFiber {
		in item userElectricalData : ElectricalData;
		out item recoveredElectricalData : ElectricalData;

		action modulate : ConvertElectricalToOptical;
		action propagate : GuideOpticalSignal;
		action detect : ConvertOpticalToElectrical;

		flow userElectricalData to modulate.electricalDataIn;
		flow modulate.opticalSignalOut to propagate.inputSignal;
		flow propagate.outputSignal to detect.opticalSignalIn;
		flow detect.electricalDataOut to recoveredElectricalData;
	}

	action def InitializeOpticalLink {
		out item status : LinkStatus;
	}

	action def IsolateFault {
		in item status : LinkStatus;
		out item command : ControlCommand;
	}

	state def OpticalFiberSystemStates {
		entry; then poweredOff;

		state poweredOff;
		state initializing {
			do action initialize : InitializeOpticalLink;
		}
		state ready;
		state transmitting {
			do action transmit : TransmitDataOverOpticalFiber;
		}
		state degraded;
		state faulted {
			do action isolate : IsolateFault;
		}

		transition powerApplied first poweredOff then initializing;
		transition initializationComplete first initializing then ready;
		transition trafficEnabled first ready then transmitting;
		transition lowMarginDetected first transmitting then degraded;
		transition marginRestored first degraded then transmitting;
		transition faultDetectedFromReady first ready then faulted;
		transition faultDetectedFromTransmitting first transmitting then faulted;
		transition faultDetectedFromDegraded first degraded then faulted;
		transition resetComplete first faulted then initializing;
		transition powerRemovedFromReady first ready then poweredOff;
		transition powerRemovedFromTransmitting first transmitting then poweredOff;
		transition powerRemovedFromFaulted first faulted then poweredOff;
	}

	part def OpticalTransmitter {
		port electricalIn : ElectricalDataInPort;
		port opticalOut : OpticalOutPort;
		port management : DeviceManagementPort;

		attribute centerWavelength : OpticalWavelength = 0.000001550 [m];
		attribute wavelengthTolerance : OpticalWavelength = 0.000000010 [m];
		attribute launchOpticalPower : OpticalPower = 0.001 [W];
		attribute launchPower_dBm : OpticalPowerLevel_dBm = 0.0;
		attribute maximumBitRate : DataRate_Hz = 10000000000.0 [Hz];
		attribute warmupTime : TimeDuration = 2.0 [s];
		attribute operatingTemperature : OperatingTemperature = 293.15 [K];

		perform action modulateElectricalData : ConvertElectricalToOptical;
	}

	part def SingleModeOpticalFiber {
		port input : OpticalInPort;
		port output : OpticalOutPort;
		port monitorOut : OpticalOutPort;

		attribute length : FiberLength = 10000.0 [m];
		attribute coreDiameter : FiberLength = 0.0000082 [m];
		attribute claddingDiameter : FiberLength = 0.000125 [m];
		attribute minimumBendRadius : FiberLength = 0.030 [m];
		attribute attenuationCoefficient_dBPerKm : OpticalAttenuation_dBPerKm = 0.20;
		attribute connectorLoss_dB : OpticalLoss_dB = 0.6;
		attribute spliceLoss_dB : OpticalLoss_dB = 0.2;
		attribute totalLoss_dB : OpticalLoss_dB = 2.8;

		perform action guideLight : GuideOpticalSignal;
	}

	part def OpticalReceiver {
		port opticalIn : OpticalInPort;
		port electricalOut : ElectricalDataOutPort;
		port management : DeviceManagementPort;

		attribute receiverSensitivity_dBm : OpticalPowerLevel_dBm = -18.0;
		attribute overloadLimit_dBm : OpticalPowerLevel_dBm = 3.0;
		attribute supportedBitRate : DataRate_Hz = 10000000000.0 [Hz];
		attribute decisionLatency : TimeDuration = 0.000000010 [s];
		attribute operatingTemperature : OperatingTemperature = 293.15 [K];

		perform action recoverElectricalData : ConvertOpticalToElectrical;
	}

	part def OpticalLinkMonitor {
		port opticalIn : OpticalInPort;
		port management : DeviceManagementPort;

		attribute alarmThreshold_dBm : OpticalPowerLevel_dBm = -15.0;
		attribute measurementInterval : TimeDuration = 1.0 [s];
		attribute measuredReceivedPower_dBm : OpticalPowerLevel_dBm = -12.0;
		attribute measuredLoss_dB : OpticalLoss_dB = 2.8;

		perform action monitorLink : MonitorOpticalLink;
	}

	part def LinkController {
		port operatorInterface : OperatorInterfacePort;
		port transmitterControl : ControllerToDeviceManagementPort;
		port receiverControl : ControllerToDeviceManagementPort;
		port monitorControl : ControllerToDeviceManagementPort;

		attribute commandedEnable : Boolean = true;
		attribute commandedReset : Boolean = false;
		attribute requiredMargin_dB : OpticalLoss_dB = 3.0;
		attribute reportingPeriod : TimeDuration = 1.0 [s];
	}

	part def OpticalFiberCommunicationSystem {
		port userDataIn : ElectricalDataInPort;
		port userDataOut : ElectricalDataOutPort;
		port operatorInterface : OperatorInterfacePort;

		part transmitter : OpticalTransmitter;
		part fiber : SingleModeOpticalFiber;
		part receiver : OpticalReceiver;
		part monitor : OpticalLinkMonitor;
		part controller : LinkController;

		attribute nominalBitRate : DataRate_Hz = 10000000000.0 [Hz];
		attribute nominalWavelength : OpticalWavelength = 0.000001550 [m];
		attribute installedFiberLength : FiberLength = 10000.0 [m];
		attribute totalOpticalLoss_dB : OpticalLoss_dB = 2.8;
		attribute linkMargin_dB : OpticalLoss_dB = 15.2;
		attribute minimumRequiredMargin_dB : OpticalLoss_dB = 3.0;
		attribute primaryFunctionAvailable : Boolean = true;

		connect userDataIn to transmitter.electricalIn;
		connect transmitter.opticalOut to fiber.input;
		connect fiber.output to receiver.opticalIn;
		connect receiver.electricalOut to userDataOut;
		connect fiber.monitorOut to monitor.opticalIn;
		connect operatorInterface to controller.operatorInterface;
		connect controller.transmitterControl to transmitter.management;
		connect controller.receiverControl to receiver.management;
		connect controller.monitorControl to monitor.management;

		perform action primaryFunction : TransmitDataOverOpticalFiber;
		exhibit state operatingState : OpticalFiberSystemStates;
	}

	requirement def PrimaryHighLevelFunctionRequirement {
		subject system : OpticalFiberCommunicationSystem;

		doc /*
			The optical fiber communication system shall perform the high-level primary
			function of transporting digital user data by converting incoming electrical
			data into modulated light, guiding the light through a single-mode optical
			fiber, and converting the received optical signal back into electrical data.
		*/

		require constraint { system.primaryFunctionAvailable == true }
		require constraint { system.nominalBitRate >= 10000000000.0 [Hz] }
	}

	requirement def WavelengthCompatibilityRequirement {
		subject system : OpticalFiberCommunicationSystem;

		require constraint { system.nominalWavelength >= 0.000001530 [m] }
		require constraint { system.nominalWavelength <= 0.000001565 [m] }
	}

	requirement def OpticalPowerBudgetRequirement {
		subject system : OpticalFiberCommunicationSystem;

		require constraint { system.totalOpticalLoss_dB <= 6.0 }
		require constraint { system.linkMargin_dB >= system.minimumRequiredMargin_dB }
	}

	requirement def FiberPhysicalConfigurationRequirement {
		subject system : OpticalFiberCommunicationSystem;

		require constraint { system.installedFiberLength >= 10000.0 [m] }
		require constraint { system.fiber.coreDiameter >= 0.0000080 [m] }
		require constraint { system.fiber.coreDiameter <= 0.0000090 [m] }
		require constraint { system.fiber.claddingDiameter == 0.000125 [m] }
	}

	part opticalFiberCommunicationSystem : OpticalFiberCommunicationSystem;

	requirement primaryHighLevelFunction : PrimaryHighLevelFunctionRequirement {
		subject system : OpticalFiberCommunicationSystem;
	}

	requirement wavelengthCompatibility : WavelengthCompatibilityRequirement {
		subject system : OpticalFiberCommunicationSystem;
	}

	requirement opticalPowerBudget : OpticalPowerBudgetRequirement {
		subject system : OpticalFiberCommunicationSystem;
	}

	requirement fiberPhysicalConfiguration : FiberPhysicalConfigurationRequirement {
		subject system : OpticalFiberCommunicationSystem;
	}
}
