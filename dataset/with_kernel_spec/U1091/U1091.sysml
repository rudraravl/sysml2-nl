package IntegerMillenniumHouse {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def HeatTransferCoefficientValue :> Real;
    attribute def ConcentrationValue :> Real;

    item def Electricity;
    item def Heat;
    item def Air;
    item def Rainwater;
    item def ControlSignal;
    item def SensorData;

    attribute def OccupiedEvent;
    attribute def UnoccupiedEvent;

    port def ElectricPort {
        item electricity : Electricity;
    }
    port def ThermalPort {
        item heat : Heat;
    }
    port def AirPort {
        item air : Air;
    }
    port def WaterPort {
        item water : Rainwater;
    }
    port def ControlInPort {
        item signal : ControlSignal;
    }
    port def ControlOutPort {
        item signal : ControlSignal;
    }
    port def DataOutPort {
        item data : SensorData;
    }
    port def DataInPort {
        item data : SensorData;
    }

    interface def ElectricInterface {
        end src : ElectricPort;
        end dst : ElectricPort;
    }
    interface def ThermalInterface {
        end src : ThermalPort;
        end dst : ThermalPort;
    }
    interface def AirInterface {
        end src : AirPort;
        end dst : AirPort;
    }
    interface def WaterInterface {
        end src : WaterPort;
        end dst : WaterPort;
    }
    interface def ControlInterface {
        end src : ControlOutPort;
        end dst : ControlInPort;
    }
    interface def DataInterface {
        end src : DataOutPort;
        end dst : DataInPort;
    }

    part def PassiveHouseEnvelope {
        attribute uValue : HeatTransferCoefficientValue;
        attribute airtightness : Real;
        attribute thermalMass : HeatCapacityValue;
        port freshAirIn : AirPort;
        port staleAirOut : AirPort;
    }

    part def TripleGlazedWindow {
        attribute uValue : HeatTransferCoefficientValue;
        attribute solarHeatGainCoeff : Real;
        attribute area : AreaValue;
    }

    part def PhotovoltaicArray {
        attribute peakPower : PowerValue;
        port electricOut : ElectricPort;
        action generateElectricity;
    }

    part def GroundSourceHeatPump {
        attribute heatingCapacity : PowerValue;
        attribute coolingCapacity : PowerValue;
        attribute cop : Real;
        port electricIn : ElectricPort;
        port thermalOut : ThermalPort;
        port thermalIn : ThermalPort;
        port controlIn : ControlInPort;
        action provideHeating;
        action provideCooling;
    }

    part def MVHR {
        attribute heatRecoveryEfficiency : Real;
        attribute supplyFlowRate : VolumeFlowRateValue;
        port electricIn : ElectricPort;
        port supplyAirOut : AirPort;
        port staleAirIn : AirPort;
        port controlIn : ControlInPort;
        action ventilate;
    }

    part def ThermalEnergyStorageTank {
        attribute capacity : EnergyValue;
        attribute currentEnergy : EnergyValue;
        port thermalIn : ThermalPort;
        port thermalOut : ThermalPort;
    }

    part def LEDLightingSystem {
        attribute powerDraw : PowerValue;
        port electricIn : ElectricPort;
        port controlIn : ControlInPort;
        action illuminate;
    }

    part def RainwaterHarvestingSystem {
        attribute storageCapacity : VolumeValue;
        port waterOut : WaterPort;
        action collectRainwater;
    }

    part def OccupancySensor {
        attribute isOccupied : Boolean;
        port dataOut : DataOutPort;
    }

    part def EnvironmentalMonitor {
        attribute temperature : TemperatureValue;
        attribute co2Level : ConcentrationValue;
        port dataOut : DataOutPort;
    }

    part def BuildingManagementSystem {
        attribute mode : String;
        port occDataIn : DataInPort;
        port envDataIn : DataInPort;
        port controlOut : ControlOutPort;
        action optimizePerformance;
    }

    state def BMSControl {
        part bms : BuildingManagementSystem;
        entry assign bms.mode := "initializing";
        then state monitoring;
        accept OccupiedEvent then occupied;
        accept UnoccupiedEvent then unoccupied;
        state occupied {
            do assign bms.mode := "occupied";
        }
        then monitoring;
        state unoccupied {
            do assign bms.mode := "unoccupied";
        }
        then monitoring;
    }

    part def House {
        attribute totalArea : AreaValue;
        attribute annualEnergyConsumption : EnergyValue;

        part envelope : PassiveHouseEnvelope;
        part windows : TripleGlazedWindow[4..*];
        part pvArray : PhotovoltaicArray;
        part heatPump : GroundSourceHeatPump;
        part mvhr : MVHR;
        part storageTank : ThermalEnergyStorageTank;
        part lighting : LEDLightingSystem;
        part rainwater : RainwaterHarvestingSystem;
        part occSensors : OccupancySensor[*];
        part envMonitors : EnvironmentalMonitor[*];
        part bms : BuildingManagementSystem;
        state bmsControl : BMSControl;

        interface pvToHeatPump : ElectricInterface
            connect pvArray.electricOut to heatPump.electricIn;
        interface pvToMVHR : ElectricInterface
            connect pvArray.electricOut to mvhr.electricIn;
        interface pvToLighting : ElectricInterface
            connect pvArray.electricOut to lighting.electricIn;

        interface heatPumpToTank : ThermalInterface
            connect heatPump.thermalOut to storageTank.thermalIn;
        interface tankToHeatPump : ThermalInterface
            connect storageTank.thermalOut to heatPump.thermalIn;

        interface mvhrToEnvelope : AirInterface
            connect mvhr.supplyAirOut to envelope.freshAirIn;
        interface envelopeToMvhr : AirInterface
            connect envelope.staleAirOut to mvhr.staleAirIn;

        interface bmsToHeatPump : ControlInterface
            connect bms.controlOut to heatPump.controlIn;
        interface bmsToMvhr : ControlInterface
            connect bms.controlOut to mvhr.controlIn;
        interface bmsToLighting : ControlInterface
            connect bms.controlOut to lighting.controlIn;

        interface occSensorToBms : DataInterface
            connect occSensors.dataOut to bms.occDataIn;
        interface envMonitorToBms : DataInterface
            connect envMonitors.dataOut to bms.envDataIn;
    }

    part millenniumHouse : House {
        attribute :>> totalArea = 180 [m2];
        attribute :>> annualEnergyConsumption = 12000 [kWh];
    }

    requirement def NearZeroEnergyReq {
        doc /* The house shall achieve near-zero annual energy consumption. */
        attribute annualEnergyConsumption : EnergyValue;
        attribute maxAnnualEnergy : EnergyValue;
        require constraint { annualEnergyConsumption <= maxAnnualEnergy }
    }

    requirement def ThermalComfortReq {
        doc /* The house shall maintain comfortable indoor temperatures. */
        attribute indoorTemp : TemperatureValue;
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
        require constraint { indoorTemp >= minTemp && indoorTemp <= maxTemp }
    }

    requirement def AirQualityReq {
        doc /* The house shall maintain excellent indoor air quality. */
        attribute co2Level : ConcentrationValue;
        attribute maxCO2 : ConcentrationValue;
        require constraint { co2Level <= maxCO2 }
    }

    requirement def HeatRecoveryReq {
        doc /* The MVHR shall recover over 90% of heat. */
        attribute efficiency : Real;
        attribute minEfficiency : Real;
        require constraint { efficiency >= minEfficiency }
    }

    requirement def RainwaterReuseReq {
        doc /* The rainwater system shall provide water for non-potable uses. */
        attribute rainwaterCollected : VolumeValue;
        attribute minRainwater : VolumeValue;
        require constraint { rainwaterCollected >= minRainwater }
    }

    requirement houseEnergyReq : NearZeroEnergyReq {
        attribute :>> maxAnnualEnergy = 15000 [kWh];
    }
    requirement houseComfortReq : ThermalComfortReq {
        attribute :>> minTemp = 20 [degC];
        attribute :>> maxTemp = 24 [degC];
    }
    requirement houseAirReq : AirQualityReq {
        attribute :>> maxCO2 = 1000;
    }
    requirement houseHeatRecoveryReq : HeatRecoveryReq {
        attribute :>> minEfficiency = 0.9;
    }
    requirement houseRainwaterReq : RainwaterReuseReq {
        attribute :>> minRainwater = 5000 [L];
    }
}
