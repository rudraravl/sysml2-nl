package ModernMobileDevice {
    private import ScalarValues::*;
    
    attribute def Volt :> Real;
    attribute def Ampere :> Real;
    attribute def MilliampereHour :> Real;
    attribute def Percent :> Real;
    attribute def MegabitPerSecond :> Real;
    attribute def DecibelMilliwatt :> Real;
    attribute def Gigabyte :> Real;
    attribute def Gigahertz :> Real;
    attribute def PixelCount :> Integer;
    attribute def GForce :> Real;
    attribute def DegreesPerSecond :> Real;
    attribute def Centimeter :> Real;
    attribute def Lux :> Real;

    item def Data;
    item def ImageData :> Data;
    item def AudioData :> Data;
    item def NetworkData :> Data;
    item def SensorReading :> Data;
    item def TouchEvent :> Data;
    item def ControlSignal;
    item def Electricity {
        attribute voltage : Volt = 3.7;
        attribute current : Ampere = 2.0;
    }

    port def PowerOut {
        out item power : Electricity;
    }
    port def PowerIn {
        in item power : Electricity;
    }
    port def BatteryStatusOut {
        out attribute chargeLevel : Percent;
    }
    port def BatteryStatusIn {
        in attribute chargeLevel : Percent;
    }
    port def ControlOut {
        out item command : ControlSignal;
    }
    port def ControlIn {
        in item command : ControlSignal;
    }
    port def TouchOut {
        out item touch : TouchEvent;
    }
    port def TouchIn {
        in item touch : TouchEvent;
    }
    port def AudioOut {
        out item audio : AudioData;
    }
    port def AudioIn {
        in item audio : AudioData;
    }
    port def NetworkControllerPort {
        out item txData : NetworkData;
        in item rxData : NetworkData;
    }
    port def RadioTransceiverPort {
        in item txData : NetworkData;
        out item rxData : NetworkData;
    }
    port def ImageOut {
        out item image : ImageData;
    }
    port def ImageIn {
        in item image : ImageData;
    }
    port def StorageControllerPort {
        out item writeData : Data;
        in item readData : Data;
    }
    port def StorageDevicePort {
        in item writeData : Data;
        out item readData : Data;
    }
    port def SensorOut {
        out item reading : SensorReading;
    }
    port def SensorIn {
        in item reading : SensorReading;
    }

    part def Processor {
        attribute coreCount : Integer = 8;
        attribute clockRate : Gigahertz = 2.5;
        port powerIn : PowerIn;
        port batteryStatusIn : BatteryStatusIn;
        port touchIn : TouchIn;
        port microphoneIn : AudioIn;
        port accelerometerIn : SensorIn;
        port gyroscopeIn : SensorIn;
        port proximityIn : SensorIn;
        port lightIn : SensorIn;
        port cameraIn : ImageIn;
        port storagePort : StorageControllerPort;
        port displayOut : ImageOut;
        port displayControlOut : ControlOut;
        port speakerOut : AudioOut;
        port radioPort : NetworkControllerPort;
        port radioControlOut : ControlOut;
        port cameraControlOut : ControlOut;
        port storageControlOut : ControlOut;
        perform action executeApplications {
            first start;
            then action scheduleTasks;
            then action dispatchInstructions;
            then done;
        }
    }

    part def RechargeableBattery {
        attribute capacity : MilliampereHour = 5000;
        attribute chargeLevel : Percent = 100;
        port powerOut : PowerOut;
        port statusOut : BatteryStatusOut;
        perform action monitorCharge {
            out attribute chargeLevel : Percent;
            first start;
            then action readCellVoltage;
            then action computeChargeLevel;
            then done;
        }
    }

    part def Display {
        attribute widthPixels : PixelCount = 2400;
        attribute heightPixels : PixelCount = 1080;
        attribute brightness : Percent = 50;
        port powerIn : PowerIn;
        port imageIn : ImageIn;
        port controlIn : ControlIn;
    }

    part def TouchScreen {
        attribute maxTouchPoints : Integer = 10;
        port powerIn : PowerIn;
        port touchOut : TouchOut;
    }

    part def Speaker {
        attribute maxVolume : Percent = 100;
        port powerIn : PowerIn;
        port audioIn : AudioIn;
    }

    part def Microphone {
        port powerIn : PowerIn;
        port audioOut : AudioOut;
    }

    part def WirelessRadio {
        attribute signalStrength : DecibelMilliwatt = -60;
        attribute dataRate : MegabitPerSecond = 1000;
        port powerIn : PowerIn;
        port networkPort : RadioTransceiverPort;
        port controlIn : ControlIn;
        perform action transmit {
            in item data : NetworkData;
            first start;
            then action encodePacket;
            then action sendPacket;
            then done;
        }
        perform action receive {
            out item data : NetworkData;
            first start;
            then action detectSignal;
            then action decodePacket;
            then done;
        }
    }

    part def Camera {
        attribute megapixels : Integer = 48;
        port powerIn : PowerIn;
        port imageOut : ImageOut;
        port controlIn : ControlIn;
        perform action captureImage {
            out item image : ImageData;
            first start;
            then action focus;
            then action capture;
            then done;
        }
    }

    part def InternalStorage {
        attribute capacity : Gigabyte = 256;
        attribute usedSpace : Gigabyte = 0;
        port powerIn : PowerIn;
        port dataPort : StorageDevicePort;
        port controlIn : ControlIn;
    }

    part def Accelerometer {
        attribute maxRange : GForce = 16;
        port powerIn : PowerIn;
        port readingOut : SensorOut;
    }

    part def Gyroscope {
        attribute maxRange : DegreesPerSecond = 2000;
        port powerIn : PowerIn;
        port readingOut : SensorOut;
    }

    part def ProximityDetector {
        attribute maxRange : Centimeter = 5;
        port powerIn : PowerIn;
        port readingOut : SensorOut;
    }

    part def LightSensor {
        attribute maxIlluminance : Lux = 10000;
        port powerIn : PowerIn;
        port readingOut : SensorOut;
    }

    state def DeviceStates {
        in attribute batteryLevel : Percent;
        in attribute powerRequested : Boolean;
        in attribute bootComplete : Boolean;
        in attribute userActive : Boolean;
        state off;
        state booting;
        state idle;
        state standby;
        state active;
        state lowPower;
        transition off to booting when powerRequested == true;
        transition booting to idle when bootComplete == true;
        transition idle to active when userActive == true;
        transition active to idle when userActive == false;
        transition idle to standby when userActive == false;
        transition standby to active when userActive == true;
        transition idle to lowPower when batteryLevel <= 5;
        transition active to lowPower when batteryLevel <= 5;
        transition standby to lowPower when batteryLevel <= 5;
        transition lowPower to idle when batteryLevel > 5;
        transition lowPower to off when batteryLevel == 0;
    }

    part def MobileDevice {
        attribute powerRequested : Boolean = false;
        attribute bootComplete : Boolean = false;
        attribute userActive : Boolean = false;

        part processor : Processor;
        part battery : RechargeableBattery;
        part display : Display;
        part touchScreen : TouchScreen;
        part speaker : Speaker;
        part microphone : Microphone;
        part wirelessRadio : WirelessRadio;
        part camera : Camera;
        part internalStorage : InternalStorage;
        part accelerometer : Accelerometer;
        part gyroscope : Gyroscope;
        part proximityDetector : ProximityDetector;
        part lightSensor : LightSensor;

        connect battery.powerOut to processor.powerIn;
        connect battery.powerOut to display.powerIn;
        connect battery.powerOut to touchScreen.powerIn;
        connect battery.powerOut to speaker.powerIn;
        connect battery.powerOut to microphone.powerIn;
        connect battery.powerOut to wirelessRadio.powerIn;
        connect battery.powerOut to camera.powerIn;
        connect battery.powerOut to internalStorage.powerIn;
        connect battery.powerOut to accelerometer.powerIn;
        connect battery.powerOut to gyroscope.powerIn;
        connect battery.powerOut to proximityDetector.powerIn;
        connect battery.powerOut to lightSensor.powerIn;

        connect battery.statusOut to processor.batteryStatusIn;
        connect touchScreen.touchOut to processor.touchIn;
        connect microphone.audioOut to processor.microphoneIn;
        connect processor.speakerOut to speaker.audioIn;
        connect processor.displayOut to display.imageIn;
        connect processor.displayControlOut to display.controlIn;
        connect processor.radioPort to wirelessRadio.networkPort;
        connect processor.radioControlOut to wirelessRadio.controlIn;
        connect camera.imageOut to processor.cameraIn;
        connect processor.cameraControlOut to camera.controlIn;
        connect processor.storagePort to internalStorage.dataPort;
        connect processor.storageControlOut to internalStorage.controlIn;
        connect accelerometer.readingOut to processor.accelerometerIn;
        connect gyroscope.readingOut to processor.gyroscopeIn;
        connect proximityDetector.readingOut to processor.proximityIn;
        connect lightSensor.readingOut to processor.lightIn;

        exhibit deviceStates : DeviceStates {
            in batteryLevel = battery.chargeLevel;
            in powerRequested = powerRequested;
            in bootComplete = bootComplete;
            in userActive = userActive;
        }
    }

    part mobileDevice : MobileDevice;

    requirement def MobileDevicePowerRequirement {
        doc /* A rechargeable battery shall supply electric power to every component of the mobile device. */
        subject device : MobileDevice;
    }
    requirement def MobileDeviceInteractionRequirement {
        doc /* The device shall accept multi-touch input and provide visual feedback on a high-resolution display. */
        subject device : MobileDevice;
    }
    requirement def MobileDeviceConnectivityRequirement {
        doc /* The device shall provide wireless connectivity for network access and data transfer. */
        subject device : MobileDevice;
    }
    requirement def MobileDeviceMultimediaRequirement {
        doc /* The device shall capture images, capture audio, and play audio. */
        subject device : MobileDevice;
    }
    requirement def MobileDevicePowerManagementRequirement {
        doc /* The device shall monitor battery charge and enter low-power mode when charge is critically low. */
        subject device : MobileDevice;
    }
}
