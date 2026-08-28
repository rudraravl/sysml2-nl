package 'GoogleNestLearningThermostat' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::m;
    private import SI::h;

    attribute def AwayModeSignal;
    attribute def HomeModeSignal;

    port def SensorDataPort;
    port def DisplayPort;
    port def NetworkPort;
    port def HVACControlPort;

    part def TemperatureSensor {
        attribute reading : TemperatureValue;
        port dataOut : SensorDataPort;
    }

    part def HumiditySensor {
        attribute reading : Real;
        port dataOut : SensorDataPort;
    }

    part def OccupancySensor {
        attribute detectionRange : LengthValue = 6 [m];
        attribute isOccupied : Boolean;
        port dataOut : SensorDataPort;
    }

    part def TouchDisplay {
        attribute currentSetpoint : TemperatureValue;
        port displayOut : DisplayPort;
    }

    part def WiFiModule {
        attribute isConnected : Boolean;
        port netOut : NetworkPort;
    }

    part def HVACSystem {
        attribute heatingActive : Boolean = false;
        attribute coolingActive : Boolean = false;
        port controlIn : ~HVACControlPort;
    }

    part def ControlProcessor {
        attribute setpoint : TemperatureValue;
        attribute ecoSetpoint : TemperatureValue;
        attribute awaySetpoint : TemperatureValue;
        attribute actualTemp : TemperatureValue;
        attribute actualHumidity : Real;
        attribute isOccupied : Boolean;
        attribute emptyDurationThreshold : DurationValue = 1 [h];
        attribute savedSetpoint : TemperatureValue;
        attribute mode : String = "Normal";

        port sensorIn : ~SensorDataPort;
        port displayIn : ~DisplayPort;
        port netIn : ~NetworkPort;
        port hvacOut : HVACControlPort;
    }

    action senseEnvironment {
        out temp : TemperatureValue;
        out humidity : Real;
        out occupied : Boolean;
    }
    action activateHeating;
    action activateCooling;
    action deactivateHVAC;
    action learnSchedule;
    action enterEco;
    action enterAway;

    state def ClimateControl {
        in processor : ControlProcessor;
        in hvac : HVACSystem;

        entry; then idle;
        do senseEnvironment;

        state idle;
        accept when senseEnvironment.temp < processor.setpoint and senseEnvironment.occupied
            do activateHeating
            then heating;
        accept when senseEnvironment.temp > processor.setpoint and senseEnvironment.occupied
            do activateCooling
            then cooling;
        accept after processor.emptyDurationThreshold
            if not senseEnvironment.occupied
            do enterEco
            then eco;
        accept AwayModeSignal
            do enterAway
            then away;

        state heating;
        accept when senseEnvironment.temp >= processor.setpoint
            do deactivateHVAC
            then idle;

        state cooling;
        accept when senseEnvironment.temp <= processor.setpoint
            do deactivateHVAC
            then idle;

        state eco;
        accept when senseEnvironment.occupied
            then idle;

        state away;
        accept HomeModeSignal
            then idle;
    }

    part def ThermostatUnit {
        part processor : ControlProcessor;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part occupancySensor : OccupancySensor;
        part display : TouchDisplay;
        part wifi : WiFiModule;

        connect tempSensor.dataOut to processor.sensorIn;
        connect humiditySensor.dataOut to processor.sensorIn;
        connect occupancySensor.dataOut to processor.sensorIn;
        connect display.displayOut to processor.displayIn;
        connect wifi.netOut to processor.netIn;
    }

    part def NestSystem {
        part thermostat : ThermostatUnit;
        part hvac : HVACSystem;

        connect thermostat.processor.hvacOut to hvac.controlIn;
    }

    requirement def TemperatureRegulationReq {
        doc /* The system shall maintain indoor temperature within 1 degree of the user setpoint. */
        attribute setpoint : TemperatureValue;
        attribute actualTemp : TemperatureValue;
        require constraint { actualTemp - setpoint <= 1 and setpoint - actualTemp <= 1 }
    }

    requirement def EcoModeActivationReq {
        doc /* The system shall automatically enter Eco Mode when the house is unoccupied for an extended period to conserve energy. */
        attribute unoccupiedDuration : DurationValue;
        attribute threshold : DurationValue = 1 [h];
        attribute mode : String;
        require constraint { unoccupiedDuration >= threshold implies mode == "Eco" }
    }

    requirement def LearningCapabilityReq {
        doc /* The system shall learn user habits and occupancy patterns to build an optimized schedule without manual programming. */
        attribute scheduleLearned : Boolean;
        require constraint { scheduleLearned == true }
    }

    requirement def OccupancyRangeReq {
        doc /* The occupancy sensor shall detect human presence within a 6-meter range. */
        attribute detectionRange : LengthValue;
        attribute maxRange : LengthValue = 6 [m];
        require constraint { detectionRange <= maxRange }
    }

    requirement def NetworkConnectivityReq {
        doc /* The WiFi module shall provide remote control via smartphone app and cloud synchronization. */
        attribute connected : Boolean;
        require constraint { connected == true }
    }

    requirement def AwayModeReq {
        doc /* The system shall support manual Away Mode activation to reduce setpoint and minimize energy consumption. */
        attribute awayActive : Boolean;
        require constraint { awayActive == true }
    }

    requirement def HumidityMonitoringReq {
        doc /* The system shall monitor indoor humidity levels for comfort and air quality management. */
        attribute humidity : Real;
        require constraint { humidity >= 30 and humidity <= 50 }
    }
}
