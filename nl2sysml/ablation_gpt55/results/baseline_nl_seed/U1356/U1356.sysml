package PhilipsHueBasedLightingModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def LuminousFluxValue :> ISQ::luminousFlux;
    attribute def IlluminanceValue :> ISQ::illuminance;
    attribute def ElectricPowerValue :> ISQ::power;
    attribute def VoltageValue :> ISQ::electricPotential;
    attribute def FrequencyValue :> ISQ::frequency;
    attribute def DurationValue :> ISQ::duration;
    attribute def ColorTemperatureValue :> ISQ::thermodynamicTemperature;
    attribute def PercentValue :> ScalarValues::Real;
    attribute def HueAngleValue :> ScalarValues::Real;

    item def ACLinePower {
        attribute rmsVoltage : VoltageValue = 120 [SI::V];
        attribute frequency : FrequencyValue = 60 [SI::Hz];
        attribute availablePower : ElectricPowerValue = 15 [SI::W];
    }

    item def DCPower {
        attribute voltage : VoltageValue = 24 [SI::V];
        attribute availablePower : ElectricPowerValue = 10 [SI::W];
    }

    item def LEDDrivePower {
        attribute channelPower : ElectricPowerValue = 9 [SI::W];
        attribute redDutyCycle : PercentValue = 0.0;
        attribute greenDutyCycle : PercentValue = 0.0;
        attribute blueDutyCycle : PercentValue = 0.0;
        attribute whiteDutyCycle : PercentValue = 100.0;
    }

    item def LightingCommand {
        attribute onRequested : Boolean = true;
        attribute brightness : PercentValue = 100.0;
        attribute hueDegrees : HueAngleValue = 0.0;
        attribute colorTemperature : ColorTemperatureValue = 2700 [SI::K];
        attribute fadeTime : DurationValue = 1 [SI::s];
    }

    item def LampStatus {
        attribute powered : Boolean = true;
        attribute reachable : Boolean = true;
        attribute emitting : Boolean = true;
        attribute reportedBrightness : PercentValue = 100.0;
        attribute reportedFlux : LuminousFluxValue = 800 [SI::lm];
        attribute reportedColorTemperature : ColorTemperatureValue = 2700 [SI::K];
    }

    item def LightEmission {
        attribute luminousFlux : LuminousFluxValue = 800 [SI::lm];
        attribute brightness : PercentValue = 100.0;
        attribute hueDegrees : HueAngleValue = 0.0;
        attribute colorTemperature : ColorTemperatureValue = 2700 [SI::K];
    }

    item def AmbientLight {
        attribute illuminance : IlluminanceValue = 300 [SI::lx];
        attribute estimatedContributionFromLamp : LuminousFluxValue = 800 [SI::lm];
    }

    item def SensorReport {
        attribute measuredIlluminance : IlluminanceValue = 300 [SI::lx];
        attribute occupancyDetected : Boolean = true;
        attribute reportPeriod : DurationValue = 5 [SI::s];
    }

    port def ACOutputPort {
        out item acPower : ACLinePower;
    }

    port def ACInputPort {
        in item acPower : ACLinePower;
    }

    port def DCOutputPort {
        out item dcPower : DCPower;
    }

    port def DCInputPort {
        in item dcPower : DCPower;
    }

    port def LEDDriveOutputPort {
        out item ledDrive : LEDDrivePower;
    }

    port def LEDDriveInputPort {
        in item ledDrive : LEDDrivePower;
    }

    port def UserCommandClientPort {
        out item command : LightingCommand;
        in item status : LampStatus;
    }

    port def UserCommandServerPort {
        in item command : LightingCommand;
        out item status : LampStatus;
    }

    port def BridgeLampPort {
        out item command : LightingCommand;
        in item status : LampStatus;
    }

    port def LampCommandPort {
        in item command : LightingCommand;
        out item status : LampStatus;
    }

    port def SensorReportOutputPort {
        out item report : SensorReport;
    }

    port def SensorReportInputPort {
        in item report : SensorReport;
    }

    port def AmbientLightInputPort {
        in item ambient : AmbientLight;
    }

    port def AmbientLightOutputPort {
        out item ambient : AmbientLight;
    }

    port def LightOutputPort {
        out item light : LightEmission;
    }

    port def LightInputPort {
        in item light : LightEmission;
    }

    action def ProvideSmartIllumination {
        in item requestedLighting : LightingCommand;
        in item inputPower : ACLinePower;
        in item roomAmbient : AmbientLight;
        out item controlledLight : LightEmission;
        out item lampStatus : LampStatus;

        action receiveCommand;
        action convertInputPower;
        action computeColorAndBrightness;
        action driveLedChannels;
        action emitVisibleLight;
        action reportStatus;

        succession first receiveCommand then convertInputPower;
        succession first convertInputPower then computeColorAndBrightness;
        succession first computeColorAndBrightness then driveLedChannels;
        succession first driveLedChannels then emitVisibleLight;
        succession first emitVisibleLight then reportStatus;
    }

    action def RouteLightingCommand {
        in item userCommand : LightingCommand;
        in item sensorReport : SensorReport;
        out item lampCommand : LightingCommand;
        out item bridgeStatus : LampStatus;

        action receiveUserIntent;
        action receiveRoomContext;
        action selectTargetLampSetting;
        action transmitZigbeeCommand;
        action relayLampStatus;

        succession first receiveUserIntent then receiveRoomContext;
        succession first receiveRoomContext then selectTargetLampSetting;
        succession first selectTargetLampSetting then transmitZigbeeCommand;
        succession first transmitZigbeeCommand then relayLampStatus;
    }

    action def MeasureRoomIlluminance {
        in item ambientInput : AmbientLight;
        out item sensorReport : SensorReport;

        action samplePhotodiode;
        action evaluateOccupancy;
        action publishReport;

        succession first samplePhotodiode then evaluateOccupancy;
        succession first evaluateOccupancy then publishReport;
    }

    state def HueLampOperatingState {
        entry; then Off;

        state Off;
        state Standby;
        state NetworkConnected;
        state Illuminating;
        state Fault;

        transition applyPower first Off then Standby;
        transition pairToBridge first Standby then NetworkConnected;
        transition commandOn first NetworkConnected then Illuminating;
        transition commandOff first Illuminating then NetworkConnected;
        transition removePower first Standby then Off;
        transition faultDetected first NetworkConnected then Fault;
        transition recover first Fault then Standby;
    }

    part def MainsPowerSource {
        port acSupplyPort : ACOutputPort;

        attribute nominalVoltage : VoltageValue = 120 [SI::V];
        attribute nominalFrequency : FrequencyValue = 60 [SI::Hz];
        attribute maximumContinuousPower : ElectricPowerValue = 1800 [SI::W];
    }

    part def MobileHueApplication {
        port userNetworkPort : UserCommandClientPort;

        attribute commandUpdatePeriod : DurationValue = 1 [SI::s];
        attribute requestedBrightness : PercentValue = 100.0;
        attribute requestedColorTemperature : ColorTemperatureValue = 2700 [SI::K];
    }

    part def HueBridge {
        port userNetworkPort : UserCommandServerPort;
        port lampNetworkPort : BridgeLampPort;
        port sensorNetworkPort : SensorReportInputPort;

        attribute wirelessCarrierFrequency : FrequencyValue = 2405000000 [SI::Hz];
        attribute commandLatencyBudget : DurationValue = 0.25 [SI::s];
        attribute pairedLampCapacity : ScalarValues::Integer = 50;

        perform action routeCommand : RouteLightingCommand;
    }

    part def LampPowerSupply {
        port acInput : ACInputPort;
        port dcOutput : DCOutputPort;

        attribute inputVoltage : VoltageValue = 120 [SI::V];
        attribute outputVoltage : VoltageValue = 24 [SI::V];
        attribute maximumOutputPower : ElectricPowerValue = 10 [SI::W];
        attribute standbyPower : ElectricPowerValue = 0.5 [SI::W];
    }

    part def LampController {
        port networkPort : LampCommandPort;
        port dcInput : DCInputPort;
        port ledDriveOutput : LEDDriveOutputPort;

        attribute processorPower : ElectricPowerValue = 0.8 [SI::W];
        attribute commandProcessingTime : DurationValue = 0.05 [SI::s];
        attribute minimumBrightness : PercentValue = 1.0;
        attribute maximumBrightness : PercentValue = 100.0;
    }

    part def RGBCCTLedEngine {
        port ledDriveInput : LEDDriveInputPort;
        port lightOutput : LightOutputPort;

        attribute maximumLuminousFlux : LuminousFluxValue = 800 [SI::lm];
        attribute minimumColorTemperature : ColorTemperatureValue = 2000 [SI::K];
        attribute maximumColorTemperature : ColorTemperatureValue = 6500 [SI::K];
        attribute opticalPowerConsumption : ElectricPowerValue = 9 [SI::W];
    }

    part def HueLamp {
        port acPowerPort : ACInputPort;
        port wirelessPort : LampCommandPort;
        port lightPort : LightOutputPort;
        port ambientPort : AmbientLightInputPort;

        attribute maximumLuminousFlux : LuminousFluxValue = 800 [SI::lm];
        attribute standbyPower : ElectricPowerValue = 0.5 [SI::W];
        attribute ratedPower : ElectricPowerValue = 10 [SI::W];
        attribute minimumColorTemperature : ColorTemperatureValue = 2000 [SI::K];
        attribute maximumColorTemperature : ColorTemperatureValue = 6500 [SI::K];

        part powerSupply : LampPowerSupply;
        part controller : LampController;
        part ledEngine : RGBCCTLedEngine;

        connection externalACToSupply connect acPowerPort to powerSupply.acInput;
        connection supplyToController connect powerSupply.dcOutput to controller.dcInput;
        connection controllerToLedEngine connect controller.ledDriveOutput to ledEngine.ledDriveInput;
        connection internalWirelessToController connect wirelessPort to controller.networkPort;
        connection ledEngineToLampAperture connect ledEngine.lightOutput to lightPort;

        perform action primaryLightingFunction : ProvideSmartIllumination;
        exhibit state operatingState : HueLampOperatingState;
    }

    part def HueAmbientSensor {
        port ambientInputPort : AmbientLightInputPort;
        port sensorReportPort : SensorReportOutputPort;

        attribute illuminanceMeasurementRangeHigh : IlluminanceValue = 10000 [SI::lx];
        attribute illuminanceMeasurementRangeLow : IlluminanceValue = 1 [SI::lx];
        attribute reportInterval : DurationValue = 5 [SI::s];

        perform action measureIlluminance : MeasureRoomIlluminance;
    }

    part def IlluminatedRoom {
        port lightInputPort : LightInputPort;
        port ambientOutputPort : AmbientLightOutputPort;

        attribute targetTaskIlluminance : IlluminanceValue = 300 [SI::lx];
        attribute roomAreaEquivalentFluxNeed : LuminousFluxValue = 800 [SI::lm];
    }

    part def HueLightingSystem {
        port userInterfacePort : UserCommandClientPort;

        attribute primaryFunctionDescription : String = "Accept user lighting commands and provide controllable white or colored visible illumination to a room.";
        attribute requiredMaximumFlux : LuminousFluxValue = 800 [SI::lm];
        attribute endToEndCommandResponseBudget : DurationValue = 1 [SI::s];

        part mains : MainsPowerSource;
        part mobileApp : MobileHueApplication;
        part bridge : HueBridge;
        part hueLamp : HueLamp;
        part ambientSensor : HueAmbientSensor;
        part illuminatedRoom : IlluminatedRoom;

        connection userToApp connect userInterfacePort to mobileApp.userNetworkPort;
        connection appToBridge connect mobileApp.userNetworkPort to bridge.userNetworkPort;
        connection bridgeToLamp connect bridge.lampNetworkPort to hueLamp.wirelessPort;
        connection mainsToLamp connect mains.acSupplyPort to hueLamp.acPowerPort;
        connection lampToRoom connect hueLamp.lightPort to illuminatedRoom.lightInputPort;
        connection roomToSensor connect illuminatedRoom.ambientOutputPort to ambientSensor.ambientInputPort;
        connection sensorToBridge connect ambientSensor.sensorReportPort to bridge.sensorNetworkPort;

        perform action systemPrimaryFunction : ProvideSmartIllumination;
    }

    requirement def HuePrimaryFunctionRequirement {
        subject hueSystem : HueLightingSystem;
        doc /* The system shall provide its primary high-level function by receiving a user lighting command and delivering controllable visible illumination to the room through a Philips Hue based lamp, bridge, and application architecture. */
    }

    requirement def HueFluxCapabilityRequirement {
        subject hueSystem : HueLightingSystem;
        doc /* The system shall include a lamp capable of producing at least 800 lm of luminous flux for general room illumination. */
        require constraint { hueSystem.hueLamp.maximumLuminousFlux >= 800 [SI::lm] }
    }

    requirement def HueCommandResponseRequirement {
        subject hueSystem : HueLightingSystem;
        doc /* The system shall route a user command from the application through the bridge to the lamp within the end-to-end response budget. */
        require constraint { hueSystem.endToEndCommandResponseBudget <= 1 [SI::s] }
    }

    requirement def HueColorControlRequirement {
        subject hueSystem : HueLightingSystem;
        doc /* The lamp shall support controllable warm-to-cool white light over the modeled color-temperature range. */
        require constraint { hueSystem.hueLamp.minimumColorTemperature <= 2000 [SI::K] }
        require constraint { hueSystem.hueLamp.maximumColorTemperature >= 6500 [SI::K] }
    }

    part hueHomeLighting : HueLightingSystem;

    requirement huePrimaryFunction : HuePrimaryFunctionRequirement {
        subject hueSystem = hueHomeLighting;
    }

    requirement hueFluxCapability : HueFluxCapabilityRequirement {
        subject hueSystem = hueHomeLighting;
    }

    requirement hueCommandResponse : HueCommandResponseRequirement {
        subject hueSystem = hueHomeLighting;
    }

    requirement hueColorControl : HueColorControlRequirement {
        subject hueSystem = hueHomeLighting;
    }

    satisfy huePrimaryFunction by hueHomeLighting;
    satisfy hueFluxCapability by hueHomeLighting.hueLamp;
    satisfy hueCommandResponse by hueHomeLighting.bridge;
    satisfy hueColorControl by hueHomeLighting.hueLamp;
}
