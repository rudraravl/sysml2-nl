package BelkinWemoSmartPlugSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def Volt {
        :> ScalarValues::Real;
        unit = "V";
    }

    attribute def Ampere {
        :> ScalarValues::Real;
        unit = "A";
    }

    attribute def Watt {
        :> ScalarValues::Real;
        unit = "W";
    }

    attribute def Hertz {
        :> ScalarValues::Real;
        unit = "Hz";
    }

    attribute def Second {
        :> ScalarValues::Real;
        unit = "s";
    }

    attribute def Celsius {
        :> ScalarValues::Real;
        unit = "degC";
    }

    enum def RelayState {
        enum off;
        enum on;
        enum faultOpen;
        enum faultClosed;
    }

    enum def NetworkState {
        enum disconnected;
        enum connecting;
        enum connected;
        enum cloudLinked;
        enum degraded;
    }

    enum def CommandKind {
        enum turnOn;
        enum turnOff;
        enum toggle;
        enum queryStatus;
        enum configureSchedule;
        enum reset;
    }

    item def ACLinePower {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute frequency : Hertz;
        attribute activePower : Watt;
    }

    item def SwitchedACPower :> ACLinePower {
        attribute energized : Boolean;
    }

    item def ControlCommand {
        attribute kind : CommandKind;
        attribute issuedBy : String;
        attribute requestedRelayState : RelayState;
        attribute timestamp : Second;
    }

    item def DeviceStatus {
        attribute relayState : RelayState;
        attribute networkState : NetworkState;
        attribute loadPower : Watt;
        attribute internalTemperature : Celsius;
        attribute firmwareVersion : String;
        attribute lastCommandAccepted : Boolean;
    }

    item def WiFiPacket {
        attribute ssid : String;
        attribute encryptedPayload : String;
        attribute signalStrength : Percent;
    }

    item def CloudMessage {
        attribute deviceIdentifier : String;
        attribute commandPayload : String;
        attribute statusPayload : String;
        attribute authenticated : Boolean;
    }

    port def ACInputPort {
        in item lineIn : ACLinePower;
    }

    port def ACOutputPort {
        out item lineOut : SwitchedACPower;
    }

    port def WirelessPort {
        in item inboundWiFi : WiFiPacket;
        out item outboundWiFi : WiFiPacket;
    }

    port def CloudServicePort {
        in item inboundCloud : CloudMessage;
        out item outboundCloud : CloudMessage;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : DeviceStatus;
    }

    port def ManualButtonPort {
        in item localPress : ControlCommand;
    }

    port def LoadPowerPort {
        in item suppliedPower : SwitchedACPower;
    }

    part def BelkinWemoSmartPlug {
        attribute deviceIdentifier : String;
        attribute nominalInputVoltage : Volt = 120;
        attribute nominalFrequency : Hertz = 60;
        attribute maximumLoadCurrent : Ampere = 15;
        attribute maximumLoadPower : Watt = 1800;
        attribute standbyPowerLimit : Watt = 2;
        attribute relayState : RelayState = RelayState::off;
        attribute networkState : NetworkState = NetworkState::disconnected;
        attribute internalTemperature : Celsius;
        attribute firmwareVersion : String;

        port acInput : ACInputPort;
        port acOutput : ACOutputPort;
        port wifi : WirelessPort;
        port cloud : CloudServicePort;
        port commandInput : CommandPort;
        port statusOutput : StatusPort;
        port manualButton : ManualButtonPort;

        part powerSupply {
            attribute inputVoltage : Volt;
            attribute logicVoltage : Volt = 3.3;
            attribute efficiency : Percent;
        }

        part relayModule {
            attribute state : RelayState = RelayState::off;
            attribute contactCurrentLimit : Ampere = 15;
            port lineIn : ACInputPort;
            port lineOut : ACOutputPort;
        }

        part microcontroller {
            attribute clockFrequencyMHz : Real = 80;
            attribute storedRelayState : RelayState = RelayState::off;
            port commandIn : CommandPort;
            port statusOut : StatusPort;
        }

        part wifiRadio {
            attribute signalStrength : Percent;
            attribute connectedSsid : String;
            port radioPort : WirelessPort;
        }

        part securityModule {
            attribute tlsEnabled : Boolean = true;
            attribute deviceCertificateInstalled : Boolean = true;
        }

        part thermalSensor {
            attribute measuredTemperature : Celsius;
        }

        part localButton {
            port buttonPort : ManualButtonPort;
        }

        connect acInput.lineIn to relayModule.lineIn.lineIn;
        connect relayModule.lineOut.lineOut to acOutput.lineOut;
        connect wifi.inboundWiFi to wifiRadio.radioPort.inboundWiFi;
        connect wifiRadio.radioPort.outboundWiFi to wifi.outboundWiFi;
        connect cloud.inboundCloud to commandInput.command;
        connect statusOutput.status to cloud.outboundCloud;
        connect manualButton.localPress to localButton.buttonPort.localPress;
        connect localButton.buttonPort.localPress to microcontroller.commandIn.command;
        connect commandInput.command to microcontroller.commandIn.command;
        connect microcontroller.statusOut.status to statusOutput.status;

        action def AcceptRemoteCommand {
            in item command : ControlCommand;
            out item acceptedStatus : DeviceStatus;
            first start;
            then validateCommand;
            then authenticateSource;
            then updateRelayRequest;
            then publishStatus;
            then done;

            action validateCommand;
            action authenticateSource;
            action updateRelayRequest;
            action publishStatus;
        }

        action def SwitchLoadPower {
            in item requestedState : RelayState;
            in item sourcePower : ACLinePower;
            out item switchedPower : SwitchedACPower;
            first start;
            then checkLoadLimit;
            then driveRelay;
            then verifyContactState;
            then done;

            action checkLoadLimit;
            action driveRelay;
            action verifyContactState;
        }

        action def ReportDeviceStatus {
            out item status : DeviceStatus;
            first start;
            then sampleRelayState;
            then sampleNetworkState;
            then sampleLoadPower;
            then sampleTemperature;
            then transmitStatus;
            then done;

            action sampleRelayState;
            action sampleNetworkState;
            action sampleLoadPower;
            action sampleTemperature;
            action transmitStatus;
        }

        state def OperatingStates {
            state initial Initializing;
            state ConnectingToWiFi;
            state CloudAvailable;
            state LocalOnly;
            state SwitchingOn;
            state On;
            state SwitchingOff;
            state Off;
            state Fault;

            transition Initializing first ConnectingToWiFi;
            transition ConnectingToWiFi then CloudAvailable
                if networkState == NetworkState::cloudLinked;
            transition ConnectingToWiFi then LocalOnly
                if networkState == NetworkState::connected;
            transition CloudAvailable then SwitchingOn
                accept ControlCommand
                if relayState == RelayState::off;
            transition LocalOnly then SwitchingOn
                accept ControlCommand
                if relayState == RelayState::off;
            transition SwitchingOn then On
                if relayState == RelayState::on;
            transition On then SwitchingOff
                accept ControlCommand
                if relayState == RelayState::on;
            transition SwitchingOff then Off
                if relayState == RelayState::off;
            transition Off then SwitchingOn
                accept ControlCommand
                if relayState == RelayState::off;
            transition CloudAvailable then Fault
                if internalTemperature > 85;
            transition LocalOnly then Fault
                if internalTemperature > 85;
            transition On then Fault
                if internalTemperature > 85;
            transition Fault then Off
                accept ControlCommand
                if relayState == RelayState::off;
        }
    }

    part def ResidentialWallOutlet {
        attribute supplyVoltage : Volt = 120;
        attribute frequency : Hertz = 60;
        port acSupply : ACInputPort;
    }

    part def ConnectedAppliance {
        attribute ratedPower : Watt;
        attribute energized : Boolean = false;
        port loadInput : LoadPowerPort;
    }

    part def MobileApplication {
        attribute userAccountId : String;
        attribute installedVersion : String;
        port userCommandOut : CommandPort;
        port deviceStatusIn : StatusPort;
    }

    part def WemoCloudService {
        attribute serviceName : String = "Wemo Cloud";
        attribute authenticatedSessions : Integer;
        port appCommandIn : CommandPort;
        port deviceCloudPort : CloudServicePort;
        port statusToApp : StatusPort;
    }

    part def HomeWiFiRouter {
        attribute ssid : String;
        attribute internetAvailable : Boolean;
        attribute signalStrengthAtPlug : Percent;
        port wirelessLan : WirelessPort;
    }

    part def WemoBasedSystem {
        attribute systemName : String = "Belkin Wemo Based Smart Outlet Control System";
        attribute primaryFunction : String =
            "Provide high-level remote and local control of AC electrical power to a connected appliance through a Belkin Wemo smart plug using Wi-Fi, cloud messaging, and relay-based load switching.";

        part wallOutlet : ResidentialWallOutlet;
        part wemoPlug : BelkinWemoSmartPlug {
            deviceIdentifier = "WEMO-LIVINGROOM-001";
            firmwareVersion = "4.00.201132";
        }
        part appliance : ConnectedAppliance {
            ratedPower = 900;
        }
        part mobileApp : MobileApplication;
        part cloudService : WemoCloudService;
        part router : HomeWiFiRouter {
            ssid = "HomeWiFi";
            internetAvailable = true;
            signalStrengthAtPlug = 82;
        }

        connect wallOutlet.acSupply.lineIn to wemoPlug.acInput.lineIn;
        connect wemoPlug.acOutput.lineOut to appliance.loadInput.suppliedPower;
        connect mobileApp.userCommandOut.command to cloudService.appCommandIn.command;
        connect cloudService.deviceCloudPort.outboundCloud to wemoPlug.cloud.inboundCloud;
        connect wemoPlug.cloud.outboundCloud to cloudService.deviceCloudPort.inboundCloud;
        connect cloudService.statusToApp.status to mobileApp.deviceStatusIn.status;
        connect router.wirelessLan.outboundWiFi to wemoPlug.wifi.inboundWiFi;
        connect wemoPlug.wifi.outboundWiFi to router.wirelessLan.inboundWiFi;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Wemo-based system shall allow a user to turn a connected AC appliance on or off locally or remotely while preserving safe delivery of household AC power. */
        subject system : WemoBasedSystem;
        require constraint {
            system.wemoPlug.maximumLoadCurrent <= 15 and
            system.wemoPlug.maximumLoadPower <= 1800
        }
    }

    requirement def RemoteControlRequirement {
        doc /* The Wemo smart plug shall accept authenticated remote commands from the mobile application through the Wemo cloud service and change relay state accordingly. */
        subject plug : BelkinWemoSmartPlug;
        require constraint {
            plug.networkState == NetworkState::cloudLinked implies
            (plug.relayState == RelayState::on or plug.relayState == RelayState::off)
        }
    }

    requirement def LocalControlRequirement {
        doc /* The Wemo smart plug shall support local manual toggling of the controlled AC output using its physical button. */
        subject plug : BelkinWemoSmartPlug;
        require constraint {
            plug.relayState == RelayState::on or plug.relayState == RelayState::off
        }
    }

    requirement def LoadSafetyRequirement {
        doc /* The Wemo smart plug shall not intentionally energize the output when measured load demand exceeds its rated current or power limits. */
        subject plug : BelkinWemoSmartPlug;
        require constraint {
            plug.maximumLoadCurrent <= 15 and
            plug.maximumLoadPower <= 1800
        }
    }

    requirement def StatusReportingRequirement {
        doc /* The Wemo smart plug shall report relay state, network state, load power, firmware version, and internal temperature to the user-facing application. */
        subject plug : BelkinWemoSmartPlug;
        require constraint {
            plug.firmwareVersion != "" and
            plug.internalTemperature < 85
        }
    }

    requirement def StandbyPowerRequirement {
        doc /* The Wemo smart plug shall consume no more than two watts in standby while connected to Wi-Fi and not energizing the connected appliance. */
        subject plug : BelkinWemoSmartPlug;
        require constraint {
            plug.standbyPowerLimit <= 2
        }
    }

    satisfy PrimaryFunctionRequirement by WemoBasedSystem;
    satisfy RemoteControlRequirement by BelkinWemoSmartPlug::AcceptRemoteCommand;
    satisfy LocalControlRequirement by BelkinWemoSmartPlug::OperatingStates;
    satisfy LoadSafetyRequirement by BelkinWemoSmartPlug::SwitchLoadPower;
    satisfy StatusReportingRequirement by BelkinWemoSmartPlug::ReportDeviceStatus;
    satisfy StandbyPowerRequirement by BelkinWemoSmartPlug::powerSupply;
}