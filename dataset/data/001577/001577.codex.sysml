package SmartDeviceSystemModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Percent :> Real {
        doc /* Percentage value from 0 to 100. */
    }

    attribute def Celsius :> Real {
        doc /* Temperature in degrees Celsius. */
    }

    attribute def Millisecond :> Real {
        doc /* Duration in milliseconds. */
    }

    attribute def Watt :> Real {
        doc /* Power in watts. */
    }

    attribute def Volt :> Real {
        doc /* Electric potential in volts. */
    }

    attribute def ByteCount :> Integer {
        doc /* Number of bytes. */
    }

    item def UserCommand {
        attribute commandId : String;
        attribute commandType : CommandType;
        attribute requestedAt : String;
        attribute priority : CommandPriority;
    }

    enum def CommandType {
        powerOn;
        powerOff;
        openApplication;
        closeApplication;
        captureSensorReading;
        transmitData;
        updateSettings;
        emergencyCall;
    }

    enum def CommandPriority {
        low;
        normal;
        high;
        emergency;
    }

    item def Notification {
        attribute message : String;
        attribute severity : NotificationSeverity;
        attribute createdAt : String;
    }

    enum def NotificationSeverity {
        info;
        warning;
        critical;
    }

    item def SensorReading {
        attribute sourceId : String;
        attribute measuredValue : Real;
        attribute unitLabel : String;
        attribute capturedAt : String;
        attribute confidence : Percent;
    }

    item def NetworkPacket {
        attribute packetId : String;
        attribute payloadSize : ByteCount;
        attribute encrypted : Boolean;
        attribute destinationAddress : String;
    }

    item def DisplayFrame {
        attribute frameId : String;
        attribute brightness : Percent;
        attribute refreshPeriod : Millisecond;
    }

    item def ElectricalEnergy {
        attribute voltage : Volt;
        attribute availableCapacity : Percent;
        attribute instantaneousPower : Watt;
    }

    port def UserInterfacePort {
        in item userCommand : UserCommand;
        out item notification : Notification;
        out item displayFrame : DisplayFrame;
    }

    port def SensorInputPort {
        out item reading : SensorReading;
    }

    port def WirelessNetworkPort {
        in item inboundPacket : NetworkPacket;
        out item outboundPacket : NetworkPacket;
    }

    port def PowerPort {
        in item suppliedEnergy : ElectricalEnergy;
        out item powerStatus : ElectricalEnergy;
    }

    part def TouchDisplay {
        attribute diagonalSizeInches : Real = 6.7;
        attribute maximumBrightness : Percent = 100;
        attribute currentBrightness : Percent;
        attribute refreshRateHz : Real = 120;

        port ui : UserInterfacePort;

        action renderUserExperience {
            in item frame : DisplayFrame;
            out item visibleFrame : DisplayFrame;
        }
    }

    part def SensorSuite {
        attribute ambientTemperature : Celsius;
        attribute motionDetected : Boolean;
        attribute locationAvailable : Boolean;
        attribute biometricAuthenticated : Boolean;

        port sensorOutput : SensorInputPort;

        action acquireContext {
            out item reading : SensorReading;
        }
    }

    part def WirelessModule {
        attribute cellularEnabled : Boolean;
        attribute wifiEnabled : Boolean;
        attribute bluetoothEnabled : Boolean;
        attribute signalStrength : Percent;
        attribute encryptionActive : Boolean;

        port network : WirelessNetworkPort;

        action sendPacket {
            in item packet : NetworkPacket;
        }

        action receivePacket {
            out item packet : NetworkPacket;
        }
    }

    part def Battery {
        attribute stateOfCharge : Percent;
        attribute nominalVoltage : Volt = 3.85;
        attribute maximumPowerOutput : Watt = 18.0;
        attribute health : Percent;

        port power : PowerPort;

        action supplyPower {
            out item energy : ElectricalEnergy;
        }

        action acceptCharge {
            in item energy : ElectricalEnergy;
        }
    }

    part def ComputePlatform {
        attribute processorLoad : Percent;
        attribute memoryUsed : ByteCount;
        attribute storageUsed : ByteCount;
        attribute secureBootVerified : Boolean;
        attribute operatingTemperature : Celsius;

        port ui : UserInterfacePort;
        port sensors : SensorInputPort;
        port network : WirelessNetworkPort;
        port power : PowerPort;

        action processCommand {
            in item command : UserCommand;
            out item notification : Notification;
        }

        action interpretContext {
            in item reading : SensorReading;
            out item notification : Notification;
        }

        action synchronizeData {
            in item inbound : NetworkPacket;
            out item outbound : NetworkPacket;
        }

        state machine operationalState {
            state off;
            state booting;
            state ready;
            state active;
            state lowPower;
            state updating;
            state emergencyMode;
            state shutdown;

            transition first off;

            transition powerOn
                first off
                then booting
                accept UserCommand
                if commandType == CommandType::powerOn;

            transition bootComplete
                first booting
                then ready
                if secureBootVerified == true;

            transition userInteraction
                first ready
                then active
                accept UserCommand;

            transition interactionComplete
                first active
                then ready;

            transition conserveEnergy
                first ready
                then lowPower
                if processorLoad < 10 and operatingTemperature < 40.0;

            transition wake
                first lowPower
                then ready
                accept UserCommand;

            transition beginUpdate
                first ready
                then updating
                accept UserCommand
                if commandType == CommandType::updateSettings;

            transition finishUpdate
                first updating
                then ready;

            transition emergency
                first ready
                then emergencyMode
                accept UserCommand
                if priority == CommandPriority::emergency;

            transition emergencyFromActive
                first active
                then emergencyMode
                accept UserCommand
                if priority == CommandPriority::emergency;

            transition endEmergency
                first emergencyMode
                then ready;

            transition powerOff
                first ready
                then shutdown
                accept UserCommand
                if commandType == CommandType::powerOff;

            transition shutdownComplete
                first shutdown
                then off;
        }
    }

    part def SmartDevice {
        attribute deviceId : String;
        attribute ownerId : String;
        attribute massGrams : Real = 210.0;
        attribute ingressProtectionRating : String = "IP68";
        attribute primaryFunctionDescription : String =
            "Provide a portable, context-aware computing interface that senses user and environment context, processes commands, presents information, and securely exchanges data over wireless networks.";

        part display : TouchDisplay;
        part sensors : SensorSuite;
        part wireless : WirelessModule;
        part battery : Battery;
        part compute : ComputePlatform;

        port userAccess : UserInterfacePort;
        port environmentAccess : SensorInputPort;
        port networkAccess : WirelessNetworkPort;
        port chargingAccess : PowerPort;

        connection userToDisplay connect userAccess to display.ui;
        connection displayToCompute connect display.ui to compute.ui;
        connection sensorsToCompute connect sensors.sensorOutput to compute.sensors;
        connection wirelessToCompute connect wireless.network to compute.network;
        connection batteryToCompute connect battery.power to compute.power;
        connection externalSensorAccess connect environmentAccess to sensors.sensorOutput;
        connection externalNetworkAccess connect networkAccess to wireless.network;
        connection externalChargingAccess connect chargingAccess to battery.power;

        action performPrimaryFunction {
            in item command : UserCommand;
            out item notification : Notification;
            out item frame : DisplayFrame;

            action senseContext : sensors.acquireContext;
            action processInput : compute.processCommand;
            action updateDisplay : display.renderUserExperience;
            action exchangeData : compute.synchronizeData;
        }

        state machine deviceLifecycle {
            state manufactured;
            state configured;
            state operating;
            state degraded;
            state serviceRequired;
            state retired;

            transition first manufactured;

            transition configure
                first manufactured
                then configured;

            transition activate
                first configured
                then operating;

            transition detectDegradation
                first operating
                then degraded
                if battery.health < 70.0 or wireless.signalStrength < 15.0;

            transition recover
                first degraded
                then operating
                if battery.health >= 70.0 and wireless.signalStrength >= 15.0;

            transition serviceNeeded
                first degraded
                then serviceRequired
                if battery.health < 50.0;

            transition serviced
                first serviceRequired
                then operating;

            transition retire
                first operating
                then retired;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject device : SmartDevice;

        require constraint {
            device.primaryFunctionDescription != "";
        }

        doc /* The smart device shall provide a portable high-level computing function by accepting user commands, sensing contextual information, processing the inputs, presenting useful information, and exchanging data securely over wireless communication links. */
    }

    requirement def SecureCommunicationRequirement {
        subject radio : WirelessModule;

        require constraint {
            radio.encryptionActive == true;
        }

        doc /* The smart device shall encrypt outbound wireless data during normal operation. */
    }

    requirement def BatteryOperationRequirement {
        subject powerSource : Battery;

        require constraint {
            powerSource.stateOfCharge >= 5.0;
        }

        doc /* The smart device shall continue controlled operation while the battery state of charge is at or above five percent. */
    }

    requirement def UserFeedbackRequirement {
        subject screen : TouchDisplay;

        require constraint {
            screen.currentBrightness >= 1.0 and screen.currentBrightness <= screen.maximumBrightness;
        }

        doc /* The smart device shall provide visible user feedback through the touch display whenever active user interaction is occurring. */
    }

    requirement def ContextSensingRequirement {
        subject sensorSystem : SensorSuite;

        require constraint {
            sensorSystem.locationAvailable == true or sensorSystem.motionDetected == true or sensorSystem.biometricAuthenticated == true;
        }

        doc /* The smart device shall support context-aware behavior using at least one available sensing capability. */
    }

    requirement def ThermalSafetyRequirement {
        subject processor : ComputePlatform;

        require constraint {
            processor.operatingTemperature <= 45.0;
        }

        doc /* The smart device shall keep the compute platform within the normal user-safe operating temperature range during sustained operation. */
    }

    part smartDevice : SmartDevice {
        attribute deviceId = "SMART-DEVICE-001";
        attribute ownerId = "PRIMARY-USER";
    }

    satisfy primaryFunctionSatisfaction
        by smartDevice
        satisfy PrimaryFunctionRequirement;

    satisfy secureCommunicationSatisfaction
        by smartDevice.wireless
        satisfy SecureCommunicationRequirement;

    satisfy batteryOperationSatisfaction
        by smartDevice.battery
        satisfy BatteryOperationRequirement;

    satisfy userFeedbackSatisfaction
        by smartDevice.display
        satisfy UserFeedbackRequirement;

    satisfy contextSensingSatisfaction
        by smartDevice.sensors
        satisfy ContextSensingRequirement;

    satisfy thermalSafetySatisfaction
        by smartDevice.compute
        satisfy ThermalSafetyRequirement;
}