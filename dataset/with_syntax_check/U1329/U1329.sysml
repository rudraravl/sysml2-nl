package 'Daikin HVAC System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TemperatureSetpoint :> TemperatureValue;
    attribute def HumidityLevel :> Real;
    attribute def AirFlowRate :> VolumeFlowRateValue;
    attribute def PowerLevel :> PowerValue;
    attribute def RefrigerantPressure :> PressureValue;
    attribute def CompressorFrequency :> FrequencyValue;

    enum def OperatingMode {
        enum cooling;
        enum heating;
        enum dehumidifying;
        enum fanOnly;
        enum auto;
        enum off;
    }

    enum def FanSpeed {
        enum low;
        enum medium;
        enum high;
        enum auto;
    }

    item def Refrigerant {
        attribute pressure : RefrigerantPressure;
        attribute temperature : TemperatureValue;
        attribute flowRate : VolumeFlowRateValue;
    }

    item def Air {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityLevel;
        attribute flowRate : AirFlowRate;
    }

    port def RefrigerantPort {
        inout refrigerant : Refrigerant;
    }

    port def AirPort {
        inout air : Air;
    }

    port def PowerPort {
        in powerSupply : PowerLevel;
    }

    port def ControlPort {
        in setpoint : TemperatureSetpoint;
        in mode : OperatingMode;
        in fanSpeed : FanSpeed;
        out currentTemperature : TemperatureValue;
        out currentHumidity : HumidityLevel;
        out systemStatus : Boolean;
    }

    part def InverterCompressor {
        attribute operatingFrequency : CompressorFrequency;
        attribute minFrequency : CompressorFrequency = 20.0[Hz];
        attribute maxFrequency : CompressorFrequency = 120.0[Hz];
        attribute efficiency : Real;

        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port power : PowerPort;

        action def CompressRefrigerant {
            in inputPressure : RefrigerantPressure;
            in frequency : CompressorFrequency;
            out outputPressure : RefrigerantPressure;
            out powerConsumed : PowerLevel;
        }
    }

    part def HeatExchanger {
        attribute surfaceArea : AreaValue;
        attribute heatTransferCoefficient : Real;

        port refrigerantSide : RefrigerantPort;
        port airSide : AirPort;

        action def ExchangeHeat {
            in refrigerantTemp : TemperatureValue;
            in airTemp : TemperatureValue;
            in airFlow : AirFlowRate;
            out refrigerantTempOut : TemperatureValue;
            out airTempOut : TemperatureValue;
        }
    }

    part def ExpansionValve {
        attribute openingDegree : Real;

        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;

        action def ExpandRefrigerant {
            in highPressure : RefrigerantPressure;
            in opening : Real;
            out lowPressure : RefrigerantPressure;
        }
    }

    part def BlowerFan {
        attribute speed : FanSpeed;
        attribute maxAirFlow : AirFlowRate;

        port air : AirPort;
        port power : PowerPort;

        action def CirculateAir {
            in speedSetting : FanSpeed;
            out airFlowGenerated : AirFlowRate;
            out powerUsed : PowerLevel;
        }
    }

    part def TemperatureHumiditySensor {
        port sensing : AirPort;

        action def MeasureConditions {
            out measuredTemp : TemperatureValue;
            out measuredHumidity : HumidityLevel;
        }
    }

    part def InverterController {
        attribute targetTemp : TemperatureSetpoint;
        attribute currentMode : OperatingMode;

        port control : ControlPort;

        action def DetermineCompressorSpeed {
            in currentTemp : TemperatureValue;
            in setpoint : TemperatureSetpoint;
            in mode : OperatingMode;
            out frequency : CompressorFrequency;
        }

        action def DetermineFanSpeed {
            in mode : OperatingMode;
            in userFanSpeed : FanSpeed;
            out actualFanSpeed : FanSpeed;
        }
    }

    part def IndoorUnit {
        doc /* Indoor unit containing evaporator coil, blower fan, and sensors. */

        part evaporator : HeatExchanger;
        part indoorFan : BlowerFan;
        part sensor : TemperatureHumiditySensor;
        part expansionValve : ExpansionValve;

        port indoorAir : AirPort;
        port refrigerantConnection : RefrigerantPort;
        port indoorPower : PowerPort;

        connect evaporator.airSide to indoorFan.air;
        connect indoorFan.air to sensor.sensing;
        connect sensor.sensing to indoorAir;
        connect expansionValve.refrigerantOut to evaporator.refrigerantSide;
        connect evaporator.refrigerantSide to refrigerantConnection;
    }

    part def OutdoorUnit {
        doc /* Outdoor unit containing compressor, condenser coil, and outdoor fan. */

        part compressor : InverterCompressor;
        part condenser : HeatExchanger;
        part outdoorFan : BlowerFan;

        port outdoorAir : AirPort;
        port refrigerantConnection : RefrigerantPort;
        port outdoorPower : PowerPort;

        connect condenser.airSide to outdoorFan.air;
        connect outdoorFan.air to outdoorAir;
        connect compressor.refrigerantOut to condenser.refrigerantSide;
        connect condenser.refrigerantSide to refrigerantConnection;
        connect compressor.power to outdoorPower;
        connect outdoorFan.power to outdoorPower;
    }

    action def CoolingCycle {
        in setpoint : TemperatureSetpoint;
        in currentTemp : TemperatureValue;
        out cooledAirTemp : TemperatureValue;

        action compressorOp : InverterCompressor::CompressRefrigerant;
        action condenserOp : HeatExchanger::ExchangeHeat;
        action expansionOp : ExpansionValve::ExpandRefrigerant;
        action evaporatorOp : HeatExchanger::ExchangeHeat;
        action fanOp : BlowerFan::CirculateAir;

        flow compressorOp.outputPressure to condenserOp.refrigerantTemp;
        flow condenserOp.refrigerantTempOut to expansionOp.highPressure;
        flow expansionOp.lowPressure to evaporatorOp.refrigerantTemp;
        flow evaporatorOp.airTempOut to cooledAirTemp;
    }

    action def HeatingCycle {
        in setpoint : TemperatureSetpoint;
        in currentTemp : TemperatureValue;
        out heatedAirTemp : TemperatureValue;

        action compressorOp : InverterCompressor::CompressRefrigerant;
        action condenserOp : HeatExchanger::ExchangeHeat;
        action expansionOp : ExpansionValve::ExpandRefrigerant;
        action evaporatorOp : HeatExchanger::ExchangeHeat;
        action fanOp : BlowerFan::CirculateAir;

        flow compressorOp.outputPressure to evaporatorOp.refrigerantTemp;
        flow evaporatorOp.refrigerantTempOut to expansionOp.highPressure;
        flow expansionOp.lowPressure to condenserOp.refrigerantTemp;
        flow condenserOp.airTempOut to heatedAirTemp;
    }

    action def DehumidifyingCycle {
        in currentHumidity : HumidityLevel;
        out dehumidifiedAir : Air;
    }

    action def FanOnlyCycle {
        in fanSpeed : FanSpeed;
        out circulatedAir : Air;
    }

    part def DaikinInverterAirConditioner {
        doc /* 
            Daikin inverter air conditioning system providing efficient climate control
            through variable-speed compressor technology and intelligent control algorithms.
            The system maintains precise temperature control while optimizing energy consumption.
        */

        attribute ratedCapacity : PowerLevel = 3500.0[W];
        attribute ratedEER : Real = 4.5;
        attribute operatingVoltage : Real = 230.0;

        port roomAir : AirPort;
        port ambientAir : AirPort;
        port powerInput : PowerPort;
        port userControl : ControlPort;

        part indoor : IndoorUnit;
        part outdoor : OutdoorUnit;
        part controller : InverterController;

        connect indoor.indoorAir to roomAir;
        connect outdoor.outdoorAir to ambientAir;
        connect indoor.indoorPower to powerInput;
        connect outdoor.outdoorPower to powerInput;
        connect controller.control to userControl;
        connect indoor.refrigerantConnection to outdoor.refrigerantConnection;

        perform action climateControl : ClimateControlOperation;
    }

    action def ClimateControlOperation {
        in targetTemperature : TemperatureSetpoint;
        in operatingMode : OperatingMode;
        out conditionedAir : Air;

        first start;
        then merge controlLoop;

        then action sense : TemperatureHumiditySensor::MeasureConditions {
            out currentTemp : TemperatureValue;
            out currentHumidity : HumidityLevel;
        }

        then action determineSpeed : InverterController::DetermineCompressorSpeed {
            in currentTemp = sense.currentTemp;
            in setpoint = targetTemperature;
            in mode = operatingMode;
            out frequency : CompressorFrequency;
        }

        then decide;
            if operatingMode == OperatingMode::cooling then performCooling;
            if operatingMode == OperatingMode::heating then performHeating;
            if operatingMode == OperatingMode::dehumidifying then performDehumidifying;
            if operatingMode == OperatingMode::fanOnly then performFanOnly;
            if operatingMode == OperatingMode::off then done;

        action performCooling : CoolingCycle {
            in setpoint = targetTemperature;
            in currentTemp = sense.currentTemp;
            out cooledAirTemp : TemperatureValue;
        }
        then controlLoop;

        action performHeating : HeatingCycle {
            in setpoint = targetTemperature;
            in currentTemp = sense.currentTemp;
            out heatedAirTemp : TemperatureValue;
        }
        then controlLoop;

        action performDehumidifying : DehumidifyingCycle {
            in currentHumidity = sense.currentHumidity;
            out dehumidifiedAir : Air;
        }
        then controlLoop;

        action performFanOnly : FanOnlyCycle {
            in fanSpeed = FanSpeed::auto;
            out circulatedAir : Air;
        }
        then controlLoop;
    }

    requirement def TemperatureAccuracyRequirement {
        doc /* The system shall maintain room temperature within ±0.5°C of setpoint during steady-state operation. */
        subject system : DaikinInverterAirConditioner;
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall achieve an Energy Efficiency Ratio (EER) of at least 4.0 at rated conditions. */
        subject system : DaikinInverterAirConditioner;
        require constraint {
            system.ratedEER >= 4.0
        }
    }

    requirement def InverterOperatingRangeRequirement {
        doc /* The inverter compressor shall operate within specified frequency range for optimal efficiency. */
        subject compressor : InverterCompressor;
        require constraint {
            compressor.operatingFrequency >= compressor.minFrequency and
            compressor.operatingFrequency <= compressor.maxFrequency
        }
    }

    requirement def QuietOperationRequirement {
        doc /* The indoor unit shall operate with noise level not exceeding 40 dB(A) at low fan speed. */
        subject indoor : IndoorUnit;
    }

    requirement systemRequirements {
        doc /* Top-level requirements for Daikin inverter air conditioning system. */

        require temperatureAccuracy : TemperatureAccuracyRequirement;
        require energyEfficiency : EnergyEfficiencyRequirement;
        require inverterRange : InverterOperatingRangeRequirement;
        require quietOperation : QuietOperationRequirement;
    }

    part daikinSystem : DaikinInverterAirConditioner {
        :>> ratedCapacity = 3500.0[W];
        :>> ratedEER = 4.5;
        :>> operatingVoltage = 230.0;

        satisfy systemRequirements;
    }
}
