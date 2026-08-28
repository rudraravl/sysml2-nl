package EnOceanBuildingAutomation {
    attribute def TemperatureValue :> ScalarValues::Real;
    attribute def FrequencyValue :> ScalarValues::Real;
    attribute def DistanceValue :> ScalarValues::Real;
    attribute def PowerValue :> ScalarValues::Real;
    attribute def EnergyValue :> ScalarValues::Real;
    attribute def IlluminanceValue :> ScalarValues::Real;

    attribute def ChargeThresholdReached;
    attribute def TransmissionComplete;

    item def SensorPayload {
        attribute nodeId : ScalarValues::String;
        attribute roomLocation : ScalarValues::String;
        attribute temperature : TemperatureValue;
        attribute occupied : ScalarValues::Boolean;
        attribute illuminance : IlluminanceValue;
        attribute timestamp : ScalarValues::String;
    }

    item def RadioTelegram {
        attribute telegramId : ScalarValues::String;
        attribute sourceNodeId : ScalarValues::String;
        item payload : SensorPayload;
        attribute signalStrength : ScalarValues::Real;
    }

    item def ControlCommand {
        attribute targetRoomId : ScalarValues::String;
        attribute lightingOn : ScalarValues::Boolean;
        attribute hvacOn : ScalarValues::Boolean;
        attribute hvacSetpoint : TemperatureValue;
    }

    port def RadioOutPort {
        out item telegram : RadioTelegram;
    }

    port def RadioInPort {
        in item telegram : RadioTelegram;
    }

    port def BuildingNetworkPort {
        in item sensorData : SensorPayload;
        out item controlCmd : ControlCommand;
    }

    port def CommandInPort {
        in item cmd : ControlCommand;
    }

    abstract part def EnergyHarvester {
        attribute maxOutputPower : PowerValue;
        perform action harvestEnergy;
    }

    part def SolarHarvester :> EnergyHarvester {
        attribute cellType : ScalarValues::String = "amorphous silicon";
        attribute activeArea : ScalarValues::Real;
    }

    part def PiezoelectricHarvester :> EnergyHarvester {
        attribute excitationType : ScalarValues::String = "mechanical vibration";
    }

    part def EnergyStorageCapacitor {
        attribute capacitance : ScalarValues::Real;
        attribute storedEnergy : EnergyValue;
        attribute maxEnergyCapacity : EnergyValue;
        assert constraint {
            storedEnergy <= maxEnergyCapacity
        }
        perform action charge;
        perform action supplyEnergy;
    }

    part def PowerManagementChip {
        attribute chargeThreshold : EnergyValue;
        attribute regulatedOutputVoltage : ScalarValues::Real;
        perform action manageEnergy;
        perform action regulateSupply;
    }

    part def MultiSensorUnit {
        attribute sensedTemperature : TemperatureValue;
        attribute roomOccupied : ScalarValues::Boolean;
        attribute sensedIlluminance : IlluminanceValue;
        perform action senseEnvironment;
    }

    part def EnOceanRadioModule {
        attribute frequencyBand : FrequencyValue;
        attribute maxRange : DistanceValue;
        port radioOut : RadioOutPort;
        perform action transmit;
    }

    part def EnOceanSensorNode {
        attribute nodeId : ScalarValues::String;
        attribute roomLocation : ScalarValues::String;
        part solarHarvester : SolarHarvester;
        part piezoHarvester : PiezoelectricHarvester;
        part storageCapacitor : EnergyStorageCapacitor;
        part powerManager : PowerManagementChip;
        part sensorUnit : MultiSensorUnit;
        part radioModule : EnOceanRadioModule;
        perform action takeSnapshot;
        exhibit state nodeStates {
            entry; then harvesting;
            state harvesting;
            accept ChargeThresholdReached then awake;
            state awake {
                entry takeSnapshot;
                do send new RadioTelegram() via radioModule.radioOut;
            }
            accept TransmissionComplete then harvesting;
        }
    }

    part def EnOceanGateway {
        attribute gatewayId : ScalarValues::String;
        attribute isMainsPowered : ScalarValues::Boolean = true;
        port radioIn : RadioInPort;
        port buildingNetworkPort : ~BuildingNetworkPort;
        perform action validateTelegram;
        perform action extractPayload;
        perform action forwardToBMS;
        exhibit state gatewayStates {
            entry; then listening;
            state listening;
            accept tg : RadioTelegram via radioIn
                do send new SensorPayload() via buildingNetworkPort
                then listening;
        }
    }

    part def HVACController {
        attribute isOn : ScalarValues::Boolean;
        attribute currentSetpoint : TemperatureValue;
        port cmdPort : CommandInPort;
        perform action applyCommand;
        perform action turnOn;
        perform action turnOff;
    }

    part def LightingController {
        attribute isOn : ScalarValues::Boolean;
        port cmdPort : CommandInPort;
        perform action applyCommand;
        perform action turnOn;
        perform action turnOff;
    }

    part def BuildingManagementSystem {
        attribute bmsId : ScalarValues::String;
        attribute controlStrategy : ScalarValues::String = "Adaptive Energy Optimization";
        port networkPort : BuildingNetworkPort;
        part hvacController : HVACController;
        part lightingController : LightingController;
        perform action analyzeData;
        perform action generateControlCommand;
        exhibit state bmsStates {
            entry; then monitoring;
            state monitoring;
            accept payload : SensorPayload via networkPort
                if payload.occupied == false
                do send new ControlCommand() to lightingController
                then monitoring;
            accept payload2 : SensorPayload via networkPort
                if payload2.occupied == true
                do send new ControlCommand() to hvacController
                then monitoring;
        }
    }

    part def BuildingAutomationSystem {
        part sensorNodes : EnOceanSensorNode[1..*];
        part gateway : EnOceanGateway[1];
        part bms : BuildingManagementSystem[1];
        interface sensorNodes.radioModule.radioOut to gateway.radioIn;
        interface gateway.buildingNetworkPort to bms.networkPort;
    }

    requirement def EnergyAutonomyRequirement {
        doc /** Each EnOcean sensor node shall operate entirely from harvested energy without batteries. */
        subject node : EnOceanSensorNode;
        assert constraint {
            node.solarHarvester.maxOutputPower > 0
            and node.piezoHarvester.maxOutputPower > 0
        }
    }

    requirement def RadioSpecRequirement {
        doc /** The EnOcean radio module shall transmit at 868 MHz with up to 300 m range. */
        subject radio : EnOceanRadioModule;
        assert constraint {
            radio.frequencyBand > 0
            and radio.maxRange > 0
        }
    }

    requirement def MaintenanceFreeRequirement {
        doc /** The system shall be maintenance-free with no battery replacements needed. */
        subject system : BuildingAutomationSystem;
        assert constraint {
            system.gateway.isMainsPowered == true
        }
    }

    requirement def AdaptiveOptimizationRequirement {
        doc /** The BMS shall implement adaptive energy optimization based on occupancy and illuminance data from sensor nodes. */
        subject bms : BuildingManagementSystem;
        assert constraint {
            bms.controlStrategy == "Adaptive Energy Optimization"
        }
    }
}
